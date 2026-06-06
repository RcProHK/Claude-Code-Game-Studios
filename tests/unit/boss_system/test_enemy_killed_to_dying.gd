# BossInstance enemy_killed -> DYING self-filtered wiring (Story 011:
# AC-08 / AC-11b + EC-24 idempotency). The handler is typed (payload: EnemyKilledPayload,
# a file-level class_name) and self-filters on transition_id.
#
# Bosses are built OFF-tree so _enter_state(DYING) -> _play_death_and_free sees
# not is_inside_tree -> cleanup-only (no queue_free), keeping the node valid to assert.
extends GutTest

const DYING := EnemyDirector.EnemyAIState.DYING
const SPAWNING := EnemyDirector.EnemyAIState.SPAWNING


func _boss(tid: String) -> BossInstance:
	var b: BossInstance = autofree(BossInstance.new())
	b.transition_id = tid
	return b


func _payload(tid: String) -> EnemyKilledPayload:
	var p := EnemyKilledPayload.new()
	p.transition_id = tid
	return p


# ---------------------------------------------------------------------------
# AC-11b / AC-08 — self-filtered death
# ---------------------------------------------------------------------------

func test_ac11b_own_id_enters_dying() -> void:
	var b := _boss("abc")
	b._on_enemy_killed_self_listen(_payload("abc"))
	assert_eq(b._ai_state, DYING, "AC-11b: own transition_id -> _enter_state(DYING)")


func test_ac11b_other_id_ignored() -> void:
	var b := _boss("abc")
	b._on_enemy_killed_self_listen(_payload("OTHER_id"))
	assert_eq(b._ai_state, SPAWNING,
		"AC-11b: a different boss's kill is ignored (self-filter holds; stays SPAWNING)")


func test_ac11b_double_fire_idempotent() -> void:
	var b := _boss("abc")
	b._on_enemy_killed_self_listen(_payload("abc"))
	assert_eq(b._ai_state, DYING, "first fire enters DYING")
	# Second fire (already DYING) — _enter_state early-returns, no double cleanup, no crash.
	b._on_enemy_killed_self_listen(_payload("abc"))
	assert_eq(b._ai_state, DYING, "AC-11b: second fire idempotent (double-cleanup guard)")


func test_ac08_payload_transition_id_is_the_filter_key() -> void:
	# Exact-match filter: a near-miss id does NOT trigger (no substring / prefix match).
	var b := _boss("abc")
	b._on_enemy_killed_self_listen(_payload("abc_extra"))
	assert_eq(b._ai_state, SPAWNING, "AC-08: filter is exact transition_id equality, not prefix")
	b._on_enemy_killed_self_listen(_payload("abc"))
	assert_eq(b._ai_state, DYING, "AC-08: exact match triggers")


# ---------------------------------------------------------------------------
# EC-24 — HP->0 also routes to DYING idempotently (single death path)
# ---------------------------------------------------------------------------

func test_ec24_hp_zero_then_enemy_killed_single_dying() -> void:
	var b := _boss("abc")
	b.max_hp = 100
	b._set_current_hp(0)               # defensive in-instance DYING trigger
	assert_eq(b._ai_state, DYING, "HP->0 enters DYING")
	b._on_enemy_killed_self_listen(_payload("abc"))  # the real Rule 8 kill, already DYING
	assert_eq(b._ai_state, DYING, "EC-24: HP->0 then enemy_killed = single DYING (idempotent)")
