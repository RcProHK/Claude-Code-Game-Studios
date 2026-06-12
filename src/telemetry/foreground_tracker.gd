class_name ForegroundTracker extends RefCounted
## Telemetry (#28) — Formula 2 foreground-time accumulator (glance proxy).
##
## Tracks cumulative foreground vs total time using a monotonic clock. A
## visibilitychange→hidden banks the elapsed visible span and pauses foreground accrual;
## →visible resumes it. Non-web platforms emit no visibility events, so the tracker stays
## visible the whole time → ratio 1.0 (EC-06 / AC-3 fallback). The caller supplies the
## monotonic timestamp at each transition / sample (Story 007 wires platform_detect; tests
## inject a controllable clock).
##
## Governing: design/gdd/telemetry.md Formula 2, Rule 9, EC-06, AC-05.

var _foreground_ms: int = 0
var _total_ms: int = 0
var _is_visible: bool = true
var _last_mark_ms: int = -1  # ts of the last transition / start; -1 = not started


## Begin tracking at `now_ms` (assumed foreground — the page starts visible).
func start(now_ms: int) -> void:
	_last_mark_ms = now_ms
	_is_visible = true


## Bank the span since the last mark into total (+ foreground if we were visible).
func _advance(now_ms: int) -> void:
	if _last_mark_ms < 0:
		_last_mark_ms = now_ms
		return
	var delta: int = now_ms - _last_mark_ms
	if delta < 0:
		delta = 0  # defensive — monotonic clock shouldn't go backwards
	_total_ms += delta
	if _is_visible:
		_foreground_ms += delta
	_last_mark_ms = now_ms


func mark_hidden(now_ms: int) -> void:
	_advance(now_ms)
	_is_visible = false


func mark_visible(now_ms: int) -> void:
	_advance(now_ms)
	_is_visible = true


## Current foreground ratio (advances accumulators to now_ms first). EC-06: total 0 → 1.0.
func ratio(now_ms: int) -> float:
	_advance(now_ms)
	return TelemetryFormulas.foreground_ratio(_foreground_ms, _total_ms)


func foreground_ms() -> int:
	return _foreground_ms


func total_ms() -> int:
	return _total_ms
