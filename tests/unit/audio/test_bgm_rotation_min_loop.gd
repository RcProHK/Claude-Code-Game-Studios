# AudioManager — #4 Story 009: BGM variant rotation + BGM_MIN_LOOP_SEC guard (Logic).
#
# Covers AC-29 (rotation non-immediate-repeat) and AC-27 (short-loop boot warning, no-throw).
# Rotation ORDER is the testable logic (_pick_next_variant); the `finished`-driven trigger + real
# variant audio are /asset-spec (Q8). AC-29 verifies sequence, NOT zero-gap (near-gap-free, IB-2).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


class MockGSM:
	signal state_changed(from_state: Variant, to_state: Variant, payload: Variant)
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func get_current_state() -> int:
		return 0

class MockPlatform:
	func is_web() -> bool:
		return false

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


func _boot_with_bgm(bgm_catalog: Dictionary) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new()
	am._persistence = MockPersistence.new()
	am._sfx_catalog = {}
	am._bgm_catalog = bgm_catalog
	add_child_autofree(am)
	return am


# ── AC-29: rotation never repeats the previous variant ──────────────────────────

func test_pick_next_variant_non_immediate_repeat() -> void:
	var am := AM.new()
	autofree(am)
	var last: int = -1
	for n: int in (AM.FOCUS_LOW_VARIANT_COUNT * 3):  # 9 rotations
		var idx: int = am._pick_next_variant(AM.FOCUS_LOW_VARIANT_COUNT, last)
		assert_ne(idx, last, "rotation %d: never repeats the previous variant" % n)
		assert_between(idx, 0, AM.FOCUS_LOW_VARIANT_COUNT - 1, "variant index within pool range")
		last = idx


func test_pick_next_variant_single_variant_is_degenerate() -> void:
	var am := AM.new()
	autofree(am)
	assert_eq(am._pick_next_variant(1, -1), 0, "count 1 → only variant 0 (no rotation possible)")


func test_rotate_focus_low_advances_variant() -> void:
	var am := _boot_with_bgm({&"focus_low_pool": {"stream": null}})
	am.play_bgm(&"focus_low_pool", 0.0)
	var before: int = am._bgm_last_variant
	am._rotate_focus_low()
	assert_ne(am._bgm_last_variant, before, "rotate advances the variant index (non-immediate-repeat)")


# ── AC-27: BGM track shorter than BGM_MIN_LOOP_SEC warns at boot (no-throw) ──────

func test_short_loop_track_warns_at_boot() -> void:
	var am := _boot_with_bgm({&"focus_low_pool": {"loop_sec": 30.0}})  # 30 < 90
	assert_eq(am._bgm_loop_warning_count, 1, "short-loop track → one boot warning")
	assert_true(am._bgm_catalog.has(&"focus_low_pool"),
		"short track still present + playable (Foundation no-throw, not rejected)")


func test_adequate_loop_track_no_warning() -> void:
	var am := _boot_with_bgm({&"focus_low_pool": {"loop_sec": 120.0}})  # >= 90
	assert_eq(am._bgm_loop_warning_count, 0, "loop >= BGM_MIN_LOOP_SEC → no warning")


func test_missing_loop_sec_field_no_warning() -> void:
	var am := _boot_with_bgm({&"focus_low_pool": {"stream": null}})  # no loop_sec key
	assert_eq(am._bgm_loop_warning_count, 0, "no loop_sec metadata → no warning (validated when present)")
