extends GutTest
## Story 005: G-AR-2 / Q-OQ-DEPTH max_class_depth resolution (Option A mock-scoped #12
## read) + EC-TIER-5 fail-safe. Mocks the #12 seam (MockAbilitySystem) and verifies the
## resolved depth feeds the Formula 2 specialist path; the unresolvable case fails safe to
## depth 0 with the generalist path still reaching tiers. CI-INV-2: depth is ONLY ever
## sourced from #12 abilities. See production/epics/avatar-renderer/story-005-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")


class MockAbilityWithDepth:
	extends Node
	var depth: int = 0
	func get_max_unlocked_class_tier() -> int:
		return depth
	func get_unlocked_abilities() -> Dictionary:
		return {}


class MockAbilityNoDepth:
	extends Node
	# Mirrors the SHIPPED #12 surface: get_unlocked_abilities() exists,
	# get_max_unlocked_class_tier() does NOT (the erratum is a follow-up).
	func get_unlocked_abilities() -> Dictionary:
		return {}


func _renderer_with(ability: Node) -> Node:
	var r = AvatarRendererScript.new()
	r._ability = ability  # untyped DI seam; bypasses _ready() boot
	return r


func test_depth_resolves_via_option_a_read() -> void:
	# G-AR-2: Option A reads the additive #12 method.
	var mock := MockAbilityWithDepth.new()
	mock.depth = 3
	var r := _renderer_with(mock)
	assert_eq(r._resolve_max_class_depth({}), 3, "Option A reads #12.get_max_unlocked_class_tier()")
	r.free()
	mock.free()


func test_depth_clamped_to_three() -> void:
	# EC-BOOT-4 parity: a future T4+ depth clamps into the 0..3 range.
	var mock := MockAbilityWithDepth.new()
	mock.depth = 9
	var r := _renderer_with(mock)
	assert_eq(r._resolve_max_class_depth({}), 3, "clamp future depth to 3")
	r.free()
	mock.free()


func test_ec_tier5_failsafe_returns_zero_when_unresolvable() -> void:
	# EC-TIER-5: #12 cannot resolve depth -> 0, never crash.
	var mock := MockAbilityNoDepth.new()
	var r := _renderer_with(mock)
	assert_eq(r._resolve_max_class_depth({}), 0, "EC-TIER-5 fail-safe -> depth 0")
	r.free()
	mock.free()


func test_resolved_depth_feeds_specialist_path() -> void:
	# AC-04: a resolved depth of 3 unlocks the pure-specialist T3 path.
	var mock := MockAbilityWithDepth.new()
	mock.depth = 3
	var r := _renderer_with(mock)
	var depth: int = r._resolve_max_class_depth({})
	var cfg := AvatarEvolutionConfig.new()
	assert_eq(AvatarFormulas.derive_tier(80, 70, 3, depth, cfg, 0), 3,
		"resolved depth 3 + peak 70 -> specialist T3 (not locked by low sum 80)")
	r.free()
	mock.free()


func test_ec_tier5_generalist_still_tiers_with_zero_depth() -> void:
	# EC-TIER-5 corollary: depth 0 turns the specialist path off but a generalist
	# still reaches T3 via the sum/breadth path.
	var cfg := AvatarEvolutionConfig.new()
	assert_eq(AvatarFormulas.derive_tier(102, 34, 6, 0, cfg, 0), 3,
		"generalist sum>=100 & count>=6 reaches T3 with depth 0")
