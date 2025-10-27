local Path = {}
local LastValues = {}

local CollectionService = game:GetService("CollectionService")

local t = require(script.Parent.internal.t)

-- just gives you all path attachments
function Path.GetPaths(pathLabel:string): {[number]: Attachment}
	assert(t.string(pathLabel))
	local p = {}
	for _, v in CollectionService:GetTagged("EnemyPath") do
		if v:GetAttribute("pathLabel") == pathLabel then table.insert(p, v) end
	end
	return p
end

-- get LastLevels template
local function LVTemplate()
	return {NextPath = {}, PreviousPath = {}, ByID = {}}
end

-- Clear LastValues cache
function Path.ClearCache()
	LastValues = {}
end
-- Fetches first path. Results are cached
function Path.GetFirstPath(pathLabel:string): Attachment?
	assert(t.string(pathLabel))
	LastValues[pathLabel] = LastValues[pathLabel] or LVTemplate()
	local cached = LastValues[pathLabel].FirstPath
	if cached then return cached end
	local minID = math.huge
	for i, v in Path.GetPaths(pathLabel) do
		if v:GetAttribute("PathID") < minID then minID = v:GetAttribute("PathID"); LastValues[pathLabel].FirstPath = v end
	end
	return LastValues[pathLabel].FirstPath
end

-- Fetches last path. Results are cached
function Path.GetLastPath(pathLabel:string): Attachment?
	assert(t.string(pathLabel))
	LastValues[pathLabel] = LastValues[pathLabel] or LVTemplate()
	local cached = LastValues[pathLabel].LastPath
	if cached then return cached end
	local minID = -math.huge
	for i, v in Path.GetPaths(pathLabel) do
		if v:GetAttribute("PathID") > minID then minID = v:GetAttribute("PathID"); LastValues[pathLabel].LastPath = v end
	end
	return LastValues[pathLabel].LastPath
end

-- Fetches next path of an ID. Results are cached. If there is no next path, returns nil
function Path.GetNextPath(pathLabel:string, id:number|string): Attachment?
	assert(t.string(pathLabel))
	LastValues[pathLabel] = LastValues[pathLabel] or LVTemplate()
	local cached = LastValues[pathLabel].NextPath[tostring(id)]
	if cached then return cached end
	local minID = math.huge
	local nextid
	local paths = Path.GetPaths(pathLabel)
	for i, v in paths do
		local val = v:GetAttribute("PathID")
		if val > id and val < minID then minID = val; nextid = v end
	end
	LastValues[pathLabel].NextPath[tostring(id)] = nextid
	return nextid
end

-- Fetches previous path of an ID. Results are cached. If there is no previous path, returns nil
function Path.GetPreviousPath(pathLabel:string, id:number|string): Attachment?
	assert(t.string(pathLabel))
	LastValues[pathLabel] = LastValues[pathLabel] or LVTemplate()
	local cached = LastValues[pathLabel].PreviousPath[tostring(id)]
	if cached then return cached end
	local maxID = -math.huge
	local previd
	local paths = Path.GetPaths(pathLabel)
	for i, v in paths do
		local val = v:GetAttribute("PathID")
		if val > maxID and val < id then maxID = val; previd = v end
	end
	LastValues[pathLabel].PreviousPath[tostring(id)] = previd
	return previd
end

-- Returns a path with a certain pathID
function Path.GetPathByID(pathLabel:string, id:number|string): Attachment?
	assert(t.string(pathLabel))
	LastValues[pathLabel] = LastValues[pathLabel] or LVTemplate()
	local cached = LastValues[pathLabel].ByID[tostring(id)]
	if cached then return cached end
	for i, v in Path.GetPaths(pathLabel) do
		if v:GetAttribute("PathID") == id then LastValues[pathLabel].ByID[tostring(id)] = v; return v end
	end
	return
end

return Path
