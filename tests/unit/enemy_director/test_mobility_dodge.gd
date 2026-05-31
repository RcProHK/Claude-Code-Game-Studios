# EnemyDirector — Story 014 MOBILITY dodge sidestep (Formula 2 / INV-8).
extends GutTest

const EAS = EnemyDirector.EnemyAIState
const TX := "TX-mob-001"


func _make_mobility_enemy() -> Enemy:
	var e := Enemy.new()
	add_child_autofree(e)
	e.set_physics_process(false)
	e.setup_locomotion(280.0, -1, true, TX)  # MOBILITY move speed, dodge enabled
	e._ai_state = EAS.PURSUING
	return e


# ---------------------------------------------------------------------------
# Dodge offset bounds + determinism (INV-8)
# ---------------------------------------------------------------------------

func test_dodge_offset_within_amplitude_after_interval() -> void:
	var e := _make_mobility_enemy()
	e.call("_tick_dodge", EnemyDirector.DODGE_INTERVAL_SEC)  # exactly one interval → re-roll
	assert_between(e.dodge_offset_x,
		-EnemyDirector.DODGE_AMPLITUDE_PX, EnemyDirector.DODGE_AMPLITUDE_PX,
		"dodge offset within ±DODGE_AMPLITUDE_PX (30)")


func test_dodge_offset_is_deterministic_for_seed() -> void:
	var e := _make_mobility_enemy()
	# Expected = the first draw of an independent sub-stream keyed by this instance.
	var expected_rng := EnemyDirector.RNGFactory.create_sub(TX, "dodge_%d" % e.get_instance_id())
	var expected := expected_rng.randf_range(-EnemyDirector.DODGE_AMPLITUDE_PX, EnemyDirector.DODGE_AMPLITUDE_PX)
	e.call("_tick_dodge", EnemyDirector.DODGE_INTERVAL_SEC)
	assert_almost_eq(e.dodge_offset_x, expected, 0.0001,
		"dodge offset == deterministic create_sub(transition_id, dodge_{id}) first draw")


## No dodge before the interval elapses.
func test_dodge_no_roll_before_interval() -> void:
	var e := _make_mobility_enemy()
	e.call("_tick_dodge", EnemyDirector.DODGE_INTERVAL_SEC - 0.1)
	assert_almost_eq(e.dodge_offset_x, 0.0, 0.0001, "no dodge re-roll before the interval")


## Dodge only applies while PURSUING.
func test_dodge_only_when_pursuing() -> void:
	var e := _make_mobility_enemy()
	e._ai_state = EAS.IDLE
	e.call("_tick_dodge", EnemyDirector.DODGE_INTERVAL_SEC * 2.0)
	assert_almost_eq(e.dodge_offset_x, 0.0, 0.0001, "no dodge while not PURSUING")


## Non-MOBILITY enemies never dodge.
func test_non_mobility_does_not_dodge() -> void:
	var e := Enemy.new()
	add_child_autofree(e)
	e.set_physics_process(false)
	e.setup_locomotion(120.0, -1, false, TX)  # STRIKE — not mobility
	e._ai_state = EAS.PURSUING
	e.call("_tick_dodge", EnemyDirector.DODGE_INTERVAL_SEC * 2.0)
	assert_almost_eq(e.dodge_offset_x, 0.0, 0.0001, "non-MOBILITY enemy never dodges")


## INV-8 static invariant: a full dodge swing stays inside melee range.
func test_inv8_dodge_swing_within_melee_range() -> void:
	assert_lt(EnemyDirector.DODGE_AMPLITUDE_PX * 2.0, EnemyDirector.MELEE_RANGE,
		"INV-8: DODGE_AMPLITUDE_PX×2 (60) < MELEE_RANGE (80)")
