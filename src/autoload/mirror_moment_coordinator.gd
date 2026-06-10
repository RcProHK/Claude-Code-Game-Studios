extends Node
## MirrorMomentCoordinator (#29) — Pillar 5 weekly ceremony orchestrator.
##
## Owns the weekly "stop and recognise yourself" ceremony: cadence detection (CR-M1),
## non-workout presentation gate (CR-M3), pending-milestone latch (CR-M4), before→after
## reveal composition + screenshot prompt (CR-M7) and the #5 celebration burst (CR-M8).
##
## ADR-0010 seam: holds ZERO evolution-tier state (CR-M14 / CI-MM-1). Every tier number
## is read from #26.get_evolution_snapshot() / the milestone payload — never derived here.
## One-directional #29→#26 (no back-edge). Terminal Polish system (no downstream).
##
## Boot order (ADR-0008 / G-MM-1): tail, after {#26 AvatarRenderer, #1 GSM, #3 Persistence,
## #5 ParticleSystemWrapper}. See design/gdd/mirror-moment.md.

# --- FSM ---
enum Phase { BOOTING, DORMANT, ARMED, PRESENTING, PAUSED }

# --- Telemetry signals (#28 subscribes; emit-only) ---
## A ceremony was shown. content ∈ MirrorMomentFormulas.CONTENT_*.
signal ceremony_presented(content: int, tier: int)
## Player tapped 截圖分享 — non-card chrome hidden, native-screenshot hint shown (mirror.share_prompted).
signal share_prompted()
## Player confirmed a screenshot (mirror.shared, FT-2).
signal shared(at_unix: int)
## Player dismissed without sharing (mirror.share_skipped).
signal share_skipped()
## Honest no-change skip (mirror.no_change_skip, CR-M15).
signal no_change_skip()
## Snapshot unusable at present-time (mirror.snapshot_invalid, EC-MM-8 CRITICAL).
signal snapshot_invalid()

# --- Persistence (CR-M13, mirror_moment.* namespace) ---
const PERSIST_KEY := "mirror_moment"
const SCHEMA_VERSION := 1

# --- Config (CR-M1 / CI-MM-3 data-driven) ---
const CONFIG_PATH := "res://assets/data/mirror_moment_config.tres"

# --- Untyped DI seams (reference_gdscript_di_seam — typed Node breaks member check) ---
var _avatar = null        ## #26 AvatarRenderer (HARD)
var _gsm = null           ## #1 GameStateMachine (HARD)
var _persistence = null   ## #3 PersistenceLayer (HARD)
var _particles = null     ## #5 ParticleSystemWrapper (HARD — celebration burst)
var _loot_reveal = null   ## #21 LootRevealCoordinator (layer reuse, has_method-guarded)
var _attention = null     ## #33 AttentionBudget (SOFT — extra gate)
var _workout = null       ## #9 WorkoutStateTracker (SOFT — caption N/M enrich)
var _inventory = null     ## #17 Equipment & Inventory (SOFT — signature-loot narrative row)
var _pr = null            ## #18 PR Detection (SOFT — PR-breakthrough narrative row)
var _platform = null      ## PlatformDetect (announce_aria gateway)
## Optional clock seam: an object with now_unix() -> int (+ optional now_ms()). Tests inject
## a controllable clock; production falls back to Time.* .
var _clock = null

# --- Config-backed knobs (loaded; zero literals — CI-MM-3) ---
var _config: MirrorMomentConfig = null

# --- Persisted latch + window markers (CR-M13) ---
var _last_ceremony_unix: int = 0
var _last_ceremony_tier: int = 0
var _pending_evolution_ceremony: bool = false
var _pending_tier: int = 0
var _pending_source_metrics: Dictionary = {}
var _week_had_change: bool = false
var _ceremony_count: int = 0
var _last_shared_unix: int = 0

# --- Runtime FSM state ---
var _phase: int = Phase.BOOTING
var _ready_complete: bool = false
## EC-MM-14 stable-IDLE confirmation counter (frames spent continuously safe while ARMED).
var _stable_idle_frames: int = 0
## CR-M12 suspend bookkeeping.
var _suspended_at_monotonic_ms: int = 0
var _phase_before_suspend: int = Phase.DORMANT
## The live ceremony (set on present, cleared on dismiss).
var _active_content: int = MirrorMomentFormulas.CONTENT_NONE
var _active_tier: int = 0

