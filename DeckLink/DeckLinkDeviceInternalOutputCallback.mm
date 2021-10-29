#import "DeckLinkDeviceInternalOutputCallback.h"

#include <stdatomic.h>

DeckLinkDeviceInternalOutputCallback::DeckLinkDeviceInternalOutputCallback(id<DeckLinkDeviceInternalOutputCallbackDelegate> delegate) :
delegate(delegate),
refCount(1)
{
}

HRESULT DeckLinkDeviceInternalOutputCallback::ScheduledFrameCompleted(IDeckLinkVideoFrame *completedFrame, BMDOutputFrameCompletionResult result)
{
	if([delegate respondsToSelector:@selector(scheduledFrameCompleted:result:)])
	{
		[delegate scheduledFrameCompleted:completedFrame result:result];
	}
	return S_OK;
}

HRESULT DeckLinkDeviceInternalOutputCallback::ScheduledPlaybackHasStopped(void)
{
	if([delegate respondsToSelector:@selector(scheduledPlaybackHasStopped)])
	{
		[delegate scheduledPlaybackHasStopped];
	}
	return S_OK;
}

HRESULT DeckLinkDeviceInternalOutputCallback::RenderAudioSamples(bool preroll)
{
	if([delegate respondsToSelector:@selector(renderAudioSamplesPreroll:)])
	{
		[delegate renderAudioSamplesPreroll:preroll ? YES : NO];
	}
	return S_OK;
}

HRESULT DeckLinkDeviceInternalOutputCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
	*ppv = NULL;
	
	CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
	if(memcmp(&iid, &iunknown, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	if(memcmp(&iid, &IID_IDeckLinkVideoOutputCallback, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	if(memcmp(&iid, &IID_IDeckLinkAudioOutputCallback, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	return E_NOINTERFACE;
}

ULONG DeckLinkDeviceInternalOutputCallback::AddRef(void)
{
	return atomic_fetch_add_explicit(&refCount, 1, memory_order_relaxed);
}

ULONG DeckLinkDeviceInternalOutputCallback::Release(void)
{
	int32_t newRefValue = atomic_fetch_add_explicit(&refCount, -1, memory_order_relaxed);
	if(newRefValue == 0)
	{
		delete this;
		return 0;
	}
	
	return newRefValue;
}
