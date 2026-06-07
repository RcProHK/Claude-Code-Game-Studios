# AudioManager — Autoload (#4, Foundation; ADR-0008 pos 11+ block)
#
# Status: PARTIAL — Story 001 (closed-API gateway surface + CI lint + pure test seams + boot
#   scaffold). Bus topology + volume persistence + Formula 2: Story 002. SFX pool + priority
#   steal: Story 003. Ducking tween + Music-bus application (Formula 3): Story 004. BGM
#   equal-power crossfade (Formula 1): Story 005. GSM state→music map: Story 006. Safari
#   unlock flow: Story 007. SUSPENDED multi-source: Story 008. BGM variant rotation: Story 009.
#
# Driving GDD: design/gdd/audio-manager.md (Approved 2026-06-02, Pass 6)
# Governing ADRs: ADR-0008 (autoload position) + ADR-0006 Contract 4/6 (boot order +
#   connect_for_initial_state sentinel subscription).
#
# Closed gateway (GDD Rule 1): ALL SFX/BGM playback + AudioServer bus mutation MUST route
#   through this autoload. No external code may `AudioServer.`, `AudioStreamPlayer.new()`, or
#   set `AudioStreamPlayer.bus` directly (CI lint: tools/ci/check_audio_callers.gd).
#
# NO `class_name` — registered as the `AudioManager` autoload singleton in project.godot
#   (a matching class_name would error "hides an autoload singleton"). Tests preload this
#   script via `const AM := preload(...)` to reach enums / new() / seams.
extends Node


# ── Public API enums ──────────────────────────────────────────────────────────

## Audio bus targets for volume/mute control (GDD Rule 2: Master → {Music, SFX}).
enum Bus { MASTER = 0, MUSIC = 1, SFX = 2 }


# ── Tuning constants (GDD Tuning Knobs — full table consumed by Stories 002+) ──
const DEFAULT_MASTER_DB: float = 0.0
const DEFAULT_MUSIC_DB: float = -6.0    ## subtle default (game-concept locked)
const DEFAULT_SFX_DB: float = 0.0
const MUTE_FLOOR_DB: float = -80.0
const MAX_BUS_DB: float = 0.0           ## MVP: boost forbidden (anti-clipping)
const DUCK_OFFSET_DB: float = -8.0      ## high-priority duck depth
const STREAK_CHIME_DUCK_OFFSET_DB: float = -5.0  ## mid-priority shallow duck
const DUCK_ATTACK_SEC: float = 0.05     ## duck lerp-down time (Story 004)
const DUCK_RELEASE_SEC: float = 0.4     ## long/high stinger lerp-back time (Story 004)
const SHALLOW_RELEASE_SEC: float = 0.15 ## short/mid stinger lerp-back (anti-pumping; release_class dispatch deferred)
const SFX_VOICE_COUNT: int = 8          ## fixed pool size (web budget; filled Story 003)
const BGM_DEFAULT_FADE_SEC: float = 1.0 ## default BGM crossfade time (Story 005)
const BOSS_THEME_FADE_SEC: float = 0.25 ## short fade into boss_theme — sharpens the stakes signal (Story 006)
const LOOT_BGM_TRANSITION_SEC: float = 0.25 ## LOOT_DROP-from-BOSS quick fade boss_theme→rest_calm (情境A; Story 006)
const FOCUS_LOW_VARIANT_COUNT: int = 3  ## focus_low rotation pool size — anti-fatigue (Story 009)
const BGM_MIN_LOOP_SEC: float = 90.0    ## min BGM loop length; shorter → fatigue warning (Story 009)
const BGM_CATALOG_PATH: String = "res://assets/data/bgm_catalog.tres"


# ── Lifecycle + SUSPENDED multi-source bitmask (Story 008) ─────────────────────
enum LifecycleState { BOOTING = 0, READY = 1, SUSPENDED = 2 }
var _lifecycle_state: LifecycleState = LifecycleState.BOOTING

## Suspend source bits (ADR-0006 C4 service axis). First-entry latch (0→non-zero pauses), last-exit
## resume (→0 resumes) — so three independent sources never double-pause / prematurely resume.
const _SUSPEND_GSM: int = 1     ## GSM → SUSPENDED state
const _SUSPEND_OS: int = 2      ## NOTIFICATION_APPLICATION_PAUSED (mobile background)
const _SUSPEND_FOCUS: int = 4   ## NOTIFICATION_WM_WINDOW_FOCUS_OUT (web tab blur)
var _suspend_sources: int = 0
## BGM state recorded at pause for resume-from-position. {variant_id: StringName, position_sec: float}.
var _suspended_bgm_state: Dictionary = {}
## focus_low's variant+position recorded when boss_theme replaces it (Rule 4 boss-exit resume).
## INDEPENDENT of _suspended_bgm_state — the two record different things and never overwrite (AC-34).
var _paused_focus_low: Dictionary = {}
## Test seams: pause/resume fired exactly once per latch cycle (AC-30 dedup).
var _pause_fire_count: int = 0
var _resume_fire_count: int = 0


# ── Orthogonal unlock flag (GDD Rule 5 — a derived gate, NOT a GSM state) ──────
## true once audio is unlocked: desktop/native boot, or web first gesture (Story 007).
var _audio_unlocked: bool = false
## Single-slot deferred BGM request while LOCKED (latest-wins). On unlock the GSM-current track
## is preferred; this is only the fallback when the current state has no music mapping (Story 007).
var _deferred_bgm_track: StringName = &""


# ── Duck refcount source-of-truth (GDD Formula 3; multiset semantics) ──────────
## handle → offset_db. refcount = size(). Story 004 lerps the Music bus toward the target.
var _active_ducks: Dictionary = {}
var _next_duck_handle: int = 1
## Music bus base dB (default; Story 002 reflects the live slider). _compute_duck_target floor.
var _base_music_db: float = DEFAULT_MUSIC_DB
## Single retained duck Tween (Story 004). Kill-before-respawn (no stacked Tweens); idle-gated
## (refcount 0 + at base → killed, never spawned) so idle frames never touch AudioServer.
var _duck_tween: Tween = null


