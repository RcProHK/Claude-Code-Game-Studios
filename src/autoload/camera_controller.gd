# CameraController — Autoload position 13 (#7)
#
# Status: STUB — implementation pending
# Driving GDD: design/gdd/camera-system.md (Approved 2026-05-26)
# Forbidden Pattern Gateway: ALL `Camera2D.position/zoom/make_current()` MUST route through here.
#   CI lint: tools/ci/check_camera_callers.gd
extends Node

func _ready() -> void:
	print("[CameraController] stub initialized — autoload pos 13; implementation pending")
