extends GutTest
## Story 002 — coordinator autoload skeleton + layers + GSM trigger wiring.
## Covers AC-4 / AC-5 / AC-6 / AC-7 (AC-79 is the CI lint
## tools/ci/check_loot_reveal_boot_order.gd, not a GUT test).
##
## GDD: design/gdd/loot-drop-modal.md Rule 1 / Rule 2.
## ADR-0001 #21 revision pins layer numbers 110/120, ALWAYS, follow_viewport=false.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")

const LOOT_DROP: int = GSMScript.GameState.LOOT_DROP
const IDLE: int = GSMScript.GameState.IDLE
const REST_PERIOD: int = GSMScript.GameState.REST_PERIOD


class MockGsm:
	extends Node
	## Untyped mirror of GSM state_changed — coordinator handler is untyped
	## (project DI discipline), so int states + null payload deliver fine.
	signal state_changed(from_state, to_state, payload)

	var current_state: int = 2  # IDLE
	var initial_fire_on_connect: bool = false

	func get_current_state() -> int:
		return current_state

	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		if initial_fire_on_connect:
			# C6 sentinel shape: from == to == current_state.
			callable.call(current_state, current_state, null)

	func emit_transition(to_state: int) -> void:
		var from_state: int = current_state
		current_state = to_state
		state_changed.emit(from_state, to_state, null)


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)

	var pending: Array = []

	func get_pending_drops() -> Array:
		return pending

	func fire_loot_dropped(drop_id: String) -> void:
		loot_dropped.emit(drop_id, "COMMON", "weapon", "t_1")


var _gsm: MockGsm
var _loot: MockLootSystem


func _make_coordinator() -> Node:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	add_child_autofree(_gsm)
	add_child_autofree(_loot)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	add_child_autofree(c)  # triggers _ready
	return c


# --- AC-4: layers held, sole instantiator, pinned numbers, pre-warmed hidden ---

func test_ready_instantiates_both_layers_with_adr0001_pinned_values() -> void:
	var c: Node = _make_coordinator()
	var modal: CanvasLayer = c.get_modal_layer()
	var vfx: CanvasLayer = c.get_celebration_vfx_layer()
	assert_not_null(modal, "ModalLayer must exist after _ready")
	assert_not_null(vfx, "CelebrationVFXLayer must exist after _ready")
	assert_eq(modal.layer, 120, "ModalLayer == ADR-0001 pinned 120")
	assert_eq(vfx.layer, 110, "CelebrationVFXLayer == ADR-0001 pinned 110")
	assert_eq(modal.process_mode, Node.PROCESS_MODE_ALWAYS, "ModalLayer ALWAYS")
	assert_eq(vfx.process_mode, Node.PROCESS_MODE_ALWAYS, "CelebrationVFXLayer ALWAYS")
	assert_false(modal.follow_viewport_enabled, "screen-space layer — no follow (ADR-0001 viewport residence)")
	assert_false(vfx.follow_viewport_enabled, "screen-space layer — no follow")
	assert_false(modal.visible, "pre-warmed hidden (HIDDEN state)")
	assert_false(vfx.visible, "pre-warmed hidden")


func test_coordinator_is_sole_instantiator_layers_are_its_children() -> void:
	var c: Node = _make_coordinator()
	assert_eq(c.get_modal_layer().get_parent(), c, "ModalLayer parented to coordinator")
	assert_eq(c.get_celebration_vfx_layer().get_parent(), c, "CelebrationVFXLayer parented to coordinator")
	var bands: Array = []
	for child in c.get_children():
		if child is CanvasLayer:
			bands.append((child as CanvasLayer).layer)
	bands.sort()
	assert_eq(bands, [110, 120], "exactly the two >100-band layers, no extras")


# --- AC-5: → LOOT_DROP with non-empty queue opens; everything else doesn't ---

func test_transition_to_loot_drop_with_pending_opens_modal() -> void:
	var c: Node = _make_coordinator()
	_loot.pending = ["drop_a"]
	_gsm.emit_transition(LOOT_DROP)
	assert_true(c.is_modal_active(), "→ LOOT_DROP + queue non-empty opens reveal flow")
	assert_true(c.get_modal_layer().visible, "modal layer visible when active")


func test_other_state_transitions_do_not_open_modal() -> void:
	var c: Node = _make_coordinator()
	_loot.pending = ["drop_a"]
	_gsm.emit_transition(REST_PERIOD)
	_gsm.emit_transition(IDLE)
	assert_false(c.is_modal_active(), "non-LOOT_DROP transitions never open the modal")


func test_loot_dropped_alone_outside_loot_drop_state_is_deferred() -> void:
	var c: Node = _make_coordinator()
	_loot.pending = ["drop_a"]
	_gsm.current_state = IDLE
	_loot.fire_loot_dropped("drop_a")
	assert_false(c.is_modal_active(), "doorbell outside LOOT_DROP → no-op (GSM owns deferral)")


func test_loot_dropped_while_in_loot_drop_state_drains_head() -> void:
	var c: Node = _make_coordinator()
	_gsm.current_state = LOOT_DROP
	_loot.pending = ["drop_a"]
	_loot.fire_loot_dropped("drop_a")
	assert_true(c.is_modal_active(), "doorbell while GSM==LOOT_DROP and modal idle → drain head")


# --- AC-6: boot when GSM already in LOOT_DROP (C6 sentinel) ---

func test_boot_with_gsm_already_in_loot_drop_opens_via_initial_state_sentinel() -> void:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_gsm.current_state = LOOT_DROP
	_gsm.initial_fire_on_connect = true  # C6: fire on connect when already in state
	_loot.pending = ["drop_boot"]
	add_child_autofree(_gsm)
	add_child_autofree(_loot)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	add_child_autofree(c)
	assert_true(c.is_modal_active(), "boot force-reveal: sentinel delivery opens the modal")


# --- AC-7: doorbell no-op while active (one-modal-at-a-time) ---

func test_new_loot_dropped_while_active_is_noop() -> void:
	var c: Node = _make_coordinator()
	_gsm.current_state = LOOT_DROP
	_loot.pending = ["drop_a"]
	_loot.fire_loot_dropped("drop_a")
	assert_true(c.is_modal_active())
	var modal_before: CanvasLayer = c.get_modal_layer()
	_loot.pending = ["drop_a", "drop_b"]
	_loot.fire_loot_dropped("drop_b")
	assert_true(c.is_modal_active(), "still the same single active flow")
	assert_eq(c.get_modal_layer(), modal_before, "no second modal instantiated")
	var bands: int = 0
	for child in c.get_children():
		if child is CanvasLayer:
			bands += 1
	assert_eq(bands, 2, "layer count unchanged — no FSM re-entry side effects")


func test_repeat_loot_drop_transition_while_active_is_guarded() -> void:
	var c: Node = _make_coordinator()
	_loot.pending = ["drop_a"]
	_gsm.emit_transition(LOOT_DROP)
	assert_true(c.is_modal_active())
	_gsm.emit_transition(LOOT_DROP)  # defensive re-entry
	assert_true(c.is_modal_active(), "re-entry guarded — no double-open")
