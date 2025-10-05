-- @ScriptType: ModuleScript
--[[
	Enemies module
	Created: 9/26/2025
	Last updated: 10/5/2025
	Author: baj (@artembon)
	Description: Holds enemy properties.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
export type CEnemy = {
	["Name"]: string,
	["BaseHealth"]: number,
	["BaseSpeed"]: number,
	["Model"]: Model
}

local CEnemies: {[string]: CEnemy} = table.freeze{
	["Green Zombie"] = {
		["Name"] = "",
		["BaseHealth"] = 100,
		["BaseSpeed"] = 1,
		["Model"] = ReplicatedStorage.Enemies["Green Zombie"]
	}
}

return CEnemies
