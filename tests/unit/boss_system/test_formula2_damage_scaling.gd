# BossFormulas Formula 2 — boss_attack_damage_scaling (Story 004: AC-19 + CF-2 + EC-06).
#
# Pure static math. Formula 2 is a REAL #13 damage input; the clamp is a
# texture/anti-downed-flicker guard, NOT a survival one-shot guard (avatar is
# invincible per EC-25). player_max_hp is an explicit scalar (not in StatSnapshot).
extends GutTest


# ---------------------------------------------------------------------------
# AC-19 — anti-downed-flicker / texture-guard ceiling
# ---------------------------------------------------------------------------

func test_ac19_signature_pattern_clamped_to_half_max_hp() -> void:
	# raw = round(200 * 0.28 * 2.5) = 140; ceiling = floor(200 * 0.5) = 100
	var dmg := BossFormulas.compute_attack_damage(200, 2.5)
	assert_eq(dmg, 100, "AC-19: clamped to floor(player_max_hp * 0.5) = 100")
	assert_true(dmg <= int(200 * 0.5), "AC-19: never exceeds 50% of player_max_hp")


func test_formula2_standard_pattern_unclamped() -> void:
	# raw = round(200 * 0.28 * 1.0) = 56; ceiling 100 -> 56 (no clamp)
	var dmg := BossFormulas.compute_attack_damage(200, 1.0)
	assert_eq(dmg, 56, "standard pattern: 56 (28% of 200, below ceiling)")


# ---------------------------------------------------------------------------
# EC-06 / CRIT-6 — degenerate low player_max_hp clamp-inversion guard
# ---------------------------------------------------------------------------

func test_ec06_degenerate_max_hp_clamps_to_min_damage() -> void:
	# player_max_hp=4: floor(4*0.5)=2 < MIN_BOSS_DAMAGE 5 -> ceiling lifted to 5;
	# raw=round(4*0.28)=1 -> clampi(1, 5, 5) = 5
	var dmg := BossFormulas.compute_attack_damage(4, 1.0)
	assert_eq(dmg, BossFormulas.MIN_BOSS_DAMAGE,
		"EC-06/CRIT-6: degenerate max_hp -> clamp range [5,5], damage = MIN_BOSS_DAMAGE")


func test_ec06_max_hp_nine_still_min_damage() -> void:
	# floor(9*0.5)=4 < 5 -> ceiling 5; raw=round(9*0.28)=round(2.52)=3 -> 5
	var dmg := BossFormulas.compute_attack_damage(9, 1.0)
	assert_eq(dmg, 5, "EC-06: max_hp=9 boundary still clamps up to MIN_BOSS_DAMAGE")


# ---------------------------------------------------------------------------
# CF-2 / INV-5 — bound never exceeded
# ---------------------------------------------------------------------------

func test_cf2_never_exceeds_dynamic_ceiling() -> void:
	# Sweep a range of player_max_hp x multipliers; assert CF-2 bound holds.
	for max_hp in [1, 10, 50, 200, 1000, 10000]:
		for mult in [0.5, 1.0, 1.5, 2.5]:
			var dmg := BossFormulas.compute_attack_damage(max_hp, mult)
			var bound := maxi(BossFormulas.MIN_BOSS_DAMAGE, int(floor(float(max_hp) * 0.5)))
			assert_true(dmg <= bound,
				"CF-2: dmg(%d, %s)=%d <= max(MIN, floor(max_hp*0.5))=%d" % [max_hp, str(mult), dmg, bound])
			assert_true(dmg >= BossFormulas.MIN_BOSS_DAMAGE, "MIN_BOSS_DAMAGE floor holds")


func test_inv5_damage_ratio_strict_half() -> void:
	assert_true(BossFormulas.MAX_BOSS_DAMAGE_RATIO <= 0.5, "INV-5: MAX_BOSS_DAMAGE_RATIO <= 0.5 STRICT")
