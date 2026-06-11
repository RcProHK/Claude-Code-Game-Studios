extends GutTest
## Story 017: CombatVisualFeedback (#25) AC-28 — the CI-testable performance slice.
## Draw-call/blend-pass bounds + IDLE zero-cost are CI-verifiable here; the mobile-Safari
## P95 ≤16.6ms frame budget is a VS-tier hardware gate (pending honesty).

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")
const F := preload("res://src/core/combat_visual_feedback_formulas.gd")


class FakeEnemyDirector:
	extends RefCounted
	signal hit_resolved(payload)
	signal enemy_killed(payload)


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)


class FakeParticles:
	extends RefCounted
	func play(_p: int, _pos: Vector2, _m: float = 1.0):
		return null


class FakeScreenFx:
	extends RefCounted
	func hit_pause(_d: float) -> void:
		pass


var _tid := 0

func _make() -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = true
	return c


func _hit(tier: int, outcome: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.damage_dealt = 9
	_tid += 1
	p.transition_id = "t%d" % _tid
	p.target_id = _tid
	return p


# --- Tests --------------------------------------------------------------------

## AC-28: damage-number peak is bounded by the pool (≤16 concurrent → ≤~16 draw calls
## sharing a font atlas). Spamming hits never exceeds the cap.
func test_number_peak_bounded_by_pool() -> void:
	var c := _make()
	assert_lte(F.MAX_CONCURRENT_DAMAGE_NUMBERS, 16, "AC-28: pool cap ≤ 16 (draw-call ceiling)")
	for _i in range(40):
		c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT))
	assert_lte(c._active_numbers.size(), F.MAX_CONCURRENT_DAMAGE_NUMBERS,
		"AC-28: 40 hits never exceed the 12-number cap (≤16 draw calls)")


## AC-28: overlay is single-instance — at most one ColorRect, so ≤1 full-screen blend pass.
func test_overlay_at_most_one_blend_pass() -> void:
	var c := _make()
	for _i in range(8):
		c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT))
	assert_eq(c._overlay_layer.get_child_count(), 1, "AC-28: exactly one overlay ColorRect (≤1 blend pass)")


## AC-28: IDLE overlay is zero per-frame cost — _tick_overlay short-circuits, leaving the
## rect untouched (no alpha writes while idle).
func test_idle_overlay_zero_cost() -> void:
	var c := _make()
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "starts IDLE")
	c._overlay_rect.color.a = 0.123  # sentinel — IDLE tick must not touch it
	c._process(0.016)
	assert_almost_eq(c._overlay_rect.color.a, 0.123, 0.0001, "AC-28: IDLE tick leaves overlay untouched (zero cost)")


## AC-28 (hardware slice): mobile Safari P95 ≤ 16.6ms is VS-tier-gated — honest skip.
func test_ac28_mobile_p95_is_hardware_gated() -> void:
	pending("VS-tier: real mobile Safari P95 ≤16.6ms profiling on target hardware (ADR-0001 ratification)")
