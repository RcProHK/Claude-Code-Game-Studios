## #22 Character Screen — data binding integration tests
## (story 009: GDD AC-21..24 + 53;story 014 加 loadout cases)。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/character_screen_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")

const SRC_EQUIPMENT: int = 2       # StatSource.EQUIPMENT
const SRC_VOLUME_TICK: int = 1     # 非 EQUIPMENT class
const SRC_INITIAL: int = 4         # StatSource.INITIAL_STATE


class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = 2  # IDLE
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


## #11 mock — get_stat 值表 + cfis sync burst ×7(真 layout)。
class MockStat:
	extends Node
	signal stat_changed(stat_id, old_value, new_value, source, meta)
	var values: Dictionary = {
		&"str": 47.0, &"dex": 31.0, &"vit": 38.0,
		&"max_hp": 1240.0, &"attack_power": 84.0,
		&"move_speed": 210.4, &"crit_chance": 0.07,
	}
	func get_stat(stat_id: StringName) -> float:
		return values.get(stat_id, 0.0)
	func connect_for_initial_state(callable: Callable) -> void:
		for id in values:
			var v: float = values[id]
			callable.callv([id, v, v, SRC_INITIAL, true])
		stat_changed.connect(callable)
	func emit_equipment(stat_id: StringName, old_v: float, new_v: float) -> void:
		values[stat_id] = new_v
		stat_changed.emit(stat_id, old_v, new_v, SRC_EQUIPMENT, null)
	func emit_reconciliation(stat_id: StringName, old_v: float, new_v: float) -> void:
		values[stat_id] = new_v
		stat_changed.emit(stat_id, old_v, new_v, SRC_VOLUME_TICK, null)


## #26 mock — 5 read-only getters + plain signal(CR-11 shape)。
class MockAvatar:
	extends Node
	signal avatar_visual_updated(visual_state)
	var posture: StringName = &"STRIKE"
	var tier: int = 3
	var milestone_ready: bool = false
	var anim: StringName = &"idle"
	func get_visual_state() -> Dictionary:
		return {"class_posture": posture, "evolution_tier": tier}
	func get_class_posture() -> StringName:
		return posture
	func get_evolution_tier() -> int:
		return tier
	func is_ready_for_milestone_check() -> bool:
		return milestone_ready
	func get_animation_state() -> StringName:
		return anim


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	var fail_writes: bool = false
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		if fail_writes:
			return false
		store[key] = value
		return true


var _sut = null
var _gsm: MockGSM
var _stat: MockStat
var _avatar: MockAvatar
var _persist: MockPersistence


func before_each() -> void:
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_stat = MockStat.new()
	add_child_autofree(_stat)
	_avatar = MockAvatar.new()
	add_child_autofree(_avatar)
	_persist = MockPersistence.new()
	_sut._gsm = _gsm
	_sut._stat_system = _stat
	_sut._avatar = _avatar
	_sut._persistence = _persist
	_sut._date_provider = func() -> String: return "1月12日"


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)


## ============ Rule 7 — open 第一 frame sync read 齊(AC-20 ungated 部分)============

func test_open_first_frame_reads_all_stats_and_avatar() -> void:
	_open()
	assert_eq(_sut.get_stat_display(&"str"), "47")
	assert_eq(_sut.get_stat_display(&"max_hp"), "1240")
	assert_eq(_sut.get_stat_display(&"move_speed"), "210")
	assert_eq(_sut.get_stat_display(&"crit_chance"), "7%")
	var view: Dictionary = _sut.get_avatar_view()
	assert_eq(view["class_posture"], &"STRIKE")
	assert_eq(view["evolution_tier"], 3)
	assert_eq(view["animation_state"], &"idle")
	assert_false(_sut.has_milestone_hint())


func test_cfis_burst_plus_sync_read_is_idempotent_ec02() -> void:
	# open 內 sync read 同 cfis burst 雙到(同 frame)— same-state 二次 render 無變化
	_open()
	assert_eq(_sut.get_stat_display(&"attack_power"), "84")
	assert_eq(_sut.get_stat_arrow(&"attack_power"), 0, "burst 係 INITIAL_STATE → snap,無 arrow")


## ============ AC-21 — EQUIPMENT tween/arrow vs 非 EQUIPMENT snap + interleave ============

func test_ac21_equipment_source_tweens_with_arrow() -> void:
	_open()
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	assert_eq(_sut.get_stat_arrow(&"attack_power"), 1)
	_sut.advance(150.0)
	assert_eq(_sut.get_stat_display(&"attack_power"), "89", "F1 golden:89.25→「89」")
	_sut.advance(150.0)
	assert_eq(_sut.get_stat_display(&"attack_power"), "90")


func test_ac21_non_equipment_snaps_no_arrow() -> void:
	_open()
	_stat.emit_reconciliation(&"attack_power", 84.0, 90.0)
	assert_eq(_sut.get_stat_display(&"attack_power"), "90", "即時 snap")
	assert_eq(_sut.get_stat_arrow(&"attack_power"), 0, "無 arrow — 補數唔演成升級")


