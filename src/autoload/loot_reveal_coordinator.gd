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

# --- DI seams (untyped — project DI discipline) ---
var _gsm            ## seam 1: #1 GameStateMachine (default /root/GameStateMachine)
var _loot_system    ## seam 2: #15 LootDropSystem (default /root/LootDropSystem)

## Single-owner CanvasLayers (Rule 1: coordinator is the only instantiator
## of the >100 band — ADR-0001 #21 revision).
var _modal_layer: CanvasLayer = null
var _celebration_vfx_layer: CanvasLayer = null

## One-modal-at-a-time guard (Rule 6). Reveal flow active ⇒ doorbell no-ops.
var _active: bool = false


func _ready() -> void:
	# G-LM-9 (#4 story 023 asserts via AC-76b): coordinator must keep
	# processing while ceremony_freeze pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instantiate_layers()
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


## Rule 2 — GSM owns "when": → LOOT_DROP is the ONLY open trigger.
func _on_state_changed(_from_state, to_state, _payload) -> void:
	if int(to_state) != GSMScript.GameState.LOOT_DROP:
		return
	if _active:
		return  # Rule 6 one-modal-at-a-time (re-entry guarded)
	if _queue_depth() > 0:
		_open_reveal_flow()
	# depth == 0 → Rule 13 empty-queue terminal emit (story 010 — AC-34).


## Rule 2 — doorbell/prep semantics ONLY. NOT an "open modal now" command:
## mid-set deferral is GSM Rule 13's job; #21 never builds its own wait queue.
func _on_loot_dropped(_drop_id: String, _rarity_tier: String, _item_type: String, _transition_id: String) -> void:
	if _active:
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


## Skeleton open (story 003 replaces this with the 8-state FSM ENTRY edge).
func _open_reveal_flow() -> void:
	_active = true
	_modal_layer.visible = true
	_celebration_vfx_layer.visible = true


func is_modal_active() -> bool:
	return _active


func get_modal_layer() -> CanvasLayer:
	return _modal_layer


func get_celebration_vfx_layer() -> CanvasLayer:
	return _celebration_vfx_layer
