## BossPayload — Boss encounter outcome envelope per Decision #2
##
## Driving GDDs:
##   * design/gdd/game-state-machine.md lines 593-609 (BossOutcome enum + schema)
##   * design/gdd/game-state-machine.md lines 141-161 (outcome semantics + Pillar 3)
##   * design/gdd/boss-system.md (boss runtime state — outcome PRODUCER)
##
## Governing ADRs:
##   * ADR-0006 (Accepted 2026-05-28) Contract 3 — explicit dict envelope
##   * ADR-0006 Contract 3 line 205 — Object.find_key(value) for enum→string
##
## Driving Story: production/epics/persistence-layer/story-004-serializable-resource-envelope.md
## Implementing TRs: TR-persist-004, TR-persist-005
##
## WHY extends SerializableResource:
## BossPayload is embedded in `StateTransitionPayload.data["boss"]` (per
## game-state-machine.md line 154 + line 292 binding rule). Forward-recovery
## (ADR-0006 Contract 2 line 153) replays the tombstone payload stored in
## `user://state.json`. If BossPayload extended plain Resource, `JSON.stringify`
## would silently drop the typed @export fields (ADR-0006 line 266) — the
## restored payload would have `outcome=0`, `boss_id=0`, `hp_at_interrupt=0`,
## `hp_max=0`, corrupting downstream consumers (#15 Loot Drop merge logic +
## #29 Mirror Moment weekly progression).
##
## WHY payload_type via get_script().get_global_name() (NOT get_class()):
## Object.get_class() returns the ENGINE BASE class string for GDScript classes —
## any subclass of Resource returns `"Resource"`, NOT `"BossPayload"`. Using
## get_class() would silently corrupt forward-recovery: `ClassDB.instantiate("Resource")`
## yields a bare Resource with no @export fields, and the from_dict dispatch in
## PersistenceLayer (Story 014) loses BossOutcome semantics entirely. CI lint
## `tools/ci/check_payload_type_uses_get_script.sh` enforces this binding across
## src/**/*.gd (TR-persist-005 binding).
##
## SCHEMA DIVERGENCE NOTE (boss_id type):
## game-state-machine.md line 607 declares `boss_id: int` (the GDD governing
## BossPayload). boss-system.md lines 107/144 use `StringName` for the runtime
## BossTemplate field of the same name. Story 004 AC-05 binds to int via
## `boss_id=42`. This file follows the game-state-machine GDD + Story 004 (int).
## Reconciliation of the cross-GDD divergence is deferred to a future GDD-sync
## pass (tracked under F-SYNC-3 follow-up family).
class_name BossPayload extends SerializableResource


## Outcome of a boss encounter. Ordering is LOAD-BEARING:
##
##   * ABANDONED = 0 — uninitialized BossPayload (int default) maps to the
##     conservative "no loot" outcome. Pillar 3 (workout = ritual = loot) is
##     never accidentally granted by a payload that forgot to set `outcome`.
##   * DEFEATED = 1 — boss HP reached 0 via combat (`boss_defeated` event path).
##   * INTERRUPTED_WITH_CREDIT = 2 — `workout_completed` fired during
##     BossEncounter (Rule 7 / Pillar 3 path); player gets loot despite boss
##     still alive.
##
## Downstream consumer contracts (advisory; binding lives in consumer GDDs):
##   * #15 Loot Drop System — merges boss-drop only if `outcome != ABANDONED`
##   * #16 Boss System — allows retry only if `outcome == INTERRUPTED_WITH_CREDIT`
##   * #29 Mirror Moment — only DEFEATED advances weekly boss-kill progression
##   * #28 Telemetry — counts each outcome as a separate funnel metric
enum BossOutcome {
	ABANDONED,
	DEFEATED,
	INTERRUPTED_WITH_CREDIT,
}