# --- Owned-fallback overlay layers (used only when #21 layers unavailable) ---
const CELEBRATION_VFX_LAYER: int = 110
const MODAL_LAYER: int = 120
var _own_celebration_layer: CanvasLayer = null
var _own_modal_layer: CanvasLayer = null
var _overlay_root: Control = null


func _ready() -> void:
	if _avatar == null:
		_avatar = _node_or_null(&"AvatarRenderer")
	if _gsm == null:
		_gsm = _node_or_null(&"GameStateMachine")
	if _persistence == null:
		_persistence = _node_or_null(&"PersistenceLayer")
	if _particles == null:
		_particles = _node_or_null(&"ParticleSystemWrapper")
	if _loot_reveal == null:
		_loot_reveal = _node_or_null(&"LootRevealCoordinator")
	if _attention == null:
		_attention = _node_or_null(&"AttentionBudget")
	if _workout == null:
		_workout = _node_or_null(&"WorkoutStateTracker")
	if _inventory == null:
		_inventory = _node_or_null(&"InventorySystem")
	if _pr == null:
		_pr = _node_or_null(&"PrDetection")
	if _platform == null:
		_platform = _node_or_null(&"PlatformDetect")

	_load_config_or_crash()
	_read_persistence()
	_instantiate_fallback_layers()

	# cfis 3-subscription (ADR-0006 Contract 6). #26 boots earlier (G-MM-1 tail), so the
	# milestone/micro signals fired during boot are replayed to us (CR-M11 replay-safe).
	# GSM routes through connect_for_initial_state too (the safe-context gate needs the
	# initial state). #26 signals are plain domain signals (no cfis on them) so we connect
	# them directly — the boot snapshot read below captures any state they would have set.
	if _avatar != null:
		if _avatar.has_signal("avatar_evolution_milestone") and not _avatar.avatar_evolution_milestone.is_connected(_on_avatar_milestone):
			_avatar.avatar_evolution_milestone.connect(_on_avatar_milestone)
		if _avatar.has_signal("avatar_micro_evolution") and not _avatar.avatar_micro_evolution.is_connected(_on_avatar_micro):
			_avatar.avatar_micro_evolution.connect(_on_avatar_micro)
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)

	_phase = Phase.DORMANT
	_ready_complete = true
	# Boot-time evaluation: a persisted pending latch + an already-safe context should arm
	# immediately (the player may have earned a tier-up last session and is opening in IDLE).
	_evaluate_arm()


func _process(_delta: float) -> void:
	if not _ready_complete or _phase == Phase.PAUSED:
		return
	# EC-MM-14: only present after the IDLE context has been stable for present_delay_frames.
	if _phase == Phase.ARMED:
		if _present_gate_open():
			_stable_idle_frames += 1
			if _stable_idle_frames >= _config.present_delay_frames:
				_present()
		else:
			_stable_idle_frames = 0


# --- Config / persistence -----------------------------------------------------

func _load_config_or_crash() -> void:
	_config = load(CONFIG_PATH) as MirrorMomentConfig
	assert(_config != null, "[MirrorMoment] config missing at " + CONFIG_PATH)
	var err := _config.validate()
	assert(err == "", "[MirrorMoment] config invalid: " + err)
	# G-MM-4 / CI-MM-3 parity — MIRROR_CADENCE_SECONDS must equal #26 MILESTONE_CADENCE_SECONDS.
	if _avatar != null and "MILESTONE_CADENCE_SECONDS" in _avatar:
		assert(_config.cadence_seconds == _avatar.MILESTONE_CADENCE_SECONDS,
			"[MirrorMoment] G-MM-4 cadence parity broken: %d != #26 %d" % [_config.cadence_seconds, _avatar.MILESTONE_CADENCE_SECONDS])
	if _avatar != null and "BFCACHE_CONTINUE_THRESHOLD_MS" in _avatar:
		assert(_config.bfcache_continue_threshold_ms == _avatar.BFCACHE_CONTINUE_THRESHOLD_MS,
			"[MirrorMoment] bfcache parity broken: %d != #26 %d" % [_config.bfcache_continue_threshold_ms, _avatar.BFCACHE_CONTINUE_THRESHOLD_MS])


