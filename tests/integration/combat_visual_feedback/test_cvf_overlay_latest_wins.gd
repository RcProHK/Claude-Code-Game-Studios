extends GutTest
## Story 010: CombatVisualFeedback (#25) overlay primitive — latest-wins single-instance
## + IDLE zero-cost + EC-20 degrade + AC-24 ratification-gated honesty.

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


func _make(overlay_enabled: bool = true) -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = overlay_enabled
	return c


var _tid_seq: int = 0

func _hit(tier: int, outcome: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.damage_dealt = 50
	_tid_seq += 1
	p.transition_id = "t%d" % _tid_seq  # distinct so dedup never blocks separate hits
	p.target_id = _tid_seq
	return p


# --- Tests --------------------------------------------------------------------

func test_overlay_host_built_at_105() -> void:
	var c := _make()
	assert_not_null(c._overlay_rect, "CombatOverlayLayer ColorRect host built")
	assert_eq(c._overlay_layer.layer, c.OVERLAY_LAYER, "overlay layer == 105 (>100 immune)")
	assert_false(c._overlay_rect.visible, "pre-warmed hidden (IDLE zero-cost)")


## AC-23: a new climax (OVERKILL) replaces the in-flight CRITICAL flash — still ONE
## active overlay, t reset, OVERKILL opacity/duration adopted (latest-wins).
func test_latest_wins_overkill_replaces_critical() -> void:
	var c := _make(true)
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT))
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "CRITICAL flash active")
	assert_almost_eq(c._overlay_max_opacity, 0.35, 0.0001, "CRITICAL opacity 0.35")
	c._process(0.05)
	assert_gt(c._overlay_t, 0.0, "CRITICAL flash advanced")

	# A more violent climax mid-flash:
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.HEAVY, CombatResolver.HitOutcome.OVERKILL))
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "still flashing (single instance)")
	assert_almost_eq(c._overlay_t, 0.0, 0.0001, "AC-23: latest-wins resets t=0")
	assert_almost_eq(c._overlay_max_opacity, 0.6, 0.0001, "AC-23: adopts OVERKILL opacity 0.6")
	assert_almost_eq(c._overlay_duration, F.OVERKILL_FLASH_DURATION_SEC, 0.0001, "AC-23: adopts OVERKILL duration 0.12")
	# Only one ColorRect ever exists — no stacking (≤1 blend pass).
	assert_eq(c._overlay_layer.get_child_count(), 1, "exactly one overlay ColorRect (no stacking)")


## Formula 2 applied by _process; flash returns to IDLE (hidden) at duration end.
func test_overlay_decays_to_idle() -> void:
	var c := _make(true)
	c._request_flash(c.FlashKind.OVERKILL)  # 0.6 / 0.12s
	assert_true(c._overlay_rect.visible, "flash visible on enter")
	for _i in range(2):
		c._process(0.1)  # → t≈0.2 > 0.12 → IDLE
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "decayed to IDLE")
	assert_false(c._overlay_rect.visible, "overlay hidden in IDLE (zero per-frame cost)")


## EC-20 / AC-07b: overlay NOT ratified → CRITICAL hit produces NO flash, no crash.
func test_degrade_no_flash_when_unratified() -> void:
	var c := _make(false)
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT))
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "EC-20 degrade: no flash when unratified")
	assert_false(c._overlay_rect.visible, "overlay stays hidden")


## AC-24 (ratification-gated ADVISORY): the REAL on-screen flash render is gated on the
## ADR-0001 CombatOverlayLayer amendment being ratified. Honest skip — never assert-true.
func test_ac24_real_flash_render_is_ratification_gated() -> void:
	pending("ratification-gated: ADR-0001 CombatOverlayLayer amendment — real flash render verified at VS-tier on hardware")
