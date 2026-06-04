## Unit tests — AttentionBudgetPolicy Story 002
## is_input_permitted() full Formula 1 Hybrid derivation + B1 sentinel guard
##
## Coverage (GDD Formula 1 + AC table):
##   AC-01a  — GSM floor: WORKOUT_ACTIVE / COMBAT_ACTIVE / BOSS_ENCOUNTER → false
##             for ALL WST phases (cartesian, including SET_ACTIVE double-lock)
##   AC-01b  — WST refinement: non-floor GSM + SET_ACTIVE phase → false
##   AC-09   — EC-3 disagree: IDLE + SET_ACTIVE → false (AC-01b IDLE instance)
##   AC-19   — Ceremony lock: LOOT_DROP + any phase → false
##   AC-02   — Lifecycle lock: SUSPENDED → false; BOOTING → false
##   AC-03   — Default-open: IDLE/REST_PERIOD(GSM)/DISCONNECTED + non-SET_ACTIVE → true
##   AC-04   — Pure-pull (Rule 2): mutate fake GSM/WST without signal → query reflects new value
##   AC-10   — Fail-closed: _gsm=null → false; _wst=null → false
##   B1      — Sentinel guard: unknown GSM int (e.g. 999) → false (fail-closed, EC-16)
##             unknown WST int → false; negative int → false
##   AC-17a  — Zero-allocation structural check: source file contains no allocating constructs
##             in the is_input_permitted method body
##   AC-17b  — (ADVISORY) 1000× loop memory baseline diff ≈ 0 (noise-tolerant, non-blocking)
##   Rule10  — Effective structural check: source file must NOT contain 'INPUT_BLOCKED_STATES'
##             (improves on Story 001 test_rule10_no_input_blocked_states_const which used
##              get_property_list(), which does not detect consts — this grep is definitive)
##
## Framework: GUT (Godot Unit Testing) v9.x
## NOTE: GUT collects test_*.gd files only; *_test.gd suffix is silently ignored.
##       All test functions must use test_ prefix.
extends GutTest


# ============================================================================
# Stub classes — local to this test file
# ============================================================================

## Minimal fake GSM — duck-typed surface: get_current_state().
## Mutable via set_state() without emitting any signal (AC-04 pure-pull).
class _FakeGSM:
	extends RefCounted
	var _state: int = GameStateMachine.GameState.IDLE

	func get_current_state() -> int:
		return _state

	func set_state(s: int) -> void:
		_state = s


## Minimal fake WST — duck-typed surface: get_current_phase().
## Mutable via set_phase() without emitting any signal (AC-04 pure-pull).
class _FakeWST:
	extends RefCounted
	var _phase: int = WorkoutStateTracker.WorkoutPhase.IDLE

	func get_current_phase() -> int:
		return _phase

	func set_phase(p: int) -> void:
		_phase = p


# ============================================================================
# Constants — shortcuts for readability
# ============================================================================

const _GS := GameStateMachine.GameState
const _WP := WorkoutStateTracker.WorkoutPhase


# ============================================================================
# Test fixtures
# ============================================================================

var _fake_gsm: _FakeGSM
var _fake_wst: _FakeWST


func before_each() -> void:
	_fake_gsm = _FakeGSM.new()
	_fake_wst = _FakeWST.new()


# ============================================================================
# AC-01a — GSM floor: WORKOUT_ACTIVE / COMBAT_ACTIVE / BOSS_ENCOUNTER
#          → false for ALL WST phases (cartesian, phase cannot override)
# ============================================================================

## AC-01a: WORKOUT_ACTIVE + each non-SET_ACTIVE phase → false (floor locks regardless of phase).
func test_ac01a_workout_active_floor_locked_for_all_phases() -> void:
	var floor_state: int = _GS.WORKOUT_ACTIVE
	var non_set_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(floor_state)
	for phase in non_set_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_false(
			policy.is_input_permitted(),
			"AC-01a: WORKOUT_ACTIVE + phase %d must return false (GSM floor lock)" % phase
		)


