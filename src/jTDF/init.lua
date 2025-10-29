--!optimize 2
--!native
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 10/20/2025
	Author: baj (@artembon)
	Description: Tower and enemy functions
]]

-- services

local __version = "1.0.0"

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")

-- declarations
local jTDF = {Units = {}, Enemies = {}, Radius = {}}
local Units, Enemies, Radius = jTDF.Units, jTDF.Enemies, jTDF.Radius
Units.__index, Enemies.__index, Radius.__index = Units, Enemies, Radius
local CEnemies = {}
local CTowers = {}
jTDF.ActiveUnits = {}
jTDF.ActiveEnemies = {}
jTDF.ActiveRadii = {}

-- internal modules
local Config = require(script.Config)
local Janitor = require(script.internal.Janitor)
local Signal = require(script.internal.Signal)
local t = require(script.internal.t)
local Util = require(script.internal.Util)

jTDF.Path = require(script.Path)
local Path = jTDF.Path

-- fetch functions
function jTDF.GetUnits() return jTDF.ActiveUnits end
function jTDF.GetEnemies() return jTDF.ActiveEnemies end
function jTDF.GetRadii() return jTDF.ActiveRadii end

local threadsafe = require(script.ThreadSafe)
Enemies.GetProgressComponent = threadsafe.GetProgressComponent
Enemies.GetProgress = threadsafe.GetProgress

--[[
Returns world position of an enemy
]]
function Enemies.GetWorldPos(self:Enemy): Vector3
	if not self then return end
	local a, b, _, _, _, Progress = Enemies.GetProgress(self, true)
	return a:Lerp(b, Progress)
end

function Enemies.StartTimeFromProgress(self:Enemy, Progress:number): number
	local _, _, PathLength = Enemies.GetProgress(self, true)
	local DistanceCovered = PathLength * Progress
	local ef = DistanceCovered/self.Speed
	self.StartTime = workspace:GetServerTimeNow() - ef
	return self.StartTime
end

-- server and client types
export type CEnemy = {
	["Name"]: string,
	["BaseHealth"]: number,
	["BaseSpeed"]: number
}
export type CTowerStats = {
	["Range"]: number?, -- studs
	["FireFunction"]: (self:{}, Unit:{}, Targets: {{}}) -> (),
	["CheckFunction"]: (self:{}) -> boolean,
	["RadiusConfig"]: {
		["CanLock"]: boolean,
		["MaxLockedTargets"]: number,
		["TargetType"]: number,
		["IsPassive"]: boolean
	}
}
export type CTower = {
	["Name"]: string,
	["Upgrades"]: {
		[number]: CTowerStats
	}
}

if RunService:IsClient() then return jTDF end
if Config.BootText then warn(`Running jTDF v{__version}\nYou can disable this text in the config.`) end

local ST_EnemyProgress = SharedTable.new()
SharedTableRegistry:SetSharedTable("EnemyProgress", ST_EnemyProgress)

local ST_Enemies = SharedTable.new()
SharedTableRegistry:SetSharedTable("Enemies", ST_Enemies)

local ST_Radii = SharedTable.new()
SharedTableRegistry:SetSharedTable("Radii", ST_Radii)

-- [ Server functions ]

-- Creates a new actor in ServerScriptService
local function CreateActor(Script:Script)
	local Actor = Instance.new("Actor")

	local f = Util.SpawnFolder("jTDF_Actors", ServerScriptService)
	Actor.Parent = f
	local s = Script:Clone()
	s.Parent = Actor
	s.Enabled = true
	return Actor
end

do -- server signals (not signalfor because intellisense)
	jTDF.UnitPlaced = Signal()
	jTDF.UnitDestroying = Signal()
	jTDF.UnitShot = Signal()
	jTDF.UnitChanged = Signal()
	jTDF.EnemyKilled = Signal()
	jTDF.EnemySpawned = Signal()
	jTDF.EnemyUpdated = Signal()
	jTDF.NewRadius = Signal()
	jTDF.RadiusDestroyed = Signal()
end

-- creates a new unit at position
local UnitCounter = 0
function Units.new(Player:Player?, CTowerID:string, Position:Vector3|vector, pathLabels: {string}?)
	
	local CheckNewUnit = t.tuple(t.instanceIsA("Player"), t.string, t.vector)
	assert(CheckNewUnit(Player, CTowerID, Position))
	
	local CTower: CTower = CTowers[CTowerID]
	if not CTower then error("Provided CTowerID is not yet defined!") end

	local userid = Player and Player.UserId or nil

	UnitCounter += 1
	
	local self = {}

	self.CurLevel = 1
	self.CurStats = CTower.Upgrades[1]
	self.CTowerID = CTowerID
	self.pathLabels = pathLabels
	self.TowerID = tostring(UnitCounter)
	self.Position = Util.tovector(Position) :: vector
	self.StatusEffects = {} :: {[string]: thread|boolean}
	self.Owner = userid
	jTDF.ActiveUnits[self.TowerID] = self
	self.CurStats.RadiusConfig.TowerID = self.TowerID
	self.CurStats.RadiusConfig.pathLabels = self.pathLabels
	if not self.CurStats.RadiusConfig.IsPassive then
		self.Radius = Radius.new(Position, self.CurStats.Range, self.CurStats.RadiusConfig)
	end
	
	setmetatable(self, Units)

	-- set signals
	Util.signalfor(self, {"Shot", "Upgraded", "StatsChanged", "Destroying"})
	jTDF.UnitPlaced:Fire(self)

	return self
