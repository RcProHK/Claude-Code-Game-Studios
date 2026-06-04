## Integration test — GymModeHud Story 012: .tscn scene structure + node binding + metadata
##
## Headless verification of the built scene (the visual sign-off / playtest AC remain external).
##
## Coverage:
##   AC-SCENE-1/2 — scene instantiates; root Control; WorkoutAudioAdapter child + 6 zone nodes
##   AC-SCENE-3   — SKILLS cluster glance_group/cluster_icon_cap metadata (unlocks Story 009)
##   AC-SCENE-4   — banner focus_mode FOCUS_NONE + ≥44×44
##   AC-SCENE-5   — Z1 anchor 0px reflow across all 9 GSM states (unlocks Story 011 AC-UX-3)
##   AC-SCENE-6   — _apply_state_matrix → node modulate.a == get_emphasis_alpha; HIDDEN/DEFER → not visible
extends GutTest

const SCENE := preload("res://src/ui/gym_mode_hud/GymModeHud.tscn")


func _instance() -> Node:
	var h: Node = SCENE.instantiate()
	add_child_autofree(h)
	return h


# ── AC-SCENE-1/2: structure ──

func test_scene_instantiates_root_control() -> void:
	var h := _instance()
	assert_true(h is Control, "AC-SCENE-1: root is a Control with the HUD script")


func test_adapter_child_present() -> void:
	var h := _instance()
	var adapter := h.get_node_or_null("WorkoutAudioAdapter")
	assert_not_null(adapter, "AC-SCENE-1: WorkoutAudioAdapter child node present")


func test_zone_nodes_present() -> void:
	var h := _instance()
	for path in [
		"Zones/Z1/HPBar", "Zones/Z1/EXPBar", "Zones/Z3/StatBlock",
		"Zones/Z5/SkillsCluster", "Zones/PROG/ProgLabel", "Zones/Z6/BossBar", "Banner",
	]:
		assert_not_null(h.get_node_or_null(path), "AC-SCENE-2: node present at %s" % path)


# ── AC-SCENE-3: glance metadata (unlocks Story 009 deferred) ──

func test_skills_cluster_metadata() -> void:
	var h := _instance()
	var cluster := h.get_node("Zones/Z5/SkillsCluster")
	assert_eq(cluster.get_meta("glance_group"), true,
		"AC-SCENE-3: SKILLS cluster glance_group == true")
	assert_eq(int(cluster.get_meta("cluster_icon_cap")), h.SKILL_CLUSTER_DISPLAY_CAP,
		"AC-SCENE-3: cluster_icon_cap == SKILL_CLUSTER_DISPLAY_CAP (4)")


func test_tier1_elements_have_glance_visible_meta() -> void:
	var h := _instance()
	for path in ["Zones/Z1/HPBar", "Zones/Z1/EXPBar", "Zones/Z5/SkillsCluster", "Zones/Z6/BossBar"]:
		assert_true(h.get_node(path).has_meta("glance_visible"),
			"AC-SCENE-3: %s has glance_visible meta" % path)


# ── AC-SCENE-4: banner ──

func test_banner_focus_none_and_touch_target() -> void:
	var h := _instance()
	var banner := h.get_node("Banner")
	assert_eq(banner.focus_mode, Control.FOCUS_NONE,
		"AC-SCENE-4: banner focus_mode == FOCUS_NONE (one-tap, no focus ring)")
	assert_gte(banner.custom_minimum_size.x, 44.0, "AC-SCENE-4: banner width ≥ 44")
	assert_gte(banner.custom_minimum_size.y, 44.0, "AC-SCENE-4: banner height ≥ 44")


# ── AC-SCENE-5: Z1 0px anchor across states (unlocks Story 011 AC-UX-3) ──

func test_z1_anchor_zero_reflow_across_states() -> void:
	var h := _instance()
	await get_tree().process_frame
	var z1: Control = h.get_node("Zones/Z1")
	var baseline: Rect2 = z1.get_global_rect()
	for state in [
		GameStateMachine.GameState.BOOTING, GameStateMachine.GameState.DISCONNECTED,
		GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.REST_PERIOD, GameStateMachine.GameState.COMBAT_ACTIVE,
		GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.LOOT_DROP,
		GameStateMachine.GameState.SUSPENDED,
	]:
		h._apply_state_matrix(state)
		await get_tree().process_frame
		assert_eq(z1.get_global_rect(), baseline,
			"AC-SCENE-5: Z1 anchor 0px reflow at state %d (emphasis changes never move Z1)" % state)


# ── AC-SCENE-6: emphasis → node render binding ──

func test_emphasis_mirrors_to_node_modulate() -> void:
	var h := _instance()
	h._apply_state_matrix(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_almost_eq(h.get_node("Zones/Z1/HPBar").modulate.a, 1.0, 0.001,
		"AC-SCENE-6: WORKOUT HP ◉ → node modulate.a == 1.0")
	assert_almost_eq(h.get_node("Zones/Z3/StatBlock").modulate.a, 0.22, 0.001,
		"AC-SCENE-6: WORKOUT STAT ◐ → node modulate.a == 0.22")


func test_loot_defer_hides_prog_node() -> void:
	var h := _instance()
	h._apply_state_matrix(GameStateMachine.GameState.LOOT_DROP)
	assert_false(h.get_node("Zones/PROG/ProgLabel").visible,
		"AC-SCENE-6: LOOT_DROP PROG ▽defer → node not visible (alpha 0)")
	assert_almost_eq(h.get_node("Zones/Z1/HPBar").modulate.a, 0.55, 0.001,
		"AC-SCENE-6: LOOT_DROP HP ○dim → node modulate.a == 0.55")


func test_exp_value_mirrors_to_bar_node() -> void:
	var h := _instance()
	h._reduce_motion = true  # instant set path (deterministic, no async tween)
	h._current_exp = 340.0
	h._exp_to_next = 500.0
	h._set_exp_fill(h.compute_exp_fill(340.0, 500.0))
	assert_almost_eq(h.get_node("Zones/Z1/EXPBar").value, 0.68, 0.001,
		"AC-SCENE-6: _exp_bar_value mirrors to EXP bar node value (0.68)")
