# 鏡像勇者 (Mirror Hero) — Master Architecture

## Document Status

| Field | Value |
|-------|-------|
| **Version** | 1.1 |
| **Last Updated** | 2026-05-28 |
| **Engine** | Godot 4.6 (Web Export, Compatibility Renderer) |
| **GDDs Covered** | #1 GSM, #2 GymSys, #3 PersistenceLayer, #5 Particles, #6 ScreenEffects, #7 Camera, #8 Streak, #9 WorkoutStateTracker, #11 StatSystem, #12 AbilitySystem, #13 CombatResolver, #14 EnemyDirector (12 Approved) |
| **ADRs Referenced** | ADR-0001 (Web Export Budget Caps), ADR-0002 (GymSys Integration), ADR-0003 (Save State Strategy), ADR-0004 (CORS Auth Topology), ADR-0005 (Loot Rarity Formula), ADR-0006 (State Machine Contract) |
| **Technical Director Sign-Off** | 2026-05-28 — APPROVED WITH CONDITIONS (resolve 5 LP BLOCKING items before sprint planning) |
| **Lead Programmer Feasibility** | 2026-05-28 — CONCERNS ACCEPTED (5 BLOCKING items documented; inline fixes applied for BLOCKER-1 and BLOCKER-3; BLOCKER-2/4/5 require ADR work in next session) |

---

## Engine Knowledge Gap Summary

| Risk Level | Domains | Implication |
|-----------|---------|-------------|
| **HIGH** | Rendering (glow before tonemapping, D3D12 default on Windows, Compatibility renderer constraints), Physics (Jolt default 3D) | GPUParticles2D + shader uniforms + CanvasLayer topology must be verified on target hardware |
| **MEDIUM** | Core (`FileAccess.store_*` returns bool since 4.4), GDScript (`@abstract`, variadic args since 4.5) | PersistenceLayer write paths + GSM scripting patterns must use post-4.4 API signatures |
| **LOW** | Navigation (dedicated 2D server), Animation (IK restored), UI (FoldableContainer, dual-focus) | Minor — no architectural impact for Mirror Hero MVP |

**Systems touching HIGH RISK domains**:
- #5 ParticleSystemWrapper → Rendering (GPUParticles2D, Compatibility WebGL2) → HIGH
- #6 ScreenEffects → Rendering (shader uniforms, glow parameters) → HIGH
- #7 Camera → Rendering (Camera2D, position_smoothing, Compatibility renderer) → HIGH
- #1 GSM → Core (FileAccess, autoload `_ready` ordering) → MEDIUM
- #3 PersistenceLayer → Core (FileAccess.store_* bool return, IndexedDB async) → MEDIUM

⚠️ All HIGH risk domains must be verified during VS-tier spike testing. ADR-0001 ratification is currently blocked on hardware verification (GPUParticles2D + Camera2D position_smoothing on iOS Safari WebGL2).

---

## Technical Requirements Baseline

Extracted from 12 approved GDDs | 38 foundation/core requirements

