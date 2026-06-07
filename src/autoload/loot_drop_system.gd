## LootDropSystem — Autoload position 7 (#15)
##
## Status: PARTIAL — Stories 004 (ceremony_cap) + 009 (boot/state/private-mode) implemented.
##   Signal handlers (boss_killed/enemy_killed/workout_completed): Story 011.
##   5-step persistence lifecycle: Story 012.
##   Autoload pos-7 registration in project.godot: Story 014 (BLOCKED on #14).
##
## Driving GDD : design/gdd/loot-drop-system.md (Pass 2 Revised 2026-05-28)
## Governing ADRs:
##   ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula
##   ADR-0003 (Accepted 2026-05-30) Save State Strategy — Private Mode gate
##   ADR-0006 (Accepted) Contracts 1/2/3/4/5/6/8/11 — connect_for_initial_state, boot order
##   ADR-0009 (Accepted 2026-05-29) Signal Payload Schema — late-bind workout_id
##
## CRITICAL boot ordering: MUST boot at position 7 (after #14 EnemyDirector, before
## #21 LootRevealModal). Registration deferred to Story 014 (BLOCKED on #14 impl).
##
## NOTE: NO `class_name` — this script is registered as the `LootDropSystem` autoload
## singleton in project.godot. Adding a matching `class_name` would error
## "hides an autoload singleton". Tests preload this script via
## `const LootDropSystem := preload(...)` to access enums / new() / constants.
extends Node


# ── State machine ─────────────────────────────────────────────────────────────

## ADR-0007 Family A (Outcome/State): ordinal 0 = BOOTING is the safe uninitialised
## default. Persisted transitions should treat 0 as "not yet ready".
enum State {
	BOOTING    = 0,  ## Boot in progress — triggers buffered, not processed
	IDLE       = 1,  ## Ready, no pending reveal
	PENDING    = 2,  ## At least one LootDrop in reveal queue
	REVEALING  = 3,  ## #21 modal open
	SUSPENDED  = 4,  ## App backgrounded / bfcache stored
	DISABLED   = 5,  ## Private Mode — all trigger events short-circuit
}

var _state: State = State.BOOTING


# ── Ceremony cap constants (Story 004, GDD Rule 6, Formula 2) ─────────────────

## Per-workout mini-boss + workout-daily ceremony pool cap (DESIGN-FROZEN).
const MINI_BOSS_CEREMONY_CAP: int = 5

## Final-boss ceremony reservation (LOCKED — never 0, never > 1).
const FINAL_BOSS_RESERVED: int = 1

## Days used by housekeeping sweep to evict stale counter entries.
const HARD_CAP_DAYS: int = 37

## Emergency LRU ceiling — mini pool never grows past this many workout entries.
const MINI_POOL_MAX_ENTRIES: int = 500

## Current LootDrop schema version — bump when adding new fields to LootDrop.to_dict().
const CURRENT_SCHEMA: int = 1


# ── DI seams (untyped — typed Node fails compile-time member check) ────────────
## Per project pattern: inject before add_child / _ready() in tests.

var _persistence = null       ## #3 PersistenceLayer
var _gsm = null               ## #1 GameStateMachine

## #21 G-LM-4c (8): fast-victory marker buffer — workout_id whose LOOT_DROP
## entry carried BossOutcome.INTERRUPTED_WITH_CREDIT. The transition payload
## is gone by deferred-reveal time; the LootDrop record is the only durable
## carrier, so the grant stamps item_metadata["fast_victory"] from here.
var _fast_victory_workout_ids: Dictionary = {}
var _streak_system = null     ## #8 StreakSystem
var _workout_tracker = null   ## #9 WorkoutStateTracker
var _enemy_director = null    ## #14 EnemyDirector
var _boss_system = null       ## #16 BossSystem
var _gymsys_client = null     ## #2 GymSysBackendClient

## LootRarityConfig — can be injected in tests to bypass disk load.
var _config: LootRarityConfig = null


# ── Signals ────────────────────────────────────────────────────────────────────

## Minimal payload per ADR-0009: drop_id + rarity_tier (String name) + item_type + transition_id.
## CI lint check_loot_signal_payload_minimal.gd enforces no full LootDrop object here.
signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)

## Emitted once per pending drop restored on boot (bfcache/reconcile path).
signal loot_pending_recovered(drop_id: String, source_event_kind: String)

## Emitted when system enters Disabled state (Private Mode / config missing / persistence fail).
## Receivers (#21) show a non-dismissible banner.
signal loot_disabled(reason: String)

## Emitted after backend ACK renames pending→committed.
signal loot_committed(drop_id: String, canonical_id_from_backend: String)

## Emitted when the mini ceremony pool cap is hit (telemetry + #28 Analytics).
signal loot_ceremony_capped(workout_id: String, capped_kill_count: int)

## Emitted when boot sequence completes successfully.
signal boot_completed

## Emitted when optimistic persist fails → #21 must cancel the reveal animation.
signal loot_rollback(drop_id: String)

## Emitted for MICRO_ACK ceremony tier (0.15s toast — no full reveal modal).
signal loot_micro_ack(drop_id: String)

## #21 G-LM-4b/4c (4): emitted on every TERMINAL dismissal — GSM subscribes
## this to exit LOOT_DROP (GSM AC-14 zero-direct-call chain; #21 NEVER calls
## GSM). queue_drained is intrinsic event data (ADR-0009): true ⇒ GSM clears
## loot_reveal_pending; false (catch-up defer — items remain) ⇒ flag survives
## so the NEXT safe-state occupancy re-offers (G-LM-4 (6) suppression stops
## the same-occupancy loop).
signal loot_confirmed(queue_drained: bool)


