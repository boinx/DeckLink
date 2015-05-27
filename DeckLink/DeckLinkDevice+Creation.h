#import "DeckLinkDevice.h"

#import "DeckLinkAPI.h"


@interface DeckLinkDevice (Creation)

- (instancetype)initWithDeckLink:(IDeckLink *)deckLink;

@property (nonatomic, assign, readonly) IDeckLink *deckLink;

@end
