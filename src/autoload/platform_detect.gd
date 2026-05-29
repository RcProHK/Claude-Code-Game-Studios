# PlatformDetect — Autoload position 3
#
# Status: STUB — implementation pending
# Governing ADR: ADR-0001 Web Export Budget Caps (mobile vs desktop GPU/CPU tier detection)
# Forbidden Pattern Gateway: ALL `JavaScriptBridge.eval()` calls MUST route through this autoload.
#   CI lint: tools/ci/check_platform_detect_callers.gd
extends Node

func _ready() -> void:
	print("[PlatformDetect] stub initialized — autoload pos 3; implementation pending")
