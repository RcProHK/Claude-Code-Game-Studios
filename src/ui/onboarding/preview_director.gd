class_name OnboardingPreviewDirector
extends Node
## Step 2 non-binding combat "試演" preview presenter (#27, Rule 5 / Pillar 1 命脈). Borrows
## the existing combat render for a scripted showcase — it mutates ZERO gameplay state: it
## NEVER writes loot.*/stat.*/ability.*/streak.*, NEVER calls #15 drop-gen / daily-claim,
## NEVER calls #11/#12 mutators (G-OB-2 lint enforced). The coordinator owns the FSM; this
## helper only presents + reports "done" via the coordinator's notify_preview_finished().
##
## MVP (Q-OB-1 deferred): with no scene path it simply runs the duration timer (placeholder
## for the real zone-1 + CF-1 TIER_1 ability showcase). The "試演 / Preview" watermark is
## visible throughout (anti-deception, Pillar 1). See design/gdd/onboarding-flow.md Rule 5,
## design/ux/onboarding-flow.md UX-06/07/08.

## Emitted when the preview ends (finished / skipped / load-failed / aborted-by-workout).
signal preview_finished()

var _coordinator = null
var _config = null
## Optional clock seam (now_ms()); production falls back to Time.get_ticks_msec().
var _clock = null
var _running: bool = false
var _started_at_ms: int = 0
var _duration_ms: int = 24000
var _watermark_visible: bool = false


## Begin the preview. preview_enabled=false OR a missing scene path → immediate graceful
## finish (AC-21 — never crash, never block boot on the preview).
func start(coordinator, config, scene_path: String = "") -> void:
	_coordinator = coordinator
	_config = config
	if config != null and not config.preview_enabled:
		_finish()  # knob off → step_preview latches immediately, no preview
		return
	if scene_path != "" and not ResourceLoader.exists(scene_path):
		# AC-21 / EC-15 — scene/asset load failure → graceful skip (zero crash, zero blank screen).
		_finish()
		return
	_duration_ms = int(config.preview_duration_sec * 1000.0) if config != null else 24000
	_started_at_ms = _now_ms()
	_running = true
	_watermark_visible = true


## Player tapped skip (≥44px affordance — UX-07). Skip is a legal completion (Rule 7).
func skip() -> void:
	if _running:
		_finish()


## EC-03 / AC-18 — a real workout started: cross-fade out, report done-by-workout.
func abort_for_workout() -> void:
	if _running:
		_finish()


## Duration-driven finish. The coordinator pumps this from _process (injected clock).
func tick() -> void:
	if _running and (_now_ms() - _started_at_ms) >= _duration_ms:
		_finish()


func is_running() -> bool:
	return _running


## 試演 watermark visibility (anti-deception — Pillar 1). True only while presenting.
func is_watermark_visible() -> bool:
	return _watermark_visible


func _finish() -> void:
	_running = false
	_watermark_visible = false
	preview_finished.emit()
	if _coordinator != null and _coordinator.has_method("notify_preview_finished"):
		_coordinator.notify_preview_finished()


func _now_ms() -> int:
	if _clock != null and _clock.has_method("now_ms"):
		return int(_clock.now_ms())
	return Time.get_ticks_msec()
