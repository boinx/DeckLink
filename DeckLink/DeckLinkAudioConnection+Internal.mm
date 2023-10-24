#import "DeckLinkAudioConnection+Internal.h"


NSArray *DeckLinkAudioConnectionsFromBMDAudioConnection(BMDAudioConnection audioConnection)
{
	NSMutableArray *audioConnections = [NSMutableArray array];
	
	if (audioConnection & bmdAudioConnectionEmbedded)
	{
		[audioConnections addObject:DeckLinkAudioConnectionEmbedded];
	}
	if (audioConnection & bmdAudioConnectionAESEBU)
	{
		[audioConnections addObject:DeckLinkAudioConnectionAESEBU];
	}
	if (audioConnection & bmdAudioConnectionAnalog)
	{
		[audioConnections addObject:DeckLinkAudioConnectionAnalog];
	}
	if (audioConnection & bmdAudioConnectionAnalogXLR)
	{
		[audioConnections addObject:DeckLinkAudioConnectionAnalogXLR];
	}
	if (audioConnection & bmdAudioConnectionAnalogRCA)
	{
		[audioConnections addObject:DeckLinkAudioConnectionAnalogRCA];
	}
	if (audioConnection & bmdAudioConnectionMicrophone)
	{
		[audioConnections addObject:DeckLinkAudioConnectionMicrophone];
	}
	if (audioConnection & bmdAudioConnectionHeadphones)
	{
		[audioConnections addObject:DeckLinkAudioConnectionHeadphones];
	}

	return audioConnections;
}

NSString *DeckLinkAudioConnectionFromBMDAudioConnection(BMDAudioConnection audioConnection)
{
	if (audioConnection == bmdAudioConnectionEmbedded)
	{
		return DeckLinkAudioConnectionEmbedded;
	}
	if (audioConnection == bmdAudioConnectionAESEBU)
	{
		return DeckLinkAudioConnectionAESEBU;
	}
	if (audioConnection == bmdAudioConnectionAnalog)
	{
		return DeckLinkAudioConnectionAnalog;
	}
	if (audioConnection == bmdAudioConnectionAnalogXLR)
	{
		return DeckLinkAudioConnectionAnalogXLR;
	}
	if (audioConnection == bmdAudioConnectionAnalogRCA)
	{
		return DeckLinkAudioConnectionAnalogRCA;
	}
	if (audioConnection == bmdAudioConnectionMicrophone)
	{
		return DeckLinkAudioConnectionMicrophone;
	}
	if (audioConnection == bmdAudioConnectionHeadphones)
	{
		return DeckLinkAudioConnectionHeadphones;
	}

	return nil;
}

BMDAudioConnection DeckLinkAudioConnectionToBMDAudioConnection(NSString *audioConnection)
{
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionEmbedded])
	{
		return bmdAudioConnectionEmbedded;
	}
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionAESEBU])
	{
		return bmdAudioConnectionAESEBU;
	}
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionAnalog])
	{
		return bmdAudioConnectionAnalog;
	}
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionAnalogXLR])
	{
		return bmdAudioConnectionAnalogXLR;
	}
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionAnalogRCA])
	{
		return bmdAudioConnectionAnalogRCA;
	}
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionMicrophone])
	{
		return bmdAudioConnectionMicrophone;
	}
	if ([audioConnection isEqualToString:DeckLinkAudioConnectionHeadphones])
	{
		return bmdAudioConnectionHeadphones;
	}

	return 0;
}
