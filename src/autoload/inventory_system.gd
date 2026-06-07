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

## GSM-suspended flag (Rule 15): receive_loot queues durably while true.
var _suspended: bool = false

## Durable SUSPENDED intake queue (serialized LootDrop dicts). Mirrored to the
## `inventory.pending_queue` key on every enqueue — a browser discarding the
## suspended tab loses nothing (Pass 3 no-loss pin). #17-owned namespace
## (never touches #15's `loot.*` sole-writer surface).
var _pending_queue: Array = []

## Batch depth (Rule 15 burst batching): while > 0, _push_aggregate and
## _mark_dirty_and_flush coalesce into single end-of-batch operations
## (N receives ⇒ one push + one write, EC-22 / AC-29).
var _batch_depth: int = 0
var _batch_push_pending: bool = false
var _batch_flush_pending: bool = false


# ── Persistence keys (ADR-0003 `inventory.*` namespace) ────────────────────────

## Whole-state envelope under ONE key — a flush is exactly one IPersistence
## write (AC-31/AC-40 assert call counts; ADR-0003 full-file rewrite means
## key-splitting buys nothing).
const PERSIST_KEY_STATE: String = "inventory.state"

## Durable SUSPENDED queue (separate key — written on enqueue, not per action).
const PERSIST_KEY_PENDING_QUEUE: String = "inventory.pending_queue"

## #15-owned recovery namespace (EC-48 / L297 exception): #17 boot-drains then
## clears it — AFTER the inventory.state flush (no-loss ordering, Rule 14).
const PERSIST_KEY_RECOVERY: String = "loot.pending.recovery"


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
	# Rule 15 (Story 015): suspended intake parks durably and returns — drained
	# FIFO one frame after GSM leaves suspension.
	if _suspended:
		_pending_queue.append(record.to_dict())
		_persistence_write_pending_queue()
		return EquipmentEnums.ReceiveResult.QUEUED_SUSPENDED

	# EC-15 (Story 016): re-entrant mutation defers to the next frame.
	if _mutating:
		_reentrancy_defer(func() -> void: receive_loot(record))
		return EquipmentEnums.ReceiveResult.FAILED_ROLLBACK
	_mutating = true
	var result: EquipmentEnums.ReceiveResult = _receive_loot_body(record)
	_mutating = false
	return result


func _receive_loot_body(record: LootDrop) -> EquipmentEnums.ReceiveResult:
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

	# Rule 11 (Story 012): cosmetic dupe — visual id already owned (any state) ⇒
	# auto-convert at salvage_yield(rarity) (single value track, #15 EC-38 / G-3),
	# never granted twice. Tombstoned so a replay of the convert is also a no-op.
	if item_type == LootEnums.ItemType.COSMETIC \
			and _owns_cosmetic_visual(String(record.item_metadata.get("visual_id", ""))):
		_forge_shards += salvage_yield(rarity)
		register_tombstone(item_id)
		_emit_telemetry("inventory.cosmetic.dupe_converted", {
			"item_id": String(item_id),
			"visual_id": String(record.item_metadata.get("visual_id", "")),
			"shards": salvage_yield(rarity),
		})
		return EquipmentEnums.ReceiveResult.CONVERTED_DUPE

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
	_mark_dirty_and_flush()
	return EquipmentEnums.ReceiveResult.OK


# ── Boot (Rule 14, 8 steps — Story 014) ────────────────────────────────────────


## Boot reconciliation. Synchronous — NO await (Contract 4: StatSystem's
## boot_completed fired BEFORE this node entered the tree; the G-2 sync getter
## is the assert, ADR-0008 constraint 8 ordering is the guarantee).
func _ready() -> void:
	if _persistence == null:
		_persistence = PersistenceLayer
	if _stat_system == null:
		_stat_system = StatSystem
	if _gsm == null:
		_gsm = GameStateMachine
	if _stat_table == null:
		_stat_table = load("res://assets/data/equipment/stat_assignment_table.tres")

	# Config gates (design-by-contract): table cells within #11 contract ranges
	# + salvage curve monotonic (Story 010 invariant).
	_stat_table._validate()
	assert_salvage_curve_monotonic()
	# Step 0 — ADR-0008 ordering assert (NEVER await boot_completed).
	assert(_stat_system.is_boot_completed(),
		"InventorySystem booted before StatSystem — ADR-0008 constraint 8 violated")

	_boot_load()
	# Rejection retry wiring (EC-14): filter source == EQUIPMENT (#17 is the
	# only equipment caller; multi-key stat_id semantics pinned at epic w/ #11).
	if _stat_system.has_signal("stat_mutation_rejected"):
		_stat_system.stat_mutation_rejected.connect(_on_stat_mutation_rejected)


