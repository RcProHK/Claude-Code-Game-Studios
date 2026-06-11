extends GutTest
## Story 003: CombatVisualFeedback (#25) scaffold — bootstrap subscription wiring +
## PROCESS_MODE_ALWAYS + lifecycle Active/Suspended substate.
##
## Fully isolated via injected fakes BEFORE add_child (reference_test_persistence_isolation /
## reference_gsm_subscription_pollution — fresh-instance wiring, never relies on a real-autoload
## connection surviving suite order). Covers AC-01 (subscription set) + process_mode + null-safe
## degrade + Suspended reject. See design/gdd/combat-visual-feedback.md States table.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")


# --- Fakes --------------------------------------------------------------------

class FakeEnemyDirector:
	extends RefCounted
	signal hit_resolved(payload)
	signal enemy_killed(payload)
	func emit_hit(payload = null) -> void:
		hit_resolved.emit(payload)
	func emit_kill(payload = null) -> void:
		enemy_killed.emit(payload)


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	var state: int = GameState.IDLE
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func go(to_state: int) -> void:
		var prev := state
		state = to_state
		state_changed.emit(prev, to_state, null)


class FakeParticles:
	extends RefCounted
	var plays: Array = []
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0):
		plays.append({"preset": preset_id, "pos": position, "mult": multiplier})
		return null


class FakeScreenFx:
	extends RefCounted
	var pauses: Array = []
	func hit_pause(duration: float) -> void:
		pauses.append(duration)


class FakeClock:
	extends RefCounted
	var ms: int = 0
	func now_ms() -> int:
		return ms


# --- Helpers ------------------------------------------------------------------

## Build + boot a coordinator with all seams injected (no autoload fallback). Returns
## the live node (add_child_autofree handles teardown). set_process(false) so no auto-tick.
func _make(ed = null, gsm = null, particles = null, screen_fx = null, clock = null) -> Node:
	var c = CvfScript.new()
	c._enemy_director = ed if ed != null else FakeEnemyDirector.new()
	c._gsm = gsm if gsm != null else FakeGSM.new()
	c._particles = particles if particles != null else FakeParticles.new()
	c._screen_fx = screen_fx if screen_fx != null else FakeScreenFx.new()
	c._clock = clock if clock != null else FakeClock.new()
	c._avatar = RefCounted.new()  # v0.2-only; no anchor API on MVP (R-17)
	add_child_autofree(c)
	c.set_process(false)
	return c


# --- Tests --------------------------------------------------------------------

## AC-01: fresh instance subscribes #14 hit_resolved + enemy_killed (raw connect) and
## #1 GSM state_changed (cfis). Fresh-instance count, not real-autoload survival.
func test_bootstrap_subscribes_enemy_director_and_gsm() -> void:
	var ed := FakeEnemyDirector.new()
	var gsm := FakeGSM.new()
	var c := _make(ed, gsm)

	assert_eq(ed.hit_resolved.get_connections().size(), 1,
		"AC-01: #14 hit_resolved has exactly 1 connection after boot")
	assert_eq(ed.enemy_killed.get_connections().size(), 1,
		"AC-01: #14 enemy_killed has exactly 1 connection after boot")
	assert_eq(gsm.state_changed.get_connections().size(), 1,
		"AC-01: #1 GSM state_changed connected via connect_for_initial_state")
	assert_true(ed.hit_resolved.is_connected(c._on_hit_resolved),
		"AC-01: hit_resolved wired to #25 handler")
	assert_true(ed.enemy_killed.is_connected(c._on_enemy_killed),
		"AC-01: enemy_killed wired to #25 handler")


## EC-15: coordinator must keep ticking while #6 holds a tree pause.
func test_process_mode_is_always() -> void:
	var c := _make()
	assert_eq(c.process_mode, Node.PROCESS_MODE_ALWAYS,
		"PROCESS_MODE_ALWAYS so number/overlay _process ticks during #6 hit_pause")


## R-20 fail-soft: predecessors absent (objects with no signals/methods) → no crash.
func test_absent_predecessors_no_crash() -> void:
	var c = CvfScript.new()
	c._enemy_director = RefCounted.new()  # no hit_resolved/enemy_killed signal
	c._gsm = RefCounted.new()             # no connect_for_initial_state method
	c._particles = RefCounted.new()
	c._screen_fx = RefCounted.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	assert_true(c._ready_complete, "boot completes even with absent predecessors (null-safe guards)")


## States table: SUSPENDED rejects all incoming signals (silent no-op + debug counter).
func test_suspended_rejects_incoming() -> void:
	var ed := FakeEnemyDirector.new()
	var gsm := FakeGSM.new()
	var c := _make(ed, gsm)

	gsm.go(FakeGSM.GameState.SUSPENDED)
	assert_eq(c._lifecycle, c.Lifecycle.SUSPENDED, "GSM SUSPENDED → lifecycle SUSPENDED")

	ed.emit_hit(null)
	ed.emit_kill(null)
	assert_eq(c._rejected_while_suspended, 2,
		"both incoming signals rejected while SUSPENDED (no-op + debug counter)")


## SUSPENDED is overridden by any non-Suspended state → back to Active.
func test_resume_returns_to_active() -> void:
	var gsm := FakeGSM.new()
	var c := _make(null, gsm)

	gsm.go(FakeGSM.GameState.SUSPENDED)
	assert_eq(c._lifecycle, c.Lifecycle.SUSPENDED, "suspended")
	gsm.go(FakeGSM.GameState.IDLE)
	assert_eq(c._lifecycle, c.Lifecycle.ACTIVE, "non-Suspended state returns to ACTIVE")
