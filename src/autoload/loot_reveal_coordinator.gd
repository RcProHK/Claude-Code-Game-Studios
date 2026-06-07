## LootRevealCoordinator — #21 Loot Drop Modal autoload (story 002 skeleton).
##
## Driving GDD: design/gdd/loot-drop-modal.md (✅ APPROVED 2026-06-06 Pass 3)
## UX spec:     design/ux/loot-drop-modal.md (✅ APPROVED)
## Governing ADRs: ADR-0001 (#21 revision 2026-06-07 — CelebrationVFXLayer 110 +
## ModalLayer 120, ALWAYS, root viewport, BackBufferCopy-immune; blur CUT from
## MVP), ADR-0006 C4/C6 (sequential boot; connect_for_initial_state — boot
## force-reveal arrives via the C6 sentinel), ADR-0008 (G-LM-5: tail append
## after ZoneSystem, predecessor set {#15, #1, #33, #7, #6, #5, #4,
## PlatformDetect} ≺ #21; #28 Telemetry stays last).
##
## Thin orchestration consumer (Rule 1): owns three presentation surfaces
## (full reveal modal / micro-ack toast / banner stack) and the choreography
## sequencing ONLY. Rarity math + ceremony decisions are #15-owned; per-tier
## ladder numbers are read from #15's data-driven config (zero hardcode).
## GSM owns "when" (LOOT_DROP entry is the ONLY open trigger — Rule 2);
## #15 owns "what" (reveal queue pulled via get_pending_drops/get_drop);
## #21 owns "how it presents".
##
## Stateless presentation — ZERO persistence writes (#3 row: reveal pending
## is #15 + GSM owned).
extends Node

## Emitted on dismiss/terminal paths (Rule 6). #15 dequeues by drop_id
## (G-LM-4b reverse-wire story 018); terminal=true → #15 emits loot_confirmed
## → GSM exit chain. #21 NEVER calls GSM directly (GSM AC-14).
signal modal_dismissed(drop_id: String, terminal: bool)

const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const ParticleWrapperScript := preload("res://src/autoload/particle_system_wrapper.gd")

## ADR-0001 #21 revision pinned layer numbers (AC-4 asserts these match).
const CELEBRATION_VFX_LAYER: int = 110
const MODAL_LAYER: int = 120

## Modal FSM (GDD States and Transitions — 8 states + in_catchup mode flag).
## FSM state ≠ timeline stage: ENTRY/CEREMONY are input-policy gates; the
## ceremony_freeze emission point is timeline-driven (T=D_hold), not edge-driven.
enum ModalState {
	HIDDEN,          ## not visible (pre-warmed) — terminal exits land here
	ENTRY,           ## S0 burst + S1 scale-in
	CEREMONY,        ## S2 ladder running (hold/focal-push → freeze @ peak, D2)
	STEADY,          ## S3 dismissable terminal frame (banking commits here)
	EXITING,         ## S4 exit anim (or stash collapse)
	CATCHUP_PROMPT,  ## "您有 N 個未拆 loot" center prompt
	CATCHUP_STREAM,  ## sub-RARE zero-tap display-only beats
	CATCHUP_GRID,    ## contact-sheet post-commit summary
}

## Table-driven edge law (AC-37): EDGE_TABLE[state][in_catchup] = legal targets.
## Off-table transition attempts are rejected loudly (push_error + no-op) —
## never a silent jump. Derived 1:1 from the GDD FSM table (Pass 1 8-state fix).
const EDGE_TABLE: Dictionary = {
	ModalState.HIDDEN: {
		false: [ModalState.ENTRY, ModalState.CATCHUP_PROMPT],
		true: [],  # in_catchup auto-resets on HIDDEN entry — never true here
	},
	ModalState.ENTRY: {
		false: [ModalState.CEREMONY, ModalState.ENTRY, ModalState.HIDDEN],
		true: [ModalState.CEREMONY, ModalState.ENTRY, ModalState.CATCHUP_GRID, ModalState.HIDDEN],
	},
	ModalState.CEREMONY: {
		false: [ModalState.STEADY, ModalState.ENTRY, ModalState.HIDDEN],
		true: [ModalState.STEADY, ModalState.ENTRY, ModalState.CATCHUP_GRID, ModalState.HIDDEN],
	},
	ModalState.STEADY: {
		false: [ModalState.EXITING],  # rollback @ S3 = display no-op, stays (Rule 11)
		true: [ModalState.EXITING],
	},
	ModalState.EXITING: {
		false: [ModalState.ENTRY, ModalState.HIDDEN],
		true: [ModalState.ENTRY, ModalState.CATCHUP_GRID, ModalState.HIDDEN],
	},
	ModalState.CATCHUP_PROMPT: {
		false: [ModalState.CATCHUP_STREAM, ModalState.ENTRY, ModalState.HIDDEN],
		true: [],  # prompt is the catch-up entry point — flag not yet set
	},
	ModalState.CATCHUP_STREAM: {
		false: [],
		true: [ModalState.ENTRY, ModalState.CATCHUP_GRID, ModalState.HIDDEN],
	},
	ModalState.CATCHUP_GRID: {
		false: [],
		true: [ModalState.HIDDEN],
	},
}

# --- DI seams (untyped node seams — project DI discipline) ---
var _gsm             ## seam 1: #1 GameStateMachine (default /root/GameStateMachine)
var _loot_system     ## seam 2: #15 LootDropSystem (default /root/LootDropSystem)
var _inventory       ## seam 10: #17 InventorySystem (receive_loot @ S3 — INV-M3)
var _particles       ## seam 5: #5 ParticleSystemWrapper (burst — FR-2 carrier)
var _audio           ## seam 6: #4 AudioManager (fanfare caller = #21 — EG-1 precedent)
var _camera          ## seam 7: #7 CameraController (request_focal + focal_completed)
var _platform        ## seam 11: PlatformDetect (announce_aria gateway — G-LM-6)
var _screen_effects  ## seam 8: #6 ScreenEffects (shake; ceremony_freeze/release/saturation — G-LM-3 shapes, fake until story 021)

## seam 3: F1 per-tier timeline data (default = class defaults — GDD table).
var _timing_config: LootRevealTimingConfig = null

## seam 4: accessibility — motion_reduction matrix input (EC-M4). Settings
## propagation wiring lands with the a11y stories; tests drive it directly.
var _motion_reduction: bool = false

## seam 9: ADR-0005 thresholds carrier (EC-M15 tier-consistency gate reads
## tier_thresholds — #15-owned numbers, never re-printed here).
var _rarity_config = null

## Nominal breakdown bar width in px (UI layout drives the real value;
## EC-M12 resize updates it). W_BAR_MIN display gate lives in the formula.
var _current_w_bar: int = 160

## Single-owner CanvasLayers (Rule 1: coordinator is the only instantiator
## of the >100 band — ADR-0001 #21 revision).
var _modal_layer: CanvasLayer = null
var _celebration_vfx_layer: CanvasLayer = null

## FSM state + first-class catch-up mode flag (AC-37 asserts on the pair).
var _state: int = ModalState.HIDDEN
var _in_catchup: bool = false

## Global reveal clock (F1 unified timing model): T=0 = reveal-start
## orchestration frame; delta-time accumulated, fake-clock testable (AC-40).
## All three tracks key off this single clock — never additive stage timers.
var _reveal_clock_ms: float = 0.0

## Tier of the drop currently revealing (LootEnums.RarityTier ordinal).
## Story 010 wires this from the #15 record pull; COMMON until then.
var _current_tier: int = LootEnums.RarityTier.COMMON

## Data-load assert outcome (F1) — invalid config refuses to reveal (fail
## loud, NEVER clamp).
var _config_valid: bool = false

## Drop currently revealing (committed-store pull — AC-32 hardening in 010).
var _current_drop = null

## Content slots (UX §B 1-6) — filled SYNCHRONOUSLY at reveal start (AC-10:
## no staggered pop-in; a tired glance may land on any frame).
var _content_slots: Dictionary = {}
var _active_content_tweens: int = 0  # structural pin — MVP content never tweens

## Freeze bookkeeping (INV-M1 single-exit skeleton — story 007 hardens).
var _freeze_issued: bool = false
var _freeze_handle = null
var _skip_pending_freeze: bool = false  # fast-complete before issue ⇒ never issue (F5)

## F5 fast-complete state (story 005).
var _fast_complete_active: bool = false
var _s3_entry_target_ms: float = -1.0  # min(t_tap + SNAP, T_block) — D5 clamp
var _since_s3_ms: float = 0.0          # debounce anchor accumulator (S3 entry)
var _s3_entries: int = 0               # exactly-once guard observable (AC-50 race)

## Burst handle of the current reveal (fast-complete stops it — natural fade).
var _burst_handle = null

## EC-M2 — freeze rejected by #6 (BOOTING/SUSPENDED not serviceable):
## ceremony degrades to the motion_reduction-variant timeline (reveal is the
## Pillar 3 hard guarantee; time-stop is garnish).
var _freeze_rejected: bool = false

