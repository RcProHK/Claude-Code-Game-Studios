#!/usr/bin/env -S godot --headless --script
## CI Lint — AvatarRenderer sprite/animation discipline (CR-2 / CI-6 / AC-28).
##
## (1) Zero `AnimationPlayer` anywhere in #26 source — the avatar uses a hand-rolled
##     FSM over AnimatedSprite2D + SpriteFrames (Representation Map Engine API fact).
## (2) `AnimatedSprite2D.sprite_frames =` assignment only inside avatar_renderer.gd.
##
## Scan: res://src/ (recursive); avatar_renderer.gd is the only file permitted the
## sprite_frames assignment. AnimationPlayer is forbidden in any avatar_* / avatar
## renderer source.
##
## Exit codes: 0 = clean, 1 = violation, 2 = internal error.
extends SceneTree

const LINT_TAG := "check_avatar_renderer_callers"
const RENDERER := "res://src/autoload/avatar_renderer.gd"


func _init() -> void:
	var files: Array[String] = []
	for f in [RENDERER, "res://src/data/avatar_visual_state.gd",
			"res://src/data/avatar_evolution_snapshot.gd", "res://src/core/avatar_formulas.gd"]:
		if FileAccess.file_exists(f):
			files.append(f)

	var ap_re := RegEx.new()
	ap_re.compile("AnimationPlayer")
	# `.sprite_frames =` property assignment (leading dot; excludes the String field
	# `sprite_frames_resource_path =` because `_` follows `sprite_frames`, not `=`).
	var sf_re := RegEx.new()
	sf_re.compile("\\.sprite_frames\\s*=(?!=)")
	var violations: Array[String] = []
	for path: String in files:
		var file := FileAccess.open(path, FileAccess.READ)
		var i := 0
		while not file.eof_reached():
			var raw := file.get_line()
			i += 1
			if raw.strip_edges(true, false).begins_with("#"):
				continue
			if ap_re.search(raw) != null:
				violations.append("%s:%d: AnimationPlayer FORBIDDEN in #26 (use AnimatedSprite2D FSM — AC-28)" % [path, i])
			# CI-6: AnimatedSprite2D.sprite_frames assignment is permitted ONLY in avatar_renderer.gd.
			if path != RENDERER and sf_re.search(raw) != null:
				violations.append("%s:%d: AnimatedSprite2D.sprite_frames assignment only allowed in avatar_renderer.gd (AC-28)" % [path, i])
	if violations.is_empty():
		print("[%s] PASS: scanned %d #26 file(s), 0 AnimationPlayer + sprite_frames-assign violations" % [LINT_TAG, files.size()])
		quit(0)
		return
	for v: String in violations:
		printerr(v)
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
