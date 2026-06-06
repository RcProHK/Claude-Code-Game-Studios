## InventorySystem — #17 Equipment & Inventory autoload(戰利品歸宿系統)
##
## Driving GDD: design/gdd/equipment-inventory.md (APPROVED 2026-06-06 Pass 3)
## Driving Stories: production/epics/equipment-inventory/story-002..016
## Governing ADRs:
##   * ADR-0003 (Accepted) — backend-primary persistence, `inventory.*` namespace,
##     per-action batched write granularity (Rule 13)
##   * ADR-0006 (Accepted) — Contract 2 (transition_id opaque) / 3 (dict envelope) /
##     4 (sequential boot — assert is_boot_completed(), NEVER await) / 5 (deferred
##     idiom) / 6 (connect_for_initial_state)
##   * ADR-0008 (Accepted, 2026-06-06 amendment) — constraint 8:
##     StatSystem ≺ InventorySystem ≺ LootDropSystem (binding — #15 calls
##     Inventory.receive_loot at runtime/catch-up)
##   * ADR-0009 (Accepted) — telemetry payloads minimal + intrinsic
##
## RESPONSIBILITY (GDD Overview): receive #15 loot_drop_records → hydrate typed
## EquipmentItem (stats from StatAssignmentTable, D9 — zero runtime RNG) → manage
## inventory (120 cap + mailbox auto-salvage) → auto-equip-if-better → salvage →
## feed #11 one clamped `&"equipment_aggregate"` modifier (FR-Equipment-AntiSnowball).
##
## D8 BINDING (derived-keys-only): items never carry STR/DEX/VIT — "真身" base
## stats are written by real training only (Pillar 1 structural guarantee).
extends Node


# ── Tuning knobs (GDD § Tuning Knobs; data-driven defaults) ────────────────────

## Inventory cap — DESIGN-FROZEN per #15 Pass 2 F-10 (count excludes mailbox).
const MAX_INVENTORY: int = 120

## Mailbox TTL before auto-salvage (A3: value never evaporates). Days.
const OVERFLOW_MAILBOX_TTL_DAYS: int = 7

## Mailbox capacity — follows #15 MAILBOX_HARD_CAP (G-1 RESOLVED: 180 > 120, INV-G3).
const MAILBOX_HARD_CAP: int = 180

## Server-clock sanity tolerance for the mailbox sweep (Rule 4). Seconds.
const CLOCK_SANITY_TOLERANCE_SEC: int = 3600

## Tombstone prune horizon — #15 HARD_CAP_DAYS (LOCKED 37; replay cannot originate
## from older sources; backend lootdrop_cache retention matches per Contract 15).
const TOMBSTONE_PRUNE_DAYS: int = 37


# ── DI seams (untyped — typed Node fails compile-time member check) ────────────

var _persistence = null      # PersistenceLayer (seam 3)
var _stat_system = null      # StatSystem (seam 2)
var _gsm = null              # GameStateMachine (seam 6)

## Wall-clock seam (seam 1) — ALL timestamp stamping/comparison goes through this.
var _now_unix_provider: Callable = Callable(Time, "get_unix_time_from_system")

## Server-clock seam (seam 7, G-7) — invalid/empty Callable ⇒ offline ⇒ grace path.
var _server_unix_provider: Callable = Callable()


# ── State ──────────────────────────────────────────────────────────────────────

## All live items (IN_MAILBOX / IN_INVENTORY / EQUIPPED): item_id → EquipmentItem.
var _items: Dictionary = {}

## SALVAGED tombstones: item_id → salvaged_at_unix (Rule 2 — id+timestamp only,
## full item discarded; pruned past TOMBSTONE_PRUNE_DAYS).
var _tombstones: Dictionary = {}

## Single salvage currency (D7 — MVP banked, salvage-only sink). int64, no cap.
var _forge_shards: int = 0

## D9 stat lookup (injected in tests; loaded from res:// at boot — Story 014).
var _stat_table: StatAssignmentTable = null

## Telemetry ring (test assertion surface + future #28 forwarding — #15 pattern).
var _telemetry_log: Array[Dictionary] = []


## Day-label map for provenance_text derivation (class_tag → 訓練日 label).
const _DAY_LABELS: Dictionary = {
	LootEnums.ClassTag.STRIKE: "推日",
	LootEnums.ClassTag.CONTROL: "拉日",
	LootEnums.ClassTag.MOBILITY: "腿日",
	LootEnums.ClassTag.NEUTRAL: "自由日",
}


# ── receive_loot (Rule 1 — Story 002) ─────────────────────────────────────────

