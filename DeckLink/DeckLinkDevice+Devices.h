#import <DeckLink/DeckLink.h>

#import <DeckLink/DeckLinkDeviceIODirection.h>


@interface DeckLinkDevice (Devices)

+ (NSArray *)devices;

+ (NSArray *)devicesWithIODirection:(DeckLinkDeviceIODirection)direction;

@end
