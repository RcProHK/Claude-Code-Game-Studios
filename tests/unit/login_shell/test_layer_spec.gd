extends GutTest
## Story 011 — two-layer independence. Covers AC-54 (EC-E3): ErrorBannerLayer (111
## ALWAYS) surfaces a banner over a paused WORKOUT_ACTIVE world while LoginShellLayer
## (62 PAUSABLE) stays hidden. (AC-35b/36 scene-tree static checks = story 016.)
##
## GDD: Rule 1 / EC-E3. The banner layer's visibility is driven solely by whether a
## banner exists — NOT by the shell FSM state.

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")

const FADE: float = CoordinatorScript.SHELL_FADE_MS
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


class MockPersistence:
	extends Node
	signal critical_save_failed(error_code: String, key: String)


var _gsm: MockGsm
var _persistence: MockPersistence


func _make(gsm_state: int) -> Node:
	_gsm = MockGsm.new()
	_persistence = MockPersistence.new()
	_gsm.current_state = gsm_state
	add_child_autofree(_gsm)
	add_child_autofree(_persistence)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._persistence = _persistence
	add_child_autofree(c)
	return c


func _settle(c: Node) -> void:
	for _i in range(8):
		c.advance(FADE)


func test_ac54_banner_surfaces_over_hidden_shell_in_workout() -> void:
	# Shell HIDDEN (GSM WORKOUT_ACTIVE).
	var c: Node = _make(G_WORKOUT)
	_settle(c)
	assert_false(c.get_shell_layer().visible, "LoginShellLayer hidden in workout (precondition)")
	assert_false(c.get_banner_layer().visible, "ErrorBannerLayer hidden — no banner yet")
	# #3 emits an ONGOING error mid-workout.
	_persistence.critical_save_failed.emit("READ_ONLY_FILESYSTEM", "k")
	# Two-layer independence: banner layer up, shell layer still hidden.
	assert_true(c.get_banner_layer().visible, "AC-54: ErrorBannerLayer.visible == true (banner over workout)")
	assert_false(c.get_shell_layer().visible, "AC-54: LoginShellLayer.visible == false (shell stays HIDDEN)")


# --- AC-35b: ErrorBannerLayer scene has NO AnimationPlayer / AudioStreamPlayer ---
# (scene-tree assertion — catches a .tscn-instanced autoplay node that the source grep
#  would miss. Rule 8: the banner is static — zero animation, zero audio, zero pulse.)

func test_ac35b_error_banner_layer_has_no_animation_or_audio() -> void:
	var c: Node = _make(G_WORKOUT)
	var banner: CanvasLayer = c.get_banner_layer()
	assert_eq(banner.find_children("*", "AnimationPlayer", true, false).size(), 0,
		"AC-35b: ErrorBannerLayer has NO AnimationPlayer (banner is static)")
	assert_eq(banner.find_children("*", "AudioStreamPlayer", true, false).size(), 0,
		"AC-35b: ErrorBannerLayer has NO AudioStreamPlayer (banner is silent)")


# --- AC-36: both #24 layers have NO BackBufferCopy (forbidden 2nd framebuffer copy) ---

func test_ac36_no_second_backbuffercopy_on_either_layer() -> void:
	var c: Node = _make(G_WORKOUT)
	assert_eq(c.get_banner_layer().find_children("*", "BackBufferCopy", true, false).size(), 0,
		"AC-36: ErrorBannerLayer has NO BackBufferCopy (opacity-only backdrop)")
	assert_eq(c.get_shell_layer().find_children("*", "BackBufferCopy", true, false).size(), 0,
		"AC-36: LoginShellLayer has NO BackBufferCopy")


func test_banner_layer_hidden_when_no_banner() -> void:
	var c: Node = _make(G_WORKOUT)
	_settle(c)
	assert_eq(c.get_banner_stack().count(), 0, "no banners")
	assert_false(c.get_banner_layer().visible, "ErrorBannerLayer hidden when stack empty")
