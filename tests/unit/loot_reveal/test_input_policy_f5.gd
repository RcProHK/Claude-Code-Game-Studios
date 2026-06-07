extends GutTest
## Story 005 — per-stage input policy + F5 fast-complete + two-stage tap.
## Covers AC-11 / AC-15 / AC-16 / AC-50 / AC-37c(ui_accept 半;ui_cancel
## target 喺 stories 014/015).
##
## GDD: design/gdd/loot-drop-modal.md Rule 5 / F5 / EC-M19.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const ParticleWrapperScript := preload("res://src/autoload/particle_system_wrapper.gd")

const S := CoordinatorScript.ModalState


class CallLog:
	extends RefCounted
	var entries: Array = []
	func count(call_name: String) -> int:
		var n: int = 0
		for e: Dictionary in entries:
			if e["call"] == call_name:
				n += 1
		return n


class SpyHandle:
	extends RefCounted
	var stop_calls: int = 0
	func stop() -> void:
		stop_calls += 1


class FakeParticles:
	extends Node
	var log: CallLog
	var last_handle: SpyHandle
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0) -> SpyHandle:
		log.entries.append({"call": "play", "preset": preset_id, "pos": position, "mult": multiplier})
		last_handle = SpyHandle.new()
		return last_handle


class FakeAudio:
	extends Node
	var log: CallLog
	func play_sfx(event_id: StringName) -> void:
		log.entries.append({"call": "play_sfx", "event": event_id})
	# Deliberately exposes a cut API — the coordinator must NEVER call it.
	func stop_sfx(event_id: StringName) -> void:
		log.entries.append({"call": "stop_sfx", "event": event_id})


class FakeCamera:
	extends Node
	signal focal_completed(target_position: Vector2)
	var log: CallLog
	func request_focal(target_position: Vector2, duration: float = 0.0, zoom_level: float = 1.0) -> void:
		log.entries.append({"call": "request_focal", "pos": target_position, "duration": duration, "zoom": zoom_level})
	func finish_focal() -> void:
		focal_completed.emit(Vector2.ZERO)


class FakeScreenEffects:
	extends Node
	var log: CallLog
	var _next_handle: int = 0
	func ceremony_freeze(duration_sec: float) -> int:
		log.entries.append({"call": "ceremony_freeze", "duration": duration_sec})
		_next_handle += 1
		return _next_handle
	func release(handle) -> void:
		log.entries.append({"call": "release", "handle": handle})
	func shake(intensity: float, duration: float) -> void:
		log.entries.append({"call": "shake", "intensity": intensity, "duration": duration})
	func apply_ceremony_saturation(drop: float, recovery_sec: float) -> void:
		log.entries.append({"call": "apply_ceremony_saturation", "drop": drop, "recovery": recovery_sec})


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 7
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func enter_loot_drop() -> void:
		state_changed.emit(2, 7, null)


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending


var _log: CallLog
var _gsm: MockGsm
var _loot: MockLootSystem
var _particles: FakeParticles
var _cam: FakeCamera
var _fx: FakeScreenEffects


func _drop(tier_name: String) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = "drop_x"
	d.rarity_tier = tier_name
	return d


func _make() -> Node:
	_log = CallLog.new()
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_particles = FakeParticles.new()
	_cam = FakeCamera.new()
	_fx = FakeScreenEffects.new()
	var audio := FakeAudio.new()
	for fake: Node in [_particles, audio, _cam, _fx]:
		fake.log = _log
	for n: Node in [_gsm, _loot, _particles, audio, _cam, _fx]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._particles = _particles
	c._audio = audio
	c._camera = _cam
	c._screen_effects = _fx
	add_child_autofree(c)
	return c


func _open(c: Node, tier_name: String) -> void:
	_loot.pending = [_drop(tier_name)]
	_gsm.enter_loot_drop()
	assert_true(c.is_modal_active())


# --- AC-11: per-stage policy ×5 ---

func test_tap_in_entry_is_ignored_covers_tap_through() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")  # ENTRY, clock 0 < D_entry — the EC-M19 tap-through window
	c.handle_tap()
	assert_eq(c.get_fsm_state(), S.ENTRY, "S0/S1 tap ignored (t < D_entry)")
	assert_false(c._fast_complete_active, "no snap from an ENTRY tap")


func test_tap_in_ceremony_fast_completes() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c._process(0.5)  # CEREMONY
	c.handle_tap()
	assert_true(c._fast_complete_active, "S2 tap = fast-complete")


