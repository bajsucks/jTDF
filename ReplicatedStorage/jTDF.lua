-- @ScriptType: ModuleScript
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 9/26/2025
	Author: baj (@artembon)
	Description:
	
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SlotTowers = require(script.SlotTowers)
local EnemyModule = require(script.Enemies)

local t = require(script.internal.t)

type Tower = SlotTowers.Tower
type Stats = SlotTowers.Stats
type Enemy = Enemies.Enemy

export type Unit = {
	["CurUpgrade"]: number,
	["CurStats"]: Stats,
	["StatusEffects"]: {[number]: string},
	["Owner"]: number -- userid
}
local CheckUnit = t.tuple(t.instanceIsA("Player"), t.table, t.CFrame)

local jTDF = {Units = {}, Enemies = {}}
local Units, Enemies = jTDF.Units, jTDF.Enemies
Units.__index, Enemies.__index = Units, Enemies

function Units:CheckUnitPlacement(Position:Vector3)
	
end

-- Client and server functions

function jTDF.UnitFromID(ID:string)
	
end

if RunService:IsClient() then
	
	-- Client functions
	
	return jTDF
end

-- Server functions

local CheckNewUnit = t.tuple(t.instanceIsA("Player"), t.table, t.CFrame)

-- creates a new unit at cframe
function Units.new(Player:Player, Tower:Tower, CF:CFrame): Unit
	assert(CheckNewUnit(Player, Tower, CF))
	
	local userid = Player.UserId
	assert(userid, "very weird")
	
	local self = setmetatable({}, Units)
	self.CurUpgrade = 0
	self.CurStats = Tower.Upgrades[0]
	self.CurStats.Cost = nil
	self.StatusEffects = {}
	
	return self
end


function Units:Destroy()
	
end

function jTDF.UpgradeUnit()
	
end


return jTDF
