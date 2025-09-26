-- @ScriptType: ModuleScript
local Util = {}

local Signal = require(script.Parent.Signal)

function Util.sigfor(t:{}, ind:{string})
	for i, v in t do
		if i == ind[2] then
			v = Signal()
		end
	end
end

return Util
