# BossTemplate / BossVisualResource / AttackPatternResource schema test (Story 001, AC-01).
#
# Verifies the boss data-resource SCHEMA contracts via `.new()` instantiation:
# field presence, types, defaults, and the enum declarations. The .tres content
# files are authored later (boss content), so this tests the schema, not data.
#
# Key ADR-0007 assertion: class_archetype defaults to the UNKNOWN sentinel (3),
# NOT STRIKE (0) — a zero-default would silently fabricate a STRIKE boss
# (Pillar 1 violation). Rule 13 maps UNKNOWN -> STRIKE explicitly at spawn.
extends GutTest


# ---------------------------------------------------------------------------
# AC-01 — BossTemplate required fields present + correct types
# ---------------------------------------------------------------------------

func test_boss_template_instantiates() -> void:
	var t := BossTemplate.new()
	assert_not_null(t, "AC-01: BossTemplate.new() must construct")


func test_boss_template_has_all_required_fields_with_types() -> void:
	# Arrange
	var t := BossTemplate.new()
	# Assert — presence + default type per Rule 1 schema
	assert_eq(typeof(t.boss_id), TYPE_STRING_NAME, "AC-01: boss_id is StringName")
	assert_eq(typeof(t.class_archetype), TYPE_INT, "AC-01: class_archetype is int (ordinal)")
	assert_eq(typeof(t.tier), TYPE_INT, "AC-01: tier is a BossTier enum (int-backed)")
	assert_eq(typeof(t.base_hp), TYPE_INT, "AC-01: base_hp is int")
	assert_eq(typeof(t.base_defense), TYPE_INT, "AC-01: base_defense is int")
	assert_eq(typeof(t.attack_patterns), TYPE_ARRAY, "AC-01: attack_patterns is Array")
	assert_eq(typeof(t.loot_guarantee_min_tier), TYPE_INT, "AC-01: loot_guarantee_min_tier is int (ordinal)")
	assert_eq(typeof(t.reveal_ritual_intensity), TYPE_FLOAT, "AC-01: reveal_ritual_intensity is float")
	assert_eq(typeof(t.arena_constraint_mode), TYPE_INT, "AC-01: arena_constraint_mode is enum (int)")
	assert_eq(typeof(t.arena_constraint_px), TYPE_VECTOR2, "AC-01: arena_constraint_px is Vector2")
	# boss_scene / visual_template / audio_template_id presence (null/empty default OK)
	assert_true("boss_scene" in t, "AC-01: boss_scene field present")
	assert_true("visual_template" in t, "AC-01: visual_template field present")
	assert_true("audio_template_id" in t, "AC-01: audio_template_id field present")


# ---------------------------------------------------------------------------
# ADR-0007 — class_archetype defaults to UNKNOWN sentinel, NOT STRIKE
# ---------------------------------------------------------------------------

func test_boss_template_class_archetype_defaults_unknown_not_strike() -> void:
	var t := BossTemplate.new()
	# UNKNOWN = ordinal 3 (mirrors AbilitySystem.AbilityClass). A 0 (STRIKE)
	# default would be a forbidden zero-default fabrication (ADR-0007 Family B).
	assert_eq(t.class_archetype, 3,
		"ADR-0007: class_archetype default must be UNKNOWN(3), never STRIKE(0)")


func test_boss_template_loot_guarantee_defaults_rare() -> void:
	var t := BossTemplate.new()
	# RARE = ordinal 2 (LootEnums.RarityTier). Pass 4 A3.1 final-boss floor.
	assert_eq(t.loot_guarantee_min_tier, 2,
		"AC-09 floor: FINAL boss loot_guarantee_min_tier default == RARE(2)")


func test_boss_template_reveal_intensity_defaults_one() -> void:
	var t := BossTemplate.new()
	assert_eq(t.reveal_ritual_intensity, 1.0,
		"Formula 4 / AC-24: final boss reveal_ritual_intensity default 1.0 (<= 1.5 #5 ceiling)")


