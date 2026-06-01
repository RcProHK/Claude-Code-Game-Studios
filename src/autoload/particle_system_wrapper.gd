# ParticleSystemWrapper — Autoload position 12 (#5)
#
# Status: PARTIAL — Story 001 (play() API + ParticleHandle contract + arg validation)
#   implemented. Object pool tiers + amounts + tier selection: Story 002.
#   CPU ledger + Formula 1: Story 003. LRU eviction + LOOT carve-out: Story 004.
#   Mobile UA detection: Story 005. burst_started ordering + re-entry guard: Story 006.
#   Boot sequence + GSM lifecycle state machine: Story 007. Preset .tres library: Story 008.
#
# Driving GDD: design/gdd/particle-system-wrapper.md (Approved 2026-05-26)
# Governing ADRs: ADR-0001 (Accepted-structural 2026-05-30) + ADR-0006 Contract 6
#
# Forbidden Pattern Gateway: ALL `GPUParticles2D` instantiation MUST route through this
#   autoload (CI lint: tools/ci/check_particle_callers.gd — Story 006). The default node
#   factory below is the ONE permitted GPUParticles2D.new() call site.
#
# NOTE: NO `class_name` — this script is registered as the `ParticleSystemWrapper`
#   autoload singleton in project.godot. A matching `class_name` would error
#   "hides an autoload singleton". Tests preload this script via
#   `const PSW := preload(...)` to reach enums / new() / constants.
extends Node


# ── Preset library ────────────────────────────────────────────────────────────

## The 9 named presets (GDD-locked closed library; CI-enforced in Story 006).
## ADR-0007: a closed Classification enum — declaration order is load-bearing for
## the visual escalation scale (HIT_LIGHT < HIT_HEAVY < LOOT_BURST < LOOT_RARE_BURST).
## No UNKNOWN sentinel: the library is fixed at exactly 9 and reflection-validated
## in play() against the enum values themselves.
enum PresetId {
	HIT_LIGHT       = 0,
	HIT_HEAVY       = 1,
	PARRY           = 2,
	DEATH           = 3,
	LOOT_BURST      = 4,
	LOOT_RARE_BURST = 5,
	STATUS_BURN     = 6,
	STATUS_FREEZE   = 7,
	STATUS_STUN     = 8,
}

## Preset data table (GDD Rule 1/7/13 `PRESET_TABLE` — Visual Spec Table). Keyed by
## PresetId; the closed set of exactly 9 entries is the membership oracle for play()
## validation (Rule 1.1). Each entry:
##   base_count   — Formula 1 step-1 base (Rule 7)
##   lifetime     — seconds, drives natural fade (set on GPUParticles2D at swap)
##   z_index      — world layer ordering (combat 5 / status 4 / loot 7 — Rule 13)
##   material_path — ParticleProcessMaterial .tres (Story 008, generated from the spec)
## (Particle texture is a GPUParticles2D node property + an unproduced art dependency —
## not in the material; left null until art lands.)
const PRESET_TABLE: Dictionary = {
	PresetId.HIT_LIGHT:       {"base_count": 8,  "lifetime": 0.25, "z_index": 5, "material_path": "res://assets/vfx/presets/hit_light.tres"},
	PresetId.HIT_HEAVY:       {"base_count": 18, "lifetime": 0.40, "z_index": 5, "material_path": "res://assets/vfx/presets/hit_heavy.tres"},
	PresetId.PARRY:           {"base_count": 14, "lifetime": 0.35, "z_index": 5, "material_path": "res://assets/vfx/presets/parry.tres"},
	PresetId.DEATH:           {"base_count": 28, "lifetime": 0.65, "z_index": 5, "material_path": "res://assets/vfx/presets/death.tres"},
	PresetId.LOOT_BURST:      {"base_count": 24, "lifetime": 0.90, "z_index": 7, "material_path": "res://assets/vfx/presets/loot_burst.tres"},
	PresetId.LOOT_RARE_BURST: {"base_count": 48, "lifetime": 1.60, "z_index": 7, "material_path": "res://assets/vfx/presets/loot_rare_burst.tres"},
	PresetId.STATUS_BURN:     {"base_count": 4,  "lifetime": 0.30, "z_index": 4, "material_path": "res://assets/vfx/presets/status_burn.tres"},
	PresetId.STATUS_FREEZE:   {"base_count": 5,  "lifetime": 0.45, "z_index": 4, "material_path": "res://assets/vfx/presets/status_freeze.tres"},
	PresetId.STATUS_STUN:     {"base_count": 6,  "lifetime": 0.50, "z_index": 4, "material_path": "res://assets/vfx/presets/status_stun.tres"},
}


# ── Lifecycle state (minimal — Story 007 owns GSM subscription + full transitions) ──

