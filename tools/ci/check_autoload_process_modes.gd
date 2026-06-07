## CI Lint — autoload PROCESS_MODE_ALWAYS whitelist (#21 story 023, G-LM-9).
##
## ceremony_freeze (G-LM-3) pauses the SceneTree. Autoloads whose runtime work
## must SURVIVE the freeze are required to self-set PROCESS_MODE_ALWAYS in
## _ready (source-level check — the property is assigned in code, not in
## project.godot). A regression here = the LEGENDARY fanfare stutters 0.4s at
## the dopamine peak (AC-76b/AC-88).
##
## Required: audio_manager.gd / loot_reveal_coordinator.gd / screen_effects.gd
## (screen_effects's own Rule 10 selective-freeze posture predates #21 — its
## marker is the `process_mode` assignment OR PROCESS_MODE_ALWAYS reference).
##
## Exit codes: 0 = pass; 1 = a required file lost its ALWAYS marker; 2 = error.
extends SceneTree

const LINT_TAG: String = "check_autoload_process_modes"
const REQUIRED_FILES: Array[String] = [
	"res://src/autoload/audio_manager.gd",
	"res://src/autoload/loot_reveal_coordinator.gd",
	"res://src/autoload/screen_effects.gd",
]
const MARKER: String = "PROCESS_MODE_ALWAYS"


func _init() -> void:
	var errors: Array[String] = []
	for path: String in REQUIRED_FILES:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			errors.append("%s missing — cannot verify process mode" % path)
			continue
		var found: bool = false
		while not f.eof_reached():
			var line: String = f.get_line()
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.contains(MARKER):
				found = true
				break
		if not found:
			errors.append("%s: no %s marker on a code line — freeze-survival regressed (G-LM-9)" % [path, MARKER])
	if errors.is_empty():
		print("[%s] PASS — freeze-survival autoloads keep PROCESS_MODE_ALWAYS" % LINT_TAG)
		quit(0)
	else:
		for e: String in errors:
			push_error("[%s] %s" % [LINT_TAG, e])
		quit(1)
