#import "DeckLinkDeviceBrowser.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Creation.h"
#import "DeckLinkDeviceBrowserInternalCallback.h"


NSString * const DeckLinkDeviceBrowserDidAddDeviceNotification = @"DeckLinkDeviceBrowserDidAddDevice";
NSString * const DeckLinkDeviceBrowserDidRemoveDeviceNotification = @"DeckLinkDeviceBrowserDidRemoveDevice";

NSString * const DeckLinkDeviceBrowserDeviceKey = @"device";


@interface DeckLinkDeviceBrowser () <DeckLinkDeviceBrowserInternalCallbackDelegate>
{
	IDeckLinkDiscovery *discovery;
	DeckLinkDeviceBrowserInternalCallback *callback;
}

@property (nonatomic, strong) NSMutableSet *devices;
@property (nonatomic, strong) dispatch_queue_t devicesQueue;

@property (nonatomic, assign) DeckLinkDeviceBrowserType type;

@end


@implementation DeckLinkDeviceBrowser

- (instancetype)init
{
	return [self initWithType:DeckLinkDeviceBrowserTypeCapture | DeckLinkDeviceBrowserTypePlayback];
}

- (instancetype)initWithType:(DeckLinkDeviceBrowserType)type
{
	self = [super init];
	if(self != nil)
	{
		self.type = type;
		
		self.devices = [NSMutableSet setWithCapacity:8];
		self.devicesQueue = dispatch_queue_create("BDDLDeviceBrowserQueue", DISPATCH_QUEUE_SERIAL);
		
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
	}
	return self;
}

- (void)dealloc
{
	[self stop];
	
	if(callback != NULL)
	{
		callback->Release();
		callback = NULL;
	}
	
	if(discovery != NULL)
	{
		discovery->Release();
		discovery = NULL;
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
#if 0
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
#endif
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
		DeckLinkDeviceBrowserType type = self.type;
		
		IDeckLinkAttributes *deckLinkAttributes = NULL;
		if (deckLink->QueryInterface(IID_IDeckLinkAttributes, (void **)&deckLinkAttributes) != S_OK)
		{
			return;
		}
		
		int64_t videoIOSupport = 0;
		deckLinkAttributes->GetInt(BMDDeckLinkVideoIOSupport, &videoIOSupport);
		
		BOOL match = NO;
		if (videoIOSupport & bmdDeviceSupportsCapture && type & DeckLinkDeviceBrowserTypeCapture)
		{
			match = YES;
		}
		else if (videoIOSupport & bmdDeviceSupportsPlayback && type & DeckLinkDeviceBrowserTypePlayback)
		{
			match = YES;
		}
		
		if (!match)
		{
			return;
		}
		
		deckLinkAttributes->Release();
		
		DeckLinkDevice *device = [[DeckLinkDevice alloc] initWithDeckLink:deckLink];
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

