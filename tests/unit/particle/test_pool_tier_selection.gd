# ParticleSystemWrapper — Story 002: object pool composition + tier selection + no-realloc.
#
# Coverage:
#   AC-03 — pool fixed at boot: 16 nodes (SMALL 8 / MEDIUM 6 / LARGE 2), PRESET_TABLE
#           size 9 with the 9 PresetId keys, per-tier amount buffers 32/96/256, amount
#           set exactly once at boot.
#   AC-04 — tier selection by final_count band; LOOT always LARGE; amount never
#           reassigned after mixed plays; defensive 0/negative; over-256 warn.
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


## Duck-typed GPU node stub with an `amount` setter that counts assignments — the
## load-bearing mechanism for the "never reassigned post-boot" invariant (AC-04).
## emitting/amount/restart are not native Node members, so nothing is overridden.
class _StubParticleNode:
	extends Node
	var emitting: bool = false
	var amount_set_count: int = 0
	var _amount: int = 0
	var amount: int:
		set(v):
			amount_set_count += 1
			_amount = v
		get:
			return _amount
	func restart(_keep_seed: bool = false) -> void:
		pass


var _sut


func before_each() -> void:
	_sut = PSW.new()
	_sut._node_factory = func() -> Node: return _StubParticleNode.new()
	add_child_autofree(_sut)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# AC-03 — pool composition fixed at boot
# ---------------------------------------------------------------------------

func test_pool_has_16_nodes_split_8_6_2() -> void:
	var slots: Array = _sut._pool
	assert_eq(slots.size(), 16, "AC-03: total pool size must be 16")
	var counts := {"SMALL": 0, "MEDIUM": 0, "LARGE": 0}
	for s in slots:
		counts[s.tier] += 1
	assert_eq(counts["SMALL"], 8, "AC-03: SMALL tier must have 8 nodes")
	assert_eq(counts["MEDIUM"], 6, "AC-03: MEDIUM tier must have 6 nodes")
	assert_eq(counts["LARGE"], 2, "AC-03: LARGE tier must have 2 nodes")


func test_preset_table_has_exactly_9_preset_keys() -> void:
	assert_eq(PSW.PRESET_TABLE.size(), 9, "AC-03: PRESET_TABLE must have 9 entries")
	for pid in PSW.PresetId.values():
		assert_true(PSW.PRESET_TABLE.has(pid),
			"AC-03: PRESET_TABLE must contain every PresetId (set equality) — missing %d" % pid)


func test_tier_amount_buffers_are_32_96_256() -> void:
	var expected := {"SMALL": 32, "MEDIUM": 96, "LARGE": 256}
	for s in _sut._pool:
		assert_eq(s.node.amount, expected[s.tier],
			"AC-03: %s node amount buffer must be %d" % [s.tier, expected[s.tier]])


func test_amount_set_exactly_once_at_boot() -> void:
	for s in _sut._pool:
		assert_eq(s.node.amount_set_count, 1,
			"AC-03: each node amount must be set exactly once at boot")


# ---------------------------------------------------------------------------
# AC-04 — tier selection
# ---------------------------------------------------------------------------

func test_select_tier_band_boundaries() -> void:
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 1), "SMALL", "AC-04: 1 → SMALL")
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 32), "SMALL", "AC-04: 32 → SMALL")
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 33), "MEDIUM", "AC-04: 33 → MEDIUM")
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 96), "MEDIUM", "AC-04: 96 → MEDIUM")
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 97), "LARGE", "AC-04: 97 → LARGE")
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 256), "LARGE", "AC-04: 256 → LARGE")


func test_loot_presets_always_large_regardless_of_count() -> void:
	assert_eq(_sut._select_tier(PSW.PresetId.LOOT_BURST, 1), "LARGE", "AC-04: LOOT_BURST tiny → LARGE")
	assert_eq(_sut._select_tier(PSW.PresetId.LOOT_RARE_BURST, 5), "LARGE", "AC-04: LOOT_RARE_BURST tiny → LARGE")
	assert_eq(_sut._select_tier(PSW.PresetId.LOOT_BURST, 300), "LARGE", "AC-04: LOOT_BURST huge → LARGE")


func test_select_tier_zero_and_negative_route_small_no_crash() -> void:
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 0), "SMALL", "AC-04: 0 → SMALL (defensive)")
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, -5), "SMALL", "AC-04: negative → SMALL (defensive)")


func test_select_tier_over_max_warns_and_clamps_large() -> void:
	var warnings: Array = []
	_sut._warn_sink = func(m): warnings.append(m)
	assert_eq(_sut._select_tier(PSW.PresetId.HIT_LIGHT, 300), "LARGE",
		"AC-04: final_count > 256 falls back to LARGE")
	assert_eq(warnings.size(), 1, "AC-04: over-buffer selection emits one warning")


func test_amount_never_reassigned_after_mixed_plays() -> void:
	var presets := [PSW.PresetId.HIT_LIGHT, PSW.PresetId.HIT_HEAVY, PSW.PresetId.LOOT_BURST, PSW.PresetId.STATUS_BURN]
	for i in 20:
		_sut.play(presets[i % presets.size()], Vector2(i, i), 1.0)
	for s in _sut._pool:
		assert_eq(s.node.amount_set_count, 1,
			"AC-04: amount setter count stays 1 after 20 mixed plays (no runtime realloc)")
