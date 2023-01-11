#import "DeckLinkDevice+Status.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Internal.h"


@implementation DeckLinkDevice (Status)

static NSDictionary* displayModeDictionary =
@{
	@(bmdModeNTSC) : @"525i59.94 NTSC",
	@(bmdModeNTSC2398) : @"525i47.96 NTSC",
	@(bmdModePAL) : @"625i50 PAL",
	@(bmdModeNTSCp) : @"525p29.97 NTSC",
	@(bmdModePALp) : @"625p25 PAL",

	@(bmdModeHD1080p2398) : @"1080p23.98",
	@(bmdModeHD1080p24) : @"1080p24",
	@(bmdModeHD1080p25) : @"1080p25",
	@(bmdModeHD1080p2997) : @"1080p29.97",
	@(bmdModeHD1080p30) : @"1080p30",
	@(bmdModeHD1080i50) : @"1080i50",
	@(bmdModeHD1080i5994) : @"1080i59.94",
	@(bmdModeHD1080i6000) : @"1080i60",
	@(bmdModeHD1080p50) : @"1080p50",
	@(bmdModeHD1080p5994) : @"1080p59.94",
	@(bmdModeHD1080p6000) : @"1080p60",

	@(bmdModeHD720p50) : @"720p50",
	@(bmdModeHD720p5994) : @"720p59.94",
	@(bmdModeHD720p60) : @"720p60",

	@(bmdMode2k2398) : @"2K 23.98p",
	@(bmdMode2k24) : @"2K 24p",
	@(bmdMode2k2398) : @"2K 25p",

	@(bmdMode2kDCI2398) : @"2K DCI 23.98p",
	@(bmdMode2kDCI24) : @"2K DCI 24p",
	@(bmdMode2kDCI25) : @"2K DCI 25p",

	@(bmdMode4K2160p2398) : @"2160p23.98",
	@(bmdMode4K2160p24) : @"2160p24",
	@(bmdMode4K2160p25) : @"2160p25",
	@(bmdMode4K2160p2997) : @"2160p29.97",
	@(bmdMode4K2160p30) : @"2160p30",
	@(bmdMode4K2160p50) : @"2160p50",
	@(bmdMode4K2160p5994) : @"2160p59.94",
	@(bmdMode4K2160p60) : @"2160p60",

	@(bmdMode4kDCI2398) : @"4K DCI 23.98p",
	@(bmdMode4kDCI24) : @"4K DCI 24p",
	@(bmdMode4kDCI25) : @"4K DCI 25p",
	
	@(0) : @"unknown",
	@(bmdModeUnknown) : @"unknown"
};

static NSDictionary* pixelFormatDictionary =
@{
	@(bmdFormat8BitYUV) : @"8-bit YUV",
	@(bmdFormat10BitYUV) : @"10-bit YUV",
	@(bmdFormat8BitARGB) : @"8-bit ARGB",
	@(bmdFormat8BitBGRA) : @"8-bit BGRA",
	@(bmdFormat10BitRGB) : @"10-bit RGB",
	@(bmdFormat12BitRGB) : @"12-bit RGB",
	@(bmdFormat12BitRGBLE) : @"12-bit RGBLE",
	@(bmdFormat10BitRGBXLE) : @"12-bit RGBXLE",
	@(bmdFormat10BitRGBX) : @"10-bit RGBX",
	@(bmdFormatH265) : @"H.265",
	
	@(0) : @"unknown",
	@(bmdModeUnknown) : @"unknown"
};

static NSDictionary* duplexModeDictionary =
@{
	@(bmdDuplexFull) : @"full-duplex",
	@(bmdDuplexHalf) : @"half-duplex",
	@(bmdDuplexSimplex) : @"simplex",
	@(bmdDuplexInactive) : @"inactive",
	
	@(0) : @"unknown",
	@(bmdModeUnknown) : @"unknown"
};

+ (NSString *) stringFromFourCC: (OSType) cccc
{
	cccc = EndianU32_NtoB(cccc); // convert to network byte order if needed
	return [[NSString alloc] initWithBytes: &cccc length: sizeof(cccc) encoding: NSMacOSRomanStringEncoding]; // lossless 8-bit encoding
}

+ (NSString*)translate:(uint32_t)fourCharValue withDictionary:(NSDictionary*)dictionary
{
	NSString *translatedString = dictionary[@(fourCharValue)];
	
	if(translatedString == nil)
	{
		return [NSString stringWithFormat:@"Unknown Value (%i, %@)", fourCharValue, [DeckLinkDevice stringFromFourCC:fourCharValue]];
	}
	
	return translatedString;
}

