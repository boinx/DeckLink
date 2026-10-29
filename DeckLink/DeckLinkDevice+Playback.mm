#import "DeckLinkDevice+Playback.h"

#import "CMFormatDescription+DeckLink.h"
#import "DeckLinkAPI.h"
#import "DeckLinkAudioConnection+Internal.h"
#import "DeckLinkDevice+Internal.h"
#import "DeckLinkKeying.h"
#import "DeckLinkPixelBufferFrame.h"
#import "DeckLinkVideoConnection+Internal.h"

#import <mach/mach_time.h>
#import <os/lock.h>


// Hidden prefs key to log how the card clock drifts against the host clock during scheduled playback.
// Switch with Terminal: "defaults write com.boinx.mimoLive TVMeasurePlayoutTiming -bool true"
// Report interval in seconds (default 10): "defaults write com.boinx.mimoLive TVMeasurePlayoutTimingInterval -float 30"
static NSString * const DeckLinkMeasurePlaybackTimingKey = @"TVMeasurePlayoutTiming";
static NSString * const DeckLinkMeasurePlaybackTimingIntervalKey = @"TVMeasurePlayoutTimingInterval";

// Exact tick counts for all common frame rates (23.976 = 5005, 25 = 4800, 29.97 = 4004, 50 = 2400, 59.94 = 2002, 60 = 2000).
static const BMDTimeScale DeckLinkPlaybackTimingTimeScale = 120000;

typedef struct
{
	uint64_t hostTime;		// mach absolute time
	BMDTimeValue cardTime;	// hardware reference clock, DeckLinkPlaybackTimingTimeScale
} DeckLinkPlaybackClockSample;

typedef struct
{
	NSUInteger completed, late, dropped, flushed;
	NSUInteger audioSamplesDropped;
	uint32_t bufferedFramesMin, bufferedFramesMax;
	double leadSum, leadMin, leadMax;	// seconds
	NSUInteger leadCount;
	double audioBufferedSum;			// sample frames
	uint32_t audioBufferedMin, audioBufferedMax;
	NSUInteger audioBufferedCount;
} DeckLinkPlaybackTimingCounters;

// The card plays out on its own oscillator (or the genlock reference), the frames are timed by mimoLive on the host clock.
// Measured on every frame completion (the card clock tick):
// - the card's hardware reference clock against the host clock: card clock drift in ppm and the real frame rate of the mode,
// - the lead: end time of the last scheduled frame minus the current playback position on the card. A growing lead means
//   frames arrive faster than the card plays them out, a shrinking one slower. Its slope is the drift that matters,
// - buffered video frames and audio sample frames on the card, the audio level slope is the audio drift,
// - completion results (late, dropped, flushed) as the symptoms.
// Playback and the audio buffer need a few seconds to settle after start, so the drift reference is taken from the first
// report window that starts after this time.
static const double DeckLinkPlaybackTimingSettleTime = 10.0;

@interface DeckLinkPlaybackTimingMonitor : NSObject
- (instancetype)initWithOutput:(IDeckLinkOutput *)output name:(NSString *)name audioSampleRate:(double)audioSampleRate;
- (void)recordScheduledFrameEndTime:(double)endTime;
- (void)recordCompletionWithResult:(BMDOutputFrameCompletionResult)result;
- (void)recordAudioSamplesWritten:(uint32_t)written requested:(uint32_t)requested;
- (void)stop;
@end

@implementation DeckLinkPlaybackTimingMonitor
{
	IDeckLinkOutput *_output;
	NSString *_name;
	double _audioSampleRate;
	double _reportInterval;
	double _hostTicksPerSecond;
	dispatch_queue_t _logQueue;

	os_unfair_lock _lock;
	BOOL _stopped;
	BOOL _hasLastScheduledEndTime;
	double _lastScheduledEndTime;
	BMDTimeValue _ticksPerFrame;

	BOOL _hasStartSample;
	DeckLinkPlaybackClockSample _startSample;
	DeckLinkPlaybackClockSample _windowStartSample;
	DeckLinkPlaybackClockSample _lastSample;

	// averages of the first settled window, the slope against them gives the drift since then
	BOOL _hasFirstLead;
	double _firstLead, _firstLeadTime;
	BOOL _hasFirstAudioBuffered;
	double _firstAudioBuffered, _firstAudioBufferedTime;

	DeckLinkPlaybackTimingCounters _window;
	DeckLinkPlaybackTimingCounters _total;
}

