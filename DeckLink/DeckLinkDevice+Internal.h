#import "DeckLinkDevice.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice.h"
#import "DeckLinkDevice+Capture.h"
#import "DeckLinkDeviceInternalInputCallback.h"
#import "DeckLinkDeviceInternalOutputCallback.h"


@interface DeckLinkDevice ()
{
	IDeckLink *deckLink;
	IDeckLinkAttributes *deckLinkAttributes;
	IDeckLinkConfiguration *deckLinkConfiguration;
	IDeckLinkKeyer *deckLinkKeyer;
	IDeckLinkInput *deckLinkInput;
	IDeckLinkOutput *deckLinkOutput;
	
	DeckLinkDeviceInternalInputCallback *deckLinkInputCallback;
	DeckLinkDeviceInternalOutputCallback *deckLinkOutputCallback;
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
@property (atomic, assign) BOOL captureInputSourceConnected;

@property (nonatomic, strong) dispatch_queue_t captureQueue;

@property (nonatomic, copy) NSArray *captureVideoFormatDescriptions;
@property (atomic, strong) __attribute__((NSObject)) CMVideoFormatDescriptionRef captureActiveVideoFormatDescription;

@property (nonatomic, copy) NSArray *captureAudioFormatDescriptions;
@property (atomic, strong) __attribute__((NSObject)) CMAudioFormatDescriptionRef captureActiveAudioFormatDescription;

@property (nonatomic, copy) NSArray *captureVideoConnections;
@property (atomic, strong) NSString *captureActiveVideoConnection;

@property (nonatomic, copy) NSArray *captureAudioConnections;
@property (atomic, strong) NSString *captureActiveAudioConnection;

@property (nonatomic, weak) id<DeckLinkDeviceCaptureVideoDelegate> captureVideoDelegate;
@property (nonatomic, strong) dispatch_queue_t captureVideoDelegateQueue;

@property (nonatomic, weak) id<DeckLinkDeviceCaptureAudioDelegate> captureAudioDelegate;
@property (nonatomic, strong) dispatch_queue_t captureAudioDelegateQueue;

@property (nonatomic, strong) __attribute__((NSObject)) CVPixelBufferPoolRef capturePixelBufferPool;

// playback

@property (atomic, assign) BOOL playbackSupported;
@property (atomic, assign) BOOL playbackActive;

@property (nonatomic, strong) dispatch_queue_t playbackQueue;
@property (nonatomic, strong) dispatch_queue_t frameDownloadQueue;

@property (nonatomic, copy) NSArray *playbackVideoFormatDescriptions;
@property (atomic, strong) __attribute__((NSObject)) CMVideoFormatDescriptionRef playbackActiveVideoFormatDescription;

@property (nonatomic, copy) NSArray *playbackAudioFormatDescriptions;
@property (atomic, strong) __attribute__((NSObject)) CMAudioFormatDescriptionRef playbackActiveAudioFormatDescription;

@property (nonatomic, copy) NSArray *playbackKeyingModes;
@property (atomic, copy) NSString *playbackActiveKeyingMode;
@property (atomic, assign) float playbackKeyingAlpha;

@property (atomic, assign) NSUInteger frameBufferCount;

@end