# ── BGM crossfade (Story 005) ──────────────────────────────────────────────────
## Two dedicated Music-bus players for equal-power crossfade (one out, one in).
var _bgm_players: Array[AudioStreamPlayer] = []
## Index of the currently-audible / crossfade-target player (-1 = nothing playing).
var _bgm_active_idx: int = -1
## track_id currently playing (&"" = none). Same-track play_bgm → idempotent no-op.
var _current_bgm_track: StringName = &""
## track_id → {stream:AudioStream, ...}. null until loaded/injected (safe mode if missing).
var _bgm_catalog = null
var _bgm_safe_mode: bool = false
## focus_low rotation state (Story 009): last-played variant index (-1 = none) for non-immediate-repeat.
var _bgm_last_variant: int = -1
## Test seam: count of BGM tracks flagged as shorter than BGM_MIN_LOOP_SEC at boot (AC-27).
var _bgm_loop_warning_count: int = 0
var _active_crossfade_count: int = 0    ## 0 = idle, 1 = crossfade in-flight (single retained tween)
var _crossfade_progress: float = -1.0   ## sentinel < 0 ⇒ no crossfade in-flight; else p ∈ [0,1]
var _crossfade_tween: Tween = null
## GSM GameState (int) → {track:StringName, fade:float} music map (Story 006; built at boot from
## GameStateMachine.GameState). States with no entry → maintain current BGM. LOOT_DROP handled
## conditionally in _on_gsm_state_changed (情境A/B), not via this map.
var _gsm_track_map: Dictionary = {}


# ── SFX pool + priority-aware voice stealing (Story 003) ───────────────────────

## SFX priority for ducking + voice-steal protection (GDD Rule 3 / catalog `priority` field).
## Declaration order is load-bearing: a higher ordinal is harder to steal (LOW stolen first).
enum SfxPriority { LOW = 0, MID = 1, HIGH = 2 }

## Data-driven catalog resource path (GDD Rule 3). Real streams land via /asset-spec (Q8);
## until then production runs in safe no-op mode (missing → push_error once, AC-16).
const SFX_CATALOG_PATH: String = "res://assets/data/sfx_catalog.tres"

## Fixed pool of non-positional AudioStreamPlayer (built at boot on the SFX bus).
var _sfx_pool: Array[AudioStreamPlayer] = []
## Per-slot logical "busy" flag — AudioManager-owned, INDEPENDENT of engine `.playing`.
## The headless Dummy audio driver does not guarantee `.playing`; internal logic
## (steal victim selection, voice-count, pool occupancy) NEVER reads `.playing`.
var _voice_busy: Array[bool] = []
## Per-slot priority of the currently-assigned voice (steal protection).
var _voice_priority: Array[int] = []
## Per-slot monotonic assignment sequence — lowest = oldest = stolen first among equal priority.
var _voice_seq: Array[int] = []
var _next_seq: int = 0
## Per-slot duck handle (-1 = no duck). mid/high voices register a duck; steal + finished release
## it (Rule 7b — Godot 4.6 steal does NOT emit `finished`, so both paths release explicitly).
var _voice_duck_handle: Array[int] = []
## event_id → {priority:int, channels:String, stream:AudioStream}. null until loaded/injected.
var _sfx_catalog = null
## True when the catalog resource is missing/invalid → all play_sfx become no-ops (AC-16).
var _sfx_safe_mode: bool = false
var _unknown_event_count: int = 0


# ── Dependency injection seams (untyped — typed Node fails compile-time member check) ──
var _gsm = null              ## GameStateMachine (connect_for_initial_state — ADR-0006 C6)
var _platform_detect = null  ## PlatformDetect (is_web → unlock strategy; Story 007)
var _persistence = null      ## PersistenceLayer (audio.* namespace — Story 002)


# ── Signals ────────────────────────────────────────────────────────────────────

## Emitted exactly once on the first gesture unlock (web) — #20 banner subscribes to dismiss.
signal audio_unlocked()

## Emitted at crossfade START (NOT completion — headless Tween does not advance; Story 005/006).
signal bgm_changed(track_id: StringName)


func _ready() -> void:
	# #21 G-LM-9: ceremony_freeze pauses the SceneTree — a PAUSABLE AudioManager
	# would stutter the fanfare 0.4s right at the dopamine peak. ALWAYS keeps the
	# SFX pool players (children — they inherit) running through the freeze.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Resolve DI seams to autoload singletons. Tests inject mocks BEFORE add_child (the
	# `== null` guards leave an injected seam untouched), so this never clobbers a mock.
	if _gsm == null:
		_gsm = GameStateMachine
	if _platform_detect == null:
		_platform_detect = PlatformDetect
	if _persistence == null:
		_persistence = PersistenceLayer

	# Unlock gate (GDD Rule 5): desktop/native unlocked at boot; web waits for a gesture (Story 007).
	_audio_unlocked = not _is_web()

	# GSM subscription (ADR-0006 Contract 6): connect_for_initial_state, NO .bind. The full
	# state→track music map is Story 006; this story wires only the sentinel-safe subscription.
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)

	# Bus topology (Rule 2) → SFX pool (Story 003; routes to SFX bus) → SFX catalog → persisted
	# volume/mute (Story 002). No sound on boot.
	_ensure_buses()
	_build_sfx_pool()
	_load_sfx_catalog()
	_build_bgm_pool()
	_load_bgm_catalog()
	_validate_bgm_loop_lengths()
	_build_gsm_track_map()
	_load_persisted_volumes()

	_lifecycle_state = LifecycleState.READY


# ── Unlock (GDD Rule 5 — Story 007) ────────────────────────────────────────────

