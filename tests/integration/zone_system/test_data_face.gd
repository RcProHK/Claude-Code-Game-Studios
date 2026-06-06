extends GutTest
## Story 008 — #14 data face (AC-09 三件套嘅 a 半;b = combined gate 現有 evidence;
## c = story-done static grep:enemy_director.gd 零 ZoneSystem reference).

const ZoneSystemScript := preload("res://src/autoload/zone_system.gd")
const REGISTRY_PATH := "res://assets/data/zone_registry.tres"


func test_mvp_pool_is_unfiltered_sentinel() -> void:
	# AC-09a — the shipped MVP registry carries EMPTY pools: the unfiltered
	# sentinel. #14 additions are never silently filtered (G-Z-2 zero-churn).
	var sut: Node = ZoneSystemScript.new()
	sut._persistence = MockPersistenceLayer.new()
	sut._registry = load(REGISTRY_PATH)
	add_child_autofree(sut)
	var active: ZoneDef = sut.get_active_zone()
	assert_not_null(active)
	assert_true(active.wave_archetype_pool.is_empty(),
		"AC-09a: empty pool = UNFILTERED sentinel (MVP zero-churn)")
	assert_true(active.boss_pool.is_empty(), "boss pool carries the same sentinel")


func test_enemy_director_has_zero_zone_touchpoints() -> void:
	# AC-09c (static gate, automated form): #14 source must not reference
	# ZoneSystem in MVP (the v0.2 G-Z-2 read is a deliberate later amendment).
	var source: String = FileAccess.get_file_as_string("res://src/autoload/enemy_director.gd")
	assert_false(source.contains("ZoneSystem"),
		"AC-09c: MVP zero-churn — enemy_director.gd has no ZoneSystem reference")
