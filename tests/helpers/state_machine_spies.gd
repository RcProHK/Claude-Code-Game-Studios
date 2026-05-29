## state_machine_spies.gd — Scaffolds the ADR-0006 Contract 14 spy set.
##
## Story 007 deliverable: helper module that consolidates spy attachment
## for the GameStateMachine test suite. Future stories that test state
## transitions can `extends StateMachineSpies` (or instantiate it) to get
## the full spy interface set with one call.
##
## ADR-0006 Contract 14 spies covered:
##   - GameStateMachine.attach_in_memory_spy (state mutations)
##   - PersistenceLayer.attach_write_spy / attach_delete_spy (storage)
##   - MockPersistenceLayer (full mock)
##
## Future spies (added when their owning systems land):
##   - Input.set_test_spy (NEW 4.6 mock API — Story 015)
##   - MockToastQueue (LootDrop epic)
##   - MockInventory (Equipment epic)
##   - MockEnemyDirector (EnemyDirector epic)
class_name StateMachineSpies extends RefCounted


var write_log: Array = []
var delete_log: Array = []
var in_memory_log: Array = []


## Attach all available spies to the production singletons. Call in
## test before_each() — and `detach_all()` in after_each() to prevent leakage.
func attach_all() -> void:
	PersistenceLayer.attach_write_spy(write_log.append)
	PersistenceLayer.attach_delete_spy(delete_log.append)
	GameStateMachine.attach_in_memory_spy(
		func(old: int, new: int) -> void:
			in_memory_log.append({"old": old, "new": new})
	)


## Detach all spies and clear logs. Call in test after_each().
func detach_all() -> void:
	PersistenceLayer.clear_spies()
	GameStateMachine.clear_spies()
	write_log.clear()
	delete_log.clear()
	in_memory_log.clear()
