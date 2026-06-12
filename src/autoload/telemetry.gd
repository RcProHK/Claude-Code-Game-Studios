extends Node
## Telemetry (#28) — Pre-MVP PIVOT/KILL gate instrument.
##
## Pure passive observer. It subscribes to upstream gameplay signals (#9 workout /
## #14 combat / #15 loot), translates each meaningful event into a structured,
## versioned, de-identified telemetry event, buffers it locally, and batch-flushes
## to the player's own GymSys backend. It emits ZERO gameplay signals, mutates ZERO
## game state, and is NEVER visible to the player (Pillar 2 / G-TEL-2 CI lint).
##
## Boot position: LAST in the autoload list (ADR-0008 G-TEL-1, reserved "Last"). It
## is order-resilient — `connect_for_initial_state` back-fills #1 GSM current_state
## for late join — so booting after every producer still captures each runtime-emitted
## signal with zero silent drop. The combat signals (#14) fire during CombatActive /
## boss-kill, far after all autoload `_ready()`, so late-boot is provably safe (this
## supersedes the stale #14 "must boot BEFORE #14" claim — Q-T1 erratum, ADR-0008).
##
## SCAFFOLD NOTE: Story 002 establishes the 5-state FSM + GSM `connect_for_initial_state`
## bootstrap. The event envelope + de-id (003), priority ring buffer (004), glance /
## euphoria proxies (005–007), upstream subscription handlers (008–010), CI lints
## (013–015), and DEGRADED/opt-out/clock-skew (016) are landed. Flush + beacon (011–012)
## and config registry (017) remain.
##
## Governing: design/gdd/telemetry.md; ADR-0008 (boot Last); ADR-0006 (Contract 6
## connect_for_initial_state); ADR-0009 (signal payload schema); ADR-0012 (transport
## + privacy); ADR-0003 (user:// spool, localStorage FORBIDDEN); ADR-0004 (same-origin).

# --- 5-state FSM (telemetry.md §States and Transitions) -----------------------
# ADR-0006: this FSM is ORTHOGONAL to the #1 GSM GameState — the BOOTING / SUSPENDED
# names happen to overlap with GameState members but are an entirely separate state
# space (this enum is local to Telemetry). BOOTING=0 is the safe ordinal-0 default
# (ADR-0007 Outcome/State family).
enum State { BOOTING, ACTIVE, FLUSHING, SUSPENDED, DEGRADED }

## Legal directed transitions (telemetry.md transition table). Any pair not listed is
## rejected by _transition_to. Same-state re-entry is a no-op (not "illegal").
##   BOOTING  → ACTIVE                              (single boot path)
##   ACTIVE   → FLUSHING / SUSPENDED / DEGRADED
##   FLUSHING → ACTIVE                              (ACK *and* failure both return here)
##   SUSPENDED→ ACTIVE                              (resume / visibilitychange→visible)
##   DEGRADED → ACTIVE                              (private-mode lifted, rare)
const _LEGAL_TRANSITIONS: Dictionary = {
	State.BOOTING: [State.ACTIVE],
	State.ACTIVE: [State.FLUSHING, State.SUSPENDED, State.DEGRADED],
	State.FLUSHING: [State.ACTIVE],
	State.SUSPENDED: [State.ACTIVE],
	State.DEGRADED: [State.ACTIVE],
}

## Sentinel for "GSM state not yet back-filled". The envelope stamps this as the
## StringName &"UNKNOWN" (EC-10; Story 003 envelope / Story 016 detail).
const SENTINEL_GAME_STATE: int = -1

## GSM GameState ordinal → envelope StringName. Mirrors game_state_machine.gd `enum
## GameState` order (BOOTING=0 … SUSPENDED=8). A unit test (test_event_envelope_deid)
## guards this against GSM enum drift so a renumber there fails loudly here rather than
## silently mis-stamping. We mirror rather than call `GameStateMachine.GameState.find_key`
## so the envelope path stays decoupled from the live autoload (tests inject mock GSMs).
const _GAME_STATE_NAMES: Array[StringName] = [
	&"BOOTING", &"DISCONNECTED", &"IDLE", &"WORKOUT_ACTIVE", &"REST_PERIOD",
	&"COMBAT_ACTIVE", &"BOSS_ENCOUNTER", &"LOOT_DROP", &"SUSPENDED",
]

# --- Untyped DI seams (reference_gdscript_di_seam — typed Node breaks member check) ---
var _gsm = null   ## #1 GameStateMachine (HARD — cfis subscribe state_changed, Rule 13)
## Optional clock seam: an object exposing now_unix_s()->int and now_monotonic_ms()->int.
## Tests inject a controllable clock (envelope timestamp + EC-07 ordering); production
## falls back to Time.* . Monotonic ms is the ordering key; unix is the wall stamp.
var _clock = null
## PlatformDetect seam — Page Visibility source for Formula 2 (Story 007). Non-web or
## unresolved → no visibility events → the foreground tracker stays visible (ratio 1.0).
var _platform = null
## #3 PersistenceLayer seam (SOFT — Story 016). Source of Private Mode detection (EC-08)
## and the durability target for the emergency user:// spool (ADR-0003). The live layer
## may not yet expose `is_private_mode()` / `private_mode_detected` — every access is
## has_method / has_signal guarded, so an absent API degrades to "non-private" (telemetry
## stays ACTIVE) rather than crashing the observer (Rule 1; #3 is a SOFT dependency).
var _persistence = null

# --- Runtime FSM state --------------------------------------------------------
var _state: int = State.BOOTING
## Latest GSM GameState, back-filled via cfis. SENTINEL_GAME_STATE until first delivery.
var _current_game_state: int = SENTINEL_GAME_STATE
var _ready_complete: bool = false

# --- Opt-out + Private Mode (Story 016; EC-17 / EC-08) ------------------------
## Master opt-out switch (Rule per telemetry.md Tuning-Knob `telemetry_enabled`, EC-17).
## Default true (first-party premium single-player). Story 017 backs this with config; the
## UI toggle lives in another system (settings / #24) — telemetry owns only the BEHAVIOR.
## false ⇒ zero flush, nothing leaves the device, capture drops to in-memory CRITICAL only.
var _telemetry_enabled: bool = true
## Latched once PersistenceLayer reports Private Mode mid-session (EC-08). Sticky because
## the contract has no "private lifted" signal; cleared only via notify_private_mode_cleared.
var _private_mode_latched: bool = false
## Emergency spool writer seam (Story 016 — injected by tests; production = FileAccess to
## user://, ADR-0003, NEVER localStorage). Callable(events: Array) -> bool (true = durable).
var _spool_writer: Callable = Callable()
## On-disk emergency spool path (ADR-0003 user://; Web Export = IndexedDB-backed).
const SPOOL_FILE_PATH: String = "user://telemetry_spool.jsonl"

