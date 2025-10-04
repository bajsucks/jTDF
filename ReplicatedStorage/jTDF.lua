-- @ScriptType: ModuleScript
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 10/3/2025
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
type CEnemy = CEnemies.CEnemy
type Stats = CTowers.Stats

export type Unit = {
	["CTowerID"]: string,
	["CurUpgrade"]: number,
	["CurStats"]: Stats,
	["StatusEffects"]: {[string]: thread|boolean}, -- update documentation
	["Owner"]: number, -- userid
	["Position"]: Vector3,
	["Model"]: Model,
	["Shot"]: Signal.Signal<string>,
	["StatusEffectsChanged"]: Signal.Signal<string, boolean>,
	["Upgraded"]: Signal.Signal<number>,
	["StatsChanged"]: Signal.Signal<>,
	["Destroying"]: Signal.Signal<>
}

export type Enemy = {
	["Name"]: string,
	["Speed"]: number,
	["Health"]: number,
	["Model"]: Model,
	["LastHit"]: Unit,
	["StatusEffects"]: {[number]: string},
	["StatsChanged"]: Signal.Signal<>,
	["Destroying"]: Signal.Signal<>,
	["GotDamaged"]: Signal.Signal<Unit>
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

local PathFolder:Folder?


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

-- global signals (not signalfor because intellisense)
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
	Util.signalfor(self, {"Shot", "StatusEffectChanged", "Upgraded", "StatsChanged", "Destroying"})
	
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

local function GetPaths(): {[number]: Attachment}
	return CollectionService:GetTagged("EnemyPath")
end

local UpToDate = {FirstPath = false, LastPath = false}
local LastValues = {FirstPath = nil, LastPath = nil}

local function GetFirstPath(): Attachment?
	if not UpToDate.FirstPath then
		local minID = math.huge
		for i, v in GetPaths() do
			if v:GetAttribute("PathID") < minID then minID = v:GetAttribute("PathID") LastValues.FirstPath = v end
		end
		UpToDate.FirstPath = true
	end
	print(LastValues.FirstPath)
	return LastValues.FirstPath
end

local function GetLastPath(): Attachment?
	if not UpToDate.LastPath then
		local minID = -math.huge
		for i, v in GetPaths() do
			if v:GetAttribute("PathID") > minID then minID = v:GetAttribute("PathID") LastValues.LastPath = v end
		end
		UpToDate.LastPath = true
	end
	return LastValues.LastPath
end

local function GetNextPath(id:number): Attachment?
	local minID = math.huge
	local nextid
	local paths = GetPaths()
	print(paths)
	for i, v in paths do
		local val = v:GetAttribute("PathID")
		print("checking id: ", val)
		if val > id and id < minID then minID = v:GetAttribute("PathID") nextid = v end
	end
	print("Next path selected:", nextid and nextid:GetAttribute("PathID") or "none")
	return nextid
end

local function GetPathByID(id:number): Attachment?
	for i, v in GetPaths() do
		if v:GetAttribute("PathID") == id then return v end
	end
end

function Enemies.new(CEnemyID: string, summon:boolean?)
	local CEnemy = CEnemies[CEnemyID]
	if not CEnemy then error("Provided wrong CEnemyID!") end
	local self = setmetatable({}, Enemies)
	r(self)
	self.Name = CEnemyID
	self.Speed = CEnemy.BaseSpeed
	self.Health = CEnemy.BaseHealth
	self.Model = CEnemy.Model:Clone()
	Util.signalfor(self, {"GotDamaged", "StatsChanged", "Destroying", "BreakAI"})
	if not summon then return self end
	local f = workspace:FindFirstChild("Enemies")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Enemies"
		f.Parent = workspace
	end
	self.Model.Parent = f
	self:BeBorn()
	return self
end

-- Starts enemy AI at given PathID (you might want)
function Enemies:BeBorn(curID:number?)
	local StartAttach = not self.curID and GetFirstPath() or GetPathByID(self.curID)
	self.curID = StartAttach:GetAttribute("PathID")
	local stop = false
	self.BreakAI:Once(function() stop = true end)
	self.Model:PivotTo(StartAttach.WorldCFrame + Vector3.yAxis*3)
	local hum: Humanoid = self.Model:FindFirstChildWhichIsA("Humanoid")
	
	local connection: RBXScriptConnection
	
	local function WalkToNext() -- TODO: !!!!! USE TWEENS ON CLIENT INSTEAD OF THIS MoveToFinished SHIT -- I just made this to test pathids
		print("walktonext from pathid", self.curID)
		if stop then connection:Disconnect() return end
		local nextPath = GetNextPath(self.curID)
		print("moving to pathid", nextPath:GetAttribute("PathID"))
		if not nextPath then connection:Disconnect() warn("That was the last pathid, man.") return end
		hum:MoveTo(nextPath.WorldPosition)
		self.curID = nextPath:GetAttribute("PathID")
	end
	
	connection = hum.MoveToFinished:Connect(WalkToNext)
	WalkToNext()
end

-- Stops enemy AI
function Enemies:Lobotomize()
	self.BreakAI:Fire()
end

-- Destroys the enemy
function Enemies:Destroy()
	task.spawn(function()
		r(self)
		self.Destroying:Fire()
		jTDF.EnemyKilled:Fire(self)

		task.wait()
		self.Model:Destroy()
		self = nil
	end)
end

return jTDF
