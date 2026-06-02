# AudioManager — #4 Story 003: SFX pool + priority-aware voice stealing.
#
# Covers AC-03 (steal oldest same-priority), AC-03b (high-priority protected), AC-10 (unknown
# event no-throw), AC-16 (catalog missing → safe no-op mode), AC-17 (voice cap invariant).
# Priority/steal logic is verified via an injected catalog (real audio streams are /asset-spec, Q8).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


class MockGSM:
	func connect_for_initial_state(_c: Callable) -> void:
		pass

class MockPlatform:
	func is_web() -> bool:
		return false  # desktop → unlocked at boot (play_sfx runs the pool path)

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


## Boot an AudioManager with mocks. If `catalog` is non-null it is injected before _ready (so
## _load_sfx_catalog uses it, safe_mode=false); null leaves the boot to find no .tres → safe mode.
func _boot(catalog: Variant) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new()
	am._persistence = MockPersistence.new()
	if catalog != null:
		am._sfx_catalog = catalog
	add_child_autofree(am)
	return am


func _low_catalog() -> Dictionary:
	return {&"hit_light": {"priority": AM.SfxPriority.LOW}}


# ── AC-17 / AC-03: voice cap + steal oldest among equal priority ────────────────

func test_pool_voice_cap_never_exceeds_count() -> void:
	var am := _boot(_low_catalog())
	for _n: int in 20:
		am.play_sfx(&"hit_light")
	assert_eq(am._test_get_active_voice_count(), AM.SFX_VOICE_COUNT,
		"voice count capped at SFX_VOICE_COUNT (8) — memory-safety invariant, no unbounded slots")


func test_full_pool_steals_oldest_same_priority() -> void:
	var am := _boot(_low_catalog())
	for _n: int in AM.SFX_VOICE_COUNT:  # fill 8: slot i gets sequence i
		am.play_sfx(&"hit_light")
	am.play_sfx(&"hit_light")  # pool full → steal lowest-priority (all LOW), oldest (seq 0 = slot 0)
	assert_eq(am._test_get_active_voice_count(), AM.SFX_VOICE_COUNT, "still 8 after steal (no growth)")
	assert_eq(am._voice_seq[0], AM.SFX_VOICE_COUNT, "oldest slot (0) reassigned with the newest sequence")
	for i: int in range(1, AM.SFX_VOICE_COUNT):
		assert_eq(am._voice_seq[i], i, "slot %d (newer) was NOT stolen" % i)


# ── AC-03b: high-priority voice protected from a lower-priority steal (Pillar 3) ─

func test_high_priority_voice_protected_from_low_steal() -> void:
	var am := _boot({
		&"hit_light": {"priority": AM.SfxPriority.LOW},
		&"loot_fanfare": {"priority": AM.SfxPriority.HIGH},
	})
	for _n: int in (AM.SFX_VOICE_COUNT - 1):  # 7 low → slots 0-6
		am.play_sfx(&"hit_light")
	am.play_sfx(&"loot_fanfare")  # slot 7 = HIGH
	assert_eq(am._voice_priority[7], AM.SfxPriority.HIGH, "slot 7 holds the high fanfare")
	am.play_sfx(&"hit_light")  # new LOW with full pool → must steal a LOW, never the HIGH
	assert_eq(am._voice_priority[7], AM.SfxPriority.HIGH, "high fanfare NOT stolen by a low (Pillar 3 peak)")
	var high_count: int = 0
	for p: int in am._voice_priority:
		if p == AM.SfxPriority.HIGH:
			high_count += 1
	assert_eq(high_count, 1, "exactly one HIGH voice survived the low steal")


# ── AC-10: unknown event_id → no-throw + counted ────────────────────────────────

func test_unknown_event_id_is_no_throw() -> void:
	var am := _boot(_low_catalog())
	am.play_sfx(&"does_not_exist")
	assert_eq(am._unknown_event_count, 1, "unknown event_id counted (Rule 8 no-throw)")
	assert_eq(am._test_get_active_voice_count(), 0, "unknown event consumes no voice")


# ── AC-16: catalog missing → safe no-op mode ────────────────────────────────────

func test_missing_catalog_enters_safe_mode_noop() -> void:
	var am := _boot(null)  # no injected catalog + no .tres on disk → safe mode at boot
	assert_true(am._sfx_safe_mode, "missing catalog → safe no-op mode (push_error once at boot)")
	am.play_sfx(&"hit_light")
	assert_eq(am._test_get_active_voice_count(), 0, "play_sfx is a no-op in safe mode (no crash)")
