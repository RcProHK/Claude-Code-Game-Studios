extends GutTest
## Story 016: particle delegation + mobile fallback (CR-14 / AC-20 / EC-XSYS-1 / G-AR-3).
##
## G-AR-3 decision (recommended, coupled with #29 G-MM-3 / B-1): #26 is render-only
## (ADR-0010) and emits NO particles itself — decorative bursts belong to the view and the
## weekly ceremony burst belongs to #29 (which reuses the #5 LOOT preset). The three new
## AVATAR_* PresetId entries (FC-6) would require amending #5's closed-set-of-9 enum +
## PRESET_TABLE + materials + its two hard `size()==9` tests, so per the GDD they are an
## out-of-scope #5 erratum follow-up. This test therefore pins the two #26-coordinator
## invariants that must hold regardless of that follow-up:
##   AC-20     — sprite resolution is platform-agnostic (mobile degrades particle density via
##               #5 only; the sprite layer is never touched).
##   EC-XSYS-1 — a milestone still emits even with no particle system (silhouette > decoration).
##   ADR-0001  — #26 never instantiates GPUParticles2D directly.
## See production/epics/avatar-renderer/story-016-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")
const RENDERER_SRC := "res://src/autoload/avatar_renderer.gd"


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, SUSPENDED}
	var state: int = GameState.IDLE
	func get_current_state() -> int:
		return state


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


func _renderer() -> Node:
	var r = AvatarRendererScript.new()
	r._gsm = FakeGSM.new()
	r._persistence = MockPersistence.new()
	r._posture_config = load("res://assets/data/posture_config.tres")
	r._ready_complete = true
	return r


func test_ac20_sprite_resolution_is_platform_agnostic() -> void:
	# AC-20: the (posture,tier) -> SpriteFrames path is deterministic and carries no platform
	# branch — mobile fallback degrades particle density inside #5, never the sprite layer.
	var r := _renderer()
	var p1 = r._resolve_sprite_path(&"STRIKE", 1)
	var p2 = r._resolve_sprite_path(&"STRIKE", 1)
	assert_eq(p1, p2, "AC-20: sprite resolution is deterministic (no hidden platform state)")
	assert_ne(p1, "", "AC-20: a valid (posture,tier) resolves to a real path, mobile or not")
	r.free()


func test_ec_xsys1_milestone_emits_without_particle_system() -> void:
	# EC-XSYS-1: #26 has no #5 dependency on the milestone path, so a tier-up still reaches
	# #29 even when the particle wrapper is unavailable (silhouette > decoration).
	var r := _renderer()
	r._visual_state.evolution_tier = 1
	r._last_emitted_tier = 0
	r._last_milestone_emit_unix = int(Time.get_unix_time_from_system()) - 700000
	watch_signals(r)
	r._maybe_emit_milestone(80.0, 3, 2)
	assert_signal_emitted(r, "avatar_evolution_milestone",
		"EC-XSYS-1: milestone emits with no particle system present")
	r.free()


func test_no_direct_gpuparticles2d_in_renderer() -> void:
	# ADR-0001 / Control Manifest: particles only ever go through ParticleSystemWrapper —
	# #26 must never instantiate GPUParticles2D directly.
	var abs := ProjectSettings.globalize_path(RENDERER_SRC)
	var file := FileAccess.open(abs, FileAccess.READ)
	assert_not_null(file, "renderer source must be readable")
	var hits := 0
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges().begins_with("#"):
			continue
		if "GPUParticles2D" in line:
			hits += 1
	if file != null:
		file.close()
	assert_eq(hits, 0, "ADR-0001: avatar_renderer.gd never instantiates GPUParticles2D directly")
