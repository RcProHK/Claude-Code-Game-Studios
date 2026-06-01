# ParticleSystemWrapper — Story 007: boot sequence + GSM lifecycle state machine.
#
# Coverage (behavioral — Integration):
#   AC-16 — GSM connect_for_initial_state subscription (once) + initial-state → Active.
#   AC-17 — wrapper persists nothing (no save_/load_ methods, no _persistence member, no user://).
#   AC-18 — EC1 lazy fallback: a boot-deferred tier is lazily built on first play; _booted true; warn.
#   AC-19 — EC12 Suspended: state set to Suspended + _drain() (no node emitting); play() rejected.
#   AC-20 — EC15 ledger reconcile runs once after 2.0s (injected clock); idempotent.
#   AC-21 — EC16: burst_started emitted synchronously (material hot-swap deferred = Story 008).
#   AC-22 — play() during Booting → INVALID (lifecycle gate).
#   AC-23 — _exit_tree drain: Draining state, emitters stopped+freed, ledger zeroed.
#
# boot ≤80ms (AC-15 sub-clause) is a PERF claim — VS-tier device evidence, not headless.
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")
const SOURCE_PATH: String = "res://src/autoload/particle_system_wrapper.gd"


class _StubNode:
	extends Node
	var amount: int = 0
	var emitting: bool = false
	func restart(_keep_seed: bool = false) -> void:
		pass


## Stub GameStateMachine: records connect_for_initial_state subscriptions and replays
## state deliveries on demand (the real GSM delivers the initial state synchronously on
## connect). RefCounted so the wrapper's _gsm reference frees it with the SUT (no orphan).
class _StubGSM:
	extends RefCounted
	var subscribe_count: int = 0
	var _cb: Callable = Callable()
	func connect_for_initial_state(cb: Callable) -> void:
		subscribe_count += 1
		_cb = cb
	func deliver(from_state: int, to_state: int, payload: Variant = null) -> void:
		if _cb.is_valid():
			_cb.call(from_state, to_state, payload)


func _stub_factory() -> Callable:
	return func() -> Node: return _StubNode.new()


## Build + boot a SUT with an injected stub GSM. _ready runs synchronously on add_child.
func _make_sut(gsm) -> Object:
	var sut = PSW.new()
	sut._node_factory = _stub_factory()
	if gsm != null:
		sut._gsm = gsm
	add_child_autofree(sut)
	return sut


func _tier_count(sut, tier: String) -> int:
	var n: int = 0
	for s in sut._pool:
		if s.tier == tier:
			n += 1
	return n


# ---------------------------------------------------------------------------
# AC-16 — GSM subscription + initial-state activation
# ---------------------------------------------------------------------------

func test_ac16_subscribes_once_and_activates() -> void:
	var gsm := _StubGSM.new()
	var sut = _make_sut(gsm)
	assert_eq(gsm.subscribe_count, 1, "AC-16: connect_for_initial_state called exactly once")
	# Synthetic initial-state sentinel (non-suspended) keeps the wrapper Active.
	gsm.deliver(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.IDLE, {"source_event": "initial_state"})
	assert_eq(sut._lifecycle_state, sut.LifecycleState.ACTIVE, "AC-16: Active after initial-state delivery")


# ---------------------------------------------------------------------------
# AC-17 — persists nothing
# ---------------------------------------------------------------------------

func test_ac17_persists_nothing() -> void:
	var sut = _make_sut(_StubGSM.new())
	for i in 10:
		sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	for m: Dictionary in sut.get_method_list():
		var n: String = m.name
		assert_false(n.begins_with("save_"), "AC-17: no save_* method (%s)" % n)
		assert_false(n.begins_with("load_"), "AC-17: no load_* method (%s)" % n)
	for p: Dictionary in sut.get_property_list():
		assert_false("persistence" in String(p.name).to_lower(), "AC-17: no persistence member (%s)" % p.name)
	# No user:// path anywhere in the source.
	var f := FileAccess.open(ProjectSettings.globalize_path(SOURCE_PATH), FileAccess.READ)
	assert_not_null(f, "source readable")
	var src := f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	assert_false("user://" in src, "AC-17: no user:// path in wrapper source")


# ---------------------------------------------------------------------------
# AC-18 — EC1 lazy fallback on a boot-deferred tier
# ---------------------------------------------------------------------------

func test_ac18_lazy_builds_deferred_tier() -> void:
	var warnings: Array = []
	var sut = PSW.new()
	sut._node_factory = _stub_factory()
	sut._warn_sink = func(m): warnings.append(m)
	sut._skip_tier_for_test = "LARGE"
	add_child_autofree(sut)
	assert_true(sut._booted, "AC-18: _booted true even with a deferred tier")
	assert_eq(_tier_count(sut, "LARGE"), 0, "AC-18: LARGE deferred at boot")
	var warned := false
	for w in warnings:
		if "boot_budget_overrun" in String(w):
			warned = true
	assert_true(warned, "AC-18: boot_budget_overrun warning emitted")
	# First LOOT play targets LARGE → lazily builds it and succeeds.
	var h: ParticleHandle = sut.play(PSW.PresetId.LOOT_BURST, Vector2.ZERO, 1.0)
	assert_true(h.alive(), "AC-18: lazy-built LARGE tier serves the burst")
	assert_eq(_tier_count(sut, "LARGE"), 2, "AC-18: LARGE lazily built (2 nodes)")
	sut.play(PSW.PresetId.LOOT_RARE_BURST, Vector2.ZERO, 1.0)
	assert_eq(_tier_count(sut, "LARGE"), 2, "AC-18: no rebuild on second use")