# --- Event envelope state (Rule 3 / Rule 11) ----------------------------------
## session_id from #2 GymSys session claim (Rule 11 — telemetry NEVER generates its own;
## set via set_session_id by the Story 008 session-lifecycle wiring). Empty until claimed.
var _session_id: String = ""
## Per-session monotonic sequence — the (session_id, client_event_id) dedup + ordering key
## (Rule 6 / ADR-0012 backend UNIQUE). Strictly increasing, never reused within a session.
var _client_event_seq: int = 0

# --- Ring buffer (Rule 5/7; Story 004) ----------------------------------------
## Default capacities. Story 017 makes these config-backed (TelemetryConfig.tres) — for
## now they are the GDD Tuning-Knob defaults (TELEMETRY_BUFFER_MAX / _CRITICAL_RESERVED).
const DEFAULT_BUFFER_MAX: int = 2000
const DEFAULT_CRITICAL_RESERVED: int = 256
var _buffer = null  ## TelemetryBuffer — built in _ready()

# --- Foreground tracker (Rule 9 / Formula 2 glance proxy; Story 007) -----------
var _foreground_tracker = null  ## ForegroundTracker — built in _ready()

# --- #9 Workout subscription + session lifecycle (Rule 11; Story 008) ----------
var _workout = null  ## #9 WorkoutStateTracker seam (HARD — 7 workout signals)
var _switch_latency = null  ## SwitchLatencyTracker (Formula 1 anchor) — built in _ready()
## session_resume_ttl_seconds default (1800s). Story 017 makes it config-backed.
const SESSION_RESUME_TTL_MS: int = 1800 * 1000
var _session_active: bool = false
var _last_activity_ms: int = -1
## Flush trigger hook (Story 011 wires the real async flush; tests inject a spy).
## Callable(reason: StringName) -> void.
var _flush_hook: Callable = Callable()
## WorkoutPhase ordinals (workout_state_tracker.gd enum WorkoutPhase).
const _PHASE_SET_ACTIVE: int = 2
const _PHASE_REST_PERIOD: int = 3
const _PHASE_WORKOUT_COMPLETE: int = 4

# --- #14 Combat subscription + anomaly + recursion guard (Story 009) -----------
var _enemy_director = null  ## #14 EnemyDirector seam (3 combat signals)
var _combat_aggregate = null  ## CombatAggregate (Formula 4 lossless) — built in _ready()
var _hits_seen: int = 0  ## hit_index counter for Formula 3 sampling
## HIT_SAMPLE_STRIDE default (Story 017 config-backed).
const DEFAULT_HIT_SAMPLE_STRIDE: int = 10
## CombatResolver.DamageTier.CRITICAL ordinal (force-keep override, AC-06).
const _DAMAGE_TIER_CRITICAL: int = 4
## Rule 15 re-entrancy guard — true while inside the anomaly handler, so a telemetry
## self-error can NEVER recurse back into combat_metric_anomaly handling (#13 EC-49).
var _in_anomaly_handler: bool = false

# --- #15 Loot subscription + euphoria proxy + dedup (Story 010) ----------------
var _loot = null  ## #15 LootDropSystem seam
## dup_window_ms code fallback (GDD canonical default; config overrides at boot, Story 017).
## EC-03 duplicate-transition window. Story 010 shipped a 5000 const; Story 017 reconciles
## the runtime default to the GDD's 1000 (config-driven via `_dup_window_ms`).
const DUP_WINDOW_MS: int = 1000
## "name|transition_id" → last-seen monotonic ms. Pruned to bound memory.
var _recent_transitions: Dictionary = {}
const _RECENT_TRANSITIONS_CAP: int = 512
## Rule 10 — session max rarity (ordinal). The PREVIOUS session's max is stamped onto the
## next session_started; ordering / correlation is computed backend-side.
var _session_max_rarity_ordinal: int = -1
var _last_session_max_rarity_ordinal: int = -1
## RarityTier name → ordinal (loot_enums.gd RarityTier; telemetry-side mirror, uppercase).
const _RARITY_ORDINAL: Dictionary = {
	"COMMON": 0, "UNCOMMON": 1, "RARE": 2, "EPIC": 3, "LEGENDARY": 4,
}

# --- Config (Story 017 — data-driven tuning knobs) ----------------------------
## Shipped TelemetryConfig (.tres). Loaded in _ready unless a test injects one first.
const CONFIG_PATH: String = "res://assets/data/telemetry_config.tres"
var _config = null  ## TelemetryConfig seam (injectable; null until _resolve_config)
## Runtime knob values, populated from _config at boot. They start at the code fallbacks
## (the DEFAULT_* / *_MS consts) so a not-yet-_ready bare test instance still has sane
## values; _apply_config() overwrites them from the loaded/injected config.
var _hit_sample_stride: int = DEFAULT_HIT_SAMPLE_STRIDE
var _session_resume_ttl_ms: int = SESSION_RESUME_TTL_MS
var _dup_window_ms: int = DUP_WINDOW_MS
var _switch_latency_buckets_ms: Array = [5000, 15000, 60000, 180000]
var _buffer_max: int = DEFAULT_BUFFER_MAX
var _critical_reserved: int = DEFAULT_CRITICAL_RESERVED
var _flush_batch_size: int = 100
var _flush_interval_seconds: float = 30.0
var _flush_base_delay: float = 2.0
var _flush_retry_cap: float = 60.0

