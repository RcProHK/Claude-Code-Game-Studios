## CombatAnomalyPayload — transient anomaly notification per GDD Rule 6 + Rule 5.
##
## Driving GDD: design/gdd/enemy-director.md Rule 6 (anomaly rate-limiter) + Rule 5
##   (3 broadcast signals — combat_metric_anomaly payload schema).
## Governing ADR: ADR-0009 §1 (minimal + intrinsic — transient event, not persisted).
## Story: production/epics/enemy-director/story-005-signal-surface-contract6.md AC-08.
##
## Emitted by EnemyDirector.combat_metric_anomaly when:
##   (a) an individual anomaly passes the rate-limit cap (Rule 6), OR
##   (b) the sliding window expires with dropped_count > 0 (aggregate emit).
##
## Consumed by #28 Telemetry (NOT YET DESIGNED). Story 007 implements rate-limiter
## logic and emission; Story 005 only defines the payload schema.
##
## WHY extends RefCounted (not SerializableResource):
## combat_metric_anomaly is a fire-and-forget telemetry signal. Payloads are never
## written to the state tombstone or user:// — no persistence contract. The context_dump
## Dictionary serialization (if needed) is done at the #28 Telemetry consumer level.
## Contrast with EnemyKilledPayload which extends SerializableResource because it
## crosses a state transition that may be tombstoned to user://.
class_name CombatAnomalyPayload
extends RefCounted

## The anomaly reason key (e.g. &"GSM_SUSPENDED", &"INVALID_ABILITY_ID",
## &"CLAMP_TRIGGERED", &"DEAD_TARGET_RESOLVE", &"RNG_INJECTION_MISSING").
## Maps to the reason strings in EnemyDirector Rule 6 + #13 combat_metric_anomaly spec.
var reason: StringName = &""

## True if this is an aggregate emit at sliding-window expiry (dropped_count > 0).
## False = individual anomaly emit that passed the per-reason rate cap.
## Consumers should treat aggregate payloads as summaries, not individual events.
var aggregate: bool = false

## Number of anomaly emits dropped in the sliding window before this aggregate emit.
## Meaningful only when aggregate == true; always 0 for individual emits.
var dropped_count: int = 0

## Diagnostic context dump for this anomaly. Content varies by reason code.
## Max serialize size capped at 10 KB per EC-33 / Rule 6:
## if context_dump serializes > 10KB, it is truncated and {truncated: true} is added.
## Story 007 implements the truncation guard in the emit path.
var context_dump: Dictionary = {}
