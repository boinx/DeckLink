#import "DeckLinkDevice+Capture.h"

#import "CMFormatDescription+DeckLink.h"
#import "DeckLinkAPI.h"
#import "DeckLinkAudioConnection+Internal.h"
#import "DeckLinkDevice+Internal.h"
#import "DeckLinkDeviceInternalInputCallback.h"
#import "DeckLinkVideoConnection+Internal.h"


static void * const CaptureQueueIdentitiy = (void *)&CaptureQueueIdentitiy;

static inline void CaptureQueue_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
	if (dispatch_get_specific(CaptureQueueIdentitiy) == (__bridge void *)queue)
	{
		block();
	}
	else
	{
		dispatch_sync(queue, block);
	}
}


@implementation DeckLinkDevice (Capture)

- (void)setupCapture
{
	if(deckLink->QueryInterface(IID_IDeckLinkInput, (void **)&deckLinkInput) != S_OK)
	{
		return;
	}
	
	deckLinkInputCallback = new DeckLinkDeviceInternalInputCallback((id)self);
	if(deckLinkInput->SetCallback(deckLinkInputCallback) != S_OK)
	{
		deckLinkInput->Release();
		deckLinkInput = NULL;
		return;
	}
	
	self.captureSupported = YES;
	
	dispatch_queue_t captureQueue = dispatch_queue_create("DeckLinkDevice.captureQueue", DISPATCH_QUEUE_SERIAL);
	dispatch_queue_set_specific(captureQueue, CaptureQueueIdentitiy, (__bridge void *)captureQueue, NULL);
	self.captureQueue = captureQueue;
	
	// Video
	IDeckLinkDisplayModeIterator *displayModeIterator = NULL;
	if (deckLinkInput->GetDisplayModeIterator(&displayModeIterator) == S_OK)
	{
		BMDPixelFormat pixelFormats[] = {
			bmdFormat8BitARGB, // == kCVPixelFormatType_32ARGB == 32
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
				if (deckLinkInput->DoesSupportVideoMode(displayModeKey, pixelFormat, bmdVideoOutputFlagDefault, &support, NULL) == S_OK && support != bmdDisplayModeNotSupported)
				{
					CMVideoFormatDescriptionRef formatDescription = NULL;
					if(CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(displayMode, pixelFormat, support == bmdDisplayModeSupported, &formatDescription) == noErr)
					{
						[formatDescriptions addObject:(__bridge id)formatDescription];
						CFRelease(formatDescription);
					}
				}
			}
		}
		displayModeIterator->Release();
			
		self.captureVideoFormatDescriptions = formatDescriptions;
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
			
		self.captureAudioFormatDescriptions = formatDescriptions;
		// TODO: get active format description
	}
	
	{
		int64_t inputConnections = 0;
		deckLinkAttributes->GetInt(BMDDeckLinkVideoInputConnections, &inputConnections);
		self.captureVideoConnections = DeckLinkVideoConnectionsFromBMDVideoConnection((BMDVideoConnection)inputConnections);

		int64_t activeInputConnection = 0;
		deckLinkConfiguration->GetInt(bmdDeckLinkConfigVideoInputConnection, &activeInputConnection);
		self.captureActiveVideoConnection = DeckLinkVideoConnectionFromBMDVideoConnection((BMDVideoConnection)activeInputConnection);
	}
	
	{
		int64_t inputConnections = 0;
		deckLinkAttributes->GetInt(BMDDeckLinkAudioInputConnections, &inputConnections);
		self.captureAudioConnections = DeckLinkAudioConnectionsFromBMDAudioConnection((BMDAudioConnection)inputConnections);
		
		int64_t activeInputConnection = 0;
		deckLinkConfiguration->GetInt(bmdDeckLinkConfigAudioInputConnection, &activeInputConnection);
		self.captureActiveAudioConnection = DeckLinkAudioConnectionFromBMDAudioConnection((BMDAudioConnection)activeInputConnection);
	}
}