# --- Flush transport (Story 011) + beacon (Story 012) — ADR-0012 --------------
## Same-origin relative endpoints (ADR-0004; absolute URLs are a CI-forbidden pattern).
const TELEMETRY_ENDPOINT: String = "/api/game/telemetry"          ## header-authed main flush
const BEACON_ENDPOINT: String = "/api/game/telemetry/beacon"      ## token-in-body page-hide
const SCHEMA_ENVELOPE_VERSION: int = 1                            ## batch wrapper version (ADR-0012 §1)
## #2-issued session auth token (ADR-0002). Telemetry is a READER only — it never mints one.
## Empty ⇒ pre-session ⇒ events stay buffered, flush is skipped (ADR-0012 §3, never blocks gameplay).
var _session_token: String = ""
## Flush transport seam (Story 011). Production = the real orphan-HTTPRequest dispatch
## (ADR-0002 idiom, the dedicated 5th channel); tests inject a mock exposing
## `dispatch(url, headers, body, on_response) -> bool`. on_response(status:int, retry_after_s:int).
var _flush_transport = null
## Monotonic per-session batch sequence (ADR-0012 §1 client_batch_id — client-side retry tracking).
var _client_batch_seq: int = 0
## client_event_ids dispatched in the current in-flight batch (remove-on-ACK target, EC-12).
var _in_flight_ids: Array = []
## Consecutive flush failures → Formula 5 backoff exponent. Reset to 0 on a 200 ACK.
var _flush_failure_count: int = 0
## Monotonic ms before which a new flush is suppressed (backoff window). 0 = no backoff.
var _backoff_until_ms: int = 0
## Periodic flush Timer (Rule 6b). Created in _ready (production); tests call _flush_now directly.
var _flush_timer: Timer = null


func _ready() -> void:
	# Contract 4: an autoload MUST NOT emit signals during _ready(). This observer
	# never emits gameplay signals at all (G-TEL-2), so that invariant holds by
	# construction. cfis `connect` here is a subscription, not an emit.
	_resolve_seams()
	# Story 017: load + validate the data-driven tuning knobs BEFORE building the buffer
	# (the buffer is sized by config). An invalid config is logged and the safe code
	# fallbacks are kept — telemetry never crashes gameplay (Rule 1).
	_resolve_config()
	_buffer = TelemetryBuffer.new(_buffer_max, _critical_reserved)
	# Story 016: route the Rule 7 CRITICAL-overflow emergency spool to the gated user://
	# writer (ADR-0003). The gate (_can_spool) suppresses the write under Private Mode /
	# opt-out so DEGRADED never touches disk.
	_buffer.set_spool_hook(_spool_to_user)
	_foreground_tracker = ForegroundTracker.new()
	_foreground_tracker.start(_now_monotonic_ms())
	_switch_latency = SwitchLatencyTracker.new()
	_combat_aggregate = CombatAggregate.new()
	_subscribe_upstream()
	# Rule 6(b): periodic interval flush. Production only — a real Timer fires _flush_now;
	# unit tests drive _flush_now directly (the interval is far longer than a test run).
	_start_flush_timer()
	# BOOTING → ACTIVE: subscriptions are wired. The GSM initial-state back-fill
	# arrives deferred (next process_frame via cfis), but ACTIVE does NOT block on it
	# (Rule 13 — late back-fill stamps current_state; it does not gate capture readiness).
	_transition_to(State.ACTIVE)
	# EC-08 boot Private Mode gate (ADR-0003): if persistence is already in Private Mode,
	# step ACTIVE → DEGRADED (the single legal entry). Capture continues in-memory; only the
	# user:// spool is suppressed. Defensive — absent API ⇒ non-private ⇒ stays ACTIVE.
	if _is_private_mode():
		_transition_to(State.DEGRADED)
	_ready_complete = true


## Resolve any seam left null to its live autoload. Tests inject mocks before add_child,
## so a non-null seam is left untouched (DI override wins).
func _resolve_seams() -> void:
	if _gsm == null:
		_gsm = get_node_or_null("/root/GameStateMachine")
	if _platform == null:
		_platform = get_node_or_null("/root/PlatformDetect")
	if _persistence == null:
		_persistence = get_node_or_null("/root/PersistenceLayer")
	if _workout == null:
		_workout = get_node_or_null("/root/WorkoutStateTracker")
	if _enemy_director == null:
		_enemy_director = get_node_or_null("/root/EnemyDirector")
	if _loot == null:
		_loot = get_node_or_null("/root/LootDropSystem")


## Resolve the tuning-knob config (Story 017). A test-injected _config wins; otherwise load
## the shipped .tres; if that is missing, fall back to a fresh TelemetryConfig (code
## defaults). Then validate (INV-T1..4) and apply. An invalid config logs the violation and
## keeps the safe code fallbacks — telemetry never crashes gameplay (Rule 1).
func _resolve_config() -> void:
	if _config == null and ResourceLoader.exists(CONFIG_PATH):
		_config = load(CONFIG_PATH)
	if _config == null:
		_config = TelemetryConfig.new()
	var err: String = _config.validate()
	if err != "":
		push_error("[Telemetry] invalid TelemetryConfig — keeping safe fallbacks: %s" % err)
		return
	_apply_config()


## Inject a TelemetryConfig (tests / future runtime reconfig). Re-validates + re-applies
## immediately if telemetry is already booted; otherwise _ready picks it up.
func set_config(cfg) -> void:
	_config = cfg
	if _ready_complete and _config != null and _config.validate() == "":
		_apply_config()


## Copy validated config values into the runtime knob vars (+ the live opt-out switch).
func _apply_config() -> void:
	_buffer_max = _config.buffer_max
	_critical_reserved = _config.critical_reserved
	_hit_sample_stride = _config.hit_sample_stride
	_session_resume_ttl_ms = _config.session_resume_ttl_seconds * 1000
	_dup_window_ms = _config.dup_window_ms
	_switch_latency_buckets_ms = _config.switch_latency_buckets_ms
	_telemetry_enabled = _config.telemetry_enabled
	_flush_batch_size = _config.flush_batch_size
	_flush_interval_seconds = _config.flush_interval_seconds
	_flush_base_delay = _config.flush_base_delay_seconds
	_flush_retry_cap = _config.flush_retry_cap_seconds


