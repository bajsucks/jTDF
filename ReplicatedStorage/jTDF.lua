-- @ScriptType: ModuleScript
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 9/26/2025
	Author: baj (@artembon)
	Description: Tower and enemy functions
	
]]

-- services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- constant modules
local CTowers = require(script.CTowers)
local CEnemies = require(script.CEnemies)

-- internal modules
local Util = require(script.internal.Util)
local t = require(script.internal.t)
local Signal = require(script.internal.Signal)

-- types
type CTower = CTowers.CTower
type CEnemy = Enemies.CEnemy
type Stats = CTowers.Stats

export type Unit = {
	["CurUpgrade"]: number,
	["CurStats"]: Stats,
	["StatusEffects"]: {[number]: string},
	["Owner"]: number, -- userid
	["Shot"]: Signal.Signal<string>,
	["StatusEffectsChanged"]: Signal.Signal<string, boolean>,
	["Upgraded"]: Signal.Signal<number>,
	["StatsChanged"]: Signal.Signal,
	["Destroying"]: Signal.Signal
}

-- type refiner
local function r(self)
	self = self :: Unit
end

local CheckUnit = t.interface({
	CurUpgrade = t.number,
	CurStats = t.table,
	StatusEffects = t.table,
	Owner = t.number
})

local jTDF = {Units = {}, Enemies = {}}
local Units, Enemies = jTDF.Units, jTDF.Enemies
Units.__index, Enemies.__index = Units, Enemies


function jTDF.CheckTowerPlacement(Position:Vector3)
	-- TBD
end

-- Client and server functions

function jTDF.UnitFromID(ID:string)
	-- TBD
end

if RunService:IsClient() then
	
	-- Client functions
	
	return jTDF
end

-- Server functions

-- global signals (not sigfor because intellisense)
jTDF.UnitPlaced = Signal()
jTDF.UnitDestroyed = Signal()
jTDF.UnitChanged = Signal()

local CheckNewUnit = t.tuple(t.instanceIsA("Player"), t.table, t.CFrame)

-- creates a new unit at cframe
function Units.new(Player:Player, Tower:Tower, CF:CFrame): Unit
	assert(CheckNewUnit(Player, Tower, CF))
	
	local userid = Player.UserId
	assert(userid, "very weird")
	
	local self = setmetatable({}, Units)
	self.CurUpgrade = 0
	self.CurStats = Tower.Upgrades[1]
	self.CurStats.Cost = nil
	self.StatusEffects = {}
	-- set signals
	Util.sigfor(self, {"Shot", "StatusEffectChanged", "Upgraded", "StatsChanged", "Destroying"})
	
	return self
end


function Units:Destroy()
	r(self)
	
	self.
	
	assert(CheckUnit(self))
	self.Destroying:Fire()
	-- TBD
end

function Units:UpgradeUnit()
	-- TBD
end


return jTDF
