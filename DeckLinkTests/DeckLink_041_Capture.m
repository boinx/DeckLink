#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "DeckLink.h"


@interface DeckLink_041_Capture : XCTestCase <DeckLinkDeviceCaptureVideoDelegate, DeckLinkDeviceCaptureAudioDelegate>

@end


@implementation DeckLink_041_Capture

- (void)setUp
{
	[super setUp];
	
	self.continueAfterFailure = NO;
}

- (void)tearDown
{
	[super tearDown];
}

- (void)testCapture
{
	DeckLinkDevice *device = [DeckLinkDevice devicesWithIODirection:DeckLinkDeviceIODirectionCapture].firstObject;
	XCTAssertNotNil(device);
	XCTAssertFalse(device.captureActive);

	NSArray *videoFormatDescriptions = device.captureVideoFormatDescriptions;
	XCTAssertNotNil(videoFormatDescriptions);
	XCTAssertGreaterThan(videoFormatDescriptions.count, 0);
	
	dispatch_queue_t queue = dispatch_queue_create("CaptureQueue", DISPATCH_QUEUE_SERIAL);
	
	[device setCaptureVideoDelegate:self queue:queue];
	[device setCaptureAudioDelegate:self queue:queue];
	
	CMVideoFormatDescriptionRef videoFormatDescription = (__bridge CMVideoFormatDescriptionRef)videoFormatDescriptions.firstObject;
	XCTAssertNotNil((__bridge id)videoFormatDescription);
	
	NSError *error = nil;
	XCTAssertTrue([device setCaptureActiveVideoFormatDescription:videoFormatDescription error:&error], @"%@", error);
	XCTAssertNil(error);

	XCTAssertTrue([device startCaptureWithError:&error], @"%@", error);
	XCTAssertNil(error);
	XCTAssertTrue(device.captureActive);

	XCTAssertTrue([device setCaptureActiveVideoFormatDescription:videoFormatDescription error:&error], @"%@", error);
	XCTAssertNil(error);

	[device stopCapture];
	XCTAssertFalse(device.captureActive);
}

#pragma mark - DeckLinkDeviceCaptureVideoDelegate

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	
}

#pragma mark - DeckLinkDeviceCaptureAudioDelegate

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	
}

@end
