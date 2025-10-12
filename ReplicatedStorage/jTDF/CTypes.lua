-- @ScriptType: ModuleScript
local Types = {}
local Signal = require(script.Parent.internal.Signal)

export type CEnemy = {
	["Name"]: string,
	["BaseHealth"]: number,
	["BaseSpeed"]: number,
	["Model"]: Model
}

export type CTowerStats = {
	["Cost"]: number,
	["Range"]: number?, -- studs
	["Damage"]: number,
	["FireRate"]: number, -- seconds
	["Cooldown"]: boolean,
	["FireFunction"]: (self:{}, Target: {}) -> (),
	["CheckFunction"]: (self:{}) -> boolean
}

export type CTower = {
	["Name"]: string,
	["Model"]: Model,
	["Upgrades"]: {
		[number]: CTowerStats
	}
}

return Types