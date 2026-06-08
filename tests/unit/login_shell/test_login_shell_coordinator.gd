extends GutTest
## Story 003 — LoginShellCoordinator scaffold: 2 CanvasLayers + cfis GSM connect
## + zero-persist invariant + file-split topology. Covers AC-01 / AC-02 / AC-27.
##
## GDD: design/gdd/login-gymsys-connection-ui.md Rules 1/14 + AC-01/02/27.
## ADR-0001 #24 revision pins LoginShellLayer 62 (PAUSABLE) + ErrorBannerLayer 111
## (ALWAYS). ADR-0006 C6 = connect_for_initial_state. ADR-0008 G-LS-2 tail append.

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")

const SHELL_LAYER: int = 62
const BANNER_LAYER: int = 111

const BANNER_STACK_PATH: String = "res://src/ui/login_shell/banner_stack.gd"
const SHELL_TRANSITIONS_PATH: String = "res://src/ui/login_shell/shell_transitions.gd"


## Untyped GSM mirror (coordinator handler is untyped — project DI discipline).
## Records whether the boot connect used connect_for_initial_state (AC-27).
class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)

	var current_state: int = 2  # IDLE
	var cfis_called: bool = false
	var initial_fire_on_connect: bool = false

	func get_current_state() -> int:
		return current_state

	func connect_for_initial_state(callable: Callable) -> void:
		cfis_called = true
		state_changed.connect(callable)
		if initial_fire_on_connect:
			# C6 sentinel shape: from == to == current_state.
			callable.call(current_state, current_state, null)

	func emit_transition(to_state: int) -> void:
		var from_state: int = current_state
		current_state = to_state
		state_changed.emit(from_state, to_state, null)


## Persistence spy — fails the AC-02 zero-persist invariant if ANY write lands.
class MockPersistence:
	extends Node
	var write_calls: int = 0

	func write(_key: String, _value) -> void:
		write_calls += 1

	func read(_key: String, default_value = null):
		return default_value


var _gsm: MockGsm
var _persistence: MockPersistence


func _make_coordinator(fire_sentinel: bool = false) -> Node:
	_gsm = MockGsm.new()
	_persistence = MockPersistence.new()
	_gsm.initial_fire_on_connect = fire_sentinel
	add_child_autofree(_gsm)
	add_child_autofree(_persistence)
	var c: Node = CoordinatorScript.new()
	# Inject seams BEFORE add_child so _ready sees them non-null and skips the
	# /root lookup (reference_test_persistence_isolation: inject before add_child).
	c._gsm = _gsm
	c._persistence = _persistence
	add_child_autofree(c)  # triggers _ready
	return c


# --- AC-01: coordinator holds both layers, pinned values, pre-warmed hidden,
#            file-split helpers exist, zero second autoload ---

func test_ready_holds_both_layers_with_adr0001_pinned_values() -> void:
	# Arrange / Act
	var c: Node = _make_coordinator()
	# Assert
	var shell: CanvasLayer = c.get_shell_layer()
	var banner: CanvasLayer = c.get_banner_layer()
	assert_not_null(shell, "LoginShellLayer exists after _ready")
	assert_not_null(banner, "ErrorBannerLayer exists after _ready")
	assert_eq(shell.layer, SHELL_LAYER, "LoginShellLayer == ADR-0001 pinned 62")
	assert_eq(banner.layer, BANNER_LAYER, "ErrorBannerLayer == ADR-0001 pinned 111")
	assert_eq(shell.process_mode, Node.PROCESS_MODE_PAUSABLE, "LoginShellLayer PAUSABLE")
	assert_eq(banner.process_mode, Node.PROCESS_MODE_ALWAYS, "ErrorBannerLayer ALWAYS")
	assert_false(shell.visible, "LoginShellLayer pre-warmed hidden")
	assert_false(banner.visible, "ErrorBannerLayer pre-warmed hidden")


func test_file_split_helper_files_exist() -> void:
	# AC-35a grep-target prerequisite: a missing file ≠ no-match (a non-existent
	# path would be a phantom pass for the banner-static grep). Assert they exist.
	# FileAccess.file_exists on res:// is the proven pattern in this repo
	# (check_loot_reveal_boot_order.gd reads project.godot the same way).
	assert_true(
		FileAccess.file_exists(BANNER_STACK_PATH),
		"banner_stack.gd must exist as a separate file (AC-35a grep scope)")
	assert_true(
		FileAccess.file_exists(SHELL_TRANSITIONS_PATH),
		"shell_transitions.gd must exist as a separate file (AC-35a grep scope)")


func test_no_second_autoload_only_two_pinned_canvas_layers() -> void:
	# Arrange / Act
	var c: Node = _make_coordinator()
	# Assert — both layers parented to the coordinator (Rule 1, sole instantiator).
	assert_eq(c.get_shell_layer().get_parent(), c, "LoginShellLayer parented to coordinator")
	assert_eq(c.get_banner_layer().get_parent(), c, "ErrorBannerLayer parented to coordinator")
	# Exactly the two pinned CanvasLayers, no extras.
	var bands: Array = []
	for child in c.get_children():
		if child is CanvasLayer:
			bands.append((child as CanvasLayer).layer)
	bands.sort()
	assert_eq(bands, [SHELL_LAYER, BANNER_LAYER], "exactly the two #24 layers (62, 111), no extras")


func test_four_sub_controllers_present_not_autoloads() -> void:
	# Arrange / Act
	var c: Node = _make_coordinator()
	# Assert — LoginPanel / ConnectionStatus / ShellEntry under the shell layer;
	# BannerStack under the banner layer. All coordinator-owned, not autoloads.
	var shell: CanvasLayer = c.get_shell_layer()
	assert_not_null(shell.get_node_or_null("LoginPanel"), "LoginPanel sub-controller")
	assert_not_null(shell.get_node_or_null("ConnectionStatus"), "ConnectionStatus sub-controller")
	assert_not_null(shell.get_node_or_null("ShellEntry"), "ShellEntry sub-controller")
	assert_not_null(c.get_banner_layer().get_node_or_null("BannerStack"), "BannerStack sub-controller")


# --- AC-02: full claim success + logout cycle → zero #24 persist writes ---

func test_claim_logout_cycle_performs_zero_persist_writes() -> void:
	# Arrange
	var c: Node = _make_coordinator()
	assert_eq(_persistence.write_calls, 0, "boot writes nothing")
	# Act — full claim success + logout cycle.
	c.notify_claim_succeeded()
	c.request_logout()
	# Assert — #24 owns no persisted state; the only token write is #2's (mocked).
	assert_eq(
		_persistence.write_calls, 0,
		"claim+logout cycle touches PersistenceLayer zero times (AC-02; token write is #2's)")


# --- AC-27: _ready connects GSM via connect_for_initial_state (not plain) ---

func test_ready_connects_gsm_via_connect_for_initial_state() -> void:
	# Arrange / Act
	var c: Node = _make_coordinator()
	# Assert
	assert_not_null(c, "coordinator booted")
	assert_true(
		_gsm.cfis_called,
		"_ready used connect_for_initial_state (ADR-0006 C6 boot-surface), not plain connect")


func test_boot_receives_initial_state_via_cfis_sentinel() -> void:
	# Arrange — GSM already in DISCONNECTED at boot fires the C6 sentinel on connect.
	# Act
	var c: Node = _make_coordinator(true)  # fire_sentinel; default current_state IDLE
	# Assert — scaffold handler recorded the sentinel-delivered current state.
	assert_eq(
		c.get_gsm_state(), _gsm.current_state,
		"boot cfis sentinel delivered current GSM state to the scaffold handler (AC-27)")
