#import <DeckLink/DeckLink.h>


typedef NS_OPTIONS(uint32_t, DeckLinkDeviceIOSupport)
{
	/**
	 * Devices that support incoming data
	 */
	DeckLinkDeviceIOSupportCapture = 1 << 0,
	
	/**
	 * Devices that support outgoing data
	 */
	DeckLinkDeviceIOSupportPlayback = 1 << 1,
};


@interface DeckLinkDevice (Devices)

+ (NSArray *)devices;

+ (NSArray *)devicesWithIOSupport:(DeckLinkDeviceIOSupport)type;

@end
