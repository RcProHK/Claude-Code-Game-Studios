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

## AC-22 — AMENDED by #22 G-CS-4 (story 011, 2026-06-07): the blanket
## "no PersistenceLayer reference" ban predates the consumer-self-read
## convention (#22 GDD Rule 29 — 無 SettingsManager autoload;#7 G-CS-2 同款
## erratum)。Ban 本意保留:#6 永不 WRITE persistence / own save state。
## 唯一允許 touchpoint = read-only boot seam(_boot_read_motion_intensity,
## G-CS-4a)。Scoped line-scan + write ban(gateway-lint owner-exempt 先例 —
## main-CI debug-override lesson)。
func test_persistence_touchpoint_is_readonly_boot_seam_only() -> void:
	var src := _read_source()
	assert_false("_persistence.write" in src, "AC-22 本意:零 persistence write")
	assert_false("PersistenceLayer.write" in src, "AC-22 本意:零 persistence write(autoload 直呼)")
	var allowed_markers: Array[String] = ["G-CS-4", "read", "seam", "/root/PersistenceLayer"]
	for line in src.split("\n"):
		if not ("PersistenceLayer" in line):
			continue
		var ok := false
		for m in allowed_markers:
			if m in line:
				ok = true
				break
		assert_true(ok,
			"AC-22(G-CS-4 amended): PersistenceLayer 只准出現喺 read-only boot seam 行: "
			+ line.strip_edges())


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
