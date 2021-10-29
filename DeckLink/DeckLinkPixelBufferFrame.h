#pragma once

#include <CoreVideo/CoreVideo.h>
#include "DeckLinkAPI.h"
#include <stdatomic.h>

class DeckLinkPixelBufferFrame : public IDeckLinkVideoFrame
{
public:
	DeckLinkPixelBufferFrame(CVPixelBufferRef imageBuffer);
	
protected:
	virtual ~DeckLinkPixelBufferFrame();
	
public:
	// IDeckLinkVideoFrame
	virtual long GetWidth(void);
	virtual long GetHeight(void);
	virtual long GetRowBytes(void);
	virtual BMDPixelFormat GetPixelFormat(void);
	virtual BMDFrameFlags GetFlags(void);
	virtual void setFlags(BMDFrameFlags);
	virtual HRESULT GetBytes(void **buffer);
	
	virtual HRESULT GetTimecode(BMDTimecodeFormat format, IDeckLinkTimecode **timecode);
	virtual HRESULT GetAncillaryData(IDeckLinkVideoFrameAncillary **ancillary);
	
	// IUnknown
	virtual HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
	virtual ULONG AddRef(void);
	virtual ULONG Release(void);
	
private:
	CVPixelBufferRef pixelBuffer;
	bool locked;
	atomic_int refCount;
	BMDFrameFlags frameFlags;
};
