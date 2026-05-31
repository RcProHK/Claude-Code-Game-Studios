# Test helper — spins up a fresh EnemyDirector instance wired to mock seams (Story 020).
# EnemyDirector has no class_name (autoload-only), so the script is loaded by path. The
# returned director is a Node NOT in the tree — the caller is responsible for free().
extends RefCounted

const _ED_SCRIPT := "res://src/autoload/enemy_director.gd"
const _WST_MOCK := "res://tests/helpers/mock_workout_state_tracker.gd"
const _FACTORY := "res://tests/helpers/archetype_resource_factory.gd"


## Build { director, mocks, run_seed }. director is wired with mock GSM / AbilitySystem /
## StatSystem / WorkoutStateTracker / CombatResolver + an in-memory registry for `archetype`.
static func make_harness(run_seed: int, archetype: StringName) -> Dictionary:
	var director: Node = (load(_ED_SCRIPT) as GDScript).new()
	var mocks: Dictionary = {
		"gsm": MockGSM.new(),
		"ability": MockAbility.new(),
		"stat": MockStat.new(),
		"wst": (load(_WST_MOCK) as GDScript).new(),
		"resolver": MockResolver.new(),
	}
	mocks["wst"].dominant_ability_class = _archetype_to_class(archetype)
	director.set(&"_gsm_source", mocks["gsm"])
	director.set(&"_ability_source", mocks["ability"])
	director.set(&"_stat_system", mocks["stat"])
	director.set(&"_wst_source", mocks["wst"])
	director.set(&"_combat_resolver", mocks["resolver"])
	director.set(&"_enemy_registry", (load(_FACTORY) as GDScript).make_registry([archetype] as Array))
	director.call("_ready")  # _ready only resolves null seams, so injected mocks persist
	return {"director": director, "mocks": mocks, "run_seed": run_seed}


static func _archetype_to_class(archetype: StringName) -> int:
	match archetype:
		&"STRIKE": return 0
		&"CONTROL": return 1
		&"MOBILITY": return 2
		_: return 3  # UNKNOWN


## Self-check (Story 020 QA).
static func _static_check() -> bool:
	var h: Dictionary = make_harness(123, &"STRIKE")
	assert(h["director"] != null, "harness: director created")
	assert(h["mocks"].has("gsm") and h["mocks"].has("resolver"), "harness: mocks present")
	assert(h["run_seed"] == 123, "harness: run_seed echoed")
	(h["director"] as Node).free()  # not in tree — free directly
	return true


# ---- Minimal mock seams ----

class MockGSM:
	extends RefCounted
	signal state_changed(from_state: int, to_state: int, payload)
	var current_state_value: int = GameStateMachine.GameState.COMBAT_ACTIVE
	var transition_id_value: String = "TX-harness-001"
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func get_current_state() -> int:
		return current_state_value
	func acquire_transition_id(_f: int, _t: int) -> String:
		return transition_id_value


class MockAbility:
	extends RefCounted
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(c: Callable) -> void:
		ability_cast.connect(c)


class MockStat:
	extends RefCounted
	var value: float = 10.0
	var call_count: int = 0
	func get_stat(_id: StringName) -> float:
		call_count += 1
		return value


class MockResolver:
	extends RefCounted
	var call_count: int = 0
	func resolve_hit(ctx) -> CombatResolver.HitResult:
		call_count += 1
		var hr := CombatResolver.HitResult.new()
		hr.transition_id = ctx.transition_id
		hr.ability_id = ctx.ability_id
		return hr
