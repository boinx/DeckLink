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

/**
 * Indicates if the pixelformat is supported natively by the device.
 * CFNumberRef (Boolean)
 */
extern CFStringRef const DeckLinkFormatDescriptionNativeDisplayModeSupportKey;


OSStatus CMVideoFormatDescriptionCreateWithDeckLinkDisplayMode(IDeckLinkDisplayMode *displayMode, CMVideoCodecType pixelFormat, Boolean nativePixelFormatSupport, CMVideoFormatDescriptionRef *outFormatDescription);

OSStatus CMVideoFormatDescriptionGetDeckLinkFrameRate(CMFormatDescriptionRef formatDescription, CMTime *outFrameRate);

#ifdef __cplusplus
} /* extern "C" */
#endif
