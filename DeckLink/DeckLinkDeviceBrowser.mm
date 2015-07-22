#import "DeckLinkDeviceBrowser.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice.h"
#import "DeckLinkDeviceBrowserInternalCallback.h"


NSString * const DeckLinkDeviceBrowserDidAddDeviceNotification = @"DeckLinkDeviceBrowserDidAddDevice";
NSString * const DeckLinkDeviceBrowserDidRemoveDeviceNotification = @"DeckLinkDeviceBrowserDidRemoveDevice";

NSString * const DeckLinkDeviceBrowserDeviceKey = @"device";


@interface DeckLinkDevice (BrowserInternal)

- (instancetype)initWithDeckLink:(IDeckLink *)deckLink;

@property (nonatomic, assign, readonly) IDeckLink *deckLink;

@end


@interface DeckLinkDeviceBrowser () <DeckLinkDeviceBrowserInternalCallbackDelegate>
{
	IDeckLinkDiscovery *discovery;
	DeckLinkDeviceBrowserInternalCallback *callback;
}

@property (nonatomic, strong) NSMutableSet *devices;
@property (nonatomic, strong) dispatch_queue_t devicesQueue;

@property (nonatomic, assign) DeckLinkDeviceIODirection direction;

@end


@implementation DeckLinkDeviceBrowser

- (instancetype)init
{
	return [self initWithIODirection:DeckLinkDeviceIODirectionCapture | DeckLinkDeviceIODirectionPlayback];
}

- (instancetype)initWithIODirection:(DeckLinkDeviceIODirection)direction;
{
	self = [super init];
	if(self != nil)
	{
		discovery = CreateDeckLinkDiscoveryInstance();
		if (discovery == NULL)
		{
			return nil;
		}
		
		callback = new DeckLinkDeviceBrowserInternalCallback(self);
		if (callback == NULL)
		{
			return nil;
		}
		
		self.direction = direction;
		
		self.devices = [NSMutableSet set];
		self.devicesQueue = dispatch_queue_create("DeckLinkDeviceBrowserQueue", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (void)dealloc
{
	if(discovery != NULL)
	{
		discovery->UninstallDeviceNotifications();
		discovery->Release();
		discovery = NULL;
	}
	
	if(callback != NULL)
	{
		callback->Release();
		callback = NULL;
	}
}

- (NSArray *)connectedDevices
{
	__block NSArray *connectedDevices = nil;
	
	dispatch_sync(self.devicesQueue, ^{
		connectedDevices = [self.devices.allObjects copy];
	});
	
	return connectedDevices;
}

- (DeckLinkDevice *)connectedDeviceWithIdentifier:(int32_t)identifier
{
	if(identifier == 0)
	{
		return nil;
	}
	
	__block DeckLinkDevice *connectedDevice = nil;
	
	dispatch_sync(self.devicesQueue, ^{
		NSSet *devices = self.devices;
		
		for(DeckLinkDevice *device in devices)
		{
			if(device.persistantID == identifier)
			{
				connectedDevice = device;
				return;
			}
		}
		
		for(DeckLinkDevice *device in devices)
		{
			if(device.topologicalID == identifier)
			{
				connectedDevice = device;
				return;
			}
		}
	});
	
	return connectedDevice;
}

- (BOOL)start
{
	__block BOOL result = NO;
	
	dispatch_sync(self.devicesQueue, ^{
		result = discovery->InstallDeviceNotifications(callback) == S_OK;
	});
	
	return result;
}

- (BOOL)stop
{
	__block BOOL result = NO;
	
	dispatch_sync(self.devicesQueue, ^{
		result = discovery->UninstallDeviceNotifications() == S_OK;
		
		// TODO: send notifications for devices?
		
		[self.devices removeAllObjects];
	});
	
	return result;
}

- (void)didAddDeckLink:(IDeckLink *)deckLink
{
	dispatch_sync(self.devicesQueue, ^{
		DeckLinkDeviceIODirection direction = self.direction;
		
		IDeckLinkAttributes *deckLinkAttributes = NULL;
		if (deckLink->QueryInterface(IID_IDeckLinkAttributes, (void **)&deckLinkAttributes) != S_OK)
		{
			return;
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
			return;
		}
		
		DeckLinkDevice *device = [[DeckLinkDevice alloc] initWithDeckLink:deckLink];
		if (device == nil)
		{
			return;
		}
		
		[self.devices addObject:device];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDictionary *userInfo = @{
				DeckLinkDeviceBrowserDeviceKey: device
			};
			
			[NSNotificationCenter.defaultCenter postNotificationName:DeckLinkDeviceBrowserDidAddDeviceNotification object:self userInfo:userInfo];
			
			id<DeckLinkDeviceBrowserDelegate> delegate = self.delegate;
			if([delegate respondsToSelector:@selector(DeckLinkDeviceBrowser:didAddDevice:)])
			{
				[delegate DeckLinkDeviceBrowser:self didAddDevice:device];
			}
		});
	});
}

- (void)didRemoveDeckLink:(IDeckLink *)deckLink
{
#if 0
	dispatch_sync(self.devicesQueue, ^{
		NSMutableSet *devices = self.devices;
		BDDLDevice *removedDevice = nil;
		
		for(BDDLDevice *device in devices)
		{
			if(device.deckLink == deckLink)
			{
				removedDevice = device;
				break;
			}
		}
		
		if(removedDevice != nil)
		{
			[devices removeObject:removedDevice];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				NSDictionary *userInfo = @{
										   BDDLDeviceBrowserDeviceKey: removedDevice
										   };
				
				[NSNotificationCenter.defaultCenter postNotificationName:BDDLDeviceBrowserDidRemoveDeviceNotification object:self userInfo:userInfo];
				
				id<BDDLDeviceBrowserDelegate> delegate = self.delegate;
				if([delegate respondsToSelector:@selector(BDDLDeviceBrowser:didRemoveDevice:)])
				{
					[delegate BDDLDeviceBrowser:self didRemoveDevice:removedDevice];
				}
			});
		}
	});
#endif
}

@end

