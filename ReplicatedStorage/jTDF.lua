-- @ScriptType: ModuleScript
--!optimize 2
--!native
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 10/11/2025
	Author: baj (@artembon)
	Description: Tower and enemy functions
]]

-- services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")

-- constant modules
local CTowers = {}
local CEnemies = {}
local Config = require(script.Config)

-- internal modules
local Util = require(script.internal.Util)
local t = require(script.internal.t)
local Signal = require(script.internal.Signal)
local Janitor = require(script.internal.Janitor)

-- effect functions
local Effects: {
	[string]: (Stats:Stats)->(Stats)
}={}

-- types
local ctypes = require(script.CTypes)
export type CTower = ctypes.CTower
export type CEnemy = ctypes.CEnemy
export type CTowerStats = ctypes.CTowerStats

local jTDF = {Units = {}, Enemies = {}, Radius = {}, Path = {}}
local Units, Enemies, Radius, Path = jTDF.Units, jTDF.Enemies, jTDF.Radius, jTDF.Path
Units.__index, Enemies.__index, Radius.__index, Path.__index = Units, Enemies, Radius, Path


jTDF.ActiveUnits = {}
jTDF.ActiveEnemies = {}
jTDF.ActiveRadii = {}

function jTDF.GetUnits() return jTDF.ActiveUnits end
function jTDF.GetEnemies() return jTDF.ActiveEnemies end
function jTDF.GetRadii() return jTDF.ActiveRadii end


local CheckUnit = t.interface({
	CurUpgrade = t.number,
	CurStats = t.table,
	StatusEffects = t.table,
	Owner = t.number,
	Position = t.vector
})

-- [ Client and server functions ]

-- path helper functions

-- just gives you all path attachments
function Path.GetPaths(): {[number]: Attachment}
	return CollectionService:GetTagged("EnemyPath")
end

local LastValues = {NextPath = {}, PreviousPath = {}, ByID = {}}

-- Fetches first path. Results are cached
function Path.GetFirstPath(): Attachment?
	local cached = LastValues.FirstPath
	if cached then return cached end
	local minID = math.huge
	for i, v in Path.GetPaths() do
		if v:GetAttribute("PathID") < minID then minID = v:GetAttribute("PathID") LastValues.FirstPath = v end
	end
	return LastValues.FirstPath
end

-- Fetches last path. Results are cached
function Path.GetLastPath(): Attachment?
	local cached = LastValues.LastPath
	if cached then return cached end
	local minID = -math.huge
	for i, v in Path.GetPaths() do
		if v:GetAttribute("PathID") > minID then minID = v:GetAttribute("PathID") LastValues.LastPath = v end
	end
	return LastValues.LastPath
end

-- Fetches next path of an ID. Results are cached. If there is no next path, returns nil
function Path.GetNextPath(id:number|string): Attachment?
	local cached = LastValues.NextPath[id]
	if cached then return cached end
	local minID = math.huge
	local nextid
	local paths = Path.GetPaths()
	for i, v in paths do
		local val = v:GetAttribute("PathID")
		if val > id and val < minID then minID = val nextid = v end
	end
	LastValues.NextPath[tostring(id)] = nextid
	return nextid
end

-- Fetches previous path of an ID. Results are cached. If there is no previous path, returns nil
function Path.GetPreviousPath(id:number|string): Attachment?
	local cached = LastValues.PreviousPath[tostring(id)]
	if cached then return cached end
	local maxID = -math.huge
	local previd
	local paths = Path.GetPaths()
	for i, v in paths do
		local val = v:GetAttribute("PathID")
		if val > maxID and val < id then maxID = val previd = v end
	end
	LastValues.PreviousPath[tostring(id)] = previd
	return previd
end

function Path.GetPathByID(id:number|string): Attachment?
	local cached = LastValues.ByID[tostring(id)]
	if cached then return cached end
	for i, v in Path.GetPaths() do
		if v:GetAttribute("PathID") == id then LastValues.ByID[tostring(id)] = v return v end
	end
