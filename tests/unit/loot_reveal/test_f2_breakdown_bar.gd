extends GutTest
## Story 008 — F2 breakdown bar 幾何 + INV-M2 + EC-M15 + EC-M12.
## Covers AC-3 / AC-42 / AC-43 / AC-44 / AC-45 / AC-63 / AC-66.
##
## GDD: design/gdd/loot-drop-modal.md F2 / EC-M15 / EC-M12. ADR-0005 binding.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

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


class FakeParticles:
	extends Node
	var log: CallLog
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0) -> RefCounted:
		log.entries.append({"call": "play", "preset": preset_id, "pos": position, "mult": multiplier})
		return RefCounted.new()


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


func _geo(ws: float, rr: float, score: float, w_bar: int) -> Dictionary:
	return LootRevealFormulas.breakdown_geometry(ws, rr, score, w_bar)


func _drop_with_breakdown(tier_name: String, ws: float, rr: float, score: float) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = "drop_bd"
	d.rarity_tier = tier_name
	d.item_metadata = {"workout_score": ws, "rng_roll": rr, "rarity_score": score}
	return d


func _make() -> Node:
	_log = CallLog.new()
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	var particles := FakeParticles.new()
	particles.log = _log
	for n: Node in [_gsm, _loot, particles]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._particles = particles
	add_child_autofree(c)
	return c


# --- AC-42: identities + honest endpoints ---

func test_golden_vector_worst_case_rare_floor() -> void:
	var g: Dictionary = _geo(0.40, 1.0, 0.55, 160)
	assert_eq(g["px_w"], 87, "px_w golden")
	assert_eq(g["px_r"], 73, "px_r golden")
	assert_eq(g["pct_w"], 55, "pct_w golden (54.5 → round-half-up 55)")
	assert_eq(g["pct_r"], 45, "pct sum closure")


func test_legal_sweep_invariants_sum_and_pct_band() -> void:
	for ws_i: int in range(0, 11):
		for rr_i: int in range(0, 11):
			var ws: float = ws_i / 10.0
			var rr: float = rr_i / 10.0
			var score: float = 0.75 * ws + 0.25 * rr
			if score < 0.55:
				continue
			var g: Dictionary = _geo(ws, rr, score, 160)
			assert_eq(g["px_w"] + g["px_r"], 160, "px sum invariant")
			assert_eq(g["pct_w"] + g["pct_r"], 100, "pct sum == 100")
			if ws > 0.0 and rr > 0.0:
				assert_between(g["pct_w"], 1, 99, "both contribs > 0 ⇒ pct ∈ [1,99]")


func test_honest_endpoints_true_zero_vs_clamped() -> void:
	var true_zero: Dictionary = _geo(0.8, 0.0, 0.6, 160)
	assert_eq(true_zero["pct_w"], 100, "rr 真零 → 100/0 係真 claim")
	assert_eq(true_zero["pct_r"], 0)
	var near_zero: Dictionary = _geo(1.0, 0.01, 0.7525, 160)
	assert_eq(near_zero["pct_w"], 99, "rr=0.01 → clamp 99/1 — 唔准顯示「運氣 0%」")
	assert_eq(near_zero["px_w"] + near_zero["px_r"], 160, "Pass 2 closure — px invariant after clamp")
	assert_gte(near_zero["px_r"], 1, "rng segment ≥ 1px when contrib_r > 0")


# --- AC-3: INV-M2 strict + naive delta ≥ 8px ---

func test_inv_m2_workout_segment_strictly_larger_sweep() -> void:
	for w_bar: int in [120, 160]:
		for ws_i: int in range(0, 21):
			for rr_i: int in range(0, 21):
				var ws: float = ws_i / 20.0
				var rr: float = rr_i / 20.0
				var score: float = 0.75 * ws + 0.25 * rr
				if score < 0.55:
					continue
				var g: Dictionary = _geo(ws, rr, score, w_bar)
				assert_gt(g["px_w"], g["px_r"], "INV-M2 strict @ ws=%s rr=%s w=%d" % [ws, rr, w_bar])
				assert_gte(g["px_w"] - g["px_r"], 8, "naive delta ≥ 8px @ legal grid")


# --- AC-43: floor clause unreachable for legal input (param on W_BAR_MIN) ---

func test_floor_clause_only_fires_on_corrupt_input() -> void:
	# Legal worst case at the knob's critical lower bound 88px:
	var critical: Dictionary = _geo(0.40, 1.0, 0.55, 88)
	assert_gte(critical["px_w"] - critical["px_r"], 8, "88px = 8px-delta 臨界 — legal input 唔觸 floor")
	# Corrupt: score inflated relative to contribs squeezes frac_w toward 50% —
	# identity gate would hide this upstream; geometry's floor is the last line.
	var corrupt: Dictionary = _geo(0.37, 1.0, 0.55, 160)  # frac_w ≈ 0.5045
	assert_gte(corrupt["px_w"] - corrupt["px_r"], 8, "floor clause enforces min delta on corrupt input")


