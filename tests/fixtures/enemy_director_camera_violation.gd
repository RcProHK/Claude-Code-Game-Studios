# EnemyDirector CI Lint — Camera Violation Fixture (Story 004 AC-05)
# ci:violation-fixture — direct Camera2D mutation outside camera_controller.gd
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# ACTIVE violation (AC-05): Camera2D.position mutation
func _bad_camera_position() -> void:
	$Camera2D.position = Vector2(100, 50)  # ci:violation-fixture — forbidden position mutation

# ACTIVE violation (AC-05): Camera2D.zoom mutation
func _bad_camera_zoom() -> void:
	$Camera2D.zoom = Vector2(1.5, 1.5)  # ci:violation-fixture — forbidden zoom mutation

# ACTIVE violation (AC-05): Camera2D.make_current()
func _bad_camera_activate() -> void:
	$Camera2D.make_current()  # ci:violation-fixture — forbidden make_current outside controller
