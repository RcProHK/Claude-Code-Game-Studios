# Tween Spike — #20 Gym-Mode HUD R7 BLOCKING resolution (CD binding ruling)
#
# Paper review (R2..R7) 連續 7 輪喺 EC-F4 tween handle-map + circuit-breaker 揭新 phantom。
# CD 裁定: 停 paper review,用 headless GUT spike 實測 Godot 4.6 tween runtime behavior,
# 由實測反向 author EC-F4 / F8 / AC-EC-F4b spec。
#
# 本 spike 回答 5 條 paper-irreducible BLOCKING:
#   B2 — kill() 會唔會 emit finished? (kill path 需唔需要獨立 erase code path)
#   B3 — _restart_count++ ordering (kill→create sequence 邊一步 ++)
#   B4 — AC-EC-F4b off-by-one (create 算唔算第 1 個 kill-restart; snap 喺第幾個 event)
#   B5 — _on_tween_finished 對 empty/stale handle 嘅行為
#   B6 — F5 stale-reference: identity guard 需唔需要 src_tween param (vs F8 single-stat_id seam)
#
# Throwaway spike — 唔入 src/,唔係 production code。結果寫入 SPIKE-FINDINGS.md。

extends GutTest


# ---------------------------------------------------------------------------
# 一個 minimal tween target (headless 可 interpolate 一個 float property)
# ---------------------------------------------------------------------------
class TweenTarget:
	extends Node
	var value: float = 0.0


# ===========================================================================
# PART A — RAW ENGINE BEHAVIOR PROBES (paper 無法裁決,必須實測)
# ===========================================================================

# --- A1 [B2 foundation] kill() 會唔會 emit finished? ---
var _a1_finished_fired: int = 0

func _a1_on_finished() -> void:
	_a1_finished_fired += 1

func test_A1_kill_does_not_emit_finished() -> void:
	var target := TweenTarget.new()
	add_child_autofree(target)
	_a1_finished_fired = 0

	var t := create_tween()
	t.tween_property(target, "value", 1.0, 0.5)  # 0.5s tween
	t.finished.connect(_a1_on_finished)

	await get_tree().process_frame
	t.kill()
	# 俾幾幀去確認 finished 永不喺 kill 後 fire
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_a1_finished_fired, 0,
		"B2: kill() 之後 finished 永不 emit → kill path 必須有獨立 erase,唔可靠 _on_tween_finished")


# --- A2 [B2 foundation] 自然完成會 emit finished (對照組) ---
var _a2_finished_fired: int = 0

func _a2_on_finished() -> void:
	_a2_finished_fired += 1

func test_A2_natural_completion_emits_finished() -> void:
	var target := TweenTarget.new()
	add_child_autofree(target)
	_a2_finished_fired = 0

	var t := create_tween()
	t.tween_property(target, "value", 1.0, 0.02)  # 極短,自然完成
	t.finished.connect(_a2_on_finished)

	# await 足夠幀數令 0.02s tween 自然完成
	for i in 10:
		await get_tree().process_frame

	assert_eq(_a2_finished_fired, 1,
		"B2 對照: 自然完成 emit finished 剛好一次 → lifecycle ③ (finished→reset) 只行於自然完成路徑")


# --- A3 [B6 foundation] kill() 之後 tween.is_valid() 行為 ---
func test_A3_tween_validity_after_kill() -> void:
	var target := TweenTarget.new()
	add_child_autofree(target)

	var t := create_tween()
	t.tween_property(target, "value", 1.0, 0.5)
	await get_tree().process_frame

	var valid_before := t.is_valid()
	t.kill()
	var valid_after := t.is_valid()

	assert_true(valid_before, "B6: kill 前 tween is_valid()==true")
	assert_false(valid_after,
		"B6: kill() 後 is_valid()==false → is_valid() 可做 stale guard 之一,但 identity (==) 仍需 src_tween 區分新舊")


