if (not AutotradeBidAuctionsPageInfo) then
	AutotradeBidAuctionsPageInfo = {};
end

AuctionTypeDraft = "Draft";
AuctionTypeOpen = "Open";
AuctionTypeClosed = "Closed";
AuctionTypeAllOpen = "All Open";
AuctionTypeAllCancelled = "All Cancelled"
AuctionTypeBidOpen = "Bidding";
AuctionTypeBidWon = "Won";
AuctionTypeBidLost = "Lost";
AuctionTypeBidCancelled = "Cancelled";

AuctionsBidOpen = {};
AuctionsBidWon = {};
AuctionsBidLost = {};
AuctionsBidCancelled  = {};

BidAuctionLists = {};
BidAuctionLists[AuctionTypeBidOpen] = AuctionsBidOpen;
BidAuctionLists[AuctionTypeBidWon] = AuctionsBidWon;
BidAuctionLists[AuctionTypeBidLost] = AuctionsBidLost;
BidAuctionLists[AuctionTypeBidCancelled] = AuctionsBidCancelled;

function AutotradeBidAuctionsFrame_OnLoad()
	if (not PageInfoByFrameName) then
		PageInfoByFrameName = {};
	end
	PageInfoByFrameName.AutotradeBidAuctionsFrame = AutotradeBidAuctionsPageInfo;

	AutotradeBidAuctionTypesList = {AuctionTypeBidOpen, AuctionTypeBidWon, AuctionTypeBidLost, AuctionTypeBidCancelled};

	AutotradeBidAuctionsPageInfo.frame = AutotradeBidAuctionsFrame;
	AutotradeBidAuctionsPageInfo.scrollFrame = AutotradeBidAuctionsListScrollFrame;
	AutotradeBidAuctionsPageInfo.highlightFrame = AutotradeBidAuctionsHighlightFrame;
	AutotradeBidAuctionsPageInfo.itemButtonName = "AutotradeBidAuctionsItem";
	AutotradeBidAuctionsPageInfo.itemIcon = AutotradeBidAuctionsItemIcon;
	AutotradeBidAuctionsPageInfo.itemIconCount = AutotradeBidAuctionsItemIconCount;
	AutotradeBidAuctionsPageInfo.itemName = AutotradeBidAuctionsItemName;
	AutotradeBidAuctionsPageInfo.upperMoneyFrame = AutotradeBidAuctionsBidMoneyFrameUpper;
	AutotradeBidAuctionsPageInfo.lowerMoneyFrame = AutotradeBidAuctionsBidMoneyFrameLower;
	AutotradeBidAuctionsPageInfo.upperMoneyLabel = AutotradeBidAuctionsBidLabelUpper;
	AutotradeBidAuctionsPageInfo.lowerMoneyLabel = AutotradeBidAuctionsBidLabelLower;
	AutotradeBidAuctionsPageInfo.upperMoneySubText = AutotradeBidAuctionsBidLabelUpperSubText;
	AutotradeBidAuctionsPageInfo.lowerMoneySubText = AutotradeBidAuctionsBidLabelLowerSubText;
	AutotradeBidAuctionsPageInfo.ownerLabel = AutotradeBidAuctionsOwnerLabel;
	AutotradeBidAuctionsPageInfo.ownerName = AutotradeBidAuctionsOwnerName;
	AutotradeBidAuctionsPageInfo.ownerLocation = AutotradeBidAuctionsOwnerLocation;
	AutotradeBidAuctionsPageInfo.timeLabel = AutotradeBidAuctionsTimeLabel;
	AutotradeBidAuctionsPageInfo.timeText = AutotradeBidAuctionsTimeText;
	AutotradeBidAuctionsPageInfo.wishListCheckbox = AutotradeBidAuctionsWishListButton;
	AutotradeBidAuctionsPageInfo.wishListAutoRemoveCheckbox = AutotradeBidAuctionsAutoRemoveButton;
	AutotradeBidAuctionsPageInfo.acceptButton = AutotradeBidAuctionsAcceptButton;
	AutotradeBidAuctionsPageInfo.removeButton = AutotradeBidAuctionsRemoveButton;
	AutotradeBidAuctionsPageInfo.meetInText = AutotradeBidAuctionsMeetInText;
	AutotradeBidAuctionsPageInfo.meetInButton = AutotradeBidAuctionsMeetInButton;
	AutotradeBidAuctionsPageInfo.auctionTypesList = AutotradeBidAuctionTypesList;
	AutotradeBidAuctionsPageInfo.auctionLists = BidAuctionLists;
	AutotradeBidAuctionsPageInfo.saleText = "For sale by:";
	AutotradeBidAuctionsPageInfo.auctionText = "For auction by:";

end
