#import "DeckLinkDevice.h"

#import "DeckLinkAPI.h"
#import "DeckLinkDevice+Internal.h"


@interface DeckLinkDevice (CaptureSetup)

- (void)setupCapture;

@end


@implementation DeckLinkDevice

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
	}
	return self;
}

- (void)dealloc
{
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
