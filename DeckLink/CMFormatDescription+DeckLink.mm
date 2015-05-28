#import "CMFormatDescription+DeckLink.h"

#import <Foundation/Foundation.h>
#import "DeckLinkAPI.h"


CFStringRef const DeckLinkFormatDescriptionDisplayModeKey = CFSTR("com.blackmagicdesign.DeckLinkDisplayMode");

CFStringRef const DeckLinkFormatDescriptionFrameRateKey = CFSTR("com.blackmagicdesign.DeckLinkFrameRate");

//CFStringRef const DeckLinkFormatDescriptionNativeDisplayModeSupportKey = CFSTR("com.blackmagicdesign.DeckLinkNativeDisplayModeSupport");


OSStatus CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(IDeckLinkDisplayMode *displayMode, CMVideoCodecType pixelFormat, CMVideoFormatDescriptionRef *outFormatDescription)
{
	if (displayMode == NULL)
	{
		return paramErr;
	}
	
	if (outFormatDescription == NULL)
	{
		return paramErr;
	}
	
	NSMutableDictionary *extensions = [NSMutableDictionary dictionary];
	
	const BMDDisplayMode displayModeKey = displayMode->GetDisplayMode();
	extensions[(__bridge NSString *)DeckLinkFormatDescriptionDisplayModeKey] = @(displayModeKey);
	
	{
		CFStringRef nameCF = NULL;
		if(displayMode->GetName(&nameCF) == S_OK)
		{
			NSString * const name = CFBridgingRelease(nameCF);
			if(name != nil)
			{
				extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FormatName] = name;
			}
		}
	}
	
	{
		BMDTimeValue frameRateValue = 0;
		BMDTimeScale frameRateScale = 0;
		if(displayMode->GetFrameRate(&frameRateValue, &frameRateScale) == S_OK)
		{
			CMTime frameRate = CMTimeMake(frameRateValue, (int32_t)frameRateScale);
			NSDictionary *frameRateDictionary = CFBridgingRelease(CMTimeCopyAsDictionary(frameRate, NULL));
			if(frameRateDictionary != nil)
			{
				extensions[(__bridge NSString *)DeckLinkFormatDescriptionFrameRateKey] = frameRateDictionary;
			}
		}
	}
	
	{
		BMDFieldDominance fieldDominance = displayMode->GetFieldDominance();
		switch (fieldDominance)
		{
			case bmdLowerFieldFirst:
			{
				extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldCount] = @2;
				extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldDetail] = (__bridge NSString *)kCMFormatDescriptionFieldDetail_TemporalBottomFirst;
				break;
			}
			case bmdUpperFieldFirst:
			{
				extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldCount] = @2;
				extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldDetail] = (__bridge NSString *)kCMFormatDescriptionFieldDetail_TemporalTopFirst;
				break;
			}
				
			case bmdProgressiveFrame:
			{
				extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldCount] = @1;
				break;
			}
				
			case bmdProgressiveSegmentedFrame:
			{
				// TODO: is this correct?
				//extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldCount] = @2;
				//extensions[(__bridge NSString *)kCMFormatDescriptionExtension_FieldDetail] = (__bridge NSString *)kCMFormatDescriptionFieldDetail_SpatialFirstLineEarly;
				break;
			}
		}
	}
	
	const int32_t width = (int32_t)displayMode->GetWidth();
	const int32_t height = (int32_t)displayMode->GetHeight();
	
	return CMVideoFormatDescriptionCreate(NULL, (CMVideoCodecType)pixelFormat, width, height, (__bridge CFDictionaryRef)extensions, outFormatDescription);
}

OSStatus CMVideoFormatDescriptionGetDeckLinkFrameRate(CMFormatDescriptionRef formatDescription, CMTime *outFrameRate)
{
	if (formatDescription == NULL)
	{
		return paramErr;
	}
	
	if (outFrameRate == NULL)
	{
		return paramErr;
	}
	
	CFDictionaryRef frameRateValue = (CFDictionaryRef)CMFormatDescriptionGetExtension(formatDescription, DeckLinkFormatDescriptionFrameRateKey);
	if (frameRateValue == NULL)
	{
		return kCMFormatDescriptionError_ValueNotAvailable;
	}
	
	CMTime frameRate = CMTimeMakeFromDictionary(frameRateValue);
	if (CMTIME_IS_INVALID(frameRate))
	{
		return kCMFormatDescriptionError_ValueNotAvailable;
	}
	
	*outFrameRate = frameRate;
	return noErr;
}
