## BossRevealCoordinator — Camera-leading boss reveal ritual (Story 010, GDD Rule 7)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 7 (Boss Reveal Ritual Coordination,
##     Camera-LEADING timeline)
##
## Governing ADRs:
##   * ADR-0001 (Web Export Budget — particle/shake/focal caps)
##   * ADR-0009 (boss_committed payload)
##
## Driving Story: production/epics/boss-system/story-010-reveal-ritual-dispatch.md
## Implementing TR: TR-boss-014 (reveal dispatch), TR-boss-009 (intensity feed)
##
## Subscribes to `BossSystem.boss_committed` and dispatches the reveal in the
## Camera-LEADING order (Pass 3 F2 — focal claims attention at frame 0, BEFORE
## shake/particles disperse it): Camera focal (frame 0) → await one frame →
## ScreenEffects shake + ParticleSystemWrapper particles + AudioManager sfx (frame 1-2).
##
## DEPENDENCY-INJECTION SEAMS: the 4 dispatch targets are injectable (`_camera` /
## `_screen_effects` / `_particles` / `_audio`), defaulting to the real autoloads.
## Tests inject mock spies (autoload methods can't be cleanly overridden). `_now_ms`
## is an injectable clock for the AC-07b logical dispatch budget.
##
## SIGNATURE NOTES (shipped-code names — the GDD used stale names): the real calls
## are `ParticleSystemWrapper.play(PresetId, pos, mult)` (GDD said `spawn`) and
## `AudioManager.play_sfx(id)` (GDD said `play_cue`). CameraController.request_focal
## + ScreenEffects.shake match the GDD.
##
## WIRING NOTE: the `BossSystem.boss_committed` subscription is established once
## BossSystem is registered as an autoload (deferred with Story 007 → #14 wiring).
## Until then `_on_boss_committed` / `dispatch_reveal` are driven directly (+ tested).
class_name BossRevealCoordinator extends Node

const BASE_FOCAL_DURATION: float = 0.6
const FOCAL_ZOOM: float = 1.4
const BASE_SHAKE_INTENSITY: float = 0.5
const SHAKE_DURATION: float = 0.3
const DISPATCH_BUDGET_MS: int = 200  # Pillar-2 sub-500ms boss-visible budget (#9 AC-41 + #14 FR-2)

# Injectable dispatch seams — default to the real autoloads (resolved in _ready).
var _camera: Object = null
var _screen_effects: Object = null
var _particles: Object = null
var _audio: Object = null
var _now_ms: Callable = Callable(Time, "get_ticks_msec")

## Logical dispatch elapsed (ms) from focal-start to all-3-dispatched (AC-07b).
var _last_dispatch_elapsed_ms: int = 0


func _ready() -> void:
	if _camera == null:
		_camera = CameraController
	if _screen_effects == null:
		_screen_effects = ScreenEffects
	if _particles == null:
		_particles = ParticleSystemWrapper
	if _audio == null:
		_audio = AudioManager
	# BossSystem.boss_committed subscription deferred with BossSystem autoload
	# registration (Story 007 -> #14 wiring). connect_for_initial_state pattern
	# (ADR-0006 Contract 6) at that point.


## Subscriber handler for BossSystem.boss_committed — derives the ritual
## multiplier (Formula 4) and dispatches the reveal.
func _on_boss_committed(
	template: BossTemplate,
	_boss: BossInstance,
	_snapshot: BossSpawnContext,
	spawn_pos: Vector2,
	_transition_id: String
) -> void:
	var ritual_mult: float = BossFormulas.compute_ritual_intensity(template.reveal_ritual_intensity)
	await dispatch_reveal(spawn_pos, ritual_mult, template.audio_template_id)


## Camera-LEADING reveal dispatch. Camera focal at frame 0 (attention anchor),
## then shake + particles + audio at frame 1-2 (released after attention captured).
## All targets use the cached `spawn_pos` (never a late boss.global_position read).
func dispatch_reveal(spawn_pos: Vector2, ritual_mult: float, audio_id: StringName) -> void:
	var start_ms: int = _now_ms.call()
	# FRAME 0 — Camera LEADING (Pass 3 F2)
	_camera.request_focal(spawn_pos, BASE_FOCAL_DURATION * ritual_mult, FOCAL_ZOOM)
	await get_tree().process_frame
	# FRAME 1-2 — follow (released after the attention anchor is locked)
	_screen_effects.shake(BASE_SHAKE_INTENSITY * ritual_mult, SHAKE_DURATION)
	_particles.play(ParticleSystemWrapper.PresetId.LOOT_RARE_BURST, spawn_pos, ritual_mult)
	if _audio != null:
		_audio.play_sfx(audio_id)
	_last_dispatch_elapsed_ms = _now_ms.call() - start_ms


## AC-07b — true iff the logical dispatch elapsed stayed within the 200ms budget.
func dispatch_within_budget() -> bool:
	return _last_dispatch_elapsed_ms <= DISPATCH_BUDGET_MS
