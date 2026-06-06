# AvatarDownedGuard — invincible-avatar enforcement (Story 013: EC-25 / AC-45 a-f).
extends GutTest


# ---------------------------------------------------------------------------
# AC-45 (a) — NO game-over / death / retry API exists
# ---------------------------------------------------------------------------

func test_ac45a_no_game_over_signals_exist() -> void:
	var g := AvatarDownedGuard.new(100)
	var sig_names: Array = g.get_signal_list().map(func(s): return String(s["name"]))
	for forbidden in ["game_over", "death", "retry", "player_died", "defeat"]:
		assert_false(sig_names.has(forbidden),
			"AC-45(a): AvatarDownedGuard exposes NO '%s' signal (no game-over — Pillar 2)" % forbidden)
	assert_true(sig_names.has("avatar_downed"), "the only down-related signal is avatar_downed")


# ---------------------------------------------------------------------------
# AC-45 (b) / (e) — auto-recover + telemetry signal
# ---------------------------------------------------------------------------

func test_ac45b_recovers_to_fraction_of_max() -> void:
	var g := AvatarDownedGuard.new(100)
	watch_signals(g)
	g.apply_boss_damage(200)  # HP 100 -> 0
	assert_eq(g.avatar_current_hp, 25, "AC-45(b): auto-recover to round(0.25 * 100) = 25")
	assert_eq(g.downed_count, 1, "downed once")
	assert_signal_emitted(g, "avatar_downed", "AC-45(e): avatar_downed signal emitted")


func test_ac45b_degenerate_max_hp_one_recovers_to_one() -> void:
	var g := AvatarDownedGuard.new(1)
	g.apply_boss_damage(5)  # one-shot on a 1-HP avatar
	assert_eq(g.avatar_current_hp, 1, "AC-45(b): max(1, round(0.25*1)) = 1 (never stays at 0)")


# ---------------------------------------------------------------------------
# AC-45 (f) — grace window suppresses the immediate re-down flicker
# ---------------------------------------------------------------------------

func test_ac45f_grace_window_prevents_instant_re_down() -> void:
	var g := AvatarDownedGuard.new(1)
	var seq := [0.0, 0.3, 0.7]   # 3 apply calls; grace window = 0.6s after the first down
	var i := [0]
	g._now_provider = func() -> float:
		var v: float = seq[i[0]]
		i[0] += 1
		return v
	# t=0: one-shot -> down -> recover to 1 -> grace until 0.6
	g.apply_boss_damage(5)
	assert_eq(g.downed_count, 1, "downed at t=0")
	# t=0.3 (within grace): damage suppressed -> NO re-down flicker
	g.apply_boss_damage(5)
	assert_eq(g.avatar_current_hp, 1, "AC-45(f): within grace -> HP stays 1 (damage suppressed)")
	assert_eq(g.downed_count, 1, "AC-45(f): no re-down during the grace window (no flicker)")
	# t=0.7 (past grace): damage applies again -> a NEW down (allowed)
	g.apply_boss_damage(5)
	assert_eq(g.downed_count, 2, "after grace elapses, a fresh hit can down again")


# ---------------------------------------------------------------------------
# AC-45 (c)/(d) — the guard touches neither boss state nor loot (architectural)
# ---------------------------------------------------------------------------

func test_ac45cd_guard_has_no_boss_or_loot_coupling() -> void:
	var g := AvatarDownedGuard.new(100)
	# The guard owns ONLY avatar HP + downed state — it has no boss/loot reference,
	# so a down can never set the boss to DYING (c) or affect loot (d).
	for forbidden_member in ["boss", "boss_instance", "loot", "enter_dying", "_enter_state"]:
		assert_false(forbidden_member in g,
			"AC-45(c/d): no '%s' coupling — avatar-down never touches boss/loot" % forbidden_member)


func test_normal_damage_below_zero_does_not_down() -> void:
	var g := AvatarDownedGuard.new(100)
	g.apply_boss_damage(30)
	assert_eq(g.avatar_current_hp, 70, "non-lethal damage just lowers HP")
	assert_eq(g.downed_count, 0, "not downed")
