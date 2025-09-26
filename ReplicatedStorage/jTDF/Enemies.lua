-- @ScriptType: ModuleScript
--[[
	Enemies module
	Created: 9/26/2025
	Last updated: 9/26/2025
	Author: baj (@artembon)
	Description: Holds information about enemies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
export type Enemy = {
	["Name"]: string,
	["BaseHealth"]: number,
	["BaseSpeed"]: number,
	["Model"]: Model
}

local Enemies: {[string]: Enemy} = {
	["Green Zombie"] = {
		["Name"] = "",
		["BaseHealth"] = 1,
		["BaseSpeed"] = 1,
		["Model"] = ReplicatedStorage.Enemies["Green Zombie"]
	}
}

return Enemies
