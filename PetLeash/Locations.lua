local addon = PetLeash
local L = LibStub("AceLocale-3.0"):GetLocale("PetLeash")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local special_locations = {
	city = {
		name = L["City"],
		func = function() return IsResting() end,
	},
	battleground = {
		name = BATTLEGROUND,
		func = function() return addon.InBattlegroundOrArena() end,
	},
	instance = {
		name = L["Dungeon"],
		func = function()
			local _, t = IsInInstance()
			return t == "party" and
			not (addon.db.profile.sets.specialLocations["manastorm"].enable and C_Manastorm.IsInManastorm())
		end,
	},
	raid = {
		name = L["Raid"],
		func = function()
			local _, t = IsInInstance()
			return t == "raid" and
			not (addon.db.profile.sets.specialLocations["manastorm"].enable and C_Manastorm.IsInManastorm())
		end,
	},
	manastorm = {
		name = THE_MANASTORM,
		func = function() return C_Manastorm.IsInManastorm() end,
	},
}

local LOCATION_TYPES = { customLocations = 1, specialLocations = 1 }

local UpdateCustomLocationConfigTables, UpdateSpecialLocationConfigTables, config_getLocationArgs, buildConfigLocation

function addon:AddCustomLocation(name)
	if (not name or name == "") then
		return
	end

	self.db.profile.sets.customLocations[name].enable = true -- touch

	UpdateCustomLocationConfigTables(self)
end

function addon:DeleteCustomLocation(name)
	wipe(self.db.profile.sets.customLocations[name])
	self.db.profile.sets.customLocations[name] = nil
	UpdateCustomLocationConfigTables(self)
	self:DoLocationCheck(false)
end

function addon:GetLocationPet(ltype, name, spellid)
	assert(LOCATION_TYPES[ltype])

	for i, v in ipairs(self.db.profile.sets[ltype][name].pets) do
		if (spellid == v) then
			return i
		end
	end
end

function addon:SetLocationPet(ltype, name, spellid, value)
	assert(LOCATION_TYPES[ltype])

	local t = self.db.profile.sets[ltype][name].pets
	local iszit = self:GetLocationPet(ltype, name, spellid)
	if (value and not iszit) then
		table.insert(t, spellid)
	elseif (not value and iszit) then
		table.remove(t, iszit)
	end

	self:DoLocationCheck(false)
end

--
-- config
--

function addon:UpdateLocationConfigTables()
	UpdateCustomLocationConfigTables(self, true)
	UpdateSpecialLocationConfigTables(self, true)
end

-- dirty bits for updating custom locations

