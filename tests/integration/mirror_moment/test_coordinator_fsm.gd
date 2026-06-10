extends GutTest
## Story 002/005/006/008/009/010/011/012/013: MirrorMomentCoordinator integration —
## FSM + cfis bootstrap + cadence/content gating + latch/persist + suspend + screenshot.
## Fully isolated via injected FakeGSM / FakeAvatar (#26 seam) / MockPersistence / FakeClock /
## FakeParticles (injected BEFORE add_child per reference_test_persistence_isolation). Covers
## AC-01/02/03/05/06/07/09/10/11/13/14/16/17/18/19/21. See mirror-moment.md.

const CoordScript := preload("res://src/autoload/mirror_moment_coordinator.gd")
const F := preload("res://src/core/mirror_moment_formulas.gd")
const NOW := 2_000_000
const LAST_OLD := 1_000_000  # Δ=1_000_000 > 604800 → cadence open


# --- Fakes --------------------------------------------------------------------

class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	var state: int = GameState.IDLE
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func go(to_state: int) -> void:
		var prev := state
		state = to_state
		state_changed.emit(prev, to_state, null)


class FakeAvatar:
	extends RefCounted
	signal avatar_evolution_milestone(tier, source_metrics)
	signal avatar_micro_evolution(delta_kind, source_metrics)
	const MILESTONE_CADENCE_SECONDS := 604800
	const BFCACHE_CONTINUE_THRESHOLD_MS := 30000
	var snap: AvatarEvolutionSnapshot = AvatarEvolutionSnapshot.new()
	func get_evolution_snapshot() -> AvatarEvolutionSnapshot:
		return snap
	func emit_milestone(tier: int, metrics: Dictionary = {}) -> void:
		avatar_evolution_milestone.emit(tier, metrics)
	func emit_micro() -> void:
		avatar_micro_evolution.emit(&"weekly_stat_delta", {})


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


class FakeClock:
	extends RefCounted
	var unix: int = NOW
	var ms: int = 0
	func now_unix() -> int:
		return unix
	func now_ms() -> int:
		return ms


class FakeParticles:
	extends RefCounted
	var plays: Array = []
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0):
		plays.append({"preset": preset_id, "pos": position, "mult": multiplier})
		return null


class FakeAttention:
	extends RefCounted
	var permitted: bool = true
	func is_input_permitted() -> bool:
		return permitted


class FakeInventory:
	extends RefCounted
	var sig: String = ""
	func get_ceremony_signature_text() -> String:
		return sig


# --- Helpers ------------------------------------------------------------------

func _snap(tier: int, prior_tier: int, prior_sprite: String = "res://prior.tres") -> AvatarEvolutionSnapshot:
	var s := AvatarEvolutionSnapshot.new()
	s.tier = tier
	s.class_posture = &"STRIKE"
	s.sprite_frames_resource_path = "res://after.tres"
	s.hero_pose_frame = 0
	s.prior_tier = prior_tier
	s.prior_sprite_frames_resource_path = prior_sprite
	s.source_metrics = {"stat_total": 80.0, "ability_count": 3, "max_class_depth": 2, "achieved_at_unix": NOW}
	s.snapshot_taken_unix = NOW
	return s


## Build + boot a coordinator with all seams injected (no autoload fallback, no auto-_process).
func _make(gsm, avatar, persistence, clock = null, particles = null) -> Node:
	var c = CoordScript.new()
	c._gsm = gsm
	c._avatar = avatar
	c._persistence = persistence
	c._clock = clock if clock != null else FakeClock.new()
	c._particles = particles if particles != null else FakeParticles.new()
	c._loot_reveal = RefCounted.new()  # no get_*_layer → own fallback layers
	c._attention = RefCounted.new()    # no is_input_permitted → GSM-only gate
	c._workout = RefCounted.new()      # no count getters → caption base form
	c._inventory = RefCounted.new()    # no signature surface → no narrative row
	c._pr = RefCounted.new()           # no PR surface → no narrative row
	c._platform = RefCounted.new()     # no announce_aria → skip
	add_child_autofree(c)
	c.set_process(false)
	return c


## Drive the present-delay window deterministically (EC-MM-14 stable-IDLE frames).
func _tick_to_present(c: Node) -> void:
	for _i in range(c._config.present_delay_frames + 1):
		c._process(0.0)


