# BossSystem.spawn_boss lifecycle (Story 007: AC-25 / AC-26 / AC-37 / AC-43 + EC-01/02).
extends GutTest


# Build a packable BossInstance scene with the 4 required children (owner-set).
func _boss_scene() -> PackedScene:
	var boss := BossInstance.new()
	boss.name = "BossInstance"
	for child_name in ["AnimationPlayer", "CollisionShape2D", "Sprite2D", "HitArea2D"]:
		var n: Node
		match child_name:
			"AnimationPlayer": n = AnimationPlayer.new()
			"CollisionShape2D": n = CollisionShape2D.new()
			"Sprite2D": n = Sprite2D.new()
			"HitArea2D": n = Area2D.new()
		n.name = child_name
		boss.add_child(n)
		n.owner = boss
	var ps := PackedScene.new()
	ps.pack(boss)
	boss.free()
	return ps


func _template() -> BossTemplate:
	var t := BossTemplate.new()
	t.boss_id = &"TEST_FINAL"
	t.base_hp = 200
	t.boss_scene = _boss_scene()
	return t


func _ctx(atk: float) -> BossSpawnContext:
	var c := BossSpawnContext.new()
	c.attack_power = atk
	c.max_hp = 200
	c.workout_duration_sec = 0.0
	return c


func _system() -> BossSystem:
	var bs := BossSystem.new()
	add_child_autofree(bs)  # in tree so spawn_boss's add_child puts the boss in-tree
	return bs


# ---------------------------------------------------------------------------
# AC-37 — spawn ordering + position persistence + commit signal
# ---------------------------------------------------------------------------

func test_spawn_boss_happy_path() -> void:
	var bs := _system()
	watch_signals(bs)
	var pos := Vector2(800, 300)
	var boss := bs.spawn_boss(_template(), "txn1", pos, _ctx(159.0))
	assert_not_null(boss, "spawn returns a BossInstance")
	assert_true(boss.is_inside_tree(), "AC-37: boss in tree post-spawn")
	assert_true(boss.global_position.is_equal_approx(pos), "AC-37: global_position == spawn_pos")
	assert_eq(boss.transition_id, "txn1", "transition_id set (chain integrity)")
	assert_eq(boss.max_hp, 1631, "boss._ready computed Formula 1 (200 + 159*9)")
	assert_signal_emitted(bs, "boss_committed", "AC-37: boss_committed emitted")


# ---------------------------------------------------------------------------
# AC-25 / EC-01 — duplicate spawn idempotency
# ---------------------------------------------------------------------------

func test_ac25_duplicate_transition_id_rejected() -> void:
	var bs := _system()
	var first := bs.spawn_boss(_template(), "dup", Vector2.ZERO, _ctx(100.0))
	var second := bs.spawn_boss(_template(), "dup", Vector2.ZERO, _ctx(100.0))
	assert_not_null(first, "AC-25: first spawn succeeds")
	assert_null(second, "AC-25: 2nd spawn with same transition_id returns null")
	# exactly one BossInstance child
	var boss_children := bs.get_children().filter(func(c): return c is BossInstance)
	assert_eq(boss_children.size(), 1, "AC-25: exactly one BossInstance child")


# ---------------------------------------------------------------------------
# AC-26 / EC-02 — empty transition_id rejected (graceful, not assert)
# ---------------------------------------------------------------------------

func test_ac26_empty_transition_id_rejected() -> void:
	var bs := _system()
	var boss := bs.spawn_boss(_template(), "", Vector2.ZERO, _ctx(100.0))
	assert_null(boss, "AC-26/EC-02: empty transition_id -> null (reject + rollback)")
	assert_eq(bs.get_children().filter(func(c): return c is BossInstance).size(), 0,
		"AC-26: no BossInstance created on reject")


# ---------------------------------------------------------------------------
# AC-43 — null snapshot rejected
# ---------------------------------------------------------------------------

func test_ac43_null_snapshot_rejected() -> void:
	var bs := _system()
	var boss := bs.spawn_boss(_template(), "txn_null", Vector2.ZERO, null)
	assert_null(boss, "AC-43: null player_snapshot -> null")
	assert_eq(bs.get_children().filter(func(c): return c is BossInstance).size(), 0,
		"AC-43: no add_child on null snapshot")


# ---------------------------------------------------------------------------
# Idempotency eviction on boss free (Pass 11 512MB rec)
# ---------------------------------------------------------------------------

func test_transition_id_evicted_on_boss_free() -> void:
	var bs := _system()
	var boss := bs.spawn_boss(_template(), "evict_me", Vector2.ZERO, _ctx(100.0))
	assert_true(bs._spawned_transition_ids.has("evict_me"), "id tracked while alive")
	boss.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(bs._spawned_transition_ids.has("evict_me"),
		"Pass 11: transition_id evicted from the dedupe set when the boss frees")
