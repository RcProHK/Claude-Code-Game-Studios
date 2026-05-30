# AbilitySystem — Autoload position 6 (#12)
#
# Status: CORE-SURFACE skeleton — Batch A (Stories 001/002/003).
# Driving GDD: design/gdd/ability-system.md (Approved 2026-05-27; Pass 2 with patches applied)
# Governing ADRs: ADR-0006 (State Machine Contract — Contract 12 chokepoints, NO await),
#                 ADR-0007 (Class & Domain Enum Convention — AbilityClass is Family B).
#
# SCOPE NOTE (Batch A — Stories 002/003, Batch B — Stories 004/005/006):
#   Story 002 — IMPLEMENTED: AbilityId constant surface (Rule 1), AbilityClass/AbilityTier
#               enums (ADR-0007 Family B), UnlockSource/CastResult/Substate enums, the 7
#               telemetry signals + boot_completed, the private _unlocked_abilities /
#               _cooldown_remaining tables, the DI seams, and the public API SIGNATURES
#               (unlock_ability / cast_ability / get_unlocked_abilities / get_ability_state).
#               The INITIAL_STATE sentinel reject guard (AC-05) is live.
#   Story 003 — IMPLEMENTED: source→class allow-list (Rule 6), caller-whitelist runtime
#               defense (_unlock_call_permitted, AC-30), idempotent unlock guard (EC-11,
#               AC-07b), and the _evaluate_unlock internal handler that derives the
#               expected class from a stat_id context (AC-07 cross-class reject).
#   Story 004 — IMPLEMENTED: UnlockRecord SerializableResource envelope (ADR-0006 C3),
#               persist-FIRST atomic write sequence in unlock_ability (persist → mutate →
#               emit, AC-17), per-source flush policy (flush_for_source, AC-13), persist-fail
#               rollback + ability_unlock_save_failed (AC-29), Path A handler
#               _on_pr_breakthrough (AC-10).
#   Story 005 — IMPLEMENTED: TIER_THRESHOLDS (Formula 1), Path B handler _on_stat_changed
#               subscribed via connect_for_initial_state (Rule 6 / EQUIPMENT excluded),
#               _evaluate_unlock_tiers multi-tier ascent + Formula 3 deterministic sort
#               (tier_ordinal, class_ordinal), _ability_id_for lookup.
#   Story 006 — IMPLEMENTED: cast_ability atomic sequence (re-entrance → registry → unlocked
#               → cooldown → GSM → stat → target → emit), BASE_COOLDOWN_SEC (Formula 2),
#               _start_cooldown, _process(delta) cooldown tick + set_process toggle +
#               MAX_FRAME_DELTA clamp, MAX_EMIT_DEPTH re-entrance guard (AC-28).
#   DEFERRED   : full boot reconciliation reading back persisted keys + AbilityRegistry.tres
#               + GSM Suspended mutation gate (Story 007/008). _ready() does a MINIMAL DI
#               resolve + subscribes the Path B handler; it does NOT yet replay persisted
#               unlocks. get_unlocked_abilities / get_ability_state remain Story-007-complete.
#
# ⚠️ F-SETUP-1 follow-up: GDD line 151 claims pos 5 (authored before PlatformDetect added).
# Actual project.godot position = 6 with PlatformDetect at pos 3. GDD prose sync needed.
extends Node

## Class-archetype dimension — ADR-0007 Family B (Pillar 4: Muscle = Class). 1:1 with
## STR/DEX/VIT (push/pull/leg). Declaration order is LOAD-BEARING (Ability Formula 3 emit
## ordering, #9 tiebreak walk) — STRIKE=0/CONTROL=1/MOBILITY=2 are fixed by GDD worked
## examples. UNKNOWN is the anti-fabrication sentinel placed LAST (=3): a producer returns
## it EXPLICITLY when no class can be determined; consumers MUST NOT treat a zero-default
## as STRIKE (Pillar 1). GDD AC-03 specified 3 values; ADR-0007 (Accepted 2026-05-29) locks
## 4 by adding the UNKNOWN sentinel — ADR-0007 takes precedence.
## Declared BEFORE AbilityId so the enum is resolvable if AbilityId metadata ever cross-refs it.
enum AbilityClass { STRIKE, CONTROL, MOBILITY, UNKNOWN }  # 0,1,2,3

## Ability tier — ADR-0007 Family B. Ordinals 0/1/2 load-bearing for Formula 3 sort.
enum AbilityTier { TIER_1, TIER_2, TIER_3 }  # 0,1,2

## Unlock provenance (Rule 4 — FR-1 LOCKED set). PR_BREAKTHROUGH and STAT_THRESHOLD are
## the two real stat-driven unlock paths; INITIAL_STATE is the ADR-0006 Contract 6 sentinel
## used only for initial-state delivery — it is NEVER a valid mutation source (AC-05).
enum UnlockSource { PR_BREAKTHROUGH, STAT_THRESHOLD, INITIAL_STATE }  # 0,1,2

## Cast outcome (Rule 5). SUCCESS=0 is the only success value; the rest are reject reasons
## the combat resolver surfaces to the caller. Ordinal 0 = SUCCESS follows ADR-0007 Family A
## (Outcome enum — but here 0 is the *success* path, not a sentinel; cast paths always set
## an explicit result, never relying on a zero-default).
enum CastResult { SUCCESS, NOT_UNLOCKED, ON_COOLDOWN, STAT_INSUFFICIENT, INVALID_TARGET, GSM_REJECT }

## Boot lifecycle substate (mirrors StatSystem). Ordinal 0 = INITIALISING is the safe
## pre-_ready() default (ADR-0007 Family A: 0 = safe state). READY after boot;
## SUSPENDED/RECONCILING reserved for the GSM gate + resume re-read (Story 007+).
enum Substate { INITIALISING, READY, SUSPENDED, RECONCILING }


## Ability identifier constants (Rule 1 — LOCKED ability surface; no magic strings).
## 9 abilities: 3 classes × 3 tiers. StringName literals are lowercase per the naming
## convention (`strike_tier_1_jab` etc.) — the magic-string CI lint excludes THIS file so
## the canonical declaration lives here legitimately. Consumers reference AbilityId.*.
class AbilityId:
	const STRIKE_TIER_1_JAB: StringName = &"strike_tier_1_jab"
	const STRIKE_TIER_2_HOOK: StringName = &"strike_tier_2_hook"
	const STRIKE_TIER_3_OVERHAND: StringName = &"strike_tier_3_overhand"
	const CONTROL_TIER_1_PARRY: StringName = &"control_tier_1_parry"
	const CONTROL_TIER_2_HOOK_PULL: StringName = &"control_tier_2_hook_pull"
	const CONTROL_TIER_3_GRAPPLE: StringName = &"control_tier_3_grapple"
	const MOBILITY_TIER_1_DASH: StringName = &"mobility_tier_1_dash"
	const MOBILITY_TIER_2_LEAP: StringName = &"mobility_tier_2_leap"
	const MOBILITY_TIER_3_GROUND_POUND: StringName = &"mobility_tier_3_ground_pound"


