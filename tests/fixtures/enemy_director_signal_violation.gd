# EnemyDirector CI Lint — Signal Lifecycle / Subscription Violation Fixture (Story 003)
# ci:violation-fixture — deliberate rule violations for AC-10 (hot-path connect/
# disconnect) and the signal-subscription lint (raw .connect() bypassing the
# connect_for_initial_state helper). Located in tests/fixtures/ (outside SCAN_ROOT);
# read by test_enemy_director_ci_lint.gd via _read_lines(). It is NOT a live script.
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

# ACTIVE violation (subscription): raw .connect() on a governed signal, bypassing
# the connect_for_initial_state Contract 6 helper.
func _ready() -> void:
	AbilitySystem.ability_cast.connect(_on_ability_cast)  # ci:violation-fixture — raw subscribe
	GameStateMachine.state_changed.connect(_on_state_changed)  # ci:violation-fixture — raw subscribe

# ACTIVE violation (signal lifecycle / AC-10): .connect() inside a hot-path body.
func _physics_process(_delta: float) -> void:
	some_node.tree_exited.connect(_on_gone)  # ci:violation-fixture — connect in hot path

# ACTIVE violation (signal lifecycle / AC-10): .disconnect() inside _on_ability_cast.
func _on_ability_cast(_ability_id, _caster, _target) -> void:
	AbilitySystem.ability_cast.disconnect(_on_ability_cast)  # ci:violation-fixture — disconnect in hot path

# Out-of-scope handlers referenced above (no violations here).
func _on_state_changed(_to, _from, _tid) -> void:
	pass

func _on_gone() -> void:
	pass
