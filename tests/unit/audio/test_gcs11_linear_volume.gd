## #4 G-CS-11 — set_bus_volume_linear (#22 story 012)。
## Formula 2 locus 喺 #4;#22 slider 經呢度,源碼零 dB 數學。
extends GutTest

const AudioManagerScript := preload("res://src/autoload/audio_manager.gd")

var _am = null
var _master_db_before: float


func before_each() -> void:
	_master_db_before = AudioServer.get_bus_volume_db(0)
	_am = AudioManagerScript.new()
	add_child_autofree(_am)


func after_each() -> void:
	AudioServer.set_bus_volume_db(0, _master_db_before)  # restore global state


func test_linear_half_maps_to_formula2_db() -> void:
	_am.set_bus_volume_linear(AudioManagerScript.Bus.MASTER, 0.5)
	assert_almost_eq(_am.get_bus_volume_db(AudioManagerScript.Bus.MASTER),
		linear_to_db(0.5), 0.01, "Formula 2:db = linear_to_db(s)")


func test_linear_one_is_zero_db() -> void:
	_am.set_bus_volume_linear(AudioManagerScript.Bus.MASTER, 1.0)
	assert_almost_eq(_am.get_bus_volume_db(AudioManagerScript.Bus.MASTER), 0.0, 0.01,
		"s=1 → 0dB(MAX_BUS_DB — 禁 boost)")


func test_linear_zero_is_mute_floor() -> void:
	_am.set_bus_volume_linear(AudioManagerScript.Bus.MASTER, 0.0)
	assert_almost_eq(_am.get_bus_volume_db(AudioManagerScript.Bus.MASTER),
		AudioManagerScript.MUTE_FLOOR_DB, 0.01, "slider 最低 = 靜音(唔係 -inf)")


func test_linear_corrupt_input_mutes_conservatively() -> void:
	for bad in [NAN, INF, -INF]:
		_am.set_bus_volume_linear(AudioManagerScript.Bus.MASTER, bad)
		assert_almost_eq(_am.get_bus_volume_db(AudioManagerScript.Bus.MASTER),
			AudioManagerScript.MUTE_FLOOR_DB, 0.01, "corrupt → 靜音(保守安全向)")


func test_linear_over_one_clamps_no_boost() -> void:
	_am.set_bus_volume_linear(AudioManagerScript.Bus.MASTER, 1.7)
	assert_almost_eq(_am.get_bus_volume_db(AudioManagerScript.Bus.MASTER), 0.0, 0.01,
		"clamp 1.0 → 0dB,boost forbidden")


func test_get_linear_round_trips() -> void:
	for s in [0.0, 0.25, 0.5, 1.0]:
		_am.set_bus_volume_linear(AudioManagerScript.Bus.MASTER, s)
		assert_almost_eq(_am.get_bus_volume_linear(AudioManagerScript.Bus.MASTER), s, 0.001,
			"linear round-trip %s(getter 配對 — #22 零 dB 數學)" % s)