end

--[[
Warning: kinda expensive math!
returns tuple:
(curPathPos, nextPathPos, PathLength, TimeSpent, DistanceCovered, Progress)
Progress is a number 0-1 representing progress from CurrentPath to NextPath
]]
function Enemies.GetProgress(self:Enemy): (Vector3, Vector3, number, number, number, number)
	local pos1 = self.CurrentPath.WorldPosition
	local pos2 = self.NextPath.WorldPosition
	local PathLength = (pos1 - pos2).Magnitude
	local TimeSpent = workspace:GetServerTimeNow() - self.StartTime
	local DistanceCovered = TimeSpent * self.Speed
	local Progress = DistanceCovered / PathLength
	return pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress
end
--[[
Warning: kinda expensive math!
Returns world position of an enemy
]]
function Enemies.GetWorldPos(self:Enemy): vector
	local a, b, _, _, _, Progress = Enemies.GetProgress(self)
	return a:Lerp(b, Progress)
end


if RunService:IsClient() then return jTDF end

-- [ Server functions ]

function jTDF.RegisterEffect(Effect:string, func:()->())
	-- todo
end


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
	jTDF.EnemyKilled = Signal()
	jTDF.EnemySpawned = Signal()
	jTDF.EnemyUpdated = Signal()
	jTDF.EnemyOvertaken = Signal()
	jTDF.NewRadius = Signal()
	jTDF.RadiusDestroyed = Signal()
end
local CheckNewUnit = t.tuple(t.instanceIsA("Player"), t.string, t.vector)

-- creates a new unit at position
local UnitCounter = 0
function Units.new(Player:Player, CTowerID:string, Position:Vector3|vector)
	assert(CheckNewUnit(Player, CTowerID, Position))
	local CTower: CTower = CTowers[CTowerID]
	if not CTower then error("Provided CTowerID is not yet defined!") end

	local userid = Player.UserId
	assert(userid, "very weird")

	UnitCounter += 1
	
	local self = {}

	self.CurUpgrade = 1
	self.CurStats = CTower.Upgrades[1]
	self.CTowerID = CTowerID
	self.TowerID = tostring(UnitCounter)
	self.Position = Util.tovector(Position) :: vector
	self.StatusEffects = {} :: {[string]: thread|boolean}
	self.Owner = userid
	jTDF.ActiveUnits[self.TowerID] = self
	self.CurStats.RadiusConfig.TowerID = self.TowerID
	self.Radius = Radius.new(Position, self.CurStats.Range, self.CurStats.RadiusConfig)
	
	setmetatable(self, Units)

	-- set signals
	Util.signalfor(self, {"Shot", "StatusEffectChanged", "Upgraded", "StatsChanged", "Destroying"})
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

		task.wait()
		self.Model:Destroy()
		jTDF.ActiveUnits[self.TowerID] = nil
		self = nil
	end)
end

function Units.UpgradeUnit(self:Unit)
	self.CurUpgrade += 1
	self.StatsChanged:Fire()
	jTDF.UnitChanged:Fire(self)
	-- TBD
end

local ef = t.tuple(t.string, t.optional(t.number))

-- add effect
function Units.Effect(self:Unit, Effect:string, duration:number?)
	assert(ef(Effect, duration))
	if duration then self.StatusEffects[Effect] = task.delay(duration, function()
			self.StatusEffects[Effect] = nil
		end)
	else
		self.StatusEffects[Effect] = true
	end
end

-- clears a specified status effect
function Units.ClearEffect(self:Unit, Effect:string)
	local cor = self.StatusEffects[Effect]
	if not cor then return end

	if cor == true then self.StatusEffects[Effect] = nil return end

	if typeof(cor) == "thread" then
		coroutine.close(cor)
	else
		print("shady sh") -- shady shit
	end
	return
end

-- helper function to clear effects
local function milk(self:Unit)
	for i, v in self.StatusEffects do
		if v == true then continue end

		if typeof(v) == "thread" then
			coroutine.close(self.StatusEffects[i])
		else
			print("shady sh") -- shady shit
		end
	end
