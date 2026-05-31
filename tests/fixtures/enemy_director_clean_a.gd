# EnemyDirector CI Lint — Negative Clean Fixture (Story 002)
# ci:clean-fixture — all patterns must PASS (exit 0). Includes an RNGFactory block
# with randf() + RandomNumberGenerator.new() INSIDE it to prove the scope-aware
# check correctly excludes the sanctioned class body. Located in tests/fixtures/
# (outside SCAN_ROOT = res://src/). THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# Clean: damage via CombatResolver.resolve_hit() — no inline arithmetic
func _good_attack(ctx: Object) -> Object:
	return CombatResolver.resolve_hit(ctx)

# Clean: RNG via factory — direct RNG allowed INSIDE the RNGFactory class body only.
class RNGFactory:
	static func create(transition_id: String) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()  # INSIDE class body — allowed
		rng.seed = hash(transition_id)
		var _warmup := rng.randf()  # INSIDE class body — allowed
		return rng

	static func create_sub(transition_id: String, sub_key: String) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()  # INSIDE class body — allowed
		rng.seed = hash("%s:%s" % [transition_id, sub_key])
		return rng

# Clean: stat reads confined to _build_stat_snapshot — direct StatSystem.get_stat()
# allowed INSIDE this method body only.
func _build_stat_snapshot() -> Object:
	var s := Object.new()
	var _atk = StatSystem.get_stat(&"ATTACK_POWER")  # INSIDE snapshot — allowed
	var _crit = StatSystem.get_stat(&"CRIT_CHANCE")  # INSIDE snapshot — allowed
	return s
