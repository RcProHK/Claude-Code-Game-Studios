# EnemyDirector — Autoload position 10 (#14)
#
# Status: STUB — implementation pending
# Driving GDD: design/gdd/enemy-director.md (Approved 2026-05-27; single-pass)
# Governing ADR: ADR-0006 Contracts 1/2/3/6
#
# Signal surface LOCK (Rule 5 + AC-07 + CI lint #3): exactly 3 emitted signals:
#   - hit_resolved(payload)
#   - enemy_killed(payload)
#   - combat_metric_anomaly(payload)
# NO `combat_started` / `combat_ended` — those don't exist (per Q-OQ2 resolution).
# Avatar Renderer + other combat-state consumers use GSM `state_changed` filtered by
# `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` instead.
extends Node

func _ready() -> void:
	print("[EnemyDirector] stub initialized — autoload pos 10; implementation pending")
