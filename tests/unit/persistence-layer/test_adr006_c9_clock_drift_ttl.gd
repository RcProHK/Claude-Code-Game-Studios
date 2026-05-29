# ADR-006 Contract 9 binding — clock-drift TTL
# Gate: Story 015 AC-32 — thin wrapper referencing Story 007 tests
extends GutTest

func test_adr006_c9_is_expired_returns_false_for_fresh_anchor() -> void:
	var anchor: int = int(Time.get_unix_time_from_system()) - 60  # 1 min ago
	assert_false(PersistenceLayer.is_expired(anchor, 86400),
		"ADR-006 Contract 9: 1-min-old anchor with 1-day TTL must not be expired")

func test_adr006_c9_is_expired_returns_true_for_old_anchor() -> void:
	var anchor: int = int(Time.get_unix_time_from_system()) - 90001  # 25h+ ago
	assert_true(PersistenceLayer.is_expired(anchor, 86400),
		"ADR-006 Contract 9: 25h-old anchor with 1-day TTL must be expired")