## Unlock audio on the first user gesture (web). Idempotent — early-returns if already unlocked.
## Two callers race harmlessly: _input() (engine-level fallback for any real gesture) and #20's
## banner `pressed` (the canonical UX path). Whichever fires first unlocks; the other is a no-op.
func _do_unlock() -> void:
	if _audio_unlocked:
		return
	_audio_unlocked = true
	audio_unlocked.emit()
	# First real action gets an audible response (Player Fantasy): a confirm chime (mid priority
	# so a same-frame combat SFX cannot steal it).
	play_sfx(&"audio_unlock_confirm")
	# Start BGM from the GSM's CURRENT state — NOT the stale deferred slot (pre-unlock state churn
	# could have queued a now-ended encounter's track). The deferred slot is only a fallback when
	# the current state has no music mapping.
	var started: bool = false
	if _gsm != null and _gsm.has_method("get_current_state"):
		var entry: Dictionary = _gsm_track_map.get(int(_gsm.get_current_state()), {})
		if not entry.is_empty():
			play_bgm(entry["track"], entry["fade"])
			started = true
	if not started and _deferred_bgm_track != &"":
		play_bgm(_deferred_bgm_track)
	_deferred_bgm_track = &""

## Engine-level unlock fallback: any real gesture unlocks (idempotent). #20's banner `pressed` is
## the canonical path; this guarantees unlock even on a stray tap outside the banner. Does not
## consume the event (no set_input_as_handled) — the banner and other nodes still receive it.
func _input(event: InputEvent) -> void:
	if _audio_unlocked:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_do_unlock()


# ── Public API (closed gateway — bodies filled by Stories 002-009) ─────────────

## Play a one-shot pooled SFX by catalog event_id. Acquires a free voice or, when the pool is
## full, priority-aware steals the lowest-priority (then oldest) voice — a high-priority voice
## (loot fanfare / boss stinger) is never stolen while any lower-priority voice exists (Pillar 3).
## Unknown event_id → push_warning + no-op (Foundation no-throw, Rule 8). Catalog missing → no-op.
func play_sfx(event_id: StringName) -> void:
	if _sfx_safe_mode:
		return  # catalog missing — already push_error'd once at boot (AC-16)
	if not _audio_unlocked:
		push_warning("[AudioManager] play_sfx(%s) dropped — audio locked (pre-gesture)" % event_id)
		return  # GDD Rule 5: one-shot SFX dropped while LOCKED (Story 007 owns the unlock flow)
	var entry: Dictionary = _lookup_sfx(event_id)
	if entry.is_empty():
		push_warning("[AudioManager] play_sfx unknown event_id: %s" % event_id)
		_unknown_event_count += 1
		return  # Rule 8 no-throw (AC-10)
	var slot: int = _acquire_slot()
	# If we stole an active voice, release any duck it held (Rule 7b). Godot 4.6 steal does NOT
	# emit `finished`, so the refcount must be decremented here or the Music bus ducks forever.
	if _voice_busy[slot] and _voice_duck_handle[slot] != -1:
		_release_duck(_voice_duck_handle[slot])
		_voice_duck_handle[slot] = -1
	var prio: int = int(entry.get("priority", SfxPriority.LOW))
	_voice_busy[slot] = true
	_voice_priority[slot] = prio
	_voice_seq[slot] = _next_seq
	_next_seq += 1
	# Mid/high voices duck the Music bus (Rule 7 / Formula 3); low voices do not duck.
	var duck_offset: float = _priority_duck_offset(prio)
	_voice_duck_handle[slot] = _register_duck(duck_offset) if duck_offset < 0.0 else -1
	_apply_duck()
	var stream: AudioStream = entry.get("stream", null)
	if stream != null:
		var player: AudioStreamPlayer = _sfx_pool[slot]
		player.stream = stream
		player.play()
	# NOTE: stream is null until /asset-spec produces the catalog audio (Q8). Logical voice
	# occupancy (_voice_busy) is the source of truth for steal/count — never engine .playing.

## Equal-power crossfade BGM to track_id over fade_in_sec (GDD Rule 4 / Formula 1). Same track
## already playing → idempotent no-op (no re-emit, no restart). Unknown track → push_warning +
## no-op (Rule 8). fade_in_sec ≤ 0 → instant-swap (no div-by-zero). `bgm_changed` is emitted at
## crossfade START (IB-7 — headless Tweens never advance, so emit-at-complete would phantom).
func play_bgm(track_id: StringName, fade_in_sec: float = BGM_DEFAULT_FADE_SEC) -> void:
	if _bgm_safe_mode:
		return  # catalog missing — push_error'd once at boot
	if not _audio_unlocked:
		_deferred_bgm_track = track_id  # GDD Rule 5: LOCKED → single-slot deferred (latest-wins)
		return
	if track_id == _current_bgm_track:
		return  # AC-04 idempotent no-op (no restart, no re-emit)
	var entry: Dictionary = _lookup_bgm(track_id)
	if entry.is_empty():
		push_warning("[AudioManager] play_bgm unknown track_id: %s" % track_id)
		return  # Rule 8 no-throw
	var players: Vector2i = _pick_crossfade_players()  # x = in, y = out (-1 = none)
	var in_idx: int = players.x
	var out_idx: int = players.y
	var stream: AudioStream = entry.get("stream", null)
	if stream != null:
		_bgm_players[in_idx].stream = stream
		_bgm_players[in_idx].play()
	_current_bgm_track = track_id
	_bgm_active_idx = in_idx
	bgm_changed.emit(track_id)  # IB-7: emit at crossfade START
	if fade_in_sec <= 0.0:
		_instant_swap_bgm(in_idx, out_idx)  # AC-21
	else:
		_start_crossfade(in_idx, out_idx, fade_in_sec)

## Crossfade the current BGM out to silence then stop. fade_out_sec ≤ 0 → instant stop.
func stop_bgm(fade_out_sec: float = BGM_DEFAULT_FADE_SEC) -> void:
	if _bgm_active_idx == -1:
		return
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	var active: AudioStreamPlayer = _bgm_players[_bgm_active_idx]
	if fade_out_sec <= 0.0:
		active.stop()
	else:
		var idx: int = _bgm_active_idx
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_method(
			func(db: float) -> void: _bgm_players[idx].volume_db = db,
			active.volume_db, MUTE_FLOOR_DB, fade_out_sec,
		)
		_crossfade_tween.finished.connect(active.stop, CONNECT_ONE_SHOT)
	_current_bgm_track = &""
	_bgm_active_idx = -1
	_crossfade_progress = -1.0
	_active_crossfade_count = 0