end

function Units.Define(ID:string?, CTower:CTower|{[string]: CTower})
	if not ID and typeof(CTower) == "table" then
		for i, v in CTower do
			CTowers[i] = v
		end
		return
	end
	CTowers[ID] = CTower
end

function Units.Destroy(self:Unit)
	task.spawn(function()
		self.Destroying:Fire()
		jTDF.UnitDestroying:Fire(self)
		if self.Radius then
			self.Radius:Destroy()
		end

		task.wait()
		jTDF.ActiveUnits[self.TowerID] = nil
		self = nil
	end)
end

function Units.Upgrade(self:Unit)
	local CTower: CTower = CTowers[self.CTowerID]
	if self.CurLevel + 1 > #CTower.Upgrades then print(CTower.Upgrades, #CTower.Upgrades, self.CurLevel + 1); return self.CurLevel end
	self.CurLevel += 1
	self.CurStats = CTower.Upgrades[self.CurLevel]
	if self.Radius then
		self.Radius:Resize(self.CurStats.Range)
	end
	self.StatsChanged:Fire()
	jTDF.UnitChanged:Fire(self)
	return self.CurLevel
end

local EnemyCounter = 0

function Enemies.Define(ID:string?, CEnemy:CEnemy|{[string]: CEnemy})
	if not ID and typeof(CEnemy) == "table" then
		for i, v in CEnemy do
			CEnemies[i] = v
		end
		return
	end
	CEnemies[ID] = CEnemy
end

-- create a new enemy and place him on the Path of the Damned
function Enemies.new(CEnemyID: string, pathLabel:string, PathPosition:{CurrentPath: Attachment, Progress:number})
	
	local CheckNewEnemy = t.tuple(t.string, t.string)
	assert(CheckNewEnemy(CEnemyID, pathLabel))
	
	local CEnemy = CEnemies[CEnemyID]
	if not CEnemy then error("Provided wrong CEnemyID!") end
	EnemyCounter += 1
	
	local self = {}
	
	self.CEnemyID = CEnemyID
	self.Speed = CEnemy.BaseSpeed
	self.Health = CEnemy.BaseHealth
	self.EnemyID = tostring(EnemyCounter)
	local p = PathPosition and PathPosition.CurrentPath or Path.GetFirstPath(pathLabel)
	self.CurrentPath = p
	self.NextPath = Path.GetNextPath(pathLabel, self.CurrentPath:GetAttribute("PathID"))
	self.StartTime = workspace:GetServerTimeNow()
	if PathPosition and PathPosition.Progress then
		local NewStartTime = Enemies.StartTimeFromProgress(self, PathPosition.Progress)
		self.StartTime = NewStartTime
	end
	self.DestroyOnDeath = true
	self.LastHit = nil :: Unit?
	self.pathLabel = pathLabel
	self.Frozen = nil :: number?
	
	Util.signalfor(self, {"GotDamaged", "StatsChanged", "Destroying"})
	
	setmetatable(self, Enemies)

	jTDF.ActiveEnemies[self.EnemyID] = self
	
	self:__Reconstruct()

	jTDF.EnemySpawned:Fire(self)

	return self
end

-- murder, but on server
function Enemies.Destroy(self:Enemy)
	self.Destroying:Fire()
	jTDF.EnemyKilled:Fire(self)
	jTDF.ActiveEnemies[self.EnemyID] = nil
	ST_EnemyProgress[self.EnemyID] = nil
	ST_Enemies[self.EnemyID] = nil
	self:__Deconstruct()
	task.defer(function()
		task.wait()
		self:__Deconstruct()
		self = nil
	end)
end

function Enemies.Damage(self:Enemy, Damage:number, WhoDamaged:Unit?): boolean
	local Died = false
	self.Health = math.max(0, self.Health - Damage)
	if self.Health <= 0 then Died = true end
	self.GotDamaged:Fire()
	jTDF.EnemyUpdated:Fire(self)
	--print("damaged", self.EnemyID)
	
	if WhoDamaged then self.LastHit = WhoDamaged end
	
	self:__Reconstruct()
	
	if Died and self.DestroyOnDeath then
		self.WasKilled = true
		self:Destroy()
	end
	return Died