| Req ID | GDD | System | Requirement | ADR Coverage |
|--------|-----|--------|-------------|-------------|
| TR-GSM-001 | game-state-machine.md | #1 | Atomic state transitions — no partial state, generational lock | ADR-0006 Contract 1 |
| TR-GSM-002 | game-state-machine.md | #1 | transition_id collision-safety — monotonic BIGINT counter | ADR-0006 Contract 2 |
| TR-GSM-003 | game-state-machine.md | #1 | Tombstone forward-recovery — stale pending_transition on boot | ADR-0006 Contract 3 |
| TR-GSM-004 | game-state-machine.md | #1 | Sequential autoload boot order (PersistenceLayer→GSM→GymSys→…) | ADR-0006 Contract 4 |
| TR-GSM-005 | game-state-machine.md | #1 | connect_for_initial_state sentinel — fire on connect if already in state | ADR-0006 Contract 6 |
| TR-GYMSYS-001 | gymsys-backend-client.md | #2 | HTTP polling 5s ±0.5s jitter (differential event cursor) | ADR-0002 |
| TR-GYMSYS-002 | gymsys-backend-client.md | #2 | Server-authoritative session lock (POST /session/claim + X-Session-Token) | ADR-0002 |
| TR-GYMSYS-003 | gymsys-backend-client.md | #2 | CORS same-origin via nginx reverse proxy (relative URLs only) | ADR-0004 |
| TR-GYMSYS-004 | gymsys-backend-client.md | #2 | SSE v0.2 upgrade path via JavaScriptBridge EventSource | ADR-0002 |
| TR-PERSIST-001 | persistence-layer.md | #3 | Backend-primary save state + IndexedDB secondary cache | ADR-0003 |
| TR-PERSIST-002 | persistence-layer.md | #3 | Schema migration chain ≤6 steps × 150ms = ≤900ms total | ADR-0003, ADR-0006 Contract 10 |
| TR-PERSIST-003 | persistence-layer.md | #3 | Private Mode detection + loot-disable gate | ADR-0003 |
| TR-PERSIST-004 | persistence-layer.md | #3 | Wall-clock drift tolerance ±300s for cross-device access | ADR-0003 |
| TR-PARTICLE-001 | particle-system-wrapper.md | #5 | GPUParticles2D ≤200 active (desktop), ≤100 (mobile 0.5×) | ADR-0001 |
| TR-PARTICLE-002 | particle-system-wrapper.md | #5 | 9 named presets via ParticleSystemWrapper.PresetId enum | ADR-0001 |
| TR-PARTICLE-003 | particle-system-wrapper.md | #5 | Mobile UA detection via JavaScriptBridge (cached at boot) | ADR-0001 |
| TR-SCREEN-001 | screen-effects-system.md | #6 | Screen shake via shader uniform (NOT Camera2D.offset — CI enforced) | ADR-0001 |
| TR-SCREEN-002 | screen-effects-system.md | #6 | Reduce Motion accessibility slider (motion_intensity [0.0, 1.0]) | ADR-0001 |
| TR-CAMERA-001 | camera-system.md | #7 | Camera2D.position_smoothing (frame-rate-independent, Compatibility renderer) | ADR-0001 |
| TR-CAMERA-002 | camera-system.md | #7 | Focal mode for boss encounters (EnemyDirector forward contract) | ADR-0001 |
| TR-STREAK-001 | streak-system.md | #8 | Cross-day accumulation with drift-tolerant `is_expired` (±300s) | ADR-0003 |
| TR-WORKOUT-001 | workout-state-tracker.md | #9 | set_progress O(1) computation per 4Hz perception tick | ADR-0002, ADR-0006 |
| TR-WORKOUT-002 | workout-state-tracker.md | #9 | dominant_class derived from set-count-weighted push/pull/leg | ADR-0006 |
| TR-WORKOUT-003 | workout-state-tracker.md | #9 | Anti-fabrication: workout events MUST come from #2 GymSys backend | ADR-0002 |
| TR-STAT-001 | stat-system.md | #11 | Closed mutation API — only StatSystem may write stat values | ADR-0003 |
| TR-STAT-002 | stat-system.md | #11 | VOLUME_TICK batching — accumulate per rep, flush at set_completed | ADR-0002 |
| TR-STAT-003 | stat-system.md | #11 | PR breakthrough provisional formula (pending Q-A1 cross-validation) | ADR-0005 |
| TR-ABILITY-001 | ability-system.md | #12 | Ability unlock via PR breakthrough signal subscription pattern | ADR-0005, ADR-0006 |
| TR-ABILITY-002 | ability-system.md | #12 | cast_ability caller whitelist — only combat_resolver.gd (CI enforced) | ADR-0006 |
| TR-COMBAT-001 | combat-resolver.md | #13 | Stateless pure-function combat math (no stored mutable state) | ADR-0006 |
| TR-COMBAT-002 | combat-resolver.md | #13 | Hit pause coordination via ScreenEffects (not frame skip) | ADR-0001 |
| TR-COMBAT-003 | combat-resolver.md | #13 | CPU budget ≤1.0ms per combat tick (Web Export constraint) | ADR-0001 |
| TR-ENEMY-001 | enemy-director.md | #14 | Wave archetype selection driven by WorkoutStateTracker.dominant_class | ADR-0006 |
| TR-ENEMY-002 | enemy-director.md | #14 | Boss pre-spawn trigger at set_progress ≥ pre_spawn_threshold | ADR-0006 |
| TR-ENEMY-003 | enemy-director.md | #14 | enemy_killed signal carries transition_id (loot chain seed) | ADR-0005, ADR-0006 |
| TR-ENEMY-004 | enemy-director.md | #14 | Orchestration CPU ≤0.5ms p95 per frame | ADR-0001 |
| TR-LOOT-001 | (ADR-0005) | #15 | loot_rarity_score = workout_score×0.75 + rng_roll×0.25 | ADR-0005 |
| TR-LOOT-002 | (ADR-0005) | #15 | Pillar 1 floor: max RNG contribution = 0.25 < EPIC threshold (0.72) | ADR-0005 |

