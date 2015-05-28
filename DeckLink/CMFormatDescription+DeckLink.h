#include <CoreMedia/CoreMedia.h>

#ifdef __cplusplus
class IDeckLinkDisplayMode;
#else
typedef struct IDeckLinkDisplayMode IDeckLinkDisplayMode;
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * CFNumberRef (BMDDisplayMode)
 */
extern CFStringRef const DeckLinkFormatDescriptionDisplayModeKey;

/**
 * CFDictionaryRef can be used to create a CMTime
 */
extern CFStringRef const DeckLinkFormatDescriptionFrameRateKey;


OSStatus CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(IDeckLinkDisplayMode *displayMode, CMVideoCodecType pixelFormat, CMVideoFormatDescriptionRef *outFormatDescription);

OSStatus CMVideoFormatDescriptionGetDeckLinkFrameRate(CMFormatDescriptionRef formatDescription, CMTime *outFrameRate);

#ifdef __cplusplus
} /* extern "C" */
#endif