- (instancetype)initWithOutput:(IDeckLinkOutput *)output name:(NSString *)name audioSampleRate:(double)audioSampleRate
{
	self = [super init];
	if (self != nil)
	{
		_output = output;
		_name = [name copy] ?: @"DeckLink";
		_audioSampleRate = audioSampleRate;
		_lock = OS_UNFAIR_LOCK_INIT;
		_logQueue = dispatch_queue_create("DeckLinkPlaybackTimingMonitor.log", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));

		mach_timebase_info_data_t timebase;
		mach_timebase_info(&timebase);
		_hostTicksPerSecond = 1.0e9 * (double)timebase.denom / (double)timebase.numer;

		double reportInterval = [NSUserDefaults.standardUserDefaults doubleForKey:DeckLinkMeasurePlaybackTimingIntervalKey];
		_reportInterval = (reportInterval > 0.0) ? reportInterval : 10.0;

		[self resetCounters:&_window];
		[self resetCounters:&_total];

		NSLog(@"DeckLink playout timing [%@]: measurement started, report every %.0f s.", _name, _reportInterval);
	}
	return self;
}

- (void)resetCounters:(DeckLinkPlaybackTimingCounters *)counters
{
	memset(counters, 0, sizeof(*counters));
	counters->bufferedFramesMin = UINT32_MAX;
	counters->audioBufferedMin = UINT32_MAX;
	counters->leadMin = INFINITY;
	counters->leadMax = -INFINITY;
}

- (void)recordScheduledFrameEndTime:(double)endTime
{
	os_unfair_lock_lock(&_lock);
	_lastScheduledEndTime = endTime;
	_hasLastScheduledEndTime = YES;
	os_unfair_lock_unlock(&_lock);
}

- (void)recordAudioSamplesWritten:(uint32_t)written requested:(uint32_t)requested
{
	if (written >= requested)
	{
		return;
	}
	os_unfair_lock_lock(&_lock);
	_window.audioSamplesDropped += requested - written;
	_total.audioSamplesDropped += requested - written;
	os_unfair_lock_unlock(&_lock);
}

- (void)recordCompletionWithResult:(BMDOutputFrameCompletionResult)result
{
	// sample everything outside the lock, these are quick driver queries
	DeckLinkPlaybackClockSample sample;
	BMDTimeValue timeInFrame = 0, ticksPerFrame = 0;
	BOOL hasCardTime = (_output->GetHardwareReferenceClock(DeckLinkPlaybackTimingTimeScale, &sample.cardTime, &timeInFrame, &ticksPerFrame) == S_OK);
	sample.hostTime = mach_absolute_time();

	BMDTimeValue streamTime = 0;
	double playbackSpeed = 0.0;
	BOOL hasStreamTime = (_output->GetScheduledStreamTime(DeckLinkPlaybackTimingTimeScale, &streamTime, &playbackSpeed) == S_OK && playbackSpeed > 0.0);

	uint32_t bufferedFrames = 0;
	BOOL hasBufferedFrames = (_output->GetBufferedVideoFrameCount(&bufferedFrames) == S_OK);

	uint32_t audioBuffered = 0;
	BOOL hasAudioBuffered = (_audioSampleRate > 0.0 && _output->GetBufferedAudioSampleFrameCount(&audioBuffered) == S_OK);

	NSString *report = nil;

	os_unfair_lock_lock(&_lock);

	if (_stopped)
	{
		os_unfair_lock_unlock(&_lock);
		return;
	}

	DeckLinkPlaybackTimingCounters *counters[] = { &_window, &_total };
	for (size_t index = 0; index < 2; ++index)
	{
		DeckLinkPlaybackTimingCounters *c = counters[index];
		switch (result)
		{
			case bmdOutputFrameCompleted:		c->completed++; break;
			case bmdOutputFrameDisplayedLate:	c->late++; break;
			case bmdOutputFrameDropped:			c->dropped++; break;
			case bmdOutputFrameFlushed:			c->flushed++; break;
			default: break;
		}
		if (hasBufferedFrames)
		{
			c->bufferedFramesMin = MIN(c->bufferedFramesMin, bufferedFrames);
			c->bufferedFramesMax = MAX(c->bufferedFramesMax, bufferedFrames);
		}
		if (hasStreamTime && _hasLastScheduledEndTime)
		{
			double lead = _lastScheduledEndTime - (double)streamTime / (double)DeckLinkPlaybackTimingTimeScale;
			c->leadSum += lead;
			c->leadMin = MIN(c->leadMin, lead);
			c->leadMax = MAX(c->leadMax, lead);
			c->leadCount++;
		}
		if (hasAudioBuffered)
		{
			c->audioBufferedSum += audioBuffered;
			c->audioBufferedMin = MIN(c->audioBufferedMin, audioBuffered);
			c->audioBufferedMax = MAX(c->audioBufferedMax, audioBuffered);
			c->audioBufferedCount++;
		}
	}

	if (hasCardTime)
	{
		if (ticksPerFrame > 0)
		{
			_ticksPerFrame = ticksPerFrame;
		}
		if (!_hasStartSample)
		{
			_startSample = sample;
			_windowStartSample = sample;
			_hasStartSample = YES;
		}
		_lastSample = sample;

		double windowDuration = (double)(sample.hostTime - _windowStartSample.hostTime) / _hostTicksPerSecond;
		if (windowDuration >= _reportInterval)
		{
			report = [self reportForWindowDuration:windowDuration];
			_windowStartSample = sample;
			[self resetCounters:&_window];
		}
	}

	os_unfair_lock_unlock(&_lock);

	if (report != nil)
	{
		dispatch_async(_logQueue, ^{
			NSLog(@"%@", report);
		});
	}
}