# --- AC-44: display gate ---

func test_narrow_bar_stacks_text_only_with_pct_intact() -> void:
	var g: Dictionary = _geo(0.40, 1.0, 0.55, 100)
	assert_true(g["stacked"], "W_bar < W_BAR_MIN → stacked text-only variant")
	assert_eq(g["pct_w"] + g["pct_r"], 100, "% labels survive — zero info loss")


# --- EC-M15 gate (formula half) ---

func test_visibility_gate_identity_and_tier_consistency() -> void:
	var rc := LootRarityConfig.new()
	assert_true(LootRevealFormulas.breakdown_visible(0.40, 1.0, 0.55, LootEnums.RarityTier.RARE, rc), "legal RARE visible")
	assert_false(LootRevealFormulas.breakdown_visible(0.40, 1.0, 0.70, LootEnums.RarityTier.RARE, rc), "identity 違反 > 0.001 → hide")
	assert_false(LootRevealFormulas.breakdown_visible(0.60, 0.40, 0.55, LootEnums.RarityTier.EPIC, rc), "score 0.55 < EPIC threshold 0.72 → 信 tier 隱藏 bar")
	assert_false(LootRevealFormulas.breakdown_visible(0.40, 1.0, 0.55, LootEnums.RarityTier.COMMON, rc), "sub-RARE never shows")


# --- AC-45 / AC-66: coordinator slot wiring ---

func test_common_and_uncommon_have_no_breakdown_slot() -> void:
	for tier_name: String in ["COMMON", "UNCOMMON"]:
		var c: Node = _make()
		_loot.pending = [_drop_with_breakdown(tier_name, 0.4, 1.0, 0.55)]
		_gsm.enter_loot_drop()
		assert_null(c._content_slots["breakdown_bar"], "%s: bar node 不存在" % tier_name)


func test_rare_with_valid_metadata_gets_geometry() -> void:
	var c: Node = _make()
	_loot.pending = [_drop_with_breakdown("RARE", 0.40, 1.0, 0.55)]
	_gsm.enter_loot_drop()
	var slot: Variant = c._content_slots["breakdown_bar"]
	assert_not_null(slot)
	assert_eq(slot["px_w"], 87, "slot carries F2 geometry @ default 160px")


func test_corrupt_input_clamps_then_gates_with_telemetry() -> void:
	var c: Node = _make()
	# ws=1.4 clamps to 1.0; score must match the CLAMPED identity to be legal.
	_loot.pending = [_drop_with_breakdown("RARE", 1.4, 1.0, 1.0)]
	_gsm.enter_loot_drop()
	assert_not_null(c._content_slots["breakdown_bar"], "clamp-on-read happens BEFORE the identity gate")
	# Identity violation → hide + telemetry.
	var c2: Node = _make()
	_loot.pending = [_drop_with_breakdown("RARE", 0.40, 1.0, 0.90)]
	_gsm.enter_loot_drop()
	assert_null(c2._content_slots["breakdown_bar"], "identity mismatch → bar hidden, tier 照行")
	var found: bool = false
	for entry: Dictionary in c2.get_telemetry():
		if entry["event"] == "loot_reveal.breakdown_mismatch":
			found = true
	assert_true(found, "telemetry breakdown_mismatch")


func test_missing_metadata_fields_hide_bar() -> void:
	var c: Node = _make()
	var d := LootDrop.new()
	d.rarity_tier = "EPIC"
	d.item_metadata = {}  # legacy record — G-LM-4a 未補 keys
	_loot.pending = [d]
	_gsm.enter_loot_drop()
	assert_null(c._content_slots["breakdown_bar"], "missing fields → hide (EC-M15 path)")


# --- AC-63: EC-M12 resize ---

func test_resize_relayouts_geometry_without_touching_timers_or_particles() -> void:
	var c: Node = _make()
	_loot.pending = [_drop_with_breakdown("RARE", 0.40, 1.0, 0.55)]
	_gsm.enter_loot_drop()
	c._process(0.35)  # mid-ceremony
	var clock_before: float = c.get_reveal_clock_ms()
	var play_before: int = _log.count("play")
	c.on_viewport_resized(100)
	var slot: Variant = c._content_slots["breakdown_bar"]
	assert_true(slot["stacked"], "resize below W_BAR_MIN → stacked variant in one frame")
	assert_eq(c.get_reveal_clock_ms(), clock_before, "timers time-based — resize 唔 reset")
	assert_eq(_log.count("play"), play_before, "particle 唔 replay")
