## #22 Character Screen — ARIA + audio assertions (story 019:GDD AC-41/42/54 + 45a)。
## AC-42 紀律:positive control 先行(同一 spy instance — 防 spy 冇接線 phantom-pass)。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/character_screen_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")
const F := preload("res://src/ui/character_screen/char_screen_formulas.gd")

const SRC_EQUIPMENT: int = 2


class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = 2
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


class MockStat:
	extends Node
	signal stat_changed(stat_id, old_value, new_value, source, meta)
	var values: Dictionary = {
		&"str": 47.0, &"dex": 31.0, &"vit": 38.0,
		&"max_hp": 1240.0, &"attack_power": 84.0,
		&"move_speed": 210.0, &"crit_chance": 0.07,
	}
	func get_stat(stat_id: StringName) -> float:
		return values.get(stat_id, 0.0)
	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)
	func emit_equipment(stat_id: StringName, old_v: float, new_v: float) -> void:
		values[stat_id] = new_v
		stat_changed.emit(stat_id, old_v, new_v, SRC_EQUIPMENT, null)


class MockAvatar:
	extends Node
	signal avatar_visual_updated(visual_state)
	var posture: StringName = &"STRIKE"
	var tier: int = 3
	func get_visual_state() -> Dictionary:
		return {"class_posture": posture, "evolution_tier": tier}
	func get_class_posture() -> StringName:
		return posture
	func get_evolution_tier() -> int:
		return tier
	func is_ready_for_milestone_check() -> bool:
		return false
	func get_animation_state() -> StringName:
		return &"idle"


class MockPlatform:
	extends Node
	var announcements: Array = []
	func announce_aria(text: String) -> void:
		announcements.append(text)


class MockAudio:
	extends Node
	var sfx_calls: Array = []
	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


## Group F 用 thin fake #17(真 #17 coverage 喺 commands suite)。
class FakeItem:
	extends RefCounted
	var is_locked: bool = false
	var rarity: int = 2
	var provenance_text: String = "拾於 6月3日"
	var lifecycle_state: int = 1
	var source_receipt = null
	var stat_modifiers: Dictionary = {}


class FakeInventory:
	extends Node
	var item := FakeItem.new()
	func equip(_id: StringName, _slot: int) -> Dictionary:
		return {"ok": true}
	func salvage(_id: StringName) -> Dictionary:
		return {"ok": true, "shards": 200}
	func get_item(_id: StringName):
		return item
	func get_loadout() -> Dictionary:
		return {0: &"sword_a", 1: &"", 2: &"", 3: &""}
	func get_items_for_slot(_slot: int) -> Array[StringName]:
		return []
	func get_aggregate_raw_and_effective() -> Dictionary:
		return {"raw": 10.0, "effective": 10.0}
	func get_forge_shards() -> int:
		return 0
	func salvage_yield(_r: int) -> int:
		return 200


var _sut = null
var _gsm: MockGSM
var _stat: MockStat
var _avatar: MockAvatar
var _platform: MockPlatform
var _audio: MockAudio
var _inv: FakeInventory


func before_each() -> void:
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_stat = MockStat.new()
	add_child_autofree(_stat)
	_avatar = MockAvatar.new()
	add_child_autofree(_avatar)
	_platform = MockPlatform.new()
	add_child_autofree(_platform)
	_audio = MockAudio.new()
	add_child_autofree(_audio)
	_inv = FakeInventory.new()
	add_child_autofree(_inv)
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_sut._gsm = _gsm
	_sut._stat_system = _stat
	_sut._avatar = _avatar
	_sut._platform = _platform
	_sut._audio = _audio
	_sut._inventory = _inv
	_sut._persistence = MockPersistenceLayer.new()
	_sut._date_provider = func() -> String: return "6月7日"


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)


## ============ AC-41 — avatar coalesce + settings announce ============

func test_ac41_avatar_significant_change_announces_once() -> void:
	_open()
	_avatar.posture = &"CONTROL"
	_avatar.tier = 4
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	var hits: Array = _platform.announcements.filter(func(a): return a.begins_with("Avatar"))
	assert_eq(hits, ["Avatar 變為 CONTROL T4"], "恰好一次")


func test_ac41_window_coalesces_to_last() -> void:
	_open()
	_avatar.posture = &"CONTROL"
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())
	_avatar.tier = 4
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())  # window 內第二次
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	var hits: Array = _platform.announcements.filter(func(a): return a.begins_with("Avatar"))
	assert_eq(hits.size(), 1, "window 內多次 → 只最後一條")
	assert_eq(hits[0], "Avatar 變為 CONTROL T4")


