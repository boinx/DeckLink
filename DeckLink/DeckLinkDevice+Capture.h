#import "DeckLink.h"

#import <CoreMedia/CoreMedia.h>


@protocol DeckLinkDeviceCaptureVideoDelegate <NSObject>
@optional

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)DeckLinkDevice:(DeckLinkDevice *)device didDropVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@protocol DeckLinkDeviceCaptureAudioDelegate <NSObject>

- (void)DeckLinkDevice:(DeckLinkDevice *)device didCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end


@interface DeckLinkDevice (Capture)

@property (atomic, assign, readonly) BOOL captureSupported;
@property (atomic, assign, readonly) BOOL captureActive;

@property (nonatomic, copy, readonly) NSArray *captureVideoFormatDescriptions;
@property (atomic, strong, readonly) __attribute__((NSObject)) CMVideoFormatDescriptionRef captureActiveVideoFormatDescription;
- (BOOL)setCaptureActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)captureActiveVideoFormatDescription error:(NSError **)error;

@property (nonatomic, copy, readonly) NSArray *captureAudioFormatDescriptions;
@property (atomic, strong, readonly) __attribute__((NSObject)) CMAudioFormatDescriptionRef captureActiveAudioFormatDescription;
- (BOOL)setCaptureActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)captureActiveAudioFormatDescription error:(NSError **)error;

- (void)setCaptureVideoDelegate:(id<DeckLinkDeviceCaptureVideoDelegate>)delegate queue:(dispatch_queue_t)queue;
- (void)setCaptureAudioDelegate:(id<DeckLinkDeviceCaptureAudioDelegate>)delegate queue:(dispatch_queue_t)queue;

- (BOOL)startCaptureWithError:(NSError **)error;
- (void)stopCapture;

@end
