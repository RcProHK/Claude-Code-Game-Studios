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

## Formula 2 — salvage baseline (COMMON). Rationale self-standing (Pass 1: the
## old "EC-38 anchor" was a mis-citation); three digits = psychologically felt.
const SHARD_BASE: int = 100

## Formula 2 — per-tier multiplier [COMMON..LEGENDARY]. Super-linear: low tiers
## are the steady faucet, high tiers keep their keep-value. MONOTONIC BINDING:
## salvage_yield(t+1) > salvage_yield(t) — asserted at boot (Story 010/014).
const RARITY_SHARD_MULT: Array[float] = [1.0, 1.5, 2.5, 4.5, 8.0]


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

## Equip loadout: EquipSlot → item_id (&"" = empty). COSMETIC slot is part of
## the loadout but NEVER aggregated (Rule 8 structural exclusion).
var _loadout: Dictionary = {
	EquipmentEnums.EquipSlot.WEAPON: &"",
	EquipmentEnums.EquipSlot.ARMOR: &"",
	EquipmentEnums.EquipSlot.ACCESSORY: &"",
	EquipmentEnums.EquipSlot.COSMETIC: &"",
}

## Re-entrancy guard (Rule 6 / EC-15 — Story 016 wires push_error+defer; the
## flag exists from Story 006 so the mutation discipline is structural).
var _mutating: bool = false

## Pending push dedup flag (Rule 14 step 7 + EC-14 — set when a push must be
## retried after GSM Ready; boot pending-replay and rejection retry share it).
var _pending_stat_push: bool = false

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
	# Rule 3 (Story 004): cap routing — inventory full (≥120) parks the item in
	# the mailbox (7d TTL → auto-salvage, Story 005). Cap count excludes mailbox.
	if get_inventory_count() >= MAX_INVENTORY:
		item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_MAILBOX
	else:
		item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY

	_items[item_id] = item

	# Rule 4 (Story 005): mailbox capacity — evict-oldest (FIFO, receipt-immune)
	# the moment the hard cap is crossed; value never evaporates (auto-salvage).
	if item.lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		_enforce_mailbox_hard_cap()

	if item.lifecycle_state == EquipmentEnums.ItemLifecycle.IN_INVENTORY:
		_evaluate_auto_equip(item)
	# TODO Story 013: dirty mark + per-action flush.
	return EquipmentEnums.ReceiveResult.OK


# ── Mailbox claim (Rule 3 / EC-10 — Story 004) ─────────────────────────────────


## Claim a mailbox item into the inventory. Blocked while the inventory is full
## (EC-10 — claim never over-admits): returns {ok: false, shortfall: N} where N
## is the number of slots the player must free (#23 surfaces "先騰 N 個位" +
## bulk-salvage shortcut). On success the item enters IN_INVENTORY and an
## auto-equip evaluation runs (Rule 6 trigger set: claim 後).
func claim(item_id: StringName) -> Dictionary:
	var item: EquipmentItem = _items.get(item_id, null)
	if item == null or item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		return {"ok": false, "shortfall": 0, "error": "not_in_mailbox"}
	var inventory_count: int = get_inventory_count()
	if inventory_count >= MAX_INVENTORY:
		return {"ok": false, "shortfall": inventory_count - MAX_INVENTORY + 1}
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	_evaluate_auto_equip(item)
	# TODO Story 013: dirty mark + per-action flush.
	return {"ok": true, "shortfall": 0}


# ── Auto-equip-if-better (Rule 6 — Story 006) ──────────────────────────────────


