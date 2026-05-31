# EnemyDirector CI Lint — Move Cap Clean Fixture (Story 004 AC-31)
# Clean: all _template_move_speed values ≤ 420 (ENEMY_MOVE_CAP).
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

## Simulated EnemyRegistry .tres block. All 3 archetypes within ENEMY_MOVE_CAP=420.
const SIM_TRES_BLOCK: String = """
[resource]
archetype = "STRIKE"
_template_move_speed = 120
max_hp = 80
defense = 8

[resource]
archetype = "CONTROL"
_template_move_speed = 90
max_hp = 35
defense = 2

[resource]
archetype = "MOBILITY"
_template_move_speed = 280
max_hp = 55
defense = 4
"""