## Intake API — #15 calls this after the #21 reveal handoff (modal dismissed).
## Returns the ReceiveResult contract (EC-1): failures return FAILED_ROLLBACK +
## CRITICAL telemetry; the `loot.pending.recovery` namespace write is #15's
## responsibility (EC-48 owner / L297 sole-writer) — #17 boot-drains it (Story 014).
##
## D9: stat_modifiers are assigned from the StatAssignmentTable — `item_metadata`
## stat keys are NEVER read (detection-only telemetry; table is authoritative).
func receive_loot(record: LootDrop) -> EquipmentEnums.ReceiveResult:
	# TODO Story 015: SUSPENDED check → durable queue → return QUEUED_SUSPENDED.

	# Validation order per GDD Rule 1 bullets.
	if record.transition_id.is_empty():
		return _fail_rollback("missing_source_transition_id", record)

	var item_type: int = LootEnums.ItemType.get(record.item_type, -1)
	if item_type == -1:
		return _fail_rollback("unknown_item_type", record)

	# rarity missing/unknown → COMMON floor (Pillar 3) — NOT a rollback (EC-3).
	var rarity: int = LootEnums.RarityTier.get(record.rarity_tier, LootEnums.RarityTier.COMMON)

	# class_tag missing/unknown → NEUTRAL; cosmetics force NEUTRAL (D2).
	var class_tag: int = LootEnums.ClassTag.get(record.class_tag, LootEnums.ClassTag.NEUTRAL)
	var is_cosmetic: bool = item_type == LootEnums.ItemType.COSMETIC
	if is_cosmetic:
		class_tag = LootEnums.ClassTag.NEUTRAL

	# F-12 binding (EC-2, drop-hydration scope ONLY): LEGENDARY without a receipt
	# is a fabrication → rollback. Other tiers: nullable.
	var receipt: SourceReceipt = _hydrate_receipt(record.item_metadata)
	if rarity == LootEnums.RarityTier.LEGENDARY and receipt == null:
		return _fail_rollback("legendary_missing_receipt", record)

	# D9 detection-only telemetry: metadata stat keys are never merged.
	if record.item_metadata.has("stat_modifiers"):
		_emit_telemetry("inventory.stat_key.dropped", {
			"reason": "metadata_stats_ignored_d9",
			"transition_id": record.transition_id,
		})

	# Formula 6 — composite StringName idempotency key (NO hash: 32-bit collision
	# = silent loot loss; drop_id is unique + stable once persisted by #15).
	var item_id: StringName = StringName(record.transition_id + "_" + record.drop_id)

	# Rule 2 (Story 003): dedup — active items AND tombstones both block re-grant.
	# A replayed salvaged item must NOT resurrect or re-pay shards (EC-6 / AC-07).
	if _items.has(item_id) or _tombstones.has(item_id):
		return EquipmentEnums.ReceiveResult.DUPLICATE_NOOP

	# TODO Story 012: cosmetic dupe visual_id detection → CONVERTED_DUPE.

	var now: int = int(_now_unix_provider.call())
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = item_id
	item.source_transition_id = record.transition_id
	item.item_type = item_type
	item.rarity = rarity
	item.class_tag = class_tag
	item.is_cosmetic = is_cosmetic
	item.visual_id = String(record.item_metadata.get("visual_id", ""))
	item.source_receipt = receipt
	item.acquired_at_unix = now
	item.slot_affinity = _slot_affinity_for(item_type)
	# D9: table-authoritative stat assignment (guards run on the FINAL dict).
	item.stat_modifiers = _guarded_stat_assign(item_type, rarity)
	item.provenance_text = _derive_provenance(now, class_tag)
	# TODO Story 004: cap routing (≥120 → IN_MAILBOX). Story 002 scope: direct grant.
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY

	_items[item_id] = item

	# TODO Story 006: auto-equip-if-better evaluation (trigger: receive_loot).
	# TODO Story 013: dirty mark + per-action flush.
	return EquipmentEnums.ReceiveResult.OK


# ── Tombstone lifecycle (Rule 2 — Story 003) ───────────────────────────────────


## Register a SALVAGED tombstone: {item_id: salvaged_at_unix}. Timestamped (NOT
## id-only) because prune needs an age and transition_id is opaque — Contract 2
## forbids parsing it for the embedded timestamp.
func register_tombstone(item_id: StringName) -> void:
	_tombstones[item_id] = int(_now_unix_provider.call())


## Prune tombstones older than the #15 replay horizon (HARD_CAP_DAYS = 37;
## backend retention matches — a replay can never originate from older sources).
## Pure helper (injected now) so boot (Story 014) and tests share one code path.
## Entries strictly OLDER than the horizon are removed; the 37.0d boundary keeps.
static func prune_tombstones(tombstones: Dictionary, now_unix: int) -> Dictionary:
	var horizon_sec: int = TOMBSTONE_PRUNE_DAYS * 86400
	var kept: Dictionary = {}
	for item_id: Variant in tombstones:
		var age_sec: int = now_unix - int(tombstones[item_id])
		if age_sec <= horizon_sec:
			kept[item_id] = tombstones[item_id]
	return kept


