# CameraController — Story 009 AC-21: persistence ban (Rule 14).
#
# Camera is derived state — no PersistenceLayer / FileAccess read or write. Static source scan.
extends GutTest

const REAL_SOURCE: String = "res://src/autoload/camera_controller.gd"


func _read_source() -> String:
	var f := FileAccess.open(ProjectSettings.globalize_path(REAL_SOURCE), FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func test_no_persistence_layer_reference() -> void:
	assert_false("PersistenceLayer" in _read_source(), "AC-21: Camera must not reference PersistenceLayer")


func test_no_file_access() -> void:
	assert_false("FileAccess" in _read_source(), "AC-21: Camera must not use FileAccess (no persisted recovery)")


func test_no_user_path() -> void:
	assert_false("user://" in _read_source(), "AC-21: Camera must not reference user:// paths")
