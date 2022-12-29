#import <DeckLink/DeckLink.h>

#import <CoreMedia/CoreMedia.h>


@protocol DeckLinkDeviceCaptureVideoDelegate <NSObject>
@optional

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)DeckLinkDevice:(DeckLinkDevice *)device didDropVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)DeckLinkDevice:(DeckLinkDevice *)device didChangeActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)videoFormatDescription;

@end

@protocol DeckLinkDeviceCaptureAudioDelegate <NSObject>

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end


@interface DeckLinkDevice (Capture)

@property (atomic, assign, readonly) BOOL captureSupported;
@property (atomic, assign, readonly) BOOL synchronizeToCaptureGroupSupported;

/**
 * Set if the capturing was started.
 * Use startCaptureWithError: and stopCapture.
 */
@property (atomic, assign, readonly) BOOL captureActive;

/**
 * Set if an input device (Camera) is connected to the decklink device (Ultra Studio.
 * This property is only valid when captureActive == YES
 */
@property (atomic, assign, readonly) BOOL captureInputSourceConnected;

@property (nonatomic, copy, readonly) NSArray *captureVideoFormatDescriptions;
@property (atomic, strong, readonly) __attribute__((NSObject)) CMVideoFormatDescriptionRef captureActiveVideoFormatDescription;
- (BOOL)setCaptureActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)formatDescription error:(NSError **)error;

@property (nonatomic, copy, readonly) NSArray *captureAudioFormatDescriptions;
@property (atomic, strong, readonly) __attribute__((NSObject)) CMAudioFormatDescriptionRef captureActiveAudioFormatDescription;
- (BOOL)setCaptureActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)formatDescription error:(NSError **)error;

@property (nonatomic, copy, readonly) NSArray *captureVideoConnections;
@property (atomic, strong, readonly) NSString *captureActiveVideoConnection;
- (BOOL)setCaptureActiveVideoConnection:(NSString *)connection error:(NSError **)error;

@property (nonatomic, copy, readonly) NSArray *captureAudioConnections;
@property (atomic, strong, readonly) NSString *captureActiveAudioConnection;
- (BOOL)setCaptureActiveAudioConnection:(NSString *)connection error:(NSError **)error;

- (void)setCaptureVideoDelegate:(id<DeckLinkDeviceCaptureVideoDelegate>)delegate queue:(dispatch_queue_t)queue;

- (void)setCaptureAudioDelegate:(id<DeckLinkDeviceCaptureAudioDelegate>)delegate queue:(dispatch_queue_t)queue;

- (BOOL)setCaptureGroupID:(int64_t)captureGroupID;
- (int64_t)captureGroupID;
- (void)resetCaptureGroup;
- (BOOL)isVideoInputSignalLocked;

- (BOOL)startCaptureWithError:(NSError **)error;
- (BOOL)initializeCaptureWithError:(NSError **)outError;
- (BOOL)actuallyStartCaptureWithError:(NSError **)outError;
- (void)stopCapture;

@end