/// Card clock rate against the host clock in ppm, positive = card clock runs fast.
- (double)cardDriftFrom:(DeckLinkPlaybackClockSample)from to:(DeckLinkPlaybackClockSample)to
{
	double hostDuration = (double)(to.hostTime - from.hostTime) / _hostTicksPerSecond;
	double cardDuration = (double)(to.cardTime - from.cardTime) / (double)DeckLinkPlaybackTimingTimeScale;
	return (hostDuration > 0.0) ? (cardDuration / hostDuration - 1.0) * 1.0e6 : NAN;
}

/// Called with the lock held.
- (NSString *)reportForWindowDuration:(double)windowDuration
{
	const DeckLinkPlaybackTimingCounters window = _window;
	const DeckLinkPlaybackTimingCounters total = _total;
	const double now = (double)(_lastSample.hostTime - _startSample.hostTime) / _hostTicksPerSecond;
	const double windowMid = now - windowDuration * 0.5;
	const BOOL windowIsSettled = (now - windowDuration) >= DeckLinkPlaybackTimingSettleTime - 0.5;

	const double cardDriftWindow = [self cardDriftFrom:_windowStartSample to:_lastSample];
	const double cardDriftTotal = [self cardDriftFrom:_startSample to:_lastSample];
	const double nominalFrameRate = (_ticksPerFrame > 0) ? (double)DeckLinkPlaybackTimingTimeScale / (double)_ticksPerFrame : 0.0;
	const double realFrameRate = nominalFrameRate * (1.0 + cardDriftTotal * 1.0e-6);

	// lead slope: positive = mimoLive delivers faster than the card plays out
	NSString *leadString = @"lead n/a";
	double leadAvg = NAN;
	if (window.leadCount > 0)
	{
		leadAvg = window.leadSum / (double)window.leadCount;
		NSString *slopeString = @"";
		if (!_hasFirstLead && windowIsSettled)
		{
			_firstLead = leadAvg;
			_firstLeadTime = windowMid;
			_hasFirstLead = YES;
		}
		else if (_hasFirstLead && windowMid > _firstLeadTime)
		{
			const double drift = (leadAvg - _firstLead) / (windowMid - _firstLeadTime) * 1.0e6;
			slopeString = [NSString stringWithFormat:@", lead drift %+.1f ppm (%+.1f ms since t=%.0fs)", drift, (leadAvg - _firstLead) * 1000.0, _firstLeadTime];
		}
		leadString = [NSString stringWithFormat:@"lead min %.1f avg %.1f max %.1f ms%@", window.leadMin * 1000.0, leadAvg * 1000.0, window.leadMax * 1000.0, slopeString];
	}

	NSString *audioString = @"audio n/a";
	if (window.audioBufferedCount > 0)
	{
		const double audioAvg = window.audioBufferedSum / (double)window.audioBufferedCount;
		NSString *slopeString = @"";
		if (!_hasFirstAudioBuffered && windowIsSettled)
		{
			_firstAudioBuffered = audioAvg;
			_firstAudioBufferedTime = windowMid;
			_hasFirstAudioBuffered = YES;
		}
		else if (_hasFirstAudioBuffered && windowMid > _firstAudioBufferedTime)
		{
			const double drift = (audioAvg - _firstAudioBuffered) / _audioSampleRate / (windowMid - _firstAudioBufferedTime) * 1.0e6;
			slopeString = [NSString stringWithFormat:@", audio drift %+.1f ppm (%+.1f ms since t=%.0fs)", drift, (audioAvg - _firstAudioBuffered) / _audioSampleRate * 1000.0, _firstAudioBufferedTime];
		}
		// Both are measured against the card's playback position. Continuous audio: the difference is how much later audio plays
		// than video. Timestamped audio plays at its timestamps anyway, the difference is how far ahead audio is delivered.
		NSString *offsetString = isnan(leadAvg) ? @"" : [NSString stringWithFormat:@", %+.1f ms vs video lead", (audioAvg / _audioSampleRate - leadAvg) * 1000.0];
		audioString = [NSString stringWithFormat:@"audio buffered min %.1f avg %.1f max %.1f ms%@%@, dropped samples %lu (total %lu)",
					   window.audioBufferedMin / _audioSampleRate * 1000.0, audioAvg / _audioSampleRate * 1000.0, window.audioBufferedMax / _audioSampleRate * 1000.0,
					   offsetString, slopeString, (unsigned long)window.audioSamplesDropped, (unsigned long)total.audioSamplesDropped];
	}

	return [NSString stringWithFormat:@"DeckLink playout timing [%@] t=%.0fs: card clock %+.1f ppm vs host (window %+.1f), mode %.5f fps nominal, %.5f fps real | %@ | buffered frames %u..%u | frames completed %lu, late %lu, dropped %lu, flushed %lu (total late %lu, dropped %lu) | %@",
			_name, now, cardDriftTotal, cardDriftWindow, nominalFrameRate, realFrameRate,
			leadString,
			(window.bufferedFramesMin == UINT32_MAX) ? 0 : window.bufferedFramesMin, window.bufferedFramesMax,
			(unsigned long)window.completed, (unsigned long)window.late, (unsigned long)window.dropped, (unsigned long)window.flushed,
			(unsigned long)total.late, (unsigned long)total.dropped,
			audioString];
}