## UnlockRecord — per-ability unlock provenance envelope (Story 004 / ADR-0006 Contract 3).
##
## Stored as the value of each `_unlocked_abilities[ability_id]` entry AND persisted to
## "ability.unlocked.<id>" via to_dict(). Extends SerializableResource so the envelope
## round-trips through PersistenceLayer / IndexedDB as a human-readable Dictionary (the
## boot-reconciliation reader in Story 007 reconstructs it via from_dict()).
##
## `source` is stored as the INT ordinal (not the typed UnlockSource enum) so the JSON
## payload is stable across enum-declaration edits — the string-name is emitted in to_dict()
## via UnlockSource.find_key for human readability, mirroring BossPayload's convention.
##
## payload_type NOTE: get_script().get_global_name() returns "" for an INNER class (only
## top-level `class_name` scripts have a global name). UnlockRecord is intentionally an
## inner class (it references the outer UnlockSource enum), so to_dict() emits the literal
## "UnlockRecord" — the Story 007 dispatch table keys on this fixed string.
class UnlockRecord extends SerializableResource:
	## Unix timestamp (seconds) of the FIRST unlock. Set once at unlock time; never re-stamped
	## (permanent-unlock + persist-once guarantee — idempotent re-unlocks never reach here).
	var first_unlocked_at_unix: int = 0

	## UnlockSource ordinal that triggered the unlock. INT (not typed enum) for serialization
	## stability. Defaults to INITIAL_STATE's ordinal (2) — but a real unlock always overwrites
	## it with PR_BREAKTHROUGH (0) or STAT_THRESHOLD (1); the default is never persisted.
	var source: int = UnlockSource.INITIAL_STATE

	## Provenance event id (e.g. the originating PR/threshold event). Empty for Batch B —
	## the upstream #18 PR signal does not yet carry an event id; reserved for Story 007+.
	var source_event_id: String = ""

	## Convert to a plain Dictionary (ADR-0006 Contract 3). `source` is emitted as its
	## string name via UnlockSource.find_key (Godot 4.4+); an out-of-range ordinal falls back
	## to "INITIAL_STATE" (conservative — a corrupt record never round-trips to a real unlock
	## source that could be mistaken for a live mutation on restore).
	func to_dict() -> Dictionary:
		var source_key: Variant = UnlockSource.find_key(source)
		var source_str: String = source_key if source_key != null else "INITIAL_STATE"
		return {
			"payload_type": "UnlockRecord",
			"first_unlocked_at_unix": first_unlocked_at_unix,
			"source": source_str,
			"source_event_id": source_event_id,
		}

	## Reconstruct from a Dictionary produced by to_dict() (Story 007 boot read). Defensive
	## against missing / older-schema keys (ADR-0006 Contract 3): unknown/missing source string
	## falls back to INITIAL_STATE's ordinal; numeric / string fields default to 0 / "".
	static func from_dict(data: Dictionary) -> SerializableResource:
		var record: UnlockRecord = UnlockRecord.new()
		record.first_unlocked_at_unix = int(data.get("first_unlocked_at_unix", 0))
		var source_str: String = data.get("source", "INITIAL_STATE")
		record.source = UnlockSource.get(source_str, UnlockSource.INITIAL_STATE)
		record.source_event_id = String(data.get("source_event_id", ""))
		return record


# ============================================================================
# Signals (Rule 16 — telemetry surface; 7 ability signals + boot_completed)
# ============================================================================

## Emitted when an ability is newly unlocked (the FIRST time only — idempotent re-unlocks
## do NOT re-emit, AC-07b). `source` is the int ordinal of the UnlockSource (typed int for
## signal compatibility per the stat-system convention).
signal ability_unlocked(ability_id: StringName, source: int)

## Emitted when an ability is cast (resolution lands in Story 006).
signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)

## Emitted when a cooldown begins for an ability (Story 006).
signal ability_cooldown_started(ability_id: StringName, duration: float)

## Emitted when a cooldown elapses and the ability becomes castable again (Story 006).
signal ability_cooldown_ended(ability_id: StringName)

## Telemetry: emitted on any UNLOCK reject path. reason ∈ {"sentinel_misuse",
## "caller_whitelist_violation", "invalid_source", "invalid_ability_id",
## "source_class_mismatch"} for this surface. `source` is the int ordinal of the
## attempted UnlockSource.
signal ability_mutation_rejected(ability_id: StringName, source: int, reason: String)

## Telemetry: emitted on any CAST reject path (Story 006). reason mirrors the
## non-SUCCESS CastResult values.
signal ability_cast_rejected(ability_id: StringName, reason: String)

## Emitted when an unlock succeeded in-memory but the persistence write failed (Story 004).
signal ability_unlock_save_failed(ability_id: StringName)

## Emitted once at the end of boot reconciliation (Story 007), AFTER the GSM subscription
## is wired. Carries no payload — subscribers re-read via get_unlocked_abilities().
signal boot_completed()


# ============================================================================
# Constants — source→class allow-list (Story 003 / Rule 6)
# ============================================================================

## Stat → class allow-list (Rule 6 — Pillar 4 separation). A PR/threshold on a given stat
## may only unlock abilities of that stat's matching class. Keyed by the StatSystem.StatId
## StringName literals (&"str"/&"dex"/&"vit") rather than importing StatSystem.StatId — an
## inner class const from another script is not safely referenceable at this script's const
## parse time, and the literals are the same locked surface StatSystem declares.
const _STAT_TO_CLASS: Dictionary = {
	&"str": AbilityClass.STRIKE,
	&"dex": AbilityClass.CONTROL,
	&"vit": AbilityClass.MOBILITY,
}

## Class → the base stat_id that gates its cast (Story 006 Rule 8 step 6). Inverse of
## _STAT_TO_CLASS: STRIKE casts gate on STR, CONTROL on DEX, MOBILITY on VIT. The minimum
## active-stat check reads _stat_system.get_stat(this) and compares against MINIMUM_ACTIVE_STAT.
const _CLASS_TO_STAT: Dictionary = {
	AbilityClass.STRIKE: &"str",
	AbilityClass.CONTROL: &"dex",
	AbilityClass.MOBILITY: &"vit",
}


# ============================================================================
# Constants — Formulas (Story 005 Formula 1 / Story 006 Formula 2)
# ============================================================================

## Formula 1 — STAT_THRESHOLD unlock thresholds per tier (Story 005 / AC-21). All 3 classes
## share the same thresholds; an inclusive `>=` boundary decides each tier. Data-driven knob
## surface (Story 009 invariants reference this). Keyed by AbilityTier ordinal.
const TIER_THRESHOLDS: Dictionary = {
	AbilityTier.TIER_1: 10,
	AbilityTier.TIER_2: 50,
	AbilityTier.TIER_3: 200,
}

## Formula 2 — base cooldown seconds per tier (Story 006 / AC-22). Higher tiers cool down
## slower. Keyed by AbilityTier ordinal. Story 009 invariants reference this.
const BASE_COOLDOWN_SEC: Dictionary = {
	AbilityTier.TIER_1: 3.0,
	AbilityTier.TIER_2: 6.0,
	AbilityTier.TIER_3: 10.0,
}

## bfcache resume safety (Story 006 / AC-18, shared semantics with #6/#7). A tab restored from
## the browser back-forward cache delivers one huge delta on the first resumed frame; clamping
## the per-frame cooldown decrement to this ceiling prevents a multi-second cooldown evaporating.
const MAX_FRAME_DELTA: float = 0.1

## Re-entrance depth ceiling for cast_ability (Story 006 / AC-28). A subscriber that casts from
## inside an ability_cast / ability_cooldown_started handler re-enters cast_ability; depth > this
## is rejected to bound the recursion (no stack overflow). 2 allows one legitimate nested cast.
const MAX_EMIT_DEPTH: int = 2

## Minimum value the class's gating stat must hold for a cast to resolve (Story 006 / Rule 8
## step 6). VS-tier flat value for all abilities (AbilityRegistry.minimum_active_stat lands in
## Story 007); a stat below this rejects with STAT_INSUFFICIENT.
const MINIMUM_ACTIVE_STAT: float = 5.0

## Cast target requirement per class (Story 006 / Rule 8 step 7). STRIKE/CONTROL abilities
## require a live ENEMY target; MOBILITY abilities are SELF-targeted (no target validation).
## Used only as a boolean "does this class need a live target?" gate for the VS tier.
const _CLASS_REQUIRES_TARGET: Dictionary = {
	AbilityClass.STRIKE: true,
	AbilityClass.CONTROL: true,
	AbilityClass.MOBILITY: false,
}

