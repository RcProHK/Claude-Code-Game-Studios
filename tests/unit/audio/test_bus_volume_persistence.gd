# AudioManager — #4 Story 002: bus topology + volume persistence + Formula 2.
#
# Covers AC-02 (bus topology + defaults), AC-13/22 (Formula 2 slider→dB), AC-23 (boost clamp),
# AC-11 (volume round-trip), AC-20a/b/c (corrupt-volume fallback), AC-28 (mute/volume independent).
# Filename uses the test_*.gd PREFIX (GUT only collects prefix; *_test.gd suffix = phantom skip).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


class MockGSM:
	func connect_for_initial_state(_c: Callable) -> void:
		pass

class MockPlatform:
	func is_web() -> bool:
		return false

class MockPersistence:
	var store: Dictionary = {}
	func read(key: String) -> Variant:
		return store.get(key, null)
	func write(key: String, value: Variant, _flush: bool = false) -> bool:
		store[key] = value
		return true


func _boot(persist: MockPersistence = null) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new()
	am._persistence = persist if persist != null else MockPersistence.new()
	add_child_autofree(am)  # triggers _ready → _ensure_buses + _load_persisted_volumes
	return am


# ── AC-02: bus topology + defaults ─────────────────────────────────────────────

func test_boot_creates_master_music_sfx_buses_with_defaults() -> void:
	var am := _boot()
	for bus_name: StringName in [&"Master", &"Music", &"SFX"]:
		assert_gt(AudioServer.get_bus_index(bus_name), -1, "%s bus exists after boot" % bus_name)
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.MASTER), 0.0, 0.01, "Master default 0 dB")
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.MUSIC), -6.0, 0.01, "Music default -6 dB (subtle, locked)")
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.SFX), 0.0, 0.01, "SFX default 0 dB")


# ── AC-13 / AC-22: Formula 2 slider → dB (pure, no _ready) ──────────────────────

func test_slider_to_db_mapping() -> void:
	var am := AM.new()
	autofree(am)
	assert_almost_eq(am._slider_to_db(0.5), -6.0206, 0.01, "slider 0.5 → ~-6.02 dB")
	assert_almost_eq(am._slider_to_db(0.0), AM.MUTE_FLOOR_DB, 0.01, "slider 0 → -80 dB (mute floor)")
	assert_almost_eq(am._slider_to_db(1.0), 0.0, 0.01, "slider 1 → 0 dB")


func test_slider_to_db_nan_and_inf_return_mute_floor() -> void:
	var am := AM.new()
	autofree(am)
	assert_almost_eq(am._slider_to_db(NAN), AM.MUTE_FLOOR_DB, 0.01, "NaN slider → -80 dB (no NaN dB to bus)")
	assert_almost_eq(am._slider_to_db(INF), AM.MUTE_FLOOR_DB, 0.01, "inf slider → -80 dB")


# ── AC-23: set boost clamped to MAX_BUS_DB ──────────────────────────────────────

func test_set_bus_volume_db_clamps_boost_to_max() -> void:
	var am := _boot()
	am.set_bus_volume_db(AM.Bus.MUSIC, 12.0)
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.MUSIC), AM.MAX_BUS_DB, 0.01,
		"+12 dB boost clamped to MAX_BUS_DB (0) — anti-clipping")


# ── AC-11: volume persists across reboot ────────────────────────────────────────

func test_volume_persists_across_reboot() -> void:
	var persist := MockPersistence.new()
	var am1 := _boot(persist)
	am1.set_bus_volume_db(AM.Bus.MUSIC, -10.0)
	assert_eq(persist.store.get("audio.music_db"), -10.0, "music_db written to audio.* namespace")
	var am2 := _boot(persist)  # reboot with the same persisted store
	assert_almost_eq(am2.get_bus_volume_db(AM.Bus.MUSIC), -10.0, 0.01, "reboot restores -10 dB")


# ── AC-28: mute + volume persist independently ──────────────────────────────────

func test_mute_and_volume_persist_independently() -> void:
	var persist := MockPersistence.new()
	var am1 := _boot(persist)
	am1.set_bus_muted(AM.Bus.MUSIC, true)
	am1.set_bus_volume_db(AM.Bus.MUSIC, -10.0)
	assert_eq(persist.store.get("audio.music_muted"), true, "mute persisted independently")
	assert_eq(persist.store.get("audio.music_db"), -10.0, "volume persisted independently")
	var am2 := _boot(persist)
	var midx: int = AudioServer.get_bus_index(&"Music")
	assert_true(AudioServer.is_bus_mute(midx), "reboot restores mute=true")
	assert_almost_eq(am2.get_bus_volume_db(AM.Bus.MUSIC), -10.0, 0.01, "volume intact under mute (not overwritten)")


# ── AC-20a/b/c: corrupt / missing persisted volume fallback ─────────────────────

func test_persisted_volume_missing_uses_default() -> void:
	var am := _boot()  # empty store → AC-20a
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.MUSIC), -6.0, 0.01, "missing key → default -6 (no warn)")


func test_persisted_volume_nan_falls_back_to_default() -> void:
	var persist := MockPersistence.new()
	persist.store["audio.music_db"] = NAN  # AC-20b
	var am := _boot(persist)
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.MUSIC), -6.0, 0.01, "NaN persisted → default -6 + warn")


func test_persisted_volume_out_of_range_clamped() -> void:
	var persist := MockPersistence.new()
	persist.store["audio.music_db"] = 40.0  # AC-20c
	var am := _boot(persist)
	assert_almost_eq(am.get_bus_volume_db(AM.Bus.MUSIC), AM.MAX_BUS_DB, 0.01,
		"+40 out-of-range → clamped to MAX_BUS_DB (0) + warn")