- (void)stop
{
	os_unfair_lock_lock(&_lock);
	_stopped = YES;
	const DeckLinkPlaybackTimingCounters total = _total;
	const double cardDriftTotal = _hasStartSample ? [self cardDriftFrom:_startSample to:_lastSample] : NAN;
	const double duration = _hasStartSample ? (double)(_lastSample.hostTime - _startSample.hostTime) / _hostTicksPerSecond : 0.0;
	os_unfair_lock_unlock(&_lock);

	NSLog(@"DeckLink playout timing [%@]: measurement stopped after %.0f s, card clock %+.1f ppm vs host, frames completed %lu, late %lu, dropped %lu, flushed %lu, dropped audio samples %lu.",
		  _name, duration, cardDriftTotal, (unsigned long)total.completed, (unsigned long)total.late, (unsigned long)total.dropped, (unsigned long)total.flushed, (unsigned long)total.audioSamplesDropped);
}

@end


// Never lets the unsigned counter wrap below zero, a wrapped counter would stop all playout in TVOutputDispatcher.
static inline void DeckLinkDecrementFrameBufferCount(atomic_uint_fast64_t *count)
{
	uint_fast64_t current = atomic_load(count);
	while (current > 0 && !atomic_compare_exchange_weak(count, &current, current - 1))
	{
	}
}


@implementation DeckLinkDevice (Playback)

