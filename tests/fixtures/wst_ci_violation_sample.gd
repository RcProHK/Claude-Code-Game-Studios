# WST CI Lint — Planted Violation Fixture (Story 009)
# ci:violation-fixture — deliberate rule violations for CI detection testing.
# Located in tests/fixtures/ (outside SCAN_ROOT = res://src/), so CI scripts
# do NOT scan this file during clean-repo checks.
# test_wst_ci_lint.gd targets this file directly to verify detection.
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# ACTIVE violation (a1): WorkoutStateTracker._field access (Rule 14 / check_workout_state_caller)
var _phase_read_viol = WorkoutStateTracker._workout_phase

# ACTIVE violation (a2): WorkoutStateTracker.set_* method call (Rule 14 / check_workout_state_caller)
# This tests the set_ branch explicitly (separate from _field access)
var _set_call_viol = WorkoutStateTracker.set_deferred("_workout_phase", 0)

# ACTIVE violation (b): PersistenceLayer.write("wst.*") outside owner (Rule 7/14 / check_wst_namespace)
var _ns_violation = PersistenceLayer.write("wst.current_workout.phase", 0)

# ACTIVE violation (c): preload(...).new() instantiation (Rule 15 / check_wst_singleton_and_nevers)
var _wst_inst = preload("res://src/autoload/workout_state_tracker.gd").new()

# ACTIVE violation (d): _dominant_class WRITE outside owner (Rule 16 / check_wst_singleton_and_nevers)
# Must be an ASSIGNMENT (=), not just a read, to match `_dominant_class\s*=` pattern
var _dominant_class = 2  # ci:violation-fixture — matches `_dominant_class\s*=` write pattern
