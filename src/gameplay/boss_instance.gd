## BossInstance — runtime final-boss node (Story 002, GDD Rule 1 A1.1 contract)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 1 (BossInstance class) + Rule 11/12/15
##
## Governing ADRs:
##   * ADR-0009 (Signal Payload Schema) — hp_changed signal
##   * ADR-0006 (transition_id provenance) + ADR-0003 (DD#1 ephemeral persist)
##
## Driving Story: production/epics/boss-system/story-002-boss-instance-contract.md
## Implementing TRs: TR-boss-001 (schema), TR-boss-004 (frozen snapshot), TR-boss-012 (AI state)
##
## Extends Node2D — a world-space entity (NOT Control/UI). Spawned ONLY via
## BossSystem.spawn_boss (Story 007) from a BossTemplate.boss_scene PackedScene —
## direct `.new()` is forbidden (Pillar 1: transition_id would be null). The 4
## required scene-tree children ($AnimationPlayer/$CollisionShape2D/$Sprite2D/
## $HitArea2D) come from that .tscn; a bare `.new()` has none, so `_ready` asserts.
##
## DD#1 (Rule 12): every HP write routes through the single `_set_current_hp`
## mutator (clamp -> emit hp_changed -> persist `boss.current_hp`) — Pillar-2
## single-source. `_persist_fight_anchor` writes the re-association keys once.
## Death/bfcache bodies are scaffolded here and refined by Story 011 (kill wiring)
## + Story 012 (cleanup + exact-restore).
class_name BossInstance extends Node2D

## Emitted on every current_hp mutation (HUD boss-bar consumer, #20).
signal hp_changed(current_hp: int, max_hp: int)

# === Spawn-time immutable fields (set by spawn_boss BEFORE add_child) ===
@export var boss_id: StringName = &""
@export var boss_template: BossTemplate = null
@export var transition_id: String = ""

## Frozen player snapshot (BossSpawnContext, Story 002 design — richer than
## CombatResolver.StatSnapshot which lacks max_hp/workout_duration). NOT @export
## (RefCounted is non-exportable); runtime-set in spawn_boss before add_child.
var player_stat_snapshot: BossSpawnContext = null

# === Runtime mutable state (Rule 12 transient) ===
var current_hp: int = 0
var max_hp: int = 0
var attack_count: int = 0
var _last_emitted_pattern_id: StringName = &""
var _spawned_emitters: Array[ParticleHandle] = []        # Rule 11 cleanup tracking (boss-owned
                                                         # particles; empty in MVP — reveal is
                                                         # BossRevealCoordinator, attack VFX is #25)
var _ai_state: int = EnemyDirector.EnemyAIState.SPAWNING  # Rule 15 (#14 enemy AI state)
var _spawn_origin: Vector2 = Vector2.ZERO  # captured at _ready (Rule 14 SPAWN_RELATIVE anchor)

const CLEANUP_TIMEOUT_MS: int = 3000       # Rule 11 bfcache-safe wall-clock death-cleanup deadline
const BOSS_HP_PERSIST_TTL_SEC: int = 7200  # Rule 12 DD#1 Q3 — stale persisted-HP age cutoff

# Injectable clocks (Followup #17 IClock) — default real Time; mocked in tests.
var _now_ms_provider: Callable = Callable(Time, "get_ticks_msec")
var _now_unix_provider: Callable = Callable(Time, "get_unix_time_from_system")


