#!/usr/bin/env -S godot --headless --script
## One-off generator — Particle System Wrapper (#5) Story 008 preset library.
##
## Builds the 9 ParticleProcessMaterial .tres assets from the GDD Visual Spec Table
## (design/gdd/particle-system-wrapper.md Rule 13). Run once to (re)generate; the .tres
## files are committed as the canonical preset library. Particle TEXTURE is a separate
## GPUParticles2D node property + unproduced art dependency — intentionally left null
## here. scale_curve (CurveTexture) is approximated via scale_min/max; the full scale
## curve lands when art is produced (follow-up).
##
## Usage:
##   godot --headless --script tools/build/generate_particle_presets.gd
##
## Output: res://assets/vfx/presets/{preset}.tres  (9 files)
extends SceneTree

const OUT_DIR: String = "res://assets/vfx/presets"


func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("[gen_presets] cannot create %s (err %d)" % [OUT_DIR, dir_err])
		quit(1)
		return

	var specs := _specs()
	var saved := 0
	for name: String in specs:
		var mat := _build_material(specs[name])
		var path := "%s/%s.tres" % [OUT_DIR, name]
		var err := ResourceSaver.save(mat, path)
		if err != OK:
			push_error("[gen_presets] save failed: %s (err %d)" % [path, err])
			quit(1)
			return
		saved += 1
		print("[gen_presets] wrote %s" % path)
	print("[gen_presets] DONE — %d preset materials written to %s" % [saved, OUT_DIR])
	quit(0)


func _build_material(s: Dictionary) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = s["emission_shape"]
	match s["emission_shape"]:
		ParticleProcessMaterial.EMISSION_SHAPE_SPHERE:
			m.emission_sphere_radius = s.get("radius", 4.0)
		ParticleProcessMaterial.EMISSION_SHAPE_BOX:
			m.emission_box_extents = s.get("box_extents", Vector3(6, 8, 0))
		ParticleProcessMaterial.EMISSION_SHAPE_RING:
			m.emission_ring_axis = Vector3(0, 0, 1)  # 2D ring faces the camera
			m.emission_ring_radius = s.get("radius", 10.0)
			m.emission_ring_inner_radius = s.get("inner_radius", 8.0)
			m.emission_ring_height = 1.0
	m.spread = s["spread"]
	m.direction = s["direction"]
	m.initial_velocity_min = s["vel_min"]
	m.initial_velocity_max = s["vel_max"]
	m.gravity = s["gravity"]
	m.damping_min = s["drag"]
	m.damping_max = s["drag"]
	m.color_ramp = _gradient_tex(s["ramp_offsets"], s["ramp_colors"])
	return m


