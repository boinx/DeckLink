#import "DeckLinkDevice+Devices.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Internal.h"


@implementation DeckLinkDevice (Devices)

+ (NSArray *)devices
{
	return [self devicesWithIODirection:DeckLinkDeviceIODirectionCapture | DeckLinkDeviceIODirectionPlayback];
}

+ (NSArray *)devicesWithIODirection:(DeckLinkDeviceIODirection)direction
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
		
		int64_t support = 0;
		deckLinkAttributes->GetInt(BMDDeckLinkVideoIOSupport, &support);

		BOOL match = NO;
		if (support & bmdDeviceSupportsCapture && direction & DeckLinkDeviceIODirectionCapture)
		{
			match = YES;
		}
		else if (support & bmdDeviceSupportsPlayback && direction & DeckLinkDeviceIODirectionPlayback)
		{
			match = YES;
		}
		
		deckLinkAttributes->Release();
		
		if (!match)
		{
			continue;
		}
		
		DeckLinkDevice *device = [[DeckLinkDevice alloc] initWithDeckLink:deckLink];
		[devices addObject:device];
	}
	
	iterator->Release();
	
	return devices.count != 0 ? [NSArray arrayWithArray:devices] : nil;
}

@end