## ADR-0007 Family A (Outcome/State): ordinal 0 = BOOTING is the safe uninitialised
## default. play() only proceeds in ACTIVE; all other states return INVALID.
## Story 007 wires GSM `connect_for_initial_state` + Suspended/Draining handling.
enum LifecycleState {
	BOOTING   = 0,  ## pool not yet allocated — play() returns INVALID (GDD Rule 14)
	ACTIVE    = 1,  ## ready — play() acquires + emits
	SUSPENDED = 2,  ## backgrounded / bfcache — play() returns INVALID (Story 007)
	DRAINING  = 3,  ## _exit_tree teardown — play() returns INVALID (Story 007)
}

var _lifecycle_state: LifecycleState = LifecycleState.BOOTING

## True once _ready() has finished building the pool (EC1 — set even if a tier deferred).
var _booted: bool = false

## GameStateMachine DI seam (untyped). Default resolved to the GSM autoload in _ready.
## Subscribed via connect_for_initial_state (ADR-0006 Contract 6 — NO .bind).
var _gsm = null

## Ledger drift reconciliation (GDD Rule 6 / EC15) — corrects _active_particle_total to
## the live ledger sum every LEDGER_RECONCILE_INTERVAL_MS via _process (no timers — AC-23).
const LEDGER_RECONCILE_INTERVAL_MS: int = 2000
var _last_reconcile_ms: int = 0
var _reconcile_count: int = 0  ## debug/test counter

## EC1 slow-boot injection (tests only): a tier named here is NOT built in _ready and is
## lazily built on first play() that needs it. Empty = build all tiers at boot.
var _skip_tier_for_test: String = ""


# ── Caller multiplier validation bounds (GDD Rule 1, Tuning Knobs G.1) ──────────

## Lower bound — below this, play() short-circuits to INVALID (caller intent "off").
const CALLER_MULTIPLIER_MIN: float = 0.1

## Upper bound — above this, the multiplier is clamped and a throttled warning fires.
const MAX_CALLER_MULTIPLIER: float = 1.5

## Capacity tiers (GDD Rule 4). Pool is segmented so the `amount` GPU buffer is fixed
## per tier at boot and NEVER reallocated at runtime (Rule 5 — amount setter triggers a
## WebGL2 buffer realloc / hitch). Tier is selected by final_count band (Rule 5);
## LOOT presets always use LARGE (Pillar 3 dedicated nodes).
const TIER_SMALL: String = "SMALL"
const TIER_MEDIUM: String = "MEDIUM"
const TIER_LARGE: String = "LARGE"

const POOL_SIZE_SMALL: int = 8
const POOL_SIZE_MEDIUM: int = 6
const POOL_SIZE_LARGE: int = 2

## Total pre-spawned nodes = 8 + 6 + 2 (GDD Rule 4).
const POOL_SIZE: int = POOL_SIZE_SMALL + POOL_SIZE_MEDIUM + POOL_SIZE_LARGE

const AMOUNT_BUFFER_SMALL: int = 32
const AMOUNT_BUFFER_MEDIUM: int = 96
const AMOUNT_BUFFER_LARGE: int = 256


# ── Formula 1 multiplier composition (GDD Rule 7) ───────────────────────────────

## LOOT presets get 3× particle count — the Pillar 3 "loot always visually dominates
## combat" guarantee (GDD Visual Identity Anchor). Applied when preset is LOOT_*.
const LOOT_BURST_MULTIPLIER: float = 3.0

## Mobile downscale (GDD Rule 7 step 3). Applied when _is_mobile (Story 005 detection).
const MOBILE_FALLBACK_MULTIPLIER: float = 0.5

## Floor — a 1-particle burst still emits a valid burst (Rule 7 step 5).
const FINAL_COUNT_FLOOR: int = 1

## Active-particle ceiling (game-concept §8 hard governance; mobile). ADR-0001
## RATIFICATION-GATED — the *number* is Provisional pending VS-tier profiling.
## Story 003 tracks the ledger total; Story 004 enforces tier availability via LRU eviction.
const MAX_ACTIVE_PARTICLES: int = 200


# ── LRU eviction (GDD Rule 8/9, Formula 2) ──────────────────────────────────────

## Floor protection: a burst younger than this is never evicted by a non-LOOT request
## (GDD Rule 8 — ~9 frames @60fps, within the 200ms peripheral-register threshold).
## A LOOT request may bypass this to evict a non-LOOT victim (hybrid carve-out, Rule 9).
const EVICTION_MIN_LIFE_MS: int = 150

## Dropped-play warning throttle (GDD Rule 9 — avoid log flood on heavy combat frames).
const WARNING_THROTTLE_MS: int = 1000


# ── Signals ─────────────────────────────────────────────────────────────────────

## Emitted synchronously inside play() on a successful burst, AFTER slot acquire and
## BEFORE the GPU node begins emitting (GDD Rule 11). Story 006 hardens the exact
## ordering relative to restart()/emitting and adds the re-entry guard.
signal burst_started(preset_id: int, position: Vector2)


