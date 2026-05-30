# StatSystem — Autoload position 5 (#11)
#
# Status: LOCKED-SURFACE skeleton — minimal vertical slice covering AC-01 / AC-04 / AC-05 only.
# Driving GDD: design/gdd/stat-system.md (Approved 2026-05-27; Pass 2 with patches applied)
# Provides: get_stat(stat_id) hot path for #13 CombatResolver, #26 AvatarRenderer
#
# SCOPE NOTE (intentional minimal surface — see Q1 decision 2026-05-29):
#   IMPLEMENTED : StatId constants (Rule 1), StatSource enum (Rule 3),
#                 get_stat() read API (Rule 1 / AC-01), apply_stat_delta()
#                 validate-then-mutate path covering source-enum + allow-list
#                 reject (Rule 3 / Rule 4 / AC-04 / AC-05), stat_mutation_rejected
#                 telemetry (Rule 16 subset).
#   IMPLEMENTED+ : persistence write (Rule 7, Story 006), equipment modifier layer
#                 (Rule 5, Story 003), observer broadcast / connect_for_initial_state
#                 (Rule 6, Story 005), boot reconciliation (Story 004), anti-decay +
#                 clamping + stat_clamped telemetry (Rules 11/12, Story 007),
#                 DEBUG_OVERRIDE release-build runtime guard (Rule 10, Story 008),
#                 GSM Suspended gate + Reconciling re-read (Rule 14, Story 009).
#   DEFERRED    : derived-stat FORMULAS (Rule 13 step 7 — derived stats still return a
#                 0.0 placeholder + equipment delta until Section D / Story 010 lands),
#                 mutation formulas (Story 011), cross-knob invariants (Story 012).
extends Node

## Stat identifier constants (Rule 1 — LOCKED stat surface; no magic strings).
## Base stats are persisted; derived stats are computed on-read (currently a
## 0.0 placeholder per the Q2 minimal-surface decision).
class StatId:
	# Base stats (persisted)
	const STR: StringName = &"str"
	const DEX: StringName = &"dex"
	const VIT: StringName = &"vit"
	# Derived stats (computed on-read; placeholder until Section D formulas land)
	const MAX_HP: StringName = &"max_hp"
	const ATTACK_POWER: StringName = &"attack_power"
	const MOVE_SPEED: StringName = &"move_speed"
	const CRIT_CHANCE: StringName = &"crit_chance"

## Transient equipment modifier — NOT a Resource, NOT serialized, NOT persisted.
## keys = StatId StringNames; values = float deltas.
## One StatModifier per equipped item, keyed by equipment_id in _equipment_modifiers.
class StatModifier extends RefCounted:
	var deltas: Dictionary  # { StatId.STR: 5.0, StatId.MAX_HP: 50.0, ... }

	func _init(delta_map: Dictionary = {}) -> void:
		deltas = delta_map

## StatSource enum (Rule 3 — 5 values, 4 mutation + 1 sentinel).
## Declaration order is load-bearing for AC-04 ordinal inspection:
## PR_BREAKTHROUGH=0, VOLUME_TICK=1, EQUIPMENT=2, DEBUG_OVERRIDE=3, INITIAL_STATE=4.
enum StatSource {
	PR_BREAKTHROUGH,
	VOLUME_TICK,
	EQUIPMENT,
	DEBUG_OVERRIDE,
	INITIAL_STATE,
}

## Boot lifecycle substate (Story 004). Ordinal 0 = INITIALISING is the safe
## pre-_ready() default (matches ADR-0007 Outcome/State family: 0 = safe default).
## Boot drives INITIALISING → RECONCILING (during read/clamp) → READY. SUSPENDED
## is reserved for Story 009 (Suspended gate); RECONCILING is an internal boot
## phase exposed for test inspection.
enum Substate {
	INITIALISING,
	READY,
	SUSPENDED,
	RECONCILING,
}

## Telemetry: emitted on any mutation reject path (Rule 16 subset).
## reason ∈ {"invalid_stat_id", "invalid_source", "source_stat_mismatch",
##           "sentinel_not_a_mutation"} for this minimal surface.
signal stat_mutation_rejected(
	stat_id: StringName,
	source: StatSource,
	delta: float,
	reason: String,
)

## Emitted after any stat value changes (base mutation or equipment modifier recompute).
## is_base_change = true for apply_stat_delta mutations; false for equipment modifier recomputes.
## Story 003 (Equipment Modifier Layer): equipment paths emit with source=EQUIPMENT,
## is_base_change=false. Base-mutation emission from apply_stat_delta is DEFERRED to a
## later story (observer broadcast / Rule 6) — apply_stat_delta does NOT emit here yet.
signal stat_changed(
	stat_id: StringName,
	old_value: float,
	new_value: float,
	source: StatSource,
	is_base_change: bool,
)

## Emitted once at the end of boot reconciliation (Story 004 / AC-22), AFTER the
## GSM subscription is wired so any state delivered during connect is already
## handled. Carries no payload — subscribers re-read via get_stat().
signal boot_completed()

## Emitted when a live mutation is clamped to the [0, MAX_STAT_VALUE] range
## (Story 007 / Rule 11 / AC-15 / AC-16 / AC-21). attempted_value is the raw
## (pre-clamp) target (old + delta); clamped_value is the value actually stored.
## Telemetry-only: clamping is NOT an error — apply_stat_delta still returns true
## and stat_changed still fires with the clamped new_value. #28 Telemetry routes
## this for balance tuning (a stat repeatedly hitting a boundary is a signal).
signal stat_clamped(
	stat_id: StringName,
	attempted_value: float,
	clamped_value: float,
)

