-- AutoTrade.lua
-- Auction/trade automator and logger
-- Copyright (c) 2004 Evan Gridley

-- RELEASE PROCEDURE
-- Set debug level to 0
-- Turn off debug communication
-- set isOwner back to normal settings

-- To-do list (bugs & housekeeping):
--	Fix for beta 3!  ***DONE*** just in time for beta 4 :P
--	Allow straight-up sales in addition to Auctions. ***DONE***
--	Ignore list?
--	Cut callback functions now that vars are globally accessible
--	Add button to restart a failed auction ***DONE*** (creates a copy instead of removing the old one)
--	Fix bug where scrolling gets messed up
--	Fix bug where owner sometimes won't see bids in the UI, but will successfully sell an item
--	Fix phantom "outbid" messages. ***DONE***
--	Fix bug where links to cancelled auctions weren't working ***DONE***
--	Fix filter picker background color ***DONE***
--	Fix notifications ***DONE***
--	Fix new auction notifications to include item quantity ***DONE***
--	Fix Collapse All button ***DONE***
--	Fix money popup disappearing when new auction received ***DONE***
--	Fix min bid getting reset to zero when anyone bids ***DONE***
--	Fix bid getting reset to default when anyone bids ***DONE***
--	Set up zone filter ***DONE***
--	Set up item filter ***DONE***
--	Hook up Going Once and Going Twice notifications ***DONE***
--	Allow multi-stack auctions ***DONE***
--	Move popup text location after mouseover ***DONE*** kinda lame though
--	Bug: in unnamed area, cannot send auction (area name is blank or nil or something) ***DONE***???
--
--	UI for editing wish list in bulk
--	queue up messages to send, send them every N seconds instead of all the time (prevent players getting kicked off)
--	queue up incoming messages in the chat handler, and process them in order in the OnUpdate handler.
--	Clean up bid & all auction lists after a while (i.e. junk leftover if when a seller disappears during an auction) ***DONE***
--	Toggling headers doesn't work ***DONE***

-- Planned features:
-- Main "tabbed" UI window showing auctions ***DONE***
-- Mini-window for notifications, shows w/ last N events, drag/drop target for starting auctions (does it need this now that there are chat notifications?)
-- Show what zones the buyer and seller were most recently known to be in ***DONE***
-- Show what zone the seller plans to be in to make the trade ***DONE***
-- Zone-specific channels so you're not stuck in world chat only

-- Seller UI
-- completed auction history
-- Drag & drop auto-selects new auction ***DONE***
-- notification of closed auction ***DONE***
-- drag & drop to choose item to auction and/or to start auction ***DONE***
-- Item count automatically included ***DONE***
-- Automatically close auctions and notify you of winners (if certain format is met) ***DONE***
-- show countdown on auctions you're in ***DONE***
-- Set min bid ***DONE***
-- Set auction time **DONE**
-- Set sell price ***DONE***
-- Show bidder list

-- Buyer UI
-- Wish List ***DONE***
-- Add/change checkbox from Item Type to Item Quality ***DONE*** but still not active
-- Next bid is auto-populated with a reasonable bid, if you can afford ***DONE***
-- auto-bidding up to a chosen max bid?
-- bid history on live auctions
-- failed auction history?
-- list of items you're looking for, notification when item comes up ***DONE*** need nice UI for it tho
-- show best bid on auctions you're participating in ***DONE***
-- notification when you win an auction ***DONE***
-- notification when you are outbid ***DONE***
-- Show last-known zone of owner **DONE**
-- Allow filtering/sorting by: seller zone ***DONE***, item types ***DONE***, seller name

-- Misc UI
-- Price history by item UI (use Thottbot)
-- tagging sold items in your inventory so you can easily find them
-- Automatic population of trade window (won't need to tag them in this case I guess?)
-- Options for receiving notifications **DONE**
-- Change main text color from red/green to item quality color (keep bid color based on affordability) ***DONE***

-- Infrastructure
-- Send duplicate Sell or Update message periodically during a long auction if it's idle ***DONE***
-- Changed messaging model (only scans channels now) ***DONE***
-- special message format to allow automatic auction management ***DONE***
-- parsing of regular WTB/WTS messages **WON'T FIX**


-- Todos
-- get "$" icon from cursors file, use as top-left portrait icon. ***DONE***




-- Global vars.  Other files have to reference these.


mouse_item = "";

Autotrade_ModEnabled = true;
UIPanelWindows["AutotradeFrame"] =		{ area = "left",	pushable = 8 };

AUTO_TRADE_DRAGGED_ITEM_INFO = nil;
AUTO_TRADE_DRAGGED_ITEM_SOURCE_BUTTON = nil;
AUTO_TRADE_DRAGGED_ITEM_SOURCE_TYPE = nil;

-- bug? Making this local makes it fail when i pass it as an arg to FauxScroll_Update
AUTO_TRADE_ITEM_HEIGHT = 16;

AuctionsMyOpen = {};
AuctionsOpen = {};
AuctionsBidsOpen = {};

-- Frames
local AutotradeSubFrames = { "AutotradeMyAuctionsFrame", "AutotradeBidAuctionsFrame", "AutotradeAllAuctionsFrame" };

-- Strings in the UI:
local PriceString = "Price:";
local MinBidString = "Min bid:";
local NoMinBidString = "No min bid";
local WinningBidString = "Winning bid:";
local NotSoldString = "Item not sold";
local HighestBidString = "Highest bid:";
local BidString = "Bid:";
local StartButtonString = "Start";
local BuyButtonString = "Buy";
local BidButtonString = "Bid";
local RemoveButtonString = "Remove";
local StopButtonString = "Stop";
local RenewButtonString = "Renew";
local CompleteButtonString = "Complete";

-- Strings in special Autotrade chat messages
local AutotradePreMeetMessageVersion = "1.1";
local AutotradePreFlatSaleMessageVersion = "1.2";
local AutotradeMessageVersion = "1.3";
local AutotradePrefix = "<AT_MSG_"..AutotradeMessageVersion.."> ";
local AutotradePreFlatSalePrefix = "<AT_MSG_"..AutotradePreFlatSaleMessageVersion.."> ";
local AutotradePreMeetPrefix = "<AT_MSG_"..AutotradePreMeetMessageVersion.."> ";

-- Prefixed message pattern.  %1 = prefix.  %2 = version string.  %3 = payload.
local AutotradeMessageFramework = "^<AT_MSG_(%d+%.%d+)>%s*(.+)$";

-- Auction announcement messages.
-- Formats for sending automated messages
local AutotradeMessageFormat = {};
AutotradeMessageFormat.FlatSale = AutotradePrefix.."WTS %s%s for %s (%s,%s,%s,%s)";
AutotradeMessageFormat.SellNoMin = AutotradePreFlatSalePrefix.."WTS %s%s (%s,%s,%s,%s,%s)";
AutotradeMessageFormat.Sell = AutotradePrefix.."WTS %s%s min %s (%s,%s,%s,%s,%s)";
AutotradeMessageFormat.Bid = AutotradePreMeetPrefix.."Offer %s on %s's %s%s (%s,%s)";
AutotradeMessageFormat.Update = AutotradePreFlatSalePrefix.."WTS %s%s heard %s from %s (%s,%s,%s,%s,%s)";
AutotradeMessageFormat.Sold = AutotradePreMeetPrefix.."SOLD %s%s to %s for %s (%s,%s)";
AutotradeMessageFormat.Ended = AutotradePreMeetPrefix.."ENDED %s%s (%s)"; -- for auctions that end with no sale

-- Note: for allowable meeting places, had to add new param to SellFormat, UpdateFormat messages.
--	The old formats will be marked as such and are still understandable to the new client version.  However,
--	old clients won't be able to understand the new clients' sell format

-- Format for link text
local LinkFormat = "|c%x%x%x%x%x%x%x%x|H.+|h%[.+%]|h|r";
-- Formats for parsing automated messages

-- Auction start messages
local AutotradePayloadFormat = {};

-- No min.  captures are link, quantity string, auction id, countdown, location, and texture filename.
AutotradePayloadFormat.SellNoMin = "^WTS%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
AutotradePayloadFormat.OldSellNoMin = "^WTS%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";
-- Min bid.  captures are link, quantity string, 2 or 4 items describing min bid, auction id, countdown, location, and texture filename.
AutotradePayloadFormat.SellLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
AutotradePayloadFormat.OldSellLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";
AutotradePayloadFormat.SellShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
AutotradePayloadFormat.OldSellShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";

--Flat sale message.  Captures are link, quantity string, auction id, location, and texture.
AutotradePayloadFormat.FlatSaleLong = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+for%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([^,]*),([^,]*),(.*)%)$";
AutotradePayloadFormat.FlatSaleShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+for%s+(%d+)(%a)%s*%((%d+),([^,]*),([^,]*),(.*)%)$";

-- Bid message.  1st 2 or 4 are coin amounts & types.  The rest are owner, link, quantity string, auction id, and location.
AutotradePayloadFormat.BidLong = "^Offer%s+(%d+)(%a)%s*(%d+)(%a)%s+on%s+(%a+)'s%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([^,]*)%)$";
AutotradePayloadFormat.BidShort = "^Offer%s+(%d+)(%a)%s+on%s+(%a+)'s%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([^,]*)%)$";