# ---------------------------------------------------------------------------
# Enum declarations (Rule 1)
# ---------------------------------------------------------------------------

func test_boss_tier_enum_final_only() -> void:
	# CRIT-2: STANDARD removed; FINAL is the only member.
	assert_eq(BossTemplate.BossTier.size(), 1, "AC-01: BossTier has exactly 1 member (FINAL)")
	assert_eq(BossTemplate.BossTier.FINAL, 0, "AC-01: BossTier.FINAL ordinal 0")


func test_arena_constraint_mode_enum_order() -> void:
	assert_eq(BossTemplate.ArenaConstraintMode.WORLD_ABSOLUTE, 0, "AC-01: WORLD_ABSOLUTE=0")
	assert_eq(BossTemplate.ArenaConstraintMode.SPAWN_RELATIVE, 1, "AC-01: SPAWN_RELATIVE=1")
	assert_eq(BossTemplate.ArenaConstraintMode.AVATAR_LEASH, 2, "AC-01: AVATAR_LEASH=2")


func test_boss_template_default_arena_mode_is_spawn_relative() -> void:
	var t := BossTemplate.new()
	assert_eq(t.arena_constraint_mode, BossTemplate.ArenaConstraintMode.SPAWN_RELATIVE,
		"Rule 14: default ArenaConstraintMode is SPAWN_RELATIVE")


# ---------------------------------------------------------------------------
# BossVisualResource — separate file (GP-F2), correct schema
# ---------------------------------------------------------------------------

func test_boss_visual_resource_instantiates_with_fields() -> void:
	var v := BossVisualResource.new()
	assert_not_null(v, "GP-F2: BossVisualResource.new() constructs (own file, file-level class_name)")
	assert_eq(typeof(v.sprite_scale), TYPE_VECTOR2, "BossVisualResource.sprite_scale is Vector2")
	assert_eq(v.sprite_scale, Vector2.ONE, "BossVisualResource.sprite_scale default ONE")
	assert_eq(v.silhouette_test_size_px, 32, "BossVisualResource.silhouette_test_size_px default 32")
	assert_eq(v.rim_light_color, Color.WHITE, "BossVisualResource.rim_light_color default WHITE")
	assert_true("sprite_texture" in v, "BossVisualResource.sprite_texture field present")
	assert_true("anim_set" in v, "BossVisualResource.anim_set field present")


# ---------------------------------------------------------------------------
# AttackPatternResource — class_name + schema
# ---------------------------------------------------------------------------

func test_attack_pattern_resource_schema() -> void:
	var p := AttackPatternResource.new()
	assert_not_null(p, "AttackPatternResource.new() constructs (file-level class_name)")
	assert_eq(p.telegraph_duration_sec, 0.5, "AttackPatternResource.telegraph_duration_sec default 0.5")
	assert_eq(p.damage_multiplier, 1.0, "AttackPatternResource.damage_multiplier default 1.0")
	assert_eq(p.cooldown_sec, 2.0, "AttackPatternResource.cooldown_sec default 2.0")
	assert_eq(typeof(p.pattern_id), TYPE_STRING_NAME, "AttackPatternResource.pattern_id is StringName")
	assert_eq(typeof(p.hit_radius_px), TYPE_FLOAT, "AttackPatternResource.hit_radius_px is float")


func test_boss_template_attack_patterns_holds_attack_pattern_resources() -> void:
	# Schema wiring: the array accepts AttackPatternResource instances.
	var t := BossTemplate.new()
	var p := AttackPatternResource.new()
	p.pattern_id = &"jab"
	t.attack_patterns.append(p)
	assert_eq(t.attack_patterns.size(), 1, "attack_patterns accepts AttackPatternResource")
	assert_eq((t.attack_patterns[0] as AttackPatternResource).pattern_id, &"jab",
		"attack_patterns element is a typed AttackPatternResource")
