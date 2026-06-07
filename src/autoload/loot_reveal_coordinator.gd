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
var _gsm            ## seam 1: #1 GameStateMachine (default /root/GameStateMachine)
var _loot_system    ## seam 2: #15 LootDropSystem (default /root/LootDropSystem)

## seam 3: F1 per-tier timeline data (default = class defaults — GDD table).
var _timing_config: LootRevealTimingConfig = null

## seam 4: accessibility — motion_reduction matrix input (EC-M4). Settings
## propagation wiring lands with the a11y stories; tests drive it directly.
var _motion_reduction: bool = false

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


func _ready() -> void:
	# G-LM-9 (#4 story 023 asserts via AC-76b): coordinator must keep
	# processing while ceremony_freeze pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instantiate_layers()
	if _timing_config == null:
		_timing_config = LootRevealTimingConfig.new()
	var config_errors: Array[String] = _timing_config.validate()
	_config_valid = config_errors.is_empty()
	for e: String in config_errors:
		push_error("LootRevealCoordinator: timing config invalid — %s" % e)
	if _gsm == null:
		_gsm = get_node_or_null("/root/GameStateMachine")
	if _loot_system == null:
		_loot_system = get_node_or_null("/root/LootDropSystem")
	if _loot_system != null and _loot_system.has_signal("loot_dropped"):
		_loot_system.loot_dropped.connect(_on_loot_dropped)
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		# ADR-0006 C6 — covers the boot force-reveal case where GSM is
		# already in LOOT_DROP before #21 (tail autoload) reaches _ready.
		_gsm.connect_for_initial_state(_on_state_changed)


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
	return true


## Rule 2 — GSM owns "when": → LOOT_DROP is the ONLY open trigger.
func _on_state_changed(_from_state, to_state, _payload) -> void:
	if int(to_state) != GSMScript.GameState.LOOT_DROP:
		return
	if _state != ModalState.HIDDEN:
		return  # Rule 6 one-modal-at-a-time (re-entry guarded)
	if _queue_depth() > 0:
		_open_reveal_flow()
	# depth == 0 → Rule 13 empty-queue terminal emit (story 010 — AC-34).
	# depth ≥ CATCH_UP_THRESHOLD → CATCHUP_PROMPT branch (story 014 — AC-26).


## Rule 2 — doorbell/prep semantics ONLY. NOT an "open modal now" command:
## mid-set deferral is GSM Rule 13's job; #21 never builds its own wait queue.
func _on_loot_dropped(_drop_id: String, _rarity_tier: String, _item_type: String, _transition_id: String) -> void:
	if _state != ModalState.HIDDEN:
		return  # AC-7: no second modal, no FSM re-entry
	if _gsm == null or not _gsm.has_method("get_current_state"):
		return
	if int(_gsm.get_current_state()) != GSMScript.GameState.LOOT_DROP:
		return  # deferral is GSM-owned; item stays in the #15 queue
	if _queue_depth() > 0:
		_open_reveal_flow()


func _queue_depth() -> int:
	if _loot_system == null or not _loot_system.has_method("get_pending_drops"):
		return 0
	var pending: Array = _loot_system.get_pending_drops()
	return pending.size()


## Opens the sequential reveal flow (HIDDEN → ENTRY edge).
func _open_reveal_flow() -> void:
	if not _config_valid:
		push_error("LootRevealCoordinator: reveal refused — timing config failed data-load assert (F1: no clamp)")
		return
	if not _transition(ModalState.ENTRY):
		return
	# TODO story 010: pull the head record via get_drop() and read its tier
	# (committed store is the content source — AC-32). COMMON until then.
	_begin_reveal(_current_tier)
	_modal_layer.visible = true
	_celebration_vfx_layer.visible = true


## Anchors T=0 for this drop's choreography (F1 unified timing model).
func _begin_reveal(tier: int) -> void:
	_current_tier = tier
	_reveal_clock_ms = 0.0


func _process(delta: float) -> void:
	if _state != ModalState.ENTRY and _state != ModalState.CEREMONY:
		return
	_reveal_clock_ms += delta * 1000.0
	_advance_timeline()


## Timeline-driven stage progression (FSM state ≠ timeline stage — these
## edges fire off the global clock, never off additive per-stage timers).
func _advance_timeline() -> void:
	var t_block: int = LootRevealFormulas.t_block_ms(_timing_config, _current_tier, _motion_reduction)
	if _state == ModalState.ENTRY and _reveal_clock_ms >= float(_timing_config.entry_ms[_current_tier]):
		_transition(ModalState.CEREMONY)
	if _state == ModalState.CEREMONY and _reveal_clock_ms >= float(t_block):
		_transition(ModalState.STEADY)
		# S3 entry side effects (receive_loot INV-M3 / SR announce) — stories 009/025.


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