-- Update message patterns.  Captures are link, quantity string, 2 or 4 items describing highest bid, bidder, auction id, countdown time, location, and texture filename
AutotradePayloadFormat.UpdateLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s*(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
AutotradePayloadFormat.OldUpdateLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s*(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";
AutotradePayloadFormat.UpdateShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
AutotradePayloadFormat.OldUpdateShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";

-- Sold message patterns.  Captures are link, quantity string, winner, 2 or 4 items describing winning bid, auction id, and location.
AutotradePayloadFormat.SoldLong = "^SOLD%s+("..LinkFormat..")%s*(%S*)%s+to%s+(%a+)%s+for%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([^,]*)%)$";
AutotradePayloadFormat.SoldShort = "^SOLD%s+("..LinkFormat..")%s*(%S*)%s+to%s+(%a+)%s+for%s+(%d+)(%a)%s*%((%d+),([^,]*)%)$";

-- Auction closed (no sale) message pattern.  Captures are link, quantity string, and auction id.
AutotradePayloadFormat.Ended = "^ENDED%s+("..LinkFormat..")%s*(%S*)%s+%((%d+)%)$";

--[[
-- No min.  captures are link, quantity string, auction id, countdown, location, and texture filename.
local AutotradeSellPayloadFormatNoMin = "^WTS%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
local AutotradeOldSellPayloadFormatNoMin = "^WTS%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";
-- Min bid.  captures are link, quantity string, 2 or 4 items describing min bid, auction id, countdown, location, and texture filename.
local AutotradeSellPayloadFormatLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
local AutotradeOldSellPayloadFormatLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";
local AutotradeSellPayloadFormatShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
local AutotradeOldSellPayloadFormatShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+min%s+(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";

--Flat sale message
local AutotradeFlatSalePayloadFormatLong = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+for%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
local AutotradeFlatSalePayloadFormatShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+for%s+(%d+)(%a)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";

-- Bid message.  1st 2 or 4 are coin amounts & types.  The rest are owner, link, quantity string, auction id, and location.
local AutotradeBidPayloadFormatLong = "^Offer%s+(%d+)(%a)%s*(%d+)(%a)%s+on%s+(%a+)'s%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([^,]*)%)$";
local AutotradeBidPayloadFormatShort = "^Offer%s+(%d+)(%a)%s+on%s+(%a+)'s%s+("..LinkFormat..")%s*(%S*)%s*%((%d+),([^,]*)%)$";

-- Update message patterns.  Captures are link, quantity string, 2 or 4 items describing highest bid, bidder, auction id, countdown time, location, and texture filename
local AutotradeUpdatePayloadFormatLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s*(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
local AutotradeOldUpdatePayloadFormatLong  = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s*(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";
local AutotradeUpdatePayloadFormatShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),([^,]*),(.*)%)$";
local AutotradeOldUpdatePayloadFormatShort = "^WTS%s+("..LinkFormat..")%s*(%S*)%s+heard%s+(%d+)(%a)%s+from%s+(%a+)%s*%((%d+),([%d%.]+),([^,]*),(.*)%)$";

-- Sold message patterns.  Captures are link, quantity string, winner, 2 or 4 items describing winning bid, auction id, and location.
local AutotradeSoldPayloadFormatLong = "^SOLD%s+("..LinkFormat..")%s*(%S*)%s+to%s+(%a+)%s+for%s+(%d+)(%a)%s*(%d+)(%a)%s*%((%d+),([^,]*)%)$";
local AutotradeSoldPayloadFormatShort = "^SOLD%s+("..LinkFormat..")%s*(%S*)%s+to%s+(%a+)%s+for%s+(%d+)(%a)%s*%((%d+),([^,]*)%)$";

-- Auction closed (no sale) message pattern.  Captures are link, quantity string, and auction id.
local AutotradeEndedPayloadFormat = "^ENDED%s+("..LinkFormat..")%s*(%S*)%s+%((%d+)%)$";
]]

-- constants

-- Static vars.  File scope.
local AUTO_TRADE_DEBUG = true;
local AUTO_TRADE_DEBUG_LEVEL = 1;
local DEBUG_COMM = true;
local DEBUG_SHOW_MESSAGES = true;


-- Error flags
local PrintedVersionError = true;

-- For some reason, making Autotrade_AuctionsDisplayed local causes weird failures.
Autotrade_AuctionsDisplayed = 11;

AuctionTypeDraft = "Draft";
AuctionTypeOpen = "Open";
AuctionTypeClosed = "Closed";
AuctionTypeAllOpen = "All Open";
AuctionTypeBidOpen = "Bidding";
AuctionTypeBidWon = "Won";
AuctionTypeBidLost = "Lost";

local NextAuctionId = 0;

local WishListName = "Autotrade_WishList";
Autotrade_WishList = {};

local TimeUpdateTimer = 0;
local AuctionCountdownTimeMinRefresh = 40;	-- Auctions must continue at least 40 seconds after each bid.
local AuctionIdleResendTime = 5*60;			-- Running Auctions that haven't had a bid in this long get their latest message resent

local AuctionLength = {};
AuctionLength.Debug = 0;
AuctionLength.Instant = 1;
AuctionLength.Short = 2;
AuctionLength.Normal = 3;
AuctionLength.Long = 4;
AuctionLength.Interminable = 5;
AuctionLength.Glacial = 6;
AuctionLength.NumAuctionLengths = 6;

local AuctionCountdownTimes = {
	[AuctionLength.Debug] = 15,
	[AuctionLength.Instant] = 60,
	[AuctionLength.Short] = 180,
	[AuctionLength.Normal] = 300,
	[AuctionLength.Long] = 600,
	[AuctionLength.Interminable] = 1200,
	[AuctionLength.Glacial] = 2400
};


Autotrade_AuctionTimeThresholdGoingOnce = 20;
Autotrade_AuctionTimeThresholdGoingTwice = 10;


-- Item type notes:
--	Line 1 left side is name
--	After line 1 can be: (all in left side only)
--	"Unique" AND/OR
--	"Soulbound" OR
--	"Binds when equipped" OR
--	"Binds when picked up"
--	next line is 'target line' that contains important data.  It is line 2, 3, or 4 depending on other modifiers.
--	weapon class is target line right side (1st non-blank)
--	weapon handedness is target line  left side
--	Armor slot is target line left side (1st non-blank)
--	Armor type is target line right side
--	Projectile label is target line left side
--	Projectile type is target line right side
--	Level requirement is last line, left-side
--
--	NOTE: where does "Quest Item" go?!?

-- Item type pref

local ItemTypeStrings = {

	-- Armor types
	"Cloth",
	"Leather",
	"Mail",

	-- Armor Slots
	"Any Armor Slot",
	"Head",
	"Shoulder",
	"Hands",
	"Back",
	"Waist",
	"Chest",
	"Wrist",
	"Legs",
	"Feet",

	-- Shield types
	"Buckler",
	"Shield",

	-- Weapon types
	"Dagger",
	"Sword",
	"Two-Hand Sword",
	"Mace",
	"Two-Hand Mace",
	"Axe",
	"Two-Hand Axe",
	"Spear",
	"Polearm",
	"Staff",
	"Wand",
	"Thrown",
	"Bow",
	"Crossbow",
	"Gun",
	"Ammunition",
	"Fishing Pole",

	-- Clothing
	"Shirt/Tabard",
	"Finger/Neck/Trinket",
	"Held In Hand",

	-- Misc
	"Misc"


};
-- Zone pickup/transfer pref
AUTOTRADE_DEFAULT_MEET_IN_STRING = "No meeting place";

local ZoneIndexFromString = {
	["Durotar"] = 0,
	["Elwynn Forest"] = 1,
	["Mulgore"] = 2,
	["Teldrassil"] = 3,
	["Tirisfal Glades"] = 4,
	["Dun Morogh"] = 5,
	["The Barrens"] = 6,
	["Blasted Lands"] = 7,
	["Silverpine Forest"] = 8,
	["Darkshore"] = 9,
	["Alterac Mountains"] = 10,
	["Loch Modan"] = 11,
	["Hillsbrad Foothills"] = 12,
	["Westfall"] = 13,
	["Arathi Highlands"] = 14,
	["Redridge Mountains"] = 15,
	["Ashenvale"] = 16,
	["Duskwood"] = 17,
	["Stonetalon Mountains"] = 18,
	["Stranglethorn Vale"] = 19,
	["Desolace"] = 20,
	["Swamp of Sorrows"] = 21,
	["Dustwallow Marsh"] = 22,
	["Burning Steppes"] = 23,
	["Thousand Needles"] = 24,
	["Badlands"] = 25,
	["Ferelas"] = 26,
	["Wetlands"] = 27,
	["Blackrock Mountain"] = 28,
	["Western Plaguelands"] = 29,
	["Eastern Plaguelands"] = 30,
	["The Hinterlands"] = 31,
	["Searing Gorge"] = 32,
	["Darrowmere Lake"] = 33,
	["Deadwind Pass"] = 34
};

local ZoneList = {
	"Durotar",
	"Elwynn Forest",
	"Mulgore",
	"Teldrassil",
	"Tirisfal Glades",
	"Dun Morogh",
	"The Barrens",
	"Westfall",
	"Silverpine Forest",
	"Darkshore",
	"Alterac Mountains",
	"Loch Modan",
	"Hillsbrad Foothills",
	"Blasted Lands",
	"Arathi Highlands",
	"Redridge Mountains",
	"Ashenvale",
	"Duskwood",
	"Stonetalon Mountains",
	"Stranglethorn Vale",
	"Desolace",
	"Swamp of Sorrows",
	"Dustwallow Marsh",
	"Burning Steppes",
	"Thousand Needles",
	"Badlands",
	"Ferelas",
	"Wetlands",
	"Blackrock Mountain",
	"Western Plaguelands",
	"Eastern Plaguelands",
	"The Hinterlands",
	"Searing Gorge",
	"Darrowmere Lake",
	"Deadwind Pass"
};

local ZoneStringFromIndexAndIntValue = {
	[0] = {
		[1] = "Durotar",
		[2] = "Elwynn Forest",
		[4] = "Mulgore",
		[8] = "Teldrassil",
		[16] = "Tirisfal Glades",
		[32] = "Dun Morogh",
		[64] = "The Barrens",
		[128] = "Blasted Lands",
		[256] = "Silverpine Forest",
		[512] = "Darkshore",
		[1024] = "Alterac Mountains",
		[2048] = "Loch Modan",
		[4096] = "Hillsbrad Foothills",
		[8192] = "Westfall",
		[16384] = "Arathi Highlands",
		[32768] = "Redridge Mountains",
		[65536] = "Ashenvale",
		[131072] = "Duskwood",
		[262144] = "Stonetalon Mountains",
		[524288] = "Stranglethorn Vale",
		[1048576] = "Desolace",
		[2097152] = "Swamp of Sorrows",
		[4194304] = "Dustwallow Marsh",
		[8388608] = "Burning Steppes",
		[16777216] = "Thousand Needles",
		[33554432] = "Badlands",
		[67108864] = "Ferelas",
		[134217728] = "Wetlands",
		[268435456] = "Blackrock Mountain",
		[536870912] = "Western Plaguelands",
		[1073741824] = "Eastern Plaguelands",
		[2147483648] = "The Hinterlands",
	},

	[1] = {
		[1] = "Searing Gorge",
		[2] = "Darrowmere Lake",
		[4] = "Deadwind Pass"
	}
};

-- Filtering state
local Filters = {};
local ZoneFilters;
local ItemFilters;
local ItemFilterStrings;

-- Notification types
local NotificationType = {}
NotificationType.Sold = 1;
NotificationType.Ended = 2;
NotificationType.Outbid = 3;
NotificationType.Won = 4;
NotificationType.Lost = 5;
NotificationType.WishList = 6;
NotificationType.New = 7;
NotificationType.Aborted = 8;
NotificationType.NewSilent = 9;
NotificationType.GoingOnce = 10;
NotificationType.GoingTwice = 11;

-- Notification Prefs.  Which types do you want to see?
Autotrade_ShowNotification = {};

-- Default notification prefs
Autotrade_ShowNotification[NotificationType.Sold] = true;
Autotrade_ShowNotification[NotificationType.Ended] = true;
Autotrade_ShowNotification[NotificationType.Outbid] = true;
Autotrade_ShowNotification[NotificationType.Won] = true;
Autotrade_ShowNotification[NotificationType.WishList] = true;
Autotrade_ShowNotification[NotificationType.NewSilent] = true;
Autotrade_ShowNotification[NotificationType.Aborted] = true;
Autotrade_ShowNotification[NotificationType.GoingOnce] = true;
Autotrade_ShowNotification[NotificationType.GoingTwice] = true;


-- Colors for various text types
local ColorPrerelease =			{ r = 0.1,	g = 0.5, b = 0.1 };
local ColorOpenAffordable =		{ r = 0,	g = 1.0, b = 0 };
local ColorOpenTooExpensive =	{ r = 0.6,	g = 0.1, b = 0.1 };
local ColorClosed =				{ r = 0.5,	g = 0.5, b = 0.5 };
local ColorSelling =			{ r = 1.0,	g = 1.0, b = 1.0 };
local ColorGoingOnce =			{ r = 1.0,	g = 0.6, b = 0.0 };
local ColorGoingTwice =			{ r = 1.0,	g = 0.0, b = 0.0 };




-- utility variable, may already have been defined by subpages' .lua files.  Don't overwrite if it already has a value.
if (not PageInfoByFrameName)
then
	PageInfoByFrameName = {};
end


-- Initialization
local AutotradeLoaded = false;
local AutotradeLoadTime = GetTime() + 60;
local AutotradeChannelJoined = false;
-- @JLR - MUTE START
local AutotradeMute = false;
-- @JLR - MUTE END


-- Communication Channels
local AutotradePlayerFaction = nil; -- quick ref of player faction, prevents extra lookups later
local AutotradeFactionHorde = "Horde";
local AutotradeFactionAlliance = "Alliance";
local HordeRaces = {"Orc", "Tauren", "Troll", "Undead" };
local AllianceRaces = {"Human", "Night Elf", "Dwarf", "Gnome" };
local AutotradeHordeChannel = "HordeAutotrade";
local AutotradeAllianceChannel = "AllianceAutotrade";
local AutotradeGlobalChannels = {};
AutotradeGlobalChannels[AutotradeFactionHorde] = AutotradeHordeChannel;
AutotradeGlobalChannels[AutotradeFactionAlliance] = AutotradeAllianceChannel;
-- TODO: add local/zone channels.



----------------------------------------------------------------------------
--------- Debugging code & tools -------------------------------------------
----------------------------------------------------------------------------

function DEBUG_MSG(msg, level, r, g, b, info)
	if (not r) then r = 1.0; end
	if (not g) then g = 1.0; end
	if (not b) then b = 0.5; end
	-- if ((level < 0) or (AUTO_TRADE_DEBUG and AUTO_TRADE_DEBUG_LEVEL >= level))
	-- then
		DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b, info);
	-- end
end


function DEBUG_PRINT_CHAT_ARGS(event, debuglevel)
	if ( (not AUTO_TRADE_DEBUG) or
		(AUTO_TRADE_DEBUG_LEVEL < debugLevel) )
	then
		return;
	end

	local testMessage = "Event "..event.."; Got args";
	local separator = " ";
	if (arg1)
	then
		testMessage = testMessage..separator.."arg1=\""..arg1.."\"";
		separator = "; ";
	end
	if (arg2)
	then
		testMessage = testMessage..separator.."arg2=\""..arg2.."\"";
		separator = "; ";
	end
	if (arg3)
	then
		testMessage = testMessage..separator.."arg3=\""..arg3.."\"";
		separator = "; ";
	end
	if (arg4)
	then
		testMessage = testMessage..separator.."arg4=\""..arg4.."\"";
		separator = "; ";
	end
	if (arg5)
	then
		testMessage = testMessage..separator.."arg5=\""..arg5.."\"";
		separator = "; ";
	end
	if (arg6)
	then
		testMessage = testMessage..separator.."arg6=\""..arg6.."\"";
		separator = "; ";
	end
	if (arg7)
	then
		testMessage = testMessage..separator.."arg7=\""..arg7.."\"";
		separator = "; ";
	end
	if (arg8)
	then
		testMessage = testMessage..separator.."arg8=\""..arg8.."\"";
		separator = "; ";
	end
	if (arg9)
	then
		testMessage = testMessage..separator.."arg9=\""..arg9.."\"";
		separator = "; ";
	end
	DEFAULT_CHAT_FRAME:AddMessage(testMessage);
end

----------------------------------------------------------------------------
--------- Support functions ------------------------------------------------
----------------------------------------------------------------------------


--------- Generic data manipulation ----------------------------------------


function Cosmos_CopyTable(table)
	if (not table)
	then
		return;
	end

	local newTable = {};
	for index, value in table do
		newTable[index] = value;
	end
	return newTable;
end


local function ExplodeHyperlink(link)
	local str = "";
	local remain = link;
	while (remain ~= "") do
		str = str..strsub(remain, 1, 1).." ";
		remain = strsub(remain, 2);
	end
	return str;
end


local function Autotrade_MakeIntFromString(str)
	DEBUG_MSG("Autotrade_MakeIntFromString("..str..")", 4);
	local remain = str;
	local amount = 0;
	while (remain ~= "") do
		amount = amount * 10;
		amount = amount + (string.byte(strsub(remain, 1, 1)) - string.byte("0"));
		remain = strsub(remain, 2);
	end
	DEBUG_MSG("MakeIntFromStr("..str..") = "..amount, 4);
	return amount;
end


local function Autotrade_MakeIntFromHexString(str)
	DEBUG_MSG("Autotrade_MakeIntFromHexString("..str..")", 4);
	local remain = str;
	local amount = 0;
	while (remain ~= "") do
		amount = amount * 16;
		local byteVal = string.byte(strupper(strsub(remain, 1, 1)));
		if (byteVal >= string.byte("0") and byteVal <= string.byte("9"))
		then
			amount = amount + (byteVal - string.byte("0"));
		elseif (byteVal >= string.byte("A") and byteVal <= string.byte("F"))
		then
			amount = amount + 10 + (byteVal - string.byte("A"));
		end
		remain = strsub(remain, 2);
	end
	DEBUG_MSG("MakeIntFromHexStr("..str..") = "..amount, 4);
	return amount;
end


local function SupportedVersion(version)
	return version == AutotradeMessageVersion or version == AutotradePreFlatSaleMessageVersion or version == AutotradePreMeetMessageVersion;
end


local function CanUnderstandVersion(version)
	return version == AutotradeMessageVersion or version == AutotradePreFlatSaleMessageVersion or version == AutotradePreMeetMessageVersion;
end


local function MessageVersionIsNewerThanCode(version)
	-- Get version numbers from message & code versions
	local index;
	local length;
	local messageMajorVersion;
	local messageMinorVersion;
	local codeMajorVersion;
	local codeMinorVersion;
	index, length, messageMajorVersion, messageMinorVersion = string.find(version, "(%d+)%.(%d+)");
	index, length, codeMajorVersion, codeMinorVersion = string.find(AutotradeMessageVersion, "(%d+)%.(%d+)");
	messageMajorVersion = Autotrade_MakeIntFromString(messageMajorVersion);
	messageMinorVersion = Autotrade_MakeIntFromString(messageMinorVersion);
	codeMajorVersion = Autotrade_MakeIntFromString(codeMajorVersion);
	codeMinorVersion = Autotrade_MakeIntFromString(codeMinorVersion);

	-- Compare version numbers
	return (messageMajorVersion > codeMajorVersion or
		(messageMajorVersion == codeMajorVersion and
			messageMinorVersion > codeMinorVersion));
end


local function EscapeString(plainString, disallowedChars)
	-- yay URL-encoding
	local str = "";
	local remain = plainString;
	disallowedChars = disallowedChars.."%";
	while (remain ~= "") do
		local char = strsub(remain, 1, 1);
		if (string.find(disallowedChars, char, 1, true))
		then
			str = str.."%";
			local hexRepresentation = string.format("%02x", string.byte(char));
			str = str..hexRepresentation;
		else
			str = str..char;
		end
		remain = strsub(remain, 2);
	end
	return str;
end

local function UnescapeString(escapedString)
	local str = "";
	local remain = escapedString;
	while (remain ~= "") do
		local char = strsub(remain, 1, 1);
		if (char == "%")
		then
			str = str..string.char(Autotrade_MakeIntFromHexString(strsub(remain, 2, 3)));
			remain = strsub(remain, 4);
		else
			str = str..char;
			remain = strsub(remain, 2);
		end
	end
	return str;
end


local function Autotrade_GetCoinString(money)
	DEBUG_MSG("GetCoinString("..money..")", 3);

	local copper = mod(money, COPPER_PER_SILVER);
	local silver = mod(floor(money / COPPER_PER_SILVER), SILVER_PER_GOLD);
	local gold = floor(money / COPPER_PER_GOLD);

	local coinString;
	if (copper > 0)
	then
		coinString = copper.."c";
	end
	if (silver > 0)
	then
		if (coinString)
		then
			coinString = silver.."s "..coinString;
		else
			coinString = silver.."s";
		end
	end
	if (gold > 0)
	then
		if (coinString)
		then
			coinString = gold.."g "..coinString;
		else
			coinString = gold.."g";
		end
	end

	return coinString;
end


local function Autotrade_GetTimeString(time)
	if (time < 0)
	then
		time = 0;
	end

	local seconds = mod(floor(time), 60);
	if (seconds < 10)
	then
		seconds = "0"..seconds;
	end
	local minutes = mod(floor(time/60), 60);
	local hours = floor(time/(60*60));

	local timeString;
	if (hours > 0)
	then
		if (minutes < 10)
		then
			minutes = "0"..minutes;
		end
		timeString = hours..":"..minutes..":"..seconds;
	else
		timeString = minutes..":"..seconds;
	end
	return timeString;
end


local function Autotrade_GetRGBFromHexColor(hexColor)
	hexColor = "4C09C4";
	local alpha = Autotrade_MakeIntFromHexString(strsub(hexColor, 1, 2)) / 256; -- is this really alpha or just garbage?
	local red = Autotrade_MakeIntFromHexString(strsub(hexColor, 3, 4)) / 256;
	local green = Autotrade_MakeIntFromHexString(strsub(hexColor, 5, 6)) / 256;
	local blue = Autotrade_MakeIntFromHexString(strsub(hexColor, 7, 8)) / 256;
	return red, green, blue;
end


-- Sanitize the player's money into a valid 2-coin-type bid
local function Autotrade_SanitizeMoneyAmount(amount)
	if (amount < 9999)
	then
		return amount;
	end

	local factor1 = 0;
	local factor2 = 0;
	local shiftedAmount = amount
	while (mod(shiftedAmount, 10) == 0) do
		shiftedAmount = shiftedAmount / 10;
		factor1 = factor1 + 1;
		factor2 = factor2 + 1;
	end
	while (shiftedAmount >= 10)  do
		shiftedAmount = shiftedAmount / 10;
		factor2 = factor2 + 1;
	end
	local spread = factor2 - factor1;
	if (spread >= 4)
	then
		local surplus = spread - 3;
		for i = 1, surplus, 1 do
			amount = amount / 10;
		end
		for i = 1, surplus, 1 do
			amount = amount * 10;
		end
	end
	return amount;
end

local function Autotrade_GetNextBid(bid, minBid)
	-- Next bid on a min bid is the min bid
	local nextBid = bid;

	-- Next bid on a non-min bid is something bigger than the min
	local increment = 1;
	if (minBid)
	then
		if (nextBid == 0)
		then
			nextBid = 1;
		end
	else
		local factor = 1;
		nextBid = bid;
		while (nextBid >= 10)  do
			nextBid = nextBid / 10;
			factor = factor * 10;
		end
		if (factor == 1)
		then
			nextBid = nextBid + 1;
		else
			-- Add 10%
			factor = factor / 10;
			increment = factor;
		end
		nextBid = bid + increment;
	end

	if (nextBid > GetMoney() - GetCursorMoney() - GetPlayerTradeMoney())
	then
		nextBid = Autotrade_SanitizeMoneyAmount(GetMoney() - GetCursorMoney() - GetPlayerTradeMoney());
	end


	return nextBid;
end

--------- CVAR manipulation ------------------------------------------------


local CVAR_MAX_SIZE = 256;


local function Autotrade_SaveStringToCVar(str, name)
	DEBUG_MSG("Saving CVar "..name.."="..str.." pair.", 4);
	local chunkName = name.."_chunks";
	RegisterCVar(chunkName);
	if (strlen(str) < CVAR_MAX_SIZE)
	then
		SetCVar(chunkName, "0");
		RegisterCVar(name);
		SetCVar(name, str);
		DEBUG_MSG("Saved string "..name.."="..str.." in one chunk.", 4);
	else
		local numChunks = ceil(strlen(str) / CVAR_MAX_SIZE);
		DEBUG_MSG("Saving string in "..numChunks.." chunks.", 4);
		SetCVar(chunkName, numChunks.."");
		for chunk = 1, numChunks, 1 do
			chunkName = name.."_chunk_"..chunk;
			RegisterCVar(chunkName);
			SetCVar(chunkName, strsub(str, CVAR_MAX_SIZE * (i - 1) + 1, CVAR_MAX_SIZE * i));
		end
		DEBUG_MSG("Saved string "..name.."="..str.." in "..numChunks.." chunks.", 4);
	end
end


local function Autotrade_SaveStringArrayToCVar(array, name)
	local i = 0;
	for index, value in array do
		if (value)
		then
			i = i + 1;
			Autotrade_SaveStringToCVar(index, name.."_index_"..i);
			Autotrade_SaveStringToCVar(value, name.."_"..i);
		end
	end
	Autotrade_SaveStringToCVar(i.."", name.."_Length");
end


local function Autotrade_LoadStringFromCVar(name)
	local str;
	RegisterCVar(name.."_chunks");
	local chunks = GetCVar(name.."_chunks");
	local chunks = "0"
	-- What is chunks if name_chunks is not registered?
	if (chunks == "0")
	then
		-- Commented out because of cvar shrinkage
		RegisterCVar(name);
		str = GetCVar(name);
		DEBUG_MSG("Loaded string "..name.."="..str.." in one chunk.", 4);

		str = nil;
	else
		local numChunks = chunks + 0; -- +0 to do conversion
		str = "";
		for chunk = 1, numChunks, 1 do
			local chunkName = name.."_chunk_"..chunk;
			RegisterCVar(chunkName);
			str = str..GetCVar(chunkName);
		end
		DEBUG_MSG("Loaded string "..name.."="..str.." in "..chunks.." chunks.", 4);
	end
	if (str)
	then
		DEBUG_MSG("Loaded CVar "..name.."="..str.." pair.", 3);
	end
	return str;
end


local function Autotrade_LoadStringArrayFromCVar(name)
	local array;
	local count = 0;
	local countStr = Autotrade_LoadStringFromCVar(name.."_Length");
	if (countStr)
	then
		count = countStr + 0; -- +0 to force to numeric
	end
	if (count and count > 0)
	then
		array = {};
		for i = 1, count, 1 do
			local index = Autotrade_LoadStringFromCVar(name.."_index_"..i);
			local value = Autotrade_LoadStringFromCVar(name.."_"..i);
			array[index] = value;
		end
	end
	return array;
end


--------- Tooltip scanning -------------------------------------------------


local function ScanTooltip(TooltipNameBase)
	local strings = {};
	for idx = 1, 10 do
		local textLeft = nil;
		local textRight = nil;
		ttext = getglobal(TooltipNameBase.."TextLeft"..idx);
		if(ttext and ttext:IsVisible() and ttext:GetText() ~= nil)
		then
			textLeft = ttext:GetText();
		end
		ttext = getglobal(TooltipNameBase.."TextRight"..idx);
		if(ttext and ttext:IsVisible() and ttext:GetText() ~= nil)
		then
			textRight = ttext:GetText();
		end
		if (textLeft or textRight)
		then
			strings[idx] = {};
			strings[idx].left = textLeft;
			strings[idx].right = textRight;
		end

		-- debug output
		if (AUTO_TRADE_DEBUG)
		then
			local text = textLeft;
			if (textRight)
			then
				text = text.."     "..textRight;
			end
			if (text)
			then
				DEBUG_MSG(text, 2);
			end
		end
	end

	return strings;
end


--------- Wish list manipulation -------------------------------------------

local function DEBUG_PRINT_WISH_LIST(list, debugLevel)
	local message = "List contents: ";
	local separator = "";
	if (list)
	then
		for index, value in list do
			message = message..separator.."("..index.."="..value..")";
			separator = ", ";
		end
	end
	DEBUG_MSG(message, debugLevel);
end

local function Autotrade_LoadSavedWishList()
	DEBUG_MSG("Loading wish list.", 2);
	local list = Autotrade_LoadStringArrayFromCVar(WishListName);
	DEBUG_PRINT_WISH_LIST(list, 2);
	return list;
end

local function Autotrade_SaveWishList(list)
	if (not list)
	then
		list = {};
	end
	Autotrade_SaveStringArrayToCVar(list, WishListName);
end

local function Autotrade_AddToWishList(list, item)
	DEBUG_MSG("Adding "..item.." to wish list", 2);
	if (not list)
	then
		list = {};
	end

	list[item] = "1";
	DEBUG_PRINT_WISH_LIST(list, 2);
	Autotrade_SaveWishList(list);
end

local function Autotrade_FindInWishList(list, item)
	DEBUG_PRINT_WISH_LIST(list, 3);
	local val;
	if (list)
	then
		val = list[item];
	end
	if (val)
	then
		DEBUG_MSG("Searching list for "..item..".  Found "..val, 4);
	else
		DEBUG_MSG("Searching list for "..item..".  Not Found.", 4);
	end
	return val;
end

local function Autotrade_RemoveFromWishList(list, item)
	DEBUG_MSG("Removing "..item.." from wish list", 2);
	if (list)
	then
		list[item] = nil;
		Autotrade_SaveWishList(list);
	end
	DEBUG_PRINT_WISH_LIST(list, 2);
end


--------- bit field manipulation -------------------------------------------


local function CheckBits(field, bits)
	local result = true;
	while (bits > 0) do
		if (mod(bits, 2) > 0)
		then
			if (mod(field, 2) == 0)
			then
				result = false;
				break;
			end
		end
		field = floor(field / 2);
		bits = floor(bits / 2);
	end
	return result;
end


local function SetBit(field, bit)
	local source = 2^31; -- 1 in highest-order bit
	local shiftCount = 1;
	local result = 0;
	while (bit > 0) do
		result = floor(result / 2);
		-- if we're about to shift off a 1, put a 1 on the destination.
		if ((mod(bits, 2) == 1) or (mod(field, 2) == 1))
		then
			result = result + source;
		end
		field = floor(field / 2);
		bits = floor(bits / 2);
		shiftCount = shiftCount + 1;
	end
	for i = shiftCount, 32, 1 do
		result = floor(result / 2);
		-- if we're about to shift off a 1, put a 1 on the destination.
		if (mod(bits, 2) == 1)
		then
			result = result + source;
		end
		field = floor(field / 2);
	end
	return result;
end


local function ClearBit(field, bit)
	local source = 2^31; -- 1 in highest-order bit
	local shiftCount = 1;
	local result = 0;
	while (bit > 0) do
		result = floor(result / 2);
		-- if we're about to shift off a 1, put a 1 on the destination. AS LONG AS this is not the bit to clear
		if ((mod(field, 2) == 1) and not (mod(bit, 2) == 1))
		then
			result = result + source;
		end
		field = floor(field / 2);
		bits = floor(bits / 2);
		shiftCount = shiftCount + 1;
	end
	for i = shiftCount, 32, 1 do
		result = floor(result / 2);
		-- if we're about to shift off a 1, put a 1 on the destination.
		if (mod(bits, 2) == 1)
		then
			result = result + source;
		end
		field = floor(field / 2);
	end
	return result;
end


--------- Item Type Filter and manipulation -------------------------------------

-- Because the UI
local function MakeItemTypeFilterFromFlags(typeStringFlags)
	local itemFilters = {};
	itemFilters.weaponTypes = {};
	itemFilters.shieldTypes = {};
	itemFilters.armorTypes = {};
	itemFilters.armorSlots = {};
	itemFilters.clothingTypes = {};
	itemFilters.miscTypes = {};
	if (typeStringFlags)
	then
		for string, flag in typeStringFlags do
			if (string == "Cloth" or
				string == "Leather" or
				string == "Mail")
			then
				itemFilters.armorTypes[string] = flag;
			elseif (string == "Buckler" or
				string == "Shield")
			then
				itemFilters.shieldTypes[string] = flag;
			elseif (string == "Mace" or
				string == "Two-Hand Mace" or
				string == "Sword" or
				string == "Two-Hand Sword" or
				string == "Axe" or
				string == "Two-Hand Axe" or
				string == "Spear" or
				string == "Polearm" or
				string == "Dagger" or
				string == "Staff" or
				string == "Bow" or
				string == "Crossbow" or
				string == "Gun" or
				string == "Thrown" or
				string == "Wand" or
				string == "Ammunition" or
				string == "Fishing Pole")
			then
				itemFilters.weaponTypes[string] = flag;
			elseif (string == "Any Armor Slot" or
				string == "Head" or
				string == "Shoulder" or
				string == "Hands" or
				string == "Back" or
				string == "Waist" or
				string == "Chest" or
				string == "Wrist" or
				string == "Legs" or
				string == "Feet")
			then
				itemFilters.armorSlots[string] = flag;
			elseif (string == "Shirt/Tabard" or
				string == "Finger/Neck/Trinket" or
				string == "Held In Hand")
			then
				itemFilters.clothingTypes[string] = flag;
			else
				itemFilters.miscTypes[string] = flag;
			end
		end
	end

	-- debug messaging
	if (AUTO_TRADE_DEBUG)
	then
		local message = "Armor types allowed: ";
		local separator = "";
		for type, flag in itemFilters.armorTypes do
			if (flag)
			then
				message = message..separator..type;
				separator = ", ";
			end
		end
		message = message.."; Armor slots allowed: ";
		separator = "";
		for type, flag in itemFilters.armorSlots do
			if (flag)
			then
				message = message..separator..type;
				separator = ", ";
			end
		end
		message = message.."; Weapon types allowed: ";
		separator = "";
		for type, flag in itemFilters.weaponTypes do
			if (flag)
			then
				message = message..separator..type;
				separator = ", ";
			end
		end
		DEBUG_MSG(message, 3);
	end
	return itemFilters;
end

local function GetItemInfoStrings(auction)
	-- Determine prior state
	local shown = ItemRefTooltip:IsVisible();

	-- Open tooltip & read contents
	SetItemRef(auction.id, true);
	local strings = ScanTooltip("ItemRefTooltip");
-- Either re-hide or restore contents of tooltip, depending on rior state
	if (shown)
	then
		SetItemRef(Autotrade_LastLink);
	else
		ItemRefTooltip:Hide();
	end

	-- Done our duty, send report
	return strings;
end


local function ClassifyItem(auction)
	local strings = GetItemInfoStrings(auction);
	local classification = "Misc";
	local leftString, rightString, minLevel;
	-- Look for the target line that identifies an item; it'll either be line 2, 3, or 4.

	for i = 2, 5, 1 do
		if (not strings[i])
		then
			break;
		end

		if (strings[i].left and
			strings[i].left ~= "Unique" and
			strings[i].left ~= "Soulbound" and
			strings[i].left ~= "Binds when equipped" and
			strings[i].left ~= "Binds when picked up" and
			strings[i].left ~= "Quest Item")
		then
			leftString = strings[i].left;
			rightString = strings[i].right;
			break;
		end
	end

	-- Find last line
	local lastLine;
	for i = 1, 10, 1 do
		if (strings[i] and strings[i].left)
		then
			lastLine = strings[i].left;
		else
			break;
		end
	end

	-- look at last line to see if it's a level requirement
	local minLevel = 0;
	if (lastLine)
	then
		local index, length, levelString = string.find(lastLine, "^Requires Level (%d+)$");
		if (index)
		then
			minLevel = Autotrade_MakeIntFromString(levelString);
		end
	end

	-- classify item based on found strings
	if (leftString)
	then
		if (leftString == "Main Hand" or
			leftString == "Two-Hand" or
			leftString == "One-Hand")
		then
			classification = "Weapon";
		elseif (leftString == "Head" or
			leftString == "Hand" or
			leftString == "Waist" or
			leftString == "Shoulders" or
			leftString == "Legs" or
			leftString == "Back" or
			leftString == "Feet" or
			leftString == "Chest" or
			leftString == "Wrist")
		then
			classification = "Armor";
		elseif (leftString == "Off Hand")
		then
			classification = "Shield";
		elseif (leftString == "Shirt" or
			leftString == "Tabard" or
			leftString == "Finger" or
			leftString == "Neck" or
			leftString == "Trinket" or
			leftString == "Held In Hand")
		then
			classification = "Clothing";
		end
	end

	return classification, leftString, rightString, minLevel;
end


local function ItemFiltersHaveMatch(auction, itemFilters)
	--	Look up item classification info.
	--	If it's not there, calculate and attach item classification & add'l info to auction
	--		so it doesn't have to be recalculated later
	local itemStrings, classification, type1, type2, minLevel;
	if (not auction.classification)
	then
		classification, type1, type2, minLevel = ClassifyItem(auction);
		auction.classification = classification;
		auction.type1 = type1;
		auction.type2 = type2;
		auction.minLevel = minLevel;
	else
		classification	= auction.classification;
		type1			= auction.type1;
		type2			= auction.type2;
		minLevel		= auction.minLevel;
	end
	local message = "Item Classification: "..classification;
	if (type1)
	then
		message = message.." type1="..type1;
	end
	if (type2)
	then
		message = message.." type2="..type2;
	end
	if (minLevel > 0)
	then
		message = message.." minLevel="..minLevel;
	end
	DEBUG_MSG(message, 3);

	local passes = false;
	if (classification == "Armor")
	then
		for type, flag in itemFilters.armorTypes do
			if (flag and type == type2)
			then
				passes = true;
			end
		end
		if (passes)
		then
			passes = false;
			for slot, flag in itemFilters.armorSlots do
				if (flag and (slot == "Any Armor Slot" or slot == type1))
				then
					passes = true;
				end
				if (passes)
				then
					break;
				end
			end
		end
	elseif (classification == "Weapon")
	then
		for type, flag in itemFilters.weaponTypes do
			local refinedType;
			if (strsub(type, 1, 9) == "Two-Hand ")
			then
				local refinedType = strsub(type, 10);
				passes = flag and (type1 == "Two-Hand" and type2 == refinedType);
			elseif (type ~= "Ammunition")
			then
				-- It passes if the subtype matches exactly AND
				-- either it's specifically NOT a 2-handed weapon (because it says so)
				-- OR it's a 2-handed weapon that doesn't have a 1-handed analog.
				passes = flag and (type2 == type and
					(type1 ~= "Two-Hand" or
						(type2 ~= "Axe" and
							type2 ~= "Sword" and
							type2 ~= "Mace")));
			else
				-- type is Ammunition
				passes = flag and (type2 == "Bullet" or type2 == "Arrow");
			end
			if (passes)
			then
				break;
			end
		end
	elseif (classification == "Shield")
	then
		for type, flag in itemFilters.shieldTypes do
			if (flag and type2 == type)
			then
				passes = true;
				break;
			end
		end
	elseif (classification == "Clothing")
	then
		for type, flag in itemFilters.clothingTypes do
			-- Is there a special case here for Held in Hand stuff?  No, Held in Hand is just the type
			if (flag and
				(type == type1 or
					(type == "Shirt/Tabard" and
						(type1 == "Shirt" or
							type1 == "Tabard")) or
					(type == "Finger/Neck/Trinket" and
						(type1 == "Finger" or
							type1 == "Neck" or
							type1 == "Trinket"))))
			then
				passes = true;
				break;
			end
		end
	elseif (classification == "Misc")
	then
		passes = itemFilters.miscTypes[classification];
	end

	return passes;
end

--------- City Filter and filter list manipulation ------------------------------


local function MakeMeetInString(zoneFilters)
	local meetString = "Meeting place: ";
	local found = false;
	if (zoneFilters)
	then
		local separator = "";
		for zone, state in zoneFilters do
			if (state)
			then
				found = true;
				meetString = meetString..separator..zone;
				separator = "; ";
			end
		end
	end

	if (strlen(meetString) > 30)
	then
		meetString = strsub(meetString, 1, 30).."...";
	end

	if (not found)
	then
		meetString = AUTOTRADE_DEFAULT_MEET_IN_STRING;
	end

	return meetString;
end


local function ClearFilters()
	Filters = {};
end


local function SetFilterState(filter, state)
	if (not Filters)
	then
		Filters = {};
	end

	if (filter)
	then
		Filters[filter] = state;
	end
end


local function CheckFilter(filter)
	return not Filters or Filters[filter];
end


local function Autotrade_EncodeZoneFilter(zoneFilterAA)
	local intArray = {};
	local highestIndex = 0;
	for zone, state in zoneFilterAA do
		local index = floor(ZoneIndexFromString[zone] / 32);
		local remainder = mod(ZoneIndexFromString[zone], 32);
		if (not intArray[index])
		then
			intArray[index] = 0;
		end
		intArray[index] = intArray[index] + 2^remainder;
		if (index > highestIndex)
		then
			highestIndex = index;
		end
	end
	-- make sure it's not a 'holey' array
	for i = 0, highestIndex, 1 do
		if (not intArray[i])
		then
			intArray[i] = 0;
		end
	end
	return intArray;
end


local function EncodeZoneFilterString(zoneFilterAA)
	local intArray;
	if (zoneFilterAA)
	then
		intArray = Autotrade_EncodeZoneFilter(zoneFilterAA);
	else
		intArray = {[0]=0, [1]=0};
	end
	if (not intArray[1])
	then
		intArray[1] = 0;
	end
	return string.format("%s-%s", intArray[0].."", intArray[1].."");
end


local function DecodeZoneFilters(zoneFilterIntegerArray)
	local zoneAA = {};

	for index, bitField in zoneFilterIntegerArray do
		DEBUG_MSG("Decoding zone filter, index="..index.."; bitfield="..bitField, 4);
		local value = 1;
		while (bitField > 0) do
			if (mod(bitField, 2) == 1)
			then
				zoneAA[ZoneStringFromIndexAndIntValue[index][value]] = true;
			end
			bitField = floor(bitField / 2);
			value = value * 2;
		end
	end

	return zoneAA;
end


local function Autotrade_DecodeZoneFilterString(zoneFilterString)
	local zoneFilter;
	local format = "^(%d+)-(%d+)$";
	if (zoneFilterString)
	then
		local index, length, low, high = string.find(zoneFilterString, format);
		local intArray = {[0]=Autotrade_MakeIntFromString(low), [1]=Autotrade_MakeIntFromString(high)};
		zoneFilter = DecodeZoneFilters(intArray);
	end
	return zoneFilter;
end


--
-- Autotrade_CheckZoneFilterForMatch()
--
-- See if an auction zone filter and a buyer's zone filter have any agreement
--
local function ZoneFiltersHaveMatch(buyerZoneFilter, auctionZoneFilter)
	local match = false;
	if (not auctionZoneFilter)
	then
		-- seller was using old version; assume they will sell anywhere for now :(
		match = true;
	else
		-- check each zone the buyer is willing to travel to.  If the seller has it checked, we have a match.
		for zone, allowed in buyerZoneFilter do
			if (allowed)
			then
				if (auctionZoneFilter[zone])
				then
					match = true;
					break;
				end
			end
		end
	end
	return match;
end


local function AuctionPassesBuyerFilter(auction)
	local passes = true;

	-- only filter All Auctions
	if (auction.status == AuctionTypeAllOpen or
		auction.status == AuctionTypeAllCancelled)
	then
		if (Filters["zone"])
		then
			if (not ZoneFiltersHaveMatch(auction.zoneFilters, ZoneFilters))
			then
				DEBUG_MSG("Item "..auction.name.." failed zone filter", 4);
				passes = false;
			end
		end
		if (passes and Filters["item"])
		then
			if (not ItemFiltersHaveMatch(auction, ItemFilters))
			then
				DEBUG_MSG("Item "..auction.name.." failed item filter", 4);
				passes = false;
			end
		end
	end
	return passes;
end


--------- Auction and auction list manipulation ----------------------------


function Autotrade_DuplicateAuction(auction, duplicateZones)
	newAuction = {};
	for index, value in auction do
		newAuction[index] = value;
	end
	if (duplicateZones)
	then
		newAuction.zoneFilters = {}
		for index, value in auction.zoneFilters do
			newAuction.zoneFilters[index] = value;
		end
	end
	-- any special cases for table values should be broken out here
	-- none yet.
	return newAuction;
end


local function Autotrade_FillAuctionFromLink(auctionInfo)
	local startindex, endindex, color, id, name = string.find(auctionInfo.link, "^|c(%x%x%x%x%x%x%x%x)|H(.+)|h%[(.+)%]|h|r$");
	if (not startindex)
	then
		return;
	end
	auctionInfo.qualityColor = color;
	auctionInfo.id = id;
	auctionInfo.name = name;
end


function Autotrade_RemoveAuctionFromList(list, auctionInfo)
	local found = false;
	DEBUG_MSG("Count before remove: "..table.getn(list), 4);
	for index, value in list do
		if ( found )
		then
			list[index - 1] = value;
			list[index] = nil;
			DEBUG_MSG("Found item at index "..index, 4);
		elseif ( value.owner == auctionInfo.owner and
			value.link == auctionInfo.link and
			value.auctionId == auctionInfo.auctionId )
		then  -- TODO: replace with nice overloaded == operator
			found = true;
			list[index] = nil;
		end
	end
	DEBUG_MSG("Count after remove: "..table.getn(list), 4);
end


-- clear list
-- BUT don't create any 'dangling references' by just setting it to {}!
function Autotrade_ClearList(list)
	for index, value in list do
		list[index] = nil;
	end
end


function Autotrade_AddAuctionToList(list, auctionInfo)
	if (not list)
	then
		-- TODO: Report error!
		return;
	end
	for index, item in list do
		if (item.owner == auctionInfo.owner and
			item.link == auctionInfo.link and
			item.auctionId == auctionInfo.auctionId)
		then
			-- Identical auction already present in list.  Prevent duplicate and report that no work was done.
			return nil;
		end
	end
	local auctionId = table.getn(list) + 1;
	if (auctionInfo.name)
	then
		DEBUG_MSG("list["..auctionId.."].name = "..auctionInfo.name, 3);
	end
	list[auctionId] = auctionInfo;

	return true;
end


function Autotrade_FindAuctionInList(list, auction)
	if (not auction)
	then
		return nil;
	end

	DEBUG_MSG("test link ="..ExplodeHyperlink(auction.link).."; owner="..auction.owner.."; id="..auction.auctionId, 4);

	for index, value in list do
		DEBUG_MSG("list["..index.."].link="..ExplodeHyperlink(value.link)..";owner="..value.owner.."; id="..value.auctionId , 4);
		if ((auction.link == value.link) and
			(auction.owner == value.owner) and
			(auction.auctionId == value.auctionId))
		then
			return value;
		end
	end
	return nil;
end


function CombineAuctionStacks(list, auction)
	if (not auction)
	then
		return nil;
	end
	DEBUG_MSG("test link ="..ExplodeHyperlink(auction.link).."; owner="..auction.owner.."; id="..auction.auctionId, 4);

	for index, value in list do
		DEBUG_MSG("list["..index.."].link="..ExplodeHyperlink(value.link)..";owner="..value.owner.."; id="..value.auctionId , 4);
		if ((auction.link == value.link) and
			(auction.owner == value.owner) and
			(auction.count > 1 or
				value.count > 1) )
		then
			value.count = value.count + auction.count;
			return value;
		end
	end
	DEBUG_MSG("Didn't find anything with which to combine", 4);
	return nil;
end

function Autotrade_FindMatchingAuctions(list, auctionCriteria)
	local matches = {};
	local i = 1;
	if (auctionCriteria)
	then
		for index, auction in list do
			local thisMatches = true;
			for criteria, value in auctionCriteria do
				if (auction[criteria] ~= value)
				then
					thisMatches = false;
					break;
				end
			end
			if (thisMatches)
			then
				matches[i] = auction;
				i = i + 1;
			end
		end
	end
	return matches;
end


--------- Details frame support functions ----------------------------------


local function Autotrade_ChooseMeetingPlace_Show(auction, page)
	local text = MakeMeetInString(auction.zoneFilters)
	page.meetInText:SetText(text);
	page.meetInButton:Show();
	page.meetInButton:SetText("Change");
	page.meetInButton.state = "write";
	return text ~= AUTOTRADE_DEFAULT_MEET_IN_STRING;
end


local function Autotrade_ShowMeetingPlace_Show(auction, page)
	page.meetInText:SetText(MakeMeetInString(auction.zoneFilters));
	page.meetInButton:Show();
	page.meetInButton:SetText("Show");
	page.meetInButton.state = "read";
end


local function Autotrade_MeetingPlace_Hide(page)
	page.meetInText:Hide();
	page.meetInButton:Hide();
	page.meetInButton.state = nil;
end


local function Autotrade_TimeFrame_Hide(page)
	page.timeLabel:Hide();
	page.timeText:Hide();
end


local function Autotrade_TimeFrame_Show(auction, page)
	page.timeLabel:SetText("Time Left:");
	page.timeLabel:Show();

	local time = auction.countdownTime - auction.elapsedTime;
	local timeString = Autotrade_GetTimeString(time);
	if (page.timeIsApproximate)
	then
		timeString = timeString.." (approx)";
	end
	page.timeText:SetText(timeString);


	local color = ColorSelling;
	if (time < Autotrade_AuctionTimeThresholdGoingTwice)
	then
		color = ColorGoingTwice;
	elseif (time < Autotrade_AuctionTimeThresholdGoingOnce)
	then
		color = ColorGoingOnce;
	end
	page.timeText:SetTextColor(color.r, color.g, color.b);

	page.timeText:Show();

end


local function Autotrade_TimeFrame_ShowChooser(auction, page)
	page.timeLabel:SetText("Auction Length:");
	page.timeLabel:Show();

	local timeString = Autotrade_GetTimeString(auction.countdownTime);
	page.timeText:SetText(timeString);

	local color = ColorSelling;
	page.timeText:SetTextColor(color.r, color.g, color.b);

	page.timeText:Show();
end


local function Autotrade_TimeFrame_ShowCancelled(auction, page)
	page.timeLabel:SetText("Auction aborted!");
	page.timeLabel:Show();

	page.timeText:Hide();
end


local function Autotrade_WishListDetails_Show(auction, page)
	local itemInWishList;
	if (page.wishListCheckbox)
	then
		-- check checkbox if it's in wish list already
		itemInWishList = Autotrade_FindInWishList(Autotrade_WishList, auction.name);
		local checked = itemInWishList;
		page.wishListCheckbox:SetChecked(checked);
		page.wishListCheckbox:Show();
	end

	if (page.wishListAutoRemoveCheckbox)
	then
		-- If the wish list box is checked, and it's a running auction of some kind, show the auto-remove checkbox.
		if (itemInWishList and
			(auction.status == AuctionTypeOpen or
				auction.status == AuctionTypeBidOpen or
				auction.status == AuctionTypeAllOpen))
		then
			local checked = auction.autoRemove;
			page.wishListAutoRemoveCheckbox:SetChecked(checked);
			page.wishListAutoRemoveCheckbox:Show();
		else
			page.wishListAutoRemoveCheckbox:Hide();
		end
	end
end


local function Autotrade_WishListDetails_Hide(page)
	if (page.wishListCheckbox)
	then
		page.wishListCheckbox:Hide();
	end

	if (page.wishListAutoRemoveCheckbox)
	then
		page.wishListAutoRemoveCheckbox:Hide();
	end
end


local function Autotrade_MoneyFrame_SetType(frame, type)
	-- Hack: fake that 'this' is the money frame, and call SetType.
	local tempthis = this;
	this = frame;
	MoneyFrame_SetType(type);
	this = tempthis;
end


local function Autotrade_MoneyFrame_ShowNothing(moneyFrame, moneyFrameLabel, moneyFrameBidderLabel)
	moneyFrameLabel:SetText("");
	moneyFrameBidderLabel:SetText("");
	Autotrade_MoneyFrame_SetType(moneyFrame, "STATIC");
	RefreshMoneyFrame(moneyFrame:GetName(), 0, 1, 1, false, false);
end


local function Autotrade_MoneyFrame_ShowMinBid(auction, moneyFrame, moneyFrameLabel, editable, moneyFrameBidderLabel)
	moneyFrame:Show();
	moneyFrameBidderLabel:SetText("");

	local minBid = 0;
	local showAllCoins = false;
	if ( editable )
	then
		if (auction.flatSale)
		then
			moneyFrameLabel:SetText(PriceString);
		else
			moneyFrameLabel:SetText(MinBidString);
		end
		minBid = auction.minBid;
		showAllCoins = true;
	-- diff3
	--	Autotrade_MoneyFrame_SetType(moneyFrame,"BIDPARAM");
	else
		if ( auction.minBid and auction.minBid > 0 )
		then
			if (auction.flatSale)
			then
				moneyFrameLabel:SetText(PriceString);
			else
				moneyFrameLabel:SetText(MinBidString);
			end
			minBid = auction.minBid;
		else
			moneyFrameLabel:SetText(NoMinBidString);
		end
		Autotrade_MoneyFrame_SetType(moneyFrame,"STATIC");
	end
	RefreshMoneyFrame(moneyFrame:GetName(), minBid, 1, 1, showAllCoins, showAllCoins);
	moneyFrameLabel:Show();
	moneyFrame:Show();
end


local function Autotrade_MoneyFrame_ShowHighestBid(auction, moneyFrame, moneyFrameLabel, moneyFrameBidderLabel)
	moneyFrame:Show();

	local bidToDisplay = 0;
	if ( ( auction.status == AuctionTypeOpen or
			auction.status == AuctionTypeAllOpen or
			auction.status == AuctionTypeBiddingOpen or
			auction.status == AuctionTypeAllCancelled or
			auction.status == AuctionTypeBidCancelled or
			auction.status == AuctionTypeMyCancelled) and
		auction.highestBid )
	then
		moneyFrameLabel:SetText(HighestBidString);
		moneyFrameBidderLabel:SetText(format(TEXT(PARENS_TEMPLATE), auction.bidder));
		moneyFrameBidderLabel:SetPoint("LEFT", moneyFrame:GetName(), "RIGHT", 5, 0);

		bidToDisplay = auction.highestBid;
	else
		if (auction.status == AuctionTypeDraft or
			(auction.minBid and auction.minBid > 0))
			then
			if (auction.flatSale)
			then
				moneyFrameLabel:SetText(PriceString);
			else
				moneyFrameLabel:SetText(MinBidString);
			end

		else
			moneyFrameLabel:SetText(NoMinBidString);
		end
		moneyFrameBidderLabel:SetText("");
		if (auction.minBid)
		then
			bidToDisplay = auction.minBid;
		else
			bidToDisplay = 0;
		end
	end
	Autotrade_MoneyFrame_SetType(moneyFrame, "STATIC");
	RefreshMoneyFrame(moneyFrame:GetName(), bidToDisplay, 1, 1, false, false);
	moneyFrameLabel:Show();
	moneyFrame:Show();

end


local function Autotrade_MoneyFrame_ShowWinningBid(auction, moneyFrame, moneyFrameLabel, moneyFrameBidderLabel)
	local bidToShow = 0;
	if (auction.highestBid)
	then
		moneyFrameLabel:SetText(WinningBidString);
		bidToShow = auction.highestBid;
		moneyFrameBidderLabel:SetText(format(TEXT(PARENS_TEMPLATE), auction.bidder));
		moneyFrameBidderLabel:SetPoint("LEFT", moneyFrame:GetName(), "RIGHT", 5, 0);
	else
		moneyFrameLabel:SetText(NotSoldString);
		moneyFrameBidderLabel:SetText("");
	end
	Autotrade_MoneyFrame_SetType(moneyFrame, "STATIC");
	RefreshMoneyFrame(moneyFrame:GetName(), bidToShow, 1, 1, false, false);
	moneyFrameLabel:Show();
	moneyFrame:Show();

end


local function Autotrade_MoneyFrame_ShowMyBid(auction, moneyFrame, moneyFrameLabel, moneyFrameBidderLabel)
	if (auction.flatSale)
	then
		return Autotrade_MoneyFrame_ShowNothing(moneyFrame, moneyFrameLabel, moneyFrameBidderLabel);
	end

	moneyFrameLabel:SetText(BidString);
	moneyFrameBidderLabel:SetText("");
	moneyFrame:Show();

	local bidToShow = 0;
	if (auction.bid and
		(not auction.highestBid or
			auction.bid > auction.highestBid))
	then
		bidToShow = auction.bid;
	else
		local bidAmount = auction.minBid;
		if (not bidAmount)
		then
			bidAmount = 0;
		end
		local isMin = true;
		if (auction.highestBid)
		then
			isMin = false;
			bidAmount = auction.highestBid;
		end
		bidToShow = Autotrade_GetNextBid(bidAmount, isMin);
	end
	Autotrade_MoneyFrame_SetType(moneyFrame, "BID");
	RefreshMoneyFrame(moneyFrame:GetName(), bidToShow, 1, 1, true, true);
end


local function Autotrade_SetTimeButtons_Show(auction, page)
	page.shorterButton:Show();
	page.longerButton:Show();
	if (auction)
	then
		if (not auction.lengthIndex)
		then
			auction.lengthIndex = AuctionLength.Normal;
			auction.countdownTime = AuctionCountdownTimes[auction.lengthIndex];
		else
			-- allow all lengths except the debug (super-short) length in normal mode.
			-- Allow all lengths in debug mode
			if ((not AUTO_TRADE_DEBUG and auction.lengthIndex == 1) or
				(AUTO_TRADE_DEBUG and auction.lengthIndex == 0))
			then
				page.shorterButton:Disable();
			else
				page.shorterButton:Enable();
			end
			if (auction.lengthIndex == AuctionLength.NumAuctionLengths)
			then
				page.longerButton:Disable();
			else
				page.longerButton:Enable();
			end
		end
	end
end


local function Autotrade_SetTimeButtons_Hide()
	AutotradeMyAuctionsShorterButton:Hide();
	AutotradeMyAuctionsLongerButton:Hide();
end


local function Autotrade_HideAuctionDetails(pageInfo)

DEBUG_MSG("Hiding auction details", 4);
	pageInfo.itemName:Hide();
	pageInfo.itemIcon:Hide();
	if (pageInfo.ownerName)
	then
		pageInfo.ownerName:Hide();
	end
	if(pageInfo.ownerLabel)
	then
		pageInfo.ownerLabel:Hide();
	end
	if(pageInfo.ownerLocation)
	then
		pageInfo.ownerLocation:Hide();
	end
	pageInfo.upperMoneyLabel:Hide();
	pageInfo.upperMoneySubText:Hide();
	pageInfo.upperMoneyFrame:Hide();
	pageInfo.lowerMoneyLabel:Hide();
	pageInfo.lowerMoneySubText:Hide();
	pageInfo.lowerMoneyFrame:Hide();
	if (pageInfo.wishListCheckbox)
	then
		pageInfo.wishListCheckbox:Hide();
	end

	if (pageInfo.wishListAutoRemoveCheckbox)
	then
		pageInfo.wishListAutoRemoveCheckbox:Hide();
	end

	pageInfo.timeText:Hide();
	pageInfo.timeLabel:Hide();

	-- hide auction length chooser
	if (pageInfo.shorterButton)
	then
		pageInfo.shorterButton:Hide();
	end
	if (pageInfo.longerButton)
	then
		pageInfo.longerButton:Hide();
	end

	pageInfo.meetInText:Hide();
	pageInfo.meetInButton:Hide();
end


local function Autotrade_UpdateOwnerLabelText(page, auction)
	if (auction.flatSale)
	then
		page.ownerLabel:SetText(page.saleText);
	else
		page.ownerLabel:SetText(page.auctionText);
	end
end


local function Autotrade_ShowAuctionDetails(pageInfo, auction)
	DEBUG_MSG("Showing auction details", 4);
	pageInfo.itemName:Show();
	pageInfo.itemIcon:Show();
	if (pageInfo.ownerName)
	then
		pageInfo.ownerName:Show();
	end
	if(pageInfo.ownerLabel)
	then
		Autotrade_UpdateOwnerLabelText(pageInfo, auction);
		pageInfo.ownerLabel:Show();
	end
	if(pageInfo.ownerLocation)
	then
		pageInfo.ownerLocation:Show();
	end
	pageInfo.upperMoneyLabel:Show();
	pageInfo.upperMoneySubText:Show();
	pageInfo.upperMoneyFrame:Show();
	pageInfo.lowerMoneyLabel:Show();
	pageInfo.lowerMoneySubText:Show();
	pageInfo.lowerMoneyFrame:Show();
	if (pageInfo.wishListCheckbox)
	then
		pageInfo.wishListCheckbox:Show();
	end

	if (pageInfo.wishListAutoRemoveCheckbox)
	then
		pageInfo.wishListAutoRemoveCheckbox:Show();
	end
	pageInfo.timeText:Show();
	pageInfo.timeLabel:Show();

	pageInfo.meetInText:Show();
	pageInfo.meetInButton:Show();
end


local function Autotrade_UpdateDetails(page, explicitAction)
	local auctionInfo = page.frame.currentAuction;

	-- TODO: search auction lists and find this auction?  Update the auction details with current info, or clear the currentAuction field.
	if (not auctionInfo)
	then
		Autotrade_HideAuctionDetails(page);
		page.acceptButton:Disable();
		page.removeButton:Disable();
		return;
	else
		Autotrade_ShowAuctionDetails(page, auctionInfo);
	end

	page.itemIcon:SetNormalTexture(auctionInfo.texture);
	page.itemName:SetText(auctionInfo.name);
	if (auctionInfo.count > 1)
	then
		page.itemIconCount:SetText(""..auctionInfo.count);
		page.itemIconCount:Show();
	else
		page.itemIconCount:SetText("");
		page.itemIconCount:Hide();
	end

	local canAfford;
	local totalPlayerBids = 0;
	local highestBid;
	if (auctionInfo.minBid)
	then
		highestBid = auctionInfo.minBid - 1;
	else
		highestBid = 0;
	end
	if (auctionInfo.highestBid)
	then
		highestBid = auctionInfo.highestBid;
	end
	if ( GetMoney() > highestBid + totalPlayerBids)
	then
		SetMoneyFrameColor(page.upperMoneyFrame:GetName(), 1.0, 1.0, 1.0);
		canAfford = true;
	else
		SetMoneyFrameColor(page.upperMoneyFrame:GetName(), 1.0, 0.1, 0.1);
		canAfford = false;
	end

	-- don't show Accept button if it's an auction they can bid on and if they can't afford it.
	-- don't show Accept button if it's an open auction they own
	-- do show Accept button if it's a prerelease auction they're setting min bid.
	local isOwner = auctionInfo.owner == UnitName("player");
	local isOpen = auctionInfo.status == AuctionTypeOpen or auctionInfo.status == AuctionTypeAllOpen or auctionInfo.status == AuctionTypeBiddingOpen;
	if ( isOpen and (not canAfford or isOwner))
	then
		page.acceptButton:Disable();
	else
		page.acceptButton:Enable();
	end

	-- Update the money displays, button titles, and such.
	if (auctionInfo.status == AuctionTypeDraft)
	then
		-- Draft auction.
		--	Show & Enable Start button
		--	Enable Remove button.
		--	Show min bid selector
		--	Show auction time & selector buttons.
		page.acceptButton:SetText(StartButtonString);
		page.removeButton:Enable();

		-- If it's not an explicit user action and the coin pickup frame is shown don't do anything -- otherwise this closes the frame
		if (explicitAction or not CoinPickupFrame:IsVisible())
		then
			Autotrade_MoneyFrame_ShowMinBid(auctionInfo, page.upperMoneyFrame, page.upperMoneyLabel, true, page.upperMoneySubText);
		end
		Autotrade_MoneyFrame_ShowNothing(page.lowerMoneyFrame , page.lowerMoneyLabel, page.lowerMoneySubText);
		if (auctionInfo.flatSale)
		then
			Autotrade_TimeFrame_Hide(page);
			Autotrade_SetTimeButtons_Hide();
		else
			Autotrade_TimeFrame_ShowChooser(auctionInfo, page);
			Autotrade_SetTimeButtons_Show(auctionInfo, page);
		end
		local zoneFilterSet = Autotrade_ChooseMeetingPlace_Show(auctionInfo, page);
		-- diff3
		--if (not zoneFilterSet)
		--then
			-- page.acceptButton:Disable();
			page.acceptButton:Enable();
		--end

	elseif (auctionInfo.status == AuctionTypeOpen or
		 auctionInfo.status == AuctionTypeAllOpen or
		 auctionInfo.status == AuctionTypeBiddingOpen)
	then
		-- Open auction.
		--	Show & Enable Bid button
		--	Disable Remove button.
		--	Show highest bid if owner, or highest bid & my bid if not owner
		--	Show auction time countdown.
		-- Show the "Stop" button if this is the player's own auction.  Otherwise show the "Buy" or "Bid" button
		if (auctionInfo.owner == UnitName("player"))
		then
			page.acceptButton:SetText(StopButtonString);
			-- Enable button if this is a flat sale, otherwise disable it.
			if (auctionInfo.flatSale)
			then
				page.acceptButton:Enable();
			else
				page.acceptButton:Disable();
			end
		else
			if (auctionInfo.flatSale)
			then
				page.acceptButton:SetText(BuyButtonString);
			else
				page.acceptButton:SetText(BidButtonString);
			end
		end
		page.removeButton:Disable();

		Autotrade_MoneyFrame_ShowHighestBid(auctionInfo, page.upperMoneyFrame, page.upperMoneyLabel, page.upperMoneySubText);
		if ( not isOwner )
		then
			-- If it's not an explicit user action and the coin pickup frame is shown don't do anything -- otherwise this closes the frame
			if (explicitAction or not CoinPickupFrame:IsVisible())
			then
				Autotrade_MoneyFrame_ShowMyBid(auctionInfo, page.lowerMoneyFrame, page.lowerMoneyLabel, page.lowerMoneySubText);
			end
		else
			Autotrade_MoneyFrame_ShowNothing(page.lowerMoneyFrame, page.lowerMoneyLabel, page.lowerMoneySubText);
		end
		DEBUG_MSG("Going to show auction time "..auctionInfo.countdownTime - auctionInfo.elapsedTime, 3);
		if (auctionInfo.flatSale)
		then
			Autotrade_TimeFrame_Hide(page);
			Autotrade_SetTimeButtons_Hide();
		else
			Autotrade_TimeFrame_Show(auctionInfo, page);
			Autotrade_SetTimeButtons_Hide();
		end
		Autotrade_ShowMeetingPlace_Show(auctionInfo, page);
	elseif (auctionInfo.status == AuctionTypeClosed or
		auctionInfo.status == AuctionTypeBidWon or
		auctionInfo.status == AuctionTypeBidLost)
	then
		-- Closed auction.
		--	Show & Disable Complete button (enable it once there's code to support it).
		--	Enable Remove button.
		--	Show min & winning bids
		--	Hide auction time.
		if (AutotradeFrame.activeFrame == "AutotradeMyAuctionsFrame")
		then
			page.acceptButton:SetText(RenewButtonString);
			page.acceptButton:Enable();
		else
			page.acceptButton:SetText(CompleteButtonString);
			-- TODO: make accept button unclickable specifically for AuctionTypeBidLost, when it's wired up to something.
			page.acceptButton:Disable();
		end
		page.removeButton:Enable();

		Autotrade_MoneyFrame_ShowMinBid(auctionInfo, page.upperMoneyFrame, page.upperMoneyLabel, false, page.upperMoneySubText);
		Autotrade_MoneyFrame_ShowWinningBid(auctionInfo, page.lowerMoneyFrame, page.lowerMoneyLabel, page.lowerMoneySubText);
		Autotrade_TimeFrame_Hide(page);
		Autotrade_SetTimeButtons_Hide();
		Autotrade_ShowMeetingPlace_Show(auctionInfo, page);
	else
		-- Cancelled auction.  Show & Disable Bid button.  Enable Remove button.  Show highest & my bids.  Show "Cancelled" message instead of countdown.
		page.acceptButton:SetText(BidButtonString);
		page.acceptButton:Disable();
		page.removeButton:Enable();

		Autotrade_MoneyFrame_ShowHighestBid(auctionInfo, page.upperMoneyFrame, page.upperMoneyLabel, page.upperMoneySubText);
		Autotrade_MoneyFrame_ShowNothing(page.lowerMoneyFrame, page.lowerMoneyLabel, page.lowerMoneySubText);

		Autotrade_TimeFrame_ShowCancelled(auctionInfo, page);
		Autotrade_SetTimeButtons_Hide();
		Autotrade_MeetingPlace_Hide(page);
	end

	Autotrade_WishListDetails_Show(auctionInfo, page);

	-- Update the owner string.
	if (page.ownerName)
	then
		page.ownerName:SetText(auctionInfo.owner);
	end

	-- Show or hide Change button for sale/action.  Show only if it's a draft.
	if (page.changeSellMethodButton)
	then
		if (auctionInfo.status == AuctionTypeDraft)
		then
			page.changeSellMethodButton:Show();
		else
			page.changeSellMethodButton:Hide();
		end
	end

	if (page.ownerLocation)
	then
		if (auctionInfo.location)
		then
			page.ownerLocation:SetText(format(TEXT(PARENS_TEMPLATE), auctionInfo.location));
		else
			-- FAILSAFE: should never happen
			page.ownerLocation:SetText("");
		end
	end

end


--------- List view support functions --------------------------------------

local function Autotrade_TypeIsShown(type, displayFlags)
	return not displayFlags[type] or displayFlags[type] == 1;
end


local function Autotrade_BuildVisibleAuctionList(auctionTypes, auctionLists, offset, numToShow, displayFlags)
	-- window start and window end are inclusive
	local windowStart = offset + 1;
	local windowEnd = offset + numToShow;

	local currentOffset = 0;
	local displayList = { };
	local done = false;
	local displayListIndex = 1;
	for index, type in auctionTypes do
		local list = auctionLists[type];
		local thisListCount = 1;
		local listCount = 0;
		local index;
		local auction;

		-- Apply filters
		local filteredList = {};
		local filteredIndex = 1;
		for index, auction in list do
			if AuctionPassesBuyerFilter(auction)
			then
				listCount = listCount + 1;
				filteredList[filteredIndex] = auction;
				filteredIndex = filteredIndex + 1;
			end
		end

		local skipList = listCount == 0;
		if (not skipList)
		then
			local listShown = not displayFlags or Autotrade_TypeIsShown(type, displayFlags)
			if (listShown)
			then
				thisListCount = thisListCount + listCount;
			end
			-- We have to do work if this list has any items within the display window range
			if ( windowStart <= currentOffset + thisListCount  and
				windowEnd >= currentOffset + 1)
			then
				-- add section header
				if ( windowStart <= currentOffset + 1)
				then
					local headerItem = { };
					headerItem.header = true;
					headerItem.name = type;
					headerItem.expanded = listShown;
					headerItem.clearable = (type == AuctionTypeAllCancelled) or
						(type == AuctionTypeMyCancelled) or
						(type == AuctionTypeBidCancelled) or
						(type == AuctionTypeBidWon) or
						(type == AuctionTypeBidLost);
					displayList[displayListIndex] = headerItem;
					displayListIndex = displayListIndex + 1;
					if (table.getn(displayList) >= numToShow)
					then
						break;
					end
				end
				-- start i at 2.  (the header took up item 1)
				if (listShown)
				then
					local i = 2;
					local index2;
					local value;
					for index2, value in filteredList do
						-- stop once we have filled the display list
						if (table.getn(displayList) >= numToShow)
						then
							done = true;
							break;
						end
						-- add item if we're past windowstart.
						if (currentOffset + i >= windowStart)
						then
							displayList[displayListIndex] = value;
							displayListIndex = displayListIndex + 1;
						end
						i = i + 1;
					end
					if ( done )
					then
						break;
					end
				end

				currentOffset = currentOffset + thisListCount;
			end
		end
	end
	return displayList;
end


local function Autotrade_CountDisplayedAuctions(page)
	local type;
	local list;
	local count = 0;
	-- TODO: nil value here when drag & drop
	for type, list in page.auctionLists do
		if (list)
		then
			local listCount = 0;
			local index;
			local auction;
			for index, auction in list do
				if AuctionPassesBuyerFilter(auction)
				then
					listCount = listCount + 1;
				end
			end

			if (not page.typeFlags or Autotrade_TypeIsShown(type, page.typeFlags))
			then
				if (listCount > 0)
				then
					DEBUG_MSG("List "..type.." has "..table.getn(list).." entries.", 4);
					count = count + listCount + 1;
				else
					DEBUG_MSG("List "..type.." has no entries.", 4);
				end
			elseif (page.typeFlags)
			then
				if (listCount > 0)
				then
					count = count + 1;
				end
			end
		end
	end
	return count;
end


local function Autotrade_GetItemTitle(auctionInfo, truncationWithCount)
	local title = "[{bad data}]";
	if (auctionInfo)
	then
		if (auctionInfo.header)
		then
			return auctionInfo.name;
		else
			title = auctionInfo.name;
			if (auctionInfo.count > 1)
			then
				if (truncationWithCount and
					strlen(title) > truncationWithCount)
				then
					title = strsub(title, 1, truncationWithCount).."...";
				end
				title = title.." x"..auctionInfo.count;
			else
				if (truncationWithCount)
				then
					local truncation = truncationWithCount + 3;
					if (strlen(title) > truncation)
					then
						title = strsub(title, 1, truncation).."...";
					end
				end
			end
		end
	end
	return title;
end


local function Autotrade_GetListDisplayBid(auction)
	if ( not auction )
	then
		return nil;
	end

	if ( not auction.minBid )
	then
		return auction.highestBid;
	end

	if ( not auction.highestBid )
	then
		return auction.minBid;
	end

	if ( auction.minBid > auction.highestBid )
	then
		return auction.minBid;
	else
		return auction.highestBid;
	end
end


local function Autotrade_GetAuctionInfo(auctionLists, auctionKind, auctionId)
	if (auctionLists[auctionKind] and
		auctionLists[auctionKind][auctionId])
	then
		return auctionLists[auctionKind][auctionId];
	else
		return nil;
	end
end


function AutotradeListFrame_Update(page, explicitAction)
	if (nil == page)
	then
		page = PageInfoByFrameName[this:GetParent():GetName()];
		DEBUG_MSG("this:GetParent()'s frame is "..this:GetParent():GetName()..".  Getting info.", 3);
	end

	-- page can still be nil if this is on an OnUpdate() call.

	DEBUG_MSG("Updating frame "..page.frame:GetName(), 2);

	local itemOffset = FauxScrollFrame_GetOffset(page.scrollFrame);

	local numAuctions = Autotrade_CountDisplayedAuctions(page);

	FauxScrollFrame_Update(page.scrollFrame, numAuctions, Autotrade_AuctionsDisplayed, AUTO_TRADE_ITEM_HEIGHT, highlight, 293, 316 )
	page.highlightFrame:Hide();
	DEBUG_MSG(numAuctions.." auctions to show", 4);
	local visibleAuctionList = Autotrade_BuildVisibleAuctionList(page.auctionTypesList, page.auctionLists, itemOffset, Autotrade_AuctionsDisplayed, page.frame.typeFlags);
	DEBUG_MSG(table.getn(visibleAuctionList).." items in display list ", 4);
	for i=1, Autotrade_AuctionsDisplayed, 1 do
		local itemIndex = i + itemOffset;
		local thisItemButtonName = page.itemButtonName..i;
		local itemButton = getglobal(thisItemButtonName);
		itemButton:SetID(i);
		if (i <= table.getn(visibleAuctionList))
		then
			local auctionInfo = Autotrade_GetAuctionInfo(page.auctionLists, visibleAuctionList, i);
			local message;
			if (visibleAuctionList[i].header)
			then
				message = "Header in position "..i..", itemindex "..itemIndex.." is: "..visibleAuctionList[i].name;
			else
				message = "Item "..i..", itemIndex "..itemIndex.." is: "..visibleAuctionList[i].name;
			end
			DEBUG_MSG(message, 4);
			if ( page.scrollFrame:IsVisible() )
			then
				itemButton:SetWidth(293);
			else
				itemButton:SetWidth(323);
			end

			local auctionInfo = visibleAuctionList[i];

			itemButton:SetText("  "..Autotrade_GetItemTitle(auctionInfo, 19));
			itemButton:Show();
			itemButton.auctionInfo = auctionInfo;

			local color = {};
			local moneyColor = {};
			bidLabel = getglobal(thisItemButtonName.."Bid");
			subTextLabel = getglobal(thisItemButtonName.."SubText");
			if ( auctionInfo.header )
			then
				if (not page.frame.typeFlags or Autotrade_TypeIsShown(auctionInfo.name,page.frame.typeFlags))
				then
					itemButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
				else
					itemButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
				end
				getglobal(thisItemButtonName.."Highlight"):SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight");
				itemButton:SetTextColor(NORMAL_FONT_COLOR.r * 0.7, NORMAL_FONT_COLOR.g * 0.7, NORMAL_FONT_COLOR.b * 0.7);
				bidLabel:Hide();
				subTextLabel:Hide();

				local clearButton = getglobal(thisItemButtonName.."ClearAllButton");
				if (clearButton and auctionInfo.clearable)
				then
					clearButton:Show();
				else
					clearButton:Hide();
				end
			else
				-- Find out the item color
				color.r, color.g, color.b = Autotrade_GetRGBFromHexColor(auctionInfo.qualityColor);
				-- Find out what color to use to display the bid or min bid info
				if (auctionInfo.status == AuctionTypeDraft)
				then
					moneyColor = ColorPrerelease;
				elseif (auctionInfo.status == AuctionTypeOpen or
						auctionInfo.status == AuctionTypeAllOpen or
						auctionInfo.status == AuctionTypeBiddingOpen)
				then
					local canAfford = GetMoney() > 0;
					if (auctionInfo.minBid)
					then
						canAfford = canAfford and
							GetMoney() >= auctionInfo.minBid;
					end
					if (auctionInfo.highestBid)
					then
						canAfford = canAfford and
							( ( auctionInfo.highestBidder == UnitName("player") ) or
								( GetMoney() > auctionInfo.highestBid ) );
					end
					if (canAfford)
					then
						moneyColor = ColorOpenAffordable;
					else
						moneyColor = ColorOpenTooExpensive;
					end
				else
					moneyColor = ColorClosed;
				end

				itemButton:SetTextColor(color.r, color.g, color.b, 1.0, 0);
				bidLabel:SetTextColor(moneyColor.r, moneyColor.g, moneyColor.b, 1.0, 0);
				subTextLabel:SetTextColor(moneyColor.r, moneyColor.g, moneyColor.b, 1.0, 0);

				-- Hide the clear button (it's only for header items)
				local clearButton = getglobal(thisItemButtonName.."ClearAllButton");
				clearButton:Hide();

				itemButton:SetNormalTexture("");

				getglobal(thisItemButtonName.."Highlight"):SetTexture("");

				local bidAmount = Autotrade_GetListDisplayBid(auctionInfo);
				if ( bidAmount )
				then
					if (auctionInfo.status == AuctionTypeClosed and
						not auctionInfo.highestBid)
					then
						bidLabel:Hide();
					else
						bidLabel:Show();
						bidLabel:SetText(Autotrade_GetCoinString(bidAmount));
					end
				else
					bidLabel:Hide();
				end

				-- Show subtext: either the highest bidder or the owner, depending on context.
				local subTextText = nil;
				if ( auctionInfo.owner == UnitName("player") )
				then
					-- If this is my auction, show me the highest bidder (if one exists).
					if ( auctionInfo.highestBid )
					then
						subTextText = auctionInfo.bidder;
					end
				elseif ( auctionInfo.status == AuctionTypeBidWon )
				then
					-- It's not my auction.  If I've won the auction, show the owner name.
					subTextText = auctionInfo.owner;
				else
					-- It's not my auction.  I've not won the auction, so show the highest bidder name.
					subTextText = auctionInfo.bidder;
				end

				if (subTextText)
				then
					DEBUG_MSG("subTextText is "..subTextText, 4);
					subTextLabel:SetText(format(TEXT(PARENS_TEMPLATE), subTextText));
					subTextLabel:SetPoint("LEFT", page.itemButtonName..i.."Text", "RIGHT", 10, 0);
					subTextLabel:Show();
				else
					DEBUG_MSG("subTextText is nil", 4);
					subTextLabel:Hide();
				end

			end

			-- Place the highlight and lock the highlight state
			if ( page.frame.currentAuction == itemButton.auctionInfo )
			then
				page.highlightFrame:SetPoint("TOPLEFT", page.itemButtonName..i, "TOPLEFT", 0, 0);
				local highlightName = page.highlightFrame:GetName();
				local highlightTextureName = strsub(highlightName, 1, strlen(highlightName)-5);
				local highlightTexture = getglobal(highlightTextureName);
				highlightTexture:SetVertexColor(color.r,color.g,color.b);
				page.highlightFrame:Show();
				itemButton:LockHighlight();
				subTextLabel:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				bidLabel:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
			else
				itemButton:UnlockHighlight();
			end
		else
			itemButton:Hide();
			itemButton.auctionInfo = nil;
		end
	end

	Autotrade_UpdateDetails(page, explicitAction);

end


local function Autotrade_SetSelection(page, id)
	local itemOffset = FauxScrollFrame_GetOffset(page.scrollFrame);
	local auctionIndex = id + itemOffset;

	local itemButton = getglobal(page.itemButtonName..id);

	-- close down any old choose zone stuff.
	-- ChooseItemsFrame:Hide();

	-- Toggle section when user clicks a header.
	if (itemButton.auctionInfo.header)
	then
		if (not page.frame.typeFlags)
		then
			page.frame.typeFlags = {};
		end
		-- toggle it on if it was off, or off if it was on (or nil, because nil == default --> on)
		if (page.frame.typeFlags[itemButton.auctionInfo.name] == 0)
		then
			page.frame.typeFlags[itemButton.auctionInfo.name] = 1;
		else
			page.frame.typeFlags[itemButton.auctionInfo.name] = 0;
		end
	else

		page.frame.currentAuction = itemButton.auctionInfo;

		Autotrade_UpdateDetails(page);
	end

	DEBUG_MSG("Clicked button \""..page.itemButtonName..id.."\"", 3);
end


--------- Link processing --------------------------------------------------

local function Autotrade_EscapeLink(link)
	return EscapeString(link, "|:");
 end


local function Autotrade_UnescapeLink(escapedLink)
	return UnescapeString(escapedLink);
end


local function Autotrade_MakeLink(linkType, data1, data2, data3, text)
	return "|cff33aaaa|HAutotrade:"..linkType..":"..data1..":"..data2..":"..data3.."|h{"..text.."}|h|r";
end


local function Autotrade_MakeMyBidLink(auction, text)
	return Autotrade_MakeLink("myBid", auction.owner, Autotrade_EscapeLink(auction.link), auction.auctionId, text);
end


local function Autotrade_MakeMyAuctionLink(auction, text)
	return Autotrade_MakeLink("myAuction", auction.owner, Autotrade_EscapeLink(auction.link), auction.auctionId, text);
end

local function Autotrade_MakeAllAuctionsLink(auction, text)
	return Autotrade_MakeLink("allAuctions", auction.owner, Autotrade_EscapeLink(auction.link), auction.auctionId, text);
end


local function Autotrade_ActivateMyBidLink(owner, escapedLink, auctionId)
	local testAuction = {};
	testAuction.owner = owner;
	testAuction.link = Autotrade_UnescapeLink(escapedLink);
	testAuction.auctionId = auctionId;
	local foundAuction = Autotrade_FindAuctionInList(AuctionsBidOpen, testAuction);
	if (not foundAuction)
	then
		foundAuction = Autotrade_FindAuctionInList(AuctionsBidWon, testAuction);
		if (not foundAuction)
		then
			foundAuction = Autotrade_FindAuctionInList(AuctionsBidLost, testAuction);
			if (not foundAuction)
			then
				foundAuction = Autotrade_FindAuctionInList(AuctionsBidCancelled, testAuction);
			end
		end
	end

	if (foundAuction)
	then
		AutotradeBidAuctionsFrame.currentAuction = foundAuction;
		ForceAutotrade("AutotradeBidAuctionsFrame");
--		Autotrade_UpdateDetails(PageInfoByFrameName["AutotradeBidAuctionsFrame"]);
		AutotradeListFrame_Update(PageInfoByFrameName["AutotradeBidAuctionsFrame"], true)
	end
end


local function Autotrade_ActivateMyAuctionLink(owner, escapedLink, auctionId)
	local testAuction = {};
	testAuction.owner = owner;
	testAuction.link = Autotrade_UnescapeLink(escapedLink);
	testAuction.auctionId = auctionId;
	local foundAuction = Autotrade_FindAuctionInList(AuctionsMyDraft, testAuction);
	if (not foundAuction)
	then
		foundAuction = Autotrade_FindAuctionInList(AuctionsMyOpen, testAuction);
		if (not foundAuction)
		then
			foundAuction = Autotrade_FindAuctionInList(AuctionsMyClosed, testAuction);
		end
	end

	if (foundAuction)
	then
		AutotradeMyAuctionsFrame.currentAuction = foundAuction;
		ForceAutotrade("AutotradeMyAuctionsFrame");
--		Autotrade_UpdateDetails(PageInfoByFrameName["AutotradeMyAuctionsFrame"]);
		AutotradeListFrame_Update(PageInfoByFrameName["AutotradeMyAuctionsFrame"], true)
	end
end


local function Autotrade_ActivateAllAuctionsLink(owner, escapedLink, auctionId)
	local testAuction = {};
	testAuction.owner = owner;
	testAuction.link = Autotrade_UnescapeLink(escapedLink);
	testAuction.auctionId = auctionId;
	local foundAuction = Autotrade_FindAuctionInList(AuctionsOpen, testAuction);
	if (not foundAuction)
	then
		foundAuction = Autotrade_FindAuctionInList(AuctionsAllCancelled, testAuction);
	end

	if (foundAuction)
	then
		AutotradeAllAuctionsFrame.currentAuction = foundAuction;
		ForceAutotrade("AutotradeAllAuctionsFrame");
--		Autotrade_UpdateDetails(PageInfoByFrameName["AutotradeAllAuctionsFrame"]);
		AutotradeListFrame_Update(PageInfoByFrameName["AutotradeAllAuctionsFrame"], true)
	end
end


-- Autotrade links are of the form:
-- Autotrade:<linkType>:<typeData1>:<typeData2>:<typeData3>
-- <linkType> can be "myBid", "myAuction", or "auction"
-- for linkType of myBid:  Clicking it takes you to the My Bids frame and selects the auction picked by the data in the link:
--	typeData1 = auction owner
--	typeData2 = escaped auction link
--	typeData3 = auction id
-- NOTE: this cannot be local because it's called from ItemRef.lua
function Autotrade_ProcessLink(link)
	local index, length, type, data1, data2, data3 = string.find(link, "^Autotrade:([^:]+):([^:]+):([^:]+):([^:]+)$");
	if (index)
	then
		if (type == "myBid")
		then
			Autotrade_ActivateMyBidLink(data1, data2, data3);
		elseif (type == "myAuction")
		then
			Autotrade_ActivateMyAuctionLink(data1, data2, data3);
		elseif (type == "allAuctions")
		then
			Autotrade_ActivateAllAuctionsLink(data1, data2, data3);
		end
	end
	if (not index)
	then
		Autotrade_LastLink = link;
	end
	return index;
end



--------- Notifications ----------------------------------------------------


-- returns true if it notified the user.
local function NotifyUser(type, auctionInfo)
	local message;
	local sound;

	local wcolor = "";
	local lbrace = "";
	local rbrace = "";
	if ( getglobal( "COS_WHOLINK_COLOR_X" ) == 1 ) then wcolor = "|c2288ffaa"; end
	if ( getglobal( "COS_WHOLINK_BRACE_X" ) == 1 ) then lbrace = "["; rbrace = "]"; end

	if (Autotrade_ShowNotification and Autotrade_ShowNotification[type])
	then
		-- Set message & sound based on message type & auction info
		if (type == NotificationType.New or type == NotificationType.NewSilent)
		then
			if (type ~= NotificationType.NewSilent)
			then
				sound = "TellMessage";
			end
			local auctionLink = Autotrade_MakeAllAuctionsLink(auctionInfo, "Jump to auction");
			if (auctionInfo.count > 1)
			then
				if ( getglobal( "COS_WHOLINK_A_X" ) == 1) then
					message = wcolor.."|HWhoLink:"..auctionInfo.owner.."|h"..lbrace..auctionInfo.owner..rbrace.."|h|r".." is selling "..auctionInfo.link.."x"..auctionInfo.count..".   "..auctionLink;
				else
					message = auctionInfo.owner.." is selling "..auctionInfo.link.."x"..auctionInfo.count..".   "..auctionLink;
				end
			else
				if ( getglobal( "COS_WHOLINK_A_X" ) == 1) then
					message =wcolor.."|HWhoLink:"..auctionInfo.owner.."|h"..lbrace..auctionInfo.owner..rbrace.."|h|r".." is selling "..auctionInfo.link..".   "..auctionLink;
				else
					message = auctionInfo.owner.." is selling "..auctionInfo.link..".   "..auctionLink;
				end
			end
		elseif (type == NotificationType.Sold)
		then
			sound = "TellMessage";
			local auctionLink = Autotrade_MakeMyAuctionLink(auctionInfo, auctionInfo.name);
			message = "Your Auction Ended: "..auctionLink..".  Sold to "..auctionInfo.bidder.." for "..Autotrade_GetCoinString(auctionInfo.highestBid);
		elseif (type == NotificationType.Ended)
		then
			local auctionLink = Autotrade_MakeMyAuctionLink(auctionInfo, auctionInfo.name);
			message = "Your Auction Ended: "..auctionLink.."."
			sound = "TellMessage";
		elseif (type == NotificationType.Won)
		then
			local auctionLink = Autotrade_MakeMyBidLink(auctionInfo, auctionInfo.owner.."'s "..auctionInfo.name);
			message = "You won "..auctionLink.." with a bid of "..Autotrade_GetCoinString(auctionInfo.highestBid)..".";
			sound = "TellMessage";
		elseif (type == NotificationType.GoingOnce)
		then
			if (auctionInfo.bidder and auctionInfo.bidder ~= UnitName("player"))
			then
				local auctionLink = Autotrade_MakeMyBidLink(auctionInfo, auctionInfo.owner.."'s "..auctionInfo.name);
				message = auctionLink.." Going Once to "..auctionInfo.bidder;
				sound = "TellMessage";
			end
		elseif (type == NotificationType.GoingTwice)
		then
			if (auctionInfo.bidder and auctionInfo.bidder ~= UnitName("player"))
			then
				local auctionLink = Autotrade_MakeMyBidLink(auctionInfo, auctionInfo.owner.."'s "..auctionInfo.name);
				message = auctionLink.." Going Twice to "..auctionInfo.bidder;
				sound = "TellMessage";
			end
		elseif (type == NotificationType.Outbid)
		then
			local auctionLink = Autotrade_MakeMyBidLink(auctionInfo, auctionInfo.owner.."'s "..auctionInfo.name);
			message = "You've been outbid on "..auctionLink..".";
			sound = "TellMessage";
		elseif (type == NotificationType.WishList)
		then
			local linkText;
			if (auctionInfo.count > 1)
			then
				linkText = auctionInfo.name.."x"..auctionInfo.count;
			else
				linkText = auctionInfo.name;
			end
			local auctionLink = Autotrade_MakeAllAuctionsLink(auctionInfo, linkText);
			if ( getglobal( "COS_WHOLINK_A_X" ) == 1) then
				message =  wcolor.."|HWhoLink:"..auctionInfo.owner.."|h"..lbrace..auctionInfo.owner..rbrace.."|h|r".." is selling "..auctionLink..", which is on your wish list";
			else
				message = auctionInfo.owner.." is selling "..auctionLink..", which is on your wish list";
			end
			sound = "TellMessage";
		elseif (type == NotificationType.Aborted)
		then
			local auctionLink = Autotrade_MakeMyBidLink(auctionInfo, auctionInfo.owner.."'s "..auctionInfo.name);
			message = "The auction for "..auctionLink.." has been aborted";
			sound = "TellMessage";
		end

		-- Send chosen message & sound
		if (message)
		then
			DEBUG_MSG(message, -1);
		end
		if (sound)
		then
			PlaySound(sound);
		end
	end
	return sound or message;
end


-- Handlers for Cosmos config page checkboxes
function Autotrade_SetSoldNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.Sold] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.Sold])
	then
		DEBUG_MSG("Turned on notifications for Sold event", 2);
	else
		DEBUG_MSG("Turned off notifications for Sold event", 2);
	end
end


function Autotrade_SetEndedNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.Ended] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.Ended])
	then
		DEBUG_MSG("Turned on notifications for Ended event", 2);
	else
		DEBUG_MSG("Turned off notifications for Ended event", 2);
	end
