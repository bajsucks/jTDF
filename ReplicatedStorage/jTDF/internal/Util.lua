-- @ScriptType: ModuleScript
local Util = {}

local Signal = require(script.Parent.Signal)

function Util.signalfor(t:{}, ind:{string})
	for i, v in ind do
		t[v] = Signal()
	end
end

return Util
