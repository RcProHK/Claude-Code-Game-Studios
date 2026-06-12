extends Node
## FIXTURE (NOT production) — a deliberately-violating telemetry-style file used by
## tests/static/test_telemetry_ci_lint.gd to prove check_telemetry_frozen_schema.gd
## catches a frozen-event field-set change without a version bump (EC-16). NEVER
## referenced by real code; lives outside the lint's scan scope.

const FAKE_PRIORITY := 1


func _bad_loot_serialize(transition_id: String, drop_id: String,
		rarity_tier: String, item_type: String, extra) -> void:
	# VIOLATION — loot_dropped serialized with a 5TH field while still schema_version 1.
	# The frozen loot_dropped_v1 set is exactly {drop_id, rarity_tier, item_type,
	# transition_id}; adding "extra_field" without bumping to v2 must be flagged (EC-16).
	_record_dedup(&"loot_dropped", transition_id, {
		"drop_id": drop_id,
		"rarity_tier": rarity_tier,
		"item_type": item_type,
		"transition_id": transition_id,
		"extra_field": extra,
	}, TelemetryEvent.Priority.STANDARD, 1)


func _record_dedup(_event, _tid, _payload, _priority, _version) -> void:
	pass