end


function Autotrade_SetOutbidNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.Outbid] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.Outbid])
	then
		DEBUG_MSG("Turned on notifications for Outbid event", 2);
	else
		DEBUG_MSG("Turned off notifications for Outbid event", 2);
	end
end


function Autotrade_SetWonNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.Won] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.Won])
	then
		DEBUG_MSG("Turned on notifications for Won event", 2);
	else
		DEBUG_MSG("Turned off notifications for Won event", 2);
	end
end


function Autotrade_SetLostNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.Lost] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.Lost])
	then
		DEBUG_MSG("Turned on notifications for Lost event", 2);
	else
		DEBUG_MSG("Turned off notifications for Lost event", 2);
	end
end


function Autotrade_SetWishListNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.WishList] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.WishList])
	then
		DEBUG_MSG("Turned on notifications for WishList event", 2);
	else
		DEBUG_MSG("Turned off notifications for WishList event", 2);
	end
end


function Autotrade_SetNewNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.New] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.New])
	then
		DEBUG_MSG("Turned on notifications for New event", 2);
	else
		DEBUG_MSG("Turned off notifications for New event", 2);
	end
end

function Autotrade_SetAbortedNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.Aborted] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.Aborted])
	then
		DEBUG_MSG("Turned on notifications for Aborted event", 2);
	else
		DEBUG_MSG("Turned off notifications for Aborted event", 2);
	end