## Set a bus volume in dB. NaN/inf → MUTE_FLOOR_DB; finite values clamped to
## [MUTE_FLOOR_DB, MAX_BUS_DB] (boost forbidden — anti-clipping). Persisted to audio.<bus>_db.
## For MUSIC, also updates the un-ducked base level (_base_music_db; Story 004 ducks below it).
func set_bus_volume_db(bus: Bus, db: float) -> void:
	var safe_db: float = MUTE_FLOOR_DB if (is_nan(db) or is_inf(db)) else db
	var clamped: float = clampf(safe_db, MUTE_FLOOR_DB, MAX_BUS_DB)
	if not (is_nan(db) or is_inf(db)) and not is_equal_approx(clamped, db):
		push_warning("[AudioManager] set_bus_volume_db %f outside [%f, %f] — clamped to %f" % [
			db, MUTE_FLOOR_DB, MAX_BUS_DB, clamped,
		])
	var idx: int = _bus_index(bus)
	if bus == Bus.MUSIC:
		_base_music_db = clamped
		# Music bus reflects the duck-effective target (= base when no duck is active), so a
		# slider change mid-duck retargets relative to the new base instead of un-ducking.
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, _compute_duck_target(_active_ducks))
	elif idx != -1:
		AudioServer.set_bus_volume_db(idx, clamped)
	_persist_write("audio." + _bus_key(bus) + "_db", clamped)

## Read the current (live) dB of a bus from AudioServer.
func get_bus_volume_db(bus: Bus) -> float:
	var idx: int = _bus_index(bus)
	return AudioServer.get_bus_volume_db(idx) if idx != -1 else MUTE_FLOOR_DB


## G-CS-11 (#22 story 012) — linear slider 入口。Formula 2(L197-213)locus
## 留喺 #4:`db = linear_to_db(s)`,s ∈ [0,1],s=0 → MUTE_FLOOR(slider 最低
## = 靜音)。#22 MASTER volume slider 經呢度 call — #22 源碼禁出現任何
## linear→dB 數學(duplicate ban;#22 AC-52 assert)。Corrupt s(NaN/inf)→
## 0.0(靜音 — 保守安全向);persistence 由 set_bus_volume_db 內部做
## (audio.<bus>_db,Rule 9 — #22 零 audio.* write)。
func set_bus_volume_linear(bus: Bus, s: float) -> void:
	var safe_s: float = 0.0 if (is_nan(s) or is_inf(s)) else clampf(s, 0.0, 1.0)
	if safe_s <= 0.0:
		set_bus_volume_db(bus, MUTE_FLOOR_DB)
		return
	set_bus_volume_db(bus, linear_to_db(safe_s))


## G-CS-11 配對 getter — #22 panel open 現值 read(slider 初始位)。
## dB→linear 數學同樣留喺 #4(duplicate ban 對稱);MUTE_FLOOR → 0.0。
func get_bus_volume_linear(bus: Bus) -> float:
	var db: float = get_bus_volume_db(bus)
	if db <= MUTE_FLOOR_DB:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)

## Mute / unmute a bus. Persisted independently of volume (unmute restores the prior dB).
func set_bus_muted(bus: Bus, muted: bool) -> void:
	var idx: int = _bus_index(bus)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)
	_persist_write("audio." + _bus_key(bus) + "_muted", muted)

## True once audio is unlocked (desktop boot, or web after the first user gesture).
func is_audio_unlocked() -> bool:
	return _audio_unlocked


# ── Test seams (pure functions — GUT calls these directly; NOT for production callers) ──

## Register an active duck; returns a monotonic voice handle. offset MUST be ≤ 0 (an
## attenuation). A positive offset (caller bug) is clamped to 0 (no-op duck) + warned —
## the Music bus is NEVER raised (would break the Pillar 3 reward-peak contrast).
func _register_duck(offset: float) -> int:
	if offset > 0.0:
		# Loud debug catch (push_error, NOT assert — assert would abort GUT and make AC-09d
		# untestable). Production safety = the clamp below (a positive offset becomes a no-op
		# duck; the Music bus is NEVER raised, which would break the Pillar 3 reward contrast).
		push_error("[AudioManager] _register_duck got positive offset %f — clamped to 0 (no duck)" % offset)
	var stored: float = clampf(offset, MUTE_FLOOR_DB, 0.0)
	var handle: int = _next_duck_handle
	_next_duck_handle += 1
	_active_ducks[handle] = stored
	return handle

## Release a duck by handle. Idempotent — Dictionary.erase on an absent key is a no-op, so
## the steal path and the `finished` path may both call this safely (no under-duck risk).
func _release_duck(handle: int) -> void:
	_active_ducks.erase(handle)

## Pure: dict{handle→offset} → Music-bus duck target dB. Empty dict → base (guarded so we
## never call `min([])`, which returns null → runtime error). min(values()) picks the
## DEEPEST offset (offsets are negative); floored at MUTE_FLOOR_DB.
func _compute_duck_target(ducks: Dictionary) -> float:
	if ducks.is_empty():
		return _base_music_db
	return maxf(_base_music_db + ducks.values().min(), MUTE_FLOOR_DB)

## Count of logically-busy voice slots (`_voice_busy == true`) — NOT engine `.playing`.
func _test_get_active_voice_count() -> int:
	var n: int = 0
	for busy: bool in _voice_busy:
		if busy:
			n += 1
	return n

## Active crossfade count (0 or 1) — Godot exposes no per-node Tween registry, so this
## member proxy is the headless-verifiable source of truth (start ++, kill/complete --).
func _test_get_active_crossfade_count() -> int:
	return _active_crossfade_count


# ── Internal ────────────────────────────────────────────────────────────────────