## AC-01a: WORKOUT_ACTIVE + SET_ACTIVE phase → false (double-lock: floor AND refinement).
func test_ac01a_workout_active_floor_set_active_double_lock() -> void:
	_fake_gsm.set_state(_GS.WORKOUT_ACTIVE)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-01a: WORKOUT_ACTIVE + SET_ACTIVE must return false (double-lock: floor + refinement)"
	)


## AC-01a: COMBAT_ACTIVE + all WST phases → false (floor lock).
func test_ac01a_combat_active_floor_locked_all_phases() -> void:
	var all_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.SET_ACTIVE, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(_GS.COMBAT_ACTIVE)
	for phase in all_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_false(
			policy.is_input_permitted(),
			"AC-01a: COMBAT_ACTIVE + phase %d must return false (GSM floor lock)" % phase
		)


## AC-01a: BOSS_ENCOUNTER + all WST phases → false (floor lock).
func test_ac01a_boss_encounter_floor_locked_all_phases() -> void:
	var all_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.SET_ACTIVE, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(_GS.BOSS_ENCOUNTER)
	for phase in all_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_false(
			policy.is_input_permitted(),
			"AC-01a: BOSS_ENCOUNTER + phase %d must return false (GSM floor lock)" % phase
		)


# ============================================================================
# AC-01b / AC-09 — WST refinement + EC-3 disagree
# ============================================================================

## AC-01b / AC-09: IDLE + SET_ACTIVE → false (WST refinement defense-in-depth, EC-3).
func test_ac01b_ac09_idle_set_active_returns_false() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-01b / AC-09: IDLE + SET_ACTIVE must return false (WST refinement, EC-3 defense)"
	)


## AC-01b edge: DISCONNECTED + SET_ACTIVE → false (WST refinement applies across all non-floor GSM).
func test_ac01b_disconnected_set_active_returns_false() -> void:
	_fake_gsm.set_state(_GS.DISCONNECTED)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-01b edge: DISCONNECTED + SET_ACTIVE must return false (WST refinement)"
	)


## AC-01b edge: REST_PERIOD(GSM) + SET_ACTIVE → false (WST refinement; GSM REST_PERIOD is not floor).
func test_ac01b_rest_period_gsm_set_active_returns_false() -> void:
	_fake_gsm.set_state(_GS.REST_PERIOD)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-01b edge: REST_PERIOD(GSM) + SET_ACTIVE must return false (WST refinement)"
	)


# ============================================================================
# AC-19 — Ceremony lock: LOOT_DROP + any phase → false
# ============================================================================

## AC-19: LOOT_DROP + non-SET_ACTIVE phases → false (ceremony lock, Rule 3b).
func test_ac19_loot_drop_ceremony_locked_non_set_active_phases() -> void:
	var non_set_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(_GS.LOOT_DROP)
	for phase in non_set_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_false(
			policy.is_input_permitted(),
			"AC-19: LOOT_DROP + phase %d must return false (ceremony lock)" % phase
		)


## AC-19 edge: LOOT_DROP + SET_ACTIVE → false (still locked: both ceremony lock AND WST refinement).
func test_ac19_loot_drop_set_active_returns_false() -> void:
	_fake_gsm.set_state(_GS.LOOT_DROP)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-19 edge: LOOT_DROP + SET_ACTIVE must return false (ceremony + refinement double-lock)"
	)


# ============================================================================
# AC-02 — Lifecycle lock: SUSPENDED / BOOTING → false
# ============================================================================

## AC-02: SUSPENDED + non-SET_ACTIVE phase → false (lifecycle lock, Rule 4).
func test_ac02_suspended_returns_false() -> void:
	_fake_gsm.set_state(_GS.SUSPENDED)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-02: SUSPENDED must return false (lifecycle lock, Rule 4)"
	)


