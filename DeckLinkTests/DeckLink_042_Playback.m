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

- (void)testVideoFormatDescriptions
{
	DeckLinkDevice *device = [DeckLinkDevice devicesWithIODirection:DeckLinkDeviceIODirectionPlayback].firstObject;
	XCTAssertNotNil(device);
	
	NSArray *videoFormatDescriptions = device.playbackVideoFormatDescriptions;
	XCTAssertGreaterThan(videoFormatDescriptions.count, 0);
	
	for (id videoFormatDescription_ in videoFormatDescriptions)
	{
		CMVideoFormatDescriptionRef videoFormatDescription = (__bridge CMVideoFormatDescriptionRef)videoFormatDescription_;
		
		NSError *error = nil;
		XCTAssertTrue([device setPlaybackActiveVideoFormatDescription:videoFormatDescription error:&error], @"%@", error);
		XCTAssertNil(error);
	}
}

- (void)testAudioFormatDescriptions
{
	DeckLinkDevice *device = [DeckLinkDevice devicesWithIODirection:DeckLinkDeviceIODirectionPlayback].firstObject;
	XCTAssertNotNil(device);
	
	NSArray *audioFormatDescriptions = device.playbackAudioFormatDescriptions;
	XCTAssertGreaterThan(audioFormatDescriptions.count, 0);
	
	for (id audioFormatDescription_ in audioFormatDescriptions)
	{
		CMAudioFormatDescriptionRef audioFormatDescription = (__bridge CMVideoFormatDescriptionRef)audioFormatDescription_;
		
		NSError *error = nil;
		XCTAssertTrue([device setPlaybackActiveAudioFormatDescription:audioFormatDescription error:&error], @"%@", error);
		XCTAssertNil(error);
	}
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
