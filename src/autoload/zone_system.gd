## ZoneSystem — #19 Zone System autoload (stories 002-008).
##
## Driving GDD: design/gdd/zone-system.md (✅ APPROVED 2026-06-06 Pass 3)
## Governing ADRs: ADR-0003 (zone.state backend-primary posture; recovery = local
## sweep — ZERO server surface), ADR-0006 C3/C4 (envelope; sequential boot; C6
## NOT applicable — no state-dependent behaviour), ADR-0007 (Kind enum), ADR-0008
## (G-Z-1: PersistenceLayer ≺ WST ≺ ZoneSystem, tail append after PrDetection).
##
## The thin container layer: data-driven ZoneRegistry, training-day count unlock
## framework (transition_id dedup + monotone `<=` UTC-date guard — per-day cap 1
## AND epoch-resync replay immunity in one operator), write-success-then-emit
## with two-append rollback, boot retroactive sweep (pure local recovery), and
## the persisted ceremony_pending queue (aggregated reveal — consumer-drained).
## MVP: 1 ALWAYS zone — the framework is structurally live, behaviourally idle.
extends Node


## Earned unlock (write-success-then-emit — Rule 5). ALWAYS zones never emit.
signal zone_unlocked(zone_id: StringName)

enum SystemState { INITIALISING, READY }

const REGISTRY_PATH := "res://assets/data/zone_registry.tres"

var _system_state: int = SystemState.INITIALISING

# --- DI seams (untyped — project DI discipline) ---
var _persistence            ## seam 1: #3 IPersistence (default /root/PersistenceLayer)
var _workout_source         ## seam 3: #9 WST (workout_completed_forwarded source)
var _registry: ZoneRegistryData = null  ## seam 2: injected registry (default = REGISTRY_PATH)

## seam 4: telemetry append-log (#15/#17 verbatim pattern).
var _telemetry_log: Array[Dictionary] = []

var _zone_state: ZoneState = ZoneState.new()


func _ready() -> void:
	if _persistence == null:
		_persistence = get_node_or_null("/root/PersistenceLayer")
	if _workout_source == null:
		_workout_source = get_node_or_null("/root/WorkoutStateTracker")
	if _registry == null and ResourceLoader.exists(REGISTRY_PATH):
		_registry = load(REGISTRY_PATH)
	if not validate_registry(_registry):
		_emit_telemetry("zone.registry_invalid", {})
		return  # fail loud — stays INITIALISING (EC-4: a game with no zones cannot run)
	_load_state()
	_retroactive_sweep()  # Rule 7 — boot recovery + v0.2 new-zone retro-credit
	if _workout_source != null and _workout_source.has_signal("workout_completed_forwarded"):
		_workout_source.workout_completed_forwarded.connect(_on_workout_completed_forwarded)
	_system_state = SystemState.READY


func is_ready() -> bool:
	return _system_state == SystemState.READY


func get_telemetry() -> Array[Dictionary]:
	return _telemetry_log


# ═══════════════════════════════════════════════════════════════════════════
# Registry (Story 001)
# ═══════════════════════════════════════════════════════════════════════════

## EC-4/EC-6 — validation-function form (raw assert is invisible to headless
## GUT — #18 AC-20 lesson). Strictly: ≥1 entry, unique non-empty zone_ids,
## non-null conditions, no UNKNOWN kind, WORKOUT_COUNT thresholds ≥ 1.
func validate_registry(registry: ZoneRegistryData) -> bool:
	if registry == null or registry.zones.is_empty():
		push_error("[ZoneSystem] registry missing/empty (EC-4)")
		return false
	var seen: Dictionary = {}
	for zone: ZoneDef in registry.zones:
		if zone == null or zone.zone_id == &"":
			push_error("[ZoneSystem] null/unnamed zone entry (EC-6)")
			return false
		if seen.has(zone.zone_id):
			push_error("[ZoneSystem] duplicate zone_id '%s' (EC-6)" % zone.zone_id)
			return false
		seen[zone.zone_id] = true
		var cond: ZoneUnlockCondition = zone.unlock_condition
		if cond == null or cond.kind == ZoneUnlockCondition.Kind.UNKNOWN:
			push_error("[ZoneSystem] zone '%s': missing/UNKNOWN unlock kind (EC-6, ADR-0007)" % zone.zone_id)
			return false
		if cond.kind == ZoneUnlockCondition.Kind.WORKOUT_COUNT and cond.threshold < 1:
			push_error("[ZoneSystem] zone '%s': WORKOUT_COUNT threshold must be ≥1 (EC-6)" % zone.zone_id)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════
# Read surfaces (Story 002)
# ═══════════════════════════════════════════════════════════════════════════

## MVP: the active zone is fixed to registry entry 0 (the ALWAYS zone).
## v0.2: player selection, locked per-day at workout start (Rule 9).
func get_active_zone() -> ZoneDef:
	if _registry == null or _registry.zones.is_empty():
		return null
	return _registry.zones[0]


## Available = derived ALWAYS ∪ persisted earned (Rule 4 — ALWAYS is never persisted).
func is_zone_unlocked(zone_id: StringName) -> bool:
	if _zone_state.unlocked_zone_ids.has(zone_id):
		return true
	if _registry == null:
		return false
	for zone: ZoneDef in _registry.zones:
		if zone.zone_id == zone_id and zone.unlock_condition != null \
				and zone.unlock_condition.kind == ZoneUnlockCondition.Kind.ALWAYS:
			return true
	return false


func get_unlocked_zone_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _registry != null:
		for zone: ZoneDef in _registry.zones:
			if zone.unlock_condition != null \
					and zone.unlock_condition.kind == ZoneUnlockCondition.Kind.ALWAYS:
				out.append(zone.zone_id)
	for id: StringName in _zone_state.unlocked_zone_ids:
		if not out.has(id):
			out.append(id)
	return out