## Subscribe to upstream lifecycle signals. Story 008/009/010 attach the #9 workout /
## #14 combat / #15 loot handlers here; Story 002 wires only the GSM state lifecycle.
func _subscribe_upstream() -> void:
	# GSM state lifecycle via Contract 6 cfis — boot-current back-fill, order-resilient
	# (so booting Last drops zero runtime-emitted signal). Guarded so a missing/partial
	# seam degrades to "no GSM context" rather than crashing the observer.
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_game_state_changed)
	# Page Visibility → Formula 2 foreground tracker (Story 007). Web-only event source;
	# non-web platforms never fire it → tracker stays foreground (ratio 1.0, AC-3).
	if _platform != null and _platform.has_signal("visibility_changed"):
		_platform.visibility_changed.connect(_on_visibility_changed)
	# Mid-session Private Mode detection (Story 016, EC-08; same posture as #15 loot
	# loot_drop_system.gd:180). SOFT — the live PersistenceLayer may not expose this
	# signal yet; has_signal-guarded so its absence simply means "no mid-session gate".
	if _persistence != null and _persistence.has_signal("private_mode_detected") \
			and not _persistence.is_connected("private_mode_detected", _on_private_mode_detected):
		_persistence.private_mode_detected.connect(_on_private_mode_detected)
	# #9 Workout lifecycle (Story 008). Plain connect — these are RUNTIME emits (workout
	# events fire long after boot), so late-boot Last captures them all; no cfis needed.
	if _workout != null:
		_connect_if(_workout, "workout_started_forwarded", _on_workout_started)
		_connect_if(_workout, "workout_completed_forwarded", _on_workout_completed)
		_connect_if(_workout, "set_progress_changed", _on_set_progress_changed)
		_connect_if(_workout, "dominant_class_changed", _on_dominant_class_changed)
		_connect_if(_workout, "phase_changed", _on_phase_changed)
		_connect_if(_workout, "workout_summary_available", _on_workout_summary)
		_connect_if(_workout, "bfcache_resumed", _on_bfcache_resumed)
	# #14 Combat signals (Story 009). Plain connect — runtime broadcast events (fire during
	# CombatActive / boss-kill, far after boot), so late-boot Last captures them all; the
	# game_state stamp rides the GSM cfis back-fill (AC-10, Story 002).
	if _enemy_director != null:
		_connect_if(_enemy_director, "hit_resolved", _on_hit_resolved)
		_connect_if(_enemy_director, "enemy_killed", _on_enemy_killed)
		_connect_if(_enemy_director, "combat_metric_anomaly", _on_combat_metric_anomaly)
	# #15 Loot signals (Story 010). Plain connect — runtime emits. _connect_if skips any
	# signal not in the #15 surface (loot_drop_unbound etc. are erratum-deferred).
	if _loot != null:
		_connect_if(_loot, "loot_dropped", _on_loot_dropped)
		_connect_if(_loot, "loot_ceremony_capped", _on_loot_ceremony_capped)
		_connect_if(_loot, "loot_pending_recovered", _on_loot_pending_recovered)
		_connect_if(_loot, "loot_drop_unbound", _on_loot_drop_unbound)


## Guarded signal connect — no-op if the signal is absent (defensive against a partial
## mock or a renamed upstream signal; telemetry degrades to "missing that stream").
func _connect_if(obj, signal_name: String, callable: Callable) -> void:
	if obj.has_signal(signal_name) and not obj.is_connected(signal_name, callable):
		obj.connect(signal_name, callable)


## GSM state sink. Pure observer — stamps the latest state for later envelope context
## (Rule 13). Never emits, never mutates gameplay (G-TEL-2). Param layout matches the
## GSM `state_changed(from_state, to_state, payload)` signal (cfis delivers positionally;
## `.bind()` is forbidden per GSM Contract 6).
func _on_game_state_changed(_from_state, to_state, _payload) -> void:
	_current_game_state = to_state


## Page Visibility sink (Story 007, Formula 2). Pure observer — banks foreground/total
## time, never emits or mutates gameplay (G-TEL-2).
func _on_visibility_changed(is_visible: bool) -> void:
	var now: int = _now_monotonic_ms()
	# Formula 2 foreground accounting (Story 007).
	if _foreground_tracker != null:
		if is_visible:
			_foreground_tracker.mark_visible(now)
		else:
			_foreground_tracker.mark_hidden(now)
	# Story 012 page-hide best-effort beacon (Rule 12) + SUSPENDED entry. The beacon fires
	# BEFORE the FSM step so the SUSPENDED-entry flush (telemetry.md Rule 12) carries the
	# latest buffer. Returning to visible resumes ACTIVE.
	if not is_visible:
		_beacon_flush()
		if _state == State.ACTIVE:
			_transition_to(State.SUSPENDED)
	else:
		if _state == State.SUSPENDED:
			_transition_to(State.ACTIVE)


## Current foreground ratio (Formula 2 glance proxy). Read-only — pure getter, no emit.
func get_foreground_ratio() -> float:
	if _foreground_tracker == null:
		return 1.0
	return _foreground_tracker.ratio(_now_monotonic_ms())


# --- #9 Workout handlers (Story 008) ------------------------------------------
# Every handler is a pure sink: translate → buffer. None emits a gameplay signal or
# mutates #9 state (G-TEL-2). Each is O(1) (Rule 2).

func _on_workout_started() -> void:
	_ensure_session(false)
	_record(&"workout_started", {}, TelemetryEvent.Priority.STANDARD)


## transition_id is a STRING — the real WST `workout_completed_forwarded(completed_at:
## int, transition_id: String)` emits a string id. (Story 008 mistyped it as int; the
## MockWST mirrored the same wrong type so the isolated test passed while the real autoload
## threw "Cannot convert argument 2 from String to int" on every real workout completion —
## the full-project gate exposed it. Story 017 erratum.)
func _on_workout_completed(completed_at_unix: int, transition_id: String) -> void:
	_record(&"workout_completed", {
		"completed_at_unix": completed_at_unix,
		"transition_id": transition_id,
	}, TelemetryEvent.Priority.STANDARD)
	# Rule 6(c): the workout boundary is the single most important flush point.
	_request_flush(&"workout_completed")


func _on_set_progress_changed(progress: float) -> void:
	# progress is an already-normalized [0,1] ratio (no raw kg) — de-id by construction.
	_record(&"set_progress", {"progress": progress}, TelemetryEvent.Priority.STANDARD)


func _on_dominant_class_changed(dominant_class: int) -> void:
	_record(&"dominant_class_changed", {"dominant_class": dominant_class},
		TelemetryEvent.Priority.STANDARD)


