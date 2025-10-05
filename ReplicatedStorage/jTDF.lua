-- @ScriptType: ModuleScript
--!optimize 2
--!native
--[[
	jTDF module
	Created: 9/26/2025
	Last updated: 10/5/2025
	Author: baj (@artembon)
	Description: Tower and enemy functions
]]

-- services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- constant modules
local CTowers = require(script.CTowers)
local CEnemies = require(script.CEnemies)
local Config = require(script.Config)

-- internal modules
local Util = require(script.internal.Util)
local t = require(script.internal.t)
local Signal = require(script.internal.Signal)

-- effect functions
local Effects: {
	[string]: (Stats:Stats)->(Stats)
}={}

-- types
type CTower = CTowers.CTower
type CEnemy = CEnemies.CEnemy
type Stats = CTowers.Stats

export type Unit = {
	["CTowerID"]: string,
	["TowerID"]: number,
	["CurUpgrade"]: number,
	["CurStats"]: Stats,
	["Actor"]: Actor,
	["StatusEffects"]: {[string]: thread|boolean}, -- update documentation
	["Owner"]: number, -- userid
	["Position"]: Vector3,
	["Model"]: Model,
	["Debounce"]: number,
	["Shot"]: Signal.Signal<string>,
	["EnemyEnterRange"]: Signal.Signal<string>,
	["EnemyExitRange"]: Signal.Signal<string>,
	["StatusEffectsChanged"]: Signal.Signal<string, boolean>,
	["Upgraded"]: Signal.Signal<number>,
	["StatsChanged"]: Signal.Signal<>,
	["Destroying"]: Signal.Signal<>
}