## Canonical (class, tier) → AbilityId lookup (Story 005 / Rule 1). 9 combinations. Path B's
## tier ascent resolves the ability id for each (expected_class, tier) pair here rather than
## reconstructing the StringName from parts — keeps the locked AbilityId surface authoritative.
## Keyed by an int composite (class_ordinal * 3 + tier_ordinal) so the lookup is O(1) and
## allocation-free. Declared as a plain Dictionary (const) — the composite key avoids a nested
## Dictionary and the StringName values reference the locked AbilityId constants.
const _CLASS_TIER_TO_ABILITY: Dictionary = {
	# STRIKE (class 0)
	0 * 3 + 0: AbilityId.STRIKE_TIER_1_JAB,
	0 * 3 + 1: AbilityId.STRIKE_TIER_2_HOOK,
	0 * 3 + 2: AbilityId.STRIKE_TIER_3_OVERHAND,
	# CONTROL (class 1)
	1 * 3 + 0: AbilityId.CONTROL_TIER_1_PARRY,
	1 * 3 + 1: AbilityId.CONTROL_TIER_2_HOOK_PULL,
	1 * 3 + 2: AbilityId.CONTROL_TIER_3_GRAPPLE,
	# MOBILITY (class 2)
	2 * 3 + 0: AbilityId.MOBILITY_TIER_1_DASH,
	2 * 3 + 1: AbilityId.MOBILITY_TIER_2_LEAP,
	2 * 3 + 2: AbilityId.MOBILITY_TIER_3_GROUND_POUND,
}

## All 9 AbilityId StringNames as a set (Story 006 Rule 8 step 2 — "is this a real ability id?").
## Used for the cast-time registry membership check (a typo'd / unknown id rejects NOT_UNLOCKED).
const _ALL_ABILITY_IDS: Array[StringName] = [
	AbilityId.STRIKE_TIER_1_JAB, AbilityId.STRIKE_TIER_2_HOOK, AbilityId.STRIKE_TIER_3_OVERHAND,
	AbilityId.CONTROL_TIER_1_PARRY, AbilityId.CONTROL_TIER_2_HOOK_PULL, AbilityId.CONTROL_TIER_3_GRAPPLE,
	AbilityId.MOBILITY_TIER_1_DASH, AbilityId.MOBILITY_TIER_2_LEAP, AbilityId.MOBILITY_TIER_3_GROUND_POUND,
]


# ============================================================================
# State
# ============================================================================

## Permanent unlock table (Rule 3 closed API — CI-guarded). Keys = AbilityId StringNames;
## values = a small state Dictionary (source + unlocked-at metadata; populated in Story 004).
## NEVER erased/cleared outside schema migration (Rule 12 — CI-guarded by check_ability_relock).
var _unlocked_abilities: Dictionary = {}

## Per-ability cooldown remaining (seconds). Keyed by AbilityId StringName (Story 006).
var _cooldown_remaining: Dictionary = {}

## Caller-whitelist runtime guard (Story 003 / EC-10 / AC-30). FALSE by default so any
## caller reaching unlock_ability without going through the internal _evaluate_unlock handler
## (which sets it TRUE for the duration of the call) is rejected. This is the runtime twin of
## the check_ability_unlock_callers CI lint — defence in depth.
var _unlock_call_permitted: bool = false

## Boot lifecycle substate. INITIALISING until _ready() completes (Story 007); inspected by
## boot tests, mutated only by the boot path.
var _substate: Substate = Substate.INITIALISING

## PersistenceLayer reference — overrideable for testing (dependency injection seam).
## Untyped INTENTIONALLY: read()/write() are NOT Node members, so a typed (Node) annotation
## would fail GDScript's compile-time member check. Duck-typed seam — pattern shared with
## StatSystem / StreakSystem. Resolved to the autoload in _ready() (Story 004).
var _persistence = null

## GameStateMachine reference — overrideable for testing (dependency injection seam).
## Untyped INTENTIONALLY (same rationale as _persistence). Subscribed in _ready() (Story 007).
var _gsm = null

## StatSystem reference — overrideable for testing (dependency injection seam).
## Untyped INTENTIONALLY (same rationale). Read at unlock-evaluation time (Story 004/005).
var _stat_system = null

## Cast re-entrance depth (Story 006 / AC-28). cast_ability increments on entry and decrements
## on every exit path; a re-entrant cast (a subscriber casting from inside an ability_cast /
## ability_cooldown_started handler) that pushes depth past MAX_EMIT_DEPTH is rejected so the
## recursion is bounded (no stack overflow). Twin of StatSystem._emit_depth.
var _cast_depth: int = 0

## Pre-Suspension unlock-table snapshot (Story 008 / AC-15b). Captured when GSM enters Suspended
## so the Reconciling re-read can detect which keys the backend unlocked during suspension. Empty
## outside a Suspended→Reconciling cycle. Twin of StatSystem._pre_suspended_snapshot.
var _pre_suspended_snapshot: Dictionary = {}


## Boot reconciliation (Story 007 / TR-ability-011 / ADR-0006 Contract 4). Synchronous —
## NO await (ADR-0006 Contract 12). Sequence:
##   0. Resolve the DI seams to the production autoloads when a test has not injected a mock.
##   1. Story 009 cross-knob invariant gate (_assert_knob_invariants) — runs FIRST so a
##      mis-tuned knob set fails fast at debug/CI boot (assert is stripped in release).
##   2. Replay every persisted "ability.unlocked.*" key into _unlocked_abilities via the
##      defensive _load_unlock_from_key reader (EC-02/03/04 — boot never blocks on corrupt data).
##   3. Clear _cooldown_remaining (cooldowns are transient — never persisted, reset on reload).
##   4. Subscribe the Path B Stat handler AND the GSM handler via connect_for_initial_state
##      (ADR-0006 Contract 6 — NEVER a raw .connect).
##   5. Flip _substate to READY and emit boot_completed (Rule 16 — AFTER subscriptions are wired).
##
## ## No ability_unlocked during boot (AC-14c)
## Subscribers (HUD, telemetry) connect to ability_unlocked AFTER boot, so a boot-time emit goes
## to no one. More importantly, connect_for_initial_state(_on_stat_changed) delivers a synchronous
## INITIAL_STATE burst that would run _evaluate_unlock_tiers and emit ability_unlocked DURING boot.
## To honour AC-14c, _on_stat_changed returns early while _substate == INITIALISING (see its body):
## the persisted unlocks are replayed from disk in step 2 instead, and the first REAL stat_changed
## after boot (once READY) drives EC-01 first-boot auto-unlock.
##
## ## list_keys_matching fallback (documented decision)
## PersistenceLayer exposes only read/write/delete/migrate — it has NO list_keys_matching(prefix).
## So boot iterates the 9 known AbilityId StringNames and reads each "ability.unlocked.<id>" key
## directly (a non-null Dictionary → load). This is exhaustive (the locked ability surface IS the
## 9-set, Rule 1) and allocation-bounded. If PersistenceLayer ever gains list_keys_matching this
## can switch to a prefix scan, but the known-id walk is the authoritative path for the VS tier.
##
## NOTE: cast/unlock unit tests use fresh un-parented instances and inject their own mocks BEFORE
## add_child (so _ready resolves to the mock, not the autoload). The lazy `== null` resolve here is
## the production path only.
func _ready() -> void:
	# (0) DI resolve.
	if _persistence == null:
		_persistence = PersistenceLayer
	if _gsm == null:
		_gsm = GameStateMachine
	if _stat_system == null:
		_stat_system = StatSystem

	# (1) Story 009 — cross-knob invariant gate. BEFORE any boot logic (Story 009 Control Manifest
	# Rule). assert() is a no-op in release builds — zero shipped-build cost; a CI/debug safety net.
	_assert_knob_invariants()

	_substate = Substate.INITIALISING

	# (2) Replay persisted unlocks. Known-id walk (no list_keys_matching on PersistenceLayer).
	for ability_id: StringName in _ALL_ABILITY_IDS:
		_load_unlock_from_key("ability.unlocked." + String(ability_id))

	# (3) Cooldowns are transient — never persisted; an unlocked ability boots castable.
	_cooldown_remaining.clear()

	# (4) Subscribe via connect_for_initial_state (ADR-0006 Contract 6 — NEVER a raw .connect).
	# Path B Stat handler (Story 005): the 5-arg positional callv layout (stat_id, old, new, source,
	# is_initial) is delivered synchronously for the initial burst, then for every future mutation.
	# _on_stat_changed returns early while INITIALISING so the burst does NOT emit (AC-14c).
	if _stat_system != null and _stat_system.has_method("connect_for_initial_state"):
		_stat_system.connect_for_initial_state(_on_stat_changed)
	# GSM handler (Story 008): the 3-arg positional callv layout (from, to, payload) drives the
	# Suspended gate + Reconciling re-read.
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)

	# (5) Boot complete (Rule 16 — AFTER subscriptions wired).
	_substate = Substate.READY
	boot_completed.emit()


