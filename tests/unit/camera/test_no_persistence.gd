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


## AC-21 — AMENDED by #22 G-CS-2 (story 013, 2026-06-07):blanket ban 係
## SettingsManager 時代設計;consumer-self-read convention(#22 Rule 29 +
## camera-system.md L697 erratum)下,唯一允許 touchpoint = read-only boot
## seam(_boot_read_motion_reduction)。Ban 本意保留:#7 永不 WRITE persistence。
## (#6 AC-22 同款 scoped amendment — gateway-lint owner-exempt 先例。)
func test_persistence_touchpoint_is_readonly_boot_seam_only() -> void:
	var src := _read_source()
	assert_false("_persistence.write" in src, "AC-21 本意:零 persistence write")
	assert_false("PersistenceLayer.write" in src, "AC-21 本意:零 persistence write(autoload 直呼)")
	var allowed_markers: Array[String] = ["G-CS-2", "read", "seam", "/root/PersistenceLayer"]
	for line in src.split("\n"):
		if not ("PersistenceLayer" in line):
			continue
		var ok := false
		for m in allowed_markers:
			if m in line:
				ok = true
				break
		assert_true(ok,
			"AC-21(G-CS-2 amended): PersistenceLayer 只准出現喺 read-only boot seam 行: "
			+ line.strip_edges())


func test_no_file_access() -> void:
	assert_false("FileAccess" in _read_source(), "AC-21: Camera must not use FileAccess (no persisted recovery)")


func test_no_user_path() -> void:
	assert_false("user://" in _read_source(), "AC-21: Camera must not reference user:// paths")
