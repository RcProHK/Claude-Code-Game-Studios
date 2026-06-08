extends GutTest
## Story 005 — Boot-Window Signal Sweep. Covers AC-53 (auth pull → LOGIN), AC-28
## (pending-errors pull → ONGOING banner), and the EC-E6 contract (#8/#11/#12 never
## sync-emit at boot).
##
## GDD: Rule 2 boot-race + Boot-Window Signal Sweep table. A tail autoload (#24) misses
## any signal a producer sync-emitted in its own _ready before #24 connected → the two
## critical signals are PULLED, not awaited. is_auth_required / get_pending_errors are
## #2/#3 additive getters (not yet shipped — G-LS-4(c)/G-LS-8) → mock-scoped here.

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")
const S_LOGIN := CoordinatorScript.ShellState.LOGIN


## GSM mock that does NOT fire the cfis sentinel — simulating the boot-race where the
## shell reaches _ready before GSM (or #2) ever delivers. The pull-check must still work.
class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 0  # BOOTING
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)  # no sentinel fire


## Mock #2 with the G-LS-4(c) additive getter is_auth_required() — but NO auth_required
## signal (proves the shell enters LOGIN by PULL, not by catching a signal).
class MockClient:
	extends Node
	var auth_required_value: bool = false
	func is_auth_required() -> bool:
		return auth_required_value


## Mock #3 with the G-LS-8 additive getter get_pending_errors() — but NO
## critical_save_failed signal fired (the backlog is pulled, not awaited).
class MockPersistence:
	extends Node
	var pending: Array = []
	func get_pending_errors() -> Array:
		return pending


func _make(auth: bool, pending: Array) -> Node:
	var gsm := MockGsm.new()
	var client := MockClient.new()
	var persistence := MockPersistence.new()
	client.auth_required_value = auth
	persistence.pending = pending
	add_child_autofree(gsm)
	add_child_autofree(client)
	add_child_autofree(persistence)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._client = client
	c._persistence = persistence
	add_child_autofree(c)  # _ready runs the boot pull-check sweep
	return c


# --- AC-53 [G-LS-4]: auth_required boot-race closed by pull-check ---

func test_ac53_is_auth_required_pull_enters_login_by_end_of_ready() -> void:
	# No auth_required signal, no GSM sentinel — pure pull.
	var c: Node = _make(true, [])
	assert_eq(c.get_state(), S_LOGIN, "AC-53: shell is LOGIN by end of _ready (pull, not signal)")
	assert_true(c.get_shell_layer().visible, "AC-53: LoginShellLayer.visible == true")


func test_ac53_no_auth_required_stays_out_of_login() -> void:
	var c: Node = _make(false, [])
	assert_ne(c.get_state(), S_LOGIN, "is_auth_required()==false → not forced into LOGIN")


# --- AC-28 [G-LS-8]: pending-error backlog pulled into the BannerStack ---

func test_ac28_pending_errors_pull_enqueues_ongoing_banner() -> void:
	var c: Node = _make(false, ["QUOTA_EXHAUSTED"])
	var stack = c.get_banner_stack()
	assert_eq(stack.count(), 1, "AC-28: pending error pulled into the stack (+1)")
	assert_eq(stack.main_slot()["severity"], ESM.Severity.ONGOING, "QUOTA_EXHAUSTED → ONGOING")
	assert_false(ESM.is_dismissable(ESM.Severity.ONGOING), "ONGOING dismissable=false")
	assert_true(c.get_banner_layer().visible, "ErrorBannerLayer surfaced for the pulled backlog")


func test_ac28_empty_pending_zero_banners() -> void:
	var c: Node = _make(false, [])
	assert_eq(c.get_banner_stack().count(), 0, "empty get_pending_errors() → zero banners")


func test_ac28_multiple_pending_codes_each_enqueue() -> void:
	var c: Node = _make(false, ["QUOTA_EXHAUSTED", "READ_ONLY_FILESYSTEM"])
	assert_eq(c.get_banner_stack().count(), 2, "each pending code → its own banner")


# --- EC-E6 contract: #8/#11/#12 must NOT sync-emit their *_save_failed in _ready ---

func test_ec_e6_upstream_systems_do_not_sync_emit_in_ready() -> void:
	# The boot-window sweep deliberately does NOT pull #8/#11/#12 — it relies on this
	# contract. If a future change makes one boot-emit, it must adopt the #3 deferred
	# pattern (and the sweep must add a pull). Source-level assertion.
	var cases := {
		"res://src/autoload/streak_system.gd": "streak_persistence_failed.emit",
		"res://src/autoload/stat_system.gd": "stat_critical_save_failed.emit",
		"res://src/autoload/ability_system.gd": "ability_unlock_save_failed.emit",
	}
	for path: String in cases:
		assert_false(
			_ready_body_contains(path, cases[path]),
			"EC-E6: %s must not %s inside _ready()" % [path, cases[path]])


## Read a .gd file and check whether the given token appears inside the _ready() body
## (from `func _ready(` to the next top-level `func `).
func _ready_body_contains(path: String, token: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "can read %s" % path)
	if f == null:
		return false
	var in_ready := false
	var found := false
	while not f.eof_reached():
		var line := f.get_line()
		var stripped := line.strip_edges()
		if stripped.begins_with("func _ready("):
			in_ready = true
			continue
		if in_ready and stripped.begins_with("func "):
			break  # left the _ready body
		if in_ready and not stripped.begins_with("#") and token in line:
			found = true
			break
	f.close()
	return found
