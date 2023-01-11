#import <DeckLink/DeckLinkDevice.h>

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>


@interface DeckLinkDevice (Status)

-(NSArray*)getStatusReport;

@end
