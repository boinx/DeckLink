#import <Foundation/Foundation.h>

#include "DeckLinkAPI.h"
#include <stdatomic.h>

// internal use only!

@protocol DeckLinkDeviceInternalInputCallbackDelegate <NSObject>
@required

- (void)didReceiveVideoFrame:(IDeckLinkVideoInputFrame *)videoFrame audioPacket:(IDeckLinkAudioInputPacket *)audioPacket;

@optional

- (void)didChangeVideoFormat:(BMDVideoInputFormatChangedEvents)changes displayMode:(IDeckLinkDisplayMode *)displayMode flags:(BMDDetectedVideoInputFormatFlags)flags;

@end


class DeckLinkDeviceInternalInputCallback : public IDeckLinkInputCallback
{
public:
	DeckLinkDeviceInternalInputCallback(id<DeckLinkDeviceInternalInputCallbackDelegate> delegate);
	
	// IDeckLinkInputCallback
	HRESULT VideoInputFormatChanged(BMDVideoInputFormatChangedEvents notificationEvents, IDeckLinkDisplayMode *newDisplayMode, BMDDetectedVideoInputFormatFlags detectedSignalFlags);
	HRESULT VideoInputFrameArrived(IDeckLinkVideoInputFrame* videoFrame, IDeckLinkAudioInputPacket* audioPacket);
	
	// IUnknown
	HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
	ULONG AddRef(void);
	ULONG Release(void);
	
private:
	id<DeckLinkDeviceInternalInputCallbackDelegate> delegate;
	atomic_int refCount;
};
