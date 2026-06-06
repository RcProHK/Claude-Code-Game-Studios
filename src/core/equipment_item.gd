## EquipmentItem — typed equipment record for #17 Equipment & Inventory
##
## Driving GDD: design/gdd/equipment-inventory.md (APPROVED 2026-06-06 Pass 3) — Rule 1 / D8 / D9
## Driving Story: production/epics/equipment-inventory/story-001-data-types-stat-table.md
## Governing ADRs:
##   * ADR-0006 (Accepted) Contract 3 — dict envelope; .tres → user:// FORBIDDEN
##   * ADR-0007 (Accepted) — enum fields persisted as STRING NAMES
##   * ADR-0009 (Accepted) — typed SerializableResource envelope
##
## WHY typed enum fields at runtime (vs LootDrop's String passthrough):
## LootDrop is a persistence-layer pure record; EquipmentItem is #17's LIVE domain
## object — auto-equip comparisons, slot-affinity switches and aggregation iterate
## it every operation. Typed enums keep call sites IDE-safe
## (`item.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED`); the
## to_dict()/from_dict() boundary does the find_key()/get() string-name round-trip
## (sanctioned pattern per serializable_resource.gd header).
##
## D8 (derived-keys-only, BINDING): stat_modifiers may ONLY carry the 4 derived
## stat keys {"ATTACK_POWER","MAX_HP","MOVE_SPEED","CRIT_CHANCE"} — never
## STR/DEX/VIT. "真身" base stats are written by real training only (Pillar 1
## structural guarantee). The guard lives in hydration (Story 002/014); this
## record documents the contract and exposes ALLOWED_STAT_KEYS for the guard.
class_name EquipmentItem extends SerializableResource


## The 4 derived-stat keys an item may carry (D8). Used by the final-dict guard
## (EC-4) and the aggregation iterator (Rule 8). StringName for cheap compare.
const ALLOWED_STAT_KEYS: Array[StringName] = [
	&"ATTACK_POWER",
	&"MAX_HP",
	&"MOVE_SPEED",
	&"CRIT_CHANCE",
]


## Globally-unique idempotency key — Formula 6: composite StringName
## `source_transition_id + "_" + drop_id` (NO hash — 32-bit collision = silent
## loot loss; composite is collision-free by construction since #15 drop_id is
## unique and stable once persisted). Empty = uninitialised sentinel.
@export var item_id: StringName = &""


## Originating GSM transition (ADR-0009 intrinsic correlation; Contract 2: OPAQUE,
## never parsed).
@export var source_transition_id: String = ""


## Item category — LootEnums.ItemType typed value.
@export var item_type: LootEnums.ItemType = LootEnums.ItemType.WEAPON


## Rarity tier — LootEnums.RarityTier typed value (ordinal 0 COMMON = Pillar 3 floor).
@export var rarity: LootEnums.RarityTier = LootEnums.RarityTier.COMMON


## Class affinity tag — LootEnums.ClassTag. MVP display-only (D2): feeds
## provenance day-label + future #12 synergy hook; not read by Formula 1.
@export var class_tag: LootEnums.ClassTag = LootEnums.ClassTag.NEUTRAL


## Derived-stat deltas (D8: ALLOWED_STAT_KEYS only; values assigned by the
## StatAssignmentTable lookup — D9, never read from #15 metadata).
## Cosmetic / consumable items carry {} (empty).
@export var stat_modifiers: Dictionary = {}


## F-12 workout receipt. LEGENDARY drops MUST carry one (EC-2 rollback if
## missing on the drop path); other tiers nullable.
@export var source_receipt: SourceReceipt = null


## All-tier lightweight provenance line ("拾於 6月3日・腿日") derived once at
## hydration from acquired_at_unix (UTC date — determinism pin) + class_tag.
@export var provenance_text: String = ""


## Cosmetic parallel-pipeline flag — true ⇒ stat_modifiers forced {}, never
## aggregated (Rule 8 structural exclusion), manual-equip only (Rule 5).
@export var is_cosmetic: bool = false


## Cosmetic visual identity (dupe detection key for Rule 11 auto-convert;
## empty for functional items).
@export var visual_id: String = ""


## Lifecycle state — EquipmentEnums.ItemLifecycle (ordinal 0 IN_MAILBOX =
## conservative default).
@export var lifecycle_state: EquipmentEnums.ItemLifecycle = EquipmentEnums.ItemLifecycle.IN_MAILBOX


