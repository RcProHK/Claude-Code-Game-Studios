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
var _spawned_emitters: Array[GPUParticles2D] = []
var _ai_state: int = EnemyDirector.EnemyAIState.SPAWNING  # Rule 15 (#14 enemy AI state)

const CLEANUP_TIMEOUT_MS: int = 3000  # Rule 11 bfcache-safe wall-clock deadline


## SINGLE canonical _ready (Pass 7 merge). Pillar 1: BossInstance MUST be
## initialized via spawn_boss; direct instantiation is a bug.
func _ready() -> void:
	assert(transition_id != "", "BossInstance MUST have transition_id set by spawn_boss before _ready")
	assert(player_stat_snapshot != null, "BossInstance MUST have a frozen snapshot before _ready")
	assert(has_node("AnimationPlayer"), "BossInstance scene tree contract: $AnimationPlayer required")
	assert(has_node("CollisionShape2D"), "BossInstance scene tree contract: $CollisionShape2D required")
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
	PersistenceLayer.write("boss.fight_timestamp", Time.get_unix_time_from_system())


## Self-filtered enemy_killed handler. Param TYPED EnemyKilledPayload (file-level
## class_name @ src/core/enemy_killed_payload.gd). Story 011 owns the full AC-11b
## coverage; this is the wired scaffold.
func _on_enemy_killed_self_listen(payload: EnemyKilledPayload) -> void:
	if payload.transition_id != self.transition_id:
		return  # NOT this boss — ignore (self-filter)
	_enter_state(EnemyDirector.EnemyAIState.DYING)


## Death + free (Story 012 expands to the full death-anim + wall-clock cleanup).
## Minimal scaffold: idempotent cleanup then queue_free.
func _play_death_and_free() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		_cleanup_resources()
		return
	_cleanup_resources()
	queue_free()


## Idempotent resource release (GP6) — clears the set after release so a bfcache
## resume re-entry double-call is safe.
func _cleanup_resources() -> void:
	for emitter in _spawned_emitters:
		if is_instance_valid(emitter):
			ParticleSystemWrapper.release(emitter)
	_spawned_emitters.clear()


## Bfcache resume defensive cleanup (Story 012 expands to the full DD#1 exact-restore).
func _on_resume_detected() -> void:
	_cleanup_resources()


## Web Export multi-hook resume coverage (Rule 11 A2.1). NOTIFICATION_APPLICATION_RESUMED
## is mobile-only (NOT Web) — intentionally not listed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_resume_detected()


func _exit_tree() -> void:
	_cleanup_resources()  # Rule 11 safety net (idempotent)
