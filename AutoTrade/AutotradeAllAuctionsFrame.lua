if (not AutotradeAllAuctionsPageInfo) then
	AutotradeAllAuctionsPageInfo = {};
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

AuctionsOpen = {};
AuctionsAllCancelled = {};

AllAuctionLists = {};
AllAuctionLists[AuctionTypeAllOpen] = AuctionsOpen;
AllAuctionLists[AuctionTypeAllCancelled] = AuctionsAllCancelled;

local function Autotrade_AdjustFilterHitRect(button)
	local text = getglobal(button:GetName().."Text");
	if (text and text.GetStringWidth)
	then
		button:SetHitRectInsets(0, -(text:GetStringWidth() + 4), 0, 0);
	end
end

function AutotradeAllAuctionsFrame_OnLoad()
	if (not PageInfoByFrameName) then
		PageInfoByFrameName = {};
	end

	PageInfoByFrameName.AutotradeAllAuctionsFrame = AutotradeAllAuctionsPageInfo;

	AutotradeAllAuctionTypesList = {AuctionTypeAllOpen, AuctionTypeAllCancelled};

	AutotradeAllAuctionsPageInfo.frame = AutotradeAllAuctionsFrame;
	AutotradeAllAuctionsPageInfo.scrollFrame = AutotradeAllAuctionsListScrollFrame;
	AutotradeAllAuctionsPageInfo.highlightFrame = AutotradeAllAuctionsHighlightFrame;
	AutotradeAllAuctionsPageInfo.itemButtonName = "AutotradeAllAuctionsItem";
	AutotradeAllAuctionsPageInfo.itemIcon = AutotradeAllAuctionsItemIcon;
	AutotradeAllAuctionsPageInfo.itemIconCount = AutotradeAllAuctionsItemIconCount;
	AutotradeAllAuctionsPageInfo.itemName = AutotradeAllAuctionsItemName;
	AutotradeAllAuctionsPageInfo.upperMoneyFrame = AutotradeAllAuctionsBidMoneyFrameUpper;
	AutotradeAllAuctionsPageInfo.lowerMoneyFrame = AutotradeAllAuctionsBidMoneyFrameLower;
	AutotradeAllAuctionsPageInfo.upperMoneyLabel = AutotradeAllAuctionsBidLabelUpper;
	AutotradeAllAuctionsPageInfo.lowerMoneyLabel = AutotradeAllAuctionsBidLabelLower;
	AutotradeAllAuctionsPageInfo.upperMoneySubText = AutotradeAllAuctionsBidLabelUpperSubText;
	AutotradeAllAuctionsPageInfo.lowerMoneySubText = AutotradeAllAuctionsBidLabelLowerSubText;
	AutotradeAllAuctionsPageInfo.ownerLabel = AutotradeAllAuctionsOwnerLabel;
	AutotradeAllAuctionsPageInfo.ownerName = AutotradeAllAuctionsOwnerName;
	AutotradeAllAuctionsPageInfo.ownerLocation = AutotradeAllAuctionsOwnerLocation;
	AutotradeAllAuctionsPageInfo.timeLabel = AutotradeAllAuctionsTimeLabel;
	AutotradeAllAuctionsPageInfo.timeText = AutotradeAllAuctionsTimeText;
	AutotradeAllAuctionsPageInfo.wishListCheckbox = AutotradeAllAuctionsWishListButton;
	AutotradeAllAuctionsPageInfo.acceptButton = AutotradeAllAuctionsAcceptButton;
	AutotradeAllAuctionsPageInfo.removeButton = AutotradeAllAuctionsRemoveButton;
	AutotradeAllAuctionsPageInfo.meetInText = AutotradeAllAuctionsMeetInText;
	AutotradeAllAuctionsPageInfo.meetInButton = AutotradeAllAuctionsMeetInButton;
	AutotradeAllAuctionsPageInfo.auctionTypesList = AutotradeAllAuctionTypesList;
	AutotradeAllAuctionsPageInfo.auctionLists = AllAuctionLists;
	AutotradeAllAuctionsPageInfo.saleText = "For sale by:";
	AutotradeAllAuctionsPageInfo.auctionText = "For auction by:";
  
	AutotradeAllAuctionsZoneButtonText:SetText(GLOBAL_ZONE_TAG_C);
	AutotradeAllAuctionsItemButtonText:SetText(GLOBAL_ITEM_TAG_C);
	Autotrade_AdjustFilterHitRect(AutotradeAllAuctionsItemButton);
	Autotrade_AdjustFilterHitRect(AutotradeAllAuctionsZoneButton);
	if (AutotradeAllAuctionsWishListButtonText)
	then
		AutotradeAllAuctionsWishListButtonText:SetText(AUTOTRADE_WISH_LIST);
	end
	AutotradeAllAuctionsBidMoneyFrameLower.autotradePageInfo = AutotradeAllAuctionsPageInfo;
	AutotradeAllAuctionsBidMoneyFrameLower.autotradeMoneyKind = "bid";
	AutotradeAllAuctionsBidMoneyFrameLower:EnableMouse(true);
	AutotradeAllAuctionsBidMoneyFrameLower:SetScript("OnMouseDown", Autotrade_MoneyFrame_OnClick);
	Autotrade_NoteFrameLoaded();
end