-(NSDictionary*)getStatus:(BMDDeckLinkStatusID)statusID
{
	
	NSString* label;
	BOOL isIntValue = NO;
	BOOL isFlagsValue = NO;
	BOOL isBoolValue = NO;
	BOOL isByteValue = NO;
	NSDictionary *translationDictionary;
	NSString *stringValue;
	
	switch (statusID)
	{
			
		case bmdDeckLinkStatusDetectedVideoInputMode:
			label = @"Detected Video Input Mode";
			isIntValue = YES;
			translationDictionary = displayModeDictionary;
			break;

		case bmdDeckLinkStatusDetectedVideoInputFlags:
			label = @"Detected Video Input Flags";
			isFlagsValue = YES;
			break;

		case bmdDeckLinkStatusCurrentVideoInputMode:
			label = @"Current Video Input Mode";
			isIntValue = YES;
			translationDictionary = displayModeDictionary;
			break;

		case bmdDeckLinkStatusCurrentVideoInputFlags:
			label = @"Current Video Input Flags";
			isFlagsValue = YES;
			break;

		case bmdDeckLinkStatusCurrentVideoInputPixelFormat:
			label = @"Current Video Input Pixel Format";
			isIntValue = YES;
			translationDictionary = pixelFormatDictionary;
			break;

		case bmdDeckLinkStatusCurrentVideoOutputMode:
			label = @"Current Video Output Mode";
			isIntValue = YES;
			translationDictionary = displayModeDictionary;
			break;

		case bmdDeckLinkStatusCurrentVideoOutputFlags:
			label = @"Current Video Output Flags";
			isFlagsValue = YES;
			break;

		case bmdDeckLinkStatusPCIExpressLinkWidth:
			label = @"PCIe Link Width";
			isIntValue = YES;
			break;

		case bmdDeckLinkStatusPCIExpressLinkSpeed:
			label = @"PCIe Link Speed";
			isIntValue = YES;
			break;

		case bmdDeckLinkStatusLastVideoOutputPixelFormat:
			label = @"Last Video Output Pixel Format";
			isIntValue = YES;
			translationDictionary = pixelFormatDictionary;
			break;

		case bmdDeckLinkStatusReferenceSignalMode:
			label = @"Reference Signal Mode";
			isIntValue = YES;
			translationDictionary = displayModeDictionary;
			break;

		case bmdDeckLinkStatusReferenceSignalFlags:
			label = @"Reference Signal Flags";
			isFlagsValue = YES;
			break;

//		case bmdDeckLinkDuplexMode:
//			label = @"Duplex Mode";
//			isIntValue = YES;
//			dictionary = duplexModeDictionary;
//			break;

		case bmdDeckLinkStatusBusy:
			label = @"Busy";
			isIntValue = YES;
			break;

		case bmdDeckLinkStatusInterchangeablePanelType:
			label = @"Interchangeable Panel Type";
			isIntValue = YES;
			break;

		case bmdDeckLinkStatusVideoInputSignalLocked:
			label = @"Video Input Signal Locked";
			isBoolValue = YES;
			break;

		case bmdDeckLinkStatusReferenceSignalLocked:
			label = @"Reference Signal Locked";
			isBoolValue = YES;
			break;
			
		case bmdDeckLinkStatusDeviceTemperature:
			label = @"Device Temperatur";
			isIntValue = YES;
			break;
			
		case bmdDeckLinkStatusReceivedEDID:
			label = @"Received EDID";
			isByteValue = YES;
			break;
			
	}
	
	if(isIntValue || isFlagsValue)
	{
		int64_t intValue;
		HRESULT result = deckLinkStatus->GetInt(statusID, &intValue);
		if(result == S_OK)
		{
			if(translationDictionary)
			{
				stringValue = [DeckLinkDevice translate:(int32_t)intValue withDictionary:translationDictionary];
			}
			else if(isFlagsValue)
			{
				stringValue = [NSString stringWithFormat:@"%08x",(UInt32)intValue];
			}
			else
			{
				stringValue = [NSString stringWithFormat:@"%lli", intValue];
			}
		}
	}
	
	if(isBoolValue)
	{
		bool boolValue;
		HRESULT result = deckLinkStatus->GetFlag(statusID, &boolValue);
		if(result == S_OK)
		{
			stringValue = boolValue ? @"yes" : @"no";
		}
	}
	
//	if(isByteValue)
//	{
//		bool boolValue;
//		HRESULT result = deckLinkStatus->GetBytes(statusID, &boolValue);
//		if(result == S_OK)
//		{
//			stringValue = boolValue ? @"yes" : @"no";
//		}
//	}


	if(label == nil)
	{
		label = @"Unkown Status Key";
	}
	
	if(stringValue == nil)
	{
		stringValue = @"n/a";
	}
	
	return @{@"key": [DeckLinkDevice stringFromFourCC:statusID], @"label" : label, @"value" : stringValue };
}

-(NSArray*)getStatusReport
{
	
	NSArray *reportStatusIDs = @[
		@(bmdDeckLinkStatusDetectedVideoInputMode),
		@(bmdDeckLinkStatusDetectedVideoInputFlags),
		@(bmdDeckLinkStatusCurrentVideoInputMode),
		@(bmdDeckLinkStatusCurrentVideoInputFlags),
		@(bmdDeckLinkStatusCurrentVideoInputPixelFormat),
		@(bmdDeckLinkStatusCurrentVideoOutputMode),
		@(bmdDeckLinkStatusCurrentVideoOutputFlags),
		@(bmdDeckLinkStatusPCIExpressLinkWidth),
		@(bmdDeckLinkStatusPCIExpressLinkSpeed),
		@(bmdDeckLinkStatusLastVideoOutputPixelFormat),
//		@(bmdDeckLinkDuplexMode),
		@(bmdDeckLinkStatusBusy),
		@(bmdDeckLinkStatusVideoInputSignalLocked),
		@(bmdDeckLinkStatusReferenceSignalMode),
		@(bmdDeckLinkStatusReferenceSignalMode),
		@(bmdDeckLinkStatusReferenceSignalFlags),
		@(bmdDeckLinkStatusDeviceTemperature),
		@(bmdDeckLinkStatusInterchangeablePanelType),
		@(bmdDeckLinkStatusReceivedEDID)
	];
	
	NSMutableArray *report = [[NSMutableArray alloc] init];
	for(NSNumber* statusID in reportStatusIDs)
	{
		[report addObject:[self getStatus:statusID.unsignedIntValue]];
	}
	
	return report;
}

@end