# --- Tests --------------------------------------------------------------------

func test_boot_dormant_when_no_change() -> void:
	var c := _make(FakeGSM.new(), FakeAvatar.new(), MockPersistence.new())
	assert_eq(c.get_phase(), c.Phase.DORMANT, "fresh boot, no change → DORMANT")
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.DORMANT, "no arm without change → never presents")


func test_ac01_arms_and_presents_evolution_in_idle() -> void:
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}  # cadence open
	var c := _make(gsm, av, p)
	watch_signals(c)
	av.emit_milestone(2, {"stat_total": 80.0})
	assert_eq(c.get_phase(), c.Phase.ARMED, "AC-01: cadence open + pending → ARMED")
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.PRESENTING, "AC-01: stable IDLE → PRESENTING")
	assert_signal_emitted(c, "ceremony_presented", "AC-01: ceremony presented once")


func test_ac02_no_represent_in_same_window() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	_tick_to_present(c)
	c.dismiss()
	assert_eq(c.get_phase(), c.Phase.DORMANT, "after dismiss → DORMANT")
	# Re-evaluate in the SAME window (last_ceremony just set to NOW, Δ=0 < cadence).
	av.emit_micro()
	assert_eq(c.get_phase(), c.Phase.DORMANT, "AC-02: same window → does not re-arm/re-present")


func test_ac03_present_gate_blocks_non_idle_then_presents_on_idle() -> void:
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.WORKOUT_ACTIVE
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	assert_eq(c.get_phase(), c.Phase.ARMED, "armed even mid-workout (latch holds)")
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.ARMED, "AC-03: WORKOUT_ACTIVE blocks presentation, stays ARMED")
	gsm.go(FakeGSM.GameState.IDLE)
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.PRESENTING, "AC-03: entering IDLE → presents")


func test_ac06_micro_only_is_reflection() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 2)  # same tier — REFLECTION
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	watch_signals(c)
	av.emit_micro()
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.PRESENTING, "AC-06: micro-only week arms + presents")
	var params = get_signal_parameters(c, "ceremony_presented")
	assert_eq(params[0], F.CONTENT_REFLECTION, "AC-06: content == REFLECTION")


func test_ac07_no_change_emits_skip_not_ceremony() -> void:
	# A race where week_had_change is cleared between arm and present collapses to NONE.
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD, "week_had_change": true}
	var c := _make(gsm, av, p)
	watch_signals(c)
	# Clear the only change flag, then force the present path directly (defense-in-depth).
	c._week_had_change = false
	c._phase = c.Phase.ARMED
	c._present()
	assert_signal_emitted(c, "no_change_skip", "AC-07: NONE content → mirror.no_change_skip")
	assert_signal_not_emitted(c, "ceremony_presented", "AC-07: no ceremony shown")


func test_ac09_latch_persists_across_kill() -> void:
	var p := MockPersistence.new()
	# Session 1: a milestone latches + persists, player never reaches a safe context.
	var gsm1 := FakeGSM.new()
	gsm1.state = FakeGSM.GameState.WORKOUT_ACTIVE
	var av1 := FakeAvatar.new()
	av1.snap = _snap(2, 1)
	var c1 := _make(gsm1, av1, p)
	av1.emit_milestone(2, {"stat_total": 80.0})
	assert_true(p.store["mirror_moment"]["pending_evolution_ceremony"], "AC-09: milestone persisted pending")
	assert_eq(int(p.store["mirror_moment"]["pending_tier"]), 2, "AC-09: pending_tier persisted")
	# Session 2: fresh coordinator, SAME persistence store (app killed + reopened).
	var gsm2 := FakeGSM.new()
	var av2 := FakeAvatar.new()
	av2.snap = _snap(2, 1)
	var c2 := _make(gsm2, av2, p)
	assert_true(c2.is_pending_evolution(), "AC-09: boot rebuilds pending from persistence (never lost)")
	_tick_to_present(c2)
	assert_eq(c2.get_phase(), c2.Phase.PRESENTING, "AC-09: next IDLE flushes the persisted ceremony")


func test_ac10_multiple_milestones_collapse_to_single() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(3, 0)  # #26 snapshot already collapsed: prior=0 (last-ceremonied), tier=3
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	watch_signals(c)
	av.emit_milestone(1)
	av.emit_milestone(2)
	av.emit_milestone(3)
	_tick_to_present(c)
	assert_signal_emit_count(c, "ceremony_presented", 1, "AC-10: three milestones → ONE ceremony")
	assert_eq(c._active_tier, 3, "AC-10: presents the net current tier")


