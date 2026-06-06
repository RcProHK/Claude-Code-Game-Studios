# BossFormulas Formula 1 — boss_max_hp_scaling (Story 003: AC-17 / AC-18 / AC-41 + invariants).
#
# Pure static math — deterministic, no randomness, no time dependency.
extends GutTest


# ---------------------------------------------------------------------------
# AC-17 — worked example
# ---------------------------------------------------------------------------

func test_formula1_worked_example_mid_game() -> void:
	# 200 + 159 * 9 * 1.0 = 1631
	var hp := BossFormulas.compute_max_hp(200, 159.0, 0.0)
	assert_almost_eq(hp, 1631, 1, "AC-17: boss_max_hp == 1631 +/- 1")


# ---------------------------------------------------------------------------
# AC-18 — floor / ceiling clamps
# ---------------------------------------------------------------------------

func test_formula1_ceiling_clamp() -> void:
	# 200 + 4500 * 9 = 40700 -> clamped to MAX_BOSS_HP
	var hp := BossFormulas.compute_max_hp(200, 4500.0, 0.0)
	assert_eq(hp, BossFormulas.MAX_BOSS_HP, "AC-18: ceiling clamp to MAX_BOSS_HP (10000)")


func test_formula1_floor_clamp_test_only_base_hp() -> void:
	# TEST-ONLY synthetic base_hp=1 (defensive future-config guard): 1 + 1*9 = 10 < 50
	var hp := BossFormulas.compute_max_hp(1, 1.0, 0.0)
	assert_eq(hp, BossFormulas.MIN_BOSS_HP, "AC-18: floor clamp up to MIN_BOSS_HP (50)")


# ---------------------------------------------------------------------------
# AC-41 — first-session bootstrap ramp (effective_atk intermediate)
# ---------------------------------------------------------------------------

func test_ac41_effective_atk_zero_duration_is_bootstrap_floor() -> void:
	assert_eq(BossFormulas.compute_effective_atk(0.0, 0.0), 10.0,
		"AC-41(a): duration 0 -> effective_atk == BOOTSTRAP_ATTACK_POWER 10")


func test_ac41_effective_atk_half_ramp() -> void:
	# 300/600 = 0.5 -> max(10, 0.5*28=14) = 14
	assert_eq(BossFormulas.compute_effective_atk(0.0, 300.0), 14.0,
		"AC-41(b): duration 300 -> effective_atk == 14")


func test_ac41_effective_atk_full_ramp() -> void:
	assert_eq(BossFormulas.compute_effective_atk(0.0, 600.0), 28.0,
		"AC-41(c): duration 600 -> effective_atk == FIRST_SESSION_BASELINE_ATK 28")


func test_ac41_effective_atk_ramp_saturates() -> void:
	# 1200/600 clamps to 1.0 -> 28 (does not exceed baseline)
	assert_eq(BossFormulas.compute_effective_atk(0.0, 1200.0), 28.0,
		"AC-41(d): duration 1200 -> ramp saturates at 28")


func test_ac41_nonzero_atk_bypasses_bootstrap() -> void:
	assert_eq(BossFormulas.compute_effective_atk(159.0, 0.0), 159.0,
		"AC-41(f): player_attack_power > 0 returns it unchanged (no bootstrap)")


func test_ac41_bootstrap_hp_bound_by_first_session_cap() -> void:
	# bootstrap: effective_atk=28, raw=200+28*9=452, then capped to 20*9=180
	var hp := BossFormulas.compute_max_hp(200, 0.0, 600.0)
	assert_eq(hp, BossFormulas.FIRST_SESSION_EXPECTED_HIT_DAMAGE * BossFormulas.FIRST_SESSION_KILL_HITS_MAX,
		"AC-41: bootstrap HP bound by first-session cap (180)")
	assert_true(hp >= BossFormulas.MIN_BOSS_HP, "AC-41: cap is floor-safe (>= MIN_BOSS_HP)")


# ---------------------------------------------------------------------------
# Cross-knob invariants (INV-3 / INV-9b / INV-9c) — enforced by construction
# ---------------------------------------------------------------------------

func test_inv3_floor_below_ceiling() -> void:
	assert_lt(BossFormulas.MIN_BOSS_HP, BossFormulas.MAX_BOSS_HP, "INV-3: MIN_BOSS_HP < MAX_BOSS_HP")


func test_inv9b_first_session_window_not_hardest() -> void:
	assert_true(BossFormulas.FIRST_SESSION_KILL_HITS_MAX <= BossFormulas.TARGET_KILL_HITS_FINAL,
		"INV-9b: FIRST_SESSION_KILL_HITS_MAX <= TARGET_KILL_HITS_FINAL (first session never hardest)")


func test_inv9c_cap_above_floor() -> void:
	var cap := BossFormulas.FIRST_SESSION_EXPECTED_HIT_DAMAGE * BossFormulas.FIRST_SESSION_KILL_HITS_MAX
	assert_true(cap >= BossFormulas.MIN_BOSS_HP,
		"INV-9c: first-session cap (EXPECTED_HIT_DAMAGE * KILL_HITS_MAX) >= MIN_BOSS_HP")


# ---------------------------------------------------------------------------
# AC-41(e) — purity static surrogate: BossFormulas cannot emit telemetry
# ---------------------------------------------------------------------------

func test_ac41e_boss_formulas_is_pure_no_telemetry() -> void:
	var src := FileAccess.get_file_as_string("res://src/formulas/boss_formulas.gd")
	assert_false(src.is_empty(), "boss_formulas.gd must be readable")
	# Strip full-line `#` comments first — the doc-comment block legitimately
	# NAMES `_emit_telemetry` / `BossSystem` in prose; the purity guarantee is
	# about CODE, not comments (comment-sweep phantom-pass guard).
	var code_lines := PackedStringArray()
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var code := "\n".join(code_lines)
	assert_eq(code.count("_emit_telemetry"), 0,
		"AC-41(e): boss_formulas.gd code contains 0 _emit_telemetry references (pure)")
	assert_eq(code.count("BossSystem"), 0,
		"AC-41(e): boss_formulas.gd code contains 0 BossSystem references (pure static helper)")