- (void)setupPlayback
{
	if(deckLink->QueryInterface(IID_IDeckLinkOutput, (void **)&deckLinkOutput) != S_OK)
	{
		return;
	}
	
	self.playbackSupported = YES;
	
	self.playbackQueue = dispatch_queue_create("DeckLinkDevice.playbackQueue", DISPATCH_QUEUE_SERIAL);
	self.frameDownloadQueue = dispatch_queue_create("DeckLinkDevice.frameDownloadQueue", DISPATCH_QUEUE_SERIAL);
	
	atomic_store(&_sampleBufferCount_BackingStore, 0);
	
	// Video
	IDeckLinkDisplayModeIterator *displayModeIterator = NULL;
	if (deckLinkOutput->GetDisplayModeIterator(&displayModeIterator) == S_OK)
	{
		BMDPixelFormat pixelFormats[] = {
			kDeckLinkPrimaryPixelFormat,  
			bmdFormat8BitYUV, // == kCVPixelFormatType_422YpCbCr8 == '2vuy'
		};
		
		NSMutableArray *formatDescriptions = [NSMutableArray array];
		
		IDeckLinkDisplayMode *displayMode = NULL;
		while (displayModeIterator->Next(&displayMode) == S_OK)
		{
			BMDDisplayMode displayModeKey = displayMode->GetDisplayMode();
			
			for (size_t index = 0; index < sizeof(pixelFormats) / sizeof(*pixelFormats); ++index)
			{
				BMDPixelFormat pixelFormat = pixelFormats[index];
				
				bool supported = false;
				if (deckLinkOutput->DoesSupportVideoMode(0 /*BMDVideoConnection*/, displayModeKey, pixelFormat, bmdNoVideoOutputConversion, bmdSupportedVideoModeDefault, nil, &supported) == S_OK && supported)
				{
					CMVideoFormatDescriptionRef formatDescription = NULL;
					if(CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(displayMode, pixelFormat, supported, &formatDescription) == noErr)
					{
						[formatDescriptions addObject:(__bridge id)formatDescription];
						CFRelease(formatDescription);
						// TODO: currently only RGBA or YUV is provided. It might make sense to provide both formats in the future and let the client filter.
						// The UltraStudio 4K supports both, but the UltraStudio Mini Monitor only support YUV.
						break;
					}
				}
			}
		}
		displayModeIterator->Release();
		
		self.playbackVideoFormatDescriptions = formatDescriptions;
		// TODO: get active format description from the device
	}
	
	// Audio
	{
		NSMutableArray *formatDescriptions = [NSMutableArray arrayWithCapacity:2];
		
		// bmdAudioSampleRate48kHz / bmdAudioSampleType16bitInteger
		{
			const AudioStreamBasicDescription streamBasicDescription = { 48000.0, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger, 4, 1, 4, 2, 16, 0 };
			const AudioChannelLayout channelLayout = { kAudioChannelLayoutTag_Stereo, 0 };
			
			NSDictionary *extensions = @{
				(__bridge id)kCMFormatDescriptionExtension_FormatName: @"48.000 Hz, 16-bit, stereo"
			};
			
			CMAudioFormatDescriptionRef formatDescription = NULL;
			CMAudioFormatDescriptionCreate(NULL, &streamBasicDescription, sizeof(channelLayout), &channelLayout, 0, NULL, (__bridge CFDictionaryRef)extensions, &formatDescription);
			
			if (formatDescription != NULL)
			{
				[formatDescriptions addObject:(__bridge id)formatDescription];
			}
		}
		
		// bmdAudioSampleRate48kHz / bmdAudioSampleType32bitInteger
		{
			const AudioStreamBasicDescription streamBasicDescription = { 48000.0, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger, 8, 1, 8, 2, 32, 0 };
			const AudioChannelLayout channelLayout = { kAudioChannelLayoutTag_Stereo, 0 };
			
			NSDictionary *extensions = @{
				(__bridge id)kCMFormatDescriptionExtension_FormatName: @"48.000 Hz, 32-bit, stereo"
			};
			
			CMAudioFormatDescriptionRef formatDescription = NULL;
			CMAudioFormatDescriptionCreate(NULL, &streamBasicDescription, sizeof(channelLayout), &channelLayout, 0, NULL, (__bridge CFDictionaryRef)extensions, &formatDescription);
			
			if (formatDescription != NULL)
			{
				[formatDescriptions addObject:(__bridge id)formatDescription];
			}
		}
		
		self.playbackAudioFormatDescriptions = formatDescriptions;
		// TODO: get active format description
	}
	
	if (deckLinkKeyer != NULL)
	{
		NSMutableArray *keyingModes = [NSMutableArray array];
		
		[keyingModes addObject:DeckLinkKeyingModeNone];
		
		bool supportsInternalKeying = false;
		deckLinkAttributes->GetFlag(BMDDeckLinkSupportsInternalKeying, &supportsInternalKeying);
		if (supportsInternalKeying)
		{
			[keyingModes addObject:DeckLinkKeyingModeInternal];
		}
		
		bool supportsExternalKeying = false;
		deckLinkAttributes->GetFlag(BMDDeckLinkSupportsExternalKeying, &supportsExternalKeying);
		if (supportsExternalKeying)
		{
			[keyingModes addObject:DeckLinkKeyingModeExternal];
		}

		self.playbackKeyingModes = keyingModes;
		self.playbackActiveKeyingMode = DeckLinkKeyingModeNone;
		self.playbackKeyingAlpha = 1.0;
		
		deckLinkKeyer->SetLevel(255);
		deckLinkKeyer->Disable();
	}
	else
	{
		self.playbackKeyingModes = @[ DeckLinkKeyingModeNone ];
	}
}

