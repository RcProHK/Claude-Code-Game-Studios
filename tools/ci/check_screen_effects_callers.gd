#!/usr/bin/env -S godot --headless --script
# CI Lint: Camera2D.offset mutation gateway (ADR-0001)
#
# Status: STUB — implementation pending
# Purpose: Scan src/ for `Camera2D.offset` direct mutation. FORBIDDEN outside
#   `src/autoload/screen_effects.gd`. Screen shake must use shader uniform path,
#   NOT direct offset assignment (preserves Pillar 2 frame-budget integrity).
extends SceneTree

func _init() -> void:
	push_warning("[check_screen_effects_callers] STUB — not yet implemented")
	quit(0)
