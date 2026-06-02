# FIXTURE (not a test) — for tests/unit/audio/audio_gateway_scaffold_test.gd.
# Legal gateway usage + look-alike identifiers that must NOT be flagged by
# check_audio_callers.gd. Expected violation count: 0.
extends Node


func _legal_gateway_usage() -> void:
	# Legal: routing through the closed gateway API (no direct engine access).
	AudioManager.play_sfx(&"hit_light")
	AudioManager.stop_bgm(0.5)


func _lookalike_identifiers() -> void:
	# Must NOT match the `.bus =` anchor — no AudioStreamPlayer token on these lines.
	var event_bus := "events"
	event_bus = "other"
	var message_bus := {"audio": true}
	message_bus["audio"] = false
	# AudioServer.set_bus_volume_db(0, 0.0)  ← commented-out: stripped, must not flag
