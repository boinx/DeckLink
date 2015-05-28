#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "DeckLink.h"


@interface DeckLink_042_Playback : XCTestCase

@end


@implementation DeckLink_042_Playback

- (void)setUp
{
	[super setUp];
	
	self.continueAfterFailure = NO;
}

- (void)tearDown
{
	[super tearDown];
}

- (void)testKeying
{
	DeckLinkDevice *device = [DeckLinkDevice devicesWithIODirection:DeckLinkDeviceIODirectionPlayback].firstObject;
	XCTAssertNotNil(device);

	NSArray *keyingModes = device.playbackKeyingModes;
	// keyingModes may be nil
	
	for (NSString *keyingMode in keyingModes)
	{
		NSError *error = nil;
		XCTAssertTrue([device setPlaybackActiveKeyingMode:keyingMode alpha:1.0 error:&error]);
		XCTAssertNil(error);
	}
	
	NSError *error = nil;
	XCTAssertFalse([device setPlaybackActiveKeyingMode:@"Invalid" alpha:1.0 error:&error]);
	XCTAssertNotNil(error);
}

@end