# ── DI seams (untyped — typed Node fails compile-time member check) ─────────────
## Inject before add_child() in tests.

## Factory for pool nodes. Default constructs real GPUParticles2D (the single
## permitted instantiation site). Tests inject a stub factory returning a duck-typed
## node that records emitting/restart/amount without driving the GPU.
var _node_factory: Callable = Callable()

## Warning sink (GDD Rule 1/9). Default routes to push_warning; tests inject a
## recording Callable to assert clamp/reject warnings deterministically.
var _warn_sink: Callable = Callable()


# ── Pool state ──────────────────────────────────────────────────────────────────

## A single particle pool slot. Plain data holder (no native-method overrides — GUT
## phantom-pass guard). The slot, not the handle, owns `generation` + `is_emitting`.
class PoolSlot:
	extends RefCounted
	var index: int = -1
	var tier: String = ""                 ## SMALL / MEDIUM / LARGE (GDD Rule 4)
	var node = null                       ## GPUParticles2D or test stub (untyped seam)
	var generation: int = 0               ## bumped on each acquire — invalidates old handles
	var is_emitting: bool = false
	var last_position: Vector2 = Vector2.ZERO
	var requested_multiplier: float = 1.0  ## clamped caller multiplier of the last play()

var _pool: Array[PoolSlot] = []

## Per-tier free lists: { TIER_SMALL: Array[int], TIER_MEDIUM: ..., TIER_LARGE: ... }.
## Dictionary values are Arrays held by reference, so pop_back/append mutate in place.
var _free: Dictionary = {}

## Test/diagnostic seam: the clamped caller multiplier from the most recent
## successful play() (lets Story 001 verify AC-02 clamp without Formula 1).
var _last_caller_mult: float = 0.0


# ── CPU ledger (GDD Rule 6 — O(1) incremental active-particle count) ────────────

## Conservative running total of active particles. Increment on play(), decrement on
## _on_expire(). Over-estimate only (never under-counts — the 50ms safety margin keeps
## a faded burst on the books briefly); ±15% drift tolerated (GDD Rule 6).
var _active_particle_total: int = 0

## handle_id → { count, spawn_time_ms, preset_id, pool_index }. The ground truth for
## the active total; reconciliation poll (Story 007 AC-20) corrects drift against it.
var _ledger: Dictionary = {}

## Monotonic handle id source (ledger key + Story 006 re-entry PENDING base).
var _next_handle_id: int = 0

## Active handle_ids in spawn order (oldest first) — the LRU eviction queue (Rule 8).
var _age_queue: Array[int] = []

## Whether this client is on mobile (drives MOBILE_FALLBACK_MULTIPLIER). Boot-cached
## once in _ready() via _detect_mobile(); immutable thereafter (UA can't change mid-session).
var _is_mobile: bool = false

## Debug override (null = auto-detect, true/false = forced). Honored only in debug builds.
var _mobile_override: Variant = null

## Injectable UA source (untyped seam). Returns { "ua": String, "max_touch": int } or null.
## In production wired to read PlatformDetect's boot-cached UA — ADR-0001 FORBIDS raw
## JavaScriptBridge.eval() here (only platform_detect.gd may call it). Tests inject this
## to exercise the UA classification table deterministically (JSBridge is null in headless).
var _ua_provider: Callable = Callable()


# ── Telemetry counters (GDD Rule 9 — #28 monitoring) ────────────────────────────

## Total play() calls this session (denominator for the >5% dropped trigger).
var _total_play_calls: int = 0

## play() calls dropped by the all-protected budget reject (Rule 9). Story 007 / #28
## owns the actual telemetry emit; Story 004 maintains the counter + the 5% ratio.
var _dropped_play_calls: int = 0

## Last time a dropped-play warning fired (throttle gate, ms via _now()).
var _last_dropped_warn_ms: int = -WARNING_THROTTLE_MS

## Injectable monotonic clock (ms). Default Time.get_ticks_msec; tests inject a fixed
## clock so eviction age + warning throttle are deterministic (no wall-clock asserts).
var _now_provider: Callable = Callable()


# ── Re-entry guard (GDD Rule 12) ────────────────────────────────────────────────

## Nesting depth of play() execution. >0 means we are inside a burst_started handler,
## so a nested play() is queued instead of executed inline (prevents recursion/overflow).
var _emit_depth: int = 0

## Queued re-entrant plays: [{ preset_id, position, multiplier, handle }]. Drained FIFO
## by _flush_deferred at frame end, resolving each PENDING handle to a real slot.
var _deferred_plays: Array = []