# ── Hydration helpers (Story 002) ──────────────────────────────────────────────


## Hydrate the F-12 receipt from item_metadata["source_receipt"] (dict form).
## Missing / wrong-shape ⇒ null (nullable for non-LEGENDARY tiers).
func _hydrate_receipt(metadata: Dictionary) -> SourceReceipt:
	var raw: Variant = metadata.get("source_receipt", null)
	if raw is Dictionary:
		return SourceReceipt.from_dict(raw)
	return null


## D8/EC-4 final-dict guard: only the 4 derived keys survive; negative deltas
## clamp to 0. Each violation emits LOUD telemetry (counter drift = alert; a
## silent drop would let auto-equip die invisibly). Runs on table output here
## (defense-in-depth — the shipped table is clean) and on boot re-hydration
## (Story 014, where corrupted persisted dicts are the real vector).
func _guarded_stat_assign(item_type: int, rarity: int) -> Dictionary:
	var table_mods: Dictionary = _stat_table.lookup(item_type, rarity) \
		if _stat_table != null else {}
	return guard_stat_dict(table_mods, _telemetry_log)


## Pure final-dict guard (shared by drop path + boot path — Story 014).
## Static so tests can exercise it without a booted autoload.
static func guard_stat_dict(mods: Dictionary, telemetry_sink: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in mods:
		var key_name: StringName = StringName(String(key))
		if not EquipmentItem.ALLOWED_STAT_KEYS.has(key_name):
			telemetry_sink.append({"event": "inventory.stat_key.dropped",
				"data": {"reason": "non_derived_key", "key": String(key_name)}})
			continue
		var delta: float = float(mods[key])
		if delta < 0.0:
			telemetry_sink.append({"event": "inventory.stat_key.dropped",
				"data": {"reason": "negative_delta_clamped", "key": String(key_name)}})
			delta = 0.0
		out[key_name] = delta
	return out


## Slot affinity per item_type (Rule 5 — 1:1 functional mapping; CONSUMABLE ⇒ NONE).
func _slot_affinity_for(item_type: int) -> EquipmentEnums.EquipSlot:
	match item_type:
		LootEnums.ItemType.WEAPON:
			return EquipmentEnums.EquipSlot.WEAPON
		LootEnums.ItemType.ARMOR:
			return EquipmentEnums.EquipSlot.ARMOR
		LootEnums.ItemType.ACCESSORY:
			return EquipmentEnums.EquipSlot.ACCESSORY
		LootEnums.ItemType.COSMETIC:
			return EquipmentEnums.EquipSlot.COSMETIC
		_:
			return EquipmentEnums.EquipSlot.NONE


## All-tier lightweight provenance (Rule 10): "拾於 M月D日・腿日". UTC date —
## determinism pin (display timezone is a #22/#23 presentation concern).
func _derive_provenance(acquired_at: int, class_tag: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(acquired_at)
	var label: String = _DAY_LABELS.get(class_tag, "自由日")
	return "拾於 %d月%d日・%s" % [int(dt["month"]), int(dt["day"]), label]


# ── Failure path (EC-1) ────────────────────────────────────────────────────────


## EC-1: emit CRITICAL telemetry + return FAILED_ROLLBACK. Inventory state is
## untouched; #15 owns the loot.pending.recovery write (this is NOT thrown).
func _fail_rollback(reason: String, record: LootDrop) -> EquipmentEnums.ReceiveResult:
	_emit_telemetry("loot.inventory.grant_fail", {
		"severity": "CRITICAL",
		"reason": reason,
		"transition_id": record.transition_id,
		"drop_id": record.drop_id,
	})
	return EquipmentEnums.ReceiveResult.FAILED_ROLLBACK


# ── Telemetry (#15 _telemetry_log pattern) ─────────────────────────────────────


## Record a telemetry event (test assertion surface + future #28 forwarding).
func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data.duplicate()})


## Return all telemetry events with the given name (for test assertions).
func get_telemetry(event_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _telemetry_log:
		if entry.get("event") == event_name:
			result.append(entry)
	return result


# ── Read API (UI data surface) ─────────────────────────────────────────────────


## Count of items in IN_INVENTORY state (cap accounting excludes mailbox — Rule 3).
func get_inventory_count() -> int:
	var count: int = 0
	for item_id: StringName in _items:
		if _items[item_id].lifecycle_state == EquipmentEnums.ItemLifecycle.IN_INVENTORY:
			count += 1
	return count


## Current forge_shard balance (int64; #23 display contract: thousands separators).
func get_forge_shards() -> int:
	return _forge_shards


## Fetch a live item by id (null when absent / salvaged).
func get_item(item_id: StringName) -> EquipmentItem:
	return _items.get(item_id, null)
