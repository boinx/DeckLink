#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "DeckLink.h"


@interface DeckLink_021_DeviceBrowserTests : XCTestCase <DeckLinkDeviceBrowserDelegate>

@property (nonatomic, strong) XCTestExpectation *expectation;

@end


@implementation DeckLink_021_DeviceBrowserTests

- (void)setUp
{
	[super setUp];
}

- (void)tearDown
{
	[super tearDown];
}

- (void)testDevices
{
	NSArray *devices = DeckLinkDevice.devices;
	XCTAssertNotNil(devices);
	XCTAssertNotEqual(devices.count, 0);
	
	for (DeckLinkDevice *device in devices)
	{
		XCTAssertTrue([device isKindOfClass:DeckLinkDevice.class]);
		
		XCTAssertNotNil(device.displayName);
		XCTAssertNotNil(device.modelName);
		
		// device.persistantID can be 0
		XCTAssertNotEqual(device.topologicalID, 0);
	}
}

- (void)testDeviceBrowserDelegate
{
	self.expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%s", __FUNCTION__]];
	
	DeckLinkDeviceBrowser *browser = [[DeckLinkDeviceBrowser alloc] init];
	XCTAssertNotNil(browser);
	
	browser.delegate = self;
	
	XCTAssertTrue([browser start]);
	
	[self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
		[browser stop];
	}];
}

- (void)testDeviceBrowserNotification
{
	self.expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%s", __FUNCTION__]];

	DeckLinkDeviceBrowser *browser = [[DeckLinkDeviceBrowser alloc] init];
	XCTAssertNotNil(browser);
	
	XCTAssertTrue([browser start]);

	NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
	NSOperationQueue *queue = NSOperationQueue.mainQueue;
	
	[notificationCenter addObserverForName:DeckLinkDeviceBrowserDidAddDeviceNotification object:browser queue:queue usingBlock:^(NSNotification *notification) {
		XCTAssertNotNil(notification);
		XCTAssertEqual(browser, notification.object);
		
		NSDictionary *userInfo = notification.userInfo;
		XCTAssertNotNil(userInfo);
		
		DeckLinkDevice *device = userInfo[DeckLinkDeviceBrowserDeviceKey];
		XCTAssertNotNil(device);
		XCTAssertTrue([device isKindOfClass:DeckLinkDevice.class]);
		
		[self.expectation fulfill];
		self.expectation = nil;
	}];
	
	[self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
		[browser stop];
	}];
}

#if defined(DECKLINK_ALLOW_MANUAL_TESTS) && (DECKLINK_ALLOW_MANUAL_TESTS > 0)
- (void)testDeviceBrowserRemoveNotification
{
	DeckLinkDeviceBrowser *browser = [[DeckLinkDeviceBrowser alloc] init];
	XCTAssertNotNil(browser);
	
	XCTAssertTrue([browser start]);

	NSLog(@"UNPLUG A DECKLINK DEVICE");
	
	[self expectationForNotification:DeckLinkDeviceBrowserDidRemoveDeviceNotification object:browser handler:^BOOL(NSNotification *notification) {
		return YES;
	}];
	
	[self waitForExpectationsWithTimeout:60.0 handler:^(NSError *error) {

	}];
	
	NSLog(@"PLUG IN A DECKLINK DEVICE");
	
	[self expectationForNotification:DeckLinkDeviceBrowserDidAddDeviceNotification object:browser handler:^BOOL(NSNotification *notification) {
		return YES;
	}];
	
	[self waitForExpectationsWithTimeout:60.0 handler:^(NSError *error) {
		[browser stop];
	}];
}
#endif

#pragma mark - DeckLinkDeviceBrowserDelegate

- (void)DeckLinkDeviceBrowser:(DeckLinkDeviceBrowser *)deviceBrowser didAddDevice:(DeckLinkDevice *)device
{
	XCTAssertNotNil(device);
	XCTAssertTrue([device isKindOfClass:DeckLinkDevice.class]);
	
	[self.expectation fulfill];
	self.expectation = nil;
}

@end