## GSM state→track music transition (ADR-0006 C6). The initial-state sentinel is a no-op (audio
## does not auto-start BGM at boot — web is LOCKED until a gesture; unlock re-queries GSM, Story 007).
## States with no map entry maintain the current BGM. Signature matches the typed `state_changed`.
func _on_gsm_state_changed(from: Variant, to: Variant, payload: Variant = null) -> void:
	# Initial-state sentinel (Contract 6) → noop (AC-08). Carried by payload.source_event.
	if payload != null and payload.get(&"source_event") == "initial_state":
		return
	var to_state: int = int(to)
	# Suspend axis (ADR-0006 C4) — GSM SUSPENDED is bit 0. Entering pauses; leaving resumes
	# (restores the recorded BGM). No music-map dispatch while the suspend bit toggles.
	if to_state == GameStateMachine.GameState.SUSPENDED:
		_set_suspend_source(_SUSPEND_GSM, true)
		return
	if _suspend_sources & _SUSPEND_GSM:
		_set_suspend_source(_SUSPEND_GSM, false)
		return
	# Rule 4 boss-exit: entering BOSS_ENCOUNTER while focus_low plays records focus_low's
	# variant+position so WORKOUT_ACTIVE re-entry can resume it (independent of _suspended_bgm_state).
	if to_state == GameStateMachine.GameState.BOSS_ENCOUNTER and _current_bgm_track == &"focus_low_pool":
		_paused_focus_low = {"variant_id": _current_bgm_track, "position_sec": _bgm_position()}
	# LOOT_DROP is conditional (情境A/B), not in the static map.
	if to_state == GameStateMachine.GameState.LOOT_DROP:
		# 情境A — from BOSS_ENCOUNTER: quick fade boss_theme → rest_calm so the loot peak lands on a
		# calm bed (the loot fanfare SFX then ducks rest_calm, Rule 7). ⚠️ The from-state assumption
		# depends on #15 confirming boss-kill → LOOT_DROP comes from BOSS_ENCOUNTER (EG-3 gate).
		# 情境B — from non-boss (workout-time loot): keep focus_low (stinger duck suffices).
		if int(from) == GameStateMachine.GameState.BOSS_ENCOUNTER:
			play_bgm(&"rest_calm", LOOT_BGM_TRANSITION_SEC)
		return
	var entry: Dictionary = _gsm_track_map.get(to_state, {})
	if entry.is_empty():
		return  # state with no track entry → keep current BGM (no change, no warning)
	play_bgm(entry["track"], entry["fade"])

## Web-platform detection via the injected seam, falling back to the engine feature flag when
## PlatformDetect (a stub) does not yet expose is_web(). Story 007 makes the seam canonical.
func _is_web() -> bool:
	if _platform_detect != null and _platform_detect.has_method("is_web"):
		return bool(_platform_detect.is_web())
	return OS.has_feature("web")


# ── Bus mapping + volume persistence (Story 002) ───────────────────────────────

## Bus enum → AudioServer bus name (GDD Rule 2 topology).
func _bus_name(bus: Bus) -> StringName:
	match bus:
		Bus.MUSIC: return &"Music"
		Bus.SFX: return &"SFX"
		_: return &"Master"

## Bus enum → short token used in the audio.<token>_db / _muted persistence keys.
func _bus_key(bus: Bus) -> String:
	match bus:
		Bus.MUSIC: return "music"
		Bus.SFX: return "sfx"
		_: return "master"

## Bus enum → default dB (GDD Rule 2: Master 0 / Music −6 subtle / SFX 0).
func _bus_default_db(bus: Bus) -> float:
	match bus:
		Bus.MUSIC: return DEFAULT_MUSIC_DB
		Bus.SFX: return DEFAULT_SFX_DB
		_: return DEFAULT_MASTER_DB

func _bus_index(bus: Bus) -> int:
	return AudioServer.get_bus_index(_bus_name(bus))

## Create the Music + SFX sub-buses (routed to Master) if they don't exist yet. Idempotent —
## safe to call on every boot. The gateway is the CI-exempt owner of AudioServer bus mutation.
func _ensure_buses() -> void:
	for bus_name: StringName in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")

## Formula 2: settings slider (0–1) → dB. NaN/inf → 0; s≤0 → MUTE_FLOOR_DB; else
## linear_to_db(maxf(s, 0.0001)) clamped to [MUTE_FLOOR_DB, MAX_BUS_DB]. No boost reachable here
## (s ≤ 1 ⇒ linear_to_db ≤ 0); a true boost needs a separate gain mapping (see GDD Formula 2 note).
func _slider_to_db(s: float) -> float:
	var s_safe: float = 0.0 if (is_nan(s) or is_inf(s)) else clampf(s, 0.0, 1.0)
	if s_safe <= 0.0:
		return MUTE_FLOOR_DB
	return clampf(linear_to_db(maxf(s_safe, 0.0001)), MUTE_FLOOR_DB, MAX_BUS_DB)

## Boot: apply persisted volume + mute for every bus. Missing key → default (no warn, normal
## first boot); NaN / non-numeric → default + warn; out-of-range finite → clamp + warn (AC-20a/b/c).
## Mute is re-applied every boot (default false) so it never leaks across reboots.
func _load_persisted_volumes() -> void:
	for bus: int in [Bus.MASTER, Bus.MUSIC, Bus.SFX]:
		var default_db: float = _bus_default_db(bus)
		var db: float = default_db
		var raw: Variant = _persist_read("audio." + _bus_key(bus) + "_db")
		if raw == null:
			db = default_db
		elif typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
			push_warning("[AudioManager] audio.%s_db non-numeric — using default %f" % [_bus_key(bus), default_db])
			db = default_db
		else:
			var v: float = float(raw)
			if is_nan(v) or is_inf(v):
				push_warning("[AudioManager] audio.%s_db NaN/inf — using default %f" % [_bus_key(bus), default_db])
				db = default_db
			elif v < MUTE_FLOOR_DB or v > MAX_BUS_DB:
				db = clampf(v, MUTE_FLOOR_DB, MAX_BUS_DB)
				push_warning("[AudioManager] audio.%s_db %f out of range — clamped to %f" % [_bus_key(bus), v, db])
			else:
				db = v
		var idx: int = _bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, db)
			var muted_raw: Variant = _persist_read("audio." + _bus_key(bus) + "_muted")
			AudioServer.set_bus_mute(idx, typeof(muted_raw) == TYPE_BOOL and muted_raw)
		if bus == Bus.MUSIC:
			_base_music_db = db

