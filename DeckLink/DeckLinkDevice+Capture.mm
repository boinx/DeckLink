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
		int64_t activeDisplayMode = 0;
		deckLinkConfiguration->GetInt(bmdDeckLinkConfigDefaultVideoOutputMode, &activeDisplayMode);
			
		BMDPixelFormat pixelFormats[] = {
			//					bmdFormat8BitARGB, // == kCVPixelFormatType_32ARGB == 32
			bmdFormat8BitYUV, // == kCVPixelFormatType_422YpCbCr8 == '2vuy'
		};
			
		NSMutableArray *formatDescriptions = [NSMutableArray array];
			
		CMVideoFormatDescriptionRef activeFormatDescription = NULL;
			
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
					if(CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(displayMode, pixelFormat, &formatDescription) == noErr)
					{
						[formatDescriptions addObject:(__bridge id)formatDescription];
						CFRelease(formatDescription);
					}
				}
			}
		}
		displayModeIterator->Release();
			
		if (activeFormatDescription == NULL)
		{
			activeFormatDescription = (__bridge CMVideoFormatDescriptionRef)formatDescriptions.firstObject;
		}
			
		self.captureVideoFormatDescriptions = formatDescriptions;
		self.captureActiveVideoFormatDescription = activeFormatDescription;
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
			
//			deckLinkInput->EnableVideoInput(<#BMDDisplayMode displayMode#>, <#BMDPixelFormat pixelFormat#>, <#BMDVideoInputFlags flags#>)
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
	
}

- (void)setCaptureAudioDelegate:(id<DeckLinkDeviceCaptureAudioDelegate>)delegate queue:(dispatch_queue_t)queue
{
	
}

- (BOOL)startCaptureWithError:(NSError **)error
{
	return NO;
}

- (void)stopCapture
{
	
}

@end