## Rule 14 steps 1-8. Push deliberately does NOT happen here — step 7 hands it
## to the GSM handler (Contract 6 initial delivery, next frame) via the single
## dedup flag, which also covers Suspended-at-boot crash recovery (AC-30).
func _boot_load() -> void:
	# Steps 1-3 — load + hydrate (persisted-trust + shape guard) + shard guard.
	var state: Variant = _persistence.read(PERSIST_KEY_STATE)
	if state is Dictionary:
		_load_state_dict(state)

	var now: int = int(_now_unix_provider.call())
	# Step 2b — tombstone prune (Story 003; replay horizon 37d).
	_tombstones = prune_tombstones(_tombstones, now)
	# Step 4 — mailbox TTL sweep (Story 005; A3 auto-salvage + grace).
	sweep_mailbox()

	# Step 5 — drain #15 recovery namespace + our own durable suspended queue
	# (batch: one push-pending + one flush at step 8, EC-22).
	var drained_recovery: bool = false
	_batch_depth += 1
	var recovery: Variant = _persistence.read(PERSIST_KEY_RECOVERY)
	if recovery is Array and not recovery.is_empty():
		for record_dict: Variant in recovery:
			if record_dict is Dictionary:
				receive_loot(LootDrop.from_dict(record_dict))
		drained_recovery = true
	var queued: Variant = _persistence.read(PERSIST_KEY_PENDING_QUEUE)
	if queued is Array and not queued.is_empty():
		for record_dict: Variant in queued:
			if record_dict is Dictionary:
				receive_loot(LootDrop.from_dict(record_dict))
	_batch_depth -= 1
	_batch_push_pending = false   # boot push is owned by step 7's flag instead
	_batch_flush_pending = false  # boot flush is step 8's single write below

	# Step 6 — loadout aggregate is COMPUTED lazily by the push; no push here
	# (single push owner = step 7 — Pass 3 fix, no double-push/dip).
	# Step 7 — GSM subscription (Contract 6; 3-arg callv layout, no .bind()).
	_pending_stat_push = true
	_gsm.connect_for_initial_state(_on_gsm_state_changed)

	# Step 8 — boot flush (ONE write) THEN recovery/queue clears (no-loss order:
	# a crash after flush but before clear only causes a harmless double-drain).
	_flush_state()
	if drained_recovery:
		_persistence.write(PERSIST_KEY_RECOVERY, [])
	if not _pending_queue.is_empty() or queued is Array and not (queued as Array).is_empty():
		_pending_queue.clear()
		_persistence.write(PERSIST_KEY_PENDING_QUEUE, [])


## Steps 1-3 detail: hydrate items (schema-shape guard — a corrupt entry is
## discarded LOUDLY, the rest load), re-run the final-dict guard + cosmetic
## scrub (EC-4/EC-5: persisted dicts are the real corruption vector; the
## drop-provenance validation does NOT re-run — EC-2 scope, persisted trust),
## clamp an illegal shard balance to 0 (EC-20).
func _load_state_dict(state: Dictionary) -> void:
	var items_raw: Variant = state.get("items", [])
	if items_raw is Array:
		for entry: Variant in items_raw:
			if not entry is Dictionary:
				_emit_telemetry("inventory.item.schema_corrupt", {"severity": "CRITICAL"})
				continue
			var item: EquipmentItem = EquipmentItem.from_dict(entry)
			if String(item.item_id).is_empty():
				_emit_telemetry("inventory.item.schema_corrupt", {"severity": "CRITICAL"})
				continue
			if item.is_cosmetic and not item.stat_modifiers.is_empty():
				item.stat_modifiers = {}
				_emit_telemetry("inventory.stat_key.dropped",
					{"reason": "cosmetic_scrub_boot", "item_id": String(item.item_id)})
			else:
				item.stat_modifiers = guard_stat_dict(item.stat_modifiers, _telemetry_log)
			_items[item.item_id] = item

	var shards_raw: Variant = state.get("shards", 0)
	if (shards_raw is int or shards_raw is float) and int(shards_raw) >= 0:
		_forge_shards = int(shards_raw)
	else:
		_forge_shards = 0
		_emit_telemetry("inventory.shard.balance_corrupted", {"severity": "CRITICAL"})

	var loadout_raw: Variant = state.get("loadout", {})
	if loadout_raw is Dictionary:
		for slot_name: Variant in loadout_raw:
			var slot: int = EquipmentEnums.EquipSlot.get(String(slot_name), -1)
			if slot != -1 and _loadout.has(slot):
				_loadout[slot] = StringName(String(loadout_raw[slot_name]))

	var tombstones_raw: Variant = state.get("tombstones", {})
	if tombstones_raw is Dictionary:
		for id_str: Variant in tombstones_raw:
			_tombstones[StringName(String(id_str))] = int(tombstones_raw[id_str])


