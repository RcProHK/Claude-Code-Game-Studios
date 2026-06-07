## #23 slot filter predicate — unit suite(story 004;AC-02;GDD Rule 8)。
extends GutTest

const InvUiFormulas := preload("res://src/ui/inventory_ui/inv_ui_formulas.gd")


func test_filter_all_passes_every_slot() -> void:
	for slot in [
		EquipmentEnums.EquipSlot.WEAPON,
		EquipmentEnums.EquipSlot.ARMOR,
		EquipmentEnums.EquipSlot.ACCESSORY,
		EquipmentEnums.EquipSlot.COSMETIC,
	]:
		assert_true(InvUiFormulas.matches_filter(slot, InvUiFormulas.FILTER_ALL),
			"ALL chip 全 pass(slot %d)" % slot)


func test_filter_chip_passes_matching_slot_only() -> void:
	# Arrange/Act/Assert: 單一 equality predicate(slot_affinity == chip)。
	assert_true(InvUiFormulas.matches_filter(
		EquipmentEnums.EquipSlot.WEAPON, EquipmentEnums.EquipSlot.WEAPON))
	assert_false(InvUiFormulas.matches_filter(
		EquipmentEnums.EquipSlot.ARMOR, EquipmentEnums.EquipSlot.WEAPON))
	assert_false(InvUiFormulas.matches_filter(
		EquipmentEnums.EquipSlot.COSMETIC, EquipmentEnums.EquipSlot.ACCESSORY))
	assert_true(InvUiFormulas.matches_filter(
		EquipmentEnums.EquipSlot.COSMETIC, EquipmentEnums.EquipSlot.COSMETIC))


func test_filter_value_unchanged_by_predicate() -> void:
	# Arrange: predicate 係 pure static — filter 值不變(AC-02「filter 值不變」)。
	var chip: int = EquipmentEnums.EquipSlot.WEAPON
	InvUiFormulas.matches_filter(EquipmentEnums.EquipSlot.ARMOR, chip)
	InvUiFormulas.matches_filter(EquipmentEnums.EquipSlot.WEAPON, chip)
	assert_eq(chip, EquipmentEnums.EquipSlot.WEAPON, "predicate 唔 mutate chip 值")
