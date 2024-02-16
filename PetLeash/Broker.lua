local addon = PetLeash

local LDB = LibStub("LibDataBroker-1.1", true)

local L = LibStub("AceLocale-3.0"):GetLocale("PetLeash")

local BrokerMenu_InitalizeMenu, BrokerMenu_SummonPet, BrokerMenu_PetRangeString

function addon:InitBroker()
	if (LDB and not self.broker) then
		self.broker = LDB:NewDataObject("PetLeash", {
			label = "PetLeash",
			type = "launcher",
			icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
			iconR = 1,
			iconG = self:IsEnabledSummoning() and 1 or 0.3,
			iconB = self:IsEnabledSummoning() and 1 or 0.3,
			OnClick = function(...) self:Broker_OnClick(...) end,
			OnTooltipShow = function(...) self:Broker_OnTooltipShow(...) end
		})
	end

	if (not self.brokerMenu) then
		self.brokerMenu = CreateFrame("FRAME", "PetLeashBrokerMenu",
			UIParent, "UIDropDownMenuTemplate")
		UIDropDownMenu_Initialize(self.brokerMenu, BrokerMenu_InitalizeMenu, "MENU")
	end
end

function addon:Broker_OnTooltipShow(tt)
	tt:AddLine("PetLeash")
	tt:AddLine(" ")
	tt:AddDoubleLine(("|cffeeeeee%s|r "):format(L["Auto Summon:"]),
		self:IsEnabledSummoning() and ("|cff00ff00%s|r"):format(L["Enabled"])
		or ("|cffff0000%s|r"):format(L["Disabled"]))
	tt:AddLine(" ")
	tt:AddLine(("|cff69b950%s|r |cffeeeeee%s|r"):format(L["Left-Click:"], L["Toggle Non-Combat Pet"]))
	tt:AddLine(("|cff69b950%s|r |cffeeeeee%s|r"):format(L["Right-Click:"], L["Pet Menu"]))
	tt:AddLine(("|cff69b950%s|r |cffeeeeee%s|r"):format(L["Ctrl + Click:"], L["Open Configuration Panel"]))

	tt:AddLine(" ")
	if GetNumCompanions("CRITTER") > 0 then
		tt:AddLine(("|cff00ff00%s|r"):format(L["You have %d pets"]:format(GetNumCompanions("CRITTER"))))
	else
		tt:AddLine(("|cff00ff00%s|r"):format(L["You have no pets"]))
	end
end

function addon:Broker_OnClick(frame, button)
	if (IsControlKeyDown()) then
		self:OpenOptions()
	elseif (button == "LeftButton") then
		self:TogglePet()
	else
		ToggleDropDownMenu(1, nil, self.brokerMenu, frame, 0, 0)
	end
end

local function iter_utf8(s)
	-- Src: http://lua-users.org/wiki/LuaUnicode
	return string.gmatch(s, "([%z\1-\127\194-\244][\128-\191]*)")
end

local function str_range_diff(a, b)
	if (not b) then return iter_utf8(a)() end
	if (not a) then return nil, iter_utf8(b)() end

	local iter_a = iter_utf8(a)
	local iter_b = iter_utf8(b)
	local char_a, char_b = iter_a(), iter_b()
	local r = ""
	while char_a and char_b do
		if (char_a ~= char_b) then
			return r .. char_a, r .. char_b
		end

		r = r .. char_a

		char_a = iter_a()
		char_b = iter_b()
	end

	return r, r
end

local function safe_GetCritterName(id)
	if (id <= 0 or id > GetNumCompanions("CRITTER")) then
		return nil
	end
	return (select(2, GetCompanionInfo("CRITTER", id)))
end

-- for two pet ids, forming a span from "a" to "b", generate a string
-- representing this span.  For example:  A - Z
function BrokerMenu_PetRangeString(a, b)
	local _, part_a = str_range_diff(safe_GetCritterName(a - 1), safe_GetCritterName(a))
	local part_b = str_range_diff(safe_GetCritterName(b), safe_GetCritterName(b + 1))

	return string.format("%s - %s", part_a, part_b)
end

function BrokerMenu_InitalizeMenu(frame, level, menuList)
	local ncritters = GetNumCompanions("CRITTER")

	-- If we have more than 25 critters, then split into equal
	-- groups of no more than 25 each
	if (not level or level == 1) then
		if (ncritters == 0) then
			-- Nothing to do!
		elseif (ncritters <= 25) then
			-- don't have to split :)
			local info = UIDropDownMenu_CreateInfo()
			info.text = L["Pets"]
			info.notCheckable = true
			info.hasArrow = true
			info.menuList = "1-" .. ncritters
			UIDropDownMenu_AddButton(info, level)
		else
			-- Split
			local numlines = math.ceil(ncritters / 25)
			local generic_linesz = ncritters / numlines -- average size

			for line = 1, numlines do
				-- start to finish are inclusive
				local start = math.floor(generic_linesz * (line - 1) + 1)
				local finish = math.floor(generic_linesz * line)
				local linesize = finish - start + 1

				local info = UIDropDownMenu_CreateInfo()
				info.text = string.format(L["Pets"] .. " (%s)", BrokerMenu_PetRangeString(start, finish))
				info.notCheckable = true
				info.hasArrow = true
				info.menuList = string.format("%d-%d", start, finish)
				UIDropDownMenu_AddButton(info, level)
			end
		end
	elseif (level == 2) then
		local start, finish = strsplit("-", menuList) -- decode
		for i = tonumber(start), tonumber(finish) do
			local _, name, _, icon = GetCompanionInfo("CRITTER", i)

			local info = UIDropDownMenu_CreateInfo()
			info.text = name
			info.icon = icon
			info.value = i
			info.notCheckable = true
			info.func = BrokerMenu_SummonPet

			UIDropDownMenu_AddButton(info, level)
		end
	end
end

function BrokerMenu_SummonPet(info)
	CallCompanion("CRITTER", info.value)
end