func _gradient_tex(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


## Per-preset visual spec (GDD Visual Spec Table — Rule 13).
func _specs() -> Dictionary:
	var P := ParticleProcessMaterial
	return {
		"hit_light": {
			"emission_shape": P.EMISSION_SHAPE_POINT, "spread": 35.0, "direction": Vector3(0, -1, 0),
			"vel_min": 90.0, "vel_max": 140.0, "gravity": Vector3(0, 60, 0), "drag": 0.25,
			"ramp_offsets": PackedFloat32Array([0.0, 0.4, 1.0]),
			"ramp_colors": PackedColorArray([Color(1, 1, 1, 1), Color(0.85, 0.92, 1, 0.9), Color(0.7, 0.8, 1, 0)]),
		},
		"hit_heavy": {
			"emission_shape": P.EMISSION_SHAPE_SPHERE, "radius": 6.0, "spread": 120.0, "direction": Vector3.ZERO,
			"vel_min": 140.0, "vel_max": 220.0, "gravity": Vector3(0, 140, 0), "drag": 0.35,
			"ramp_offsets": PackedFloat32Array([0.0, 0.3, 1.0]),
			"ramp_colors": PackedColorArray([Color(1, 0.95, 0.85, 1), Color(1, 0.55, 0.25, 0.95), Color(0.4, 0.15, 0.1, 0)]),
		},
		"parry": {
			"emission_shape": P.EMISSION_SHAPE_RING, "radius": 10.0, "inner_radius": 8.0, "spread": 360.0, "direction": Vector3.ZERO,
			"vel_min": 180.0, "vel_max": 240.0, "gravity": Vector3.ZERO, "drag": 0.55,
			"ramp_offsets": PackedFloat32Array([0.0, 0.3, 1.0]),
			"ramp_colors": PackedColorArray([Color(1.4, 1.4, 1.4, 1), Color(0.7, 0.95, 1.0, 0.95), Color(0.3, 0.6, 0.9, 0)]),
		},
		"death": {
			"emission_shape": P.EMISSION_SHAPE_SPHERE, "radius": 4.0, "spread": 180.0, "direction": Vector3.ZERO,
			"vel_min": 60.0, "vel_max": 180.0, "gravity": Vector3(0, 220, 0), "drag": 0.20,
			"ramp_offsets": PackedFloat32Array([0.0, 0.4, 1.0]),
			"ramp_colors": PackedColorArray([Color(0.85, 0.8, 0.75, 1), Color(0.55, 0.5, 0.5, 0.85), Color(0.2, 0.2, 0.25, 0)]),
		},
		"status_burn": {
			"emission_shape": P.EMISSION_SHAPE_BOX, "box_extents": Vector3(6, 8, 0), "spread": 15.0, "direction": Vector3(0, -1, 0),
			"vel_min": 40.0, "vel_max": 80.0, "gravity": Vector3(0, -60, 0), "drag": 0.15,
			"ramp_offsets": PackedFloat32Array([0.0, 0.5, 1.0]),
			"ramp_colors": PackedColorArray([Color(1, 0.6, 0.2, 0.9), Color(1, 0.3, 0.1, 0.8), Color(0.4, 0.1, 0, 0)]),
		},
		"status_freeze": {
			"emission_shape": P.EMISSION_SHAPE_SPHERE, "radius": 10.0, "spread": 360.0, "direction": Vector3.ZERO,
			"vel_min": 10.0, "vel_max": 30.0, "gravity": Vector3(0, 30, 0), "drag": 0.70,
			"ramp_offsets": PackedFloat32Array([0.0, 0.5, 1.0]),
			"ramp_colors": PackedColorArray([Color(0.85, 0.95, 1, 0.9), Color(0.55, 0.8, 1, 0.75), Color(0.3, 0.5, 0.85, 0)]),
		},
		"status_stun": {
			"emission_shape": P.EMISSION_SHAPE_RING, "radius": 12.0, "inner_radius": 11.0, "spread": 360.0, "direction": Vector3.ZERO,
			"vel_min": 30.0, "vel_max": 50.0, "gravity": Vector3.ZERO, "drag": 0.40,
			"ramp_offsets": PackedFloat32Array([0.0, 0.5, 1.0]),
			"ramp_colors": PackedColorArray([Color(1, 0.95, 0.5, 0.9), Color(1, 0.85, 0.3, 0.85), Color(0.6, 0.5, 0.2, 0)]),
		},
		"loot_burst": {
			"emission_shape": P.EMISSION_SHAPE_SPHERE, "radius": 8.0, "spread": 360.0, "direction": Vector3(0, -1, 0),
			"vel_min": 160.0, "vel_max": 260.0, "gravity": Vector3(0, 280, 0), "drag": 0.30,
			"ramp_offsets": PackedFloat32Array([0.0, 0.3, 0.7, 1.0]),
			"ramp_colors": PackedColorArray([Color(1.3, 1.3, 1.1, 1), Color(0.6, 1.0, 0.7, 0.95), Color(0.3, 0.8, 0.5, 0.85), Color(0.2, 0.5, 0.3, 0)]),
		},
		"loot_rare_burst": {
			"emission_shape": P.EMISSION_SHAPE_RING, "radius": 14.0, "inner_radius": 10.0, "spread": 360.0, "direction": Vector3.ZERO,
			"vel_min": 120.0, "vel_max": 320.0, "gravity": Vector3(0, 160, 0), "drag": 0.18,
			"ramp_offsets": PackedFloat32Array([0.0, 0.25, 0.6, 0.85, 1.0]),
			"ramp_colors": PackedColorArray([Color(1.5, 1.4, 1.6, 1), Color(0.85, 0.55, 1.0, 0.95), Color(0.6, 0.4, 1.0, 0.9), Color(1.0, 0.65, 0.3, 0.85), Color(0.6, 0.3, 0.2, 0)]),
		},
	}