# --- A4 [B6 foundation] bound callable arg order: finished(0 args) + .bind(stat_id, tween) ---
var _a4_received_stat: StringName = &""
var _a4_received_tween_matches: bool = false

func _a4_on_finished(stat_id: StringName, src_tween: Tween) -> void:
	_a4_received_stat = stat_id
	_a4_received_tween_matches = (src_tween != null)

func test_A4_bound_callable_arg_order() -> void:
	var target := TweenTarget.new()
	add_child_autofree(target)
	_a4_received_stat = &""
	_a4_received_tween_matches = false

	var t := create_tween()
	t.tween_property(target, "value", 1.0, 0.02)
	t.finished.connect(_a4_on_finished.bind(&"hp", t))

	for i in 10:
		await get_tree().process_frame

	assert_eq(_a4_received_stat, &"hp",
		"B6/F8: finished() (0 args) + .bind(stat_id, tween) → callback 收到 (stat_id, src_tween);bound args 喺尾,signal 0 args 故位置正確")
	assert_true(_a4_received_tween_matches,
		"B6/F8: src_tween 成功經 bind 傳入 → 2-param seam (_on_tween_finished(stat_id, src_tween)) 可行;F8 single-stat_id mandate 不足以做 identity guard")


# ===========================================================================
# PART B — REFERENCE HANDLE-MAP IMPL (authoritative spec via assertion)
# ===========================================================================
#
# 呢個 inner class = EC-F4 tween handle-map 嘅 reference 實作。
# 所有 ordering / off-by-one / identity 行為由斷言鎖死,之後反向 author 入 GDD。

class HudTweenManager:
	extends RefCounted

	const MAX_RESTART := 5  # = max_tween_restart_count

	var _host: Node
	var _target: Node
	var _active_tweens: Dictionary = {}   # stat_id -> Tween  (F5 handle-map)
	var _restart_count: Dictionary = {}   # stat_id -> int    (F9 seam)
	var _active_tween_count: int = 0      # AC-CR-2 counter seam
	var snap_events: Array = []           # 記錄 snap 觸發時嘅 event index (B4 snap-index)
	var _event_index: Dictionary = {}     # stat_id -> 累計 event 次數 (測試用)
	var reduce_motion: bool = false

	func _init(host: Node, target: Node) -> void:
		_host = host
		_target = target

	# --- public: 模擬一個 stat_changed(stat_id, target_value) ---
	func on_stat_changed(stat_id: StringName, target_value: float) -> void:
		_event_index[stat_id] = _event_index.get(stat_id, 0) + 1

		if reduce_motion:
			# F2 instant set,從不 ++ counter
			_set_immediate(stat_id, target_value)
			return

		if _active_tweens.has(stat_id):
			# === kill-restart path ===
			# B3 裁定: _restart_count++ 喺 kill-restart branch 最頭,先於 cap-check
			_restart_count[stat_id] = _restart_count.get(stat_id, 0) + 1
			if _restart_count[stat_id] >= MAX_RESTART:
				# === circuit breaker: snap ===
				_kill(stat_id)
				_set_immediate(stat_id, target_value)
				_restart_count[stat_id] = 0
				snap_events.append(_event_index[stat_id])  # 記錄 snap 喺第幾個 event
				return
			_kill(stat_id)
			_create(stat_id, target_value)
		else:
			# === first event: create (唔算 kill-restart,_restart_count 不 ++) ===
			_create(stat_id, target_value)

	# --- kill path: 獨立 erase (B2 — 唔靠 finished) ---
	func _kill(stat_id: StringName) -> void:
		var t: Tween = _active_tweens.get(stat_id)
		if t != null and t.is_valid():
			t.kill()
		if _active_tweens.has(stat_id):
			_active_tweens.erase(stat_id)
			_active_tween_count = maxi(_active_tween_count - 1, 0)

	func _create(stat_id: StringName, target_value: float) -> void:
		var t := _host.create_tween()
		t.tween_property(_target, "value", target_value, 0.5)
		# F8: 具名 callback + 2-param seam (stat_id + src_tween 做 identity guard)
		t.finished.connect(_on_tween_finished.bind(stat_id, t))
		_active_tweens[stat_id] = t
		_active_tween_count += 1

	func _set_immediate(stat_id: StringName, target_value: float) -> void:
		# snap = 直接 set,唔創 tween (不 ++ counter)
		_target.set("value", target_value)

	# --- F8 seam: 2-param 具名 callback + B6 identity guard ---
	func _on_tween_finished(stat_id: StringName, src_tween: Tween) -> void:
		# B6 identity guard: 只有當前 live tween 自然完成先處理
		if _active_tweens.get(stat_id) != src_tween:
			return  # stale (舊 tween 殘響 / 已被 restart 取代) → no-op
		# B5: 自然完成路徑
		_active_tweens.erase(stat_id)
		_active_tween_count = maxi(_active_tween_count - 1, 0)
		_restart_count[stat_id] = 0  # lifecycle ③

	# --- F9 seam: test inspect ---
	func get_restart_count(stat_id: StringName) -> int:
		return _restart_count.get(stat_id, 0)