# ── Internal state ─────────────────────────────────────────────────────────────

## drop_id → LootDrop — the backend-SYNC ledger (ACK erases entries here).
## NOT the reveal queue — see _reveal_pending (#21 G-LM-4a).
var _pending_drops: Dictionary = {}

## #21 G-LM-4a (1): the REVEAL queue — FULL_CEREMONY, not-yet-revealed drops only.
## SEPARATE from _pending_drops (the backend-SYNC ledger): a backend ACK (which
## erases the sync entry within seconds) must NEVER evaporate an unrevealed drop
## out of the reveal queue, and a reveal dequeue must NEVER skip the
## loot.pending -> loot.committed rename. drop_id -> LootDrop.
var _reveal_pending: Dictionary = {}

## transition_id → LootDrop (idempotency cache — Rule 9).
var _drops_by_transition: Dictionary = {}

## Per-workout-id counter for MINI_BOSS + WORKOUT_DAILY ceremonies (cap = 5).
## Carried over from Story 004.
var _emit_counter_mini: Dictionary = {}

## Per-workout-id counter for FINAL_BOSS ceremonies (reserved = 1).
var _emit_counter_final: Dictionary = {}

## Telemetry event log — append-only. Tests inspect via get_telemetry().
var _telemetry_log: Array[Dictionary] = []

## Seeded RNG — must NOT use global randf()/randi() (CI lint AC-26).
var _rng := RandomNumberGenerator.new()


# ── Lifecycle ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	# ADR-0006 Contract 8: assert knob invariants BEFORE reconciliation.
	_assert_knob_invariants()

	# ── Step 1: Load LootRarityConfig (fail-hard if missing — EC-03) ──────────
	if _config == null:
		_config = load("res://assets/data/loot/loot_rarity_config.tres")
	if _config == null:
		push_error("[LootDropSystem] LootRarityConfig missing — EC-03 hard fail, entering Disabled")
		_enter_disabled("config_missing")
		return
	_config._validate()  # INV-1 + INV-6 asserts (debug build)

	# ── Step 2: connect_for_initial_state GSM (ADR-0006 Contract 6) ──────────
	if _gsm != null:
		# Contract 6: use connect_for_initial_state, NOT direct state_changed.connect().
		# Contract 6 Addendum: do NOT pass .bind() callables.
		_gsm.connect_for_initial_state(_on_gsm_state_changed)
		# #21 G-LM-4c: reverse-wire the exit chain (#15 boots after GSM).
		if _gsm.has_method("on_loot_confirmed"):
			loot_confirmed.connect(_gsm.on_loot_confirmed)

	# ── Private Mode gate (ADR-0003) — check BEFORE any persistence reads ─────
	if _persistence != null and _persistence.is_private_mode():
		_enter_disabled("private_mode")
		return

	# ── Step 3: Restore pending drops from PersistenceLayer ──────────────────
	if _persistence != null:
		_restore_pending_drops()
		# Subscribe to mid-session private mode detection (Story 009 AC-24).
		if _persistence.has_signal("private_mode_detected"):
			_persistence.private_mode_detected.connect(_on_private_mode_detected)

	# ── Step 4: await backend_ready (race guard — no signal subscriptions yet) ─
	if _gymsys_client != null:
		await _gymsys_client.backend_ready

	# ── Step 5: Subscribe upstream signals (Story 014 — #9/#14 now Complete) ──
	# Resolve DI seams to production autoloads if not injected by tests.
	if _enemy_director == null:
		_enemy_director = EnemyDirector
	if _workout_tracker == null:
		_workout_tracker = WorkoutStateTracker
	# EnemyDirector.enemy_killed is an event broadcast (not initial-state sentinel).
	# LootDrop boots at pos 9 BEFORE EnemyDirector (pos 10); by this await point all
	# autoloads are constructed. Use raw .connect() — NOT connect_for_initial_state.
	if _enemy_director != null and _enemy_director.has_signal("enemy_killed"):
		_enemy_director.enemy_killed.connect(_on_enemy_killed_payload)
	# WorkoutStateTracker boots at pos 8 BEFORE LootDrop (pos 9) — safe to connect here.
	if _workout_tracker != null and _workout_tracker.has_signal("workout_completed_forwarded"):
		_workout_tracker.workout_completed_forwarded.connect(_on_workout_completed_forwarded)

	# ── Step 6: TTL check on restored pending drops ────────────────────────────
	_check_pending_ttl()

	_state = State.IDLE
	boot_completed.emit()
	print("[LootDropSystem] boot complete — state=IDLE (Stories 004+009 loaded)")


# ── Public API (Story 009) ────────────────────────────────────────────────────

## Register a callback to receive `loot_dropped` events (Observer pattern).
## Preferred over direct signal.connect() to allow future middleware.
func subscribe(callback: Callable) -> void:
	if not loot_dropped.is_connected(callback):
		loot_dropped.connect(callback)


## Returns a copy of all reveal-pending (FULL_CEREMONY, unrevealed) LootDrop
## instances — the #21 reveal flow's source of truth (G-LM-4a (2): micro_ack
## records bank via Rule 9 and never appear here).
func get_pending_drops() -> Array:
	return _reveal_pending.values()