local function config_location_pettoggle_get(info)
	return info.handler:GetLocationPet(info[#info - 3], info[#info - 2], tonumber(info[#info]))
end

local function config_location_pettoggle_set(info, val)
	info.handler:SetLocationPet(info[#info - 3], info[#info - 2], tonumber(info[#info]), val)
end

local function config_location_delete(info)
	info.handler:DeleteCustomLocation(info[#info - 1])
end

local function config_location_enable_set(info, v)
	assert(LOCATION_TYPES[info[#info - 2]])
	info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].enable = v
	info.handler:DoLocationCheck(false)
end

local function config_location_enable_get(info)
	assert(LOCATION_TYPES[info[#info - 2]])
	return info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].enable
end

local function config_location_immediate_set(info, v)
	assert(LOCATION_TYPES[info[#info - 2]])
	info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].immediate = v
end

local function config_location_immediate_get(info)
	assert(LOCATION_TYPES[info[#info - 2]])
	return info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].immediate
end

local function config_location_inherit_set(info, v)
	assert(LOCATION_TYPES[info[#info - 2]])
	local loc = info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]]
	if (not v) then
		loc.inherit = false
		info.handler:UpdateLocationConfigTables()
	elseif (v and not loc.inherit) then
		-- only set if we're not going to clobber it
		-- and not ourselves
		loc.inherit = true
		info.handler:UpdateLocationConfigTables()
	end

	info.handler:DoLocationCheck(false)
end

local function config_location_inherit_get(info)
	assert(LOCATION_TYPES[info[#info - 2]])
	return info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].inherit
end

local loc_pet_config = {
	type = "group",
	name = "",
	order = 10,
	args = {},
	inline = true
}
local loc_inherit_config = {
	type = "select",
	name = L["Inherits From"],
	order = 11,
	values = {},
	get = function(info)
		assert(LOCATION_TYPES[info[#info - 2]])

		local inherit = info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].inherit
		if (inherit ~= true) then
			return inherit
		end
	end,
	set = function(info, val)
		assert(LOCATION_TYPES[info[#info - 2]])
		info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].inherit = val
		info.handler:DoLocationCheck(false)
	end
}

function UpdateCustomLocationConfigTables(self, nosignal)
	local pet_args = loc_pet_config.args
	wipe(pet_args)

	for i = 1, GetNumCompanions("CRITTER") do
		local _, name, spellid = GetCompanionInfo("CRITTER", i)

		pet_args[tostring(spellid)] = {
			type = "toggle",
			name = name,
			get = config_location_pettoggle_get,
			set = config_location_pettoggle_set
		}
	end

	local loc_args = self.options.args.locations.args.customLocations.plugins.data
	wipe(loc_args) -- TODO: check to see if locations is dirty before wiping
	wipe(loc_inherit_config.values)

	for name, data in pairs(self.db.profile.sets.customLocations) do
		if (data.enable) then
			if (not loc_inherit_config.values[name]) then
				loc_inherit_config.values[name] = name
			end

			buildConfigLocation(loc_args,
				name,
				name,
				self.db.profile.sets.customLocations[name].inherit,
				"customLocations")
		end
	end

	if (not nosignal) then
		AceConfigRegistry:NotifyChange("PetLeash")
	end
end

function UpdateSpecialLocationConfigTables(self, nosignal)
	for key, data in pairs(special_locations) do
		buildConfigLocation(
			self.options.args.locations.args.specialLocations.plugins.data,
			key,
			data.name,
			self.db.profile.sets.specialLocations[key].inherit,
			"specialLocations")
	end

	if (not nosignal) then
		AceConfigRegistry:NotifyChange("PetLeash")
	end
end

function buildConfigLocation(args, key, name, inherit, ctype)
	if (not args[key]) then
		args[key] = config_getLocationArgs(name, ctype)
	end

	if (inherit) then
		args[key].args.pets = nil
		args[key].args.inherits = loc_inherit_config
	else
		args[key].args.pets = loc_pet_config
		args[key].args.inherits = nil
	end
end

function config_getLocationArgs(name, ctype)
	local deleteMe, enableMe

	if (ctype == "customLocations") then
		deleteMe = {
			type = "execute",
			name = DELETE,
			order = 1,
			func = config_location_delete
		}
	elseif (ctype == "specialLocations") then
		deleteMe = {
			type = "toggle",
			name = ENABLE,
			order = 1,
			get = config_location_enable_get,
			set = config_location_enable_set,
		}
	end

	return {
		type = "group",
		name = name,
		args = {
			deleteMe = deleteMe,
			enableMe = enableMe,
			immediate = {
				type = "toggle",
				name = L["Immediate"],
				desc = L["Immediately switch pets upon zone change."],
				order = 2,
				set = config_location_immediate_set,
				get = config_location_immediate_get
			},
			inherit = {
				type = "toggle",
				name = L["Inherits"],
				desc = L["Use a pet list from another location."],
				order = 2,
				set = config_location_inherit_set,
				get = config_location_inherit_get,
			},
			seperator = {
				type = "header",
				name = "",
				order = 3,
			},
		}
	}
end

--
-- switcher code
--

function addon:TryInitLocation()
	if (GetZoneText() == "" or GetZoneText() == nil) then
		return
	end

	self:HasPet(true) -- not yet called?
	self:UpdateLocationConfigTables()
	self:DoLocationCheck(false)

	self.TryInitLocation = function() end
end

local checkZone

function addon:DoLocationCheck(allow_immediate)
	local cur_zone = GetZoneText()
	local cur_subzone = GetSubZoneText()

	local cur_pet = self:HasPet()
	if (cur_pet) then
		-- convert to spell id
		cur_pet = select(3, GetCompanionInfo("CRITTER", cur_pet))
	end

	-- custom zone checks
	if (checkZone(self, "customLocations", cur_subzone, cur_pet, allow_immediate)) then
		return
	end
	if (checkZone(self, "customLocations", cur_zone, cur_pet, allow_immediate)) then
		return
	end

	-- special zone checks
	for key, data in pairs(special_locations) do
		if (data.func()) then
			if (checkZone(self, "specialLocations", key, cur_pet, allow_immediate)) then
				return
			end
		end
	end

	-- nothing doing
	self.override_pets = {}
	-- check spec pets
	self:DoSpecCheck(true)
end

function checkZone(self, ltype, zonename, curpet, allow_immediate)
	if (not zonename or zonename == "") then
		return
	end

	-- don't let AceDB generate an entry for us
	local locdata = rawget(self.db.profile.sets[ltype], zonename)

	-- make sure entry exists
	if (not locdata or not locdata.enable) then
		return
	end

	local pets = locdata.pets
	if (locdata.inherit and locdata.inherit ~= true
			and self.db.profile.sets.customLocations[locdata.inherit]) then
		pets = self.db.profile.sets.customLocations[locdata.inherit].pets
	end

	if (locdata and #pets > 0) then
		self.override_pets = pets

		if (allow_immediate and locdata.immediate) then
			local i
			for id, petid in pairs(pets) do
				if (petid == curpet) then
					i = id
					break
				end
			end

			if (not i) then
				-- mark for resummon immediately!
				self.ready_to_autoswitch = true -- we're abusive.
				self:StartPetTimer()
			end
		end

		return true
	end
end
