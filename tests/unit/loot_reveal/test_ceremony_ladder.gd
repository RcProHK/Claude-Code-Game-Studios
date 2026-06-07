extends GutTest
## Story 006 — ceremony ladder D2 調用序 + freeze anchors + EC-M4/M9 halves.
## Covers AC-8 / AC-10 / AC-12 / AC-13 / AC-14 / AC-55 / AC-60(watchdog 半 +
## margin formula;件距 wiring 半 → story 010).
##
## GDD: design/gdd/loot-drop-modal.md Rule 4 (D2 freeze-as-hold) / F1 / EC-M4 / EC-M9.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const ParticleWrapperScript := preload("res://src/autoload/particle_system_wrapper.gd")

const S := CoordinatorScript.ModalState
const T := LootEnums.RarityTier
const LOOT_BURST: int = ParticleWrapperScript.PresetId.LOOT_BURST
const LOOT_RARE_BURST: int = ParticleWrapperScript.PresetId.LOOT_RARE_BURST


class CallLog:
	extends RefCounted
	var entries: Array = []

	func names() -> Array:
		var out: Array = []
		for e: Dictionary in entries:
			out.append(e["call"])
		return out

	func first(call_name: String) -> Dictionary:
		for e: Dictionary in entries:
			if e["call"] == call_name:
				return e
		return {}

	func count(call_name: String) -> int:
		var n: int = 0
		for e: Dictionary in entries:
			if e["call"] == call_name:
				n += 1
		return n


class FakeParticles:
	extends Node
	var log: CallLog
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0) -> RefCounted:
		log.entries.append({"call": "play", "preset": preset_id, "pos": position, "mult": multiplier})
		return RefCounted.new()


class FakeAudio:
	extends Node
	var log: CallLog
	func play_sfx(event_id: StringName) -> void:
		log.entries.append({"call": "play_sfx", "event": event_id})


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
	func shake(intensity: float, duration: float) -> void:
		log.entries.append({"call": "shake", "intensity": intensity, "duration": duration})
	func apply_ceremony_saturation(drop: float, recovery_sec: float) -> void:
		log.entries.append({"call": "apply_ceremony_saturation", "drop": drop, "recovery": recovery_sec})


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 7  # LOOT_DROP
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
	func get_drop(_drop_id: String) -> LootDrop:
		return pending[0] if not pending.is_empty() else null


var _log: CallLog
var _gsm: MockGsm
var _loot: MockLootSystem
var _cam: FakeCamera
var _fx: FakeScreenEffects


func _drop(tier_name: String) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = "drop_%s" % tier_name.to_lower()
	d.rarity_tier = tier_name
	d.item_type = "WEAPON"
	d.source_event_kind = "MINI_BOSS"
	d.item_metadata = {"item_name": "Test Blade"}
	return d


func _make(motion_reduction: bool = false) -> Node:
	_log = CallLog.new()
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_cam = FakeCamera.new()
	_fx = FakeScreenEffects.new()
	var particles := FakeParticles.new()
	var audio := FakeAudio.new()
	for fake: Node in [particles, audio, _cam, _fx]:
		fake.log = _log
	add_child_autofree(_gsm)
	add_child_autofree(_loot)
	add_child_autofree(particles)
	add_child_autofree(audio)
	add_child_autofree(_cam)
	add_child_autofree(_fx)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._particles = particles
	c._audio = audio
	c._camera = _cam
	c._screen_effects = _fx
	c._motion_reduction = motion_reduction
	add_child_autofree(c)
	return c


func _open_with_tier(c: Node, tier_name: String) -> void:
	_loot.pending = [_drop(tier_name)]
	_gsm.enter_loot_drop()
	assert_true(c.is_modal_active(), "reveal opened for %s" % tier_name)


# --- AC-8: FR-2 structural — burst on the SAME call stack, preset per tier ---

