local addon = PetLeash
local L = LibStub("AceLocale-3.0"):GetLocale("PetLeash")

local PlayerHasQuest = addon.PlayerHasQuest

-- QUEST ITEMS (or not)

local quest_items = {
	-- Sizzling Ember
	["item:34253"] = function() return GetItemCount(34253) > 0 end,

	-- Felhound Whistle
	["item:30803"] = function() return GetItemCount(30803) > 0 end,

	-- Bloodsail Hat
	["item:12185"] = function() return IsEquippedItem(12185) end,

	-- Don Carlos' Famous Hat
	["item:38506"] = function() return IsEquippedItem(38506) end,

	-- Blood Elf Orphan Whistle
	["item:31880"] = function() return GetItemCount(31880) > 0 end,

	-- Draenei Orphan Whistle
	["item:31881"] = function() return GetItemCount(31881) > 0 end,

	-- Human Orphan Whistle
	["item:18598"] = function() return GetItemCount(18598) > 0 end,

	-- Orcish Orphan Whistle
	["item:18597"] = function() return GetItemCount(18597) > 0 end,

	-- Golem Control Unit (battery version)
	["item:36936"] = function() return GetItemCount(36936) > 0 end,

	-- Scepter of Domination (Mal Mortis quide for Disclosure quest)
	["item:39319"] = function() return GetItemCount(39319) > 0 end,

	-- Warsong Flare Gun (Alliance Deserter)
	["item:34971"] = function() return GetItemCount(34971) > 0 end,

	-- Zeppit's Crystal (Bloody Imp-ossible!)
	["item:31815"] = function() return GetItemCount(31815) > 0 end,

	-- Wolvar Orphan Whistle
	["item:46396"] = function() return GetItemCount(46396) > 0 end,

	-- Oracle Orphan Whistle
	["item:46397"] = function() return GetItemCount(46397) > 0 end,

	-- Venomhide Hatchling (20day Raptor Mount quest)
	["item:46362"] = function()
		-- XXX: if player changes which map they are looking at, we
		-- won't detect the zone correctly.
		local mapname = GetMapInfo()
		return GetItemCount(46362) > 0 and
			(mapname == "UngoroCrater" or
				mapname == "Tanaris" or
				mapname == "Silithus")
	end,

	-- Winterspring Cub (20day Winterspring Frostsaber quest)
	["item:68646"] = function()
		-- XXX: if player changes which map they are looking at, we
		-- won't detect the zone correctly.
		local mapname = GetMapInfo()
		return GetItemCount(68646) > 0 and mapname == "Winterspring"
	end,

	["item:46831"] = function() return GetItemCount(46831) > 0 end,

	["item:32834"] = function() return GetItemCount(32834) > 0 end,

	["quest:26831"] = function() return PlayerHasQuest(26831) end,

	["quest:25371"] = function() return PlayerHasQuest(25371) end,

	["quest:11878"] = function() return PlayerHasQuest(11878) end,

	["item:71137"] = function() return GetItemCount(71137) > 0 end,
}

addon.quest_items = quest_items

function addon:HasQuestItem()
	for item, func in pairs(quest_items) do
		if (not self.db.profile.selectedQuestItems[item] and func()) then
			return true
		end
	end
	return false
end

function addon:GetQuestItemName(item)
	if (strsub(item, 1, 5) == "item:") then
		return (GetItemInfo(item)) or L[item] or item
	elseif (strsub(item, 1, 6) == "spell:") then
		return (GetSpellInfo(strsub(item, 7))) or item
	elseif (strsub(item, 1, 6) == "quest:") then
		return L[item] or item
	else
		return item
	end
end
