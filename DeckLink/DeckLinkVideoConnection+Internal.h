#import "DeckLinkVideoConnection.h"

#import "DeckLinkAPI.h"

#ifdef __cplusplus
#define DECKLINK_EXTERN_C extern "C"
#else
#define DECKLINK_EXTERN_C
#endif


DECKLINK_EXTERN_C NSArray *DeckLinkVideoConnectionsFromBMDVideoConnection(BMDVideoConnection videoConnection);

DECKLINK_EXTERN_C NSString *DeckLinkVideoConnectionFromBMDVideoConnection(BMDVideoConnection videoConnection);

DECKLINK_EXTERN_C BMDVideoConnection DeckLinkVideoConnectionToBMDVideoConnection(NSString *videoConnection);