## Defensive boot reader (Story 007 / EC-02/03/04). Reads one "ability.unlocked.<id>" key and,
## if it round-trips to a valid UnlockRecord for a KNOWN ability id, installs it into
## _unlocked_abilities. Every failure mode degrades gracefully (boot never blocks — AC-14b):
##   - absent / non-Dictionary read        → skip + push_warning (EC-02 — first boot / missing key)
##   - UnlockRecord.from_dict returns null  → skip + ability_unlock_save_failed.emit (unrecoverable)
##   - source ordinal not a UnlockSource    → coerce to INITIAL_STATE + push_warning (EC-04)
##   - NaN first_unlocked_at_unix           → stamp Time.get_unix_time_from_system() + push_warning
##   - ability_id not in the locked 9-set   → skip + push_warning (EC-03 partial / Rule 1 surface)
## NO emit of ability_unlocked here (boot replay is silent — AC-14c); NO await (Contract 12).
func _load_unlock_from_key(key: String) -> void:
	var record_dict: Variant = _persistence.read(key)
	if typeof(record_dict) != TYPE_DICTIONARY:
		# Absent / null / wrong type — first-boot or a key that was never written (EC-02). Silent
		# on a plain null (the common first-boot case); only warn on a present-but-malformed value.
		if record_dict != null:
			push_warning("[AbilitySystem] boot: '%s' is not a Dictionary — skipped (EC-02)" % key)
		return

	var ability_id: StringName = StringName(key.replace("ability.unlocked.", ""))

	# Rule 1 locked surface — only a known ability id may enter the table (EC-03 partial-key guard).
	if not _ALL_ABILITY_IDS.has(ability_id):
		push_warning("[AbilitySystem] boot: '%s' is not a known ability id — skipped (EC-03/Rule 1)" % ability_id)
		return

	var record: Variant = UnlockRecord.from_dict(record_dict)
	if record == null or not (record is UnlockRecord):
		# Unrecoverable record — surface telemetry and skip the key (boot continues, AC-14b).
		push_error("[AbilitySystem] boot: UnlockRecord.from_dict failed for '%s' — skipped (EC-04)" % key)
		ability_unlock_save_failed.emit(ability_id)
		return

	var typed_record: UnlockRecord = record

	# EC-04 — coerce an out-of-range source ordinal to the INITIAL_STATE sentinel (never a live
	# mutation source on restore; conservative — matches UnlockRecord.from_dict's own fallback).
	if not UnlockSource.values().has(typed_record.source):
		push_warning("[AbilitySystem] boot: '%s' has invalid source %s — coercing INITIAL_STATE (EC-04)"
			% [key, typed_record.source])
		typed_record.source = int(UnlockSource.INITIAL_STATE)

	# EC-04 — a NaN timestamp is restamped with the current time (a corrupt clock value would
	# break downstream ordering / display). first_unlocked_at_unix is int-typed in the record, but
	# a corrupt from_dict could leave it as a NaN that int() coerced — guard defensively via float.
	if is_nan(float(typed_record.first_unlocked_at_unix)):
		push_warning("[AbilitySystem] boot: '%s' has NaN timestamp — restamping now (EC-04)" % key)
		typed_record.first_unlocked_at_unix = int(Time.get_unix_time_from_system())

	_unlocked_abilities[ability_id] = typed_record


# ============================================================================
# Public API (Rule 3 closed mutation surface)
# ============================================================================

## Unlock an ability (Rule 3/6 chokepoint). NO await (ADR-0006 Contract 12).
##
## `expected_class` is an OPTIONAL cross-class guard seam (Story 003 / AC-07). The PUBLIC
## contract takes only (ability_id, source); the internal _evaluate_unlock handler passes the
## stat-derived expected class as the 3rd arg so a PR/threshold on stat X can never unlock an
## ability of a different class. When expected_class is UNKNOWN (the default — i.e. no stat
## context supplied) the cross-class check is skipped; the caller-whitelist guard already
## blocks every EXTERNAL invocation, so the only path that reaches the cross-class check with
## a concrete expected_class is the internal handler. (AC-19: no character_id parameter —
## single-character MVP scope, Rule 15.)
##
## Guard order (LOCKED — Story 002/003 composite):
##   1. INITIAL_STATE sentinel reject (AC-05) — sentinel never reaches a permitted path.
##   2. caller-whitelist runtime defense (AC-30) — non-handler callers rejected.
##   3. idempotent guard (EC-11 / AC-07b) — already-unlocked is a silent true no-op.
##   4. source enum validity (defensive).
##   5. source→class allow-list (AC-07) — ability class must be known AND, when a stat
##      context supplies expected_class, must match it.
## On a reject path ability_mutation_rejected fires and false is returned; the unlock table
## is untouched. On the success path (Story 004) the persist-FIRST atomic write sequence runs
## (persist → mutate → emit ability_unlocked); a failed persist aborts with rollback +
## ability_unlock_save_failed (AC-29). Requires `_persistence` resolved (via _ready or DI inject).
func unlock_ability(
	ability_id: StringName,
	source: UnlockSource,
	expected_class: AbilityClass = AbilityClass.UNKNOWN,
) -> bool:
	# (1) Rule 4 / AC-05 — INITIAL_STATE is a Contract 6 delivery sentinel, never a mutation.
	# Checked FIRST so the sentinel is rejected even on a permitted internal path.
	if source == UnlockSource.INITIAL_STATE:
		push_error("[AbilitySystem] unlock_ability: INITIAL_STATE is a sentinel, not a valid unlock source (AC-05)")
		ability_mutation_rejected.emit(ability_id, int(source), "sentinel_misuse")
		return false

	# (1b) Story 008 / AC-15 — GSM Suspended gate (Rule 14). While GSM holds the system Suspended
	# (or mid-Reconciling) every unlock mutation rejects — checked right after the sentinel so no
	# caller-whitelist / allow-list / persist side effect runs on a gated path. Read-only
	# get_unlocked_abilities() is intentionally NOT gated.
	if _is_mutation_gated():
		push_warning("[AbilitySystem] unlock_ability: rejected during %s substate (AC-15)"
			% Substate.keys()[_substate])
		ability_mutation_rejected.emit(ability_id, int(source), "suspended_substate")
		return false

	# (2) Story 003 / EC-10 / AC-30 — caller-whitelist runtime defense. Only the internal
	# _evaluate_unlock handler sets _unlock_call_permitted true (around its own call). Any
	# other caller (an external system bypassing the signal pattern) sees false → reject.
	if not _unlock_call_permitted:
		push_error("[AbilitySystem] unlock_ability: caller not whitelisted — emit a signal, do not call directly (AC-30)")
		ability_mutation_rejected.emit(ability_id, int(source), "caller_whitelist_violation")
		return false

	# (3) Story 003 / EC-11 / AC-07b — idempotent guard. An already-unlocked ability is a
	# silent no-op: return true, NO ability_unlocked emit, NO persist (permanent-unlock + the
	# persist-only-once guarantee). Checked before any further validation so a re-unlock never
	# re-runs the allow-list or fires telemetry.
	if _unlocked_abilities.has(ability_id):
		return true

	# (4) Defensive enum membership check.
	if not UnlockSource.values().has(source):
		push_error("[AbilitySystem] unlock_ability: invalid source enum '%s'" % source)
		ability_mutation_rejected.emit(ability_id, int(source), "invalid_source")
		return false

	# (5) Story 003 / Rule 6 / AC-07 — source→class allow-list.
	var ability_class: AbilityClass = _get_ability_class(ability_id)
	if ability_class == AbilityClass.UNKNOWN:
		# Unknown ability id — cannot map to a class. Reject (never fabricate STRIKE — Pillar 1).
		push_error("[AbilitySystem] unlock_ability: unknown ability id '%s' (no class)" % ability_id)
		ability_mutation_rejected.emit(ability_id, int(source), "invalid_ability_id")
		return false
	if expected_class != AbilityClass.UNKNOWN and ability_class != expected_class:
		# Cross-class unlock (e.g. a STR/STRIKE PR attempting a CONTROL ability). Reject —
		# Pillar 4 class separation (Rule 6).
		push_error("[AbilitySystem] unlock_ability: source class %s does not match ability class %s for '%s' (AC-07)" % [
			expected_class, ability_class, ability_id,
		])
		ability_mutation_rejected.emit(ability_id, int(source), "source_class_mismatch")
		return false

	# Validated. Story 004 — persist-FIRST atomic write sequence (Rule 13 / AC-17):
	#   persist (T1) → mutate in-memory (T2) → emit ability_unlocked (T3).
	# A failed persist aborts BEFORE any in-memory mutation (AC-29 rollback) so disk and
	# memory never diverge and no subscriber ever sees a phantom unlock.

	# (T1) Construct the envelope and persist it FIRST. The flush flag is per-source
	# (flush_for_source, AC-13): PR_BREAKTHROUGH flushes immediately (critical moment),
	# STAT_THRESHOLD defers (Stat System already batched the underlying delta).
	var record: UnlockRecord = UnlockRecord.new()
	record.first_unlocked_at_unix = Time.get_unix_time_from_system()
	record.source = int(source)
	record.source_event_id = ""

	var persist_ok: bool = _persistence.write(
		"ability.unlocked." + String(ability_id),
		record.to_dict(),
		flush_for_source(source),
	)
	if not persist_ok:
		# AC-29 rollback: leave _unlocked_abilities UNCHANGED, surface the failure, and do
		# NOT emit ability_unlocked (no phantom unlock). Telemetry via ability_unlock_save_failed.
		push_error("[AbilitySystem] unlock_ability: persist failed for '%s' — unlock aborted (AC-29)" % ability_id)
		ability_unlock_save_failed.emit(ability_id)
		return false

	# (T2) Mutate in-memory AFTER a successful persist (AC-17). A subscriber reading
	# get_unlocked_abilities() inside the emit below sees the NEW ability.
	_unlocked_abilities[ability_id] = record

	# (T3) Emit AFTER mutate (AC-10/AC-17). 2-arg signature per AC-20 locked decl
	# (ability_unlocked(ability_id, source: int)) — the int ordinal, NOT the typed enum.
	ability_unlocked.emit(ability_id, int(source))
	return true