---

## System Layer Map

```
┌──────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (7 systems)                          │
│  #20 Gym-Mode HUD  #21 Loot Drop Modal                   │
│  #22 Character Screen  #23 Inventory UI                  │
│  #24 Login/GymSys UI   #25 Combat VFX   #26 Avatar       │
├──────────────────────────────────────────────────────────┤
│  FEATURE LAYER (4 systems)                               │
│  #16 Boss System   #17 Equipment+Inventory               │
│  #18 PR Detection+Avatar Prog.   #19 Zone System         │
├──────────────────────────────────────────────────────────┤
│  CORE LAYER (8 systems)                                  │
│  #9 Workout State Tracker   #10 Exercise→Class Mapping   │
│  #11 Stat System   #12 Ability System                    │
│  #13 Combat Resolver   #14 Enemy Director                │
│  #15 Loot Drop System   #33 Attention Budget Policy      │
├──────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER (8 systems)                            │
│  #1 Game State Machine   #2 GymSys Backend Client        │
│  #3 PersistenceLayer   #4 Audio Manager                  │
│  #5 Particle System Wrapper   #6 Screen Effects          │
│  #7 Camera System   #8 Streak System                     │
├──────────────────────────────────────────────────────────┤
│  PLATFORM LAYER (engine + OS + browser)                  │
│  Godot 4.6 Compatibility Renderer + Web Export           │
│  GymSys Backend (FastAPI 9120) + nginx proxy             │
│  iOS Safari / Chrome + IndexedDB                         │
└──────────────────────────────────────────────────────────┘
```

**Polish / Post-MVP Systems** (6, not shown in diagram): #27 Onboarding, #28 Telemetry, #29 Mirror Moment, #30 Skill Tree, #31 SSE Upgrade, #32 Friend Leaderboard.

---

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Key Engine APIs | Risk |
|--------|------|---------|----------|-----------------|------|
| **#1 GameStateMachine** | 9-state FSM, transition_id counter, state_changed signal | `request_transition(tr_id)`, `connect_for_initial_state(state, callable)`, `current_state` | PersistenceLayer (read/write state), WorkoutStateTracker (state → WorkoutActive/Idle) | Callable signal connections, FileAccess | MEDIUM |
| **#2 GymSys BackendClient** | HTTP polling loop, session token, differential event cursor | `get_workout_events_since(cursor)`, `claim_session()`, `get_loot_drop_endpoints()` | PersistenceLayer (`session_token`, `_committed_tombstones`, cursor) | HTTPRequest, Timer, JavaScriptBridge (SSE v0.2) | HIGH (CORS) |
| **#3 PersistenceLayer** | All IndexedDB namespaced storage, migration chain | `save(namespace, key, value)`, `load(namespace, key)`, `migrate(schema_version)`, `is_expired(timestamp)` | Engine FileAccess, JavaScriptBridge (IDB) | FileAccess (bool returns post-4.4), JavaScriptBridge | MEDIUM |
| **#4 AudioManager** | Audio bus routing, SFX/BGM playback | `play_sfx(event_id)`, `play_bgm(track_id)`, `set_volume(bus, db)` | GSM (state changes for music transitions) | AudioStreamPlayer2D, AudioBus | LOW |
| **#5 ParticleSystemWrapper** | 16-node pool (8S/6M/2L), 9 presets, LRU eviction | `play(preset_id, position, multiplier) → ParticleHandle` | GSM (Suspended gate), PlatformDetect (mobile flag) | GPUParticles2D, CanvasLayer | HIGH (WebGL2) |
| **#6 ScreenEffects** | Trauma-based screen shake, hit pause, slow-motion | `add_trauma(source, amount, duration)`, `trigger_hit_pause(ms)` | #5 burst_started signal, GSM state | Shader uniforms (`screen_shake_strength`), CanvasLayer | HIGH (shader) |
| **#7 CameraSystem** | Camera2D follow, focal mode, zoom levels | `set_focal_target(entity)`, `clear_focal()`, `get_effective_zoom()` | GSM (state changes), #6 (shake via signal, NOT Camera.offset) | Camera2D.position_smoothing (post-4.0) | HIGH (Compatibility) |
| **#8 StreakSystem** | Cross-day streak counter, milestone thresholds | `record_today_workout()`, `get_current_streak() → int`, `get_streak_buff_multiplier()` | PersistenceLayer (`streak.*` namespace) | Time.get_unix_time_from_system() | LOW |

