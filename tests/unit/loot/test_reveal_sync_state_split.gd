extends GutTest
## Story 017 (G-LM-4a) — #15 revealed/sync state 分離 + ceremony kind 持久化 +
## ②b breakdown 載體。AC-71 ordering case 嘅 #15-side 基礎。
##
## GDD: design/gdd/loot-drop-modal.md G-LM-4 ①②②b / Rule 2 grep-verified 警告.

const LootSystemScript := preload("res://src/autoload/loot_drop_system.gd")


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String) -> Variant:
		return store.get(key)
	func write(key: String, value: Variant, _flush: bool = false) -> bool:
		store[key] = value
		return true
	func delete(key: String) -> bool:
		store.erase(key)
		return true
	func list_keys(prefix: String) -> Array:
		var out: Array = []
		for k: String in store.keys():
			if k.begins_with(prefix):
				out.append(k)
		return out
	func is_private_mode() -> bool:
		return false


var _persist: MockPersistence


func _make_system() -> Node:
	_persist = MockPersistence.new()
	var sys: Node = LootSystemScript.new()
	sys._persistence = _persist
	add_child_autofree(sys)
	return sys


func _grant(sys: Node, tid: String, ceremony: int, ws: float = 0.6) -> LootDrop:
	sys._process_loot_trigger(tid, LootEnums.SourceEventKind.MINI_BOSS, ws, ceremony)
	# sync-fallback persistence ⇒ the coroutine completes synchronously
	var drops: Dictionary = sys._drops_by_transition
	return drops.get(tid)


# --- ① ordering survival: backend ACK 先到、reveal 後到 ---

func test_backend_ack_never_evaporates_unrevealed_drop_from_reveal_queue() -> void:
	var sys: Node = _make_system()
	var drop: LootDrop = _grant(sys, "tid_order_1", LootEnums.CeremonyDecision.FULL_CEREMONY)
	assert_not_null(drop)
	assert_eq(sys.get_pending_drops().size(), 1, "reveal queue 有件")
	# Backend ACK 跑贏 reveal(秒級 vs 等 safe state):
	sys._on_backend_ack({"drop_id": drop.drop_id, "canonical_id": "canon_1"})
	assert_eq(sys.get_pending_drops().size(), 1, "件仍喺 reveal queue — ACK 永不蒸發未 reveal 件")
	assert_not_null(sys.get_drop(drop.drop_id), "get_drop 喺 ACK 後照搵到(reveal queue fallback)")
	# sync rename 照行:
	assert_true(_persist.store.has("loot.committed.canon_1"), "loot.pending → loot.committed rename 冇 skip")
	assert_false(_persist.store.has("loot.pending." + drop.drop_id), "pending key 已清")


# --- ② kind filter: micro_ack 件永不入 reveal queue ---

func test_micro_ack_records_never_enter_the_reveal_queue() -> void:
	var sys: Node = _make_system()
	_grant(sys, "tid_full", LootEnums.CeremonyDecision.FULL_CEREMONY)
	var micro: LootDrop = _grant(sys, "tid_micro", LootEnums.CeremonyDecision.MICRO_ACK)
	assert_eq(sys.get_pending_drops().size(), 1, "reveal flow 只見 FULL_CEREMONY 件")
	assert_eq(str((sys.get_pending_drops()[0] as LootDrop).transition_id), "tid_full")
	assert_not_null(sys.get_drop(micro.drop_id), "micro 件 get_drop 照搵到(Rule 9 banking 用)")
	assert_eq(micro.ceremony_kind, "MICRO_ACK", "kind 喺 record 上")


func test_ceremony_kind_is_in_the_persisted_snapshot() -> void:
	var sys: Node = _make_system()
	var drop: LootDrop = _grant(sys, "tid_persist", LootEnums.CeremonyDecision.MICRO_ACK)
	var on_disk: Dictionary = _persist.store["loot.pending." + drop.drop_id]
	assert_eq(str(on_disk["ceremony_kind"]), "MICRO_ACK", "kind set BEFORE the Step-3 persist snapshot")
	assert_false(bool(on_disk["revealed"]), "revealed default false")


# --- ②b breakdown 載體 ---

func test_grant_persists_ws_rr_score_on_the_record() -> void:
	var sys: Node = _make_system()
	var drop: LootDrop = _grant(sys, "tid_bd", LootEnums.CeremonyDecision.FULL_CEREMONY, 0.6)
	var meta: Dictionary = drop.item_metadata
	for key: String in ["workout_score", "rng_roll", "rarity_score"]:
		assert_true(meta.has(key), "pinned key %s 存在" % key)
	var identity: float = 0.75 * float(meta["workout_score"]) + 0.25 * float(meta["rng_roll"])
	assert_almost_eq(float(meta["rarity_score"]), identity, 0.0001,
		"identity 成立 — #21 F2 EC-M15 gate 直接食得(weights 讀 config,零印數)")


# --- migration: 舊 record 無新 fields → 安全 defaults ---

func test_legacy_record_migrates_with_safe_defaults() -> void:
	var legacy: Dictionary = {
		"payload_type": "LootDrop", "drop_id": "old_1", "transition_id": "t_old",
		"rarity_tier": "RARE", "item_type": "WEAPON", "class_tag": "NEUTRAL",
		"source_event_kind": "WORKOUT_DAILY", "created_at_unix": 1, "schema_version": 1,
		"item_metadata": {},
	}
	var drop := LootDrop.from_dict(legacy) as LootDrop
	assert_eq(drop.ceremony_kind, "FULL_CEREMONY", "migration default — celebrate-it safe")
	assert_false(drop.revealed, "unrevealed default")


# --- ① boot rehydrate filter ---

func test_boot_rehydrate_requeues_only_unrevealed_full_ceremony_records() -> void:
	var sys: Node = _make_system()
	var unrevealed := LootDrop.new()
	unrevealed.drop_id = "re_1"
	unrevealed.transition_id = "t_re1"
	unrevealed.ceremony_kind = "FULL_CEREMONY"
	unrevealed.revealed = false
	var revealed_unsynced := LootDrop.new()
	revealed_unsynced.drop_id = "re_2"
	revealed_unsynced.transition_id = "t_re2"
	revealed_unsynced.ceremony_kind = "FULL_CEREMONY"
	revealed_unsynced.revealed = true  # banked — sync-pending only
	var micro := LootDrop.new()
	micro.drop_id = "re_3"
	micro.transition_id = "t_re3"
	micro.ceremony_kind = "MICRO_ACK"
	for d: LootDrop in [unrevealed, revealed_unsynced, micro]:
		_persist.store["loot.pending." + d.drop_id] = d.to_dict()
	sys._restore_pending_drops()
	assert_eq(sys._pending_drops.size(), 3, "sync ledger 全收(ACK 等緊)")
	assert_eq(sys.get_pending_drops().size(), 1, "reveal queue 只收 unrevealed FULL")
	assert_eq(str((sys.get_pending_drops()[0] as LootDrop).drop_id), "re_1",
		"revealed-but-unsynced 永不 re-reveal(anti-flashbulb);micro 行 Rule 9")
