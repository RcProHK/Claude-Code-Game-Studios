# EnemyDirector — Story 005 AC-07: Signal Surface Regression Lock
#
# Coverage:
#   AC-07 — EnemyDirector declares EXACTLY 3 user signals:
#     hit_resolved / enemy_killed / combat_metric_anomaly
#   No internal, debug, or extra signals may be added.
#   This is a regression guard: Story 001 declared the signals; AC-07 locks them
#   so no future story silently adds a 4th signal.
extends GutTest


## Return all user-declared signal names on EnemyDirector (excludes Node built-ins).
func _get_user_signals() -> Array[String]:
	# Collect Node built-in signal names to exclude. free() the probe to avoid orphan leak.
	var probe := Node.new()
	var node_signals: Array[String] = []
	for s: Dictionary in probe.get_signal_list():
		node_signals.append(String(s.get("name", "")))
	probe.free()
	# Filter EnemyDirector signals.
	var user_sigs: Array[String] = []
	for s: Dictionary in EnemyDirector.get_signal_list():
		var name: String = String(s.get("name", ""))
		if not node_signals.has(name):
			user_sigs.append(name)
	return user_sigs


# ---------------------------------------------------------------------------
# AC-07: exactly 3 user-declared signals
# ---------------------------------------------------------------------------

## Signal count must be exactly 3 (regression lock).
func test_ac07_exactly_3_user_signals() -> void:
	var user_sigs := _get_user_signals()
	assert_eq(user_sigs.size(), 3,
		"AC-07: EnemyDirector must declare exactly 3 user signals (hit_resolved/enemy_killed/combat_metric_anomaly)")


## hit_resolved must be in the signal list.
func test_ac07_hit_resolved_declared() -> void:
	assert_true(_get_user_signals().has("hit_resolved"),
		"AC-07: hit_resolved must be declared on EnemyDirector")


## enemy_killed must be in the signal list.
func test_ac07_enemy_killed_declared() -> void:
	assert_true(_get_user_signals().has("enemy_killed"),
		"AC-07: enemy_killed must be declared on EnemyDirector")


## combat_metric_anomaly must be in the signal list.
func test_ac07_combat_metric_anomaly_declared() -> void:
	assert_true(_get_user_signals().has("combat_metric_anomaly"),
		"AC-07: combat_metric_anomaly must be declared on EnemyDirector")
