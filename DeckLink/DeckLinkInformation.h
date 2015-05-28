#import <Foundation/Foundation.h>


@interface DeckLinkInformation : NSObject

+ (instancetype)sharedInformation;

/**
 * Returns the API version.
 * Example: 10.3.7
 * Use NSNumericSearch as option when comparing the value.
 */
- (NSString *)APIVersion;

@end