## Evaluate one candidate against the current loadout (trigger set: receive_loot
## 後 / claim 後 / salvage-induced backfill 經 _backfill_slot).
##
## Comparison key = LOADOUT-LEVEL MARGINAL (clamp-aware, Formula 1+4): the swap
## happens iff the post-clamp loadout score with the candidate is STRICTLY
## greater than the current one — never swaps an HP item away for capped ATK.
## COSMETIC is manual-only (Rule 5); CONSUMABLE has no slot (D1); locked
## equipped items freeze their slot (Rule 7).
##
## Mutation discipline (Rule 6 BINDING): all in-memory mutations complete BEFORE
## the single #11 push — _push_aggregate() is always the last step.
func _evaluate_auto_equip(item: EquipmentItem) -> void:
	if item.is_cosmetic:
		return  # manual-only — the algorithm never overrides the player's look
	if item.slot_affinity == EquipmentEnums.EquipSlot.NONE \
			or item.slot_affinity == EquipmentEnums.EquipSlot.COSMETIC:
		return  # CONSUMABLE (or mis-tagged cosmetic) never auto-equips
	if item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_INVENTORY:
		return
	var slot: int = item.slot_affinity
	var current: EquipmentItem = _equipped_item_in_slot(slot)
	if current != null and current.is_locked:
		return  # Rule 7: lock always wins
	var current_score: float = LoadoutScoreCalc.loadout_score(_compute_effective_aggregate())
	var candidate_score: float = LoadoutScoreCalc.loadout_score(
		_effective_aggregate_with(slot, item))
	if candidate_score > current_score:
		_swap_into_slot(slot, item)
		_push_aggregate()


## Backfill an emptied functional slot (Rule 6 trigger: salvage-induced unequip).
## Picks the best unlocked IN_INVENTORY candidate by loadout-marginal score with
## the deterministic tie-break (rarity ↓ → acquired_at ↑ → item_id ↑). Positive
## marginal only (empty baseline contributes 0 — any positive candidate wins).
## In-memory only — the caller (salvage batch, Story 010) owns the single push.
func _backfill_slot(slot: int) -> void:
	var best: EquipmentItem = null
	for item_id: StringName in _items:
		var item: EquipmentItem = _items[item_id]
		if item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_INVENTORY:
			continue
		if item.slot_affinity != slot or item.is_cosmetic or item.is_locked:
			continue
		if best == null or _candidate_beats(slot, item, best):
			best = item
	if best == null:
		return
	var with_best: float = LoadoutScoreCalc.loadout_score(
		_effective_aggregate_with(slot, best))
	var without: float = LoadoutScoreCalc.loadout_score(_compute_effective_aggregate())
	if with_best > without:
		_swap_into_slot(slot, best)


## Deterministic candidate ordering (AC-14): loadout-marginal score ↓ →
## rarity ↓ → acquired_at_unix ↑ (older kept, less churn) → item_id ↑.
func _candidate_beats(slot: int, a: EquipmentItem, b: EquipmentItem) -> bool:
	var score_a: float = LoadoutScoreCalc.loadout_score(_effective_aggregate_with(slot, a))
	var score_b: float = LoadoutScoreCalc.loadout_score(_effective_aggregate_with(slot, b))
	if score_a != score_b:
		return score_a > score_b
	if a.rarity != b.rarity:
		return a.rarity > b.rarity
	if a.acquired_at_unix != b.acquired_at_unix:
		return a.acquired_at_unix < b.acquired_at_unix
	return String(a.item_id) < String(b.item_id)


## In-memory swap: previous occupant → IN_INVENTORY, candidate → EQUIPPED.
## NEVER pushes #11 itself (mutation discipline — push is the caller's last step).
func _swap_into_slot(slot: int, item: EquipmentItem) -> void:
	var previous: EquipmentItem = _equipped_item_in_slot(slot)
	if previous != null:
		previous.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.EQUIPPED
	_loadout[slot] = item.item_id


func _equipped_item_in_slot(slot: int) -> EquipmentItem:
	var item_id: StringName = _loadout.get(slot, &"")
	if item_id == &"":
		return null
	return _items.get(item_id, null)


# ── Aggregation + AntiSnowball + #11 push (Rule 8 — Story 008) ─────────────────

## StatSystem script ref for the nested StatModifier class (production path; the
## _stat_system seam itself stays untyped for test mocks).
const _StatSystemScript = preload("res://src/autoload/stat_system.gd")


