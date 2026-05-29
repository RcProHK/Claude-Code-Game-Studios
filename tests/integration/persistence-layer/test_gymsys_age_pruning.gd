# PersistenceLayer — Story 014 AC-31/31b GymSys Age Pruning Tests
#
# Proves MockPersistenceLayer.is_expired() + delete() integration for
# GymSys committed tombstone age-pruning pattern.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 9 (is_expired TTL), Contract 14 (mock)
extends GutTest


var _mock: MockPersistenceLayer
var _delete_log: Array


func before_each() -> void:
	_mock = MockPersistenceLayer.new()
	_delete_log = []
	_mock.attach_delete_spy(_delete_log.append)


## AC-31: 35-day-old tombstone → is_expired → delete via mock.
func test_gymsys_age_prune_deletes_expired_tombstone() -> void:
	# Arrange — anchor 35 days + 1 second ago (definitely expired)
	var committed_at: int = int(Time.get_unix_time_from_system()) - (35 * 86400 + 1)
	var key: String = "gym._committed_tombstones.tid_A:loot-commit"
	_mock.write(key, committed_at)

	# Simulate GymSys prune logic: if is_expired → delete
	var is_exp: bool = PersistenceLayer.is_expired(committed_at, 35 * 86400)
	if is_exp:
		_mock.delete(key)

	# Assert
	assert_true(is_exp, "35d+1s old tombstone must be expired")
	assert_eq(_delete_log.size(), 1, "Expired tombstone must trigger one delete")
	assert_eq(_delete_log[0], key, "Delete must target the correct key")


## AC-31b: fresh tombstone (1s old) → NOT expired → NOT deleted.
func test_gymsys_age_prune_skips_fresh_tombstone() -> void:
	# Arrange — anchor 1 second ago (fresh)
	var committed_at: int = int(Time.get_unix_time_from_system()) - 1
	var key: String = "gym._committed_tombstones.tid_B:fresh"
	_mock.write(key, committed_at)

	# Simulate prune logic
	var is_exp: bool = PersistenceLayer.is_expired(committed_at, 35 * 86400)
	if is_exp:
		_mock.delete(key)

	# Assert — fresh tombstone NOT deleted
	assert_false(is_exp, "1s old tombstone must NOT be expired (35d TTL)")
	assert_eq(_delete_log.size(), 0, "Fresh tombstone must NOT trigger delete")
	assert_eq(_mock.read(key), committed_at, "Fresh tombstone must remain in mock cache")


## Additional: boundary case — exactly at TTL (wall_delta == ttl_seconds → false).
func test_gymsys_age_prune_exactly_at_ttl_not_expired() -> void:
	var ttl: int = 35 * 86400
	var committed_at: int = int(Time.get_unix_time_from_system()) - ttl
	# wall_delta == ttl → 0 > ttl = false (strict greater-than)
	var is_exp: bool = PersistenceLayer.is_expired(committed_at, ttl)
	# Note: tiny race possible (1s tolerance acceptable for this test)
	assert_false(is_exp, "Exactly-at-TTL must not be expired (strict > not >=)")