func test_ac21_interleave_reconciliation_kills_equipment_tween() -> void:
	_open()
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	_sut.advance(100.0)  # tween 進行中
	_stat.emit_reconciliation(&"attack_power", 90.0, 87.0)  # DISCONNECTED reconnect class
	assert_eq(_sut.get_stat_display(&"attack_power"), "87", "kill + snap 到 v_target")
	assert_eq(_sut.get_stat_arrow(&"attack_power"), 0, "清 arrow(sd B-4)")


## ============ AC-22 — 4-row 並行 lockstep settle ============

func test_ac22_four_rows_parallel_constant_duration() -> void:
	_open()
	_stat.emit_equipment(&"max_hp", 1240.0, 1310.0)
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	_stat.emit_equipment(&"move_speed", 210.4, 220.0)
	_stat.emit_equipment(&"crit_chance", 0.07, 0.09)
	_sut.advance(150.0)
	# 4 row 並行,mid-tween 全部未到 target
	assert_eq(_sut.get_stat_display(&"attack_power"), "89")
	_sut.advance(150.0)
	# constant duration ⇒ 同時落定
	assert_eq(_sut.get_stat_display(&"max_hp"), "1310")
	assert_eq(_sut.get_stat_display(&"attack_power"), "90")
	assert_eq(_sut.get_stat_display(&"move_speed"), "220")
	assert_eq(_sut.get_stat_display(&"crit_chance"), "9%")


## ============ AC-23 — avatar view + milestone hint EC-16 ============

func test_ac23_milestone_hint_only_evaluated_on_open_and_signal() -> void:
	_open()
	assert_false(_sut.has_milestone_hint())
	# mid-session flip 而冇 signal → 唔追 real-time(EC-16;#26 冇 per-readiness signal)
	_avatar.milestone_ready = true
	assert_false(_sut.has_milestone_hint(), "flip 唔即時反映")
	# avatar_visual_updated 先 re-evaluate
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())
	assert_true(_sut.has_milestone_hint())


func test_ac23_avatar_signal_refreshes_view_idempotent() -> void:
	_open()
	_avatar.posture = &"CONTROL"
	_avatar.tier = 4
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())
	assert_eq(_sut.get_avatar_view()["class_posture"], &"CONTROL")
	assert_eq(_sut.get_avatar_view()["evolution_tier"], 4)
	# 同 state 再 emit — idempotent(EC-02)
	_avatar.avatar_visual_updated.emit(_avatar.get_visual_state())
	assert_eq(_sut.get_avatar_view()["class_posture"], &"CONTROL")


## ============ AC-24 — tab 切走切返 re-read + snap(EC-11)============

func test_ac24_tab_switch_back_rereads_and_kills_tween() -> void:
	_open()
	_stat.emit_equipment(&"attack_power", 84.0, 90.0)
	_sut.advance(100.0)  # mid-tween
	_sut.set_active_panel(CoordinatorScript.PanelKind.LOADOUT)
	# 切走期間值再變(cross-surface mutation class)
	_stat.values[&"attack_power"] = 95.0
	_sut.set_active_panel(CoordinatorScript.PanelKind.STATS)
	assert_eq(_sut.get_stat_display(&"attack_power"), "95", "re-read snap 到 true 值")
	assert_eq(_sut.get_stat_arrow(&"attack_power"), 0, "舊 tween kill 唔 resume")


## ============ AC-53 — breathing freeze(Rule 11)============

func test_ac53_persisted_reduce_motion_frozen_on_open() -> void:
	_persist.store["settings.reduce_camera_motion"] = true
	_open()
	assert_true(_sut.is_avatar_breathing_frozen(), "persisted true → open 即 frozen")


func test_ac53_flip_takes_effect_same_frame_and_recovers() -> void:
	_open()
	assert_false(_sut.is_avatar_breathing_frozen())
	_sut.set_reduce_motion(true)   # P-08 flip(同屏即場生效)
	assert_true(_sut.is_avatar_breathing_frozen())
	_sut.set_reduce_motion(false)  # OFF → breathing 恢復
	assert_false(_sut.is_avatar_breathing_frozen())


## ============ watermark 行(Rule 31 render 整合)============

func test_watermark_line_renders_after_divergence() -> void:
	_persist.store["charscreen.stat_watermark.str"] = {"value": 30.0, "date": "1月12日"}
	_open()  # str current = 47
	assert_eq(_sut.get_watermark_line(&"str"), "⌜1月12日:30⌟")


func test_watermark_line_suppressed_on_fresh_account() -> void:
	_open()  # 第一次 — watermark == current
	assert_eq(_sut.get_watermark_line(&"str"), "", "fmt 相等 → suppress 廢話行")


func test_watermark_persist_fail_renders_nothing() -> void:
	_persist.fail_writes = true
	_open()
	assert_eq(_sut.get_watermark_line(&"str"), "", "persist fail → 零 render 零 fabrication")
