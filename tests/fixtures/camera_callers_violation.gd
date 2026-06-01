# Fixture — banned Camera2D mutations that check_camera_callers.gd MUST flag.
# NOT production code; consumed by test_camera_ci_lint.gd only. One line per pattern.
extends Node

var cam: Camera2D


func _bad() -> void:
	(get_node("C") as Camera2D).position = Vector2.ZERO     # Camera2D.position
	(get_node("C") as Camera2D).zoom = Vector2.ONE          # Camera2D.zoom
	cam.make_current()                                      # .make_current(
	var c = get_viewport().get_camera_2d()                 # get_viewport().get_camera_2d()
	var _unused = c