## Sum the 3 FUNCTIONAL slots' stat_modifiers into a raw aggregate. COSMETIC is
## structurally excluded — the iterator never visits it, so even a scrub-escaped
## stat dict cannot feed combat (Rule 8 last line of defense / AC-22).
func _compute_raw_aggregate() -> Dictionary:
	var raw: Dictionary = {}
	for slot: int in [EquipmentEnums.EquipSlot.WEAPON,
			EquipmentEnums.EquipSlot.ARMOR, EquipmentEnums.EquipSlot.ACCESSORY]:
		var item: EquipmentItem = _equipped_item_in_slot(slot)
		if item == null:
			continue
		for key: Variant in item.stat_modifiers:
			raw[key] = float(raw.get(key, 0.0)) + float(item.stat_modifiers[key])
	return raw


## Formula 4 over the current loadout: raw aggregate → AntiSnowball + per-key
## contract clamp. SDA comes from the G-2 API (single source of truth — inline
## re-derivation is FORBIDDEN, knob-drift hazard).
func _compute_effective_aggregate() -> Dictionary:
	return EquipmentClampCalc.clamp_aggregate(
		_compute_raw_aggregate(), _stat_derived_atk())


## Hypothetical effective aggregate with `item` occupying `slot` (the loadout
## itself is NOT mutated — used by the marginal comparison, Rule 6).
func _effective_aggregate_with(slot: int, item: EquipmentItem) -> Dictionary:
	var raw: Dictionary = {}
	for other_slot: int in [EquipmentEnums.EquipSlot.WEAPON,
			EquipmentEnums.EquipSlot.ARMOR, EquipmentEnums.EquipSlot.ACCESSORY]:
		var occupant: EquipmentItem = item if other_slot == slot \
			else _equipped_item_in_slot(other_slot)
		if occupant == null:
			continue
		for key: Variant in occupant.stat_modifiers:
			raw[key] = float(raw.get(key, 0.0)) + float(occupant.stat_modifiers[key])
	return EquipmentClampCalc.clamp_aggregate(raw, _stat_derived_atk())


func _stat_derived_atk() -> float:
	return float(_stat_system.get_attack_power_excluding_equipment()) \
		if _stat_system != null else 0.0


## Push the clamped aggregate to #11 as ONE synthetic-id modifier. Same-id
## re-apply = atomic replace (#11 EC-17 pin, G-2 RESOLVED — no remove+apply dip).
## ALWAYS the last step of any mutation operation (Rule 6 discipline). Emits
## the AntiSnowball clamp telemetry when the cap actually bound (EC-16 — never
## silent: #22 shows the "+84 / +90 受真身上限約束" badge off the same data).
func _push_aggregate() -> void:
	var raw: Dictionary = _compute_raw_aggregate()
	var effective: Dictionary = EquipmentClampCalc.clamp_aggregate(raw, _stat_derived_atk())
	var raw_atk: float = float(raw.get(&"ATTACK_POWER", 0.0))
	var effective_atk: float = float(effective.get(&"ATTACK_POWER", 0.0))
	if raw_atk > effective_atk:
		_emit_telemetry("equipment.antisnowball.clamp", {
			"raw_atk": raw_atk, "effective_atk": effective_atk,
		})
	if _stat_system == null:
		return
	var modifier = _StatSystemScript.StatModifier.new()
	modifier.deltas = effective
	_stat_system.apply_equipment_modifier(&"equipment_aggregate", modifier)
	# TODO Story 015: stat_mutation_rejected subscription → _pending_stat_push retry.


## #22 badge data contract (EC-16 / AC-38): current raw vs effective ATK.
func get_aggregate_raw_and_effective() -> Dictionary:
	var raw: Dictionary = _compute_raw_aggregate()
	var effective: Dictionary = _compute_effective_aggregate()
	return {
		"raw": float(raw.get(&"ATTACK_POWER", 0.0)),
		"effective": float(effective.get(&"ATTACK_POWER", 0.0)),
	}


# ── Formula 2 + auto-salvage (Rule 4/9 — Story 005) ────────────────────────────


