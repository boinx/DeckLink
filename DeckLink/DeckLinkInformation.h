#import <Foundation/Foundation.h>


@interface DeckLinkInformation : NSObject

+ (instancetype)sharedInformation;

/**
 * Returns the API version.
 * Use NSNumericSearch to as option when comparing the value.
 */
- (NSString *)APIVersion;

@end
