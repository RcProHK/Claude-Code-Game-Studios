extends GutTest
## Story 008: CombatVisualFeedback (#25) R-14 dedup + R-15 coalescing (Formula 3) +
## enemy_killed eviction. AC-13 / AC-14 / AC-31 + EC-03 + F3 first-hit.
##
## Coalescing is time-dependent → injected FakeClock (never the real Time clock, which
## would flake). enemy_killed carries the enemy id in `enemy_instance_id` (grep-verified)
## == hit_resolved.target_id (both = the enemy's instance_id).

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")
const F := preload("res://src/core/combat_visual_feedback_formulas.gd")


# --- Fakes --------------------------------------------------------------------

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
	var plays: int = 0
	func play(_preset_id: int, _position: Vector2, _multiplier: float = 1.0):
		plays += 1
		return null


class FakeScreenFx:
	extends RefCounted
	func hit_pause(_duration: float) -> void:
		pass


class FakeClock:
	extends RefCounted
	var ms: int = 0
	func now_ms() -> int:
		return ms


# --- Helpers ------------------------------------------------------------------

func _make(clock: FakeClock) -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._clock = clock
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return c


func _hit(tier: int, outcome: int, tid: String, target: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.transition_id = tid
	p.target_id = target
	return p


func _kill(enemy_id: int, tid: String):
	var p := EnemyKilledPayload.new()
	p.enemy_instance_id = enemy_id
	p.transition_id = tid
	return p


# --- Tests --------------------------------------------------------------------

## AC-13: one logical kill fires hit_resolved(KILLED) + enemy_killed for the same
## (transition_id, target) → number spawns EXACTLY once (enemy_killed is non-visual).
func test_dedup_kill_plus_enemy_killed_spawns_one_number() -> void:
	var c := _make(FakeClock.new())
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.MEDIUM, CombatResolver.HitOutcome.KILLED, "X", 7))
	c._on_enemy_killed(_kill(7, "X"))
	assert_eq(c._numbers_spawned, 1, "AC-13: exactly one number (enemy_killed is non-visual)")


## AC-14 + EC-03: two hits on the same target within the coalesce window → ONE particle
## (2nd coalesced) but TWO numbers (number is not gated). A third hit past the window fires again.
func test_coalesce_suppresses_second_particle_not_number() -> void:
	var clock := FakeClock.new()
	var c := _make(clock)

	clock.ms = 0
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT, "t1", 5))
	clock.ms = 120  # < HIT_PARTICLE_COALESCE_MS (200)
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT, "t2", 5))

	assert_eq(c._particles.plays, 1, "AC-14: second hit within window → particle coalesced (play==1)")
	assert_eq(c._numbers_spawned, 2, "AC-14/EC-03: number is not gated by coalescing (number==2)")

	clock.ms = 210  # past the window relative to the t=0 record
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT, "t3", 5))
	assert_eq(c._particles.plays, 2, "AC-14: third hit past window → particle fires again (play==2)")


## F3 first-hit: a brand-new target (no dict entry) always emits (int-clean `not has()`).
func test_first_hit_always_emits_particle() -> void:
	var c := _make(FakeClock.new())
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT, "a", 99))
	assert_eq(c._particles.plays, 1, "F3: first hit on a fresh target always fires a particle")


## AC-31 (leak guard): enemy_killed evicts the target from _last_particle_ms AND _seen.
func test_enemy_killed_evicts_per_target_state() -> void:
	var c := _make(FakeClock.new())
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, CombatResolver.HitOutcome.NORMAL_HIT, "z", 7))
	assert_true(c._last_particle_ms.has(7), "precondition: target 7 recorded in coalesce dict")
	assert_true(c._seen.has("z|7"), "precondition: (z,7) recorded in dedup set")

	c._on_enemy_killed(_kill(7, "z"))
	assert_false(c._last_particle_ms.has(7), "AC-31: enemy_killed erases target 7 from _last_particle_ms")
	assert_false(c._seen.has("z|7"), "AC-31: enemy_killed clears target 7's dedup entry")


## Coalesce knob sanity: the gated interval is the documented 200ms (alignment with #5).
func test_coalesce_knob_is_200ms() -> void:
	assert_eq(F.HIT_PARTICLE_COALESCE_MS, 200, "HIT_PARTICLE_COALESCE_MS = 200 (R-15 / #5 EVICTION_MIN_LIFE_MS align)")