## Formula 2 — salvage_yield(rarity) = floori(SHARD_BASE × RARITY_SHARD_MULT).
## Defaults: COMMON 100 / UNCOMMON 150 / RARE 250 / EPIC 450 / LEGENDARY 800.
## Single salvage value track: manual salvage, bulk, mailbox auto-salvage AND
## the #15 EC-38 cosmetic-dupe auto-convert all use THIS function (G-3).
static func salvage_yield(rarity: int) -> int:
	return floori(SHARD_BASE * RARITY_SHARD_MULT[rarity])


## Convert an item to shards in place (auto paths: mailbox TTL / hard-cap evict).
## Value never evaporates (A3): shards credited, tombstone registered, loud
## telemetry. NOT the manual salvage path (that is Story 010's transaction).
func _auto_salvage(item: EquipmentItem, telemetry_event: String) -> void:
	_forge_shards += salvage_yield(item.rarity)
	_items.erase(item.item_id)
	register_tombstone(item.item_id)
	_emit_telemetry(telemetry_event, {
		"item_id": String(item.item_id),
		"rarity": LootEnums.RarityTier.find_key(item.rarity),
		"shards": salvage_yield(item.rarity),
	})


# ── Mailbox sweep + hard cap (Rule 4 — Story 005) ──────────────────────────────


## Boot-time TTL sweep (Rule 14 step 4 wires this): mailbox items older than
## OVERFLOW_MAILBOX_TTL_DAYS auto-salvage. A3 BINDING: receipt-bearing items are
## immune — they never silently expire. Cross-session time basis: wall-clock +
## server sanity; offline or drift beyond tolerance ⇒ grace (sweep skipped,
## retried next boot — misjudgement risk degraded to "early salvage" by A3).
func sweep_mailbox() -> void:
	var now: int = int(_now_unix_provider.call())
	if not _server_clock_sane(now):
		return  # grace — prefer not expiring
	var ttl_sec: int = OVERFLOW_MAILBOX_TTL_DAYS * 86400
	for item_id: StringName in _items.keys():
		var item: EquipmentItem = _items[item_id]
		if item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_MAILBOX:
			continue
		if item.has_receipt():
			continue  # A3: never silently expire
		if now - item.acquired_at_unix > ttl_sec:
			_auto_salvage(item, "inventory.mailbox.auto_salvaged")


## Server-clock sanity (G-7 seam). Invalid/empty provider or null return =
## offline ⇒ NOT sane ⇒ grace. Drift beyond CLOCK_SANITY_TOLERANCE_SEC ⇒ grace.
func _server_clock_sane(now_unix: int) -> bool:
	if not _server_unix_provider.is_valid():
		return false
	var server_now: Variant = _server_unix_provider.call()
	if server_now == null:
		return false
	return absi(int(server_now) - now_unix) <= CLOCK_SANITY_TOLERANCE_SEC


## Hard-cap enforcement (EC-9): while the mailbox exceeds MAILBOX_HARD_CAP the
## OLDEST (min acquired_at_unix — FIFO, not LRU) non-receipt item auto-salvages.
## All-receipt fallback (defense-in-depth; unreachable for ~300 weeks at 0.6
## LEGENDARY/week): soft-admit over cap + loud telemetry alert.
func _enforce_mailbox_hard_cap() -> void:
	while _mailbox_count() > MAILBOX_HARD_CAP:
		var oldest: EquipmentItem = _oldest_evictable_mailbox_item()
		if oldest == null:
			_emit_telemetry("inventory.mailbox.all_receipt_soft_admit", {
				"mailbox_count": _mailbox_count(),
			})
			return
		_auto_salvage(oldest, "inventory.mailbox.auto_salvaged")


func _mailbox_count() -> int:
	var count: int = 0
	for item_id: StringName in _items:
		if _items[item_id].lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX:
			count += 1
	return count


## Oldest non-receipt mailbox item (receipt-bearing skipped — A3), or null when
## every mailbox item carries a receipt.
func _oldest_evictable_mailbox_item() -> EquipmentItem:
	var oldest: EquipmentItem = null
	for item_id: StringName in _items:
		var item: EquipmentItem = _items[item_id]
		if item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_MAILBOX:
			continue
		if item.has_receipt():
			continue
		if oldest == null or item.acquired_at_unix < oldest.acquired_at_unix:
			oldest = item
	return oldest


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
