#import "DeckLinkDevice.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Capture.h"
#import "DeckLinkDeviceInternalInputCallback.h"


@interface DeckLinkDevice ()
{
	IDeckLink *deckLink;
	IDeckLinkAttributes *deckLinkAttributes;
	IDeckLinkConfiguration *deckLinkConfiguration;
	IDeckLinkKeyer *deckLinkKeyer;
	IDeckLinkInput *deckLinkInput;
	IDeckLinkOutput *deckLinkOutput;
	
	DeckLinkDeviceInternalInputCallback *deckLinkInputCallback;
//	BDDLDeviceInternalOutputCallback *outputCallback;
}

- (instancetype)initWithDeckLink:(IDeckLink *)deckLink;

@property (nonatomic, assign, readonly) IDeckLink *deckLink;

@property (nonatomic, copy) NSString *modelName;
@property (nonatomic, copy) NSString *displayName;

@property (nonatomic, assign) int32_t persistantID;
@property (nonatomic, assign) int32_t topologicalID;

// capture

@property (atomic, assign) BOOL captureSupported;
@property (atomic, assign) BOOL captureActive;

@property (nonatomic, strong) dispatch_queue_t captureQueue;

@property (nonatomic, copy) NSArray *captureVideoFormatDescriptions;
@property (atomic, strong) __attribute__((NSObject)) CMVideoFormatDescriptionRef captureActiveVideoFormatDescription;

@property (nonatomic, copy) NSArray *captureAudioFormatDescriptions;
@property (atomic, strong) __attribute__((NSObject)) CMAudioFormatDescriptionRef captureActiveAudioFormatDescription;

@property (nonatomic, weak) id<DeckLinkDeviceCaptureVideoDelegate> captureVideoDelegate;
@property (nonatomic, strong) dispatch_queue_t captureVideoDelegateQueue;

@property (nonatomic, weak) id<DeckLinkDeviceCaptureAudioDelegate> captureAudioDelegate;
@property (nonatomic, strong) dispatch_queue_t captureAudioDelegateQueue;

@property (nonatomic, strong) __attribute__((NSObject)) CVPixelBufferPoolRef capturePixelBufferPool;


// record

@property (nonatomic, strong) dispatch_queue_t recordQueue;

@property (nonatomic, assign) BOOL canRecord;
@property (nonatomic, assign) BOOL supportsRecordFormatDetection;
@property (nonatomic, copy) NSArray *recordVideoFormatDescriptions;
@property (nonatomic, copy) NSArray *recordAudioFormatDescriptions;
@property (nonatomic, strong) __attribute__((NSObject)) CMVideoFormatDescriptionRef recordActiveVideoFormatDescription;
@property (nonatomic, strong) __attribute__((NSObject)) CMAudioFormatDescriptionRef recordActiveAudioFormatDescription;

// keying

@property (nonatomic, assign) BOOL supportsInternalKeying;
@property (nonatomic, assign) BOOL supportsExternalKeying;
@property (nonatomic, assign) BOOL supportsHDKeying;

//@property (assign) BDDLDeviceKeyingMode keyingMode;
//@property (assign) float keyingAlpha;

@end