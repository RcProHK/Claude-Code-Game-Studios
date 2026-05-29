# WorkoutStateTracker — Autoload position 8 (#9)
#
# Status: STUB — implementation pending
# Driving GDD: design/gdd/workout-state-tracker.md (Approved 2026-05-27)
# Provides:
#   - get_dominant_ability_class() → AbilityClass (Pillar 4 day-flavor for #14)
#   - set_progress: float (Pillar 2 boss anchor pre-spawn trigger per #14 Rule 13)
#   - workout_completed signal (triggers #14 boss commit + #15 daily loot drop)
extends Node

func _ready() -> void:
	print("[WorkoutStateTracker] stub initialized — autoload pos 8; implementation pending")
