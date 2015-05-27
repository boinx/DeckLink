#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "DeckLinkInformation.h"


@interface DeckLinkTests : XCTestCase

@end


@implementation DeckLinkTests

- (void)setUp
{
	[super setUp];
}

- (void)tearDown
{
	[super tearDown];
}

- (void)testAPIVersion
{
	DeckLinkInformation *information = [[DeckLinkInformation alloc] init];
	XCTAssertNotNil(information, @"No DeckLink drivers found");
	
	NSString *APIVersion = information.APIVersion;
	XCTAssertNotNil(APIVersion);
	XCTAssertNotEqual([APIVersion compare:@"10.3" options:NSNumericSearch], NSOrderedAscending, @"DeckLink drivers must be at least version 10.3 to work with the rest of the API.");
}

@end
