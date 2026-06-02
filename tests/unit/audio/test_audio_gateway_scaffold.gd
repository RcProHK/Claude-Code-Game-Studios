# AudioManager — #4 Story 001: closed-API gateway scaffold + CI lint + pure test seams.
#
# Covers AC-01 (check_audio_callers.gd regex + whitelist) and the Rule 1 test-seam contract
# (_register_duck / _release_duck / _compute_duck_target / _voice_busy / _active_crossfade_count)
# plus the boot scaffold (platform unlock gate + GSM subscription + voice-flag allocation).
#
# The CI lint extends SceneTree and calls quit(), so it cannot be invoked from GUT directly —
# its regex + whitelist logic is mirrored inline here (same pattern as the #10 / streak lint tests).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")

# ── CI lint mirror (must match check_audio_callers.gd) ────────────────────────────
const VIOLATION_FIXTURE: String = "res://tests/fixtures/audio_callers_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/audio_callers_clean.gd"
const SCAN_ROOT: String = "res://src/"
const EXEMPT_EXACT: Array[String] = ["res://src/autoload/audio_manager.gd"]
const PATTERNS: Array[String] = [
	"AudioServer\\.",
	"AudioStreamPlayer\\.new\\s*\\(",
	"AudioStreamPlayer[^\\n]*\\.bus\\s*=",
]


# ── Mocks (untyped DI seams accept any object exposing the expected methods) ──────

class MockGSM:
	var connect_count: int = 0
	func connect_for_initial_state(_c: Callable) -> void:
		connect_count += 1

class MockPlatform:
	var _web: bool = false
	func _init(web: bool) -> void:
		_web = web
	func is_web() -> bool:
		return _web

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


# ── lint helpers (mirrors check_audio_callers.gd) ─────────────────────────────────

func _read_lines(res_path: String) -> PackedStringArray:
	var file := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


func _strip_trailing_comment(line: String) -> String:
	var in_single: bool = false
	var in_double: bool = false
	for k: int in line.length():
		var ch: String = line[k]
		if ch == "\"" and not in_single:
			in_double = not in_double
		elif ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "#" and not in_single and not in_double:
			return line.substr(0, k)
	return line


func _count_raw_matches(lines: PackedStringArray) -> int:
	var compiled: Array[RegEx] = []
	for p: String in PATTERNS:
		var re := RegEx.new()
		assert_eq(re.compile(p), OK, "regex must compile: %s" % p)
		compiled.append(re)
	var count: int = 0
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue
		var stripped: String = _strip_trailing_comment(line)
		for re: RegEx in compiled:
			if re.search(stripped) != null:
				count += 1
	return count


func _is_whitelisted(file_path: String) -> bool:
	return EXEMPT_EXACT.has(file_path)


func _collect_gd_files(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd":
			acc.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), acc)


func _make_booted(web: bool) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new(web)
	am._persistence = MockPersistence.new()
	add_child_autofree(am)  # triggers _ready
	return am


# ── AC-01: CI lint regex + whitelist ──────────────────────────────────────────────

func test_violation_fixture_flags_all_three_patterns() -> void:
	assert_eq(_count_raw_matches(_read_lines(VIOLATION_FIXTURE)), 3,
		"AC-01: the 3 forbidden audio-engine uses (one per pattern) are each flagged")


func test_clean_fixture_has_no_violations() -> void:
	assert_eq(_count_raw_matches(_read_lines(CLEAN_FIXTURE)), 0,
		"AC-01: gateway calls + lookalike identifiers (event_bus/message_bus) must NOT flag")


func test_real_src_has_zero_external_audio_callers() -> void:
	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)
	assert_gt(scan_files.size(), 0, "src/ must contain .gd files to scan")
	var offenders: Array[String] = []
	for file_path: String in scan_files:
		if _is_whitelisted(file_path):
			continue
		if _count_raw_matches(_read_lines(file_path)) > 0:
			offenders.append(file_path)
	assert_eq(offenders, ([] as Array[String]),
		"AC-01: no external AudioServer/AudioStreamPlayer use in src/ (gateway exempt)")


