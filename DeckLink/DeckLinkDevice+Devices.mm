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
		if(device){
			[devices addObject:device];
		}
		else
		{
			CFStringRef displayName = NULL;
			if (deckLink->GetDisplayName(&displayName) == S_OK)
			{
				NSLog(@"%s:%d can't create DeckLinkDevice instance from %@", __FUNCTION__, __LINE__, displayName);
				CFRelease(displayName);
			}
			else
			{
				NSLog(@"%s:%d can't create DeckLinkDevice instance from unnamed Deck Link device.", __FUNCTION__, __LINE__);
			}
		}
	}
	
	iterator->Release();
	
	return devices.count != 0 ? [NSArray arrayWithArray:devices] : nil;
}

@end
