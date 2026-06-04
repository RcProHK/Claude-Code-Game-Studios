## WorkoutAudioAdapter — #20 Gym-Mode HUD audio-trigger consumer (Story 007)
##
## Dedicated child node of GymModeHud. The ONLY place that consumes the raw #2 set_logged
## signal — and it consumes it for SFX TRIGGERING ONLY, never for count/EXP visuals (those go
## through the #9-validated path, Story 005). This is the EG-1-relocated ownership (#4 audio's
## workout-SFX forwarding lives here, NOT in #9 which is a pure data/event layer).
##
## Responsibilities:
##   - GSM-state-level audio gate (∈ {WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER})
##   - buffer mid/high SFX while audio LOCKED (FIFO cap), drop low; flush priority-desc on unlock
##   - set_complete × streak_chime stagger (CR-11) via an injectable timer (no wall-clock)
##   - exit cleanup (no dangling play_sfx on a freed node)
##
## Audio gate is INTENTIONALLY non-generational (enhancement layer): a mid-transition stale read
## may drop/double one chime. This is an explicit asymmetry vs the visual reconcile (SM-C) — audio
## is enhancement, the Silent Witness's truth is the visual layer.
##
## Driving GDD: design/gdd/gym-mode-hud.md CR-9/10/11, EC-A1/A4, EC-S4*
## Governing ADR: ADR-0002 GymSys Integration · ADR-0009 Signal Payload
extends Node


## SFX priority mirror of #4 audio_manager.gd SfxPriority { LOW=0, MID=1, HIGH=2 }.
## Only MID/HIGH are buffered while locked; LOW is dropped (transient, not worth a deferred play).
enum Priority { LOW = 0, MID = 1, HIGH = 2 }

## FIFO buffer cap while audio is locked (oldest dropped on overflow). Config const.
const PENDING_BUFFER_CAP: int = 12

## Inter-SFX delay on flush (anti voice-steal — high-priority flush does not stomp itself). ms.
const FLUSH_STAGGER_MS: int = 40

## set_complete → streak_chime stagger (CR-11). The chime trails the set-complete stinger. ms.
const SET_STREAK_CHIME_STAGGER_MS: int = 100

## The SFX event fired on a logged set (raw #2 set_logged → this catalog event).
const SFX_SET_COMPLETE: StringName = &"set_complete"
const SFX_STREAK_CHIME: StringName = &"streak_chime"

## GSM states in which workout SFX may trigger (GDD CR-9 gate). Built in _ready (enum at runtime).
var _gate_states: Dictionary = {}

## Untyped DI seams.
var _audio_manager  ## #4 AudioManager — play_sfx / is_audio_unlocked / audio_unlocked
var _gsm            ## GameStateMachine — get_current_state
var _gymsys         ## #2 GymSysClient — set_logged signal source (optional; tests may call directly)
var _sfx_catalog    ## priority lookup: Dictionary(event_id→int) OR object.get_priority(event_id)
var _timer_service  ## ITimerService seam: schedule(delay_sec: float, cb: Callable). null → immediate.

## FIFO buffer of {event_id, priority} while audio is locked.
var _pending: Array = []


func _ready() -> void:
	_gate_states = {
		GameStateMachine.GameState.WORKOUT_ACTIVE: true,
		GameStateMachine.GameState.REST_PERIOD: true,
		GameStateMachine.GameState.COMBAT_ACTIVE: true,
		GameStateMachine.GameState.BOSS_ENCOUNTER: true,
	}
	if _audio_manager != null:
		_audio_manager.audio_unlocked.connect(_on_audio_unlocked)
	if _gymsys != null and _gymsys.has_signal("set_logged"):
		# ONLY the adapter consumes raw set_logged — for SFX, never for count/visual.
		_gymsys.set_logged.connect(_on_set_logged)


func _exit_tree() -> void:
	# AC-EC-A1: clear the buffer so a freed node never flushes a dangling play_sfx.
	_pending.clear()


# ── Public / handler surface ──

