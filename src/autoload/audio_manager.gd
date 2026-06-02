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

	# Bus topology (GDD Rule 2) + persisted volume/mute load (Story 002). No sound on boot.
	_ensure_buses()
	_load_persisted_volumes()
	# SfxCatalog / BgmCatalog load wires here in Story 003.

	_lifecycle_state = LifecycleState.READY


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
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, clamped)
	if bus == Bus.MUSIC:
		_base_music_db = clamped
	_persist_write("audio." + _bus_key(bus) + "_db", clamped)

## Read the current (live) dB of a bus from AudioServer.
func get_bus_volume_db(bus: Bus) -> float:
	var idx: int = _bus_index(bus)
	return AudioServer.get_bus_volume_db(idx) if idx != -1 else MUTE_FLOOR_DB

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
