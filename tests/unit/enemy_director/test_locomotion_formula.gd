# EnemyDirector — Story 014 Locomotion (Formula 6) + 4Hz Batch Perception.
#
# Coverage:
#   AC-30 — Formula 6 velocity step: move_toward + cap clamp, velocity.y = 0.
#   4Hz   — batch perception reads the avatar position ONCE per 0.25s and updates all enemies.
extends GutTest

const EAS = EnemyDirector.EnemyAIState


## Avatar mock whose global_position read is counted (proves single-read budget).
class AvatarSpy:
	extends RefCounted
	var read_count: int = 0
	var _pos: Vector2 = Vector2(100.0, 0.0)
	var global_position: Vector2:
		get:
			read_count += 1
			return _pos


# ---------------------------------------------------------------------------
# AC-30 — Formula 6 velocity step
# ---------------------------------------------------------------------------

func test_ac30_formula6_accelerates_toward_target() -> void:
	var enemy := Enemy.new()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy._template_move_speed = 120.0
	enemy._direction = 1
	enemy.velocity = Vector2(0.0, 0.0)
	enemy.call("_step_velocity", 1.0 / 60.0)
	# accel = 120×10 = 1200; accel×delta = 20; move_toward(0,120,20) = 20; clamp(20)=20.
	assert_almost_eq(enemy.velocity.x, 20.0, 0.001, "AC-30: velocity.x == 20 after one 1/60 step")
	assert_almost_eq(enemy.velocity.y, 0.0, 0.001, "AC-30: velocity.y == 0 (no vertical locomotion)")


func test_ac30_velocity_clamped_to_move_cap() -> void:
	var enemy := Enemy.new()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy._template_move_speed = 120.0
	enemy._direction = 1
	enemy.velocity = Vector2(500.0, 0.0)  # above cap, decelerating toward 120
	enemy.call("_step_velocity", 1.0 / 60.0)
	# move_toward(500,120,20)=480; clamp(480,-420,420)=420.
	assert_almost_eq(enemy.velocity.x, 420.0, 0.001, "AC-30: velocity.x clamped to ENEMY_MOVE_CAP (420)")


func test_ac30_negative_direction_moves_left() -> void:
	var enemy := Enemy.new()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy._template_move_speed = 120.0
	enemy._direction = -1
	enemy.velocity = Vector2(0.0, 0.0)
	enemy.call("_step_velocity", 1.0 / 60.0)
	assert_almost_eq(enemy.velocity.x, -20.0, 0.001, "AC-30: direction -1 accelerates left")


# ---------------------------------------------------------------------------
# 4Hz batch perception
# ---------------------------------------------------------------------------

func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.set(&"_avatar_source", null)
	EnemyDirector.set(&"_perception_tick_accumulator", 0.0)


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.set(&"_avatar_source", null)
	EnemyDirector.set_physics_process(true)


func test_4hz_reads_avatar_once_and_updates_all_enemies() -> void:
	var avatar := AvatarSpy.new()
	EnemyDirector.set(&"_avatar_source", avatar)
	var enemies: Array[Enemy] = []
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	for i in 8:
		var e := Enemy.new()
		add_child_autofree(e)
		e.set_physics_process(false)
		e.global_position = Vector2(float(i) * 10.0, 0.0)
		enemies.append(e)
		pool[e.get_instance_id()] = true
	# Accumulate to the 0.25s threshold in 4 ticks of 1/16s.
	for _t in 4:
		EnemyDirector.call("_perception_tick", 1.0 / 16.0)
	assert_eq(avatar.read_count, 1, "4Hz: avatar position read EXACTLY once per 0.25s window")
	for e in enemies:
		assert_ne(e._cached_avatar_distance, INF, "4Hz: every enemy's cached distance updated")
	# Spot-check enemy 0 distance (avatar at (100,0), enemy at (0,0) → 100).
	assert_almost_eq(enemies[0]._cached_avatar_distance, 100.0, 0.001, "4Hz: distance computed correctly")


func test_4hz_no_read_before_interval() -> void:
	var avatar := AvatarSpy.new()
	EnemyDirector.set(&"_avatar_source", avatar)
	EnemyDirector.call("_perception_tick", 1.0 / 16.0)  # 0.0625 < 0.25
	assert_eq(avatar.read_count, 0, "4Hz: no avatar read before the 0.25s window elapses")


func test_4hz_null_avatar_is_noop() -> void:
	EnemyDirector.set(&"_avatar_source", null)
	EnemyDirector.call("_perception_tick", 1.0)  # must not crash
	assert_eq((EnemyDirector.get(&"_enemy_state_pool") as Dictionary).size(), 0,
		"4Hz: null avatar → perception is a safe no-op")
