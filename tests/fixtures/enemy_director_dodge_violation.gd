# EnemyDirector CI Lint — Dodge Amplitude Violation Fixture (Story 004 AC-32)
# ci:violation-fixture — DODGE_AMPLITUDE_PX=50; 50*2=100 >= MELEE_RANGE=80 (INV-8 violation)
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

## ACTIVE violation (AC-32): DODGE_AMPLITUDE_PX * 2 >= MELEE_RANGE=80
const DODGE_AMPLITUDE_PX: int = 50  # ci:violation-fixture — INV-8 broken (50*2=100 >= 80)
