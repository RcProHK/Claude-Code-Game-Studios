extends GutTest
## Story 006: GSM-driven 3-state animation FSM (IDLE/COMBAT/CAST). Drives the real
## handler with an injected monotonic clock and the real GameStateMachine enum (read-only).
## Covers AC-06 (combat cut), boss-shares-combat, EC-SIG-5 (unknown state ignored), and
## EC-XSYS-2 (16ms storm debounce; cast NOT debounced).
## See production/epics/avatar-renderer/story-006-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")


class FakeClock:
	extends RefCounted
	var ms: int = 0
	func now_ms() -> int:
		return ms


## In-memory persistence seam so a combat-exit re-derive (which may write through
## milestone/micro) never touches the real autoload cache (reference_test_persistence_isolation).
class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


func _renderer():
	var r = AvatarRendererScript.new()
	r._gsm = GameStateMachine
	r._stat = StatSystem
	r._ability = AbilitySystem
	r._persistence = MockPersistence.new()
	r._clock = FakeClock.new()
	r._ready_complete = true
	return r


func test_ac06_idle_to_combat_and_back() -> void:
	var r = _renderer()
	r._clock.ms = 1000
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	assert_eq(r.get_animation_state(), &"COMBAT", "IDLE -> COMBAT_ACTIVE drives COMBAT")
	r._clock.ms = 2000
	r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, GameStateMachine.GameState.IDLE, {})
	assert_eq(r.get_animation_state(), &"IDLE", "COMBAT_ACTIVE -> IDLE drives IDLE")
	r.free()


func test_boss_encounter_shares_combat_anim() -> void:
	var r = _renderer()
	r._clock.ms = 5000
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.BOSS_ENCOUNTER, {})
	assert_eq(r.get_animation_state(), &"COMBAT", "BOSS_ENCOUNTER shares the COMBAT anim (CR-1/Option C)")
	r.free()


func test_ec_sig5_unknown_state_ignored() -> void:
	var r = _renderer()
	r._clock.ms = 1000
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	assert_eq(r.get_animation_state(), &"COMBAT")
	# An out-of-enum ordinal is ignored; the previous anim is retained.
	r._clock.ms = 2000
	r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, 999, {})
	assert_eq(r.get_animation_state(), &"COMBAT", "EC-SIG-5 unknown state ignored, anim retained")
	r.free()


func test_ec_xsys2_storm_coalesced_latest_wins() -> void:
	var r = _renderer()
	var clk = r._clock
	clk.ms = 0
	# First transition applies immediately.
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	assert_eq(r.get_animation_state(), &"COMBAT", "first storm event applies immediately")
	# 10 rapid transitions within the 16ms window -> coalesced, not applied.
	for i in range(10):
		clk.ms = 2 + i
		var to_state = GameStateMachine.GameState.IDLE if i % 2 == 0 else GameStateMachine.GameState.COMBAT_ACTIVE
		r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, to_state, {})
	assert_eq(r.get_animation_state(), &"COMBAT", "intermediate storm transitions suppressed during window")
	# A final IDLE inside the window, then flush after the window elapses.
	clk.ms = 12
	r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, GameStateMachine.GameState.IDLE, {})
	r._flush_pending_gsm_anim(30)
	assert_eq(r.get_animation_state(), &"IDLE", "only the final coalesced target applies after 16ms")
	r.free()


func test_cast_is_not_debounced() -> void:
	var r = _renderer()
	r._clock.ms = 0
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	assert_eq(r.get_animation_state(), &"COMBAT")
	# A cast inside the debounce window applies immediately (atomicity bypasses debounce).
	r._clock.ms = 4
	r._on_ability_cast(&"strike_1", null, null)
	assert_eq(r.get_animation_state(), &"CAST", "cast bypasses the GSM debounce (EC-XSYS-2)")
	r.free()
