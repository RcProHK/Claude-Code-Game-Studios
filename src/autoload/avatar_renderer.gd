extends Node
## AvatarRenderer (#26) — Pillar 5 PRIMARY render substrate (render-only, ADR-0010).
##
## Subscribes canonical #11 Stat / #12 Ability / #1 GSM signals, derives a
## presentation-only AvatarVisualState (class posture / evolution tier / animation /
## sprite frame), and exposes a READ-ONLY API + an AvatarEvolutionSnapshot + two
## milestone trigger signals for #29 Mirror Moment. #26 renders ZERO ceremony
## (CR-17 / AC-30). See design/gdd/avatar-renderer.md.
##
## Boot order (ADR-0008 / G-AR-1): after {#11 Stat, #12 Ability, #3 Persistence,
## #1 GSM, #5 ParticleSystemWrapper}. #29 MirrorMomentCoordinator tail-appends after.

# --- Signals (domain, not UI/analytics) ---
signal avatar_visual_updated(state: AvatarVisualState)
signal animation_state_changed(new_state: StringName)
## The #29 ceremony trigger (CR-5). Emitted once per tier promotion that clears the
## two-gate; deferred out of the workout window (CR-15). FC-2 frozen payload.
signal avatar_evolution_milestone(tier: int, source_metrics: Dictionary)
## Weekly shader-only delta marker (CR-5b). #29 sets week_had_change from this.
signal avatar_micro_evolution(delta_kind: StringName, source_metrics: Dictionary)
## Telemetry — a cast was dropped because the 1-deep queue was full (CR-10).
signal avatar_cast_dropped(ability_id: StringName)

# --- Persistence ---
const PERSIST_KEY := "avatar.evolution_tier_history"
const SCHEMA_VERSION := 1
## CR-12 append-only attainment log FIFO cap (one entry per weekly tier-up; 52 ≈ 1yr).
const TIER_ATTAINMENT_LOG_CAP := 52

# --- Config paths (CR-4 / EC-BOOT-2 hard-load) ---
const CONFIG_PATH := "res://assets/data/avatar_evolution_config.tres"
const POSTURE_CONFIG_PATH := "res://assets/data/posture_config.tres"
const EMERGENCY_FRAMES_PATH := "res://assets/art/avatar/emergency_avatar.tres"

# --- Tuning knobs (data-driven via config; mirrored here only as parity anchors) ---
const MILESTONE_CADENCE_SECONDS := 604800
const MICRO_EVOLUTION_CADENCE_SECONDS := 604800
const BFCACHE_CONTINUE_THRESHOLD_MS := 30000
const POSTURE_HYSTERESIS_SECONDS := 300
const FIRST_BOOT_GRACE_SECONDS := 172800
const MIN_OBSERVED_SESSIONS := 1
const CAST_HARD_WINDOW_MS := 300
const CAST_TOTAL_MS := 500
const CAST_QUEUE_DEPTH := 1
const MIRROR_MOMENT_PENDING_BUFFER := 3

# --- Untyped DI seams (reference_gdscript_di_seam — typed Node breaks member check) ---
var _stat = null
var _ability = null
var _gsm = null
var _persistence = null
## Optional monotonic-clock seam: an object with `now_ms() -> int`. Tests inject a
## controllable clock; production falls back to Time.get_ticks_msec() (CR-10 / CR-8 / EC-XSYS-2).
var _clock = null
## Optional AnimatedSprite2D the view registers (register_sprite). When present, suspend
## calls pause() (NOT stop() — CR-8 hallucination fix); resume restores via set_frame_and_progress.
var _sprite = null

# --- GSM-derived anim debounce (EC-XSYS-2) ---
const GSM_SIGNAL_DEBOUNCE_MS := 16
var _last_gsm_anim_apply_ms: int = -1000000
var _pending_gsm_anim_target = null  # StringName or null (coalesced storm target)
var _unknown_state_logged: bool = false  # EC-SIG-5 log-once

# --- Cast timing + 1-deep queue (CR-10 / story 007) ---
var _cast_active: bool = false
var _cast_started_ms: int = 0
var _cast_queue: Array = []  # depth CAST_QUEUE_DEPTH; holds pending ability_id StringNames

# --- bfcache suspend/resume (CR-8 / Formula 5 / story 010) ---
var _suspended: bool = false
var _suspended_snapshot: Dictionary = {}

# --- Derived state ---
var _config: AvatarEvolutionConfig = null
var _posture_config: PostureConfig = null
var _emergency_frames: SpriteFrames = null
var _visual_state: AvatarVisualState = AvatarVisualState.new()

