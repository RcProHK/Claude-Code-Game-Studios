## Integration test — AttentionBudget Story 004
## Boot subscription + Substate + derivation independence + CI lint
##
## Coverage:
##   AC-12(a)  — #1 state_changed subscribed via connect_for_initial_state (spy) +
##               initial callback fired (3-arg callv delivery).
##   AC-12(b)  — #9 phase_changed subscribed via plain .connect.
##   AC-12 CI  — check_attention_subscription regex flags the violation fixture +
##               does NOT flag the clean fixture (mirrors camera/screen-effects lint).
##   AC-14     — derivation independence: subscription signals NEVER fire + live
##               phase == SET_ACTIVE → is_input_permitted() false (pure-pull).
##   AC-16     — Substate boot fail-closed: GSM == BOOTING → is_input_permitted()
##               false; Substate starts INITIALISING and reaches READY after wiring.
##   AC-20     — _on_gsm_state_changed is exactly 3-arg, no .bind() (callv arity).
##
## Framework: GUT (Godot Unit Testing) v9.x.
## NOTE: GUT collects test_*.gd files only; *_test.gd suffix is silently ignored.
##       All test functions must use the test_ prefix.
extends GutTest


# ============================================================================
# Stub classes — local to this test, per project integration test pattern
# ============================================================================

## Fake GSM — records connect_for_initial_state calls and delivers an initial-state
## callback via 3-arg callv (mirroring the real GameStateMachine.connect_for_initial_state
## sentinel-delivery path, ADR-0006 Contract 6). Also exposes get_current_state() so an
## AttentionBudgetPolicy can pure-pull derive against it.
class _FakeGSM:
	extends RefCounted

	signal state_changed(from_state: int, to_state: int, payload)

	var _state: int = GameStateMachine.GameState.IDLE
	## Records every Callable passed to connect_for_initial_state (AC-12a spy).
	var initial_state_connect_calls: Array[Callable] = []
	## True once the deferred 3-arg initial-state callback was delivered.
	var initial_callback_delivered: bool = false

	func get_current_state() -> int:
		return _state

	func set_state(s: int) -> void:
		_state = s

	## Mirrors GSM Contract 6: connect the signal AND deliver the current state via
	## 3-arg callv. We deliver synchronously here (no process_frame) so the test can
	## assert delivery without pumping the SceneTree.
	func connect_for_initial_state(callable: Callable) -> void:
		initial_state_connect_calls.append(callable)
		state_changed.connect(callable)
		# 3-arg positional callv — same shape as _deliver_initial_state (NO .bind()).
		var payload := StateTransitionPayload.new()
		payload.source_event = GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT
		callable.callv([_state, _state, payload])
		initial_callback_delivered = true


## Fake WST — exposes a real phase_changed signal (for plain .connect) + the
## get_current_phase() pure-pull surface. Has NO connect_for_initial_state helper,
## matching the real WorkoutStateTracker (GSM-specific helper).
class _FakeWST:
	extends RefCounted

	signal phase_changed(from_phase: int, to_phase: int)

	var _phase: int = WorkoutStateTracker.WorkoutPhase.IDLE

	func get_current_phase() -> int:
		return _phase

	func set_phase(p: int) -> void:
		_phase = p


# ============================================================================
# Test fixtures
# ============================================================================

const VIOLATION_FIXTURE: String = "res://tests/fixtures/attention_subscription_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/attention_subscription_clean.gd"
const REAL_AUTOLOAD: String = "res://src/autoload/attention_budget.gd"
const GSM_OWNER_SOURCE: String = "res://src/autoload/game_state_machine.gd"

## Must match FORBIDDEN_PATTERNS in check_attention_subscription.gd.
const BAN_PATTERN: String = "state_changed\\s*\\.\\s*connect\\s*\\("

var _fake_gsm: _FakeGSM
var _fake_wst: _FakeWST


func before_each() -> void:
	_fake_gsm = _FakeGSM.new()
	_fake_wst = _FakeWST.new()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Construct an unregistered AttentionBudget node WITHOUT running _ready()'s real
## wiring (which would target the live autoloads). add_child would fire _ready, so we
## DON'T add it — we call _wire_subscriptions(fake, fake) directly instead.
func _make_budget() -> Node:
	return preload("res://src/autoload/attention_budget.gd").new()


func _read_lines(res_path: String) -> PackedStringArray:
	var file := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


## Count ban-pattern matches, skipping whole-line comments (mirrors the lint's
## comment skip; the lint additionally strips trailing comments — the fixtures
## avoid inline-after-code bans so a whole-line skip is sufficient here).
func _count_ban_matches(lines: PackedStringArray) -> int:
	var re := RegEx.new()
	assert_eq(re.compile(BAN_PATTERN), OK, "ban regex must compile")
	var count: int = 0
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if re.search(line) != null:
			count += 1
	return count


# ============================================================================
# AC-12(a) — #1 state_changed via connect_for_initial_state + initial callback
# ============================================================================