end

function Autotrade_SetSilentNewNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.NewSilent] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.NewSilent])
	then
		DEBUG_MSG("Turned on silent chat notifications for New event", 2);
	else
		DEBUG_MSG("Turned off silent chat notifications for New event", 2);
	end
end


function Autotrade_SetGoingGoingGoneNotification(value, checked)
	Autotrade_ShowNotification[NotificationType.GoingOnce] = (checked == 1);
	Autotrade_ShowNotification[NotificationType.GoingTwice] = (checked == 1);
	if (Autotrade_ShowNotification[NotificationType.GoingOnce])
	then
		DEBUG_MSG("Turned on notifications for Going Once and Going Twice events", 2);
	else
		DEBUG_MSG("Turned off notifications for Going Once and Going Twice events", 2);
	end
end


--------- General frame management support functions -----------------------

local function AutotradeFrame_ShowSubFrame(frameName)
	DEBUG_MSG("Toggling subframe "..frameName, 3);
	for index, value in AutotradeSubFrames do

		if ( value == frameName )
		then
			DEBUG_MSG("Showing frame "..value, 4);
			getglobal(value):Show()
		else
			DEBUG_MSG("Hiding frame "..value, 4);
			getglobal(value):Hide();
		end
	end
	getglobal(frameName).typeFlags = nil;
	AutotradeListFrame_Update(PageInfoByFrameName[frameName], true);
