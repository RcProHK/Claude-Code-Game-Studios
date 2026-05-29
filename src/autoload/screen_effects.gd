# ScreenEffects — Autoload position 14 (#6)
#
# Status: STUB — implementation pending
# Driving GDD: design/gdd/screen-effects-system.md (Approved 2026-05-26)
# Forbidden Pattern Gateway: ALL `Camera2D.offset` mutation (shake) MUST route through here
# via shader uniform path (NOT direct offset assignment).
#   CI lint: tools/ci/check_screen_effects_callers.gd
extends Node

func _ready() -> void:
	print("[ScreenEffects] stub initialized — autoload pos 14; implementation pending")