## Emitted when a persisted base stat is unrecoverable (Story 004 corrupt path
## AC-12, and Story 006 atomic-write failure AC-18). Boot continues in degraded
## mode (the corrupt stat falls back to DEFAULT_BASE_VALUE); a write failure
## leaves _base unchanged. Distinct from stat_mutation_rejected: that signal is
## for validation rejects, this one is for persistence/data-integrity failures.
signal stat_critical_save_failed(stat_id: StringName)

## First-boot default for the three base stats (Rule 11; Q2 decision STR 10→11
## requires a 10.0 baseline so AC-05 can assert the +1 delta lands at 11.0).
const DEFAULT_BASE_VALUE: float = 10.0

## Upper clamp ceiling for persisted base stats during boot reconciliation
## (Story 004 AC-12b). A persisted value above this is clamped down with a
## push_warning; clamping of live mutations (apply_stat_delta) lands in Story 007.
const MAX_STAT_VALUE: float = 999.0

## Placeholder value for derived stats until Section D formulas are implemented
## (Q2 decision — superseded by Story 010 real formulas below; retained only so the
## historical 0.0-baseline scope note above still parses. No longer read by any path.)
const DERIVED_PLACEHOLDER: float = 0.0

# --- Derived-stat formula knobs (Story 010 / Formulas F3-F6) -----------------------------
# All 10 are designer-tunable balance constants (data-driven intent — kept as module
# constants for the hot get_stat() path; a future LootRarityConfig-style .tres can override
# at boot if Section D needs runtime tuning). Cross-knob safety is enforced by
# _assert_knob_invariants() (Story 012). Baselines (STR=DEX=VIT=10, no equipment):
#   MAX_HP=160, ATTACK_POWER=28, MOVE_SPEED=184.0, CRIT_CHANCE=0.015.

## F3 MAX_HP = HP_BASE + VIT * HP_PER_VIT (+ equipment), floored at 1.
const HP_BASE: float = 80.0
const HP_PER_VIT: float = 8.0

## F4 ATTACK_POWER = ATK_BASE + STR * ATK_PER_STR + DEX * ATK_PER_DEX (+ equipment), floored at 1.
const ATK_BASE: float = 10.0
const ATK_PER_STR: float = 1.5
const ATK_PER_DEX: float = 0.3

## F5 MOVE_SPEED = min(MOVE_BASE + DEX * MOVE_PER_DEX (+ equipment), MOVE_CAP).
const MOVE_BASE: float = 180.0
const MOVE_PER_DEX: float = 0.4
const MOVE_CAP: float = 420.0

## F6 CRIT_CHANCE = min(DEX * CRIT_PER_DEX (+ equipment), MAX_CRIT_CHANCE).
const CRIT_PER_DEX: float = 0.0015
const MAX_CRIT_CHANCE: float = 0.50

# --- Mutation formula knobs (Story 011 / Formulas F1-F2) ---------------------------------
# F1/F2 are COMPUTED BY THE CALLER (#9 PR/#18 VolumeTick), not by StatSystem — the caller
# passes a pre-computed delta to apply_stat_delta. These constants are the single source of
# truth those callers reference (and the Story 011 tests reference) so the formula math is
# not duplicated as magic numbers.

## F1 per-tick volume increment (base step a VOLUME_TICK mutation adds before scaling).
const VOLUME_TICK_BASE: float = 0.05

## F2 PR base gain. PROVISIONAL — ADR-0005 flags this for retune once the loot/PR economy
## is balanced; do NOT treat as final. F2 delta = PR_BASE * (stat/100) * (1 - (stat/MAX)^PR_DIMINISH_EXP).
const PR_BASE: float = 6.0
const PR_DIMINISH_EXP: float = 2.0

## All 7 locked stat_ids in canonical order (Story 005). Drives
## connect_for_initial_state's initial-delivery loop so every subscriber receives
## exactly 7 deliveries (AC-08). Order: 3 base then 4 derived.
const _ALL_STAT_IDS: Array[StringName] = [
	StatId.STR, StatId.DEX, StatId.VIT,
	StatId.MAX_HP, StatId.ATTACK_POWER, StatId.MOVE_SPEED, StatId.CRIT_CHANCE,
]

# The three persisted base stats. Mutation only via apply_stat_delta (Rule 2).
var _base: Dictionary = {
	StatId.STR: DEFAULT_BASE_VALUE,
	StatId.DEX: DEFAULT_BASE_VALUE,
	StatId.VIT: DEFAULT_BASE_VALUE,
}

## Transient modifier table (keyed by equipment_id: StringName → StatModifier).
## Empty at boot — #17 Equipment Inventory replays modifiers in its own _ready().
## NEVER persisted — apply_equipment_modifier MUST NOT call PersistenceLayer.write().
var _equipment_modifiers: Dictionary = {}

