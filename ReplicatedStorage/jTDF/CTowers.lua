-- @ScriptType: ModuleScript
--[[
	SlotTowers module
	Created: 9/25/2025
	Last updated: 9/27/2025
	Author: baj (@artembon)
	Description: Holds read-only information about each tower.
	
	SlotTowers shouldn't be changed at runtime
	Consider using Unit's StatusEffect for dynamic stat changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Stats = {
	["Cost"]: number,
	["Range"]: number?, -- studs
	["Damage"]: number,
	["FireRate"]: number, -- seconds
	["FireFunction"]: (Target: {}) -> (boolean)?
	-- FireFunction receives an enemy as target
	-- When true is returned, firerate will be applied
	-- tip: You can intentionally yield this function to wait BEFORE firerate applies
}

export type CTower = {
	["Name"]: string,
	["Model"]: Model,
	["Upgrades"]: {
		[number]: Stats
	}
}

local CTowers:{[string]: CTower} = table.freeze {
	["Pistol Guy"] = {
		["Name"] = "Pistol Guy", -- display name?
		["Model"] = ReplicatedStorage.Towers["Pistol Guy"],
		["Upgrades"] = {
			[1] = {
				["Cost"] = 10,
				["Range"] = 1,
				["Damage"] = 1,
				["FireRate"] = 1,
				["FireFunction"] = nil
			},
		}
	}
}

return CTowers
