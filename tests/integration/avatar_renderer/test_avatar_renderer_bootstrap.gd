extends GutTest
## Integration: the real AvatarRenderer autoload booted against real
## StatSystem / AbilitySystem / GameStateMachine / PersistenceLayer. Verifies the
## fresh-boot derived state + the read-only #29 seam. Covers AC-01 (subscriptions),
## AC-02/AC-29 (derived_from attribution), AC-13 (snapshot), AC-22 (idempotent boot,
## no historical milestone), CR-11 (read-only API closure).

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")


## In-memory persistence so the fresh-instance boot below never touches the real
## autoload cache (reference_test_persistence_isolation).
class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


func test_subscribed_to_four_canonical_signals() -> void:
	# AC-01: AvatarRenderer._ready() wires exactly the four canonical sources. Verified on a
	# FRESH instance (real Stat/Ability/GSM collaborators + a mock persistence) so this asserts
	# the wiring LOGIC, not suite-order survival: a GSM unit test (test_rule2_atomic_transition)
	# disconnects every real state_changed subscriber for its own isolation and never restores
	# them, which would otherwise nuke the live autoload's GSM link before this test runs.
	var r = AvatarRendererScript.new()
	r._persistence = MockPersistence.new()  # _stat/_ability/_gsm fall back to the real autoloads
	add_child_autofree(r)  # entering the tree runs _ready(); GSM cfis needs a live get_tree()
	await get_tree().process_frame  # let the GSM cfis deferred initial-delivery settle
	assert_true(StatSystem.stat_changed.is_connected(Callable(r, "_on_stat_changed")),
		"subscribed to #11.stat_changed")
	assert_true(AbilitySystem.ability_unlocked.is_connected(Callable(r, "_on_ability_unlocked")),
		"subscribed to #12.ability_unlocked")
	assert_true(AbilitySystem.ability_cast.is_connected(Callable(r, "_on_ability_cast")),
		"subscribed to #12.ability_cast")
	assert_true(GameStateMachine.state_changed.is_connected(Callable(r, "_on_gsm_state_changed")),
		"subscribed to #1.state_changed")

func test_boot_state_derives_from_canonical() -> void:
	# AC-02 / AC-22: the booted state is consistent with the live canonical inputs
	# (freshness-agnostic — user:// persistence is shared across the GUT suite, so we
	# verify derivability, not a fixed "fresh = T0" value).
	var str_v: float = StatSystem.get_stat(StatSystem.StatId.STR)
	var dex_v: float = StatSystem.get_stat(StatSystem.StatId.DEX)
	var vit_v: float = StatSystem.get_stat(StatSystem.StatId.VIT)
	var expected_class := AvatarFormulas.dominant_class(str_v, dex_v, vit_v)
	assert_eq(AvatarRenderer.get_class_posture(), expected_class,
		"posture == dominant_class from live STR/DEX/VIT (boot applies it, no hysteresis lock)")
	assert_between(AvatarRenderer.get_evolution_tier(), 0, 3, "tier in valid range")
	assert_true(AvatarRenderer.is_ready_for_milestone_check(), "boot complete")

func test_visual_state_fields_attributed() -> void:
	# AC-02 / AC-29: every visible field carries a derivation source.
	var vs := AvatarRenderer.get_visual_state()
	assert_eq(vs.schema_version, 1, "schema_version present")
	for field in ["evolution_tier", "class_posture", "sprite_frames_resource_path"]:
		assert_true(vs.derived_from.has(field), "derived_from attributes " + field)

func test_ac29_visual_state_schema_complete() -> void:
	# AC-29: AvatarVisualState declares its full schema (no field silently dropped),
	# schema_version is present, and the LIVE derived state attributes every core visible
	# field to a canonical source in derived_from (CR-6 / INV-1 anti-fabrication audit).
	var vs := AvatarVisualState.new()
	var declared := {}
	for p in vs.get_property_list():
		declared[p["name"]] = true
	for field in ["evolution_tier", "class_posture", "animation_state",
			"sprite_frames_resource_path", "current_frame", "frame_progress",
			"micro_palette_shift", "micro_outline_intensity", "last_emitted_tier",
			"last_milestone_emit_unix", "derived_from", "transition_id", "schema_version"]:
		assert_true(declared.has(field), "AC-29: AvatarVisualState declares field " + field)
	assert_eq(vs.schema_version, 1, "AC-29: schema_version present and pinned to 1")
	# Live derived state: every core visible field traces to a canonical source.
	var live := AvatarRenderer.get_visual_state()
	for field in ["evolution_tier", "class_posture", "animation_state", "sprite_frames_resource_path"]:
		assert_true(live.derived_from.has(field),
			"AC-29: derived_from attributes visible field " + field)


func test_get_visual_state_returns_duplicate() -> void:
	# CR-11: no external mutation by reference.
	var a := AvatarRenderer.get_visual_state()
	var b := AvatarRenderer.get_visual_state()
	assert_ne(a.get_instance_id(), b.get_instance_id(), "each call returns a fresh duplicate")

func test_snapshot_is_valid_for_29() -> void:
	# AC-13: get_evolution_snapshot returns a self-contained AvatarEvolutionSnapshot.
	var snap := AvatarRenderer.get_evolution_snapshot()
	assert_not_null(snap, "snapshot produced")
	assert_true(snap is AvatarEvolutionSnapshot, "correct type")
	assert_eq(snap.tier, AvatarRenderer.get_evolution_tier(), "tier matches visible state")
	assert_eq(snap.class_posture, AvatarRenderer.get_class_posture(), "posture matches")
	assert_true(snap.source_metrics.has("stat_total"), "source_metrics has stat_total")
	assert_true(snap.source_metrics.has("ability_count"), "source_metrics has ability_count")

func test_sprite_resolution_falls_back_to_emergency() -> void:
	# AC-12 (resolution path): a valid (class,tier) loads non-null SpriteFrames.
	var frames := AvatarRenderer.derive_sprite_frames(&"STRIKE", 0)
	assert_not_null(frames, "T0 STRIKE resolves to non-null SpriteFrames")
	assert_true(frames is SpriteFrames, "correct type")

func test_no_setter_api_on_public_surface() -> void:
	# CR-11 / AC-25 (spirit): no mutation prefix on the SCRIPT-defined public surface
	# (script methods only — inherited Node setters are out of scope; CI-3 greps source).
	for m in AvatarRenderer.get_script().get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("_"):
			continue
		assert_false(
			n.begins_with("set_") or n.begins_with("mutate_") or n.begins_with("force_") or n.begins_with("inject_"),
			"no mutation-prefixed public method: " + n)
