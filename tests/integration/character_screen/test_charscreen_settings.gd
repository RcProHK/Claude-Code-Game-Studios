## #22 Character Screen — settings panel integration tests
## (story 018:GDD AC-35..40 + 52;mock #6 #7 #3 #4)。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/character_screen_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")


class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = 2
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func transition(to: int) -> void:
		var from: int = state
		state = to
		state_changed.emit(from, to, null)


class MockScreenEffects:
	extends Node
	var motion_calls: Array = []
	var preview_calls: int = 0
	func set_motion_intensity(v: float) -> void:
		motion_calls.append(v)
	func preview_hit_heavy() -> void:
		preview_calls += 1


class MockCamera:
	extends Node
	var reduction_calls: Array = []
	func set_motion_reduction(enabled: bool) -> void:
		reduction_calls.append(enabled)


class MockAudioVolume:
	extends Node
	var linear_calls: Array = []
	var sfx_calls: Array = []
	var current_linear: float = 1.0
	func set_bus_volume_linear(_bus: int, s: float) -> void:
		linear_calls.append(s)
		current_linear = s
	func get_bus_volume_linear(_bus: int) -> float:
		return current_linear
	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


class MockPersist:
	extends RefCounted
	var store: Dictionary = {}
	var writes: Array = []  # [{key, value, flush}]
	var fail_writes: bool = false
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, flush: bool = false) -> bool:
		writes.append({"key": key, "value": value, "flush": flush})
		if fail_writes:
			return false
		store[key] = value
		return true


var _sut = null
var _gsm: MockGSM
var _fx: MockScreenEffects
var _cam: MockCamera
var _audio: MockAudioVolume
var _persist: MockPersist


func before_each() -> void:
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_fx = MockScreenEffects.new()
	add_child_autofree(_fx)
	_cam = MockCamera.new()
	add_child_autofree(_cam)
	_audio = MockAudioVolume.new()
	add_child_autofree(_audio)
	_persist = MockPersist.new()
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_sut._gsm = _gsm
	_sut._screen_effects = _fx
	_sut._camera = _cam
	_sut._audio = _audio
	_sut._persistence = _persist


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)


func _count_persist_writes(key: String) -> int:
	var n: int = 0
	for w in _persist.writes:
		if w["key"] == key:
			n += 1
	return n


## ============ AC-35 — per-frame coalesce + settle final + P-08 ============

func test_ac35_drag_coalesces_per_frame() -> void:
	_open()
	var calls_before: int = _fx.motion_calls.size()
	_sut.slider_drag(0.30)
	_sut.slider_drag(0.40)
	_sut.slider_drag(0.50)  # 同一 frame 3 tick
	_sut.advance(16.0)
	assert_eq(_fx.motion_calls.size() - calls_before, 1, "同 frame 3 tick ⇒ ≤1 call")
	assert_almost_eq(_fx.motion_calls[-1], 0.5, 0.001, "latest-wins")


func test_ac35_thirty_ticks_across_frames_bounded() -> void:
	_open()
	var calls_before: int = _fx.motion_calls.size()
	for i in range(30):
		_sut.slider_drag(float(i) / 30.0)
		if i % 3 == 2:
			_sut.advance(16.0)  # 10 frames
	assert_lte(_fx.motion_calls.size() - calls_before, 10, "30 tick 跨 10 frame ⇒ ≤10 calls")


func test_ac35_p08_flip_calls_camera_and_persists() -> void:
	_open()
	_sut.toggle_reduce_motion(true)
	assert_eq(_cam.reduction_calls, [true], "set_motion_reduction 即時 call")
	assert_true(_sut.is_avatar_breathing_frozen(), "一掣兩 consumer — avatar freeze 同 frame")
	_sut.advance(TimingConfig.SETTINGS_PERSIST_DEBOUNCE_MS)
	assert_eq(_persist.store.get("settings.reduce_camera_motion"), true)


## ============ AC-36 — debounce:零 per-tick write,settle 後恰好 1 ============

func test_ac36_zero_write_during_drag_one_after_release() -> void:
	_open()
	var key := "settings.motion_intensity"
	var before: int = _count_persist_writes(key)
	for i in range(30):
		_sut.slider_drag(float(i) / 30.0)
		_sut.advance(16.0)
	assert_eq(_count_persist_writes(key) - before, 0, "drag 期間零 write")
	_sut.slider_release()
	_sut.advance(TimingConfig.SETTINGS_PERSIST_DEBOUNCE_MS)
	assert_eq(_count_persist_writes(key) - before, 1, "release 後 debounce window 恰好 1 次")


## ============ AC-37 — preview uniform path,零 play_sfx ============