## Raw #2 set_logged handler (the ONLY raw consumer). Fires the set-complete SFX request.
func _on_set_logged(_exercise_id: Variant, _reps: Variant = 0, _weight: Variant = 0.0) -> void:
	handle_sfx_request(SFX_SET_COMPLETE)


## Core gate + buffer/play decision for a single SFX request (AC-CR-9 / CR-10 / EC-S4).
func handle_sfx_request(event_id: StringName) -> void:
	if not _in_audio_gate_state():
		return  # deny-side: outside the workout audio gate → no SFX (EC-S4*)
	if _is_unlocked():
		_play(event_id)  # AC-CR-9: unlocked → play immediately
		return
	# LOCKED: buffer mid/high (FIFO cap), drop low.
	var prio: int = _get_priority(event_id)
	if prio < Priority.MID:
		return  # low priority → drop (not worth a deferred play)
	_pending.append({"event_id": event_id, "priority": prio})
	while _pending.size() > PENDING_BUFFER_CAP:
		_pending.pop_front()  # FIFO drop oldest


## set_complete with optional streak chime (CR-11 / EC-S6 fallback). When a streak chime is
## available it trails set_complete by SET_STREAK_CHIME_STAGGER_MS via the injectable timer;
## when #8 is not wired (has_streak=false) set_complete plays immediately with no stagger (EC-S6).
func handle_set_complete(has_streak: bool) -> void:
	handle_sfx_request(SFX_SET_COMPLETE)
	if not has_streak:
		return  # EC-S6: no #8 streak → no deferred chime, no waiting
	# CR-11: schedule the chime to trail the stinger (no wall-clock — ITimerService seam).
	var delay_sec: float = SET_STREAK_CHIME_STAGGER_MS / 1000.0
	if _timer_service != null and _timer_service.has_method("schedule"):
		_timer_service.schedule(delay_sec, _fire_streak_chime)
	else:
		_fire_streak_chime()


## Deferred streak-chime fire (AC-EC-A4 guard): only if still in tree AND still in a gate state.
func _fire_streak_chime() -> void:
	if not is_inside_tree():
		return  # node freed / suspended → drop (no dangling play_sfx)
	if not _in_audio_gate_state():
		return
	_play(SFX_STREAK_CHIME)


## audio_unlocked → flush buffered SFX in priority-desc order (AC-CR-10).
func _on_audio_unlocked() -> void:
	if _pending.is_empty():
		return
	# Priority-desc (HIGH first), stable for equal priority (preserve FIFO within a tier).
	var ordered: Array = _pending.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"]))
	_pending.clear()
	for i: int in ordered.size():
		var event_id: StringName = ordered[i]["event_id"]
		if _timer_service != null and _timer_service.has_method("schedule"):
			var delay_sec: float = (i * FLUSH_STAGGER_MS) / 1000.0
			_timer_service.schedule(delay_sec, _play.bind(event_id))
		else:
			_play(event_id)  # no timer seam → flush immediately (tests / headless)


# ── Internal helpers ──

func _in_audio_gate_state() -> bool:
	if _gsm == null:
		return false
	return _gate_states.has(int(_gsm.get_current_state()))


func _is_unlocked() -> bool:
	return _audio_manager != null and _audio_manager.is_audio_unlocked()


## Priority for an event_id from the injected SfxCatalog (Dictionary or object.get_priority).
## No catalog → default MID (buffered, conservative — never silently drop a real chime).
func _get_priority(event_id: StringName) -> int:
	if _sfx_catalog == null:
		return Priority.MID
	if _sfx_catalog is Dictionary:
		return int(_sfx_catalog.get(event_id, Priority.MID))
	if _sfx_catalog.has_method("get_priority"):
		return int(_sfx_catalog.get_priority(event_id))
	return Priority.MID


func _play(event_id: StringName) -> void:
	if _audio_manager != null and _audio_manager.has_method("play_sfx"):
		_audio_manager.play_sfx(event_id)


# ── Test seams ──

## Current buffered SFX count (AC-CR-10 / EC-A1 assertion point).
func get_pending_size() -> int:
	return _pending.size()