# Source → allowed stat_id set (Rule 4 allow-list). For this minimal surface the
# table covers all 5 sources; INITIAL_STATE maps to an empty set (sentinel is
# never a valid mutation target — Rule 3 / AC-04).
var _source_allow_list: Dictionary = {
	StatSource.PR_BREAKTHROUGH: [StatId.STR, StatId.DEX, StatId.VIT],
	StatSource.VOLUME_TICK: [StatId.STR, StatId.DEX, StatId.VIT],
	StatSource.EQUIPMENT: [
		StatId.STR, StatId.DEX, StatId.VIT,
		StatId.MAX_HP, StatId.ATTACK_POWER, StatId.MOVE_SPEED, StatId.CRIT_CHANCE,
	],
	StatSource.DEBUG_OVERRIDE: [
		StatId.STR, StatId.DEX, StatId.VIT,
		StatId.MAX_HP, StatId.ATTACK_POWER, StatId.MOVE_SPEED, StatId.CRIT_CHANCE,
	],
	StatSource.INITIAL_STATE: [],
}

## PersistenceLayer reference — overrideable for testing (dependency injection seam).
## Production: points to the PersistenceLayer autoload singleton. Tests inject a mock
## before add_child()/_ready().
## Untyped INTENTIONALLY: read()/write()/critical_save_failed are NOT Node members, so
## a typed (Node) annotation would fail GDScript's compile-time member check. Duck-typed
## seam — memory-confirmed pattern shared with StreakSystem (Story 004/006).
var _persistence = null

## GameStateMachine reference — overrideable for testing (dependency injection seam).
## Production: points to the GameStateMachine autoload singleton. Tests inject a mock GSM.
## Untyped INTENTIONALLY: connect_for_initial_state is not a Node member (same rationale as
## _persistence). Subscribed in _ready() (Story 004); handler body lands in Story 009.
var _gsm = null

## Boot lifecycle substate (Story 004). INITIALISING until _ready() completes
## reconciliation, then READY. Inspected by boot tests; mutated only by _ready().
var _substate: Substate = Substate.INITIALISING

## Contract 7 race guard (Story 005). Bumped on every real stat_changed emit; a
## connect_for_initial_state subscriber captures this at connect-time so a stale
## initial delivery can be detected. (Capture-only in Story 005; the skip branch
## is exercised once a same-frame deferred path exists — kept for parity with GSM.)
var _last_emit_tick: int = 0

## Re-entrance guard depth (Story 006 / AC-33). apply_stat_delta increments around
## its stat_changed.emit(); a subscriber that calls back into apply_stat_delta sees
## _emit_depth > 0 and is rejected, preventing unbounded recursion / stack overflow.
var _emit_depth: int = 0

## DEBUG_OVERRIDE release-build guard seam (Story 008 / AC-13/13b/13c). null is the
## production default — _get_is_debug() falls through to OS.is_debug_build(). Tests
## set this to false to simulate a release export (OS.is_debug_build() is untestable
## in GUT without a real release build) or true to force the debug path.
## Variant INTENTIONALLY (3-state: null / true / false) — a typed bool could not
## express "no override; defer to the engine".
var _debug_build_override: Variant = null

## Pre-Suspension base-stat snapshot (Story 009 / AC-new-reconciling). Captured when
## GSM enters Suspended so the Reconciling re-read can emit a delta stat_changed only
## for keys the backend actually changed during suspension. Empty outside a
## Suspended→Reconciling cycle.
var _pre_suspended_snapshot: Dictionary = {}

## The 3 persisted base keys, paired with their StatId, in canonical order. Drives
## the Reconciling re-read loop (Story 009). Module-scope constant so the loop does
## not rebuild the pairing each resume.
const _BASE_KEY_PAIRS: Array = [
	["stat.str", StatId.STR],
	["stat.dex", StatId.DEX],
	["stat.vit", StatId.VIT],
]


## Boot reconciliation (Story 004). Synchronous — NO await (ADR-0006 Contract 12).
## Sequence: resolve DI singletons → read+reconcile the 3 persisted base stats →
## populate _base → subscribe to GSM → flip to READY → emit boot_completed.
## NO stat_changed is emitted during boot (subscribers connect via
## connect_for_initial_state AFTER boot, Story 005).
func _ready() -> void:
	if _persistence == null:
		_persistence = PersistenceLayer
	if _gsm == null:
		_gsm = GameStateMachine

	# Story 012 — cross-knob invariant gate (AC-30/AC-31). Runs BEFORE reconciliation so
	# a mis-tuned knob set fails fast at boot (debug builds) rather than silently producing
	# broken derived values. assert() is stripped in release builds — the invariants are a
	# development/CI safety net, not a runtime cost on the hot path.
	_assert_knob_invariants()

	_substate = Substate.RECONCILING
	_base[StatId.STR] = _reconcile_base_stat(StatId.STR)
	_base[StatId.DEX] = _reconcile_base_stat(StatId.DEX)
	_base[StatId.VIT] = _reconcile_base_stat(StatId.VIT)

	# ADR-0006 Contract 6: subscribe via connect_for_initial_state (NEVER
	# _gsm.state_changed.connect directly — see streak_system + GSM doc). Handler
	# body is a Story 009 concern; the stub accepts the 3-arg callv layout.
	_gsm.connect_for_initial_state(_on_gsm_state_changed)

	_substate = Substate.READY
	# AC-22: emitted AFTER the GSM subscription is wired.
	boot_completed.emit()


