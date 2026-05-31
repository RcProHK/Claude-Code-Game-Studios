# EnemyDirector — Story 018 AC-34: AOE target distance-sort + clamp to 8 (EC-21).
extends GutTest


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()


func after_each() -> void:
	for child in EnemyDirector.get_children():
		if child is Node2D:
			child.free()
	await get_tree().process_frame
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.set_physics_process(true)


## Create `count` Node2D targets at increasing X distance; return their instance ids in order.
func _make_targets(count: int) -> Array:
	var ids: Array = []
	for i in count:
		var n := Node2D.new()
		n.global_position = Vector2(float(i + 1) * 10.0, 0.0)  # nearest = i 0
		EnemyDirector.add_child(n)
		ids.append(n.get_instance_id())
	return ids


# ---------------------------------------------------------------------------
# AC-34 — clamp to 8 nearest + CLAMP_TRIGGERED
# ---------------------------------------------------------------------------

func test_ac34_twelve_targets_clamped_to_eight() -> void:
	var ids := _make_targets(12)
	watch_signals(EnemyDirector)
	var result: Array = EnemyDirector.call("_expand_targets", ids, Vector2.ZERO)
	assert_eq(result.size(), 8, "AC-34: 12 targets clamped to 8")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly", "AC-34: CLAMP anomaly emitted")
	var payload = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")[0]
	assert_eq(payload.reason, EnemyDirector.REASON_CLAMP_TRIGGERED, "AC-34: reason CLAMP_TRIGGERED")
	assert_eq(payload.context_dump["requested"], 12, "AC-34: context_dump.requested == 12")
	assert_eq(payload.context_dump["capped"], 8, "AC-34: context_dump.capped == 8")


func test_ac34_returns_eight_nearest() -> void:
	var ids := _make_targets(12)  # positions x = 10,20,...,120; ids[0] nearest to origin
	var result: Array = EnemyDirector.call("_expand_targets", ids, Vector2.ZERO)
	# The 8 nearest are ids[0..7]; ids[8..11] (farthest) must be excluded.
	for i in 8:
		assert_true(ids[i] in result, "AC-34: nearest target %d retained" % i)
	for i in range(8, 12):
		assert_false(ids[i] in result, "AC-34: farther target %d clamped out" % i)


func test_ac34_eight_or_fewer_unchanged_no_anomaly() -> void:
	var ids := _make_targets(8)
	watch_signals(EnemyDirector)
	var result: Array = EnemyDirector.call("_expand_targets", ids, Vector2.ZERO)
	assert_eq(result.size(), 8, "AC-34: exactly 8 → unchanged")
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 0,
		"AC-34: no CLAMP anomaly at/under cap")


func test_ac34_empty_targets_safe() -> void:
	var result: Array = EnemyDirector.call("_expand_targets", [] as Array, Vector2.ZERO)
	assert_eq(result.size(), 0, "AC-34: empty target list → empty result, no crash")
