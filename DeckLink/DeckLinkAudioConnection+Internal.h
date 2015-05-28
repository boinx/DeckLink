#import "DeckLinkAudioConnection.h"

#import "DeckLinkAPI.h"

#ifdef __cplusplus
#define DECKLINK_EXTERN_C extern "C"
#else
#define DECKLINK_EXTERN_C
#endif


DECKLINK_EXTERN_C NSArray *DeckLinkAudioConnectionsFromBMDAudioConnection(BMDAudioConnection audioConnection);

DECKLINK_EXTERN_C NSString *DeckLinkAudioConnectionFromBMDAudioConnection(BMDAudioConnection audioConnection);

DECKLINK_EXTERN_C BMDAudioConnection DeckLinkAudioConnectionToBMDAudioConnection(NSString *audioConnection);
