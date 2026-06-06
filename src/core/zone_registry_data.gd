## ZoneRegistryData — #19 registry container (Story 001; EnemyRegistry precedent).
## Array[ZoneDef] (NOT a Dictionary — a duplicate-zone_id assert is physically
## untriggerable on Dictionary keys, Pass 1 godot F-6).
class_name ZoneRegistryData extends Resource


@export var zones: Array[ZoneDef] = []
