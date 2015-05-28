#import "DeckLinkDevice+Playback.h"

#import "CMFormatDescription+DeckLink.h"
#import "DeckLinkAPI.h"
#import "DeckLinkAudioConnection+Internal.h"
#import "DeckLinkDevice+Internal.h"
#import "DeckLinkKeying.h"
#import "DeckLinkVideoConnection+Internal.h"


@implementation DeckLinkDevice (Playback)

- (void)setupPlayback
{
	if(deckLink->QueryInterface(IID_IDeckLinkOutput, (void **)&deckLinkOutput) != S_OK)
	{
		return;
	}
	
#if 0
	deckLinkOutputCallback = new DeckLinkDeviceInternalOutputCallback((id)self);
	if(deckLinkOutput->SetCallback(deckLinkOutputCallback) != S_OK)
	{
		deckLinkOutput->Release();
		deckLinkOutput = NULL;
		return;
	}
#endif
	
	self.playbackSupported = YES;
	
	self.playbackQueue = dispatch_queue_create("DeckLinkDevice.playbackQueue", DISPATCH_QUEUE_SERIAL);
	
	if (deckLinkKeyer != NULL)
	{
		
	}
	else
	{
		self.playbackKeyingModes = @[ DeckLinkKeyingModeNone ];
	}
	
#if 0
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
#endif
}

- (BOOL)setPlaybackActiveKeyingMode:(NSString *)keyingMode alpha:(float)alpha error:(NSError **)outError
{
	__block BOOL result = NO;
	__block NSError *error = nil;
	
	dispatch_sync(self.playbackQueue, ^{
		if (deckLinkKeyer != NULL)
		{
			HRESULT status = 0;
			
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
			
			if (status != S_OK)
			{
				error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
				return;
			}
			
			deckLinkKeyer->SetLevel(alpha * 255.0);
		}
		else
		{
			if (![keyingMode isEqualToString:DeckLinkKeyingModeNone])
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

@end