func _on_phase_changed(from_phase: int, to_phase: int) -> void:
	var now: int = _now_monotonic_ms()
	# Feed the Formula 1 switch-latency anchor (Story 006).
	if to_phase == _PHASE_REST_PERIOD:
		_switch_latency.on_rest_period(now)
	elif to_phase == _PHASE_SET_ACTIVE:
		var bucket: int = _switch_latency.on_set_active(now, _switch_latency_buckets_ms)
		if bucket != SwitchLatencyTracker.NO_EVENT:
			_record(&"switch_latency", {"bucket": bucket}, TelemetryEvent.Priority.STANDARD)
	elif to_phase == _PHASE_WORKOUT_COMPLETE:
		_switch_latency.clear_anchor()  # edge a — no latency on the final set
	_record(&"phase_changed", {"from": from_phase, "to": to_phase},
		TelemetryEvent.Priority.STANDARD)


func _on_workout_summary(_summary) -> void:
	# WorkoutSummaryRO carries already-normalized fields; telemetry records only a
	# de-identified marker (a real extraction would use volume = exercise COUNT, never
	# kg). Kept minimal — the summary schema detail is not load-bearing here.
	_record(&"workout_summary", {}, TelemetryEvent.Priority.STANDARD)


func _on_bfcache_resumed(was_mid_workout: bool, restored_phase: int) -> void:
	# EC-09 session continuity: capture the gap BEFORE _ensure_session mutates activity.
	var now: int = _now_monotonic_ms()
	var continued: bool = true
	if _last_activity_ms >= 0 and (now - _last_activity_ms) > _session_resume_ttl_ms:
		continued = false
		_ensure_session(true)  # beyond TTL → new session boundary
	_record(&"bfcache_resumed", {
		"was_mid_workout": was_mid_workout,
		"restored_phase": restored_phase,
		"session_continued": continued,
	}, TelemetryEvent.Priority.STANDARD)


# --- Session lifecycle (Rule 11) + shared sink + flush hook -------------------

## Mark a session active; emit session_started on the first activation OR a forced new
## session (EC-09 bfcache beyond TTL). telemetry never GENERATES session_id (Rule 11) —
## it only marks the session boundary for analytics; session_id is set by set_session_id.
func _ensure_session(force_new: bool) -> void:
	if force_new or not _session_active:
		# Rule 10: roll the previous session's max rarity forward as session context.
		_last_session_max_rarity_ordinal = _session_max_rarity_ordinal
		_session_max_rarity_ordinal = -1
		_session_active = true
		_record(&"session_started", {
			"resumed_from_bfcache": force_new,
			"last_session_max_rarity": _last_session_max_rarity_ordinal,
		}, TelemetryEvent.Priority.STANDARD)


## Shared event sink: stamp envelope, buffer it, refresh activity timestamp. O(1).
## EC-17 opt-out: when telemetry is disabled, capture drops to in-memory CRITICAL only
## (local crash diagnostics that never leave the device — a non-CRITICAL event is simply
## not retained). The toggle is read live, so flipping it mid-session takes effect at once.
func _record(event_name: StringName, payload: Dictionary, priority: int,
		schema_version: int = 1) -> void:
	if _buffer == null:
		return
	if not _telemetry_enabled and priority != TelemetryEvent.Priority.CRITICAL:
		return
	var ev := _make_event(event_name, payload, priority, schema_version)
	_buffer.push(ev)
	_last_activity_ms = _now_monotonic_ms()
	# Rule 6(a) batch-size trigger — the in-flight gate in _flush_now keeps this cheap (a
	# single dispatch stays in-flight until ACK; further records' attempts no-op).
	if _buffer.size() >= _flush_batch_size:
		_flush_now(&"batch_size")


## Request a flush (Rule 6 triggers a/b/c). Fires the legacy hook (Story 008 tests assert
## it) AND drives the real async batch POST (Story 011). The opt-out / pre-session / in-flight
## gates live in _flush_now.
func _request_flush(reason: StringName) -> void:
	if not _telemetry_enabled:
		return
	if _flush_hook.is_valid():
		_flush_hook.call(reason)
	_flush_now(reason)


## Buffered event count (tests / diagnostics). Pure getter.
func get_buffered_count() -> int:
	if _buffer == null:
		return 0
	return _buffer.size()


# --- Flush transport (Story 011) — ADR-0012 dedicated 5th HTTP channel --------

## Adopt the #2-issued session auth token (ADR-0002). Telemetry is a READER only — it never
## mints one (Rule 11). Empty ⇒ pre-session ⇒ events stay buffered (no flush, no fabrication).
func set_session_token(token: String) -> void:
	_session_token = token


## Inject the flush transport (tests). Production leaves it null → the default orphan
## HTTPRequest dispatch is used. The mock exposes dispatch(url, headers, body, on_response).
func set_flush_transport(transport) -> void:
	_flush_transport = transport


## Rule 6(b) periodic flush Timer. One-shot=false; the interval comes from config. Added as
## a child so it ticks with the tree. A telemetry flush is best-effort — the Timer just
## nudges _flush_now (which self-gates on token / in-flight / backoff).
func _start_flush_timer() -> void:
	_flush_timer = Timer.new()
	_flush_timer.wait_time = maxf(1.0, _flush_interval_seconds)
	_flush_timer.one_shot = false
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_on_flush_timer_timeout)
	add_child(_flush_timer)


func _on_flush_timer_timeout() -> void:
	_flush_now(&"interval")


## Attempt one async batch flush (Rule 6). Gated, single in-flight, never blocks gameplay.
## Returns true iff a dispatch was started. Skips (events stay buffered) when: opt-out,
## already FLUSHING, no session_token (pre-session), inside the backoff window, or empty.
func _flush_now(reason: StringName) -> bool:
	if not _telemetry_enabled or _buffer == null:
		return false
	if _state == State.FLUSHING:
		return false                                   # single in-flight (ADR-0012 §2)
	if _session_token == "":
		return false                                   # pre-session buffering (ADR-0012 §3)
	if _now_monotonic_ms() < _backoff_until_ms:
		return false                                   # honouring Formula 5 backoff window
	var batch: Array = _buffer.get_batch(_flush_batch_size)
	if batch.is_empty():
		return false
	_in_flight_ids = []
	for ev in batch:
		_in_flight_ids.append(ev.client_event_id)
	var body: String = _serialize_batch(batch, false)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Session-Token: " + _session_token,
	])
	if not _transition_to(State.FLUSHING):
		return false
	var dispatched: bool = _dispatch_flush(TELEMETRY_ENDPOINT, headers, body, _on_flush_response)
	if not dispatched:
		# Could not even start (e.g. HTTPRequest busy) — keep the buffer, count a failure,
		# return to ACTIVE. Gameplay is never affected (Rule 1).
		_register_flush_failure(0)
		_in_flight_ids = []
		notify_flush_finished(false)
		return false
	return true