# ── Persistence flush (Rule 13 — Story 013) ────────────────────────────────────


## #21 G-LM-10 — PUBLIC batch seam (story 024). Wraps the shipped internal
## _batch_depth coalescing (boot/suspended-drain pattern above) for external
## callers: #21's catch-up stream-end / grid-overflow commits N records in one
## frame — without the seam that is N full persists (the :389-393 gate fires
## per call). begin/end pairs nest; the OUTERMOST end runs the deferred
## aggregate-push + state-flush exactly once.
##
## Usage (#21 coordinator):
##   InventorySystem.begin_receive_batch()
##   for drop in displayed: InventorySystem.receive_loot(drop)
##   InventorySystem.end_receive_batch()
func begin_receive_batch() -> void:
	_batch_depth += 1


## Idempotent against imbalance: an unmatched end is a warned no-op (a crash
## mid-batch may strand depth — the next begin/end pair self-heals because
## the pending flags survive and drain on the next balanced end).
func end_receive_batch() -> void:
	if _batch_depth <= 0:
		push_warning("[InventorySystem] end_receive_batch without begin — no-op (G-LM-10)")
		return
	_batch_depth -= 1
	if _batch_depth > 0:
		return  # nested — the outermost end owns the drain
	if _batch_push_pending:
		_batch_push_pending = false
		_push_aggregate()
	if _batch_flush_pending:
		_batch_flush_pending = false
		_flush_state()


## Per-action flush: ONE IPersistence write for the whole state (items + shards
## + loadout + tombstones under PERSIST_KEY_STATE). Batched contexts coalesce.
func _mark_dirty_and_flush() -> void:
	if _batch_depth > 0:
		_batch_flush_pending = true
		return
	_flush_state()


func _flush_state() -> void:
	if _persistence == null:
		return
	var items_out: Array = []
	for item_id: StringName in _items:
		items_out.append(_items[item_id].to_dict())
	var loadout_out: Dictionary = {}
	for slot: int in _loadout:
		loadout_out[EquipmentEnums.EquipSlot.find_key(slot)] = String(_loadout[slot])
	var tombstones_out: Dictionary = {}
	for item_id: StringName in _tombstones:
		tombstones_out[String(item_id)] = _tombstones[item_id]
	_persistence.write(PERSIST_KEY_STATE, {
		"schema_version": 1,
		"items": items_out,
		"shards": _forge_shards,
		"loadout": loadout_out,
		"tombstones": tombstones_out,
	})


func _persistence_write_pending_queue() -> void:
	if _persistence != null:
		_persistence.write(PERSIST_KEY_PENDING_QUEUE, _pending_queue.duplicate())


# ── GSM lifecycle (Rule 15 — Story 015) ────────────────────────────────────────


## GSM script ref for the GameState enum (the autoload itself stays an untyped
## seam; the real signal is typed `state_changed(GameState, GameState, payload)`
## — int enum args, NOT StringName).
const _GSMScript = preload("res://src/autoload/game_state_machine.gd")


