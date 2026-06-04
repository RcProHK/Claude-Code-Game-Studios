## AttentionBudget — Autoload (position 11+, after GSM pos 2 + WST pos 5 + PersistenceLayer pos 1)
##
## Pillar 2 (無壓力陪伴 / Frictionless Companion) constitutional enforcement service.
## Exposes a narrow read-only API for input and notification permission.
##
## ## Story 001 scope — factory only
## Only `create_policy()` is live in Story 001.
##
## ## Story 003 — DONE
## CRITICAL_NOTIFICATION_KINDS closed allowlist const + is_critical_notification()
## are live (critical-bypass surface for notification producers; #8/#28 query it).
##
## ## Story 004 — DONE
## _ready() boot subscription (connect_for_initial_state for #1 state_changed +
## plain .connect for #9 phase_changed) + Substate (INITIALISING → READY).
## Registered in project.godot [autoload] (pos 17, ADR-0008 #33 insertion rule).
##
## ## Story 005 — DONE
## GLANCE_BUDGET_CEILING_MS const (Tuning Knobs, default 2000) + glance_within_budget()
## (Formula 3, pure) + assert_glance_within_budget() (debug-only push_error instrument;
## EC-9 design-time/playtest check, NOT a runtime gate).
##
## ## Autoload registration note (Story 001 decision, executed Story 004)
## Story 004 registers this file in project.godot at the ADR-0008 pos 11+ block
## (appended after AudioManager, mirroring the #4 Audio precedent). Story 004 owns
## the full boot subscription that makes the autoload functionally necessary;
## registering earlier (without GSM/WST wiring) would produce a misleading live
## autoload with no subscriptions.
##
## Driving GDD: design/gdd/attention-budget-policy.md (Approved 2026-06-04)
## Governing ADRs: ADR-0006 Contract 4 (boot position), Contract 6 (connect_for_initial_state),
##                 ADR-0008 Autoload Position Map (#33 insertion rule queued)
extends Node


# ============================================================================
# Constitutional constants — GDD Tuning Knobs / Rule 7 critical-bypass allowlist
# ============================================================================

## Rule 7 critical-notification allowlist (GDD Tuning Knobs default).
##
## "closed" is a CONSTITUTIONAL naming convention, NOT a CI-enforced lint:
## adding a kind to this allowlist requires design review (GDD G2 acknowledged
## this is not machine-enforced in #33 — the AC-18b producer-compliance grep is
## deferred to #8/#28). Each member grants the matching producer the right to
## BYPASS Formula 2 suppression (it fires its notification without querying
## is_notification_permitted()). Adding a non-critical kind = The Nag Engine leak.
## Only data-loss / safety-critical kinds belong here.
const CRITICAL_NOTIFICATION_KINDS: Array[StringName] = [
	&"disconnect_warning",
	&"save_failed",
]


## Cross-system single-glance attention ceiling, in milliseconds (GDD Tuning
## Knobs default 2000; safe range [800, 3000]).
##
## This is the cross-system HARD CAP applied by Formula 3 (glance_within_budget).
## It is deliberately LOOSER than any per-system glance target: e.g. #20 Gym-Mode
## HUD owns its own stricter 0.3s (300ms) 餘光 budget. This const does NOT replace
## the stricter #20 budget — it is the constitutional upper bound that NO element
## in ANY system may exceed (>3000 betrays Pillar 2; <800 over-restricts legible HUD).
const GLANCE_BUDGET_CEILING_MS: int = 2000


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


## Boot subscription (Story 004). Two-route subscription per Rule 9 + Substate table:
##   1. #1 GameStateMachine.state_changed via connect_for_initial_state (ADR-0006
##      Contract 6) — guarantees the initial-state callback fires (GSM does NOT
##      emit state_changed from its own _ready(); subscribers obtain initial state
##      via the sentinel-delivery helper). The callable is the EXACTLY-3-arg
##      _on_gsm_state_changed with NO .bind() (AC-20 / Contract 6).
##   2. #9 WorkoutStateTracker.phase_changed via plain .connect — WST has no
##      connect_for_initial_state helper (GSM-specific) and phase_changed is a
##      2-arg (from, to) signal incompatible with the Contract 6 3-arg+payload
##      callv shape, so a plain .connect is the correct (and only) form.
##
## Substate: INITIALISING → READY after both subscriptions are wired (Substate
## table). There is NO SUSPENDED substate — #33 caches nothing, so it never needs
## suspend/restore (GSM SUSPENDED is handled in the derivation layer, Rule 4).
##
## CRITICAL (AC-14 derivation independence): these subscriptions ONLY drive
## notification-suppression edge tracking (Rule 7). They do NOT feed
## is_input_permitted()/is_notification_permitted() — those are pure-pull (Rule 2)
## and read live GSM/WST values on every call. Even if neither signal ever fires,
## the derivation stays correct.
func _ready() -> void:
	_wire_subscriptions(GameStateMachine, WorkoutStateTracker)


## Wire the two boot subscriptions against the supplied GSM / WST refs and flip
## the Substate to READY. Extracted from _ready() so tests can inject mock GSM
## (with a connect_for_initial_state spy + state_changed signal) and mock WST
## (with a phase_changed signal) without constructing the real autoloads.
##
## Params are UNTYPED (Variant) — the GSM/WST autoload refs are the DI seam
## (GDScript DI seam rule: a typed Node param fails the compile-time member check
## for connect_for_initial_state, which is not a Node member).
##
## AC-12(a): #1 state_changed subscribed via connect_for_initial_state.
## AC-12(b): #9 phase_changed subscribed via plain .connect.
## AC-20: _on_gsm_state_changed is passed as a bare 3-arg Callable — NO .bind().
func _wire_subscriptions(gsm_ref, wst_ref) -> void:
	# Route 1 — #1 GSM state_changed (ADR-0006 Contract 6, NO raw state_changed.connect).
	gsm_ref.connect_for_initial_state(_on_gsm_state_changed)
	# Route 2 — #9 WST phase_changed (plain .connect; WST has no helper, 2-arg signal).
	wst_ref.phase_changed.connect(_on_wst_phase_changed)
	# Boot subscription wired → leave INITIALISING.
	_substate = Substate.READY