func test_ac11_snapshot_read_at_present_not_at_latch() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	# Avatar evolves again AFTER the latch but BEFORE presentation.
	av.snap = _snap(3, 2)
	_tick_to_present(c)
	assert_eq(c._active_tier, 3, "AC-11: render uses present-time snapshot (tier 3), not latch-time (2)")


func test_ac13_screenshot_flow_emits_prompt_then_shared() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	_tick_to_present(c)
	watch_signals(c)
	c.request_screenshot()
	assert_signal_emitted(c, "share_prompted", "AC-13: tap 截圖分享 → mirror.share_prompted")
	c.confirm_shared()
	assert_signal_emitted(c, "shared", "AC-13: confirm → mirror.shared")
	assert_eq(int(p.store["mirror_moment"]["last_shared_unix"]), NOW, "AC-13: last_shared_unix recorded")
	assert_eq(c.get_phase(), c.Phase.DORMANT, "AC-13: window closes after share")


func test_ac14_evolution_plays_burst_reflection_does_not() -> void:
	# EVOLUTION → #5.play() with the LOOT preset.
	var fp := FakeParticles.new()
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p, null, fp)
	av.emit_milestone(2)
	_tick_to_present(c)
	assert_eq(fp.plays.size(), 1, "AC-14: EVOLUTION fires exactly one celebration burst")
	assert_true(c._config.LOOT_PRESET_INTS.has(fp.plays[0]["preset"]), "AC-14/B-1: burst uses a #5 LOOT preset")
	# REFLECTION → no burst.
	var fp2 := FakeParticles.new()
	var gsm2 := FakeGSM.new()
	var av2 := FakeAvatar.new()
	av2.snap = _snap(2, 2)
	var p2 := MockPersistence.new()
	p2.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c2 := _make(gsm2, av2, p2, null, fp2)
	av2.emit_micro()
	_tick_to_present(c2)
	assert_eq(fp2.plays.size(), 0, "AC-14: REFLECTION fires NO burst")


func test_ac16_dismiss_marks_window_and_clears_latch() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	_tick_to_present(c)
	c.dismiss()
	var rec: Dictionary = p.store["mirror_moment"]
	assert_eq(int(rec["last_ceremony_unix"]), NOW, "AC-16: window marker set to now")
	assert_false(rec["pending_evolution_ceremony"], "AC-16: latch cleared")
	assert_false(rec["week_had_change"], "AC-16: week_had_change cleared")
	assert_eq(int(rec["ceremony_count"]), 1, "AC-16: ceremony_count incremented")


func test_ac17_replay_idempotent_no_double_present() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	# Boot with a persisted pending latch (simulating #26 emitted last session).
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD, "pending_evolution_ceremony": true, "pending_tier": 2}
	var c := _make(gsm, av, p)
	assert_true(c.is_pending_evolution(), "AC-17: latch rebuilt from persistence")
	watch_signals(c)
	# The same milestone is re-delivered (signal replay) — boolean latch makes it a no-op.
	av.emit_milestone(2)
	_tick_to_present(c)
	assert_signal_emit_count(c, "ceremony_presented", 1, "AC-17: replay does NOT open a second ceremony")


func test_ac18_suspend_resume_continue_then_collapse() -> void:
	# Continue branch: resume within 30s.
	var clock := FakeClock.new()
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p, clock)
	av.emit_milestone(2)
	_tick_to_present(c)
	clock.ms = 1000
	gsm.go(FakeGSM.GameState.SUSPENDED)
	assert_eq(c.get_phase(), c.Phase.PAUSED, "AC-18: SUSPENDED mid-ceremony → PAUSED")
	clock.ms = 1000 + 15000  # Δ=15s ≤ 30s
	gsm.go(FakeGSM.GameState.IDLE)
	assert_eq(c.get_phase(), c.Phase.PRESENTING, "AC-18: resume ≤30s → continue")
	# Collapse branch: resume after >30s on a second coordinator.
	var clock2 := FakeClock.new()
	var gsm2 := FakeGSM.new()
	var av2 := FakeAvatar.new()
	av2.snap = _snap(2, 1)
	var p2 := MockPersistence.new()
	p2.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c2 := _make(gsm2, av2, p2, clock2)
	av2.emit_milestone(2)
	_tick_to_present(c2)
	clock2.ms = 1000
	gsm2.go(FakeGSM.GameState.SUSPENDED)
	clock2.ms = 1000 + 45000  # Δ=45s > 30s
	gsm2.go(FakeGSM.GameState.IDLE)
	assert_eq(c2.get_phase(), c2.Phase.DORMANT, "AC-18: resume >30s → collapse + mark window")
	assert_eq(int(p2.store["mirror_moment"]["last_ceremony_unix"]), NOW, "AC-18: window marker kept (no resume spam)")