## Contract 6 handler (3-arg callv layout, GameState int args). Suspension gates
## intake; leaving suspension (or the initial non-suspended delivery) drains the
## queue and fires the pending boot/retry push — both DEFERRED one frame
## (Contract 5 ONE_SHOT idiom) to clear #11's Reconciling reject window.
func _on_gsm_state_changed(_previous: int, new_state: int, _payload: Variant = null) -> void:
	_suspended = new_state == _GSMScript.GameState.SUSPENDED
	if _suspended:
		return
	if not _pending_queue.is_empty():
		# The drain ends with an unconditional aggregate push — it absorbs any
		# pending boot-replay/retry push (single-push dedup, AC-29/AC-30).
		_pending_stat_push = false
		_defer_one_shot(_drain_pending_queue)
	elif _pending_stat_push:
		_pending_stat_push = false
		_defer_one_shot(_push_aggregate)


## FIFO drain of the durable suspended queue — batch semantics: N records ⇒
## one push + one flush (EC-22/AC-29), then the durable mirror clears.
func _drain_pending_queue() -> void:
	var queue: Array = _pending_queue.duplicate()
	_pending_queue.clear()
	_batch_depth += 1
	for record_dict: Variant in queue:
		if record_dict is Dictionary:
			receive_loot(LootDrop.from_dict(record_dict))
	_batch_depth -= 1
	_batch_push_pending = false
	_batch_flush_pending = false
	# Unconditional: the drain owns the post-resume aggregate (covers the boot
	# replay / rejection retry the handler folded into this drain).
	_push_aggregate()
	_flush_state()
	_persistence_write_pending_queue()


## EC-14: a rejected equipment push is never fire-and-forget — flag and retry
## after GSM Ready (loadout and #11 must never desync). Source-filtered:
## #17 is the only EQUIPMENT caller.
func _on_stat_mutation_rejected(_stat_id: StringName, source: int, _delta: float, _reason: String) -> void:
	if source != _StatSystemScript.StatSource.EQUIPMENT:
		return
	_pending_stat_push = true


## Contract 5 preferred idiom (process_frame ONE_SHOT; call_deferred flagged).
func _defer_one_shot(callable: Callable) -> void:
	if is_inside_tree():
		get_tree().process_frame.connect(callable, CONNECT_ONE_SHOT)
	else:
		callable.call()


## EC-15 (Story 016): re-entrant mutation attempt — loud error + deferred retry.
func _reentrancy_defer(retry: Callable) -> void:
	push_error("[InventorySystem] re-entrant mutation blocked (EC-15) — deferred one frame")
	_emit_telemetry("inventory.reentrancy.blocked", {})
	_defer_one_shot(retry)


# ── Cosmetic dupe detection (Rule 11 — Story 012) ──────────────────────────────


## True when a live cosmetic item with this visual id is already owned (any
## lifecycle state). Empty visual id never matches (functional items).
func _owns_cosmetic_visual(visual_id: String) -> bool:
	if visual_id.is_empty():
		return false
	for item_id: StringName in _items:
		var item: EquipmentItem = _items[item_id]
		if item.is_cosmetic and item.visual_id == visual_id:
			return true
	return false


# ── Salvage (Rule 9 — Story 010) ───────────────────────────────────────────────


## Manual salvage — single batch transaction (Pass 3 ordering): ALL in-memory
## mutations (unequip + SALVAGED + shard credit + tombstone + backfill) complete
## first, then ONE final-aggregate #11 push, then one persist write (Story 013).
## Locked items refuse (Rule 7); EQUIPPED items auto-unequip inside the batch
## (EC-13). Returns {ok, shards} or {ok: false, error}.
func salvage(item_id: StringName) -> Dictionary:
	if _mutating:
		_reentrancy_defer(func() -> void: salvage(item_id))
		return {"ok": false, "error": "deferred_reentrancy"}
	var item: EquipmentItem = _items.get(item_id, null)
	if item == null or item.lifecycle_state == EquipmentEnums.ItemLifecycle.SALVAGED:
		return {"ok": false, "error": "not_found"}
	if item.is_locked:
		return {"ok": false, "error": "locked"}
	_mutating = true

	var was_equipped: bool = \
		item.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED
	var slot: int = item.slot_affinity

	# Batch (in-memory, single commit unit — EC-19):
	if was_equipped:
		_loadout[slot] = &""
	var yield_shards: int = salvage_yield(item.rarity)
	_forge_shards += yield_shards
	_items.erase(item_id)
	register_tombstone(item_id)
	if was_equipped:
		_backfill_slot(slot)  # Rule 6 trigger: salvage-induced unequip

	# Push LAST (Rule 6 discipline) — only loadout changes need a re-push.
	if was_equipped:
		_push_aggregate()
	_mutating = false
	_mark_dirty_and_flush()  # one write for the whole transaction (EC-19)
	return {"ok": true, "shards": yield_shards}


