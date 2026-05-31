# EnemyDirector — Story 017 AC-33: boss entry cascade — 5 steps, exact order, same frame.
extends GutTest

const BAS = EnemyDirector.BossAnchorState
const EAS = EnemyDirector.EnemyAIState


## Boss mock — Node2D with engage() that logs into a shared order list.
class MockBoss:
	extends Node2D
	var log_ref: Array
	func engage() -> void:
		log_ref.append("engage")


class CameraSpy:
	extends RefCounted
	var log_ref: Array
	var args: Array = []
	func focal_request(target, duration: float, easing: String) -> void:
		args = [target, duration, easing]
		log_ref.append("camera")


class ScreenEffectsSpy:
	extends RefCounted
	var log_ref: Array
	var args: Array = []
	func shake(intensity: float, duration: float) -> void:
		args = [intensity, duration]
		log_ref.append("shake")


class ParticleSpy:
	extends RefCounted
	var log_ref: Array
	var args: Array = []
	func play(preset: StringName, pos: Vector2, caller_mult: float) -> void:
		args = [preset, pos, caller_mult]
		log_ref.append("play")


var _call_log: Array
var _boss: MockBoss
var _camera: CameraSpy
var _screen: ScreenEffectsSpy
var _particle: ParticleSpy


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	_call_log = []
	_boss = MockBoss.new()
	_boss.log_ref = _call_log
	_boss.visible = false
	_boss.global_position = Vector2(500.0, 360.0)
	add_child_autofree(_boss)
	_camera = CameraSpy.new(); _camera.log_ref = _call_log
	_screen = ScreenEffectsSpy.new(); _screen.log_ref = _call_log
	_particle = ParticleSpy.new(); _particle.log_ref = _call_log
	EnemyDirector.set(&"_boss_node", _boss)
	EnemyDirector.set(&"_boss_cascade_params", EnemyDirector.call("_select_boss_cascade_params", 5))  # standard
	EnemyDirector.set(&"_boss_anchor_state", BAS.COMMIT_PENDING)
	EnemyDirector.set(&"_camera_source", _camera)
	EnemyDirector.set(&"_screen_effects_source", _screen)
	EnemyDirector.set(&"_particle_source", _particle)


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set(&"_boss_node", null)
	EnemyDirector.set(&"_boss_anchor_state", BAS.IDLE)
	EnemyDirector.set(&"_camera_source", null)
	EnemyDirector.set(&"_screen_effects_source", null)
	EnemyDirector.set(&"_particle_source", null)
	EnemyDirector.set_physics_process(true)


func _commit() -> void:
	EnemyDirector.call("_on_state_changed",
		GameStateMachine.GameState.COMBAT_ACTIVE, GameStateMachine.GameState.BOSS_ENCOUNTER, null)


# ---------------------------------------------------------------------------
# AC-33 — cascade order + args + state
# ---------------------------------------------------------------------------

func test_ac33_cascade_runs_five_steps_in_exact_order() -> void:
	_commit()
	assert_eq(_call_log, ["engage", "camera", "shake", "play"],
		"AC-33: cascade order engage → camera → shake → particle (same frame)")
	assert_true(_boss.visible, "AC-33: boss revealed (visible = true)")


func test_ac33_camera_args() -> void:
	_commit()
	assert_eq(_camera.args[0], _boss, "AC-33: focal_request targets the boss")
	assert_almost_eq(_camera.args[1], 0.6, 0.001, "AC-33: camera 0.6s (standard)")
	assert_eq(_camera.args[2], "quart_ease_out", "AC-33: easing quart_ease_out")


func test_ac33_shake_args() -> void:
	_commit()
	assert_almost_eq(_screen.args[0], 0.4, 0.001, "AC-33: shake intensity 0.4")
	assert_almost_eq(_screen.args[1], 0.08, 0.001, "AC-33: shake duration 0.08")


func test_ac33_particle_args() -> void:
	_commit()
	assert_eq(_particle.args[0], &"BOSS_ENTRY", "AC-33: particle preset BOSS_ENTRY")
	assert_eq(_particle.args[1], _boss.global_position, "AC-33: particle at boss position")
	assert_almost_eq(_particle.args[2], 1.2, 0.001, "AC-33: caller_mult 1.2 (boss spectacle)")


func test_ac33_state_ends_engaged() -> void:
	_commit()
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.ENGAGED,
		"AC-33: boss anchor ends in ENGAGED after cascade")


## Cascade only fires from COMMIT_PENDING — a stray BOSS_ENCOUNTER while IDLE is a no-op.
func test_no_cascade_when_not_commit_pending() -> void:
	EnemyDirector.set(&"_boss_anchor_state", BAS.IDLE)
	_commit()
	assert_eq(_call_log, [], "no cascade unless COMMIT_PENDING")
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.IDLE, "state unchanged")