end

-- clears all status effects, except permanent
function Units.Milk(self:Unit)
	milk(self)
	self.StatusEffectsChanged:Fire()
end

-- clears all status effects, including permanent
function Units.SuperMilk(self:Unit)
	milk(self)
	self.StatusEffects = {}
	self.StatusEffectsChanged:Fire()
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
function Enemies.new(CEnemyID: string)
	local CEnemy = CEnemies[CEnemyID]
	if not CEnemy then error("Provided wrong CEnemyID!") end
	EnemyCounter += 1
	
	local self = {}
	
	self.CEnemyID = CEnemyID
	self.Speed = CEnemy.BaseSpeed
	self.Health = CEnemy.BaseHealth
	self.EnemyID = tostring(EnemyCounter)
	self.CurrentPath = Path.GetFirstPath()
	self.NextPath = Path.GetNextPath(self.CurrentPath:GetAttribute("PathID"))
	self.StartTime = workspace:GetServerTimeNow()
	self.DestroyOnDeath = true
	self.LastHit = nil :: Unit?
	
	Util.signalfor(self, {"GotDamaged", "StatsChanged", "Destroying"})
	
	setmetatable(self, Enemies)

	jTDF.ActiveEnemies[self.EnemyID] = self

	jTDF.EnemySpawned:Fire(self)

	return self
end

local EnemiesProgress = SharedTable.new()
SharedTableRegistry:SetSharedTable("EnemiesProgress", EnemiesProgress)

-- murder, but on server
function Enemies.Destroy(self:Enemy)
	self.Destroying:Fire()
	jTDF.EnemyKilled:Fire(self)
	jTDF.ActiveEnemies[self.EnemyID] = nil
	EnemiesProgress[self.EnemyID] = nil
	task.defer(function()
		task.wait()
		self = nil
	end)
end

function Enemies.Damage(self:Enemy, Damage:number, WhoDamaged:Unit?)
	self.Health = math.max(0, self.Health - Damage)
	self.GotDamaged:Fire()
	jTDF.EnemyUpdated:Fire(self)
	
	if WhoDamaged then self.LastHit = WhoDamaged end
	
	if self.Health == 0 and self.DestroyOnDeath then
		self:Destroy()
	end
end

local WaypointActors: {Actor} = {}
for i = 1, 1 do
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
	self.MaxLockedTargets = Config.MaxLockedTargets or 1
	self.Position = InitPos :: Vector2
	self.Debounce = 0 -- do I need this?
	self.Actor = CreateActor(script.Parallel.Radius)
	
	Util.signalfor(self, {"Update", "TargetChanged", "Destroying"})
	
	setmetatable(self, Radius)
	
	local function Update(arg)
		local r = {} -- TODO: user regula tables instead of dictionaries
		r[1] = self.RadiusID
		r[2] = self.Size
		r[3] = self.Position
		r[4] = self.Actor
		r[5] = self.CanLock
		r[6] = self.MaxLockedTargets
		r[7] = {}
		for id, v in self.LockedTargets do
			table.insert(r[7], id)
		end
		debug.profilebegin("Actor messaging")
		self.Actor:SendMessage("ProcessRadius", r, arg)
		debug.profileend()
	end
	j:Add(self.Update:Connect(function()
		local EnemySpawned = false
		local c = task.defer(function()
			jTDF.EnemySpawned:Wait()
			EnemySpawned = true
		end)
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
			
			
			-- TODO: remove currenttarget and whip up an alternative that works with LockedTargets
			
			
			
			--if self.MaxLockedTargets <= #self.LastThreats then
			--	print("sending a table of", self.LastThreats)
			--	Update(self.LastThreats)
			--else
				Update()
			--end
			task.wait()
		else
			if c then task.cancel(c) end
			jTDF.EnemySpawned:Wait()
		end
		if c then task.cancel(c) end
		self.Update:Fire()
	end), "Disconnect")
	--j:Add(self.TargetChanged:Connect(function(TargetID)
	--	--print("New target: ", TargetID)
	--end), "Disconnect")
	j:Add(jTDF.EnemyKilled:Connect(function(Enemy)
		if self.LockedTargets[Enemy.EnemyID] then
			self.LockedTargets[Enemy.EnemyID] = nil
			self.TargetChanged:Fire()
		end
	end), "Disconnect")
	
	jTDF.ActiveRadii[self.RadiusID] = self
	
	jTDF.NewRadius:Fire(self)
	
	self.Update:Fire()
	return self