## Flush response sink (ADR-0012 §3). FLUSHING → ACTIVE always; the buffer is only cleared
## on a 200 ACK (remove-on-ACK, EC-12 by-id no-op for already-evicted events).
func _on_flush_response(status_code: int, retry_after_s: int) -> void:
	match status_code:
		200:
			_buffer.remove_by_event_ids(_in_flight_ids)
			_flush_failure_count = 0
			_backoff_until_ms = 0
		401:
			# THE key divergence from #2: a telemetry auth failure is transient — keep the
			# buffer, wait for #2 to refresh the token, and NEVER force-boot the gameplay
			# session (ADR-0012 §3; Rule 1). No backoff escalation on 401.
			pass
		429:
			_register_flush_failure(retry_after_s)     # honour Retry-After if provided
		_:
			_register_flush_failure(0)                 # 5xx / 0 (timeout/network) → backoff
	_in_flight_ids = []
	notify_flush_finished(status_code == 200)          # FLUSHING → ACTIVE (always)


## Record a flush failure and arm the backoff window (Formula 5, or a 429 Retry-After).
func _register_flush_failure(retry_after_s: int) -> void:
	_flush_failure_count += 1
	var delay_s: float
	if retry_after_s > 0:
		delay_s = float(retry_after_s)
	else:
		delay_s = TelemetryFormulas.flush_backoff_delay(_flush_failure_count, _flush_base_delay, _flush_retry_cap)
	_backoff_until_ms = _now_monotonic_ms() + int(delay_s * 1000.0)


## Serialize a batch to the ADR-0012 §1 envelope. `include_token` adds the top-level
## `session_token` field for the beacon path (token-in-body, since sendBeacon has no headers).
func _serialize_batch(events: Array, include_token: bool) -> String:
	_client_batch_seq += 1
	var event_dicts: Array = []
	for ev in events:
		event_dicts.append(ev.to_dict())
	var envelope: Dictionary = {
		"session_id": _session_id,
		"client_batch_id": _client_batch_seq,
		"schema_envelope_version": SCHEMA_ENVELOPE_VERSION,
		"events": event_dicts,
	}
	if include_token:
		envelope["session_token"] = _session_token
	return JSON.stringify(envelope)


## Route a flush dispatch through the injected transport, else the default HTTPRequest path.
func _dispatch_flush(url: String, headers: PackedStringArray, body: String, on_response: Callable) -> bool:
	if _flush_transport != null:
		return bool(_flush_transport.dispatch(url, headers, body, on_response))
	return _default_dispatch(url, headers, body, on_response)


## Default transport: an orphan HTTPRequest (ADR-0002 idiom) — CONNECT_ONE_SHOT response,
## call_deferred queue_free, no `await` in the handler path. This is the dedicated 5th
## channel, isolated from #2's 4-channel pool (ADR-0012 §2). Returns false if request() fails.
func _default_dispatch(url: String, headers: PackedStringArray, body: String, on_response: Callable) -> bool:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, response_headers: PackedStringArray, _rbody: PackedByteArray) -> void:
			req.call_deferred("queue_free")
			var status: int = code if result == HTTPRequest.RESULT_SUCCESS else 0
			on_response.call(status, _parse_retry_after(response_headers)),
		CONNECT_ONE_SHOT)
	var err: int = req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		req.queue_free()
		return false
	return true


## Parse a `Retry-After: <seconds>` response header (429). Missing / non-integer → 0.
func _parse_retry_after(response_headers: PackedStringArray) -> int:
	for h in response_headers:
		var lower: String = h.to_lower()
		if lower.begins_with("retry-after:"):
			var val: String = h.substr(h.find(":") + 1).strip_edges()
			if val.is_valid_int():
				return val.to_int()
	return 0


# --- Page-hide beacon (Story 012) — ADR-0012 §4 ------------------------------

## Best-effort synchronous flush on page-hide (Rule 12). Serializes the buffer with the
## token IN BODY (sendBeacon cannot set headers) to the separate beacon endpoint, fire-and-
## forget. EC-18: send_beacon false (unavailable / non-Web) → synchronous XHR fallback.
## Best-effort: no remove-on-ACK (no response); backend UNIQUE dedup absorbs the overlap
## with the normal flush (EC-02). Returns true iff something was dispatched.
func _beacon_flush() -> bool:
	if not _telemetry_enabled or _buffer == null or _platform == null:
		return false
	var batch: Array = _buffer.get_all()
	if batch.is_empty():
		return false
	var body: String = _serialize_batch(batch, true)   # token-in-body
	if _platform.has_method("send_beacon") and bool(_platform.send_beacon(BEACON_ENDPOINT, body)):
		return true
	# EC-18 fallback — a synchronous best-effort XHR (also confined to platform_detect's
	# JS seam per ADR-0001). Further failure is accepted loss (EC-02 bounds it).
	if _platform.has_method("send_sync_xhr"):
		return bool(_platform.send_sync_xhr(BEACON_ENDPOINT, body))
	return false


# --- #14 Combat handlers (Story 009) ------------------------------------------

## hit_resolved → Formula 4 lossless accumulate (EVERY hit) + Formula 3 sampled individual
## event. Reads HitResolvedPayload {damage_dealt, is_crit, damage_tier}. EC-11: buffered
## even while SUSPENDED (faithful record). O(1) (hits are high frequency, Rule 2).
func _on_hit_resolved(payload) -> void:
	if payload == null:
		return
	var damage: int = int(payload.damage_dealt)
	var is_crit: bool = bool(payload.is_crit)
	var tier: int = int(payload.damage_tier)
	# Lossless accumulator updates regardless of sampling (AC-07).
	_combat_aggregate.accumulate(damage, is_crit, tier)
	# Individual event only when sampled; a crit / CRITICAL tier is force-kept (AC-06).
	var force_keep: bool = is_crit or tier == _DAMAGE_TIER_CRITICAL
	if TelemetryFormulas.hit_sample_keep(_hits_seen, _hit_sample_stride, force_keep):
		_record(&"hit_resolved", {"damage_tier": tier, "is_crit": is_crit},
			TelemetryEvent.Priority.LOW)
	_hits_seen += 1