func test_gateway_is_whitelisted() -> void:
	assert_true(_is_whitelisted("res://src/autoload/audio_manager.gd"),
		"AC-01: the gateway autoload is whitelisted (exact res:// path)")


func test_whitelist_exact_path_is_precise() -> void:
	assert_false(_is_whitelisted("res://src/other/audio_manager.gd"),
		"AC-01: same basename at a different path is NOT the gateway")
	assert_false(_is_whitelisted("res://src/autoload/audio_manager_helper.gd"),
		"AC-01: a look-alike basename is NOT the gateway")


# ── Rule 1 test seams — pure duck functions (no _ready required) ───────────────────

func test_compute_duck_target_empty_returns_base() -> void:
	var am := AM.new()
	autofree(am)
	assert_almost_eq(am._compute_duck_target({}), AM.DEFAULT_MUSIC_DB, 0.001,
		"empty dict → base_music_db (guarded; never calls min([]))")


func test_register_duck_returns_distinct_handles_and_targets_deepest_offset() -> void:
	var am := AM.new()
	autofree(am)
	var h1: int = am._register_duck(AM.DUCK_OFFSET_DB)              # -8 (high)
	var h2: int = am._register_duck(AM.STREAK_CHIME_DUCK_OFFSET_DB) # -5 (mid)
	assert_ne(h1, h2, "handles are monotonic / distinct (multiset, no dedup)")
	var expected: float = maxf(AM.DEFAULT_MUSIC_DB + AM.DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB)  # -14
	assert_almost_eq(am._compute_duck_target(am._active_ducks), expected, 0.001,
		"min(values()) picks the deepest offset (-8) → -14 dB")


func test_release_duck_is_idempotent_and_restores_base() -> void:
	var am := AM.new()
	autofree(am)
	var h: int = am._register_duck(-8.0)
	am._release_duck(h)
	am._release_duck(h)  # idempotent — erase on absent key is a no-op, no error
	assert_almost_eq(am._compute_duck_target(am._active_ducks), AM.DEFAULT_MUSIC_DB, 0.001,
		"after release refcount 0 → base (never a permanent duck)")


# ── Boot scaffold (platform unlock gate + GSM subscription + voice-flag allocation) ──

func test_boot_desktop_is_unlocked_at_boot() -> void:
	var am := _make_booted(false)  # is_web() == false
	assert_true(am.is_audio_unlocked(),
		"desktop/native boot → unlocked immediately (no gesture gate)")


func test_boot_web_is_locked_until_gesture() -> void:
	var am := _make_booted(true)  # is_web() == true
	assert_false(am.is_audio_unlocked(),
		"web boot → LOCKED until first gesture (Story 007 unlock flow)")


func test_boot_allocates_voice_flags_and_subscribes_gsm_once() -> void:
	var mock_gsm := MockGSM.new()
	var am := AM.new()
	am._gsm = mock_gsm
	am._platform_detect = MockPlatform.new(false)
	am._persistence = MockPersistence.new()
	add_child_autofree(am)  # triggers _ready
	assert_eq(am._test_get_active_voice_count(), 0, "all voice slots idle at boot")
	assert_eq(am._voice_busy.size(), AM.SFX_VOICE_COUNT, "voice flags allocated to pool size")
	assert_eq(am._test_get_active_crossfade_count(), 0, "no crossfade in-flight at boot")
	assert_eq(mock_gsm.connect_count, 1,
		"GSM subscribed exactly once via connect_for_initial_state (ADR-0006 C6)")


func test_public_api_surface_and_bus_enum_present() -> void:
	var am := AM.new()
	autofree(am)
	for method_name: String in [
		"play_sfx", "play_bgm", "stop_bgm", "set_bus_volume_db",
		"get_bus_volume_db", "set_bus_muted", "is_audio_unlocked",
	]:
		assert_true(am.has_method(method_name), "gateway exposes %s()" % method_name)
	assert_eq(AM.Bus.MASTER, 0, "Bus enum: MASTER ordinal 0")
	assert_eq(AM.Bus.MUSIC, 1, "Bus enum: MUSIC ordinal 1")
	assert_eq(AM.Bus.SFX, 2, "Bus enum: SFX ordinal 2")
