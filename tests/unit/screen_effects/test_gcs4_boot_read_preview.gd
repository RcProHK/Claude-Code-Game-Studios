## #6 G-CS-4 — boot self-read + preview API (#22 story 011)。
## Parity 準則:#6 existing suite 零變紅(成個 dir 一齊跑)。
extends GutTest

const ScreenEffectsScript := preload("res://src/autoload/screen_effects.gd")


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)


func _make_fx(persisted_motion = null):
	var fx = ScreenEffectsScript.new()
	var mock := MockPersistence.new()
	if persisted_motion != null:
		mock.store["settings.motion_intensity"] = persisted_motion
	fx._persistence = mock
	add_child_autofree(fx)  # _ready 行 boot self-read
	return fx


## --- G-CS-4(a) boot self-read ---

func test_boot_reads_persisted_motion_intensity() -> void:
	var fx = _make_fx(0.68)
	assert_almost_eq(fx._motion_intensity, 0.68, 0.0001, "boot apply persisted 值")


func test_boot_missing_key_keeps_default_one() -> void:
	var fx = _make_fx(null)
	assert_almost_eq(fx._motion_intensity, 1.0, 0.0001, "fresh install → default 1.0")


func test_boot_corrupt_type_retains_default() -> void:
	var fx = _make_fx("abc")
	assert_almost_eq(fx._motion_intensity, 1.0, 0.0001, "corrupt type → retain(reject-and-retain 語意)")


func test_boot_non_finite_retains_default() -> void:
	var fx = _make_fx(NAN)
	assert_almost_eq(fx._motion_intensity, 1.0, 0.0001, "NaN → setter reject-and-retain")


func test_boot_raw_legacy_float_applied_raw() -> void:
	# #22 EC-25:boot 用 raw float(0.999),同 UI 顯示最多差 0.005 — 唔 quantize
	var fx = _make_fx(0.999)
	assert_almost_eq(fx._motion_intensity, 0.999, 0.0001)


## --- G-CS-4(b) preview_hit_heavy ---

func test_preview_sets_trauma_from_dispatch_table() -> void:
	var fx = _make_fx(null)
	fx.preview_hit_heavy()
	assert_almost_eq(fx._trauma, 0.4, 0.0001, "HIT_HEAVY intensity 0.4 × motion 1.0")


func test_preview_spam_does_not_stack() -> void:
	var fx = _make_fx(null)
	for i in range(5):
		fx.preview_hit_heavy()
	assert_almost_eq(fx._trauma, 0.4, 0.0001, "cancel-restart latest-wins — 唔疊(EC-26)")


func test_preview_scales_with_motion_intensity() -> void:
	var fx = _make_fx(0.5)
	fx.preview_hit_heavy()
	assert_almost_eq(fx._trauma, 0.2, 0.0001, "0.4 × 0.5")


func test_preview_at_zero_motion_produces_no_motion() -> void:
	var fx = _make_fx(0.0)
	fx.preview_hit_heavy()
	assert_almost_eq(fx._trauma, 0.0, 0.0001, "EC-24:零 motion,唔 fake shake")


func test_preview_never_pauses_tree() -> void:
	var fx = _make_fx(null)
	fx.preview_hit_heavy()
	assert_false(get_tree().paused, "shake-only — 永不 hit_pause(#22 layer PAUSABLE trap)")