- (BOOL)setPlaybackActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)formatDescription error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	dispatch_sync(self.playbackQueue, ^{
		if (formatDescription != NULL)
		{
			if (![self.playbackVideoFormatDescriptions containsObject:(__bridge id)formatDescription])
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				return;
			}
			
			NSNumber *displayModeValue = (__bridge NSNumber *)CMFormatDescriptionGetExtension(formatDescription, DeckLinkFormatDescriptionDisplayModeKey);
			if (![displayModeValue isKindOfClass:NSNumber.class])
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:kCMFormatDescriptionError_ValueNotAvailable userInfo:nil];
				return;
			}
			
			// if the output format is 2vuy then we need to convert the frame
			FourCharCode codecType = CMVideoFormatDescriptionGetCodecType(formatDescription);
			self.videoFramesRequiresFrameConvertion = (codecType == '2vuy');
				
			BMDDisplayMode displayMode = displayModeValue.intValue;
			BMDVideoOutputFlags flags = bmdVideoOutputFlagDefault;
			
			deckLinkOutput->DisableVideoOutput();
			
			HRESULT status = deckLinkOutput->EnableVideoOutput(displayMode, flags);
			if (status != S_OK)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
		}
		else
		{
			deckLinkOutput->DisableVideoOutput();
		}
		
		self.playbackActiveVideoFormatDescription = formatDescription;
		result = YES;
	});
	
	if (error != nil)
	{
		if (outError != NULL)
		{
			*outError = error;
		}
		else
		{
			NSLog(@"%s:%d: %@", __FUNCTION__, __LINE__, error);
		}
	}
	
	return result;
}

- (BOOL)setPlaybackActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)formatDescription error:(NSError **)outError
{
	return [self setPlaybackActiveAudioFormatDescription:formatDescription timestamped:NO error:outError];
}

- (BOOL)setPlaybackActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)formatDescription timestamped:(BOOL)timestamped error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	dispatch_sync(self.playbackQueue, ^{
		if (formatDescription != NULL)
		{
			if (![self.playbackAudioFormatDescriptions containsObject:(__bridge id)formatDescription])
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				return;
			}
			
			const AudioStreamBasicDescription *basicStreamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
			
			const BMDAudioSampleRate sampleRate = basicStreamDescription->mSampleRate;;
			const BMDAudioSampleType sampleType = basicStreamDescription->mBitsPerChannel;
			const uint32_t channels = basicStreamDescription->mChannelsPerFrame;
			
			deckLinkOutput->DisableAudioOutput();

			const BMDAudioOutputStreamType streamType = timestamped ? bmdAudioOutputStreamTimestamped : bmdAudioOutputStreamContinuous;
			HRESULT status = deckLinkOutput->EnableAudioOutput(sampleRate, sampleType, channels, streamType);
			if (status != S_OK)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
		}
		else
		{
			deckLinkOutput->DisableAudioOutput();
		}
		
		self.playbackActiveAudioFormatDescription = formatDescription;
		self.playbackAudioTimestamped = (formatDescription != NULL) && timestamped;
		result = YES;
	});
	
	if (error != nil)
	{
		if (outError != NULL)
		{
			*outError = error;
		}
		else
		{
			NSLog(@"%s:%d: %@", __FUNCTION__, __LINE__, error);
		}
	}
	
	return result;
}

- (BOOL)setPlaybackActiveKeyingMode:(NSString *)keyingMode alpha:(float)alpha error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	dispatch_sync(self.playbackQueue, ^{
		if (deckLinkKeyer != NULL)
		{
			HRESULT status = E_NOTIMPL;
			
			if ([keyingMode isEqualToString:DeckLinkKeyingModeNone])
			{
				status = deckLinkKeyer->Disable();
			}
			else if ([keyingMode isEqualToString:DeckLinkKeyingModeInternal])
			{
				status = deckLinkKeyer->Enable(false);
			}
			else if ([keyingMode isEqualToString:DeckLinkKeyingModeExternal])
			{
				status = deckLinkKeyer->Enable(true);
			}
			
			if (status != S_OK && status != E_NOTIMPL)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
			
			deckLinkKeyer->SetLevel(alpha * 255.0);
		}
		else
		{
			if (keyingMode != nil)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				return;
			}
		}
		
		self.playbackActiveKeyingMode = keyingMode;
		self.playbackKeyingAlpha = alpha;
		result = YES;
	});
	
	if (error != nil)
	{
		if (outError != NULL)
		{
			*outError = error;
		}
		else
		{
			NSLog(@"%s:%d: %@", __FUNCTION__, __LINE__, error);
		}
	}
	
	return result;
}