### Core Layer (Approved Systems)

| Module | Owns | Exposes | Consumes | Pillar Primary |
|--------|------|---------|----------|----------------|
| **#9 WorkoutStateTracker** | WorkoutPhase FSM, set_progress, dominant_class derivation | `get_set_progress() → float`, `get_dominant_class() → AbilityClass`, signals: `set_completed`, `workout_completed` | #2 GymSys events (polling stream), #3 PersistenceLayer (`wst.*`) | P4 (肌群即職業) |
| **#11 StatSystem** | Stat values (ATK, HP, DEX, STR, VIT, MOVE_SPEED, CRIT_CHANCE), stat mutations | `get_stat(stat_id) → float`, signal: `stat_changed` | #3 PersistenceLayer (`stat.*`), #9 (VOLUME_TICK, PR_BREAKTHROUGH events) | P1 (anti-fabrication #3) |
| **#12 AbilitySystem** | Ability registry, unlock state, cooldown tracking | `get_unlocked_abilities() → Array[AbilityId]`, `cast_ability(id, caster, target)`, signal: `ability_cast(id, caster, target)` | #10 (exercise→class mapping), #11 (stat values + PR_BREAKTHROUGH signal) | P4 (class-tiered unlock) |
| **#13 CombatResolver** | Damage formulas, hit chain, crit logic (stateless) | `resolve_hit(attacker_stats, ability_id, target_stats) → HitResult` | #11 (stat reads, O(1)), #12 (ability_cast signal) | P3 (DNF hit-feel math) |
| **#14 EnemyDirector** | Wave spawn lifecycle, boss anchor, AI state machines | `spawn_wave(archetype, arena_config)`, `spawn_boss(boss_id, tier, arena_config, snapshot)`, signals: `enemy_killed(transition_id, faction, tier)`, `boss_anchor_committed` | #5 Particles, #6 ScreenEffects, #7 Camera (focal), #9 (set_progress + dominant_class), #13 (combat tick) | P2 (frictionless orchestrator) |

**Note**: #10 ExerciseMapping, #15 LootDrop, #33 AttentionBudget — Not Started. API contracts pending GDD authoring.

---

## Data Flow

### 1. Frame Update Path (Workout Session Active)

```
GymSys Polling Timer (5s ±0.5s)
  → HTTPRequest.request_completed
    → WorkoutStateTracker.on_gymsys_event(event)
      → If set_completed: StatSystem.add_volume_tick(exercise_id, reps)
      → If workout_completed: emit workout_completed(workout_id)
      → EnemyDirector reads set_progress at 4Hz (Timer)
        → If set_progress ≥ pre_spawn_threshold: spawn_boss(...)
        → EnemyDirector.combat_tick → CombatResolver.resolve_hit(...)
          → If crit: #6 ScreenEffects.add_trauma(COMBAT, amount)
          → Always: #5 ParticleWrapper.play(HIT_HEAVY, position)
```

**Communication types**:
- GymSys → WorkoutStateTracker: async HTTPRequest callback (sync on main thread)
- WorkoutStateTracker → EnemyDirector: shared state read (O(1) property access)
- EnemyDirector → CombatResolver: synchronous function call (stateless)
- CombatResolver → ScreenEffects: signal emit (decoupled)
- All engine autoloads: Godot main thread (single-thread WASM)

### 2. Event/Signal Path (GSM State Changes)

```
Player completes exercise (GymSys event)
  → WorkoutStateTracker requests GSM transition WorkoutActive → ExerciseSwitch
    → GSM validates + increments transition_id
      → PersistenceLayer writes new state atomically
        → GSM emits state_changed(ExerciseSwitch, transition_id)
          → EnemyDirector receives (via connect_for_initial_state)
            → Triggers mini-boss spawn
          → Camera receives → focal mode on mini-boss
          → ParticleWrapper receives → spawn particles
          → ScreenEffects receives → (none for ExerciseSwitch)
```

**Key invariant (ADR-0006 Contract 4)**: All autoloads boot in fixed sequential order. No autoload may call another during `_ready()`. Cross-system calls only after all autoloads have reached `_ready()`.

### 3. Save/Load Path (PersistenceLayer Architecture)