## Item-level lock (Pass 1 unified — NOT slot-level). Locked ⇒ auto-equip skips
## its slot; immune to salvage / bulk-salvage / mailbox auto-salvage (Rule 7).
@export var is_locked: bool = false


## Unix timestamp (seconds) stamped via TimeProvider.now_unix() at receive.
## Drives mailbox FIFO evict + tie-break ordering. 0 = unset.
@export var acquired_at_unix: int = 0


## Slot this item occupies when equipped — EquipmentEnums.EquipSlot.
## CONSUMABLE ⇒ NONE (occupies no slot, never auto-equips — D1).
@export var slot_affinity: EquipmentEnums.EquipSlot = EquipmentEnums.EquipSlot.NONE


## Schema version for ADR-0003 migration path.
@export var schema_version: int = 1


## Convert to plain Dictionary per ADR-0006 Contract 3. Enum fields emit STRING
## NAMES via find_key (ADR-0007 — int ordinals are migration-fragile).
## payload_type via get_script().get_global_name() (TR-persist-005).
func to_dict() -> Dictionary:
	return {
		"payload_type": get_script().get_global_name(),
		"item_id": String(item_id),
		"source_transition_id": source_transition_id,
		"item_type": LootEnums.ItemType.find_key(item_type),
		"rarity": LootEnums.RarityTier.find_key(rarity),
		"class_tag": LootEnums.ClassTag.find_key(class_tag),
		"stat_modifiers": _stat_modifiers_to_json(),
		"source_receipt": source_receipt.to_dict() if source_receipt != null else null,
		"provenance_text": provenance_text,
		"is_cosmetic": is_cosmetic,
		"visual_id": visual_id,
		"lifecycle_state": EquipmentEnums.ItemLifecycle.find_key(lifecycle_state),
		"is_locked": is_locked,
		"acquired_at_unix": acquired_at_unix,
		"slot_affinity": EquipmentEnums.EquipSlot.find_key(slot_affinity),
		"schema_version": schema_version,
	}


## Reconstruct from a to_dict() Dictionary. Defensive per Contract 3: every field
## falls back to its safe default (Family A ordinal-0 / Family B explicit sentinel).
static func from_dict(data_dict: Dictionary) -> SerializableResource:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName(String(data_dict.get("item_id", "")))
	item.source_transition_id = String(data_dict.get("source_transition_id", ""))
	item.item_type = LootEnums.ItemType.get(
		String(data_dict.get("item_type", "")), LootEnums.ItemType.WEAPON)
	item.rarity = LootEnums.RarityTier.get(
		String(data_dict.get("rarity", "")), LootEnums.RarityTier.COMMON)
	item.class_tag = LootEnums.ClassTag.get(
		String(data_dict.get("class_tag", "")), LootEnums.ClassTag.NEUTRAL)
	item.stat_modifiers = _stat_modifiers_from_json(data_dict.get("stat_modifiers", {}))
	var receipt_dict: Variant = data_dict.get("source_receipt", null)
	if receipt_dict is Dictionary:
		item.source_receipt = SourceReceipt.from_dict(receipt_dict)
	item.provenance_text = String(data_dict.get("provenance_text", ""))
	item.is_cosmetic = bool(data_dict.get("is_cosmetic", false))
	item.visual_id = String(data_dict.get("visual_id", ""))
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.get(
		String(data_dict.get("lifecycle_state", "")), EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	item.is_locked = bool(data_dict.get("is_locked", false))
	item.acquired_at_unix = int(data_dict.get("acquired_at_unix", 0))
	item.slot_affinity = EquipmentEnums.EquipSlot.get(
		String(data_dict.get("slot_affinity", "")), EquipmentEnums.EquipSlot.NONE)
	item.schema_version = int(data_dict.get("schema_version", 1))
	return item


## True when this item carries an F-12 receipt — A3 binding: receipt-bearing
## items never silently expire (mailbox TTL sweep + hard-cap evict skip them).
func has_receipt() -> bool:
	return source_receipt != null


# ── Private serialization helpers ──────────────────────────────────────────────


## StringName keys → plain String keys for JSON round-trip safety.
func _stat_modifiers_to_json() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in stat_modifiers:
		out[String(key)] = stat_modifiers[key]
	return out


## Plain String keys → StringName keys (runtime compare form).
static func _stat_modifiers_from_json(json_dict: Variant) -> Dictionary:
	var out: Dictionary = {}
	if json_dict is Dictionary:
		for key: Variant in json_dict:
			out[StringName(String(key))] = float(json_dict[key])
	return out