func _read_persistence() -> void:
	var raw = _persistence.read(PERSIST_KEY) if _persistence != null else null
	if raw == null or not (raw is Dictionary):
		# Genuine first boot OR degraded persistence — start clean (never fabricates: every
		# field defaults to "no ceremony yet", and a real change still has to arrive via #26).
		return
	var d: Dictionary = raw
	_last_ceremony_unix = int(d.get("last_ceremony_unix", 0))
	_last_ceremony_tier = int(d.get("last_ceremony_tier", 0))
	_pending_evolution_ceremony = bool(d.get("pending_evolution_ceremony", false))
	_pending_tier = int(d.get("pending_tier", 0))
	# EC-MM-10: a malformed persisted dict drops to {} (render uses fresh snapshot anyway).
	var psm = d.get("pending_source_metrics", {})
	_pending_source_metrics = psm if psm is Dictionary else {}
	_week_had_change = bool(d.get("week_had_change", false))
	_ceremony_count = int(d.get("ceremony_count", 0))
	_last_shared_unix = int(d.get("last_shared_unix", 0))


func _write_persistence() -> bool:
	if _persistence == null:
		return false
	return _persistence.write(PERSIST_KEY, {
		"last_ceremony_unix": _last_ceremony_unix,
		"last_ceremony_tier": _last_ceremony_tier,
		"pending_evolution_ceremony": _pending_evolution_ceremony,
		"pending_tier": _pending_tier,
		"pending_source_metrics": _pending_source_metrics,
		"week_had_change": _week_had_change,
		"ceremony_count": _ceremony_count,
		"last_shared_unix": _last_shared_unix,
		"schema_version": SCHEMA_VERSION,
	})


# --- #26 signal handlers (CR-M4 latch / CR-M2 week_had_change) -----------------

func _on_avatar_milestone(tier: int, source_metrics: Dictionary) -> void:
	# CR-M4: latch the pending tier-up + persist immediately so it survives a kill before
	# the player ever reaches a safe context. Idempotent: re-setting the boolean is a no-op.
	_pending_evolution_ceremony = true
	_pending_tier = maxi(_pending_tier, tier)
	_pending_source_metrics = source_metrics if source_metrics is Dictionary else {}
	_week_had_change = true
	_write_persistence()
	_evaluate_arm()


func _on_avatar_micro(_delta_kind, _source_metrics) -> void:
	# CR-M2b: a weekly micro-evolution marks the week as changed (REFLECTION-eligible).
	# Idempotent boolean (EC-MM-20).
	_week_had_change = true
	_write_persistence()
	_evaluate_arm()


func _on_gsm_state_changed(_from_state, to_state, _payload) -> void:
	if not _ready_complete:
		# During boot cfis delivery — fold into the boot evaluation that runs after _ready.
		return
	# Suspend / resume (CR-M12) takes precedence over normal gating.
	if to_state == _state(&"SUSPENDED"):
		_enter_suspend()
		return
	if _phase == Phase.PAUSED:
		_resume()
	# Any state change re-evaluates the arm gate (Formula 1).
	_evaluate_arm()


# --- FSM transitions ----------------------------------------------------------

## Formula 1 — DORMANT → ARMED when cadence window open ∧ has_change.
func _evaluate_arm() -> void:
	if not _ready_complete or _phase == Phase.PRESENTING or _phase == Phase.PAUSED:
		return
	var armed := MirrorMomentFormulas.ceremony_arm_check(
		_now_unix(), _last_ceremony_unix, _config.cadence_seconds,
		_pending_evolution_ceremony, _week_had_change)
	if armed:
		if _phase != Phase.ARMED:
			_phase = Phase.ARMED
			_stable_idle_frames = 0
	else:
		if _phase == Phase.ARMED:
			_phase = Phase.DORMANT
			_stable_idle_frames = 0