## EC-M1 — suspend parking (freeze state NEVER survives the suspend boundary).
var _suspended_mid_reveal: bool = false
var _suspend_at_ms: int = 0

## Injectable monotonic clock (tests drive resume deltas deterministically).
var _now_ms: Callable = Callable(Time, "get_ticks_msec")

## INV-M3 banking state (story 009). _banked guards exactly-once per drop.
var _banked: bool = false
var _pending_stash_exit: bool = false  # QUEUED_SUSPENDED → stash-exit (011 consumes)

## S4 exit + inter-reveal gap bookkeeping (story 010).
var _exit_clock_ms: float = 0.0
var _exit_emitted: bool = false       # AC-23 idempotency — emit exactly once per exit
var _in_gap: bool = false             # gap runs INSIDE the EXITING state (no extra FSM state)
var _gap_clock_ms: float = 0.0
var _gap_target_ms: float = 0.0
var _last_dismissed_id: String = ""   # exclusion until #15's dequeue handler lands (018)
var _stash_mode: bool = false         # story 011 — post-S3 force-close collapse variant
var _force_closed_mid_exit: bool = false  # force-close landed mid-S4 → no gap-advance

## Rollback bookkeeping (story 012). Rolled ids mirror #15's own removal
## (pull-model exclusion until the real dequeue is observable).
var _rolled_ids: Array[String] = []
var _rollback_gap_pending: bool = false  # gap before the next ENTRY after a rollback-cancel

## Catch-up (contact-sheet) state — stories 014/015. Drops are SELECTED ONCE
## at reveal-all (K-cap never re-picks — EC-M8/Rule 11); phases never revisit
## (termination guarantee).
var _prompt_count: int = 0               # banner N (EC-M18 in-place updates)
var _catchup_stream: Array = []          # sub-RARE drops, display order
var _catchup_stream_displayed: Array = []  # display-only beats awaiting batch commit (015)
var _catchup_stream_index: int = 0
var _stream_clock_ms: float = 0.0
var _stream_phase: String = ""           # "banner" / "beats"
var _catchup_ceremonies: Array = []      # RARE+ drops, ascending reveal order
var _catchup_grid_items: Array = []      # overflow (sub-RARE 「+N」-able + RARE+ own cells)
var _catchup_phase: String = ""          # "stream" / "ceremonies" / "grid" — 唔回頭
var _catchup_exit_pending: bool = false  # 「稍後再拆」mid-ceremony → S3 後 stash + terminal

## Banner stack (story 016 — Rule 12): top-edge status region, 同屏最多 1 條,
## priority private_mode > 其他;displacement ≠ one-shot dismissal(被 displace
## 嘅 banner predicate 仍 true 就 re-render — #20-side arbitration 係 AC-78/026)。
var _banner_active_kind: String = ""
var _banner_displaced_kind: String = ""
var _banner_deferred: Array[String] = []  # modal active 時 loot_disabled defer

## SR announcement state (story 025 — AC-77 once-only + intra-queue short variant).
var _announced_current: bool = false   # exactly-once per drop (fast-complete 唔 double)
var _reveals_this_run: int = 0         # 連環 reveal 計數 — 第二件起用 short variant

## Deferred acknowledgement bucket (F4 — story 013 owns aggregation/flush;
## EC-M14 CONVERTED_DUPE shard acks land here from 009). Entry shape:
## {tier:int, reason:String, n:int(default 1)}.
var _deferred_acks: Array = []

## F4 toast instance state (story 013). Pure-data toast + a contentless
## display node — the real visual skin is the UI evidence story (027).
var _toast_active: bool = false
var _toast_n: int = 0
var _toast_tier: int = 0
var _toast_age_ms: float = 0.0
var _toast_phase: String = ""            # "entry" / "plateau" / "fade"
var _toast_phase_ms: float = 0.0
var _toast_plateau_remaining_ms: float = 0.0
var _toast_node: Node = null
var _toast_container: Node = null
var _carryover_acks: Array = []          # cap-overflow bucket (F4 merge boundary)
var _flush_wait_ms: float = 0.0
var _total_acks: int = 0                 # 守恆 audit input
var _displayed_acks_total: int = 0       # Σ N_agg over CLOSED instances

## Telemetry append-log (#15/#17 verbatim pattern; #28 sink not required).
var _telemetry_log: Array[Dictionary] = []


func _ready() -> void:
	# G-LM-9 (#4 story 023 asserts via AC-76b): coordinator must keep
	# processing while ceremony_freeze pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instantiate_layers()
	if _timing_config == null:
		_timing_config = LootRevealTimingConfig.new()
	if _rarity_config == null:
		_rarity_config = LootRarityConfig.new()  # ADR-0005 defaults
	var config_errors: Array[String] = _timing_config.validate()
	_config_valid = config_errors.is_empty()
	for e: String in config_errors:
		push_error("LootRevealCoordinator: timing config invalid — %s" % e)
	if _gsm == null:
		_gsm = get_node_or_null("/root/GameStateMachine")
	if _loot_system == null:
		_loot_system = get_node_or_null("/root/LootDropSystem")
	if _inventory == null:
		_inventory = get_node_or_null("/root/InventorySystem")
	if _particles == null:
		_particles = get_node_or_null("/root/ParticleSystemWrapper")
	if _audio == null:
		_audio = get_node_or_null("/root/AudioManager")
	if _camera == null:
		_camera = get_node_or_null("/root/CameraController")
	if _screen_effects == null:
		_screen_effects = get_node_or_null("/root/ScreenEffects")
	if _platform == null:
		_platform = get_node_or_null("/root/PlatformDetect")
	if _camera != null and _camera.has_signal("focal_completed"):
		_camera.focal_completed.connect(_on_focal_completed)
	if _loot_system != null and _loot_system.has_signal("loot_dropped"):
		_loot_system.loot_dropped.connect(_on_loot_dropped)
	if _loot_system != null and _loot_system.has_signal("loot_rollback"):
		_loot_system.loot_rollback.connect(_on_loot_rollback)
	if _loot_system != null and _loot_system.has_signal("loot_micro_ack"):
		_loot_system.loot_micro_ack.connect(_on_loot_micro_ack)
	if _loot_system != null and _loot_system.has_signal("loot_disabled"):
		_loot_system.loot_disabled.connect(_on_loot_disabled)
	if _loot_system != null and _loot_system.has_method("on_modal_dismissed"):
		# G-LM-4b reverse-wire: #21 (tail autoload) connects its emit-back into
		# the #15 dequeue handler (#18 G-PR-2 precedent — emitter wires itself).
		modal_dismissed.connect(_loot_system.on_modal_dismissed)
	_toast_container = Node.new()
	_toast_container.name = "ToastContainer"
	add_child(_toast_container)
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		# ADR-0006 C6 — covers the boot force-reveal case where GSM is
		# already in LOOT_DROP before #21 (tail autoload) reaches _ready.
		_gsm.connect_for_initial_state(_on_state_changed)
	if _particles != null and _particles.has_method("register_celebration_layer"):
		# G-LM-2 post-boot handshake — LOOT pool nodes reparent onto the >100
		# layer (freeze-proof + saturation-immune). #21 is tail, so the layer
		# only exists now.
		_particles.register_celebration_layer(_celebration_vfx_layer)


## Lifecycle hygiene (G-LM-2): hand the LOOT pool nodes back to the wrapper
## before our layer frees them (production never tears down — autoload — but
## tests do, and a freed layer must never strand the shared pool).
func _exit_tree() -> void:
	if _particles != null and is_instance_valid(_particles) and _particles.has_method("register_celebration_layer"):
		_particles.register_celebration_layer(null)


## Pre-warmed, hidden until a reveal opens (HIDDEN state — FSM story 003).
func _instantiate_layers() -> void:
	_celebration_vfx_layer = CanvasLayer.new()
	_celebration_vfx_layer.name = "CelebrationVFXLayer"
	_celebration_vfx_layer.layer = CELEBRATION_VFX_LAYER
	_celebration_vfx_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# ADR-0001 #21 revision: screen-space layer on the root viewport. World
	# content lives inside the GameLayer SubViewport — follow_viewport is
	# meaningless here and must stay false; world-anchored positions are
	# explicitly transformed world→screen at call time (story 006).
	_celebration_vfx_layer.follow_viewport_enabled = false
	_celebration_vfx_layer.visible = false
	add_child(_celebration_vfx_layer)

	_modal_layer = CanvasLayer.new()
	_modal_layer.name = "ModalLayer"
	_modal_layer.layer = MODAL_LAYER
	_modal_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_modal_layer.follow_viewport_enabled = false
	_modal_layer.visible = false
	add_child(_modal_layer)


