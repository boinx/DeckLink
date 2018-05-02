#import "DeckLinkDevice.h"

#import <CoreMedia/CoreMedia.h>
#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Internal.h"


@interface DeckLinkDevice (CaptureSetup)

- (void)setupCapture;

@end


@interface DeckLinkDevice (PlaybackSetup)

- (void)setupPlayback;

@end


@implementation DeckLinkDevice

// The getter for the read-only \c frameBufferCount must not be synthesized but will instead by provided by a category.
// Otherwise, the synthesized method and the category method would clash at runtime.
@dynamic frameBufferCount;

@synthesize deckLink = deckLink;

- (instancetype)initWithDeckLink:(IDeckLink *)deckLink_
{
	NSParameterAssert(deckLink_);
	
	self = [super init];
	if (self != nil)
	{
		deckLink = deckLink_;
		deckLink->AddRef();
		
		if (deckLink->QueryInterface(IID_IDeckLinkAttributes, (void **)&deckLinkAttributes) != S_OK)
		{
			return nil;
		}
		
		if (deckLink->QueryInterface(IID_IDeckLinkConfiguration, (void **)&deckLinkConfiguration) != S_OK)
		{
			return nil;
		}
		
		if (deckLink->QueryInterface(IID_IDeckLinkKeyer, (void **)&deckLinkKeyer) != S_OK)
		{
			// keyer may be nil
		}
		
		CFStringRef modelName = NULL;
		if (deckLink->GetModelName(&modelName) == S_OK)
		{
			self.modelName = CFBridgingRelease(modelName);
		}
		
		CFStringRef displayName = NULL;
		if (deckLink->GetDisplayName(&displayName) == S_OK)
		{
			self.displayName = CFBridgingRelease(displayName);
		}
		
		int64_t persistantID = 0;
		if(deckLinkAttributes->GetInt(BMDDeckLinkPersistentID, &persistantID) == S_OK)
		{
			self.persistantID = (int32_t)persistantID;
		}
		
		int64_t topologicalID = 0;
		if(deckLinkAttributes->GetInt(BMDDeckLinkTopologicalID, &topologicalID) == S_OK)
		{
			self.topologicalID = (int32_t)topologicalID;
		}
		
		[self setupCapture];
		[self setupPlayback];
	}
	return self;
}

- (void)dealloc
{
	if (deckLinkOutput != NULL)
	{
		deckLinkOutput->Release();
		deckLinkOutput = NULL;
	}
	
	if (deckLinkInputCallback != NULL)
	{
		deckLinkInputCallback->Release();
		deckLinkInputCallback = NULL;
	}
	
	if (deckLinkInput != NULL)
	{
		deckLinkInput->Release();
		deckLinkInput = NULL;
	}
	
	if (deckLinkKeyer != NULL)
	{
		deckLinkKeyer->Release();
		deckLinkKeyer = NULL;
	}
	
	if (deckLinkConfiguration != NULL)
	{
		deckLinkConfiguration->Release();
		deckLinkConfiguration = NULL;
	}
	
	if (deckLinkAttributes != NULL)
	{
		deckLinkAttributes->Release();
		deckLinkAttributes = NULL;
	}
	
	if (deckLink != NULL)
	{
		deckLink->Release();
		deckLink = NULL;
	}
}

@end
