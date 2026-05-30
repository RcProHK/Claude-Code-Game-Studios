## LootDrop — persisted loot-grant record per ADR-0006 Contract 3 (#15 Story 002)
##
## Driving GDD: design/gdd/loot-drop-system.md Section D (Data Architecture)
## Driving Story: production/epics/loot-drop-system/story-002-data-resources-enums.md (AC: LootDrop record)
## Governing ADRs:
##   * ADR-0006 (Accepted 2026-05-28) Contract 3 — explicit dict envelope, payload_type via get_script()
##   * ADR-0007 (Accepted 2026-05-29) — enum fields persisted as STRING NAMES (not ints)
##   * ADR-0009 (Accepted 2026-05-29) — minimal + intrinsic payload; transition_id correlation key
##   * ADR-0003 (Accepted 2026-05-30) — pending-loot persisted to user:// (IndexedDB) for bfcache/reconcile
##
## WHY extends SerializableResource:
## A LootDrop is stashed in `loot.pending.<drop_id>` (PersistenceLayer / user://)
## across a bfcache suspend or a boot, and may also ride inside a
## StateTransitionPayload during the Booting→LootDrop force-reveal (Rule 5). A plain
## Resource would have its typed @export fields silently dropped by JSON.stringify
## (ADR-0006 line 266) — the restored drop would lose rarity / class_tag / source,
## corrupting the deferred ceremony. The explicit to_dict()/from_dict() envelope
## keeps the IndexedDB blob human-readable AND round-trip-safe.
##
## WHY all enum-derived fields are stored as String (NOT typed enums):
## This is the PERSISTENCE-LAYER record. Per ADR-0007, enum values cross the
## persistence boundary as their STRING NAME (int ordinals are migration-fragile —
## a future enum reorder would corrupt every stored drop). The PRODUCER (Formula
## stories 003-008 + LootDropSystem) is responsible for the enum→String conversion
## via `LootEnums.RarityTier.find_key(value)` etc. at construction time; LootDrop
## itself is a pure String passthrough — same pattern as EnemyKilledPayload, which
## also carries no live enum fields. Consumers that need a typed enum back convert
## via `LootEnums.RarityTier.get(rarity_tier, LootEnums.RarityTier.COMMON)`.
##
## WHY transition_id is carried here (ADR-0009):
## Intrinsic correlation key linking the drop to its originating GSM transition so
## the grant is idempotent (a replayed tombstone with the same transition_id is not
## double-granted). It is NOT ambient context — it travels with the event.
class_name LootDrop extends SerializableResource


## Stable unique id for this loot drop (idempotency key across persist/restore).
## Empty string is the uninitialised sentinel — a real drop always has a non-empty id.
@export var drop_id: String = ""


## Transition id correlating this drop to its originating combat / workout
## transition (ADR-0009 intrinsic correlation; idempotent grant on replay).
@export var transition_id: String = ""


## Rarity tier as a serialized enum STRING NAME (ADR-0007), one of
## LootEnums.RarityTier keys: "COMMON" | "UNCOMMON" | "RARE" | "EPIC" | "LEGENDARY".
## Default "COMMON" is the Pillar 3 floor (ADR-0005) — a record that somehow lost
## its tier reads back as the safest, lowest-value tier, never a fabricated EPIC.
@export var rarity_tier: String = "COMMON"


## Item category as a serialized enum STRING NAME (ADR-0007), one of
## LootEnums.ItemType keys: "WEAPON" | "ARMOR" | "ACCESSORY" | "CONSUMABLE" | "COSMETIC".
@export var item_type: String = "WEAPON"


## Loot-item class affinity as a serialized enum STRING NAME (ADR-0007), one of
## LootEnums.ClassTag keys: "STRIKE" | "CONTROL" | "MOBILITY" | "NEUTRAL".
## NOTE: this is the ClassTag space (loot-item outcome), NOT AbilityClass
## (player-class identity) — they are distinct enums (ADR-0007 F-7). "NEUTRAL"
## means "any class can use", a real usable outcome.
@export var class_tag: String = "NEUTRAL"