func test_ac37_preview_fires_on_release_even_at_zero() -> void:
	_open()
	_sut.slider_drag(0.0)
	_sut.advance(16.0)
	assert_eq(_fx.preview_calls, 0, "drag 期間零 preview call")
	_sut.slider_release()
	assert_eq(_fx.preview_calls, 1, "pct==0 release preview 照 trigger(uniform path)")
	# preview/slider 路徑零 play_sfx(silent 名單 — open cue 唔計)
	for cue in _audio.sfx_calls:
		assert_ne(cue, &"ui_charscreen_close")
	assert_eq(_audio.sfx_calls.filter(func(c): return c != &"ui_charscreen_open").size(), 0,
		"slider 全路徑零 SFX")


## ============ AC-38 — close path flush(drag 中 force-close = settle)============

func test_ac38_force_close_mid_drag_flushes_critical() -> void:
	_open()
	_sut.slider_drag(0.62)
	# 未 release — force-close
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	var found := false
	for w in _persist.writes:
		if w["key"] == "settings.motion_intensity":
			assert_almost_eq(w["value"], 0.62, 0.001, "當 force-close = settle(applied 值)")
			assert_true(w["flush"], "critical flush write(key, value, true) — EC-27")
			found = true
	assert_true(found, "先寫後閂")


func test_ac38_normal_close_within_debounce_window_flushes() -> void:
	_open()
	_sut.slider_drag(0.4)
	_sut.advance(16.0)
	_sut.slider_release()  # settle — debounce arm(500ms 未到)
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_persist.store.get("settings.motion_intensity"), 0.4,
		"settle 後 window 內 normal close → flush 先於離開(uip B3)")


func test_ac38_persist_fail_session_applied_banner_suppressed_on_close() -> void:
	_persist.fail_writes = true
	_open()
	_sut.slider_drag(0.3)
	_sut.advance(16.0)
	_gsm.transition(GSMScript.GameState.SUSPENDED)  # snap close
	assert_almost_eq(_fx.motion_calls[-1], 0.3, 0.001, "value 留 session-applied")
	assert_false(_sut.is_persist_fail_banner_visible(), "screen 閂緊 → banner suppress")


## ============ AC-39 — legacy float 顯示 quantized,唔即時 rewrite ============

func test_ac39_legacy_float_display_no_open_time_rewrite() -> void:
	_persist.store["settings.motion_intensity"] = 0.999
	_open()
	assert_eq(_sut.get_motion_slider()["label"], "100%", "F2 apply 後 render")
	assert_eq(_count_persist_writes("settings.motion_intensity"), 0,
		"唔即時 rewrite(open-time write storm 避開)")
	# user settle 先 normalize
	_sut.slider_drag(1.0)
	_sut.slider_release()
	_sut.advance(TimingConfig.SETTINGS_PERSIST_DEBOUNCE_MS)
	assert_eq(_persist.store["settings.motion_intensity"], 1.0, "settle 自然 normalize")


## ============ AC-40 — fresh install defaults ============

func test_ac40_fresh_install_defaults() -> void:
	_open()
	assert_eq(_sut.get_motion_slider()["label"], "100%", "motion default 1.0")
	assert_false(_sut.is_avatar_breathing_frozen(), "reduce_camera_motion default false")


## ============ AC-52 — volume slider(G-CS-11;零 #22 persist;零 SFX)============

func test_ac52_volume_via_linear_setter_no_22_persist_no_sfx() -> void:
	_open()
	var sfx_before: int = _audio.sfx_calls.size()
	_sut.volume_drag(0.68)
	_sut.advance(16.0)
	_sut.volume_release()
	assert_almost_eq(_audio.linear_calls[-1], 0.68, 0.001, "經 G-CS-11 linear setter")
	assert_eq(_count_persist_writes("audio.master_db"), 0, "零 audio.* write from #22(persistence #4 own)")
	assert_eq(_audio.sfx_calls.size(), sfx_before, "volume 操作全程零 play_sfx")


func test_ac52_open_reads_current_via_paired_getter() -> void:
	_audio.current_linear = 0.5
	_open()
	assert_eq(_sut.get_volume_slider()["pct"], 50, "現值經 get_bus_volume_linear 讀")


func test_ac52_no_db_math_in_22_source() -> void:
	# AC-52 grep-able 斷言:#22 源碼零 linear_to_db / db_to_linear(duplicate ban)
	var f := FileAccess.open("res://src/autoload/character_screen_coordinator.gd", FileAccess.READ)
	var src := f.get_as_text()
	f.close()
	assert_false("linear_to_db" in src, "#22 禁 linear→dB 數學")
	assert_false("db_to_linear" in src, "#22 禁 dB→linear 數學(配對 getter 喺 #4)")


## ============ EC-28 keyboard ============

func test_ec28_keyboard_clamp_no_wrap() -> void:
	_open()
	_sut.slider_keyboard_step(1)  # 100 + → clamp
	assert_eq(_sut.get_motion_slider()["pct"], 100, "clamp no-op 唔 wrap")
	for i in range(12):
		_sut.slider_keyboard_step(-1)
	assert_eq(_sut.get_motion_slider()["pct"], 0, "落到 0 clamp")