## Bulk-salvage every UNLOCKED item of `rarity` (locked absolutely excluded —
## no bypass parameter, Rule 9). One transaction: one push at most, one write.
## Mailbox + inventory + equipped items of the rarity are all in range
## (equipped unlock-state items unequip inside the batch).
func bulk_salvage(rarity: int) -> Dictionary:
	if _mutating:
		_reentrancy_defer(func() -> void: bulk_salvage(rarity))
		return {"ok": false, "error": "deferred_reentrancy"}
	_mutating = true
	var to_salvage: Array[EquipmentItem] = []
	for item_id: StringName in _items:
		var item: EquipmentItem = _items[item_id]
		if item.rarity != rarity or item.is_locked:
			continue
		if item.lifecycle_state == EquipmentEnums.ItemLifecycle.SALVAGED:
			continue
		to_salvage.append(item)

	var total_shards: int = 0
	var touched_loadout: bool = false
	var emptied_slots: Array[int] = []
	for item: EquipmentItem in to_salvage:
		if item.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED:
			_loadout[item.slot_affinity] = &""
			touched_loadout = true
			emptied_slots.append(item.slot_affinity)
		total_shards += salvage_yield(item.rarity)
		_items.erase(item.item_id)
		register_tombstone(item.item_id)
	_forge_shards += total_shards
	for slot: int in emptied_slots:
		_backfill_slot(slot)
	if touched_loadout:
		_push_aggregate()
	_mutating = false
	_mark_dirty_and_flush()  # one write for the whole bulk transaction
	return {"ok": true, "count": to_salvage.size(), "shards": total_shards}


## Preview for the #23 confirm dialog (Pass 3 ownership: #17 provides the
## counts, #23 renders the receipt warning). No mutation.
## `receipt_ids` (G-IU-1 additive, #23 story 003): the receipt-bearing ids in
## bulk range, collected INSIDE the selection loop — 誠實名單同毀滅名單同源,
## #23 零 predicate duplicate (#23 Rule 16 ① itemised receipt list)。
func bulk_salvage_preview(rarity: int) -> Dictionary:
	var count: int = 0
	var total_shards: int = 0
	var receipt_count: int = 0
	var receipt_ids: Array[StringName] = []
	for item_id: StringName in _items:
		var item: EquipmentItem = _items[item_id]
		if item.rarity != rarity or item.is_locked:
			continue
		count += 1
		total_shards += salvage_yield(item.rarity)
		if item.has_receipt():
			receipt_count += 1
			receipt_ids.append(item.item_id)
	return {
		"count": count,
		"yield": total_shards,
		"receipt_count": receipt_count,
		"receipt_ids": receipt_ids,
	}


## Economy config assertion (Story 010): salvage curve must stay monotonic —
## per-tier ±50% knob ranges can otherwise invert tiers (rarer salvages for
## less = player-visible absurdity). Boot calls this (Story 014); design-by-
## contract assert pattern (LootRarityConfig precedent).
static func assert_salvage_curve_monotonic() -> void:
	for tier: int in range(RARITY_SHARD_MULT.size() - 1):
		assert(salvage_yield(tier + 1) > salvage_yield(tier),
			"salvage_yield must be strictly increasing across tiers (INV: monotonic)")


# ── Manual override (Rule 7 — Story 011) ───────────────────────────────────────