func _persist_read(key: String) -> Variant:
	if _persistence != null and _persistence.has_method("read"):
		return _persistence.read(key)
	return null

func _persist_write(key: String, value: Variant) -> void:
	if _persistence != null and _persistence.has_method("write"):
		_persistence.write(key, value)


# ── SFX voice pool + priority-aware stealing (Story 003) ───────────────────────

## Build the fixed AudioStreamPlayer pool on the SFX bus + the parallel occupancy arrays.
## Idempotent (guards against a double _ready). The SFX bus must already exist (_ensure_buses).
func _build_sfx_pool() -> void:
	if not _sfx_pool.is_empty():
		return
	_voice_busy.resize(SFX_VOICE_COUNT)
	_voice_busy.fill(false)
	_voice_priority.resize(SFX_VOICE_COUNT)
	_voice_priority.fill(SfxPriority.LOW)
	_voice_seq.resize(SFX_VOICE_COUNT)
	_voice_seq.fill(0)
	_voice_duck_handle.resize(SFX_VOICE_COUNT)
	_voice_duck_handle.fill(-1)
	for i: int in SFX_VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_pool.append(player)
		# Natural playback end frees the slot. Steal (Rule 3) does NOT emit `finished`
		# (Godot 4.6 stop()/replay is silent), so the steal path clears occupancy directly.
		player.finished.connect(_on_voice_finished.bind(i))

## A voice finished playing naturally → free its slot and release any duck it held (Rule 7b).
func _on_voice_finished(slot: int) -> void:
	if slot >= 0 and slot < _voice_busy.size():
		_voice_busy[slot] = false
		if _voice_duck_handle[slot] != -1:
			_release_duck(_voice_duck_handle[slot])
			_voice_duck_handle[slot] = -1
			_apply_duck()

## Return a slot index for a new voice: a free slot if any, else the steal victim =
## lowest-priority voice (oldest sequence among ties). High priority is protected while any
## lower-priority voice exists; only the all-high degenerate case steals the oldest high (Rule 3).
func _acquire_slot() -> int:
	for i: int in SFX_VOICE_COUNT:
		if not _voice_busy[i]:
			return i
	var victim: int = 0
	for i: int in range(1, SFX_VOICE_COUNT):
		var lower_priority: bool = _voice_priority[i] < _voice_priority[victim]
		var same_priority_older: bool = (
			_voice_priority[i] == _voice_priority[victim] and _voice_seq[i] < _voice_seq[victim]
		)
		if lower_priority or same_priority_older:
			victim = i
	return victim

## Look up a catalog entry by event_id. Empty dict = unknown event OR no catalog loaded.
func _lookup_sfx(event_id: StringName) -> Dictionary:
	if _sfx_catalog == null:
		return {}
	return _sfx_catalog.get(event_id, {})

## Boot: resolve the SFX catalog. An injected `_sfx_catalog` (tests) is used as-is. Otherwise
## attempt to load the .tres; if absent → safe no-op mode + a single push_error (AC-16). The
## real catalog schema + audio streams are produced by /asset-spec (Q8) — until then production
## runs in safe mode (priority/steal logic is fully implemented + unit-tested via injection).
func _load_sfx_catalog() -> void:
	if _sfx_catalog != null:
		_sfx_safe_mode = false
		return
	if ResourceLoader.exists(SFX_CATALOG_PATH):
		var res: Resource = load(SFX_CATALOG_PATH)
		_sfx_catalog = _build_catalog_dict(res)
		_sfx_safe_mode = _sfx_catalog.is_empty()
		if _sfx_safe_mode:
			push_error("[AudioManager] SfxCatalog at %s loaded but empty/invalid — SFX in safe no-op mode" % SFX_CATALOG_PATH)
	else:
		_sfx_catalog = {}
		_sfx_safe_mode = true
		push_error("[AudioManager] SfxCatalog missing at %s — SFX disabled (safe no-op mode)" % SFX_CATALOG_PATH)

## Build the event_id→entry dict from a loaded catalog resource. Defensive: expects an `entries`
## Array[Dictionary] of {event_id, priority, channels, stream}. (Schema finalised by /asset-spec.)
func _build_catalog_dict(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	if res == null or not (&"entries" in res):
		return out
	var entries: Variant = res.get(&"entries")
	if entries is Array:
		for e: Variant in entries:
			if e is Dictionary and e.has("event_id"):
				out[StringName(e["event_id"])] = e
	return out


# ── Ducking application (Story 004 — Formula 3 + single retained Tween + idle gate) ──

## SFX priority → Music-bus duck offset (dB). HIGH/MID duck; LOW does not duck (returns 0).
func _priority_duck_offset(prio: int) -> float:
	match prio:
		SfxPriority.HIGH: return DUCK_OFFSET_DB
		SfxPriority.MID: return STREAK_CHIME_DUCK_OFFSET_DB
		_: return 0.0

## Drive the Music bus toward the current duck target (Formula 3). Single retained Tween,
## killed-before-respawn (no stacked Tweens → no write race). Idle gate: with no active duck
## the Tween is killed and the bus hard-set to base — never spawned — so idle frames (90%+ of a
## session) never touch AudioServer. Uses a lambda closure, NEVER `.bind` (Godot 4.x bind appends
## args → set_bus_volume_db(dB, idx) arg-reversal → silent ducking failure).
func _apply_duck() -> void:
	var music_idx: int = _bus_index(Bus.MUSIC)
	if music_idx == -1:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if _active_ducks.is_empty():
		# Idle gate: refcount 0 → restore base, do not spawn a Tween.
		AudioServer.set_bus_volume_db(music_idx, _base_music_db)
		return
	var target: float = _compute_duck_target(_active_ducks)
	var from_db: float = AudioServer.get_bus_volume_db(music_idx)
	# Attack (going deeper) is fast; release (returning toward base) is slower (Rule 7b).
	var sec: float = DUCK_ATTACK_SEC if target < from_db else DUCK_RELEASE_SEC
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(music_idx, db),
		from_db, target, sec,
	)


