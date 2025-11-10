--!optimize 2
--!native
--[[
	Radius parallel script
	Author: baj (@artembon)
	Description: Parallel execution for radius enemy detection
]]

local actor = script:GetActor()
local CollectionService = game:GetService("CollectionService")
local jtdfmodule = CollectionService:GetTagged("_JTDFMODULE")[1]
local Util = require(jtdfmodule.internal.Util)

-- sorts the enemy to threats and close tables
local function CheckEnemy(self, EnemyID:string, Enemy, Threats:{}, Close:{}, ST_EnemyProgress:SharedTable)
	if self.pathLabels and not table.find(self.pathLabels, Enemy.pathLabel) then return end
	local Progress: number? = ST_EnemyProgress[EnemyID]
	if not Progress then return end
	Progress = math.min(1, Progress)
	local a:Vector2 = self.Position
	local b:vector = vector.lerp(Enemy.CurrentPathPos, Enemy.NextPathPos, Progress) -- could still be faulty
	b = Util.toVector2(b, {"X", "Z"})
	local mag = (a - b).Magnitude
	if mag <= self.Size + 4 then
		if mag <= self.Size then
			table.insert(Threats, EnemyID)
		else
			table.insert(Close, EnemyID)
		end
	end
end

-- get all enemies that the tower should shoot at; main radius logic is here
local function GetTargets(self, Threats:{}, ST_EnemyProgress:SharedTable, ST_Enemies:SharedTable)
	local Targets: {[number]: string} = {} -- enemies that the tower should shoot at

	if #Threats <= self.MaxLockedTargets then return Threats end -- if there are less threats than the tower can handle, just return em all

	if self.CanLock then -- if tower can lock, put targets that are in threats and in lockedtargets to targets so they stay locked.
		for _, id in self.LockedTargets do
			local f = table.find(Threats, id)
			if f then
				table.insert(Targets, id)
				if #Targets >= self.MaxLockedTargets then
					return Targets
				end
			end
		end
	end

	if self.TargetType == 1 then -- TargetType First
		for i = #Targets + 1, self.MaxLockedTargets do
			local Target = Util.__GetFirst(ST_Enemies, ST_EnemyProgress, Threats, Targets)
			if not Target then warn("something broke again in jtdf *internal scream*"); break end
			table.insert(Targets, Target)
		end
	elseif self.TargetType == 2 then -- TargetType closest
		-- TODO
	end
	return Targets
end

actor:BindToMessageParallel("ProcessRadius", function(RadiusID:string, ST_EnemyProgress:SharedTable, ST_Enemies:SharedTable, ST_Radii:SharedTable)
	local self = ST_Radii[RadiusID]
	if not self then warn("this"); return end
	
	local Threats: {[number]: string} = {} -- enemies that are within range
	local Close: {[number]: string} = {} -- enemies that are not within range, but in close proximity to range borders
	
	debug.profilebegin("Enemy analyze")
	-- returns all targets out of threats
	for EnemyID, Enemy in ST_Enemies do -- fill up threats and close tables
		CheckEnemy(self, EnemyID, Enemy, Threats, Close, ST_EnemyProgress)
	end
	local Targets = GetTargets(self, Threats, ST_EnemyProgress, ST_Enemies)
	jtdfmodule.RadiusReply:Fire(RadiusID, Targets, Threats, Close)
	debug.profileend()
end)