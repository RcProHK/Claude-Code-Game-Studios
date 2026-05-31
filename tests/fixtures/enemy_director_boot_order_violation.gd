# EnemyDirector CI Lint — Boot-Order Violation Fixture (Story 003, AC-04)
# ci:violation-fixture — simulated project.godot [autoload] text with EnemyDirector
# listed BEFORE LootDropSystem. This is a TEXT fixture, NOT a live script: it is
# read line-by-line by test_enemy_director_ci_lint.gd via _read_lines() and fed to
# the _parse_autoload_order() helper to prove the HARD constraint detection
# (LootDropSystem ≺ EnemyDirector). THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.
#
# The lines below intentionally mimic the project.godot [autoload] INI block format
# (Key="*res://path.gd"). The leading "# " makes the .gd file parseable-as-empty if
# ever loaded, while the embedded SIM_AUTOLOAD_BLOCK string carries the raw INI text
# the helper test parses. The test extracts the block from the string constant.

const SIM_AUTOLOAD_BLOCK: String = """
[autoload]

; Foundation layer
PersistenceLayer="*res://src/autoload/persistence_layer.gd"
GameStateMachine="*res://src/autoload/game_state_machine.gd"
PlatformDetect="*res://src/autoload/platform_detect.gd"
GymSysBackendClient="*res://src/autoload/gym_sys_backend_client.gd"
StatSystem="*res://src/autoload/stat_system.gd"
AbilitySystem="*res://src/autoload/ability_system.gd"
StreakSystem="*res://src/autoload/streak_system.gd"
WorkoutStateTracker="*res://src/autoload/workout_state_tracker.gd"

; ci:violation-fixture — EnemyDirector listed BEFORE LootDropSystem (HARD violation)
EnemyDirector="*res://src/autoload/enemy_director.gd"
LootDropSystem="*res://src/autoload/loot_drop_system.gd"

[display]
window/size/viewport_width=1280
"""