- (BOOL)setCaptureActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)formatDescription error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		if (formatDescription != NULL)
		{
			if (![self.captureVideoFormatDescriptions containsObject:(__bridge id)formatDescription])
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
			
			BMDPixelFormat pixelFormat = CMVideoFormatDescriptionGetCodecType(formatDescription);
			
			bool supportsInputFormatDetection = false;
			deckLinkAttributes->GetFlag(BMDDeckLinkSupportsInputFormatDetection, &supportsInputFormatDetection);
			
			BMDVideoInputFlags flags = bmdVideoInputFlagDefault;
			if (supportsInputFormatDetection)
			{
				flags |= bmdVideoInputEnableFormatDetection;
			}
			
			deckLinkInput->PauseStreams();
			HRESULT status = deckLinkInput->EnableVideoInput(displayMode, pixelFormat, flags);
			if (status != S_OK)
			{
				deckLinkInput->PauseStreams();
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
			deckLinkInput->PauseStreams();
		}
		else
		{
			deckLinkInput->PauseStreams();
			HRESULT status = deckLinkInput->DisableVideoInput();
			if (status != S_OK)
			{
				deckLinkInput->PauseStreams();
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
			deckLinkInput->PauseStreams();
		}
		
		self.captureActiveVideoFormatDescription = formatDescription;
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

- (BOOL)setCaptureActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)formatDescription error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		if (formatDescription != NULL)
		{
			if (![self.captureAudioFormatDescriptions containsObject:(__bridge id)formatDescription])
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				return;
			}
			
			const AudioStreamBasicDescription *basicStreamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
			
			const BMDAudioSampleRate sampleRate = basicStreamDescription->mSampleRate;;
			const BMDAudioSampleType sampleType = basicStreamDescription->mBitsPerChannel;
			const uint32_t channels = basicStreamDescription->mChannelsPerFrame;
			
			deckLinkInput->PauseStreams();
			HRESULT status = deckLinkInput->EnableAudioInput(sampleRate, sampleType, channels);
			if (status != S_OK)
			{
				deckLinkInput->PauseStreams();
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
			deckLinkInput->PauseStreams();
		}
		else
		{
			deckLinkInput->PauseStreams();
			HRESULT status = deckLinkInput->DisableAudioInput();
			if (status != S_OK)
			{
				deckLinkInput->PauseStreams();
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
			deckLinkInput->PauseStreams();
		}
		
		self.captureActiveAudioFormatDescription = formatDescription;
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

- (BOOL)setCaptureActiveVideoConnection:(NSString *)connection error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;

	dispatch_queue_t captureQueue = self.captureQueue;
	if (captureQueue == nil)
	{
		error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
	}
	else
	{
		CaptureQueue_dispatch_sync(captureQueue, ^{
			BMDVideoConnection videoConnection = DeckLinkVideoConnectionToBMDVideoConnection(connection);
			if (videoConnection == 0)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				return;
			}
		
			HRESULT status = deckLinkConfiguration->SetInt(bmdDeckLinkConfigVideoInputConnection, videoConnection);
			if (status != S_OK)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
		
			self.captureActiveVideoConnection = connection;
			result = YES;
		});
	}
	
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

- (BOOL)setCaptureActiveAudioConnection:(NSString *)connection error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;

	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		BMDAudioConnection audioConnection = DeckLinkAudioConnectionToBMDAudioConnection(connection);
		if (audioConnection == 0)
		{
			error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
			return;
		}
		
		HRESULT status = deckLinkConfiguration->SetInt(bmdDeckLinkConfigAudioInputConnection, audioConnection);
		if (status != S_OK)
		{
			error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
			return;
		}
		
		self.captureActiveAudioConnection = connection;
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

- (void)setCaptureVideoDelegate:(id<DeckLinkDeviceCaptureVideoDelegate>)delegate queue:(dispatch_queue_t)queue
{
	if(delegate != nil && queue == nil)
	{
		queue = dispatch_get_main_queue();
	}
	
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		self.captureVideoDelegate = delegate;
		self.captureVideoDelegateQueue = queue;
	});
}

- (void)setCaptureAudioDelegate:(id<DeckLinkDeviceCaptureAudioDelegate>)delegate queue:(dispatch_queue_t)queue
{
	if(delegate != nil && queue == nil)
	{
		queue = dispatch_get_main_queue();
	}
	
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		self.captureAudioDelegate = delegate;
		self.captureAudioDelegateQueue = queue;
	});
}

- (BOOL)startCaptureWithError:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		if (self.captureActive)
		{
			result = YES;
			return;
		}

		HRESULT status = deckLinkInput->StartStreams();
		if (status != S_OK)
		{
			error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
			return;
		}

		self.captureInputSourceConnected = YES; // We assume an input source is connected when start capturing
		self.captureActive = YES;
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

- (void)stopCapture
{
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		if (!self.captureActive)
		{
			return;
		}
		
		deckLinkInput->StopStreams();
		
		self.captureActive = NO;
		self.captureInputSourceConnected = NO;
	});
}

#pragma mark - DeckLinkDeviceInternalInputCallbackDelegate

static void videoFrameReleaseCallback(void *context, const void *memory)
{
	IDeckLinkVideoInputFrame *videoFrame = (IDeckLinkVideoInputFrame *)context;
	videoFrame->Release();
}

