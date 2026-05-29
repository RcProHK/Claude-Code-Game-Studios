# LootDropSystem — Autoload position 9 (#15)
#
# Status: STUB — implementation pending
# Driving GDD: design/gdd/loot-drop-system.md (Pass 2 Revised 2026-05-28 pending Pass 3)
# Governing ADRs: ADR-0005 Loot Rarity Formula, ADR-0003 Save State, ADR-0006 Contracts 1/2/3/11
#
# CRITICAL boot ordering: MUST boot BEFORE EnemyDirector (pos 10) per #13 EC-43 + Rule 9.
# EnemyDirector emits `enemy_killed` which #15 subscribes — connection must exist before first emit.
extends Node

func _ready() -> void:
	print("[LootDropSystem] stub initialized — autoload pos 9; implementation pending")