# ── Boot ────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not _node_factory.is_valid():
		_node_factory = _default_node_factory
	_is_mobile = _detect_mobile()  # boot-cache once (Rule 10 — UA immutable mid-session)
	_build_pool()
	_booted = true
	_last_reconcile_ms = _now()
	# Boot done → Active (GDD state table: Booting exits to Active on _ready done).
	_lifecycle_state = LifecycleState.ACTIVE
	# GSM subscription (ADR-0006 Contract 6): connect_for_initial_state, NO .bind.
	# The initial-state sentinel delivery may immediately move us to Suspended.
	if _gsm == null:
		_gsm = GameStateMachine
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)


## Per-frame ledger drift reconciliation gate (EC15). No timers (AC-23 — no orphans).
func _process(_delta: float) -> void:
	_check_reconcile()


## The ONE permitted GPUParticles2D.new() call site (ADR-0001 gateway).
func _default_node_factory() -> Node:
	return GPUParticles2D.new()


## Minimal teardown — free the pool nodes built in _build_pool so their rendering
## RIDs are released. Story 007 (AC-23) expands this into the full Draining state
## machine (set emitting=false on all slots + zero the CPU ledger before freeing).
func _exit_tree() -> void:
	# Draining (GDD state table / AC-23): reject further play(), stop + free all emitters,
	# zero the ledger. free() synchronously (not queue_free) so rendering RIDs release before
	# the server tears down at headless exit. No timers are used → no orphaned timers.
	_lifecycle_state = LifecycleState.DRAINING
	for slot in _pool:
		if slot.node != null and is_instance_valid(slot.node):
			slot.node.emitting = false
			slot.node.free()
	_pool.clear()
	_free.clear()
	_ledger.clear()
	_age_queue.clear()
	_active_particle_total = 0


## Pre-spawn the tiered pool (GDD Rule 4): 8 SMALL + 6 MEDIUM + 2 LARGE. Each node's
## `amount` GPU buffer is set ONCE here and never reassigned at runtime (Rule 5).
func _build_pool() -> void:
	_pool.clear()
	_free = {TIER_SMALL: [], TIER_MEDIUM: [], TIER_LARGE: []}
	_build_tier_guarded(TIER_SMALL, POOL_SIZE_SMALL, AMOUNT_BUFFER_SMALL)
	_build_tier_guarded(TIER_MEDIUM, POOL_SIZE_MEDIUM, AMOUNT_BUFFER_MEDIUM)
	_build_tier_guarded(TIER_LARGE, POOL_SIZE_LARGE, AMOUNT_BUFFER_LARGE)


## Build a tier unless it is the EC1 slow-boot deferred tier (lazily built on first use).
func _build_tier_guarded(tier: String, count: int, buffer: int) -> void:
	if tier == _skip_tier_for_test:
		_warn("boot_budget_overrun: tier %s deferred to lazy build (EC1)" % tier)
		return
	_build_tier(tier, count, buffer)


## Lazily build a tier that was deferred at boot (EC1). No-op if already built.
func _lazy_build_tier_if_absent(tier: String) -> void:
	for slot in _pool:
		if slot.tier == tier:
			return  # already built
	match tier:
		TIER_SMALL:  _build_tier(TIER_SMALL, POOL_SIZE_SMALL, AMOUNT_BUFFER_SMALL)
		TIER_MEDIUM: _build_tier(TIER_MEDIUM, POOL_SIZE_MEDIUM, AMOUNT_BUFFER_MEDIUM)
		TIER_LARGE:  _build_tier(TIER_LARGE, POOL_SIZE_LARGE, AMOUNT_BUFFER_LARGE)


## Build one capacity tier: `count` nodes each with a fixed `amount` buffer.
func _build_tier(tier: String, count: int, amount_buffer: int) -> void:
	for _i in count:
		var slot := PoolSlot.new()
		slot.index = _pool.size()
		slot.tier = tier
		slot.node = _node_factory.call()
		if slot.node != null and slot.node is Node:
			slot.node.amount = amount_buffer  # set ONCE at boot (Rule 5 — no runtime realloc)
			add_child(slot.node)
		_pool.append(slot)
		(_free[tier] as Array).append(slot.index)


# ── Public API ──────────────────────────────────────────────────────────────────

## Single entry point for all particle bursts (GDD Rule 1/2). Synchronously validates
## arguments (never awaits), acquires a pool slot, and returns a ParticleHandle. On any
## rejection returns `ParticleHandle.INVALID` and emits NO `burst_started` signal
## (ghost-shake guard, GDD Rule 11). GPU emission is fire-and-forget on the next frame.
##
## [param preset_id] one of the 9 PresetId values.
## [param position] world position; NaN/±INF rejected.
## [param multiplier] caller hint, clamped to [CALLER_MULTIPLIER_MIN, MAX_CALLER_MULTIPLIER];
##   below the minimum short-circuits to INVALID.
func play(preset_id: PresetId, position: Vector2, multiplier: float = 1.0) -> ParticleHandle:
	# Re-entry guard (GDD Rule 12): a play() issued from inside a burst_started handler is
	# queued and resolved at frame end — never executed inline (prevents unbounded
	# recursion). Returns a PENDING handle (_pool_index == -1) until _flush_deferred runs.
	if _emit_depth > 0:
		return _queue_deferred(preset_id, position, multiplier)
	_emit_depth += 1
	var handle := _execute_play(preset_id, position, multiplier)
	_emit_depth -= 1
	if _emit_depth == 0 and not _deferred_plays.is_empty():
		call_deferred("_flush_deferred")
	return handle


