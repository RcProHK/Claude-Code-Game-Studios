extends GutTest
## Story 011: CombatVisualFeedback (#25) Formula 5 — anchor base spawn position.
## Deterministic part only (jitter is cosmetic RNG, excluded per coding-standards).

const F := preload("res://src/core/combat_visual_feedback_formulas.gd")


func test_anchor_base_matches_gdd_example() -> void:
	# focal_base=(400,300), facing=+1, FORWARD=40, VERTICAL=-16 → (440, 284)
	assert_eq(F.anchor_base(Vector2(400, 300), 1), Vector2(440, 284),
		"Formula 5 base (J=0): focal + (facing×40, -16)")


func test_anchor_base_facing_negative_mirrors_forward() -> void:
	assert_eq(F.anchor_base(Vector2(400, 300), -1), Vector2(360, 284),
		"facing=-1 → forward offset mirrors to -40")


func test_anchor_base_vertical_is_upward() -> void:
	var p := F.anchor_base(Vector2.ZERO, 1)
	assert_lt(p.y, 0.0, "ANCHOR_VERTICAL_PX is negative (upward, torso height)")


func test_anchor_knobs_in_documented_range() -> void:
	assert_almost_eq(F.ANCHOR_FORWARD_PX, 40.0, 0.001, "ANCHOR_FORWARD_PX = 40")
	assert_almost_eq(F.ANCHOR_VERTICAL_PX, -16.0, 0.001, "ANCHOR_VERTICAL_PX = -16")
	assert_almost_eq(F.ANCHOR_JITTER_PX, 24.0, 0.001, "ANCHOR_JITTER_PX = 24")