## Single transition law (AC-37): every state change goes through here.
## Off-table → push_error + no-op (never silent). Returns whether it applied.
func _transition(to_state: int) -> bool:
	var legal: Array = (EDGE_TABLE.get(_state, {}) as Dictionary).get(_in_catchup, [])
	if to_state not in legal:
		push_error(
			"LootRevealCoordinator: illegal FSM edge %s(in_catchup=%s) -> %s — off-table, rejected (AC-37)" % [
				ModalState.find_key(_state), _in_catchup, ModalState.find_key(to_state),
			])
		return false
	_state = to_state
	if _state == ModalState.HIDDEN:
		_in_catchup = false  # terminal exits always reset the mode flag
		_modal_layer.visible = false
		_celebration_vfx_layer.visible = false
		_flush_deferred_banners()  # Rule 12 — banner 喺 dismiss 後先出
		_reveals_this_run = 0      # short-variant 計數隨 occupancy 重置
	elif _state == ModalState.STEADY:
		_since_s3_ms = 0.0  # debounce anchor = S3 ENTRY (F5/AC-15 unified)
		_s3_entries += 1
		_commit_current_drop()  # INV-M3 — S3 is THE banking commit point
		_announce_reveal()      # SR announcement — exactly once per drop (AC-77)
		if _catchup_exit_pending:
			_stash_exit(false)  # 「稍後再拆」mid-ceremony: commit 完即 stash (Rule 10)
	return true


## INV-M3 (story 009): receive_loot fires at S3 ENTRY, exactly once per drop —
## the tap is purely ceremonial (撳快門); a player who never taps never loses
## the item. EC-M14 maps all five ReceiveResult variants.
func _commit_current_drop() -> void:
	if _banked:
		return  # exactly-once (fast-complete / natural / suspend-resume all converge)
	if _current_drop == null:
		return  # nothing to bank (EC-M6 null-skip path never reaches S3 anyway)
	if _inventory == null or not _inventory.has_method("receive_loot"):
		return
	_banked = true
	var result: int = int(_inventory.receive_loot(_current_drop))
	match result:
		EquipmentEnums.ReceiveResult.FAILED_ROLLBACK:
			# 真假 ambiguous (re-entrant defer path returns it too) — zero
			# user-visible delta, dismiss proceeds; #15 recovery chain keeps
			# eventual grant alive (Rule 7 — handler dedupes, defer-path safe).
			_emit_telemetry("loot_reveal.receive_failed", {"drop_id": _drop_id_of(_current_drop), "severity": "CRITICAL"})
			if _loot_system != null and _loot_system.has_method("report_receive_failure"):
				_loot_system.report_receive_failure(_drop_id_of(_current_drop))
		EquipmentEnums.ReceiveResult.QUEUED_SUSPENDED:
			# Suspend × S3 same-frame race — durably parked == success;
			# the visible exit is a stash (story 011 consumes the flag).
			_pending_stash_exit = true
		EquipmentEnums.ReceiveResult.DUPLICATE_NOOP:
			_emit_telemetry("loot_reveal.duplicate_noop", {"drop_id": _drop_id_of(_current_drop)})
			# success — and NO second micro_ack is emitted.
		EquipmentEnums.ReceiveResult.CONVERTED_DUPE:
			# Honest loop closure: shard ack joins the F4 deferred aggregate
			# (flush at terminal + safe state — story 013).
			_enqueue_ack(_current_tier, "converted_dupe")
		_:
			pass  # OK


func _drop_id_of(drop) -> String:
	if drop is Object and "drop_id" in drop:
		return str(drop.drop_id)
	return ""


## Rule 2 — GSM owns "when": → LOOT_DROP is the ONLY open trigger.
## SUSPENDED transitions are the EC-M1 park/resume boundary; any other
## transition out of the reveal context is the Rule 8 force-close path —
## EXCEPT safe→safe moves (EC-M11: the safe set is entry-time only).
func _on_state_changed(_from_state, to_state, _payload) -> void:
	var to_int: int = int(to_state)
	if to_int == GSMScript.GameState.SUSPENDED:
		_on_suspended()
		return
	if _suspended_mid_reveal:
		_on_resumed_from_suspend()
		return  # the resume decision owns this frame; LOOT_DROP retry comes via GSM
	if to_int != GSMScript.GameState.LOOT_DROP:
		if _state != ModalState.HIDDEN and to_int not in GSMScript.LOOT_REVEAL_SAFE_STATES:
			_on_force_close()
		return  # safe→safe mid-modal continues (EC-M11 — no stash, no cancel)
	if _state != ModalState.HIDDEN:
		return  # Rule 6 one-modal-at-a-time (re-entry guarded)
	# EC-M13 — single entry point, ONE depth read, exclusive branch: the
	# force-transition only decides WHEN; the flow is the queue depth's call.
	var depth: int = _queue_depth()
	if depth == 0:
		# Rule 13 — empty-queue LOOT_DROP entry (rollback race): emit the
		# terminal immediately or GSM is stuck (seam runs the #15 chain).
		modal_dismissed.emit("", true)
	elif depth >= _timing_config.catch_up_threshold:
		_open_catchup_prompt(depth)
	else:
		_open_reveal_flow()


## EC-M1 — bfcache/suspend mid-reveal: #6's Suspended override hard-cancels
## the freeze itself; #21 runs the INV-M1 exit (release is a no-op against
## the already-cleared ledger) and PARKS. Freeze state never survives here.
## Post-S3 suspend → Rule 8 SUSPENDED clause: zero frames will render — skip
## every animation and run the branch IMMEDIATELY (emit must not wait for resume).
func _on_suspended() -> void:
	match _state:
		ModalState.ENTRY, ModalState.CEREMONY:
			_suspended_mid_reveal = true
			_suspend_at_ms = int(_now_ms.call())
			_release_freeze()  # idempotent — #6 already cleared its own entry
		ModalState.STEADY:
			_stash_exit(true)  # banked — instant emit, no anim
		ModalState.EXITING:
			if _in_gap:
				_transition(ModalState.HIDDEN)  # emit already happened
			else:
				_finish_exit_closed()  # skip anim, emit once, close


## Rule 8 — GSM force-transition while the modal is open (D1 pre/post-S3 split).
## EC-M7 — catch-up phases each have their own commit point.
func _on_force_close() -> void:
	match _state:
		ModalState.CATCHUP_PROMPT:
			# banner 收埋、零 commit、全部留 pending — terminal emit (EC-M7).
			modal_dismissed.emit("", true)
			_transition(ModalState.HIDDEN)
			return
		ModalState.CATCHUP_STREAM:
			# force-close 嗰刻就係 batch commit point — 已 display beats 單一
			# frame 連發 commit;in-flight 未 display → 留 pending。
			_commit_stream_batch()
			_emit_telemetry("catchup_truncated", {"remaining": _queue_depth(), "reason": "force_close"})
			modal_dismissed.emit("", true)
			_transition(ModalState.HIDDEN)
			return
		ModalState.CATCHUP_GRID:
			# grid 係 post-commit summary → 直接收埋,零 data 影響。
			modal_dismissed.emit("", true)
			_transition(ModalState.HIDDEN)
			return
	match _state:
		ModalState.ENTRY, ModalState.CEREMONY:
			# Pre-S3: cancel + re-reveal (D1) — 未撳快門 = 張相從未影過.
			# ≤1 frame, INV-M1 exit, ZERO emit, item stays in the #15 queue,
			# GSM's loot_reveal_pending stays true (L127 retry semantics).
			_emit_telemetry("re_reveal_count", {"tier": _current_tier})
			_cancel_reveal()
		ModalState.STEADY:
			_stash_exit(false)  # post-S3 stash-exit — Rule 8 / F6
		ModalState.EXITING:
			if _in_gap:
				_transition(ModalState.HIDDEN)  # dismissed item already emitted
			else:
				_force_closed_mid_exit = true  # AC-23: anim finishes, single emit, no advance


## Post-S3 stash-exit (F6): release same frame (idempotent — usually expired),
## collapse ≤ STASH_COLLAPSE_SEC (+0.1s jitter margin budget-checked by config),
## then emit + deferred-ack「+N」for the next safe-state flush (F4 — story 013).
## instant=true (SUSPENDED-triggered) skips the anim entirely.
func _stash_exit(instant: bool) -> void:
	_release_freeze()
	if not _transition(ModalState.EXITING):
		return
	_exit_emitted = false
	_in_gap = false
	_stash_mode = true
	_exit_clock_ms = 0.0
	if instant:
		_finish_exit_closed()


## Closes the modal entirely (GSM has left): single emit, deferred-ack for
## stash, NO gap-advance — remaining items stay pending for the GSM retry.
func _finish_exit_closed() -> void:
	if _exit_emitted:
		return  # AC-23 idempotency
	_exit_emitted = true
	var dismissed_id: String = _drop_id_of(_current_drop)
	_last_dismissed_id = dismissed_id
	if _stash_mode:
		_enqueue_ack(_current_tier, "stash")
		_emit_telemetry("stash_exit_count", {"tier": _current_tier})
	var remaining: Array = _pull_queue()
	modal_dismissed.emit(dismissed_id, remaining.is_empty())
	if _catchup_exit_pending:
		# 「稍後再拆」係玩家 exit — GSM 仍喺 LOOT_DROP,要 terminal 推進
		# (剩餘 selected + 未 stream 件全部原封 pending,banner 下次以新 N 重現)。
		_catchup_exit_pending = false
		if not remaining.is_empty():
			modal_dismissed.emit("", true)
	_transition(ModalState.HIDDEN)


