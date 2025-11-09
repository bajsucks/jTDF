# API Reference

## Types

### CTower

!!! warning

	Objects of this type are read-only. Use the [constructor](#define)

```luau
{
	["Name"]: string, -- Visual name of the tower. Not used by jTDF
	["Upgrades"]: { -- Upgrades of the unit; When spawned, unit will have level 1
		[number]: CTowerStats -- Stats that the unit will have when it reaches that upgrade
	}
}
```

#### CTowerStats

!!! warning

	Objects of this type are read-only. Use the [constructor](#define)

```luau
{
	["Range"]: number?, -- Range of the tower, in studs
	["FireFunction"]: (self:Radius, Unit:Unit, Targets: {Enemy}) -> (),
	--[[	
			Function that fires at enemies. Here you damage the enemies and apply cooldowns. This will be the main source of logic for your tower.
			It would also make sense to fire Unit.Shot signal here, if you're using it.
			NOTE: Sometimes, when a lot of towers fire at the same enemy and it dies, it will disappear from Targets,
			and units with MaxLockedTargets = 1 will still call the fire function.
			Thus, it is recommended to use for loops to damage enemies instead of directly referencing Targets[1],
			even for towers that can only damage a single enemy at a time.
	]]
	["CheckFunction"]: (self:Unit) -> boolean,
	--[[
			Function that checks if the tower is ready to fire. Return true if tower is ready, and false if it's not.
	]]
	["RadiusConfig"]: { -- Configuration for the radius that the tower will use
		["IsPassive"]: boolean, -- Determines whether this tower has a radius. If true, properties below will be ignored.
		["CanLock"]: boolean, -- Whether the tower locks onto enemies, or grabs the first enemy in it's radius. True for lock, false for first enemy.
		["MaxLockedTargets"]: number, -- Maximum amount of targets a tower can have. Applies to both lockable and not lockable towers, despite the name.
		["TargetType"]: number, -- TargetType of this Radius.
		--[[
			Target types:
			1: First
			2: Closest (not yet implemented!)
		]]
	}
}
```

### CEnemy

!!! warning

	Objects of this type are read-only. Use the [constructor](#define_1)

```luau
{
	["Name"]: string, -- Visual name of the enemy. Not used by jTDF
	["BaseHealth"]: number, -- Health that the enemy has when it spawns
	["BaseSpeed"]: number -- Speed that the enemy has when it spawns
}
```

### Unit

!!! note

	You can add new indecies to this object if needed

```luau
{
	["CurLevel"]: number, -- Current upgrade of the tower. Defaults to 1
	["CurStats"]: CTowerStats, -- Current stats used by the tower. Not recommended to change manually. Instead, use StatEffects to change stats
	["CTowerID"]: string, -- CTower index used by the tower. Don't change

	["pathLabels"]: {string}, -- Paths that this unit can target.
	-- Warning: if 2 paths have different length, ranges with TargetType 1 will target enemies that have travelled the farthest on THEIR path!
	-- Due to this behavior, it is adviced against having enemies cross 2 different paths at the same time, although if you don't mind this, you can.

	["TowerID"]: string, -- Unique ID that this unit has. You can use it to refer to jTDF.ActiveUnits, if such need is present
	["Position"]: vector, -- Position of the unit. Note that it's a vector, not Vector3
	["Owner"]: number, -- UserID of the player that placed that tower. You can manually set this value to nil in case where a neutral tower is needed
	["Radius"]: Radius -- Radius that the unit uses
}
```

### Enemy

!!! note

	You can add new indecies to this object if needed

```luau
{
	["CEnemyID"]: string, -- CEnemy index used by the enemy. Don't change
	["Speed"]: number, -- Speed of the enemy, in studs/s. Defaults to CEnemy.BaseSpeed
	["Health"]: number, -- Current health of the enemy. When it reaches 0, if DestroyOnDeath is true, Enemy:Destroy() will be called. Defaults to CEnemy.BaseHealth
	["EnemyID"]: string, -- Unique ID that this enemy has. You can use it to refer to jTDF.ActiveEnemies, if such need is present
	["CurrentPath"]: Attachment, -- Path attachment that the enemy has already passed
	["NextPath"]: Attachment, -- Path attachment that the enemy is currently travelling to
	["StartTime"]: number, -- Time passed since CurrentPath has changed. Used for enemy position calculation
	["DestroyOnDeath"]: boolean, -- Whether :Destroy() will be called when health reaches 0
	["LastHit"]: Unit?, -- Last unit that has hit the enemy
	["pathLabel"]: string, -- Path used by the enemy. Cannot be changed.
	["Frozen"]: number? -- Determines whether the enemy is frozen. Use the Freeze and Unfreeze functions to change.
}
```

### Radius

!!! note

	You can add new indecies to this object if needed

```luau
{
	["RadiusID"]: string, -- Unique ID that this radius has. You can use it to refer to jTDF.ActiveRadii, if such need is present
	["TowerID"]: string?, -- Unique ID of the unit that this radius is bound to, if any
	["LastThreats"]: {Enemy}, -- Enemies in this radius since the last frame
	["LastClose"]: {Enemy}, -- Enemies that are within 5 studs from the border of this radius. Threats are not included in this table.
	["Size"]: number, -- Size of this radius in studs
	["LockedTargets"]: {[EnemyID]: Enemy}, -- Dictionary of enemies that this radius is currently locked onto
	["CanLock"]: boolean, -- Whether this radius locks onto enemies, or grabs the threat with best progress. True for lock, false for first enemy.
	["MaxLockedTargets"]: number, -- Maximum amount of targets this radius can have. Applies to both lockable and not lockable radii, despite the name.
	["Position"]: Vector2 -- Position of this radius, excluding height
}
```

## Signals

### .UnitPlaced
```luau
-> (Unit: Unit, Position: Vector3)
```
Fires when a new unit is created

### .UnitDestroying
```luau
-> (Unit: Unit)
```
Fires when `:Destroy()` is called on any unit, 1 frame before it expires

### .UnitShot
```luau
-> (Unit: Unit, Targets: {EnemyID})
```
Fires when a unit calls its [FireFunction](#ctowerstats)

### .UnitChanged
```luau
-> (Unit: Unit)
```
Fires when a unit is upgraded. It's functionality might be expanded in the future.

### .EnemyKilled
```luau
-> (Enemy: Enemy)
```
Fires when enemy's health drops to 0, before `:Destroy()` is called

### .EnemySpawned
```luau
-> (Enemy: Enemy)
```
Fires when a new enemy is created

### .EnemyUpdated
```luau
-> (Enemy: Enemy)
```
Fires when an enemy's stats change (e.g. Speed)

### .NewRadius
```luau
-> (Radius: Radius)
```
Fires when a new radius is created

### .RadiusDestroyed
```luau
-> (Radius: Radius)
```
Fires when `:Destroy()` is called on this radius

## Unit

### Functions

#### .Define
```luau
(ID: string?, CTower: CTower|{[CTowerID]: CTower})
```
Defines a new CTower. ID is not used when CTower is a list

#### .new

!!! note

	Some of this function's argument types are protected. If any of those arguments have an invalid type, the function will error.

	Protected arguments: Player, CTowerID, Position

```luau
(Player:Player?, CTowerID:string, Position:Vector3|vector, pathLabels: {string}?): Unit
```
Creates a new unit object. If it's CTower is not yet defined, an error will be thrown


#### :Destroy
```luau
()
```

Destroys this unit object.

`Unit.Destroying` and `jTDF.Destroying` signals are called 1 frame before this unit is destroyed

#### :Upgrade
```luau
(NewLevel)
```

Upgrades this unit. If next level doesn't have stats, upgrade will not happen, and unchanged CurLevel will be returned.

### Signals

#### .Upgraded
```luau
-> (CurUpgrade: number)
```

Fires when this unit is upgraded

#### .Destroying
```luau
-> ()
```
Fires when `:Destroy()` is called on this unit, 1 frame before it expires

## Enemy

### Functions

#### .Define
```luau
(ID:string?, CEnemy:CEnemy|{[string]: CEnemy})
```
Defines a new CEnemy. ID is not used when CEnemy is a list

#### .new

!!! note

	Some of this function's argument types are protected. If any of those arguments have an invalid type, the function will error.

	Protected arguments: CEnemyID, pathLabel

```luau
(CEnemyID: string, pathLabel:string, PathPosition:{CurrentPath: Attachment, Progress:number}?): Enemy
```
Creates a new enemy object. If it's CEnemy is not yet defined, an error will be thrown.

Optional PathPosition argument determines *where* this enemy will be spawned. Example usage of this would be mystery enemies that spawn new random enemies on death.

#### :Destroy
```luau
()
```

Destroys this enemy object.

`Enemy.Destroying` and `jTDF.EnemyKilled` signals are called 1 frame before this enemy is destroyed

#### :Damage
```luau
(Damage:number)
```

Damages this enemy

#### :ChangeSpeed
```luau
(NewSpeed:number)
```
!!! warning

	This function will error with speeds of 0 or less. In those cases use [:Freeze()](#freeze) and [:Unfreeze()](#unfreeze) respectively.

Changes speed of this enemy.

#### :Freeze
```luau
()
```
Freezes this enemy in place.

It should be noted that the original speed is not affected by this, and will be restored once this enemy is unfrozen.

If you try to freeze a frozen enemy, the function will return silently.

#### :Unfreeze
```luau
()
```
Unfreezes this enemy

It should be noted that the original speed is not affected by this, and will remain the same when unfrozen.

If you try to unfreeze an enemy that's not frozen, the function will return silently.


### Signals

#### .Destroying
```luau
-> ()
```
Fires when `:Destroy()` is called on this enemy, 1 frame before it expires

#### .GotDamaged
```luau
-> ()
```
Fires when this enemy is damaged

## Radius

### Functions

#### .new
```luau
(InitPos:Vector2|vector, Size:number, Config:{}): Radius
```
Creates a new radius

#### .FromID
```luau
(ID:string): Radius
```
Returns a radius from its ID, if such a radius exists

#### :Resize
```luau
(newRadius:number)
```
Changes size of this radius. Currently, it just changes the Radius.Size property

#### :Destroy
```luau
()
```
Destroys this radius object

### Signals

#### .Destroying
```luau
-> ()
```

Fires 1 frame before this radius is destroyed

#### .TargetChanged
```luau
-> (OldTargets:{}, NewTargets:{})
```

#### .Update

!!! warning

	This event should only be used by advanced users.
	Incorrect usage WILL lead to performance drawbacks.

```luau
-> ()
```
Forces a radius to update it's enemy list.

Unlike other signals, it is used by firing it.

Example usage of this signal would be if you know that radius has outdated enemy data, has already updated once, and now you need up-to-date enemy data THIS exact frame.

It can also be used as a tool to instantly wake up a radius from throttle, for example when an enemy teleports into this radius from a distance larger than 5 studs.