## Reconcile one persisted base stat (Story 004 / AC-10..AC-12b). Reads the
## "stat.<id>" key and resolves it to a usable float:
##   - absent / non-float ({}/null) → DEFAULT_BASE_VALUE + push_warning (AC-10/AC-11)
##   - NaN / Inf                    → DEFAULT_BASE_VALUE + push_error + critical signal
##                                     (AC-12 degraded mode — boot continues)
##   - < 0.0                        → clamp to 0.0 + push_warning (AC-12b)
##   - > MAX_STAT_VALUE             → clamp to MAX_STAT_VALUE + push_warning (AC-12b)
##   - otherwise                    → used as-is
## NO await, no emit (subscribers are not connected during boot).
func _reconcile_base_stat(stat_id: StringName) -> float:
	var key: String = "stat." + String(stat_id)
	var result: Variant = _persistence.read(key)

	if typeof(result) != TYPE_FLOAT:
		# absent / {} / null / wrong type — first-boot or missing key (AC-10/AC-11).
		push_warning("%s absent — defaulting to %s" % [key, DEFAULT_BASE_VALUE])
		return DEFAULT_BASE_VALUE

	var v: float = result
	if is_nan(v) or is_inf(v):
		# Corrupt save — degraded mode (AC-12). Fall back but flag the failure.
		push_error("%s corrupt (NaN/Inf) — defaulting to %s, degraded mode" % [key, DEFAULT_BASE_VALUE])
		stat_critical_save_failed.emit(stat_id)
		return DEFAULT_BASE_VALUE

	if v < 0.0:
		push_warning("%s below floor (%s) — clamping to 0.0" % [key, v])
		return 0.0

	if v > MAX_STAT_VALUE:
		push_warning("%s above ceiling (%s) — clamping to %s" % [key, v, MAX_STAT_VALUE])
		return MAX_STAT_VALUE

	return v


## GSM state delivery handler (Story 009 / Rule 14 / AC-20 / AC-new-reconciling).
## Signature mirrors StreakSystem's handler so the GSM callv positional layout
## ([from, to, payload]) delivers correctly (ADR-0006 Contract 6). State comparison
## is enum-typed (`to_state == GameStateMachine.GameState.SUSPENDED`) per the Q1
## decision — NOT string-name parsing — keeping the typed signature and avoiding any
## dependency on the GSM callv layout carrying string names.
##
## Transitions:
##   - INITIAL_STATE sentinel delivery whose `to` is SUSPENDED (EC-24): enter
##     Suspended immediately after boot (backend already suspended at connect time).
##     Other sentinel deliveries are a no-op (boot already left _substate at READY).
##   - real transition → SUSPENDED: enter Suspended, snapshot _base for the eventual
##     Reconciling delta.
##   - real transition leaving SUSPENDED (any non-Suspended `to`): run the
##     synchronous Reconciling re-read, then return to READY.
##   - any other real transition: no-op (Stat System only reacts to the Suspended seam).
func _on_gsm_state_changed(
	_from_state: GameStateMachine.GameState,
	to_state: GameStateMachine.GameState,
	payload: StateTransitionPayload,
) -> void:
	var is_initial: bool = payload != null \
			and payload.source_event == GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT

	if to_state == GameStateMachine.GameState.SUSPENDED:
		# EC-24: a SUSPENDED initial delivery still latches Suspended — the only
		# difference from a real transition is provenance, not the resulting gate.
		_enter_suspended()
		return

	if is_initial:
		# Non-Suspended initial delivery — boot already left _substate at READY; the
		# sentinel carries no transition to reconcile. No-op.
		return

	# Real, non-Suspended transition. Only meaningful if we were Suspended — that is
	# the GSM-resume edge that triggers the Pillar 1 anti-stale Reconciling re-read.
	if _substate == Substate.SUSPENDED:
		_reconcile_after_resume()


## Enter the Suspended substate (Story 009). Captures a pre-Suspension snapshot of
## _base so the resume-time Reconciling re-read can compute a precise delta. Idempotent:
## re-entering Suspended while already Suspended just refreshes the snapshot.
func _enter_suspended() -> void:
	_substate = Substate.SUSPENDED
	_pre_suspended_snapshot = _base.duplicate()


## Reconciling re-read after GSM leaves Suspended (Story 009 / AC-new-reconciling).
## Pillar 1 anti-stale guarantee: the backend may have advanced the persisted base
## stats while we were gated, so we re-read all 3 base keys synchronously (NO await —
## ADR-0006 Contract 12) and emit a delta stat_changed for any key whose fresh value
## differs from the pre-Suspension snapshot. Non-float / absent reads are skipped (the
## prior in-memory value is authoritative — we never fabricate a default here, which
## would clobber a good cached value on a transient read miss). Source is
## PR_BREAKTHROUGH per the Q1 decision (known semantic stretch — the backend recorded
## the change; orchestrator logs the tech debt). Substate returns to READY at the end.
func _reconcile_after_resume() -> void:
	_substate = Substate.RECONCILING
	for pair: Array in _BASE_KEY_PAIRS:
		var key: String = pair[0]
		var stat_id: StringName = pair[1]
		var fresh: Variant = _persistence.read(key)
		# Skip non-float / absent reads — keep the cached value, do NOT emit (point C).
		if typeof(fresh) != TYPE_FLOAT:
			continue
		var snapshot_value: float = _pre_suspended_snapshot.get(stat_id, _base[stat_id])
		if fresh == snapshot_value:
			continue  # backend unchanged for this key — no delta, no emit.
		var old_value: float = _base[stat_id]
		_base[stat_id] = fresh
		# Bump the emit tick for Contract 7 race-guard parity (same as apply_stat_delta).
		_last_emit_tick += 1
		stat_changed.emit(stat_id, old_value, fresh, StatSource.PR_BREAKTHROUGH, false)
	_pre_suspended_snapshot.clear()
	_substate = Substate.READY