# Persistence counters (CR-12).
var _historical_max_tier: int = 0
var _last_emitted_tier: int = 0
var _last_milestone_emit_unix: int = 0
var _last_micro_emit_unix: int = 0
var _pending_milestone: bool = false
var _persistence_degraded: bool = false

# CR-12 schema: append-only attainment log (FIFO cap) + config-drift anchor (EC-BOOT-3).
var _tier_attainment_log: Array = []
var _config_hash_at_last_emit: String = ""
# Set when EC-BOOT-3 detects a config version change: the first canonical derive rebases
# last_emitted_tier to the current tier so no cross-version milestone replay fires.
var _config_drift_recovery: bool = false
# EC-BOOT-1 (degraded persistence) / EC-BOOT-5 (corruption): suppress ALL emits this
# session so a later restore can't double-fire a tier-up the player never earned in-app.
var _suppress_emit_this_session: bool = false

# Posture hysteresis (CR-9, monotonic clock per-session).
var _last_class_switch_ms: int = 0
var _first_posture_applied: bool = false

# EC-TIER-5: log the unresolved-depth fail-safe once per session, not per derive.
var _class_depth_unresolved_logged: bool = false

# Micro-evolution (CR-5b / story 013): session-anchored stat baseline + reduced-motion gate.
var _micro_baseline_stat_total: float = 0.0
var _reduced_motion: bool = false

# CR-6 / CI-1: event-driven presentation state lives in backing vars; ONLY
# _derive_state_from_canonical() ever writes _visual_state (the single fabrication boundary).
# These are synced INTO _visual_state at the tail of each derive.
var _current_anim: StringName = &"IDLE"
var _micro_palette_shift: float = 0.0
var _micro_outline_intensity: float = 0.0

# Pending-emit buffer for when #29 isn't listening yet (EC-MILE-5).
var _pending_emit_queue: Array = []

# Boot gate — EC-SIG-1: drop canonical signals fired before _ready() completes.
var _ready_complete: bool = false


func _ready() -> void:
	if _stat == null:
		_stat = StatSystem
	if _ability == null:
		_ability = AbilitySystem
	if _gsm == null:
		_gsm = GameStateMachine
	if _persistence == null:
		_persistence = PersistenceLayer

	_validate_knobs()
	_load_config_or_crash()
	_posture_config = load(POSTURE_CONFIG_PATH) as PostureConfig
	_emergency_frames = load(EMERGENCY_FRAMES_PATH) as SpriteFrames

	_read_persistence()

	# Subscriptions (AC-01 exact set: stat_changed, ability_unlocked, ability_cast,
	# state_changed). ADR-0006 Contract 6: stat / ability_cast / gsm MUST route through
	# connect_for_initial_state — it is the only Contract-6-correct path (a plain .connect()
	# would miss the initial-state delivery, and the CI gateway lints forbid it). All three
	# canonical autoloads ship cfis, so it is called unconditionally (matches the #14/#33
	# subscription convention; fakes in tests provide cfis too).
	# ability_unlocked has NO cfis (AbilitySystem.cfis is bound to ability_cast — shipped
	# reality), so it uses a plain connect. This is Contract-6-safe because the bootstrap
	# derive below sync-reads get_unlocked_abilities(), capturing the initial unlock state
	# regardless of the signal (AC-16 erratum). The ability-signal lint allowlists this exact
	# file+signal pair (avatar_renderer.gd / ability_unlocked); ability_cast stays gated.
	_stat.connect_for_initial_state(_on_stat_changed)
	if not _ability.ability_unlocked.is_connected(_on_ability_unlocked):
		_ability.ability_unlocked.connect(_on_ability_unlocked)
	_ability.connect_for_initial_state(_on_ability_cast)
	_gsm.connect_for_initial_state(_on_gsm_state_changed)

	# One explicit bootstrap derive from a synchronous canonical snapshot (EC-SIG-1:
	# signal-triggered derives during boot were dropped; this is the single source).
	_derive_state_from_canonical(0)
	# Anchor the micro-evolution rolling baseline to the booted stat total so the first
	# post-boot delta starts at ~0 (no spurious micro on launch — CR-5b honesty).
	_micro_baseline_stat_total = _stat_total_now()
	_ready_complete = true
	avatar_visual_updated.emit(_visual_state)

	# Flush a persisted pending milestone left from a prior session (CR-15 / EC-MILE-3).
	if _pending_milestone:
		_try_flush_pending_milestone()


