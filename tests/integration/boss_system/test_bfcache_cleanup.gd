# BossInstance cleanup + bfcache DD#1 exact-restore (Story 012:
# AC-11 / AC-38 / AC-42 / AC-27a / AC-46). Injectable clocks for determinism.
extends GutTest

const DYING := EnemyDirector.EnemyAIState.DYING


func _fixed_clock(values: Array) -> Callable:
	var i := [0]
	return func() -> int:
		var v: int = values[i[0]]
		i[0] += 1
		return v


# --- off-tree boss for _restore_from_bfcache branch tests ---
func _bare_boss(tid: String, max_hp: int) -> BossInstance:
	var b: BossInstance = autofree(BossInstance.new())
	b.transition_id = tid
	b.max_hp = max_hp
	return b


# --- in-tree boss (4 children) for _play_death_and_free ---
func _tree_boss(with_death_anim: bool) -> BossInstance:
	var boss := BossInstance.new()
	var anim := AnimationPlayer.new(); anim.name = "AnimationPlayer"; boss.add_child(anim)
	for cn in ["CollisionShape2D", "Sprite2D", "HitArea2D"]:
		var n: Node
		match cn:
			"CollisionShape2D": n = CollisionShape2D.new()
			"Sprite2D": n = Sprite2D.new()
			"HitArea2D": n = Area2D.new()
		n.name = cn
		boss.add_child(n)
	if with_death_anim:
		var lib := AnimationLibrary.new()
		var a := Animation.new(); a.length = 1.0
		lib.add_animation("death", a)
		anim.add_animation_library("", lib)
	var t := BossTemplate.new(); t.base_hp = 200
	boss.boss_template = t
	boss.transition_id = "txn"
	var ctx := BossSpawnContext.new(); ctx.attack_power = 100.0; ctx.max_hp = 200
	boss.player_stat_snapshot = ctx
	add_child_autofree(boss)  # _ready
	return boss


# ---------------------------------------------------------------------------
# AC-11 — cleanup + queue_free
# ---------------------------------------------------------------------------

func test_ac11_death_without_anim_cleans_and_frees() -> void:
	var boss := _tree_boss(false)
	await boss._play_death_and_free()
	assert_true(boss.is_queued_for_deletion(), "AC-11: no death anim -> immediate cleanup + queue_free")


# ---------------------------------------------------------------------------
# AC-38 — wall-clock deadline drives cleanup when animation_finished never fires
# ---------------------------------------------------------------------------

func test_ac38_wallclock_deadline_frees_when_anim_never_finishes() -> void:
	var boss := _tree_boss(true)
	# Clock: deadline = now(0) + 3000 = 3000; next read 4000 >= 3000 -> exit poll.
	boss._now_ms_provider = _fixed_clock([0, 4000, 4000])
	await boss._play_death_and_free()
	assert_true(boss.is_queued_for_deletion(),
		"AC-38: animation_finished never fires -> wall-clock deadline triggers cleanup + queue_free")


# ---------------------------------------------------------------------------
# AC-42 / AC-27a — DD#1 exact-restore branches
# ---------------------------------------------------------------------------

func test_ac42_branch_a_exact_restore() -> void:
	var b := _bare_boss("abc", 100)
	b._restore_from_bfcache(50, "abc", 1000, 1000)  # fresh, matching tid
	assert_eq(b.current_hp, 50, "AC-42(a): exact restore of persisted HP")
	assert_ne(b._ai_state, DYING, "AC-42(a): HP>0 restore does not enter DYING")


func test_ac42_branch_b_zero_hp_enters_dying() -> void:
	var b := _bare_boss("abc", 100)
	b._restore_from_bfcache(0, "abc", 1000, 1000)
	assert_eq(b.current_hp, 0, "AC-42(b): restored HP 0")
	assert_eq(b._ai_state, DYING, "AC-42(b): restored HP==0 enters DYING idempotently")


func test_ac42_branch_c_tid_mismatch_restores_max() -> void:
	var b := _bare_boss("abc", 100)
	b._restore_from_bfcache(50, "WRONG_tid", 1000, 1000)
	assert_eq(b.current_hp, 100, "AC-42(c): transition_id mismatch -> restore max_hp (treat as fresh)")


func test_ac42_branch_c_null_record_restores_max() -> void:
	var b := _bare_boss("abc", 100)
	b._restore_from_bfcache(null, null, null, 1000)
	assert_eq(b.current_hp, 100, "AC-42(c): no persisted record -> restore max_hp")


# ---------------------------------------------------------------------------
# AC-46 — TTL staleness boundary
# ---------------------------------------------------------------------------

func test_ac46_within_ttl_restores_exact() -> void:
	var b := _bare_boss("abc", 100)
	# Δ == TTL (7200) is NOT stale (strict >); exact restore.
	b._restore_from_bfcache(50, "abc", 1000, 1000 + BossInstance.BOSS_HP_PERSIST_TTL_SEC)
	assert_eq(b.current_hp, 50, "AC-46: Δ == TTL boundary -> still fresh, exact restore")


func test_ac46_past_ttl_restores_max() -> void:
	var b := _bare_boss("abc", 100)
	# Δ == TTL + 1 -> stale -> max_hp.
	b._restore_from_bfcache(50, "abc", 1000, 1000 + BossInstance.BOSS_HP_PERSIST_TTL_SEC + 1)
	assert_eq(b.current_hp, 100, "AC-46: Δ > TTL -> stale -> restore max_hp")
