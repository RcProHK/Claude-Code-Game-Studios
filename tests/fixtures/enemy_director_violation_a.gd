# EnemyDirector CI Lint — Positive Violation Fixture (Story 002)
# ci:violation-fixture — deliberate rule violations for CI detection testing.
# Located in tests/fixtures/ (outside SCAN_ROOT = res://src/), NOT scanned by normal CI.
# test_enemy_director_ci_lint.gd uses this file to verify each lint script's detection.
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# ACTIVE violation (chokepoint): inline damage arithmetic bypasses CombatResolver
func _bad_attack(target, caster) -> void:
	target.hp -= caster.attack_power * 1.5  # ci:violation-fixture — inline damage

# ACTIVE violation (randf): direct RandomNumberGenerator outside RNGFactory class body
func _bad_rng() -> float:
	return randf()  # ci:violation-fixture — randf outside RNGFactory

# ACTIVE violation (stat): StatSystem.get_stat() outside _build_stat_snapshot
func _bad_stat() -> float:
	return StatSystem.get_stat(&"ATTACK_POWER")  # ci:violation-fixture — stat outside snapshot