func _process(_delta: float) -> void:
	if not _ready_complete or _suspended:
		return
	var now := _now_ms()
	# EC-XSYS-2: flush a coalesced GSM-derived anim transition once the window elapses.
	_flush_pending_gsm_anim(now)
	# CR-10: advance the cast machine so a queued/finished cast releases on time.
	if _cast_active:
		_tick_cast(now)


## INV-2 (N-2 pin): cast timing is monotonic and the posture cooldown covers a full cast.
func _validate_knobs() -> void:
	assert(CAST_HARD_WINDOW_MS < CAST_TOTAL_MS,
		"INV-2: CAST_HARD_WINDOW_MS(%d) must be < CAST_TOTAL_MS(%d)" % [CAST_HARD_WINDOW_MS, CAST_TOTAL_MS])
	assert(POSTURE_HYSTERESIS_SECONDS * 1000 >= CAST_TOTAL_MS,
		"INV-2: POSTURE_HYSTERESIS_SECONDS*1000(%d) must be >= CAST_TOTAL_MS(%d)" % [POSTURE_HYSTERESIS_SECONDS * 1000, CAST_TOTAL_MS])


## The view registers its AnimatedSprite2D so #26 can pause()/play() it on suspend/resume.
## (Not a forbidden mutation prefix — CR-11/CI-3 allow register_*.)
func register_sprite(animated_sprite) -> void:
	_sprite = animated_sprite


# --- Config / persistence ----------------------------------------------------

func _load_config_or_crash() -> void:
	_config = load(CONFIG_PATH) as AvatarEvolutionConfig
	assert(_config != null, "[AvatarRenderer] EC-BOOT-2: AvatarEvolutionConfig missing at " + CONFIG_PATH)
	var err := _config.validate()
	assert(err == "", "[AvatarRenderer] config invalid (INV-G1): " + err)


func _read_persistence() -> void:
	var raw = _persistence.read(PERSIST_KEY)
	if raw == null or not (raw is Dictionary):
		# No persisted history. Genuine first boot OR Private Mode (user:// unavailable).
		# EC-BOOT-1: probe writability — a failed write means degraded persistence, so we
		# suppress emits this session (a later restore must not double-fire). A successful
		# write means a clean first boot (emits allowed once earned in-app).
		_historical_max_tier = 0
		_last_emitted_tier = 0
		_last_milestone_emit_unix = 0
		_last_micro_emit_unix = 0
		_pending_milestone = false
		_tier_attainment_log = []
		_config_hash_at_last_emit = _config_version_hash()
		_persistence_degraded = not _write_persistence()
		if _persistence_degraded:
			push_warning("[AvatarRenderer] EC-BOOT-1: persistence degraded (Private Mode); milestone+micro suppressed this session")
			_last_emitted_tier = _historical_max_tier
			_suppress_emit_this_session = true
		return
	var d: Dictionary = raw
	_historical_max_tier = int(d.get("current_tier", 0))
	_last_emitted_tier = int(d.get("last_emitted_tier", 0))
	_last_milestone_emit_unix = int(d.get("last_milestone_emit_unix", 0))
	_last_micro_emit_unix = int(d.get("last_micro_emit_unix", 0))
	_pending_milestone = bool(d.get("pending_milestone", false))
	_tier_attainment_log = (d.get("tier_attainment_log", []) as Array)
	_config_hash_at_last_emit = String(d.get("config_hash_at_last_emit", ""))
	# EC-BOOT-4: persisted future tier (T4+) -> clamp T3 + downgrade migration.
	if _historical_max_tier > 3:
		push_warning("[AvatarRenderer] EC-BOOT-4: tier_downgrade_migration T%d -> T3" % _historical_max_tier)
		_historical_max_tier = 3
		_last_emitted_tier = _historical_max_tier
	# EC-BOOT-5 (CRITICAL): last_emitted_tier > current_tier violates INV-4 = corruption.
	if _last_emitted_tier > _historical_max_tier:
		push_warning("[AvatarRenderer] EC-BOOT-5: persistence_corruption (last_emitted > current); repairing, no emit this session")
		_last_emitted_tier = _historical_max_tier  # INV-4 repair
		_suppress_emit_this_session = true
	# EC-BOOT-3: config version drift -> rebase last_emitted to current tier on first derive
	# (no cross-version milestone replay); clear pending.
	if _config_hash_at_last_emit != "" and _config_hash_at_last_emit != _config_version_hash():
		push_warning("[AvatarRenderer] EC-BOOT-3: config_drift_recovery (version changed); re-deriving last_emitted_tier, no cross-version replay")
		_pending_milestone = false
		_config_drift_recovery = true
		_config_hash_at_last_emit = _config_version_hash()


