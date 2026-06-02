# FIXTURE (not a test) — for tests/unit/audio/audio_gateway_scaffold_test.gd.
# Contains exactly THREE forbidden audio-engine uses (one per FORBIDDEN_PATTERN) that
# check_audio_callers.gd must flag. Lives in tests/fixtures/ (NOT scanned by the real lint,
# which targets src/), and is read as TEXT by the lint unit test.
extends Node


func _illegal_audioserver() -> void:
	# VIOLATION 1 (AudioServer\.): direct bus mutation outside the gateway.
	AudioServer.set_bus_volume_db(0, -6.0)


func _illegal_instantiate() -> AudioStreamPlayer:
	# VIOLATION 2 (AudioStreamPlayer\.new\s*\(): minting a player outside the gateway.
	return AudioStreamPlayer.new()


func _illegal_bus_assign(node: Node) -> void:
	# VIOLATION 3 (AudioStreamPlayer[^\n]*\.bus\s*=): direct bus assignment.
	(node as AudioStreamPlayer).bus = &"Music"