## Returns the LootDrop for the given drop_id, or null if not found.
## Checks the sync ledger first, then the reveal queue — a backend-ACKed but
## not-yet-revealed drop is only findable in the reveal queue (G-LM-4a (1)).
func get_drop(drop_id: String) -> LootDrop:
	var drop = _pending_drops.get(drop_id)
	return drop if drop != null else _reveal_pending.get(drop_id)


## #21 G-LM-4b (3): reveal-dequeue handler — #21's modal_dismissed wires in
## here (reverse-wire: #21 boots last and connects in its _ready, #18 G-PR-2
## precedent). Dequeues BY drop_id (catch-up may reorder — never head-pop);
## EC-29 double-dismiss is a silent no-op. Marks the record revealed and
## refreshes the on-disk pending snapshot so a reboot never re-reveals a
## banked item — WITHOUT touching the sync ledger (the ACK rename is sacred).
func on_modal_dismissed(drop_id: String, terminal: bool) -> void:
	if drop_id != "":
		_reveal_pending.erase(drop_id)
		var drop = get_drop(drop_id)
		if drop != null and not drop.revealed:
			drop.revealed = true  # micro_ack 件都標 — acknowledged 語意統一
			# Refresh the pending snapshot only if the ACK hasn't renamed it yet.
			if _pending_drops.has(drop_id) and _persistence != null and _persistence.has_method("write"):
				_persistence.write("loot.pending." + drop_id, drop.to_dict())
	if terminal:
		loot_confirmed.emit(_reveal_pending.is_empty())


## #21 G-LM-4b (5): EC-1 recovery chain — #21 is stateless presentation and
## cannot write persistence; a FAILED_ROLLBACK at S3/micro-ack reports here
## and #15 (the loot.pending.* sole writer) records the recovery entry.
## Deduped: the re-entrant defer path also returns FAILED_ROLLBACK (true/false
## indistinguishable at the caller) — a repeat report is a harmless no-op.
func report_receive_failure(drop_id: String) -> void:
	if _persistence == null or drop_id.is_empty():
		return
	var key: String = "loot.pending.recovery." + drop_id
	if _persistence.read(key) != null:
		return  # dedupe — defer-path false alarms land here
	var drop = get_drop(drop_id)
	_persistence.write(key, drop.to_dict() if drop != null else {"drop_id": drop_id})
	_emit_telemetry("loot.receive_failure_reported", {"drop_id": drop_id})


## Returns true when the system is in Disabled state due to Private Mode.
func is_private_mode_blocked() -> bool:
	return _state == State.DISABLED


# ── State transitions ─────────────────────────────────────────────────────────

## Enter Disabled state — used for Private Mode, missing config, persistence failure.
func _enter_disabled(reason: String) -> void:
	_state = State.DISABLED
	loot_disabled.emit(reason)
	_emit_telemetry("loot_disabled", {"reason": reason})


## Handle mid-session Private Mode detection (AC-24).
## Already-revealed volatile state is preserved; new triggers short-circuit.
func _on_private_mode_detected() -> void:
	if _state == State.DISABLED:
		return  # Already disabled — no double-emit.
	_enter_disabled("private_mode")


## GSM state-change handler (ADR-0006 Contract 6 sentinel pattern).
## #21 G-LM-4c (8): captures the fast-victory marker off the transition payload
## (BossOutcome.INTERRUPTED_WITH_CREDIT string name — Contract 3 serialization).
## Both orders covered: marker-before-grant buffers; marker-after-grant patches
## the already-granted record and refreshes its pending snapshot.
func _on_gsm_state_changed(_from, _to, _payload) -> void:
	# Suspend/resume handling wired in Story 009 (partial) and Story 012 (full).
	if _payload == null or not (_payload is Object and "data" in _payload):
		return
	var data = _payload.data
	if not (data is Dictionary):
		return
	var boss_dict = data.get("boss")
	if not (boss_dict is Dictionary):
		return
	if str(boss_dict.get("outcome", "")) != "INTERRUPTED_WITH_CREDIT":
		return
	var workout_id: String = str(data.get("workout_id", ""))
	if workout_id.is_empty():
		return
	_fast_victory_workout_ids[workout_id] = true
	# Late-marker order: the workout-completion drop may already be granted.
	if _drops_by_transition.has(workout_id):
		var drop: LootDrop = _drops_by_transition[workout_id]
		if not bool(drop.item_metadata.get("fast_victory", false)):
			drop.item_metadata["fast_victory"] = true
			if _pending_drops.has(drop.drop_id) and _persistence != null and _persistence.has_method("write"):
				_persistence.write("loot.pending." + drop.drop_id, drop.to_dict())


## Short-circuit guard for all trigger event handlers (Rule 16).
## Call at the start of _handle_*_killed() and _handle_workout_completed().
func _is_trigger_blocked() -> bool:
	return _state == State.DISABLED


# ── Boot helpers ───────────────────────────────────────────────────────────────

## Assert knob invariants before boot (ADR-0006 Contract 8).
## Must be called first in _ready(), before any reconciliation.
func _assert_knob_invariants() -> void:
	assert(MINI_BOSS_CEREMONY_CAP >= 2,
		"INV-G2: MINI_BOSS_CEREMONY_CAP must be ≥ 2 (Pillar 3 guard)")
	assert(FINAL_BOSS_RESERVED == 1,
		"FINAL_BOSS_RESERVED must be exactly 1 (LOCKED)")
	assert(MINI_POOL_MAX_ENTRIES > 0,
		"MINI_POOL_MAX_ENTRIES must be > 0")