# ── BGM equal-power crossfade (Story 005 — Formula 1) ──────────────────────────

## Build the two Music-bus BGM players (idempotent). The Music bus must already exist.
func _build_bgm_pool() -> void:
	if not _bgm_players.is_empty():
		return
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = MUTE_FLOOR_DB  # start silent
		add_child(player)
		_bgm_players.append(player)
		# Non-looping focus_low variant ends → rotate (Story 009). Looped tracks never fire this.
		player.finished.connect(_on_bgm_finished.bind(i))

## Formula 1 equal-power gains at progress p. Returns Vector2(out_gain, in_gain) — LINEAR gains.
## out_gain = cos(p·π/2), in_gain = sin(p·π/2) ⇒ out² + in² = 1 (constant perceived loudness, no
## mid-fade dip). p is clamped to [0,1] so a caller's elapsed/fade overrun never flips cos negative.
func _equal_power_gains(p: float) -> Vector2:
	var pc: float = clampf(p, 0.0, 1.0)
	return Vector2(cos(pc * PI / 2.0), sin(pc * PI / 2.0))

## Pick (in_idx, out_idx) for a new track. Steady state: in = the idle player, out = active. Mid-
## crossfade (only 2 players): keep the LOUDER player as the out-source, reuse the quieter (the
## previous out, already fading) as the in. Nothing playing: in = 0, out = -1.
func _pick_crossfade_players() -> Vector2i:
	if _bgm_active_idx == -1:
		return Vector2i(0, -1)
	if _crossfade_progress >= 0.0:
		var louder: int = 0 if _bgm_players[0].volume_db >= _bgm_players[1].volume_db else 1
		return Vector2i(1 - louder, louder)
	return Vector2i(1 - _bgm_active_idx, _bgm_active_idx)

## fade_sec ≤ 0 path: in player to full gain, out stopped, no crossfade in-flight (AC-21).
func _instant_swap_bgm(in_idx: int, out_idx: int) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_bgm_players[in_idx].volume_db = 0.0  # full gain on the Music bus
	if out_idx != -1 and out_idx != in_idx:
		_bgm_players[out_idx].stop()
	_crossfade_progress = -1.0
	_active_crossfade_count = 0

## Start an equal-power crossfade in p-space (NOT tween_property on volume_db — that is a linear-dB
## ramp whose midpoint dips to ~−40 dB, violating Formula 1). Single retained tween, kill-before-
## respawn. _crossfade_progress is written every step; the endpoint is hard-set in the finish
## callback (never relies on the cos(π/2) ≈ 6e-17 trig residual).
func _start_crossfade(in_idx: int, out_idx: int, fade_sec: float) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_bgm_players[in_idx].volume_db = MUTE_FLOOR_DB
	_crossfade_progress = 0.0
	_active_crossfade_count = 1
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_method(
		func(p: float) -> void: _crossfade_step(p, in_idx, out_idx),
		0.0, 1.0, fade_sec,
	)
	_crossfade_tween.finished.connect(
		func() -> void: _crossfade_finish(in_idx, out_idx), CONNECT_ONE_SHOT
	)

func _crossfade_step(p: float, in_idx: int, out_idx: int) -> void:
	var gains: Vector2 = _equal_power_gains(p)
	_bgm_players[in_idx].volume_db = linear_to_db(maxf(gains.y, 0.00001))
	if out_idx != -1 and out_idx != in_idx:
		_bgm_players[out_idx].volume_db = linear_to_db(maxf(gains.x, 0.00001))
	_crossfade_progress = p

func _crossfade_finish(in_idx: int, out_idx: int) -> void:
	_bgm_players[in_idx].volume_db = 0.0  # hard-set full (no trig residual)
	if out_idx != -1 and out_idx != in_idx:
		_bgm_players[out_idx].stop()
	_crossfade_progress = -1.0
	_active_crossfade_count = 0

## Look up a BGM catalog entry. Empty = unknown track OR no catalog.
func _lookup_bgm(track_id: StringName) -> Dictionary:
	if _bgm_catalog == null:
		return {}
	return _bgm_catalog.get(track_id, {})

## Boot: resolve the BGM catalog (injected → used as-is; else load the .tres; missing → safe mode
## + one push_error). Real tracks land via /asset-spec (Q8) — production runs safe until then.
func _load_bgm_catalog() -> void:
	if _bgm_catalog != null:
		_bgm_safe_mode = false
		return
	if ResourceLoader.exists(BGM_CATALOG_PATH):
		var res: Resource = load(BGM_CATALOG_PATH)
		_bgm_catalog = _build_catalog_dict(res)
		_bgm_safe_mode = _bgm_catalog.is_empty()
	else:
		_bgm_catalog = {}
		_bgm_safe_mode = true
		push_error("[AudioManager] BgmCatalog missing at %s — BGM disabled (safe no-op mode)" % BGM_CATALOG_PATH)


# ── GSM state → music map (Story 006 — ADR-0006 C6) ────────────────────────────

## Build the data-driven GameState→{track, fade} map. Keyed by GameStateMachine.GameState ints
## (the autoload boots at pos 2, before AudioManager at 11+, so the enum is available). Per-state
## fade override; BOSS_ENCOUNTER uses the short fade to sharpen the stakes signal. REST_PERIOD
## (NOT "REST_BETWEEN_SETS" — that is not a valid GameState) → rest_calm. LOOT_DROP is conditional
## and handled in _on_gsm_state_changed, not here.
func _build_gsm_track_map() -> void:
	_gsm_track_map = {
		GameStateMachine.GameState.WORKOUT_ACTIVE: {"track": &"focus_low_pool", "fade": BGM_DEFAULT_FADE_SEC},
		GameStateMachine.GameState.BOSS_ENCOUNTER: {"track": &"boss_theme", "fade": BOSS_THEME_FADE_SEC},
		GameStateMachine.GameState.REST_PERIOD: {"track": &"rest_calm", "fade": BGM_DEFAULT_FADE_SEC},
	}


