#import "DeckLinkDeviceInternalInputCallback.h"

#include <stdatomic.h>

DeckLinkDeviceInternalInputCallback::DeckLinkDeviceInternalInputCallback(id<DeckLinkDeviceInternalInputCallbackDelegate> delegate) :
delegate(delegate),
refCount(1)
{
}

HRESULT DeckLinkDeviceInternalInputCallback::VideoInputFormatChanged(BMDVideoInputFormatChangedEvents notificationEvents, IDeckLinkDisplayMode *newDisplayMode, BMDDetectedVideoInputFormatFlags detectedSignalFlags)
{
	if([delegate respondsToSelector:@selector(didChangeVideoFormat:displayMode:flags:)])
	{
		[delegate didChangeVideoFormat:notificationEvents displayMode:newDisplayMode flags:detectedSignalFlags];
	}
	return S_OK;
}

HRESULT DeckLinkDeviceInternalInputCallback::VideoInputFrameArrived(IDeckLinkVideoInputFrame* videoFrame, IDeckLinkAudioInputPacket* audioPacket)
{
	if([delegate respondsToSelector:@selector(didReceiveVideoFrame:audioPacket:)])
	{
		[delegate didReceiveVideoFrame:videoFrame audioPacket:audioPacket];
	}
	return S_OK;
}

HRESULT DeckLinkDeviceInternalInputCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
	*ppv = NULL;
	
	CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
	if(memcmp(&iid, &iunknown, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	if(memcmp(&iid, &IID_IDeckLinkInputCallback, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	return E_NOINTERFACE;
}

ULONG DeckLinkDeviceInternalInputCallback::AddRef(void)
{
	return atomic_fetch_add(&refCount, 1);
}

ULONG DeckLinkDeviceInternalInputCallback::Release(void)
{
	int32_t oldRefValue = atomic_fetch_add(&refCount, -1);	// Note: atomic_fetch_add() returns the previous value
	int32_t newRefValue = oldRefValue - 1;
	
	if(newRefValue == 0)
	{
		delete this;
		return 0;
	}
	
	return newRefValue;
}