## EC-M1 resume decision (#15 threshold): delta ≤ 30s → re-enter S3 directly
## (content is final; S3 entry fires its commit exactly once; freeze is NEVER
## re-issued). > 30s → pre-S3 cancel semantics (D1: not banked, zero emit,
## item stays pending — re-reveal is honest).
func _on_resumed_from_suspend() -> void:
	_suspended_mid_reveal = false
	var delta: int = int(_now_ms.call()) - _suspend_at_ms
	if delta <= _timing_config.bfcache_continue_threshold_ms:
		_skip_pending_freeze = true  # 嚴禁 re-issue ceremony_freeze
		if _state == ModalState.ENTRY:
			_transition(ModalState.CEREMONY)
		if _state == ModalState.CEREMONY:
			_transition(ModalState.STEADY)
	else:
		_cancel_reveal()


## INV-M1 shared cancel exit — rollback (012) / pre-S3 force-close (011) /
## EC-M1 long-suspend all route through HERE: single release call-site,
## zero modal_dismissed emit, item stays in the #15 queue.
func _cancel_reveal() -> void:
	_release_freeze()
	_fast_complete_active = false
	_transition(ModalState.HIDDEN)


## Rule 2 — doorbell/prep semantics ONLY. NOT an "open modal now" command:
## mid-set deferral is GSM Rule 13's job; #21 never builds its own wait queue.
func _on_loot_dropped(drop_id: String, _rarity_tier: String, _item_type: String, _transition_id: String) -> void:
	if _state == ModalState.CATCHUP_PROMPT:
		_prompt_count = _queue_depth()  # EC-M18 — in-place count, no re-trigger anim
		return
	if _state == ModalState.CATCHUP_STREAM or (_in_catchup and _state != ModalState.HIDDEN):
		var drop = _loot_system.get_drop(drop_id) if _loot_system != null and _loot_system.has_method("get_drop") else null
		if drop != null:
			_catchup_phase_gated_append(drop)  # EC-M8
		return
	if _state != ModalState.HIDDEN:
		return  # AC-7: no second modal, no FSM re-entry
	if _gsm == null or not _gsm.has_method("get_current_state"):
		return
	if int(_gsm.get_current_state()) != GSMScript.GameState.LOOT_DROP:
		return  # deferral is GSM-owned; item stays in the #15 queue
	if _queue_depth() > 0:
		_open_reveal_flow()


func _queue_depth() -> int:
	return _pull_queue().size()


## Pulls the #15 reveal queue (committed store — AC-32 source of truth).
## EC-M6: dangling/null records are skipped with CRITICAL telemetry — a
## placeholder modal would be fabrication. The just-dismissed id is excluded
## locally until #15's dequeue handler lands (story 018 makes this redundant).
func _pull_queue() -> Array:
	if _loot_system == null or not _loot_system.has_method("get_pending_drops"):
		return []
	var out: Array = []
	for drop in _loot_system.get_pending_drops():
		if drop == null:
			_emit_telemetry("loot_reveal.dangling_drop", {"severity": "CRITICAL"})
			continue
		if _last_dismissed_id != "" and _drop_id_of(drop) == _last_dismissed_id:
			continue
		if _drop_id_of(drop) in _rolled_ids:
			continue  # #15's rollback path removes these — pull-model mirror
		out.append(drop)
	return out


## Opens the sequential reveal flow (HIDDEN → ENTRY edge).
func _open_reveal_flow() -> void:
	if not _config_valid:
		push_error("LootRevealCoordinator: reveal refused — timing config failed data-load assert (F1: no clamp)")
		return
	var drop = _peek_head_drop()
	if drop == null:
		return  # EC-M6 — _pull_queue already skipped nulls with telemetry
	_interrupt_toast_for_modal()  # EC-M17 — count folds into deferred, never lost
	if not _transition(ModalState.ENTRY):
		return
	_begin_reveal(drop)
	_modal_layer.visible = true
	_celebration_vfx_layer.visible = true


## Head of the #15 reveal queue (committed store — AC-32 source of truth).
func _peek_head_drop():
	var queue: Array = _pull_queue()
	return queue[0] if not queue.is_empty() else null


## Anchors T=0 and fires the frame-0 orchestration for this drop (F1 unified
## timing model + Rule 4 D2 call order). S0 is a frame-0 EVENT, not a duration:
## burst + fanfare + (RARE+) focal request all leave on THIS call stack — the
## synchronous chain from the GSM trigger is the FR-2 structural guarantee (AC-8).
func _begin_reveal(drop) -> void:
	_current_drop = drop
	_current_tier = _coerce_tier(drop)
	_reveal_clock_ms = 0.0
	_freeze_issued = false
	_freeze_handle = null
	_skip_pending_freeze = false
	_fast_complete_active = false
	_s3_entry_target_ms = -1.0
	_burst_handle = null
	_freeze_rejected = false
	_suspended_mid_reveal = false
	_banked = false
	_pending_stash_exit = false
	_announced_current = false
	_stash_mode = false
	_force_closed_mid_exit = false
	_exit_emitted = false
	_fill_content_slots(drop)
	var anchor: Vector2 = _resolve_reveal_anchor()
	# ── S0 frame-0: tier-colored burst (pre-attentive rarity channel) + fanfare ──
	if _particles != null and _particles.has_method("play"):
		var preset: int = _burst_preset_for_tier(_current_tier)
		var mult: float = _timing_config.particle_multiplier[_current_tier]
		if _motion_reduction:
			mult *= 0.5  # EC-M4 — density halves, ceremony stays
		_burst_handle = _particles.play(preset, anchor, mult)
	if _audio != null and _audio.has_method("play_sfx"):
		_audio.play_sfx(_fanfare_event_for_tier(_current_tier))
	# ── Camera track (T=0, GSM==LOOT_DROP holds by construction — #7 Rule 4):
	#    EPIC/LEG push-in IS S2a (focal duration == hold, D2 同源); RARE pulse. ──
	if not _motion_reduction and _current_tier >= LootEnums.RarityTier.RARE:
		if _camera != null and _camera.has_method("request_focal"):
			_camera.request_focal(
				anchor,
				_timing_config.focal_duration_sec[_current_tier],
				_timing_config.focal_zoom[_current_tier])


## EC-M5 — unknown tier string coerces to COMMON BEFORE any ladder lookup
## (#17 inventory_system.gd:180 同源 — modal tier always == banked tier).
func _coerce_tier(drop) -> int:
	var tier_name: String = str(drop.rarity_tier) if (drop is Object and "rarity_tier" in drop) else "COMMON"
	var tier = LootEnums.RarityTier.get(tier_name)
	if tier == null:
		_emit_telemetry("loot_reveal.unknown_tier", {"raw": tier_name})
		return LootEnums.RarityTier.COMMON
	return tier


func _burst_preset_for_tier(tier: int) -> int:
	if tier >= LootEnums.RarityTier.EPIC:
		return ParticleWrapperScript.PresetId.LOOT_RARE_BURST
	return ParticleWrapperScript.PresetId.LOOT_BURST


func _fanfare_event_for_tier(tier: int) -> StringName:
	return StringName("loot_fanfare_%s" % String(LootEnums.RarityTier.find_key(tier)).to_lower())


## All visual content slots (UX §B 1-6) fill synchronously — zero staggered
## pop-in (AC-10). Slot 7 (SR announcement) fires at S3 (story 025).
func _fill_content_slots(drop) -> void:
	var is_record: bool = drop is Object
	# AC-37b — fast-victory marker (G-LM-4c ⑧): attribution slot uses the
	# 「快勝」copy variant; the ceremony ladder stays tier-driven (layout
	# variant, NOT a ceremony variant — Rule 13b(c)).
	var fast_victory: bool = is_record and "item_metadata" in drop \
		and bool(drop.item_metadata.get("fast_victory", false))
	_content_slots = {
		"rarity_badge": _current_tier,
		"item_icon": str(drop.item_type) if (is_record and "item_type" in drop) else "",
		"item_name": str(drop.item_metadata.get("item_name", "")) if (is_record and "item_metadata" in drop) else "",
		"source_attribution": "快勝" if fast_victory else (str(drop.source_event_kind) if (is_record and "source_event_kind" in drop) else ""),
		"breakdown_bar": _compute_breakdown_slot(drop),
		"dismiss_cta": "影低佢",
	}
	_active_content_tweens = 0