end

function Enemies.ChangeSpeed(self:Enemy, NewSpeed:number)
	if NewSpeed == 0 then warn("Enemy speed of 0 is not supported!\nUse Enemy:Freeze() and Enemy:Unfreeze() instead."); return end
	local _, _, _, _, DistanceCovered, _ = Enemies.GetProgress(self, true)
	local ef = DistanceCovered/NewSpeed
	self.StartTime = workspace:GetServerTimeNow() - ef
	self.Speed = NewSpeed
	self:__Reconstruct()
	jTDF.EnemyUpdated:Fire(self)
end

function Enemies.Freeze(self:Enemy)
	if self.Frozen then return end
	self.Frozen = workspace:GetServerTimeNow()
	self:__Reconstruct()
	jTDF.EnemyUpdated:Fire(self)
end

function Enemies.Unfreeze(self:Enemy)
	if not self.Frozen or not jTDF.ActiveEnemies[self.EnemyID] then return end
	local difference = workspace:GetServerTimeNow() - self.Frozen
	self.Frozen = nil
	self.StartTime += difference
	self:__Reconstruct()
	jTDF.EnemyUpdated:Fire(self)
end

function Enemies.__Reconstruct(self:Enemy)
	local t = {
		CurrentPathPos = Util.tovector(self.CurrentPath.WorldPosition),
		CurrentPathID = self.CurrentPath:GetAttribute("PathID"),
		NextPathPos = Util.tovector(self.NextPath.WorldPosition),
		StartTime = self.StartTime,
		Speed = self.Speed,
		pathLabel = self.pathLabel,
		Frozen = self.Frozen
	}
	ST_Enemies[self.EnemyID] = t
	return t
end

function Enemies.__Deconstruct(self:Enemy)
	ST_Enemies[self.EnemyID] = nil
end

local WaypointActors: {Actor} = {}
for i = 1, 32 do
	table.insert(WaypointActors, CreateActor(script.Parallel.Waypoints))
end

local function WrapNumber(N: number, Max: number): number
	local zeroBasedN = N - 1
	local resultZeroBased = zeroBasedN % Max
	local resultOneBased = resultZeroBased + 1
	return resultOneBased
end

local RadiusCounter = 0
function Radius.new(InitPos:Vector2|vector, Size:number, Config:{})
	Config = Config or {}
	if typeof(InitPos) ~= "Vector2" then
		InitPos = Util.toVector2(InitPos, {"X", "Z"})
	end
	RadiusCounter += 1
	local self = {}
	local j = Janitor.new()
	self.Janitor = j
	self.RadiusID = tostring(RadiusCounter)
	self.TowerID = Config.TowerID or nil
	self.LastThreats = {} :: {Enemy}
	self.LastClose = {} :: {Enemy}
	self.Size = Size
	self.LockedTargets = {} :: {[string]: Enemy}
	self.CanLock = Config.CanLock or false
	self.TargetType = Config.TargetType or 1
	self.MaxLockedTargets = Config.MaxLockedTargets or 1
	self.pathLabels = Config.pathLabels
	self.Position = InitPos :: Vector2
	self.Actor = CreateActor(script.Parallel.Radius)
	
	Util.signalfor(self, {"Update", "Destroying", "TargetChanged"})
	
	setmetatable(self, Radius)
	
	local function Update()
		debug.profilebegin("Actor messaging")
		self.Actor:SendMessage("ProcessRadius", self.RadiusID, ST_EnemyProgress, ST_Enemies, ST_Radii)
		debug.profileend()
	end
	j:Add(self.Update:Connect(function()
		local j2 = Janitor.new()
		local EnemySpawned = false
		local DoNotRefresh = false
		j2:Add(task.defer(function()
			jTDF.EnemySpawned:Wait()
			EnemySpawned = true
		end))
		j2:Add(task.defer(function()
			self.Update:Wait()
			DoNotRefresh = true
		end))
		local function ewait(e)
			local i = 0
			repeat
				i += 1
				task.wait()
				if EnemySpawned then break end
			until i >= e
		end
			
		if not Util.IsDictEmpty(jTDF.ActiveEnemies) then
			if Util.IsDictEmpty(self.LastThreats) and Util.IsDictEmpty(self.LastClose) then
				ewait(5)
			end
			Update()
			task.wait()
		else
			jTDF.EnemySpawned:Wait()
			if DoNotRefresh then return end
			self.Update:Fire()
			return
		end
		j2:Destroy()
		if DoNotRefresh then return end
		self.Update:Fire()
	end), "Disconnect")
	
	j:Add(jTDF.EnemyKilled:Connect(function(Enemy)
		if self.LockedTargets[Enemy.EnemyID] then
			self.LockedTargets[Enemy.EnemyID] = nil
		end
	end), "Disconnect")
	jTDF.ActiveRadii[self.RadiusID] = self
	
	self:__Reconstruct()
	
	jTDF.NewRadius:Fire(self)
	
	self.Update:Fire()
	return self
