extends GutTest
## Story 012: CombatVisualFeedback (#25) lifecycle — Suspended force-reset + bfcache
## resume clear + delta clamp. AC-16 / AC-17 + EC-08 / EC-09.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")


class FakeEnemyDirector:
	extends RefCounted
	signal hit_resolved(payload)
	signal enemy_killed(payload)


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
	func play(_p: int, _pos: Vector2, _m: float = 1.0):
		return null


class FakeScreenFx:
	extends RefCounted
	func hit_pause(_d: float) -> void:
		pass


var _tid := 0

func _make() -> Array:
	var gsm := FakeGSM.new()
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = gsm
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = true
	return [c, gsm]


func _hit(tier: int, outcome: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.damage_dealt = 50
	_tid += 1
	p.transition_id = "t%d" % _tid
	p.target_id = _tid
	return p


# --- Tests --------------------------------------------------------------------

## AC-16 / EC-08: Suspended mid-flash → overlay OFF + pool released + dicts cleared +
## subsequent signals rejected (no-op + debug counter).
func test_suspended_force_resets_everything() -> void:
	var pair := _make()
	var c: Node = pair[0]
	var gsm = pair[1]

	# Build live residual: a CRITICAL flash + two floating numbers + a coalesce entry.
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT))
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT))
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "precondition: flashing")
	assert_gt(c._active_numbers.size(), 0, "precondition: numbers active")
	assert_gt(c._last_particle_ms.size(), 0, "precondition: coalesce entries")

	gsm.go(FakeGSM.GameState.SUSPENDED)

	assert_eq(c._lifecycle, c.Lifecycle.SUSPENDED, "lifecycle SUSPENDED")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "AC-16: overlay forced OFF")
	assert_false(c._overlay_rect.visible, "AC-16: overlay rect hidden")
	assert_eq(c._active_numbers.size(), 0, "AC-16: number pool fully released")
	assert_eq(c._last_particle_ms.size(), 0, "AC-16: coalescing dict cleared")
	assert_eq(c._seen.size(), 0, "AC-16: dedup set cleared")

	# Subsequent signals are rejected (no-op + counter).
	var before = c._rejected_while_suspended  # untyped: member access on typed Node is Variant
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.HEAVY, CombatResolver.HitOutcome.NORMAL_HIT))
	assert_eq(c._rejected_while_suspended, before + 1, "EC-08: incoming hit rejected while SUSPENDED")
	assert_eq(c._active_numbers.size(), 0, "EC-08: rejected hit spawns nothing")


## Leaving Suspended returns to Active and clears any residual (belt-and-braces).
func test_resume_from_suspended_returns_active_clean() -> void:
	var pair := _make()
	var c: Node = pair[0]
	var gsm = pair[1]
	gsm.go(FakeGSM.GameState.SUSPENDED)
	assert_eq(c._lifecycle, c.Lifecycle.SUSPENDED, "suspended")
	gsm.go(FakeGSM.GameState.IDLE)
	assert_eq(c._lifecycle, c.Lifecycle.ACTIVE, "back to Active")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "no residual flash after resume")
	assert_eq(c._active_numbers.size(), 0, "no residual numbers after resume")


## AC-17: _process clamps a huge resume-frame delta to MAX_FRAME_DELTA (no jump-to-end).
func test_process_clamps_large_resume_delta() -> void:
	var pair := _make()
	var c: Node = pair[0]
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT))
	c._process(0.5)  # bfcache resume frame with a half-second gap
	assert_almost_eq(c._last_clamped_delta, c.MAX_FRAME_DELTA, 0.0001,
		"AC-17: per-frame delta clamped to MAX_FRAME_DELTA (0.1), not 0.5")


## EC-09: bfcache resume notification force-clears latched flash + numbers.
func test_bfcache_notification_force_resets() -> void:
	var pair := _make()
	var c: Node = pair[0]
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT))
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "precondition: latched flash")
	c._notification(c.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "EC-09: resume notification clears flash")
	assert_eq(c._active_numbers.size(), 0, "EC-09: resume notification clears numbers")