## Read-only accessor for the boot lifecycle substate (INITIALISING / READY).
## Mirrors the other Foundation autoloads' get_substate() surface; lets a boot
## test assert the autoload reached READY after _ready()/_wire_subscriptions.
func get_substate() -> Substate:
	return _substate


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


## Returns true if `kind` is a critical notification permitted to bypass Rule 7
## Formula 2 suppression.
##
## Critical notifications (data-loss / safety) fire unconditionally — a producer
## with a critical kind does NOT query is_notification_permitted() (EC-12). This
## predicate lets a producer (or a future #8/#28 compliance check) ask whether a
## given kind is on the closed allowlist.
##
## The allowlist (CRITICAL_NOTIFICATION_KINDS) is "closed" by constitutional
## naming convention: extending it requires design review, NOT a code change
## reviewed only at PR level. This is not CI-enforced in #33 (GDD G2); the
## AC-18b producer-compliance grep is deferred to the #8/#28 producer epic.
##
## AC-18a: is_critical_notification(&"disconnect_warning") → true;
##         is_critical_notification(&"streak_nag") → false;
##         is_critical_notification(&"") → false.
func is_critical_notification(kind: StringName) -> bool:
	return kind in CRITICAL_NOTIFICATION_KINDS


# ============================================================================
# Glance budget ceiling (Story 005 — GDD Rule 8 / Formula 3)
# ============================================================================

## Formula 3 — returns true if a measured single-glance attention demand fits
## within the cross-system ceiling.
##
##   glance_within_budget(measured_ms) = measured_ms <= GLANCE_BUDGET_CEILING_MS
##
## Pure predicate (no state, const-foldable). `measured_ms` is a playtest-measured
## glance duration in milliseconds (tachistoscope / observed glance). Boundary:
## 2000 → true; 2001 → false; 0 → true (AC-13).
func glance_within_budget(measured_ms: int) -> bool:
	return measured_ms <= GLANCE_BUDGET_CEILING_MS


## Debug-build instrumentation hook: logs (push_error) when a measured glance
## exceeds the ceiling. NO-OP in release builds.
##
## Enforcement model (EC-9): the glance budget is a DESIGN-TIME / instrumented-
## playtest AC, NOT a per-frame runtime gate. A measured value >2000ms is an AC
## FAILURE (design must narrow the element) — it is NEVER a runtime block. This
## helper exists only to surface a breach loudly during instrumented playtests.
##
## Implementation note (godot design-review R-5): uses `OS.is_debug_build()` +
## `push_error`, deliberately NOT `assert()`. `assert()` is stripped in release
## with semantics that vary by build config and can interfere with GUT; the
## explicit debug gate + push_error is GUT-safe and unambiguously release-no-op.
func assert_glance_within_budget(element_id: StringName, measured_ms: int) -> void:
	if not OS.is_debug_build():
		return  # release no-op (EC-9: never a runtime gate)
	if measured_ms > GLANCE_BUDGET_CEILING_MS:
		push_error("glance budget exceeded: %s = %dms (ceiling %d)" % [
			element_id, measured_ms, GLANCE_BUDGET_CEILING_MS
		])


# ============================================================================
# Boot-subscription signal callbacks (Story 004 — wired in _wire_subscriptions)
# ============================================================================
#
# Both callbacks exist ONLY to drive notification-suppression edge detection
# (Rule 7 boundary DROP decisions). They MUST NOT mutate any state that
# is_input_permitted()/is_notification_permitted() read — those predicates are
# pure-pull (Rule 2) and stay correct even if these callbacks never fire (AC-14).
# Story 004 scope keeps the edge-tracking bodies minimal; the actual edge logic
# is light and lands with the notification producers (#8/#28).

## GSM state_changed callback. EXACTLY 3 args `(from: int, to: int, payload)` and
## passed to connect_for_initial_state WITHOUT .bind() (AC-20 / ADR-0006 Contract 6:
## the helper delivers the initial state via positional callv — a 2-arg callback or
## a .bind()-shifted layout would mis-deliver / crash off-stack).
##
## `from`/`to` are GameStateMachine.GameState enum values (int-compatible); `payload`
## is a StateTransitionPayload (untyped here to keep the DI seam decoupled). The
## initial-state delivery carries payload.source_event == "initial_state".
func _on_gsm_state_changed(from: int, to: int, payload) -> void:
	# Notification-suppression edge tracking (Rule 7) lands here. Story 004 scope:
	# minimal — derivation is pure-pull and does not depend on this callback (AC-14).
	pass


## WST phase_changed callback. 2 args `(from: int, to: int)` — plain .connect form
## (WST has no connect_for_initial_state helper and phase_changed carries no payload).
## Distinct from _on_gsm_state_changed: do NOT confuse the two arities (AC-20).
func _on_wst_phase_changed(from: int, to: int) -> void:
	# Notification-suppression edge tracking (Rule 7) lands here. Story 004 scope:
	# minimal — derivation is pure-pull and does not depend on this callback (AC-14).
	pass
