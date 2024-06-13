local addon = PetLeash
local L = LibStub("AceLocale-3.0"):GetLocale("PetLeash")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local SPEC_TYPES = { customSpec = 12222222222222222 }

local UpdateCustomSpecConfigTables, config_getSpecArgs, buildConfigSpec

function addon:AddCustomSpec(specid)
	if (not specid) then
		return
	end

	self.db.profile.sets.customSpec[specid].enable = true -- touch

	UpdateCustomSpecConfigTables(self)
end

function addon:DeleteCustomSpec(specid)
	wipe(self.db.profile.sets.customSpec[specid])
	self.db.profile.sets.customSpec[specid] = nil
	UpdateCustomSpecConfigTables(self)
	self:DoSpecCheck(false)
end

function addon:GetSpecPet(ltype, name, spellid)
	assert(SPEC_TYPES[ltype])

	for i, v in ipairs(self.db.profile.sets[ltype][name].pets) do
		if (spellid == v) then
			return i
		end
	end
end

function addon:SetSpecPet(ltype, name, spellid, value)
	assert(SPEC_TYPES[ltype])

	local t = self.db.profile.sets[ltype][name].pets
	local iszit = self:GetSpecPet(ltype, name, spellid)
	if (value and not iszit) then
		table.insert(t, spellid)
	elseif (not value and iszit) then
		table.remove(t, iszit)
	end

	self:DoSpecCheck(false)
end

--
-- config
--

function addon:UpdateSpecConfigTables()
	UpdateCustomSpecConfigTables(self, true)
end

-- dirty bits for updating custom specs

local function config_spec_pettoggle_get(info)
	return info.handler:GetSpecPet(info[#info - 3], info[#info - 2], tonumber(info[#info]))
end

local function config_spec_pettoggle_set(info, val)
	info.handler:SetSpecPet(info[#info - 3], info[#info - 2], tonumber(info[#info]), val)
end

local function config_spec_delete(info)
	info.handler:DeleteCustomSpec(info[#info - 1])
end

local function config_spec_immediate_set(info, v)
	assert(SPEC_TYPES[info[#info - 2]])
	info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].immediate = v
end

local function config_spec_immediate_get(info)
	assert(SPEC_TYPES[info[#info - 2]])
	return info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].immediate
end

local function config_spec_inherit_set(info, v)
	assert(SPEC_TYPES[info[#info - 2]])
	local loc = info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]]
	if (not v) then
		loc.inherit = false
		info.handler:UpdateSpecConfigTables()
	elseif (v and not loc.inherit) then
		-- only set if we're not going to clobber it
		-- and not ourselves
		loc.inherit = true
		info.handler:UpdateSpecConfigTables()
	end

	info.handler:DoSpecCheck(false)
end

local function config_spec_inherit_get(info)
	assert(SPEC_TYPES[info[#info - 2]])
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
		assert(SPEC_TYPES[info[#info - 2]])

		local inherit = info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].inherit
		if (inherit ~= true) then
			return inherit
		end
	end,
	set = function(info, val)
		assert(SPEC_TYPES[info[#info - 2]])
		info.handler.db.profile.sets[info[#info - 2]][info[#info - 1]].inherit = val
		info.handler:DoSpecCheck(false)
	end
}

function UpdateCustomSpecConfigTables(self, nosignal)
	local pet_args = loc_pet_config.args
	wipe(pet_args)

	for i = 1, GetNumCompanions("CRITTER") do
		local _, name, spellid = GetCompanionInfo("CRITTER", i)

		pet_args[tostring(spellid)] = {
			type = "toggle",
			name = name,
			get = config_spec_pettoggle_get,
			set = config_spec_pettoggle_set
		}
	end

	local loc_args = self.options.args.specs.args.customSpec.plugins.data
	wipe(loc_args) -- TODO: check to see if specs is dirty before wiping
	wipe(loc_inherit_config.values)

	for name, data in pairs(self.db.profile.sets.customSpec) do
		if (data.enable) then
			if (not loc_inherit_config.values[name]) then
				loc_inherit_config.values[name] = name
			end

			buildConfigSpec(loc_args,
				name,
				name,
				self.db.profile.sets.customSpec[name].inherit,
				"customSpec")
		end
	end

	if (not nosignal) then
		AceConfigRegistry:NotifyChange("PetLeash")
	end
end

function buildConfigSpec(args, key, name, inherit, ctype)
	if (not args[key]) then
		args[key] = config_getSpecArgs(name, ctype)
	end

	if (inherit) then
		args[key].args.pets = nil
		args[key].args.inherits = loc_inherit_config
	else
		args[key].args.pets = loc_pet_config
		args[key].args.inherits = nil
	end
end

function config_getSpecArgs(name, ctype)
	local deleteMe, enableMe

	if (ctype == "customSpec") then
		deleteMe = {
			type = "execute",
			name = DELETE,
			order = 1,
			func = config_spec_delete
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
				set = config_spec_immediate_set,
				get = config_spec_immediate_get
			},
			inherit = {
				type = "toggle",
				name = L["Inherits"],
				desc = L["Use a pet list from another Spec."],
				order = 2,
				set = config_spec_inherit_set,
				get = config_spec_inherit_get,
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

function addon:TryInitSpec()
	if (tostring(SpecializationUtil.GetActiveSpecialization()) == nil) then
		return
	end

	self:HasPet(true) -- not yet called?
	self:UpdateSpecConfigTables()
	self:DoSpecCheck(false)

	self.TryInitSpec = function() end
end

local checkSpec

function addon:DoSpecCheck(allow_immediate)
	local cur_spec = tostring(SpecializationUtil.GetActiveSpecialization())

	local cur_pet = self:HasPet()
	if (cur_pet) then
		-- convert to spell id
		cur_pet = select(3, GetCompanionInfo("CRITTER", cur_pet))
	end

	-- custom spec check
	if (checkSpec(self, "customSpec", cur_spec, cur_pet, allow_immediate)) then
		return
	end

	-- nothing doing
	self.override_pets = {}
end

function checkSpec(self, ltype, cur_spec, curpet, allow_immediate)
	if (not cur_spec or cur_spec == "") then
		return
	end

	-- don't let AceDB generate an entry for us
	local specdata = rawget(self.db.profile.sets[ltype], cur_spec)

	-- make sure entry exists
	if (not specdata or not specdata.enable) then
		return
	end

	local pets = specdata.pets
	if (specdata.inherit and specdata.inherit ~= true
			and self.db.profile.sets.customSpec[specdata.inherit]) then
		pets = self.db.profile.sets.customSpec[specdata.inherit].pets
	end

	if (specdata and #pets > 0) then
		self.override_pets = pets

		if (allow_immediate and specdata.immediate) then
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
