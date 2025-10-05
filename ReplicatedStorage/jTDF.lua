-- @ScriptType: ModuleScript
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
	["CEnemyID"]: string,
	["EnemyID"]: number,
	["Speed"]: number,
	["Health"]: number,
	["LastHit"]: Unit,
	["CurrentPathID"]: number,
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
	
	-- convenience
	local function GetProgressComponents(v)
		local pos1 = v.CurrentPath.WorldPosition
		local pos2 = v.NextPath.WorldPosition
		local PathLength = (pos1 - pos2).Magnitude
		local TimeSpent = workspace:GetServerTimeNow() - v.StartTime
		local DistanceCovered = TimeSpent * v.Speed
		local Progress = DistanceCovered / PathLength
		return pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress
	end
	
	-- update every single frame!!! hooray main source of lag
	RunService.RenderStepped:Connect(function()
		-- list to bulk moveto
		local Models = {}
		local CFrames = {}
		for i in enemylist do
			local v = enemylist[i] -- regular for loop value does not hold reference to the table
			local pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress = GetProgressComponents(v)
			if Progress > 1 then
				-- move to next waypoint
				v.CurrentPath = v.NextPath
				v.NextPath = GetNextPath(v.CurrentPath:GetAttribute("PathID"))
				
				if not v.NextPath then warn("Reached end!") Enemies.Kill(i) return end
				
				-- start time of that specific waypoint, because that's how server formats it
				v.StartTime = workspace:GetServerTimeNow() - (DistanceCovered - PathLength) / v.Speed
				
				-- update variables because they're fucked up now
				pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress = GetProgressComponents(v)
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
	self.Model = CTower.Model:Clone()
	self.Model.Parent = Config.TowerParent
	
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
	self.CurrentPathID = GetFirstPath():GetAttribute("PathID")
	self.StartTime = workspace:GetServerTimeNow()
	
	jTDF.EnemySpawned:Fire(self)
	
	return self
end

-- murder, but on server
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

jTDF.EnemySpawned:Connect(function(self:Enemy)
	script.Remotes.EnemySpawn:FireAllClients(self.CEnemyID, self.EnemyID, self.Speed, self.CurrentPathID, workspace:GetServerTimeNow())
end)

return jTDF