export type Enemy = {
	["CEnemyID"]: string,
	["EnemyID"]: number,
	["Speed"]: number,
	["Health"]: number,
	["LastHit"]: Unit,
	["CurrentPath"]: Attachment,
	["NextPath"]: Attachment,
	["StartTime"]: number,
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
local ActiveUnits = {}
local ActiveEnemies = {}

-- [ Client and server functions ]

function jTDF.CheckTowerPlacement(Position:Vector3): boolean
	-- TBD
end

-- path helper functions

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
	for i, v in paths do
		local val = v:GetAttribute("PathID")
		if val > id and val < minID then minID = v:GetAttribute("PathID") nextid = v end
	end
	--print("Next path selected:", nextid and nextid:GetAttribute("PathID") or "none")
	return nextid
end

local function GetPathByID(id:number): Attachment?
	for i, v in GetPaths() do
		if v:GetAttribute("PathID") == id then return v end
	end
end

-- convenience
function Enemies.GetProgress(Enemy)
	local pos1 = Enemy.CurrentPath.WorldPosition
	local pos2 = Enemy.NextPath.WorldPosition
	local PathLength = (pos1 - pos2).Magnitude
	local TimeSpent = workspace:GetServerTimeNow() - Enemy.StartTime
	local DistanceCovered = TimeSpent * Enemy.Speed
	local Progress = DistanceCovered / PathLength
	return pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress
end


-- "Why are both client and server crammed in a single module?" you ask? Well, to put it simply, I didn't give a fuck
if RunService:IsClient() then
	
	-- [ Client functions ]
	
	local enemylist = {}
	
	function Enemies.new(CEnemyID:string, EnemyID:number, Speed:number, CurrentPathID:number, StartTime:number)
		print("spawning new enemy: ", CEnemyID)
		local Model = CEnemies[CEnemyID].Model:Clone()
		local f = workspace:FindFirstChild("Enemies")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Enemies"
			f.Parent = workspace
		end
		Model.PrimaryPart.Anchored = true
		Model.Parent = f
		local hum = Model:FindFirstChild("Humanoid")
		local Animator:Animator = hum.Animator
		
		local run = Instance.new("Animation")
		
		-- walk 95495983843351
		-- run 122021252351758
		run.AnimationId = "rbxassetid://95495983843351"
		
		local track = Animator:LoadAnimation(run):Play()
		
		enemylist[tostring(EnemyID)] = {
			CEnemyID = CEnemyID,
			Speed = Speed,
			StartTime = StartTime,
			Model = Model,
			CurrentPath = GetPathByID(CurrentPathID),
			NextPath = GetNextPath(CurrentPathID)
		}
	end
	
	-- update the darn creature and sync it with the server. Happens when speed changes
	function Enemies.Update(EnemyID:number, Speed:number, CurrentPathID:number, StartTime:number)
		local entry = enemylist[tostring(EnemyID)]
		entry.Speed = Speed
		entry.CurrentPath = GetPathByID(CurrentPathID)
		entry.NextPath = GetNextPath(CurrentPathID)
		entry.StartTime = StartTime
	end
	
	-- murder, but on client
	function Enemies.Kill(EnemyID:number) -- TODO: support for custom functions
		enemylist[tostring(EnemyID)].Model:Destroy()
		enemylist[tostring(EnemyID)] = nil
	end
	
	-- update every single frame!!! hooray main source of lag
	RunService.RenderStepped:Connect(function()
		-- list to bulk moveto
		local Models = {}
		local CFrames = {}
		for i in enemylist do
			local v = enemylist[i] -- regular for loop value does not hold reference to the table
			local pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress = Enemies.GetProgress(v)
			if Progress > 1 then
				-- move to next waypoint
				v.CurrentPath = v.NextPath
				v.NextPath = GetNextPath(v.CurrentPath:GetAttribute("PathID"))
				
				if not v.NextPath then warn("Reached end!") Enemies.Kill(i) return end
				
				-- start time of that specific waypoint, because that's how server formats it
				v.StartTime = workspace:GetServerTimeNow() - (DistanceCovered - PathLength) / v.Speed
				
				-- update variables because they're fucked up now
				pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress = Enemies.GetProgress(v)
			end
			table.insert(Models, v.Model)
			table.insert(CFrames, CFrame.new(pos1:Lerp(pos2, Progress)) * CFrame.lookAt(pos1, pos2).Rotation)
		end
		Util.BulkPivotTo(Models, CFrames, Enum.BulkMoveMode.FireCFrameChanged) -- 2x performance than for loop PivotTo()! Let that sink in
	end)
	
	script.Remotes.EnemySpawn.OnClientEvent:Connect(Enemies.new)
	script.Remotes.EnemyUpdate.OnClientEvent:Connect(Enemies.Update)
	script.Remotes.EnemyKilled.OnClientEvent:Connect(Enemies.Kill)
	
	return jTDF
end

-- [ Server functions ]

function jTDF.RegisterEffect(Effect:string, func:()->())
	-- todo
end


local function CreateActor(Script:Script)
	local Actor = Instance.new("Actor")
	local f = ServerScriptService:FindFirstChild("jTDF_Actors")
	if not f then
		f = Instance.new("Folder")
		f.Name = "jTDF_Actors"
		f.Parent = ServerScriptService
	end
	Actor.Parent = f
	local s = Script:Clone()
	s.Parent = Actor
	s.Enabled = true
	return Actor
end

-- server signals (not signalfor because intellisense)
jTDF.UnitPlaced = Signal()
jTDF.UnitDestroying = Signal()
jTDF.UnitChanged = Signal()
jTDF.EnemyKilled = Signal()
jTDF.EnemySpawned = Signal()
jTDF.EnemyUpdated = Signal()

local CheckNewUnit = t.tuple(t.instanceIsA("Player"), t.string, t.Vector3)

-- creates a new unit at position
local UnitCounter = 0
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
	UnitCounter += 1
	self.TowerID = UnitCounter
	self.CurStats.Cost = nil
	self.StatusEffects = {}
	self.Position = Position
	self.Debounce = 0
	self.Actor = CreateActor(script.Parallel.TowerRange)
	
	ActiveUnits[tostring(self.TowerID)] = self
	
	-- set signals
	Util.signalfor(self, {"Shot", "StatusEffectChanged", "Upgraded", "StatsChanged", "Destroying"})
	
	jTDF.UnitPlaced:Fire(self)
	
	return self
end

function Units:Destroy()
	task.spawn(function()
		r(self)
		self.Destroying:Fire()
		jTDF.UnitDestroying:Fire(self)
		
		task.wait()
		self.Model:Destroy()
		self.Actor:Destroy()
		ActiveUnits[tostring(self.TowerID)] = nil
		self = nil
	end)
end

function Units:UpgradeUnit()
	r(self)
	self.CurUpgrade += 1
	self.StatsChanged:Fire()
	jTDF.UnitChanged:Fire(self)
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

local EnemyCounter = 0

-- create a new enemy and place him on the Path of the Damned
function Enemies.new(CEnemyID: string)
	local CEnemy = CEnemies[CEnemyID]
	if not CEnemy then error("Provided wrong CEnemyID!") end
	local self = setmetatable({}, Enemies)
	r(self)
	self.CEnemyID = CEnemyID
	self.Speed = CEnemy.BaseSpeed
	self.Health = CEnemy.BaseHealth
	EnemyCounter += 1
	self.EnemyID = EnemyCounter
	Util.signalfor(self, {"GotDamaged", "StatsChanged", "Destroying"})
	self.CurrentPath = GetFirstPath()
	self.NextPath = GetNextPath(self.CurrentPath:GetAttribute("PathID"))
	self.StartTime = workspace:GetServerTimeNow()
	
	ActiveEnemies[tostring(self.EnemyID)] = self
	
	jTDF.EnemySpawned:Fire(self)
	
	return self
end

function Enemies:GetPosition(): Vector3
	
end

-- murder, but on server
function Enemies:Destroy()
	r(self)
	self.Destroying:Fire()
	jTDF.EnemyKilled:Fire(self)
	ActiveEnemies[tostring(self.EnemyID)] = nil
	task.defer(function()
		task.wait()
		self = nil
	end)
end

jTDF.EnemySpawned:Connect(function(self:Enemy)
	script.Remotes.EnemySpawn:FireAllClients(self.CEnemyID, self.EnemyID, self.Speed, self.CurrentPath:GetAttribute("PathID"), workspace:GetServerTimeNow())
end)

local WaypointActors: {Actor} = {}
for i = 1, 20 do
	table.insert(WaypointActors, CreateActor(script.Parallel.Waypoints))
end

local function WrapNumber(N: number, Max: number): number
	local zeroBasedN = N - 1
	local resultZeroBased = zeroBasedN % Max
	local resultOneBased = resultZeroBased + 1
	return resultOneBased
end

RunService.Heartbeat:Connect(function(dt)
	local counter = 0
	
	local e = {}
	debug.profilebegin("Table reform") -- Make enemy tables lighter for actor messaging
	for i, v in ActiveEnemies do
		e[i] = {
			EnemyID = v.EnemyID,
			CurrentPath = v.CurrentPath,
			NextPath = v.NextPath,
			StartTime = v.StartTime,
			Speed = v.Speed
		}
	end
	debug.profileend("Table reform")
	debug.profilebegin("WaypointBatching") -- batch waypoints for actors to digest
	local batches = {}
	for i, v in e do
		counter += 1
		local w = WrapNumber(counter, 20)
		batches[w] = batches[w] or {}
		table.insert(batches[w], v)
	end
	debug.profileend("WaypointBatching")
	debug.profilebegin("EnemyWaypointMessage") -- send batches to actors (expensive!)
	for i, v in batches do
		WaypointActors[WrapNumber(counter, 20)]:SendMessage("UpdateEnemyWaypoint", v)
	end
	debug.profileend("EnemyWaypointMessage")
	debug.profilebegin("ProcessUnit")
	for idUnit in ActiveUnits do
		task.spawn(function()
			local u = {}
			local Unit: Unit = ActiveUnits[idUnit]
			if Unit.Debounce then Unit.Debounce -= 1 return end
			u.TowerID = Unit.TowerID
			u.Actor = Unit.Actor
			u.CurStats = Unit.CurStats
			u.Debounce = Unit.Debounce
			u.Position = Unit.Position
			Unit.Actor:SendMessage("ProcessUnit", u, e)
		end)
	end
	debug.profileend("ProcessUnit")
end)
script.TowerRangeReply.Event:Connect(function(UnitID, Threats, Close)
	local self:Unit = ActiveUnits[tostring(UnitID)]
	if not self then warn("fake unit") return end
	--if self.Debounce >= 1 then self.Debounce -= 1 return end
	if Util.IsDictEmpty(Threats) and Util.IsDictEmpty(Close) then self.Debounce = 5 return end
end)

script.WaypointReply.Event:Connect(function(enemyid)
	debug.profilebegin("WaypointReply")
	local v = ActiveEnemies[enemyid]
	local _, _, PathLength, _, DistanceCovered, Progress = Enemies.GetProgress(v)
	if Progress > 1 then
		print("Updating path for someone")
		-- move to next waypoint
		v.CurrentPath = v.NextPath
		v.NextPath = GetNextPath(v.CurrentPath:GetAttribute("PathID"))

		if not v.NextPath then v:Destroy() return end

		-- start time of that specific waypoint, because that's how server formats it
		v.StartTime = workspace:GetServerTimeNow() - (DistanceCovered - PathLength) / v.Speed
	end
	debug.profileend("WaypointReply")
end)

jTDF.EnemySpawned:Connect(function() -- so towers that are directly next to enemy spawner can react instantly when an enemy spawns even when they sleep
	for idUnit in ActiveUnits do
		local Unit: Unit = ActiveUnits[idUnit]
		Unit.Debounce = 0
	end
end)

return jTDF