## Check TTL on restored pending drops (Step 6 stub).
## Full implementation uses LootTtlCalc.pending_ttl_expired() (Story 005).
func _check_pending_ttl() -> void:
	# Story 012 will iterate _pending_drops and call LootTtlCalc.pending_ttl_expired().
	_housekeeping_sweep_counters()


# ── Ceremony cap (Story 004) ────────────────────────────────────────────────────

## Gate each loot-granting event through the ceremony-budget pools.
## Formula 2 (GDD §D Formula 2, Rule 6, INV-9, ADR-0009 §7.5).
## See Story 004 for full documentation.
func _ceremony_cap_check(kind: int, workout_id_or_null) -> int:
	# ADR-0009 §2 mandatory null branch.
	if workout_id_or_null == null:
		_emit_telemetry("loot_drop_unbound", {"reason": "no_active_workout"})
		return LootEnums.CeremonyDecision.NON_CEREMONY_ROUTE

	var wid: String = str(workout_id_or_null)

	if kind == LootEnums.SourceEventKind.FINAL_BOSS:
		var final_current: int = _emit_counter_final.get(wid, 0)
		if final_current >= FINAL_BOSS_RESERVED:
			_emit_telemetry("loot_final_boss_ceremony_overflow", {"workout_id": wid})
			return LootEnums.CeremonyDecision.FULL_CEREMONY
		_emit_counter_final[wid] = final_current + 1
		return LootEnums.CeremonyDecision.FULL_CEREMONY

	# MINI_BOSS or WORKOUT_DAILY → mini pool.
	var mini_current: int = _emit_counter_mini.get(wid, 0)
	if mini_current >= MINI_BOSS_CEREMONY_CAP:
		var seq_num: int = mini_current + 1
		_emit_telemetry("loot_ceremony_capped", {
			"workout_id": wid, "capped_kill_count": seq_num
		})
		_emit_telemetry("loot_micro_ack_triggered", {
			"workout_id": wid, "mini_boss_seq_num": seq_num
		})
		loot_ceremony_capped.emit(wid, seq_num)
		return LootEnums.CeremonyDecision.MICRO_ACK

	_emit_counter_mini[wid] = mini_current + 1
	return LootEnums.CeremonyDecision.FULL_CEREMONY


## Evict stale/excess entries from ceremony-cap counters.
func _housekeeping_sweep_counters() -> void:
	if _emit_counter_mini.size() > MINI_POOL_MAX_ENTRIES:
		var oldest_key: String = _emit_counter_mini.keys()[0]
		_emit_counter_mini.erase(oldest_key)
		_emit_telemetry("loot_counter_emergency_evict", {"evicted_key": oldest_key})


# ── Telemetry ─────────────────────────────────────────────────────────────────

## Record a telemetry event. Appended to _telemetry_log for tests + #28 forwarding.
func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data.duplicate()})
	# TODO Story 028: forward to TelemetrySystem.record(event, data)


