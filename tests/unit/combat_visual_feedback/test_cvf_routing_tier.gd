extends GutTest
## Story 004: CombatVisualFeedback (#25) tier routing core — R-2/R-3/R-4/R-5/R-6 + EC-18.
##
## FR Test #4 (AC-02, MUST-NOT-REGRESS): routing key is ALWAYS payload.damage_tier; the
## preset must NEVER be re-derived from damage_dealt/damage_raw. Spies #5 play() preset arg
## + #6 hit_pause count + the #25 number-spawn counter. Fully injected fakes (no autoload).

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")
const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


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
	var plays: Array = []
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0):
		plays.append({"preset": preset_id, "pos": position, "mult": multiplier})
		return null


class FakeScreenFx:
	extends RefCounted
	var pauses: Array = []
	func hit_pause(duration: float) -> void:
		pauses.append(duration)


# --- Helpers ------------------------------------------------------------------

func _make() -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return c


func _hit(tier: int, dealt: int, outcome: int = -1, crit: bool = false):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.damage_dealt = dealt
	p.outcome = outcome if outcome >= 0 else CombatResolver.HitOutcome.NORMAL_HIT
	p.is_crit = crit
	return p


# --- Tests --------------------------------------------------------------------

## AC-02 (FR Test #4): tier=HEAVY but damage_dealt=1 (tier/value contradict) → HIT_HEAVY.
## The preset follows the TIER, never a value re-classification.
func test_fr_test4_heavy_tier_low_value_routes_hit_heavy() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.HEAVY, 1))
	assert_eq(c._particles.plays.size(), 1, "AC-02: HEAVY routes one particle")
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_HEAVY,
		"AC-02 FR Test #4: damage_tier=HEAVY → HIT_HEAVY even when damage_dealt=1")


## AC-02 edge: huge value but tier=LIGHT → still HIT_LIGHT (value never upgrades the preset).
func test_fr_test4_light_tier_high_value_routes_hit_light() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, 999))
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_LIGHT,
		"AC-02 FR Test #4: damage_tier=LIGHT → HIT_LIGHT even when damage_dealt=999")


## AC-03: NEGLIGIBLE non-kill → zero reaction (no play, no pause, no number).
func test_negligible_zero_reaction() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.NEGLIGIBLE, 0))
	assert_eq(c._particles.plays.size(), 0, "AC-03: no particle for NEGLIGIBLE")
	assert_eq(c._screen_fx.pauses.size(), 0, "AC-03: no hit_pause for NEGLIGIBLE")
	assert_eq(c._numbers_spawned, 0, "AC-03: no damage number for NEGLIGIBLE")


## AC-04: LIGHT → play(HIT_LIGHT) ×1 + number ×1 + hit_pause ×0.
func test_light_plays_hit_light_no_pause() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, 5))
	assert_eq(c._particles.plays.size(), 1, "AC-04: one particle")
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_LIGHT, "AC-04: HIT_LIGHT")
	assert_eq(c._numbers_spawned, 1, "AC-04: one damage number")
	assert_eq(c._screen_fx.pauses.size(), 0, "AC-04: no hit_pause for LIGHT")


## AC-05: MEDIUM shares HIT_LIGHT (NOT HIT_HEAVY) + no pause (MVP Q1 decision A).
func test_medium_shares_hit_light_not_heavy() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.MEDIUM, 50))
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_LIGHT,
		"AC-05: MEDIUM uses HIT_LIGHT, not HIT_HEAVY (tier distinction is number style only)")
	assert_eq(c._screen_fx.pauses.size(), 0, "AC-05: no hit_pause for MEDIUM")
	assert_eq(c._numbers_spawned, 1, "AC-05: one damage number")


## EC-18: damage_dealt ≤ 0 but tier ≠ NEGLIGIBLE → trust the tier (don't second-guess value).
func test_ec18_zero_value_nonzero_tier_trusts_tier() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, 0))
	assert_eq(c._particles.plays.size(), 1, "EC-18: LIGHT tier reacts even at damage_dealt=0")
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_LIGHT, "EC-18: trusts tier")