## SINGLE canonical _ready (Pass 7 merge). Pillar 1: BossInstance MUST be
## initialized via spawn_boss; direct instantiation is a bug.
func _ready() -> void:
	assert(transition_id != "", "BossInstance MUST have transition_id set by spawn_boss before _ready")
	assert(player_stat_snapshot != null, "BossInstance MUST have a frozen snapshot before _ready")
	assert(has_node("AnimationPlayer"), "BossInstance scene tree contract: $AnimationPlayer required")
	assert(has_node("CollisionShape2D"), "BossInstance scene tree contract: $CollisionShape2D required")
	_spawn_origin = global_position  # Rule 14 — spawn_pos anchor for SPAWN_RELATIVE clamping
	# Formula 1 computed once per spawn (CF-3 caching) — base_hp from template,
	# attack_power + workout_duration from the frozen BossSpawnContext.
	max_hp = BossFormulas.compute_max_hp(
		boss_template.base_hp if boss_template != null else 0,
		player_stat_snapshot.attack_power,
		player_stat_snapshot.workout_duration_sec)
	_set_current_hp(max_hp)        # route through mutator: clamp + emit + DD#1 persist
	_persist_fight_anchor()        # DD#1 re-association keys (Q3 TTL anchor)
	var anim: AnimationPlayer = $AnimationPlayer
	if anim.has_animation("idle"):
		anim.play("idle")
	# Death wiring (Story 011 refines the body) — #14 owns enemy_killed emission;
	# this boss only LISTENS for its own id (self-filter in the handler).
	EnemyDirector.enemy_killed.connect(_on_enemy_killed_self_listen)
	# Bfcache resume (Safari path) — inert until PlatformDetect declares the signal.
	if PlatformDetect.has_signal("page_shown_from_bfcache"):
		PlatformDetect.page_shown_from_bfcache.connect(_on_resume_detected)


## Single HP mutator (GP-F8 / Rule 12) — the ONE path for every HP write
## (combat hit, bfcache restore). Clamps, emits, and mirrors `boss.current_hp`
## (DD#1). One of the two whitelisted `boss.*` persist callsites.
func _set_current_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	PersistenceLayer.write("boss.current_hp", current_hp)
	if current_hp == 0:
		# Defensive in-instance trigger; real death still originates from Rule 8
		# enemy_killed (idempotent _enter_state -> no double path).
		_enter_state(EnemyDirector.EnemyAIState.DYING)


## Canonical AI-state entry (GP-F4) — idempotent re-entry no-op is the
## double-cleanup guard root (Rule 11/15).
func _enter_state(new_state: int) -> void:
	if _ai_state == new_state:
		return
	_ai_state = new_state
	match new_state:
		EnemyDirector.EnemyAIState.DYING:
			_play_death_and_free()


## DD#1 immutable re-association keys — written ONCE at _ready. The SECOND
## whitelisted `boss.*` persist callsite.
func _persist_fight_anchor() -> void:
	PersistenceLayer.write("boss.transition_id", transition_id)
	PersistenceLayer.write("boss.fight_timestamp", int(_now_unix_provider.call()))


## Rule 14 — constrain a desired world-space position to the arena bounds per the
## template's ArenaConstraintMode. Component-wise clamp around the relevant anchor:
##   * WORLD_ABSOLUTE — clamp to ±arena_constraint_px around world origin (fixed arena)
##   * SPAWN_RELATIVE — clamp within ±arena_constraint_px of the spawn origin (default)
##   * AVATAR_LEASH   — clamp within ±arena_constraint_px of the avatar (leash-chase)
## Constraint values are world-space px at zoom 1.0 (unaffected by reveal zoom /
## SubViewport oversample — world position, not screen).
##
## @param desired    The position the AI wants to move to.
## @param avatar_pos The avatar's world position (only used by AVATAR_LEASH).
## @return           The clamped position (never exits the arena bounds).
func clamp_position(desired: Vector2, avatar_pos: Vector2) -> Vector2:
	var ext: Vector2 = boss_template.arena_constraint_px if boss_template != null else Vector2(300, 200)
	var anchor: Vector2
	match (boss_template.arena_constraint_mode if boss_template != null else BossTemplate.ArenaConstraintMode.SPAWN_RELATIVE):
		BossTemplate.ArenaConstraintMode.WORLD_ABSOLUTE:
			anchor = Vector2.ZERO
		BossTemplate.ArenaConstraintMode.AVATAR_LEASH:
			anchor = avatar_pos
		_:  # SPAWN_RELATIVE (default)
			anchor = _spawn_origin
	return Vector2(
		clampf(desired.x, anchor.x - ext.x, anchor.x + ext.x),
		clampf(desired.y, anchor.y - ext.y, anchor.y + ext.y))


## Self-filtered enemy_killed handler. Param TYPED EnemyKilledPayload (file-level
## class_name @ src/core/enemy_killed_payload.gd). Story 011 owns the full AC-11b
## coverage; this is the wired scaffold.
func _on_enemy_killed_self_listen(payload: EnemyKilledPayload) -> void:
	if payload.transition_id != self.transition_id:
		return  # NOT this boss — ignore (self-filter)
	_enter_state(EnemyDirector.EnemyAIState.DYING)