end



local function Autotrade_AddAuctionToViewList(auctionInfo)
	if (Autotrade_AddAuctionToList(AuctionsOpen, auctionInfo))
	then
		-- try silent & loud notifications.  Don't do silent if we do loud, thoug
		local notified;
		notified = NotifyUser(NotificationType.New, auctionInfo);

		if (not notified)
		then
			NotifyUser(NotificationType.NewSilent, auctionInfo);
		end
	end

	-- Notify user if this is in their wish list
	if (Autotrade_FindInWishList(Autotrade_WishList, auctionInfo.name))
	then
		NotifyUser(NotificationType.WishList, auctionInfo);
	end
end


local function Autotrade_ResolveClosedAuction(auctionInfo)
	DEBUG_MSG("Resolving closed auction on "..auctionInfo.link, 3);
	DEBUG_MSG("ResolveClosedAuction: Searching in All Open for "..auctionInfo.link, 4);
	local foundAuction = Autotrade_FindAuctionInList(AuctionsOpen, auctionInfo);
	if (foundAuction)
	then
		-- Remove auction from All Auctions list.
		DEBUG_MSG("ResolveClosedAuction: Removing "..auctionInfo.link.." from All Open", 4);
		Autotrade_RemoveAuctionFromList(AuctionsOpen, auctionInfo);
		local frameAuction = AutotradeAllAuctionsFrame.currentAuction;
		if (frameAuction and
			frameAuction.owner == auctionInfo.owner and -- TODO: make nice auction comparison function
			frameAuction.link == auctionInfo.link and
			frameAuction.auctionId == auctionInfo.auctionId)
		then
			AutotradeAllAuctionsFrame.currentAuction = nil;
			Autotrade_HideAuctionDetails(PageInfoByFrameName["AutotradeAllAuctionsFrame"]);
		end

	end
	DEBUG_MSG("ResolveClosedAuction: moving from Bid Open to Bid Closed for "..auctionInfo.link, 4);
	foundAuction = Autotrade_FindAuctionInList(AuctionsBidOpen, auctionInfo);
	if (foundAuction)
	then
		foundAuction.bidder = auctionInfo.bidder;
		foundAuction.highestBid = auctionInfo.highestBid;
		DEBUG_MSG("ResolveClosedAuction: Moving "..auctionInfo.link.." from Bid Open to Bid Closed", 4);
		Autotrade_RemoveAuctionFromList(AuctionsBidOpen, foundAuction);
		local targetList = nil;
		local newStatus;
		if (auctionInfo.bidder and auctionInfo.bidder == UnitName("player"))
		then
			NotifyUser(NotificationType.Won, foundAuction);
			targetList = AuctionsBidWon;
			newStatus = AuctionTypeBidWon;

			-- Remove from wish list if desired
			if (foundAuction.autoRemove)
			then
				Autotrade_RemoveFromWishList(Autotrade_WishList, foundAuction.name);
			end
		else
			targetList = AuctionsBidLost;
			newStatus = AuctionTypeBidLost;
		end
		foundAuction.status = newStatus;
		Autotrade_AddAuctionToList(targetList, foundAuction);
	end
	if (AutotradeFrame.activeFrame)
	then
		AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame]);
	end
end


local function Autotrade_UpdateAuctionData(auctionInfo, updatedAuction)
	auctionInfo.bidder = updatedAuction.bidder;
	auctionInfo.highestBid = updatedAuction.highestBid;
	auctionInfo.countdownTime = updatedAuction.countdownTime;
	auctionInfo.elapsedTime = updatedAuction.elapsedTime;
	auctionInfo.location = updatedAuction.location;
	auctionInfo.bidderLocation = updatedAuction.bidderLocation;
end


