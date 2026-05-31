# EnemyDirector CI Lint — Camera + Particle Clean Fixture (Story 004 AC-05/AC-26)
# Clean: all dispatch through authorized APIs — no Camera2D or GPUParticles2D mutation.
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# Clean: camera motion via CameraController
func _spawn_boss_entry() -> void:
	CameraController.focal_request(self, 0.6, "quart_ease_out")  # correct

# Clean: particle dispatch via ParticleSystemWrapper
func _play_spawn_burst() -> void:
	ParticleSystemWrapper.play("SPAWN_BURST", global_position, 0.8)  # correct

# Clean: ScreenEffects shake via authorized API
func _do_boss_shake() -> void:
	ScreenEffects.shake(0.4, 0.08)  # correct