# ═══════════════════════════════════════════════════════════════════════════
# Training-day count (Story 004) — Rule 2 / Formula
# ═══════════════════════════════════════════════════════════════════════════

## #9 workout_completed_forwarded handler. completed_at is unix MS
## (workout_state_tracker.gd:68) — ÷1000 before the seconds-based date API
## (a missed unit pin silently kills the per-day cap = the farming defence).
func _on_workout_completed_forwarded(completed_at: int, transition_id: String) -> void:
	if transition_id == _zone_state.last_counted_transition_id:
		return  # replay dedup (EC-2)
	@warning_ignore("integer_division")
	var day: String = Time.get_date_string_from_unix_time(completed_at / 1000)
	if day <= _zone_state.last_counted_date:
		return  # monotone guard: per-day cap 1 + stale-replay no-op (epoch resync)
	_zone_state.workout_count += 1
	_zone_state.last_counted_transition_id = transition_id
	_zone_state.last_counted_date = day
	var newly: Array[StringName] = _evaluate_unlocks()
	_commit_and_emit(newly, false)


# ═══════════════════════════════════════════════════════════════════════════
# Unlock evaluation + write-success-then-emit (Story 005) — Rules 3/4/5
# ═══════════════════════════════════════════════════════════════════════════

## Scan registry for satisfiable not-yet-unlocked WORKOUT_COUNT zones; appends
## (unlocked + ceremony) happen in-memory — _commit_and_emit owns the
## write-then-emit ordering and the two-append rollback.
func _evaluate_unlocks() -> Array[StringName]:
	var newly: Array[StringName] = []
	if _registry == null:
		return newly
	for zone: ZoneDef in _registry.zones:
		var cond: ZoneUnlockCondition = zone.unlock_condition
		if cond == null or cond.kind != ZoneUnlockCondition.Kind.WORKOUT_COUNT:
			continue
		if _zone_state.unlocked_zone_ids.has(zone.zone_id):
			continue  # idempotent (EC-2)
		if _zone_state.workout_count >= cond.threshold:
			_zone_state.unlocked_zone_ids.append(zone.zone_id)
			_zone_state.ceremony_pending.append(zone.zone_id)
			newly.append(zone.zone_id)
	return newly


## Rule 5 binding (#8 Rule 7 milestone-unlock template, streak-system.md:285-293):
## write returns true BEFORE any emit; on false both appends roll back
## (count/cursors deliberately keep — in-memory carries to the next successful
## write; a boot reload of the older value is self-consistent and the sweep heals).
func _commit_and_emit(newly: Array[StringName], anchor_even_if_empty: bool) -> void:
	if newly.is_empty() and not anchor_even_if_empty:
		_persist_state(false)  # count/cursor-only change
		return
	var flush: bool = not newly.is_empty()  # unlock = anchor moment
	if _persist_state(flush):
		for zone_id: StringName in newly:
			zone_unlocked.emit(zone_id)
			_emit_telemetry("zone.unlocked", {"zone_id": String(zone_id)})
	else:
		for zone_id: StringName in newly:
			_zone_state.unlocked_zone_ids.erase(zone_id)
			_zone_state.ceremony_pending.erase(zone_id)
		# ceremony un-placed + territory un-granted — three faces stay consistent;
		# the next boot sweep re-evaluates from the persisted count (EC-7).


# ═══════════════════════════════════════════════════════════════════════════
# Boot sweep (Story 006) — Rule 7
# ═══════════════════════════════════════════════════════════════════════════

## Pure local recompute: unlocks are a derivation of workout_count, so the sweep
## IS the recovery path (no backend surface exists — EC-1). Idempotent; re-run free.
func _retroactive_sweep() -> void:
	var newly: Array[StringName] = _evaluate_unlocks()
	if not newly.is_empty():
		_commit_and_emit(newly, false)


# ═══════════════════════════════════════════════════════════════════════════
# Ceremony queue (Story 007) — Rule 6
# ═══════════════════════════════════════════════════════════════════════════

## Consumer (#20/#29 — BLOCKED-ON their surfaces) drains the whole queue at once
## and renders ONE aggregated reveal (「3 個 zone 迷霧散開」), never N toasts.
## Drain persists; a failed write does NOT roll the drain back (the ceremony was
## delivered — a next-boot replay over-delivers, the accepted direction).
func drain_ceremony_queue() -> Array[StringName]:
	var out: Array[StringName] = _zone_state.ceremony_pending.duplicate()
	if out.is_empty():
		return out
	_zone_state.ceremony_pending.clear()
	_persist_state(false)
	return out


# ═══════════════════════════════════════════════════════════════════════════
# Persistence (Story 003) — Rule 5 envelope
# ═══════════════════════════════════════════════════════════════════════════

func _load_state() -> void:
	if _persistence == null:
		return
	var raw: Variant = _persistence.read("zone.state")
	if raw == null:
		return  # fresh install
	if raw is Dictionary:
		_zone_state = ZoneState.from_dict(raw)
	else:
		# EC-1: corrupt manifest → ALWAYS zones stay available (derived);
		# earned unlocks re-derive from count via the sweep; count itself is the
		# only non-derivable primary state — honest reset + CRITICAL telemetry.
		_zone_state = ZoneState.new()
		_emit_telemetry("zone.manifest_corrupt", {})


func _persist_state(flush: bool) -> bool:
	if _persistence == null:
		return false
	var ok: bool = _persistence.write("zone.state", _zone_state.to_dict(), flush)
	if not ok:
		_emit_telemetry("zone.persist_failed", {"flush": flush})
	return ok


func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data})