## Cast an ability (Rule 5/6 chokepoint — sole authorised caller is combat_resolver.gd, the
## caller whitelist is CI-enforced). NO await (ADR-0006 Contract 12). Synchronous atomic
## sequence (Story 006 / Rule 8): re-entrance → registry → unlocked → cooldown → GSM state →
## stat gate → target → emit + start cooldown. Returns a CastResult; SUCCESS only when every
## gate passes. NO combat math here — #13 CombatResolver owns damage (AC-12: ability_cast
## carries no damage param). (AC-19: no character_id parameter.)
func cast_ability(ability_id: StringName, caster: Node2D, target: Node2D) -> CastResult:
	# (Step 1) Re-entrance guard (AC-28). A subscriber casting from inside an ability_cast /
	# ability_cooldown_started handler re-enters here; bound the recursion at MAX_EMIT_DEPTH.
	# Increment FIRST so the depth reflects this invocation; decrement on EVERY exit path.
	_cast_depth += 1
	if _cast_depth > MAX_EMIT_DEPTH:
		_cast_depth -= 1
		push_warning("[AbilitySystem] cast_ability: re-entrance depth exceeded for '%s' (AC-28)" % ability_id)
		ability_cast_rejected.emit(ability_id, "reentrance_depth_exceeded")
		return CastResult.GSM_REJECT

	# (Step 1b) Story 008 / AC-15 — GSM Suspended gate. A cast attempted while the system is
	# Suspended (or mid-Reconciling) is rejected GSM_REJECT — uniform with the unlock gate. Checked
	# right after the depth guard so no registry / cooldown / stat side effect runs on a gated cast.
	# Decrement the depth this invocation took before returning (every exit path balances it).
	if _is_mutation_gated():
		_cast_depth -= 1
		ability_cast_rejected.emit(ability_id, "gsm_reject")
		return CastResult.GSM_REJECT

	# (Step 2) Registry membership — an unknown / typo'd id is treated as NOT_UNLOCKED (EC-17).
	if not _ALL_ABILITY_IDS.has(ability_id):
		_cast_depth -= 1
		ability_cast_rejected.emit(ability_id, "not_unlocked")
		return CastResult.NOT_UNLOCKED

	# (Step 3) Unlocked gate — only a permanently-unlocked ability can be cast.
	if not _unlocked_abilities.has(ability_id):
		_cast_depth -= 1
		ability_cast_rejected.emit(ability_id, "not_unlocked")
		return CastResult.NOT_UNLOCKED

	# (Step 4) Cooldown gate — an ability with a live cooldown entry rejects ON_COOLDOWN.
	if _cooldown_remaining.has(ability_id):
		_cast_depth -= 1
		ability_cast_rejected.emit(ability_id, "on_cooldown")
		return CastResult.ON_COOLDOWN

	# (Step 5) GSM state gate (Rule 8 step 3) — casting is only legal in an active-combat
	# state. The full Suspended-substate mutation gate is a Story 008 concern; Batch B only
	# does the cast-time state check via the _gsm DI seam. Enum compare (NOT string parsing).
	var gsm_state: int = _gsm.get_current_state()
	if gsm_state != GameStateMachine.GameState.COMBAT_ACTIVE \
			and gsm_state != GameStateMachine.GameState.BOSS_ENCOUNTER:
		_cast_depth -= 1
		ability_cast_rejected.emit(ability_id, "gsm_reject")
		return CastResult.GSM_REJECT

	# (Step 6) Stat gate (Rule 8 step 6) — the class's gating base stat must be >= the
	# minimum-active floor. STRIKE→str, CONTROL→dex, MOBILITY→vit.
	var ability_class: AbilityClass = _get_ability_class(ability_id)
	var class_stat_id: StringName = _CLASS_TO_STAT.get(ability_class, &"")
	if float(_stat_system.get_stat(class_stat_id)) < MINIMUM_ACTIVE_STAT:
		_cast_depth -= 1
		ability_cast_rejected.emit(ability_id, "stat_insufficient")
		return CastResult.STAT_INSUFFICIENT

	# (Step 7) Target gate (Rule 8 step 7) — STRIKE/CONTROL need a live ENEMY target;
	# MOBILITY is SELF-targeted and skips target validation. A null or queued-for-deletion
	# target rejects INVALID_TARGET (EC-22).
	if _CLASS_REQUIRES_TARGET.get(ability_class, false):
		if target == null or target.is_queued_for_deletion():
			_cast_depth -= 1
			ability_cast_rejected.emit(ability_id, "invalid_target")
			return CastResult.INVALID_TARGET

	# (Step 8) All gates passed — emit the cast (no damage; #13 resolves combat math) and
	# start the cooldown. _start_cooldown may synchronously fire ability_cooldown_started,
	# which a subscriber can re-enter cast_ability from — the depth guard above bounds it.
	ability_cast.emit(ability_id, caster, target)
	_start_cooldown(ability_id)

	_cast_depth -= 1
	return CastResult.SUCCESS