## enemy_killed → STANDARD event. Reads EnemyKilledPayload {enemy_instance_id,
## transition_id} (enemy_instance_id, NOT target_id — #25 grep erratum).
func _on_enemy_killed(payload) -> void:
	if payload == null:
		return
	_record(&"enemy_killed", {
		"enemy_instance_id": int(payload.enemy_instance_id),
		"transition_id": String(payload.transition_id),
	}, TelemetryEvent.Priority.STANDARD)


## combat_metric_anomaly → CRITICAL channel (silent-fail backstop, FR-5). Rule 15: this
## handler is the recursion frontier — a telemetry self-error inside it goes to the
## diagnostic channel and NEVER re-emits combat_metric_anomaly (#13 EC-49). Re-entrancy
## guarded so a nested anomaly cannot loop.
func _on_combat_metric_anomaly(payload) -> void:
	if _in_anomaly_handler:
		# Re-entrancy backstop — a self-error must not recurse into anomaly handling.
		_record_self_error("re-entrant combat_metric_anomaly suppressed")
		return
	_in_anomaly_handler = true
	var reason: StringName = payload.reason if payload != null else &"unknown"
	var aggregate: bool = bool(payload.aggregate) if payload != null else false
	_record(&"combat_metric_anomaly", {"reason": reason, "aggregate": aggregate},
		TelemetryEvent.Priority.CRITICAL)
	_in_anomaly_handler = false


## Telemetry self-error → diagnostic channel (Rule 15). A push_warning + a LOW
## telemetry_self_error meta-event. CRUCIALLY this never re-emits combat_metric_anomaly,
## so a telemetry failure can never trigger the anomaly path it might be processing.
func _record_self_error(context: String) -> void:
	push_warning("[Telemetry] self-error: %s" % context)
	if _buffer != null:
		var ev := _make_event(&"telemetry_self_error", {"context": context},
			TelemetryEvent.Priority.LOW)
		_buffer.push(ev)


## Read-only combat aggregate snapshot (tests / Story 011 flush). Pure getter.
func get_combat_aggregate_dict() -> Dictionary:
	if _combat_aggregate == null:
		return {}
	return _combat_aggregate.to_dict()


# --- #15 Loot handlers (Story 010) --------------------------------------------

## loot_dropped → STANDARD, frozen loot_dropped_v1 (EXACTLY 4 fields, G-TEL-4). Feeds the
## drop-euphoria proxy (rarity distribution + session max rarity, Rule 10). Runs dedup (EC-03).
func _on_loot_dropped(drop_id: String, rarity_tier: String, item_type: String,
		transition_id: String) -> void:
	_record_dedup(&"loot_dropped", transition_id, {
		"drop_id": drop_id,
		"rarity_tier": rarity_tier,
		"item_type": item_type,
		"transition_id": transition_id,
	}, TelemetryEvent.Priority.STANDARD, 1)  # schema_version 1 = loot_dropped_v1
	# Rule 10: track this session's highest rarity (ordinal; -1 if name unrecognized).
	var ordinal: int = int(_RARITY_ORDINAL.get(rarity_tier.to_upper(), -1))
	if ordinal > _session_max_rarity_ordinal:
		_session_max_rarity_ordinal = ordinal


## loot_ceremony_capped → CRITICAL (loot integrity anomaly, never sampled/dropped).
func _on_loot_ceremony_capped(workout_id: String, capped_kill_count: int) -> void:
	_record(&"loot_ceremony_capped", {
		"workout_id": workout_id,
		"capped_kill_count": capped_kill_count,
	}, TelemetryEvent.Priority.CRITICAL)


## loot_pending_recovered → STANDARD (ADR-0003 durability verification audit).
func _on_loot_pending_recovered(drop_id: String, source_event_kind: String) -> void:
	_record(&"loot_pending_recovered", {
		"drop_id": drop_id,
		"source_event_kind": source_event_kind,
	}, TelemetryEvent.Priority.STANDARD)


## loot_drop_unbound → STANDARD audit (EC-14 — a known-legit non-error path: a drop in a
## non-workout context). Erratum: #15 does not yet emit this; _connect_if skips it until
## the signal ships. Handler is ready for that day.
func _on_loot_drop_unbound(transition_id: String, reason: String) -> void:
	_record(&"loot_drop_unbound", {
		"transition_id": transition_id,
		"reason": reason,
	}, TelemetryEvent.Priority.STANDARD)


# --- Dedup (EC-03) ------------------------------------------------------------

## Record an event; if the same (event_name, transition_id) was seen within DUP_WINDOW_MS,
## ALSO emit a duplicate_transition_observed (CRITICAL). Faithful observer: both originals
## are recorded — telemetry never silently suppresses (EC-03).
func _record_dedup(event_name: StringName, transition_id: String, payload: Dictionary,
		priority: int, schema_version: int = 1) -> void:
	var now: int = _now_monotonic_ms()
	var key: String = "%s|%s" % [event_name, transition_id]
	_record(event_name, payload, priority, schema_version)
	if _recent_transitions.has(key) and (now - int(_recent_transitions[key])) <= _dup_window_ms:
		_record(&"duplicate_transition_observed", {
			"event_name": event_name,
			"transition_id": transition_id,
		}, TelemetryEvent.Priority.CRITICAL)
	_recent_transitions[key] = now
	_prune_recent_transitions(now)


## Bound the dedup map: when it grows past the cap, drop entries older than the window.
func _prune_recent_transitions(now: int) -> void:
	if _recent_transitions.size() <= _RECENT_TRANSITIONS_CAP:
		return
	var stale: Array = []
	for k in _recent_transitions:
		if now - int(_recent_transitions[k]) > _dup_window_ms:
			stale.append(k)
	for k in stale:
		_recent_transitions.erase(k)


## Central FSM transition entry. Illegal transitions are rejected (warned, no change);
## same-state re-entry is a no-op. Returns true iff the state actually changed.
func _transition_to(next: int) -> bool:
	if next == _state:
		return false  # no-op re-entry (not an illegal transition)
	var allowed: Array = _LEGAL_TRANSITIONS.get(_state, [])
	if next not in allowed:
		push_warning("[Telemetry] illegal FSM transition %s → %s rejected"
			% [_state_name(_state), _state_name(next)])
		return false
	_state = next
	return true