func _write_persistence() -> bool:
	return _persistence.write(PERSIST_KEY, {
		"current_tier": _historical_max_tier,
		"last_emitted_tier": _last_emitted_tier,
		"last_milestone_emit_unix": _last_milestone_emit_unix,
		"last_micro_emit_unix": _last_micro_emit_unix,
		"pending_milestone": _pending_milestone,
		"tier_attainment_log": _tier_attainment_log,
		"config_hash_at_last_emit": _config_hash_at_last_emit,
		"schema_version": SCHEMA_VERSION,
	})


func _config_version_hash() -> String:
	return _config.version_hash if _config != null else ""


## CR-12 append-only attainment log with FIFO cap (drop oldest at cap).
func _append_tier_attainment(tier: int, at_unix: int) -> void:
	_tier_attainment_log.append({"tier": tier, "at_unix": at_unix})
	while _tier_attainment_log.size() > TIER_ATTAINMENT_LOG_CAP:
		_tier_attainment_log.pop_front()


# --- Derivation (CR-6 — the only writer of _visual_state) ---------------------

func _derive_state_from_canonical(transition_id: int) -> void:
	var str_v: float = _stat.get_stat(_stat.StatId.STR)
	var dex_v: float = _stat.get_stat(_stat.StatId.DEX)
	var vit_v: float = _stat.get_stat(_stat.StatId.VIT)
	var unlocked: Dictionary = _ability.get_unlocked_abilities()

	var new_class := AvatarFormulas.dominant_class(str_v, dex_v, vit_v)
	var stat_total := AvatarFormulas.sanitize_stat(str_v) + AvatarFormulas.sanitize_stat(dex_v) + AvatarFormulas.sanitize_stat(vit_v)
	var peak_stat := maxf(maxf(AvatarFormulas.sanitize_stat(str_v), AvatarFormulas.sanitize_stat(dex_v)), AvatarFormulas.sanitize_stat(vit_v))
	var ability_count := unlocked.size()
	var max_class_depth := _resolve_max_class_depth(unlocked)

	var tier := AvatarFormulas.derive_tier(stat_total, peak_stat, ability_count, max_class_depth, _config, _historical_max_tier)
	# EC-BOOT-3: after a config version change, rebase last_emitted to the freshly-derived
	# tier ONCE so no cross-version milestone replay fires for tiers already held.
	if _config_drift_recovery:
		_last_emitted_tier = maxi(_last_emitted_tier, tier)
		_config_drift_recovery = false
		_write_persistence()
	# Monotonic historical lock (CR-12 / CF-2) + append-only attainment log.
	if tier > _historical_max_tier:
		_historical_max_tier = tier
		_append_tier_attainment(tier, _now_unix())

	# Posture-swap hysteresis (CR-9). First boot is exempt from cooldown.
	var applied_class := _visual_state.class_posture
	if not _first_posture_applied:
		applied_class = new_class
		_first_posture_applied = true
		_last_class_switch_ms = Time.get_ticks_msec()
	elif AvatarFormulas.hysteresis_can_swap(
			new_class, _visual_state.class_posture, Time.get_ticks_msec(),
			_last_class_switch_ms, POSTURE_HYSTERESIS_SECONDS, _in_workout_window()):
		applied_class = new_class
		_last_class_switch_ms = Time.get_ticks_msec()

	_visual_state.evolution_tier = tier
	_visual_state.class_posture = applied_class
	_visual_state.sprite_frames_resource_path = _resolve_sprite_path(applied_class, tier)
	_visual_state.last_emitted_tier = _last_emitted_tier
	_visual_state.last_milestone_emit_unix = _last_milestone_emit_unix
	_visual_state.transition_id = transition_id
	_visual_state.derived_from = {
		"evolution_tier": "stat_changed+ability_unlocked",
		"class_posture": "stat_changed",
		"animation_state": "state_changed",
		"sprite_frames_resource_path": "posture_config",
		"last_emitted_tier": "persistence",
		"last_milestone_emit_unix": "persistence",
	}

	_maybe_emit_milestone(stat_total, ability_count, max_class_depth)
	_maybe_emit_micro(stat_total - _micro_baseline_stat_total)

	# CI-1 single-writer boundary: sync event-driven backing state into the snapshot here,
	# at the tail of the ONLY method permitted to write _visual_state fields.
	_visual_state.animation_state = _current_anim
	_visual_state.micro_palette_shift = _micro_palette_shift
	_visual_state.micro_outline_intensity = _micro_outline_intensity


## The view/settings layer toggles reduced-motion; the micro tween is then suppressed
## (information is never carried by motion — accessibility). Not a forbidden prefix.
func apply_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


