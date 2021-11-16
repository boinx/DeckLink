#import "DeckLinkDeviceBrowserInternalCallback.h"

#include <stdatomic.h>

DeckLinkDeviceBrowserInternalCallback::DeckLinkDeviceBrowserInternalCallback(id<DeckLinkDeviceBrowserInternalCallbackDelegate> delegate) :
delegate(delegate), refCount(1)
{
}

HRESULT DeckLinkDeviceBrowserInternalCallback::DeckLinkDeviceArrived(IDeckLink *deckLink)
{
	[delegate didAddDeckLink:deckLink];
	return S_OK;
}

HRESULT DeckLinkDeviceBrowserInternalCallback::DeckLinkDeviceRemoved(IDeckLink *deckLink)
{
	[delegate didRemoveDeckLink:deckLink];
	return S_OK;
}

HRESULT DeckLinkDeviceBrowserInternalCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
	// Initialise the return result
	*ppv = NULL;
	
	// Obtain the IUnknown interface and compare it the provided REFIID
	CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
	if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	if (memcmp(&iid, &IID_IDeckLinkDeviceNotificationCallback, sizeof(REFIID)) == 0)
	{
		*ppv = (IDeckLinkDeviceNotificationCallback *)this;
		AddRef();
		return S_OK;
	}
	
	return E_NOINTERFACE;
}

ULONG DeckLinkDeviceBrowserInternalCallback::AddRef(void)
{
	return atomic_fetch_add(&refCount, 1);
}

ULONG DeckLinkDeviceBrowserInternalCallback::Release(void)
{
	int32_t oldRefValue = atomic_fetch_add(&refCount, -1);	// Note: atomic_fetch_add() returns the previous value
	int32_t newRefValue = oldRefValue - 1;
	
	if (newRefValue == 0)
	{
		delete this;
		return 0;
	}
	
	return newRefValue;
}
