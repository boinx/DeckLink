#import "DeckLinkDevice+Playback.h"

#import "CMFormatDescription+DeckLink.h"
#import "DeckLinkAPI.h"
#import "DeckLinkAudioConnection+Internal.h"
#import "DeckLinkDevice+Internal.h"
#import "DeckLinkKeying.h"
#import "DeckLinkPixelBufferFrame.h"
#import "DeckLinkVideoConnection+Internal.h"


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
				
				BMDDisplayModeSupport support = bmdDisplayModeNotSupported;
				if (deckLinkOutput->DoesSupportVideoMode(displayModeKey, pixelFormat, bmdVideoOutputFlagDefault, &support, NULL) == S_OK && support != bmdDisplayModeNotSupported)
				{
					CMVideoFormatDescriptionRef formatDescription = NULL;
					if(CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(displayMode, pixelFormat, support == bmdDisplayModeSupported, &formatDescription) == noErr)
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
		
		bool supportsHDKeying = false;
		deckLinkAttributes->GetFlag(BMDDeckLinkSupportsHDKeying, &supportsHDKeying);
		if (supportsHDKeying)
		{
			// Nobody cares for non HD-keying anymore
			
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

			HRESULT status = deckLinkOutput->EnableAudioOutput(sampleRate, sampleType, channels, bmdAudioOutputStreamContinuous);
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
		atomic_store(&_sampleBufferCount_BackingStore, 0);
		deckLinkOutput->StartScheduledPlayback(startTime, timeScale, 1.0);
		deckLinkOutputCallback = new DeckLinkDeviceInternalOutputCallback((id<DeckLinkDeviceInternalOutputCallbackDelegate>)self);
		deckLinkOutput->SetScheduledFrameCompletionCallback(deckLinkOutputCallback);
	});
}

- (void)schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer displayTime:(NSUInteger)displayTime frameDuration:(NSUInteger)frameDuration timeScale:(NSUInteger)timeScale
{
	atomic_fetch_add(&_sampleBufferCount_BackingStore, 1);
	
	CFRetain(pixelBuffer);
	dispatch_async(self.frameDownloadQueue, ^{
		// The first queue just downloads the frame from GPU to CPU RAM even if the playbackQueue is sending out data to the device.
		
		DeckLinkPixelBufferFrame *frame = new DeckLinkPixelBufferFrame(pixelBuffer);
		// IDeckLinkVideoConversion
		
		dispatch_async(self.playbackQueue, ^{
			// the second queue is sending the image data to the device immediately but don't need to wait for next download
			
			// deckLinkOutput->DisplayVideoFrameSync(frame);
			deckLinkOutput->ScheduleVideoFrame(frame, displayTime, frameDuration, timeScale);
			CFRelease(pixelBuffer);

		});
		
	});

}

- (void)scheduledFrameCompleted:(DeckLinkPixelBufferFrame *)frame result:(BMDOutputFrameCompletionResult)result
{
	frame->Release();
	
	atomic_fetch_add(&_sampleBufferCount_BackingStore, -1);
}

- (void)stopScheduledPlaybackWithCompletionHandler:(DeckLinkDeviceStopPlaybackCompletionHandler)completionHandler
{
	dispatch_async(self.playbackQueue, ^{
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
		
		dispatch_async(self.playbackQueue, ^{
			// the second queue is sending the image data to the device immediately but don't need to wait for next download
			
			deckLinkOutput->DisplayVideoFrameSync(frame);

			frame->Release();
			
			CFRelease(pixelBuffer);

			atomic_fetch_add(&_sampleBufferCount_BackingStore, -1);

		});

	});
}

- (void)playbackContinuousAudioBufferList:(AudioBufferList *)audioBufferList numberOfSamples:(UInt32)numberOfSamples completionHandler:(void(^)(void))completionHandler
{
	dispatch_async(self.playbackQueue, ^{
		uint32_t outNumberOfSamples = 0;
		deckLinkOutput->WriteAudioSamplesSync(audioBufferList->mBuffers[0].mData, numberOfSamples, &outNumberOfSamples);
		
		if (numberOfSamples != outNumberOfSamples)
		{
			NSLog(@"%s:%d:Dropped Audio Samples: %u != %u", __FUNCTION__, __LINE__, numberOfSamples, outNumberOfSamples);
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