## CR-5b / Formula 3b (story 013) — weekly shader-only delta marker. NEVER touches sprite
## or tier; reduced-motion suppresses the visual tween but the micro is still recorded.
func _maybe_emit_micro(rolling_7day_stat_delta: float) -> void:
	if not _ready_complete or _suppress_emit_this_session:
		return
	var now := _now_unix()
	if not AvatarFormulas.should_micro(
			now, _last_micro_emit_unix, MICRO_EVOLUTION_CADENCE_SECONDS,
			rolling_7day_stat_delta, _in_workout_window()):
		return
	if not _reduced_motion:
		_micro_palette_shift = fmod(_micro_palette_shift + 0.1, 1.0)
		_micro_outline_intensity = clampf(_micro_outline_intensity + 0.1, 0.0, 1.0)
	_last_micro_emit_unix = now
	_micro_baseline_stat_total = _stat_total_now()
	_write_persistence()
	avatar_micro_evolution.emit(&"weekly_stat_delta", {
		"stat_total": _stat_total_now(),
		"rolling_7day_stat_delta": rolling_7day_stat_delta,
		"achieved_at_unix": now,
	})


## G-AR-2 / Q-OQ-DEPTH (story 005). Option A (GDD-recommended): an additive #12 read
## `get_max_unlocked_class_tier() -> int` (max tier ordinal 0..3 reached in ANY single
## class). Mock-scoped today; the real #12 erratum wires the same method name (story 018
## follow-up). EC-TIER-5 fail-safe: if #12 can't resolve depth, return 0 — the
## generalist tier path still works and tier derivation never crashes (CI-INV-2: depth
## is ONLY ever sourced from #12 abilities, never inferred from stat/equipment).
func _resolve_max_class_depth(_unlocked: Dictionary) -> int:
	if _ability != null and _ability.has_method("get_max_unlocked_class_tier"):
		var d: int = int(_ability.get_max_unlocked_class_tier())
		if d >= 0:
			return clampi(d, 0, 3)
	if not _class_depth_unresolved_logged:
		push_warning("[AvatarRenderer] class_depth_unresolved (EC-TIER-5) -> depth 0; generalist path active")
		_class_depth_unresolved_logged = true
	return 0


# --- Sprite resolution (CR-7 / EC-ASSET-1) -----------------------------------

func _resolve_sprite_path(class_posture: StringName, tier: int) -> String:
	if _posture_config == null:
		return EMERGENCY_FRAMES_PATH
	var p := _posture_config.path_for(class_posture, tier)
	return p if p != "" else EMERGENCY_FRAMES_PATH


## Load the SpriteFrames for (class,tier); EMERGENCY fallback on any failure (AC-12).
func derive_sprite_frames(class_posture: StringName, tier: int) -> SpriteFrames:
	var path := _resolve_sprite_path(class_posture, tier)
	var frames := load(path) as SpriteFrames
	if frames == null:
		push_warning("[AvatarRenderer] sprite_load_failure: " + path + " -> EMERGENCY")
		return _emergency_frames
	return frames


# --- Milestone (CR-5 / CR-15 / Formula 3) ------------------------------------

func _maybe_emit_milestone(stat_total: float, ability_count: int, max_class_depth: int) -> void:
	# EC-BOOT-1 / EC-BOOT-5: degraded or corrupt persistence suppresses emits this session.
	if _suppress_emit_this_session:
		return
	var now := _now_unix()
	var gate := AvatarFormulas.milestone_gate(
		_visual_state.evolution_tier, _last_emitted_tier, _last_milestone_emit_unix,
		now, _account_created_unix(), _observed_sessions(), _in_workout_window(),
		MILESTONE_CADENCE_SECONDS, FIRST_BOOT_GRACE_SECONDS, MIN_OBSERVED_SESSIONS)
	if gate["should_emit"]:
		_emit_milestone(stat_total, ability_count, max_class_depth, now)
	elif gate["defer"]:
		_pending_milestone = true
		_write_persistence()


func _emit_milestone(stat_total: float, ability_count: int, max_class_depth: int, now: int) -> void:
	var metrics := {
		"stat_total": stat_total,
		"ability_count": ability_count,
		"max_class_depth": max_class_depth,
		"achieved_at_unix": now,
	}
	_last_emitted_tier = _visual_state.evolution_tier
	_last_milestone_emit_unix = now
	_pending_milestone = false
	_write_persistence()
	# EC-MILE-5: never silently drop — if no #29 listener, buffer + surface next boot.
	if avatar_evolution_milestone.get_connections().is_empty():
		if _pending_emit_queue.size() < MIRROR_MOMENT_PENDING_BUFFER:
			_pending_emit_queue.append(metrics)
		_pending_milestone = true
		_write_persistence()
		return
	avatar_evolution_milestone.emit(_visual_state.evolution_tier, metrics)


