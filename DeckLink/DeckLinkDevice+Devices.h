#import <DeckLink/DeckLink.h>

#import "DeckLinkDeviceIODirection.h"


@interface DeckLinkDevice (Devices)

+ (NSArray *)devices;

+ (NSArray *)devicesWithIODirection:(DeckLinkDeviceIODirection)direction;

@end