# ---------------------------------------------------------------------------
# AC-19 — EC12 Suspended drain + reject
# ---------------------------------------------------------------------------

func test_ac19_suspended_drains_and_rejects_play() -> void:
	var gsm := _StubGSM.new()
	var sut = _make_sut(gsm)
	var h: ParticleHandle = sut.play(PSW.PresetId.HIT_LIGHT, Vector2.ZERO, 1.0)
	assert_true(h.alive(), "burst active before suspend")
	gsm.deliver(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SUSPENDED, null)
	assert_eq(sut._lifecycle_state, sut.LifecycleState.SUSPENDED, "AC-19: lifecycle Suspended")
	for s in sut._pool:
		if s.node != null:
			assert_false(s.node.emitting, "AC-19: all emitters stopped on drain")
	var h2: ParticleHandle = sut.play(PSW.PresetId.HIT_LIGHT, Vector2.ZERO, 1.0)
	assert_false(h2.alive(), "AC-19: play() rejected while Suspended")
	# Resume restores service.
	gsm.deliver(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, null)
	assert_eq(sut._lifecycle_state, sut.LifecycleState.ACTIVE, "AC-19: resume → Active")


# ---------------------------------------------------------------------------
# AC-20 — EC15 ledger reconcile after 2.0s
# ---------------------------------------------------------------------------

func test_ac20_reconcile_runs_once_after_2s() -> void:
	var clock := {"t": 0}
	var sut = PSW.new()
	sut._node_factory = _stub_factory()
	sut._now_provider = func() -> int: return clock["t"]
	add_child_autofree(sut)
	sut.set_process(false)  # drive reconcile manually (deterministic)
	sut.play(PSW.PresetId.HIT_LIGHT, Vector2.ZERO, 1.0)  # ledger sum = 8
	sut._active_particle_total = 9999  # inject drift
	clock["t"] = 1900
	sut._check_reconcile()
	assert_eq(sut._reconcile_count, 0, "AC-20: no reconcile before 2.0s")
	assert_eq(sut._active_particle_total, 9999, "AC-20: total still drifted at 1.9s")
	clock["t"] = 2000
	sut._check_reconcile()
	assert_eq(sut._reconcile_count, 1, "AC-20: reconcile ran exactly once at 2.0s")
	assert_eq(sut._active_particle_total, 8, "AC-20: total corrected to ledger sum")
	sut._check_reconcile()  # same clock — idempotent
	assert_eq(sut._reconcile_count, 1, "AC-20: no second reconcile at the same clock")


# ---------------------------------------------------------------------------
# AC-21 — EC16 burst_started synchronous (material swap deferred = Story 008)
# ---------------------------------------------------------------------------

func test_ac21_burst_started_is_synchronous() -> void:
	var sut = _make_sut(_StubGSM.new())
	watch_signals(sut)
	var h: ParticleHandle = sut.play(PSW.PresetId.HIT_LIGHT, Vector2.ZERO, 1.0)
	assert_eq(get_signal_emit_count(sut, "burst_started"), 1,
		"AC-21: burst_started emitted synchronously within play() (material hot-swap is deferred)")
	assert_true(h.alive(), "AC-21: burst succeeds")


# ---------------------------------------------------------------------------
# AC-22 — play() during Booting
# ---------------------------------------------------------------------------

func test_ac22_play_during_booting_returns_invalid() -> void:
	var sut = PSW.new()  # NOT added to tree → _ready not run → lifecycle Booting
	sut._node_factory = _stub_factory()
	assert_eq(sut._lifecycle_state, sut.LifecycleState.BOOTING, "pre-_ready state is Booting")
	var h: ParticleHandle = sut.play(PSW.PresetId.HIT_LIGHT, Vector2.ZERO, 1.0)
	assert_false(h.alive(), "AC-22: play() during Booting returns INVALID silently")
	assert_eq(h, ParticleHandle.INVALID, "AC-22: returns the INVALID sentinel")
	autofree(sut)


# ---------------------------------------------------------------------------
# AC-23 — _exit_tree drain
# ---------------------------------------------------------------------------

func test_ac23_exit_tree_drains_and_zeroes_ledger() -> void:
	var sut = PSW.new()
	sut._node_factory = _stub_factory()
	sut._gsm = _StubGSM.new()
	add_child(sut)
	await get_tree().process_frame
	for i in 5:
		sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	assert_gt(sut._active_particle_total, 0, "bursts active before teardown")
	remove_child(sut)  # triggers _exit_tree
	assert_eq(sut._lifecycle_state, sut.LifecycleState.DRAINING, "AC-23: Draining state")
	assert_eq(sut._active_particle_total, 0, "AC-23: ledger total zeroed")
	assert_eq(sut._pool.size(), 0, "AC-23: pool drained/freed")
	sut.free()
