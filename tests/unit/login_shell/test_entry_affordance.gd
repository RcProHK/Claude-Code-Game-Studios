extends GutTest
## Story 013 — entry affordance three-state. Covers AC-39 (enabled a=1.0 / interactive-
## dimmed a=0.55 / hidden), Rule 10 (NO greyed disabled full-feature surface).
##
## GDD: Rule 10. Entry cards render only in steady shell states; alpha encodes
## enabled vs the rare can_open()==false race (still tappable → inline reason).

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const FADE: float = CoordinatorScript.SHELL_FADE_MS

const G_IDLE := GSMScript.GameState.IDLE
const G_DISCONNECTED := GSMScript.GameState.DISCONNECTED
const G_WORKOUT := GSMScript.GameState.WORKOUT_ACTIVE


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	var initial_fire_on_connect: bool = true
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		if initial_fire_on_connect:
			callable.call(current_state, current_state, null)


class MockScreen:
	extends Node
	var can_open_value: bool = true
	func can_open() -> bool: return can_open_value


var _cs: MockScreen
var _inv: MockScreen


func _make(gsm_state: int) -> Node:
	var gsm := MockGsm.new()
	gsm.current_state = gsm_state
	_cs = MockScreen.new()
	_inv = MockScreen.new()
	add_child_autofree(gsm)
	add_child_autofree(_cs)
	add_child_autofree(_inv)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._character_screen = _cs
	c._inventory_ui = _inv
	add_child_autofree(c)
	for _i in range(8):
		c.advance(FADE)
	return c


# --- AC-39: enabled (1.0) in DISCONNECTED_SHELL, not greyed ---

func test_ac39_disconnected_shell_entry_enabled() -> void:
	var c := _make(G_DISCONNECTED)
	assert_true(c.is_entry_visible(), "AC-39: entry visible in DISCONNECTED_SHELL")
	assert_eq(c.get_entry_card_alpha(&"character_screen"), 1.0, "AC-39: #22 card enabled (a=1.0, not greyed)")
	assert_eq(c.get_entry_card_alpha(&"inventory"), 1.0, "AC-39: #23 card enabled (a=1.0)")


func test_ac39_shell_idle_entry_enabled() -> void:
	var c := _make(G_IDLE)
	assert_true(c.is_entry_visible(), "entry visible in SHELL_IDLE")
	assert_eq(c.get_entry_card_alpha(&"inventory"), 1.0, "enabled in SHELL_IDLE")


# --- AC-39 race branch: can_open()==false → interactive-dimmed (0.55), still tappable ---

func test_ac39_can_open_false_race_is_interactive_dimmed() -> void:
	var c := _make(G_IDLE)
	_inv.can_open_value = false  # rare race
	assert_eq(c.get_entry_card_alpha(&"inventory"), 0.55, "AC-39: can_open false → 0.55 interactive-dimmed (NOT greyed)")
	# The other card is unaffected.
	assert_eq(c.get_entry_card_alpha(&"character_screen"), 1.0, "the can_open()==true card stays enabled")


# --- AC-39: workout-family hides entries entirely (no greyed surface) ---

func test_ac39_workout_state_hides_entry() -> void:
	var c := _make(G_WORKOUT)
	assert_false(c.is_entry_visible(), "AC-39: entry hidden in workout (not rendered, never greyed)")
