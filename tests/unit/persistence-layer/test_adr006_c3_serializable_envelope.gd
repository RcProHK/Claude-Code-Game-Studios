# ADR-006 Contract 3 binding — SerializableResource envelope
# Gate: Story 015 AC-32 — thin wrapper referencing Story 004 tests
extends GutTest

func test_adr006_c3_boss_payload_round_trip() -> void:
	var boss := BossPayload.new()
	boss.outcome = BossPayload.BossOutcome.DEFEATED
	boss.boss_id = 1
	boss.hp_at_interrupt = 50
	boss.hp_max = 100
	var d: Dictionary = boss.to_dict()
	assert_eq(d.get("payload_type"), "BossPayload",
		"ADR-006 Contract 3: payload_type must be class_name, not 'Resource'")
	var restored: BossPayload = BossPayload.from_dict(d)
	assert_eq(restored.outcome, BossPayload.BossOutcome.DEFEATED)