## FLUSHING terminal convergence (Rule per telemetry.md L104): a flush — whether ACK or
## failure — ALWAYS returns to ACTIVE. A failed flush keeps the buffer and schedules
## backoff (real logic Story 011); it NEVER enters an error state, because telemetry must
## never let a dead backend affect gameplay. No-op if not currently FLUSHING.
func notify_flush_finished(_success: bool) -> bool:
	if _state != State.FLUSHING:
		return false
	return _transition_to(State.ACTIVE)


## Read-only FSM accessor (tests / diagnostics). NOT a gameplay signal — pure getter.
func get_state() -> int:
	return _state


## Read-only GSM-state accessor (tests / Story 003 envelope). SENTINEL_GAME_STATE until
## the first cfis back-fill.
func get_current_game_state() -> int:
	return _current_game_state


# --- Opt-out + Private Mode + emergency spool (Story 016) ---------------------

## EC-17 master opt-out. true = normal; false = no flush, nothing leaves the device,
## capture drops to in-memory CRITICAL only. Story 017 calls this from the config load;
## the player-facing toggle lives in another system (this owns only the behavior).
func set_telemetry_enabled(enabled: bool) -> void:
	_telemetry_enabled = enabled


func is_telemetry_enabled() -> bool:
	return _telemetry_enabled


## Inject the emergency-spool writer (tests). Production leaves it unset → the default
## user:// FileAccess writer is used. Callable(events: Array) -> bool.
func set_spool_writer(writer: Callable) -> void:
	_spool_writer = writer


## True iff telemetry is currently in Private Mode (EC-08). Sticky latch from the
## mid-session signal OR a live PersistenceLayer.is_private_mode(). Defensive: an absent
## API ⇒ false (non-private), so a SOFT/stub persistence never forces DEGRADED.
func _is_private_mode() -> bool:
	if _private_mode_latched:
		return true
	return _persistence != null and _persistence.has_method("is_private_mode") \
		and bool(_persistence.is_private_mode())


## Mid-session Private Mode handler (EC-08). Latch it and, if currently ACTIVE, step to
## DEGRADED (the single legal entry). FLUSHING/SUSPENDED return to ACTIVE later; the spool
## gate reads _is_private_mode() live, so disk stays untouched regardless of FSM phase.
func _on_private_mode_detected() -> void:
	_private_mode_latched = true
	if _state == State.ACTIVE:
		_transition_to(State.DEGRADED)


## Rare DEGRADED → ACTIVE recovery (Private Mode lifted; the contract has no signal for
## this, so it is a caller-driven recovery hook). No-op unless currently DEGRADED.
func notify_private_mode_cleared() -> bool:
	_private_mode_latched = false
	if _state == State.DEGRADED:
		return _transition_to(State.ACTIVE)
	return false


## True iff the emergency spool may durably write (EC-08 / EC-17 gate). Suppressed under
## opt-out, DEGRADED, or Private Mode — in those cases an overflowing CRITICAL is honestly
## counted as dropped (anti-fabrication) rather than silently spooled.
func _can_spool() -> bool:
	return _telemetry_enabled and _state != State.DEGRADED and not _is_private_mode()


## Buffer emergency-spool hook (Story 004 → real ADR-0003 write). Gated; returns true iff
## the events were durably persisted to user:// (NEVER localStorage — ADR-0003).
func _spool_to_user(events: Array) -> bool:
	if not _can_spool():
		return false
	if _spool_writer.is_valid():
		var injected = _spool_writer.call(events)
		return injected if injected is bool else false
	return _default_spool_write(events)


## Default emergency spool writer: append one JSON line per event to the user:// spool
## file (FileAccess, ADR-0003). Append-open falls back to a fresh WRITE if the file does
## not exist yet. Any failure returns false → the buffer counts the CRITICAL as dropped.
func _default_spool_write(events: Array) -> bool:
	var file := FileAccess.open(SPOOL_FILE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(SPOOL_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	for ev in events:
		if ev is TelemetryEvent:
			file.store_line(JSON.stringify(ev.to_dict()))
	file.close()
	return true


# --- Event envelope factory (Rule 3) ------------------------------------------

## Construct a telemetry envelope (Rule 3). Centralizes client_event_id++ / session_id /
## both timestamps / game_state stamping in ONE place. O(1), allocation = one envelope
## (Rule 2). The handler is responsible for passing an ALREADY-normalized, de-identified
## `payload` (Rule 4); this factory never reads raw body data — it only stamps metadata.
## `schema_version` is per-event-name (Rule 14; the frozen-schema lint Story 015 guards
## the field set for versioned events such as loot_dropped_v1).
func _make_event(event_name: StringName, payload: Dictionary, priority: int,
		schema_version: int = 1) -> TelemetryEvent:
	_client_event_seq += 1
	var ev := TelemetryEvent.new()
	ev.event_name = event_name
	ev.schema_version = schema_version
	ev.client_event_id = _client_event_seq
	ev.session_id = _session_id
	ev.client_ts_unix = _now_unix_s()
	ev.client_ts_monotonic_ms = _now_monotonic_ms()
	ev.game_state = _game_state_name()
	ev.payload = payload
	ev.priority = priority
	return ev


## Rule 11 — adopt the upstream (#2 GymSys) session_id. Telemetry never generates its own.
func set_session_id(session_id: String) -> void:
	_session_id = session_id


func _now_unix_s() -> int:
	if _clock != null and _clock.has_method("now_unix_s"):
		return _clock.now_unix_s()
	return int(Time.get_unix_time_from_system())


func _now_monotonic_ms() -> int:
	if _clock != null and _clock.has_method("now_monotonic_ms"):
		return _clock.now_monotonic_ms()
	return Time.get_ticks_msec()


## Map the back-filled GSM GameState ordinal → its envelope StringName. SENTINEL or an
## out-of-range value → &"UNKNOWN" (EC-10).
func _game_state_name() -> StringName:
	if _current_game_state >= 0 and _current_game_state < _GAME_STATE_NAMES.size():
		return _GAME_STATE_NAMES[_current_game_state]
	return &"UNKNOWN"


func _state_name(s: int) -> String:
	return State.keys()[s] if s >= 0 and s < State.size() else "INVALID(%d)" % s
