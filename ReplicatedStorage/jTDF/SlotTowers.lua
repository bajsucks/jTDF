-- @ScriptType: ModuleScript
--[[
	SlotTowers module
	Created: 9/25/2025
	Last updated: 9/25/2025
	Author: baj (@artembon)
	Description: Holds read-only information about each tower.
	
	SlotTowers CANNOT be changed at runtime
	Consider using Unit's StatusEffect for dynamic stat changes.
]]

type Tower = {
	["Name"]: string,
	["Upgrades"]: {
		[number]: {
			["Cost"]: number,
			["Stats"]: {
				["Range"]: number?, -- studs
				["Damage"]: number,
				["FireRate"]: number, -- seconds
				["FireFunction"]: (string) -> (boolean)?
				-- FireFunction receives TargetID
				-- When true is returned, firerate will be applied
				-- tip: You can intentionally yield this function to wait BEFORE firerate applies
			}
		}
	}
}

local SlotTowers:{[string]: Tower} = table.freeze {
	--["Pistol Guy"] = {
	--	["Name"] = "Pistol Guy",
	--	["Upgrades"] = {
	--		[1] = {
	--			["Cost"] = 10,
	--			["Stats"] = {
	--				["Range"] = 1,
	--				["Damage"] = 1,
	--				["FireRate"] = 1,
	--				["FireFunction"] = nil
	--			}
	--		},
	--	}
	--}
}

return SlotTowers