## F2 slot (RARE+ only — AC-45). ws/rr/score ride the record's pinned
## item_metadata keys (G-LM-4a persists them at grant; absent/corrupt →
## EC-M15 hide-the-bar path — the tier claim always wins over the bar).
func _compute_breakdown_slot(drop) -> Variant:
	if _current_tier < LootEnums.RarityTier.RARE:
		return null
	if not (drop is Object and "item_metadata" in drop):
		return null
	var meta: Dictionary = drop.item_metadata
	if not (meta.has("workout_score") and meta.has("rng_roll") and meta.has("rarity_score")):
		_emit_telemetry("loot_reveal.breakdown_mismatch", {"reason": "missing_fields"})
		return null
	var ws: float = float(meta["workout_score"])
	var rr: float = float(meta["rng_roll"])
	var score: float = float(meta["rarity_score"])
	if not LootRevealFormulas.breakdown_visible(ws, rr, score, _current_tier, _rarity_config):
		_emit_telemetry("loot_reveal.breakdown_mismatch", {"reason": "identity_or_tier"})
		return null
	var geometry: Dictionary = LootRevealFormulas.breakdown_geometry(ws, rr, score, _current_w_bar)
	geometry["ws"] = clampf(ws, 0.0, 1.0)
	geometry["rr"] = clampf(rr, 0.0, 1.0)
	return geometry


## EC-M12 — viewport resize / 手機轉向 mid-modal: single-frame re-layout of
## the geometry ONLY. Timers are time-based (untouched); particles never replay.
func on_viewport_resized(new_w_bar: int) -> void:
	_current_w_bar = new_w_bar
	if _content_slots.has("breakdown_bar") and _content_slots["breakdown_bar"] != null:
		_content_slots["breakdown_bar"] = _compute_breakdown_slot(_current_drop)


## reveal_anchor_pos (Rule 4): avatar group query, viewport-center fallback.
## ADR-0001 #21 revision: layers are root-viewport screen-space — a world
## anchor must be explicitly carried into canvas coordinates (no follow).
func _resolve_reveal_anchor() -> Vector2:
	var anchor_node: Node = get_tree().get_first_node_in_group(&"avatar_anchor")
	if anchor_node is Node2D:
		return (anchor_node as Node2D).get_global_transform_with_canvas().origin
	var viewport: Viewport = get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size * 0.5
	return Vector2.ZERO


## D2 freeze-as-hold anchor: EPIC/LEG freeze on focal_completed (camera pinned
## at peak zoom — the pause-bound exit tween freezes with the tree).
func _on_focal_completed(_target_position: Vector2) -> void:
	if _state != ModalState.CEREMONY and _state != ModalState.ENTRY:
		return
	if _current_tier < LootEnums.RarityTier.EPIC:
		return  # RARE freeze anchors on the clock (T = D_hold), not the signal
	_issue_ceremony_freeze()


## Single issuance point for the S2b ladder tail: freeze → shake → saturation
## (AC-12 order). Skips: motion_reduction (EC-M4), timestop==0 tiers,
## fast-complete-before-issue (F5: freeze 未 issue ⇒ 唔 issue).
func _issue_ceremony_freeze() -> void:
	if _freeze_issued or _skip_pending_freeze or _motion_reduction:
		return
	if _timing_config.timestop_ms[_current_tier] <= 0:
		return
	if _screen_effects == null:
		return
	if _screen_effects.has_method("ceremony_freeze"):
		var handle = _screen_effects.ceremony_freeze(
			float(_timing_config.timestop_ms[_current_tier]) / 1000.0)
		if handle == null or (handle is int and int(handle) <= 0):
			# EC-M2 — #6 not serviceable: degrade to the motion-variant
			# timeline for THIS reveal, ceremony continues to S3.
			_freeze_rejected = true
			_emit_telemetry("loot_reveal.freeze_rejected", {"tier": _current_tier})
			return
		_freeze_handle = handle
		_freeze_issued = true
	if _screen_effects.has_method("shake") and _timing_config.shake_intensity[_current_tier] > 0.0:
		_screen_effects.shake(
			_timing_config.shake_intensity[_current_tier],
			_timing_config.shake_duration_sec[_current_tier])
	if _screen_effects.has_method("apply_ceremony_saturation"):
		# G-LM-3 ④ new API shape (fake seam until story 021).
		_screen_effects.apply_ceremony_saturation(
			_timing_config.saturation_drop, _timing_config.saturation_recovery_sec)


# ── Input (story 005 — Rule 5 two-stage tap + F5) ─────────────────────────────

## Keyboard parity (AC-37c): ui_accept == scrim tap, same per-stage policy.
## ui_cancel == catch-up「稍後再拆」(stories 014/015 give it a target).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		handle_tap()
	elif event.is_action_pressed(&"ui_cancel"):
		_handle_catchup_exit()


## The full-screen scrim's single entry point (Fitts + sweat — the whole scrim
## is the surface; the ≥48px「影低佢」CTA is a labelled affordance only).
## #33 exempt handler: NEVER consults is_input_permitted() (EC-15 / AC-11b
## "modal is the input, not the surroundings").
## Per-stage policy (AC-11): ENTRY ignore (covers S0/S1 + tap-through EC-M19);
## CEREMONY fast-complete; STEADY dismiss (debounced); EXITING ignore.
## Ignored taps get NO audio feedback (deliberate — the sting is the sole
## audio subject at that moment; debounce-ignore is not an invalid action).
func handle_tap() -> void:
	match _state:
		ModalState.CEREMONY:
			_fast_complete()
		ModalState.STEADY:
			_attempt_dismiss()
		ModalState.CATCHUP_PROMPT:
			_start_catchup_reveal_all()  # 全屏 tap = reveal-all (Rule 10)
		ModalState.CATCHUP_GRID:
			_handle_catchup_exit()       # tap close → terminal emit
		_:
			pass  # ENTRY / EXITING / HIDDEN / CATCHUP_STREAM (zero-tap)


## F5 stage-1: snap to the S3 terminal frame over SNAP_SEC.
## Freeze active → release THIS frame; not yet issued → never issue (skip).
## Particle stop() = natural fade (never hard-cut); the audio sting keeps
## playing — zero stop/cut calls (colorblind rarity backup channel).
func _fast_complete() -> void:
	if _fast_complete_active:
		return  # second S2 tap — snap already in flight
	_fast_complete_active = true
	_emit_telemetry("ceremony_skip_attempted", {"tier": _current_tier})
	var t_block: int = LootRevealFormulas.t_block_ms(_timing_config, _current_tier, _motion_reduction)
	_s3_entry_target_ms = minf(
		_reveal_clock_ms + _timing_config.snap_sec * 1000.0, float(t_block))
	if _freeze_issued:
		_release_freeze()
	else:
		_skip_pending_freeze = true
	if _burst_handle != null and _burst_handle is Object and _burst_handle.has_method("stop"):
		_burst_handle.stop()
	_advance_timeline()  # same-frame snap-window check (SNAP may be sub-frame)


## F5 stage-2: dismiss, locked out for DISMISS_DEBOUNCE_SEC after a
## fast-completed S3 entry (min-readable window). Natural S3 → zero lockout.
func _attempt_dismiss() -> void:
	if _fast_complete_active and _since_s3_ms < _timing_config.dismiss_debounce_sec * 1000.0:
		return  # debounce-ignore: silent, no ui_error (Rule 5)
	_dismiss()


## Tap = 撳快門. Banking already happened at S3 (INV-M3) — this only exits.
func _dismiss() -> void:
	var total_ms: int = int(_reveal_clock_ms + _since_s3_ms)
	var payload: Dictionary = {"ms": total_ms, "tier": _current_tier}
	if _current_tier >= LootEnums.RarityTier.EPIC and total_ms < 500:
		payload["suspicious_dismiss"] = true  # 誤觸 dismiss = moment 蒸發嘅盲區量度
	_emit_telemetry("time_to_dismiss_ms", payload)
	if not _transition(ModalState.EXITING):
		return
	_exit_clock_ms = 0.0
	_exit_emitted = false
	_in_gap = false
	_stash_mode = false
	_force_closed_mid_exit = false


## S4 anim complete (story 010). Terminal evaluation happens HERE — drops
## that arrived mid-S4 are naturally in the queue read (EC-M20: never a
## mid-exit re-entry; the anim always finishes first).
func _finish_exit() -> void:
	if _exit_emitted:
		return  # AC-23 — force-close landing mid-S4 must not double-emit
	_exit_emitted = true
	var dismissed_id: String = _drop_id_of(_current_drop)
	_last_dismissed_id = dismissed_id
	if _in_catchup:
		# Catch-up ceremonies: per-item commit happened at S3; advance the
		# pre-selected remainder, then the grid (EXITING→ENTRY / →CATCHUP_GRID).
		modal_dismissed.emit(dismissed_id, false)
		if not _catchup_ceremonies.is_empty():
			_in_gap = true
			_gap_clock_ms = 0.0
			_gap_target_ms = LootRevealFormulas.successor_gap_sec(_timing_config, _current_tier) * 1000.0
		else:
			_enter_catchup_grid()
		return
	var remaining: Array = _pull_queue()
	if remaining.size() > 0:
		# Intra-queue: GSM does NOT move (Rule 6) — gap then next ENTRY.
		modal_dismissed.emit(dismissed_id, false)
		_in_gap = true
		_gap_clock_ms = 0.0
		_gap_target_ms = LootRevealFormulas.successor_gap_sec(_timing_config, _current_tier) * 1000.0
	else:
		# Terminal: emit AFTER the anim (AC-19) — #15 chain exits GSM.
		modal_dismissed.emit(dismissed_id, true)
		_transition(ModalState.HIDDEN)


