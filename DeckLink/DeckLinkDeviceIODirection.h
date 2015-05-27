#import <Foundation/Foundation.h>


typedef NS_OPTIONS(uint32_t, DeckLinkDeviceIODirection)
{
	/**
	 * Devices that support incoming data
	 */
	DeckLinkDeviceIODirectionCapture = 1 << 0,
	
	/**
	 * Devices that support outgoing data
	 */
	DeckLinkDeviceIODirectionPlayback = 1 << 1,
};