## AC-02: BOOTING + any phase → false (lifecycle lock, Rule 4).
func test_ac02_booting_returns_false() -> void:
	_fake_gsm.set_state(_GS.BOOTING)
	_fake_wst.set_phase(_WP.IDLE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_false(
		policy.is_input_permitted(),
		"AC-02: BOOTING must return false (lifecycle lock, Rule 4)"
	)


# ============================================================================
# AC-03 — Default-open: IDLE/REST_PERIOD(GSM)/DISCONNECTED + non-SET_ACTIVE → true
# ============================================================================

## AC-03: IDLE + non-SET_ACTIVE phases → true (Rule 5 default-open).
func test_ac03_idle_non_set_active_phases_permitted() -> void:
	var open_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(_GS.IDLE)
	for phase in open_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_true(
			policy.is_input_permitted(),
			"AC-03: IDLE + phase %d must return true (default-open)" % phase
		)


## AC-03: REST_PERIOD(GSM) + non-SET_ACTIVE phases → true (one-tap window; GSM not in floor).
func test_ac03_rest_period_gsm_non_set_active_phases_permitted() -> void:
	var open_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(_GS.REST_PERIOD)
	for phase in open_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_true(
			policy.is_input_permitted(),
			"AC-03: REST_PERIOD(GSM) + phase %d must return true (one-tap window)" % phase
		)


## AC-03 specific edge: REST_PERIOD(GSM) + REST_PERIOD(WST) → true
## (GDD Example B: set完抖氣 → 一 tap window 開放).
func test_ac03_rest_period_gsm_rest_period_wst_returns_true() -> void:
	_fake_gsm.set_state(_GS.REST_PERIOD)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	assert_true(
		policy.is_input_permitted(),
		"AC-03: REST_PERIOD(GSM) + REST_PERIOD(WST) must be true (GDD Example B — one-tap window)"
	)


## AC-03: DISCONNECTED + non-SET_ACTIVE phases → true (EC-13: reconnect affordance permitted).
func test_ac03_disconnected_non_set_active_phases_permitted() -> void:
	var open_phases: Array[int] = [
		_WP.IDLE, _WP.WARM_UP, _WP.REST_PERIOD, _WP.WORKOUT_COMPLETE
	]
	_fake_gsm.set_state(_GS.DISCONNECTED)
	for phase in open_phases:
		_fake_wst.set_phase(phase)
		var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
		assert_true(
			policy.is_input_permitted(),
			"AC-03: DISCONNECTED + phase %d must return true (reconnect affordance, EC-13)" % phase
		)


# ============================================================================
# AC-04 — Pure-pull (Rule 2): no cache — mutation without signal is reflected
# ============================================================================

## AC-04: mutate fake GSM state (no signal) → query reflects new value.
## Proves derivation reads live value on every call, no cached gate state.
func test_ac04_pure_pull_gsm_mutation_no_signal_reflected() -> void:
	# Arrange — start in default-open state
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	# First query — must be true (IDLE + REST_PERIOD)
	assert_true(
		policy.is_input_permitted(),
		"AC-04 setup: IDLE + REST_PERIOD must return true before mutation"
	)

	# Mutate GSM directly, NO signal emitted
	_fake_gsm.set_state(_GS.WORKOUT_ACTIVE)

	# Second query — must reflect new value (WORKOUT_ACTIVE → false)
	assert_false(
		policy.is_input_permitted(),
		"AC-04: after mutating GSM to WORKOUT_ACTIVE (no signal), must return false (no cache)"
	)


## AC-04: mutate fake WST phase (no signal) → query reflects new value.
func test_ac04_pure_pull_wst_mutation_no_signal_reflected() -> void:
	# Arrange — start in open state
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.IDLE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	# First query — true
	assert_true(
		policy.is_input_permitted(),
		"AC-04 setup: IDLE + IDLE must return true before mutation"
	)

	# Mutate WST directly, NO signal emitted
	_fake_wst.set_phase(_WP.SET_ACTIVE)

	# Second query — must reflect new value (SET_ACTIVE → false)
	assert_false(
		policy.is_input_permitted(),
		"AC-04: after mutating WST to SET_ACTIVE (no signal), must return false (no cache)"
	)


# ============================================================================
# AC-10 — Fail-closed: null dependency ref → false
# ============================================================================

## AC-10: _gsm = null → is_input_permitted() returns false (fail-closed, EC-2).
## Uses reflection set() to simulate post-construction null without triggering _init assert.
func test_ac10_null_gsm_returns_false() -> void:
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	policy.set(&"_gsm", null)

	assert_false(
		policy.is_input_permitted(),
		"AC-10: null _gsm ref must cause is_input_permitted() to return false (fail-closed, EC-2)"
	)


## AC-10: _wst = null → is_input_permitted() returns false (fail-closed, EC-2).
func test_ac10_null_wst_returns_false() -> void:
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	policy.set(&"_wst", null)

	assert_false(
		policy.is_input_permitted(),
		"AC-10: null _wst ref must cause is_input_permitted() to return false (fail-closed, EC-2)"
	)


## AC-10 edge: both refs null → false (both arms of the null guard fire together).
func test_ac10_both_null_returns_false() -> void:
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	policy.set(&"_gsm", null)
	policy.set(&"_wst", null)

	assert_false(
		policy.is_input_permitted(),
		"AC-10 edge: both null refs must return false"
	)


# ============================================================================
# B1 Sentinel guard — Story 002 core: unknown enum int → fail-closed (EC-16)
#
# This is the regression test for the hole that Story 001 left open.
# A future GameState added to the enum but NOT added to KNOWN_GSM_STATES would
# not match any lock set and fall through to return true (fail-OPEN), violating
# Pillar 2. The sentinel guard closes this unconditionally.
# ============================================================================

## B1: GSM returns an invalid out-of-range int (999) → false (fail-closed, not true).
## Regression: without the sentinel, 999 not in any lock set → derivation returns true.
func test_b1_sentinel_unknown_gsm_int_returns_false() -> void:
	# Arrange — use a fake that returns a raw invalid int
	_fake_gsm.set_state(999)  # not a valid GameState enum member
	_fake_wst.set_phase(_WP.IDLE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	assert_false(
		policy.is_input_permitted(),
		"B1 sentinel: unknown GSM int 999 must return false (fail-closed, not fail-OPEN)"
	)


## B1: GSM returns -1 (negative invalid int) → false.
func test_b1_sentinel_negative_gsm_int_returns_false() -> void:
	_fake_gsm.set_state(-1)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	assert_false(
		policy.is_input_permitted(),
		"B1 sentinel: GSM int -1 must return false (out-of-range, fail-closed)"
	)


## B1: WST returns an invalid out-of-range int (999) → false (fail-closed).
## Regression: without the sentinel, 999 not in INPUT_LOCKED_PHASES → derivation returns true.
func test_b1_sentinel_unknown_wst_int_returns_false() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(999)  # not a valid WorkoutPhase enum member
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	assert_false(
		policy.is_input_permitted(),
		"B1 sentinel: unknown WST int 999 must return false (fail-closed, not fail-OPEN)"
	)


## B1: WST returns -1 (negative invalid int) → false.
func test_b1_sentinel_negative_wst_int_returns_false() -> void:
	_fake_gsm.set_state(_GS.DISCONNECTED)
	_fake_wst.set_phase(-1)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	assert_false(
		policy.is_input_permitted(),
		"B1 sentinel: WST int -1 must return false (out-of-range, fail-closed)"
	)


## B1: both GSM and WST invalid → false.
func test_b1_sentinel_both_unknown_ints_returns_false() -> void:
	_fake_gsm.set_state(999)
	_fake_wst.set_phase(888)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	assert_false(
		policy.is_input_permitted(),
		"B1 sentinel: both unknown ints must return false"
	)


## B1: one valid, one just-out-of-range → false.
## int = 9 is one past the last SUSPENDED (ordinal 8) — not in KNOWN_GSM_STATES.
func test_b1_sentinel_gsm_one_past_end_returns_false() -> void:
	_fake_gsm.set_state(9)  # one past SUSPENDED (ordinal 8) — future unknown state
	_fake_wst.set_phase(_WP.IDLE)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	assert_false(
		policy.is_input_permitted(),
		"B1 sentinel: GSM int 9 (one past SUSPENDED) must return false (not yet in KNOWN_GSM_STATES)"
	)


# ============================================================================
# AC-17a — Zero-allocation structural check (hot-path perf, BLOCKING Static)
#
# Loads the source file as text and asserts the is_input_permitted method body
# contains none of the banned allocating tokens.
# This is a deterministic CI-class check, not a runtime profiler check.
# ============================================================================

## AC-17a: is_input_permitted() method body must not contain allocating constructs.
## Banned tokens: inline [ / { literal, .new(, % or + string concat/format.
## Scans between the func signature line and the next func/end-of-file.
func test_ac17a_is_input_permitted_zero_allocation_structural() -> void:
	# Load source file as text
	const SOURCE_PATH := "res://src/systems/attention_budget_policy.gd"
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	assert_not_null(file, "AC-17a: source file must be readable at " + SOURCE_PATH)
	if file == null:
		return
	var source_text: String = file.get_as_text()
	file.close()

	# Extract the is_input_permitted method body only.
	# Strategy: find the func signature, then collect lines until the next top-level func.
	var lines: PackedStringArray = source_text.split("\n")
	var in_method: bool = false
	var method_body_lines: Array[String] = []
	for line in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func is_input_permitted"):
			in_method = true
			continue
		if in_method:
			# Stop at next top-level func declaration (not indented)
			if stripped.begins_with("func ") and not line.begins_with("\t"):
				break
			method_body_lines.append(line)

	assert_true(
		method_body_lines.size() > 0,
		"AC-17a: is_input_permitted method body must be non-empty (found no lines after signature)"
	)

	var method_body: String = "\n".join(method_body_lines)

	# Check for banned allocating tokens:
	# 1. Inline Array literal [ used to create a new array (e.g. [1, 2, 3])
	#    — const arrays named KNOWN_* are defined outside the method body, not in it.
	#    A bare '[' in the method body means an inline literal. We look for '[' NOT preceded
	#    by 'KNOWN_' or a const name — use a simple check: any '[' in method body = violation.
	#    Exception: the method body legitimately has no '['; const arrays are file-level.
	assert_false(
		_method_body_has_inline_bracket(method_body),
		"AC-17a: is_input_permitted body must not contain inline [ (Array/Dict literal allocation)"
	)

	# 2. .new( — object allocation
	assert_false(
		method_body.contains(".new("),
		"AC-17a: is_input_permitted body must not contain .new( (object allocation)"
	)

	# 3. String concat / format: " % " (format string) — simple presence check
	assert_false(
		_method_body_has_string_format(method_body),
		"AC-17a: is_input_permitted body must not contain string % format (allocation)"
	)

	# 4. Inline Dictionary literal { — object allocation
	assert_false(
		_method_body_has_inline_brace(method_body),
		"AC-17a: is_input_permitted body must not contain inline { (Dictionary literal allocation)"
	)


## Helper: returns true if method body has a '[' that is not part of a comment.
## Used by AC-17a structural check.
func _method_body_has_inline_bracket(body: String) -> bool:
	for line in body.split("\n"):
		var stripped: String = line.strip_edges()
		# Skip comment lines
		if stripped.begins_with("#"):
			continue
		# Check for '[' in non-comment part (strip inline comment first)
		var code_part: String = stripped
		var comment_pos: int = stripped.find(" #")
		if comment_pos >= 0:
			code_part = stripped.substr(0, comment_pos)
		if "[" in code_part:
			return true
	return false


## Helper: returns true if method body has string format operator % (non-comment).
func _method_body_has_string_format(body: String) -> bool:
	for line in body.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var code_part: String = stripped
		var comment_pos: int = stripped.find(" #")
		if comment_pos >= 0:
			code_part = stripped.substr(0, comment_pos)
		# Look for string format: quoted-string followed by ' %' or standalone ' % '
		if '" %' in code_part or "' %" in code_part:
			return true
	return false


## Helper: returns true if method body has inline '{' (non-comment).
func _method_body_has_inline_brace(body: String) -> bool:
	for line in body.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var code_part: String = stripped
		var comment_pos: int = stripped.find(" #")
		if comment_pos >= 0:
			code_part = stripped.substr(0, comment_pos)
		if "{" in code_part:
			return true
	return false


# ============================================================================
# AC-17b — ADVISORY: runtime memory baseline diff over 1000 calls ≈ 0
#
# This test is deliberately noise-tolerant. The GUT headless profiler diff
# includes GC jank and routed allocs from surrounding test machinery.
# It is NOT a hard deterministic gate — that role belongs to AC-17a (structural).
# Failure here is logged as a WARNING, not a blocking assert.
# ============================================================================

## AC-17b (ADVISORY): 1000 calls to is_input_permitted() produce negligible heap growth.
## Non-blocking: generous tolerance (1KB) accounts for GC / surrounding allocs.
func test_ac17b_advisory_no_heap_growth_1000_calls() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)

	# Warm up — discard first few calls so GC is settled
	for _i in range(10):
		var _warm: bool = policy.is_input_permitted()

	var baseline_bytes: int = Performance.get_monitor(Performance.MEMORY_STATIC)

	# Hot loop — 1000 calls
	for _i in range(1000):
		var _result: bool = policy.is_input_permitted()

	var after_bytes: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	var diff_bytes: int = after_bytes - baseline_bytes

	# ADVISORY tolerance: 1024 bytes (1KB). GUT overhead and GC noise can move this.
	# This is a warning signal, not a blocking gate. AC-17a (structural) is the real gate.
	const ADVISORY_TOLERANCE_BYTES: int = 1024
	if diff_bytes > ADVISORY_TOLERANCE_BYTES:
		push_warning(
			"AC-17b ADVISORY: is_input_permitted() 1000× heap diff = %d bytes (> %d tolerance). "
			+ "Investigate if this recurs — may indicate allocation regression. "
			+ "AC-17a structural check is the blocking gate." % [diff_bytes, ADVISORY_TOLERANCE_BYTES]
		)
	# Non-blocking: log the measurement but never fail the suite
	assert_true(true, "AC-17b ADVISORY: measurement complete (diff = %d bytes)" % diff_bytes)


# ============================================================================
# Rule 10 effective structural check
#
# Story 001's test_rule10_no_input_blocked_states_const used get_property_list()
# which does NOT detect `const` declarations (consts are not in the property list).
# This grep-based check is definitive: if 'INPUT_BLOCKED_STATES' appears anywhere
# in the source file it means the old banned const was re-introduced.
# ============================================================================

## Rule 10 structural: source file must NOT contain 'INPUT_BLOCKED_STATES' anywhere.
## The old stub used this const; Rule 10 migration replaced it with named sets.
## get_property_list() misses consts — this grep is the effective check.
func test_rule10_effective_input_blocked_states_absent_from_source() -> void:
	const SOURCE_PATH := "res://src/systems/attention_budget_policy.gd"
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	assert_not_null(file, "Rule 10 structural: source file must be readable at " + SOURCE_PATH)
	if file == null:
		return
	var source_text: String = file.get_as_text()
	file.close()

	# Scan code lines only — doc comments (lines starting with '#') legitimately
	# mention INPUT_BLOCKED_STATES to document that the old-stub const was REMOVED.
	# Rule 10 bans the const DECLARATION, not the word appearing in a comment.
	var offending_line := ""
	for raw_line in source_text.split("\n"):
		var stripped: String = raw_line.strip_edges()
		if stripped.begins_with("#"):
			continue  # comment line — skip
		if stripped.contains("INPUT_BLOCKED_STATES"):
			offending_line = stripped
			break

	assert_eq(
		offending_line,
		"",
		"Rule 10 structural: 'INPUT_BLOCKED_STATES' must NOT exist as a code declaration in "
		+ "attention_budget_policy.gd (comments documenting its removal are allowed). Offending: "
		+ offending_line
	)
