# Fixture — legal forms that check_camera_callers.gd must NOT flag.
# Routes through CameraController API; commented banned line must not false-positive.
extends Node


func _good() -> void:
	CameraController.register_camera($Camera2D)
	CameraController.set_follow_target($Avatar)
	CameraController.request_focal(Vector2(100, 0))
	var sprite_offset := Vector2(3, 4)  # plain `.position`/`.zoom` on non-Camera2D is fine
	var _unused := sprite_offset


func _commented_bans_ignored() -> void:
	# cam.make_current()                          ← commented example, must NOT match
	# get_viewport().get_camera_2d()              ← commented example, must NOT match
	pass
