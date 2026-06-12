class_name TelemetryBuffer extends RefCounted
## Telemetry (#28) — 3-tier priority ring buffer (Rule 5 / Rule 7 overflow).
##
## CRITICAL events live in a dedicated RESERVED deque that is NEVER evicted by ordinary
## overflow (anti-fabrication / anomaly命脈). STANDARD + LOW share a main ring. When the
## main ring is full a new STANDARD/LOW push evicts the OLDEST LOW first, then the OLDEST
## STANDARD; every eviction bumps `dropped_count` — itself a CRITICAL meta-fact so "we
## lost data" never silently vanishes. When even the CRITICAL reserve overflows, the
## oldest overflowing CRITICAL is handed to an emergency spool hook (Story 016 wires the
## real user:// write + private-mode gate); only a FAILED spool drops + counts it (EC-05).
##
## Pure in-memory structure (no ADR). Capped to honor the 512MB browser ceiling.
##
## Governing: design/gdd/telemetry.md Rule 5/7, EC-01/05/15, INV-T1, AC-03.

const PRIORITY := TelemetryEvent.Priority  # CRITICAL / STANDARD / LOW

## The dropped_count meta-event is itself CRITICAL (Rule 7 — "we lost data" must survive).
const DROPPED_COUNT_EVENT_PRIORITY: int = TelemetryEvent.Priority.CRITICAL

var _buffer_max: int
var _critical_reserved: int
var _main_capacity: int
var _critical: Array = []   # reserved deque (CRITICAL only, FIFO)
var _main: Array = []        # ring (STANDARD + LOW, FIFO with priority eviction)
var _dropped_count: int = 0
## Emergency spool hook: Callable(events: Array) -> bool (true = durably spooled).
## Default invalid → treated as "no spool wired" → a CRITICAL overflow is dropped+counted.
var _spool_hook: Callable = Callable()


## INV-T1 + sanity — pure predicate (no push_error, so tests can probe it without
## tripping the .gutconfig engine-error gate). Returns "" if valid, else a reason.
static func validate_config(buffer_max: int, critical_reserved: int) -> String:
	if buffer_max <= 0:
		return "buffer_max must be > 0 (got %d)" % buffer_max
	if critical_reserved < 0:
		return "critical_reserved must be >= 0 (got %d)" % critical_reserved
	if critical_reserved >= buffer_max:
		return "INV-T1 violated: TELEMETRY_CRITICAL_RESERVED (%d) >= TELEMETRY_BUFFER_MAX (%d)" \
			% [critical_reserved, buffer_max]
	return ""


func _init(buffer_max: int, critical_reserved: int) -> void:
	var err := validate_config(buffer_max, critical_reserved)
	if err != "":
		# Illegal config: log it (production startup surfaces this) and fall back to a
		# safe split so the observer still boots — telemetry NEVER crashes gameplay (Rule 1).
		push_error("[TelemetryBuffer] %s — using safe fallback split" % err)
		buffer_max = maxi(buffer_max, 2)
		critical_reserved = clampi(critical_reserved, 0, buffer_max - 1)
	_buffer_max = buffer_max
	_critical_reserved = critical_reserved
	_main_capacity = buffer_max - critical_reserved


## Set the emergency spool hook (Story 016). Callable(events: Array) -> bool.
func set_spool_hook(hook: Callable) -> void:
	_spool_hook = hook


## Append an event, routing by priority + applying Rule 7 overflow.
func push(ev: TelemetryEvent) -> void:
	if ev.priority == PRIORITY.CRITICAL:
		_push_critical(ev)
	else:
		_push_main(ev)


func _push_critical(ev: TelemetryEvent) -> void:
	if _critical.size() >= _critical_reserved:
		# Reserve full — spool the oldest overflowing CRITICAL; NEVER silently drop.
		var overflow = _critical.pop_front()
		if not _emergency_spool([overflow]):
			_dropped_count += 1  # spool failed/unwired → the at-risk CRITICAL is counted
	_critical.append(ev)


func _push_main(ev: TelemetryEvent) -> void:
	if _main.size() >= _main_capacity:
		_evict_one_main()
	_main.append(ev)


## Rule 7: evict the OLDEST LOW; if none, the oldest STANDARD. Bump dropped_count.
func _evict_one_main() -> void:
	var idx := _find_oldest_of_priority(PRIORITY.LOW)
	if idx == -1:
		idx = _find_oldest_of_priority(PRIORITY.STANDARD)
	if idx == -1:
		idx = 0  # defensive — main holds only STANDARD/LOW
	if not _main.is_empty():
		_main.remove_at(idx)
		_dropped_count += 1


func _find_oldest_of_priority(prio: int) -> int:
	for i in range(_main.size()):
		if _main[i].priority == prio:
			return i
	return -1


## Returns true iff the events were durably spooled (Story 016). Unwired → false.
func _emergency_spool(events: Array) -> bool:
	if _spool_hook.is_valid():
		var result = _spool_hook.call(events)
		return result if result is bool else false
	return false


# --- Inspection (tests / flush Story 011) -------------------------------------

func size() -> int:
	return _critical.size() + _main.size()


func critical_size() -> int:
	return _critical.size()


func main_size() -> int:
	return _main.size()


func get_dropped_count() -> int:
	return _dropped_count


func count_priority(prio: int) -> int:
	if prio == PRIORITY.CRITICAL:
		return _critical.size()
	return _find_count_of_priority(prio)


func _find_count_of_priority(prio: int) -> int:
	var n := 0
	for ev in _main:
		if ev.priority == prio:
			n += 1
	return n


## All buffered events (CRITICAL first, then main FIFO). Used by flush (Story 011).
func get_all() -> Array:
	var out: Array = []
	out.append_array(_critical)
	out.append_array(_main)
	return out


## A bounded prefix of buffered events for one flush batch (Story 011). CRITICAL first
## (highest analytic value), then main FIFO, capped at `limit` (the flush_batch_size knob).
## limit <= 0 → all (get_all).
func get_batch(limit: int) -> Array:
	if limit <= 0:
		return get_all()
	var out: Array = []
	for ev in _critical:
		if out.size() >= limit:
			return out
		out.append(ev)
	for ev in _main:
		if out.size() >= limit:
			return out
		out.append(ev)
	return out


## Remove-on-ACK (Story 011 / EC-12): drop every buffered event whose client_event_id is in
## `acked_ids`. An id not present (already evicted by overflow) is a silent no-op — a late
## ACK for an evicted batch never corrupts the buffer. Returns the count actually removed.
func remove_by_event_ids(acked_ids: Array) -> int:
	if acked_ids.is_empty():
		return 0
	var id_set := {}
	for id in acked_ids:
		id_set[int(id)] = true
	var removed := 0
	removed += _remove_acked_from(_critical, id_set)
	removed += _remove_acked_from(_main, id_set)
	return removed


func _remove_acked_from(deque: Array, id_set: Dictionary) -> int:
	var kept: Array = []
	var removed := 0
	for ev in deque:
		if id_set.has(ev.client_event_id):
			removed += 1
		else:
			kept.append(ev)
	if removed > 0:
		deque.assign(kept)
	return removed