## Actual burst execution (GDD Rule 1/2/6/7/8). Wrapped by play()'s re-entry guard.
func _execute_play(preset_id: PresetId, position: Vector2, multiplier: float = 1.0) -> ParticleHandle:
	# Lifecycle gate (Story 007 expands Suspended/Draining/Booting buffering).
	if _lifecycle_state != LifecycleState.ACTIVE:
		return ParticleHandle.INVALID

	_total_play_calls += 1  # denominator for the >5% dropped telemetry trigger (Rule 9)

	# Rule 1.1 — preset must be a real entry in the closed table (defensive vs
	# reflection / network routing injecting an out-of-range int).
	if not PRESET_TABLE.has(preset_id):
		return ParticleHandle.INVALID

	# Rule 1.2 — NaN / ±INF position rejected (Foundation never throws — Pillar 2).
	if not (is_finite(position.x) and is_finite(position.y)):
		return ParticleHandle.INVALID

	# Rule 1.3 — multiplier validation: non-finite or below minimum short-circuits;
	# above maximum clamps with a warning.
	if not is_finite(multiplier) or multiplier < CALLER_MULTIPLIER_MIN:
		return ParticleHandle.INVALID
	var clamped: float = multiplier
	if multiplier > MAX_CALLER_MULTIPLIER:
		clamped = MAX_CALLER_MULTIPLIER
		_warn("ParticleSystemWrapper.play: caller multiplier %f clamped to %f" % [multiplier, MAX_CALLER_MULTIPLIER])

	# Compose the final particle count via Formula 1 (Rule 7), then select the capacity
	# tier (Rule 5) from it. node.amount is fixed at boot — never set here (Rule 5).
	var final_count: int = _compose_for_preset(preset_id, clamped)
	var tier: String = _select_tier(preset_id, final_count)

	# Acquire a slot from that tier. If the tier is full, attempt LRU eviction
	# (Rule 8/9), then retry once. All-protected → clean reject below.
	var idx: int = _acquire_slot(tier)
	if idx < 0:
		if _try_evict(tier, final_count, _is_loot(preset_id)):
			idx = _acquire_slot(tier)
	if idx < 0:
		# All-protected (Rule 9): clean reject — NO signal (ghost-shake guard),
		# increment dropped counter, throttled warning.
		_dropped_play_calls += 1
		_maybe_warn_dropped()
		return ParticleHandle.INVALID

	var slot: PoolSlot = _pool[idx]
	slot.is_emitting = true
	slot.last_position = position
	slot.requested_multiplier = clamped
	_last_caller_mult = clamped

	var spawn_ms: int = _now()
	var handle := ParticleHandle.new()
	handle.handle_id = _next_handle_id
	_next_handle_id += 1
	handle.preset_id = preset_id
	handle.spawn_time_ms = spawn_ms
	handle._pool_index = idx
	handle._generation = slot.generation
	handle._slot = slot

	# CPU ledger (Rule 6): O(1) incremental — insert entry + bump the conservative total
	# + record in the LRU age queue (oldest first).
	_ledger[handle.handle_id] = {
		"count": final_count,
		"spawn_time_ms": spawn_ms,
		"preset_id": preset_id,
		"pool_index": idx,
	}
	_active_particle_total += final_count
	_age_queue.append(handle.handle_id)

	_begin_emit(slot, preset_id, position)
	return handle


# ── Emit sequence + re-entry queue (GDD Rule 11/12) ─────────────────────────────

## Locked emit ordering (GDD Rule 11): apply_preset → restart(keep_seed=false) → emit
## burst_started → set emitting=true. The signal fires AFTER the emitter is configured
## but BEFORE emitting flips true, so a consumer (#6 ScreenEffects) sees a ready-but-not-
## yet-emitting node — particles + shake + hit-pause coincide on the next _process frame.
func _begin_emit(slot: PoolSlot, preset_id: int, position: Vector2) -> void:
	_apply_preset(slot.node, preset_id, position)
	if slot.node != null:
		slot.node.restart(false)
	burst_started.emit(preset_id, position)
	if slot.node != null:
		slot.node.emitting = true


