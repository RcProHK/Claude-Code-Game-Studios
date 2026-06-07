## StatTween — #22 F1 stat tween core (story 004).
##
## GDD: design/gdd/character-screen.md §F1 (Pass 1 pins all implemented here):
##   - clamp u (sd B-1): u = clampf(t / STAT_TWEEN_MS, 0, 1) — frame-delta 累積
##     必然 overshoot duration;冇 clamp 嘅 ease_out_cubic(u>1) 係爆炸性外插,
##     browser throttle delta 500ms 會顯示超過 target 嘅值(Pillar 1 違反)。
##   - retarget 只限 EQUIPMENT source (sd B-4):非 EQUIPMENT signal 行 snap()。
##   - zero-delta formatter guard settle := v_target (sd B-3):display 內部
##     state 永遠收斂上游真值,唔留 interpolated fiction。
##   - arrow operand pin:sign(v_target − v_display_at_retarget),operand =
##     raw interpolated 值(即新 tween 嘅 v_from),唔係 formatted 值。
##
## 「Formatter 就係 epsilon」:所有 visibility/animation predicate 比較
## formatted display 值 — 殺 phantom-arrow / sub-display-unit tween class。
##
## Timing:外部 injected clock 經 advance(delta_ms) 驅動(coordinator 嘅
## 同一條 clock)— 呢個 class 自己零 engine timing。
## Per-row instance;4-row 並行 = 4 個獨立 instance,constant duration ⇒
## lockstep settle(同一 frame 落定 — settle SFX coalesce 喺 story 019)。
extends RefCounted

const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")

## per-stat display formatter fmt_s (story 005 Format Table 提供).
var _fmt: Callable
## knob — injectable for band-edge tests (safe range 200-400).
var _tween_ms: float

var _v_from: float = 0.0
var _v_target: float = 0.0
var _elapsed_ms: float = 0.0
var _active: bool = false
## -1 = ↓, 0 = none, +1 = ↑ (settle 後 render 層做 hold ~1.2s fade — 唔喺度).
var _arrow: int = 0
## Rule 32d coalesced announce 用:由 settled 起首次 retarget 嗰刻嘅起點值
## (retarget chain 唔覆寫 — announce「84→90」嘅 84;settle 後由 caller 清)。
var announce_from: float = NAN


func _init(fmt: Callable, tween_ms: float = TimingConfig.STAT_TWEEN_MS) -> void:
	_fmt = fmt
	_tween_ms = tween_ms


## Open-time initial value (Rule 7 sync read) — settled, no arrow.
func reset(v: float) -> void:
	_v_from = v
	_v_target = v
	_elapsed_ms = 0.0
	_active = false
	_arrow = 0


## Raw interpolated current value (F1 display_value 嘅 pre-format 值).
func current_raw() -> float:
	if not _active:
		return _v_target
	var u: float = clampf(_elapsed_ms / _tween_ms, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - u, 3.0)
	return lerpf(_v_from, _v_target, eased)


## Formatted display string (F1 output).
func display() -> String:
	return _fmt.call(current_raw())


func arrow() -> int:
	return _arrow


func is_active() -> bool:
	return _active


func target() -> float:
	return _v_target


## EQUIPMENT-source signal 入口 (Rule 10 tween path + F1 retarget 規則).
## Mid-tween 再收 → 由當前 interpolated 值 restart,永不 queue。
func retarget(v_target_new: float) -> void:
	var v_display_at_retarget: float = current_raw()  # raw interpolated pin
	# Zero-delta formatter guard (EC-08/EC-10):無 tween 無 arrow;
	# 進行中 tween kill 並 settle := v_target(sd B-3 — 真值收斂).
	if _fmt.call(v_target_new) == _fmt.call(v_display_at_retarget):
		_v_from = v_target_new
		_v_target = v_target_new
		_elapsed_ms = 0.0
		_active = false
		_arrow = 0
		return
	if not _active and is_nan(announce_from):
		announce_from = v_display_at_retarget  # settled→tween 起點(announce 用)
	_arrow = int(signf(v_target_new - v_display_at_retarget))
	_v_from = v_display_at_retarget
	_v_target = v_target_new
	_elapsed_ms = 0.0
	_active = true


## 非 EQUIPMENT source (reconnect reconciliation 等) — kill + snap + 清 arrow
## (sd B-4:retarget 規則只適用 EQUIPMENT;backend 補數唔可以演成即場升級).
func snap(v: float) -> void:
	_v_from = v
	_v_target = v
	_elapsed_ms = 0.0
	_active = false
	_arrow = 0


## Injected clock tick. 自然行到尾 = settle 喺 v_target(formatter guard 唔使).
## Returns true 喺「settle 呢一下」發生嗰 tick(story 019 settle-frame SFX coalesce 用).
func advance(delta_ms: float) -> bool:
	if not _active:
		return false
	_elapsed_ms += delta_ms
	if _elapsed_ms >= _tween_ms:
		_active = false
		_elapsed_ms = _tween_ms
		return true
	return false
