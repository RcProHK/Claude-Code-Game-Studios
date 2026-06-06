extends GutTest
## Story 003 — zone.state envelope round-trip (AC-08) + corrupt vectors (AC-04).
## Round-trip forced through JSON.stringify → parse_string (the #3 disk path) —
## typed Array[StringName] rebuild is the codebase's first typed-array round-trip.

const ZoneSystemScript := preload("res://src/autoload/zone_system.gd")


func _populated() -> ZoneState:
	var s := ZoneState.new()
	s.workout_count = 23
	s.last_counted_transition_id = "txn-rt"
	s.last_counted_date = "2026-06-06"
	s.unlocked_zone_ids = [&"zone_two", &"zone_three"] as Array[StringName]
	s.ceremony_pending = [&"zone_three"] as Array[StringName]
	return s


func _mvp_registry() -> ZoneRegistryData:
	var r := ZoneRegistryData.new()
	var z := ZoneDef.new()
	z.zone_id = &"zone_verdant_forest"
	var c := ZoneUnlockCondition.new()
	c.kind = ZoneUnlockCondition.Kind.ALWAYS
	z.unlock_condition = c
	r.zones.append(z)
	return r


# --- AC-08: typed rebuild through the real JSON path -----------------------------------

func test_envelope_roundtrip_rebuilds_typed_arrays() -> void:
	var original := _populated()
	var reloaded: Variant = JSON.parse_string(JSON.stringify(original.to_dict()))
	assert_true(reloaded is Dictionary)

	var restored: ZoneState = ZoneState.from_dict(reloaded)

	assert_eq(restored.workout_count, 23, "int re-coerced after JSON float")
	assert_eq(restored.last_counted_transition_id, "txn-rt")
	assert_eq(restored.last_counted_date, "2026-06-06")
	# Typed Array[StringName] rebuild — JSON lands generic Array[String].
	assert_eq(restored.unlocked_zone_ids.size(), 2)
	assert_true(restored.unlocked_zone_ids[0] is StringName,
		"AC-08: typed StringName rebuild (generic assign is a runtime error)")
	assert_true(restored.unlocked_zone_ids.has(&"zone_two"))
	assert_true(restored.ceremony_pending.has(&"zone_three"))


# --- AC-04: three corrupt vectors → ALWAYS available + telemetry + no crash ---------------

func test_corrupt_envelope_vectors_degrade_safely() -> void:
	var vectors: Array = [
		"garbage-not-a-dict",                                  # non-Dictionary
		{"unlocked_zone_ids": 42, "workout_count": "x"},       # wrong field types
		{},                                                    # missing schema_version etc.
	]
	for v: Variant in vectors:
		var mock := MockPersistenceLayer.new()
		mock.write("zone.state", v)
		var sut: Node = ZoneSystemScript.new()
		sut._persistence = mock
		sut._registry = _mvp_registry()
		add_child_autofree(sut)
		assert_true(sut.is_ready(), "corrupt vector must not break boot: %s" % [v])
		assert_true(sut.is_zone_unlocked(&"zone_verdant_forest"),
			"AC-04: ALWAYS zones stay available (derived)")
		if v is String:
			var events: Array = sut.get_telemetry().map(
				func(e: Dictionary) -> String: return e["event"])
			assert_has(events, "zone.manifest_corrupt")