## Return all telemetry events with the given name (for test assertions).
func get_telemetry(event_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _telemetry_log:
		if entry.get("event") == event_name:
			result.append(entry)
	return result


## Clear telemetry log (for test teardown).
func clear_telemetry() -> void:
	_telemetry_log.clear()


# ── Idempotency + Guards (Story 010) ─────────────────────────────────────────

## Debug-build override for testing release-guard behaviour (AC-25).
## Set to false in tests to simulate a release build without modifying OS.is_debug_build().
var _debug_build_override: bool = OS.is_debug_build()


## Generate or retrieve a LootDrop for the given transition_id.
## RULE 9 (INV-7): same transition_id → same LootDrop, no re-roll (idempotency).
## RULE 10 (EC-31): deterministic RNG seeded from transition_id.
##
## @param transition_id  Unique event identifier (ADR-0006 Contract 2 format).
## @param kind           LootEnums.SourceEventKind ordinal.
## @param workout_score  Pillar 1 signal; 0.0 forces COMMON via Formula 1.
## @return               LootDrop instance (cached or freshly generated).
func _generate_loot_internal(
	transition_id: String,
	kind: int,
	workout_score: float
) -> LootDrop:
	# Rule 9: return cached drop if seen before (idempotency, INV-7).
	if _drops_by_transition.has(transition_id):
		return _drops_by_transition[transition_id]

	# Compute final rarity tier via Formula 1.
	var rng_roll: float = _compute_rng_roll(transition_id)
	var raw_tier: int = LootRarityCalc.compute_rarity_from_score(workout_score, rng_roll, _config)
	var final_tier: int = LootRarityCalc.apply_tier_ceiling_floor(raw_tier, kind, workout_score)

	# Item type (Formula E1) and class affinity (Formula E2) — deterministic sub-rolls.
	var rng_roll_2: float = _compute_rng_roll(transition_id + "_itemtype")
	var rng_roll_3: float = _compute_rng_roll(transition_id + "_classtag")
	var item_type: int = LootItemCalc.item_type_weighted_selection(
		final_tier, _get_gear_gap(), _get_dominant_class(), rng_roll_2
	)
	var class_tag: int = LootItemCalc.class_affinity_resolution(
		item_type, _get_dominant_class(), rng_roll_3
	)

	# Build LootDrop record.
	var drop := LootDrop.new()
	drop.drop_id = _generate_drop_id()
	drop.transition_id = transition_id
	# #21 G-LM-4a (2b): breakdown carrier — ws/rr/score persist on the record
	# (the grant-time values otherwise evaporate; the RARE+ breakdown bar's
	# GIVEN is unconstructable without them — story-008 discovered gap).
	var clamped_ws: float = clampf(workout_score, 0.0, 1.0)
	drop.item_metadata["workout_score"] = clamped_ws
	drop.item_metadata["rng_roll"] = rng_roll
	drop.item_metadata["rarity_score"] = _config.workout_weight * clamped_ws + _config.rng_weight * rng_roll
	drop.rarity_tier = LootEnums.RarityTier.find_key(final_tier)
	drop.item_type = LootEnums.ItemType.find_key(item_type)
	drop.class_tag = LootEnums.ClassTag.find_key(class_tag)
	drop.source_event_kind = LootEnums.SourceEventKind.find_key(kind)
	drop.created_at_unix = int(Time.get_unix_time_from_system())
	drop.schema_version = 1

	# Cache for idempotency.
	_drops_by_transition[transition_id] = drop
	return drop


## Validate a transition_id before processing a trigger event (EC-12).
## Returns true if valid, false and emits telemetry if malformed.
func _validate_transition_id(tid) -> bool:
	if tid == null:
		_emit_telemetry("loot.trigger.malformed_id", {"reason": "null", "tid": ""})
		return false
	var tid_str: String = str(tid)
	if tid_str.is_empty():
		_emit_telemetry("loot.trigger.malformed_id", {"reason": "empty", "tid": ""})
		return false
	if tid_str.length() < 4:
		_emit_telemetry("loot.trigger.malformed_id", {"reason": "too_short", "tid": tid_str})
		return false
	return true


## Debug-only forced loot generation. MUST NOT exist in release builds (Rule 12, EC-34).
## In release: emits CRITICAL telemetry and crashes via assert (fail-loud).
## In debug: proceeds to generate a drop (testing only).
func _force_test_drop(rarity_tier: int) -> LootDrop:
	if not _debug_build_override:
		_emit_telemetry("loot.debug.production_leak", {
			"rarity": rarity_tier,
			"severity": "CRITICAL",
		})
		# Fail-loud via push_error (NOT assert(false), which would crash debug/test
		# builds — assert is also stripped in release so it gives no real protection).
		# The CI lint check_loot_force_drop_debug_only.gd is the compile-time guard;
		# this runtime guard refuses to fabricate (returns null) + emits a CRITICAL
		# telemetry alert. Same pattern as StatSystem DEBUG_OVERRIDE release guard.
		push_error("[LootDropSystem] _force_test_drop blocked in release build — debug API in production (Rule 12, EC-34)")
		return null
	# Debug path: generate a synthetic drop with the requested tier.
	var drop := LootDrop.new()
	drop.drop_id = _generate_drop_id()
	drop.transition_id = "debug_%d" % rarity_tier
	drop.rarity_tier = LootEnums.RarityTier.find_key(rarity_tier)
	drop.item_type = LootEnums.ItemType.find_key(LootEnums.ItemType.WEAPON)
	drop.class_tag = LootEnums.ClassTag.find_key(LootEnums.ClassTag.NEUTRAL)
	drop.created_at_unix = int(Time.get_unix_time_from_system())
	drop.schema_version = 1
	return drop


# ── Internal helpers (Story 010) ──────────────────────────────────────────────

## Deterministic RNG roll seeded from transition_id. Uses local _rng instance
## (NOT global randf() — CI lint AC-26 enforces this).
func _compute_rng_roll(seed_key: String) -> float:
	_rng.seed = hash(seed_key)
	return _rng.randf()


## Generate a unique drop_id for new drops. Uses the owned _rng (seeded from a
## monotonic counter + clock) — NOT global randi() (CI lint check_loot_rng_seeded).
## drop_id uniqueness does not need determinism; the seeded roll just avoids the
## forbidden global generator while staying collision-resistant via the tick prefix.
func _generate_drop_id() -> String:
	_rng.seed = hash("dropid_%d_%d" % [Time.get_ticks_usec(), _drop_id_counter])
	_drop_id_counter += 1
	return "D-%d-%d" % [Time.get_ticks_msec(), _rng.randi()]

## Monotonic counter to guarantee drop_id uniqueness even within the same tick.
var _drop_id_counter: int = 0


## Gear gap state — returns current inventory slot starter flags.
## Stub: returns empty dict until #17 Equipment & Inventory is implemented.
func _get_gear_gap() -> Dictionary:
	return {}


## Dominant class for Formula E2 — returns null until #9 WorkoutStateTracker provides data.
## null → EC-35 uniform fallback in LootItemCalc.class_affinity_resolution().
func _get_dominant_class():
	if _workout_tracker != null and _workout_tracker.has_method("get_dominant_ability_class"):
		return _workout_tracker.get_dominant_ability_class()
	return null


# ── Daily Token Gate + Trigger Routing (Story 011) ───────────────────────────

## UTC date override for tests — set to a fixed string (e.g. "2026-05-30") to
## decouple tests from the real clock. Leave empty ("") for production behaviour.
var _today_override: String = ""

## Known mini-boss tier strings (per #14 EnemyDirector + #16 BossSystem contract).
## Story 011 stub — tightened when #14 GDD is finalised.
const MINI_BOSS_TIERS: PackedStringArray = ["mini_boss", "miniboss", "sub_boss"]


# ── Daily token helpers ────────────────────────────────────────────────────────

## Returns today's UTC date as "YYYY-MM-DD". Uses _today_override when set (tests).
func _get_today_utc_string() -> String:
	if not _today_override.is_empty():
		return _today_override
	var dt := Time.get_datetime_dict_from_system(true)  # true = UTC
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Check if the daily token for today has already been consumed (EC-43).
## Uses PersistenceLayer as the local cache; backend is authoritative at claim time.
func _is_daily_token_already_used() -> bool:
	if _persistence == null:
		return false
	var key: String = "loot.daily_token_used." + _get_today_utc_string()
	return _persistence.read(key) != null


## Attempt to claim the daily token via GymSys backend (stub for Story 011).
## Production: POST /api/game/loot/claim-daily → {eligible: bool, daily_token: String}.
## Offline / test mode (no _gymsys_client): returns true (allow).
func _claim_daily_token() -> bool:
	if _gymsys_client == null:
		return true  # Offline or test mode — permissive.
	# TODO Story 013: await _gymsys_client.post_claim_daily()
	return true


## Write the "daily token used" marker to PersistenceLayer.
func _mark_daily_token_used() -> void:
	if _persistence == null:
		return
	var key: String = "loot.daily_token_used." + _get_today_utc_string()
	_persistence.write(key, {"used_at": int(Time.get_unix_time_from_system())})


# ── Trigger handlers ───────────────────────────────────────────────────────────

## Handle workout_completed — daily guaranteed drop (Rule 2 + AC-43).
## INV-12: workout_id is late-bound from #9.get_active_workout_id(), NOT the signal.
func _handle_workout_completed(workout_id: String, completed_exercises: int) -> void:
	if _is_trigger_blocked():
		return
	if not _validate_transition_id(workout_id):
		return

	# Daily token gate (AC-43).
	if _is_daily_token_already_used():
		_emit_telemetry("loot_daily_token_skipped", {
			"workout_id": workout_id,
			"reason": "already_consumed_today",
		})
		return

	# Claim token (synchronous stub in Story 011).
	if not _claim_daily_token():
		_emit_telemetry("loot_daily_token_skipped", {
			"workout_id": workout_id,
			"reason": "ineligible",
		})
		return
	_mark_daily_token_used()

	# Late-bind workout_id for ceremony cap (ADR-0009 §2 + INV-12).
	var workout_id_or_null = _workout_tracker.get_active_workout_id() if _workout_tracker else null
	var ceremony: int = _ceremony_cap_check(LootEnums.SourceEventKind.WORKOUT_DAILY, workout_id_or_null)
	var ws: float = _compute_workout_score_from_tracker()
	_process_loot_trigger(workout_id, LootEnums.SourceEventKind.WORKOUT_DAILY, ws, ceremony)


## Handle enemy_killed — mini-boss drops only (Rule 1 + EC-15).
## Non-mini-boss tiers → SILENT early return (no telemetry per GDD telemetry hygiene).
func _handle_enemy_killed(transition_id: String, faction: String, tier: String) -> void:
	if _is_trigger_blocked():
		return
	if not _validate_transition_id(transition_id):
		return
	# EC-15: non-mini-boss tiers → silent drop, NO telemetry.
	if not _is_mini_boss_tier(tier):
		return

	var workout_id_or_null = _workout_tracker.get_active_workout_id() if _workout_tracker else null
	var ceremony: int = _ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, workout_id_or_null)
	var ws: float = _compute_workout_score_from_tracker()
	_process_loot_trigger(transition_id, LootEnums.SourceEventKind.MINI_BOSS, ws, ceremony)


