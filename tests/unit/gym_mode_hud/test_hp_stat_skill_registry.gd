## Unit test — GymModeHud Story 004: HP (non-depleting) + SkillIconRegistry sort + cluster cap
##
## Coverage:
##   AC-CR-12 HP   — HP bound to MAX_HP (non-depleting); MAX_HP grow → value steps up
##   AC-CR-12 sort — cluster sorted (tier_ordinal DESC, class_ordinal ASC), top-cap, "+N" overflow,
##                   insertion-order-agnostic
##   AC-CR-13⑨    — anti-Stagnation: strongest tier wins slot, not oldest insertion order
##   AC-UX-4       — empty ability set → empty cluster (no crash); HP NaN first-frame → 0.0 fallback
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


class _StubStatSystem:
	extends RefCounted
	signal stat_changed(stat_id: StringName, old_value: float, new_value: float, source: int, is_initial: bool)

	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)

	func emit_stat_changed(stat_id: StringName, new_val: float) -> void:
		stat_changed.emit(stat_id, 0.0, new_val, 0, false)


func _make_sut() -> SUT:
	var sut: SUT = SUT.new()
	sut._stat_system = _StubStatSystem.new()
	add_child_autofree(sut)
	return sut


# ── AC-CR-12: HP non-depleting bound to MAX_HP ──

func test_hp_binds_to_max_hp() -> void:
	var sut := _make_sut()
	var stub := sut._stat_system as _StubStatSystem
	stub.emit_stat_changed(&"max_hp", 160.0)
	assert_eq(sut.get_hp_max_value(), 160.0,
		"AC-CR-12: HP value bound to MAX_HP (160)")


func test_hp_steps_up_when_max_hp_grows() -> void:
	var sut := _make_sut()
	var stub := sut._stat_system as _StubStatSystem
	stub.emit_stat_changed(&"max_hp", 160.0)
	stub.emit_stat_changed(&"max_hp", 210.0)  # leveled VIT → MAX_HP grows
	assert_eq(sut.get_hp_max_value(), 210.0,
		"AC-CR-12: HP steps up to new MAX_HP (non-depleting, only grows on stat change)")


func test_hp_default_is_zero_not_nan() -> void:
	var sut := _make_sut()
	assert_eq(sut.get_hp_max_value(), 0.0,
		"AC-UX-4: HP first-frame default is 0.0 (non-NaN)")


func test_hp_nan_sanitised_to_zero() -> void:
	var sut := _make_sut()
	var stub := sut._stat_system as _StubStatSystem
	stub.emit_stat_changed(&"max_hp", NAN)
	assert_eq(sut.get_hp_max_value(), 0.0,
		"AC-UX-4: MAX_HP NaN → 0.0 fallback (no NaN display)")


# ── AC-CR-12: cluster sort (tier DESC, class ASC) ──

func test_cluster_sort_tier_desc_class_asc() -> void:
	var sut := _make_sut()
	# Mixed-tier fixture from QA test cases.
	var ids: Array = [
		&"strike_tier_1_jab",      # tier0 class0
		&"control_tier_3_grapple", # tier2 class1
		&"mobility_tier_2_leap",   # tier1 class2
		&"strike_tier_3_overhand", # tier2 class0
		&"control_tier_1_parry",   # tier0 class1
	]
	var result: Array = sut.get_skill_cluster_display(ids, 4)
	var expected: Array = [
		&"strike_tier_3_overhand", # tier2 class0
		&"control_tier_3_grapple", # tier2 class1
		&"mobility_tier_2_leap",   # tier1 class2
		&"strike_tier_1_jab",      # tier0 class0
	]
	assert_eq(result, expected,
		"AC-CR-12: cluster sorted tier_ordinal DESC then class_ordinal ASC, top 4")


func test_cluster_overflow_count() -> void:
	var sut := _make_sut()
	var ids: Array = [
		&"strike_tier_1_jab", &"control_tier_3_grapple", &"mobility_tier_2_leap",
		&"strike_tier_3_overhand", &"control_tier_1_parry",
	]
	assert_eq(sut.get_skill_overflow_count(ids, 4), 1,
		"AC-CR-12: 5 abilities, cap 4 → overflow +1")


func test_cluster_insertion_order_agnostic() -> void:
	var sut := _make_sut()
	var ids_a: Array = [
		&"strike_tier_1_jab", &"control_tier_3_grapple", &"mobility_tier_2_leap",
		&"strike_tier_3_overhand", &"control_tier_1_parry",
	]
	# Same set, different insertion order — must yield identical result (L413 agnostic).
	var ids_b: Array = [
		&"control_tier_1_parry", &"strike_tier_3_overhand", &"strike_tier_1_jab",
		&"mobility_tier_2_leap", &"control_tier_3_grapple",
	]
	assert_eq(sut.get_skill_cluster_display(ids_a, 4), sut.get_skill_cluster_display(ids_b, 4),
		"AC-CR-12: cluster result identical regardless of input iteration order")


func test_cluster_tie_tier_breaks_by_class_asc() -> void:
	var sut := _make_sut()
	# All tier 3 → must order strike(0) < control(1) < mobility(2).
	var ids: Array = [
		&"mobility_tier_3_ground_pound", # class2
		&"control_tier_3_grapple",       # class1
		&"strike_tier_3_overhand",       # class0
	]
	var result: Array = sut.get_skill_cluster_display(ids, 4)
	assert_eq(result, [&"strike_tier_3_overhand", &"control_tier_3_grapple", &"mobility_tier_3_ground_pound"],
		"AC-CR-12: same-tier tie broken by class_ordinal ASC")


# ── AC-CR-13⑨: anti-Stagnation ──

func test_strongest_tier_wins_slot_not_oldest() -> void:
	var sut := _make_sut()
	# Old T1 (inserted first) + new T3 (inserted last), cap 1 → must show T3, not T1.
	var ids: Array = [&"strike_tier_1_jab", &"strike_tier_3_overhand"]
	var result: Array = sut.get_skill_cluster_display(ids, 1)
	assert_eq(result, [&"strike_tier_3_overhand"],
		"AC-CR-13⑨: cluster shows strongest (T3), never oldest insertion (T1) holding the slot")


# ── AC-UX-4: empty / unknown handling ──

func test_empty_ability_set_returns_empty_cluster() -> void:
	var sut := _make_sut()
	assert_eq(sut.get_skill_cluster_display([], 4), [],
		"AC-UX-4: empty ability set → empty cluster (no crash, no void)")
	assert_eq(sut.get_skill_overflow_count([], 4), 0,
		"AC-UX-4: empty set → 0 overflow")


func test_unknown_ability_id_ignored() -> void:
	var sut := _make_sut()
	var ids: Array = [&"strike_tier_3_overhand", &"not_a_real_ability"]
	var result: Array = sut.get_skill_cluster_display(ids, 4)
	assert_eq(result, [&"strike_tier_3_overhand"],
		"AC-UX-4: unmapped ability_id ignored (no crash on unknown id)")