## Read API — a copy of the unlock table (read-only view; callers must not mutate the original,
## and the CI lint forbids direct _unlocked_abilities access). Returns a shallow duplicate so a
## mutation by a consumer cannot corrupt the internal table. (Story 004 enriches the per-entry
## value shape.)
func get_unlocked_abilities() -> Dictionary:
	return _unlocked_abilities.duplicate(true)


## Read API — the runtime state of a single ability (unlocked flag + cooldown remaining).
## Returns a fresh Dictionary; an unknown/never-unlocked id yields {unlocked=false, cooldown=0.0}.
func get_ability_state(ability_id: StringName) -> Dictionary:
	return {
		"unlocked": _unlocked_abilities.has(ability_id),
		"cooldown_remaining": float(_cooldown_remaining.get(ability_id, 0.0)),
	}


## Per-source persistence flush policy (Story 004 / AC-13). A PR_BREAKTHROUGH unlock is a
## high-stakes "earned-it-now" moment — flush to disk immediately so a crash/tab-close in the
## next frame cannot lose it. A STAT_THRESHOLD unlock rides the Stat System's already-batched
## delta cadence, so it defers the flush to the PersistenceLayer's own batched write. The
## INITIAL_STATE sentinel never reaches a persist path (rejected up-front in unlock_ability),
## so it falls through the match to the defer branch defensively.
func flush_for_source(source: UnlockSource) -> bool:
	match source:
		UnlockSource.PR_BREAKTHROUGH:
			return true
		_:
			return false


# ============================================================================
# Cooldown lifecycle (Story 006 / Rule 14)
# ============================================================================

## Per-frame cooldown tick (Story 006 / AC-18). ONLY active while at least one ability is on
## cooldown — _start_cooldown set_process(true)s us, and we set_process(false) the frame the
## last cooldown clears, so an idle AbilitySystem costs 0 CPU. NO await (Contract 12).
##
## `delta` is clamped to MAX_FRAME_DELTA (bfcache safety): a tab restored from the browser
## back-forward cache delivers one multi-second delta on its first resumed frame; without the
## clamp a 30s spike would instantly clear every cooldown. Keys are snapshotted before the loop
## so an erase mid-iteration is safe.
func _process(delta: float) -> void:
	var clamped: float = minf(delta, MAX_FRAME_DELTA)
	for id: StringName in _cooldown_remaining.keys():
		_cooldown_remaining[id] = float(_cooldown_remaining[id]) - clamped
		if _cooldown_remaining[id] <= 0.0:
			_cooldown_remaining.erase(id)
			ability_cooldown_ended.emit(id)
	if _cooldown_remaining.is_empty():
		set_process(false)


## Start (or restart) an ability's cooldown (Story 006 / AC-12). Records the tier's base
## cooldown, re-enables _process (the tick loop), and emits ability_cooldown_started. A
## subscriber MAY synchronously re-enter cast_ability from this emit — the _cast_depth guard
## in cast_ability bounds that recursion (AC-28).
func _start_cooldown(ability_id: StringName) -> void:
	var tier: AbilityTier = _get_ability_tier(ability_id)
	var duration: float = float(BASE_COOLDOWN_SEC[tier])
	_cooldown_remaining[ability_id] = duration
	set_process(true)
	ability_cooldown_started.emit(ability_id, duration)


## Derive the AbilityTier of an ability from its id (Story 005/006 stub — Story 007 reads this
## from AbilityRegistry.tres). The locked AbilityId surface embeds the tier as "…tier_1…" /
## "…tier_2…" / "…tier_3…", so a substring probe is authoritative for the VS tier. An id with no
## recognised tier marker falls back to TIER_1 (the safest/lowest cooldown + threshold) and flags
## the anomaly — callers only ever pass a real AbilityId, so this branch is defensive.
func _get_ability_tier(ability_id: StringName) -> AbilityTier:
	var id_str: String = String(ability_id)
	if id_str.contains("tier_3"):
		return AbilityTier.TIER_3
	if id_str.contains("tier_2"):
		return AbilityTier.TIER_2
	if id_str.contains("tier_1"):
		return AbilityTier.TIER_1
	push_error("[AbilitySystem] _get_ability_tier: no tier marker in '%s' — defaulting TIER_1" % ability_id)
	return AbilityTier.TIER_1


## Resolve the canonical AbilityId for a (class, tier) pair (Story 005 / Rule 1). Path B's tier
## ascent calls this for each (expected_class, tier) it wants to unlock, keeping the locked
## AbilityId surface authoritative rather than reconstructing the StringName from parts. Uses the
## composite-int key layout (class_ordinal * 3 + tier_ordinal) of _CLASS_TIER_TO_ABILITY. Returns
## the empty StringName for UNKNOWN (or any unmapped) class — the caller skips an empty result.
func _ability_id_for(cls: AbilityClass, tier: AbilityTier) -> StringName:
	if cls == AbilityClass.UNKNOWN:
		return &""
	return _CLASS_TIER_TO_ABILITY.get(int(cls) * 3 + int(tier), &"")


# ============================================================================
# Internal — unlock evaluation (Story 003/004/005 handler seam)
# ============================================================================

## Internal unlock evaluation handler (Story 003 seam; full stat-driven trigger logic lands in
## Story 004/005). This is the ONLY function permitted to call unlock_ability: it flips the
## caller-whitelist guard true for the duration of the call (try/finally semantics via a manual
## reset so an early return or error still clears it), derives the expected class from the
## stat_id context, and delegates to unlock_ability with that expected_class so the cross-class
## allow-list (AC-07) is enforced. `current_value` is accepted for the Story 004/005 threshold
## math (unused in Batch A but kept on the signature so the handler contract is stable).
func _evaluate_unlock(stat_id: StringName, _current_value: float, source: UnlockSource, ability_id: StringName) -> bool:
	# Derive the expected class from the stat context (Pillar 4). An unknown stat_id maps to
	# UNKNOWN, which makes the cross-class check a no-op (the ability-class-known check in
	# unlock_ability still applies); a real stat maps to its locked class.
	var expected_class: AbilityClass = _STAT_TO_CLASS.get(stat_id, AbilityClass.UNKNOWN)

	# Open the caller-whitelist window only around the delegated call. Reset unconditionally
	# afterwards (NO await between set and reset — ADR-0006 Contract 12 — so the window cannot
	# leak across a yield).
	_unlock_call_permitted = true
	var result: bool = unlock_ability(ability_id, source, expected_class)
	_unlock_call_permitted = false
	return result


