## G-IU-5 shards thousands-separator formatter — unit goldens(story 017;D6)。
## #22/#23 shared contract — InventorySystem.format_shards 係唯一 locus。
extends GutTest

const InventoryScript := preload("res://src/autoload/inventory_system.gd")


func test_format_shards_goldens() -> void:
	# Arrange/Act/Assert: 千位逗號 binary-exact(AC golden 系列)。
	assert_eq(InventoryScript.format_shards(0), "0")
	assert_eq(InventoryScript.format_shards(999), "999")
	assert_eq(InventoryScript.format_shards(1000), "1,000")
	assert_eq(InventoryScript.format_shards(1400), "1,400")
	assert_eq(InventoryScript.format_shards(1234567), "1,234,567")


func test_format_shards_negative_boundary() -> void:
	# 邊界:負數(理論上 shards 唔會負 — formatter 防禦性正確)。
	assert_eq(InventoryScript.format_shards(-1234), "-1,234")
	assert_eq(InventoryScript.format_shards(-1), "-1")


func test_shared_contract_both_coordinators_use_formatter() -> void:
	# Locus assert:#22 + #23 coordinator source 都行 format_shards
	#(shared contract — 唔係各自 str())。
	var src22: String = FileAccess.get_file_as_string(
		"res://src/autoload/character_screen_coordinator.gd")
	var src23: String = FileAccess.get_file_as_string(
		"res://src/autoload/inventory_ui_coordinator.gd")
	assert_true("format_shards" in src22, "#22 行 shared formatter(一行 churn)")
	assert_true("format_shards" in src23, "#23 行 shared formatter")