## Death animation then free (Story 012 — full Rule 11 GP2/GP4). Plays "death",
## waits for `animation_finished` OR a wall-clock deadline (bfcache-safe: Time
## advances even while process frames are frozen), then cleans up + deletes the
## DD#1 record + queue_free. `is_instance_valid` guards before AND after every await.
func _play_death_and_free() -> void:
	if not is_instance_valid(self):
		return
	if not is_inside_tree():
		_cleanup_resources()
		_delete_persist_record()
		return
	var anim := $AnimationPlayer as AnimationPlayer
	if anim.has_animation("death"):
		anim.play("death")
		var deadline_ms: int = int(_now_ms_provider.call()) + CLEANUP_TIMEOUT_MS
		var anim_done: Array = [false]  # boxed so the lambda can mutate it
		var on_finished := func(_a: StringName) -> void: anim_done[0] = true
		anim.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
		# Poll — yields each frame; exits on completion OR wall-clock deadline (GP4).
		while not anim_done[0] and int(_now_ms_provider.call()) < deadline_ms:
			await get_tree().process_frame
			if not is_instance_valid(self):
				return  # freed during await (GP2)
		if is_instance_valid(anim) and anim.animation_finished.is_connected(on_finished):
			anim.animation_finished.disconnect(on_finished)
	if not is_instance_valid(self):
		return
	_cleanup_resources()
	_delete_persist_record()
	queue_free()


## Idempotent resource release (GP6) — stops any boss-owned particle handles
## (#5's pool auto-expires; we only stop early on death) and clears the set after,
## so a bfcache resume re-entry double-call is safe.
func _cleanup_resources() -> void:
	for handle in _spawned_emitters:
		if handle != null and handle.alive():
			handle.stop()
	_spawned_emitters.clear()


## DD#1 — delete the ephemeral mid-fight record (boss.* namespace) on death /
## cleanup / stale-resume, so no stale HP leaks across workouts.
func _delete_persist_record() -> void:
	PersistenceLayer.delete("boss.current_hp")
	PersistenceLayer.delete("boss.transition_id")
	PersistenceLayer.delete("boss.fight_timestamp")


## Bfcache resume — DD#1 exact-restore (Rule 12 + EC-17 + AC-42/27a/46). Reads the
## persisted ephemeral record + delegates to the testable branch logic. (The
## PRE_SPAWN-freeze branch (d) — boss shouldn't exist — is handled at the #14
## BossAnchor layer; an existing BossInstance only does branches a/b/c.)
func _on_resume_detected() -> void:
	_cleanup_resources()  # idempotent — clear any orphaned handles first (GP6)
	var restored_hp: Variant = PersistenceLayer.read("boss.current_hp")
	var restored_tid: Variant = PersistenceLayer.read("boss.transition_id")
	var restored_ts: Variant = PersistenceLayer.read("boss.fight_timestamp")
	_restore_from_bfcache(restored_hp, restored_tid, restored_ts, int(_now_unix_provider.call()))


## DD#1 restore branch logic (extracted for testability — AC-42 a/b/c + AC-46 TTL).
##   (a)/(b) fresh record + matching tid -> exact restore (0 -> DYING idempotent via _set_current_hp)
##   (c)     no record / tid mismatch / stale (Δ > TTL) -> restore max_hp + delete the stale record
func _restore_from_bfcache(restored_hp: Variant, restored_tid: Variant, restored_ts: Variant, now_ts: int) -> void:
	var is_stale: bool = (restored_ts == null) or (now_ts - int(restored_ts) > BOSS_HP_PERSIST_TTL_SEC)
	if restored_hp != null and String(restored_tid) == transition_id and not is_stale:
		_set_current_hp(int(restored_hp))  # exact restore; HP==0 -> DYING (idempotent)
	else:
		_set_current_hp(max_hp)            # treat as fresh
		_delete_persist_record()


## Web Export multi-hook resume coverage (Rule 11 A2.1). NOTIFICATION_APPLICATION_RESUMED
## is mobile-only (NOT Web) — intentionally not listed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_resume_detected()


func _exit_tree() -> void:
	_cleanup_resources()  # Rule 11 safety net (idempotent)
