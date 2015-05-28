#import "DeckLinkVideoConnection+Internal.h"


NSArray *DeckLinkVideoConnectionsFromBMDVideoConnection(BMDVideoConnection videoConnection)
{
	NSMutableArray *videoConnections = [NSMutableArray array];
	
	if (videoConnection & bmdVideoConnectionSDI)
	{
		[videoConnections addObject:DeckLinkVideoConnectionSDI];
	}
	if (videoConnection & bmdVideoConnectionHDMI)
	{
		[videoConnections addObject:DeckLinkVideoConnectionHDMI];
	}
	if (videoConnection & bmdVideoConnectionOpticalSDI)
	{
		[videoConnections addObject:DeckLinkVideoConnectionOpticalSDI];
	}
	if (videoConnection & bmdVideoConnectionComponent)
	{
		[videoConnections addObject:DeckLinkVideoConnectionComponent];
	}
	if (videoConnection & bmdVideoConnectionComposite)
	{
		[videoConnections addObject:DeckLinkVideoConnectionComposite];
	}
	if (videoConnection & bmdVideoConnectionSVideo)
	{
		[videoConnections addObject:DeckLinkVideoConnectionSVideo];
	}
	
	return videoConnections;
}

NSString *DeckLinkVideoConnectionFromBMDVideoConnection(BMDVideoConnection videoConnection)
{
	if (videoConnection == bmdVideoConnectionSDI)
	{
		return DeckLinkVideoConnectionSDI;
	}
	if (videoConnection == bmdVideoConnectionHDMI)
	{
		return DeckLinkVideoConnectionHDMI;
	}
	if (videoConnection == bmdVideoConnectionOpticalSDI)
	{
		return DeckLinkVideoConnectionOpticalSDI;
	}
	if (videoConnection == bmdVideoConnectionComponent)
	{
		return DeckLinkVideoConnectionComponent;
	}
	if (videoConnection == bmdVideoConnectionComposite)
	{
		return DeckLinkVideoConnectionComposite;
	}
	if (videoConnection == bmdVideoConnectionSVideo)
	{
		return DeckLinkVideoConnectionSVideo;
	}
	
	return nil;
}

BMDVideoConnection DeckLinkVideoConnectionToBMDVideoConnection(NSString *videoConnection)
{
	if ([videoConnection isEqualToString:DeckLinkVideoConnectionSDI])
	{
		return bmdVideoConnectionSDI;
	}
	if ([videoConnection isEqualToString:DeckLinkVideoConnectionHDMI])
	{
		return bmdVideoConnectionHDMI;
	}
	if ([videoConnection isEqualToString:DeckLinkVideoConnectionOpticalSDI])
	{
		return bmdVideoConnectionOpticalSDI;
	}
	if ([videoConnection isEqualToString:DeckLinkVideoConnectionComponent])
	{
		return bmdVideoConnectionComponent;
	}
	if ([videoConnection isEqualToString:DeckLinkVideoConnectionComposite])
	{
		return bmdVideoConnectionComposite;
	}
	if ([videoConnection isEqualToString:DeckLinkVideoConnectionSVideo])
	{
		return bmdVideoConnectionSVideo;
	}
	
	return 0;
}
