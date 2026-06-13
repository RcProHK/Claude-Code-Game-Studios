## Live GymSys integration check (Option B) — runs the REAL #2 client against a RUNNING GYM.
## Logs in as a throwaway test account, polls GET /api/game/feed, prints the ADR-0002 signals
## the client emits from the seeded workout. Standalone Node scene (needs live GYM on :8090 +
## the real HTTPRequest transport) — NOT a CI test.
## Run: godot --headless --path . res://prototypes/vertical-slice/GymsysLiveCheck.tscn
extends Node

const CLIENT := preload("res://src/autoload/gym_sys_backend_client.gd")
const BASE := "http://127.0.0.1:8090"

var _c: Node
var _events: Array[String] = []


func _ready() -> void:
	_c = CLIENT.new()
	add_child(_c)
	_c.workout_started.connect(func() -> void: _events.append("workout_started"))
	_c.set_logged.connect(func(eid: StringName, reps: int, w: float) -> void:
		_events.append("set_logged %s reps=%d weight=%.1f" % [eid, reps, w]))
	_c.workout_completed.connect(func(at: int) -> void: _events.append("workout_completed saved_at=%d" % at))
	_c.poll_failed.connect(func(cat: StringName) -> void: _events.append("poll_failed %s" % cat))
	_c.poll_recovered.connect(func() -> void: _events.append("poll_recovered"))
	_c.logged_in.connect(func(ok: bool) -> void: print("[live] logged_in = ", ok))

	print("[live] login to %s as mh_e2e + poll /api/game/feed ..." % BASE)
	_c.login(BASE, "mh_e2e", "pass1234", 2.0)

	await get_tree().create_timer(6.0).timeout

	print("\n=== signals the #2 client emitted from the LIVE GYM feed ===")
	for e: String in _events:
		print("   ", e)
	print("=== total: %d signal(s) ===" % _events.size())
	if _events.size() > 0:
		print("[gymsys_live_check] PASS — real GYM workout drove the client end-to-end")
		get_tree().quit(0)
	else:
		printerr("[gymsys_live_check] FAIL — no signals")
		get_tree().quit(1)
