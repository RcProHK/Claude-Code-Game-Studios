# EnemyDirector CI Lint — Move Cap Violation Fixture (Story 004 AC-31)
# ci:violation-fixture — simulated EnemyRegistry .tres with _template_move_speed = 500 (> 420)
# Used by _extract_template_speeds + test_enemy_director_ci_lint.gd for AC-31 detection.
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

## Simulated EnemyRegistry .tres block. MOBILITY archetype move speed 500 violates
## ENEMY_MOVE_CAP=420 (INV-7 cross-system binding per GDD Section G).
const SIM_TRES_BLOCK: String = """
[resource]
script/source = ""
archetype = "MOBILITY"
_template_move_speed = 500
max_hp = 55
defense = 4
"""