## True while the mutation API is gated by the GSM Suspended seam (Story 009 / Rule 14).
## Covers BOTH Suspended and the transient Reconciling re-read window — a mutation
## arriving mid-reconcile would race the delta emit, so both substates reject uniformly
## with reason "suspended_substate" (GDD EC-21). get_stat() is NOT gated (read-only).
func _is_mutation_gated() -> bool:
	return _substate == Substate.SUSPENDED or _substate == Substate.RECONCILING


## DEBUG_OVERRIDE build-context resolver (Story 008 / AC-13c). Falls through to
## OS.is_debug_build() unless a test has set the _debug_build_override seam. Kept as a
## one-liner so the apply_stat_delta guard reads cleanly.
func _get_is_debug() -> bool:
	if _debug_build_override != null:
		return _debug_build_override
	return OS.is_debug_build()


## Connect a subscriber for initial-state delivery + future stat mutations
## (Story 005 / Rule 6 / AC-08). Mirrors GSM's connect_for_initial_state contract:
## the callable receives a synchronous burst of 7 "initial" deliveries (one per
## locked stat_id, in _ALL_STAT_IDS order), then is connected to stat_changed for
## all future emissions.
##
## CALLABLE SIGNATURE (unified 5-arg positional layout):
##   (stat_id, old_value, new_value, source, is_initial_or_base: bool)
## The 5th param is dual-purpose by position (this is a deliberate, documented
## design — see Story 005 note):
##   - initial delivery (here): 5th = `true`  → "this is a boot/initial delivery"
##   - real stat_changed emit : 5th = is_base_change (false for equipment, etc.)
## A subscriber treats the 5th param as "is this the initial snapshot?" — true only
## for the burst below; every real emission passes the stat_changed semantics.
##
## INITIAL DELIVERY uses old == new == current value, source = INITIAL_STATE, so a
## subscriber can render current state without inferring a fake transition.
##
## NO .bind(): a bound callable shifts the positional layout and silently mis-delivers
## (AC-08c). Debug builds push_error if the callable carries bound args.
func connect_for_initial_state(callable: Callable) -> void:
	# Reject bound callables UNCONDITIONALLY (not gated on debug build): a bound
	# callable mis-delivers every row via shifted callv args, and in a release build
	# that corruption would be silent. The check is a zero-cost int compare, so there
	# is no reason to skip it in release. (AC-08c asserts the debug-build path.)
	if callable.get_bound_arguments_count() > 0:
		push_error(
			"[StatSystem] connect_for_initial_state: callable must NOT use .bind() — "
			+ "bound args shift the positional callv layout (AC-08c)"
		)
		# Reject: a bound callable would mis-deliver every row. Do NOT connect or
		# deliver — surfacing the error and bailing is safer than silent corruption.
		return

	# Contract 7 race guard: capture the emit tick at connect-time (parity with GSM).
	var _captured_tick: int = _last_emit_tick

	# Synchronous initial burst: 7 deliveries, one per locked stat_id.
	for stat_id: StringName in _ALL_STAT_IDS:
		var current: float = get_stat(stat_id)
		callable.callv([stat_id, current, current, StatSource.INITIAL_STATE, true])

	# Connect for all future real mutations (stat_changed 5-arg layout).
	stat_changed.connect(callable)


## Read API (Rule 1 / AC-01). O(1), side-effect-free.
## Returns the canonical float value for any of the 7 locked stat_ids.
## Base stats read from the in-memory cache; derived stats return the 0.0
## placeholder (Q2). Unknown stat_id returns NAN and does NOT crash (AC-01).
func get_stat(stat_id: StringName) -> float:
	if _base.has(stat_id):
		return _base[stat_id]
	if _is_derived_stat(stat_id):
		return _compute_derived(stat_id)
	push_error("[StatSystem] get_stat: unknown stat_id '%s'" % stat_id)
	stat_mutation_rejected.emit(stat_id, StatSource.INITIAL_STATE, 0.0, "invalid_stat_id")
	return NAN


