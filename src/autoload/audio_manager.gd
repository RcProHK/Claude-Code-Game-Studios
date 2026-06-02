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
## Single retained duck Tween (Story 004). Kill-before-respawn (no stacked Tweens); idle-gated
## (refcount 0 + at base → killed, never spawned) so idle frames never touch AudioServer.
var _duck_tween: Tween = null


# ── Crossfade observability (Story 005 drives the tween; these are the seams) ──
var _active_crossfade_count: int = 0
var _crossfade_progress: float = -1.0   ## sentinel < 0 ⇒ no crossfade in-flight


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
	_load_persisted_volumes()
	# BgmCatalog load wires here in Story 005/009.

	_lifecycle_state = LifecycleState.READY


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