func test_tap_in_steady_dismisses_natural_path_zero_lockout() -> void:
	var c: Node = _make()
	_open(c, "COMMON")
	c._process(0.25)  # natural S3 (T_block 200)
	assert_eq(c.get_fsm_state(), S.STEADY)
	c.handle_tap()  # immediate — natural S3 has NO debounce
	assert_eq(c.get_fsm_state(), S.EXITING, "natural S3 → tap dismisses instantly")


func test_tap_in_exiting_is_ignored() -> void:
	var c: Node = _make()
	_open(c, "COMMON")
	c._process(0.25)
	c.handle_tap()  # → EXITING
	c.handle_tap()  # S4 tap
	assert_eq(c.get_fsm_state(), S.EXITING, "S4 tap ignored")


func test_tap_while_hidden_is_ignored() -> void:
	var c: Node = _make()
	c.handle_tap()
	assert_eq(c.get_fsm_state(), S.HIDDEN, "no surface — no effect")


# --- AC-15: debounce anchored at S3 entry ---

func test_two_stage_debounce_sequence() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c._process(0.5)  # clock 500 — CEREMONY
	c.handle_tap()   # fast-complete: S3 target = min(500+100, 1200) = 600
	c._process(0.1)  # clock 600 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY, "S3 @ t_tap + SNAP_SEC")
	c._process(0.2)  # since_s3 = 200ms < 250
	c.handle_tap()
	assert_eq(c.get_fsm_state(), S.STEADY, "second tap inside debounce ignored")
	c._process(0.1)  # since_s3 = 300ms ≥ 250
	c.handle_tap()
	assert_eq(c.get_fsm_state(), S.EXITING, "third tap after debounce dismisses")


# --- AC-16: fast-complete side effects ---

func test_fast_complete_releases_active_freeze_same_frame() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c._process(0.5)
	c._process(0.5)   # clock 1000 — still ceremony
	_cam.finish_focal()  # freeze issued
	assert_eq(_log.count("ceremony_freeze"), 1)
	c.handle_tap()
	assert_eq(_log.count("release"), 1, "freeze released on the tap frame (INV-M1 exit)")


func test_fast_complete_before_freeze_issue_skips_it_entirely() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c._process(0.5)  # CEREMONY, freeze not yet issued (focal pending)
	c.handle_tap()
	_cam.finish_focal()           # would-be freeze anchor arrives late
	for i: int in range(4):
		c._process(0.5)           # drive past every fallback window
	assert_eq(_log.count("ceremony_freeze"), 0, "freeze never issued after skip (F5)")
	assert_eq(_log.count("release"), 0, "nothing to release — not-issued path")


func test_fast_complete_stops_particles_naturally_and_never_cuts_audio() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c._process(0.5)
	c.handle_tap()
	assert_eq(_particles.last_handle.stop_calls, 1, "burst stop() — natural fade, not hard-cut")
	assert_eq(_log.count("stop_sfx"), 0, "audio sting NEVER cut (rarity backup channel)")
	assert_eq(_log.count("play_sfx"), 1, "no extra audio feedback on the skip tap (deliberate silence)")


# --- AC-50: F5 window + clamp + boundary + exactly-once ---

func test_tap_before_entry_done_ignored_then_clamp_near_t_block() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c.handle_tap()  # t=0 < D_entry 450 — ignored
	assert_false(c._fast_complete_active)
	c._process(0.5)     # 500 — CEREMONY
	c._process(0.625)   # 1125
	c._process(0.025)   # 1150
	c.handle_tap()      # S3 target = min(1150+100, 1200) = 1200 (clamp — D5)
	assert_eq(c._s3_entry_target_ms, 1200.0, "fast-complete never lands LATER than natural")
	c._process(0.05)    # 1200 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY)
	assert_eq(c._s3_entries, 1, "S3 side effects exactly once (same-frame race safe)")


func test_snap_window_is_not_zero_frame() -> void:
	var c: Node = _make()
	_open(c, "LEGENDARY")
	c._process(0.5)
	c.handle_tap()  # target 600
	assert_eq(c.get_fsm_state(), S.CEREMONY, "snap runs over SNAP_SEC — 0-frame is rollback-only")
	c._process(0.1)
	assert_eq(c.get_fsm_state(), S.STEADY)


# --- AC-37c: keyboard ui_accept == scrim tap (same handler, same policy) ---

func test_ui_accept_routes_through_the_same_per_stage_policy() -> void:
	var c: Node = _make()
	_open(c, "COMMON")
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	c._unhandled_input(accept)  # ENTRY — ignored
	assert_eq(c.get_fsm_state(), S.ENTRY, "keyboard obeys S0/S1 ignore")
	c._process(0.25)            # → STEADY (natural)
	c._unhandled_input(accept)  # dismiss
	assert_eq(c.get_fsm_state(), S.EXITING, "ui_accept == scrim tap at S3")