```
Any system write:
  system.gd → PersistenceLayer.save(namespace, key, value)
    → Step 1: Write to WASM-side cache (in-memory dict)
    → Step 2: FileAccess.store_var() → IDB via JavaScriptBridge (async)
    → Step 3: On IDB commit: emit write_completed(namespace, key)
    → Step 4: On backend sync interval: POST /api/game/save to GymSys backend

Any system read:
  system.gd → PersistenceLayer.load(namespace, key) → value
    (reads from in-memory cache; IDB is source of truth on cold boot)

Boot sequence:
  PersistenceLayer._ready()
    → Load all namespaces from IDB
    → Check backend sync (if delta exists: pull backend version)
    → Run schema migration if schema_version mismatch
    → Emit ready()
    → GSM._ready() begins (Contract 4)
```

**Namespace ownership** (from GDD Section F):
- `gsm.*` — #1 GameStateMachine
- `gym.*` — #2 GymSys BackendClient
- `streak.*` — #8 StreakSystem
- `wst.*` — #9 WorkoutStateTracker
- `stat.*` — #11 StatSystem
- `ability.unlocked.*` — #12 AbilitySystem

### 4. Autoload Boot Sequence (ADR-0006 Contract 4)

```
Engine loads project (Godot Project Settings → Autoload list — linear, 1-indexed)
  → pos 1: PersistenceLayer._ready()       — IDB load + migration
  → pos 2: GameStateMachine._ready()       — reads persisted state, emits state_changed
  → pos 3: GymSys BackendClient._ready()  — starts polling timer
  → pos 4: PlatformDetect._ready()         — UA detection, caches mobile flag (immutable after _ready)
  → pos 5: ParticleSystemWrapper._ready()  — pool warm, shader pre-load (≤80ms budget)
  → pos 6: ScreenEffects._ready()          — shader register
  → pos 7: CameraSystem._ready()           — viewport config
  → pos 8: StreakSystem._ready()           — loads streak.* from PersistenceLayer
  → pos 9: WorkoutStateTracker._ready()    — subscribes GymSys events
  → pos 10: EnemyDirector._ready()         — subscribes all upstream signals
  → [pos 11+: AudioManager, #33 AttentionBudget reserved — see ADR-0008]
  → All autoloads ready → gameplay begins
```
> ⚠️ **BLOCKER-3 partially resolved**: Specific integer positions 1-10 assigned above. Positions 11+ (AudioManager, AttentionBudget, LootDrop at Pre-MVP tier) require ADR-0008. Run `/architecture-decision "Autoload Full Position Registry"` before Pre-MVP sprint planning.

**Critical**: Positions 4+ must NOT call positions 1-3 during `_ready()`. GSM's `connect_for_initial_state` pattern fires state handler only after the subscribing autoload reaches `_ready()`, preventing boot-order race conditions.

---

## API Boundaries

### Foundation Layer Public Contracts

```gdscript
# --- GameStateMachine ---
signal state_changed(new_state: GameState, transition_id: int)
func request_transition(tr_id: int) -> TransitionResult
func connect_for_initial_state(state: GameState, callable: Callable) -> void
var current_state: GameState  # read-only

# --- PersistenceLayer --- (aligned with ADR-0003 + ADR-0006 Contract 11)
# namespace is embedded in key (e.g. "gsm.current_state", "streak.count")
signal write_completed(latency_ms: int)    # IDB async commit confirmation (NOT MEMFS ack)
signal migration_completed(from_version: int, to_version: int)
signal private_mode_detected()             # banner + loot disable trigger
func write(key: String, value: Variant) -> bool  # bool = MEMFS success (NOT IDB ack)
func read() -> Dictionary                         # full cached state dict (in-memory, sync)
func delete(key: String) -> bool
func migrate(from_version: int, to_version: int) -> bool
func is_expired(timestamp: int) -> bool    # ADR-0006 Contract 9 drift-tolerant TTL
func is_private_mode() -> bool             # Safari Private Mode detection

# --- GymSys BackendClient ---
signal set_completed(exercise_id: String, reps: int, weight_kg: float)
signal workout_completed(workout_id: String, exercises: Array)
signal session_acquired(session_token: String)
func get_cursor() -> int  # differential event cursor
func claim_session() -> Error

# --- ParticleSystemWrapper ---
func play(preset_id: PresetId, position: Vector2, multiplier: float = 1.0) -> ParticleHandle
signal burst_started(preset_id: PresetId, position: Vector2)
# multiplier clamped [0.1, 1.5]; loot bypass protection for LOOT_* presets

# --- ScreenEffects ---
func add_trauma(source: TraumaSource, amount: float, duration: float) -> void
func trigger_hit_pause(duration_ms: int) -> void
func set_motion_intensity(value: float) -> void  # accessibility [0.0, 1.0]

# --- CameraSystem ---
func set_focal_target(entity: Node2D) -> void
func clear_focal() -> void
```

