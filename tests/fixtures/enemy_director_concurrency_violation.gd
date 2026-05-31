# EnemyDirector CI Lint — Particle Concurrency Cap Violation Fixture (Story 004 Story-AC)
# ci:violation-fixture — MAX_CONCURRENT_PARTICLE_EMITTERS declared as var (mutable) not const
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

extends Node

## ACTIVE violation: var allows runtime modification of the cap — must be const
var MAX_CONCURRENT_PARTICLE_EMITTERS = 8  # ci:violation-fixture — must be const, not var