var _mgr: HudTweenManager
var _target: TweenTarget

func before_each() -> void:
	_target = TweenTarget.new()
	add_child_autofree(_target)
	_mgr = HudTweenManager.new(self, _target)


# --- B-invariant: _active_tween_count == _active_tweens.size() 全程成立 ---
func _assert_invariant(ctx: String) -> void:
	assert_eq(_mgr._active_tween_count, _mgr._active_tweens.size(),
		"INVARIANT _active_tween_count == _active_tweens.size() (%s)" % ctx)


# --- B4 [off-by-one] create=第1個 event 唔算 restart; snap 喺第幾個 event? ---
func test_B4_snap_index_with_max_restart_5() -> void:
	# 連續注入同一 stat_id event,觀察 snap 喺第幾個
	for i in 8:
		_mgr.on_stat_changed(&"hp", float(i + 1))

	assert_eq(_mgr.snap_events.size() >= 1, true, "B4: 至少觸發一次 snap")
	# e1=create(rc=0), e2=rc1, e3=rc2, e4=rc3, e5=rc4, e6=rc5→SNAP
	assert_eq(_mgr.snap_events[0], 6,
		"B4: MAX_RESTART=5 時,snap 喺第 6 個 event (create 第1個唔算 restart;5 次 kill-restart 後第6個 event snap)。AC-EC-F4b 須寫『第 MAX_RESTART+1 個 event』唔係『第 MAX_RESTART 個』")


# --- B3 [ordering] snap 嗰刻 _restart_count 歸 0 ---
func test_B3_restart_count_reset_at_snap() -> void:
	for i in 6:
		_mgr.on_stat_changed(&"hp", float(i + 1))
	assert_eq(_mgr.get_restart_count(&"hp"), 0,
		"B3: snap 後 _restart_count[stat_id] 即時歸 0 (一次性 reset,非永久 snap-mode)")
	_assert_invariant("snap 後")


# --- B3 [ordering] snap 後 counter 歸零 (snap path 只 -- 唔 ++) ---
func test_B3_active_count_zero_after_snap() -> void:
	for i in 6:
		_mgr.on_stat_changed(&"hp", float(i + 1))
	assert_eq(_mgr._active_tween_count, 0,
		"B3: snap path = kill(--) + set_immediate(唔 ++) → _active_tween_count 歸 0,非 stuck 偏高")
	_assert_invariant("snap 後 count==0")


