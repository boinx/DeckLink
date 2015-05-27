#import "DeckLinkDevice.h"

#import "DeckLinkAPI.h"


@interface DeckLinkDevice ()
{
	IDeckLink *deckLink;
}
@end


@implementation DeckLinkDevice

- (instancetype)initWithDeckLink:(IDeckLink *)deckLink_
{
	NSParameterAssert(deckLink_);
	
	self = [super init];
	if (self != nil)
	{
		deckLink = deckLink_;
		deckLink->AddRef();
	}
	return self;
}

- (void)dealloc
{
	if (deckLink != NULL)
	{
		deckLink->Release();
	}
}

@end
