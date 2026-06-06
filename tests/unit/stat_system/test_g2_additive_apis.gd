# StatSystem — #17 G-2 additive APIs (cross-epic Story 009) Unit Tests.
#
# Scope (stat-system.md 2026-06-06 G-2 amendments, L228 + L267):
#   - is_boot_completed(): sync getter — true after _ready() boot reconciliation.
#     WHY: ADR-0006 Contract 4 — autoloads after StatSystem enter the tree after
#     boot_completed has already fired; awaiting the signal hangs forever. #17
#     InventorySystem asserts this getter at its own boot instead.
#   - get_attack_power_excluding_equipment(): ATK_BASE + STR×ATK_PER_STR +
#     DEX×ATK_PER_DEX from the _base dict ONLY — an applied equipment modifier
#     must NOT change the result (AntiSnowball cap base; single source of truth,
#     #17 forbidden from re-deriving inline).
#
# Golden: fresh-account default (STR=DEX=10 @ ATK_BASE=10/PER_STR=1.5/PER_DEX=0.3)
# = 28.0 — the #17 GDD whole-doc baseline (cap = max(30, 3×28) = 84).
#
# Framework: GUT v9.x
# Driving GDD: design/gdd/stat-system.md (G-2) + design/gdd/equipment-inventory.md Formula 4
# Story: production/epics/equipment-inventory/story-009-stat-system-g2-apis.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm


func _boot() -> void:
	add_child_autofree(_sut)  # _ready() → READY (fresh account STR=DEX=VIT=10)


# ─── is_boot_completed() ───────────────────────────────────────────────────────


func test_is_boot_completed_false_before_ready() -> void:
	# Arrange — constructed but not yet in tree (no _ready)

	# Act / Assert
	assert_false(_sut.is_boot_completed(),
		"pre-boot StatSystem must report is_boot_completed() == false")
	_boot()  # cleanup path: ensure node is freed via autofree


func test_is_boot_completed_true_after_ready() -> void:
	# Arrange / Act
	_boot()

	# Assert
	assert_true(_sut.is_boot_completed(),
		"post-_ready() StatSystem must report is_boot_completed() == true")


# ─── get_attack_power_excluding_equipment() ────────────────────────────────────


func test_excluding_equipment_fresh_account_golden_28() -> void:
	# Arrange — fresh account: STR=DEX=10 @ default knobs
	_boot()

	# Act
	var sda: float = _sut.get_attack_power_excluding_equipment()

	# Assert — 10 + 10×1.5 + 10×0.3 = 28.0 (#17 whole-doc baseline)
	assert_almost_eq(sda, 28.0, 0.0001)


func test_excluding_equipment_unaffected_by_equipment_modifier() -> void:
	# Arrange — apply the #17 aggregate modifier (the exact pollution vector)
	_boot()
	var modifier = StatSystem.StatModifier.new()
	modifier.deltas = { &"ATTACK_POWER": 50.0, &"MAX_HP": 160.0 }
	_sut.apply_equipment_modifier(&"equipment_aggregate", modifier)

	# Act
	var sda: float = _sut.get_attack_power_excluding_equipment()

	# Assert — modifier table must not leak into the cap base
	assert_almost_eq(sda, 28.0, 0.0001)


func test_excluding_equipment_tracks_base_stat_growth() -> void:
	# Arrange — STR 10→30 via the exempt DEBUG_OVERRIDE source
	_boot()
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 20.0)

	# Act
	var sda: float = _sut.get_attack_power_excluding_equipment()

	# Assert — 10 + 30×1.5 + 10×0.3 = 58.0
	assert_almost_eq(sda, 58.0, 0.0001)


func test_excluding_equipment_matches_get_stat_when_no_equipment() -> void:
	# Arrange — with an empty modifier table the two reads must agree
	# (ATTACK_POWER floor at 1 never binds at fresh-account values)
	_boot()

	# Act / Assert
	assert_almost_eq(
		_sut.get_attack_power_excluding_equipment(),
		_sut.get_stat(&"ATTACK_POWER"),
		0.0001)
