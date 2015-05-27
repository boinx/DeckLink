#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "DeckLink.h"


@interface DeckLinkDeviceBrowserTests : XCTestCase <DeckLinkDeviceBrowserDelegate>

@property (nonatomic, strong) XCTestExpectation *expectation;

@end


@implementation DeckLinkDeviceBrowserTests

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
}

- (void)testDeviceBrowserDelegate
{
	XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%s", __FUNCTION__]];
	self.expectation = expectation;
	
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
	XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%s", __FUNCTION__]];

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
		XCTAssertEqualObjects(device.class, DeckLinkDevice.class);
		
		[expectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
		[browser stop];
	}];
}

#pragma mark - DeckLinkDeviceBrowserDelegate

- (void)DeckLinkDeviceBrowser:(DeckLinkDeviceBrowser *)deviceBrowser didAddDevice:(DeckLinkDevice *)device
{
	XCTAssertNotNil(device);
	XCTAssertEqualObjects(device.class, DeckLinkDevice.class);
	
	[self.expectation fulfill];
}

@end