## Sole mutation entry point (Rule 2 closed API). Minimal-surface validation:
##   1. source must be a valid StatSource enum value (Rule 3 / EC-08)
##   2. INITIAL_STATE sentinel is never a mutation (Rule 3 / AC-04)
##   3. stat_id must be in the source's allow-list (Rule 4 / AC-05 / EC-09)
## On success the base stat is mutated in-memory and true is returned. On any
## reject path stat_mutation_rejected fires and false is returned; _base is
## unchanged. Persistence, derived recompute, clamping, no-decay, Suspended gate,
## and observer broadcast are DEFERRED (see scope note).
func apply_stat_delta(stat_id: StringName, source: StatSource, delta: float) -> bool:
	# Guard order (LOCKED — Story 006/007/008/009 composite):
	#   re-entrance → debug-release → suspended → anti-decay
	#     → enum/sentinel/allow-list/derived → compute+clamp → persist → mutate → emit
	# Each guard fires before any side effect of a later guard so a reject leaves
	# _base, disk, and subscribers untouched.

	# (1) Story 006 / AC-33 — re-entrance guard. A subscriber that calls back into
	# apply_stat_delta from its stat_changed handler would recurse unboundedly;
	# reject the nested call. Checked FIRST so no validation/persist side effects
	# fire on the re-entrant path.
	if _emit_depth > 0:
		push_error("[StatSystem] apply_stat_delta: re-entrant mutation rejected (AC-33) — "
			+ "a stat_changed subscriber must not mutate stats synchronously")
		return false

	# (2) Story 008 / AC-13 — DEBUG_OVERRIDE release-build runtime guard (FR-3 Pillar 1
	# hard guarantee). Fires before anti-decay and allow-list so a release build NEVER
	# processes a DEBUG_OVERRIDE mutation regardless of any other validation state.
	if source == StatSource.DEBUG_OVERRIDE and not _get_is_debug():
		push_error("[StatSystem] apply_stat_delta: DEBUG_OVERRIDE blocked in release build (AC-13)")
		stat_mutation_rejected.emit(stat_id, source, delta, "debug_override_release_blocked")
		return false

	# (3) Story 009 / AC-20 — GSM Suspended gate (Rule 14). While GSM holds the system
	# Suspended (or mid-Reconciling), all mutations reject with a push_warning. Read-only
	# get_stat() is intentionally NOT gated.
	if _is_mutation_gated():
		push_warning("[StatSystem] apply_stat_delta: rejected during %s substate (AC-20)"
			% Substate.keys()[_substate])
		stat_mutation_rejected.emit(stat_id, source, delta, "suspended_substate")
		return false

	# (4) Story 007 / AC-17 — anti-decay (Rule 12). Base stats (STR/DEX/VIT) cannot
	# decay via PR_BREAKTHROUGH or VOLUME_TICK (Pillar 1 anti-fabrication). DEBUG_OVERRIDE
	# is exempt (debug/test may push base stats down); EQUIPMENT never reaches this path.
	# Derived stats are not in _base so the base-only set check excludes them naturally.
	if delta < 0.0 \
			and _base.has(stat_id) \
			and source != StatSource.DEBUG_OVERRIDE:
		push_error("[StatSystem] apply_stat_delta: base-stat decay blocked for '%s' (AC-17, Rule 12)" % stat_id)
		stat_mutation_rejected.emit(stat_id, source, delta, "base_stat_decay_blocked")
		return false

	# (5) Rule 3 / EC-08 — defensive enum membership check.
	if not StatSource.values().has(source):
		push_error("[StatSystem] apply_stat_delta: invalid source enum '%s'" % source)
		stat_mutation_rejected.emit(stat_id, source, delta, "invalid_source")
		return false

	# Rule 3 / AC-04 — INITIAL_STATE is a subscriber-delivery sentinel, never a mutation.
	if source == StatSource.INITIAL_STATE:
		push_error("[StatSystem] apply_stat_delta: INITIAL_STATE is a sentinel, not a valid mutation source")
		stat_mutation_rejected.emit(stat_id, source, delta, "invalid_source")
		return false

	# Rule 4 / AC-05 / EC-09 — source→stat_id allow-list.
	var allowed: Array = _source_allow_list.get(source, [])
	if not allowed.has(stat_id):
		# Distinguish "unknown stat entirely" (EC-07) from "known stat, wrong source"
		# (EC-09) so #28 Telemetry can route the two cases differently.
		var reason: String = "invalid_stat_id" if not _is_known_stat(stat_id) else "source_stat_mismatch"
		push_error("[StatSystem] apply_stat_delta: %s for stat_id '%s' under source %s" % [reason, stat_id, source])
		stat_mutation_rejected.emit(stat_id, source, delta, reason)
		return false

	# Minimal mutate: only base stats are mutable in this surface (derived are
	# computed on-read and have no backing store yet — equipment/derived writes
	# are DEFERRED). A derived stat reaching here means an EQUIPMENT/DEBUG source
	# targeted it; reject as out-of-scope rather than silently dropping.
	if not _base.has(stat_id):
		push_error("[StatSystem] apply_stat_delta: derived-stat mutation not implemented in minimal surface ('%s')" % stat_id)
		stat_mutation_rejected.emit(stat_id, source, delta, "source_stat_mismatch")
		return false

	# (6) Story 007 — compute + clamp (Rule 11 / AC-15 / AC-16). The raw target is
	# clamped to [0, MAX_STAT_VALUE]; a triggered clamp emits stat_clamped telemetry
	# (AC-21) but is NOT an error — the (possibly clamped) value still persists and
	# broadcasts. EC-10: a delta that lands exactly on a boundary does not clamp.
	var old_value: float = _base[stat_id]
	var raw_target: float = old_value + delta
	var target: float = clampf(raw_target, 0.0, MAX_STAT_VALUE)
	if target != raw_target:
		# AC-21 telemetry — emitted before persist so #28 sees the attempt even if the
		# subsequent write fails (the clamp decision itself already happened).
		stat_clamped.emit(stat_id, raw_target, target)

	# Story 006 — persist-first atomic write sequence (AC-18/AC-19).
	# 1. Persist FIRST. If the write fails, _base stays unchanged (AC-18) and
	#    we surface a critical failure rather than diverging memory from disk.
	var persist_ok: bool = _persistence.write("stat." + String(stat_id), target, flush_for_source(source))
	if not persist_ok:
		push_error("[StatSystem] apply_stat_delta: persist failed for '%s' — _base unchanged (AC-18)" % stat_id)
		stat_critical_save_failed.emit(stat_id)
		return false

	# 2. Mutate _base only AFTER a successful persist (AC-19 — subscribers that
	#    read get_stat() inside the emit below see the NEW value).
	_base[stat_id] = target

	# 3. Emit guarded by _emit_depth so a re-entrant apply_stat_delta is rejected
	#    (AC-33). _last_emit_tick bumped for Contract 7 race-guard parity.
	_emit_depth += 1
	_last_emit_tick += 1
	stat_changed.emit(stat_id, old_value, target, source, false)
	_emit_depth -= 1

	return true


