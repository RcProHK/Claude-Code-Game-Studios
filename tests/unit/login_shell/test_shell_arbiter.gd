extends GutTest
## Story 013 — central mutual-exclusion arbiter. Covers AC-40 (request_open: close →
## deferred open, can_open double-guard, last-wins latch, no force + log on false).
##
## GDD: Rule 11. #24 actively calls #22/#23 behind has_method guards (never subscribes
## their state); the open is deferred (call_deferred) and last-wins.

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


class MockScreen:
	extends Node
	var can_open_value: bool = true
	var open_calls: int = 0
	var close_calls: int = 0
	func can_open() -> bool: return can_open_value
	func open() -> void: open_calls += 1
	func close() -> void: close_calls += 1


var _cs: MockScreen
var _inv: MockScreen


func _make() -> Node:
	var gsm := MockGsm.new()
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
	return c


# --- AC-40: close → deferred open, can_open queried ---

func test_ac40_request_open_closes_then_opens_target() -> void:
	var c := _make()
	c.request_open(&"inventory")
	# Close is immediate (best-effort on both screens); open is deferred.
	assert_eq(_cs.close_calls, 1, "current screen closed (best-effort)")
	assert_eq(_inv.open_calls, 0, "open deferred — not yet")
	await get_tree().process_frame
	assert_eq(_inv.open_calls, 1, "AC-40: target opened after deferral")


func test_ac40_can_open_false_does_not_force_open() -> void:
	var c := _make()
	_inv.can_open_value = false  # rare race
	c.request_open(&"inventory")
	await get_tree().process_frame
	assert_eq(_inv.open_calls, 0, "AC-40: can_open()==false → NOT force-opened (EC-E4)")


func test_ac40_open_character_screen_target() -> void:
	var c := _make()
	c.request_open(&"character_screen")
	await get_tree().process_frame
	assert_eq(_cs.open_calls, 1, "character_screen target opens")
	assert_eq(_inv.open_calls, 0, "the other screen does not open")


# --- last-wins latch: rapid request_open does not double-open ---

func test_last_wins_latch_no_double_open() -> void:
	var c := _make()
	c.request_open(&"inventory")
	c.request_open(&"character_screen")  # overwrites before the deferred fires
	await get_tree().process_frame
	assert_eq(_cs.open_calls, 1, "last-wins: character_screen (the final target) opens")
	assert_eq(_inv.open_calls, 0, "the overwritten target does NOT open")


func test_unknown_target_is_noop() -> void:
	var c := _make()
	c.request_open(&"nonexistent")
	await get_tree().process_frame
	assert_eq(_cs.open_calls, 0, "unknown target → no open")
	assert_eq(_inv.open_calls, 0, "unknown target → no open")
