extends GutTest
## Story 010 — BannerStack main-slot total-order comparator. Covers AC-29 (severity
## order) + AC-29b (same-severity deterministic tie-break by arrival_sequence).
##
## GDD: Rule 7. The slot is chosen by (priority_weight desc, arrival_sequence asc) —
## NOT sort_custom (4.6-unstable) and NOT StringName sort (pointer order).

const BannerStackScript := preload("res://src/ui/login_shell/banner_stack.gd")
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")


func _make() -> Node:
	var s: Node = BannerStackScript.new()
	add_child_autofree(s)
	return s


# --- AC-29: severity order — ONGOING outranks FEATURE_DEGRADED ---

func test_ac29_ongoing_wins_main_slot_over_feature_degraded() -> void:
	var s := _make()
	# Same-frame: #8 FEATURE_DEGRADED first, then #3 ONGOING.
	s.dispatch_error(ESM.Source.STREAK, &"X", "s")
	s.dispatch_error(ESM.Source.PERSISTENCE, &"READ_ONLY_FILESYSTEM", "p")
	var main: Dictionary = s.main_slot()
	assert_eq(main["severity"], ESM.Severity.ONGOING, "AC-29: main slot = ONGOING (severity order, not arrival)")
	assert_eq(s.overflow_count(), 1, "FEATURE_DEGRADED goes to「+N」(count 1)")


func test_ac29_arrival_order_does_not_override_severity() -> void:
	var s := _make()
	# ONGOING arrives FIRST, FEATURE_DEGRADED second — ONGOING still holds the slot.
	s.dispatch_error(ESM.Source.PERSISTENCE, &"QUOTA_EXHAUSTED", "p")
	s.dispatch_error(ESM.Source.STAT, &"strength", null)
	assert_eq(s.main_slot()["severity"], ESM.Severity.ONGOING, "higher severity holds slot regardless of arrival")


# --- AC-29b: same-class deterministic tie-break by arrival_sequence ---

func test_ac29b_same_class_tiebreak_by_arrival_sequence() -> void:
	var s := _make()
	# #11 then #12 — both FEATURE_DEGRADED. The FIRST-arrived holds the slot.
	s.dispatch_error(ESM.Source.STAT, &"strength", "stat_first")
	s.dispatch_error(ESM.Source.ABILITY, &"fireball", "ability_second")
	var main: Dictionary = s.main_slot()
	assert_eq(main["arrival_sequence"], 1, "AC-29b: earliest arrival_sequence holds the slot")
	assert_eq(main["source"], ESM.Source.STAT, "the #11 banner (arrived first) is the main slot")


func test_ac29b_deterministic_across_repeated_runs() -> void:
	# Same inputs → same main slot every time (the determinism guarantee — no pointer sort).
	for _i in range(5):
		var s := _make()
		s.dispatch_error(ESM.Source.STAT, &"zzz", "z")     # arrival 1
		s.dispatch_error(ESM.Source.ABILITY, &"aaa", "a")  # arrival 2
		assert_eq(s.main_slot()["arrival_sequence"], 1, "run %d: deterministic — arrival 1 always wins" % _i)


func test_empty_stack_main_slot_is_empty() -> void:
	var s := _make()
	assert_eq(s.main_slot(), {}, "empty stack → empty main slot")
	assert_eq(s.overflow_count(), 0, "no overflow")


func test_arrival_sequence_is_monotonic() -> void:
	var s := _make()
	s.dispatch_error(ESM.Source.STREAK, &"a", "1")
	s.dispatch_error(ESM.Source.STREAK, &"b", "2")
	s.dispatch_error(ESM.Source.STREAK, &"c", "3")
	assert_eq(s.entries()[0]["arrival_sequence"], 1, "first = 1")
	assert_eq(s.entries()[1]["arrival_sequence"], 2, "second = 2")
	assert_eq(s.entries()[2]["arrival_sequence"], 3, "monotonic +1")
