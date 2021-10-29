#import <Foundation/Foundation.h>

#import "DeckLinkAPI.h"
#include <stdatomic.h>

// internal use only!

@protocol DeckLinkDeviceBrowserInternalCallbackDelegate <NSObject>
@required

- (void)didAddDeckLink:(IDeckLink *)deckLink;
- (void)didRemoveDeckLink:(IDeckLink *)deckLink;

@end


class DeckLinkDeviceBrowserInternalCallback : public IDeckLinkDeviceNotificationCallback
{
public:
	DeckLinkDeviceBrowserInternalCallback(id<DeckLinkDeviceBrowserInternalCallbackDelegate> delegate);
	
	// IDeckLinkDeviceNotificationCallback
	HRESULT DeckLinkDeviceArrived(IDeckLink *deckLink);
	HRESULT DeckLinkDeviceRemoved(IDeckLink *deckLink);
	
	// IUnknown
	HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
	ULONG AddRef(void);
	ULONG Release(void);
	
private:
	id<DeckLinkDeviceBrowserInternalCallbackDelegate> delegate;
	atomic_int refCount;
};