## CR-M3 — presentation only in the IDLE safe context (+ #33 soft gate when present).
func _present_gate_open() -> bool:
	if _gsm == null:
		return false
	if _gsm.get_current_state() != _state(&"IDLE"):
		return false
	# #33 soft: if AttentionBudget is present and denies input, hold (AC-04). Absent → GSM only.
	if _attention != null and _attention.has_method("is_input_permitted"):
		if not bool(_attention.is_input_permitted()):
			return false
	return true


## ARMED → PRESENTING. Reads a FRESH snapshot (CR-M6), selects content (Formula 2), composes
## the reveal, plays the EVOLUTION burst (CR-M8) and shows the screenshot prompt (CR-M7).
func _present() -> void:
	var content := MirrorMomentFormulas.content_tier_selection(
		_pending_evolution_ceremony, _week_had_change)
	if content == MirrorMomentFormulas.CONTENT_NONE:
		# Defense-in-depth (Formula 2 race): nothing real to show → honest skip (CR-M15).
		_mark_window_presented()
		no_change_skip.emit()
		_phase = Phase.DORMANT
		return

	var snap = _avatar.get_evolution_snapshot() if _avatar != null and _avatar.has_method("get_evolution_snapshot") else null
	if snap == null:
		# EC-MM-11: #26 not ready → stay ARMED, retry next tick. Never crash.
		return
	if not _snapshot_usable(snap):
		# EC-MM-8: unusable sprite even after #26 EMERGENCY fallback → skip + mark + CRITICAL.
		snapshot_invalid.emit()
		_mark_window_presented()
		_phase = Phase.DORMANT
		return

	_phase = Phase.PRESENTING
	_active_content = content
	_active_tier = int(snap.tier)

	var show_ghost := MirrorMomentFormulas.should_show_ghost(
		content, int(snap.prior_tier), int(snap.tier), String(snap.prior_sprite_frames_resource_path))
	var caption := _build_caption(content, snap)
	_compose_overlay(snap, content, show_ghost, caption)

	if content == MirrorMomentFormulas.CONTENT_EVOLUTION:
		_play_celebration_burst()

	_announce(content, int(snap.tier))
	ceremony_presented.emit(content, int(snap.tier))


## CR-M9 — dismiss (✕ / backdrop / screenshot-confirmed / auto). Marks the window presented;
## sharing or not does NOT change the marker (no re-nag, Pillar 2).
func dismiss() -> void:
	if _phase != Phase.PRESENTING:
		return
	_mark_window_presented()
	_teardown_overlay()
	_phase = Phase.DORMANT


## CR-M7 — player tapped 截圖分享: hide non-card chrome + show native-screenshot hint.
func request_screenshot() -> void:
	if _phase != Phase.PRESENTING:
		return
	_hide_chrome_for_capture()
	share_prompted.emit()


## CR-M7 — player confirmed they captured (EC-MM-13). Records the share, ends the window.
func confirm_shared() -> void:
	if _phase != Phase.PRESENTING:
		return
	_last_shared_unix = _now_unix()
	shared.emit(_last_shared_unix)
	_mark_window_presented()
	_teardown_overlay()
	_phase = Phase.DORMANT


## CR-M7 / EC-MM-12 — player skipped sharing (dismiss without capture).
func skip_share() -> void:
	if _phase != Phase.PRESENTING:
		return
	share_skipped.emit()
	dismiss()


func _mark_window_presented() -> void:
	# CR-M9 — set window markers + clear the latch + persist. Once-per-cadence-window.
	_last_ceremony_unix = _now_unix()
	if _active_tier > _last_ceremony_tier:
		_last_ceremony_tier = _active_tier
	_pending_evolution_ceremony = false
	_pending_tier = 0
	_pending_source_metrics = {}
	_week_had_change = false
	_ceremony_count += 1
	_write_persistence()
	_stable_idle_frames = 0


# --- Suspend / resume (CR-M12) ------------------------------------------------

func _enter_suspend() -> void:
	if _phase == Phase.PAUSED:
		return
	_phase_before_suspend = _phase
	_suspended_at_monotonic_ms = _now_ms()
	if _phase == Phase.PRESENTING:
		_phase = Phase.PAUSED  # freeze the overlay; keep the window marker unset (not dismissed)


