# EnemyDirector CI Lint — Signal Lifecycle / Subscription Clean Fixture (Story 003)
# ci:clean-fixture — all signal lints must PASS (exit 0). Subscriptions to governed
# signals go through connect_for_initial_state (Contract 6); non-hot-path .connect()
# (e.g. in _ready() and a spawn helper) is allowed; hot-path bodies contain NO
# connect/disconnect. Located in tests/fixtures/ (outside SCAN_ROOT); read by
# test_enemy_director_ci_lint.gd via _read_lines(). It is NOT a live script.
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# Clean: governed-signal subscriptions via the Contract 6 helper (no raw .connect()
# on .ability_cast / .state_changed). A non-governed .connect() in _ready() is fine —
# AC-10 only forbids connect/disconnect inside hot-path method bodies, not _ready().
func _ready() -> void:
	GameStateMachine.connect_for_initial_state(self, &"_on_state_changed", &"state_changed")
	AbilitySystem.connect_for_initial_state(self, &"_on_ability_cast", &"ability_cast")

# Clean: spawn-time wiring uses .connect() but is NOT a hot-path method — allowed.
func _spawn_enemy(enemy: Node) -> void:
	enemy.tree_exited.connect(_on_enemy_despawned)  # outside hot path — allowed

# Clean: hot-path body does pure dispatch — NO connect/disconnect here.
func _on_ability_cast(_ability_id, _caster, _target) -> void:
	var gsm_state := GameStateMachine.current_state
	if gsm_state == &"Suspended":
		return
	_process_cast_immediate(_ability_id, _caster, _target)

# Clean: hot-path body iterates state only — NO connect/disconnect here.
func _physics_process(_delta: float) -> void:
	for instance_id in _enemy_state_pool:
		_advance_locomotion(instance_id)

# Out-of-scope helpers (no violations).
func _on_state_changed(_to, _from, _tid) -> void:
	pass

func _on_enemy_despawned() -> void:
	pass

func _process_cast_immediate(_a, _c, _t) -> void:
	pass

func _advance_locomotion(_id) -> void:
	pass