## Gap end — EC-M20 re-evaluation: the queue may have grown (new drop → keep
## revealing, GSM stays) or drained (rollback ate the rest → terminal now).
func _end_gap() -> void:
	_in_gap = false
	if _in_catchup:
		_begin_next_catchup_ceremony_or_grid()
		return
	var head = _peek_head_drop()
	if head != null:
		if _transition(ModalState.ENTRY):
			_begin_reveal(head)
			_modal_layer.visible = true
			_celebration_vfx_layer.visible = true
	else:
		modal_dismissed.emit("", true)
		_transition(ModalState.HIDDEN)


## INV-M1 single freeze-release exit (skeleton — story 007 hardens with
## idempotency + EC-M1/M2; story 021 supplies the real #6 release(handle)).
func _release_freeze() -> void:
	if not _freeze_issued:
		return  # not-issued ⇒ no-op (INV-M1)
	if _screen_effects != null and _screen_effects.has_method("release"):
		_screen_effects.release(_freeze_handle)
	_freeze_issued = false
	_freeze_handle = null


# ── Catch-up contact-sheet mode (stories 014/015 — Rule 10 / F3 / EC-M7/M8/M13/M18) ──

func _open_catchup_prompt(depth: int) -> void:
	_interrupt_toast_for_modal()
	if not _transition(ModalState.CATCHUP_PROMPT):
		return
	_prompt_count = depth
	_modal_layer.visible = true


## Reveal-all (prompt full-scrim tap): selection happens ONCE here.
func _start_catchup_reveal_all() -> void:
	var queue: Array = _pull_queue()
	var tiers: Array = []
	for drop in queue:
		tiers.append(_coerce_tier_of(drop))
	var parts: Dictionary = LootRevealFormulas.catchup_partition(tiers, _timing_config)
	_catchup_stream = []
	for i: int in parts["stream"]:
		_catchup_stream.append(queue[i])
	_catchup_ceremonies = []
	for i: int in parts["ceremonies"]:
		_catchup_ceremonies.append(queue[i])
	_catchup_grid_items = []
	for i: int in parts["grid_overflow"]:
		_catchup_grid_items.append(queue[i])
	_catchup_stream_displayed = []
	_catchup_stream_index = 0
	if _catchup_stream.size() > 0:
		if _transition(ModalState.CATCHUP_STREAM):
			_in_catchup = true
			_catchup_phase = "stream"
			_stream_phase = "banner"
			_stream_clock_ms = 0.0
	else:
		_begin_next_catchup_ceremony_or_grid()


## Stream beats are display-only (luminance-stable — zero per-beat flash;
## the batch commit fires at stream end / force-close — story 015).
func _stream_tick(delta: float) -> void:
	_stream_clock_ms += delta * 1000.0
	if _stream_phase == "banner":
		if _stream_clock_ms >= _timing_config.banner_beat_sec * 1000.0:
			_stream_phase = "beats"
			_stream_clock_ms = 0.0
			# D4 — ONE aggregated cue for the whole stream (single duck handle
			# #4-side; per-beat fanfare is FORBIDDEN — G-LM-8 registers the id).
			if _audio != null and _audio.has_method("play_sfx"):
				_audio.play_sfx(&"loot_stream_aggregate")
		return
	while _stream_clock_ms >= _timing_config.stream_beat_sec * 1000.0 \
			and _catchup_stream_index < _catchup_stream.size():
		_stream_clock_ms -= _timing_config.stream_beat_sec * 1000.0
		_catchup_stream_displayed.append(_catchup_stream[_catchup_stream_index])
		_catchup_stream_index += 1
	if _catchup_stream_index >= _catchup_stream.size():
		_commit_stream_batch()  # stream-end batch commit point (Rule 7 — 015)
		_begin_next_catchup_ceremony_or_grid()


func _begin_next_catchup_ceremony_or_grid() -> void:
	_catchup_phase = "ceremonies" if not _catchup_ceremonies.is_empty() else "grid"
	if _catchup_phase == "ceremonies":
		var next = _catchup_ceremonies.pop_front()
		if _transition(ModalState.ENTRY):
			_in_catchup = true
			_begin_reveal(next)
			_modal_layer.visible = true
			_celebration_vfx_layer.visible = true
	else:
		_enter_catchup_grid()


func _enter_catchup_grid() -> void:
	if not _transition(ModalState.CATCHUP_GRID):
		return
	_catchup_phase = "grid"
	_commit_grid_overflow_batch()  # C-2 — grid entry frame (015)
	# 收尾單一 aggregate announce(stream 逐件零 announce — AC §E)
	var total: int = _catchup_stream.size() + _catchup_grid_items.size() + _reveals_this_run
	var max_tier: int = 0
	for drop in _catchup_grid_items:
		max_tier = maxi(max_tier, _coerce_tier_of(drop))
	max_tier = maxi(max_tier, _current_tier)
	_announce_catchup_grid(total, max_tier)


## EC-M8 — phase-gated append: only a phase that has NOT finished may accept;
## phases never rewind ⇒ catch-up always terminates.
func _catchup_phase_gated_append(drop) -> void:
	var tier: int = _coerce_tier_of(drop)
	if tier < LootEnums.RarityTier.RARE:
		if _state == ModalState.CATCHUP_STREAM and _catchup_stream.size() < _timing_config.max_stream_beats:
			_catchup_stream.append(drop)
		# stream 已過/cap 滿 → 留 pending(下次 catch-up)
	else:
		# K-cap counts the ORIGINAL selection: remainder + the one revealing.
		var in_flight: int = _catchup_ceremonies.size() + (1 if _catchup_phase == "ceremonies" else 0)
		if _catchup_phase != "grid" and in_flight < _timing_config.k_ceremony_max:
			# ascending insert (chronological inside a tier — append-after-equals)
			var inserted: bool = false
			for i: int in range(_catchup_ceremonies.size()):
				if _coerce_tier_of(_catchup_ceremonies[i]) > tier:
					_catchup_ceremonies.insert(i, drop)
					inserted = true
					break
			if not inserted:
				_catchup_ceremonies.append(drop)
		# cap 滿 → 留 pending,唔入 grid(grid 係本 session commit summary — Pass 1 釘)


## Tier coercion without touching the active-reveal state (catch-up bookkeeping).
func _coerce_tier_of(drop) -> int:
	var tier_name: String = str(drop.rarity_tier) if (drop is Object and "rarity_tier" in drop) else "COMMON"
	var tier = LootEnums.RarityTier.get(tier_name)
	return LootEnums.RarityTier.COMMON if tier == null else tier


## Stream-end / force-close batch commit (story 015 wires the G-LM-10 seam).
func _commit_stream_batch() -> void:
	if _catchup_stream_displayed.is_empty():
		return
	_batch_commit_drops(_catchup_stream_displayed)
	_catchup_stream_displayed = []


## C-2 — every overflow item (sub-RARE「+N」collapsibles AND RARE+ own-cell
## items) batch-commits on the grid entry frame.
func _commit_grid_overflow_batch() -> void:
	if _catchup_grid_items.is_empty():
		return
	_batch_commit_drops(_catchup_grid_items)


## Single-frame batch: G-LM-10 public seam wrap + 連發 receive_loot + per-item
## dequeue emits — aggregate/push/persist once (#17-side; AC-72 persist count).
func _batch_commit_drops(drops: Array) -> void:
	var seam: bool = _inventory != null and _inventory.has_method("begin_receive_batch")
	if seam:
		_inventory.begin_receive_batch()
	for drop in drops:
		if _inventory != null and _inventory.has_method("receive_loot"):
			_inventory.receive_loot(drop)
		var id: String = _drop_id_of(drop)
		_consume_id(id)
		modal_dismissed.emit(id, false)
	if seam:
		_inventory.end_receive_batch()


## 「稍後再拆」(corner affordance / ui_cancel) — Pillar 2 never-trap:
## exit 永遠唔丟件 (Rule 10)。
func _handle_catchup_exit() -> void:
	match _state:
		ModalState.CATCHUP_PROMPT:
			_emit_telemetry("catchup_abandoned", {"remaining": _queue_depth()})
			modal_dismissed.emit("", true)  # terminal — GSM 推進;pending 不變
			_transition(ModalState.HIDDEN)
		ModalState.CATCHUP_STREAM:
			_commit_stream_batch()  # 已 display 件 commit;未 display 留 pending
			_emit_telemetry("catchup_abandoned", {"remaining": _queue_depth()})
			modal_dismissed.emit("", true)
			_transition(ModalState.HIDDEN)
		ModalState.CATCHUP_GRID:
			modal_dismissed.emit("", true)
			_transition(ModalState.HIDDEN)
		ModalState.ENTRY, ModalState.CEREMONY:
			if _in_catchup:
				# 當前件 fast-complete → S3 commit → stash 收埋;剩餘留 pending。
				_catchup_exit_pending = true
				if _state == ModalState.CEREMONY:
					_fast_complete()
				# ENTRY 段: content 未 final — 等 CEREMONY 先 snap;flag 喺 S3 接手
		ModalState.STEADY:
			if _in_catchup:
				_catchup_exit_pending = true
				_stash_exit(false)
		_:
			pass


