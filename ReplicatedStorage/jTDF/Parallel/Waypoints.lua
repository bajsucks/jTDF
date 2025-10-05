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
local jtdfmodule = CollectionService:GetTagged("_JTDFMODULE")[1]

local function GetProgress(Enemy)
	local pos1 = Enemy.CurrentPath.WorldPosition
	local pos2 = Enemy.NextPath.WorldPosition
	local PathLength = (pos1 - pos2).Magnitude
	local TimeSpent = workspace:GetServerTimeNow() - Enemy.StartTime
	local DistanceCovered = TimeSpent * Enemy.Speed
	local Progress = DistanceCovered / PathLength
	return Progress
end
actor:BindToMessageParallel("UpdateEnemyWaypoint", function(batch:{{}})
	for i, self in batch do
		if GetProgress(self) >= 1 then
			jtdfmodule.WaypointReply:Fire(tostring(self.EnemyID))
		end
	end
end)