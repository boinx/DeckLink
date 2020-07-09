#import <DeckLink/DeckLinkDevice.h>

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>


@interface DeckLinkDevice (Playback)

@property (nonatomic, copy, readonly) NSArray *playbackVideoFormatDescriptions;
@property (atomic, strong, readonly) __attribute__((NSObject)) CMVideoFormatDescriptionRef playbackActiveVideoFormatDescription;
- (BOOL)setPlaybackActiveVideoFormatDescription:(CMVideoFormatDescriptionRef)formatDescription error:(NSError **)error;

@property (nonatomic, copy, readonly) NSArray *playbackAudioFormatDescriptions;
@property (atomic, strong, readonly) __attribute__((NSObject)) CMAudioFormatDescriptionRef playbackActiveAudioFormatDescription;
- (BOOL)setPlaybackActiveAudioFormatDescription:(CMAudioFormatDescriptionRef)formatDescription error:(NSError **)error;

@property (atomic, assign, readonly) BOOL playbackSupported;
@property (atomic, assign, readonly) BOOL playbackActive;

@property (nonatomic, copy, readonly) NSArray *playbackKeyingModes;
@property (atomic, strong, readonly) NSString *playbackActiveKeyingMode;
- (BOOL)setPlaybackActiveKeyingMode:(NSString *)keyingMode alpha:(float)alpha error:(NSError **)error;

- (void)startScheduledPlaybackWithStartTime:(NSUInteger)startTime timeScale:(NSUInteger)timeScale;
- (void)schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer displayTime:(NSUInteger)displayTime frameDuration:(NSUInteger)frameDuration timeScale:(NSUInteger)timeScale;
- (void)stopScheduledPlaybackWithCompletionHandler:(DeckLinkDeviceStopPlaybackCompletionHandler)completionHandler;
- (void)playbackPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)playbackPixelBuffer:(CVPixelBufferRef)pixelBuffer isFlipped:(BOOL)flipped;

- (void)playbackContinuousAudioBufferList:(AudioBufferList *)audioBufferList numberOfSamples:(UInt32)numberOfSamples completionHandler:(void(^)(void))completionHandler;

#if 0

@property (nonatomic, copy, readonly) NSArray *playbackVideoConnections;
@property (atomic, strong, readonly) NSString *playbackActiveVideoConnection;
- (BOOL)setPlaybackActiveVideoConnection:(NSString *)connection error:(NSError **)error;

@property (nonatomic, copy, readonly) NSArray *playbackAudioConnections;
@property (atomic, strong, readonly) NSString *playbackActiveAudioConnection;
- (BOOL)setPlaybackActiveAudioConnection:(NSString *)connection error:(NSError **)error;

- (BOOL)startPlaybackWithError:(NSError **)error;
- (void)stopPlayback;

#endif

#if 0
- (CMVideoFormatDescriptionRef)recordVideoFormatDescriptionWithDisplayMode:(int32_t)displayMode;
- (CMVideoFormatDescriptionRef)recordVideoFormatDescriptionWithName:(NSString *)name;

- (CMAudioFormatDescriptionRef)recordAudioFormatDescriptionWithName:(NSString *)name;

- (BOOL)startRecordWithError:(NSError **)error;
- (void)stopRecord;

- (void)recordPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)recordAudioBufferList:(const AudioBufferList *)audioBufferList numberOfSamples:(UInt32)numberOfSamples;

- (void)recordVideoData:(const void *)data presentationTimeStamp:(CMTime)presentationTimeStamp duration:(CMTime)duration;
- (void)recordVideoDataPresentationTimeStamp:(CMTime)presentationTimeStamp duration:(CMTime)duration frameCallbackHandler:(void(^)(void *data, int32_t width, int32_t height, int32_t bytesPerRow, CMPixelFormatType pixelFormat))callback;
#endif

@end
