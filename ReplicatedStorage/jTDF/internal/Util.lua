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

function Util.IsDictEmpty(dict:{[any]: any}): boolean
	for i in dict do
		return false
	end
	return true
end

function Util.SpawnFolder(n:string, p:Instance)
	local f = p:FindFirstChild(n)
	if not f then
		f = Instance.new("Folder")
		f.Name = n
		f.Parent = p
	end
	return f
end

-- converts a Vector3 to a vector. If a vector is passed, it will be returned with no changes.
function Util.tovector(v:Vector3): vector
	if type(v) == "vector" then return v end
	return vector.create(v.X, v.Y, v.Z)
end
-- converts a vector to a Vector3. If a Vector3 is passed, it will be returned with no changes.
function Util.toVector3(v:vector): Vector3
	if typeof(v) == "Vector3" then return v end
	return Vector3.new(v.x, v.y, v.z)
end

function Util.toVector2(v:Vector3|vector, preserve:{[number]: "X"|"Y"|"Z"})
	local x, y = v[preserve[1]], v[preserve[2]]
	return Vector2.new(x, y)
end


return Util
