# ParticleSystemWrapper — Story 008: preset library + visual spec .tres (Config/Data smoke).
#
# Coverage (smoke / schema — Config/Data story):
#   AC-S1 — 9 .tres ParticleProcessMaterial assets load without error; PRESET_TABLE has the
#           9 PresetId keys (set equality).
#   AC-S2 — each PRESET_TABLE entry is schema-complete: base_count(int), lifetime(float),
#           z_index(int), material_path(String) → loads as ParticleProcessMaterial.
#   AC-S3 — spot checks: HIT_LIGHT count/lifetime/z_index; z_index discipline (combat 5 /
#           status 4 / loot 7); count range [4, 48].
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


# ---------------------------------------------------------------------------
# AC-S1 — 9 .tres load + PRESET_TABLE keys
# ---------------------------------------------------------------------------

func test_preset_table_has_9_preset_keys() -> void:
	assert_eq(PSW.PRESET_TABLE.size(), 9, "AC-S1: PRESET_TABLE has 9 entries")
	for pid in PSW.PresetId.values():
		assert_true(PSW.PRESET_TABLE.has(pid), "AC-S1: PRESET_TABLE contains PresetId %d" % pid)


func test_all_9_material_tres_load_as_particle_process_material() -> void:
	for pid in PSW.PRESET_TABLE:
		var path: String = PSW.PRESET_TABLE[pid]["material_path"]
		assert_true(ResourceLoader.exists(path), "AC-S1: material exists: %s" % path)
		var res := load(path)
		assert_not_null(res, "AC-S1: material loads: %s" % path)
		assert_true(res is ParticleProcessMaterial,
			"AC-S2: %s loads as ParticleProcessMaterial" % path)


# ---------------------------------------------------------------------------
# AC-S2 — schema completeness + types
# ---------------------------------------------------------------------------

func test_every_entry_is_schema_complete() -> void:
	for pid in PSW.PRESET_TABLE:
		var e: Dictionary = PSW.PRESET_TABLE[pid]
		assert_true(e.has("base_count") and e["base_count"] is int, "AC-S2: base_count int (%d)" % pid)
		assert_true(e.has("lifetime") and e["lifetime"] is float, "AC-S2: lifetime float (%d)" % pid)
		assert_true(e.has("z_index") and e["z_index"] is int, "AC-S2: z_index int (%d)" % pid)
		assert_true(e.has("material_path") and e["material_path"] is String, "AC-S2: material_path String (%d)" % pid)


# ---------------------------------------------------------------------------
# AC-S3 — spot checks
# ---------------------------------------------------------------------------

func test_hit_light_spot_values() -> void:
	var e: Dictionary = PSW.PRESET_TABLE[PSW.PresetId.HIT_LIGHT]
	assert_eq(e["base_count"], 8, "AC-S3: HIT_LIGHT base_count 8")
	assert_almost_eq(e["lifetime"], 0.25, 0.0001, "AC-S3: HIT_LIGHT lifetime 0.25")
	assert_eq(e["z_index"], 5, "AC-S3: HIT_LIGHT z_index 5")


func test_z_index_layer_discipline() -> void:
	var combat := [PSW.PresetId.HIT_LIGHT, PSW.PresetId.HIT_HEAVY, PSW.PresetId.PARRY, PSW.PresetId.DEATH]
	var status := [PSW.PresetId.STATUS_BURN, PSW.PresetId.STATUS_FREEZE, PSW.PresetId.STATUS_STUN]
	var loot := [PSW.PresetId.LOOT_BURST, PSW.PresetId.LOOT_RARE_BURST]
	for pid in combat:
		assert_eq(PSW.PRESET_TABLE[pid]["z_index"], 5, "AC-S3: combat z_index 5 (%d)" % pid)
	for pid in status:
		assert_eq(PSW.PRESET_TABLE[pid]["z_index"], 4, "AC-S3: status z_index 4 (%d)" % pid)
	for pid in loot:
		assert_eq(PSW.PRESET_TABLE[pid]["z_index"], 7, "AC-S3: loot z_index 7 — renders above combat (%d)" % pid)


func test_base_count_in_visual_spec_range() -> void:
	for pid in PSW.PRESET_TABLE:
		var c: int = PSW.PRESET_TABLE[pid]["base_count"]
		assert_between(c, 4, 48, "AC-S3: base_count %d in [4,48] (preset %d)" % [c, pid])