# ── SUSPENDED multi-source pause/resume (Story 008 — ADR-0006 C4) ──────────────

## Set/clear a suspend source bit. First-entry latch (0 → non-zero pauses once); last-exit (→ 0
## resumes once). Three independent sources (GSM / OS / window-focus) never double-pause (AC-30).
func _set_suspend_source(bit: int, active: bool) -> void:
	var prev: int = _suspend_sources
	if active:
		_suspend_sources |= bit
	else:
		_suspend_sources &= ~bit
	if prev == 0 and _suspend_sources != 0:
		_pause_audio()
	elif prev != 0 and _suspend_sources == 0:
		_resume_audio()

## Pause all audio (first suspend source). Kills the retained duck + crossfade Tweens, hard-sets the
## Music bus to base (AC-33 — `_active_ducks` is RETAINED for resume), finalises any in-flight
## crossfade to its target, records the BGM state, and pauses the active BGM player. Does NOT touch
## `_audio_unlocked` (the unlock flag is orthogonal — LOCKED and SUSPENDED coexist, AC-14c).
func _pause_audio() -> void:
	_pause_fire_count += 1
	_lifecycle_state = LifecycleState.SUSPENDED
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	var music_idx: int = _bus_index(Bus.MUSIC)
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, _base_music_db)  # hard-set base; ducks NOT cleared
	# Finalise any interrupted crossfade to its target so resume is not stuck mid-mix (AC-14b).
	if _bgm_active_idx >= 0 and _bgm_active_idx < _bgm_players.size():
		for i: int in _bgm_players.size():
			if i != _bgm_active_idx:
				_bgm_players[i].stop()
		_bgm_players[_bgm_active_idx].volume_db = 0.0
	_crossfade_progress = -1.0
	_active_crossfade_count = 0
	# Record resume-from-position state + pause the active player.
	_suspended_bgm_state = {"variant_id": _current_bgm_track, "position_sec": _bgm_position()}
	if _bgm_active_idx >= 0 and _bgm_active_idx < _bgm_players.size():
		_bgm_players[_bgm_active_idx].stream_paused = true

## Resume audio (last suspend source cleared). Unpauses the BGM player and re-applies ducking from
## the retained `_active_ducks` (recomputes the target; base if empty). `_audio_unlocked` untouched.
func _resume_audio() -> void:
	_resume_fire_count += 1
	_lifecycle_state = LifecycleState.READY
	if _bgm_active_idx >= 0 and _bgm_active_idx < _bgm_players.size():
		_bgm_players[_bgm_active_idx].stream_paused = false
	_apply_duck()

## Window-focus pause/resume (NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN) → suspend source bit 2.
## Pure (testable headless); the OS notification wiring is in _notification (AC-24b ADVISORY).
func _handle_focus_change(paused: bool) -> void:
	_set_suspend_source(_SUSPEND_FOCUS, paused)

## OS / window lifecycle wiring (ADVISORY — headless does not fire these; the bitmask logic they
## drive is unit-tested via _set_suspend_source / _handle_focus_change directly).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_set_suspend_source(_SUSPEND_OS, true)
		NOTIFICATION_APPLICATION_RESUMED:
			_set_suspend_source(_SUSPEND_OS, false)
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_handle_focus_change(true)
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_handle_focus_change(false)

## Active BGM player playback position (0 if nothing playing). Used for resume-from-position.
func _bgm_position() -> float:
	if _bgm_active_idx >= 0 and _bgm_active_idx < _bgm_players.size():
		return _bgm_players[_bgm_active_idx].get_playback_position()
	return 0.0


# ── BGM variant rotation + loop-length guard (Story 009 — GDD-owned) ───────────

## Pick the next variant index, never the previous one (non-immediate-repeat). A sequential cycle
## is deterministic and guarantees no adjacent repeat for count ≥ 2; count ≤ 1 has no choice (0).
func _pick_next_variant(count: int, last: int) -> int:
	if count <= 1:
		return 0
	return (last + 1) % count

## Rotate focus_low to its next variant and crossfade to it. Triggered by the non-looping variant's
## `finished` (a looped OGG never emits finished — GDD Pass-4 fix). NOTE near-gap-free (≤1 frame):
## `finished` is deferred, so a tiny gap exists — NOT true gap-free (IB-2). Per-variant audio streams
## are produced by /asset-spec (Q8); the rotation DECISION (which variant) is owned here.
func _rotate_focus_low() -> void:
	_bgm_last_variant = _pick_next_variant(FOCUS_LOW_VARIANT_COUNT, _bgm_last_variant)
	if _bgm_active_idx != -1:
		var in_idx: int = 1 - _bgm_active_idx
		_start_crossfade(in_idx, _bgm_active_idx, BGM_DEFAULT_FADE_SEC)
		_bgm_active_idx = in_idx

## A non-looping BGM player finished naturally → rotate if it was the focus_low pool.
func _on_bgm_finished(player_idx: int) -> void:
	if player_idx == _bgm_active_idx and _current_bgm_track == &"focus_low_pool":
		_rotate_focus_low()

## Boot backstop: warn (no-throw) for any BGM track whose loop is shorter than BGM_MIN_LOOP_SEC —
## short loops fatigue over a 30-90 min session (AC-27). The track still plays (Foundation no-throw).
## A build-time CI lint (check_bgm_loop_length.gd) is the hard enforcement; this is the runtime guard.
func _validate_bgm_loop_lengths() -> void:
	if _bgm_catalog == null:
		return
	for track_id: Variant in _bgm_catalog:
		var entry: Variant = _bgm_catalog[track_id]
		if entry is Dictionary and entry.has("loop_sec"):
			var loop_sec: float = float(entry["loop_sec"])
			if loop_sec < BGM_MIN_LOOP_SEC:
				_bgm_loop_warning_count += 1
				push_warning("[AudioManager] BGM '%s' loop %.0fs < BGM_MIN_LOOP_SEC %.0fs — fatigue risk" % [
					track_id, loop_sec, BGM_MIN_LOOP_SEC,
				])