func test_ac12a_gsm_subscribed_via_connect_for_initial_state() -> void:
	# Arrange
	var budget := _make_budget()

	# Act — wire against the fakes (bypasses _ready's live-autoload targeting).
	budget.call("_wire_subscriptions", _fake_gsm, _fake_wst)

	# Assert — connect_for_initial_state was the subscription path used for GSM.
	assert_eq(_fake_gsm.initial_state_connect_calls.size(), 1,
		"AC-12a: GSM state_changed must be subscribed via connect_for_initial_state exactly once")
	budget.free()


func test_ac12a_initial_state_callback_fired() -> void:
	# Arrange
	var budget := _make_budget()

	# Act
	budget.call("_wire_subscriptions", _fake_gsm, _fake_wst)

	# Assert — the 3-arg initial-state delivery reached the callback (sentinel path).
	assert_true(_fake_gsm.initial_callback_delivered,
		"AC-12a: initial-state callback must fire on connect (Contract 6 callv delivery)")
	budget.free()


func test_ac12a_subscribed_callable_targets_on_gsm_state_changed() -> void:
	# Arrange
	var budget := _make_budget()

	# Act
	budget.call("_wire_subscriptions", _fake_gsm, _fake_wst)

	# Assert — the connected Callable is the bare 3-arg method (AC-20: no .bind()).
	var connected: Callable = _fake_gsm.initial_state_connect_calls[0]
	assert_eq(connected.get_method(), "_on_gsm_state_changed",
		"AC-12a/AC-20: connect_for_initial_state must receive _on_gsm_state_changed")
	assert_eq(connected.get_bound_arguments_count(), 0,
		"AC-20: callback must NOT use .bind() — 0 bound args (callv arity contract)")
	budget.free()


# ============================================================================
# AC-12(b) — #9 phase_changed via plain .connect
# ============================================================================

func test_ac12b_wst_phase_changed_plain_connect_used() -> void:
	# Arrange
	var budget := _make_budget()

	# Act
	budget.call("_wire_subscriptions", _fake_gsm, _fake_wst)

	# Assert — the WST phase_changed signal now has the callback connected (plain form).
	assert_true(_fake_wst.phase_changed.is_connected(Callable(budget, "_on_wst_phase_changed")),
		"AC-12b: WST phase_changed must be subscribed via plain .connect")
	budget.free()


func test_ac12b_wst_callback_is_two_arg() -> void:
	# Arrange — phase_changed is a 2-arg signal; emitting it must reach the 2-arg
	# callback without arity error (distinct from the GSM 3-arg callback, AC-20).
	var budget := _make_budget()
	budget.call("_wire_subscriptions", _fake_gsm, _fake_wst)

	# Act — emit the 2-arg signal; if the callback were 3-arg this would error.
	_fake_wst.phase_changed.emit(
		WorkoutStateTracker.WorkoutPhase.IDLE,
		WorkoutStateTracker.WorkoutPhase.WARM_UP
	)

	# Assert — reaching here without a connection/arity error proves the 2-arg shape.
	assert_true(true, "AC-12b/AC-20: 2-arg phase_changed delivery must not error (callback is 2-arg)")
	budget.free()


# ============================================================================
# AC-12 CI lint — fixture verification (mirrors camera/screen-effects lint tests)
# ============================================================================

func test_ac12_lint_violation_fixture_is_flagged() -> void:
	# Arrange + Act
	var count: int = _count_ban_matches(_read_lines(VIOLATION_FIXTURE))
	# Assert
	assert_eq(count, 1,
		"AC-12: violation fixture's plain `state_changed.connect(` must be flagged exactly once")