local function Autotrade_UpdateAuctionInViewList(updatedAuctionInfo)
	-- Update All Auctions list -----------
	local auctionInfo = Autotrade_FindAuctionInList(AuctionsOpen, updatedAuctionInfo);
	if (not auctionInfo)
	then
		-- it's not there, so add it
		Autotrade_AddAuctionToViewList(updatedAuctionInfo);
	else
		-- it's there, just update it.
		Autotrade_UpdateAuctionData(auctionInfo, updatedAuctionInfo);
	end

	-- Update Bidding Auctions list -----------
	auctionInfo = Autotrade_FindAuctionInList(AuctionsBidOpen, updatedAuctionInfo);
	if (auctionInfo)
	then
		-- it's there, so update it.

		-- If we were outbid (a bid came in higher than ours, and wasn't from us
		if (auctionInfo.bidder == UnitName("player") and
			updatedAuctionInfo.bidder ~= UnitName("player") and
			updatedAuctionInfo.highestBid > auctionInfo.highestBid)
		then
			local link = Autotrade_MakeMyBidLink(auctionInfo, auctionInfo.owner.."'s "..auctionInfo.name);
			NotifyUser(NotificationType.Outbid, auctionInfo);
		end
		Autotrade_UpdateAuctionData(auctionInfo, updatedAuctionInfo);
	end

	-- redisplay cuz stuff's changed! -----------
	if (AutotradeFrame.activeFrame)
	then
		AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame]);
	end

end


-- Called when an auctioneer leaves the channel.
local function CancelAuctionsByOwner(owner)
	-- set search criteria to be the owner
	local criteria = {};
	criteria.owner = owner;

	if (owner == UnitName("player"))
	then
		for index, auction in AuctionsOpen do
			auction.status = AuctionTypeMyCancelled;
			Autotrade_AddAuctionToList(AuctionsMyCancelled, auction);
		end
		Autotrade_ClearList(AuctionsMyOpen);
	end

	DEBUG_MSG("Removing auctions for user "..owner, 3);
	-- find matching auctions in All Auctions and Bidding Auctions lists.  Then remove them and mark them as cancelled
	local auctions = Autotrade_FindMatchingAuctions(AuctionsOpen, criteria);
	DEBUG_MSG("Removing "..table.getn(auctions).." auctions from All Auctions", 4);
	for index, auction in auctions do
		Autotrade_RemoveAuctionFromList(AuctionsOpen, auction);
		Autotrade_AddAuctionToList(AuctionsAllCancelled, auction);
		auction.status = AuctionTypeAllCancelled;
	end
	auctions = Autotrade_FindMatchingAuctions(AuctionsBidOpen, criteria);
	DEBUG_MSG("Removing "..table.getn(auctions).." auctions from Bidding Auctions", 4);
	for index, auction in auctions do
		Autotrade_RemoveAuctionFromList(AuctionsBidOpen, auction);
		Autotrade_AddAuctionToList(AuctionsBidCancelled, auction);
		auction.status = AuctionTypeBidCancelled;
		NotifyUser(NotificationType.Aborted, auction);
	end

	-- redisplay.
	local pageInfo = PageInfoByFrameName[AutotradeFrame.activeFrame];
	if (pageInfo)
	then
		AutotradeListFrame_Update(pageInfo);
		-- diff3
		Autotrade_UpdateDetails(pageInfo);
	end
end


--------- Communication Channels -------------------------------------------

local function Autotrade_GetChannelNumber(channel)
	local num = 0;
	for i = 1, 9, 1 do
		local channelNum, channelName = GetChannelName(i);

		if (channelNum > 0 and
			channelName ~= nil and
			channelName == channel)
		then
			num = channelNum;
			break;
		end
	end

	return num;
end


local function Autotrade_GetPlayerFaction()
	local faction;
	local race = UnitRace("player");
	for index, hordeRace in HordeRaces do
		if (race == hordeRace)
		then
			faction = AutotradeFactionHorde;
			break;
		end
	end
	if (not channel)
	then
		for index, allianceRace in AllianceRaces do
			if (race == allianceRace)
			then
				faction = AutotradeFactionAlliance;
				break;
			end
		end
	end
	if (faction)
	then
		DEBUG_MSG("Player faction is "..faction, 4);
	else
		if (race)
		then
			DEBUG_MSG("Could not find player faction. ("..race..")", 4);
		else
			DEBUG_MSG("Could not find player race", 4);
		end
	end
	return faction;
end


local function Autotrade_GetPlayerGlobalChannel()
	local channel = AutotradeGlobalChannels[AutotradePlayerFaction];
	if (DEBUG_COMM and channel)
	then
		channel = channel.."DEBUG";
	end
	return channel;
end


-- TODO: clean up now that channel stuff is better handled by client.
local function Autotrade_JoinChannel(channelName)
	local channelNumber = Autotrade_GetChannelNumber(channelName);
	local needToJoin = (channelNumber <= 0);

	if (not needToJoin)
	then
		DEBUG_MSG("Already in channel "..channelNumber..". "..channelName, 3);
	else
		local i = 1;
		while ( DEFAULT_CHAT_FRAME.channelList[i] ) do
			DEBUG_MSG("DEFAULT_CHAT_FRAME.channelList["..i.."] == "..DEFAULT_CHAT_FRAME.channelList[i], 4);
			local zoneValue = "nil";
			if (DEFAULT_CHAT_FRAME.zoneChannelList[i])
			then
				zoneValue = DEFAULT_CHAT_FRAME.zoneChannelList[i];
			end
			DEBUG_MSG("DEFAULT_CHAT_FRAME.zoneChannelList["..i.."] == "..zoneValue, 4);
			if ( strupper(DEFAULT_CHAT_FRAME.channelList[i]) == strupper(channelName) and
				DEFAULT_CHAT_FRAME.zoneChannelList[i] and DEFAULT_CHAT_FRAME.zoneChannelList[i] > 0)
			then
				needToJoin = false;
				break;
			end
			i = i + 1;
		end
		DEBUG_MSG("Joining channel "..channelName, 3);

		JoinChannelByName(channelName, "", DEFAULT_CHAT_FRAME:GetID());
		DEFAULT_CHAT_FRAME.channelList[i] = channelName;
		DEFAULT_CHAT_FRAME.zoneChannelList[i] = 0;
	end
end


local function Autotrade_LeaveChannel(channelName)
	LeaveChannelByName(channelName, "", DEFAULT_CHAT_FRAME:GetID());
end


local function Autotrade_SendMessageOnChannel(message, channelName)
	local channelNum = Autotrade_GetChannelNumber(channelName);

	if (not channelNum)
	then
		Autotrade_JoinChannel(channelName);
		channelNum = Autotrade_GetChannelNumber(channelName);
	end

	if (not channelNum)
	then
		DEBUG_MSG("Autotrade Error: Not in autotrade channel \""..channelName.."\" and failed to rejoin.", -1);
		return;
	end

	-- diff3 - All SendChatMessage craches then extended questlog are active
	DEBUG_MSG("Sending on channel "..channelNum..". "..channelName..": "..message, 3);
  SendChatMessage(message, "CHANNEL", GetLanguageByIndex(0), channelNum);
end


local function Autotrade_SendMessage(message)
	local channelName = Autotrade_GetPlayerGlobalChannel();
	Autotrade_SendMessageOnChannel(message, channelName);
	--TODO: continue and send on local channels etc.
end


local function Autotrade_SetupCommunication()
	AutotradePlayerFaction = Autotrade_GetPlayerFaction();
	if (AutotradePlayerFaction)
	then
		DEBUG_MSG("Setting up comm.  Player faction is "..AutotradePlayerFaction, 4);
		local channel = Autotrade_GetPlayerGlobalChannel();
		Autotrade_JoinChannel(channel);
	else
		DEBUG_MSG("Failed to set up comm.  Player faction still unknown", 4);
	end
end


local function Autotrade_ShutdownCommunication()
	AutotradePlayerFaction = Autotrade_GetPlayerFaction();
	if ( AutotradePlayerFaction ~= nil ) then
	DEBUG_MSG("Shutting down comm.  Player faction is "..AutotradePlayerFaction, 4);
	local channel = Autotrade_GetPlayerGlobalChannel();
	Autotrade_LeaveChannel(channel);
	end
end




--------- Message Generation and Parsing -----------------------------------

function GetZoneFilterString(auction)
	return EncodeZoneFilterString(auction.zoneFilters);
end


function Autotrade_NewAuction_Owner(link, texture, count)
	local newAuction = {};
	if (not link)
	then
		return nil;
	end

	if (not texture)
	then
		return nil;
	end

	newAuction.link = link;
	Autotrade_FillAuctionFromLink(newAuction);

	newAuction.owner = UnitName("player");
	newAuction.texture = texture;

	if (not count)
	then
		newAuction.count = 1;
	else
		newAuction.count = count;
	end

	return newAuction;
end


local function GetMoneyAmountFromParsedArrays(amount, coin)
	local bid = 0;
	if (not amount or not coin)
	then
		return bid;
	end
	for index, coinType in coin do
		if (coinType == "g")
		then
			bid = bid + Autotrade_MakeIntFromString(amount[index]) * COPPER_PER_GOLD;
		elseif (coinType == "s")
		then
			bid = bid + Autotrade_MakeIntFromString(amount[index]) * COPPER_PER_SILVER;
		elseif (coinType == "c")
		then
			bid = bid + Autotrade_MakeIntFromString(amount[index]);
		end
	end
	return bid;
end


function Autotrade_AuctionToString(auction)
	local message = "[Auction: ";
	newAuction = {};
	local separator = "";
	for index, value in auction do
		message = message..separator..index.." = ";
		if (value)
		then
			if (index ~= "zoneFilters")
			then
				message = message..value;
			else
				message = message.."<zoneFilters>";
			end
		else
			message = message.."nil";
		end
		separator = "; ";
	end
	-- any special cases for table values should be broken out here
	-- none yet.

	return message.."]";
end


local function GetEscapedLocation()
	local zoneText = GetMinimapZoneText();
	if (not zoneText)
	then
		zoneText = "";
	end
	return EscapeString(zoneText, ",");
end


local function UnescapeLocation(escapedLocation)
	return UnescapeString(escapedLocation);
end


-- Send WTS message
local function Autotrade_SendSellMessage(auctionInfo)
	DEBUG_MSG("Sending sell message for "..Autotrade_AuctionToString(auctionInfo), 3);
	local auctionMessage;
	local count;
	if (auctionInfo.count > 1)
	then
		count = "x"..auctionInfo.count;
	else
		count = "";
	end
	if (auctionInfo.flatSale and auctionInfo.minBid and auctionInfo.minBid > 0)
	then
		auctionMessage = string.format(AutotradeMessageFormat.FlatSale, auctionInfo.link, count, Autotrade_GetCoinString(auctionInfo.minBid), auctionInfo.auctionId, GetEscapedLocation(), GetZoneFilterString(auctionInfo), auctionInfo.texture);
	elseif (auctionInfo.minBid and auctionInfo.minBid > 0)
	then
		auctionMessage = string.format(AutotradeMessageFormat.Sell, auctionInfo.link, count, Autotrade_GetCoinString(auctionInfo.minBid), auctionInfo.auctionId, auctionInfo.countdownTime - auctionInfo.elapsedTime, GetEscapedLocation(), GetZoneFilterString(auctionInfo), auctionInfo.texture);
	else
		auctionMessage = string.format(AutotradeMessageFormat.SellNoMin, auctionInfo.link, count, auctionInfo.auctionId, auctionInfo.countdownTime - auctionInfo.elapsedTime, GetEscapedLocation(), GetZoneFilterString(auctionInfo), auctionInfo.texture);
	end

	Autotrade_SendMessage(auctionMessage);
end


-- See if it's a WTS message
local function Autotrade_ParseAuctionString(message)
	local auction;
	local index;
	local length;
	local coin = {};
	local amount = {};
	local link;
	local auctionId;
	local texture;
	local count;
	local duration;
	local escapedDuration;
	local meetFlags;
	local flatSale;

	-- see if it's a new auction listing
	DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.SellNoMin..">", 3);
	index, length, link, count, auctionId, duration, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.SellNoMin);
	if (not index)
	then
		DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.SellShort..">", 3);
		index, length, link, count, amount[1], coin[1], auctionId, duration, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.SellShort);
		if (not index)
		then
			DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.SellLong..">", 3);
			index, length, link, count, amount[1], coin[1], amount[2], coin[2], auctionId, duration, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.SellLong);
			if (not index)
			then
				DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.FlatSaleShort..">", 3);
				index, length, link, count, amount[1], coin[1], auctionId, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.FlatSaleShort);
				if (index)
				then
					duration = 0;
					flatSale = 1;
				else
					DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.FlatSaleLong..">", 3);
					index, length, link, count, amount[1], coin[1], amount[2], coin[2], auctionId, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.FlatSaleLong);
					if (index)
					then
						duration = 0;
						flatSale = 1;
					else
						DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.OldSellNoMin..">", 3);
						index, length, link, count, auctionId, duration, escapedLocation, texture = string.find(message, AutotradePayloadFormat.OldSellNoMin);
						if (not index)
						then
							DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.OldSellShort..">", 3);
							index, length, link, count, amount[1], coin[1], auctionId, duration, escapedLocation, texture = string.find(message, AutotradePayloadFormat.OldSellShort);
							if (not index)
							then
								DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.OldSellLong..">", 3);
								index, length, link, count, amount[1], coin[1], amount[2], coin[2], auctionId, duration, escapedLocation, texture = string.find(message, AutotradePayloadFormat.OldSellLong);
							end
						end
					end
				end
			end
		end
	end
	if (index)
	then
		DEBUG_MSG("Found pattern.", 3);
		local minBid = GetMoneyAmountFromParsedArrays(amount, coin);
		local message = "Found new auction of "..link;
		if (count and count ~= "")
		then
			if (strsub(count, 1, 1) == "x")
			then
				count = Autotrade_MakeIntFromString(strsub(count, 2));
				message = message.."x"..count;
			else
				count = 1;
			end
		end
		if (minBid > 0)
		then
			message = message.." min "..Autotrade_GetCoinString(minBid);
		end
		DEBUG_MSG(message, 2);
		local location = UnescapeLocation(escapedLocation);
		local zoneFilter = Autotrade_DecodeZoneFilterString(meetFlags);
		local auction = {};
		auction.link = link;
		auction.auctionId = auctionId;
		auction.countdownTime = duration;
		auction.elapsedTime = 0;
		auction.texture = texture;
		auction.count = Autotrade_MakeIntFromString(count);
		auction.minBid = minBid;
		auction.location = location;
		auction.zoneFilters = zoneFilter;
		auction.flatSale = flatSale;
		if (flatSale)
		then
			auction.bid = auction.minBid;
		end
		return auction;
	end
end

-- Send WTS update message
local function Autotrade_SendUpdateMessage(auctionInfo)
	local auctionMessage;
	local count;
	if (auctionInfo.count > 1)
	then
		count = "x"..auctionInfo.count;
	else
		count = "";
	end
	auctionMessage = string.format(AutotradeMessageFormat.Update, auctionInfo.link, count, Autotrade_GetCoinString(auctionInfo.highestBid), auctionInfo.bidder, auctionInfo.auctionId, auctionInfo.countdownTime - auctionInfo.elapsedTime, GetEscapedLocation(), GetZoneFilterString(auctionInfo), auctionInfo.texture);

	Autotrade_SendMessage(auctionMessage);
end


-- Try to parse WTS update message
local function Autotrade_ParseUpdateString(message)
	local index;
	local length;
	local coin = {};
	local amount = {};
	local link;
	local bidder;
	local auctionId;
	local texture;
	local count;
	local duration;
	local escapedLocation;
	local meetFlags;

	-- See if it's an update to an existing auction
	DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.UpdateLong..">", 3);
	index, length, link, count, amount[1], coin[1], amount[2], coin[2], bidder, auctionId, duration, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.UpdateLong);
	if (not index)
	then
		DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.UpdateShort..">", 3);
		index, length, link, count, amount[1], coin[1], bidder, auctionId, duration, escapedLocation, meetFlags, texture = string.find(message, AutotradePayloadFormat.UpdateShort);
		if (not index)
		then
			DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.UpdateLong..">", 3);
			index, length, link, count, amount[1], coin[1], amount[2], coin[2], bidder, auctionId, duration, escapedLocation, texture = string.find(message, AutotradePayloadFormat.OldUpdateLong);
			if (not index)
			then
				DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.UpdateShort..">", 3);
				index, length, link, count, amount[1], coin[1], bidder, auctionId, duration, escapedLocation, texture = string.find(message, AutotradePayloadFormat.OldUpdateShort);
			end
		end
	end

	if (index)
	then
		DEBUG_MSG("Found pattern.", 3);
		local bid = GetMoneyAmountFromParsedArrays(amount, coin);
		local message = "Found offer of "..Autotrade_GetCoinString(bid).." by "..bidder.." on "..link;
		if (count and count ~= "")
		then
			if (strsub(count, 1, 1) == "x")
			then
				count = Autotrade_MakeIntFromString(strsub(count, 2));
				message = message.."x"..count;
			else
				count = 1;
			end
		end
		DEBUG_MSG(message, 3);
		local location = UnescapeLocation(escapedLocation);
		local zoneFilter = Autotrade_DecodeZoneFilterString(meetFlags);
		local auction = {};
		auction.highestBid = bid;
		auction.bidder = bidder;
		auction.link = link;
		auction.count = Autotrade_MakeIntFromString(count);
		auction.texture = texture;
		auction.auctionId = auctionId;
		auction.countdownTime = duration;
		auction.elapsedTime = 0;
		auction.location = location;
		auction.zoneFilters = zoneFilter;
		return auction;
	end

end


-- Send SOLD or ENDED message
local function Autotrade_SendClosedMessage(auctionInfo)
	local auctionMessage;
	local count;
	if (auctionInfo.count > 1)
	then
		count = "x"..auctionInfo.count;
	else
		count = "";
	end
	if (auctionInfo.highestBid and auctionInfo.bidder)
	then
		auctionMessage = string.format(AutotradeMessageFormat.Sold, auctionInfo.link, count, auctionInfo.bidder, Autotrade_GetCoinString(auctionInfo.highestBid), auctionInfo.auctionId, GetEscapedLocation());
	else
		auctionMessage = string.format(AutotradeMessageFormat.Ended, auctionInfo.link, count, auctionInfo.auctionId);
	end

	Autotrade_SendMessage(auctionMessage);
end


-- Try to parse SOLD or ENDED message;
local function Autotrade_ParseEndedString(message)
	local index;
	local length;
	local coin = {};
	local amount = {};
	local link;
	local bidder;
	local auctionId;
	local texture;
	local count;
	local escapedLocation;

	-- See if it's an end to an auction
	DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.SoldLong..">", 3);
	index, length, link, count, bidder, amount[1], coin[1], amount[2], coin[2], auctionId, escapedLocation = string.find(message, AutotradePayloadFormat.SoldLong);
	if (not index)
	then
		DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.SoldShort..">", 3);
		index, length, link, count, bidder, amount[1], coin[1], auctionId, escapedLocation = string.find(message, AutotradePayloadFormat.SoldShort);
		if (not index)
		then
			DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.Ended..">", 3);
			index, length, link, count, auctionId = string.find(message, AutotradePayloadFormat.Ended);
		end
	end
	if (index)
	then
		DEBUG_MSG("Found pattern.", 3);
		local bid = GetMoneyAmountFromParsedArrays(amount, coin);
		local message;
		if (bid > 0)
		then
			message = "Found offer of "..Autotrade_GetCoinString(bid).." by "..bidder.." on "..link;
		else
			message = "Found unsuccessful auction end on "..link;
		end

		if (count and count ~= "")
		then
			if (strsub(count, 1, 1) == "x")
			then
				count = Autotrade_MakeIntFromString(strsub(count, 2));
				message = message.."x"..count;
			else
				count = 1;
			end
		end
		DEBUG_MSG(message, 3);
		local location;
		if (escapedLocation)
		then
			location = UnescapeLocation(escapedLocation);
		end
		return bid, link, auctionId, bidder, location;
	end

end


-- Send OFFER message
local function Autotrade_MakeBid(pageInfo)
	local auction = pageInfo.frame.currentAuction;
	if (auction)
	then
		-- save bid in local store
		auction.bid = pageInfo.lowerMoneyFrame.staticMoney;
		local count;
		if (auction.count > 1)
		then
			count = " x"..auction.count;
		else
			count = "";
		end

		if ( Autotrade_GetCoinString(auction.bid) ~= nil ) then
			local bidMessage = string.format(AutotradeMessageFormat.Bid, Autotrade_GetCoinString(auction.bid), auction.owner, auction.link, count, auction.auctionId.."", GetEscapedLocation());
			Autotrade_SendMessage(bidMessage);
		end
	end
end


-- Try to parse OFFER message
local function Autotrade_ParseBidString(message)
	local index;
	local length;
	local coin = {};
	local amount = {};
	local link;
	local owner;
	local auctionId;
	local count;
	local escapedLocation;

	-- See if it's a bid
	DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.BidLong..">", 3);
	index, length, amount[1], coin[1], amount[2], coin[2], owner, link, count, auctionId, escapedLocation = string.find(message, AutotradePayloadFormat.BidLong);
	if (not index)
	then
		DEBUG_MSG("Checking <"..message.."> for pattern <"..AutotradePayloadFormat.BidShort..">", 3);
		index, length, amount[1], coin[1], owner, link, count, auctionId, escapedLocation = string.find(message, AutotradePayloadFormat.BidShort);
	end
	if (index)
	then
		DEBUG_MSG("Found pattern.", 3);
		local bid = GetMoneyAmountFromParsedArrays(amount, coin);
		DEBUG_MSG("Found bid "..Autotrade_GetCoinString(bid).." on "..owner.."'s "..link..".", 3);
		local location = UnescapeLocation(escapedLocation);
		local bidInfo = {};
		bidInfo.bid = bid;
		bidInfo.link = link;
		bidInfo.auctionId = auctionId;
		bidInfo.owner = owner;
		bidInfo.location = location;
		return bidInfo;
	end

end

