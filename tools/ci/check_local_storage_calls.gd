#!/usr/bin/env -S godot --headless --script
# CI Lint: window.localStorage usage detection (ADR-0003)
#
# Status: STUB — implementation pending
# Purpose: Scan src/ for any `window.localStorage` usage. FORBIDDEN per ADR-0003 forbidden pattern.
#   Must use `user://` (FileAccess / PersistenceLayer) instead.
#   Reason: ~5MB quota + requires JavaScriptBridge + not bfcache-friendly on iOS Safari.
extends SceneTree

func _init() -> void:
	push_warning("[check_local_storage_calls] STUB — not yet implemented")
	quit(0)
