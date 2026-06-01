# ScreenEffects — Story 008 AC-22: persistence ban + boot defaults + connect-once.
#
# ScreenEffects is pure runtime effect infrastructure (Rule 16): no PersistenceLayer reference,
# no save_/load_ methods, no user:// paths; boot defaults are constant. GSM subscription uses
# connect_for_initial_state exactly once (ADR-0006 Contract 6).
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")
const REAL_SOURCE: String = "res://src/autoload/screen_effects.gd"


## Stub GSM that only counts connect_for_initial_state calls.
class _StubGSM:
	extends RefCounted
	var connect_count: int = 0
	func connect_for_initial_state(_cb: Callable) -> void:
		connect_count += 1


func _read_source() -> String:
	var f := FileAccess.open(ProjectSettings.globalize_path(REAL_SOURCE), FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


# ---------------------------------------------------------------------------
# AC-22 — boot defaults
# ---------------------------------------------------------------------------

func test_boot_defaults_are_constant() -> void:
	var sut = SE.new()
	add_child_autofree(sut)
	await get_tree().process_frame
	assert_eq(sut._trauma, 0.0, "AC-22: trauma boots at 0")
	assert_almost_eq(sut._motion_intensity, 1.0, 0.0001, "AC-22: motion_intensity defaults to 1.0 (EC-15)")
	assert_eq(sut._pause_remaining_sec, 0.0, "AC-22: pause boots at 0")


# ---------------------------------------------------------------------------
# AC-22 — persistence ban (static scan)
# ---------------------------------------------------------------------------

func test_no_persistence_layer_reference() -> void:
	assert_false("PersistenceLayer" in _read_source(), "AC-22: ScreenEffects must not reference PersistenceLayer")


func test_no_save_or_load_methods() -> void:
	var re := RegEx.new()
	re.compile("func\\s+(save|load)_")
	assert_null(re.search(_read_source()), "AC-22: no save_*/load_* methods (Rule 16)")


func test_no_user_path() -> void:
	assert_false("user://" in _read_source(), "AC-22: no user:// path in ScreenEffects")


# ---------------------------------------------------------------------------
# Boot — connect_for_initial_state exactly once
# ---------------------------------------------------------------------------

func test_connect_for_initial_state_called_once() -> void:
	var sut = SE.new()
	var stub := _StubGSM.new()
	sut._gsm = stub  # inject before add_child so _ready uses the stub
	add_child_autofree(sut)
	await get_tree().process_frame
	assert_eq(stub.connect_count, 1, "Boot: connect_for_initial_state called exactly once (ADR-0006 C6)")
