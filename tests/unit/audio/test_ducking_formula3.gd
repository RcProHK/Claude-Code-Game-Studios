# AudioManager — #4 Story 004: ducking (Formula 3 + multiset de-escalation).
#
# Covers AC-09 (duck target + release), AC-09b (bus isolation), AC-09c (explicit/steal release),
# AC-09d (positive-offset guard — push_error, non-aborting), AC-15 (multiset de-escalation steps),
# AC-25 (priority dispatch depth) + a Rule 7b steal-releases-duck no-leak integration check.
# Duck-target assertions are PURE (_compute_duck_target) — headless Tweens do not advance, so the
# live Music-bus dB mid-tween is never asserted (GDD design).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


class MockGSM:
	func connect_for_initial_state(_c: Callable) -> void:
		pass

class MockPlatform:
	func is_web() -> bool:
		return false

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


func _boot(catalog: Variant) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new()
	am._persistence = MockPersistence.new()
	if catalog != null:
		am._sfx_catalog = catalog
	add_child_autofree(am)
	return am


## Pure instance (no _ready) for the dict-only duck seam tests. _base_music_db = DEFAULT (-6).
func _pure() -> Node:
	var am := AM.new()
	autofree(am)
	return am


# ── AC-09: high duck target + release restores base ─────────────────────────────

func test_high_duck_targets_minus14_release_restores_base() -> void:
	var am := _pure()
	var base: float = am._base_music_db
	var h: int = am._register_duck(AM.DUCK_OFFSET_DB)  # -8
	assert_almost_eq(am._compute_duck_target(am._active_ducks),
		maxf(base + AM.DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB), 0.01, "high duck → base-8 = -14 dB")
	am._release_duck(h)
	assert_almost_eq(am._compute_duck_target(am._active_ducks), base, 0.01, "release → base")


# ── AC-09c: explicit release (steal path uses the same call) is safe ────────────

func test_explicit_release_erases_handle_and_restores_base() -> void:
	var am := _pure()
	var h: int = am._register_duck(AM.DUCK_OFFSET_DB)
	am._release_duck(h)
	assert_false(am._active_ducks.has(h), "handle erased")
	assert_almost_eq(am._compute_duck_target(am._active_ducks), am._base_music_db, 0.01,
		"refcount 0 → base (never a permanent duck)")


# ── AC-09d: positive offset clamped (push_error, non-aborting); music never raised ─

func test_positive_offset_clamped_music_never_raised() -> void:
	var am := _pure()
	am._register_duck(8.0)  # caller bug — push_error logged, NOT an aborting assert
	assert_almost_eq(am._compute_duck_target(am._active_ducks), am._base_music_db, 0.01,
		"+8 offset clamped to 0 → target == base (music never raised above base)")
	var am2 := _pure()
	am2._register_duck(0.0)
	assert_almost_eq(am2._compute_duck_target(am2._active_ducks), am2._base_music_db, 0.01,
		"0 offset → base (harmless no-op duck)")


# ── AC-15: multiset de-escalation steps (-14 → -11 → base) ──────────────────────

func test_multiset_de_escalation_steps_down() -> void:
	var am := _pure()
	var base: float = am._base_music_db
	var loud: int = am._register_duck(AM.DUCK_OFFSET_DB)              # -8
	var soft: int = am._register_duck(AM.STREAK_CHIME_DUCK_OFFSET_DB)  # -5
	assert_almost_eq(am._compute_duck_target(am._active_ducks),
		maxf(base + AM.DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB), 0.01, "both active → min(-8,-5)=-8 → -14")
	am._release_duck(loud)  # erase the -8
	assert_almost_eq(am._compute_duck_target(am._active_ducks),
		maxf(base + AM.STREAK_CHIME_DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB), 0.01,
		"release -8 → remaining -5 → -11 (stepped, NOT straight to base)")
	am._release_duck(soft)
	assert_almost_eq(am._compute_duck_target(am._active_ducks), base, 0.01, "release -5 → base")


# ── AC-09b: every SFX pool player on the SFX bus (duck presses Music only) ───────

func test_sfx_pool_players_on_sfx_bus_only() -> void:
	var am := _boot(null)  # safe mode (no catalog) still builds the pool
	assert_eq(am._sfx_pool.size(), AM.SFX_VOICE_COUNT, "8 pool players built")
	for p: AudioStreamPlayer in am._sfx_pool:
		assert_eq(p.bus, &"SFX", "pool player routed to SFX bus (stingers never duck themselves)")


# ── AC-25: priority dispatch → duck depth (low base / mid -11 / high -14) ───────

func test_priority_dispatch_duck_depth() -> void:
	var cat: Dictionary = {
		&"lo": {"priority": AM.SfxPriority.LOW},
		&"mid": {"priority": AM.SfxPriority.MID},
		&"hi": {"priority": AM.SfxPriority.HIGH},
	}
	var am_lo := _boot(cat)
	am_lo.play_sfx(&"lo")
	assert_almost_eq(am_lo._compute_duck_target(am_lo._active_ducks), am_lo._base_music_db, 0.01,
		"low priority → no duck → base")
	var am_mid := _boot(cat)
	am_mid.play_sfx(&"mid")
	assert_almost_eq(am_mid._compute_duck_target(am_mid._active_ducks),
		maxf(am_mid._base_music_db + AM.STREAK_CHIME_DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB), 0.01,
		"mid priority → shallow duck -11")
	var am_hi := _boot(cat)
	am_hi.play_sfx(&"hi")
	assert_almost_eq(am_hi._compute_duck_target(am_hi._active_ducks),
		maxf(am_hi._base_music_db + AM.DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB), 0.01,
		"high priority → full duck -14")


# ── Rule 7b: steal releases the stolen voice's duck (no refcount leak) ──────────

func test_steal_releases_stolen_voice_duck_no_leak() -> void:
	var am := _boot({&"hi": {"priority": AM.SfxPriority.HIGH}})
	for _n: int in 20:
		am.play_sfx(&"hi")  # 8 fill + 12 steals (all high)
	assert_eq(am._active_ducks.size(), AM.SFX_VOICE_COUNT,
		"duck refcount == busy voices (8), NOT 20 — steal releases the stolen duck (Rule 7b)")
