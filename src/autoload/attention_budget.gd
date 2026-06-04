## AttentionBudget — Autoload (position 11+, after GSM pos 2 + WST pos 5 + PersistenceLayer pos 1)
##
## Pillar 2 (無壓力陪伴 / Frictionless Companion) constitutional enforcement service.
## Exposes a narrow read-only API for input and notification permission.
##
## ## Story 001 scope — factory only
## Only `create_policy()` is live in Story 001. Remaining boot subscription and
## Substate management are deferred:
##   Story 004: _ready() boot subscription (connect_for_initial_state for #1 state_changed
##              + plain .connect for #9 phase_changed) + Substate (INITIALISING → READY).
##   Story 003: CRITICAL_NOTIFICATION_KINDS const + is_critical_notification() method.
##   Story 005: glance budget ceiling helpers.
##
## ## Autoload registration note (Story 001 decision)
## This file is NOT yet registered in project.godot. Registration (with the correct
## boot position per ADR-0008 Autoload Position Map) is Story 004's responsibility —
## Story 004 owns the full boot subscription that makes the autoload functionally
## necessary. Registering here without the boot subscription would produce a live
## autoload with no GSM/WST wiring, which is misleading. Story 004 registers it.
##
## Driving GDD: design/gdd/attention-budget-policy.md (Approved 2026-06-04)
## Governing ADRs: ADR-0006 Contract 4 (boot position), Contract 6 (connect_for_initial_state),
##                 ADR-0008 Autoload Position Map (#33 insertion rule queued)
extends Node


# ============================================================================
# Substate — boot lifecycle (deferred to Story 004 for full wiring)
# ============================================================================

## Autoload lifecycle substate (ADR-0006 Contract 4 pattern).
## INITIALISING until _ready() completes boot subscription (Story 004).
enum Substate {
	INITIALISING,  ## 0 — _ready() in progress; queries on any injected policy are fail-closed
	READY,         ## 1 — boot subscription wired; normal operation
}

var _substate: Substate = Substate.INITIALISING


func _ready() -> void:
	# Story 004: GSM connect_for_initial_state + WST phase_changed subscription + Substate.
	# Boot subscription goes here:
	#   GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)   # Contract 6
	#   WorkoutStateTracker.phase_changed.connect(_on_wst_phase_changed)    # plain .connect (WST 2-arg)
	#   _substate = Substate.READY
	#
	# AC-20: _on_gsm_state_changed MUST be exactly 3-arg (from: int, to: int, payload)
	#        and MUST NOT use .bind() — see ADR-0006 Contract 6.
	pass


# ============================================================================
# Public API
# ============================================================================

## Factory method: creates a fully-wired AttentionBudgetPolicy instance.
## Input handlers call this in their constructor to obtain an injectable IInputPolicy.
##
## Returns a new AttentionBudgetPolicy injected with the live GameStateMachine
## and WorkoutStateTracker autoload refs (the concrete Pillar 2 gate).
##
## ADR-0006 B-B2: handler calls AttentionBudget.create_policy() → receives IInputPolicy.
## Handler stores as IInputPolicy (not AttentionBudgetPolicy) to preserve testability.
##
## Example:
##   func _init(policy: IInputPolicy = AttentionBudget.create_policy()) -> void:
##       _policy = policy
func create_policy() -> IInputPolicy:
	return AttentionBudgetPolicy.new(GameStateMachine, WorkoutStateTracker)


# ============================================================================
# Story 004 stubs — GSM + WST signal callbacks (wired in Story 004 _ready)
# ============================================================================

## GSM state_changed callback — exactly 3 args, no .bind() (AC-20 / ADR-0006 Contract 6).
## Story 004 wires this via connect_for_initial_state(_on_gsm_state_changed).
## Used for notification-suppression edge tracking (Rule 7); does NOT affect
## is_input_permitted() pure-pull derivation (Rule 2).
func _on_gsm_state_changed(from: int, to: int, payload) -> void:
	# Story 004: update notification-suppression edge state here.
	pass


## WST phase_changed callback — 2 args (plain .connect; WST has no connect_for_initial_state).
## Story 004 wires this via WorkoutStateTracker.phase_changed.connect(_on_wst_phase_changed).
func _on_wst_phase_changed(from: int, to: int) -> void:
	# Story 004: update notification-suppression edge state here.
	pass
