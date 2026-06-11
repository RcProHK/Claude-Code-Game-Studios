#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatVisualFeedback (#25) no per-hit runtime allocation (AC-29 / R-19).
##
## Purpose (GDD R-19 / ADR-0001):
##   The damage-number pool pre-instantiates its Labels once at boot and self-manages
##   rise+fade in _process. Per-hit allocation is forbidden:
##     - GPUParticles2D.new() — particles go through #5 play() (ADR-0001), never direct
##     - create_tween() / Tween.new() — per-label tweens orphan on recycle (WASM leak)
##     - Timer.new() — number lifetime is _process-driven, not Timer-driven
##   (Label.new() in _build_number_layer is the legal one-time boot pool — NOT matched.)
##
## Scan target: res://src/autoload/combat_visual_feedback.gd (single file ONLY).
##
## Exit codes: 0 = clean; 1 = a forbidden runtime alloc found (CI MUST fail); 2 = error.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/combat_visual_feedback.gd"
const LINT_TAG: String = "check_cvf_no_runtime_alloc"
const FORBIDDEN_PATTERNS: Array[String] = [
	"GPUParticles2D\\.new\\(",
	"create_tween\\(",
	"Tween\\.new\\(",
	"Timer\\.new\\(",
]


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_error("[%s] unreadable: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var violations: Array[Dictionary] = []
	var line_no: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		for j: int in compiled.size():
			var m := compiled[j].search(line)
			if m != null:
				violations.append({"line": line_no, "pattern": FORBIDDEN_PATTERNS[j], "snippet": stripped})

	file.close()

	if violations.is_empty():
		print("[%s] PASS: %s — 0 per-hit runtime allocations (R-19 pool discipline)" % [
			LINT_TAG, TARGET_FILE,
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: forbidden runtime alloc — %s (R-19: pre-instantiate the pool at boot, tick in _process)" % [
			TARGET_FILE, v["line"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d runtime allocation(s)." % [LINT_TAG, violations.size()])
	quit(1)
