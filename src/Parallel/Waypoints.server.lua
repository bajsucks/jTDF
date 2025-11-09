--!optimize 2
--!native
--[[
	Waypoints script
	Author: baj (@artembon)
	Description: Parallel execution for enemy waypoint updates
]]

local actor = script:GetActor()
local CollectionService = game:GetService("CollectionService")
local jtdfmodule = CollectionService:GetTagged("_JTDFMODULE")[1]

local ThreadSafe = require(game.ReplicatedStorage.jTDF.ThreadSafe) -- TODO: change to jtdfmodule

actor:BindToMessageParallel("UpdateEnemyWaypoint", function(batch:{{}}, ST_EnemyProgress)
	for EnemyID:string, self in batch do
		debug.profilebegin("Calculation")
		local p = ThreadSafe.GetProgressComponent(self.CurrentPathPos, self.NextPathPos, self.StartTime, self.Speed, self.Frozen)
		debug.profileend()
		if p >= 1 then
			jtdfmodule.WaypointReply:Fire(EnemyID)
		else
			ST_EnemyProgress[EnemyID] = p
		end
	end
end)