- (void)startScheduledPlaybackWithStartTime:(NSUInteger)startTime timeScale:(NSUInteger)timeScale
{
	dispatch_async(self.playbackQueue, ^{
		// Don't reset _sampleBufferCount_BackingStore here: frames may already be scheduled (preroll) and each of them
		// decrements the counter on completion, so a reset makes the unsigned counter wrap below zero and
		// TVOutputDispatcher then drops every frame because it believes the writer buffer is full.

		if ([NSUserDefaults.standardUserDefaults boolForKey:DeckLinkMeasurePlaybackTimingKey])
		{
			double audioSampleRate = 0.0;
			CMAudioFormatDescriptionRef audioFormatDescription = self.playbackActiveAudioFormatDescription;
			if (audioFormatDescription != NULL)
			{
				const AudioStreamBasicDescription *streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription);
				audioSampleRate = (streamBasicDescription != NULL) ? streamBasicDescription->mSampleRate : 0.0;
			}
			self.playbackTimingMonitor = [[DeckLinkPlaybackTimingMonitor alloc] initWithOutput:deckLinkOutput name:self.displayName audioSampleRate:audioSampleRate];
		}

		deckLinkOutput->StartScheduledPlayback(startTime, timeScale, 1.0);
		deckLinkOutputCallback = new DeckLinkDeviceInternalOutputCallback((id<DeckLinkDeviceInternalOutputCallbackDelegate>)self);
		deckLinkOutput->SetScheduledFrameCompletionCallback(deckLinkOutputCallback);
	});
}

- (void)schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer displayTime:(NSUInteger)displayTime frameDuration:(NSUInteger)frameDuration timeScale:(NSUInteger)timeScale
{
	atomic_fetch_add(&_sampleBufferCount_BackingStore, 1);
	
	CFRetain(pixelBuffer);
	
	// TODO: Potential problem with CPU/GPU overload!!! this needs to be guarded by a semaphore with inital count of 2 or more!
	
	dispatch_async(self.frameDownloadQueue, ^{
		// The first queue just downloads the frame from GPU to CPU RAM even if the playbackQueue is sending out data to the device.
		
		DeckLinkPixelBufferFrame *frame = new DeckLinkPixelBufferFrame(pixelBuffer);
		// IDeckLinkVideoConversion
		
		dispatch_async(self.playbackQueue, ^{
			// the second queue is sending the image data to the device immediately but don't need to wait for next download
			
			DeckLinkPixelBufferFrame *myFrame = frame;
			
			if(self.videoFramesRequiresFrameConvertion)
			{
				IDeckLinkMutableVideoFrame* conversionFrame;
				if (deckLinkOutput->CreateVideoFrame((int32_t)frame->GetWidth(),
													 (int32_t)frame->GetHeight(),
													 (int32_t)(((frame->GetWidth() + 47) / 48) * 128),
													 bmdFormat8BitYUV,
													 frame->GetFlags(),
													 &conversionFrame) != S_OK)
					return;
				
				if(self.frameConverter == nil)
				{
					self.frameConverter = CreateVideoConversionInstance();
				}
				
				if (((IDeckLinkVideoConversion*)self.frameConverter)->ConvertFrame(frame, conversionFrame) != S_OK)
					return;
				
				myFrame->Release();	// release the old frame.
				myFrame = (DeckLinkPixelBufferFrame*)conversionFrame;	// IMPORTANT: we can cast the pointer because we only need it in the following call ScheduleVideoFrame() which can handle different types of frames.
			}

			// deckLinkOutput->DisplayVideoFrameSync(frame);
			deckLinkOutput->ScheduleVideoFrame(myFrame, displayTime, frameDuration, timeScale);
			[(DeckLinkPlaybackTimingMonitor *)self.playbackTimingMonitor recordScheduledFrameEndTime:(double)(displayTime + frameDuration) / (double)timeScale];
			CFRelease(pixelBuffer);

		});
		
	});

}

- (void)scheduledFrameCompleted:(DeckLinkPixelBufferFrame *)frame result:(BMDOutputFrameCompletionResult)result
{
	frame->Release();

	DeckLinkDecrementFrameBufferCount(&_sampleBufferCount_BackingStore);

	[(DeckLinkPlaybackTimingMonitor *)self.playbackTimingMonitor recordCompletionWithResult:result];
}

- (void)stopScheduledPlaybackWithCompletionHandler:(DeckLinkDeviceStopPlaybackCompletionHandler)completionHandler
{
	dispatch_async(self.playbackQueue, ^{
		DeckLinkPlaybackTimingMonitor *playbackTimingMonitor = self.playbackTimingMonitor;
		self.playbackTimingMonitor = nil;
		[playbackTimingMonitor stop];

		deckLinkOutput->StopScheduledPlayback(0, NULL, 0);
		
		if(completionHandler){
			completionHandler(YES, nil);
		}
	});
}

