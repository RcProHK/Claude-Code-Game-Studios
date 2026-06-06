# BossInstance snapshot freeze / CF-3 caching (Story 009: AC-05 / AC-22 / AC-36).
#
# The boss reads ONLY its frozen BossSpawnContext (computed once at _ready) —
# never live StatSystem. Mid-fight stat mutations cannot affect the boss.
extends GutTest


func _make_boss(base_hp: int, ctx: BossSpawnContext) -> BossInstance:
	var boss := BossInstance.new()
	for cn in ["AnimationPlayer", "CollisionShape2D", "Sprite2D", "HitArea2D"]:
		var n: Node
		match cn:
			"AnimationPlayer": n = AnimationPlayer.new()
			"CollisionShape2D": n = CollisionShape2D.new()
			"Sprite2D": n = Sprite2D.new()
			"HitArea2D": n = Area2D.new()
		n.name = cn
		boss.add_child(n)
	var t := BossTemplate.new()
	t.base_hp = base_hp
	boss.boss_template = t
	boss.transition_id = "txn"
	boss.player_stat_snapshot = ctx
	return boss


func _ctx(atk: float, max_hp: int) -> BossSpawnContext:
	var c := BossSpawnContext.new()
	c.attack_power = atk
	c.max_hp = max_hp
	return c


# ---------------------------------------------------------------------------
# AC-05 — max_hp derived from the frozen snapshot
# ---------------------------------------------------------------------------

func test_max_hp_derived_from_frozen_snapshot() -> void:
	var ctx := _ctx(159.0, 200)
	var boss := _make_boss(200, ctx)
	add_child_autofree(boss)  # _ready computes max_hp from the ctx
	assert_eq(boss.max_hp, 1631, "AC-05: max_hp == compute_max_hp(200, ctx.attack_power 159, 0)")


func test_ac22_snapshot_identity_preserved() -> void:
	var ctx := _ctx(159.0, 200)
	var boss := _make_boss(200, ctx)
	add_child_autofree(boss)
	# CI-1/CI-2 / AC-22: the boss holds the EXACT context object passed (single source).
	assert_true(is_same(boss.player_stat_snapshot, ctx),
		"AC-22: boss.player_stat_snapshot is the same object both formulas read")


# ---------------------------------------------------------------------------
# AC-36 — mid-fight stat change cannot alter the boss (frozen)
# ---------------------------------------------------------------------------

func test_ac36_mid_fight_ctx_mutation_does_not_change_max_hp() -> void:
	var ctx := _ctx(159.0, 200)
	var boss := _make_boss(200, ctx)
	add_child_autofree(boss)
	var frozen_max_hp := boss.max_hp  # 1631
	# Simulate a mid-fight stat spike on the (supposedly frozen) source.
	ctx.attack_power = 9999.0
	assert_eq(boss.max_hp, frozen_max_hp,
		"AC-36: max_hp is computed ONCE at _ready (cached) — a later stat change does not re-derive it")


# ---------------------------------------------------------------------------
# CF-3 static — the boss never live-queries StatSystem
# ---------------------------------------------------------------------------

func test_cf3_boss_instance_never_queries_statsystem_live() -> void:
	var src := FileAccess.get_file_as_string("res://src/gameplay/boss_instance.gd")
	assert_false(src.is_empty(), "boss_instance.gd readable")
	var code_lines := PackedStringArray()
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var code := "\n".join(code_lines)
	assert_eq(code.count("StatSystem.get_"), 0,
		"CF-3: boss_instance.gd never calls StatSystem.get_* (reads frozen BossSpawnContext only)")
