#import <Foundation/Foundation.h>

#include "DeckLinkAPI.h"
#include <stdatomic.h>


// internal use only!

@protocol DeckLinkDeviceInternalOutputCallbackDelegate <NSObject>
@optional

- (void)scheduledFrameCompleted:(IDeckLinkVideoFrame *)frame result:(BMDOutputFrameCompletionResult)result;
- (void)scheduledPlaybackHasStopped;
- (void)renderAudioSamplesPreroll:(BOOL)preroll;

@end


class DeckLinkDeviceInternalOutputCallback : public IDeckLinkVideoOutputCallback, public IDeckLinkAudioOutputCallback
{
public:
	DeckLinkDeviceInternalOutputCallback(id<DeckLinkDeviceInternalOutputCallbackDelegate> delegate);
	
	// IDeckLinkVideoOutputCallback
	HRESULT ScheduledFrameCompleted(IDeckLinkVideoFrame *completedFrame, BMDOutputFrameCompletionResult result);
	HRESULT ScheduledPlaybackHasStopped(void);
	
	// IDeckLinkAudioOutputCallback
	HRESULT RenderAudioSamples(bool preroll);
	
	// IUnknown
	HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
	ULONG AddRef(void);
	ULONG Release(void);
	
private:
	id<DeckLinkDeviceInternalOutputCallbackDelegate> delegate;
	atomic_int refCount;
};
