# Fixture — magic preset-id play() calls that check_particle_preset_magic.gd MUST flag.
# NOT loaded as production code; consumed by test_particle_ci_lint.gd only.
extends Node


func _bad_int_preset() -> void:
	ParticleSystemWrapper.play(42, Vector2.ZERO)


func _bad_string_preset() -> void:
	ParticleSystemWrapper.play("HIT_LIGHT", Vector2(10, 10))


func _bad_with_multiplier() -> void:
	ParticleSystemWrapper.play(0, Vector2.ZERO, 1.5)
