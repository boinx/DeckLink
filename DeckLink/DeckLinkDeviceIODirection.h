#import <Foundation/Foundation.h>


typedef NS_OPTIONS(uint32_t, DeckLinkDeviceIODirection)
{
	/**
	 * Devices that support incoming data
	 * Like UltraStudio Mini Recorder
	 */
	DeckLinkDeviceIODirectionCapture = 1 << 0,
	
	/**
	 * Devices that support outgoing data
	 * Like UltraStudio Mini Monitor
	 */
	DeckLinkDeviceIODirectionPlayback = 1 << 1,
};
