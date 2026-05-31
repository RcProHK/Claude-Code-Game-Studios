# EnemyDirector CI Lint — Boss Transition Violation Fixture (Story 004 Story-AC)
# ci:violation-fixture — illegal direct assignment of non-IDLE BossAnchorState
# (should transition via FSM helper; direct assignment skips transition guards)
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

enum BossAnchorState { IDLE, PRE_SPAWN, COMMIT_PENDING, COMMITTED, ENGAGED }
var _boss_anchor_state: int = BossAnchorState.IDLE

# ACTIVE violation: direct ENGAGED assignment (skips IDLE→PRE_SPAWN→COMMIT_PENDING→COMMITTED→ENGAGED chain)
func _bad_boss_jump() -> void:
	_boss_anchor_state = BossAnchorState.ENGAGED  # ci:violation-fixture — illegal direct non-IDLE assignment
