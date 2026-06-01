# Fixture — correct PresetId-enum play() calls that check_particle_preset_magic.gd must NOT flag.
# Also includes an unrelated AnimationPlayer-style .play("...") call (must not false-positive)
# and a commented-out magic call (must not false-positive). Consumed by test_particle_ci_lint.gd.
extends Node

var _anim  # stand-in for an AnimationPlayer-like node


func _good_enum_preset() -> void:
	ParticleSystemWrapper.play(ParticleSystemWrapper.PresetId.HIT_LIGHT, Vector2.ZERO)
	ParticleSystemWrapper.play(ParticleSystemWrapper.PresetId.LOOT_BURST, Vector2(5, 5), 1.5)


func _unrelated_play_is_fine() -> void:
	_anim.play("idle")  # AnimationPlayer.play — not ParticleSystemWrapper, must NOT match


func _commented_magic_is_ignored() -> void:
	# ParticleSystemWrapper.play(42, Vector2.ZERO)  # commented example — must NOT match
	pass