func test_burst_fires_synchronously_with_correct_preset_per_tier() -> void:
	var expectations: Dictionary = {
		"COMMON": LOOT_BURST, "UNCOMMON": LOOT_BURST, "RARE": LOOT_BURST,
		"EPIC": LOOT_RARE_BURST, "LEGENDARY": LOOT_RARE_BURST,
	}
	for tier_name: String in expectations:
		var c: Node = _make()
		_open_with_tier(c, tier_name)
		# Synchronous: the call is already logged — no frame elapsed, no await.
		var burst: Dictionary = _log.first("play")
		assert_false(burst.is_empty(), "%s: burst left on the trigger call stack (FR-2)" % tier_name)
		assert_eq(burst["preset"], expectations[tier_name], "%s preset" % tier_name)
		var fanfare: Dictionary = _log.first("play_sfx")
		assert_eq(fanfare["event"], StringName("loot_fanfare_%s" % tier_name.to_lower()),
			"%s fanfare id — caller is the #21 coordinator (EG-1)" % tier_name)


func test_burst_multiplier_reads_config_per_tier() -> void:
	var c: Node = _make()
	_open_with_tier(c, "LEGENDARY")
	assert_eq(_log.first("play")["mult"], 3.0, "LEGENDARY 3× — #15 table via config, zero hardcode")


# --- AC-13: focal per-tier config (C/U none; R pulse; E/L focal == hold) ---

func test_common_and_uncommon_never_request_focal() -> void:
	for tier_name: String in ["COMMON", "UNCOMMON"]:
		var c: Node = _make()
		_open_with_tier(c, tier_name)
		assert_eq(_log.count("request_focal"), 0, "%s: no focal" % tier_name)


func test_rare_plus_focal_args_match_config() -> void:
	var expectations: Dictionary = {
		"RARE": [0.3, 1.02], "EPIC": [0.65, 1.05], "LEGENDARY": [0.8, 1.08],
	}
	for tier_name: String in expectations:
		var c: Node = _make()
		_open_with_tier(c, tier_name)
		assert_eq(_log.count("request_focal"), 1, "%s: exactly one focal request" % tier_name)
		var focal: Dictionary = _log.first("request_focal")
		assert_eq(focal["duration"], expectations[tier_name][0], "%s focal duration (config)" % tier_name)
		assert_eq(focal["zoom"], expectations[tier_name][1], "%s zoom (config)" % tier_name)


# --- AC-12: LEGENDARY D2 call order + freeze anchor + fallback ---

func test_legendary_call_order_burst_fanfare_focal_then_freeze_on_signal_then_shake() -> void:
	var c: Node = _make()
	_open_with_tier(c, "LEGENDARY")
	assert_eq(_log.names(), ["play", "play_sfx", "request_focal"], "frame-0 trio in order")
	c._process(0.5)  # into CEREMONY (entry 450)
	assert_eq(_log.count("ceremony_freeze"), 0, "freeze waits for focal_completed (D2)")
	_cam.finish_focal()
	var names: Array = _log.names()
	assert_eq(names.slice(3), ["ceremony_freeze", "shake", "apply_ceremony_saturation"],
		"freeze → shake → saturation after the peak")
	assert_eq(_log.first("ceremony_freeze")["duration"], 0.4, "freeze duration == #15 timestop (config)")
	assert_eq(_log.first("shake")["intensity"], 6.0, "LEG shake 6px (config)")
	assert_eq(_log.first("apply_ceremony_saturation")["drop"], 0.6, "−60% flat saturation")


func test_focal_never_completes_fallback_freezes_at_hold_plus_grace() -> void:
	var c: Node = _make()
	_open_with_tier(c, "LEGENDARY")
	c._process(0.5)   # 500 — CEREMONY
	c._process(0.375) # 875 < 800+200
	assert_eq(_log.count("ceremony_freeze"), 0, "before fallback window")
	c._process(0.25)  # 1125 ≥ 1000 → fallback
	assert_eq(_log.count("ceremony_freeze"), 1, "fallback freeze fired — queue never deadlocks (F1/EC-M9)")
	var found: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.focal_fallback":
			found = true
	assert_true(found, "telemetry loot_reveal.focal_fallback recorded")


func test_rare_freeze_is_clock_anchored_at_hold_end() -> void:
	var c: Node = _make()
	_open_with_tier(c, "RARE")
	c._process(0.375)  # 375 — CEREMONY (entry 300), pulse done, before hold end
	assert_eq(_log.count("ceremony_freeze"), 0, "no freeze before T=D_hold")
	c._process(0.125)  # 500 == hold → freeze
	assert_eq(_log.count("ceremony_freeze"), 1, "RARE freeze anchors at clock T=D_hold (no signal dependency)")
	assert_eq(_log.first("ceremony_freeze")["duration"], 0.15, "RARE timestop 0.15s")


