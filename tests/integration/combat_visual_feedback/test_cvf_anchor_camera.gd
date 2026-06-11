extends GutTest
## Story 011: CombatVisualFeedback (#25) anchor camera-relative focal — AC-18 + EC-10/19.
## #26 has no anchor API (render-only) so the focal is purely camera-relative; no crash
## when no camera is mounted (EC-19 = the MVP normal state, not a degraded fallback).

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
	var plays: Array = []
	func play(_p: int, pos: Vector2, _m: float = 1.0):
		plays.append(pos)
		return null


class FakeScreenFx:
	extends RefCounted
	func hit_pause(_d: float) -> void:
		pass


func _make() -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()  # #26 render-only; no anchor API queried (EC-10)
	add_child_autofree(c)
	c.set_process(false)
	return c


func _light():
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = CombatResolver.DamageTier.LIGHT
	p.outcome = CombatResolver.HitOutcome.NORMAL_HIT
	p.transition_id = "a"
	p.target_id = 1
	p.damage_dealt = 5
	return p


# --- Tests --------------------------------------------------------------------

## EC-19 / EC-10: no active camera → screen-centre world default, finite Vector2, no crash.
func test_focal_without_camera_is_finite_no_crash() -> void:
	var c := _make()
	var focal: Vector2 = c._camera_relative_focal()
	assert_true(is_finite(focal.x) and is_finite(focal.y), "EC-19: focal is a finite Vector2 with no camera")


## AC-18: routing a hit with no #26 anchor API + no camera spawns the particle at a
## finite focal point and never crashes (the MVP camera-relative path is self-sufficient).
func test_route_hit_spawns_at_finite_focal_no_crash() -> void:
	var c := _make()
	c._on_hit_resolved(_light())
	assert_eq(c._particles.plays.size(), 1, "AC-18: particle spawned")
	var pos: Vector2 = c._particles.plays[0]
	assert_true(is_finite(pos.x) and is_finite(pos.y), "AC-18: spawn position is finite (no crash, no NaN)")


## #26 is never queried for an anchor (render-only, ADR-0010) — a bare RefCounted #26
## with no get_render_anchor() must not break routing (EC-10 grep proof).
func test_avatar_anchor_never_queried() -> void:
	var c := _make()
	# _avatar has no get_render_anchor; if the code queried it this would crash.
	c._on_hit_resolved(_light())
	assert_eq(c._particles.plays.size(), 1, "EC-10: routing works without any #26 anchor API")