-- Find what type of message it is, and return message params
local function Autotrade_ParseChatMessage(message, sender)
	local version;
	local payload;
	local index;
	local length;
	index, length, version, payload = string.find(message, AutotradeMessageFramework);
	if (index and not SupportedVersion(version))
	then
		if (MessageVersionIsNewerThanCode(version) and not PrintedVersionError)
		then
			DEBUG_MSG("Error: Received a message that is more advanced than what this version of Cosmos Autotrade can understand.  This likely means there is an updated version available.  (This message will not be shown again for the remainder of this session.)", -1, 1, 0, 0);
			PrintedVersionError = true;
		end
		if (not CanUnderstandVersion(version))
		then
			-- return true to suppress message display, but don't process it.
			return true;
		end
	end
	local prefix;
	if (index)
	then
		prefix = true;
	else
		payload = message;
	end
	local messageInfo = nil;

	if (prefix and version and payload)
	then
		DEBUG_MSG("Found version "..version..", payload \""..payload.."\".", 3);
	end

	local bid;
	bid = Autotrade_ParseBidString(payload);
	if (bid)
	then
		-- found bid offer
		messageInfo = {};
		messageInfo.auctionInfo = {};
		messageInfo.auctionInfo.bid = bid.bid;
		messageInfo.auctionInfo.owner = bid.owner;
		messageInfo.auctionInfo.link = bid.link;
		messageInfo.auctionInfo.auctionId = bid.auctionId;
		messageInfo.auctionInfo.bidderLocation = bid.location;
		messageInfo.isBid = true;
		Autotrade_FillAuctionFromLink(messageInfo.auctionInfo);
	else
		local updatedAuction = Autotrade_ParseUpdateString(payload);
		if (updatedAuction)
		then
			-- found auction status update
			messageInfo = {};
			messageInfo.auctionInfo = updatedAuction;
			messageInfo.auctionInfo.owner = sender;
			messageInfo.auctionInfo.status = AuctionTypeAllOpen;
			messageInfo.isUpdate = true;
			Autotrade_FillAuctionFromLink(messageInfo.auctionInfo);
		else
			-- see if we found auction begin message
			local newAuction = Autotrade_ParseAuctionString(payload);
			if (newAuction)
			then
				-- found auction begin message
				messageInfo = {};
				messageInfo.auctionInfo = newAuction;
				messageInfo.auctionInfo.owner = sender;
				messageInfo.auctionInfo.status = AuctionTypeAllOpen;
				messageInfo.isAuction = true;
				Autotrade_FillAuctionFromLink(messageInfo.auctionInfo);
			else
				-- see if we found sold or ended message
				local money;
				local link;
				local auctionId;
				local bidder;
				local location;
				money, link, auctionId, bidder, location = Autotrade_ParseEndedString(payload);
				if (link)
				then
					-- found sold or ended message
					messageInfo = {};
					messageInfo.auctionInfo = {};
					messageInfo.auctionInfo.highestBid = money;
					messageInfo.auctionInfo.bidder = bidder;
					messageInfo.auctionInfo.owner = sender;
					messageInfo.auctionInfo.link = link;
					messageInfo.auctionInfo.auctionId = auctionId;
					messageInfo.auctionInfo.status = AuctionTypeBidClosed;
					messageInfo.auctionInfo.location = location;
					messageInfo.isEnded = true;
					Autotrade_FillAuctionFromLink(messageInfo.auctionInfo);
				end
			end
		end
	end

	return prefix, messageInfo;
end


local function Autotrade_MessageChannelIsAutotrade(channel)
	local isSpecific = false;
	if (channel == Autotrade_GetPlayerGlobalChannel())
	then
		isSpecific = true;
	end
	local resultString = "false";
	if (isSpecific)
	then
		resultString = "true";
	end
	if (channel)
	then
		DEBUG_MSG("Autotrade_MessageChannelIsAutotrade("..channel..") is returning "..resultString, 4);
	end
	return isSpecific;
end


-- would like to move this function down into Auction Management section, but it's called by a function in this section.
local function Autotrade_TakeBid(link, auctionId, bidder, amount)
	DEBUG_MSG("Autotrade_TakeBid("..link..", "..auctionId..", "..bidder..", "..amount..")", 2);
	local tempAuction = {};
	tempAuction.owner = UnitName("player");
	tempAuction.link = link;
	tempAuction.auctionId = auctionId;
	local auction = Autotrade_FindAuctionInList(AuctionsMyOpen, tempAuction);
	if (auction)
	then
		DEBUG_MSG("found auction with link "..link.."("..auctionId..")", 3);
	else
		DEBUG_MSG("Couldn't find matching auction "..link.."("..auctionId..")", 3);
	end

	if (auction and
		(auction.status == AuctionTypeOpen or
			auction.status == AuctionTypeAllOpen or
			auction.status == AuctionTypeBiddingOpen) and
		(not auction.minBid or amount >= auction.minBid) and
		(not auction.highestBid or amount > auction.highestBid))
	then
		if (auction.flatSale)
		then
			-- Buyer is buying flat-price sale item.  Close it out immediately.
			auction.highestBid = auction.minBid;
			auction.bidder = bidder;
			Autotrade_CloseAuction(auction);
		else
			-- Process bid
			auction.bidder = bidder;
			auction.highestBid = amount;
			-- Set countdown time for retransmission
			local oldCountdownTime = auction.countdownTime;
			local remainingTime = auction.countdownTime - auction.elapsedTime;
			if (remainingTime < AuctionCountdownTimeMinRefresh)
			then
				auction.countdownTime = AuctionCountdownTimeMinRefresh;
			else
				auction.countdownTime = remainingTime;
			end

			-- reset elapsed time for this bid's countdown
			auction.elapsedTime = 0;

			-- reset idle resend time
			auction.timeToResend = auction.elapsedTime + AuctionIdleResendTime;

			-- Send out Bid Accepted response
			Autotrade_SendUpdateMessage(auction);
		end

		-- update viewed UI, if any
		local pageInfo;
		if (AutotradeMyAuctionsFrame:IsVisible())
		then
			pageInfo = AutotradeMyAuctionsPageInfo;
		elseif (AutotradeAllAuctionsFrame:IsVisible())
		then
			pageInfo = AutotradeAllAuctionsPageInfo;
		end
		if (pageInfo)
		then
			AutotradeListFrame_Update(pageInfo);
		end
	end
end


-- ProcessChatMessage: receives message and acts on its contents.
--
-- returns true if the message is an Autotrade-specific message and should be hidden from the UI, otherwise returns false.
--
function Autotrade_ProcessChatMessage(channel, messageType, message, sender, eventType)
	local messageIsAutotradeSpecific = false;

	-- autotrade only parses messages sent by people
	if (not sender or not message)
	then
		return false;
	end

	local testMessage = "Processing chat message \""..message.."\" from "..sender;
	if (eventType)
	then
		testMessage = testMessage.." message type "..eventType;
	end
	if (channel)
	then
		testMessage = testMessage.." on channel "..channel;
	end
	DEBUG_MSG(testMessage, 4);

	if (not Autotrade_MessageChannelIsAutotrade(channel))
	then
		DEBUG_MSG("Not an Autotrade message.", 4);
		return false;
	end

	local processMessage = true;
	-- First check if it's a channel join/leave message.
	if (string.find(eventType, "CHANNEL_LEAVE") or
		(eventType == "CHANNEL_NOTICE" and message == "YOU_LEFT"))
	then
		-- someone left.  cancel all their auctions.

		messageIsAutotradeSpecific = true;
		-- fill in sender name if it's the user himself who left
		if (message == "YOU_LEFT")
		then
			sender = UnitName("player");
		end
		CancelAuctionsByOwner(sender);
		if (AutotradeFrame.activeFrame and not AutotradeFrame.activeFrame == "AutotradeMyAuctionsFrame")
		then
			Autotrade_UpdateDetails(PageInfoByFrameName[AutotradeFrame.activeFrame]);
		end

		processMessage = false;
	elseif (string.find(eventType, "CHANNEL_JOIN"))
	then
		messageIsAutotradeSpecific = true;
		processMessage = false;
	end

	-- Now check for any Autotrade-specific messages
	local hasPrefix;
	local payload;
	if (processMessage)
	then
		DEBUG_MSG("Parsing Message", 4);
		hasPrefix, payload = Autotrade_ParseChatMessage(message, sender);
		messageIsAutotradeSpecific = messageIsAutotradeSpecific or hasPrefix;
	end

	if (messageIsAutotradeSpecific)
	then
		DEBUG_MSG("Message is Autotrade-specific", 4);
	else
		DEBUG_MSG("Message is NOT Autotrade-specific", 4);
	end

	-- If we've parsed something, process it.
	if (processMessage and payload and payload.auctionInfo)
	then
		if (payload.isBid)
		then
			-- If this user owns the auction, try to process the bid
			if (payload.auctionInfo.owner == UnitName("player"))
			then
				Autotrade_TakeBid(payload.auctionInfo.link, payload.auctionInfo.auctionId, sender, payload.auctionInfo.bid);
			end
		elseif (payload.isUpdate)
		then
			Autotrade_UpdateAuctionInViewList(payload.auctionInfo);
		elseif (payload.isAuction)
		then
			Autotrade_AddAuctionToViewList(payload.auctionInfo);
			if (AutotradeFrame.activeFrame)
			then
				AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame]);
			end
		elseif (payload.isEnded)
		then
			Autotrade_ResolveClosedAuction(payload.auctionInfo);
		end
	end

	if (DEBUG_COMM and DEBUG_SHOW_MESSAGES)
	then
		messageIsAutotradeSpecific = false;
	end

	return (messageIsAutotradeSpecific or AutotradeMute);
end


-- For now, make global.  Can't be local if defined here because it's called up above.
function Autotrade_CloseAuction(auction)
	DEBUG_MSG("Auction for "..Autotrade_GetItemTitle(auction).." has closed.", 2);

	auction.status = AuctionTypeClosed;
	if (auction.owner == UnitName("player"))
	then
		local notification;
		if (auction.bidder)
		then
			notification = NotificationType.Sold;
		else
			notification = NotificationType.Ended;
		end
		NotifyUser(notification, auction);
		Autotrade_RemoveAuctionFromList(AuctionsMyOpen, auction);
		Autotrade_AddAuctionToList(AuctionsMyClosed, auction);
		Autotrade_SendClosedMessage(auction);
	end
end


local function Autotrade_AddTimeToAuctions(elapsed)
	-- update auction times.
	for index, auction in AuctionsMyOpen do
		auction.elapsedTime = auction.elapsedTime + elapsed;
	end
	for index, auction in AuctionsOpen do
		auction.elapsedTime = auction.elapsedTime + elapsed;
	end
	for index, auction in AuctionsBidOpen do
		if (not auction.flatSale)
		then
			-- For auctions we're bidding in, update time and send any Going Once/Going Twice notifications

			local oldTime = auction.elapsedTime;
			local newTime = oldTime + elapsed;
			auction.elapsedTime = newTime;

			local oldTimeLeft = auction.countdownTime - oldTime;
			local newTimeLeft = auction.countdownTime - newTime;

			if (oldTimeLeft > Autotrade_AuctionTimeThresholdGoingOnce)
			then
				if (newTimeLeft < Autotrade_AuctionTimeThresholdGoingOnce)
				then
					NotifyUser(NotificationType.GoingOnce, auction);
				end
			elseif (oldTimeLeft > Autotrade_AuctionTimeThresholdGoingTwice and
				newTimeLeft < Autotrade_AuctionTimeThresholdGoingTwice)
			then
				NotifyUser(NotificationType.GoingTwice, auction);
			end
		end
	end

	-- remove finished auctions, send timed updates, etc.
	local foundNewFinishedAuction = false;
	for index, auction in AuctionsMyOpen do
		if (not auction.flatSale and auction.elapsedTime > auction.countdownTime)
		then
			Autotrade_CloseAuction(auction);
			foundNewFinishedAuction = true;
		elseif (auction.elapsedTime > auction.timeToResend)
		then
			-- Re-notify everyone of auction status (for anyone who may have come online since it was started or bidded in)
			if (not auction.bidder)
			then
				Autotrade_SendSellMessage(auction);
			else
				Autotrade_SendUpdateMessage(auction);
			end

			-- Set next time to resend message.
			auction.timeToResend = auction.timeToResend + AuctionIdleResendTime;
		end
	end
	if (foundNewFinishedAuction)
	then
		if (AutotradeFrame.activeFrame)
		then
			AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame]);
		end
	end
end


--------- Communication code and core auction management -------------------

local function Autotrade_StartAuction(auctionInfo)
	auctionInfo.minBid = AutotradeMyAuctionsPageInfo.upperMoneyFrame.staticMoney;
	auctionInfo.status = AuctionTypeOpen;
	auctionInfo.countdownTime = auctionInfo.countdownTime;
	auctionInfo.elapsedTime = 0;
	auctionInfo.timeToResend = AuctionIdleResendTime;
	Autotrade_SendSellMessage(auctionInfo);

	Autotrade_RemoveAuctionFromList(AuctionsMyDraft, auctionInfo);
	Autotrade_AddAuctionToList(AuctionsMyOpen, auctionInfo);

	ForceAutotrade("AutotradeMyAuctionsFrame");
	AutotradeListFrame_Update(AutotradeMyAuctionsPageInfo, true);
end


----------------------------------------------------------------------------
--------- Main event handler functions and other global functions ----------
----------------------------------------------------------------------------

local function Autotrade_SetZoneFilters(zoneFilters)
	-- Receive new filter
	ZoneFilters = zoneFilters;

	-- Apply filter
	SetFilterState("zone", true);

	-- Redisplay list with filter applied
	AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame], true);
end


local function Autotrade_SetItemFilters(itemFilterStrings)
	-- Receive new filters, process them, and save them globally.
	ItemFilterStrings = itemFilterStrings;
	ItemFilters = MakeItemTypeFilterFromFlags(itemFilterStrings);

	-- Apply filter
	SetFilterState("item", true);

	-- Redisplay list with filter applied
	AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame], true);
end


local function Autotrade_Init()
	Autotrade_SetupCommunication();
	local i = 0;
	if (Autotrade_WishList) then
		for index, value in Autotrade_WishList do
			i = i + 1;
			break;
		end
	end
	if (i == 0)
	then
		Autotrade_WishList = Autotrade_LoadSavedWishList();
	end
end

function ToggleAutotrade(subFrameName)
	DEBUG_MSG("ToggleAutotrade("..subFrameName..")", 3);

 if (not Autotrade_ModEnabled)
	then
	 	return;
	end

	AutotradeFrame.activeFrame = subFrameName;
	local subFrame = getglobal(subFrameName);
	if ( subFrame )
	then
  DEBUG_MSG("AutoTrade", 3);
		PanelTemplates_SetTab(AutotradeFrame, subFrame:GetID());
    -- DEBUG_MSG("ToggleAutotrade("..PanelTemplates_SetTab..")", 3);
		if ( AutotradeFrame:IsVisible() )
		then
			if ( subFrame:IsVisible() )
			then
				AutotradeFrame.activeFrame = nil;
				HideUIPanel(AutotradeFrame);
			else
				PlaySound("igCharacterInfoTab");
				AutotradeFrame_ShowSubFrame(subFrameName);
			end
		else
			ShowUIPanel(AutotradeFrame);
			AutotradeFrame_ShowSubFrame(subFrameName);
		end
	end
end


function ForceAutotrade(subFrameName)
	DEBUG_MSG("ForceAutotrade("..subFrameName..")", 3);

	if (not Autotrade_ModEnabled)
	then
		return;
	end

	AutotradeFrame.activeFrame = subFrameName;
		local subFrame = getglobal(subFrameName);
	if ( subFrame )
	then
		PanelTemplates_SetTab(AutotradeFrame, subFrame:GetID());
		if ( AutotradeFrame:IsVisible() )
		then
			if ( not subFrame:IsVisible() )
			then
				PlaySound("igCharacterInfoTab");
				AutotradeFrame_ShowSubFrame(subFrameName);
			end
		else
			ShowUIPanel(AutotradeFrame);
			AutotradeFrame_ShowSubFrame(subFrameName);
		end
	end
end


function Autotrade_Enable(checked)
  checked = 1
	if (checked == 1) then
		DEBUG_MSG("Autotrade activated", 1);
		Autotrade_ModEnabled = true;
		-- Need full init if we've never loaded.  Otherwise we just need to rejoin channels etc.
		if (not AutotradeLoaded)
		then
			Autotrade_Init();
		else
			Autotrade_SetupCommunication();
		end
	else
		Autotrade_ShutdownCommunication();
		Autotrade_ModEnabled = false;
		DEBUG_MSG("Autotrade deactivated", 1);
	end
end

-- diff3, cosmos does not work.
--[[
local function RegisterNotificationCheckbox(cosmosId, text, tooltip, callback)
	Cosmos_RegisterConfiguration(cosmosId,
	"CHECKBOX",
	text,
	tooltip,
	callback,
	1,
	1,
	0,
	1,
	"",
	.01,
	1,
	"\%"
	);
end
]]

function AutotradeFrame_OnLoad()
  Cosmos_RegisterChatCommand();
  Autotrade_Enable();
	-- diff3 - cosmos does not work
	-- Register with CSM (Cosmos Master Configuration) --
	--[[local tempcarray = { "/autotrade", "/allauctions" }
	local tempcfunc = function (msg) ToggleAutotrade("AutotradeAllAuctionsFrame"); end
	Cosmos_RegisterChatCommand ( "AUTOTRADE_AA", tempcarray, tempcfunc, "Shows all auctions currently in progress", CSM_CHAINNONE );

  local tempcarray = { "/myauctions" }
	local tempcfunc = function (msg) ToggleAutotrade("AutotradeMyAuctionsFrame"); end
	Cosmos_RegisterChatCommand ( "AUTOTRADE_MY", tempcarray, tempcfunc, "Shows my auctions currently in progress", CSM_CHAINNONE );

	local tempcarray = { "/mybids" }
	local tempcfunc = function (msg) ToggleAutotrade("AutotradeBidAuctionsFrame"); end
	Cosmos_RegisterChatCommand ( "AUTOTRADE_BID", tempcarray, tempcfunc, "Shows my bids currently in progress", CSM_CHAINNONE );

	Cosmos_RegisterConfiguration("COS_AUTOTRADE","SECTION","Autotrade","This section is devoted to Autotrade options");
	Cosmos_RegisterConfiguration("COS_AUTOTRADE_SECTION","SEPARATOR","Autotrade","This section is devoted to Autotrade options");

  Cosmos_RegisterConfiguration("COS_ENABLEAUTOTRADE","CHECKBOX","Enable Autotrade",
	"Click here to turn on/off the Autotrade system,\nwhich manages auctions ",
	 Autotrade_Enable,
	 1,
	 1,
	 1,
	 1,
	 "",
	 .01,
	 1,
	 "\%"
	 );
	 Cosmos_RegisterConfiguration("COS_AUTOTRADEMUTE","CHECKBOX","Filter Channel Chatter",
 	 "Click here to turn on/off the Display of\nplayer chatter in the auction channel ",
 	 Autotrade_Mute,
 	 1,
 	 1,
 	 1,
  d	1
 	);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYSOLD",
		"Notify me when one of my items is sold",
		"Click here to toggle notifications when one of your items is sold",
		Autotrade_SetSoldNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYENDED",
		"Notify me when my auction ends unsuccessfully",
		"Click here to toggle notifications when one of your auctions ends with no sale",
		Autotrade_SetEndedNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYOUTBID",
		"Notify me when I am outbid in an auction",
		"Click here to toggle notifications when one you get outbid in an auction",
		Autotrade_SetOutbidNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYGGG",
		"Notify when when auctions are \"going,\" \"going,\" \"gone,\"",
		"Click here to toggle notifications when an auction I'm in is Going Once or Going Twice",
		Autotrade_SetGoingGoingGoneNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYWON",
		"Notify me when I win an auction",
		"Click here to toggle notifications when you win an auction",
		Autotrade_SetWonNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYLOST",
		"Notify me when I lose an auction",
		"Click here to toggle notifications when someone else wins an auction you're bidding in",
		Autotrade_SetLostNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYWISHLIST",
		"Notify me when a wish list item is for sale",
		"Click here to toggle notifications when one of your wish list item goes up for sale or auction",
		Autotrade_SetWishListNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYABORTED",
		"Notify me when an auction I'm bidding in gets aborted",
		"Click here to toggle notifications when an auction you bid in gets aborted because the seller quit or crashed",
		Autotrade_SetAbortedNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYNEW",
		"Notify me with audio and text when a new auction is posted",
		"Click here to toggle notifications when a new auction is posted to the All Auctions tab",
		Autotrade_SetNewNotification);

	RegisterNotificationCheckbox("COS_AUTOTRADENOTIFYNEWSILENT",
		"Notify me with text only when a new auction is posted",
		"Click here to toggle notifications when a new auction is posted to the All Auctions tab",
		Autotrade_SetSilentNewNotification);

	Cosmos_RegisterConfiguration("COS_END_SECTION","SEPARATOR","End of Options","");
]]--
	this:RegisterEvent("UNIT_NAME_UPDATE");
	-- diff3
	this:RegisterEvent("ITEM_LOCK_CHANGED");

	PanelTemplates_SetNumTabs(this, 3);
	PanelTemplates_SetTab(this, 1);

	--	Normally Setup comm gets handled in unit name update function, but on ReloadUI it should happen here because unit name does not change at that time.
	if (Autotrade_ModEnabled)
	then
		local name = UnitName("player");
		if (name and name ~= "" and name ~= "Unknown Being")
		then
			DEBUG_MSG("Initializing.  Player name known: "..name..".", 3);
			Autotrade_Init();
		end
	end
end

function Autotrade_ShowA()
	ToggleAutotrade("AutotradeAllAuctionsFrame");
end

