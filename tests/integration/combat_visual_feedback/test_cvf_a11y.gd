extends GutTest
## Story 013: CombatVisualFeedback (#25) accessibility — motion_intensity gate +
## input non-interference + WCAG 2.3.1 structural. AC-25 / UX-04 / UX-06.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")


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


## FakeScreenFx exposes get_motion_intensity so the a11y gate is test-controllable.
class FakeScreenFx:
	extends RefCounted
	var pauses: Array = []
	var motion: float = 1.0
	func hit_pause(d: float) -> void:
		pauses.append(d)
	func get_motion_intensity() -> float:
		return motion


var _tid := 0

func _make(motion: float) -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	var fx := FakeScreenFx.new()
	fx.motion = motion
	c._screen_fx = fx
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = true
	return c


func _critical():
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = CombatResolver.DamageTier.CRITICAL
	p.outcome = CombatResolver.HitOutcome.CRITICAL_HIT
	p.damage_dealt = 99
	_tid += 1
	p.transition_id = "t%d" % _tid
	p.target_id = _tid
	return p


# --- Tests --------------------------------------------------------------------

## AC-25 / UX-04: motion_intensity==0 → overlay effective opacity 0 (no visible flash)
## BUT hit_pause STILL fires (visual freeze ≠ vestibular — a11y doc §2).
func test_motion_zero_kills_flash_but_keeps_hit_pause() -> void:
	var c := _make(0.0)
	c._on_hit_resolved(_critical())
	assert_almost_eq(c._overlay_rect.color.a, 0.0, 0.0001, "AC-25: motion_intensity=0 → effective opacity 0")
	assert_eq(c._screen_fx.pauses.size(), 1, "UX-04: hit_pause STILL fires at motion 0")
	assert_almost_eq(c._screen_fx.pauses[0], 0.080, 0.0001, "UX-04: hit_pause unscaled (0.080)")


## motion_intensity scales the flash opacity proportionally.
func test_motion_half_scales_flash_opacity() -> void:
	var c := _make(0.5)
	c._on_hit_resolved(_critical())
	# CRITICAL peak 0.35 × 0.5 = 0.175 at t=0
	assert_almost_eq(c._overlay_rect.color.a, 0.175, 0.0001, "flash opacity scaled by motion_intensity 0.5")


## Full motion → full peak opacity.
func test_motion_full_is_peak() -> void:
	var c := _make(1.0)
	c._on_hit_resolved(_critical())
	assert_almost_eq(c._overlay_rect.color.a, 0.35, 0.0001, "motion 1.0 → CRITICAL peak 0.35")


## UX-06: #25 render nodes never consume input (mouse_filter IGNORE) → flash never steals
## the GymSys/HUD one-tap.
func test_render_nodes_never_consume_input() -> void:
	var c := _make(1.0)
	assert_eq(c._overlay_rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "UX-06: overlay ColorRect IGNORE")
	for lbl: Label in c._number_pool:
		assert_eq(lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "UX-06: every pooled number Label IGNORE")


## WCAG 2.3.1 (structural): single-instance latest-wins → only ever one ColorRect, so
## successive climaxes replace rather than compound — >3 flash/sec is impossible.
func test_wcag_single_instance_structural() -> void:
	var c := _make(1.0)
	for _i in range(5):
		c._on_hit_resolved(_critical())
	assert_eq(c._overlay_layer.get_child_count(), 1, "WCAG 2.3.1: exactly one overlay ColorRect (no flash stacking)")
