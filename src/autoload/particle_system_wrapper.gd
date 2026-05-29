# ParticleSystemWrapper — Autoload position 12 (#5)
#
# Status: STUB — implementation pending
# Driving GDD: design/gdd/particle-system-wrapper.md (Approved 2026-05-26)
# Forbidden Pattern Gateway: ALL `GPUParticles2D` instantiation MUST route through this autoload.
#   CI lint: tools/ci/check_particle_callers.gd
extends Node

func _ready() -> void:
	print("[ParticleSystemWrapper] stub initialized — autoload pos 12; implementation pending")
