#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "CMFormatDescription+DeckLink.h"
#import "DeckLinkAPI.h"


@interface DeckLink_031_FormatDescriptionTests : XCTestCase

@end


@implementation DeckLink_031_FormatDescriptionTests

- (void)setUp
{
	[super setUp];
}

- (void)tearDown
{
	[super tearDown];
}

- (void)testFormatDescriptionCreation
{
	IDeckLinkIterator *deckLinkIterator = CreateDeckLinkIteratorInstance();
	XCTAssert(deckLinkIterator != NULL);
	
	// This test is only successful if at least one format description was created
	BOOL createdFormatDescription = NO;
	
	IDeckLink *deckLink = NULL;
	while(deckLinkIterator->Next(&deckLink) == S_OK)
	{
		IDeckLinkInput *deckLinkInput = NULL;
		if (deckLink->QueryInterface(IID_IDeckLinkInput, (void **)&deckLinkInput) == S_OK)
		{
			IDeckLinkDisplayModeIterator *displayModeIterator = NULL;
			if (deckLinkInput->GetDisplayModeIterator(&displayModeIterator) == S_OK)
			{
				IDeckLinkDisplayMode *displayMode = NULL;
				while (displayModeIterator->Next(&displayMode) == S_OK)
				{
					CMPixelFormatType pixelFormat = kCMPixelFormat_422YpCbCr8;
					
					BMDDisplayModeSupport displayModeSupport = 0;
					if (deckLinkInput->DoesSupportVideoMode(displayMode->GetDisplayMode(), (BMDPixelFormat)pixelFormat, bmdVideoInputFlagDefault, &displayModeSupport, NULL) == S_OK && displayModeSupport != bmdDisplayModeNotSupported)
					{
						CMVideoFormatDescriptionRef formatDescription = NULL;
						XCTAssertEqual(CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(displayMode, pixelFormat, displayModeSupport == bmdDisplayModeSupported, &formatDescription), noErr);
						XCTAssertNotNil((__bridge id)formatDescription);
					
						CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
						XCTAssertEqual(dimensions.width, (int32_t)displayMode->GetWidth());
						XCTAssertEqual(dimensions.height, (int32_t)displayMode->GetHeight());
					
						CMTime frameRate = kCMTimeInvalid;
						XCTAssertEqual(CMVideoFormatDescriptionGetDeckLinkFrameRate(formatDescription, &frameRate), noErr);
						XCTAssertTrue(CMTIME_IS_VALID(frameRate));
					
						NSNumber *displayModeValue = (__bridge NSNumber *)CMFormatDescriptionGetExtension(formatDescription, DeckLinkFormatDescriptionDisplayModeKey);
						XCTAssertNotNil(displayModeValue);
						XCTAssertTrue([displayModeValue isKindOfClass:NSNumber.class]);
						XCTAssertEqual(displayModeValue.intValue, displayMode->GetDisplayMode());
					
						CFRelease(formatDescription);
						formatDescription = NULL;

						createdFormatDescription = YES;
					}
				}
				displayModeIterator->Release();
				displayModeIterator = NULL;
			}
			deckLinkInput->Release();
			deckLinkInput = NULL;
		}
		
		IDeckLinkOutput *deckLinkOutput = NULL;
		if (deckLink->QueryInterface(IID_IDeckLinkOutput, (void **)&deckLinkOutput) == S_OK)
		{
			IDeckLinkDisplayModeIterator *displayModeIterator = NULL;
			if (deckLinkOutput->GetDisplayModeIterator(&displayModeIterator) == S_OK)
			{
				IDeckLinkDisplayMode *displayMode = NULL;
				while (displayModeIterator->Next(&displayMode) == S_OK)
				{					
					CMPixelFormatType pixelFormat = kCMPixelFormat_422YpCbCr8;
					
					BMDDisplayModeSupport displayModeSupport = 0;
					if (deckLinkOutput->DoesSupportVideoMode(displayMode->GetDisplayMode(), (BMDPixelFormat)pixelFormat, bmdVideoInputFlagDefault, &displayModeSupport, NULL) == S_OK && displayModeSupport != bmdDisplayModeNotSupported)
					{
						CMVideoFormatDescriptionRef formatDescription = NULL;
						XCTAssertEqual(CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(displayMode, pixelFormat, displayModeSupport == bmdDisplayModeSupported, &formatDescription), noErr);
						XCTAssertNotNil((__bridge id)formatDescription);
						
						CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
						XCTAssertEqual(dimensions.width, (int32_t)displayMode->GetWidth());
						XCTAssertEqual(dimensions.height, (int32_t)displayMode->GetHeight());
						
						CMTime frameRate = kCMTimeInvalid;
						XCTAssertEqual(CMVideoFormatDescriptionGetDeckLinkFrameRate(formatDescription, &frameRate), noErr);
						XCTAssertTrue(CMTIME_IS_VALID(frameRate));
						
						NSNumber *displayModeValue = (__bridge NSNumber *)CMFormatDescriptionGetExtension(formatDescription, DeckLinkFormatDescriptionDisplayModeKey);
						XCTAssertNotNil(displayModeValue);
						XCTAssertTrue([displayModeValue isKindOfClass:NSNumber.class]);
						XCTAssertEqual(displayModeValue.intValue, displayMode->GetDisplayMode());
						
						CFRelease(formatDescription);
						formatDescription = NULL;
						
						createdFormatDescription = YES;
					}
				}
				
				displayModeIterator->Release();
				displayModeIterator = NULL;
			}
			
			deckLinkOutput->Release();
			deckLinkOutput = NULL;
		}
	}
	deckLinkIterator->Release();
	deckLinkIterator = NULL;
	
	XCTAssertTrue(createdFormatDescription, @"No format descriptions were created. Maybe no device is connected");
	
}

@end