## Persistence flush policy (Story 006 / AC-09). High-stakes mutations
## (PR_BREAKTHROUGH, DEBUG_OVERRIDE) flush to disk immediately so a crash cannot
## lose them; high-frequency mutations (VOLUME_TICK) defer the flush to the
## PersistenceLayer's batched cadence. EQUIPMENT never reaches apply_stat_delta
## (it routes through apply_equipment_modifier and never persists). INITIAL_STATE
## is a sentinel and is rejected before this is consulted.
func flush_for_source(source: StatSource) -> bool:
	match source:
		StatSource.PR_BREAKTHROUGH:
			return true
		StatSource.DEBUG_OVERRIDE:
			return true
		_:
			return false


## Apply (or replace) a transient equipment modifier (Rule 5 / Story 003 / AC-06 / AC-08).
## Idempotent on equipment_id — re-applying the same id overwrites the prior modifier.
## For each DERIVED stat_id present in modifier.deltas, captures the old derived value,
## recomputes the new value (with the new modifier table in place), and emits
## stat_changed(stat_id, old, new, EQUIPMENT, false).
## Unknown stat_id keys are silently IGNORED (EC-19 — no push_error). Base-stat deltas
## carried by an equipment modifier do NOT mutate _base and do NOT emit here — base stats
## change only through apply_stat_delta (Rule 2). This path NEVER persists (AC-07) and
## NEVER calls apply_stat_delta.
func apply_equipment_modifier(equipment_id: StringName, modifier: StatModifier) -> void:
	# Capture old derived values for every derived stat this modifier (new or prior) touches.
	var affected: Dictionary = _collect_affected_derived(equipment_id, modifier)
	var old_values: Dictionary = {}
	for stat_id: StringName in affected:
		old_values[stat_id] = _compute_derived(stat_id)

	# Idempotent overwrite — same equipment_id replaces the prior modifier.
	_equipment_modifiers[equipment_id] = modifier

	# Recompute and emit for each affected derived stat.
	_emit_derived_changes(affected, old_values)


## Remove a transient equipment modifier (Rule 5 / Story 003).
## EC-18: if equipment_id is not present, this is a no-op with no emit and no error.
## Otherwise captures old derived values, removes the modifier, recomputes, and emits
## stat_changed for each derived stat that the removed modifier affected.
func remove_equipment_modifier(equipment_id: StringName) -> void:
	if not _equipment_modifiers.has(equipment_id):
		return  # EC-18 — unknown id is a silent no-op.

	var prior: StatModifier = _equipment_modifiers[equipment_id]
	var affected: Dictionary = {}
	var old_values: Dictionary = {}
	for stat_id: StringName in prior.deltas:
		if _is_derived_stat(stat_id):
			affected[stat_id] = true
			old_values[stat_id] = _compute_derived(stat_id)

	_equipment_modifiers.erase(equipment_id)

	_emit_derived_changes(affected, old_values)


## Build the set of DERIVED stat_ids affected by applying `modifier` to `equipment_id`,
## including any derived stats the PRIOR modifier (same id) touched so removals/shrinks
## of the delta set also re-emit. Returns a Dictionary used as a set (stat_id → true).
func _collect_affected_derived(equipment_id: StringName, modifier: StatModifier) -> Dictionary:
	var affected: Dictionary = {}
	for stat_id: StringName in modifier.deltas:
		if _is_derived_stat(stat_id):
			affected[stat_id] = true
	if _equipment_modifiers.has(equipment_id):
		var prior: StatModifier = _equipment_modifiers[equipment_id]
		for stat_id: StringName in prior.deltas:
			if _is_derived_stat(stat_id):
				affected[stat_id] = true
	return affected


## Recompute the new derived value for each stat in `affected` (a set: stat_id → true)
## and emit stat_changed(stat_id, old, new, EQUIPMENT, false) using the captured
## `old_values`. Shared by apply/remove so both paths emit identically.
func _emit_derived_changes(affected: Dictionary, old_values: Dictionary) -> void:
	for stat_id: StringName in affected:
		var old_value: float = old_values[stat_id]
		var new_value: float = _compute_derived(stat_id)
		stat_changed.emit(stat_id, old_value, new_value, StatSource.EQUIPMENT, false)


## Compute the canonical value of a DERIVED stat (Story 010 / Formulas F3-F6).
## Dispatches to the per-stat formula. Each formula reads the relevant base stats from
## _base and folds in the summed equipment-modifier delta for that stat. Returns float
## for the whole derived surface: F3/F4 produce an int (HP/ATK are whole numbers) that
## widens to float on return — get_stat()'s contract is float, and AC-26 asserts 160 == 160.0,
## so the int→float widening is intentional and lossless for these ranges.
## Base stats (STR/DEX/VIT) are NOT routed here — they read _base directly via get_stat.
func _compute_derived(stat_id: StringName) -> float:
	match stat_id:
		StatId.MAX_HP:
			return _compute_max_hp()
		StatId.ATTACK_POWER:
			return _compute_attack_power()
		StatId.MOVE_SPEED:
			return _compute_move_speed()
		StatId.CRIT_CHANCE:
			return _compute_crit_chance()
	# Unreachable: callers gate on _is_derived_stat() before reaching here. Defensive
	# fallback keeps the function total (returns the equipment delta with no base term).
	push_error("[StatSystem] _compute_derived: non-derived stat_id '%s'" % stat_id)
	return _sum_equipment_delta(stat_id)


