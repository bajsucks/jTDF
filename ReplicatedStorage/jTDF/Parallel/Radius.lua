-- @ScriptType: Script
--!optimize 2
--!native
--[[
	Radius parallel script
	Created: 10/6/2025
	Last updated: 10/6/2025
	Author: baj (@artembon)
	Description: Parallel execution for radius enemy detection
]]

local actor = script:GetActor()
local CollectionService = game:GetService("CollectionService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local jtdfmodule = CollectionService:GetTagged("_JTDFMODULE")[1]
local Util = require(jtdfmodule.internal.Util)

actor:BindToMessageParallel("ProcessRadius", function(self, SpecEnemyIDs: {string})
	
	-- Actor messaging is done with regular tables for sake of performance. Each dictionary index hogs a ton of bytes
	--self[1] = self.RadiusID: string
	--self[2] = self.Size: number
	--self[3] = self.Position: Vector2
	--self[4] = self.Actor: Actor
	--self[5] = self.CanLock: boolean
	--self[6] = self.MaxLockedTargets: number
	--self[7] = self.LockedTargets: {EnemyID}
	
	local Enemies = SharedTableRegistry:GetSharedTable("EnemiesSimple")
	local EnemiesProgress = SharedTableRegistry:GetSharedTable("EnemiesProgress")
	
	assert(self[4] == actor, "Wrong actor!")
	--if self.CanLock then
	--	if #self.LockedTargets >= self.MaxLockedTargets then
	--		return
	--	end
	--end
	
	local Threats = {} -- enemies that are within range
	local Close = {} -- enemies that are not within range, but in close proximity to range borders
	
	debug.profilebegin("Enemy analyze")
	-- sorts enemy to Threats, Close or none
	local function CheckEnemy(Enemy)
		local Progress = EnemiesProgress[Enemy.EnemyID]
		if not Progress then return end
		Progress = math.min(1, Progress)
		local a:Vector2 = self[3]
		local a1:Vector3 = Util.toVector3(Enemy.CurrentPath)	--
		local b1:Vector3 = Util.toVector3(Enemy.NextPath)		-- vector.lerp() is broken in the current version of Roblox Studio
		local b = a1:Lerp(b1, Progress)							-- remove these lines, and uncomment the line below once it's stable
		--local b:vector = vector.lerp(Enemy.CurrentPath, Enemy.NextPath, Progress)
		b = Util.toVector2(b, {"X", "Z"})
		local mag = (a - b).Magnitude
		if mag <= self[2] + 5 then
			if mag <= self[2] then
				table.insert(Threats, Enemy.EnemyID)
			else
				table.insert(Close, Enemy.EnemyID)
			end
		end
	end
	-- returns all targets that a tower should have, given how many targets it can handle
	local function GetTargets(n)
		-- get the first target in threats
		local function GetFirst()
			local BestPathID = -math.huge
			local BestProgress = -math.huge
			local Target
			for _, id in Threats do
				local PathID = Enemies[id].CurrentPathID
				if PathID > BestPathID then BestPathID = PathID end
			end
			for _, id in Threats do
				local PathID = Enemies[id].CurrentPathID
				local Progress = EnemiesProgress[id]
				if PathID == BestPathID then
					if Progress > BestProgress then Target = id BestProgress = Progress end
				end
			end
			return Target
		end
		if #Threats <= self[6] then return Threats end -- if there are less threats than the tower can handle, just return em all
		local Targets = {}
		if self[5] then -- if tower can lock, remove targets that are already in LockedTargets from threats
			for _, id in self[7] do
				if Threats[id] then table.insert(Targets, id) table.remove(Threats, table.find(Threats, id)) self[6] -= 1 end
			end
		end
		if self[6] < 1 then warn("bad?") return Targets end -- idk if this will ever happen, but if it does, without this the actor will implode
		for i = 1, n do
			local Target = GetFirst()
			if not Target then break end
			table.remove(Threats, table.find(Threats, Target))
			table.insert(Targets, Target)
		end
		return Targets
	end
	if SpecEnemyIDs then
		for _, v in SpecEnemyIDs do
			if not Enemies[v] then warn("no enemy") return end
			CheckEnemy(Enemies[v])
		end
	else
		for idEnemy, Enemy in Enemies do
			CheckEnemy(Enemy)
		end
	end
	local function Reply(Threats, Close)
		print("result:", Threats, Close)
		jtdfmodule.RadiusReply:Fire(self[1], GetTargets(self[6]), Threats, Close)
	end
	Reply(Threats, Close)
	debug.profileend("Enemy analyze")
end)