### Core Layer Public Contracts

```gdscript
# --- WorkoutStateTracker ---
func get_set_progress() -> float              # [0.0, 1.0], O(1)
func get_dominant_class() -> AbilityClass     # STRIKE/CONTROL/MOBILITY
signal set_completed(exercise_id: String, set_number: int, progress: float)
signal workout_completed(workout_id: String, completed_exercises: Array)

# --- StatSystem ---
func get_stat(stat_id: StatId) -> float       # O(1) read
signal stat_changed(stat_id: StatId, old_val: float, new_val: float)
# FORBIDDEN: no external write path — all mutations via internal events

# --- AbilitySystem ---
func get_unlocked_abilities() -> Array[AbilityId]
func cast_ability(ability_id: AbilityId, caster: Node, target: Node) -> void
signal ability_cast(ability_id: AbilityId, caster: Node, target: Node)
# caller whitelist: cast_ability caller = combat_resolver.gd only (CI enforced)

# --- CombatResolver ---
func resolve_hit(
    attacker: CombatantSnapshot,
    ability_id: AbilityId,
    target: CombatantSnapshot
) -> HitResult
# STATELESS — no member variables modified by resolve_hit

# --- EnemyDirector ---
func spawn_boss(boss_id: BossId, tier: BossTier, arena_config: ArenaConfig, snapshot: StatSnapshot) -> void
signal enemy_killed(transition_id: int, faction: Faction, tier: EnemyTier)
signal boss_anchor_committed(boss_instance: BossInstance)
```

**Caller constraints** (CI-enforced, `tools/ci/` GDScript linters):
- `cast_ability()` → only `combat_resolver.gd`
- `Camera2D.offset` → only `screen_effects.gd`
- `Camera2D.position/zoom/make_current()` → only `camera_controller.gd`
- `GPUParticles2D` direct instantiation → only `particle_system_wrapper.gd`
- `JavaScriptBridge.eval()` → only `platform_detect.gd`
- `StatSystem` stat writes → only `stat_system.gd` internal

---

## ADR Audit

### ADR Quality Check

| ADR | Engine Compat Section | Version Stamped | GDD Linkage | ADR Dependencies Section | Conflicts | Status |
|-----|----------------------|-----------------|-------------|--------------------------|-----------|--------|
| ADR-0001: Web Export Budget Caps | ✅ HIGH risk noted | ✅ 4.6 | ✅ #5 FR-1/2/3, #6 FR-1/2/3, #7 FR-1/2/3, #13 FR-3, #14 FR-4 | ✅ | None | **Proposed** — blocked on VS hardware verification |
| ADR-0002: GymSys Integration | ✅ | ✅ 4.6 | ✅ #2, #9 | ✅ | None | **Proposed** — CD-CASCADE-A/B/C ratification-gated |
| ADR-0003: Save State Strategy | ✅ | ✅ 4.6 | ✅ #3, #8 FR-1/2/3, #11, #12 | ✅ | ⚠️ B-1 Contract 10 values (resolved 2026-05-27 in-session) | **Proposed** |
| ADR-0004: CORS Auth Topology | ✅ | ✅ 4.6 | ✅ #2 Q1 | ✅ | None | **Proposed** |
| ADR-0005: Loot Rarity Formula | ✅ | ✅ 4.6 | ✅ #9 CI-5, #13 FR-2, #14 FR-2 | ✅ | None | **Proposed** |
| ADR-0006: State Machine Contract | ✅ HIGH risk noted | ✅ 4.6 | ✅ 15 contracts trace to #1 + downstream | ✅ | ⚠️ B-2 PlatformDetect position 0 (resolved 2026-05-27 in-session) | **Accepted 2026-05-28** (N-002 sync) |

**Key note**: ADR-0006 is now **Accepted** (ratified 2026-05-28 via Gate A systems-designer + Gate B creative-director parallel signoffs). Remaining 5 ADRs (0001/0002/0003/0004/0005) are still **Proposed** — stories referencing them are auto-blocked per `docs/CLAUDE.md`. ADR-0002 ↔ ADR-0004 mutual Proposed dependency loop (N-003 follow-up) requires coordinated ratification.