func _try_flush_pending_milestone() -> void:
	# Re-validate against current state on a non-workout context (EC-MILE-3).
	if _in_workout_window():
		return
	if _visual_state.evolution_tier <= _last_emitted_tier:
		_pending_milestone = false
		_write_persistence()
		return
	_emit_milestone(
		_visual_state.evolution_tier, 0, 0, _now_unix())


# --- Canonical signal handlers (EC-SIG-1: drop while booting) -----------------

func _on_stat_changed(stat_id, _old_value, _new_value, _source, _is_base_change) -> void:
	# CR-8: a suspended avatar rejects incoming canonical signals (resume re-derives).
	if not _ready_complete or _suspended:
		return
	if stat_id == _stat.StatId.STR or stat_id == _stat.StatId.DEX or stat_id == _stat.StatId.VIT:
		_derive_state_from_canonical(0)


func _on_ability_unlocked(_ability_id, _source) -> void:
	if not _ready_complete or _suspended:
		return
	_derive_state_from_canonical(0)


func _on_ability_cast(ability_id, _caster, _target) -> void:
	# EC-SIG-2: a cast arriving before boot completes is dropped WITH telemetry — never
	# silently. Cast is NOT debounced (atomicity, EC-XSYS-2).
	if not _ready_complete:
		avatar_cast_dropped.emit(ability_id if ability_id != null else &"")
		return
	if _suspended:
		return
	# Only the player's casts drive the avatar CAST anim (CR-2b). MVP treats any cast as
	# the player; caster-identity refinement is a follow-up.
	_request_cast(ability_id if ability_id != null else &"", _now_ms())


func _on_gsm_state_changed(from_state, to_state, payload) -> void:
	var is_initial: bool = payload != null and "source_event" in payload and payload.source_event == _initial_sentinel()
	# Resume path (Formula 5): leaving SUSPENDED restores or resets the held animation
	# BEFORE normal handling re-applies the resumed-into state's anim baseline.
	if _suspended and from_state == _gsm.GameState.SUSPENDED:
		_resume(_now_ms())
	# Suspend path (CR-8): entering SUSPENDED caches + pauses; reject derives until resume.
	if to_state == _gsm.GameState.SUSPENDED:
		_enter_suspend(_now_ms())
		return
	if not _ready_complete:
		return
	# EC-SIG-5: an unknown GSM state is ignored — retain the previous anim, log once.
	if not _known_gsm_state(to_state):
		if not _unknown_state_logged:
			push_warning("[AvatarRenderer] EC-SIG-5: unknown_gsm_state %s ignored, anim retained" % str(to_state))
			_unknown_state_logged = true
		return
	if is_initial:
		_apply_anim_for_gsm(to_state)
		return
	# EC-XSYS-2: GSM-derived anim transitions are debounced (16ms, latest wins); the
	# cast path is never debounced (atomicity).
	_request_gsm_anim_for(to_state, _now_ms())
	# Combat exit re-evaluates a deferred sprite swap.
	if _is_combat_state(from_state) and not _is_combat_state(to_state):
		_derive_state_from_canonical(0)


func _apply_anim_for_gsm(to_state) -> void:
	var target := _anim_target_for_gsm(to_state)
	if target != &"":
		_set_animation_state(target)


## The GSM-derived anim target, or &"" when a cast is in progress and the GSM would
## otherwise force IDLE (cast atomicity — never interrupt a cast).
func _anim_target_for_gsm(to_state) -> StringName:
	if _is_combat_state(to_state):
		return &"COMBAT"
	if _cast_active or _current_anim == &"CAST":
		return &""
	return &"IDLE"


# --- EC-XSYS-2 debounce (16ms, latest-wins; cast NOT debounced) ----------------

func _request_gsm_anim_for(to_state, now_ms: int) -> void:
	var target := _anim_target_for_gsm(to_state)
	if target == &"":
		return
	if (now_ms - _last_gsm_anim_apply_ms) >= GSM_SIGNAL_DEBOUNCE_MS:
		_apply_gsm_anim(target, now_ms)
	else:
		_pending_gsm_anim_target = target  # coalesce; flushed when the window elapses


func _flush_pending_gsm_anim(now_ms: int) -> void:
	if _pending_gsm_anim_target != null and (now_ms - _last_gsm_anim_apply_ms) >= GSM_SIGNAL_DEBOUNCE_MS:
		var t: StringName = _pending_gsm_anim_target
		_apply_gsm_anim(t, now_ms)


