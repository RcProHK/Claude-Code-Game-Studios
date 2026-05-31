# EnemyDirector CI Lint — Particle Violation Fixture (Story 004 AC-26)
# ci:violation-fixture — direct GPUParticles2D instantiation + emitting mutation
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# ACTIVE violation (AC-26): GPUParticles2D.new() forbidden instantiation
func _bad_particle_new() -> void:
	var p := GPUParticles2D.new()  # ci:violation-fixture — must use ParticleSystemWrapper
	add_child(p)

# ACTIVE violation (AC-26): .emitting = true forbidden outside wrapper
func _bad_particle_emit() -> void:
	$GPUParticles2D.emitting = true  # ci:violation-fixture — direct emitting mutation
