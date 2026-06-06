extends GutTest
## Story 013 — #12 reverse-wire integration (AC-21).
## A REAL AbilitySystem instance receives pr_breakthrough exactly once via the
## G-PR-4 pinned handler, and the unlock lands under the PR provenance route.

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")
const AbilitySystemScript := preload("res://src/autoload/ability_system.gd")


class MockStat:
	extends RefCounted
	var stat_value: float = 12.0  # clears STRIKE T1 (threshold 10)

	func get_stat(_stat_id: StringName) -> float:
		return stat_value

	func apply_stat_delta(_s: StringName, _src: int, _d: float) -> bool:
		return true


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0  # STRIKE → &"str"


func test_real_ability_system_receives_exactly_once_and_unlocks_via_path_a() -> void:
	# Arrange — a real (un-parented) AbilitySystem forced READY with mocks.
	var ability = AbilitySystemScript.new()
	ability._persistence = MockPersistenceLayer.new()
	ability._stat_system = MockStat.new()
	ability._substate = AbilitySystemScript.Substate.READY
	autofree(ability)

	var sut: Node = PrDetectionScript.new()
	sut._persistence = MockPersistenceLayer.new()
	sut._stat_system = MockStat.new()
	sut._class_mapping = MockClassMapping.new()
	# G-PR-4 reverse-wire: #18 connects its OWN signal into the pinned handler.
	sut._ability_handler = Callable(ability, "_on_pr_breakthrough")
	add_child_autofree(sut)
	sut._pr_state.baselines["bench_press"] = 70.0

	# Act — one confirmed PR (STR).
	sut._on_set_logged("bench_press", 5, 65.0)

	# Assert — STRIKE T1 unlocked through Path A (PR provenance route).
	assert_true(ability.get_ability_state(ability.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-21: the real #12 receives the reverse-wired emit and unlocks via Path A")
	# Exactly once: the unlock table holds exactly the cleared tier (no double-path
	# duplicate — G-PR-5 keeps Path B silent for PR-sourced changes).
	assert_eq(ability.get_unlocked_abilities().size(), 1, "exactly one unlock — no double-path")


func test_default_seam_resolves_the_pinned_autoload_handler() -> void:
	# The default seam resolution targets /root/AbilitySystem._on_pr_breakthrough
	# (the shipped pinned entry point). With no injection, boot must wire it.
	var sut: Node = PrDetectionScript.new()
	sut._persistence = MockPersistenceLayer.new()
	add_child_autofree(sut)
	assert_true(sut._ability_handler.is_valid(),
		"default seams must pin AbilitySystem._on_pr_breakthrough (G-PR-4)")
	assert_false(sut.pr_breakthrough.get_connections().is_empty(),
		"pr_breakthrough must be reverse-wired by end of _ready")
