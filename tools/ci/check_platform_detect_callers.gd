#!/usr/bin/env -S godot --headless --script
# CI Lint: JavaScriptBridge.eval() gateway (ADR-0001)
#
# Status: STUB — implementation pending
# Purpose: Scan src/ for raw `JavaScriptBridge.eval()` calls. FORBIDDEN outside
#   `src/autoload/platform_detect.gd`. All JS bridge calls must route through
#   PlatformDetect to centralize web export concerns + GC retention discipline.
extends SceneTree

func _init() -> void:
	push_warning("[check_platform_detect_callers] STUB — not yet implemented")
	quit(0)