static void audioPacketReleaseCallback(void *context, void *memory, size_t sizeInBytes)
{
	IDeckLinkAudioInputPacket *audioPacket = (IDeckLinkAudioInputPacket *)context;
	audioPacket->Release();
}

- (void)didReceiveVideoFrame:(IDeckLinkVideoInputFrame *)videoFrame audioPacket:(IDeckLinkAudioInputPacket *)audioPacket
{
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		if(videoFrame != NULL)
		{
			CMVideoFormatDescriptionRef videoFormatDescription = self.captureActiveVideoFormatDescription;
			
			CMTime frameRate = CMTimeMake(0, 60000);
			CMVideoFormatDescriptionGetDeckLinkFrameRate(videoFormatDescription, &frameRate);
			
			BMDTimeScale frameScale = frameRate.timescale;
			BMDTimeValue frameTime = 0;
			BMDTimeValue frameDuration = 0;
			videoFrame->GetStreamTime(&frameTime, &frameDuration, frameRate.timescale);
			
#if 0
			// TODO: become kCMIOSampleBufferAttachmentKey_HostTime?
			BMDTimeValue hardwareTime = 0;
			BMDTimeValue hardwareDuration = 0;
			videoFrame->GetHardwareReferenceTimestamp(NSEC_PER_SEC, &hardwareTime, &hardwareDuration);
#endif
	
			CMPixelFormatType pixelFormat = videoFrame->GetPixelFormat();
			long width = videoFrame->GetWidth();
			long height = videoFrame->GetHeight();
			long bytesPerRow = videoFrame->GetRowBytes();
			
			BMDFrameFlags flags = videoFrame->GetFlags();
			
			BOOL captureInputSourceConnected = (flags & bmdFrameHasNoInputSource) != 0;
			if (self.captureInputSourceConnected != captureInputSourceConnected)
			{
				self.captureInputSourceConnected = captureInputSourceConnected;
			}
			
			void *baseAddress = NULL;
			videoFrame->GetBytes(&baseAddress);
			
			NSDictionary *pixelBufferAttributes = @{
				(__bridge NSString *)kCVPixelBufferOpenGLCompatibilityKey: @YES,
				(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{
					(__bridge NSString *)kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey: @YES,
				},
			};
			
			CVPixelBufferRef pixelBuffer = NULL;
			const CVReturn pixelBufferStatus = CVPixelBufferCreateWithBytes(NULL, width, height, pixelFormat, baseAddress, bytesPerRow, videoFrameReleaseCallback, videoFrame, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);
			if (pixelBufferStatus != kCVReturnSuccess)
			{
				return;
			}

			videoFrame->AddRef(); // videoFrame will be released by videoFrameReleaseCallback

			CMVideoFormatDescriptionRef formatDescription = NULL;
			CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDescription);
			
			CMSampleTimingInfo timingInfo = {
				CMTimeMake(frameDuration, (CMTimeScale)frameScale),
				CMTimeMake(frameTime, (CMTimeScale)frameScale),
				kCMTimeInvalid
			};
			
			CMSampleBufferRef sampleBuffer = NULL;
			OSStatus status = CMSampleBufferCreateForImageBuffer(NULL, pixelBuffer, YES, NULL, NULL, formatDescription, &timingInfo, &sampleBuffer);
			if(status == noErr)
			{
				id<DeckLinkDeviceCaptureVideoDelegate> delegate = self.captureVideoDelegate;
				dispatch_queue_t queue = self.captureVideoDelegateQueue;
				if(delegate != nil && queue != nil)
				{
					dispatch_async(queue, ^{
						if([delegate respondsToSelector:@selector(DeckLinkDevice:didCaptureVideoSampleBuffer:)])
						{
							[delegate DeckLinkDevice:self didCaptureVideoSampleBuffer:sampleBuffer];
						}
						CFRelease(sampleBuffer);
					});
				}
				else
				{
					CFRelease(sampleBuffer);
				}
			}
			
			CVPixelBufferRelease(pixelBuffer);
			CFRelease(formatDescription);
		}
		else
		{
			// TODO: is this assumption right?
			id<DeckLinkDeviceCaptureVideoDelegate> delegate = self.captureVideoDelegate;
			dispatch_queue_t queue = self.captureVideoDelegateQueue;
			if(delegate != nil && queue != nil)
			{
				dispatch_async(queue, ^{
					if([delegate respondsToSelector:@selector(DeckLinkDevice:didDropVideoSampleBuffer:)])
					{
						[delegate DeckLinkDevice:self didDropVideoSampleBuffer:NULL];
					}
				});
			}
		}
		
		if(audioPacket != NULL)
		{
			long frameCount = audioPacket->GetSampleFrameCount();
			
			CMAudioFormatDescriptionRef formatDescription = self.captureActiveAudioFormatDescription;
			
			const AudioStreamBasicDescription *basicStreamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
			
			BMDTimeValue packetTime = 0;
			audioPacket->GetPacketTime(&packetTime, basicStreamDescription->mSampleRate);
			
			CMSampleTimingInfo timingInfo = {
				CMTimeMake(1, basicStreamDescription->mSampleRate),
				CMTimeMake(packetTime, basicStreamDescription->mSampleRate),
				kCMTimeInvalid
			};
			const size_t frameSize = basicStreamDescription->mBytesPerFrame;
			
			void *audioSamples = NULL;
			audioPacket->GetBytes(&audioSamples);
			
			CMBlockBufferCustomBlockSource customBlockSource = {
				kCMBlockBufferCustomBlockSourceVersion,
				NULL,
				audioPacketReleaseCallback,
				audioPacket,
			};
			
			CMBlockBufferRef dataBuffer = NULL;
			const CVReturn dataBufferStatus = CMBlockBufferCreateWithMemoryBlock(NULL, audioSamples, frameCount * basicStreamDescription->mBytesPerFrame, NULL, &customBlockSource, 0, frameCount * frameSize, kCMBlockBufferAssureMemoryNowFlag, &dataBuffer);
			if (dataBufferStatus != kCVReturnSuccess)
			{
				return;
			}
			
			audioPacket->AddRef(); // audioPacket will be released by audioPacketReleaseCallback
			
			CMSampleBufferRef sampleBuffer = NULL;
			OSStatus status = CMSampleBufferCreate(NULL, dataBuffer, YES, NULL, NULL, formatDescription, frameCount, 1, &timingInfo, 1, &frameSize, &sampleBuffer);
			if(status == noErr)
			{
				id<DeckLinkDeviceCaptureAudioDelegate> delegate = self.captureAudioDelegate;
				dispatch_queue_t queue = self.captureAudioDelegateQueue;
				if(delegate != nil && queue != nil)
				{
					dispatch_async(queue, ^{
						if([delegate respondsToSelector:@selector(DeckLinkDevice:didCaptureAudioSampleBuffer:)])
						{
							[delegate DeckLinkDevice:self didCaptureAudioSampleBuffer:sampleBuffer];
						}
						CFRelease(sampleBuffer);
					});
				}
				else
				{
					CFRelease(sampleBuffer);
				}
			}
			
			CFRelease(dataBuffer);
		}
	});
}