function AutotradeFrameTab_OnClick()
  DEBUG_MSG("AutoTrade: "..this:GetName()..".", 3);
	if ( this:GetName() == "AutotradeFrameTab1" )
	then
		ToggleAutotrade("AutotradeMyAuctionsFrame");
	elseif ( this:GetName() == "AutotradeFrameTab2" )
	then
		ToggleAutotrade("AutotradeBidAuctionsFrame");
	elseif ( this:GetName() == "AutotradeFrameTab3" )
	then
		ToggleAutotrade("AutotradeAllAuctionsFrame");
	end
	PlaySound("igCharacterInfoTab");
end


function AutotradeSubFrame_OnLoad(pageInfo)
	this.currentAuction = nil;

	-- diff3
	-- money frame's 'small' flag is getting set to 0.  I think this is because all the OnLoad's get called at app startup, so sometimes this is left as 0 and other times it's left as 1.
	-- pageInfo.upperMoneyFrame.small = 1;
	-- pageInfo.upperMoneyFrame.staticMoney = 0;
	-- pageInfo.lowerMoneyFrame.small = 1;
	-- pageInfo.lowerMoneyFrame.staticMoney = 0;
end


function AutotradeSubFrame_OnHide(AutotradeMyAuctionsPageInfo)
	-- close down any choose zone stuff.
	-- diff3
	-- ChooseItemsFrame:Hide();
end

-- This function was so frustating to make
-- I will replace this the day I bother to learn regex
local function CutHyperlink(link)
	local str = ""

	for i = 1, string.len(link) -2 do
  	local c = string.sub(link, i, i)

		if (c == ":")	then break;	end
		str =  str .. c
	end

	return str
end


function AutotradeFrame_OnEvent()
	-- Don't resond if mod is disabled
	if (not Autotrade_ModEnabled)
	then
		return;
	end

	if (event == "UNIT_NAME_UPDATE" and not AutotradeLoaded)
	then
		if (arg1 == "player")
		then
			if (UnitName("player") ~= "Unknown Being" and UnitName("player") ~= "")
			then
				Autotrade_Init();
				AutotradeLoaded = true;
			end
		end
		-- diff3
	elseif (event == "ITEM_LOCK_CHANGED")
	then
		DEBUG_MSG("ITEM_LOCK_CHANGED");

		-- This is broken, get an error messages
		if GetMouseFocus():GetParent():GetID() then
			-- This i my fix for AUTO_TRADE_DRAGGED_ITEM_INFO
			-- basecly I get bag and slot then we moce an item

			slot = GetMouseFocus():GetID();
			bag = GetMouseFocus():GetParent():GetID();

			-- It's ugly but it work, cut the ID out of a ItemLink
			mouse_item = GetContainerItemLink(bag, slot);
			mouse_item = string.sub(mouse_item, 18)
			mouse_item = CutHyperlink(mouse_item);
			mouse_item = tonumber(mouse_item)
		end
	end
end


function AutotradeFrame_OnUpdate(elapsed)
	Autotrade_AddTimeToAuctions(elapsed);

	-- Update displayed auction countdown timer
	TimeUpdateTimer = TimeUpdateTimer + elapsed;
	if (TimeUpdateTimer > 0.5)
	then

		TimeUpdateTimer = 0;

		if (AutotradeFrame.activeFrame)
		then
			local pageInfo = PageInfoByFrameName[AutotradeFrame.activeFrame];
			local frame = getglobal(AutotradeFrame.activeFrame);
			if (frame and frame.currentAuction and pageInfo.timeText:IsVisible() and frame.currentAuction.status ~= AuctionTypeDraft)
			then
				Autotrade_TimeFrame_Show(frame.currentAuction, pageInfo);
			end
		end
	end
end


function AutotradeItemButton_OnEnter()
	if (this.auctionInfo and this.auctionInfo.id)
	then
		ItemRefTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT");
		SetItemRef(this.auctionInfo.id);
	end
end


function AutotradeItemButton_OnLeave()
	if (this.auctionInfo and this.auctionInfo.id)
	then
		HideUIPanel(ItemRefTooltip);
		ItemRefTooltip:SetOwner(DEFAULT_CHAT_FRAME, "ANCHOR_RIGHT");
	end
end


function AutotradeItemIcon_OnEnter()
	local frame = this:GetParent():GetParent();
	if (frame.currentAuction and
		frame.currentAuction.id)
	then
		ItemRefTooltip:SetOwner(this, "ANCHOR_RIGHT");
		SetItemRef(frame.currentAuction.id);
		local own1, own2, own3, own4 = ItemRefTooltip:GetOwner();
		DEFAULT_CHAT_FRAME:AddMessage("Item ref owner info: "..own1..", "..own2..", "..own3..", "..own4);
	end
end


function AutotradeItemIcon_OnLeave()
	local frame = this:GetParent():GetParent();
	if (frame.currentAuction and
		frame.currentAuction.id)
	then
		HideUIPanel(ItemRefTooltip);
		ItemRefTooltip:SetOwner(DEFAULT_CHAT_FRAME, "ANCHOR_BOTTOMRIGHT");
	end
end


function AutotradeSortButton_OnShow(what, filterwhat)
-- diff3, broken?
end

function Autotrade_OpenChooseItemsFrame(zone, zoneFilter, frame, text, zoneFilters)

end

function AutotradeSortButton_OnClick(filterwhat)
  AutotradeAllAuctionsExpandButtonFrame:Show();

	local checked = this:GetChecked();
	local changed = true;

	-- Set status for the selected filter
	SetFilterState(filterwhat, checked);

	if (checked and filterwhat == "zone")
	then
		-- Open dialog to let user choose zone
		Autotrade_OpenChooseItemsFrame(ZoneList, ZoneFilters, this:GetParent(), "Choose the areas you are willing to travel to:", Autotrade_SetZoneFilters);
		-- Wait til user chooses zone(s) to enable this filter.  That will happen in a separate callback.
		SetFilterState(filterwhat, false);
		changed = false;
	end

	if (checked and filterwhat == "item")
	then
		Autotrade_OpenChooseItemsFrame(ItemTypeStrings, ItemFilterStrings, this:GetParent(), "Choose all types of items you wish to see.\nNote: pick both armor type AND slot for armor.", Autotrade_SetItemFilters);
		SetFilterState(filterwhat, false);
		changed = false;
	end

	-- Update display if things have changed
	if (changed and AutotradeFrame.activeFrame)
	then
		AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame], true);
	end
end


-- callback function for choose zone frame in auction creation process
function Autotrade_SetSellerZones(zoneFilters)
	local frame = getglobal(AutotradeFrame.activeFrame);
	if (frame)
	then
		frame.currentAuction.zoneFilters = zoneFilters;
		local zoneFilterSet = Autotrade_ChooseMeetingPlace_Show(frame.currentAuction, PageInfoByFrameName[AutotradeFrame.activeFrame]);

		if (not zoneFilterSet)
		then
			PageInfoByFrameName[AutotradeFrame.activeFrame].acceptButton:Disable();
		else
			PageInfoByFrameName[AutotradeFrame.activeFrame].acceptButton:Enable();
		end

	end
end


function Autotrade_MeetInButton_OnClick()
	-- choose filters to show
	local frame = getglobal(AutotradeFrame.activeFrame);
	local filters = nil;
	if (frame)
	then
		filters = frame.currentAuction.zoneFilters;
	end

	-- choose display mode based on button state
	if (this.state == "write")
	then
		Autotrade_OpenChooseItemsFrame(ZoneList, filters, this:GetParent(), "Choose the areas you are willing to travel to:", Autotrade_SetSellerZones);
	elseif (this.state == "read")
	then
		Autotrade_OpenChooseItemsFrame(ZoneList, filters, this:GetParent(), "Areas the seller is willing\n to travel to:");
	end
end


function AutotradeListClearButton_OnClick(itemButton)
	local header = itemButton.auctionInfo;
	if (header)
	then
		local targetList;
		local found;
		local allLists = {MyAuctionLists, AllAuctionLists, BidAuctionLists};
		for index, metaList in allLists do
			local type;
			for type, list in metaList do
				if (type == header.name)
				then
					targetList = list;
					break;
				end
			end
			if (targetList)
			then
				break;
			end
		end
		if (targetList)
		then
			for index, auction in targetList do
				local frame = getglobal(AutotradeFrame.activeFrame);
				if (frame.currentAuction and
					frame.currentAuction.owner == auction.owner and
					frame.currentAuction.link == auction.link and
					frame.currentAuction.auctionId == auction.auctionId)
				then
					frame.currentAuction = nil;
					Autotrade_UpdateDetails(PageInfoByFrameName[AutotradeFrame.activeFrame]);
				end
			end

			Autotrade_ClearList(targetList);
			AutotradeListFrame_Update(PageInfoByFrameName[AutotradeFrame.activeFrame], true);
		end
	end
end

function AutotradeAcceptButton_OnClick()
	if (not Autotrade_ModEnabled)
	then
		return;
	end

	PlaySound("GAMESCREENMEDIUMBUTTONMOUSEDOWN");
	local parent = this:GetParent();
	local pageInfo = PageInfoByFrameName[parent:GetName()];
	DEBUG_MSG("Parent frame is "..parent:GetName()..".  Getting info.", 3);
	local auction = pageInfo.frame.currentAuction;
	if (auction)
	then
		if (auction.owner == UnitName("player") and
			auction.status == AuctionTypeDraft)
		then
			Autotrade_StartAuction(auction);
			AutotradeListFrame_Update(pageInfo, true);
		elseif (auction.status == AuctionTypeOpen or auction.status == AuctionTypeAllOpen or auction.status == AuctionTypeBiddingOpen)
		then
			local sendBid;
			if (auction.flatSale)
			then
				if (auction.owner == UnitName("player"))
				then
					-- It's the player's own sale.  He wanted to stop selling.
					Autotrade_CloseAuction(auction);

					-- don't send a bid message to anyone
					sendBid = false;
				else
					-- It's someone else's sale.  Set buy price and continue on to send the bid
					pageInfo.lowerMoneyFrame.staticMoney = auction.minBid;
					sendBid = true;
				end
			else
				sendBid = true;
			end

			if (sendBid)
			then
				Autotrade_MakeBid(pageInfo);
				if (parent ~= AutotradeBidAuctionsFrame)
				then
					local foundAuction = Autotrade_FindAuctionInList(AuctionsBidOpen, auction);
					if (not foundAuction)
					then
						-- don't need the overhead of duplicating zone filter, as it can never change again
						local newAuction = Autotrade_DuplicateAuction(auction);
						Autotrade_AddAuctionToList(AuctionsBidOpen, newAuction);
						AutotradeBidAuctionsFrame.currentAuction = newAuction;
						ForceAutotrade("AutotradeBidAuctionsFrame");
					end
				end
			end
			AutotradeListFrame_Update(pageInfo, true);
		elseif (auction.status == AuctionTypeClosed)
		then
			if (auction.bidder)
			then
				-- TODO: initiate trade with winner
			elseif (auction.owner == UnitName("player"))
			then
				-- No bidder and this is owned by the player.  In this case the button copies the auction into a new Draft auction.
				local newAuction = Autotrade_RecreateAuction(auction);
				Autotrade_AddAuctionToList(AuctionsMyDraft, newAuction);
				AutotradeMyAuctionsFrame.currentAuction = newAuction;
				AutotradeListFrame_Update(pageInfo, true);
			else
				-- No bidder and this is not owned by the player.  Nothing we can really do.
			end
		elseif (auction.status == AuctionTypeBidWon)
		then
			-- TODO: initiate trade with owner
		end
	end
end


function AutotradeRemoveButton_OnClick()
	if (not Autotrade_ModEnabled)
	then
		return;
	end

	local parent = this:GetParent();
	local pageInfo = PageInfoByFrameName[parent:GetName()];
	DEBUG_MSG("Parent frame is "..parent:GetName()..".  Getting info.", 3);
	local auction = pageInfo.frame.currentAuction;
	if (auction)
	then
		-- find which list to remove item from
		local listToChange = nil;
		if (auction.status == AuctionTypeDraft)
		then
			listToChange = AuctionsMyDraft;
		elseif (auction.status == AuctionTypeClosed)
		then
			listToChange = AuctionsMyClosed;
		elseif (auction.status == AuctionTypeBidLost)
		then
			listToChange = AuctionsBidLost;
		elseif (auction.status == AuctionTypeBidWon)
		then
			listToChange = AuctionsBidWon;
		elseif (auction.status == AuctionTypeAllCancelled)
		then
			listToChange = AuctionsAllCancelled;
		elseif (auction.status == AuctionTypeBidCancelled)
		then
			listToChange = AuctionsBidCancelled;
		elseif (auction.status == AuctionTypeMyCancelled)
		then
			listToChange = AuctionsMyCancelled;
		end
		-- if we know what list to edit, remove the item from it
		if (listToChange)
		then
			Autotrade_RemoveAuctionFromList(listToChange, auction);
			pageInfo.frame.currentAuction = nil;
			Autotrade_HideAuctionDetails(pageInfo);
			AutotradeListFrame_Update(pageInfo, true);
			PlaySound("GAMESCREENMEDIUMBUTTONMOUSEDOWN");
		end
	end
end

function AutotradeWishListButton_OnClick()
	local frame;
	if (AutotradeFrame.activeFrame)
	then
		DEBUG_MSG("Getting global "..AutotradeFrame.activeFrame, 4);
		frame = getglobal(AutotradeFrame.activeFrame);
	end
	if (frame)
	then
		DEBUG_MSG("Got frame.", 4);
		local auction = frame.currentAuction;
		if (auction)
		then
			DEBUG_MSG("Got auction of "..auction.link, 4);
			local checked = this:GetChecked();
			if (checked)
			then
				DEBUG_MSG("Box "..this:GetName().." is checked.", 4);
				Autotrade_AddToWishList(Autotrade_WishList, auction.name);
				Autotrade_WishListDetails_Show(auction, PageInfoByFrameName[AutotradeFrame.activeFrame]);
			else
				DEBUG_MSG("Box "..this:GetName().." is unchecked.", 4);
				Autotrade_RemoveFromWishList(Autotrade_WishList, auction.name);
				auction.autoRemove = false;
				Autotrade_WishListDetails_Show(auction, PageInfoByFrameName[AutotradeFrame.activeFrame]);
			end
		end
	end
end


function AutotradeWishListAutoRemoveButton_OnClick()
	local frame;
	if (AutotradeFrame.activeFrame)
	then
		frame = getglobal(AutotradeFrame.activeFrame);
	end
	if (frame)
	then
		local auction = frame.currentAuction;
		if (auction)
		then
			local checked = this:GetChecked();
			auction.autoRemove = checked;
		end
	end
end


function AutotradeChangeTimeButton_OnClick(direction)
	local auction = AutotradeMyAuctionsFrame.currentAuction;
	if (not auction or not auction.lengthIndex)
	then
		return;
	end

	if (direction == "+")
	then
		if (auction.lengthIndex < AuctionLength.NumAuctionLengths)
		then
			auction.lengthIndex = auction.lengthIndex + 1;
		end
	else
		if ((AUTO_TRADE_DEBUG and auction.lengthIndex > 0) or
			(not AUTO_TRADE_DEBUG and auction.lengthIndex > 1))
		then
			auction.lengthIndex = auction.lengthIndex - 1;
		end
	end
	auction.countdownTime = AuctionCountdownTimes[auction.lengthIndex];

	-- update display w/ new time
	Autotrade_TimeFrame_ShowChooser(auction, PageInfoByFrameName["AutotradeMyAuctionsFrame"]);
	Autotrade_SetTimeButtons_Show(auction, PageInfoByFrameName["AutotradeMyAuctionsFrame"]);
end


function AutotradeCollapseAllButton_OnClick(page)
	if (not page.frame.typeFlags)
	then
		page.frame.typeFlags = {};
	end
	for index, type in page.auctionTypesList do
		DEBUG_MSG("Hiding auctions of type "..type, 3);
		page.frame.typeFlags[type] = 0;
	end
	AutotradeListFrame_Update(page, true);
end

function Autotrade_Mute(value,checked)
 	if (checked == 1) then
 		DEBUG_MSG("Autotrade Mute Activated", 1);
 		AutotradeMute = true;
 	else
 		AutotradeMute = false;
 		DEBUG_MSG("Autotrade Mute Deactivated", 1);
 	end
end


function AutotradeItemButton_OnClick(button)
	parent = this:GetParent();
	local pageInfo = PageInfoByFrameName[parent:GetName()];
	DEBUG_MSG("Parent frame is "..parent:GetName()..".  Getting info.", 3);
	if ( button == "LeftButton" )
	then
		pageInfo.frame.showAuctionDetails = 1;
		Autotrade_SetSelection(pageInfo, this:GetID());
		AutotradeListFrame_Update(pageInfo, true);
	end
end


function Autotrade_RecreateAuction(auction)
	-- have to duplicate zone filter because the new copy is editable
	local newAuction = Autotrade_DuplicateAuction(auction, true);
	newAuction.countdownTime = AuctionCountdownTimes[auction.lengthIndex];
	if (not newAuction.countdownTime)
	then
		newAuction.lengthIndex = AuctionLength.Normal;
		newAuction.countdownTime = AuctionCountdownTimes[newAuction.lengthIndex];
	end
	newAuction.elapsedTime = 0;
	newAuction.status = AuctionTypeDraft;
	newAuction.auctionId = NextAuctionId..""; -- just use strings, it's easier
	NextAuctionId = NextAuctionId + 1;
	return newAuction;
end

-- used in OnReceiveDrag
-- Diff3 -A lot of stuff has changes here.

function Autotrade_CreateAuction()
	DEBUG_MSG("Autotrade_CreateAuction", 3);

	local itemid = mouse_item

	-- I don't know how AUTO_TRADE_DRAGGED_ITEM_INFO, so I had to replace it
	-- if (AUTO_TRADE_DRAGGED_ITEM_INFO)
	if (itemid)
	then
		-- auctionInfo = AUTO_TRADE_DRAGGED_ITEM_INFO
		AUTO_TRADE_DRAGGED_ITEM_INFO = nil;

	 	auctionInfo = {};
		itemName, itemLink, _, _, _, _, _, _, itemTexture = GetItemInfo(itemid);

		-- update info to include auction ID and owner ID (together these should uniquely identify the auction)
		auctionInfo.owner = UnitName("player");
		auctionInfo.name = itemName;
		auctionInfo.link = itemLink;
		auctionInfo.minBid = 0;
		auctionInfo.count = 1;
		auctionInfo.texture = itemTexture;
		auctionInfo.lengthIndex = AuctionLength.Normal;
		auctionInfo.countdownTime = AuctionCountdownTimes[AuctionLength.Normal];
		auctionInfo.status = AuctionTypeDraft;
		DEBUG_MSG("Adding "..auctionInfo.name.." to draft auctions.", 3);
		DEBUG_MSG("Link is "..ExplodeHyperlink(auctionInfo.link), 4);
		auctionInfo.auctionId = NextAuctionId..""; -- just use strings, it's easier
		NextAuctionId = NextAuctionId + 1;

		-- Add it to the My Auctions frame list and select it.
		-- Special case: if we're creating an auction with a stack, and a stack of this item is already in drafts, add the quantities together.
		local combinedAuctionInfo = CombineAuctionStacks(AuctionsMyDraft, auctionInfo);
		if (combinedAuctionInfo)
		then
			auctionInfo = combinedAuctionInfo;
		else
			Autotrade_AddAuctionToList(AuctionsMyDraft, auctionInfo);
		end
		AutotradeMyAuctionsFrame.currentAuction = auctionInfo;

		-- Removed lot of stuff here, just present to remove item from cursor
		ClearCursor()

		-- show the right panel
		ForceAutotrade("AutotradeMyAuctionsFrame");
		AutotradeListFrame_Update(AutotradeMyAuctionsPageInfo, true);
	end
end

-- Autotrade_MoneyFrameUpdated()
--	Callback from Money Frame pickup func.
--	Tells us that the money amount in a specified money frame has been updated
function Autotrade_MoneyFrameUpdated(frame)
	local activeFrame;
	if (AutotradeFrame.activeFrame)
	then
		activeFrame = getglobal(AutotradeFrame.activeFrame);
	end
	if (AutotradeFrame.activeFrame == "AutotradeMyAuctionsFrame")
	then
		activeFrame.currentAuction.minBid = frame.staticMoney;
	else
		activeFrame.currentAuction.bid = frame.staticMoney;
	end
end


function Autotrade_ChangeSellMethod_OnClick()
	local frame = getglobal(AutotradeFrame.activeFrame);
	if (frame and frame.currentAuction)
	then
		local page = PageInfoByFrameName["AutotradeMyAuctionsFrame"];
		local newValue;
		if (frame.currentAuction.flatSale)
		then
			newValue = nil;
		else
			newValue = 1;
		end
		frame.currentAuction.flatSale = newValue;
		Autotrade_UpdateOwnerLabelText(page, frame.currentAuction);
		Autotrade_UpdateDetails(page, true);
		-- replaced by UpdateDetails call
		--Autotrade_MoneyFrame_ShowMinBid(frame.currentAuction, page.upperMoneyFrame, page.upperMoneyLabel, true, page.upperMoneySubText);
	end
end

-- diff3
-- Cosmos Emulator stuff goes here
function Cosmos_RegisterChatCommand()
  SLASH_AutoTrade1 = "/autotrade";
  SLASH_AutoTrade2 = "/at";
  SlashCmdList["AutoTrade"] = function (msg)

  cmd = msg;

    if cmd == "reload" then
      ReloadUI();
    elseif cmd == "autotrade" or cmd == "allauctions" then
      ToggleAutotrade("AutotradeAllAuctionsFrame");
    elseif cmd == "myauctions" then
      ToggleAutotrade("AutotradeMyAuctionsFrame");
    elseif cmd == "mybids" then
      ToggleAutotrade("AutotradeBidAuctionsFrame");
    elseif cmd == "help" then
      ChatFrame1:AddMessage( "AutoTrade: /autotrade [autotrade, allauctions, myauctions, mybids]" , 1.0, 1.0, 0.0, 1.0);
    else
      ToggleAutotrade("AutotradeMyAuctionsFrame");
    end
  end
end