end

function Radius.Resize(self:Radius, newRadius:number)
	self.Size = newRadius
end

function Radius.FromID(ID:string)
	return jTDF.ActiveRadii[ID]
end

function Radius.Destroy(self:Radius)
	jTDF.ActiveRadii[self.RadiusID] = nil
	self.Destroying:Fire()
	self.Janitor:Destroy()
	task.defer(function()
		task.wait()
		self = nil
	end)
end

script.RadiusReply.Event:Connect(function(RadiusID: number|string, Targets: {string}, Threats, Close)
	local self = Radius.FromID(RadiusID)
	self.LockedTargets = Targets
	self.LastThreats = Threats
	self.LastClose = Close
	if not Util.IsDictEmpty(self.LockedTargets) then
		local list = {}
		for i, v in Targets do
			local Enemy: Enemy = jTDF.ActiveEnemies[v]
			table.insert(list, Enemy)
		end
		local Unit = jTDF.ActiveUnits[self.TowerID]
		if not Unit then warn("bad") return end
		local st = Unit.CurStats
		if st.CheckFunction(Unit) then
			jTDF.UnitShot:Fire(Unit, Targets)
			st.FireFunction(Unit, list)
		end
	end
end)

local EnemiesSimple = SharedTable.new()
SharedTableRegistry:SetSharedTable("EnemiesSimple", EnemiesSimple)

RunService.Heartbeat:Connect(function(dt)
	local counter = 0
	
	--[[ this section updates at which waypoint enemies are currently located for tower range detection. ]]
	-- Make enemy tables lighter for actor messaging
	local newt = {}
	for i, v in jTDF.ActiveEnemies do
		newt[i] = {
			EnemyID = v.EnemyID, -- u16
			CurrentPath = Util.tovector(v.CurrentPath.WorldPosition), --u32*3
			CurrentPathID = v.CurrentPath:GetAttribute("PathID"), --u8
			NextPath = Util.tovector(v.NextPath.WorldPosition), --u32*3
			StartTime = v.StartTime, --u32
			Speed = v.Speed, -- u8
		}
	end
	newt = SharedTable.new(newt)
	SharedTableRegistry:SetSharedTable("EnemiesSimple", newt)
	-- batch waypoints for actors to digest
	local batches = {}
	for _, v in newt do
		counter += 1
		local w = WrapNumber(counter, #WaypointActors)
		batches[w] = batches[w] or {}
		table.insert(batches[w], v)
	end
	
	for i, v in batches do
		WaypointActors[WrapNumber(i, #WaypointActors)]:SendMessage("UpdateEnemyWaypoint", v)
	end
end)

script.WaypointReply.Event:Connect(function(enemyid) -- actor reply for waypoint update
	local v = jTDF.ActiveEnemies[enemyid]
	print(v)
	local _, _, PathLength, _, DistanceCovered, Progress = Enemies.GetProgress(v)
	if Progress > 1 then
		-- move to next waypoint
		v.CurrentPath = v.NextPath
		v.NextPath = Path.GetNextPath(v.CurrentPath:GetAttribute("PathID"))

		if not v.NextPath then v:Destroy() return end

		-- start time of that specific waypoint, because that's how server formats it
		v.StartTime = workspace:GetServerTimeNow() - (DistanceCovered - PathLength) / v.Speed
	end
end)

export type Enemy = typeof(Enemies.new())
export type Unit = typeof(Units.new())
export type Radius = typeof(Radius.new())

return jTDF