## Signal adapter — Story 014 (AC-44).
## Bridges EnemyDirector.enemy_killed(EnemyKilledPayload) → _handle_enemy_killed(String,String,String).
## EnemyDirector surface is locked to enemy_killed (no boss_killed signal);
## boss kills arrive here with enemy_id matching the boss template id.
## Tier is derived from enemy_id: if it contains "mini" the EnemyTemplate is a
## mini-boss flavour; otherwise it is treated as a regular enemy (silent skip in handler).
## Boss final-boss path deferred to #16 Boss System integration (Story scope boundary).
func _on_enemy_killed_payload(payload: EnemyKilledPayload) -> void:
	var id_lower: String = payload.enemy_id.to_lower()
	var tier: String = "mini_boss" if id_lower.contains("mini") else "enemy"
	_handle_enemy_killed(payload.transition_id, "enemy", tier)


## Signal adapter — Story 014 (AC-32 / AC-42).
## Bridges WorkoutStateTracker.workout_completed_forwarded(completed_at, transition_id)
## → _handle_workout_completed(workout_id, completed_exercises).
## WST emits transition_id as the workout key; the handler validates it as workout_id.
## completed_exercises is 0 here — the handler derives exercise data internally via
## _compute_workout_score_from_tracker() (reads WST directly, not from the signal payload).
func _on_workout_completed_forwarded(completed_at: int, transition_id: String) -> void:
	# completed_at not used by the handler (workout timing is WST's concern).
	var _discard_at: int = completed_at
	_handle_workout_completed(transition_id, 0)