## Manual equip (#22 command sink). NOT score-gated — the player may equip a
## weaker item (their avatar, their call). BUT an unlocked manual choice will be
## displaced by the next auto-equip trigger (by design: lock IS the "respect my
## choice" mechanism — #22 must surface the lock affordance, forward flag).
func equip(item_id: StringName, slot: int) -> Dictionary:
	var item: EquipmentItem = _items.get(item_id, null)
	if item == null or item.lifecycle_state == EquipmentEnums.ItemLifecycle.SALVAGED:
		return {"ok": false, "error": "not_found"}
	if item.lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		return {"ok": false, "error": "in_mailbox_claim_first"}
	if item.slot_affinity != slot:
		return {"ok": false, "error": "slot_type_mismatch"}
	if _mutating:
		_reentrancy_defer(func() -> void: equip(item_id, slot))
		return {"ok": false, "error": "deferred_reentrancy"}
	_mutating = true
	_swap_into_slot(slot, item)
	_push_aggregate()
	_mutating = false
	_mark_dirty_and_flush()
	return {"ok": true}


## Manual unequip (#22 command sink): occupant → IN_INVENTORY + re-push.
func unequip(slot: int) -> Dictionary:
	var current: EquipmentItem = _equipped_item_in_slot(slot)
	if current == null:
		return {"ok": false, "error": "slot_empty"}
	if _mutating:
		_reentrancy_defer(func() -> void: unequip(slot))
		return {"ok": false, "error": "deferred_reentrancy"}
	_mutating = true
	current.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	_loadout[slot] = &""
	_push_aggregate()
	_mutating = false
	_mark_dirty_and_flush()
	return {"ok": true}


## Item-level lock (Pass 1 unified — NOT slot-level). Locked items freeze their
## slot against auto-equip and are immune to MANUAL + BULK salvage paths.
## (G-IU-3 (f) 2026-06-08 收窄: TTL sweep + hard-cap evict 唔理 is_locked —
## 嗰兩個 path 只豁免 receipt 件;lock 擋 bulk 唔擋 sweep,#23 Rule 12 honest
## copy 同一 ground truth。) Persisted.
func set_lock(item_id: StringName, locked: bool) -> Dictionary:
	var item: EquipmentItem = _items.get(item_id, null)
	if item == null:
		return {"ok": false, "error": "not_found"}
	item.is_locked = locked
	_mark_dirty_and_flush()
	return {"ok": true}


# ── Mailbox claim (Rule 3 / EC-10 — Story 004) ─────────────────────────────────


## Claim a mailbox item into the inventory. Blocked while the inventory is full
## (EC-10 — claim never over-admits): returns {ok: false, shortfall: N} where N
## is the number of slots the player must free (#23 surfaces "先騰 N 個位" +
## bulk-salvage shortcut — SUPERSEDED note G-IU-3 (e) 2026-06-08: 已兌現,#23
## MAKE_ROOM 入口 (a)「批量分解」→ BULK_SELECT,story 009). On success the item
## enters IN_INVENTORY and an auto-equip evaluation runs (Rule 6 trigger set: claim 後).
func claim(item_id: StringName) -> Dictionary:
	var item: EquipmentItem = _items.get(item_id, null)
	if item == null or item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		return {"ok": false, "shortfall": 0, "error": "not_in_mailbox"}
	var inventory_count: int = get_inventory_count()
	if inventory_count >= MAX_INVENTORY:
		return {"ok": false, "shortfall": inventory_count - MAX_INVENTORY + 1}
	if _mutating:
		_reentrancy_defer(func() -> void: claim(item_id))
		return {"ok": false, "shortfall": 0, "error": "deferred_reentrancy"}
	_mutating = true
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	_evaluate_auto_equip(item)
	_mutating = false
	_mark_dirty_and_flush()
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
	# Batch contexts coalesce: N receives in a drain/boot ⇒ one end-of-batch
	# push (EC-22 / AC-29 — same gate as _mark_dirty_and_flush).
	if _batch_depth > 0:
		_batch_push_pending = true
		return
	var raw: Dictionary = _compute_raw_aggregate()
	var effective: Dictionary = EquipmentClampCalc.clamp_aggregate(raw, _stat_derived_atk())
	var raw_atk: float = float(raw.get(&"attack_power", 0.0))
	var effective_atk: float = float(effective.get(&"attack_power", 0.0))
	if raw_atk > effective_atk:
		_emit_telemetry("equipment.antisnowball.clamp", {
			"raw_atk": raw_atk, "effective_atk": effective_atk,
		})
	if _stat_system == null:
		return
	var modifier = _StatSystemScript.StatModifier.new()
	modifier.deltas = effective
	_stat_system.apply_equipment_modifier(&"equipment_aggregate", modifier)
	# Rejection retry: _on_stat_mutation_rejected (wired in _ready, Story 015)
	# flags _pending_stat_push; the GSM Ready handler re-pushes deferred.