func _apply_gsm_anim(target: StringName, now_ms: int) -> void:
	_last_gsm_anim_apply_ms = now_ms
	_pending_gsm_anim_target = null
	_set_animation_state(target)


# --- Cast timing + 1-deep queue (CR-10 / story 007) --------------------------

func _request_cast(ability_id: StringName, now_ms: int) -> void:
	if not _cast_active:
		_start_cast(now_ms)
		return
	# A cast is active. The new cast enters the 1-deep queue. When the queue is full the
	# OLDEST pending is dropped so the most-recent intent wins (AC-07 / EC-ANIM-2).
	if _cast_queue.size() >= CAST_QUEUE_DEPTH:
		var dropped: StringName = _cast_queue.pop_front()
		avatar_cast_dropped.emit(dropped)
	_cast_queue.append(ability_id)


func _start_cast(now_ms: int) -> void:
	_cast_active = true
	_cast_started_ms = now_ms
	_set_animation_state(&"CAST")  # onset <=100ms (synchronous, CR-10a)
	if _sprite != null and _sprite.has_method("play"):
		_sprite.play(&"cast")


## Advance the cast machine to now_ms; releases the queued cast when CAST_TOTAL_MS elapses.
func _tick_cast(now_ms: int) -> void:
	if not _cast_active:
		return
	if (now_ms - _cast_started_ms) < CAST_TOTAL_MS:
		return
	_cast_active = false
	if not _cast_queue.is_empty():
		_cast_queue.pop_front()
		_start_cast(now_ms)
	else:
		_set_animation_state(_idle_or_combat_anim())


func _idle_or_combat_anim() -> StringName:
	if _gsm != null and _is_combat_state(_gsm.get_current_state()):
		return &"COMBAT"
	return &"IDLE"


# --- bfcache suspend / resume (CR-8 / Formula 5 / story 010) ------------------

func _enter_suspend(now_ms: int) -> void:
	if _suspended:
		return
	var frame := 0
	var progress := 0.0
	if _sprite != null:
		if _sprite.has_method("get_frame"):
			frame = int(_sprite.get_frame())
		if "frame_progress" in _sprite:
			progress = float(_sprite.frame_progress)
	_suspended_snapshot = {
		"animation_state": _current_anim,
		"current_frame": frame,
		"frame_progress": progress,
		"state_before_suspend": _gsm.get_current_state() if _gsm != null else -1,
		"suspended_at_monotonic_ms": now_ms,
		"cast_active": _cast_active,
	}
	_suspended = true
	# CR-8 命脈: pause() HOLDS the frame; stop() RESETS to 0 (FORBIDDEN here — Pass-4 fix).
	if _sprite != null and _sprite.has_method("pause"):
		_sprite.pause()


func _resume(now_ms: int) -> void:
	if not _suspended:
		return
	_suspended = false
	var snap := _suspended_snapshot
	_suspended_snapshot = {}
	var raw_delta := now_ms - int(snap.get("suspended_at_monotonic_ms", now_ms))
	# EC-SUS-3: a mid-cast suspend never restores the mid-cast frame (atlas may have
	# unloaded). Synthesize animation_finished: end the cast and release any queued cast.
	if bool(snap.get("cast_active", false)):
		_cast_active = false
		if not _cast_queue.is_empty():
			_cast_queue.pop_front()
			_start_cast(now_ms)
		else:
			_set_animation_state(_idle_or_combat_anim())
			if _sprite != null and _sprite.has_method("play"):
				_sprite.play(&"idle")
		return
	var action := AvatarFormulas.bfcache_resume_action(raw_delta, BFCACHE_CONTINUE_THRESHOLD_MS)
	if action == AvatarFormulas.RESTORE_SNAPSHOT:
		# EC-SUS-1: restore the exact held frame. Animation goes through the backing-var
		# writer (CI-1 single-writer); the derive tail syncs it into _visual_state.
		_set_animation_state(snap.get("animation_state", &"IDLE"))
		if _sprite != null:
			if _sprite.has_method("play"):
				_sprite.play()
			if _sprite.has_method("set_frame_and_progress"):
				_sprite.set_frame_and_progress(
					int(snap.get("current_frame", 0)), float(snap.get("frame_progress", 0.0)))
	else:
		# EC-SUS-2 / AC-18: >=30s or negative (untrusted clock) -> reset IDLE + re-derive.
		if raw_delta < 0:
			push_warning("[AvatarRenderer] avatar_monotonic_anomaly: negative resume delta %d -> reset" % raw_delta)
		_cast_active = false
		_cast_queue.clear()
		_set_animation_state(&"IDLE")
		if _sprite != null and _sprite.has_method("play"):
			_sprite.play(&"idle")
		_derive_state_from_canonical(0)