# ── Banner stack (story 016 — Rule 12) ───────────────────────────────────────

## Private Mode 等 status banner。Modal active → 現行 ceremony 行完先出
## (唔 mid-ceremony 偷走 euphoria);copy 係 #15 own。
func _on_loot_disabled(_reason: String) -> void:
	if _state != ModalState.HIDDEN:
		if "private_mode" not in _banner_deferred:
			_banner_deferred.append("private_mode")
		return
	_show_banner("private_mode")


## 同屏最多 1 條;priority: private_mode > 其他(audio silent-mode 等)。
## Displacement 語意:被 displace 嘅 banner 喺高 priority 清走後 re-render。
func _show_banner(kind: String) -> void:
	if _banner_active_kind == "":
		_banner_active_kind = kind
		return
	if kind == "private_mode" and _banner_active_kind != "private_mode":
		_banner_displaced_kind = _banner_active_kind
		_banner_active_kind = kind
	# 同級/較低 priority 嚟 → 唔搶位(現行 banner 留)


func clear_banner(kind: String) -> void:
	if _banner_active_kind != kind:
		return
	_banner_active_kind = ""
	if _banner_displaced_kind != "":
		# predicate 仍 true 就返嚟 — displacement ≠ one-shot dismissal
		var restored: String = _banner_displaced_kind
		_banner_displaced_kind = ""
		_show_banner(restored)


func _flush_deferred_banners() -> void:
	for kind: String in _banner_deferred:
		_show_banner(kind)
	_banner_deferred = []


# ── micro_ack banking + F4 toast (story 013 — Rule 9 / F4 / EC-M17) ─────────

## Rule 9 — micro_ack banking: instant data-layer grant, ZERO UI, dequeue
## emit-back, F4-deferred acknowledgement. The item never leaks into a later
## catch-up as a full ceremony (that would double-acknowledge and overturn
## the #15 cap decision).
func _on_loot_micro_ack(drop_id: String) -> void:
	var drop = null
	if _loot_system != null and _loot_system.has_method("get_drop"):
		drop = _loot_system.get_drop(drop_id)
	if drop == null:
		_emit_telemetry("loot_reveal.dangling_drop", {"severity": "CRITICAL", "path": "micro_ack"})
		return
	var tier: int = _coerce_tier(drop)
	if _inventory != null and _inventory.has_method("receive_loot"):
		var result: int = int(_inventory.receive_loot(drop))
		if result == EquipmentEnums.ReceiveResult.FAILED_ROLLBACK:
			# Rule 9 (c) — same recovery chain as the S3 path (AC-34b variant).
			_emit_telemetry("loot_reveal.receive_failed", {"drop_id": drop_id, "severity": "CRITICAL", "path": "micro_ack"})
			if _loot_system != null and _loot_system.has_method("report_receive_failure"):
				_loot_system.report_receive_failure(drop_id)
	_consume_id(drop_id)
	modal_dismissed.emit(drop_id, false)  # dequeue emit-back (#15 handler — 018)
	_enqueue_ack(tier, "micro_ack")


## F4 entry point for every acknowledgement source (micro_ack / stash /
## CONVERTED_DUPE shard). Visible toast → merge-or-carryover; otherwise the
## deferred bucket waits for the flush gate.
func _enqueue_ack(tier: int, reason: String = "ack", n: int = 1) -> void:
	_total_acks += n
	if _toast_active:
		_try_merge(tier, n)
	else:
		_deferred_acks.append({"tier": tier, "reason": reason, "n": n})


## F4 merge boundary: merge ONLY when remaining-to-cap ≥ MERGE_MIN_REMAIN —
## otherwise the ack goes straight to carryover (the acknowledge guarantee
## is never silently broken by the lifetime cap).
func _try_merge(tier: int, n: int) -> void:
	var remaining_to_cap: float = _timing_config.toast_max_lifetime_sec * 1000.0 - _toast_age_ms
	if remaining_to_cap >= _timing_config.merge_min_remain_sec * 1000.0:
		_toast_n += n
		_toast_tier = maxi(_toast_tier, tier)
		_toast_plateau_remaining_ms = maxf(_toast_plateau_remaining_ms, _timing_config.merge_min_remain_sec * 1000.0)
	else:
		_carryover_acks.append({"tier": tier, "reason": "carryover", "n": n})


## Flush gate (F4): modal fully closed + FLUSH_DELAY + GSM in the
## player-attention-safe set. Mid-workout acks hold and keep aggregating.
func _flush_tick(delta: float) -> void:
	if _toast_active or _deferred_acks.is_empty() or _state != ModalState.HIDDEN:
		_flush_wait_ms = 0.0
		return
	if not _gsm_in_safe_state():
		_flush_wait_ms = 0.0
		return
	_flush_wait_ms += delta * 1000.0
	if _flush_wait_ms >= _timing_config.flush_delay_sec * 1000.0:
		_flush_wait_ms = 0.0
		_open_toast(_deferred_acks)
		_deferred_acks = []


func _gsm_in_safe_state() -> bool:
	if _gsm == null or not _gsm.has_method("get_current_state"):
		return false
	return int(_gsm.get_current_state()) in GSMScript.LOOT_REVEAL_SAFE_STATES


func _open_toast(acks: Array) -> void:
	if acks.is_empty():
		return
	_toast_active = true
	_toast_n = 0
	_toast_tier = 0
	for a: Dictionary in acks:
		_toast_n += int(a.get("n", 1))
		_toast_tier = maxi(_toast_tier, int(a.get("tier", 0)))
	_toast_age_ms = 0.0
	_toast_phase = "entry"
	_toast_phase_ms = 0.0
	_toast_plateau_remaining_ms = _timing_config.toast_visible_sec * 1000.0
	_toast_node = Node2D.new()  # icon + tier tint skin lands with UI; ZERO text node
	_toast_node.name = "MicroAckToast"
	_toast_container.add_child(_toast_node)
	# Toast 一律配 tick(low/mono)— fanfare 音色家族 modal 獨家(#15 L204
	# erratum;cue id 屬 G-LM-8 freeze 表)。
	if _audio != null and _audio.has_method("play_sfx"):
		_audio.play_sfx(&"loot_toast_tick")


func _toast_tick(delta: float) -> void:
	if not _toast_active:
		return
	var d_ms: float = delta * 1000.0
	_toast_age_ms += d_ms
	_toast_phase_ms += d_ms
	# Instance hard cap — fade NOW regardless of phase (carryover reopens).
	if _toast_phase != "fade" and _toast_age_ms >= _timing_config.toast_max_lifetime_sec * 1000.0:
		_toast_phase = "fade"
		_toast_phase_ms = 0.0
	match _toast_phase:
		"entry":
			if _toast_phase_ms >= _timing_config.toast_entry_sec * 1000.0:
				_toast_phase = "plateau"
				_toast_phase_ms = 0.0
		"plateau":
			_toast_plateau_remaining_ms -= d_ms
			if _toast_plateau_remaining_ms <= 0.0:
				_toast_phase = "fade"
				_toast_phase_ms = 0.0
		"fade":
			if _toast_phase_ms >= _timing_config.toast_fade_sec * 1000.0:
				_close_toast()


func _close_toast() -> void:
	_displayed_acks_total += _toast_n
	_toast_active = false
	if _toast_node != null:
		_toast_node.queue_free()
		_toast_node = null
	if not _carryover_acks.is_empty():
		var next: Array = _carryover_acks
		_carryover_acks = []
		_open_toast(next)


## EC-M17 — modal opening over a visible toast: interrupt fade (0.1s class —
## instant fold here, the visual fade is skin) and the count folds back into
## the deferred bucket. The count NEVER evaporates.
func _interrupt_toast_for_modal() -> void:
	if not _toast_active:
		return
	_total_acks -= _toast_n  # fold-back re-enters via _enqueue-shape entry below
	_deferred_acks.append({"tier": _toast_tier, "reason": "interrupted", "n": _toast_n})
	_total_acks += _toast_n
	_toast_active = false
	if _toast_node != null:
		_toast_node.queue_free()
		_toast_node = null
	for a: Dictionary in _carryover_acks:
		_deferred_acks.append(a)
	_carryover_acks = []


func _consume_id(drop_id: String) -> void:
	if drop_id != "" and drop_id not in _rolled_ids:
		_rolled_ids.append(drop_id)  # pull-model exclusion (shared list)


