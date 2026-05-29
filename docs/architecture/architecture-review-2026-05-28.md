---
review_date: 2026-05-28
reviewer: /architecture-review skill (general-purpose agent, opus tier)
scope: full review — all phases
gdds_reviewed: 16 (skipped avatar-renderer.md per Pass 4 BLOCKED mandate)
adrs_reviewed: 6
reconstruction_note: |
  Source captured from saved agent JSON output. Bash tool unavailable in
  reconstruction session — content extracted via ripgrep window-matching;
  a small number of long table rows may show minor truncation, but all
  TR-IDs, gap rows, conflict findings, and the verdict are intact.
---

# Architecture Review — Phases 1-5 Synthesis Report

## Phase 1 — Documents Loaded

- **ADRs**: 6 (ADR-0001 through ADR-0006 — all read in full)
- **GDDs**: 16 read (full or strategic — Persistence + GSM full; remaining via Grep on §§ Detailed Rules / Formulas / Edge Cases / Dependencies / Tuning Knobs / ACs). Skipped: `avatar-renderer.md` per Pass 4 BLOCKED mandate
- **Engine reference**: VERSION + breaking-changes + deprecated-apis + current-best-practices fully read (8 module docs sampled — none touched by ADR APIs requiring deeper inspection)
- **Existing artifacts**: `tr-registry.yaml` confirmed empty (only example/comments — all TRs below are NEW). `requirements-traceability.md` from prior `/architecture-review` 2026-05-28 covered 40 TRs across 12 GDDs — used as cross-validation, but per task mandate I'm re-extracting fresh.
- **Unexpected state**: ADR-0006 now Accepted (not Proposed as stale traceability matrix line 91 shows); GDDs #15 LootDrop + #16 BossSystem now have richer scope than prior matrix captured (both with explicit signal contracts); F-STEP4-1 footnote present at ADR-0006 Decision Makers line 20 (not yet propagated to Contract 6 code sample).

---

## Phase 2 — TR Catalog (per GDD)

