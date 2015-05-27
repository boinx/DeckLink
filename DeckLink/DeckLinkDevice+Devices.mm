#import "DeckLinkDevice+Devices.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Creation.h"


@implementation DeckLinkDevice (Devices)

+ (NSArray *)devices
{
	return [self devicesWithIOSupport:DeckLinkDeviceIOSupportCapture | DeckLinkDeviceIOSupportPlayback];
}

+ (NSArray *)devicesWithIOSupport:(DeckLinkDeviceIOSupport)IOSupport
{
	IDeckLinkIterator *iterator = CreateDeckLinkIteratorInstance();
	if (iterator == NULL)
	{
		return nil;
	}
	
	NSMutableArray *devices = [NSMutableArray array];
	
	IDeckLink *deckLink = NULL;
	while (iterator->Next(&deckLink) == S_OK)
	{
		IDeckLinkAttributes *deckLinkAttributes = NULL;
		if (deckLink->QueryInterface(IID_IDeckLinkAttributes, (void **)&deckLinkAttributes) != S_OK)
		{
			continue;
		}
		
		int64_t videoIOSupport = 0;
		deckLinkAttributes->GetInt(BMDDeckLinkVideoIOSupport, &videoIOSupport);

		BOOL match = NO;
		if (videoIOSupport & bmdDeviceSupportsCapture && IOSupport & DeckLinkDeviceIOSupportCapture)
		{
			match = YES;
		}
		else if (videoIOSupport & bmdDeviceSupportsPlayback && IOSupport & DeckLinkDeviceIOSupportPlayback)
		{
			match = YES;
		}
		
		deckLinkAttributes->Release();
		
		DeckLinkDevice *device = [[DeckLinkDevice alloc] initWithDeckLink:deckLink];
		[devices addObject:device];
	}
	
	iterator->Release();
	
	return devices;
}

@end
