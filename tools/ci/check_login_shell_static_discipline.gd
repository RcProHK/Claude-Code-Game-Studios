#!/usr/bin/env -S godot --headless --script
## CI Lint — #24 Login/Shell static discipline (story 016: AC-35a / AC-50 / AC-51).
##
## Three source greps (comment lines + trailing comments stripped before matching):
##   AC-35a — banner_stack.gd (the banner-static-discipline file, Rule 8) must contain
##            ZERO `create_tween` / `pulse` / `AudioStreamPlayer` / `.play(` (the banner is
##            static: no animation / no audio / no pulse). The legitimate animated shell
##            cross-fade lives in shell_transitions.gd and is NOT scanned. The target file
##            MUST exist — a missing file is a FAIL, never a phantom pass (no-file != no-match).
##   AC-51  — shell_formulas.gd (Formula 1/2) must contain ZERO direct Time.get_ticks_msec()
##            (a formula path reads the injected clock; a direct call = wall-clock phantom).
##   AC-50  — login_shell_coordinator.gd must never log a credential var (username/password/
##            credential/secret/passwd) into print()/push_error()/push_warning().
##
## Exit codes: 0 = pass; 1 = a violation found; 2 = internal error / required file missing.
extends SceneTree

const BANNER_STACK: String = "res://src/ui/login_shell/banner_stack.gd"
const SHELL_FORMULAS: String = "res://src/ui/login_shell/shell_formulas.gd"
const COORDINATOR: String = "res://src/autoload/login_shell_coordinator.gd"
const LINT_TAG: String = "check_login_shell_static_discipline"

## AC-35a banned tokens (banner static discipline). `.play(` is escaped for regex.
const BANNER_PATTERNS: Array[String] = [
	"create_tween", "pulse", "AudioStreamPlayer", "\\.play\\(",
]
const CLOCK_PATTERN: String = "Time\\.get_ticks_msec"
## AC-50 — a log call whose argument mentions a credential token.
const CREDENTIAL_LOG_PATTERN: String = "(print|push_error|push_warning)\\s*\\(.*(username|password|credential|secret|passwd)"


func _init() -> void:
	var errors: Array[String] = []

	# AC-35a — required file must exist (no-file != no-match).
	if not FileAccess.file_exists(BANNER_STACK):
		push_error("[%s] AC-35a target %s missing — no-file is NOT a pass" % [LINT_TAG, BANNER_STACK])
		quit(2)
		return
	for pat: String in BANNER_PATTERNS:
		_scan(BANNER_STACK, pat, "AC-35a banner-static violation", errors)
	_scan(SHELL_FORMULAS, CLOCK_PATTERN, "AC-51 formula must read injected clock, not Time.get_ticks_msec()", errors)
	_scan(COORDINATOR, CREDENTIAL_LOG_PATTERN, "AC-50 credential must never be logged", errors)

	if errors.is_empty():
		print("[%s] PASS — banner static / clock seam / credential discipline clean" % LINT_TAG)
		quit(0)
	else:
		for e: String in errors:
			push_error("[%s] %s" % [LINT_TAG, e])
		quit(1)


## Scan a file for `pattern` on non-comment code (full-line comments skipped; a trailing
## `#` comment is stripped before matching, ignoring `#` inside string literals).
func _scan(path: String, pattern: String, label: String, errors: Array[String]) -> void:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		errors.append("regex compile failed: %s" % pattern)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("cannot read %s" % path)
		return
	var line_no: int = 0
	while not f.eof_reached():
		line_no += 1
		var raw: String = f.get_line()
		if raw.strip_edges(true, false).begins_with("#"):
			continue
		var code: String = _strip_trailing_comment(raw)
		if re.search(code) != null:
			errors.append("%s:%d: %s — `%s`" % [path, line_no, label, raw.strip_edges()])
	f.close()


func _strip_trailing_comment(line: String) -> String:
	var in_single: bool = false
	var in_double: bool = false
	for k: int in line.length():
		var ch: String = line[k]
		if ch == "\"" and not in_single:
			in_double = not in_double
		elif ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "#" and not in_single and not in_double:
			return line.substr(0, k)
	return line
