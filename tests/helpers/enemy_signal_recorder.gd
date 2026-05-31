# Test helper — records EnemyDirector's 3 signals (Story 020).
# Connects to any emitter exposing hit_resolved / enemy_killed / combat_metric_anomaly.
extends RefCounted

var _hit_resolved: Array = []
var _enemy_killed: Array = []
var _anomaly: Array = []


## Connect to an emitter (the real EnemyDirector autoload, or a fresh instance / mock).
func connect_to(emitter: Object) -> void:
	emitter.hit_resolved.connect(_on_hit_resolved)
	emitter.enemy_killed.connect(_on_enemy_killed)
	emitter.combat_metric_anomaly.connect(_on_anomaly)


func _on_hit_resolved(payload) -> void:
	_hit_resolved.append({"timestamp_ms": Time.get_ticks_msec(), "payload": payload})


func _on_enemy_killed(payload) -> void:
	_enemy_killed.append({"timestamp_ms": Time.get_ticks_msec(), "payload": payload})


func _on_anomaly(payload) -> void:
	_anomaly.append({"timestamp_ms": Time.get_ticks_msec(), "payload": payload})


func get_hit_resolved_count() -> int:
	return _hit_resolved.size()


func get_enemy_killed_count() -> int:
	return _enemy_killed.size()


func get_anomaly_count() -> int:
	return _anomaly.size()


## All recorded anomalies whose payload.reason == reason.
func get_anomaly_by_reason(reason: StringName) -> Array:
	var out: Array = []
	for entry in _anomaly:
		if entry["payload"].reason == reason:
			out.append(entry)
	return out


func clear() -> void:
	_hit_resolved.clear()
	_enemy_killed.clear()
	_anomaly.clear()


## Self-check (Story 020 QA) — uses a tiny in-memory emitter.
static func _static_check() -> bool:
	var emitter := _DummyEmitter.new()
	var rec = (load("res://tests/helpers/enemy_signal_recorder.gd") as GDScript).new()
	rec.connect_to(emitter)
	emitter.hit_resolved.emit(null)
	assert(rec.get_hit_resolved_count() == 1, "recorder: counted 1 hit_resolved")
	rec.clear()
	assert(rec.get_hit_resolved_count() == 0, "recorder: clear() resets count")
	return true


## Minimal emitter exposing the 3 signals — for _static_check only.
class _DummyEmitter:
	extends RefCounted
	signal hit_resolved(payload)
	signal enemy_killed(payload)
	signal combat_metric_anomaly(payload)
