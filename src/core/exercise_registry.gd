## ExerciseRegistry — authoring-time container Resource for the exercise→class table.
##
## Governing story : #10 Story 001 (Registry schema + core exercise lookup)
## Governing ADRs  : ADR-0007 (AbilityClass enum convention),
##                   ADR-0003 (no per-player persistence — static config)
##
## Loaded from res://assets/data/exercise_registry.tres at boot by ExerciseClassMapping.
## After boot, ExerciseClassMapping._build_lookup() flattens `entries` into internal
## Dictionaries. Runtime lookups never access this Resource again.
##
## File path convention (GDD Pass 2 RECOMMENDED): res://assets/data/exercise_registry.tres
class_name ExerciseRegistry
extends Resource

## All exercise entries. Order is significant: first-listed entry wins on duplicate
## exercise_id (boot validation); first-listed alias wins on alias collision (Story 004).
@export var entries: Array[ExerciseEntry] = []
