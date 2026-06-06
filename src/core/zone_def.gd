## ZoneDef — #19 zone identity record (Story 001).
##
## Driving GDD: design/gdd/zone-system.md Rule 1. background_scene_path is a
## String (NOT a PackedScene export — registry load must never pull a scene
## graph; #14 EnemyRegistry path-based precedent). Empty pools are the
## UNFILTERED sentinel (MVP — #14 additions are never silently filtered).
class_name ZoneDef extends Resource


@export var zone_id: StringName = &""
@export var display_name: String = ""
@export var background_scene_path: String = ""
## Empty = UNFILTERED sentinel (MVP). v0.2 narrows per zone (G-Z-2).
@export var wave_archetype_pool: Array[StringName] = []
## Empty = UNFILTERED sentinel — same semantics for the #16 boss chain.
@export var boss_pool: Array[StringName] = []
## Art-bible Layer Discipline: desaturated -30% palette variant id.
@export var world_palette_id: StringName = &""
@export var unlock_condition: ZoneUnlockCondition = null