- (void)didChangeVideoFormat:(BMDVideoInputFormatChangedEvents)changes displayMode:(IDeckLinkDisplayMode *)displayMode flags:(BMDDetectedVideoInputFormatFlags)flags
{
	CaptureQueue_dispatch_sync(self.captureQueue, ^{
		BMDDisplayMode displayModeValue = displayMode->GetDisplayMode();
		BMDDisplayMode pixelFormat = 0;
		if (flags & bmdDetectedVideoInputYCbCr422)
		{
			pixelFormat = bmdFormat8BitYUV;
		}
		else if (flags & bmdDetectedVideoInputRGB444)
		{
			pixelFormat = bmdFormat8BitARGB;
		}
		
		for (id captureVideoFormatDescription_ in self.captureVideoFormatDescriptions)
		{
			CMVideoFormatDescriptionRef captureVideoFormatDescription = (__bridge CMVideoFormatDescriptionRef)captureVideoFormatDescription_;
			
			NSNumber *displayMode2 = (__bridge NSNumber *)CMFormatDescriptionGetExtension(captureVideoFormatDescription, DeckLinkFormatDescriptionDisplayModeKey);
			
			if (displayModeValue == displayMode2.intValue && pixelFormat == CMVideoFormatDescriptionGetCodecType(captureVideoFormatDescription))
			{
				NSError *error = nil;
				if ([self setCaptureActiveVideoFormatDescription:captureVideoFormatDescription error:&error])
				{
					id<DeckLinkDeviceCaptureVideoDelegate> delegate = self.captureVideoDelegate;
					dispatch_queue_t queue = self.captureVideoDelegateQueue;
					if(delegate != nil && queue != nil)
					{
						dispatch_async(queue, ^{
							if([delegate respondsToSelector:@selector(DeckLinkDevice:didChangeActiveVideoFormatDescription:)])
							{
								[delegate DeckLinkDevice:self didChangeActiveVideoFormatDescription:captureVideoFormatDescription];
							}
						});
					}
				}
				break;
			}
		}
	});
}

@end