## Rule 11 — rollback paths (story 012). #15 owns its queue on rollback;
## #21 NEVER emits modal_dismissed here (it would double-advance).
func _on_loot_rollback(drop_id: String) -> void:
	_rolled_ids.append(drop_id)
	if _state == ModalState.CATCHUP_STREAM:
		# EC-M16 — displayed-but-uncommitted beat: cancel, skip, aggregate −1,
		# NEVER enters the batch; undisplayed: silently drops from the stream.
		for i: int in range(_catchup_stream_displayed.size()):
			if _drop_id_of(_catchup_stream_displayed[i]) == drop_id:
				_catchup_stream_displayed.remove_at(i)
				return
		for i: int in range(_catchup_stream.size()):
			if _drop_id_of(_catchup_stream[i]) == drop_id:
				_catchup_stream.remove_at(i)
				if i < _catchup_stream_index:
					_catchup_stream_index -= 1
				return
		return  # already committed (post stream-end) → #15/#17 post-grant path
	var is_current: bool = _drop_id_of(_current_drop) == drop_id and _state != ModalState.HIDDEN
	if not is_current:
		return  # AC-31 queued rollback — pull model, zero action
	match _state:
		ModalState.ENTRY, ModalState.CEREMONY:
			_rollback_cancel_and_requery()
		ModalState.STEADY:
			# Post-banking — display no-op (show-then-revoke is forbidden;
			# the revoke belongs to the #15/#17 post-grant reconciliation).
			_emit_telemetry("loot_reveal.late_rollback", {"drop_id": drop_id})
		_:
			pass  # EXITING — already dismissed/banked; post-grant class


## Pre-S3 rollback: ≤1 frame cancel (0-frame snap is rollback-exclusive),
## timescale restored via the INV-M1 exit, zero terminal frame, zero toast,
## zero emit — then RE-QUERY (Rule 11 Pass 1 fix: without it GSM stalls
## forever — Rule 13 is entry-time only, an empty queue has no terminal emitter).
func _rollback_cancel_and_requery() -> void:
	_release_freeze()
	_fast_complete_active = false
	if _in_catchup:
		# Re-query targets the ALREADY-SELECTED ceremonies remainder (K-cap
		# never re-picks — 防 cancel 觸發超 cap 補位); cleared → CATCHUP_GRID
		# (grid is this session's commit summary — it still shows).
		if not _catchup_ceremonies.is_empty():
			if _state == ModalState.CEREMONY:
				_transition(ModalState.ENTRY)
			_in_gap = true
			_gap_clock_ms = 0.0
			_gap_target_ms = LootRevealFormulas.successor_gap_sec(_timing_config, _current_tier) * 1000.0
		else:
			_enter_catchup_grid()
		return
	if _queue_depth() > 0:
		# Gap then next ENTRY (table self-edge ENTRY→ENTRY / CEREMONY→ENTRY).
		if _state == ModalState.CEREMONY:
			_transition(ModalState.ENTRY)
		_rollback_gap_pending = true
		_in_gap = true
		_gap_clock_ms = 0.0
		_gap_target_ms = LootRevealFormulas.successor_gap_sec(_timing_config, _current_tier) * 1000.0
	else:
		modal_dismissed.emit("", true)  # terminal — GSM 唔 stuck
		_transition(ModalState.HIDDEN)


## AC-77 — fires at S3 entry exactly once (fast-complete converges on the
## same edge). Intra-queue chains use the short variant from the second item
## (assertive announcements preempt each other — a full read never finishes);
## catch-up streams announce NOTHING per beat, the grid aggregates once.
func _announce_reveal() -> void:
	if _announced_current:
		return
	_announced_current = true
	if _state == ModalState.STEADY and _in_catchup:
		pass  # catch-up ceremonies still announce — they are full ceremonies
	_reveals_this_run += 1
	if _platform == null or not _platform.has_method("announce_aria"):
		return
	var tier_name: String = String(LootEnums.RarityTier.find_key(_current_tier))
	var item_name: String = str(_content_slots.get("item_name", ""))
	if _reveals_this_run > 1:
		_platform.announce_aria("%s:%s" % [tier_name, item_name])  # short variant
		return
	var text: String = "%s loot: %s,來自 %s." % [
		tier_name, item_name, str(_content_slots.get("source_attribution", ""))]
	var bd = _content_slots.get("breakdown_bar")
	if bd is Dictionary:
		text += " Workout %d%%, RNG %d%%" % [int(bd["pct_w"]), int(bd["pct_r"])]
	_platform.announce_aria(text)


func _announce_catchup_grid(total: int, max_tier: int) -> void:
	if _platform == null or not _platform.has_method("announce_aria"):
		return
	_platform.announce_aria("%d 件 loot 已收,最高 %s" % [
		total, String(LootEnums.RarityTier.find_key(max_tier))])


func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data})


func get_telemetry() -> Array[Dictionary]:
	return _telemetry_log


func _process(delta: float) -> void:
	if _suspended_mid_reveal:
		return  # EC-M1 park — bfcache renders zero frames; the clock must not drift
	_toast_tick(delta)
	_flush_tick(delta)
	if _state == ModalState.STEADY:
		_since_s3_ms += delta * 1000.0  # debounce window only — reveal clock parks
		return
	if _state == ModalState.CATCHUP_STREAM:
		_stream_tick(delta)
		return
	if _state == ModalState.EXITING:
		if _in_gap:
			_gap_clock_ms += delta * 1000.0
			if _gap_clock_ms >= _gap_target_ms:
				_end_gap()
		else:
			_exit_clock_ms += delta * 1000.0
			var anim_sec: float = _timing_config.stash_collapse_sec if _stash_mode else _timing_config.exit_anim_sec
			if _exit_clock_ms >= anim_sec * 1000.0:
				if _stash_mode or _force_closed_mid_exit:
					_finish_exit_closed()
				else:
					_finish_exit()
		return
	if _state != ModalState.ENTRY and _state != ModalState.CEREMONY:
		return
	if _in_gap:
		# Rollback-cancel inter-reveal gap (clock parked — next T=0 is fresh).
		_gap_clock_ms += delta * 1000.0
		if _gap_clock_ms >= _gap_target_ms:
			_in_gap = false
			_rollback_gap_pending = false
			if _in_catchup:
				_begin_next_catchup_ceremony_or_grid()
				return
			var head = _peek_head_drop()
			if head != null:
				_begin_reveal(head)
			else:
				modal_dismissed.emit("", true)
				_transition(ModalState.HIDDEN)
		return
	_reveal_clock_ms += delta * 1000.0
	_advance_timeline()


## Timeline-driven stage progression (FSM state ≠ timeline stage — these
## edges fire off the global clock, never off additive per-stage timers).
func _advance_timeline() -> void:
	# EC-M2: a rejected freeze degrades this reveal to the motion-variant
	# timeline (no time-stop) — the reveal itself is the hard guarantee.
	var variant: bool = _motion_reduction or _freeze_rejected
	var t_block: int = LootRevealFormulas.t_block_ms(_timing_config, _current_tier, variant)
	if _state == ModalState.ENTRY and _reveal_clock_ms >= float(_timing_config.entry_ms[_current_tier]):
		_transition(ModalState.CEREMONY)
	if _state == ModalState.CEREMONY and not _freeze_issued and not _motion_reduction and not _freeze_rejected:
		var hold: float = float(_timing_config.hold_ms[_current_tier])
		if _current_tier == LootEnums.RarityTier.RARE and _reveal_clock_ms >= hold:
			# RARE: clock-anchored (pulse 0.3s finishes early; freeze still
			# anchors at the END of the hold window — F1).
			_issue_ceremony_freeze()
		elif _current_tier >= LootEnums.RarityTier.EPIC \
				and _reveal_clock_ms >= hold + float(_timing_config.focal_fallback_grace_ms):
			# F1 fallback: focal_completed never arrived (#7 bug) — freeze
			# anyway at T = D_hold + grace; the queue must never deadlock.
			_emit_telemetry("loot_reveal.focal_fallback", {"tier": _current_tier})
			_issue_ceremony_freeze()
	# F5: fast-complete S3 target = min(t_tap + SNAP, T_block) — D5 clamp.
	# Same-frame race (snap target == natural T_block) resolves here in one
	# pass: the FIRST satisfied condition transitions, S3 side effects fire
	# exactly once (natural supersede is byte-identical — same edge).
	var effective_block: float = float(t_block)
	if _fast_complete_active:
		effective_block = minf(_s3_entry_target_ms, float(t_block))
	if _state == ModalState.CEREMONY and _reveal_clock_ms >= effective_block:
		_transition(ModalState.STEADY)


func is_modal_active() -> bool:
	return _state != ModalState.HIDDEN


func get_fsm_state() -> int:
	return _state


func is_in_catchup() -> bool:
	return _in_catchup


func get_reveal_clock_ms() -> float:
	return _reveal_clock_ms


func get_modal_layer() -> CanvasLayer:
	return _modal_layer


func get_celebration_vfx_layer() -> CanvasLayer:
	return _celebration_vfx_layer
