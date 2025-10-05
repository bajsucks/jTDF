-- @ScriptType: ModuleScript
--[[
	Util module
	Created: 9/26/2025
	Last updated: 10/5/2025
	Author: baj (@artembon)
	Description: Utility functions for jTDF
]]
local Util = {}

local Signal = require(script.Parent.Signal)

function Util.signalfor(t:{}, ind:{string})
	for i, v in ind do
		t[v] = Signal()
	end
end


function Util.BulkPivotTo(models:{PVInstance}, CFrames:{CFrame}, mode:Enum.BulkMoveMode)
	local newCFrames = {}
	local newModels = {}
	for i, v in models do
		local pivotOffset = v:GetPivot():Inverse() * v.PrimaryPart.CFrame
		table.insert(newModels, v.PrimaryPart)
		table.insert(newCFrames, CFrames[i] * pivotOffset)
	end
	workspace:BulkMoveTo(newModels, newCFrames, mode)
end


return Util