### Traceability Coverage Check

| Req ID | Requirement | ADR Coverage | Status |
|--------|-------------|--------------|--------|
| TR-GSM-001..005 | GSM atomic transitions, transition_id, tombstone, boot order, connect_for_initial_state | ADR-0006 | ✅ |
| TR-GYMSYS-001..004 | HTTP polling, session lock, CORS proxy, SSE upgrade path | ADR-0002, ADR-0004 | ✅ |
| TR-PERSIST-001..004 | Backend-primary, migration chain, Private Mode, drift tolerance | ADR-0003 | ✅ |
| TR-PARTICLE-001..003 | GPU particle budget, 9 presets, mobile UA | ADR-0001 | ✅ |
| TR-SCREEN-001..002 | Shader-based shake, accessibility slider | ADR-0001 | ✅ |
| TR-CAMERA-001..002 | Camera2D smoothing, focal mode | ADR-0001 | ✅ |
| TR-STREAK-001 | Cross-day accumulation + drift | ADR-0003 | ✅ |
| TR-WORKOUT-001..003 | set_progress O(1), dominant_class, anti-fabrication | ADR-0002, ADR-0006 | ✅ |
| TR-STAT-001..003 | Closed API, VOLUME_TICK batching, PR breakthrough | ADR-0003, ADR-0005 | ✅ |
| TR-ABILITY-001..002 | Unlock via signal, cast_ability whitelist | ADR-0005, ADR-0006 | ✅ |
| TR-COMBAT-001..003 | Stateless math, hit pause, CPU budget | ADR-0001, ADR-0006 | ✅ |
| TR-ENEMY-001..004 | Wave archetype, boss pre-spawn, transition_id chain, CPU budget | ADR-0001, ADR-0005, ADR-0006 | ✅ |
| TR-LOOT-001..002 | Rarity formula, Pillar 1 floor | ADR-0005 | ✅ |
| **MISSING: Class Enum Naming** | STRIKE/CONTROL/MOBILITY naming convention lock | **NO ADR** | ❌ GAP |
| **MISSING: Autoload Full Registry** | Positions for all 14+ autoloads at Pre-MVP+ scope | **ADR-0006 partial** | ⚠️ PARTIAL |

**Coverage**: 38/38 functional requirements covered by existing ADRs. **2 structural gaps** requiring new ADRs.

---

## Required ADRs

### Foundation Layer (must create before implementation begins)

**ADR-0007: Class Enum Naming Convention** (HIGH priority — pre-VS kickoff)
- Covers: STRIKE/CONTROL/MOBILITY enum naming standard + narrative display name localization separation
- Unblocks: #12 Ability System implementation + #14 EnemyDirector wave archetype data files
- Flagged by: CD F-9 in #9 WorkoutStateTracker review, #14 EnemyDirector OQ
- Gap: Every system that references AbilityClass uses ad-hoc naming until this is locked

