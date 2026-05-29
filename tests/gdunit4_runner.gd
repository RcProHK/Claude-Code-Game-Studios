# DEPRECATED — superseded 2026-05-28 by tests/gut_runner.gd
#
# This file existed as a stale stub from before the test framework was decided.
# Project pinned to GUT v7.x per .claude/docs/technical-preferences.md (line 43).
# Use `tests/gut_runner.gd` instead. See `addons/gut/README.md` for GUT installation.
#
# Foundation chain step 2 (/setup-engine 2026-05-28) marked this as deprecated.
# Foundation chain step 3 (/test-setup) will delete this file once verified that
# no CI script or external reference still points here.
extends SceneTree

func _init() -> void:
	push_error("[gdunit4_runner] DEPRECATED — use tests/gut_runner.gd (GUT v7.x); this stub will be removed at step 3 /test-setup")
	quit(1)