## Boss encounter outcome. See BossOutcome doc comment for semantic ordering
## rationale. Default ABANDONED is the conservative fail-safe — code paths
## that forget to set this value will NOT accidentally grant loot.
@export var outcome: BossOutcome = BossOutcome.ABANDONED


## Identifier of the boss instance (numeric). Matches the BossTemplate that
## spawned this encounter — boss-system.md uses StringName for its runtime
## field of the same name; this envelope uses int per game-state-machine.md
## line 607 + Story 004 AC-05 binding.
@export var boss_id: int = 0


## HP remaining on the boss at the moment the outcome was finalised.
##   * DEFEATED → 0 (combat drove HP to 0)
##   * INTERRUPTED_WITH_CREDIT → current_hp at workout_completed instant
##   * ABANDONED → current_hp at quit/TTL trigger
##
## Downstream consumers may derive engagement % via `hp_at_interrupt / hp_max`
## — the state machine does NOT make engagement-threshold policy decisions
## (per game-state-machine.md line 152).
@export var hp_at_interrupt: int = 0


## Boss maximum HP (constant for the encounter). Used by downstream consumers
## for engagement % derivation (see hp_at_interrupt doc comment).
@export var hp_max: int = 0


## Convert this resource to a plain Dictionary per ADR-0006 Contract 3.
##
## `payload_type` is set via `get_script().get_global_name()` per TR-persist-005
## binding — NEVER `get_class()` (which returns "Resource" for all GDScript
## resource subclasses and corrupts forward-recovery dispatch). CI lint
## `tools/ci/check_payload_type_uses_get_script.sh` enforces this rule.
##
## Enum field `outcome` is emitted as its string name via `BossOutcome.find_key(value)`
## (Godot 4.4+ API per ADR-0006 line 205). `find_key` returns null when the int
## value is outside the enum's value range — we fall back to "ABANDONED" so a
## bug-mutated `outcome = 99` does NOT silently round-trip to a Loot-granting
## outcome on restore (conservative read of Pillar 3 — see BossOutcome ordering
## rationale).
##
## Schema:
##   {
##     "payload_type": "BossPayload",  # for PersistenceLayer dispatch
##     "outcome": "DEFEATED" | "INTERRUPTED_WITH_CREDIT" | "ABANDONED",
##     "boss_id": int,
##     "hp_at_interrupt": int,
##     "hp_max": int,
##   }
func to_dict() -> Dictionary:
	var outcome_key: Variant = BossOutcome.find_key(outcome)
	var outcome_str: String = outcome_key if outcome_key != null else "ABANDONED"
	return {
		"payload_type": get_script().get_global_name(),
		"outcome": outcome_str,
		"boss_id": boss_id,
		"hp_at_interrupt": hp_at_interrupt,
		"hp_max": hp_max,
	}


## Reconstruct a BossPayload from a Dictionary produced by `to_dict()`.
##
## Defensive against missing / older-schema keys per ADR-0006 Contract 3 line
## 41-42 binding (`SerializableResource.from_dict` doc comment). Missing fields
## fall back to safe defaults:
##   * outcome — unknown string OR missing key → ABANDONED (conservative)
##   * boss_id / hp_at_interrupt / hp_max — missing key → 0
##
## `payload_type` is NOT consumed here — PersistenceLayer reads `payload_type`
## from the outer envelope to dispatch THIS factory call. By the time we're
## inside from_dict, the type has already been resolved.
static func from_dict(data_dict: Dictionary) -> SerializableResource:
	var payload: BossPayload = BossPayload.new()
	var outcome_str: String = data_dict.get("outcome", "ABANDONED")
	# BossOutcome.get(key, default) returns the enum int when key matches a
	# member name; default when not. Conservative fallback to ABANDONED.
	payload.outcome = BossOutcome.get(outcome_str, BossOutcome.ABANDONED)
	payload.boss_id = data_dict.get("boss_id", 0)
	payload.hp_at_interrupt = data_dict.get("hp_at_interrupt", 0)
	payload.hp_max = data_dict.get("hp_max", 0)
	return payload
