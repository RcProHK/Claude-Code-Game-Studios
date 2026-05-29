#!/usr/bin/env -S godot --headless --script
# CI Lint: Camera2D mutation gateway enforcement (ADR-0001)
#
# Status: STUB — implementation pending
# Purpose: Scan src/ for `Camera2D.position` / `.zoom` / `.make_current()` direct mutation.
#   FORBIDDEN outside `src/autoload/camera_controller.gd`. All callers must route through
#   CameraController API to preserve Pillar 2 frictionless feel + ADR-001 budget caps.
extends SceneTree

func _init() -> void:
	push_warning("[check_camera_callers] STUB — not yet implemented")
	quit(0)
