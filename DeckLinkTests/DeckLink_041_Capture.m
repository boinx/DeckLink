#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "DeckLink.h"


@interface DeckLink_041_Capture : XCTestCase <DeckLinkDeviceCaptureVideoDelegate, DeckLinkDeviceCaptureAudioDelegate>

@property (nonatomic, strong) dispatch_semaphore_t videoSemaphore;
@property (nonatomic, strong) dispatch_semaphore_t audioSemaphore;

@end


@implementation DeckLink_041_Capture

- (void)setUp
{
	[super setUp];
	
	self.continueAfterFailure = NO;
	
	self.videoSemaphore = dispatch_semaphore_create(0);
	self.audioSemaphore = dispatch_semaphore_create(0);
}

- (void)tearDown
{
	[super tearDown];
}

- (void)testSimpleCapture
{
	XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%s", __FUNCTION__]];
	
	DeckLinkDevice *device = [DeckLinkDevice devicesWithIODirection:DeckLinkDeviceIODirectionCapture].firstObject;
	XCTAssertNotNil(device);
	XCTAssertFalse(device.captureActive);

	dispatch_queue_t queue = dispatch_queue_create("CaptureQueue", DISPATCH_QUEUE_SERIAL);
	[device setCaptureVideoDelegate:self queue:queue];
	[device setCaptureAudioDelegate:self queue:queue];

	// Setup video
	{
		NSArray *videoFormatDescriptions = device.captureVideoFormatDescriptions;
		XCTAssertNotNil(videoFormatDescriptions);
		XCTAssertGreaterThan(videoFormatDescriptions.count, 0);
	
		CMVideoFormatDescriptionRef videoFormatDescription = (__bridge CMVideoFormatDescriptionRef)videoFormatDescriptions.firstObject;
		XCTAssertNotNil((__bridge id)videoFormatDescription);

		NSError *error = nil;
		XCTAssertTrue([device setCaptureActiveVideoFormatDescription:videoFormatDescription error:&error], @"%@", error);
		XCTAssertNil(error);
	}

	// Setup audio
	{
		NSArray *audioFormatDescriptions = device.captureAudioFormatDescriptions;
		XCTAssertNotNil(audioFormatDescriptions);
		XCTAssertGreaterThan(audioFormatDescriptions.count, 0);
	
		CMVideoFormatDescriptionRef audioFormatDescription = (__bridge CMAudioFormatDescriptionRef)audioFormatDescriptions.firstObject;
		XCTAssertNotNil((__bridge id)audioFormatDescription);
		
		NSError *error = nil;
		XCTAssertTrue([device setCaptureActiveAudioFormatDescription:audioFormatDescription error:&error], @"%@", error);
		XCTAssertNil(error);
	}

	// Start capture
	{
		NSError *error = nil;
		XCTAssertTrue([device startCaptureWithError:&error], @"%@", error);
		XCTAssertNil(error);
		XCTAssertTrue(device.captureActive);
	}
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		dispatch_semaphore_wait(self.videoSemaphore, DISPATCH_TIME_FOREVER);
		dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[device stopCapture];
			XCTAssertFalse(device.captureActive);

			[expectation fulfill];
		});
	});

	[self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
		[device stopCapture];
	}];
}

#pragma mark - DeckLinkDeviceCaptureVideoDelegate

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	dispatch_semaphore_signal(self.videoSemaphore);
}

#pragma mark - DeckLinkDeviceCaptureAudioDelegate

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	dispatch_semaphore_signal(self.audioSemaphore);
}

@end