## Multi-tier unlock evaluation (Story 005 / Rule 6 / Formula 1 + Formula 3). Both real unlock
## paths funnel here: Path A (_on_pr_breakthrough) and Path B (_on_stat_changed). Given the stat
## that moved + its current value + the provenance source, this unlocks EVERY tier the value now
## clears that is not yet unlocked, in a DETERMINISTIC order.
##
## Step 1 — class gate (Pillar 4): the stat maps to exactly one class via _STAT_TO_CLASS. An
##   unknown stat_id maps to UNKNOWN → return immediately (never fabricate a class — Pillar 1).
## Step 2 — collect pending tiers: for each tier T, if current_value >= TIER_THRESHOLDS[T] AND
##   (expected_class, T) is not already unlocked, T is a candidate. A jump straight to a high stat
##   (e.g. 200) unlocks T1+T2+T3 in one call (AC-11 multi-tier ascent).
## Step 3 — Formula 3 deterministic ordering: sort candidates by the composite sort key
##   tier_ordinal * 4 + class_ordinal. Within this single call the class is fixed, so the sort
##   degenerates to ascending tier order — but the explicit composite key matches the cross-class
##   GDD worked example and makes the determinism contract (AC-23) self-evident and stable.
## Step 4 — unlock each in order through the permitted internal chokepoint: flip the
##   caller-whitelist window true, call unlock_ability(id, source, expected_class), reset the
##   window. expected_class is passed so the cross-class allow-list (AC-07) still applies — a
##   stat can only ever unlock its own class here, but the guard stays defence-in-depth.
## NO await between window-set and reset (ADR-0006 Contract 12) so the permit cannot leak.
func _evaluate_unlock_tiers(stat_id: StringName, current_value: float, source: UnlockSource) -> void:
	# Story 008 / AC-15 — never run tier ascent while the GSM Suspended gate is up (or mid-
	# Reconciling). A defence-in-depth twin of the unlock_ability gate: even if a stat_changed
	# slips through during Suspended, no unlock fires. (INITIALISING is NOT gated here — boot
	# replay is suppressed at the _on_stat_changed entry instead; the Path B / formula unit tests
	# call this directly in INITIALISING and must still evaluate.)
	if _is_mutation_gated():
		return
	var expected_class: AbilityClass = _STAT_TO_CLASS.get(stat_id, AbilityClass.UNKNOWN)
	if expected_class == AbilityClass.UNKNOWN:
		# Unknown / non-class-bearing stat (e.g. a derived stat). Nothing to unlock — never
		# fabricate STRIKE (Pillar 1). Silent return: not an error, just out of scope.
		return

	# Collect the pending (not-yet-unlocked) tiers this value now clears.
	var pending: Array[AbilityTier] = []
	for tier: AbilityTier in [AbilityTier.TIER_1, AbilityTier.TIER_2, AbilityTier.TIER_3]:
		if current_value < float(TIER_THRESHOLDS[tier]):
			continue
		var ability_id: StringName = _ability_id_for(expected_class, tier)
		if ability_id == &"":
			continue
		if _unlocked_abilities.has(ability_id):
			continue
		pending.append(tier)

	if pending.is_empty():
		return

	# Formula 3 deterministic order: composite key tier_ordinal*4 + class_ordinal (AC-23).
	pending.sort_custom(func(a: AbilityTier, b: AbilityTier) -> bool:
		return (int(a) * 4 + int(expected_class)) < (int(b) * 4 + int(expected_class)))

	# Unlock each pending tier through the permitted chokepoint, in the sorted order.
	for tier: AbilityTier in pending:
		var ability_id: StringName = _ability_id_for(expected_class, tier)
		_unlock_call_permitted = true
		unlock_ability(ability_id, source, expected_class)
		_unlock_call_permitted = false


## Path B handler (Story 005 / Rule 6) — subscribed to StatSystem via connect_for_initial_state in
## _ready(). The unified 5-arg positional layout is (stat_id, old_value, new_value, source,
## is_initial). `source` is the StatSystem.StatSource INT ordinal (PR_BREAKTHROUGH=0, VOLUME_TICK=1,
## EQUIPMENT=2, DEBUG_OVERRIDE=3, INITIAL_STATE=4).
##
## Filtering (Rule 6 / EQUIPMENT excluded):
##   - EQUIPMENT (2): transient gear modifier, never an earned stat gain → never unlocks (return).
##   - any source NOT in {PR_BREAKTHROUGH(0), VOLUME_TICK(1)}: out of the threshold-unlock contract
##     (covers DEBUG_OVERRIDE(3) and the INITIAL_STATE(4) sentinel burst) → return. The initial
##     burst delivers current state so a fresh subscriber CAN evaluate it, but Batch B intentionally
##     does NOT unlock on the initial snapshot (avoids re-firing telemetry for already-earned tiers
##     on every boot — Story 007's boot-reconciliation replays persisted unlocks instead).
##   - a stat_id with no class mapping (derived stats) → return.
## A surviving PR/VOLUME mutation on a base stat delegates to _evaluate_unlock_tiers with the
## STAT_THRESHOLD provenance (the AbilitySystem's own source taxonomy — distinct from the StatSystem
## int that triggered it).
func _on_stat_changed(
	stat_id: StringName,
	_old_value: float,
	new_value: float,
	source: int,
	_is_initial: bool,
) -> void:
	# (Story 007 / AC-14c) Boot guard — during the INITIALISING burst delivered by
	# connect_for_initial_state, do NOT evaluate/emit. The persisted unlocks are replayed from disk
	# in _ready() instead; the first REAL stat_changed after boot (READY) drives EC-01 auto-unlock.
	if _substate == Substate.INITIALISING:
		return
	# EQUIPMENT (StatSource ordinal 2) never unlocks an ability (Rule 6 — transient gear).
	if source == 2:
		return
	# Only real earned stat gains (PR_BREAKTHROUGH=0, VOLUME_TICK=1) drive threshold unlocks.
	# DEBUG_OVERRIDE(3) and the INITIAL_STATE(4) sentinel burst are excluded.
	if source != 0 and source != 1:
		return
	# Non-class-bearing stat (derived stat / unknown) — nothing to unlock.
	if not _STAT_TO_CLASS.has(stat_id):
		return
	_evaluate_unlock_tiers(stat_id, new_value, UnlockSource.STAT_THRESHOLD)


## Path A handler (Story 004 / AC-10) — PR-breakthrough unlock. PUBLIC seam reserved for the future
## #18 PR system to connect to; _ready() does NOT wire it in Batch B because StatSystem exposes no
## pr_breakthrough signal yet (the live Path A unlock currently arrives through _on_stat_changed
## with a PR_BREAKTHROUGH-sourced stat_changed). Kept as a stable, tested entry point so #18 can
## connect without an AbilitySystem change.
##
## `magnitude` is the PR delta that triggered the breakthrough; a NaN or negative magnitude is a
## malformed event (a PR is always a positive gain) — push_error and reject without unlocking. On a
## valid event the CURRENT stat value (read from the Stat System) is what gates the tiers, not the
## magnitude, so a big PR that crosses several thresholds unlocks every cleared tier via
## _evaluate_unlock_tiers under the PR_BREAKTHROUGH provenance (which flushes immediately, AC-13).
func _on_pr_breakthrough(stat_id: StringName, magnitude: float) -> void:
	if is_nan(magnitude) or magnitude < 0.0:
		push_error("[AbilitySystem] _on_pr_breakthrough: invalid magnitude %s for '%s' (AC-10)" % [magnitude, stat_id])
		return
	var current_value: float = float(_stat_system.get_stat(stat_id))
	_evaluate_unlock_tiers(stat_id, current_value, UnlockSource.PR_BREAKTHROUGH)


# ============================================================================
# GSM Suspended lifecycle (Story 008 / Rule 14 / TR-ability-012)
# ============================================================================

## GSM state delivery handler (Story 008 / Rule 14 / AC-15 / EC-30). Subscribed via
## connect_for_initial_state in _ready() (ADR-0006 Contract 6). Signature mirrors StatSystem's
## handler so the GSM callv positional layout ([from, to, payload]) delivers correctly. State
## comparison is ENUM-typed (`to == GameStateMachine.GameState.SUSPENDED`) per the established
## Q1 decision — NOT string-name parsing.
##
## Transitions:
##   - to == SUSPENDED (real OR initial-state sentinel, EC-30): enter Suspended. A SUSPENDED
##     initial delivery still latches the gate — the only difference is provenance, not the gate.
##   - non-Suspended INITIAL_STATE sentinel: no-op (boot already left _substate at READY).
##   - real transition leaving SUSPENDED (any non-Suspended `to` while we are Suspended): run the
##     synchronous Reconciling re-read, then return to READY.
##   - any other real transition: no-op (AbilitySystem only reacts to the Suspended seam).
func _on_gsm_state_changed(
	_from_state: GameStateMachine.GameState,
	to_state: GameStateMachine.GameState,
	payload: StateTransitionPayload,
) -> void:
	var is_initial: bool = payload != null \
			and payload.source_event == GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT

	if to_state == GameStateMachine.GameState.SUSPENDED:
		# EC-30: a SUSPENDED initial delivery latches Suspended exactly like a real transition.
		_enter_suspended()
		return

	if is_initial:
		# Non-Suspended initial delivery — boot already left _substate READY; nothing to reconcile.
		return

	# Real, non-Suspended transition. Only meaningful if we WERE Suspended — that is the
	# GSM-resume edge that triggers the Pillar-1 anti-stale Reconciling re-read.
	if _substate == Substate.SUSPENDED:
		_reconcile_after_resume()