func test_ac41_non_significant_silent() -> void:
	_open()
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())  # same posture+tier
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	var hits: Array = _platform.announcements.filter(func(a): return a.begins_with("Avatar"))
	assert_eq(hits.size(), 0, "非 significant → 零 announce")


func test_ac41_keyboard_hold_at_clamp_coalesces() -> void:
	_open()
	for i in range(20):
		_sut.slider_keyboard_step(1)  # 100 clamp hold ×20
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	var hits: Array = _platform.announcements.filter(func(a): return a == "100%")
	assert_eq(hits.size(), 1, "EC-28:announce 1 次後 window 內 coalesce — 唔 spam ×20")


func test_ac41_slider_settle_announces_pct_once() -> void:
	_open()
	_sut.slider_drag(0.68)
	_sut.advance(16.0)
	_sut.slider_release()
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	var hits: Array = _platform.announcements.filter(func(a): return a == "68%")
	assert_eq(hits.size(), 1)


## ============ AC-42 — settle SFX coalesce(positive control 先行)============

func test_ac42_positive_then_negative_sfx_discipline() -> void:
	_open()
	# POSITIVE CONTROL(同一 spy):open cue 已 fire
	assert_eq(_audio.sfx_calls, [&"ui_charscreen_open"], "positive:open cue 接咗線")
	# 4-row 並行 EQUIPMENT push → settle 恰好 1 響
	_stat.emit_equipment(&"max_hp", 1240.0, 1310.0)
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	_stat.emit_equipment(&"move_speed", 210.0, 220.0)
	_stat.emit_equipment(&"crit_chance", 0.07, 0.09)
	_sut.advance(300.0)
	var settles: Array = _audio.sfx_calls.filter(func(c): return c == &"ui_equip_settle")
	assert_eq(settles.size(), 1, "4-row settle-frame coalesce = 恰好 1 響(唔係 4)")
	# NEGATIVE(silent 名單):tab switch / banner / nudge 出現 — 零新 SFX
	var count_before: int = _audio.sfx_calls.size()
	_sut.set_active_panel(CoordinatorScript.PanelKind.LOADOUT)
	_sut.set_active_panel(CoordinatorScript.PanelKind.STATS)
	assert_eq(_audio.sfx_calls.size(), count_before, "tab switch silent")
	# player close cue(positive 收尾)
	_sut.close()
	assert_eq(_audio.sfx_calls[-1], &"ui_charscreen_close")


func test_ac42_retarget_merge_shares_one_settle() -> void:
	_open()
	_audio.sfx_calls.clear()
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	_sut.advance(150.0)
	_stat.emit_equipment(&"attack_power", 90.0, 95.0)  # retarget merge(兩 command)
	_sut.advance(300.0)
	var settles: Array = _audio.sfx_calls.filter(func(c): return c == &"ui_equip_settle")
	assert_eq(settles.size(), 1, "retarget merge 共一響(「最多 1」滿足 — audio R2)")


## ============ AC-54 — command-result announces(Rule 32)============

func test_ac54_equip_announce() -> void:
	_open()
	_sut.equip_item(&"sword_a", 0)
	assert_has(_platform.announcements, "已裝備 sword_a")


func test_ac54_salvage_announce() -> void:
	_open()
	_sut.request_salvage(&"sword_a")
	_sut.confirm_salvage()
	assert_has(_platform.announcements, "已分解 sword_a — +200 碎片")


func test_ac54_settle_coalesced_stat_announce() -> void:
	_open()
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	_stat.emit_equipment(&"max_hp", 1240.0, 1310.0)
	_sut.advance(300.0)
	var hits: Array = _platform.announcements.filter(func(a): return "→" in a)
	assert_eq(hits.size(), 1, "settle 一刻一條 coalesced message")
	assert_true("attack_power 84→90" in hits[0], "只列有變 row,from→to")
	assert_true("max_hp 1240→1310" in hits[0])


## ============ AC-45a — tap target guard ============

func test_ac45a_tap_target_floor_guard() -> void:
	assert_eq(F.MIN_TAP_TARGET_PX, 48)
	assert_eq(F.clamp_tap_target(30), 48, "永不細過 48px")
	assert_eq(F.clamp_tap_target(56), 56)
