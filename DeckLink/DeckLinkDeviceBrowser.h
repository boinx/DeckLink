#import <Foundation/Foundation.h>

#import <DeckLink/DeckLinkDeviceIODirection.h>


extern NSString * const DeckLinkDeviceBrowserDidAddDeviceNotification;
extern NSString * const DeckLinkDeviceBrowserDidRemoveDeviceNotification;

extern NSString * const DeckLinkDeviceBrowserDeviceKey;


@class DeckLinkDevice;
@class DeckLinkDeviceBrowser;


@protocol DeckLinkDeviceBrowserDelegate <NSObject>
@optional

- (void)DeckLinkDeviceBrowser:(DeckLinkDeviceBrowser *)deviceBrowser didAddDevice:(DeckLinkDevice *)device;
- (void)DeckLinkDeviceBrowser:(DeckLinkDeviceBrowser *)deviceBrowser didRemoveDevice:(DeckLinkDevice *)device;

@end


@interface DeckLinkDeviceBrowser : NSObject

- (instancetype)init;

- (instancetype)initWithIODirection:(DeckLinkDeviceIODirection)direction NS_DESIGNATED_INITIALIZER;

@property (nonatomic, weak) id<DeckLinkDeviceBrowserDelegate> delegate;

/**
 * Contains DeckLinkDevices
 */
- (NSArray *)connectedDevices;

/**
 * Search for a device with persistantID and topologicalID
 */
- (DeckLinkDevice *)connectedDeviceWithIdentifier:(int32_t)identifier;

- (BOOL)start;
- (BOOL)stop;

@end