func _known_gsm_state(s) -> bool:
	if _gsm == null:
		return true
	return s in _gsm.GameState.values()


func _set_animation_state(new_state: StringName) -> void:
	# CR-6 / CI-1 single-writer (AC-23): animation is event-driven, so the LIVE value lives in
	# the `_current_anim` backing var — it is NOT written into `_visual_state` here. The derive
	# tail is the ONLY writer of `_visual_state.animation_state` (it syncs `_current_anim`).
	# get_animation_state() reads the live backing var, so a transition is reflected immediately.
	if _current_anim == new_state:
		return
	_current_anim = new_state
	animation_state_changed.emit(new_state)


# --- Read-only public API (CR-11) --------------------------------------------

func get_visual_state() -> AvatarVisualState:
	return _visual_state.duplicate(true)


func get_class_posture() -> StringName:
	return _visual_state.class_posture


func get_evolution_tier() -> int:
	return _visual_state.evolution_tier


func get_animation_state() -> StringName:
	# CI-1: the live event-driven animation lives in the backing var; _visual_state.animation_state
	# is a derive-tail-synced mirror (a transition between derives would otherwise read stale).
	return _current_anim


func is_ready_for_milestone_check() -> bool:
	return _ready_complete


## The #29 ceremony seam (AC-13). #26 renders NO ceremony from this.
func get_evolution_snapshot() -> AvatarEvolutionSnapshot:
	var snap := AvatarEvolutionSnapshot.new()
	snap.tier = _visual_state.evolution_tier
	snap.class_posture = _visual_state.class_posture
	snap.sprite_frames_resource_path = _visual_state.sprite_frames_resource_path
	snap.hero_pose_frame = 0  # designated mirror-pose still; story 015 / asset-spec assigns
	snap.prior_tier = _last_emitted_tier
	snap.prior_sprite_frames_resource_path = (
		_resolve_sprite_path(_visual_state.class_posture, _last_emitted_tier)
		if _last_emitted_tier < _visual_state.evolution_tier else ""
	)
	var unlocked_now: Dictionary = _ability.get_unlocked_abilities()
	snap.source_metrics = {
		"stat_total": _stat_total_now(),
		"ability_count": unlocked_now.size(),
		"max_class_depth": _resolve_max_class_depth(unlocked_now),
		"achieved_at_unix": _last_milestone_emit_unix,
	}
	snap.snapshot_taken_unix = _now_unix()
	return snap


# --- Helpers -----------------------------------------------------------------

func _stat_total_now() -> float:
	return (
		AvatarFormulas.sanitize_stat(_stat.get_stat(_stat.StatId.STR))
		+ AvatarFormulas.sanitize_stat(_stat.get_stat(_stat.StatId.DEX))
		+ AvatarFormulas.sanitize_stat(_stat.get_stat(_stat.StatId.VIT)))


func _in_workout_window() -> bool:
	var s = _gsm.get_current_state()
	return s == _gsm.GameState.WORKOUT_ACTIVE or s == _gsm.GameState.REST_PERIOD


func _is_combat_state(s) -> bool:
	return s == _gsm.GameState.COMBAT_ACTIVE or s == _gsm.GameState.BOSS_ENCOUNTER


func _initial_sentinel() -> String:
	if "INITIAL_STATE_PAYLOAD_SOURCE_EVENT" in _gsm:
		return _gsm.INITIAL_STATE_PAYLOAD_SOURCE_EVENT
	return "initial_state"


func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())


## Monotonic ms — injectable clock seam for deterministic cast/suspend timing tests.
func _now_ms() -> int:
	return _clock.now_ms() if _clock != null else Time.get_ticks_msec()


func _account_created_unix() -> int:
	# Sourced from persistence/backend in later stories; 0 keeps the epoch-zero guard
	# conservative (now - 0 is huge, but gate_b first-boot also requires sessions).
	return 0


func _observed_sessions() -> int:
	# Conservative default 0 until in-app session tracking is wired (later story):
	# the epoch-zero guard's first-boot branch requires >= MIN_OBSERVED_SESSIONS, so
	# 0 SUPPRESSES a fresh-account backfill milestone (Pillar 1 — never fabricate a
	# tier-up the player hasn't earned in-app). Returning accounts (last_emit > 0) use
	# the cadence branch and are unaffected.
	return 0
