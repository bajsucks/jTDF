-- @ScriptType: Script
--!optimize 2
--!native
--[[
	Waypoints script
	Created: 10/5/2025
	Last updated: 10/5/2025
	Author: baj (@artembon)
	Description: Parallel execution for enemy waypoint updates
]]

local actor = script:GetActor()
local CollectionService = game:GetService("CollectionService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local jtdfmodule = CollectionService:GetTagged("_JTDFMODULE")[1]

local function GetProgress(Enemy, t)
	local pos1: vector = Enemy.CurrentPath
	local pos2: vector = Enemy.NextPath
	local PathLength = (pos1 - pos2).magnitude
	local TimeSpent = t - Enemy.StartTime
	local DistanceCovered = TimeSpent * Enemy.Speed
	local Progress = DistanceCovered / PathLength
	return Progress
end
actor:BindToMessageParallel("UpdateEnemyWaypoint", function(batch:{{}})
	--debug.profilebegin("Getting SharedTable")
	--local EnemiesProgress = SharedTableRegistry:GetSharedTable("EnemiesProgress")
	--debug.profileend()
	local t = workspace:GetServerTimeNow()
	local NewProgress = {}
	for i, self in batch do
		--debug.profilebegin("Calculation")
		--local p = GetProgress(self, t)
		--debug.profileend()
		debug.profilebegin("Calculation + Table")
		local p = GetProgress(self, t)
		NewProgress[self.EnemyID] = p
		debug.profileend()
		if p >= 1 then
			jtdfmodule.WaypointReply:Fire(self.EnemyID)
		end
	end
	debug.profilebegin("Sharedtable")
	SharedTableRegistry:SetSharedTable("EnemiesProgress", SharedTable.new(NewProgress))
	debug.profileend()
end)