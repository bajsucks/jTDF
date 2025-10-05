-- @ScriptType: Script
--!optimize 2
--!native
--[[
	TowerRange script
	Created: 10/5/2025
	Last updated: 10/5/2025
	Author: baj (@artembon)
	Description: Parallel execution for unit enemy detection
]]

local actor = script:GetActor()
local CollectionService = game:GetService("CollectionService")
local jtdfmodule = CollectionService:GetTagged("_JTDFMODULE")[1]
local Util = require(jtdfmodule.internal.Util)

-- yes it's a copy of function in jtdf
-- yes I could've probably done it differently but fuck you it's easier
local function GetProgress(Enemy)
	local pos1 = Enemy.CurrentPath.WorldPosition
	local pos2 = Enemy.NextPath.WorldPosition
	local PathLength = (pos1 - pos2).Magnitude
	local TimeSpent = workspace:GetServerTimeNow() - Enemy.StartTime
	local DistanceCovered = TimeSpent * Enemy.Speed
	local Progress = DistanceCovered / PathLength
	return Progress
end


actor:BindToMessageParallel("ProcessUnit", function(self, Enemies)
	local function Reply(Threats, Close)
		jtdfmodule.TowerRangeReply:Fire(tostring(self.TowerID), Threats or {}, Close or {})
	end
	if self.Actor ~= actor then warn("wrong actor") return end
	if self.CurStats.Cooldown or (not self.CurStats.Range) then warn("cooldown or no range") return end
	if self.Debounce >= 1 then Reply() return end
	local Threats = {} -- enemies that are within range
	local Close = {} -- enemies that are not within range, but in close proximity to range borders
	local mags = {}
	debug.profilebegin("Enemy analyze")
	for idEnemy, Enemy in Enemies do
		local Progress = GetProgress(Enemy)
		Progress = math.min(1, Progress)
		local a = self.Position - Vector3.yAxis * self.Position.Y
		local b = Enemy.CurrentPath.WorldPosition:Lerp(Enemy.NextPath.WorldPosition, Progress)
		b -= Vector3.yAxis * b.Y
		local mag = (a - b).Magnitude
		if mag <= self.CurStats.Range + 5 then
			if mag <= self.CurStats.Range then table.insert(Threats, idEnemy) continue end
			table.insert(Close, idEnemy) continue
		else continue end
	end
	debug.profileend("Enemy analyze")
	Reply(Threats, Close)
end)