### GDD: design/gdd/persistence-layer.md — System: #3 PersistenceLayer

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-persist-001 | Sync `IPersistence` interface — no `await` in any of 4 public methods | Threading-Timing | LOW |
| TR-persist-002 | In-memory write-through cache; `read()` O(1) zero file-I/O | Performance | LOW |
| TR-persist-003 | Atomic file flush via single `store_string(JSON.stringify(_cache))` blob (NOT per-key incremental) | Persistence | MEDIUM (4.4 `store_string` bool return semantics) |
| TR-persist-004 | SerializableResource envelope: `payload_type` MUST use `get_script().get_global_name()` (NOT `get_class()` which returns `"Resource"`) | Engine capability | HIGH (silent-fail footgun) |
| TR-persist-005 | `_payload_dispatch` via `ClassDB.instantiate(payload_type)` — no manual registry; forbids inner-class payloads | Engine capability | MEDIUM |
| TR-persist-006 | Schema migration chain bounded: ≤6 steps × ≤150ms = 900ms ceiling; fail-fast on chain length > 6 | Performance | LOW |
| TR-persist-007 | Test spy contract: production no-op + MockPersistenceLayer records (`attach_write_spy/attach_delete_spy/clear_spies`) | Test infrastructure | LOW |
| TR-persist-008 | VS-tier IDB fence policy: no `await` on IDB ack; ~1 frame lag accepted; telemetry `write_completed` + `flush_completed` for MVP gate measurement | Threading-Timing | HIGH (4.6 Web Export IDB-commit timing unverified — Q-A8) |
| TR-persist-009 | Clock-drift TTL helper `is_expired(anchor_unix, ttl_seconds, anchor_monotonic_ms)` with `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS=300` | Threading-Timing | LOW |
| TR-persist-010 | Corrupt save detection: 7 trigger conditions emit `critical_save_failed(error_code, key)` + `corrupt_save_recovered(wiped_byte_count)` in fixed order | State persistence | LOW |
| TR-persist-011 | Safari ITP `touch(key)` rewrite (refresh 7-day eviction timer) | Platform | MEDIUM (Safari ITP behavior) |
| TR-persist-012 | Telemetry signal surface (6 generic signals — NO `tombstone_write_completed`; that's GSM-owned) | Cross-system communication | LOW |
| TR-persist-013 | Key namespace convention (`gsm.*` / `gym.*` / `_internal.*` / `streak.*` / `wst.*` / `stat.*` / `ability.unlocked.*`) — push_warning only | Cross-system communication | LOW |
| TR-persist-014 | Migration step idempotency requirement (`if "schema_version" already at target → no-op`) | State persistence | LOW |
| TR-persist-015 | Substate machine: Initialising/Migrating/Ready/Corrupt with strict API-rejection matrix per substate | State persistence | LOW |
| TR-persist-016 | `MAX_STATE_FILE_BYTES = 1MB` defensive parse limit; `FileAccess.get_length()` is instance method (post-open) | Engine capability | MEDIUM |
| TR-persist-017 | Quota exhaustion = stay Ready (NOT Corrupt) — emit `critical_save_failed("quota_exceeded")` and keep operating from in-mem cache | State persistence | LOW |

### GDD: design/gdd/game-state-machine.md — System: #1 GameStateMachine

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-gsm-001 | Rule 1: Exactly one active top-level state from 9-enum (Booting/Disconnected/Idle/WorkoutActive/RestPeriod/CombatActive/BossEncounter/LootDrop/Suspended) | State machine | LOW |
| TR-gsm-002 | Rule 2: 8-step atomic transition (acquire lock → validate → tombstone → final state → in-mem → remove tombstone → backend write → emit signal → release lock) | Threading-Timing | HIGH |
| TR-gsm-003 | Generational lock `_lock_gen: int` + `_force_clear_timer` per-transition fallback (NOT process-global) | Threading-Timing | HIGH |
| TR-gsm-004 | `transition_id` = `wall_clock_ms × 1000 + persisted_monotonic_counter`; format `"%d_%d_%s_%s"`; opaque string (no parsing back); persisted via `_transition_id_counter` PersistenceLayer key | State persistence | LOW |
| TR-gsm-005 | Forward-recovery MUST verbatim reuse tombstone `transition_id` — NEVER call `_generate_transition_id()` in `_forward_recover*` (CI enforced) | State persistence | LOW |
| TR-gsm-006 | Tombstone serialization via Contract 3 `to_dict()`/`from_dict()` envelope; payload_type via `get_script().get_global_name()` | Data structure | HIGH |
| TR-gsm-007 | Subscriber re-entry: synchronous re-entry blocked (lock held during emit); follow-up MUST use `get_tree().process_frame.connect(..., CONNECT_ONE_SHOT)` lambda pattern | Threading-Timing | HIGH (4.5 variadic-args ambiguity for `Callable.call_deferred(BossPayload)`) |
| TR-gsm-008 | `connect_for_initial_state(callable: Callable)` helper — sentinel payload `source_event = "initial_state"`; deferred deliver via `process_frame.connect(... CONNECT_ONE_SHOT)`; race guard `_last_emit_tick` skip-stale | Cross-system communication | HIGH |
| TR-gsm-009 | Initial-state delivery contract: `callable.callv([from, to, payload])` — `.bind()` FORBIDDEN (shifts arg positions); CI scan `connect_for_initial_state(*.bind(*))` | Cross-system communication | HIGH (CI enforced) |
| TR-gsm-010 | Boot ordering: autoload 1=PersistenceLayer / 2=GameStateMachine; per-autoload sequential `_enter_tree → _ready` (NOT batched) | Engine capability | HIGH (4.6 SceneTree verified) |
| TR-gsm-011 | Rule 5 reconciliation precedence (priority 0/0.5/1/1.5/2/3/4/5) including 401 active-state-deferred + 30-day LootDrop force-transition | State persistence | MEDIUM |
| TR-gsm-012 | Rule 5.5 weekly tick missed-window replay — boot-time catch-up `missed_count = floor((now - _last_weekly_tick_unix) / WEEKLY_TICK_INTERVAL_SECONDS)` clamped to `MAX_WEEKLY_TICK_CATCHUP = 8` | State persistence | LOW |
| TR-gsm-013 | Natural-pause gated LootDrop reveal — safe=`{Idle, RestPeriod, Disconnected}`, suppressed=`{WorkoutActive, CombatActive, BossEncounter}` | State machine | LOW |
| TR-gsm-014 | Event Intake Queue — priority FIFO, 1-event-per-frame drain, validity re-check on dequeue | State machine | LOW |
| TR-gsm-015 | Rule 7: `workout_completed` priority 1 force-transition to `LootDrop` from any state (including `BossEncounter` → INTERRUPTED_WITH_CREDIT) | State machine | LOW |
| TR-gsm-016 | BossOutcome enum (DEFEATED / INTERRUPTED_WITH_CREDIT / ABANDONED) — replaces `boss_defeated: bool` | Data structure | LOW |
| TR-gsm-017 | Rule 6 (Pillar 2): WorkoutActive/CombatActive/BossEncounter must require zero player input; defer to RestPeriod/LootDrop | State machine | LOW |
| TR-gsm-018 | Storage backend: IndexedDB via Godot `user://`; 9 JSON top-level keys; `current_state` uses stable string (StringName) | State persistence | LOW |
| TR-gsm-019 | bfcache fast-resume: `pageshow event.persisted == true` + in-mem `_current_state == Suspended` + tombstone absent + schema matches → fast path; else fall through to full boot | Platform | HIGH (Q-A3 spike) |
| TR-gsm-020 | Knob invariant assertions at boot: 8 invariants (Contract 8) including `STATE_TRANSITION_FALLBACK_MS ≤ MIN_REVEAL_WINDOW_SECONDS × 100`, `TOMBSTONE_TTL < SUSPENSION_TTL`, `ATTEMPT_CAP == 30` | State persistence | LOW |
| TR-gsm-021 | Test Spy Contract (Contract 14) — IPersistence + GSM + Input + MockToastQueue + MockInventory + MockEnemyDirector spy interface set | Test infrastructure | LOW |
| TR-gsm-022 | `@no-await` static analysis — scan-entire-file rule on `src/core/state_machine/**.gd` (includes helper functions) | Test infrastructure | LOW |
| TR-gsm-023 | IInputPolicy interface (Contract 13) — AttentionBudgetPolicy `extends IInputPolicy`; MockInputPolicy for tests | Cross-system communication | LOW |
| TR-gsm-024 | Cross-device `pending_since_server` authoritative — backend server-side timestamp; client `pending_since` mirror only | State persistence | LOW |

### GDD: design/gdd/gymsys-backend-client.md — System: #2 GymSys Backend Client

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-gym-001 | HTTP polling 5s ± 0.5s jitter (Formula 1: `5.0 + randf_range(-0.5, 0.5)`); per-cycle resample (NOT fixed at boot) | Networking | LOW |
| TR-gym-002 | Single-flight per channel: 4 channels (poll, state_write, loot_cache, loot_commit); `MAX_INFLIGHT_REQUESTS = 4` | Networking | LOW |
| TR-gym-003 | Orphan HTTPRequest pattern: `.new() + .timeout = <non-zero> + .request_completed.connect(..., CONNECT_ONE_SHOT) + add_child` within 10-line window same function | Engine capability | LOW |
| TR-gym-004 | NO `JavaScriptBridge.eval` anywhere (Chrome Incognito detection via reactive `IPersistence.write → false`) | Platform | HIGH (CI enforced) |
| TR-gym-005 | 13 typed signals normalized from poll responses (workout_started/set_logged/rest_started/rest_ended/workout_completed/poll_failed/poll_recovered + 6 auxiliary) | Cross-system communication | LOW |
| TR-gym-006 | `X-Session-Token` header on ALL authenticated requests + `X-Protocol-Version: 1` + `X-Transition-Id: <tid>:state` | Networking | MEDIUM (CORS) |
| TR-gym-007 | 401 latch single-emit: cancel all 4 in-flight, emit `session_invalidated()` once, queue_free all | Networking | LOW |
| TR-gym-008 | `transition_id` child suffix: `:state`, `:loot-cache`, `:loot-commit` (separate UNIQUE per backend table) | Data structure | LOW |
| TR-gym-009 | Retry matrix: 5xx → exponential backoff `min(BASE_DELAY × 2^(n-1), RETRY_CAP)` × 5 attempts; 429 → `Retry-After`; 401 → force-boot | Networking | LOW |
| TR-gym-010 | `_session_epoch` stale-response swallow — cross-claim responses dropped | Networking | LOW |
| TR-gym-011 | bfcache cleanup contract: on `state_changed → Suspended`, cancel + queue_free all 4 in-flight; swallow any post-suspend `request_completed` | Platform | HIGH (Q-A3) |
| TR-gym-012 | DST/monotonic clock discipline — `Time.get_unix_time_from_system()` whitelisted to `_build_transition_id_timestamp_prefix()` only | Threading-Timing | LOW |
| TR-gym-013 | Server-time payload uses backend `completed_at` verbatim (NOT client time); ≥5min clock skew → emit `protocol_error("clock_skew_detected")` | Networking | LOW |
| TR-gym-014 | `REST_PERIOD_FALLBACK_SECONDS = 90` when `rest_started` event omits `duration_seconds` + emit `protocol_error("missing_field_duration_seconds")` | Networking | LOW |
| TR-gym-015 | 35-day `_committed_tombstones` age-pruning via `PersistenceLayer.is_expired(committed_at, 35*86400)` | Networking | LOW |
| TR-gym-016 | Polling lifecycle suppression: paused during `state_changed(*, Suspended)` | Networking | LOW |
| TR-gym-017 | SSE v0.2 upgrade path: `JavaScriptBridge.create_callback` + EventSource; Web-only; native desktop keeps polling | Platform | HIGH (4.6 JSBridge GC under bfcache) |

### GDD: design/gdd/stat-system.md — System: #11 Stat System

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-stat-001 | 7-stat surface LOCKED (STR/VIT/DEX/INT/AGI/LUK/?) — Rule 1 enum closed | Data structure | LOW |
| TR-stat-002 | Closed mutation API — no direct `_base` write; caller whitelist (CI lint) | Data structure | LOW |
| TR-stat-003 | StatSource enum 5 values (VOLUME_TICK / PR_BREAKTHROUGH / EQUIPMENT / DEBUG_OVERRIDE / INITIAL_STATE) | Data structure | LOW |
| TR-stat-004 | Source/stat allow-list: PR_BREAKTHROUGH = base-only; EQUIPMENT = all-7 (modifier layer NOT persisted) | Data structure | LOW |
| TR-stat-005 | `connect_for_initial_state` delivers 7 initial stats (ADR-006 Contract 6 binding) | Cross-system communication | LOW |
| TR-stat-006 | Persistence flush policy split: PR_BREAKTHROUGH `flush=true` (critical) / VOLUME_TICK `flush=false` (debounced) | State persistence | LOW |
| TR-stat-007 | Atomic write ordering — persist BEFORE in-memory mutate BEFORE emit | State persistence | LOW |
| TR-stat-008 | Clamping at 0 + MAX_STAT_VALUE boundaries; anti-decay (negative VOLUME_TICK rejected) | Data structure | LOW |
| TR-stat-009 | Telemetry signals: `stat_clamped` on boundary; `boot_completed` after `_ready()` | Cross-system communication | LOW |
| TR-stat-010 | GSM Suspended gate — mutation API rejects when GSM `current_state == Suspended` | State machine | LOW |
| TR-stat-011 | Boot reconciliation: first-boot defaults / partial keys / corrupt fallback | State persistence | LOW |
| TR-stat-012 | 6 derived formulas (MAX_HP / ATTACK_POWER / MOVE_SPEED / CRIT_CHANCE / VOLUME_TICK delta / PR_BREAKTHROUGH delta) | Data structure | LOW |
| TR-stat-013 | 15 owned tuning knobs + 9 cross-knob invariants (CI-verified) | Data structure | LOW |
| TR-stat-014 | Namespace `stat.*` on PersistenceLayer (ADR-003 binding) | State persistence | LOW |
| TR-stat-015 | Re-entrance guard rejects nested mutation (EC-22) | Threading-Timing | LOW |
| TR-stat-016 | DEBUG_OVERRIDE — debug build runtime guard + CI lint catches `src/` usage | Test infrastructure | LOW |
| TR-stat-017 | Autoload position 5 (per project.godot — F-SETUP-1 synced) | Engine capability | LOW |

### GDD: design/gdd/ability-system.md — System: #12 Ability System

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-ability-001 | Ability ID surface LOCKED to 9 enum constants; magic-string `ability_id` literal banned in src/ (CI) | Data structure | LOW |
| TR-ability-002 | AbilityClass + AbilityTier enums LOCKED (STRIKE/CONTROL/MOBILITY × tier 1-3) | Data structure | LOW |
| TR-ability-003 | Closed mutation API — direct private field access rejected (CI) | Data structure | LOW |
| TR-ability-004 | UnlockSource enum exactly 3 values (PR_BREAKTHROUGH / STAT_THRESHOLD / INITIAL_STATE sentinel) | Data structure | LOW |
| TR-ability-005 | CastResult enum exactly 6 outcomes | Data structure | LOW |
| TR-ability-006 | Source-to-class allow-list rejects cross-class unlock | Data structure | LOW |
| TR-ability-007 | Caller whitelist CI lints for `unlock_ability` + `cast_ability` | Test infrastructure | LOW |
| TR-ability-008 | Unlock evaluation Path A (PR_BREAKTHROUGH) + Path B (STAT_THRESHOLD multi-tier ascent) | Data structure | LOW |
| TR-ability-009 | Cast evaluation atomic sequence | Threading-Timing | LOW |
| TR-ability-010 | Persistence namespace `ability.unlocked.*` (ADR-003 binding) per-source flush policy | State persistence | LOW |
| TR-ability-011 | Boot reconciliation rebuilds state from PersistenceLayer | State persistence | LOW |
| TR-ability-012 | GSM Suspended gate rejects mutation | State machine | LOW |
| TR-ability-013 | Permanent unlock contract — no relock under stat drop | Data structure | LOW |
| TR-ability-014 | Atomic unlock write ordering: persist → mutate → emit | State persistence | LOW |
| TR-ability-015 | Cooldown tick uses `set_process` toggle + `MAX_FRAME_DELTA` clamp | Performance | LOW |
| TR-ability-016 | 7 core/telemetry signals declared with typed signatures | Cross-system communication | LOW |
| TR-ability-017 | TIER_THRESHOLDS / BASE_COOLDOWN_SEC / UNLOCK_EVENT_PRIORITY deterministic sort | Data structure | LOW |
| TR-ability-018 | INV-1..INV-8 cross-knob invariants (CI-verified) | Data structure | LOW |
| TR-ability-019 | Re-entrance depth limit (`MAX_EMIT_DEPTH` guard) | Threading-Timing | LOW |
| TR-ability-020 | Autoload position 6 (after PlatformDetect insertion) | Engine capability | LOW |

### GDD: design/gdd/streak-system.md — System: #8 Streak System

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-streak-001 | Single API entry `_on_workout_completed(completed_at_utc)` with drift gate `_passes_drift_gate` (uses `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` aligned with PersistenceLayer) | Threading-Timing | LOW |
| TR-streak-002 | 4-layer Pillar 1 defense: closed API + CI mutator ban + CI caller whitelist + namespace isolation | Test infrastructure | LOW |
| TR-streak-003 | State machine (Booting / Ready / Updating / Failed / Backoff) + `_drain_deferred_if_any()` on Booting→Ready | State machine | LOW |
| TR-streak-004 | Subscribe via `GameStateMachine.connect_for_initial_state(...)` ONLY (ADR-006 Contract 6 — direct `.connect` banned by CI) | Cross-system communication | LOW |
| TR-streak-005 | `loot_rarity_modifier_step_curve` formula (Formula 1) — monotone non-decreasing across steps `{1,7,14,30,60,90}`, capped at 2.00 | Data structure | LOW |
| TR-streak-006 | `consecutive_day_classification` (Formula 2) — DST-robust via locked timezone offset + noon-anchored arithmetic | Threading-Timing | LOW |
| TR-streak-007 | `local_calendar_date_from_utc` (Formula 3) | Threading-Timing | LOW |
| TR-streak-008 | Atomic 2-write order: `("streak.streak_count", N, flush=false)` then `("streak.last_workout_date_local", date, flush=true)` | State persistence | LOW |
| TR-streak-009 | Failed state sticky single-emit (`streak_persistence_failed` not re-emitted) | State persistence | LOW |
| TR-streak-010 | Namespace `streak.*` filter on `critical_save_failed` (cross-system namespace isolation) | Cross-system communication | LOW |
| TR-streak-011 | Milestone gates ascending + no-duplicate + bounded invariant (`MILESTONE_THRESHOLDS`) | Data structure | LOW |
| TR-streak-012 | `Streak.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` cross-system consistency | Data structure | LOW |

### GDD: design/gdd/workout-state-tracker.md — System: #9 Workout State Tracker

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-wst-001 | Subscribe to exactly 7 #2 typed signals (workout_started/set_logged/rest_started/rest_ended/workout_completed/poll_failed/poll_recovered) | Cross-system communication | LOW |
| TR-wst-002 | 5-state WorkoutPhase machine (IDLE/WARM_UP/SET_ACTIVE/REST_PERIOD/WORKOUT_COMPLETE) | State machine | LOW |
| TR-wst-003 | 3-substate (INITIALISING/READY/SUSPENDED) + Frozen flag orthogonal | State machine | LOW |
| TR-wst-004 | `set_progress` monotonicity (CF-1) — downward revision suppressed; estimator backward-step blocked | Data structure | LOW |
| TR-wst-005 | 5 read-only queries + immutable RO resources; no `set_*` / `mutate_*` / `force_*` public methods | Data structure | LOW |
| TR-wst-006 | CI lints: `WorkoutStateTracker.(set_|_)` outside source = 0; `PersistenceLayer.write("wst.")` outside source = 0 | Test infrastructure | LOW |
| TR-wst-007 | `set_history` append-only — never in-place mutate / pop | Data structure | LOW |
| TR-wst-008 | `workout_id` lifecycle isolation — old WorkoutSummaryRO preserved, new `set_history` resets empty | Data structure | LOW |
| TR-wst-009 | `dominant_class` hysteresis — `DOMINANT_CLASS_CHANGE_COOLDOWN_S = 30s` | Data structure | LOW |
| TR-wst-010 | Class→stat routing call to `Stat.apply_stat_delta(STR/VIT/DEX, vol, VOLUME_TICK, source_key=...)` | Cross-system communication | LOW |
| TR-wst-011 | UNKNOWN class honest return — `&"UNKNOWN"` (no fallback to STRIKE in #9; that's #14's responsibility) | Data structure | LOW |
| TR-wst-012 | `completed_exercises_count` = distinct exercise_id count | Data structure | LOW |
| TR-wst-013 | `total_volume` aggregation + frozen at workout_completed; late events dropped per EC-32 | Data structure | LOW |
| TR-wst-014 | EWMA `historical_avg_sets_per_workout` (alpha=0.3) computed BEFORE workout reset | Data structure | LOW |
| TR-wst-015 | Autoload boot position 5 per project.godot (F-SETUP-1 synced) | Engine capability | LOW |
| TR-wst-016 | Namespace `wst.*` on PersistenceLayer (ADR-003 binding) | State persistence | LOW |
| TR-wst-017 | Frozen flag set on `poll_failed`, cleared on `poll_recovered` (orthogonal to substate) | State machine | LOW |
| TR-wst-018 | CI-1 binding: `set_progress >= 0.8` → triggers #14 boss anchor pre-spawn pipeline | Cross-system communication | LOW |
| TR-wst-019 | CI-4 binding: `total_volume` → ADR-005 `volume_factor = min(1.0, completed/TARGET)` | Cross-system communication | LOW |

### GDD: design/gdd/combat-resolver.md — System: #13 CombatResolver

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-combat-001 | Stateless pure-function — `class_name CombatResolver extends RefCounted` with `static func` only; no `var` instance member, no `@onready`, no `signal` (CI enforced) | Data structure | LOW |
| TR-combat-002 | Determinism — identical CombatContext input → identical HitResult output (1000-run replay test) | Data structure | LOW |
| TR-combat-003 | Per-cast StatSnapshot pattern — source StatSystem mutation mid-call does NOT affect HitResult | Data structure | LOW |
| TR-combat-004 | Single entry: `static func resolve_hit(ctx: CombatContext) -> HitResult` | Data structure | LOW |
| TR-combat-005 | EnemyDirector owns signal emission (`hit_resolved` / `enemy_killed` / `combat_metric_anomaly`); CombatResolver emits nothing | Cross-system communication | LOW |
| TR-combat-006 | HitResolvedPayload schema (12 typed fields incl. `transition_id` for #15 RNG sub-seed) | Data structure | LOW |
| TR-combat-007 | `combat_metric_anomaly.reason` enum (6 values: GSM_SUSPENDED / INVALID_ABILITY_ID / NEGATIVE_DAMAGE / CLAMP_TRIGGERED / DEAD_TARGET_RESOLVE / RNG_INJECTION_MISSING) | Data structure | LOW |
| TR-combat-008 | AOE — caller iterates `resolve_hit(ctx_i)`; 1-to-1 mapping; `hit_seq` 0/1/2/3/4 | Data structure | LOW |
| TR-combat-009 | Formula 1: `base_damage = max(1, round(attack × multiplier − defense))` | Data structure | LOW |
| TR-combat-010 | Formula 2: `roll_crit` via `hash(transition_id + ability_id + hit_seq)` sub-seed (deterministic) | Data structure | LOW |
| TR-combat-011 | Formula 3: crit multiplier = 1.5× (Q-D2 [A] fixed) | Data structure | LOW |
| TR-combat-012 | Formula 4: 5-tier damage classification (ratio thresholds 0.01/0.05/0.15/0.40 of max_hp); crit forces ≥HEAVY | Data structure | LOW |
| TR-combat-013 | Formula 5: overkill clamp + expose `overkill_excess` | Data structure | LOW |
| TR-combat-014 | HitOutcome enum exactly 4 values (NORMAL_HIT / CRITICAL_HIT / KILLED / OVERKILL) — NO DODGED in MVP | Data structure | LOW |
| TR-combat-015 | 5-stage pipeline order: validate → compute_hit_damage → roll_crit → apply_crit_multiplier → detect_overkill + classify_damage_tier → outcome | Data structure | LOW |
| TR-combat-016 | Unicode-safe sub-seed; `MAX_HIT_SEQ = 1_000_000` boundary | Data structure | LOW |
| TR-combat-017 | Null ctx + dead target + NaN multiplier safe handling | Data structure | LOW |
| TR-combat-018 | CPU budget ≤ 1.0ms per combat tick (ADR-001 FR-3) | Performance | LOW |
| TR-combat-019 | AOE clamp `MAX_TARGETS_PER_CAST = 8` (distance sort) | Data structure | LOW |
| TR-combat-020 | GSM Suspended gate — caller snapshots gsm_state; resolver rejects in Stage 1 | State machine | LOW |

### GDD: design/gdd/enemy-director.md — System: #14 EnemyDirector

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-enemy-001 | 8 state containers owned in EnemyDirector class body (Rule 1 caller-side state locality, CI enforced) | Data structure | LOW |
| TR-enemy-002 | Damage chokepoint — all damage paths via `CombatResolver.resolve_hit()`; inline arithmetic rejected (CI) | Cross-system communication | LOW |
| TR-enemy-003 | Autoload position LAST among combat-relevant autoloads (after #1/#3/#5/#6/#7/#11/#12/#15/#28) | Engine capability | MEDIUM |
| TR-enemy-004 | No direct `Camera2D.position/zoom/offset` mutation, no `GPUParticles2D.emitting = true` outside wrappers (ADR-001 CI enforced) | Engine capability | HIGH |
| TR-enemy-005 | Subscribe via `connect_for_initial_state` to #1 GSM + #12 AbilitySystem (Contract 6) | Cross-system communication | LOW |
| TR-enemy-006 | Emit exactly 3 signals (hit_resolved / enemy_killed / combat_metric_anomaly) — no internal/debug leak | Cross-system communication | LOW |
| TR-enemy-007 | Anomaly rate limit: 10/sec per reason via `Formula 4 rate_limit_check`; window expiry emits aggregate | Cross-system communication | LOW |
| TR-enemy-008 | No `signal.disconnect/connect` in hot path (`_physics_process`, `_on_ability_cast`) | Performance | LOW |
| TR-enemy-009 | Catch-up queue defers new AOE casts (Rule 7) | State machine | LOW |
| TR-enemy-010 | `_rng_factory.create(transition_id)` + `create_sub(transition_id, label)` — sub-RNG independence + deterministic across processes | Data structure | LOW |
| TR-enemy-011 | RNG ban: no `randf/randi/randf_range/Time.get_ticks_msec/RandomNumberGenerator.new()` outside `_rng_factory` (CI) | Data structure | LOW |
| TR-enemy-012 | EnemyRegistry.tres schema validation: 3 archetypes × mandatory fields (Rule 12) | Data structure | LOW |
| TR-enemy-013 | Wave archetype readability — 60%+ test recognition (ADVISORY playtest) | Data structure | LOW |
| TR-enemy-014 | Boss kill same-frame `enemy_killed` emit (Rule 5 order) | Threading-Timing | LOW |
| TR-enemy-015 | Boss anchor pre-spawn at `set_progress >= 0.8`; rollback on undo set | State machine | LOW |
| TR-enemy-016 | Light-workout boss scaling (`LIGHT_WORKOUT_THRESHOLD_SETS = 2` → mini-boss + reduced ritual intensity) | Data structure | LOW |
| TR-enemy-017 | Particle throttle auto-degrade (`Formula 3`) — 3-frame >33ms window triggers `caller_mult` 1.5→1.0; 60-frame recovery hysteresis | Performance | MEDIUM |
| TR-enemy-018 | Per-enemy AI state machine (SPAWNING / IDLE / PURSUING / ATTACKING / STAGGERED / DYING) | State machine | LOW |
| TR-enemy-019 | CPU orchestration ≤ 0.5ms p95 (ADR-001 FR-4) | Performance | LOW |
| TR-enemy-020 | MOBILITY mob lateral dodge (`Formula 2 mobility_dodge_offset`) | Data structure | LOW |
| TR-enemy-021 | `enemy_killed.transition_id` propagates verbatim from `ctx.transition_id` (#15 RNG seed binding) | Cross-system communication | LOW |

### GDD: design/gdd/loot-drop-system.md — System: #15 Loot Drop System

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-loot-001 | Loot rarity formula per ADR-0005: `loot_rarity_score = workout_score × 0.75 + rng_roll × 0.25`; Pillar 3 floor `max(raw_tier, COMMON)` | Data structure | LOW |
| TR-loot-002 | Rule 7.5 NEW: `workout_id` resolution via `WorkoutStateTracker.get_active_workout_id()` with explicit null branch | Cross-system communication | LOW |
| TR-loot-003 | Ceremony cap split: `MINI_BOSS_CEREMONY_CAP=5` + `FINAL_BOSS_RESERVED=1` (final boss ceremony guaranteed) | Data structure | LOW |
| TR-loot-004 | Micro-ack ceremony tier — 0.15s toast + mailbox badge for mini-boss #6+ | Data structure | LOW |
| TR-loot-005 | Formula E3 while-loop with `max_iterations=10` + monotonic invariant (anti-pillar soft-clamp termination) | Data structure | LOW |
| TR-loot-006 | Rule 4 dual-gate: workout-score tier ceiling `floor(workout_score × 5)` | Data structure | LOW |
| TR-loot-007 | Floor protection + LRU eviction (age-only + 150ms floor protection) | Data structure | LOW |
| TR-loot-008 | Item type weighted selection (Formula E1) | Data structure | LOW |
| TR-loot-009 | Class affinity resolution (Formula E2) | Data structure | LOW |
| TR-loot-010 | Inventory overflow → mailbox (Formula E4); MAX_INVENTORY 120 | Data structure | LOW |
| TR-loot-011 | Backend cache + commit via ADR-002 endpoints; idempotent via `transition_id` UNIQUE | Networking | LOW |
| TR-loot-012 | Daily token gate (workout-locked daily, NOT calendar-daily) | Data structure | LOW |
| TR-loot-013 | Unknown rarity tier → COMMON fallback + telemetry (EC-22) | Data structure | LOW |
| TR-loot-014 | Pending TTL expiry (Formula 3) — 6-day soft + 30-day hard cap | State persistence | LOW |
| TR-loot-015 | bfcache resume action (Formula 4) — 30s parity with #26 | Platform | MEDIUM |
| TR-loot-016 | Local vs backend reconciliation (Formula 5) — unsynced client wins / synced backend wins | State persistence | LOW |
| TR-loot-017 | Catch-up threshold compression (Formula 6) | Data structure | LOW |
| TR-loot-018 | 27 owned knobs + 14 INVs + 10 CI lints | Test infrastructure | LOW |
| TR-loot-019 | 44 ACs (34 BLOCKING + 4 ADR-RATIFICATION-GATED) | Test infrastructure | LOW |

### GDD: design/gdd/boss-system.md — System: #16 Boss System

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-boss-001 | BossTemplate Resource schema with @export immutable fields (boss_id / class_archetype / tier / base_hp / base_defense / attack_patterns / loot_guarantee_min_tier / reveal_ritual_intensity) | Data structure | LOW |
| TR-boss-002 | Deterministic boss spawn selection via hash seed on `transition_id + dominant_class + total_planned_sets` | Data structure | LOW |
| TR-boss-003 | Class archetype mapping (STRIKE/CONTROL/MOBILITY); fallback STRIKE for UNKNOWN | Data structure | LOW |
| TR-boss-004 | Player snapshot frozen at COMMITTED (mid-fight stat mutations don't affect boss damage) | Data structure | LOW |
| TR-boss-005 | Formula 3 attack-pattern anti-spam: zero consecutive same-pattern; deterministic round-robin via `posmod` hardened for negative hash | Data structure | LOW |
| TR-boss-006 | `enemy_killed.transition_id` chain integrity (verbatim from spawn → #15) | Cross-system communication | LOW |
| TR-boss-007 | Formula 1 boss_max_hp_scaling: `(player_attack × TARGET_KILL_HITS × HP_SCALE_FACTOR)` clamped [MIN_BOSS_HP=50, MAX_BOSS_HP=10000] | Data structure | LOW |
| TR-boss-008 | Formula 2 boss_attack_damage_scaling: anti-one-shot ceiling `floor(player_max_hp × 0.5)` | Data structure | LOW |
| TR-boss-009 | Formula 4 reveal_ritual_intensity_scaling — final boss only, categorical (mini-boss dead path per Weber-Fechner) | Data structure | LOW |
| TR-boss-010 | AC-24: all BossTemplate.reveal_ritual_intensity ≤ 1.0 (well below #5 max_caller_multiplier=1.5) | Performance | LOW |
| TR-boss-011 | Boss cleanup within 2 frames: all `_spawned_emitters` released via #5 wrapper + `queue_free` | Engine capability | LOW |
| TR-boss-012 | AI state inheritance from #14 enemy_ai_state_enum exactly (SPAWNING/IDLE/PURSUING/ATTACKING/STAGGERED/DYING) | State machine | LOW |
| TR-boss-013 | Spawn position bounded by ArenaConfig.tres (#14 `arena_config` single source of truth) | Data structure | LOW |
| TR-boss-014 | Rule 11 wall-clock cleanup via `Time.get_ticks_msec()` deadline + CONNECT_ONE_SHOT (bfcache-safe) | Platform | MEDIUM |
| TR-boss-015 | Duplicate spawn idempotency — same `transition_id` within 1 frame → exactly 1 instance + BOSS_DUP_SPAWN_001 log | Data structure | LOW |
| TR-boss-016 | Boss snapshot Resource caching mechanism (`BossInstance.player_stat_snapshot`) frozen-at-spawn (AC-36 enforces CF-3) | Data structure | LOW |
| TR-boss-017 | Light-workout boundary (mini-boss spawn for ≤2 planned sets) | Data structure | LOW |
| TR-boss-018 | TTK target band 4-12s anti-bullet-sponge on MAX_BOSS_HP | Data structure | LOW |

### GDD: design/gdd/camera-system.md — System: #7 Camera System

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-camera-001 | Single Camera2D node owner via `register_camera(camera2d_ref)` autoload API (no direct mutation outside autoload — ADR-001 CI) | Engine capability | HIGH |
| TR-camera-002 | `set_follow_target` + dead-zone box (8% × 12% world units @ 1920×1080) | Engine capability | LOW |
| TR-camera-003 | `request_focal(target, duration, zoom)` with `is_finite()` reject + clamp `MAX_FOCAL_DURATION=10.0` + `FOCAL_ZOOM_CAP=4.0` | Engine capability | LOW |
| TR-camera-004 | Formula 1: `follow_position_after_smoothing` — Godot Camera2D `position_smoothing_enabled` + `position_smoothing_speed` (4.x stable) | Engine capability | MEDIUM (4.6 verification — Compatibility renderer) |
| TR-camera-005 | Formula 2: `quart_ease_out_value` for Focal entry (76% in 30% time invariant) | Data structure | LOW |
| TR-camera-006 | Formula 3: `cubic_ease_in_out_value` for Focal exit (symmetric) | Data structure | LOW |
| TR-camera-007 | Formula 4: `glance_lock_on_time(30.0, 3.0, 5.0) < 500ms` Pillar 2 numerical proof | Performance | LOW |
| TR-camera-008 | Formula 5: `dead_zone_box_world_extents` — viewport-resize aware auto-recompute | Engine capability | LOW |
| TR-camera-009 | Strict reject second `request_focal()` during active Focal state | State machine | LOW |
| TR-camera-010 | Focal tween freeze under `get_tree().paused = true` (process_mode = PAUSABLE); resume without phase jump | State machine | LOW |
| TR-camera-011 | bfcache restore via `_cached_target_path` + `get_node_or_null` (stale → camera_target_lost signal) | Platform | HIGH |
| TR-camera-012 | Subscribe via `connect_for_initial_state` (ADR-006 Contract 6) | Cross-system communication | LOW |
| TR-camera-013 | CPU ≤ 0.1ms p95 mobile / ≤ 0.2ms p95 desktop (ADR-001 FR-1) | Performance | LOW |
| TR-camera-014 | Decoupled from #6 via CI Rule 13 — no direct ScreenEffects access | Cross-system communication | LOW |

### GDD: design/gdd/screen-effects-system.md — System: #6 ScreenEffects

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-screen-001 | `shake(intensity, duration)` + `hit_pause(duration)` + `set_motion_intensity(value)` API; NaN/INF reject; clamp `motion_intensity ∈ [0, 1.0]` | Engine capability | LOW |
| TR-screen-002 | Formula 1 Trauma² decay: `shake_offset = pow(trauma, 2) × MAX_OFFSET_PX × noise; trauma -= decay_rate × delta` | Data structure | LOW |
| TR-screen-003 | Formula 2 trauma combiner: additive `min(1.0, trauma + new)`; decay_rate `max(old, new)` monotonic | Data structure | LOW |
| TR-screen-004 | Formula 3 pause max-remaining (no extend, no stack); clamp at `MAX_PAUSE_SEC = 0.12s` | Data structure | LOW |
| TR-screen-005 | `TRAUMA_EPSILON = 0.01` short-circuit (zero per-frame cost when idle) | Performance | LOW |
| TR-screen-006 | Dispatch table — auto-invoke on `ParticleSystemWrapper.burst_started(PresetId.X)` per Rule 9 | Cross-system communication | LOW |
| TR-screen-007 | Re-entry guard `MAX_EMIT_DEPTH = 0` strict (Rule 12) | Threading-Timing | LOW |
| TR-screen-008 | Suspended entry: trauma=0, pause_remaining=0, shader uniform Vector2.ZERO, `get_tree().paused = false` | State machine | LOW |
| TR-screen-009 | Shake via shader uniform `u_shake_offset` (NOT `Camera2D.offset`) — ADR-001 CI enforced | Engine capability | HIGH |
| TR-screen-010 | `HUD_SHAKES_WITH_WORLD` knob — HUD layer position toggle | Engine capability | LOW |
| TR-screen-011 | Motion intensity slider for accessibility (motion_intensity = 0 → shake zero but hit_pause fires) | Data structure | LOW |
| TR-screen-012 | CPU ≤ 0.3ms p95 mobile / ≤ 0.5ms p95 desktop (ADR-001 FR-1) | Performance | LOW |
| TR-screen-013 | Autoload position 14 per project.godot (F-SYNC-2 synced — was claimed pos 5) | Engine capability | LOW |
| TR-screen-014 | Subscribe via `connect_for_initial_state` (Contract 6) | Cross-system communication | LOW |

### GDD: design/gdd/particle-system-wrapper.md — System: #5 ParticleSystemWrapper

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-particle-001 | `play(preset_id, position, caller_mult, count) → ParticleHandle` sync return | Engine capability | LOW |
| TR-particle-002 | Input validation: NaN reject + multiplier clamp `[0.5, 2.0]` | Engine capability | LOW |
| TR-particle-003 | Object pool size 16 with SMALL/LARGE tier split (no runtime realloc) | Performance | MEDIUM |
| TR-particle-004 | Tier selection by `amount`: ≤32 SMALL, >32 LARGE | Performance | LOW |
| TR-particle-005 | CPU ledger O(1) incremental update with ±15% drift tolerance + 2-sec reconcile poll | Performance | LOW |
| TR-particle-006 | Formula 1 multiplier composition with clamp boundaries `[1, 256]` | Data structure | LOW |
| TR-particle-007 | LRU eviction age-only + 150ms floor protection | Data structure | LOW |
| TR-particle-008 | Hybrid LOOT carve-out: LOOT bypasses floor for non-LOOT victims | Data structure | LOW |
| TR-particle-009 | Combat all-protected silent reject + telemetry | Cross-system communication | LOW |
| TR-particle-010 | Mobile UA detection boot-cached (PlatformDetect autoload) — no per-frame JSBridge call | Platform | HIGH |
| TR-particle-011 | `burst_started` signal: sync emit AFTER alloc BEFORE `emitting=true` | Cross-system communication | LOW |
| TR-particle-012 | Re-entry guard: nested `play()` from signal handler → deferred | Threading-Timing | LOW |
| TR-particle-013 | CI static check: magic int/string preset ID rejected at build | Test infrastructure | LOW |
| TR-particle-014 | Autoload position 12 + boot budget ≤80ms (F-SYNC-2 synced — was claimed pos 4) | Engine capability | LOW |
| TR-particle-015 | GSM `connect_for_initial_state` subscription (Contract 6) | Cross-system communication | LOW |
| TR-particle-016 | Wrapper persists nothing (3 invariants — no `PersistenceLayer.*` call) | State persistence | LOW |
| TR-particle-017 | EC1 fallback path on boot exceed 80ms | Performance | LOW |
| TR-particle-018 | EC12 atomic mid-flight reject on Active→Suspended | State machine | LOW |
| TR-particle-019 | EC16 material hot-swap via `call_deferred` (WebGL 2 pre-first-frame race) | Engine capability | HIGH (WebGL 2 async pipeline) |
| TR-particle-020 | `MAX_ACTIVE_PARTICLES = 200` mobile (game-concept hard governance §8) / 400 desktop | Performance | HIGH (ADR-001 RATIFICATION-GATED) |
| TR-particle-021 | iOS Safari UA detection 100% accuracy across variants (ADR-001 FR-3) | Platform | HIGH |
| TR-particle-022 | LOOT_BURST vs LOOT_RARE_BURST peripheral 1-second glance distinguishability (ADR-001 FR-2) | Engine capability | LOW |
| TR-particle-023 | Direct `GPUParticles2D` instantiation outside wrapper FORBIDDEN (ADR-001 CI) | Engine capability | LOW |

### GDD: design/gdd/game-concept.md — System: Game Concept (hard governance)

| TR-ID | Requirement | Domain | Engine Risk |
|---|---|---|---|
| TR-concept-001 | Engine: Godot 4.6 (mandatory) | Engine capability | LOW |
| TR-concept-002 | Web Export primary target with iOS Safari + desktop browser parity | Platform | HIGH |
| TR-concept-003 | Hard governance §8: `MAX_ACTIVE_PARTICLES = 200` mobile cap (non-negotiable) | Performance | HIGH |
| TR-concept-004 | GymSys backend polling `/api/game/state` every 5s (MVP); SSE v0.2 upgrade | Networking | LOW |
| TR-concept-005 | Backend-primary save state `game_state.json` per user in GymSys backend; localStorage cache for offline boot (ADR-003 supersedes localStorage → IndexedDB) | State persistence | LOW |
| TR-concept-006 | 5 Pillar enforcement (Real Body Real Power / Frictionless Companion / Drop Euphoria / Muscle=Class / Mirror Moment) | Cross-cutting | LOW |
| TR-concept-007 | Anti-Pillar: NOT 氪金 / NOT cardio-input to attack / NOT PVP / NOT in-game grinding for loot quality | Cross-cutting | LOW |
| TR-concept-008 | GPUParticles2D (NOT CPUParticles2D — Web Export perf differential) | Engine capability | MEDIUM |

**Phase 2 totals**: ~270 TRs across 14 GDDs + game-concept (well above the 60-150 guidance — Mirror Hero is a contract-heavy project).

---

## Phase 3 — Traceability Matrix (compact)

| TR-ID(s) Range | System | ADR Coverage | Status |
|---|---|---|---|
| TR-persist-001..017 | PersistenceLayer | ADR-0003 (full); ADR-0006 Contracts 3/4/9/10/11/14 | ✅ Covered (17/17) |
| TR-gsm-001..024 | GameStateMachine | ADR-0006 (all 15 Contracts); ADR-0002 (Decision #3/#4 binding); ADR-0003 (Decision #5 Storage) | ✅ Covered (24/24) |
| TR-gym-001..017 | GymSys Backend Client | ADR-0002 (full endpoint contract); ADR-0004 (CORS/same-origin); ADR-0006 Contracts 2/15 (transition_id + pending_since) | ✅ Covered (17/17) |
| TR-stat-001..017 | StatSystem | ADR-0003 (`stat.*` namespace); ADR-0005 (PR_BREAKTHROUGH provisional); ADR-0006 Contracts 3/4/6 | ✅ Covered (17/17) |
| TR-ability-001..020 | AbilitySystem | ADR-0003 (`ability.unlocked.*`); ADR-0005 (PR_BREAKTHROUGH path); ADR-0006 Contracts 3/4/6 | ✅ Covered (20/20) |
| TR-streak-001..012 | Streak | ADR-0003 (`streak.*` first adopter + FR-1/2/3 RATIFICATION-GATED); ADR-0006 Contracts 6/9 | ✅ Covered (12/12) |
| TR-wst-001..019 | WorkoutStateTracker | ADR-0002 (7 signals); ADR-0003 (`wst.*`); ADR-0005 (volume_factor input); ADR-0006 Contracts 2/4/6/9 | ✅ Covered (19/19) |
| TR-combat-001..020 | CombatResolver | ADR-0001 (FR-3 CPU 1.0ms); ADR-0005 (FR-2 transition_id chain); ADR-0006 Contract 6 | ✅ Covered (20/20) |
| TR-enemy-001..021 | EnemyDirector | ADR-0001 (FR-4 + Foundation autoload CPU 0.5ms); ADR-0002 (catch-up cadence); ADR-0005 (transition_id chain); ADR-0006 Contracts 2/4/6 | ✅ Covered (21/21) |
| TR-loot-001..019 | LootDropSystem | ADR-0005 (formula primary); ADR-0002 (cache/commit endpoints); ADR-0006 Contract 2 | ✅ Covered (19/19) |
| TR-boss-001..018 | BossSystem | ADR-0005 (transition_id chain via #14); ADR-0006 Contract 6; ADR-0001 (ritual ≤ #5 max_caller_multiplier) | ✅ Covered (18/18) |
| TR-camera-001..014 | CameraSystem | ADR-0001 (full — FR-1/2/3 RATIFICATION-GATED); ADR-0006 Contracts 4/6 | ✅ Covered (14/14) |
| TR-screen-001..014 | ScreenEffects | ADR-0001 (full — FR-1/2/3 RATIFICATION-GATED); ADR-0006 Contracts 4/6 | ✅ Covered (14/14) |
| TR-particle-001..023 | ParticleSystemWrapper | ADR-0001 (full — FR-1/2/3 RATIFICATION-GATED + game-concept §8 governance); ADR-0006 Contract 6 | ✅ Covered (23/23) |
| TR-concept-001..008 | game-concept hard governance | ADR-0001 (§8 200/400); ADR-0002 (polling); ADR-0003 (storage tier); ADR-0006 (engine version) | ✅ Covered (8/8) |

**Coverage totals**: 263 Covered / 0 Partial / 0 Gaps within current GDD/ADR set.

**Structural gaps (require NEW ADRs)** — carried from prior matrix + re-validated:

| Gap ID | Description | Impacted | Required ADR | Priority |
|---|---|---|---|---|
| GAP-001 | STRIKE/CONTROL/MOBILITY enum naming convention NOT locked across #9/#10/#12/#13/#14/#15 — F-9 followup from #9 review log + #15 F-12 ADR-007 candidate | All Class-tagged systems | ADR-0007 | **HIGH (pre-VS implementation)** |
| GAP-002 | Autoload positions 4-14 NOT yet ratified in a master ADR (project.godot is current ground truth per F-SETUP-4; #4 Audio + #28 Telemetry + #33 AttentionBudget unwritten) | #4, #28, #33 + boot sequence audit | ADR-0008 | MEDIUM (pre-Pre-MVP sprint) |
| GAP-003 | Signal payload schema convention (`workout_id` resolution, late-binding) — surfaced by #15 Pass 2 F-12 | #15, #9, #29 | ADR-0009 (candidate) | MEDIUM |
| GAP-004 | Mirror Moment ceremony ownership split between #26 (avatar render) and #29 (ceremony composition) — surfaced by #26 Pass 4 CD binding | #26 BLOCKED, #29 Not Started | ADR-0010 (candidate, Producer escalation) | HIGH (#26 BLOCKED gate) |
| GAP-005 | F-STEP4-1: ADR-0006 Contract 6 code at line 374 still shows `callv(["", captured_state, _initial_state_payload])` deprecated empty-string pattern — needs addendum to ratify self-loop OR Contract 6 code update | #1, all `connect_for_initial_state` subscribers | ADR-0006 addendum | HIGH (Foundation chain gate) |

---

## Phase 4 — Conflict Detection

### Confirmed pre-existing findings (re-verified)

**F-STEP4-1 — ADR/GDD divergence in initial-state delivery (GDD = self-loop / ADR = empty string)**
- **Type**: Integration contract conflict
- **ADR-0006 Contract 6 claim** (line 374): `callable.callv(["", captured_state, _initial_state_payload])` — uses empty String for `from_state`
- **GDD game-state-machine.md claim** (lines 615-630, F-STEP4-2 synced): `callable.callv([captured_state, captured_state, payload])` — self-loop pattern; sentinel detection via `payload.source_event == "initial_state"`
- **Impact**: GDScript signal signature is `state_changed(from_state: GameState, to_state: GameState, payload: StateTransitionPayload)` — empty String `""` is type-incompatible with GameState enum. ADR sample would crash at runtime.
- **Resolution options**: (a) **PREFERRED** — ratify self-loop pattern in ADR-006 addendum (matches impl + GDD; sentinel via payload.source_event). (b) Introduce GameState.INITIAL enum value (expands 9→10; ripples 51 ACs — NOT preferred). Implementation (`src/autoload/game_state_machine.gd`) and CI lint already follow option (a); only ADR prose lags.
- **Status**: CONFIRMED. Implementation correct; ADR prose update pending.

**F-RAT-1 — Contract 8 Invariant 1 boundary gap (cross-knob `STATE_TRANSITION_FALLBACK_MS` + `MIN_REVEAL_WINDOW_SECONDS`)**
- **Type**: Tuning-knob safe-range invariant gap
- **Claim**: Contract 8 safe ranges `STATE_TRANSITION_FALLBACK_MS ∈ [100, 1499]` + `MIN_REVEAL_WINDOW_SECONDS ∈ [11, 30]`. Invariant 1: `FALLBACK_MS ≤ MIN_REVEAL × 100`. Worst-case corner: `FALLBACK=1499` + `MIN_REVEAL=11` → `1499 > 1100` violates invariant. Production defaults (1000/15) safely in invariant interior.
- **Resolution adopted (option b)**: Cross-knob warning paragraph added to game-state-machine.md after line 505: "若 MIN_REVEAL < 15, FALLBACK upper must ≤ MIN_REVEAL × 100 − 1". Runtime `_assert_knob_invariants()` trips on actual violation. Per Gate A signoff 2026-05-28.
- **Status**: CONFIRMED. GDD updated; ADR Negative Consequences notes the gap.

### NEW conflicts surfaced this review

**N-001 — Autoload position numbering: ADR-0001 says PlatformDetect "position 3 or later" but project.godot locks position 3**
- **Type**: Integration contract conflict (mild)
- **ADR-0001 line 156**: "Autoload position: position 3 or later (after PersistenceLayer position 1 + GameStateMachine position 2)"
- **Current ground truth**: project.godot locks PlatformDetect at position 3; downstream GDDs (#11 Stat at 5, #12 Ability at 6, #5 Particle at 12, #6 ScreenEffects at 14) all assume this concrete position
- **Impact**: LOW — ADR allows the actual position; no runtime conflict. But the "or later" wording invites future drift.
- **Resolution**: ADR-0001 prose edit (1-line).

**N-002 — ADR-0006 lists `Depends On: None` but ADR-0001 lists `Depends On: ADR-006`; ADR-0006 was ratified 2026-05-28 (Accepted) yet still labeled Proposed in ADR-0001 dependency tables**
- **Type**: ADR status staleness across cross-reference tables
- **ADR-0001 line 24**: "Depends On: ADR-006 State Machine Contract (Proposed)"
- **ADR-0002 line 24**: "Depends On: ADR-006 State Machine Contract (Proposed)"
- **ADR-0003 line 24**: "Depends On: ADR-006 State Machine Contract (Proposed)"
- **ADR-0006 actual status**: Accepted 2026-05-28 (confirmed)
- **Impact**: LOW — dependency relationships are valid; only status labels are stale. Cosmetic but creates auditor confusion.
- **Resolution**: Bulk update all 5 downstream ADRs to "ADR-006 State Machine Contract (Accepted 2026-05-28)".

**N-003 — ADR-0002 still labels self as Proposed; per ADR-0004 line 25 "blocked on ADR-0002 Accepted"; mutual dependency loop never resolved**
- **Type**: Status dependency chain
- **Chain**: ADR-0002 (Proposed) → blocked on ADR-0004 (Proposed) → which depends on ADR-0002 endpoint contracts (circular reference partially resolved by both being Proposed simultaneously)
- **Impact**: MEDIUM — both ADRs locked at Proposed; neither blocking VS-tier authoring (per ADR-002 "Backend Readiness Gate Phase A" allows VS-tier work pre-Accepted), but Production-tier gate requires both Accepted.
- **Resolution**: Coordinated ratification — author Gate-A/B for ADR-0002 + ADR-0004 in same session.

**N-004 — ADR-0003 line 167 ("`STATE_TRANSITION_FALLBACK_MS` corrects stale ADR-006 registry entry of 5000ms") — ADR-0003 explicitly corrects ADR-0006; but ADR-0006 Contract 10 line 502-503 NOW carries the revised values (`MAX_CHAIN=6`, `BUDGET=150ms`)**
- **Type**: ADR self-consistency (already resolved)
- **Status**: NOT a conflict — both ADRs now consistent (6×150=900ms). The "corrects stale" prose in ADR-0003 should be amended to "ratifies ADR-006 Contract 10 revised values" for clarity.
- **Resolution**: Cosmetic ADR-0003 prose cleanup.

**N-005 — game-concept.md §Technical Considerations line 268 says "localStorage cache for offline boot" but ADR-0003 explicitly FORBIDS localStorage and supersedes with IndexedDB**
- **Type**: Document-to-document conflict (game-concept ↔ ADR-0003)
- **Impact**: LOW — game-concept predates ADR-0003; ADR-0003 explicitly supersedes ("game-concept.md Q1: '...localStorage cache for offline boot' — this ADR updates 'localStorage' to IndexedDB"). But game-concept prose still reads as if localStorage were the plan.
- **Resolution**: game-concept.md prose edit OR add inline marker "[superseded by ADR-0003 — see IndexedDB via user://]".

**N-006 — ADR-0001 Phase B CI script `check_screen_effects_callers.gd` enforces "no `Engine.time_scale` mutation outside #6"; #6 GDD (Rule 8) implements hit_pause via `get_tree().paused = true` not `Engine.time_scale`**
- **Type**: CI rule scope conflict (mild)
- **ADR-0001 line 184**: enforces "no `Camera2D.offset` / `Engine.time_scale` mutation outside #6 ScreenEffects autoload"
- **#6 ScreenEffects GDD Rule 8**: uses `get_tree().paused = true` (frame freeze) — NOT `Engine.time_scale`
- **Impact**: LOW — CI rule guards against a pattern #6 doesn't actually use; over-strict but not blocking. Could be relaxed OR retained as defensive.
- **Resolution**: Keep CI rule (defensive); update ADR-0001 prose to clarify intent: "no `Engine.time_scale` mutation anywhere in src/ (#6 uses `get_tree().paused = true` instead)".

**N-007 — Contract 11 risk window (~0.05% per-transition) tolerated at VS-tier via Gate B 5 MVP escalation triggers; trigger #2 ("PersistenceLayer.write latency p99 > 50ms in real-device telemetry") lacks calendar owner**
- **Type**: Risk acceptance accountability gap
- **Status**: Documented as F-RAT-5 follow-up (5 MVP escalation triggers calendared). Trigger #2 specifically lacks "Engine-programmer + godot-specialist" calendar slot.
- **Impact**: MEDIUM — if Q-A4 never runs, Contract 11 risk window silently becomes permanent.
- **Resolution**: Producer to calendar 5 MVP triggers + Q-A4 spike before any state machine story enters sprint.

### ADR dependency topology (revised)

```
ADR-0006 (Accepted 2026-05-28) — Foundation
  ├─ ADR-0001 (Proposed) — depends on ADR-006 + own VS profiling
  ├─ ADR-0003 (Proposed) — depends on ADR-006 + ADR-001 memory ceiling
  ├─ ADR-0002 (Proposed) — depends on ADR-006 + ADR-004 (mutual)
  ├─ ADR-0004 (Proposed) — depends on ADR-002 + ADR-003 (mutual)
  └─ ADR-0005 (Proposed) — depends on None (formula self-contained)
```

**No dependency cycles** — ADR-0002 ↔ ADR-0004 mutual reference is intentional staging (both can be Proposed simultaneously; both need Accepted together).

**Recommended implementation order**: ADR-0006 (done) → ADR-0001 (VS profiling) → ADR-0005 (formula, no deps) → coordinated ADR-0002 + ADR-0004 (pair) → ADR-0003.

**Proposed-status flags** (5 of 6 ADRs Proposed):
- ADR-0001 — gated on VS-tier mobile Safari profiling (5 verification items)
- ADR-0002 — gated on ADR-0004 (CORS preflight on X-Session-Token)
- ADR-0003 — gated on Q-E1 Private Mode UX + Safari ITP touch-refresh verification
- ADR-0004 — gated on production nginx deployment test
- ADR-0005 — gated on VS-tier playtest distribution validation

---

## Phase 5 — Engine Audit

### Version consistency

| ADR | Engine | Status |
|---|---|---|
| ADR-0001 | Godot 4.6 (pinned) | ✅ |
| ADR-0002 | Godot 4.6 (pinned) | ✅ |
| ADR-0003 | Godot 4.6 (pinned) | ✅ |
| ADR-0004 | Godot 4.6 | ✅ (browser-managed, engine-agnostic) |
| ADR-0005 | Godot 4.6 | ✅ |
| ADR-0006 | Godot 4.6 (pinned 2026-02-12) | ✅ |

**All ADRs consistent. No version drift.**

### Engine Compatibility section presence

| ADR | Engine Compatibility section | References Consulted | Post-Cutoff APIs Used | Verification Required |
|---|---|---|---|---|
| ADR-0001 | ✅ | ✅ | ✅ (5 listed) | ✅ (5 items) |
| ADR-0002 | ✅ | ✅ | ✅ (3 listed) | ✅ (4 items) |
| ADR-0003 | ✅ | ✅ | ✅ (FileAccess.store_* bool) | ✅ (3 items) |
| ADR-0004 | ✅ | ✅ | ✅ (None — engine-agnostic) | ✅ (4 items) |
| ADR-0005 | ✅ | ✅ | ✅ (None — formula pure math) | ✅ (3 items) |
| ADR-0006 | ✅ | ✅ | ✅ (3 listed + 1 considered/avoided) | ✅ (4 items) |

**6/6 ADRs have complete Engine Compatibility sections. No missing.**

### Post-cutoff API usage validation

| API | Used By | 4.x Status | Status |
|---|---|---|---|
| `FileAccess.store_*` returning `bool` | ADR-0003, ADR-0006 | 4.4 breaking change | ✅ correctly handled |
| `Enum.find_key()` | ADR-0006 (BossPayload.to_dict) | 4.4+ | ✅ correctly cited |
| GDScript variadic args (`Variant...`) | ADR-0006 (explicitly avoided in `Callable.call_deferred`) | 4.5 | ✅ correctly avoided |
| `Resource.duplicate_deep()` | ADR-0006 (considered, NOT used — explicit to_dict/from_dict instead) | 4.5 | ✅ correctly bypassed |
| `RandomNumberGenerator.seed` | ADR-0005 | Stable | ✅ |
| `HTTPRequest.timeout: float` | ADR-0002 | Stable | ✅ |
| `JavaScriptBridge.create_callback()` + `eval()` returning `JavaScriptObject` | ADR-0002 (SSE v0.2 path) | Stable since 4.2 | ✅ |
| `SceneTree.create_timer(time_sec, process_always, ignore_time_scale, ignore_paused)` | ADR-0002 | Stable; explicit 4-param form prescribed | ✅ |
| `Camera2D.position_smoothing_enabled` + `position_smoothing_speed` | ADR-0001 | Stable 4.x | ✅ |
| `GPUParticles2D` on Compatibility/WebGL2 | ADR-0001 | Transform feedback supported | ✅ (VS verification required) |
| `JavaScriptBridge.eval()` | ADR-0001 | 4.x canonical | ✅ |
| Shader Baker | ADR-0001 | 4.5+ | ⚠️ Compatibility renderer coverage TO VERIFY at VS-tier |
| `RenderingServer.global_shader_parameter_set` | ADR-0001 | Stable | ✅ |
| `Object.get_script().get_global_name()` | ADR-0006, persistence-layer GDD Rule 4 | Stable | ✅ |
| `ClassDB.instantiate(payload_type)` | persistence-layer GDD Rule 4 | Stable | ✅ |
| `SubViewport.size = display_size * Vector2(1.05, 1.05)` (code-set, NOT `stretch_shrink = 1.05`) | ADR-0001 | Corrects float-truncation bug (stretch_shrink is int) | ✅ |

**No deprecated APIs in active use.** Cross-checked against `deprecated-apis.md`:
- `yield()` → `await signal` — N/A
- `connect("signal", obj, "method")` → `signal.connect(callable)` — ✅ all ADRs use Callable form
- `instance()` → `instantiate()` — ✅
- `OS.get_ticks_msec()` → `Time.get_ticks_msec()` — ✅ all ADRs use Time singleton
- `duplicate()` for nested resources → `duplicate_deep()` — ADR-0006 explicitly bypasses via `to_dict/from_dict`
- `Texture2D` in shader parameters → `Texture` — N/A (no shader code in ADRs directly)

**No stale version references.** All ADRs reference `docs/engine-reference/godot/VERSION.md` (pinned 2026-02-12).

### Engine knowledge risk per ADR

| ADR | Risk Level | Notes |
|---|---|---|
| ADR-0001 | HIGH | Multiple post-cutoff renderer/Camera2D APIs; 5 VS-tier verification items |
| ADR-0002 | MEDIUM (LOW for HTTPRequest; MEDIUM for JSBridge SSE) | 4 VS-tier verification items |
| ADR-0003 | HIGH | 4.4 FileAccess bool semantics — critical; IDB fence unverified on 4.6 |
| ADR-0004 | LOW | Browser-managed; engine-agnostic |
| ADR-0005 | LOW | Pure math; IEEE 754 stable |
| ADR-0006 | HIGH | 4.6 post-cutoff; 4 VS verification items including COOP/COEP threading default |

**Engine reference module docs sampled**: rendering.md / networking.md / physics.md / audio.md / animation.md / input.md / ui.md / navigation.md — none contradict ADR claims. Notable cross-references confirmed:
- breaking-changes.md confirms 4.4 `FileAccess.store_*` returns `bool` (ADR-0003/0006 correctly handled)
- breaking-changes.md confirms 4.5 GDScript variadic args (ADR-0006 correctly avoids in Callable contexts)
- breaking-changes.md confirms 4.6 D3D12 default on Windows + Jolt physics default + Glow before tonemapping (none in ADR scope)
- current-best-practices.md confirms `duplicate_deep()` availability (ADR-0006 correctly bypasses)
- current-best-practices.md ripgrep tool note `rg --type gdscript` is invalid (`*.gd` is `gap` type) — relevant to all CI scripts referenced in ADRs

---

## Top findings summary (for main session synthesis)

- **Critical conflicts**: 1 (F-STEP4-1 ADR/GDD divergence — needs ADR-006 addendum or Contract 6 code update)
- **Coverage gaps requiring new ADRs**: 5 (prioritized)
  1. **ADR-006 addendum (F-STEP4-1)** — ratify self-loop pattern OR update Contract 6 code (HIGH; Foundation chain gate)
  2. **ADR-0007 — Class enum convention** (STRIKE/CONTROL/MOBILITY/UNKNOWN) (HIGH; pre-VS implementation; cross-#9/#10/#12/#13/#14/#15)
  3. **ADR-0010 — Mirror Moment ceremony ownership split** (HIGH; #26 BLOCKED gate)
  4. **ADR-0008 — Autoload position map** (positions 4-14 + Audio/#28/#33 unwritten autoloads) (MEDIUM; pre-Pre-MVP)
  5. **ADR-0009 — Signal payload schema convention** (`workout_id` resolution, late-binding from #15 F-12) (MEDIUM)
- **Engine audit issues**: 0 blocking; 1 advisory (Shader Baker Compatibility renderer coverage in Godot 4.6 — VS-tier verification item)
- **F-STEP4-1 status verification**: CONFIRMED — GDD-level resolution (self-loop) consistent with implementation + CI lint; ADR-0006 Contract 6 code at line 374 still shows deprecated `""` empty-string pattern; ADR addendum pending.
- **F-RAT-1 status verification**: CONFIRMED — cross-knob warning added to GDD per Gate A option (b); production defaults safely in invariant center; runtime `_assert_knob_invariants()` catches violations.
- **NEW issues surfaced**:
  - **N-001**: ADR-0001 PlatformDetect "position 3+" wording vs project.godot locked position 3 (cosmetic — 1-line edit)
  - **N-002**: 5 downstream ADRs reference ADR-006 as "Proposed" but it's Accepted 2026-05-28 (status label staleness — bulk update)
  - **N-003**: ADR-0002 ↔ ADR-0004 status dependency loop (both Proposed; both need Accepted together for Production gate)
  - **N-004**: ADR-0003 "corrects stale ADR-006 5000ms" prose — both now consistent; prose cleanup needed
  - **N-005**: game-concept.md still says "localStorage cache" — ADR-0003 supersedes; needs inline marker
  - **N-006**: ADR-0001 CI rule for `Engine.time_scale` mutation is over-strict (#6 uses `get_tree().paused`); benign defensive rule
  - **N-007**: Contract 11 Q-A4 spike (MVP escalation trigger #2) lacks calendar owner; Producer escalation required
  - **PARTICLE/SCREEN/AVATAR position drift**: F-SETUP-1/F-SYNC-2 already resolved in GDDs; ADR-0001 line 156 still uses "position 3 or later" wording — consider tightening to "position 3 (locked per project.godot)" for clarity (covered in N-001)

**Coverage health**: 263/263 TRs covered by existing ADRs. Zero TR coverage gaps within the approved-GDD set. All structural gaps are about NEW ADRs needed for systems-level conventions (enum naming, autoload map, signal schema, ceremony ownership) rather than missing per-TR coverage.
