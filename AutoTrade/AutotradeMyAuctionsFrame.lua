if (not AutotradeMyAuctionsPageInfo) then
	AutotradeMyAuctionsPageInfo = {};
end

AuctionTypeDraft = "Draft";
AuctionTypeOpen = "Open";
AuctionTypeClosed = "Closed";
AuctionTypeMyCancelled = "Aborted";
AuctionTypeAllOpen = "All Open";
AuctionTypeBidOpen = "Bidding";
AuctionTypeBidWon = "Won";
AuctionTypeBidLost = "Lost";

AuctionsMyDraft = {};  -- "pre" auctions haven't gone live yet
AuctionsMyOpen = {}; -- "open" auctions are running
AuctionsMyClosed = {}; -- "closed" auctions have terminated and are awaiting item delivery or are fully complete.
AuctionsMyCancelled = {}; -- "cancelled" auctions have terminated because this user left the autotrade channel.

MyAuctionLists = {};
MyAuctionLists[AuctionTypeDraft] = AuctionsMyDraft;
MyAuctionLists[AuctionTypeOpen] = AuctionsMyOpen;
MyAuctionLists[AuctionTypeClosed] = AuctionsMyClosed;
MyAuctionLists[AuctionTypeMyCancelled] = AuctionsMyCancelled;


function AutotradeMyAuctionsFrame_OnLoad()
	if (not PageInfoByFrameName) then
		PageInfoByFrameName = {};
	end
	PageInfoByFrameName.AutotradeMyAuctionsFrame = AutotradeMyAuctionsPageInfo;
	AutotradeMyAuctionTypesList = {AuctionTypeDraft, AuctionTypeOpen, AuctionTypeClosed, AuctionTypeMyCancelled};
	AutotradeMyAuctionsPageInfo.frame = AutotradeMyAuctionsFrame;
	AutotradeMyAuctionsPageInfo.scrollFrame = AutotradeMyAuctionsListScrollFrame;
	AutotradeMyAuctionsPageInfo.highlightFrame = AutotradeMyAuctionsHighlightFrame;
	AutotradeMyAuctionsPageInfo.itemButtonName = "AutotradeMyAuctionsItem";
	AutotradeMyAuctionsPageInfo.itemIcon = AutotradeMyAuctionsItemIcon;
	AutotradeMyAuctionsPageInfo.itemIconCount = AutotradeMyAuctionsItemIconCount;
	AutotradeMyAuctionsPageInfo.itemName = AutotradeMyAuctionsItemName;
	AutotradeMyAuctionsPageInfo.upperMoneyFrame = AutotradeMyAuctionsBidMoneyFrameUpper;
	AutotradeMyAuctionsPageInfo.lowerMoneyFrame = AutotradeMyAuctionsBidMoneyFrameLower;
	AutotradeMyAuctionsPageInfo.upperMoneyLabel = AutotradeMyAuctionsBidLabelUpper;
	AutotradeMyAuctionsPageInfo.lowerMoneyLabel = AutotradeMyAuctionsBidLabelLower;
	AutotradeMyAuctionsPageInfo.upperMoneySubText = AutotradeMyAuctionsBidLabelUpperSubText;
	AutotradeMyAuctionsPageInfo.lowerMoneySubText = AutotradeMyAuctionsBidLabelLowerSubText;
	AutotradeMyAuctionsPageInfo.ownerLabel = AutotradeMyAuctionsOwnerLabel;
	AutotradeMyAuctionsPageInfo.timeLabel = AutotradeMyAuctionsTimeLabel;
	AutotradeMyAuctionsPageInfo.timeText = AutotradeMyAuctionsTimeText;
	AutotradeMyAuctionsPageInfo.acceptButton = AutotradeMyAuctionsAcceptButton;
	AutotradeMyAuctionsPageInfo.removeButton = AutotradeMyAuctionsRemoveButton;
	AutotradeMyAuctionsPageInfo.meetInText = AutotradeMyAuctionsMeetInText;
	AutotradeMyAuctionsPageInfo.meetInButton = AutotradeMyAuctionsMeetInButton;
	AutotradeMyAuctionsPageInfo.auctionTypesList = AutotradeMyAuctionTypesList;
	AutotradeMyAuctionsPageInfo.auctionLists = MyAuctionLists;
	AutotradeMyAuctionsPageInfo.shorterButton = AutotradeMyAuctionsShorterButton;
	AutotradeMyAuctionsPageInfo.longerButton = AutotradeMyAuctionsLongerButton;
	AutotradeMyAuctionsPageInfo.saleText = "Format: Sale";
	AutotradeMyAuctionsPageInfo.auctionText = "Format: Auction";
	AutotradeMyAuctionsPageInfo.changeSellMethodButton = AutotradeMyAuctionsChangeSellFormatButton;
end
