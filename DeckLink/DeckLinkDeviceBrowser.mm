#import "DeckLinkDeviceBrowser.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Internal.h"
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
	
	dispatch_sync(self.devicesQueue, ^{
		[self.devices addObject:device];
        [self uniquifyDisplayNameOfDevice:device inSet:self.devices];
	});
		
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
}

- (void)didRemoveDeckLink:(IDeckLink *)deckLink
{
	__block DeckLinkDevice *removedDevice = nil;

	dispatch_sync(self.devicesQueue, ^{
		NSMutableSet *devices = self.devices;
		
		for(DeckLinkDevice *device in devices)
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
		}
	});
	
	if (removedDevice == nil)
	{
		return;
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		NSDictionary *userInfo = @{
			DeckLinkDeviceBrowserDeviceKey: removedDevice
		};
				
		[NSNotificationCenter.defaultCenter postNotificationName:DeckLinkDeviceBrowserDidRemoveDeviceNotification object:self userInfo:userInfo];
				
		id<DeckLinkDeviceBrowserDelegate> delegate = self.delegate;
		if([delegate respondsToSelector:@selector(DeckLinkDeviceBrowser:didRemoveDevice:)])
		{
			[delegate DeckLinkDeviceBrowser:self didRemoveDevice:removedDevice];
		}
	});
}

- (void)uniquifyDisplayNameOfDevice:(DeckLinkDevice *)deckLinkDevice inSet:(NSSet *)devices
{
    NSString *displayName = deckLinkDevice.displayName;
    NSString *modelName = deckLinkDevice.modelName;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName BEGINSWITH %@ AND modelName == %@", displayName, modelName];
    NSSet *devicesWithNonUniqueDisplayNames = [devices filteredSetUsingPredicate:predicate];
    
    if (devicesWithNonUniqueDisplayNames.count > 1) // the passed in device is assumed to be part of the set
    {
        NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"persistantID" ascending:YES],
                                     [NSSortDescriptor sortDescriptorWithKey:@"topologicalID" ascending:YES]];
                                    // DeckLink devices that do not provide any of these IDs will remain in random order
        
        NSArray *devicesWithNonUniqueDisplayNamesSorted = [devicesWithNonUniqueDisplayNames sortedArrayUsingDescriptors:sortDescriptors];
        
        NSInteger counter = 0;
        for (DeckLinkDevice *sortedDevice in devicesWithNonUniqueDisplayNamesSorted)
        {
            NSString *uniquifiedDisplayName = [displayName stringByAppendingFormat:@" %ld", counter];
            sortedDevice.displayName = uniquifiedDisplayName;
            
            counter++;
        }
    }
}

@end

