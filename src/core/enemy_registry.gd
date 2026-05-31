# EnemyRegistry — data-driven catalogue of wave archetypes (Story 010).
#
# Driving GDD: design/gdd/enemy-director.md (Rule 12).
# Governing ADR: ADR-0007 (enum string-name keys; classification load-bearing order).
#
# Root resource saved as res://assets/data/EnemyRegistry.tres. EnemyDirector loads it
# in _ready() via the _enemy_registry DI seam (tests inject a fake). `archetypes` maps
# an archetype key (StringName: &"STRIKE" / &"CONTROL" / &"MOBILITY") to a WaveDescriptor.
class_name EnemyRegistry
extends Resource

## Archetype key (StringName) → WaveDescriptor. Exactly 3 entries (STRIKE/CONTROL/MOBILITY).
@export var archetypes: Dictionary = {}


## Return enemy_id → PackedScene mapping for spawn-pool preload (consumed by
## EnemyDirector._preload_spawn_pool). Story 010 ships the schema only — PackedScenes
## depend on enemy art/scenes (Story 012), so this returns an empty pool for now.
## Story 012 fills this by resolving each WaveDescriptor.enemy_templates id to a scene.
func get_preloaded_pool() -> Dictionary:
	return {}
