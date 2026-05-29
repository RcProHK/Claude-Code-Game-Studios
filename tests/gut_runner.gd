# GUT v7.x Headless Test Runner — invoked by CI and /smoke-check
#
# Status: STUB — full implementation pending Foundation chain step 3 (/test-setup)
# Replaces stale gdunit4_runner.gd per Foundation step 2 setup-engine decision.
# Framework: GUT (Godot Unit Testing) v7.x — see addons/gut/README.md for installation.
#
# Usage:
#   godot --headless --script tests/gut_runner.gd
#
# Foundation step 3 (/test-setup) will implement full GUT v7.x command-line API integration:
#   - res://addons/gut/gut_cmdln.gd
#   - PackedStringArray test directories: tests/unit/ + tests/integration/
#   - JUnit XML output for GitHub Actions
#   - Exit code 0 = all pass, 1 = any fail
extends SceneTree

func _init() -> void:
	var gut_cmdln_path: String = "res://addons/gut/gut_cmdln.gd"
	if not ResourceLoader.exists(gut_cmdln_path):
		push_error("[gut_runner] GUT v7.x not installed at %s. See addons/gut/README.md" % gut_cmdln_path)
		quit(1)
		return
	push_warning("[gut_runner] STUB — full CLI integration pending /test-setup (Foundation step 3)")
	quit(0)
