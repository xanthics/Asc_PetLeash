local addon = LibStub("AceAddon-3.0"):NewAddon("PetLeash", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.PetLeash = addon

local L = LibStub("AceLocale-3.0"):GetLocale("PetLeash")

-- Binding globals
BINDING_HEADER_PETLEASH = "PetLeash"
BINDING_NAME_PETLEASH_SUMMON = L["Summon Another Pet"]
BINDING_NAME_PETLEASH_DESUMMON = L["Desummon Pet"]
BINDING_NAME_PETLEASH_TOGGLE = L["Toggle Non-Combat Pet"]
BINDING_NAME_PETLEASH_CONFIG = L["Open Configuration"]


-- Default DB
local defaults = {
	profile = {
		enable = true,
		enableInCombat = false,
		desummonInCombat = false,
		desummonRaidCombat = false,
		desummonPartyCombat = false,
		desummonVSBoss = false,
		enableInBattleground = true,
		disableOutsideCities = false,
		dismissWhenStealthed = true,
		dismissWhileFlying = false,
		disableForQuestItems = true,
		waitTimer = 3,
		selectedQuestItems = {}, -- "item:xx" = true, disable.  if false, use check
		autoSwitchTimer = false,
		autoSwitchCitiesOnly = false,
		autoSwitchOnZone = false,
		weightedPets = false,
		ignore_pets = { -- [spellid] = true, hide.  if false, don't hide
			[25162] = true, -- Disgusing Oozling (Combat Effect)
			[92398] = true, -- Guild Page, Horde (Long cooldown)
			[92396] = true, -- Guild Herald, Horde (Long cooldown)
			[92395] = true, -- Guild Page, Alliance (Long cooldown)
			[92397] = true, -- Guild Herald, Alliance (Long cooldown)
		},
		weights = {}, -- [spellid] = num (if nil default is 1)
		sets = {
			-- locations
			customLocations = {
				-- custom locations
				["*"] = {
					enable = false,
					immediate = true,
					inherit = false,
					pets = {} -- {spellid, spellid, ...}
				}
			},
			specialLocations = {
				-- premade (special) locations
				["*"] = {
					enable = false,
					immediate = true,
					inherit = false,
					pets = {} -- {spellid, spellid, ...}
				}
			},
			customSpec = {
				-- custom locations
				["*"] = {
					enable = false,
					immediate = true,
					inherit = false,
					pets = {} -- {spellid, spellid, ...}
				}
			},
		}
	}
}

-- config

local function config_toggle_get(info) return addon.db.profile[info[#info]] end
local function config_toggle_set(info, v) addon.db.profile[info[#info]] = v end

local config_autoSwitchTimer_oldval = 30

local options = {
	name = "PetLeash",
	handler = PetLeash,
	type = 'group',
	args = {
		main = {
			name = GENERAL,
			type = 'group',
			childGroups = "tab",
			args = {
				general = {
					name = GENERAL,
					type = "group",
					order = 10,
					args = {
						enable = {
							type = "toggle",
							name = ENABLE,
							desc = L["Enable Auto-Summon"],
							order = 10,
							width = "full",
							get = function(info) return addon:IsEnabledSummoning() end,
							set = function(info, v) addon:EnableSummoning(v) end,
						},
						enableInCombat = {
							type = "toggle",
							name = L["Enable In Combat"],
							order = 11,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						desummonInCombat = {
                            type = "toggle",
                            name = L["Desummon Pet During Any Combat"],
                            order = 12,
                            width = "double",
                            get = config_toggle_get,
                            set = config_toggle_set
                        },
						desummonPartyCombat = {
                            type = "toggle",
                            name = L["Desummon Pet During Party Combat"],
                            order = 13,
                            width = "double",
                            get = config_toggle_get,
                            set = config_toggle_set
                        },
						desummonRaidCombat = {
                            type = "toggle",
                            name = L["Desummon Pet During Raid Combat"],
                            order = 14,
                            width = "double",
                            get = config_toggle_get,
                            set = config_toggle_set
                        },
						desummonVSBoss = {
                            type = "toggle",
                            name = L["Desummon Pet During Boss Fights"],
                            order = 15,
                            width = "double",
                            get = config_toggle_get,
                            set = config_toggle_set
                        },
						enableInBattleground = {
							type = "toggle",
							name = L["Enable In Battlegrounds/Arena"],
							order = 16,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						disableOutsideCities = {
							type = "toggle",
							name = L["Only Enable in Cities"],
							order = 17,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						dismissWhenStealthed = {
							type = "toggle",
							name = L["Dismiss When Stealthed or Invisible"],
							order = 18,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						dismissWhileFlying = {
							type = "toggle",
							name = L["Dismiss When Flying"],
							order = 19,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						waitTimerValue = {
							type = "range",
							name = L["Wait Time (Seconds)"],
							desc = L["How long must pass before a player is considered idle enough to summon a pet."],
							order = 25,
							min = 1,
							step = .5,
							bigStep = 1,
							max = 30,
							get = function()
								return addon.db.profile.waitTimer
							end,
							set = function(info, v)
								addon.db.profile.waitTimer = v
							end
						},
					},
				},
				questItems = {
					name = L["Special Items"],
					type = "group",
					order = 20,
					args = {
						disableForQuestItems = {
							type = "toggle",
							name = L["Disable For Special Items"],
							desc = L
							["Disable when special items that summon pets are detected.  This includes quest items and hats."],
							order = 20,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						questItemsSelector = {
							type = "multiselect",
							name = L["Special Items"],
							order = 21,
							style = "dropdown",
							disabled = function()
								return not addon.db.profile.disableForQuestItems
							end,
							values = function()
								local r = {}

								for item, func in pairs(addon.quest_items) do
									r[item] = addon:GetQuestItemName(item)
								end

								return r
							end,
							get = function(info, key)
								return not addon.db.profile.selectedQuestItems[key]
							end,
							set = function(info, key, value)
								addon.db.profile.selectedQuestItems[key] = not value
							end,
						},
					}
				},
				autoSwitch = {
					name = L["Auto Switch Pet"],
					type = "group",
					order = 30,
					args = {
						autoSwitchTimerEnable = {
							type = "toggle",
							name = L["Enable Timed Auto Switch"],
							width = "double",
							order = 31,
							get = function() return addon.db.profile.autoSwitchTimer end,
							set = function(info, v)
								if (v) then
									if (not addon.db.profile.autoSwitchTimer) then
										addon.db.profile.autoSwitchTimer = config_autoSwitchTimer_oldval
									end
								else
									config_autoSwitchTimer_oldval = addon.db.profile.autoSwitchTimer
									addon.db.profile.autoSwitchTimer = v
									addon:StartAutoSwitchTimer()
								end
							end
						},
						autoSwitchTimerValue = {
							type = "range",
							name = L["Seconds between switch"],
							order = 32,
							min = 30,
							step = 1,
							bigStep = 60,
							max = 3600,
							disabled = function() return not addon.db.profile.autoSwitchTimer end,
							get = function()
								return addon.db.profile.autoSwitchTimer or config_autoSwitchTimer_oldval
							end,
							set = function(info, v)
								addon.db.profile.autoSwitchTimer = v
								addon:StartAutoSwitchTimer()
							end
						},
						autoSwitchCitiesOnly = {
							type = "toggle",
							name = L["Only use Timed Auto Switch in cities"],
							width = "double",
							order = 33,
							get = config_toggle_get,
							set = config_toggle_set
						},
						autoSwitchOnZone = {
							type = "toggle",
							name = L["Auto Switch when changing maps"],
							width = "double",
							order = 40,
							get = config_toggle_get,
							set = config_toggle_set
						}
					}
				}
			}
		},
		pets = {
			type = "group",
			name = L["Enabled Pets"],
			order = 10,
			cmdHidden = true,
			args = {
				enableAll = {
					type = "execute",
					name = L["Enable All"],
					order = 1,
					func = function(info)
						addon:_Config_PetToggle_SetAll(info, false)
					end
				},
				disableAll = {
					type = "execute",
					name = L["Disable All"],
					order = 2,
					func = function(info)
						addon:_Config_PetToggle_SetAll(info, true)
					end
				},
				useWeightedPets = {
					-- If we get more pickers, change this to type = "select"
					type = "toggle",
					name = L["Weighted Pets"],
					order = 3,
					get = function(info)
						return addon.db.profile.weightedPets
					end,
					set = function(info, v)
						addon.db.profile.weightedPets = v
						addon:UpdateConfigTables()
					end
				},
				seperator = {
					type = "header",
					name = "",
					order = 9,
				},
				pets = {
					type = "group",
					name = "",
					order = 10,
					args = {},
					inline = true
				}
			}
		},
		locations = {
			type = "group",
			name = L["Locations"],
			order = 11,
			cmdHidden = true,
			args = {
				specialLocations = {
					type = "group",
					name = L["Special Locations"],
					order = 1,
					args = {
						description = {
							type = "description",
							name = L["Special Locations are predefined areas that cover a certain type of zone."]
						}
					},
					plugins = { data = {} }
				},
				customLocations = {
					type = "group",
					name = L["Custom Locations"],
					order = 2,
					args = {
						addCurrentZone = {
							type = "execute",
							name = L["Add Current Zone"],
							order = 1,
							func = function(info)
								addon:AddCustomLocation(GetZoneText())
							end,
						},
						addCurrentSubZone = {
							type = "execute",
							name = L["Add Current Subzone"],
							order = 1,
							func = function(info)
								addon:AddCustomLocation(GetSubZoneText())
							end,
						},
						--addNamedZone = {
						--
						--}
					},
					plugins = { data = {} }
				},
			}
		},
		specs = {
			type = "group",
			name = L["Specs"],
			order = 12,
			cmdHidden = true,
			args = {
				customSpec = {
					type = "group",
					name = L["Custom Specialization"],
					order = 3,
					args = {
						addCurrentSpec = {
							type = "execute",
							name = L["Add Current Spec"],
							order = 1,
							func = function(info)
								addon:AddCustomSpec(tostring(SpecializationUtil.GetActiveSpecialization()))
							end,
						},
					},
					plugins = { data = {} }
				},
			}
		},
		profiles = nil, -- reserve for later setup
	},
}

local options_slashcmd = {
	name = "PetLeash Slash Command",
	handler = PetLeash,
	type = "group",
	order = -2,
	args = {
		config = {
			type = "execute",
			name = L["Open Configuration"],
			dialogHidden = true,
			order = 1,
			func = function(info) addon:OpenOptions() end
		},
		resummon = {
			type = "execute",
			name = L["Summon Another Pet"],
			desc = L["Desummon your current pet and summon another pet.  Enable summoning if needed."],
			order = 20,
			func = function(info) addon:ResummonPet() end
		},
		desummon = {
			type = "execute",
			name = L["Desummon Pet"],
			desc = L["Desummon your currently summoned pet.  Disable summoning."],
			order = 21,
			func = function(info) addon:DesummonPet() end
		},
		togglePet = {
			type = "execute",
			name = L["Toggle Non-Combat Pet"],
			order = 22,
			func = function(info) addon:TogglePet() end
		},
		enable = options.args.main.args.general.args.enable,
		enableInCombat = options.args.main.args.general.args.enableInCombat,
		desummonInCombat = options.args.main.args.general.args.desummonInCombat,
		desummonPartyCombat = options.args.main.args.general.args.desummonPartyCombat,
		desummonRaidCombat = options.args.main.args.general.args.desummonRaidCombat,
		desummonVSBoss = options.args.main.args.general.args.desummonVSBoss,
		dismissWhenStealthed = options.args.main.args.general.args.dismissWhenStealthed,
		disableForQuestItems = options.args.main.args.general.args.disableForQuestItems,
	},
}

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function migrateData()
	if not PetLeashDB.char then return end
	for k,v in pairs(PetLeashDB.char) do
		for j,l in pairs(v) do
			PetLeashDB.profiles[k][j] = l
		end
	end
	PetLeashDB.char = nil
	print("PetLeash: Data migrated to profiles")
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PetLeashDB", defaults)
	migrateData()
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChange")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChange")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChange")

	self.usable_pets = {} -- spellid, spellid
	self.override_pets = {} -- spellid, spellid -- OVERRIDE FOR USABLE_PETS
	self.pet_map = {}    -- spellid -> {id,name} (complete)
	self.player_invisible = false

	self.options = options
	self.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	self.options_slashcmd = options_slashcmd

	AceConfig:RegisterOptionsTable(self.name, options)
	self.optionsFrame = LibStub("LibAboutPanel").new(nil, self.name)
	self.optionsFrame.General = AceConfigDialog:AddToBlizOptions(self.name, L["General"], self.name, "main")
	self.optionsFrame.Pets = AceConfigDialog:AddToBlizOptions(self.name, L["Enabled Pets"], self.name, "pets")
	self.optionsFrame.Locations = AceConfigDialog:AddToBlizOptions(self.name, L["Locations"], self.name, "locations")
	self.optionsFrame.Locations = AceConfigDialog:AddToBlizOptions(self.name, L["Specs"], self.name, "specs")
	self.optionsFrame.Profiles = AceConfigDialog:AddToBlizOptions(self.name, L["Profiles"], self.name, "profiles")
	AceConfig:RegisterOptionsTable(self.name .. "SlashCmd", options_slashcmd, { "petleash", "pl" })

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("COMPANION_UPDATE")
	self:RegisterEvent("COMPANION_LEARNED")
	self:RegisterEvent("UPDATE_STEALTH")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("ZONE_CHANGED")
	self:RegisterEvent("ZONE_CHANGED_INDOORS")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ENCOUNTER_START")
	self:RegisterEvent("BARBER_SHOP_CLOSE")
	self:RegisterEvent("BARBER_SHOP_OPEN")
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("QUEST_FINISHED")
	self:RegisterEvent("ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED")
	--    self:RegisterEvent("ACTIVE_MANASTORM_UPDATED")

	self:LoadPets()                 -- attempt to load pets (might fail)
	self:ScheduleTimer("LoadPets", 45) -- sometimes COMPANION_* fails

	self:ScheduleRepeatingTimer("FlightCheck", 1.0)

	-- specifically clicking dismiss will disable us
	-- TODO: perhaps clicking summon when we've been disabled in this
	-- way should reenable us?
	if SpellBookCompanionSummonButton then
		SpellBookCompanionSummonButton:HookScript("OnClick", function(btn, ...)
			if (btn:GetText() == PET_DISMISS) then
				self:EnableSummoning(false)
			end
		end)
	end
	self:InitBroker()
end

function addon:OnEnable()
	if select(4, GetBuildInfo()) >= 50001 then
		self:ScheduleTimer(function()
			self:Print("This version of PetLeash is not designed for WoW 5.0.  Please check for an updated version.")
		end, 10)
	end
end

function addon:IsEnabledSummoning()
	return self.db.profile.enable
end

function addon:EnableSummoning(v)
	local oldv = self.db.profile.enable

	if ((not oldv) ~= (not v)) then
		self.db.profile.enable = v

		-- TODO: is there a better way to trigger config update?
		AceConfigRegistry:NotifyChange("PetLeash")
	end

	if (self.broker) then
		local notR = v and 1 or 0.3
		self.broker.iconG = notR
		self.broker.iconB = notR
	end
end

function addon:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

-- utility functions

local function HasCompanion(pettype)
	for id = 1, GetNumCompanions(pettype) do
		local _, _, _, _, issum = GetCompanionInfo(pettype, id)
		if (issum) then
			return id
		end
	end
	return nil
end

local function IsMounted()
	return _G.IsMounted()
	--return HasCompanion("MOUNT")
end

local function IsPetted(id)
	if (id) then
		local _, _, _, _, issum = GetCompanionInfo("CRITTER", id)
		if (issum) then
			return id
		end
	else
		return HasCompanion("CRITTER")
	end
end
addon.IsPetted = IsPetted -- expose (mostly for debugging)

local function IsCasting()
	return (UnitCastingInfo("player") or UnitChannelInfo("player"))
end

local function IsDrinkingOrEating()
	local drink_name = GetSpellInfo(430)
	local eat_name = GetSpellInfo(433)

	if (UnitAura("player", drink_name, nil, "HELPFUL")) then
		return true
	elseif (UnitAura("player", eat_name, nil, "HELPFUL")) then
		return true
	end
end

local BATTLEGROUND_ARENA = { ["pvp"] = 1, ["arena"] = 1 }
local function InBattlegroundOrArena()
	local _, t = IsInInstance()
	return BATTLEGROUND_ARENA[t]
end
addon.InBattlegroundOrArena = InBattlegroundOrArena

-- Blizz function is broken, so we reimplement
local function UnitIsFeignDeath(unit)
	local fd_name = GetSpellInfo(5384)
	if (UnitAura(unit, fd_name, nil, "HELPFUL")) then
		return true
	end
end

local InCombat = InCombatLockdown -- shorthand

local function CanSummonPet()
	return
	-- are we busy?
		not IsCasting()
		and not IsMounted()
		and not UnitInVehicle("player")
		and not UnitIsGhost("player")
		and not UnitIsDead("player")
		and not UnitOnTaxi("player")
		and not UnitIsFeignDeath("player")
		and not IsFlying()
		and not IsFalling()
		and not IsDrinkingOrEating()
		and not IsStealthed()
		and not addon.player_invisible
		and not addon.player_barber
		and GetNumLootItems() == 0
		and HasFullControl()
		-- verify we have pets
		and GetNumCompanions("CRITTER") > 0
		-- gcd check
		and (not GetCompanionCooldown or GetCompanionCooldown("CRITTER", 1) == 0)
end
addon.CanSummonPet = CanSummonPet -- expose (mostly for debugging)

-- pet list handling

function addon:LoadPets(updateconfig)
	wipe(self.usable_pets)

	for i = 1, GetNumCompanions("CRITTER") do
		local _, name, spellid = GetCompanionInfo("CRITTER", i)

		if (not name) then
			return -- pets not loaded yet?
		end

		if (not self.db.profile.ignore_pets[spellid]) then
			table.insert(self.usable_pets, spellid)
		end

		if (not self.pet_map[spellid]) then
			self.pet_map[spellid] = {}
		end
		self.pet_map[spellid].id = i
		self.pet_map[spellid].name = name
	end

	if (updateconfig == nil or updateconfig) then
		self:UpdateConfigTables(true)
	end

	-- does nothing if we've called it successfully before
	self:TryInitLocation()
	self:TryInitSpec()
	self:UpdateQuestList()

	-- update timer
	self:UpdatePetTimer()
end

function addon:OnProfileChange()
	self:LoadPets()
end

local L_WeightValues = { "|cffff0000" .. L["Never"] .. "|r",
	"|cffff6600" .. L["Hardly Ever"] .. "|r",
	"|cffff9900" .. L["Rarely"] .. "|r",
	"|cffddff00" .. L["Occasionally"] .. "|r",
	"|cff99ff00" .. L["Sometimes"] .. "|r",
	"|cff00ff00" .. L["Often"] .. "|r" }
function addon:UpdateConfigTables()
	local args = options.args.pets.args.pets.args
	local useWeighted = self.db.profile.weightedPets

	wipe(args)

	for i = 1, GetNumCompanions("CRITTER") do
		local _, name, spellid = GetCompanionInfo("CRITTER", i)

		if (not useWeighted) then
			args[tostring(spellid)] = {
				type = "toggle",
				name = name,
				order = 1,
				get = "Config_PetToggle_Get",
				set = "Config_PetToggle_Set"
			}
		else
			args[tostring(spellid)] = {
				type = "select",
				name = name,
				order = 1,
				values = L_WeightValues,
				get = "Config_PetToggle_Weighted_Get",
				set = "Config_PetToggle_Weighted_Set"
			}
		end
	end

	self:UpdateLocationConfigTables()
	self:UpdateSpecConfigTables()

	-- Config Tables changed!
	AceConfigRegistry:NotifyChange("PetLeash")
end

function addon:Config_PetToggle_Set(info, v)
	if (v) then
		self.db.profile.ignore_pets[tonumber(info[#info])] = false
	else
		self.db.profile.ignore_pets[tonumber(info[#info])] = true
	end

	self:LoadPets(false)
end

function addon:Config_PetToggle_Get(info)
	return not self.db.profile.ignore_pets[tonumber(info[#info])]
end

function addon:Config_PetToggle_Weighted_Get(info)
	local id = tonumber(info[#info])
	if (not self.db.profile.ignore_pets[id]) then
		return math.floor((self.db.profile.weights[id] or 1) * 5) + 1
	end
	return 1
end

function addon:Config_PetToggle_Weighted_Set(info, v)
	local id = tonumber(info[#info])
	if (v == 1) then
		self.db.profile.ignore_pets[id] = true
	else
		self.db.profile.ignore_pets[id] = false
		self.db.profile.weights[id] = (v - 1) / 5
	end
	self:LoadPets(false)
end

function addon:_Config_PetToggle_SetAll(info, v)
	for key in pairs(info.options.args.pets.args.pets.args) do
		self.db.profile.ignore_pets[tonumber(key)] = v
	end
	self:LoadPets(false)
end

-- events

function addon:PLAYER_ENTERING_WORLD()
	-- reload hijinks: maybe we have a pet out already!
	if (#self.usable_pets > 0 and IsPetted()) then
		self:StartAutoSwitchTimer()
	end

	self:TryInitSpec()
	self:TryInitLocation()
	self:UpdateQuestList()
end

function addon:COMPANION_UPDATE(event, ctype)
	if (ctype == nil) then
		self:LoadPets()
	elseif (ctype == "CRITTER") then
		-- TODO: pet was shown or hidden
		self:UpdatePetTimer()
	end
end

function addon:COMPANION_LEARNED()
	self:LoadPets()
end

function addon:BARBER_SHOP_OPEN()
	self.player_barber = true
end

function addon:BARBER_SHOP_CLOSE()
	self.player_barber = false
end

function addon:UPDATE_STEALTH()
	if (IsStealthed()) then
		if (self.db.profile.dismissWhenStealthed) then
			-- desummon pet, but don't disable completely
			self:DesummonPet(true)
		end
	else
		self:UpdatePetTimer()
	end
end

local INVIS_SPELLS = { 66, 11392, 3680, 80326 }
function addon:UNIT_AURA(event, unit)
	if (unit ~= "player") then
		return
	end

	-- check for invisibility
	local invisible = false
	for i, spellid in ipairs(INVIS_SPELLS) do
		local invis_name, _, invis_texture = GetSpellInfo(spellid)
		local c_name, _, c_texture = UnitAura("player", invis_name, nil, "HELPFUL")
		if (c_name == invis_name and invis_texture == c_texture) then
			invisible = true
			break
		end
	end

	if (invisible) then
		if (not self.player_invisible) then
			self.player_invisible = true
			if (IsPetted() and self.db.profile.dismissWhenStealthed) then
				self:DesummonPet(true)
			end
		end
	else
		if (self.player_invisible) then
			self.player_invisible = false
			self:UpdatePetTimer()
		end
	end
end

function addon:OnZoneChanged()
	local curZone = GetZoneText()
	if self.currentZone ~= curZone then
		self.currentZone = curZone
		if PetLeash.db.profile.autoSwitchOnZone then
			-- pet will be resummoned shortly
			if (CanSummonPet()) then
				self:DesummonPet(true)
			end
		end
	end
end

function addon:OnSpecChanged(curSpec)
	if self.currentSpec ~= curSpec then
		self.currentSpec = curSpec
		-- pet will be resummoned shortly
		if (CanSummonPet()) then
			self:DesummonPet(true)
		end
	end
end

function addon:ZONE_CHANGED()
	self:DoLocationCheck(true)
	self:OnZoneChanged()
end

function addon:ZONE_CHANGED_INDOORS()
	self:DoLocationCheck(true)
	self:OnZoneChanged()
end

function addon:ZONE_CHANGED_NEW_AREA()
	self:DoLocationCheck(true)
	self:OnZoneChanged()
end

function addon:ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED(event, spec)
	self:DoLocationCheck(true)
	self:OnSpecChanged(spec)
end

function addon:PLAYER_UPDATE_RESTING()
	self:DoLocationCheck(true)
end

function addon:ENCOUNTER_START()
    if self.db.profile.desummonVSBoss then
        addon:DesummonPet(true)
    end
end

function addon:PLAYER_REGEN_DISABLED()
	local _, t = IsInInstance()
    if self.db.profile.desummonInCombat  or (self.db.profile.desummonPartyCombat and t == "party") or (self.db.profile.desummonRaidCombat and t == "raid") then
        addon:DesummonPet(true)
    end
end

function addon:QUEST_ACCEPTED()
	self:UpdateQuestList()
end

function addon:QUEST_FINISHED()
	self:UpdateQuestList()
end

function addon:UpdateQuestList()
	self.currentquests = {}
	for i = 1, (GetNumQuestLogEntries() or 0) do
		local link = GetQuestLink(i)
		if link ~= nil then
			local _, _, qid = string.find(link, "|Hquest:(%d+):(%d+)|")
			if qid ~= nil then
				self.currentquests[tonumber(qid)] = true
			end
		end
	end
end

function addon.PlayerHasQuest(questid)
	return addon.currentquests[questid]
end

function addon:UpdatePetTimer()
	local haspet = self:HasPet(true)
	if (not haspet) then
		self:StartPetTimer()
	else
		-- we have a pet
		if (not self.ready_to_autoswitch) then
			-- and we are happy with it
			self:StopPetTimer()
			self:StartAutoSwitchTimer(true)
		end
	end
end

local countdown
function addon:StartPetTimer()
	countdown = self.db.profile.waitTimer * 2 -- set countdown
	if (self.pet_timer) then
		countdown = countdown + 1        -- add padding
		return                           -- leave timer running
	end
	self.pet_timer = self:ScheduleRepeatingTimer("PeriodicCheckPet", 0.5)
end

function addon:StopPetTimer()
	self:CancelTimer(self.pet_timer)
	self.pet_timer = nil
end

function addon:PeriodicCheckPet()
	countdown = countdown - 1
	if (not self:IsPetSummonReady()) then
		-- reset timer
		countdown = self.db.profile.waitTimer * 2
	elseif (countdown == 0) then
		self:SummonPet()
		self:StopPetTimer()

		self:ScheduleTimer("UpdatePetTimer", 3) -- verify success
	end
end

function addon:IsPetSummonReady()
	if (not self.db.profile.enable) then
		return
	elseif (not self.db.profile.enableInCombat and InCombat()) then
		return
	elseif (self.db.profile.disableForQuestItems and self:HasQuestItem()) then
		return
	elseif (not self.db.profile.enableInBattleground and InBattlegroundOrArena()) then
		return
	elseif (self.db.profile.disableOutsideCities and not IsResting()) then
		return
	end

	if (CanSummonPet()) then
		return true
	end
end

function addon:HasPet(nocache)
	if (nocache) then
		local pet_id = IsPetted(self.pet_id) or IsPetted()
		self.pet_id = pet_id
		return pet_id
	end
	return self.pet_id
end

function addon:FlightCheck()
	if (not self.db.profile.dismissWhileFlying or not self:HasPet()) then
		return
	end

	if (IsFlying()) then
		addon:DesummonPet(true)
	end
end

function addon:StartAutoSwitchTimer(dont_restart)
	if (self.switch_timer_handle) then
		if (dont_restart) then
			return
		end

		self:CancelTimer(self.switch_timer_handle)
		self.switch_timer_handle = nil
	end

	local timer = self.db.profile.autoSwitchTimer
	if (timer) then
		self.switch_timer_handle = self:ScheduleTimer("AutoSwitchTimer", timer)
	end
end

function addon:AutoSwitchTimer()
	self.switch_timer_handle = nil -- timer is finished!

	if (self.db.profile.autoSwitchCitiesOnly and not IsResting()) then
		-- not resting, when we require it  restart timer!
		return self:StartAutoSwitchTimer()
	end

	self.ready_to_autoswitch = true
	self:StartPetTimer()
end

local function pick_flat(self, petlist)
	petlist = petlist or self.usable_pets
	local random_spellid = petlist[math.random(#petlist)]
	return self.pet_map[random_spellid].id
end

local function pick_weighted(self, countdown)
	countdown = (countdown or 1000) -- upper bound on tries

	local random_spellid = self.usable_pets[math.random(#self.usable_pets)]
	local weight = self.db.profile.weights[random_spellid] or 1

	assert(weight > 0)

	if (math.random() > weight and countdown > 0) then
		-- retry
		return pick_weighted(self, countdown - 1)
	end

	return self.pet_map[random_spellid].id
end

function addon:PickPet()
	if (self.override_pets and #self.override_pets > 0) then
		return pick_flat(self, self.override_pets)
	end

	if (not self.db.weightedPets) then
		return pick_flat(self)
	else
		return pick_weighted(self)
	end
end

function addon:SummonPet()
	if (#self.usable_pets > 0) then
		CallCompanion("CRITTER", self:PickPet())

		self.ready_to_autoswitch = false
		self:StartAutoSwitchTimer()
	end
end

function addon:DesummonPet(disable)
	DismissCompanion("CRITTER")
	if (not disable or disable == nil) then
		addon:EnableSummoning(false)
	end
end

function addon:ResummonPet()
	self:EnableSummoning(true)

	self:DesummonPet(true)
	self:SummonPet()
end

function addon:TogglePet()
	if (IsPetted()) then
		self:DesummonPet()
	else
		self:EnableSummoning(true)
		if (CanSummonPet()) then
			self:SummonPet()
		end
	end
end
