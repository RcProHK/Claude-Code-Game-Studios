extends GutTest
## Story 001 — registry resources + validation (AC-07) + shipped .tres smoke.

const ZoneSystemScript := preload("res://src/autoload/zone_system.gd")
const REGISTRY_PATH := "res://assets/data/zone_registry.tres"


func _zone(id: StringName, kind: int, threshold: int) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = id
	var c := ZoneUnlockCondition.new()
	c.kind = kind
	c.threshold = threshold
	z.unlock_condition = c
	return z


func _registry(zones: Array) -> ZoneRegistryData:
	var r := ZoneRegistryData.new()
	for z: ZoneDef in zones:
		r.zones.append(z)
	return r


var _sut: Node


func before_each() -> void:
	_sut = ZoneSystemScript.new()
	autofree(_sut)


# --- AC-07: four invalid vectors → validate false (no raw assert) -------------------

func test_duplicate_zone_id_fails() -> void:
	var r := _registry([
		_zone(&"a", ZoneUnlockCondition.Kind.ALWAYS, 0),
		_zone(&"a", ZoneUnlockCondition.Kind.WORKOUT_COUNT, 5)])
	assert_false(_sut.validate_registry(r))


func test_zero_entries_fails() -> void:
	assert_false(_sut.validate_registry(_registry([])))
	assert_false(_sut.validate_registry(null))


func test_zero_threshold_fails() -> void:
	var r := _registry([_zone(&"a", ZoneUnlockCondition.Kind.WORKOUT_COUNT, 0)])
	assert_false(_sut.validate_registry(r))


func test_unknown_kind_fails() -> void:
	var r := _registry([_zone(&"a", ZoneUnlockCondition.Kind.UNKNOWN, 5)])
	assert_false(_sut.validate_registry(r),
		"ADR-0007: UNKNOWN kind is a config error, never a default")


func test_valid_registry_passes() -> void:
	var r := _registry([
		_zone(&"a", ZoneUnlockCondition.Kind.ALWAYS, 0),
		_zone(&"b", ZoneUnlockCondition.Kind.WORKOUT_COUNT, 20)])
	assert_true(_sut.validate_registry(r))


# --- shipped .tres headless load smoke (typed-array-of-script-class first use) -------

func test_shipped_registry_tres_loads_and_validates() -> void:
	var registry: ZoneRegistryData = load(REGISTRY_PATH)
	assert_not_null(registry, "zone_registry.tres must load headlessly")
	assert_eq(registry.zones.size(), 1, "MVP registry = 1 entry")
	var zone: ZoneDef = registry.zones[0]
	assert_eq(zone.zone_id, &"zone_verdant_forest")
	assert_eq(zone.unlock_condition.kind, ZoneUnlockCondition.Kind.ALWAYS)
	assert_true(zone.wave_archetype_pool.is_empty(), "empty pool = UNFILTERED sentinel")
	assert_true(_sut.validate_registry(registry))