func _resume() -> void:
	if _phase != Phase.PAUSED:
		return
	var raw_delta := _now_ms() - _suspended_at_monotonic_ms
	var action := MirrorMomentFormulas.resume_action(raw_delta, _config.bfcache_continue_threshold_ms)
	if action == MirrorMomentFormulas.RESUME_CONTINUE:
		_phase = Phase.PRESENTING  # continue the frozen ceremony
	else:
		# >30s / negative: collapse the overlay but mark the window presented (no resume spam).
		_teardown_overlay()
		_mark_window_presented()
		_phase = Phase.DORMANT


# --- Caption (CR-M10 narrative, null-safe) ------------------------------------

func _build_caption(content: int, snap) -> String:
	# Base form: tier/class only (R-1 — source_metrics has no weekly count). #9 soft enrich
	# adds week/visit counts when WorkoutStateTracker exposes them; absent → base form.
	var class_posture := String(snap.class_posture)
	var tier := int(snap.tier)
	var base: String
	if content == MirrorMomentFormulas.CONTENT_EVOLUTION:
		if int(snap.prior_sprite_frames_resource_path.length()) == 0 or String(snap.prior_sprite_frames_resource_path) == "":
			base = "首次進化 · %s · T%d" % [class_posture, tier]
		else:
			base = "%s · 進化到 T%d" % [class_posture, tier]
	else:
		base = "本週回顧 · %s" % class_posture
	var prefix := _workout_prefix()
	var head := "%s · %s" % [prefix, base] if prefix != "" else base
	# CR-M10 narrative rows (#17 signature loot / #18 PR) — null-safe; absent → head only.
	var rows := _narrative_rows()
	if rows.is_empty():
		return head
	return head + "\n" + "\n".join(rows)


## CR-M10 — optional narrative rows from soft deps (#17 signature loot / #18 PR breakthrough).
## Returns [] when no surface is present / nothing this week (EC-MM-19 null-safe). #29 reads
## already-existing receipt text only — it never searches loot or judges a PR itself.
func _narrative_rows() -> Array:
	var rows: Array = []
	if _inventory != null and _inventory.has_method("get_ceremony_signature_text"):
		var sig := String(_inventory.get_ceremony_signature_text())
		if sig != "":
			rows.append("本週簽名戰利品 · " + sig)
	if _pr != null and _pr.has_method("get_ceremony_pr_text"):
		var pr := String(_pr.get_ceremony_pr_text())
		if pr != "":
			rows.append("本週 PR · " + pr)
	return rows


## #9 SOFT enrich — "第 N 週 · 練咗 M 次". Null-safe: any gap → "" (caption stays base form).
func _workout_prefix() -> String:
	if _workout == null:
		return ""
	var week := -1
	var visits := -1
	if _workout.has_method("get_week_number"):
		week = int(_workout.get_week_number())
	if _workout.has_method("get_total_workout_count"):
		visits = int(_workout.get_total_workout_count())
	if week >= 0 and visits >= 0:
		return "第 %d 週 · 練咗 %d 次" % [week, visits]
	if visits >= 0:
		return "練咗 %d 次" % visits
	return ""


# --- Overlay (UI — reuse #21 110/120 shared infra; fallback self-owned) --------

func _instantiate_fallback_layers() -> void:
	# Only used when #21 LootRevealCoordinator is absent (test isolation / #21 Not Started).
	# When #21 is present we reuse its persistent 110/120 layers (G-MM-2).
	if _loot_reveal != null and _loot_reveal.has_method("get_celebration_vfx_layer"):
		return
	_own_celebration_layer = CanvasLayer.new()
	_own_celebration_layer.name = "MirrorCelebrationVFXLayer"
	_own_celebration_layer.layer = CELEBRATION_VFX_LAYER
	add_child(_own_celebration_layer)
	_own_modal_layer = CanvasLayer.new()
	_own_modal_layer.name = "MirrorModalLayer"
	_own_modal_layer.layer = MODAL_LAYER
	add_child(_own_modal_layer)


