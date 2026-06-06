extends GutTest
## Story 008 — server baseline reconcile (ADR-0011 §D-2 client half).
## Covers AC-14 (server wins) / AC-15 (grace + fail-closed) / AC-16 (session
## floor — double-count race) / AC-23 (per-entry validation).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


class MockStat:
	extends RefCounted
	var calls: int = 0

	func get_stat(_stat_id: StringName) -> float:
		return 12.0

	func apply_stat_delta(_stat_id: StringName, _source: int, _delta: float) -> bool:
		calls += 1
		return true


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0


var _sut: Node
var _stat: MockStat
var _signals: Array = []
var _imports: Array = []


func before_each() -> void:
	_stat = MockStat.new()
	_signals = []
	_imports = []
	_sut = PrDetectionScript.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._stat_system = _stat
	_sut._class_mapping = MockClassMapping.new()
	add_child_autofree(_sut)
	_sut.pr_breakthrough.connect(func(_sid: StringName, m: float) -> void:
		_signals.append(m))
	_sut.baseline_import_completed.connect(func(n: int) -> void:
		_imports.append(n))


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


# --- AC-14: server wins the pre-session truth -------------------------------------

func test_server_overrides_local_cache() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut.apply_server_baselines({"bench_press": 85.0})
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 85.0, 0.001)
	# Subsequent judgment uses 85: a set at e1rm 86 → m ≈ 0.0118 → PR.
	_sut._on_set_logged("bench_press", 5, 86.0 * 6.0 / 7.0)
	assert_eq(_signals.size(), 1)


# --- AC-15: offline grace (a) + INV-PR-1 fail-closed (b) ----------------------------

func test_local_cache_judges_during_offline_grace() -> void:
	# (a) server never answers — exercises WITH a local cache still judge.
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_set_logged("bench_press", 5, 65.0)  # e1rm 75.833 → PR
	assert_eq(_signals.size(), 1, "local cache judges during BASELINE_SYNCING grace")


func test_no_cache_no_sync_is_establishment_only() -> void:
	# (b) no local cache + sync never succeeded → establishment-only, ZERO PR.
	_sut._on_set_logged("bench_press", 5, 40.0)
	_sut._on_set_logged("bench_press", 5, 60.0)  # ascending — would be a fake PR
	assert_eq(_signals.size(), 0, "INV-PR-1 fail-closed: no trusted baseline, no PR")
	assert_eq(_stat.calls, 0)


# --- AC-16: session-confirmed floor (EC-7b double-count race) -----------------------

func test_stale_server_snapshot_cannot_pull_below_session_floor() -> void:
	# Local-cache PR confirmed during BASELINE_SYNCING: 70 → 75.833.
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_set_logged("bench_press", 5, 65.0)
	assert_eq(_signals.size(), 1)
	# Server response arrives, computed BEFORE that set: 70.0 (capture-release).
	_sut.apply_server_baselines({"bench_press": 70.0})
	# Floor holds; conflict telemetry; replay of the same set is a no-op.
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 75.833, 0.001,
		"session-confirmed floor — never pulled below (EC-7b)")
	assert_has(_events(), "pr.baseline_conflict")
	_sut._on_set_logged("bench_press", 5, 65.0)
	assert_eq(_signals.size(), 1, "catch-up replay stays a no-op (zero double-count)")


# --- AC-23: per-entry validation (six pinned vectors) -------------------------------

func test_per_entry_validation_rejects_degenerates() -> void:
	_sut._pr_state.baselines["d_local"] = 50.0
	_sut.apply_server_baselines({
		"a": 0.0,        # zero → ÷0 fake-max-PR seed
		"b": -10.0,      # negative → permanent suppression
		"c": INF,        # non-finite
		"d_local": 0.5,  # near-zero sibling (< WEIGHT_SANITY_MIN)
		"e": 800.0,      # > ceiling 500 × (1 + 12/30) = 700
		"f": 85.0,       # valid
	})
	# a/b/c/e never adopted; d_local rejected → LOCAL value kept; f adopted.
	assert_false(_sut._pr_state.baselines.has("a"))
	assert_false(_sut._pr_state.baselines.has("b"))
	assert_false(_sut._pr_state.baselines.has("c"))
	assert_almost_eq(_sut._pr_state.baselines["d_local"], 50.0, 0.001,
		"rejected entry keeps the local value")
	assert_false(_sut._pr_state.baselines.has("e"))
	assert_almost_eq(_sut._pr_state.baselines["f"], 85.0, 0.001)
	var invalid: int = _events().filter(
		func(e: String) -> bool: return e == "pr.baseline_invalid").size()
	assert_eq(invalid, 5, "five rejected entries, five pr.baseline_invalid events")


# --- Formula 4 window termination + import reveal ------------------------------------

func test_server_adoption_terminates_window_keeping_height() -> void:
	# In-window candidate 80 > server 70 → keep the candidate height, no PR fired.
	_sut._on_set_logged("bench_press", 5, 60.0 * 8.0 / 7.0)  # candidate ~80
	_sut.apply_server_baselines({"bench_press": 70.0})
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 80.0, 0.01,
		"max(server, candidate) — ratchet height never lost")
	assert_true(_sut._pr_state.candidates.is_empty(), "window terminated")
	assert_has(_events(), "pr.candidate_supersession")
	assert_eq(_signals.size(), 0, "supersession never fires a PR")


func test_first_nonempty_sync_emits_import_reveal_once() -> void:
	_sut.apply_server_baselines({"bench_press": 85.0, "barbell_squat": 120.0})
	_sut.apply_server_baselines({"bench_press": 86.0})
	assert_eq(_imports.size(), 1, "import reveal is a one-shot")
	assert_eq(_imports[0], 2)