## #22 badge data contract (EC-16 / AC-38): current raw vs effective ATK.
func get_aggregate_raw_and_effective() -> Dictionary:
	var raw: Dictionary = _compute_raw_aggregate()
	var effective: Dictionary = _compute_effective_aggregate()
	return {
		"raw": float(raw.get(&"attack_power", 0.0)),
		"effective": float(effective.get(&"attack_power", 0.0)),
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


## Count of owned non-mailbox items (IN_INVENTORY + EQUIPPED — Rule 3: the cap
## counts everything the player holds EXCEPT mailbox parking; an unequip must
## never burst the cap).
func get_inventory_count() -> int:
	var count: int = 0
	for item_id: StringName in _items:
		var state: int = _items[item_id].lifecycle_state
		if state == EquipmentEnums.ItemLifecycle.IN_INVENTORY \
				or state == EquipmentEnums.ItemLifecycle.EQUIPPED:
			count += 1
	return count


## Current forge_shard balance (int64; #22/#23 shared display contract:
## thousands separators — format_shards below, G-IU-5).
func get_forge_shards() -> int:
	return _forge_shards


## Shards 顯示 formatter(D6 — 全 game 統一;G-IU-5)。千位逗號 lossless
##(「禁 K/M」原意 = 禁 lossy abbreviation;千位逗號係真賬簿文法)。
## **#22/#23 shared contract** — 兩邊全部 shards 顯示位行呢一個 static。
static func format_shards(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if negative else out


## Fetch a live item by id (null when absent / salvaged).
## NOTE (#22 Rule 14): returns the LIVE domain object, not a copy — callers are
## read-only-by-discipline (all writes via equip/unequip/set_lock/salvage).
func get_item(item_id: StringName) -> EquipmentItem:
	return _items.get(item_id, null)


## ---- G-CS-1 additive read getters (#22 story 010;GDD L127 兌現) ----

## Loadout snapshot — slot → item_id COPY (caller mutation 唔掂 internal _loadout)。
## Caller: #22 loadout panel (Rule 13 render + Rule 23 visibility re-read)。
func get_loadout() -> Dictionary:
	return _loadout.duplicate()


## Slot-filtered enumeration:IN_INVENTORY 且 slot_affinity == slot 嘅 item_ids。
## 排序由 caller 做(#22 F3 picker comparator — 方向 intentionally 異於
## 內部 _candidate_beats;呢度零 ordering 承諾)。Cosmetic slot → cosmetic-only
## 由 slot_affinity 1:1 mapping 自然成立。
## Caller: #22 SLOT_PICKER (Rule 17 / AC-31)。
func get_items_for_slot(slot: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for item_id: StringName in _items:
		var item: EquipmentItem = _items[item_id]
		if item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_INVENTORY:
			continue
		if int(item.slot_affinity) != slot:
			continue
		out.append(item_id)
	return out


## ---- G-IU-1 additive read getters (#23 story 003;GDD inventory-ui.md Rule 5/8) ----

## Full owned enumeration:IN_INVENTORY + EQUIPPED item_ids — 口徑 =
## `get_inventory_count`(cap 數乜佢列乜;#23 Rule 5/8「倉房口徑」由 getter
## 直接兌現,#23 唔做 loadout merge)。Copy 語意;零 ordering 承諾(F3 sort
## 由 #23 做)。Caller: #23 INVENTORY section(Rule 5 first-frame sync read)。
func get_all_inventory_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for item_id: StringName in _items:
		var state: int = _items[item_id].lifecycle_state
		if state == EquipmentEnums.ItemLifecycle.IN_INVENTORY \
				or state == EquipmentEnums.ItemLifecycle.EQUIPPED:
			out.append(item_id)
	return out


## Mailbox enumeration:IN_MAILBOX item_ids。Copy 語意;零 ordering 承諾
## (F2-M acquired-asc sort 由 #23 做)。
## Caller: #23 MAILBOX section(Rule 5 sync read / Rule 10)。
func get_mailbox_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for item_id: StringName in _items:
		if _items[item_id].lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX:
			out.append(item_id)
	return out
