## BossSystem — final-boss spawn orchestrator (Story 007, GDD GP-F4 contract)
##
## Driving GDD:
##   * design/gdd/boss-system.md — BossSystem autoload contract + Rule 7 (spawn ordering) + Rule 8
##
## Governing ADRs:
##   * ADR-0006 (transition_id provenance — Contract 2 idempotency)
##   * ADR-0009 (boss_committed payload — intrinsic + transition_id)
##
## Driving Story: production/epics/boss-system/story-007-boss-system-autoload-spawn.md
## Implementing TRs: TR-boss-002 (deterministic spawn), TR-boss-006 (transition_id chain), TR-boss-014
##
## Extends Node — the root for spawned BossInstance children; MUST have identity
## transform (Pass 4 A2.3 parent-identity contract — BossInstance is never nested
## under a transform-modifying parent). Registered as an autoload so #14 EnemyDirector
## can call spawn_boss at BossAnchor COMMITTED (autoload registration deferred — see
## Story 007 notes — until a consumer wires it; spawn logic is testable via `.new()`).
##
## Idempotency (EC-01): same transition_id replay is rejected (tombstone-style);
## the id is evicted when the boss frees (session-scoped, bounds Web Export memory).
class_name BossSystem extends Node

## Emitted synchronously right after a boss commits (subscribers: #5/#6/#7/Audio/
## #28, connected at their own _ready via connect_for_initial_state — NOT here).
signal boss_committed(
	template: BossTemplate,
	boss: BossInstance,
	snapshot: BossSpawnContext,
	spawn_pos: Vector2,
	transition_id: String)

const POSITION_TOLERANCE_PX: float = 0.5

## transition_id:String -> true. Rejects same-id replay (EC-01). Evicted on boss free.
var _spawned_transition_ids: Dictionary = {}


## GP-F3 scene instantiation — instantiates the template's PackedScene (which
## carries the required scene-tree children), NOT a bare BossInstance.new().
func _instantiate_boss(template: BossTemplate) -> BossInstance:
	assert(template.boss_scene != null, "BossTemplate.boss_scene MUST be set (GP-F3)")
	var boss := template.boss_scene.instantiate() as BossInstance
	assert(boss != null, "boss_scene root MUST be type BossInstance")
	return boss


## GP-F5 telemetry helper — local graceful noop until #28 Telemetry lands.
## NEVER hard-depends on #28 (Pillar 2 — boss must run without it).
func _emit_telemetry(event: StringName, payload: Dictionary) -> void:
	if OS.is_debug_build():
		print_verbose("[BossSystem telemetry] %s %s" % [event, payload])


## Spawn the final boss (A1.3 canonical 4-param). Synchronous; main-thread only.
## Returns the BossInstance, or null on a rejected spawn (caller #14 handles the
## null + BossAnchor rollback).
##
## @param template        Boss content (immutable BossTemplate).
## @param transition_id   #14 BossAnchor commit id (NEVER empty, NEVER self-generated).
## @param spawn_pos       World-space spawn position (Rule 14).
## @param player_snapshot Frozen BossSpawnContext (A1.2 caller-passed; NOT global state).
func spawn_boss(
	template: BossTemplate,
	transition_id: String,
	spawn_pos: Vector2,
	player_snapshot: BossSpawnContext
) -> BossInstance:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(), "spawn_boss MUST run on the main thread")
	# EC-02 — empty transition_id is rejected gracefully (NOT an assert: EC-02
	# requires「reject + #14 rollback」, which a return-null supports + is testable).
	if transition_id == "":
		push_error("BOSS_INVALID_TXN_001: spawn_boss invoked with empty transition_id")
		_emit_telemetry("boss.invalid_txn", {})
		return null
	# A1.2 null-guard — Pillar 1 forbids fabricating a default snapshot.
	if player_snapshot == null:
		push_error("BOSS_NULL_SNAPSHOT_001: spawn_boss null player_snapshot for transition_id=%s" % transition_id)
		_emit_telemetry("boss.null_snapshot", {"transition_id": transition_id})
		return null
	# EC-01 idempotency — same transition_id replay rejected (Pillar 1 chain integrity).
	if _spawned_transition_ids.has(transition_id):
		push_error("BOSS_DUP_SPAWN_001: duplicate spawn for transition_id=%s" % transition_id)
		return null
	_spawned_transition_ids[transition_id] = true

	var boss := _instantiate_boss(template)
	# A1.1 — set immutable fields BEFORE add_child (boss._ready asserts them).
	boss.boss_id = template.boss_id
	boss.boss_template = template
	boss.transition_id = transition_id
	boss.player_stat_snapshot = player_snapshot

	boss.global_position = spawn_pos     # pre-add_child (local-equiv while detached)
	add_child(boss)                      # synchronous; NOT call_deferred
	boss.global_position = spawn_pos     # A2.3 — re-set against parent transform

	assert(boss.is_inside_tree(), "Boss MUST be in tree before commit signal")
	assert(boss.global_position.is_equal_approx(spawn_pos),
		"Position must persist through add_child (got %s, expected %s)" % [boss.global_position, spawn_pos])

	# Pass 11 512MB rec — evict the id when the boss frees (session-scoped bound).
	boss.tree_exited.connect(func() -> void: _spawned_transition_ids.erase(transition_id))

	# AC-41(e) — first-session bootstrap telemetry emitted HERE (BossSystem scope),
	# NOT in the pure static BossFormulas. boss.max_hp is computed (boss._ready ran
	# during add_child). Same condition Formula 1 uses (attack_power == 0).
	if player_snapshot.attack_power == 0.0:
		_emit_telemetry("boss.first_session_bootstrap",
			{"transition_id": transition_id, "boss_max_hp": boss.max_hp})

	# A1.4 — synchronous emit BEFORE return; subscribers receive callback before caller resumes.
	boss_committed.emit(template, boss, player_snapshot, spawn_pos, transition_id)
	return boss
