-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
type Enemy = {
	["Name"]: string,
	["BaseHealth"]: number,
	["BaseSpeed"]: number,
	["Model"]: Model
}

local Enemies: {[string]: Enemy} = {
	--["Green Zombie"] = {
	--	["Name"] = "",
	--	["BaseHealth"] = 1,
	--	["BaseSpeed"] = 1,
	--	["Model"] = ReplicatedStorage.Enemies["Green Zombie"]
	--}
}

return Enemies