# --- AC-10: content slots all-final at entry completion, zero content tweens ---

func test_content_slots_final_and_tween_free_when_scale_in_completes() -> void:
	var c: Node = _make()
	_open_with_tier(c, "EPIC")
	c._process(0.38)  # entry 380 done → CEREMONY
	assert_eq(c.get_fsm_state(), S.CEREMONY)
	assert_eq(c._content_slots["rarity_badge"], T.EPIC, "badge final")
	assert_eq(c._content_slots["item_icon"], "WEAPON", "icon final")
	assert_eq(c._content_slots["item_name"], "Test Blade", "name final")
	assert_eq(c._content_slots["source_attribution"], "MINI_BOSS", "source final")
	assert_eq(c._content_slots["dismiss_cta"], "影低佢", "CTA label (UX locked)")
	assert_eq(c._active_content_tweens, 0, "zero active content tweens — no staggered pop-in")


# --- AC-14: no auto-dismiss — S3 parks forever without input ---

func test_steady_never_auto_dismisses() -> void:
	var c: Node = _make()
	_open_with_tier(c, "COMMON")
	c._process(0.25)  # 250 ≥ entry 150 → CEREMONY; ≥ T_block 200 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY)
	for i: int in range(60):
		c._process(1.0)  # 60 simulated seconds
	assert_eq(c.get_fsm_state(), S.STEADY, "modal still open after 60s — dismiss is the player's act")
	assert_eq(_log.count("play"), 1, "no replay / no scheduled dismissal side effects")


# --- AC-55: EC-M4 motion_reduction matrix (ladder-call half) ---

func test_motion_reduction_matrix_suppresses_focal_shake_freeze_halves_particles() -> void:
	for tier_name: String in ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]:
		var c: Node = _make(true)
		_open_with_tier(c, tier_name)
		# drive far past every window — nothing freeze/focal/shake may fire
		_cam.finish_focal()
		for i: int in range(4):
			c._process(0.5)
		assert_eq(_log.count("request_focal"), 0, "%s: zero focal (EC-M4 — fade-in vignette path)" % tier_name)
		assert_eq(_log.count("ceremony_freeze"), 0, "%s: zero freeze" % tier_name)
		assert_eq(_log.count("shake"), 0, "%s: zero shake" % tier_name)
		assert_eq(_log.count("apply_ceremony_saturation"), 0, "%s: zero saturation" % tier_name)
		var burst: Dictionary = _log.first("play")
		assert_false(burst.is_empty(), "%s: burst still fires — ceremony survives, density halves" % tier_name)
		assert_eq(c.get_fsm_state(), S.STEADY, "%s: timeline completes (hold preserved)" % tier_name)


func test_motion_reduction_particle_multiplier_is_halved() -> void:
	var c: Node = _make(true)
	_open_with_tier(c, "LEGENDARY")
	assert_eq(_log.first("play")["mult"], 1.5, "LEG 3.0 × 0.5 = 1.5 (EC-M4)")


# --- AC-60 margin formula half (EC-M9 — wiring lands in story 010) ---

func test_successor_gap_formula() -> void:
	var config := LootRevealTimingConfig.new()
	assert_eq(LootRevealFormulas.successor_gap_sec(config, T.COMMON), 0.3, "prev COMMON → plain gap")
	assert_eq(LootRevealFormulas.successor_gap_sec(config, T.RARE), 0.3, "prev RARE → plain gap")
	assert_eq(LootRevealFormulas.successor_gap_sec(config, T.EPIC), 0.6, "prev EPIC → focal exit margin")
	assert_eq(LootRevealFormulas.successor_gap_sec(config, T.LEGENDARY), 0.6, "prev LEG → focal exit margin")


# --- EC-M5 coercion happens BEFORE ladder lookup (cross-pin; full AC-56 in 009) ---

func test_unknown_tier_coerces_to_common_before_ladder() -> void:
	var c: Node = _make()
	_open_with_tier(c, "MYTHIC")
	assert_eq(_log.first("play")["preset"], LOOT_BURST, "COMMON ceremony preset")
	assert_eq(_log.count("request_focal"), 0, "COMMON ladder — no focal")
	var found: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.unknown_tier":
			found = true
	assert_true(found, "telemetry loot_reveal.unknown_tier recorded")
