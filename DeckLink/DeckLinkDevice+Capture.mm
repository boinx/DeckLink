#import "DeckLinkDevice+Capture.h"

#import "CMFormatDescription+DeckLink.h"
#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Internal.h"


@implementation DeckLinkDevice (Capture)

- (void)setupCapture
{
	if(deckLink->QueryInterface(IID_IDeckLinkInput, (void **)&deckLinkInput) != S_OK)
	{
		return;
	}
	
	self.captureSupported = YES;
		
	self.captureQueue = dispatch_queue_create("BDDLDevice.captureQueue", DISPATCH_QUEUE_SERIAL);
	
#if 0
	inputCallback = new BDDLDeviceInternalInputCallback((id)self);
	if(deckLinkInput->SetCallback(inputCallback) != S_OK)
	{
		// TODO: error handling
		return;
	}
#endif
	
	IDeckLinkDisplayModeIterator *displayModeIterator = NULL;
	if (deckLinkInput->GetDisplayModeIterator(&displayModeIterator) == S_OK)
	{
		// Video
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
	}
}

- (BOOL)setCaptureActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)captureActiveVideoFormatDescription error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	dispatch_sync(self.captureQueue, ^{
		if (captureActiveVideoFormatDescription != NULL)
		{
			if (![self.captureVideoFormatDescriptions containsObject:(__bridge id)captureActiveVideoFormatDescription])
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				return;
			}
			
			NSNumber *displayModeValue = (__bridge NSNumber *)CMFormatDescriptionGetExtension(captureActiveVideoFormatDescription, DeckLinkFormatDescriptionDisplayModeKey);
			if (![displayModeValue isKindOfClass:NSNumber.class])
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:kCMFormatDescriptionError_ValueNotAvailable userInfo:nil];
				return;
			}
			
			BMDDisplayMode displayMode = displayModeValue.intValue;
			
			BMDPixelFormat pixelFormat = CMVideoFormatDescriptionGetCodecType(captureActiveVideoFormatDescription);
			
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
		
		self.captureActiveVideoFormatDescription = captureActiveVideoFormatDescription;
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

- (BOOL)setCaptureActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)captureActiveAudioFormatDescription error:(NSError **)error
{
	__block BOOL result = NO;
	
	dispatch_sync(self.captureQueue, ^{

	});
	
	return result;
}

- (void)setCaptureVideoDelegate:(id<DeckLinkDeviceCaptureVideoDelegate>)delegate queue:(dispatch_queue_t)queue
{
	if(delegate != nil && queue == nil)
	{
		queue = dispatch_get_main_queue();
	}
	
	dispatch_sync(self.captureQueue, ^{
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
	
	dispatch_sync(self.captureQueue, ^{
		self.captureAudioDelegate = delegate;
		self.captureAudioDelegateQueue = queue;
	});
}

- (BOOL)startCaptureWithError:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	dispatch_sync(self.captureQueue, ^{
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
	dispatch_sync(self.captureQueue, ^{
		if (!self.captureActive)
		{
			return;
		}
		
		deckLinkInput->StopStreams();
		
		self.captureActive = NO;
	});
}

@end
