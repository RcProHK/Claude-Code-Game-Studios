## EquipmentEnums — canonical enum declarations for #17 Equipment & Inventory
##
## Driving GDD: design/gdd/equipment-inventory.md (APPROVED 2026-06-06 Pass 3)
## Driving Story: production/epics/equipment-inventory/story-001-data-types-stat-table.md
## Governing ADRs:
##   * ADR-0007 (Accepted 2026-05-29) Class & Domain Enum Convention — Family A / B rules
##   * ADR-0009 (Accepted 2026-05-29) Signal Payload Schema — enum string-name serialization
##
## WHY a dedicated holder (vs inline in inventory_system.gd):
## Same rationale as LootEnums — EquipmentItem (equipment_item.gd) + the formula
## calcs import these enums BEFORE the InventorySystem autoload exists (Story 016
## registers it). src/core/ keeps them dependency-neutral.
##
## REUSED enums (declared in LootEnums, NOT redeclared here — D1/D2 binding):
##   * LootEnums.ItemType   {WEAPON, ARMOR, ACCESSORY, CONSUMABLE, COSMETIC}
##   * LootEnums.ClassTag   {STRIKE, CONTROL, MOBILITY, NEUTRAL}
##   * LootEnums.RarityTier {COMMON..LEGENDARY}
class_name EquipmentEnums


## EquipmentItem lifecycle state — ADR-0007 Family A (Outcome/State). Ordinal 0 =
## IN_MAILBOX is the conservative default: an uninitialised item reads back as
## "parked in mailbox" — it neither feeds combat (#11) nor can be silently lost
## (mailbox expiry = auto-salvage, value-preserving per GDD A3). Never fabricates
## an EQUIPPED combat contribution.
enum ItemLifecycle {
	IN_MAILBOX,    # 0 — overflow parking, 7d TTL → auto-salvage (conservative default)
	IN_INVENTORY,  # 1 — banked, not equipped
	EQUIPPED,      # 2 — live, feeding #11 via equipment_aggregate
	SALVAGED,      # 3 — terminal; survives only as {item_id: salvaged_at_unix} tombstone
}


## Functional + cosmetic equip slots — ADR-0007 Family B (Classification).
## Declaration order is load-bearing (1:1 with LootEnums.ItemType functional
## members). NONE is the Family B sentinel placed LAST: CONSUMABLE items carry
## slot_affinity = NONE (they occupy no slot and never trigger auto-equip — D1).
## Producers assign explicitly; zero-default reliance FORBIDDEN.
enum EquipSlot {
	WEAPON,     # 0 — 1:1 ItemType.WEAPON
	ARMOR,      # 1 — 1:1 ItemType.ARMOR
	ACCESSORY,  # 2 — 1:1 ItemType.ACCESSORY
	COSMETIC,   # 3 — parallel pipeline, never feeds #11, manual-only (Rule 5)
	NONE,       # 4 — sentinel LAST: no slot (CONSUMABLE)
}


## receive_loot() return contract — ADR-0007 Family A (Outcome). Ordinal 0 =
## FAILED_ROLLBACK is the conservative default: an unset/zero result reads as
## "the grant did NOT happen" → #15 keeps the record in loot.pending.recovery
## and boot drain re-attempts (idempotent, dedup makes the retry harmless).
## A zero-default fabricating OK would silently drop loot — Pillar 3 violation.
## NOTE: GDD Pass 3 lists members with OK first for readability; the ORDINALS
## here follow ADR-0007 (conservative = 0). Members cross boundaries as string
## names (ADR-0009), so ordinal order is an internal safety property only.
enum ReceiveResult {
	FAILED_ROLLBACK,    # 0 — hydration/validation failed; #15 owns recovery write (EC-1)
	OK,                 # 1 — granted (IN_INVENTORY or IN_MAILBOX)
	QUEUED_SUSPENDED,   # 2 — GSM suspended; parked in inventory.pending_queue (Rule 15)
	DUPLICATE_NOOP,     # 3 — item_id already active or tombstoned (Rule 2)
	CONVERTED_DUPE,     # 4 — cosmetic dupe auto-converted to shards (Rule 11)
}
