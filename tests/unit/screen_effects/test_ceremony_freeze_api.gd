extends GutTest
## Stories 020+021 (G-LM-3) — #6 ceremony freeze ledger + new APIs.
## ② hybrid ledger(hit-scalar parity by construction + ceremony per-entry)
## ① ceremony_freeze ceiling 自管 ③ idempotent release ④ saturation uniform
## ⑤ Suspended 安全網 ⑥ hit_pause 隔離;EC-M3 主測試(AC-54 嘅 #6-side 主場)。

const ScreenEffectsScript := preload("res://src/autoload/screen_effects.gd")


var _sut: Node
var _uniform_writes: Array = []


func before_each() -> void:
	_uniform_writes = []
	_sut = ScreenEffectsScript.new()
	_sut._shader_sink = func(uniform: StringName, value: Variant) -> void:
		_uniform_writes.append({"uniform": uniform, "value": value})
	add_child_autofree(_sut)
	_sut._lifecycle_state = ScreenEffectsScript.LifecycleState.ACTIVE


func after_each() -> void:
	if is_instance_valid(_sut) and get_tree().paused:
		get_tree().paused = false


# --- ① ceiling 自管(唔受 MAX_PAUSE_SEC 0.12 管) ---

func test_ceremony_freeze_accepts_durations_beyond_hit_pause_ceiling() -> void:
	var handle: int = _sut.ceremony_freeze(0.4)
	assert_gt(handle, 0, "0.4s 接受 — CEREMONY_FREEZE_MAX_SEC 自管,MAX_PAUSE_SEC 唔干涉")
	assert_almost_eq(float(_sut._ceremony_freeze_ledger[handle]), 0.4, 0.0001)
	assert_true(get_tree().paused, "tree 凍結")
	_sut.release(handle)


func test_over_ceiling_clamps_to_0_4() -> void:
	var handle: int = _sut.ceremony_freeze(1.5)
	assert_almost_eq(float(_sut._ceremony_freeze_ledger[handle]), 0.4, 0.0001, "clamp 到 ceiling")
	_sut.release(handle)


func test_not_serviceable_rejects_with_zero_handle() -> void:
	_sut._lifecycle_state = ScreenEffectsScript.LifecycleState.BOOTING
	assert_eq(_sut.ceremony_freeze(0.3), 0, "EC-M2 — caller 收 0 即 degrade")
	assert_false(get_tree().paused)


# --- ③ idempotent release ×3 ---

func test_release_is_idempotent_and_never_issued_safe() -> void:
	var handle: int = _sut.ceremony_freeze(0.4)
	_sut.release(handle)
	assert_false(get_tree().paused, "早收即解凍")
	_sut.release(handle)       # double-release
	_sut.release(99999)        # never-issued
	assert_false(get_tree().paused, "no-op 無 error 無 double-decrement")


# --- EC-M3 主測試: per-entry + max-remaining 效果 ---

func test_overlapping_freezes_max_remaining_and_own_entry_release() -> void:
	var short_h: int = _sut.ceremony_freeze(0.1)
	var long_h: int = _sut.ceremony_freeze(0.4)
	assert_true(get_tree().paused)
	_sut._process(0.15)  # short 過期;long 剩 0.25
	assert_false(_sut._ceremony_freeze_ledger.has(short_h), "短 entry 自然過期")
	assert_true(get_tree().paused, "effective freeze = max remaining — 長 entry 仍 hold")
	_sut.release(long_h)  # 只清自己 entry
	assert_false(get_tree().paused)


# --- ⑥ hit_pause 隔離(雙向) ---

func test_hit_pause_expiry_never_truncates_ceremony_freeze() -> void:
	var handle: int = _sut.ceremony_freeze(0.4)
	_sut.hit_pause(0.05)
	assert_true(get_tree().paused)
	_sut._process(0.06)  # hit 過期(scalar drain)
	assert_true(get_tree().paused, "ceremony 仍 hold — stray hit_pause 唔可以截斷 (⑥)")
	_sut.release(handle)
	assert_false(get_tree().paused)


func test_ceremony_release_respects_active_hit_pause() -> void:
	_sut.hit_pause(0.1)
	var handle: int = _sut.ceremony_freeze(0.4)
	_sut.release(handle)
	assert_true(get_tree().paused, "hit 仍 active — tree 唔解凍(雙 store 都清先)")
	_sut._process(0.12)
	assert_false(get_tree().paused)


# --- ⑤ Suspended 安全網 ---

func test_suspended_override_clears_ceremony_ledger_and_saturation() -> void:
	var _handle: int = _sut.ceremony_freeze(0.4)
	_sut.apply_ceremony_saturation(0.6, 2.0)
	_sut._enter_suspended()
	assert_true(_sut._ceremony_freeze_ledger.is_empty(), "ledger 清空 — freeze 永不 survive suspend")
	assert_false(get_tree().paused)
	var saturation_reset: bool = false
	for w: Dictionary in _uniform_writes:
		if w["uniform"] == &"u_world_saturation_drop" and w["value"] is float and float(w["value"]) == 0.0:
			saturation_reset = true
	assert_true(saturation_reset, "saturation 還原到 0(uniform write)")
	assert_eq(_sut._saturation_drop_current, 0.0)


# --- ④ saturation uniform path + recovery ---

func test_saturation_writes_uniform_and_recovers_to_zero() -> void:
	_sut.apply_ceremony_saturation(0.6, 2.0)
	var first: Dictionary = _uniform_writes[-1]
	assert_eq(first["uniform"], &"u_world_saturation_drop")
	assert_almost_eq(float(first["value"]), 0.6, 0.0001, "−60% drop 落 uniform(shader path,唔掂 nodes)")
	# MAX_FRAME_DELTA(0.1)clamp — recovery 以 0.1s ticks 推(rate 0.3/s):
	for i: int in range(10):
		_sut._process(0.1)  # 1.0s → 0.6 − 0.3 = 0.3
	assert_almost_eq(_sut._saturation_drop_current, 0.3, 0.001)
	for i: int in range(15):
		_sut._process(0.1)
	assert_eq(_sut._saturation_drop_current, 0.0, "recover 到零(non-blocking ambient)")


## 自然 expiry 行 INV-M1 嘅「無早收」path:
func test_natural_expiry_unfreezes() -> void:
	var _handle: int = _sut.ceremony_freeze(0.2)
	for i: int in range(3):
		_sut._process(0.1)  # MAX_FRAME_DELTA clamp — 0.3s 累積
	assert_false(get_tree().paused, "自然過期解凍")
	assert_true(_sut._ceremony_freeze_ledger.is_empty())
