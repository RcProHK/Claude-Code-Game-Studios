# Unit tests — AbilitySystem cast_ability atomic sequence (Story 006 / AC-12).
#
# cast_ability runs a fixed gate sequence: re-entrance → registry → unlocked → cooldown → GSM
# state → stat gate → target → emit + start cooldown. SUCCESS only when every gate passes.
# ability_cast carries NO damage param — #13 CombatResolver owns combat math (AC-12).
#
# The DI seams are injected directly on a fresh un-parented SUT (no _ready()): a MockGSM reporting
# an active-combat state, a MockStat reporting a high stat, and a Node2D target. The ability is
# white-box unlocked by setting _unlocked_abilities directly so the test isolates the CAST path.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## Minimal GSM stub — get_current_state + connect_for_initial_state (the seams AbilitySystem uses).
class MockGSM extends RefCounted:
	var state: int = GameStateMachine.GameState.COMBAT_ACTIVE

	func get_current_state() -> int:
		return state

	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Minimal Stat stub — get_stat returns a fixed high value so the stat gate always passes.
class MockStat extends RefCounted:
	var value: float = 100.0

	func get_stat(_stat_id: StringName) -> float:
		return value

	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut
var _gsm: MockGSM
var _stat: MockStat
var _caster: Node2D
var _target: Node2D


func before_each() -> void:
	_sut = AbilitySystem.new()
	_gsm = MockGSM.new()
	_stat = MockStat.new()
	_sut._gsm = _gsm
	_sut._stat_system = _stat
	_sut._persistence = MockPersistenceLayer.new()
	_caster = autofree(Node2D.new())
	_target = autofree(Node2D.new())
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null
	_gsm = null
	_stat = null


## White-box unlock helper — records an ability without driving the unlock path (isolates cast).
func _force_unlock(ability_id: StringName) -> void:
	_sut._unlocked_abilities[ability_id] = AbilitySystem.UnlockRecord.new()


# --- AC-12: a fully-gated cast succeeds and emits ability_cast ---------------------------------

func test_cast_success_emits_ability_cast() -> void:
	# Arrange — unlock a STRIKE ability (needs a target; the stat gate passes at 100).
	_force_unlock(_sut.AbilityId.STRIKE_TIER_1_JAB)

	# Act
	var result: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, _target)

	# Assert — SUCCESS + exactly one ability_cast carrying (id, caster, target), NO damage param.
	assert_eq(result, _sut.CastResult.SUCCESS, "AC-12: a fully-gated cast returns SUCCESS")
	assert_signal_emit_count(_sut, "ability_cast", 1, "AC-12: exactly one ability_cast emitted")
	var params: Array = get_signal_parameters(_sut, "ability_cast", 0)
	assert_eq(params.size(), 3, "AC-12: ability_cast carries exactly 3 args (id, caster, target) — no damage")
	assert_eq(params[0], _sut.AbilityId.STRIKE_TIER_1_JAB, "AC-12: cast id")
	assert_eq(params[1], _caster, "AC-12: caster")
	assert_eq(params[2], _target, "AC-12: target")


func test_cast_starts_cooldown_on_success() -> void:
	# Arrange
	_force_unlock(_sut.AbilityId.STRIKE_TIER_1_JAB)

	# Act
	_sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, _target)

	# Assert — a cooldown was started (TIER_1 base = 3.0s) and ability_cooldown_started fired.
	assert_gt(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["cooldown_remaining"], 0.0,
		"AC-12: a successful cast starts the ability's cooldown")
	assert_signal_emit_count(_sut, "ability_cooldown_started", 1, "AC-12: cooldown_started emitted once on cast")


func test_cast_not_unlocked_rejects() -> void:
	# Act — cast WITHOUT unlocking first.
	var result: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, _target)

	# Assert
	assert_eq(result, _sut.CastResult.NOT_UNLOCKED, "AC-12: casting a locked ability rejects NOT_UNLOCKED")
	assert_signal_emit_count(_sut, "ability_cast", 0, "AC-12: a rejected cast does not emit ability_cast")


func test_cast_wrong_gsm_state_rejects() -> void:
	# Arrange — unlocked, but the GSM is NOT in an active-combat state.
	_force_unlock(_sut.AbilityId.STRIKE_TIER_1_JAB)
	_gsm.state = GameStateMachine.GameState.IDLE

	# Act
	var result: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, _target)

	# Assert
	assert_eq(result, _sut.CastResult.GSM_REJECT, "AC-12: a cast outside active-combat state rejects GSM_REJECT")


func test_cast_low_stat_rejects() -> void:
	# Arrange — unlocked + active combat, but the gating stat is below MINIMUM_ACTIVE_STAT (5.0).
	_force_unlock(_sut.AbilityId.STRIKE_TIER_1_JAB)
	_stat.value = 1.0

	# Act
	var result: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, _target)

	# Assert
	assert_eq(result, _sut.CastResult.STAT_INSUFFICIENT, "AC-12: a cast with the gating stat below the floor rejects")


func test_cast_strike_null_target_rejects() -> void:
	# Arrange — STRIKE needs a live target; pass null.
	_force_unlock(_sut.AbilityId.STRIKE_TIER_1_JAB)

	# Act
	var result: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, null)

	# Assert
	assert_eq(result, _sut.CastResult.INVALID_TARGET, "AC-12: a STRIKE cast with no target rejects INVALID_TARGET")


func test_cast_mobility_ignores_null_target() -> void:
	# Arrange — MOBILITY is self-targeted; a null target is fine.
	_force_unlock(_sut.AbilityId.MOBILITY_TIER_1_DASH)

	# Act
	var result: int = _sut.cast_ability(_sut.AbilityId.MOBILITY_TIER_1_DASH, _caster, null)

	# Assert
	assert_eq(result, _sut.CastResult.SUCCESS, "AC-12: a MOBILITY (self-targeted) cast succeeds with a null target")