## Triggering event kind as a serialized enum STRING NAME (ADR-0007), one of
## LootEnums.SourceEventKind keys: "WORKOUT_DAILY" | "MINI_BOSS" | "FINAL_BOSS".
@export var source_event_kind: String = "WORKOUT_DAILY"


## Unix timestamp (seconds) when the drop was created. Used by Formula 3 TTL /
## expiry-state derivation and by #29 Mirror Moment historical ordering. 0 = unset.
@export var created_at_unix: int = 0


## Schema version of this record's serialized shape. Bumped when the dict schema
## changes so PersistenceLayer migration (Story 012) can up-convert older blobs.
@export var schema_version: int = 1


## Free-form item metadata bag (name, icon id, stat rolls, etc.) populated by the
## item generator. Kept as an opaque Dictionary so the rarity/affinity record does
## not couple to the #17 Equipment item schema. Values MUST be JSON-native scalars
## / nested Dictionaries / Arrays for round-trip safety.
@export var item_metadata: Dictionary = {}


## Convert this record to a plain Dictionary per ADR-0006 Contract 3.
##
## `payload_type` is set via `get_script().get_global_name()` (NOT get_class(),
## which returns "Resource" for every GDScript Resource subclass and corrupts
## forward-recovery dispatch — same binding as BossPayload / EnemyKilledPayload,
## TR-persist-005). CI lint check_payload_type_uses_get_script enforces this.
##
## All enum-derived fields are ALREADY String (string-name set by the producer per
## ADR-0007) — this method is a pure passthrough and performs no find_key round-trip.
##
## Schema:
##   {
##     "payload_type": "LootDrop",
##     "drop_id": String,
##     "transition_id": String,
##     "rarity_tier": String,         # RarityTier name
##     "item_type": String,           # ItemType name
##     "class_tag": String,           # ClassTag name
##     "source_event_kind": String,   # SourceEventKind name
##     "created_at_unix": int,
##     "schema_version": int,
##     "item_metadata": Dictionary,
##   }
func to_dict() -> Dictionary:
	return {
		"payload_type": get_script().get_global_name(),
		"drop_id": drop_id,
		"transition_id": transition_id,
		"rarity_tier": rarity_tier,
		"item_type": item_type,
		"class_tag": class_tag,
		"source_event_kind": source_event_kind,
		"created_at_unix": created_at_unix,
		"schema_version": schema_version,
		"item_metadata": item_metadata,
	}


## Reconstruct a LootDrop from a Dictionary produced by to_dict().
##
## Defensive against missing / older-schema keys per ADR-0006 Contract 3 — every
## field falls back to its safe default. The string-name enum fields fall back to
## the Family A safe value ("COMMON" / "WORKOUT_DAILY") or, for the Family B
## ClassTag, to "NEUTRAL" (the usable any-class outcome). `payload_type` is consumed
## by PersistenceLayer's outer dispatch, not here.
static func from_dict(data_dict: Dictionary) -> SerializableResource:
	var drop: LootDrop = LootDrop.new()
	drop.drop_id = String(data_dict.get("drop_id", ""))
	drop.transition_id = String(data_dict.get("transition_id", ""))
	drop.rarity_tier = String(data_dict.get("rarity_tier", "COMMON"))
	drop.item_type = String(data_dict.get("item_type", "WEAPON"))
	drop.class_tag = String(data_dict.get("class_tag", "NEUTRAL"))
	drop.source_event_kind = String(data_dict.get("source_event_kind", "WORKOUT_DAILY"))
	drop.created_at_unix = int(data_dict.get("created_at_unix", 0))
	drop.schema_version = int(data_dict.get("schema_version", 1))
	drop.item_metadata = data_dict.get("item_metadata", {})
	return drop