**ADR-0008: Autoload Full Position Registry** (MEDIUM priority — before Pre-MVP sprint)
- Covers: Complete autoload position map for 14+ autoloads as Foundation grows (Audio, WorkoutTracker, StreakSystem all need explicit positions beyond ADR-0006 Contract 4's initial 4)
- Unblocks: Pre-MVP sprint planning, #4 Audio Manager implementation
- Gap: ADR-0006 Contract 4 defines positions 1-4 only. WorkoutStateTracker = pos 5, EnemyDirector = LAST, but #4 Audio, #8 Streak, #33 AttentionBudget positions are unspecified.

### Should have before VS-tier implementation

After creating ADR-0007 + ADR-0008:
- All 6 existing Proposed ADRs should be elevated to **Accepted** via fresh-session `/architecture-review` verification
- ADR-0001 ratification is blocked on VS hardware spike (GPUParticles2D + Camera2D on iOS Safari WebGL2)

---

## Architecture Principles

Five principles governing all technical decisions for Mirror Hero:

1. **Anti-fabrication chain integrity** — Every data path that influences loot rarity, stat values, or ability unlocks MUST trace back to GymSys backend canonical events (#2). No local fabrication. The quintet (#2 GymSys → #9 WorkoutTracker → #11 StatSystem → #12 AbilitySystem → #14 EnemyDirector) is the architectural backbone of Pillar 1.

2. **Foundation-first, never skip layers** — Core layer systems may call Foundation layer systems. Feature layer systems may call Core. Presentation calls Feature/Core but NEVER vice versa. Polish systems call any layer below. Cross-layer dependencies must be declared bidirectionally in GDD Section F.

3. **Single-thread WASM = no async surprises** — All Godot logic runs on the main thread in Web Export. HTTPRequest callbacks are pseudo-async but always arrive on the main thread. IndexedDB writes are truly async (JavaScriptBridge) and must not be assumed synchronous. PersistenceLayer owns all async-boundary management.

4. **Closed mutation APIs everywhere** — Every system that owns shared state must enforce a closed write path. StatSystem's closed API pattern (established #11) is the template: no external write path, only internal event processing. Apply this pattern to WorkoutStateTracker, AbilitySystem, and StreakSystem.

5. **Godot-idiomatic signals over direct calls for cross-layer communication** — Within a layer, direct function calls are fine. Across layers, use signals. The GSM `state_changed` signal + `connect_for_initial_state` sentinel is the canonical cross-system communication pattern. Direct cross-layer function calls require explicit justification in the calling GDD's Section F.

---

## Open Questions

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | ADR-0001 ratification — GPUParticles2D + Camera2D iOS Safari WebGL2 stability (VS hardware spike required) | HIGH | VS-tier playtest on target hardware; update ADR-0001 provisional CPU values |
| QQ-02 | All 6 ADRs remain Proposed — must elevate to Accepted before sprint planning | HIGH | Fresh-session `/architecture-review` to verify; then author ADR-0007 + ADR-0008 |
| QQ-03 | #15 Loot Drop System GDD not started — TR-LOOT covered by ADR-0005 but implementation contract undefined | HIGH | `/design-system 15` — VS-tier required per 2026-05-27 tier upgrade |
| QQ-04 | #26 Avatar Renderer GDD not started — VS-tier remaining | MEDIUM | `/design-system 26` after #16 Boss System re-review complete |
| QQ-05 | #16 Boss System Pass 4 TIER A complete but TIER B (9 items) deferred — sprint-ready status unclear | MEDIUM | Complete TIER B items or formally accept as sprint-kickoff polish |
| QQ-06 | WorkoutStateTracker (TR-WORKOUT-002) dominant_class change cooldown — interacts with #14 wave archetype selection | MEDIUM | `dominant_class_change_cooldown_s` knob validation during #14 implementation |
| QQ-07 | Q-A1 from #11 StatSystem — PR_BASE retune pending ADR-0005 ratification | LOW | Resolved when ADR-0005 reaches Accepted + empirical VS data |
| QQ-08 | ADR-0007 (class enum naming) required before #12 and #14 implementation | HIGH | `/architecture-decision "Class Enum Naming Convention"` |

---

## LP-FEASIBILITY Remaining Blockers

The following items were raised by Lead Programmer review (2026-05-28) and require resolution before sprint planning:

| Blocker | Status | Resolution |
|---------|--------|-----------|
| **BLOCKER-1** PersistenceLayer API contradiction (`save/load` vs `write/read/delete`) | ✅ **Fixed inline** — API section updated to align with ADR-0003 + ADR-0006 Contract 11 | Done |
| **BLOCKER-2** GymSys BackendClient API incomplete (missing differential cursor schema, 4-channel access pattern) | ⚠️ **Partially documented** | `/architecture-decision` or expand ADR-0002 API section |
| **BLOCKER-3** Autoload position ambiguity (`pos 3+`, `pos 4 three-way tie`, `pos LAST`) | ✅ **Fixed inline** — specific positions 1-10 assigned | Done; positions 11+ require ADR-0008 |
| **BLOCKER-4** All 6 ADRs Proposed → auto-blocks all stories | ⚠️ **Known blocker** | Fresh session `/architecture-review` + VS hardware spike for ADR-0001 |
| **BLOCKER-5** `tools/ci/*.gd` directory empty | ⚠️ **Known gap** | CI scripts must be written concurrent with first Foundation autoload story |

Additional LP concerns documented (non-blocking):
- 18 type definitions missing from architecture doc (resolve via ADR-0007 for class enum + inline type defs in future revision)
- `EnemyDirector = pos LAST` fragility → replaced with `pos 10` specific position
- `StatSystem` VOLUME_TICK emitter caller-whitelist undefined → to be specified in #11 implementation story
- `FileAccess.store_var()` bool ≠ IDB commit ack → documented in PersistenceLayer API section