## Enter the Suspended substate (Story 008). Captures a snapshot of the unlock table so the
## resume-time Reconciling re-read can tell which keys the backend unlocked during suspension, and
## freezes the cooldown tick (set_process(false)) so cooldowns do not drain while gated. Idempotent:
## re-entering Suspended while already Suspended just refreshes the snapshot.
func _enter_suspended() -> void:
	_substate = Substate.SUSPENDED
	_pre_suspended_snapshot = _unlocked_abilities.duplicate()
	set_process(false)


## Reconciling re-read after GSM leaves Suspended (Story 008 / AC-15b). Pillar-1 anti-stale
## guarantee: the backend may have unlocked abilities (via PR breakthrough on the server) while we
## were gated, so we re-read all persisted "ability.unlocked.*" keys synchronously (NO await —
## ADR-0006 Contract 12) and emit ability_unlocked for every id that is newly present. Permanent
## unlock means we never REMOVE a local unlock here — only additions are reconciled. Source is
## PR_BREAKTHROUGH (the backend recorded the unlock as an earned PR moment). Substate returns to
## READY at the end; the cooldown tick is re-armed only if a cooldown survived the suspension.
func _reconcile_after_resume() -> void:
	_substate = Substate.RECONCILING
	for ability_id: StringName in _ALL_ABILITY_IDS:
		if _unlocked_abilities.has(ability_id):
			continue  # already unlocked locally — permanent, never re-emit (idempotent).
		_load_unlock_from_key("ability.unlocked." + String(ability_id))
		if _unlocked_abilities.has(ability_id):
			# Backend unlocked this during suspension — emit the delta (AC-15b).
			ability_unlocked.emit(ability_id, int(UnlockSource.PR_BREAKTHROUGH))
	_pre_suspended_snapshot.clear()
	_substate = Substate.READY
	if not _cooldown_remaining.is_empty():
		set_process(true)


## True while the mutation API is gated by the GSM Suspended seam (Story 008 / Rule 14). Covers
## BOTH Suspended and the transient Reconciling re-read window — a mutation arriving mid-reconcile
## would race the delta emit, so both substates reject uniformly. get_unlocked_abilities() /
## get_ability_state() are read-only and NOT gated. INITIALISING is NOT gated by this helper (boot
## suppression is handled at the _on_stat_changed entry) — matching the StatSystem contract.
func _is_mutation_gated() -> bool:
	return _substate == Substate.SUSPENDED or _substate == Substate.RECONCILING


# ============================================================================
# Cross-knob invariants (Story 009 / Rule — TR-ability-018)
# ============================================================================

## Cross-knob invariant gate (Story 009 / AC-24..AC-27). Asserts the balance-knob set is
## internally consistent BEFORE boot proceeds (called at the head of _ready()). Each assert is a
## designer-safety contract; a violation means the knob constants were tuned into a broken regime.
## assert() is a no-op in release builds, so this is zero runtime cost on shipped builds — it
## exists to fail CI / debug boot loudly. INV derivation: design/gdd/ability-system.md §G.
##   INV-1  threshold strict-monotonic (unlock event ordering correctness).
##   INV-2  TIER_1 threshold >= StatSystem.DEFAULT_BASE_VALUE (first-boot auto-unlock guarantee).
##   INV-3  TIER_3 threshold <= floor(StatSystem.MAX_STAT_VALUE * 0.25) (no grind ceiling).
##   INV-4  cooldown strict-monotonic (tier hierarchy).
##   INV-5  TIER_1 cooldown >= 2.0 (anti-spam floor).
##   INV-6  TIER_3 cooldown <= 15.0 (anti-dead-time ceiling).
##   INV-7  TIER_3/TIER_1 cooldown ratio <= 4.0 (cadence gap cap).
## Cross-system references (StatSystem.DEFAULT_BASE_VALUE / MAX_STAT_VALUE) use autoload-global
## const access, identical to the StatSystem ↔ ability-threshold coupling the GDD pins.
func _assert_knob_invariants() -> void:
	# INV-1 — threshold strict monotonic.
	assert(TIER_THRESHOLDS[AbilityTier.TIER_1] < TIER_THRESHOLDS[AbilityTier.TIER_2],
		"INV-1: TIER_1 < TIER_2 threshold violated")
	assert(TIER_THRESHOLDS[AbilityTier.TIER_2] < TIER_THRESHOLDS[AbilityTier.TIER_3],
		"INV-1: TIER_2 < TIER_3 threshold violated")
	# INV-4 — cooldown strict monotonic.
	assert(BASE_COOLDOWN_SEC[AbilityTier.TIER_1] < BASE_COOLDOWN_SEC[AbilityTier.TIER_2],
		"INV-4: TIER_1 < TIER_2 cooldown violated")
	assert(BASE_COOLDOWN_SEC[AbilityTier.TIER_2] < BASE_COOLDOWN_SEC[AbilityTier.TIER_3],
		"INV-4: TIER_2 < TIER_3 cooldown violated")
	# INV-2 — first-boot auto-unlock anchor (TIER_1 reachable at the stat default).
	assert(TIER_THRESHOLDS[AbilityTier.TIER_1] >= StatSystem.DEFAULT_BASE_VALUE,
		"INV-2: TIER_1 threshold must be >= StatSystem.DEFAULT_BASE_VALUE")
	# INV-3 — no grind ceiling (TIER_3 reachable within a quarter of the stat range).
	assert(TIER_THRESHOLDS[AbilityTier.TIER_3] <= floori(StatSystem.MAX_STAT_VALUE * 0.25),
		"INV-3: TIER_3 threshold must be <= floor(MAX_STAT_VALUE * 0.25)")
	# INV-5/INV-6 — cooldown floor/ceiling.
	assert(BASE_COOLDOWN_SEC[AbilityTier.TIER_1] >= 2.0, "INV-5: TIER_1 cooldown must be >= 2.0")
	assert(BASE_COOLDOWN_SEC[AbilityTier.TIER_3] <= 15.0, "INV-6: TIER_3 cooldown must be <= 15.0")
	# INV-7 — cadence gap ratio cap.
	assert(BASE_COOLDOWN_SEC[AbilityTier.TIER_3] / BASE_COOLDOWN_SEC[AbilityTier.TIER_1] <= 4.0,
		"INV-7: TIER_3/TIER_1 cooldown ratio must be <= 4.0")


## Derive the AbilityClass of an ability from its id prefix (Story 003 stub — Story 007 will
## read this from AbilityRegistry.tres). "strike…" → STRIKE, "control…" → CONTROL,
## "mobility…" → MOBILITY; anything else → UNKNOWN (anti-fabrication sentinel — never STRIKE).
func _get_ability_class(ability_id: StringName) -> AbilityClass:
	var id_str: String = String(ability_id)
	if id_str.begins_with("strike"):
		return AbilityClass.STRIKE
	if id_str.begins_with("control"):
		return AbilityClass.CONTROL
	if id_str.begins_with("mobility"):
		return AbilityClass.MOBILITY
	return AbilityClass.UNKNOWN