- (void)playbackPixelBuffer:(CVPixelBufferRef)pixelBuffer {

	[self playbackPixelBuffer:pixelBuffer isFlipped:NO];
}

- (void)playbackPixelBuffer:(CVPixelBufferRef)pixelBuffer isFlipped:(BOOL)flipped
{
	atomic_fetch_add(&_sampleBufferCount_BackingStore, 1);

	CFRetain(pixelBuffer);
	dispatch_async(self.frameDownloadQueue, ^{
		// The first queue just downloads the frame from GPU to CPU RAM even if the playbackQueue is sending out data to the device.
		
		DeckLinkPixelBufferFrame *frame = new DeckLinkPixelBufferFrame(pixelBuffer);

		if (flipped) {
			
			frame->setFlags(bmdFrameFlagFlipVertical);
		}
		
		if(self.videoFramesRequiresFrameConvertion)
		{
			IDeckLinkMutableVideoFrame* conversionFrame;
			if (deckLinkOutput->CreateVideoFrame((int32_t)frame->GetWidth(),
												 (int32_t)frame->GetHeight(),
												 (int32_t)(((frame->GetWidth() + 47) / 48) * 128),
												 bmdFormat8BitYUV,
												 frame->GetFlags(),
												 &conversionFrame) != S_OK)
				return;
			
			if(self.frameConverter == nil)
			{
				self.frameConverter = CreateVideoConversionInstance();
			}
			
			if (((IDeckLinkVideoConversion*)self.frameConverter)->ConvertFrame(frame, conversionFrame) != S_OK)
				return;
			
			frame->Release();	// release the old frame.
			frame = (DeckLinkPixelBufferFrame*)conversionFrame;	// IMPORTANT: we can cast the pointer because we only need it in the following block to call DisplayVideoFrameSync() which can handle different types of frames.
		}
		
		dispatch_async(self.playbackQueue, ^{
			// the second queue is sending the image data to the device immediately but don't need to wait for next download
			
			deckLinkOutput->DisplayVideoFrameSync(frame);

			frame->Release();
			
			CFRelease(pixelBuffer);

			DeckLinkDecrementFrameBufferCount(&_sampleBufferCount_BackingStore);

		});

	});
}

- (void)playbackContinuousAudioBufferList:(AudioBufferList *)audioBufferList numberOfSamples:(UInt32)numberOfSamples completionHandler:(void(^)(void))completionHandler
{
	dispatch_async(self.playbackQueue, ^{
		uint32_t outNumberOfSamples = 0;
		deckLinkOutput->WriteAudioSamplesSync(audioBufferList->mBuffers[0].mData, numberOfSamples, &outNumberOfSamples);
		[(DeckLinkPlaybackTimingMonitor *)self.playbackTimingMonitor recordAudioSamplesWritten:outNumberOfSamples requested:numberOfSamples];

		if (numberOfSamples != outNumberOfSamples)
		{
			// NSLog(@"%s:%d:Dropped Audio Samples: %u != %u", __FUNCTION__, __LINE__, numberOfSamples, outNumberOfSamples);
		}
		
		if (completionHandler)
		{
			completionHandler();
		}
	});
}

- (void)schedulePlaybackOfAudioBufferList:(AudioBufferList *)audioBufferList numberOfSamples:(UInt32)numberOfSamples streamTime:(int64_t)streamTime timeScale:(int64_t)timeScale completionHandler:(void(^)(void))completionHandler
{
	dispatch_async(self.playbackQueue, ^{
		// Samples scheduled for a time the card has already played are discarded by the driver, so a stall can no
		// longer shift audio against video permanently, as it does in continuous mode.
		uint32_t outNumberOfSamples = 0;
		deckLinkOutput->ScheduleAudioSamples(audioBufferList->mBuffers[0].mData, numberOfSamples, streamTime, timeScale, &outNumberOfSamples);
		[(DeckLinkPlaybackTimingMonitor *)self.playbackTimingMonitor recordAudioSamplesWritten:outNumberOfSamples requested:numberOfSamples];

		if (numberOfSamples != outNumberOfSamples)
		{
			// NSLog(@"%s:%d:Dropped Audio Samples: %u != %u", __FUNCTION__, __LINE__, numberOfSamples, outNumberOfSamples);
		}

		if (completionHandler)
		{
			completionHandler();
		}
	});
}

- (NSUInteger)frameBufferCount
{
	return _sampleBufferCount_BackingStore;
}

@end