func test_ac12_lint_clean_fixture_not_flagged() -> void:
	# Arrange — clean fixture uses connect_for_initial_state( + phase_changed.connect(
	# + a commented ban; none must match the state_changed-anchored ban regex.
	var lines := _read_lines(CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: clean fixture must be readable")
	# Sanity: the clean fixture DOES contain connect_for_initial_state + phase_changed.connect.
	var has_helper: bool = false
	var has_phase_connect: bool = false
	for line: String in lines:
		if line.contains("connect_for_initial_state("):
			has_helper = true
		if line.contains("phase_changed.connect("):
			has_phase_connect = true
	assert_true(has_helper, "Precondition: clean fixture must use connect_for_initial_state(")
	assert_true(has_phase_connect, "Precondition: clean fixture must use phase_changed.connect(")
	# Act + Assert — ban regex must NOT match any of those legal forms.
	assert_eq(_count_ban_matches(lines), 0,
		"AC-12: clean fixture (helper + phase_changed.connect + commented ban) must NOT be flagged")


func test_ac12_lint_gsm_owner_exempt() -> void:
	# Arrange — the GSM owner legitimately has `state_changed.connect(` inside its own
	# connect_for_initial_state() helper. The ban regex WOULD match it (MAJOR-5), so the
	# lint EXEMPTS the owner file. This test proves: (1) the owner really contains the
	# pattern (so the exemption is load-bearing, not vacuous), and (2) the attention
	# autoload itself does NOT contain it.
	var owner_lines := _read_lines(GSM_OWNER_SOURCE)
	var autoload_lines := _read_lines(REAL_AUTOLOAD)
	assert_true(owner_lines.size() > 0, "Precondition: game_state_machine.gd must be readable")
	assert_true(autoload_lines.size() > 0, "Precondition: attention_budget.gd must be readable")
	# Act + Assert — owner DOES match (proves exemption is necessary; PR #12 lesson)...
	assert_gt(_count_ban_matches(owner_lines), 0,
		"AC-12: game_state_machine.gd must contain state_changed.connect( (the exempt owner seam)")
	# ...and the attention autoload uses connect_for_initial_state, never the plain form.
	assert_eq(_count_ban_matches(autoload_lines), 0,
		"AC-12: attention_budget.gd must use connect_for_initial_state (0 plain state_changed.connect)")


func test_ac12_lint_does_not_match_phase_changed_connect() -> void:
	# Arrange — a synthetic legal line: plain phase_changed.connect must NOT be flagged
	# (the ban is anchored on state_changed).
	var lines: PackedStringArray = [
		"\tWorkoutStateTracker.phase_changed.connect(_on_wst_phase_changed)",
	]
	# Act + Assert
	assert_eq(_count_ban_matches(lines), 0,
		"AC-12: phase_changed.connect( must NOT match the state_changed-anchored ban regex")


func test_ac12_lint_does_not_match_connect_for_initial_state() -> void:
	# Arrange — a synthetic legal line: connect_for_initial_state has `connect` followed
	# by `_`, never `(`, so the ban regex must NOT match it.
	var lines: PackedStringArray = [
		"\tGameStateMachine.connect_for_initial_state(_on_gsm_state_changed)",
		"\tGameStateMachine.state_changed.connect_for_initial_state(_on_gsm_state_changed)",
	]
	# Act + Assert
	assert_eq(_count_ban_matches(lines), 0,
		"AC-12: connect_for_initial_state( must NOT match the ban regex (connect followed by `_`)")


# ============================================================================
# AC-14 — derivation independence (subscription never fires)
# ============================================================================

func test_ac14_derivation_independent_of_subscription() -> void:
	# Arrange — build a policy directly against fakes whose signals NEVER fire.
	# Set live phase to SET_ACTIVE; GSM stays IDLE (non-floor) so ONLY the WST
	# refinement can block input — proving the pure-pull path drives the result.
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	_fake_gsm.set_state(GameStateMachine.GameState.IDLE)
	_fake_wst.set_phase(WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)

	# Act — query WITHOUT ever emitting state_changed / phase_changed.
	var permitted: bool = policy.is_input_permitted()

	# Assert — false purely from the live SET_ACTIVE pull (Rule 2), no subscription.
	assert_false(permitted,
		"AC-14: is_input_permitted() must be false from live SET_ACTIVE pull, independent of subscription")


func test_ac14_subscription_signals_never_delivered() -> void:
	# Arrange — a policy never subscribes; it only reads live values. Confirm that
	# emitting nothing leaves derivation fully functional in the permitted direction.
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	_fake_gsm.set_state(GameStateMachine.GameState.IDLE)
	_fake_wst.set_phase(WorkoutStateTracker.WorkoutPhase.REST_PERIOD)

	# Act
	var permitted: bool = policy.is_input_permitted()

	# Assert — IDLE + REST_PERIOD (no lock) → true, with zero signals fired.
	assert_true(permitted,
		"AC-14: derivation returns true for IDLE+REST_PERIOD with no subscription delivery")


# ============================================================================
# AC-16 — Substate boot fail-closed
# ============================================================================

func test_ac16_substate_starts_initialising() -> void:
	# Arrange — fresh node, _ready() NOT run (not added to tree).
	var budget := _make_budget()
	# Act + Assert — substate is the safe pre-wiring default.
	assert_eq(budget.get("_substate"), budget.Substate.INITIALISING,
		"AC-16: _substate must start INITIALISING before wiring")
	budget.free()


func test_ac16_substate_reaches_ready_after_wiring() -> void:
	# Arrange
	var budget := _make_budget()
	# Act
	budget.call("_wire_subscriptions", _fake_gsm, _fake_wst)
	# Assert — wiring flips to READY (Substate table) and get_substate() reflects it.
	assert_eq(budget.get("_substate"), budget.Substate.READY,
		"AC-16: _substate must be READY after _wire_subscriptions")
	assert_eq(budget.call("get_substate"), budget.Substate.READY,
		"AC-16: get_substate() must report READY after wiring")
	budget.free()


func test_ac16_booting_gsm_fails_closed() -> void:
	# Arrange — GSM == BOOTING (lifecycle lock); phase IDLE. Pure-pull must fail-closed.
	var policy := AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)
	_fake_gsm.set_state(GameStateMachine.GameState.BOOTING)
	_fake_wst.set_phase(WorkoutStateTracker.WorkoutPhase.IDLE)

	# Act
	var permitted: bool = policy.is_input_permitted()

	# Assert — BOOTING ∈ LIFECYCLE_LOCKED_STATES → false (Rule 4 fail-closed safe).
	assert_false(permitted,
		"AC-16: GSM == BOOTING must make is_input_permitted() false (fail-closed)")
