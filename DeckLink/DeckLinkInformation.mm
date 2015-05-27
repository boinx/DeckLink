#import "DeckLinkInformation.h"

#import "DeckLinkAPI.h"


@interface DeckLinkInformation ()
{
	IDeckLinkAPIInformation *deckLinkInformation;
}
@end


@implementation DeckLinkInformation

+ (instancetype)sharedInformation
{
	static DeckLinkInformation *information = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		information = [[self alloc] init];
	});
	
	return information;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
	{
		deckLinkInformation = CreateDeckLinkAPIInformationInstance();
		if (deckLinkInformation == NULL)
		{
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	if (deckLinkInformation != NULL)
	{
		deckLinkInformation->Release();
		deckLinkInformation = NULL;
	}
}

- (NSString *)APIVersion
{
	CFStringRef value = NULL;
	if (deckLinkInformation->GetString(BMDDeckLinkAPIVersion, &value) != S_OK)
	{
		return nil;
	}
	
	return CFBridgingRelease(value);
}

@end
