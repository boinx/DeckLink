#include "DeckLinkPixelBufferFrame.h"

#include <stdatomic.h>

DeckLinkPixelBufferFrame::DeckLinkPixelBufferFrame(CVPixelBufferRef pixelBuffer) :
pixelBuffer(pixelBuffer),
locked(false),
frameFlags(bmdFrameFlagDefault),
refCount(1)
{
	CFRetain(pixelBuffer);
}

DeckLinkPixelBufferFrame::~DeckLinkPixelBufferFrame()
{
	if(locked)
	{
		CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
	}
	
	CFRelease(pixelBuffer);
}

long DeckLinkPixelBufferFrame::GetWidth(void)
{
	return (long)CVPixelBufferGetWidth(pixelBuffer);
}

long DeckLinkPixelBufferFrame::GetHeight(void)
{
	return (long)CVPixelBufferGetHeight(pixelBuffer);
}

long DeckLinkPixelBufferFrame::GetRowBytes(void)
{
	return (long)CVPixelBufferGetBytesPerRow(pixelBuffer);
}

BMDPixelFormat DeckLinkPixelBufferFrame::GetPixelFormat(void)
{
	return (BMDPixelFormat)CVPixelBufferGetPixelFormatType(pixelBuffer);
}

BMDFrameFlags DeckLinkPixelBufferFrame::GetFlags(void)
{
	return frameFlags;
}

HRESULT DeckLinkPixelBufferFrame::GetBytes(void **buffer)
{
	if(buffer == NULL)
	{
		return E_FAIL;
	}
	
	if(!locked)
	{
		if(CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess)
		{
			return E_FAIL;
		}
		locked = true;
	}
	
	*buffer = CVPixelBufferGetBaseAddress(pixelBuffer);
	return S_OK;
}

HRESULT DeckLinkPixelBufferFrame::GetTimecode(BMDTimecodeFormat format, IDeckLinkTimecode **timecode)
{
	// TODO:
	return E_FAIL;
}

HRESULT DeckLinkPixelBufferFrame::GetAncillaryData(IDeckLinkVideoFrameAncillary **ancillary)
{
	// TODO:
	return E_FAIL;
}

HRESULT DeckLinkPixelBufferFrame::QueryInterface(REFIID iid, LPVOID *ppv)
{
	*ppv = NULL;
	
	CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
	if(memcmp(&iid, &iunknown, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	if(memcmp(&iid, &IID_IDeckLinkVideoFrame, sizeof(REFIID)) == 0)
	{
		*ppv = this;
		AddRef();
		return S_OK;
	}
	
	return E_NOINTERFACE;
}


void DeckLinkPixelBufferFrame::setFlags(BMDFrameFlags flag)
{
	frameFlags = flag;
	
}

ULONG DeckLinkPixelBufferFrame::AddRef(void)
{
	return atomic_fetch_add(&refCount, 1);
}

ULONG DeckLinkPixelBufferFrame::Release(void)
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