# --- B5 [empty handle] snap 後 call _on_tween_finished 係 no-op ---
func test_B5_on_tween_finished_on_empty_handle_is_noop() -> void:
	for i in 6:
		_mgr.on_stat_changed(&"hp", float(i + 1))
	# snap 已 erase _active_tweens[hp]。模擬一個 stale finished 殘響:
	var count_before := _mgr._active_tween_count
	_mgr._on_tween_finished(&"hp", null)  # empty handle (get 返 null,唔 match)
	assert_eq(_mgr._active_tween_count, count_before,
		"B5: _on_tween_finished 對 empty/stale handle → identity guard 提早 return,counter 不變 (no double-decrement)")
	_assert_invariant("stale finished 後")


# --- B6 [stale-reference] 舊 tween 殘響唔污染新 tween entry ---
func test_B6_stale_tween_finished_does_not_corrupt_new_entry() -> void:
	# e1: create tween A for hp
	_mgr.on_stat_changed(&"hp", 1.0)
	var tween_A: Tween = _mgr._active_tweens[&"hp"]
	# e2: kill A, create tween B for hp
	_mgr.on_stat_changed(&"hp", 2.0)
	var tween_B: Tween = _mgr._active_tweens[&"hp"]
	assert_ne(tween_A, tween_B, "B6 前置: restart 後係新 tween object")

	var count_before := _mgr._active_tween_count
	# 模擬 tween A (已 kill) 嘅 stale finished 殘響到達
	_mgr._on_tween_finished(&"hp", tween_A)
	assert_eq(_mgr._active_tween_count, count_before,
		"B6: stale tween A 嘅 finished → identity guard (_active_tweens[hp]==B≠A) 提早 return,唔錯誤 erase B")
	assert_true(_mgr._active_tweens.has(&"hp"),
		"B6: 新 tween B entry 完好,冇被 stale A 誤刪")
	_assert_invariant("stale A 殘響後")


# --- B2 [kill path] restart 全程 invariant 維持 (kill 有獨立 erase) ---
func test_B2_invariant_held_across_restart_burst() -> void:
	_assert_invariant("初始")
	_mgr.on_stat_changed(&"hp", 1.0)
	_assert_invariant("e1 create")
	_mgr.on_stat_changed(&"hp", 2.0)
	_assert_invariant("e2 restart")
	_mgr.on_stat_changed(&"hp", 3.0)
	_assert_invariant("e3 restart")
	# 多 stat_id 並存
	_mgr.on_stat_changed(&"exp", 5.0)
	_assert_invariant("exp create")
	assert_eq(_mgr._active_tween_count, 2, "B2: hp + exp 兩個 live tween")


# --- reduce_motion (F2): instant set 從不 ++,counter 不 drift 負 ---
func test_F2_reduce_motion_never_increments_counter() -> void:
	_mgr.reduce_motion = true
	for i in 5:
		_mgr.on_stat_changed(&"hp", float(i))
	assert_eq(_mgr._active_tween_count, 0,
		"F2/B9: reduce_motion instant set 從不創 tween,_active_tween_count 永遠 0")
	assert_true(_mgr._active_tween_count >= 0, "B9: counter 永不負")
	_assert_invariant("reduce_motion")


# --- reset-then-resume (B7 from R6): 自然 finished → reset → 下個 event 正常重啟 ---
func test_resume_after_natural_finish() -> void:
	# e1 create
	_mgr.on_stat_changed(&"hp", 1.0)
	var t: Tween = _mgr._active_tweens[&"hp"]
	# 模擬自然完成 (call seam,real finished 喺 headless timing 非 deterministic)
	_mgr._on_tween_finished(&"hp", t)
	assert_eq(_mgr._active_tween_count, 0, "自然完成後 counter 歸 0")
	assert_false(_mgr._active_tweens.has(&"hp"), "自然完成後 handle 清除")
	assert_eq(_mgr.get_restart_count(&"hp"), 0, "lifecycle ③: 自然完成 reset _restart_count")
	# 下個全新 event 應正常重啟 (唔係 snap-mode)
	_mgr.on_stat_changed(&"hp", 2.0)
	assert_eq(_mgr._active_tween_count, 1, "resume: 自然完成後新 event 正常重啟 tween")
	_assert_invariant("resume")