## Handle boss_killed — final-boss drop with UNCOMMON floor (Rule 5).
func _handle_boss_killed(transition_id: String, boss_id: String, _tier: String) -> void:
	if _is_trigger_blocked():
		return
	if not _validate_transition_id(transition_id):
		return

	var workout_id_or_null = _workout_tracker.get_active_workout_id() if _workout_tracker else null
	var ceremony: int = _ceremony_cap_check(LootEnums.SourceEventKind.FINAL_BOSS, workout_id_or_null)
	var ws: float = _compute_workout_score_from_tracker()
	_process_loot_trigger(transition_id, LootEnums.SourceEventKind.FINAL_BOSS, ws, ceremony)


# ── Trigger routing stub ───────────────────────────────────────────────────────

## Generate a LootDrop and route it through the 5-step optimistic persist pipeline.
##
## GDD Section C — 5-Step Persistence Lifecycle (Story 012):
##   Step 1: Generate LootDrop in memory.
##   Step 2: OPTIMISTIC emit (before await) — satisfies FR-2 100ms visual onset.
##   Step 3: await PL.write_async("loot.pending.<drop_id>") — Safari IDB can be slow.
##   Step 4: Rollback on write failure — loot_rollback + loot_disabled emit.
##   Step 5: Background backend POST (fire-and-forget, no await; ACK in _on_backend_ack).
##
## This function is a coroutine (contains await). Callers fire-and-forget (no await).
func _process_loot_trigger(
	transition_id: String,
	kind: int,
	workout_score: float,
	ceremony: int
) -> void:
	# Step 1: generate LootDrop in memory.
	var drop := _generate_loot_internal(transition_id, kind, workout_score)
	if drop == null:
		return
	# #21 G-LM-4a (2): routing kind set BEFORE the Step-3 persist snapshot —
	# the on-disk record must carry it for deferred-reveal rehydration.
	drop.ceremony_kind = LootEnums.CeremonyDecision.find_key(ceremony)
	# #21 G-LM-4c (8): fast-victory stamp (workout-completion path keys the
	# trigger by workout_id == transition_id).
	if kind == LootEnums.SourceEventKind.WORKOUT_DAILY and _fast_victory_workout_ids.has(transition_id):
		drop.item_metadata["fast_victory"] = true

	# Step 2: OPTIMISTIC emit before any async operation (FR-2 100ms visual onset).
	# MICRO_ACK is NOT optimistic (#21 G-LM-4b fix): it has no visual-onset
	# deadline, and its consumer banks IMMEDIATELY via get_drop() — emitting
	# before registration guarantees a null lookup. It emits post-registration.
	if ceremony == LootEnums.CeremonyDecision.FULL_CEREMONY:
		loot_dropped.emit(drop.drop_id, drop.rarity_tier, drop.item_type, drop.transition_id)
	# NON_CEREMONY_ROUTE: silent persist, no ceremony signal.

	# Step 3: Async persist to loot.pending namespace.
	var write_key: String = "loot.pending." + drop.drop_id
	var write_ok: bool = false
	if _persistence != null and _persistence.has_method("write_async"):
		write_ok = await _persistence.write_async(write_key, drop.to_dict())
	elif _persistence != null:
		write_ok = _persistence.write(write_key, drop.to_dict())
		# Fallback synchronous path (test mocks that lack write_async).

	# Step 4: Rollback on write failure (EC-17).
	if not write_ok:
		loot_disabled.emit("persistence_unavailable")
		loot_rollback.emit(drop.drop_id)  # #21 cancels the reveal animation.
		_emit_telemetry("loot_optimistic_rollback", {"drop_id": drop.drop_id})
		_drops_by_transition.erase(drop.transition_id)  # clean idempotency cache
		return

	# Persist succeeded — drop is now in the pending (sync) ledger.
	_pending_drops[drop.drop_id] = drop
	# #21 G-LM-4a (2): FULL_CEREMONY joins the reveal queue — micro_ack
	# records bank instantly via Rule 9 and never enter it.
	if ceremony == LootEnums.CeremonyDecision.FULL_CEREMONY:
		_reveal_pending[drop.drop_id] = drop
	elif ceremony == LootEnums.CeremonyDecision.MICRO_ACK:
		# Post-registration emit — the Rule 9 banking consumer's get_drop()
		# must resolve (G-LM-4b ordering fix; rollback race also closed:
		# a failed persist never acks).
		loot_micro_ack.emit(drop.drop_id)
	_state = State.PENDING
	_on_loot_persisted(drop)  # transition_id format validation (AC-37)

	# Step 5: Fire-and-forget backend POST (Story 013 wires real ACK).
	if _gymsys_client != null and _gymsys_client.has_method("post_loot_async"):
		_gymsys_client.post_loot_async(drop)


# ── Trigger helpers ────────────────────────────────────────────────────────────

## Returns true if the given tier string matches the mini-boss bucket (per #14/#16 contract).
## Stub tier list — tightened when #14 EnemyDirector GDD is finalised.
func _is_mini_boss_tier(tier: String) -> bool:
	return tier.to_lower() in MINI_BOSS_TIERS


## Derive workout_score from #9 WorkoutStateTracker if available.
## Falls back to 0.5 (neutral middle score) when tracker is absent.
func _compute_workout_score_from_tracker() -> float:
	if _workout_tracker == null:
		return 0.5
	# If the tracker provides a pre-computed score:
	if _workout_tracker.has_method("get_workout_score"):
		return _workout_tracker.get_workout_score()
	# Fallback: derive from raw counters.
	return 0.5