func test_ac19_persistence_writes_only_mirror_moment_namespace() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	_tick_to_present(c)
	c.dismiss()
	for key in p.store.keys():
		assert_true(String(key).begins_with("mirror_moment"), "AC-19: only mirror_moment.* keys written, got " + str(key))
	assert_eq(int(p.store["mirror_moment"]["schema_version"]), 1, "AC-19: schema_version == 1")


func test_ac21_caption_null_safe_without_soft_deps() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(1, 0, "")  # first-ever tier-up, empty prior sprite
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(1)
	_tick_to_present(c)
	# No #9 workout surface, no #17 receipt → base-form caption, no crash, still presents.
	assert_eq(c.get_phase(), c.Phase.PRESENTING, "AC-21: presents with no soft deps")
	var caption = c._build_caption(F.CONTENT_EVOLUTION, av.snap)
	assert_string_contains(caption, "首次進化", "AC-21/EC-MM-7: first-ever caption, no narrative row, no crash")


func test_ac04_attention_budget_soft_gate_holds() -> void:
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	var att := FakeAttention.new()
	att.permitted = false
	c._attention = att  # #33 present + denies input
	av.emit_milestone(2)
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.ARMED, "AC-04: #33 denies input → ceremony holds even in IDLE")
	att.permitted = true
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.PRESENTING, "AC-04: #33 permits → presents")


func test_ec_mm14_transient_idle_flicker_does_not_present() -> void:
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	# Only a few stable frames (< present_delay_frames), then IDLE flickers to COMBAT.
	c._process(0.0)
	c._process(0.0)
	gsm.go(FakeGSM.GameState.COMBAT_ACTIVE)
	c._process(0.0)
	assert_eq(c.get_phase(), c.Phase.ARMED, "EC-MM-14: transient IDLE flicker → no flash, stays ARMED")


func test_ec_mm16_loot_drop_modal_excluded_from_present() -> void:
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.LOOT_DROP
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	_tick_to_present(c)
	assert_eq(c.get_phase(), c.Phase.ARMED, "EC-MM-16: LOOT_DROP modal active → ceremony holds (no modal stacking)")


func test_ac22_signature_loot_adds_narrative_row() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	var c := _make(gsm, av, p)
	var inv := FakeInventory.new()
	inv.sig = "鍛造自 180kg × 5"
	c._inventory = inv
	var caption = c._build_caption(F.CONTENT_EVOLUTION, av.snap)
	assert_string_contains(caption, "鍛造自 180kg × 5", "AC-22: #17 signature loot adds a narrative row")
	assert_string_contains(caption, "本週簽名戰利品", "AC-22: signature row labelled")


func test_ac25_no_fabrication_overlay_fields_trace_to_snapshot() -> void:
	var gsm := FakeGSM.new()
	var av := FakeAvatar.new()
	av.snap = _snap(2, 1)
	var p := MockPersistence.new()
	p.store["mirror_moment"] = {"last_ceremony_unix": LAST_OLD}
	var c := _make(gsm, av, p)
	av.emit_milestone(2)
	_tick_to_present(c)
	# Every composed visual field is sourced from the present-time snapshot (FT-M2 / AC-25).
	assert_eq(c._overlay_root.get_meta("after_sprite"), av.snap.sprite_frames_resource_path,
		"AC-25: after-sprite traces to snapshot, never fabricated")
	assert_eq(c._overlay_root.get_meta("prior_sprite"), av.snap.prior_sprite_frames_resource_path,
		"AC-25: prior-sprite traces to snapshot")
	assert_eq(c._active_tier, av.snap.tier, "AC-25: presented tier traces to snapshot")
