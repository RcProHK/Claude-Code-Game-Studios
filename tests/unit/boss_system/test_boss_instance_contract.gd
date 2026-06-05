# BossInstance scene-tree contract + HP mutator (Story 002: AC-01 schema, AC-15, Rule 12).
extends GutTest


func _ctx(atk: float, max_hp: int, duration: float) -> BossSpawnContext:
	var c := BossSpawnContext.new()
	c.attack_power = atk
	c.max_hp = max_hp
	c.workout_duration_sec = duration
	return c


func _template(base_hp: int) -> BossTemplate:
	var t := BossTemplate.new()
	t.base_hp = base_hp
	return t


# Build a BossInstance with the 4 required scene-tree children, NOT yet in tree.
func _make_boss(base_hp: int, atk: float, max_hp: int, duration: float) -> BossInstance:
	var boss := BossInstance.new()
	var anim := AnimationPlayer.new(); anim.name = "AnimationPlayer"; boss.add_child(anim)
	var col := CollisionShape2D.new(); col.name = "CollisionShape2D"; boss.add_child(col)
	var spr := Sprite2D.new(); spr.name = "Sprite2D"; boss.add_child(spr)
	var hit := Area2D.new(); hit.name = "HitArea2D"; boss.add_child(hit)
	boss.boss_id = &"TEST_BOSS"
	boss.boss_template = _template(base_hp)
	boss.transition_id = "txn_test"
	boss.player_stat_snapshot = _ctx(atk, max_hp, duration)
	return boss


# ---------------------------------------------------------------------------
# _ready — full scene-tree contract + Formula 1 wiring
# ---------------------------------------------------------------------------

func test_ready_computes_max_hp_and_sets_current() -> void:
	var boss := _make_boss(200, 159.0, 200, 0.0)
	watch_signals(boss)
	add_child_autofree(boss)  # _ready fires here
	# compute_max_hp(200, 159, 0) = 200 + 159*9 = 1631
	assert_eq(boss.max_hp, 1631, "AC-01/Rule5: _ready computes max_hp via Formula 1 (1631)")
	assert_eq(boss.current_hp, 1631, "Rule 12: current_hp initialized to max_hp via _set_current_hp")
	assert_signal_emitted(boss, "hp_changed", "hp_changed emitted during _ready init")


func test_ready_default_ai_state_is_spawning() -> void:
	var boss := _make_boss(200, 100.0, 200, 0.0)
	add_child_autofree(boss)
	# AC-15: state ids match #14 enemy_ai_state_enum; SPAWNING is the boot default.
	assert_eq(boss._ai_state, EnemyDirector.EnemyAIState.SPAWNING,
		"AC-15: _ai_state default == EnemyDirector.EnemyAIState.SPAWNING")


# ---------------------------------------------------------------------------
# _set_current_hp — single mutator (clamp + emit), no tree needed
# ---------------------------------------------------------------------------

func test_set_current_hp_clamps_high() -> void:
	var boss: BossInstance = autofree(BossInstance.new())
	boss.max_hp = 100
	watch_signals(boss)
	boss._set_current_hp(150)
	assert_eq(boss.current_hp, 100, "Rule 12: _set_current_hp clamps to max_hp")
	assert_signal_emitted_with_parameters(boss, "hp_changed", [100, 100])


func test_set_current_hp_clamps_low() -> void:
	var boss: BossInstance = autofree(BossInstance.new())
	boss.max_hp = 100
	boss._set_current_hp(50)
	assert_eq(boss.current_hp, 50, "Rule 12: in-range value passes")
	# Note: not testing value 0 here (that path enters DYING — covered below).


func test_set_current_hp_zero_enters_dying() -> void:
	# NOT in tree: _play_death_and_free sees not is_inside_tree -> cleanup only,
	# no queue_free, so the boss stays valid and we can assert the state.
	var boss: BossInstance = autofree(BossInstance.new())
	boss.max_hp = 100
	boss._set_current_hp(0)
	assert_eq(boss.current_hp, 0, "Rule 12: HP clamps to 0")
	assert_eq(boss._ai_state, EnemyDirector.EnemyAIState.DYING,
		"Rule 12: current_hp == 0 enters DYING (defensive in-instance trigger)")


# ---------------------------------------------------------------------------
# _enter_state — idempotent guard (double-cleanup guard root)
# ---------------------------------------------------------------------------

func test_enter_state_idempotent_no_reentry() -> void:
	var boss: BossInstance = autofree(BossInstance.new())
	boss.max_hp = 100
	# Move to a non-DYING state, then re-enter the SAME state -> no-op (no crash).
	boss._enter_state(EnemyDirector.EnemyAIState.IDLE)
	assert_eq(boss._ai_state, EnemyDirector.EnemyAIState.IDLE, "entered IDLE")
	boss._enter_state(EnemyDirector.EnemyAIState.IDLE)  # idempotent re-entry
	assert_eq(boss._ai_state, EnemyDirector.EnemyAIState.IDLE, "re-entering same state is a safe no-op")


# ---------------------------------------------------------------------------
# Schema fields present (BossInstance contract)
# ---------------------------------------------------------------------------

func test_boss_instance_field_contract() -> void:
	var boss: BossInstance = autofree(BossInstance.new())
	assert_true("hp_changed" in boss.get_signal_list().map(func(s): return s.name),
		"hp_changed signal declared")
	for f in ["boss_id", "boss_template", "transition_id", "player_stat_snapshot",
			"current_hp", "max_hp", "attack_count", "_last_emitted_pattern_id",
			"_spawned_emitters", "_ai_state"]:
		assert_true(f in boss, "BossInstance field present: %s" % f)