# ── Persistence + Schema Migration (Story 012) ────────────────────────────────

## Validate and log any transition_id format issues after persisting a LootDrop (AC-37).
## ADR-0006 Contract 2 format: "%d_%d_%s_%s" — digits + underscores + uppercase state names.
func _on_loot_persisted(drop: LootDrop) -> void:
	if not _validate_transition_id_format(drop.transition_id):
		push_error("[LootDropSystem] transition_id format violation in persisted drop: '%s'" % drop.transition_id)
		_emit_telemetry("loot.persist.transition_id_format_error", {
			"drop_id": drop.drop_id,
			"transition_id": drop.transition_id,
		})


## Validate transition_id conforms to ADR-0006 Contract 2 format (AC-37).
## Lenient pattern: digits + hex chars + underscores + uppercase letters.
## Minimum length: 4 characters.
func _validate_transition_id_format(tid: String) -> bool:
	if tid.length() < 4:
		return false
	# ADR-0006 Contract 2 format is "%d_%d_%s_%s" where %s are GSM state names
	# (full uppercase words like IDLE / COMBAT_ACTIVE). Allow alphanumeric +
	# underscore — NOT just hex (state names contain non-hex letters).
	var regex := RegEx.new()
	if regex.compile("^[0-9a-zA-Z_]+$") != OK:
		return false  # Defensive: regex compile failure
	return regex.search(tid) != null


## Restore pending drops from PersistenceLayer with schema migration (Step 3 full impl).
## Reads all loot.pending.* keys, migrates older schema versions, quarantines
## unresolvable entries. Replaces the Story 009 stub.
func _restore_pending_drops() -> void:
	if _persistence == null:
		return
	# Read all pending keys — PL must expose a list method in full impl.
	# For Story 012 stub: iterate known pending drop_ids stored in _pending_drops.
	# Full implementation (Story 013+): read from PL namespace scan.
	var keys_to_process: Array = []
	if _persistence.has_method("list_keys"):
		keys_to_process = _persistence.list_keys("loot.pending.")
	# If PL can't list keys, skip — Story 013 will handle the full namespace read.
	for key: String in keys_to_process:
		var raw: Variant = _persistence.read(key)
		if raw == null or not raw is Dictionary:
			continue
		var drop_dict: Dictionary = raw
		var migrated := _migrate_pending_drop(drop_dict)
		if migrated.is_empty():
			continue  # quarantined
		var drop := LootDrop.from_dict(migrated)
		if drop == null:
			continue
		_pending_drops[drop.drop_id] = drop
		_drops_by_transition[drop.transition_id] = drop
		# #21 G-LM-4a (1): only FULL_CEREMONY + not-yet-revealed records re-enter
		# the reveal queue — a revealed-but-unsynced record stays sync-pending
		# only (re-revealing a banked item is the anti-flashbulb).
		if drop.ceremony_kind == "FULL_CEREMONY" and not drop.revealed:
			_reveal_pending[drop.drop_id] = drop


## Migrate a pending drop dict from an older schema version to CURRENT_SCHEMA (AC-35).
## Current schema = 1. Migration table is empty (schema 1 is the first version).
## Returns {} for unresolvable entries (quarantine path).
func _migrate_pending_drop(drop_dict: Dictionary) -> Dictionary:
	var schema: int = int(drop_dict.get("schema_version", 0))
	if schema == CURRENT_SCHEMA:
		return drop_dict  # Already current — no migration needed.
	if schema > CURRENT_SCHEMA:
		# Future schema from a newer build — quarantine (we can't downgrade).
		_quarantine_drop(drop_dict, "schema_version_too_new")
		return {}
	# Schema < CURRENT_SCHEMA: attempt in-place migration via migration table.
	# Migration table is empty because schema 1 is the first version.
	# When schema 2 is introduced, add: migrations[1] = _migrate_v1_to_v2
	var migrations: Dictionary = {}
	if not migrations.has(schema):
		_quarantine_drop(drop_dict, "unmigratable_schema_version")
		return {}
	var migration_fn: Callable = migrations[schema]
	return migration_fn.call(drop_dict)


## Move an unmigratable pending drop to the quarantine namespace.
func _quarantine_drop(drop_dict: Dictionary, reason: String) -> void:
	var drop_id: String = str(drop_dict.get("drop_id", "unknown"))
	if _persistence != null:
		_persistence.write("loot.pending.quarantine." + drop_id, drop_dict)
	_emit_telemetry("loot.migration.quarantined", {
		"drop_id": drop_id,
		"reason": reason,
		"schema": drop_dict.get("schema_version", "missing"),
	})


## Handle backend ACK for a committed drop (5-step Step 5 reply) — Story 013 stub.
## Renames loot.pending.<drop_id> → loot.committed.<canonical_id>.
func _on_backend_ack(response: Dictionary) -> void:
	var drop_id: String = str(response.get("drop_id", ""))
	var canonical_id: String = str(response.get("canonical_id", ""))
	if drop_id.is_empty() or canonical_id.is_empty():
		return
	if not _pending_drops.has(drop_id):
		return  # Drop not found — may have been evicted already.
	var drop: LootDrop = _pending_drops[drop_id]
	if _persistence != null:
		_persistence.write("loot.committed." + canonical_id, drop.to_dict())
		_persistence.delete("loot.pending." + drop_id)
	_pending_drops.erase(drop_id)
	loot_committed.emit(drop_id, canonical_id)