## F3 — MAX_HP = HP_BASE + VIT * HP_PER_VIT + equipment, floored at 1 (an entity always
## has at least 1 HP). int() truncates toward zero; maxi() applies the integer floor.
func _compute_max_hp() -> int:
	return maxi(1, int(
		HP_BASE
		+ _base[StatId.VIT] * HP_PER_VIT
		+ _sum_equipment_delta(StatId.MAX_HP)
	))


## F4 — ATTACK_POWER = ATK_BASE + STR * ATK_PER_STR + DEX * ATK_PER_DEX + equipment,
## floored at 1. STR dominates (ATK_PER_STR); DEX is a minor secondary (ATK_PER_DEX) —
## INV-4 (Story 012) guarantees DEX never out-scales STR here.
func _compute_attack_power() -> int:
	return maxi(1, int(
		ATK_BASE
		+ _base[StatId.STR] * ATK_PER_STR
		+ _base[StatId.DEX] * ATK_PER_DEX
		+ _sum_equipment_delta(StatId.ATTACK_POWER)
	))


## F5 — MOVE_SPEED = min(MOVE_BASE + DEX * MOVE_PER_DEX + equipment, MOVE_CAP).
## Hard cap (MOVE_CAP) prevents runaway DEX from breaking traversal/animation budgets;
## INV-6 (Story 012) guarantees the cap is reachable within the DEX range.
func _compute_move_speed() -> float:
	return minf(
		MOVE_BASE
		+ _base[StatId.DEX] * MOVE_PER_DEX
		+ _sum_equipment_delta(StatId.MOVE_SPEED),
		MOVE_CAP
	)


## F6 — CRIT_CHANCE = min(DEX * CRIT_PER_DEX + equipment, MAX_CRIT_CHANCE).
## Probability ceiling (MAX_CRIT_CHANCE) keeps crit a bonus, never a guarantee;
## INV-8 (Story 012) guarantees the cap is reachable within [0, MAX_STAT_VALUE].
func _compute_crit_chance() -> float:
	return minf(
		_base[StatId.DEX] * CRIT_PER_DEX
		+ _sum_equipment_delta(StatId.CRIT_CHANCE),
		MAX_CRIT_CHANCE
	)


## Sum every equipped item's delta for `stat_id` across the transient modifier table.
## Missing keys contribute 0.0 (Dictionary.get default). O(equipped-items); the table
## is small (player wears a handful of items) so this stays well within the hot-path budget.
func _sum_equipment_delta(stat_id: StringName) -> float:
	var total: float = 0.0
	for equipment_id: StringName in _equipment_modifiers:
		var modifier: StatModifier = _equipment_modifiers[equipment_id]
		total += modifier.deltas.get(stat_id, 0.0)
	return total


## True if stat_id is one of the 4 derived stats (Rule 1 surface).
func _is_derived_stat(stat_id: StringName) -> bool:
	return stat_id == StatId.MAX_HP \
		or stat_id == StatId.ATTACK_POWER \
		or stat_id == StatId.MOVE_SPEED \
		or stat_id == StatId.CRIT_CHANCE


## True if stat_id is any of the 7 locked stats (base or derived).
func _is_known_stat(stat_id: StringName) -> bool:
	return _base.has(stat_id) or _is_derived_stat(stat_id)


## Cross-knob invariant guard (Story 012 / AC-30/AC-31). Asserts the balance-knob set is
## internally consistent BEFORE boot proceeds. Each assert is a designer-safety contract;
## a violation means the knob constants were tuned into a broken regime. assert() is a no-op
## in release builds, so this is zero runtime cost on shipped builds — it exists to fail CI /
## debug boot loudly. Invariants (derivation in design/gdd/stat-system.md §F):
##   INV-1  PR_BASE doubled stays well under a 50/tick sanity ceiling (no PR runaway).
##   INV-3  MAX_HP at baseline VIT (10) is a survivable floor (>= 150).
##   INV-4  DEX must not dominate ATTACK_POWER — its per-point weight (doubled) < STR's.
##   INV-5  baseline ATTACK_POWER (STR=DEX=10) is a viable floor (>= 25).
##   INV-6  MOVE_SPEED cap is reachable within the DEX range (max DEX overshoots MOVE_CAP).
##   INV-8  CRIT_CHANCE cap is reachable AND requires a DEX inside [100, MAX_STAT_VALUE].
func _assert_knob_invariants() -> void:
	assert(PR_BASE * 2.0 < 50.0, "INV-1 violated: PR_BASE*2=%f" % (PR_BASE * 2.0))
	assert(HP_BASE + 10.0 * HP_PER_VIT >= 150.0, "INV-3 violated")
	assert(ATK_PER_DEX * 2.0 < ATK_PER_STR, "INV-4 violated: DEX must not dominate ATK")
	assert(ATK_BASE + 10.0 * ATK_PER_STR + 10.0 * ATK_PER_DEX >= 25.0, "INV-5 violated")
	assert(MOVE_BASE + 999.0 * MOVE_PER_DEX > MOVE_CAP, "INV-6 violated")
	var dex_for_crit: float = MAX_CRIT_CHANCE / CRIT_PER_DEX
	assert(dex_for_crit >= 100.0 and dex_for_crit <= MAX_STAT_VALUE, "INV-8 violated")
