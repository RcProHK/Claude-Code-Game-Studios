#!/usr/bin/env -S godot --headless --script
# CI Lint: GPUParticles2D instantiation gateway (ADR-0001)
#
# Status: STUB — implementation pending
# Purpose: Scan src/ for direct `GPUParticles2D` instantiation. FORBIDDEN outside
#   `src/autoload/particle_system_wrapper.gd`. All particle FX must route through
#   ParticleSystemWrapper API (web export budget governance + mobile 0.5× density).
extends SceneTree

func _init() -> void:
	push_warning("[check_particle_callers] STUB — not yet implemented")
	quit(0)
