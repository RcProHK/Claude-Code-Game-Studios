# EnemyDirector CI Lint — State Locality Violation Fixture (Story 003)
# ci:violation-fixture — deliberately OMITS the `_rng_factory` state container
# (and `_boss_anchor_state`) from the class body. check_enemy_director_state_locality.gd
# requires all 8 Rule 1 containers; a missing container => exit 1. Located in
# tests/fixtures/ (outside SCAN_ROOT); read by test_enemy_director_ci_lint.gd via
# _read_lines(). It is NOT a live script. THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# Present: 6 of the 8 required state containers.
var _catch_up_queue: Array = []
var _anomaly_rate_tracker: Dictionary = {}
var _enemy_state_pool: Dictionary = {}
var _killed_dedupe_set: Dictionary = {}
var _spawn_pool: Dictionary = {}
var _active_wave = null

# MISSING (ci:violation-fixture): _rng_factory  — Rule 1 container omitted
# MISSING (ci:violation-fixture): _boss_anchor_state — Rule 1 container omitted

func _ready() -> void:
	_catch_up_queue.clear()
	_enemy_state_pool.clear()