func _celebration_layer() -> CanvasLayer:
	if _loot_reveal != null and _loot_reveal.has_method("get_celebration_vfx_layer"):
		return _loot_reveal.get_celebration_vfx_layer()
	return _own_celebration_layer


func _modal_layer() -> CanvasLayer:
	if _loot_reveal != null and _loot_reveal.has_method("get_modal_layer"):
		return _loot_reveal.get_modal_layer()
	return _own_modal_layer


## Build the share-card chrome on the modal layer (MVP minimal). Defensive: a missing layer
## (headless / degraded) skips the visual build — the FSM + telemetry path is unaffected.
func _compose_overlay(snap, content: int, show_ghost: bool, caption: String) -> void:
	var modal := _modal_layer()
	if modal == null or not is_instance_valid(modal):
		return
	_teardown_overlay()
	_overlay_root = Control.new()
	_overlay_root.name = "MirrorMomentOverlay"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.set_meta("content", content)
	_overlay_root.set_meta("show_ghost", show_ghost)
	_overlay_root.set_meta("caption", caption)
	_overlay_root.set_meta("after_sprite", String(snap.sprite_frames_resource_path))
	_overlay_root.set_meta("prior_sprite", String(snap.prior_sprite_frames_resource_path))
	modal.add_child(_overlay_root)


func _hide_chrome_for_capture() -> void:
	if _overlay_root != null and is_instance_valid(_overlay_root):
		_overlay_root.set_meta("chrome_hidden", true)


func _teardown_overlay() -> void:
	if _overlay_root != null and is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
	_overlay_root = null


func _play_celebration_burst() -> void:
	# CR-M8 — celebration ONLY via #5.play() (never instantiate GPUParticles2D — CI-MM-2).
	# B-1: a LOOT preset reaches #5 LARGE tier and reparents onto CelebrationVFXLayer 110.
	if _particles == null or not _particles.has_method("play"):
		return
	_particles.play(_config.celebration_burst_preset, _burst_position(), _config.celebration_particle_multiplier)


func _burst_position() -> Vector2:
	# Avatar centre; headless / no-view → viewport centre fallback.
	var vp := get_viewport()
	if vp != null:
		return vp.get_visible_rect().size * 0.5
	return Vector2.ZERO


func _announce(content: int, tier: int) -> void:
	if _platform == null or not _platform.has_method("announce_aria"):
		return
	var label := "進化到 T%d" % tier if content == MirrorMomentFormulas.CONTENT_EVOLUTION else "本週回顧"
	_platform.announce_aria("Mirror Moment:%s" % label, false)  # polite region


# --- EC-MM-8: snapshot usability ----------------------------------------------

func _snapshot_usable(snap) -> bool:
	# #26 already resolves to EMERGENCY_AVATAR on load failure; an empty after-path here means
	# even the fallback was empty (genuine asset breakage) → unusable.
	return snap != null and String(snap.sprite_frames_resource_path) != ""


# --- Read-only introspection (tests / debug; no setter API — ADR-0010) --------

func get_phase() -> int:
	return _phase

func is_pending_evolution() -> bool:
	return _pending_evolution_ceremony

func has_week_change() -> bool:
	return _week_had_change

func get_ceremony_count() -> int:
	return _ceremony_count

func get_last_ceremony_unix() -> int:
	return _last_ceremony_unix


# --- Helpers ------------------------------------------------------------------

func _state(name: StringName) -> int:
	# GSM GameState enum access via the injected seam (untyped). String() key so a StringName
	# resolves against the String-keyed enum dict on every Godot 4 minor.
	if _gsm != null and "GameState" in _gsm:
		return int(_gsm.GameState[String(name)])
	return -1


func _node_or_null(autoload_name: StringName):
	var root := get_node_or_null("/root")
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(autoload_name)))


func _now_unix() -> int:
	if _clock != null and _clock.has_method("now_unix"):
		return int(_clock.now_unix())
	return int(Time.get_unix_time_from_system())


func _now_ms() -> int:
	if _clock != null and _clock.has_method("now_ms"):
		return int(_clock.now_ms())
	return Time.get_ticks_msec()
