## EnemyKilledPayload — enemy-death outcome envelope per ADR-0006 Contract 3 (#13 FR-2)
##
## Driving GDD: design/gdd/combat-resolver.md FR-2 (LootDrop chain)
## Governing ADRs:
##   * ADR-0006 (Accepted 2026-05-28) Contract 3 — explicit dict envelope
##   * ADR-0006 Contract 3 line 205 — Object.find_key(value) for enum→string
## Story: production/epics/combat-resolver/story-002-data-structures.md (§2)
##
## WHY extends SerializableResource (vs the transient RefCounted structs in
## combat_resolver.gd):
## When CombatResolver kills an enemy, EnemyDirector (Story 009) emits this
## payload to drive the LootDrop chain (FR-2). That chain crosses a state
## transition whose `StateTransitionPayload.data` may be persisted to
## `user://state.json` for forward-recovery (ADR-0006 Contract 2). A plain
## Resource would have its typed fields silently dropped by JSON.stringify
## (ADR-0006 line 266), so the restored payload would lose killer_id /
## transition_id / overkill data and corrupt loot attribution. The explicit
## to_dict()/from_dict() envelope keeps the tombstone human-readable AND
## round-trip-safe.
##
## WHY transition_id is carried here:
## ADR-0009 (Signal Payload Schema Convention) — the transition_id is intrinsic
## event data that travels with the payload so the LootDrop merge can correlate
## the kill to the originating combat transition (idempotent loot grant).
##
## NOTE: CombatResolver itself does NOT construct this — the resolver is pure and
## returns a HitResult. EnemyDirector (Story 009) builds an EnemyKilledPayload
## from a kill-flagged HitResult. This file lives in src/core/ (not the resolver
## file) precisely because it carries state-machine serialization concerns the
## pure resolver must not.
class_name EnemyKilledPayload extends SerializableResource


## Identifier of the enemy TYPE/template that was killed (e.g. &"goblin_grunt").
@export var enemy_id: StringName = &""


## Unique runtime instance id of the killed enemy (distinguishes two goblins of
## the same template). Matches EnemyState.instance_id at kill time.
@export var enemy_instance_id: int = 0


## Instance id of the caster that landed the killing blow (for attribution).
@export var killer_id: int = 0


## The ability that dealt the killing blow (e.g. &"basic_strike").
@export var killing_ability: StringName = &""


## Transition id correlating this kill to its originating combat transition
## (ADR-0009 — intrinsic event data; LootDrop uses it for idempotent grant).
@export var transition_id: String = ""


## True when the killing blow dealt damage beyond the target's remaining HP.
@export var is_overkill: bool = false


## Damage dealt beyond 0 HP (0 when is_overkill is false). Downstream loot/FX
## may scale a flourish on large overkill.
@export var overkill_excess: int = 0


## Convert this payload to a plain Dictionary per ADR-0006 Contract 3.
##
## `payload_type` is set via `get_script().get_global_name()` (NOT get_class(),
## which returns "Resource" for every GDScript Resource subclass and would
## corrupt forward-recovery dispatch — same binding as BossPayload / TR-persist-005).
##
## All fields are JSON-native scalars (StringName serialises as String). No enum
## fields here, so no find_key round-trip is needed.
##
## Schema:
##   {
##     "payload_type": "EnemyKilledPayload",
##     "enemy_id": String,
##     "enemy_instance_id": int,
##     "killer_id": int,
##     "killing_ability": String,
##     "transition_id": String,
##     "is_overkill": bool,
##     "overkill_excess": int,
##   }
func to_dict() -> Dictionary:
	return {
		"payload_type": get_script().get_global_name(),
		"enemy_id": String(enemy_id),
		"enemy_instance_id": enemy_instance_id,
		"killer_id": killer_id,
		"killing_ability": String(killing_ability),
		"transition_id": transition_id,
		"is_overkill": is_overkill,
		"overkill_excess": overkill_excess,
	}


## Reconstruct an EnemyKilledPayload from a Dictionary produced by to_dict().
##
## Defensive against missing / older-schema keys per ADR-0006 Contract 3 — every
## field falls back to its safe default (empty / 0 / false) when the key is absent.
## `payload_type` is consumed by PersistenceLayer's outer dispatch, not here.
static func from_dict(data_dict: Dictionary) -> SerializableResource:
	var payload: EnemyKilledPayload = EnemyKilledPayload.new()
	payload.enemy_id = StringName(data_dict.get("enemy_id", ""))
	payload.enemy_instance_id = int(data_dict.get("enemy_instance_id", 0))
	payload.killer_id = int(data_dict.get("killer_id", 0))
	payload.killing_ability = StringName(data_dict.get("killing_ability", ""))
	payload.transition_id = String(data_dict.get("transition_id", ""))
	payload.is_overkill = bool(data_dict.get("is_overkill", false))
	payload.overkill_excess = int(data_dict.get("overkill_excess", 0))
	return payload
