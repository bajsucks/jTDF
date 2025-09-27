-- @ScriptType: ModuleScript
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 9/27/2025
	Author: baj (@artembon)
	Description: Tower and enemy functions
	
]]

-- services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- constant modules
local CTowers = require(script.CTowers)
local CEnemies = require(script.CEnemies)
local Config = require(script.Config)

-- internal modules
local Util = require(script.internal.Util)
local t = require(script.internal.t)
local Signal = require(script.internal.Signal)

local Effects: {
	[string]: (Stats:Stats)->(Stats)
}={}

-- types
type CTower = CTowers.CTower
type CEnemy = Enemies.CEnemy
type Stats = CTowers.Stats

export type Unit = {
	["CTowerID"]: string,
	["CurUpgrade"]: number,
	["CurStats"]: Stats,
	["StatusEffects"]: {[string]: boolean|thread}, -- update documentation
	["Owner"]: number, -- userid
	["Position"]: Vector3,
	["Model"]: Model,
	["Shot"]: Signal.Signal<string>,
	["StatusEffectsChanged"]: Signal.Signal<string, boolean>,
	["Upgraded"]: Signal.Signal<number>,
	["StatsChanged"]: Signal.Signal,
	["Destroying"]: Signal.Signal
}

export type Enemy = {
	["Name"]: string,
	["Speed"]: number,
	["Health"]: number,
	["Model"]: Model,
	["LastHit"]: Unit,
	["StatusEffects"]: {[number]: string},
	["StatsChanged"]: Signal.Signal,
	["Destroying"]: Signal.Signal
}

-- type refiner
-- intellisense doesn't work on self without this
local function r(self)
	self = self :: Unit
end

local CheckUnit = t.interface({
	CurUpgrade = t.number,
	CurStats = t.table,
	StatusEffects = t.table,
	Owner = t.number,
	Position = t.Vector3
})

local jTDF = {Units = {}, Enemies = {}}
local Units, Enemies = jTDF.Units, jTDF.Enemies
Units.__index, Enemies.__index = Units, Enemies


-- Client and server functions

function jTDF.CheckTowerPlacement(Position:Vector3): boolean
	-- TBD
end

if RunService:IsClient() then
	
	-- Client functions
	
	return jTDF
end

-- Server functions

function jTDF.RegisterEffect(Effect:string, func:()->())
	
end

-- global signals (not sigfor because intellisense)
jTDF.UnitPlaced = Signal()
jTDF.UnitDestroying = Signal()
jTDF.UnitChanged = Signal()
jTDF.EnemyKilled = Signal()
jTDF.EnemySpawned = Signal()

local CheckNewUnit = t.tuple(t.instanceIsA("Player"), t.string, t.Vector3)

-- creates a new unit at cframe
function Units.new(Player:Player, CTowerID:string, Position:Vector3): Unit
	assert(CheckNewUnit(Player, CTowerID, Position))
	local CTower = CTowers[CTowerID]
	if not CTower then error("Provided wrong CTowerID!") end
	
	local userid = Player.UserId
	assert(userid, "very weird")
	
	local self = setmetatable({}, Units)
	
	self.CurUpgrade = 0
	self.CurStats = CTower.Upgrades[1]
	self.CTowerID = CTowerID
	self.CurStats.Cost = nil
	self.StatusEffects = {}
	self.Position = Position
	self.Model = CTower.Model:Clone()
	self.Model.Parent = Config.TowerParent
	
	-- set signals
	Util.sigfor(self, {"Shot", "StatusEffectChanged", "Upgraded", "StatsChanged", "Destroying"})
	
	return self
end

function Units:Destroy()
	task.spawn(function()
		r(self)
		self.Destroying:Fire()
		jTDF.UnitDestroying:Fire(self)
		
		task.wait()
		self.Model:Destroy()
		self = nil
	end)
end

function Units:UpgradeUnit()
	r(self)
	self.CurUpgrade += 1
	self.StatsChanged:Fire()
	-- TBD
end

local ef = t.tuple(t.string, t.optional(t.number))
-- add effect
function Units:Effect(Effect:string, duration:number?)
	assert(ef(Effect, duration))
	r(self)
	if duration then self.StatusEffects[Effect] = task.delay(duration, function()
			self.StatusEffects[Effect] = nil
		end)
	else
		self.StatusEffects[Effect] = true
	end
end
-- clears a specified status effect
function Units:ClearEffect(Effect:string)
	r(self)
	if not self.StatusEffects[Effect] then return end
	
	if self.StatusEffects[Effect] == true then self.StatusEffects[Effect] = nil return end

	if typeof(self.StatusEffects[Effect]) == "thread" then
		coroutine.close(self.StatusEffects[Effect])
	else
		print("shady shit")
	end
	return
end


local function milk(self:Unit)
	for i, v in self.StatusEffects do
		if v == true then continue end

		if typeof(v) == "thread" then
			coroutine.close(self.StatusEffects[i])
		else
			print("shady shit")
		end
	end
end

-- clears all status effects, except permanent
function Units:Milk()
	r(self)
	milk(self)
	self.StatusEffectsChanged:Fire()
end

-- clears all status effects, including permanent
function Units:SuperMilk()
	r(self)
	milk(self)
	self.StatusEffects = {}
	self.StatusEffectsChanged:Fire()
end

function Enemies.new(CEnemy)
	local self = setmetatable({}, Enemies)
	Util.sigfor(self, {"Shot", "StatusEffectChanged", "Upgraded", "StatsChanged", "Destroying"})
	return self
end

function Enemies:Destroy()
	jTDF.EnemyKilled:Fire()
end

return jTDF
