local ThreadSafe = {}

--[[
return tuple:
(curPathPos, nextPathPos, PathLength, TimeSpent, DistanceCovered, Progress)
returrn single:
(Progress)
Progress is a number 0-1 representing progress from CurrentPath to NextPath
]]
function ThreadSafe.GetProgressComponent(pos1:Vector3, pos2:Vector3, StartTime:number, Speed:number, FrozenTime:number?, ReturnTuple:boolean?): any
	local difference = 0
	if FrozenTime then
		difference = workspace:GetServerTimeNow() - FrozenTime
	end
	local PathLength = (pos1 - pos2).Magnitude
	local TimeSpent = workspace:GetServerTimeNow() - StartTime - difference
	local DistanceCovered = TimeSpent * Speed
	local Progress = DistanceCovered / PathLength
	if ReturnTuple then return pos1, pos2, PathLength, TimeSpent, DistanceCovered, Progress else return Progress end
end

--[[
return tuple:
(curPathPos, nextPathPos, PathLength, TimeSpent, DistanceCovered, Progress)
returrn single:
(Progress)
Progress is a number 0-1 representing progress from CurrentPath to NextPath
]]
function ThreadSafe.GetProgress(self, ReturnTuple:boolean?): any
	return ThreadSafe.GetProgressComponent(
		self.CurrentPath.WorldPosition,
		self.NextPath.WorldPosition,
		self.StartTime,
		self.Speed,
		self.Frozen,
		ReturnTuple
	)
end

return ThreadSafe
