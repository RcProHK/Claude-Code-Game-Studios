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
const DUCK_OFFSET_DB: float = -8.0      ## high-priority duck depth (applied Story 004)
const STREAK_CHIME_DUCK_OFFSET_DB: float = -5.0  ## mid-priority shallow duck (Story 004)
const SFX_VOICE_COUNT: int = 8          ## fixed pool size (web budget; filled Story 003)


# ── Lifecycle (minimal — Story 008 owns full SUSPENDED multi-source bitmask) ───
enum LifecycleState { BOOTING = 0, READY = 1, SUSPENDED = 2 }
var _lifecycle_state: LifecycleState = LifecycleState.BOOTING


# ── Orthogonal unlock flag (GDD Rule 5 — a derived gate, NOT a GSM state) ──────
## true once audio is unlocked: desktop/native boot, or web first gesture (Story 007).
var _audio_unlocked: bool = false


# ── Duck refcount source-of-truth (GDD Formula 3; multiset semantics) ──────────
## handle → offset_db. refcount = size(). Story 004 lerps the Music bus toward the target.
var _active_ducks: Dictionary = {}
var _next_duck_handle: int = 1
## Music bus base dB (default; Story 002 reflects the live slider). _compute_duck_target floor.
var _base_music_db: float = DEFAULT_MUSIC_DB


# ── Crossfade observability (Story 005 drives the tween; these are the seams) ──
var _active_crossfade_count: int = 0
var _crossfade_progress: float = -1.0   ## sentinel < 0 ⇒ no crossfade in-flight


# ── SFX pool logical occupancy (slots themselves built in Story 003) ───────────
## Per-slot logical "busy" flag — AudioManager-owned, INDEPENDENT of engine `.playing`.
## The headless Dummy audio driver does not guarantee `.playing`; internal logic
## (steal victim selection, voice-count, pool occupancy) NEVER reads `.playing`.
var _voice_busy: Array[bool] = []
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
	# Resolve DI seams to autoload singletons. Tests inject mocks BEFORE add_child (the
	# `== null` guards leave an injected seam untouched), so this never clobbers a mock.
	if _gsm == null:
		_gsm = GameStateMachine
	if _platform_detect == null:
		_platform_detect = PlatformDetect
	if _persistence == null:
		_persistence = PersistenceLayer

	# Allocate logical voice-occupancy flags (the AudioStreamPlayer slots are built Story 003).
	_voice_busy.resize(SFX_VOICE_COUNT)
	_voice_busy.fill(false)

	# Unlock gate (GDD Rule 5): desktop/native unlocked at boot; web waits for a gesture (Story 007).
	_audio_unlocked = not _is_web()

	# GSM subscription (ADR-0006 Contract 6): connect_for_initial_state, NO .bind. The full
	# state→track music map is Story 006; this story wires only the sentinel-safe subscription.
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)

	_lifecycle_state = LifecycleState.READY
	# No sound on boot. Catalog load (Story 003) + persisted-volume load (Story 002) wire here.


# ── Public API (closed gateway — bodies filled by Stories 002-009) ─────────────

## Play a one-shot pooled SFX by catalog event_id. Unknown id → no-op + warn (Story 003/008).
func play_sfx(_event_id: StringName) -> void:
	pass  # Story 003: pool acquire + priority-aware voice steal.

## Crossfade BGM to track_id over fade_in_sec. Same track already playing → no-op (Story 005).
func play_bgm(_track_id: StringName, _fade_in_sec: float = 1.0) -> void:
	pass  # Story 005: equal-power crossfade.

## Crossfade out the current BGM over fade_out_sec.
func stop_bgm(_fade_out_sec: float = 1.0) -> void:
	pass  # Story 005.

## Set a bus volume in dB (clamped [MUTE_FLOOR_DB, MAX_BUS_DB]; persisted to audio.*). Story 002.
func set_bus_volume_db(_bus: Bus, _db: float) -> void:
	pass  # Story 002.

## Read the current dB of a bus.
func get_bus_volume_db(_bus: Bus) -> float:
	return 0.0  # Story 002.

## Mute / unmute a bus (persisted independently of volume).
func set_bus_muted(_bus: Bus, _muted: bool) -> void:
	pass  # Story 002.

## True once audio is unlocked (desktop boot, or web after the first user gesture).
func is_audio_unlocked() -> bool:
	return _audio_unlocked


# ── Test seams (pure functions — GUT calls these directly; NOT for production callers) ──

## Register an active duck; returns a monotonic voice handle. offset MUST be ≤ 0 (an
## attenuation). A positive offset (caller bug) is clamped to 0 (no-op duck) + warned —
## the Music bus is NEVER raised (would break the Pillar 3 reward-peak contrast).
func _register_duck(offset: float) -> int:
	assert(offset <= 0.0, "duck offset must be ≤ 0")
	if offset > 0.0:
		push_warning("[AudioManager] _register_duck got positive offset %f — clamped to 0 (no duck)" % offset)
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

## GSM state→music handler. The full state→track map is Story 006; the initial-state sentinel
## (ADR-0006 C6) must be a no-op here. Signature matches the typed `state_changed` contract.
func _on_gsm_state_changed(_from: Variant, _to: Variant, _payload: Variant = null) -> void:
	pass  # Story 006: data-driven state→track crossfade + bgm_changed emit.

## Web-platform detection via the injected seam, falling back to the engine feature flag when
## PlatformDetect (a stub) does not yet expose is_web(). Story 007 makes the seam canonical.
func _is_web() -> bool:
	if _platform_detect != null and _platform_detect.has_method("is_web"):
		return bool(_platform_detect.is_web())
	return OS.has_feature("web")