## Configure a pool node for a burst before it starts. Position (and the boot-fixed
## amount, Rule 5) are applied synchronously here. The process_material / lifetime hot-swap
## is deferred via call_deferred (EC16 — avoids a WebGL2 pre-first-frame material race);
## the swap body lands in Story 008 once the preset .tres library exists. burst_started
## itself stays synchronous (Rule 11) — only the material swap is deferred.
func _apply_preset(node, preset_id: int, position: Vector2) -> void:
	if node == null:
		return
	if node is Node2D:
		(node as Node2D).global_position = position
	call_deferred("_swap_material", node, preset_id)


## Deferred material/lifetime/z_index hot-swap (EC16, Story 008). Applies the preset's
## ParticleProcessMaterial (.tres) + lifetime + z_index to a real GPUParticles2D node.
## No-op for test stubs / freed nodes (guarded) so headless tests stay GPU-free.
func _swap_material(node, preset_id: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not (node is GPUParticles2D):
		return  # test stub — material swap is a real-GPU-only concern
	var entry: Dictionary = PRESET_TABLE.get(preset_id, {})
	if entry.is_empty():
		return
	var gp := node as GPUParticles2D
	gp.lifetime = float(entry.get("lifetime", 1.0))
	gp.z_index = int(entry.get("z_index", 5))
	var mat := load(String(entry.get("material_path", ""))) as ParticleProcessMaterial
	if mat != null:
		gp.process_material = mat


## Queue a re-entrant play() (called while _emit_depth > 0). Returns a PENDING handle
## (_pool_index == -1, alive() == false) resolved later by _flush_deferred.
func _queue_deferred(preset_id: int, position: Vector2, multiplier: float) -> ParticleHandle:
	var pending := ParticleHandle.new()
	pending._pool_index = -1  # PENDING marker
	_deferred_plays.append({
		"preset_id": preset_id,
		"position": position,
		"multiplier": multiplier,
		"handle": pending,
	})
	return pending


## Drain the deferred-play queue at frame end (FIFO), resolving each PENDING handle to a
## real slot. Runs under its own _emit_depth so plays re-entered DURING the flush are
## themselves queued for the next flush (no recursion). Idempotent on an empty queue.
func _flush_deferred() -> void:
	if _deferred_plays.is_empty():
		return
	var queue: Array = _deferred_plays.duplicate()
	_deferred_plays.clear()
	_emit_depth += 1
	for item: Dictionary in queue:
		var resolved := _execute_play(item["preset_id"], item["position"], item["multiplier"])
		var pending: ParticleHandle = item["handle"]
		pending.handle_id = resolved.handle_id
		pending.preset_id = resolved.preset_id
		pending.spawn_time_ms = resolved.spawn_time_ms
		pending._pool_index = resolved._pool_index
		pending._generation = resolved._generation
		pending._slot = resolved._slot
	_emit_depth -= 1
	if _emit_depth == 0 and not _deferred_plays.is_empty():
		call_deferred("_flush_deferred")


# ── Pool internals ──────────────────────────────────────────────────────────────

## Select the capacity tier for a burst (GDD Rule 5). LOOT presets always use LARGE
## (Rule 4 dedicated-node design intent — Pillar 3 guarantee). Otherwise the tier is
## chosen by final_count band. final_count is clamped to ≤256 upstream (Story 003
## Formula 1); values above LARGE here warn and fall back to LARGE defensively.
func _select_tier(preset_id: PresetId, final_count: int) -> String:
	if preset_id == PresetId.LOOT_BURST or preset_id == PresetId.LOOT_RARE_BURST:
		return TIER_LARGE
	if final_count <= AMOUNT_BUFFER_SMALL:
		return TIER_SMALL
	if final_count <= AMOUNT_BUFFER_MEDIUM:
		return TIER_MEDIUM
	if final_count <= AMOUNT_BUFFER_LARGE:
		return TIER_LARGE
	_warn("ParticleSystemWrapper: final_count %d exceeds LARGE buffer; clamping to LARGE" % final_count)
	return TIER_LARGE


## Pop a free slot index from the given tier and bump its generation (invalidating
## stale handles). Lazily reclaims stopped slots of that tier first. Returns -1 if the
## tier is genuinely full (LRU eviction + LOOT carve-out is Story 004).
func _acquire_slot(tier: String) -> int:
	var free_list: Array = _free[tier]
	if free_list.is_empty():
		_lazy_build_tier_if_absent(tier)  # EC1 — build a boot-deferred tier on first use
		free_list = _free[tier]
	if free_list.is_empty():
		_reclaim_stopped_slots(tier)
	if free_list.is_empty():
		return -1
	var idx: int = free_list.pop_back()
	_pool[idx].generation += 1
	return idx


## Return stopped (is_emitting == false) slots of the given tier that are not yet on
## the free list back to it. Story 003/004/007 replace this with expiry-driven
## reclamation + LRU eviction; Story 001/002 reclaim only explicitly stopped slots.
func _reclaim_stopped_slots(tier: String) -> void:
	var free_list: Array = _free[tier]
	for slot in _pool:
		if slot.tier == tier and not slot.is_emitting and not free_list.has(slot.index):
			free_list.append(slot.index)


# ── Formula 1: multiplier composition (GDD Rule 7) ──────────────────────────────

## Pre-clamp composed count: round(base × loot × mobile × caller). roundi() is
## half-away-from-zero (GDScript), matching the GDD's rounding contract. Pure/static.
static func compose_raw_count(base: int, loot_mult: float, mobile_mult: float, caller_mult: float) -> int:
	return roundi(float(base) * loot_mult * mobile_mult * caller_mult)


## Final particle count (GDD Rule 7): clamp(round(base × loot × mobile × caller),
## FINAL_COUNT_FLOOR, AMOUNT_BUFFER_LARGE). Deterministic, side-effect-free — the
## high-value unit-test target (no node/stub needed).
static func compute_final_count(base: int, loot_mult: float, mobile_mult: float, caller_mult: float) -> int:
	return clampi(compose_raw_count(base, loot_mult, mobile_mult, caller_mult), FINAL_COUNT_FLOOR, AMOUNT_BUFFER_LARGE)


## True if the preset is a LOOT burst (gets the 3× multiplier + dedicated LARGE tier).
static func _is_loot(preset_id: int) -> bool:
	return preset_id == PresetId.LOOT_BURST or preset_id == PresetId.LOOT_RARE_BURST


## Compose the final count for a preset using its PRESET_TABLE base + the loot/mobile
## state + the (already caller-clamped, Rule 1) caller multiplier. Warns on ceiling
## clamp (defensive — no v1 preset reaches 256, but reflection/future bases might).
func _compose_for_preset(preset_id: PresetId, caller_mult: float) -> int:
	var base: int = PRESET_TABLE[preset_id].base_count
	var loot_mult: float = LOOT_BURST_MULTIPLIER if _is_loot(preset_id) else 1.0
	var mobile_mult: float = MOBILE_FALLBACK_MULTIPLIER if _is_mobile else 1.0
	if compose_raw_count(base, loot_mult, mobile_mult, caller_mult) > AMOUNT_BUFFER_LARGE:
		_warn("ParticleSystemWrapper: composed count exceeds %d ceiling; clamped" % AMOUNT_BUFFER_LARGE)
	return compute_final_count(base, loot_mult, mobile_mult, caller_mult)


# ── Mobile UA detection (GDD Rule 10) ───────────────────────────────────────────

## Pure UA classification (GDD Rule 10 table). Conservative default MOBILE on
## null / non-String / unknown UA (FR-3 — rather a desktop user sees 0.5× particles
## than a mobile user janks). Static → fully deterministic headless test, no JSBridge.
static func classify_ua(ua: Variant, max_touch: int) -> bool:
	if ua == null or typeof(ua) != TYPE_STRING:
		return true  # FR-3 conservative default
	var s: String = (ua as String).to_lower()
	if "iphone" in s or "ipod" in s or "ipad" in s:
		return true
	if "macintosh" in s:
		return max_touch > 1  # iPad-pretending-Mac since iPadOS 13 (real Mac → max_touch 0)
	if "android" in s or "mobile" in s:
		return true
	return false  # windows / linux / desktop Mac


## Resolve mobile-ness (GDD Rule 10). Debug override wins; else the injected UA provider
## (PlatformDetect-sourced in production) feeds classify_ua. Without a provider, native/CI
## (OS.has_feature("web") == false) is DESKTOP; a web build with no provider is conservative.
func _detect_mobile() -> bool:
	if _mobile_override != null:
		return bool(_mobile_override)
	if not _ua_provider.is_valid():
		return true if OS.has_feature("web") else false
	var data = _ua_provider.call()
	if data == null or not (data is Dictionary):
		return true  # FR-3 conservative default
	return classify_ua(data.get("ua"), int(data.get("max_touch", 0)))


## Debug-only manual override (null / true / false). Production no-op (Rule 10).
## Re-caches _is_mobile so the change takes effect.
func set_mobile_override(value: Variant) -> void:
	if not OS.is_debug_build():
		return
	_mobile_override = value
	_is_mobile = _detect_mobile()


# ── GSM lifecycle (GDD Rule 15, ADR-0006 Contract 6) ────────────────────────────

## GSM state-change handler (Contract 6: also receives the one-shot initial-state sentinel
## via self-loop callv, payload.source_event == "initial_state"). Suspended → drain +
## reject; any non-suspended state resumes service. EC12: lifecycle is set to Suspended
## BEFORE _drain() runs so an in-flight/late play() is rejected by the gate.
func _on_gsm_state_changed(_from: Variant, to: Variant, _payload: Variant = null) -> void:
	if _is_suspended_state(to):
		_enter_suspended()
	elif _lifecycle_state == LifecycleState.SUSPENDED or _lifecycle_state == LifecycleState.BOOTING:
		_lifecycle_state = LifecycleState.ACTIVE  # resume / initial-state activation


## True if a GSM state value is the SUSPENDED state (GameState enum ordinal).
func _is_suspended_state(state: Variant) -> bool:
	return int(state) == GameStateMachine.GameState.SUSPENDED


## Enter Suspended (GDD Rule 15). State set BEFORE drain (EC12 ordering) so play() rejects.
func _enter_suspended() -> void:
	_lifecycle_state = LifecycleState.SUSPENDED
	_drain()


## Stop every emitting node (preserve the pool) — Mobile Safari background-tab budget guard.
func _drain() -> void:
	for slot in _pool:
		if slot.is_emitting:
			slot.is_emitting = false
			if slot.node != null:
				slot.node.emitting = false


# ── Ledger reconciliation (GDD Rule 6 / EC15) ───────────────────────────────────

## Reconcile the conservative total to the live ledger sum once per interval (corrects
## the ±15% over-estimate drift). Driven by _process; tests call directly with an injected clock.
func _check_reconcile() -> void:
	var now: int = _now()
	if now - _last_reconcile_ms >= LEDGER_RECONCILE_INTERVAL_MS:
		_reconcile_ledger()
		_last_reconcile_ms = now


func _reconcile_ledger() -> void:
	var truth: int = 0
	for entry: Dictionary in _ledger.values():
		truth += int(entry.count)
	_active_particle_total = truth
	_reconcile_count += 1


# ── CPU ledger (GDD Rule 6) ─────────────────────────────────────────────────────

## Decrement the active total and release the slot when a burst expires. Driven by
## the lifetime timer in production (Story 006/007) and directly by tests. Idempotent:
## a second call for an already-expired handle_id is a no-op (never under-counts).
func _on_expire(handle_id: int) -> void:
	if not _ledger.has(handle_id):
		return
	var entry: Dictionary = _ledger[handle_id]
	_active_particle_total -= int(entry.count)
	_ledger.erase(handle_id)
	_age_queue.erase(handle_id)
	var pool_index: int = int(entry.pool_index)
	if pool_index >= 0 and pool_index < _pool.size():
		_pool[pool_index].is_emitting = false


# ── LRU eviction (GDD Rule 8/9, Formula 2) ──────────────────────────────────────

## Try to free one slot in the target tier by evicting the oldest eligible burst.
## Non-LOOT requests skip floor-protected (<150ms) victims; LOOT requests bypass the
## floor for non-LOOT victims but NEVER evict a LOOT burst (hybrid carve-out). Returns
## true if a slot was freed. Iterates a snapshot of the age queue (oldest first).
func _try_evict(tier: String, _needed: int, is_loot_request: bool) -> bool:
	var now: int = _now()
	for handle_id in _age_queue.duplicate():
		if not _ledger.has(handle_id):
			continue
		var entry: Dictionary = _ledger[handle_id]
		var pool_index: int = int(entry.pool_index)
		if pool_index < 0 or pool_index >= _pool.size() or _pool[pool_index].tier != tier:
			continue  # wrong tier — cannot satisfy this request
		var age_ms: int = now - int(entry.spawn_time_ms)
		if age_ms < EVICTION_MIN_LIFE_MS:
			if not is_loot_request:
				continue  # floor-protected; non-LOOT cannot bypass
			if _is_loot(int(entry.preset_id)):
				continue  # never evict a LOOT burst
		_force_expire(handle_id)
		return true  # freed one slot in the tier — enough for one burst
	return false


## Force-expire a burst for eviction (GDD Rule 8): stop the GPU emitter (natural fade,
## NOT restart / queue_free) and decrement the ledger immediately (Rule 6 drift source).
func _force_expire(handle_id: int) -> void:
	if not _ledger.has(handle_id):
		return
	var pool_index: int = int(_ledger[handle_id].pool_index)
	if pool_index >= 0 and pool_index < _pool.size():
		var node = _pool[pool_index].node
		if node != null:
			node.emitting = false
	_on_expire(handle_id)


# ── Helpers ─────────────────────────────────────────────────────────────────────

## Monotonic clock (ms). Injectable via _now_provider for deterministic tests.
func _now() -> int:
	if _now_provider.is_valid():
		return int(_now_provider.call())
	return Time.get_ticks_msec()


## Emit a dropped-play warning, throttled to one per WARNING_THROTTLE_MS (Rule 9).
func _maybe_warn_dropped() -> void:
	var now: int = _now()
	if now - _last_dropped_warn_ms >= WARNING_THROTTLE_MS:
		_warn("ParticleSystemWrapper.play: burst dropped — all slots floor-protected (dropped=%d)" % _dropped_play_calls)
		_last_dropped_warn_ms = now


func _warn(msg: String) -> void:
	if _warn_sink.is_valid():
		_warn_sink.call(msg)
	else:
		push_warning(msg)
