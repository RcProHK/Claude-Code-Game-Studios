# BossInstance arena constraint (Story 014: AC-14 Rule 14) + AC-15 state inheritance.
extends GutTest


func _boss(mode: int, ext: Vector2, spawn_origin: Vector2) -> BossInstance:
	var b: BossInstance = autofree(BossInstance.new())
	var t := BossTemplate.new()
	t.arena_constraint_mode = mode
	t.arena_constraint_px = ext
	b.boss_template = t
	b._spawn_origin = spawn_origin
	return b


# ---------------------------------------------------------------------------
# AC-14 — SPAWN_RELATIVE (default)
# ---------------------------------------------------------------------------

func test_ac14_spawn_relative_clamps_far_pursuit() -> void:
	var b := _boss(BossTemplate.ArenaConstraintMode.SPAWN_RELATIVE, Vector2(300, 200), Vector2.ZERO)
	var clamped := b.clamp_position(Vector2(10000, 5000), Vector2.ZERO)
	assert_eq(clamped, Vector2(300, 200), "AC-14: SPAWN_RELATIVE clamps to spawn +/- arena_constraint_px")


func test_ac14_spawn_relative_within_bounds_unchanged() -> void:
	var b := _boss(BossTemplate.ArenaConstraintMode.SPAWN_RELATIVE, Vector2(300, 200), Vector2.ZERO)
	var inside := Vector2(100, -50)
	assert_eq(b.clamp_position(inside, Vector2.ZERO), inside, "within bounds -> unchanged")


func test_ac14_spawn_relative_anchored_to_origin_not_zero() -> void:
	var b := _boss(BossTemplate.ArenaConstraintMode.SPAWN_RELATIVE, Vector2(300, 200), Vector2(1000, 1000))
	var clamped := b.clamp_position(Vector2(5000, 5000), Vector2.ZERO)
	assert_eq(clamped, Vector2(1300, 1200), "clamp is anchored to the spawn origin (1000,1000)")


# ---------------------------------------------------------------------------
# AC-14 — WORLD_ABSOLUTE
# ---------------------------------------------------------------------------

func test_ac14_world_absolute_clamps_around_origin() -> void:
	var b := _boss(BossTemplate.ArenaConstraintMode.WORLD_ABSOLUTE, Vector2(300, 200), Vector2(9999, 9999))
	assert_eq(b.clamp_position(Vector2(10000, 5000), Vector2.ZERO), Vector2(300, 200),
		"AC-14: WORLD_ABSOLUTE clamps to +/- ext around world origin (ignores spawn origin)")
	assert_eq(b.clamp_position(Vector2(-10000, -5000), Vector2.ZERO), Vector2(-300, -200),
		"AC-14: WORLD_ABSOLUTE negative side")


# ---------------------------------------------------------------------------
# AC-14 — AVATAR_LEASH
# ---------------------------------------------------------------------------

func test_ac14_avatar_leash_clamps_around_avatar() -> void:
	var b := _boss(BossTemplate.ArenaConstraintMode.AVATAR_LEASH, Vector2(300, 200), Vector2.ZERO)
	var avatar := Vector2(1000, 1000)
	assert_eq(b.clamp_position(Vector2(10000, 10000), avatar), Vector2(1300, 1200),
		"AC-14: AVATAR_LEASH clamps within +/- ext of the avatar (never escapes)")


# ---------------------------------------------------------------------------
# AC-15 — AI state inheritance (confirm)
# ---------------------------------------------------------------------------

func test_ac15_ai_state_uses_enemy_director_enum() -> void:
	var b: BossInstance = autofree(BossInstance.new())
	assert_eq(b._ai_state, EnemyDirector.EnemyAIState.SPAWNING,
		"AC-15: _ai_state default == EnemyDirector.EnemyAIState.SPAWNING (no BOSS_PHASE_TRANSITION in MVP)")