end

function Radius.Resize(self:Radius, newRadius:number)
	self.Size = newRadius
	self:__Reconstruct()
end

function Radius.Move(self:Radius, newPosition:vector|Vector3|Vector2)
	if typeof(newPosition) ~= "Vector2" then
		newPosition = Util.toVector2(newPosition, {"X", "Z"})
	end
	self.Position = newPosition
	self:__Reconstruct()
end

function Radius.FromID(ID:string)
	return jTDF.ActiveRadii[ID]
end

function Radius.Destroy(self:Radius)
	if not self or not jTDF.ActiveRadii[self.RadiusID] then return end
	print("destroying radius")
	jTDF.ActiveRadii[self.RadiusID] = nil
	self:__Deconstruct()
	self.Destroying:Fire()
	self.Janitor:Destroy()
	task.defer(function()
		task.wait()
		self = nil
	end)
end

function Radius.__Reconstruct(self:Radius)
	local r = {
		Size = self.Size,
		Position = self.Position,
		CanLock = self.CanLock,
		MaxLockedTargets = self.MaxLockedTargets,
		pathLabels = self.pathLabels,
		TargetType = self.TargetType,
		LockedTargets = {}
	}
	for id, v in self.LockedTargets do
		table.insert(r.LockedTargets, id)
	end
	ST_Radii[self.RadiusID] = r
	return r
end

function Radius.__Deconstruct(self:Radius)
	print("deconstructing")
	ST_Radii[self.RadiusID] = nil
end

script.RadiusReply.Event:Connect(function(RadiusID: string, Targets: {string}, Threats, Close)
	local self = Radius.FromID(RadiusID)
	if not self then warn("self is nil!", jTDF.ActiveRadii[RadiusID], jTDF.ActiveRadii); return end
	local TargetChanged = false
	local LastTargets = self.__LastTargets or {}
	if #LastTargets ~= #Targets then
		TargetChanged = true
	else
		for i, v in Targets do
			if LastTargets[i] ~= v then
				TargetChanged = true
				break
			end
		end
	end
	
	self.LockedTargets = {}
	for _, v in Targets do
		local Enemy = jTDF.ActiveEnemies[v]
		if Enemy then
			self.LockedTargets[v] = Enemy
		end
	end
	self:__Reconstruct()
	if TargetChanged then 
		self.TargetChanged:Fire(self.__LastTargets, Targets)
	end
	self.__LastTargets = Targets
	self.LastThreats = Threats
	self.LastClose = Close
	if not Util.IsDictEmpty(self.LockedTargets) then
		local list = {}
		for i, v in Targets do
			local Enemy: Enemy = jTDF.ActiveEnemies[v]
			table.insert(list, Enemy)
		end
		local Unit = jTDF.ActiveUnits[self.TowerID]
		if not Unit then warn("bad"); return end
		local st = Unit.CurStats
		if st.CheckFunction(self, Unit) then
			jTDF.UnitShot:Fire(Unit, Targets)
			st.FireFunction(self, Unit, list)
		else
			--warn("did not pass check")
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local counter = 0
	--[[ this section updates at which waypoint enemies are currently located for tower range detection. ]]
	
	-- batch waypoints for actors to digest
	local batches = {}
	
	for EnemyID, v in ST_Enemies do
		counter += 1
		local w = WrapNumber(counter, #WaypointActors)
		batches[w] = batches[w] or {}
		batches[w][EnemyID] = v
	end
	
	for i, v in batches do
		WaypointActors[WrapNumber(i, #WaypointActors)]:SendMessage("UpdateEnemyWaypoint", v, ST_EnemyProgress)
	end
end)
script.WaypointReply.Event:Connect(function(enemyid) -- actor reply for waypoint update
	local v = jTDF.ActiveEnemies[enemyid]
	if not v then warn("not v"); return end
	local _, _, PathLength, _, DistanceCovered, Progress = Enemies.GetProgress(v, true)
	if Progress > 1 then
		ST_EnemyProgress[enemyid] = 0
		-- move to next waypoint
		v.CurrentPath = v.NextPath
		v.NextPath = Path.GetNextPath(v.pathLabel, v.CurrentPath:GetAttribute("PathID"))

		if not v.NextPath then v:Destroy(); return end

		-- start time of that specific waypoint
		v.StartTime = workspace:GetServerTimeNow() - (DistanceCovered - PathLength) / v.Speed
		v:__Reconstruct()
	end
end)

-- server types
export type Enemy = typeof(Enemies.new())
export type Unit = typeof(Units.new())
export type Radius = typeof(Radius.new())

return jTDF