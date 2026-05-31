# EnemyDirector CI Lint — Particle Concurrency Cap Clean Fixture (Story 004 Story-AC)
# Clean: MAX_CONCURRENT_PARTICLE_EMITTERS declared as const (immutable cap).
# THIS FILE MUST NEVER BE IMPORTED OR INSTANTIATED.

extends Node

## Correct: const prevents runtime modification of the particle emitter cap.
const MAX_CONCURRENT_PARTICLE_EMITTERS = 8  # ✓ immutable cap (CI lint Layer 11)
