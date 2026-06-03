# Workout State Tracker

> **Status**: Approved (CD-GDD-ALIGN APPROVED 2026-05-27 with 2 CONCERNs inline-fixed same-session)
> **Author**: user + claude (full mode — section specialists per skill rules)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 4 (Muscle = Class) PRIMARY substrate; Pillar 1 (Real Body, Real Power) supporting (anti-fabrication chain 第五件套); Pillar 2 (Frictionless Companion) supporting (O(1) read contract for #14 4Hz tick)
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED 2026-05-27 — 8 ALIGN + 3 ADVISORY + 2 CONCERN (inline-fixed: AC-40 n≥8 MVP requirement + Q-X3 recommended answer added) + 0 BLOCKING. CD assessment: "Mirror Hero pre-production 至今最 architecturally sound 嘅 GDD —— 全部 5 個 pillar 嘅 substrate binding 都 honest，5 個 locked contracts 100% honored，anti-fabrication chain 第五件套合格入隊"

## Overview

Workout State Tracker (#9) 係 Core layer 嘅「workout reality bridge」— 接收 #2 GymSys Backend Client 嘅 7 個 typed workout signals (`workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`, `poll_failed`, `poll_recovered`)，aggregate 成 in-game workout phase state machine (Idle / WarmUp / SetActive / RestPeriod / WorkoutComplete)，並 expose 一組 stable read-only queries 畀 5 個下游 consumer 用：

- `get_workout_phase() -> WorkoutPhase` — workout 當前階段 enum
- `get_dominant_ability_class() -> AbilityClass` — **Pillar 4 day-flavor signal source**，#14 EnemyDirector Rule 12 wave archetype 同 #11 Stat System VOLUME_TICK class routing 兩邊都讀
- `set_progress: float [0.0, 1.0]` — **Pillar 2 boss anchor pre-spawn trigger**，#14 Rule 13 用嚟喺 final-set 嘅 80% 位置 pre-spawn final boss，避免 `workout_completed` arrival 嗰刻先 instantiate 引發 ≥500ms frame spike
- `get_completed_exercises_count() -> int` — ADR-005 loot rarity formula `volume_factor = min(1.0, completed / EXERCISE_TARGET_COUNT=5)` 嘅 input
- `workout_completed` signal forwarding — #15 Loot Drop 必爆 trigger + #14 boss anchor commit trigger

呢個系統嘅核心責任 = **「將 #2 嘅 raw event stream 翻譯成 in-game-usable aggregated state，唔做 mutation，唔做 fabrication」**。所有狀態 derive from real GymSys backend events；冇任何 code path 可以 mutate phase / set_progress / dominant_class 而 bypass #2 signal stream。呢個 architectural posture 令 #9 成為 anti-fabrication chain (#2 + #3 + #11 + #14) 嘅第五件套 — Pillar 1 (Real Body, Real Power) supporting role。

**Negative contract (重要)**：#9 **永不 call back to #2 GymSysClient**（per #2 GDD line 477 read-only consumer constraint）；亦**永不 mutate #11 / #14 state directly** — #9 expose pure queries + emit derived signals，consumer 自己 connect。Player 通過 downstream visible effects（leg day 嘅 MOBILITY 0.75× spawn cadence、boss appear before「最後一 rep」嘅 emotional climax）間接「感受到」#9 嘅輸出，但不會 directly 見到 #9 嘅任何 visual surface（Core layer data system）。

**Key ADR references**：
- **ADR-002 GymSys Integration Protocol** (Proposed) — locks 7 workout signal payloads #9 consumes
- **ADR-003 Save State Strategy** (Proposed) — `wst.*` namespace + IPersistence.read/write for in-progress workout snapshot bfcache resume
- **ADR-005 Loot Rarity Formula** (Accepted 2026-05-27) — defines `volume_factor` consumer of #9's `completed_exercises` output
- **ADR-006 State Machine Contract** — Contract 4 (autoload boot order) + Contract 6 (`connect_for_initial_state` helper) + Contract 9 (drift-tolerant TTL for snapshot `is_expired` check)

## Player Fantasy

### Identity: 「肌群預言家 / The Muscle Oracle」

#9 將「今日真實練咩肌群」呢個身體事實，**預言**成「今日 game 入面係咩職業日」。玩家行入 gym warming up 嘅嗰一刻，#9 已經拎到第一個 `set_logged` event，已經知道今日 dominant ability class 係 MOBILITY ——下游 #14 EnemyDirector 即刻將 game 世界調成 leg-day flavor（spawn cadence 加快 25%、敵人 archetype 轉成要走位閃避嘅 MOBILITY mob）。冇 menu、冇 confirm、冇「choose your class」UI。**玩家控制 game 嘅方法，係控制自己**。

### Central Player Moments (兩個 anchor 場景)

**Moment A — 週二臨時改練 leg day (Pillar 4 day-flavor prediction)**：
玩家本來 schedule 係 push day，但週二臨時轉做 leg。佢做完 warm-up squat 第一組，攞起 phone 望 game 一眼 —— **game 已經變成 leg day 模式**：spawn 加快、敵人類型轉為 mobility archetype、wave cadence 多咗動態壓力。「我冇揀過 leg day，但 game 已經知道」呢一刻嘅信任落腳點 = Pillar 4 mechanical core。

**Moment B — Final-set 80% 嘅 boss preemptive arrival (Pillar 2 sub-500ms 承諾)**：
玩家做緊今日最後一組 squat 嘅最後 3 reps，正在咬牙。佢眼角望 phone —— **boss 已經喺度等緊**。冇 loading、冇 spawn animation 撞落 `workout_completed` event。佢完成最後 1 rep，event 一到，`workout_completed` 即刻 trigger commit + visible engagement —— **「冇咗呢一 rep，呢個 boss 就唔會喺度」**。Pillar 2 frictionless companion 嘅延伸意義：not just「唔搶你注意力」，而係**「game 已經知道下一步要做咩」**。

### Architectural Protection (Pillar 1 anti-fabrication 第五件套)

預言嘅準確性 = 訓練嘅誠實性。#9 嘅 architectural posture 直接 enforce 呢條等式：

1. **唯一 input source = #2 GymSysClient 7 typed signals** — 冇任何 local fabrication path；player 唔可以 UI override `dominant_ability_class`
2. **Negative contract**：5 個 public queries 全部 read-only；冇 public mutator method (跟 #8 Streak 同款 closed API pattern) — 違反 = CI lint 拒
3. **Anti-fabrication chain 第五件套**：#2 (event source) + #3 (persistence backbone) + #11 (stat aggregation) + #14 (orchestration discipline) + **#9 (state derivation gate)** —— 任何一環造假，玩家信任 collapse；五環全部 architectural enforcement 先成為 Pillar 1 完整 defense
4. **Pure derivation**：所有 5 個 queries 都係 **derived from event stream**，唔係 stored mutable state。即使 storage layer 出 bug，replay event stream 都應該 reproduce 同樣結果

### What It WOULDN'T Be (anti-patterns rejected)

- **NO「Choose Today's Class」menu** — player 改 class 唯一方法 = 去 gym 練不同 muscle group
- **NO weighted blend UI** — 多 muscle session 用 deterministic "last clear dominant" rule，唔交畀 player tune
- **NO local fabrication** — `poll_failed` 期間 phase freeze，唔 invent set events；`poll_recovered` 先繼續
- **NO「Smart Coach」predictive fill** — 漏一個 set_logged，set_progress 就唔郁；唔 estimate「你應該做完啦」
- **NO retroactive mutation** — once `workout_completed` emit，phase 鎖入 COMPLETE；唔接受「actually 我想再做多一個動作」嘅 ad-hoc 改寫（呢個 case 要 backend 出 new `workout_started`）

### Falsifiable Tests (5 tests bound to Section H ACs)

| # | Test | Expected outcome | Failure = framing broken |
|---|------|------------------|--------------------------|
| **1** | **Blind dominant_class playtest** — playtester A 練 leg、B 練 push，兩個人開 game 唔睇 menu 講出 game 嘅 feel | A 講「敵人走得快、要閃」(MOBILITY)，B 講「敵人扛得實、要打硬」(STRIKE) | 兩個體感一致 → 預言唔落地 → Pillar 4 mechanical home failure |
| **2** | **Sub-500ms boss anchor latency** — mock `workout_completed` arrival timing vs boss visible-on-screen frame | p95 ≤ 500ms（pre-spawn at `set_progress > 0.8` + commit on event arrival） | p95 > 500ms → Pillar 2 frictionless 承諾失敗 |
| **3** | **Truth-gate integrity** — mock GymSys stream 故意 skip 一個 `set_logged` event | `set_progress` 唔郁、boss 唔出 | 任何 interpolation / fallback 推進 phase → anti-fabrication chain 第五件套 broken |
| **4** | **Closed API CI lint** — grep `tools/ci/check_workout_state_caller.gd` | 偵測到任何 caller path 直接 mutate `_workout_phase` / `_dominant_class` / `_set_progress` → build fail | 任何 caller bypass closed API → Pillar 1 architectural defense 失效 |
| **5** | **bfcache resume integrity** — mobile Safari freeze 30s → resume → assert phase + set_progress 同 freeze 前一致 OR cleanly reset to Idle (per snapshot `is_expired`) | Either consistent OR clean reset；NO half-state corruption | 半 stale phase 出現 → reality bridge 違反 |

### Fantasy Risk Register (3 FR — gate-bound)

| FR | Risk | Mitigation gate | Status |
|----|------|------------------|--------|
| **FR-1** | `set_progress` not exposable at MVP (Q-9-SetProgress per #14 forward constraint) → #14 boss anchor falls back to 50% reps heuristic → Falsifiable Test #2 (sub-500ms) latency target may not hold | Section D Formula 5 (set_progress derivation) + Section E EC list fallback path explicit | OPEN — pending Section D design |
| **FR-2** | Exercise→Class mapping #10 未 designed (Pre-MVP tier) → #9 cannot return `get_dominant_ability_class()` reliably for VS-tier → Falsifiable Test #1 (Pillar 4 blind playtest) fails at VS milestone | Section C inline VS-tier hardcoded MVP-3-exercise stub (bench_press→STRIKE, row→CONTROL, squat→MOBILITY) + Section F #10 dependency provisional contract | OPEN — pending Section C design |
| **FR-3** | Anti-fabrication chain 第五件套 integrity depends on ALL 5 systems (#2 + #3 + #11 + #14 + #9) honoring closed-API + truth-gate posture. Any single system regression → entire chain broken → Pillar 1 collapse | Section C Rule N CI lint enforcement + Section H AC closed-API verification + Bidirectional sync gap flagged to #11 / #14 next-revision batch | OPEN — pending Section C + H design |

### Pillar Ties (explicit)

- **Pillar 4 肌群即職業 (PRIMARY substrate)**：`get_dominant_ability_class()` 係 Pillar 4 mechanical home — 冇呢條，Pillar 4 唔知喺邊個 system 落腳
- **Pillar 1 真身真力 (supporting — anti-fabrication chain 第五件套)**：完成 chain 嘅 architectural integrity
- **Pillar 2 無壓力陪伴 (supporting — sub-500ms boss anchor enabling)**：`set_progress` 係 #14 Rule 13 pre-spawn 嘅唯一 trigger source
- **Pillar 5 鏡像時刻 (echo only)**：「daily mirror moment micro-version」— 每一日訓練都係一次 mirror echo，但 #9 唔負責 weekly visible evolution（#29 owns）

### Vocabulary Partition (Foundation/Core tier extended to 9-way)

```
#1 GSM         — ms-scale temporal continuity
#5 Particles   — peripheral visual sensation
#6 ScreenFX    — peripheral kinaesthetic sensation
#7 Camera      — spatial framing ("Silent Showrunner")
#8 Streak      — cross-day temporal accumulation
#11 Stat       — anti-fabrication trio member (real PR → numbers)
#13 Combat     — DNF 重擊指揮家 (Pillar 3)
#14 EnemyDir   — 無形軍師 (Pillar 2 protector)
#9 Workout     — 肌群預言家 (Pillar 4 substrate + sub-500ms anchor enabler)
```

## Detailed Design

### Core Rules

#### Rule 1 — Closed-API Read-Only Surface

**Rationale**：Pillar 1 anti-fabrication — #9 係單一真相源，下游 system (#11 / #14 / #15) 唔可以繞過 query API 直接讀內部 state。跟 #8 Streak / #11 Stat 同款 closed-API pattern。

**Public API** (5 read-only methods + 5 signals locked by #14/#15 downstream contracts)：

```gdscript
# Public read-only query API
func get_current_phase() -> WorkoutPhase
func get_dominant_ability_class() -> AbilityClass     # returns &"UNKNOWN" if no session data (Rule 5)
func get_set_progress() -> float                       # clamp [0.0, 1.0], monotonic non-decreasing within workout
func get_completed_exercises_count() -> int            # monotonic non-decreasing within workout
func get_workout_snapshot() -> WorkoutSnapshotRO       # immutable struct for debug/UI consumers

# Forwarded signals (re-emit only, never synthesised)
signal workout_started_forwarded()
signal workout_completed_forwarded(completed_at: int, transition_id: int)
signal workout_summary_available(summary: WorkoutSummaryRO)   # emit IMMEDIATELY BEFORE workout_completed_forwarded
signal set_progress_changed(new_progress: float)              # derived, debounced 500ms [→ Knob: snapshot_debounce_ms]
signal dominant_class_changed(new_class: AbilityClass)        # derived, on flip only (not per set_logged)
signal phase_changed(from_phase: WorkoutPhase, to_phase: WorkoutPhase)
```

- 冇 `set_*`, `mutate_*`, `force_*` 嘅 public method
- Internal state mutation 只可以喺 `src/core/workout_state_tracker.gd` 入面發生
- `WorkoutSnapshotRO` / `WorkoutSummaryRO` 係 immutable resource — `resource_local_to_scene = false`，consumer 嘗試 mutate field 應該 fail-fast
- CI script `tools/ci/check_workout_state_caller.gd` enforce (Rule 14)

**Cross-ref**: #2 GDD line 477; #8 Streak Rule 13 closed-API; #11 Stat Rule 4; #14 Rule 12-13 downstream callers.

---

#### Rule 2 — WorkoutPhase Enum and Transition Matrix

**Rationale**：Pillar 4 substrate 需要明確 phase 語意俾下游判斷時機 — #15 LootDrop 只可以喺 `WORKOUT_COMPLETE` trigger，#14 boss anchor pre-spawn 只可以喺 `SET_ACTIVE` 加 `set_progress ≥ 0.8` 時觸發。

```gdscript
enum WorkoutPhase {
    IDLE,              # no active workout (boot default + post-complete terminal)
    WARM_UP,           # workout_started received, no set_logged yet
    SET_ACTIVE,        # mid-set window (last event was set_logged, before rest_started)
    REST_PERIOD,       # rest_started received, awaiting rest_ended OR next set_logged
    WORKOUT_COMPLETE,  # terminal — auto-returns to IDLE next tick via call_deferred
}
```

**Valid transition matrix** (rows = from, cols = to)：

| From \ To | IDLE | WARM_UP | SET_ACTIVE | REST_PERIOD | WORKOUT_COMPLETE |
|---|---|---|---|---|---|
| IDLE | — | ✓ `workout_started` | ✗ EC | ✗ EC | ✗ EC |
| WARM_UP | ✗ EC | — | ✓ `set_logged` | ✗ EC (no set yet) | ✓ `workout_completed` |
| SET_ACTIVE | ✗ EC | ✗ EC | ✓ `set_logged` (next set) | ✓ `rest_started` | ✓ `workout_completed` |
| REST_PERIOD | ✗ EC | ✗ EC | ✓ `set_logged` (next set) | — (rest_ended internal flag, NOT phase change [→ EC]) | ✓ `workout_completed` |
| WORKOUT_COMPLETE | ✓ auto next tick | ✗ EC | ✗ EC | ✗ EC | — |

- ✗ EC 標記：違反 transition matrix → drop event + log `wst.invariant_violation(from, to, signal)` + DO NOT crash + DO NOT fabricate
- `rest_ended` from REST_PERIOD 設定 internal flag `_rest_ended_awaiting_next_set = true` 但 phase 保持 REST_PERIOD (per Rule 4 set_progress derivation needs)

---

#### Rule 3 — Substates Lifecycle (Initialising / Ready / Suspended)

跟 #11 Stat / #8 Streak 同款 boot + bfcache pattern。

```gdscript
enum Substate { INITIALISING, READY, SUSPENDED }
```

- **INITIALISING**：autoload `_ready()` → restore snapshot from #3 PersistenceLayer (Rule 7) → subscribe to #2 signals via `connect_for_initial_state(callable)` per ADR-006 Contract 6 → substate → READY
- **READY**：normal operation；query API 返 live values
- **SUSPENDED**：收到 #1 GSM `state_changed → Suspended` 觸發；query API 返 last-known cached values + `WorkoutSnapshotRO.is_suspended = true`；workout signals received during SUSPENDED → **DROP + log** (per Rule 8 — NOT queue)

---

#### Rule 4 — set_progress Derivation Contract

**Rationale**：#14 EnemyDirector Rule 13 boss anchor pre-spawn 用 `set_progress >= 0.8` 作為 trigger — 需要呢個值單調上升 + 喺 final set 有意義變化。FR-1 風險：`final_planned_set` 喺 `workout_started` 時可能未知。

**Derivation inputs** (all derived from #2 signal stream, never external)：
- `current_set_index` — count of `set_logged` events received this workout
- `planned_total_sets` — known iff GymSys exposes via future signal extension `[ADR-002-EXTENSION-GATED]`；否則 estimated
- `reps_in_current_set` / `planned_reps_in_current_set` — same caveat

**Fallback strategy (VS-tier)** when `planned_total_sets` unknown：
- Rolling estimator：`estimated_total = max(current_set_index + 1, historical_avg_sets_per_workout)` [→ Formula 1]
- `historical_avg_sets_per_workout` persists in `wst.history.avg_sets` (EWMA, α=0.3) [→ Knob: `historical_ewma_alpha`]
- Confidence flag：`get_workout_snapshot().set_progress_is_estimated: bool` so #14 can downgrade behavior if estimated
- Per #14 Rule 13 fallback：if `set_progress` unreliable → #14 uses `reps_completed_in_set >= ceil(planned_reps × 0.5)` heuristic instead

**Monotonicity invariant**：`set_progress` MUST be non-decreasing within a single workout。若 estimator 修正 `estimated_total` 上調，value clamp to `max(previous_value, recomputed_value)` 避免 downward jump [→ EC]。

**Freshness contract**：caller (e.g. #14 4Hz tick) reads last-known value；NO interpolation, NO time-extrapolation — Pillar 1 forbids fabricated progress。若 caller need smoother boss anchor input，caller-side local interpolation 自理 (gameplay-programmer Q2 confirmed)。

---

#### Rule 5 — dominant_class Derivation (Set-count Weighted + Last-Solo-Leader Tiebreak)

**Rationale**：Pillar 4 substrate；Falsifiable Test #1 嘅 A-vs-B blind playtest 直接依賴呢條 derivation。Game-designer rejected volume-weighted (heavy compound 偏見) AND last-cleared-dominant (warmup 偏見) AND first-class-lock (warmup 偏見) — set-count 最忠實反映「玩家願意花幾多組做呢個 muscle group」嘅 intent。

**Algorithm** (deterministic, no randomness, no player tuning)：

```
derive_dominant_class():
  set_counts = {STRIKE: 0, CONTROL: 0, MOBILITY: 0}
  for each set_logged event in current workout session:
    class = ExerciseClassMapper.classify(exercise_id)  # via #10 interface, VS stub fallback
    if class == UNKNOWN: continue   # skip unmapped exercises (DO NOT default to STRIKE)
    set_counts[class] += 1

  max_count = max(set_counts.values())
  if max_count == 0: return UNKNOWN   # no mapped sets yet

  winners = [class for class, count in set_counts if count == max_count]
  if len(winners) == 1: return winners[0]

  # Tie: walk set_logged history backwards, return class of most recent SOLO leader
  # (i.e. the class that was uniquely leading at some prior set_logged event)
  return last_solo_leader_in_history  OR  previous_returned_value if no prior solo leader
```

**`&"UNKNOWN"` policy** (per game-designer Q2 — sticky-last-known on transient tie)：

| Phase | `get_dominant_ability_class()` returns |
|-------|----------------------------------------|
| IDLE (no active workout) | `&"UNKNOWN"` |
| WARM_UP (0 sets logged) | `&"UNKNOWN"` |
| First set logged → before 2nd set | derived class of set #1 (committed immediately) |
| Subsequent sets | recomputed; **if computation returns UNKNOWN due to transient tie → return previous returned value (sticky)** |
| WORKOUT_COMPLETE (terminal frame) | last returned value |
| Persisted across workouts (`last_session_class`) | persisted to `wst.history.last_completed_class` — for #28 telemetry / future #15 streak analytics ONLY; **#9 never reads back during Idle** (per game-designer Q3) |

**Class naming**：keep current STRIKE / CONTROL / MOBILITY (matches #11 / #12 / #14 already-Approved enum). Game-designer flagged alternative naming (STRIKE/GRAPPLE/STANCE) as Q-X1 Open Question — defer to playtest evidence + cross-GDD review.

**Cache strategy** (per gameplay-programmer Q3)：
- `_cached_dominant_class` updated synchronously inside `_on_set_logged` handler — NOT via `call_deferred` (避免 1-frame staleness for #14 4Hz tick reads)
- `get_dominant_ability_class()` O(1) return cached value
- Invalidated to UNKNOWN on `workout_started`；preserved through WORKOUT_COMPLETE terminal frame
- `dominant_class_changed` signal emit 只喺 returned value 真正 flip 時 (not per set_logged) — 避免 #14 spurious wave re-routing

---

#### Rule 6 — #11 Stat System Caller Obligation (One-Way)

**Rationale**：#11 owns stat math + VOLUME_TICK formula；#9 只係 event trigger 來源。Pillar 1 invariant：#9 NEVER computes stat math，only forwards observable workout events to Stat as the canonical caller。

**Caller pattern**：

```gdscript
# Inside _on_set_logged handler (per set_logged event):
var class_id = ExerciseClassMapper.classify(exercise_id)
if class_id != AbilityClass.UNKNOWN:
    Stat.apply_stat_delta(
        stat_id = _derive_stat_id_from_class(class_id),  # PUSH→STR / PULL→DEX / LEG→VIT (Rule 13)
        delta = reps * weight,                            # raw volume; #11 applies VOLUME_TICK formula internally
        source = StatSource.VOLUME_TICK,
        source_key = "%s_set_%d" % [_current_workout_id, current_set_index]  # per-set idempotency key (see note)
    )
```

**Note — per-set idempotency key vs ADR-006 transition_id**：Per-set `apply_stat_delta` 呼叫使用 `source_key = workout_id + "_set_" + set_index` 作為 #11 側嘅 deduplication key。呢個係 **client-derived correlation ID**，唔係 ADR-006 Contract 2 嘅 GSM-acquired `transition_id`（後者只係喺 `WORKOUT_COMPLETE` phase entry 一次過 acquire，用於 boss commit + loot trigger）。原因：每個 `set_logged` event 唔係 GameStateMachine phase transition，唔應 consume GSM generational lock slot；per-set 冪等性由 `_current_workout_id` (Rule 11.1) + monotonic `current_set_index` 組合已足夠。

- **#9 NEVER reads `Stat.get_*()` back** — strictly one-way caller (avoids circular dep + matches Pillar 1)
- If #11 substate ≠ READY → buffer invocation into `_pending_stat_deltas: Array` (cap 100 [→ Knob: `pending_stat_deltas_max`], overflow drops oldest + log `wst.stat_queue_overflow`) [→ EC]
- Drain queue on `Stat.ready` signal

**Bidirectional sync gap** (Rule 14 batch): #11 GDD Rule 4 須 confirm `apply_stat_delta` accepts `source_key: String` param (per-set client-derived idempotency key，唔係 ADR-006 transition_id) + "buffer-while-not-ready" caller contract。

---

#### Rule 7 — Persistence: `wst.*` Namespace Snapshot (Bfcache Survival)

**Rationale**：Web Export bfcache eviction（iOS Safari aggressive）+ tab refresh，in-progress workout 必須能 resume。#9 係 PersistenceLayer Rule 12 `wst.*` namespace **first adopter**。

**Persisted keys** (via `PersistenceLayer.write`)：

| Key | Type | Purpose |
|---|---|---|
| `wst.current_workout.phase` | int (enum) | resume phase machine |
| `wst.current_workout.id` | String | matches GymSys workout_id (when #2 exposes — see Q-X2 below) OR client-derived fallback (per Rule 11.1) |
| `wst.current_workout.started_at` | int (unix ms) | TTL anchor + 24h bfcache window |
| `wst.current_workout.set_history` | Array[Dictionary{exercise_id, reps, weight, logged_at}] | replay for dominant_class + set_progress recompute |
| `wst.current_workout.set_progress_state` | Dictionary | estimator memory (Rule 4) |
| `wst.current_workout.last_signal_received_at` | int (unix ms) | reconciliation hint per gameplay-programmer Q4 — detect "workout_completed missed during freeze" cases |
| `wst.history.avg_sets` | float | EWMA across workouts |
| `wst.history.last_completed_class` | int (enum) | telemetry only; #9 never reads back during Idle (game-designer Q3) |

**NOT persisted** (recomputed/re-derived on resume)：
- `_cached_dominant_class` (recompute from set_history via Rule 5)
- `set_progress` value (re-derive from estimator state)
- Substate (always boots INITIALISING)
- Signal connections (re-subscribe in `_ready()`)
- Any Node reference

**TTL via `is_expired()`**：24h window from `started_at` [→ Knob: `workout_snapshot_ttl_hours`, default 24]。超時 → discard snapshot, boot IDLE + log `wst.snapshot_expired` [→ EC]。

**Write triggers** (avoid write-amplification)：
- On `phase_changed` (always, flush=true)
- On `set_logged` (always — light Array append)
- On `rest_started` / `rest_ended` (always — short event update)
- On `set_progress_changed` 內部更新：debounced 500ms [→ Knob: `snapshot_debounce_ms`]

---

#### Rule 8 — Suspended: Drop Workout Signals (per gameplay-programmer Q1)

**Rationale**：Workout phase state machine 非 idempotent；replay 一個 stale `set_logged` event 喺 resume 後 = fabrication = Pillar 1 violation。#2 GymSysClient source-level 已經 gate (per #2 Rule 14 Suspended drain)，#9 喺 defensive second-line drop。

**Behavior**：
- Substate enters SUSPENDED → 所有 incoming #2 workout signals (workout_started / set_logged / rest_started / rest_ended / workout_completed) → **drop + log** `wst.signal_dropped_during_suspend(signal_name)`
- `poll_failed` / `poll_recovered` signals during SUSPENDED → still processed (these mutate `_is_frozen` flag only — Rule 9)
- Substate returns to READY → resume normal subscription；trust #2 backfill mechanism (#2 polling cursor pulls missed events on `poll_recovered`)

**Distinction from #8 Streak Rule 11**：Streak 用 latest-wins single-slot drain because streak counter is idempotent (count of days, not event sequence). #9 workout machine NOT idempotent — drop is correct.

---

#### Rule 9 — poll_failed / poll_recovered Freeze Behavior

**Rationale**：Pillar 1 anti-fabrication — 當 #2 GymSysClient 失去 backend connectivity 時，#9 完全唔可以 fabricate phase transition 或 dominant_class flip。Player UI 應該見到「workout state frozen」而唔係 stale-but-pretending-fresh data。

**On `poll_failed(category)` received**：
- Set internal `_is_frozen = true` flag (NOT a separate Substate — keeps READY semantic)
- Phase machine 拒絕所有 transition (return early + log `wst.frozen_transition_blocked(signal)`) [→ EC]
- Query API 繼續 return last-known values；`WorkoutSnapshotRO.is_stale_due_to_poll_failure = true`
- 唔 invoke #11 Stat delta during frozen window
- `set_progress` 凍結，`dominant_class` 凍結

**On `poll_recovered()` received**：
- `_is_frozen = false`
- #2 backfill mechanism pushes any missed events; #9 processes via normal handlers (set_progress / dominant_class recompute happens organically)
- Emit `unfreeze_completed` debug signal

---

#### Rule 10 — workout_completed Forwarding (Strict Emission Order)

**Rationale**：#14 (boss commit) + #15 (loot roll) 都需要喺 `workout_completed` 嗰刻拎齊 summary data — separate signals 會 race condition。

**Decision: direct re-emit + auxiliary summary signal** (rejected single fat signal — would break #2 locked payload)：

`WorkoutSummaryRO` immutable resource fields：
- `completed_at: int`
- `transition_id: int` (Rule 11)
- `dominant_class: AbilityClass`
- `completed_exercises_count: int`
- `final_set_progress: float`
- `total_sets_logged: int`
- `total_volume: float` (sum of reps × weight)

**Strict emission order** (deterministic for #14 / #15 listeners)：
1. Phase transition to `WORKOUT_COMPLETE`
2. `phase_changed(prev, WORKOUT_COMPLETE)` emit
3. `workout_summary_available(summary)` emit  ← consumers cache the snapshot
4. `workout_completed_forwarded(completed_at, transition_id)` emit  ← consumers trigger actions (boss commit, loot roll)
5. Persistence snapshot updated to terminal state (set_history preserved for telemetry)
6. Auto-transition to IDLE on next tick via `call_deferred(_transition_to_idle)` [→ EC]

---

#### Rule 11 — transition_id Binding (ADR-006 Contract 2)

`workout_completed` phase entry acquires `transition_id` via `GameStateMachine.acquire_transition_id()` (ADR-006 generational lock). Same ID published via both `workout_completed_forwarded(.., transition_id)` AND `WorkoutSummaryRO.transition_id`.

**Anti-pattern guard**：#9 NEVER generates its own transition_id — must use #1 GSM helper. Violation = ADR-006 Contract 2 generational lock invariant break. [→ EC: transition_id collision via ADR-006 tombstone forward-recovery].

---

#### Rule 11.1 — workout_id Source (Defensive Monotonicity per gameplay-programmer Q5)

**Conflict discovered**：#2 GymSysClient `signal workout_started()` payload (per gymsys-backend-client.md line 86 + registry `gymsys_client_signal_contract`) has **NO `workout_id` field**. Yet #9 needs to identify "this set belongs to current workout" vs "stale set from previous workout" (gameplay-programmer Q5).

**Defensive design** (until cross-GDD resolution per Q-X2)：
1. On `workout_started` → client-derive `_current_workout_id = "wst-%d-%d" % [Time.get_unix_time_from_system(), randi() % 10000]` (deterministic-ish; collision risk acceptable for VS-tier — single-device session per ADR-006 Decision #4)
2. On `set_logged(exercise_id, reps, weight)` → tag append to `set_history` with `_current_workout_id` + `logged_at`
3. Secondary guard via **monotonicity**: reject any signal whose `completed_at` (workout_completed) `< _last_signal_received_at` — log `wst.out_of_order_signal(signal, ts, last)` [→ EC]
4. On `workout_completed(completed_at)` → assert `completed_at > started_at`; else log + emergency-IDLE [→ EC]

**Q-X2 (Open Question)**: should #2 GDD next-revision add `workout_id: String` to `workout_started()` payload for cross-device bfcache survival? If yes, #9 Rule 11.1 client-derived fallback becomes pre-deprecated — switch to server-assigned ID.

---

#### Rule 12 — Bfcache Resume Composite

跟 Rule 3 + 7 + 8 + 9 compose 成完整 bfcache survival contract。

**Resume sequence** (autoload `_ready()` after restore)：
1. Substate = INITIALISING
2. Read `wst.current_workout.*` via #3 PersistenceLayer
3. Check `is_expired(started_at, ttl_hours * 3600)` per ADR-006 Contract 9 — if expired → discard snapshot + reset to IDLE
4. Reconstruct phase + set_history + estimator state
5. Recompute `_cached_dominant_class` from set_history (Rule 5)
6. Recompute `_cached_set_progress` from estimator state (Rule 4)
7. Subscribe to #2 signals via `connect_for_initial_state(callable)` (ADR-006 Contract 6)
8. Subscribe to #1 GSM `state_changed` for Suspended detection
9. Substate → READY
10. Emit `bfcache_resumed(was_mid_workout: bool, restored_phase: WorkoutPhase)` debug signal for #28 telemetry

**Resume-time backfill**：#2 GymSysClient own `_ready()` will backfill any missed events since last poll cursor — backfilled signals arrive after #9 READY → process normally [→ EC: backfill arrives during INITIALISING → drop per Rule 8 + #2 will retry; OR queue if Rule 8 deferred policy changed in future revision].

---

#### Rule 13 — `_derive_stat_id_from_class` (Class → Stat Routing)

Internal helper for Rule 6 Stat invocation：

| AbilityClass | StatId | Cross-ref |
|--------------|--------|-----------|
| STRIKE  (PUSH muscles) | `STR` | #11 GDD Formula 4 attack_power_derived |
| CONTROL (PULL muscles) | `DEX` | #11 GDD Formula 4 attack_power_derived (DEX minor) + Formula 5 move_speed_derived |
| MOBILITY (LEG muscles) | `VIT` | #11 GDD Formula 3 max_hp_derived |
| UNKNOWN | (skip apply_stat_delta entirely) | Rule 6 + Rule 5 |

呢條 routing 鎖死，#10 ExerciseClassMapping GDD authoring 須 honor 同樣 class → stat mapping (Rule 14 bidirectional sync flag)。

---

#### Rule 14 — CI Enforcement (Closed-API + Namespace Discipline)

**CI scripts** (跟 ADR-001 既有 pattern)：
- `tools/ci/check_workout_state_caller.gd` — grep external mutation:
  - Pattern: `WorkoutStateTracker\.(set_|_)` outside `src/core/workout_state_tracker.gd` → FAIL
  - Pattern: assignments to `WorkoutStateTracker.*` fields → FAIL
- `tools/ci/check_wst_namespace.gd` — grep `PersistenceLayer.write\(["']wst\.` outside `src/core/workout_state_tracker.gd` → FAIL (只有 #9 寫 `wst.*`)
- Whitelist: `WorkoutStateTracker.get_*()` 同 signal `connect` allowed anywhere；test files 用 `# ci:allow-wst-mutation` comment bypass

---

#### Rule 15 — Autoload Boot Position (Position-Independent Subscription)

**Recommended position**: **5** (after #3=1, #1=2, #2=3, #4 Audio=4)
**Fallback**: **4** if #4 Audio deferred past VS tier

**Per gameplay-programmer Q6**: subscription strategy MUST be position-independent — use `connect_for_initial_state(callable)` per ADR-006 Contract 6 → 即使 positions reshuffle，#9 self-heals。Position number is doc-comment hint, NOT contract.

Boot `_ready()` budget: ≤80ms per ADR-001 Foundation autoload budget (#9 = Core layer 不嚴格 binding，但 sequential boot 加成 < 500ms 總 budget per ADR-006 Contract 4).

---

#### Rule 16 — Anti-Fabrication Invariants (Negative Specification — 12 NEVERs)

跟 Section B「What It Wouldn't Be」對應 + CI 同 code review enforcement。

#9 **NEVER** does:

1. **NEVER fabricates a `set_logged` event** — only forwards #2 signals
2. **NEVER infers a workout has started from non-#2 source** (time-of-day heuristic, app focus event, etc.)
3. **NEVER guesses `dominant_class`** when set_history is empty → return UNKNOWN
4. **NEVER interpolates `set_progress`** based on elapsed time (per gameplay-programmer Q2 — Pillar 1 forbid)
5. **NEVER calls back into #2 GymSysClient** to mutate backend state (per #2 line 477)
6. **NEVER reads from #11 Stat System** — strictly one-way caller (Rule 6)
7. **NEVER generates its own transition_id** — always via #1 GSM helper (Rule 11)
8. **NEVER persists to namespaces other than `wst.*`** (Rule 14 CI lint)
9. **NEVER fabricates phase transitions during `poll_failed` window** (Rule 9 frozen)
10. **NEVER queues workout signals during Suspended** — drop + log (per gameplay-programmer Q1, Rule 8)
11. **NEVER allows `set_progress` to decrease within a single workout** (Rule 4 monotonicity)
12. **NEVER emits `workout_completed_forwarded` without preceding `workout_summary_available`** (Rule 10 ordering invariant)

---

### States and Transitions

**WorkoutPhase machine** (5 states + auto-transition) — see Rule 2 transition matrix

**Substate lifecycle** (3 states):

| Substate | Entry | Exit | Query API behavior |
|----------|-------|------|--------------------|
| INITIALISING | autoload `_ready()` | snapshot restored + signals subscribed | Returns enum defaults + `WARN: not ready` log |
| READY | post-INITIALISING OR resume from SUSPENDED | #1 GSM `state_changed → Suspended` | Live values |
| SUSPENDED | #1 GSM Suspended state | #1 GSM exits Suspended | Last cached values + `is_suspended=true` flag; incoming workout signals dropped (Rule 8) |

**Frozen flag** (orthogonal to substate, Rule 9):
- `_is_frozen` toggled by `poll_failed` / `poll_recovered`
- Can be true in any substate；no Substate change

---

### Interactions with Other Systems

| # | System | Direction | Interface | Owner | Notes |
|---|--------|-----------|-----------|-------|-------|
| #2 | GymSysClient | upstream subscriber | 7 typed signals (Rule 1 / 4 / 5 / 8 / 9 / 10) | #2 | locked payload — never redefine |
| #3 | PersistenceLayer | upstream caller (write + read) | `wst.*` namespace; IPersistence.read/write/is_expired | #3 | Rule 7 + 12 |
| #1 | GameStateMachine | upstream subscriber + caller | `state_changed` subscription via `connect_for_initial_state`; `acquire_transition_id()` (Rule 11) | #1 | ADR-006 Contracts 4/6/2 |
| #8 | Streak System | **NO direct interaction** — both subscribe `#2.workout_completed` independently | (no interface) | (split) | **CONFLICT RESOLVED**: systems-index says #9 → #8 dep but #8 declares no-public-mutator; both consume same source signal independently. Reframed in Section F |
| #10 | Exercise→Class Mapping | downstream caller | `IExerciseClassMapper.classify(exercise_id) -> AbilityClass` | #10 | VS-tier stub fallback (3-exercise inline); #10 implements interface when designed |
| #11 | Stat System | upstream caller (one-way) | `Stat.apply_stat_delta(stat_id, delta, VOLUME_TICK, source_key)` per set_logged (source_key = client-derived `workout_id_set_index` idempotency key; see Rule 6 note) | #11 | Rule 6 + 13 |
| #14 | EnemyDirector | downstream caller + subscriber | `get_dominant_ability_class()` 4Hz / `get_set_progress()` 4Hz / `workout_summary_available` / `workout_completed_forwarded` | #14 | locked downstream contract; FR-9-SetProgress |
| #15 | Loot Drop System (Not Started) | downstream subscriber | `workout_completed_forwarded` / `workout_summary_available` for transition_id seed | #15 | provisional |
| #18 | PR Detection (Not Started) | **subscribes #2.set_logged directly** — not via #9 | (no interface) | (split) | #18 owns PR derivation; #9 just forwards |
| #28 | Telemetry (Not Started) | downstream subscriber | all phase_changed / dominant_class_changed / poll_freeze events + `wst.history.*` snapshot reads | #28 | read-only consumer |

## Formulas

#9 owns 4 formulas — all derive in-game state from real `set_logged` event stream (Pillar 1 no fabrication). Two `historical_avg_*` EWMA formulas share identical shape (Formula 2 covers both).

---

### Formula 1 — `set_progress` derivation

呢個係 Workout State Tracker 嘅 centerpiece formula，畀 #14 EnemyDirector 用嚟做 boss anchor pre-spawn gating。**兩條 path**：full-data path（GymSys 將來開放 `planned_total_sets` + `planned_reps_in_current_set` 之後行得通）同 estimated path（fallback，當前 default）。

The `set_progress` formula is defined as:

**Full-data path** (preferred，需要 ADR-002-EXTENSION-GATED signal extension for `planned_total_sets` + per-rep `rep_logged` event)：

`set_progress_raw = clamp((current_set_index - 1 + reps_completed_in_set / planned_reps_in_current_set) / planned_total_sets, 0.0, 1.0)`

**Estimated path** (fallback，當前 default)：

`set_progress_raw = clamp((current_set_index - 1 + reps_completed_in_set / effective_planned_reps) / effective_planned_total, 0.0, 1.0)`

其中：
- `effective_planned_total = max(current_set_index + 1, historical_avg_sets)` — 確保 current set 永遠唔會超過 estimated total
- `effective_planned_reps = max(1, round(historical_avg_reps_per_set))` — guard against zero-division

**Bonus-set cap** (apply BEFORE monotonic clamp，當 `current_set_index > planned_total_sets` 或 `current_set_index > effective_planned_total`)：

`set_progress_raw = min(set_progress_raw, SET_PROGRESS_BONUS_SET_CLAMP)  # default 0.95 [→ Knob] — preserves buffer for true workout_completed`

**Monotonic clamp** (必須 apply，兩 path 都係)：

`set_progress = max(set_progress_raw, previous_set_progress)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current set index (1-based) | `current_set_index` | int | [1, ∞) | 已收到嘅 `set_logged` event 數 (含 current) |
| Reps in current set | `reps_completed_in_set` | int | [0, planned] | Last `rep_logged` count，未 log rep 時為 0 |
| Planned reps in current set | `planned_reps_in_current_set` | int | [1, ∞) | GymSys 提供（full-data path only） |
| Planned total sets | `planned_total_sets` | int | [1, ∞) | GymSys 提供（full-data path only） |
| Effective planned total (fallback) | `effective_planned_total` | int | [1, ∞) | `max(current_set_index + 1, historical_avg_sets)` |
| Effective planned reps (fallback) | `effective_planned_reps` | int | [1, ∞) | `max(1, round(historical_avg_reps_per_set))` |
| Historical EWMA sets/workout | `historical_avg_sets` | float | [1.0, ∞) | 由 Formula 2 維護，persisted at `wst.history.avg_sets` |
| Historical EWMA reps/set | `historical_avg_reps_per_set` | float | [1.0, ∞) | EWMA same α，persisted at `wst.history.avg_reps_per_set` |
| Previous set_progress value | `previous_set_progress` | float | [0.0, 1.0] | Last emitted value（in-memory state，workout reset 時歸零） |
| Raw computed progress | `set_progress_raw` | float | [0.0, 1.0] | Pre-monotonic-clamp 值 |
| Final emitted progress | `set_progress` | float | [0.0, 1.0] | Property exposed via `get_set_progress()` |

**Output Range:** 0.0 to 1.0（hard-clamped both ends）。Workout reset 時 `previous_set_progress` 歸 0.0。

**Implementation note — current signal contract vs full-data path:**
現有 7-signal contract 入面，`reps` 只喺 `set_logged(exercise_id, reps, weight)` payload 攜帶（即 set 完成時），**冇** per-rep `rep_logged` event。因此喺現有 signal contract 下：`reps_completed_in_set = 0` 喺 set 進行中（唔係 mid-set tracking），只喺 `set_logged` 觸發時等於 payload 嘅完成 reps count。Example A 下面展示嘅係 **future full-data path**（需要 ADR-002-EXTENSION-GATED `rep_logged` per-rep signal），唔係現行可實現行為。Estimated fallback path（Example B）係目前 default。

**Example A — full-data path** (requires ADR-002-EXTENSION-GATED `rep_logged` signal)：

Leg day session, planned 6 squat sets × 10 reps each. After set #5 logged, current rep count in set #5 reached 8:
- `current_set_index = 5`, `reps_completed_in_set = 8`, `planned_reps_in_current_set = 10`, `planned_total_sets = 6`
- `set_progress_raw = (5 - 1 + 8/10) / 6 = (4 + 0.8) / 6 = 4.8 / 6 = 0.800`
- 假設 `previous_set_progress = 0.733`（set #5 第 4 reps 時）
- `set_progress = max(0.800, 0.733) = 0.800`
- **正正撞中 #14 `pre_spawn_threshold = 0.8`** → triggers boss anchor pre-spawn [→ CI-1]

**Example B — estimated fallback path:**

Same session但 GymSys 冇提供 plan。User history：`historical_avg_sets = 5.2`, `historical_avg_reps_per_set = 9.4`。After set #5, reps = 8：
- `effective_planned_total = max(5 + 1, 5.2) = 6`（int cast via max with `current_set_index + 1`）
- `effective_planned_reps = max(1, round(9.4)) = 9`
- `set_progress_raw = (5 - 1 + 8/9) / 6 = (4 + 0.889) / 6 = 4.889 / 6 = 0.815`
- `set_progress = max(0.815, previous) = 0.815`
- 同樣會 trigger boss pre-spawn — fallback path 嘅準確性夠用

**Notes:**
- **Edge: division-by-zero** — `planned_reps_in_current_set = 0` 理論上唔應該由 GymSys 嚟，但 fallback 一定 `max(1, ...)` 保底。Full-data path 收到 0 時 fall back 去 estimated path 並 log warning。
- **Edge: `current_set_index > planned_total_sets`** — user 做多過 plan (bonus set)。Full-data path 嘅 numerator 會 > denominator，靠 outer `clamp(_, 0.0, 1.0)` 封頂去 1.0。Estimated path 由 `max(current_set_index + 1, historical_avg_sets)` 自動升 denominator，所以結果通常 < 1.0 直到 workout completed。
- **Pillar 1 compliance**: 冇 time-based extrapolation、冇 interpolation。所有 input 都來自實際 `set_logged` / `rep_logged` events。

---

### Formula 2 — `historical_avg_sets_per_workout` EWMA update (+ parallel `avg_reps_per_set`)

Workout completed 時更新 user 嘅「typical sets per workout」估值，畀 Formula 1 fallback path 用。

The `historical_avg_sets` formula is defined as:

`new_avg = alpha × sets_in_completed_workout + (1 - alpha) × old_avg`

**Initial-value rule (first workout)**: if `old_avg == null` then `new_avg = sets_in_completed_workout`（即係跳過 EWMA blending，直接 store raw 值，避免 cold-start bias）。

**Parallel formula** `historical_avg_reps_per_set` 用相同 EWMA shape：

`new_avg_reps = alpha × avg_reps_in_completed_workout + (1 - alpha) × old_avg_reps`

其中 `avg_reps_in_completed_workout = total_reps / current_set_index`。

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| EWMA smoothing factor | `alpha` | float | [0.1, 0.5] | `HISTORICAL_EWMA_ALPHA = 0.3` default [→ Knob] |
| Sets in just-completed workout | `sets_in_completed_workout` | int | [1, ∞) | `current_set_index` value at `workout_completed` |
| Previous EWMA value | `old_avg` | float \| null | [1.0, ∞) ∪ null | `wst.history.avg_sets` 之前值；first workout 為 null |
| Updated EWMA value | `new_avg` | float | [1.0, ∞) | 寫返入 `wst.history.avg_sets` |

**Output Range:** [1.0, ∞)（unbounded upper；practical ceiling 約 20–30 sets per workout）。

**Example:**
- Prior `old_avg = 6.0`, just-completed workout had 4 sets, `alpha = 0.3`:
- `new_avg = 0.3 × 4 + 0.7 × 6.0 = 1.2 + 4.2 = 5.4`
- 寫返 `wst.history.avg_sets = 5.4`。下次 fallback path 會用呢個值做 baseline。

**Notes:**
- α = 0.3 嘅 rationale: 半衰期 ≈ 2 workouts — 對近期 workout style change 敏感（e.g. user 由 strength 轉去 hypertrophy）但 single outlier 唔會 dominate。Safe range [0.1, 0.5]：低過 0.1 反應太慢、高過 0.5 易俾單次異常 workout 拉歪。

---

### Formula 3 — `dominant_class` derivation (formalize Rule 5 pseudocode)

Pillar 4 substrate — set-count weighted with sticky-last-leader tiebreak。

The `dominant_class` formula is defined as:

`set_counts[c] = |{s ∈ set_history : exercise_class_map[s.exercise_id] == c}|`

`leaders = {c ∈ AbilityClass : set_counts[c] == max(set_counts.values()) ∧ set_counts[c] > 0}`

`dominant_class = resolve(leaders, set_history, previous_dominant_class)`

其中 `resolve()` 嘅 decision tree：
1. If `set_counts` empty 或 all-zero → return `&"UNKNOWN"`
2. If `|leaders| == 1` → return `leaders[0]`，更新 `previous_dominant_class`
3. If `|leaders| > 1`（tie）→ walk `set_history` reverse-chronologically，搵 last index `i` where exactly one leader class appeared 喺 `set_history[0..i]` 入面係 strict max → return that class
4. If tiebreak walk 都搵唔到 solo leader → return `previous_dominant_class`（sticky）。如果 `previous_dominant_class` 仍然 null → return `&"UNKNOWN"`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Set history this workout | `set_history` | Array[Dictionary] | [0, ∞) entries | Each: `{exercise_id, reps, weight, logged_at}` |
| Exercise-to-class map | `exercise_class_map` | Dictionary[StringName, AbilityClass] | static | #10 ExerciseClassMapping curated；UNKNOWN exercise_id 唔會出現喺 key set |
| Per-class tally | `set_counts` | Dictionary[AbilityClass, int] | values [0, ∞) | Excludes UNKNOWN-mapped sets |
| Leader set | `leaders` | Array[AbilityClass] | size [0, 3] | Classes tied for max set_counts |
| Sticky previous value | `previous_dominant_class` | AbilityClass \| null | enum ∪ null | In-memory，workout reset 時清 null |
| Output ability class | `dominant_class` | AbilityClass | {STRIKE, CONTROL, MOBILITY, UNKNOWN} | Returned by `get_dominant_ability_class()` |

**Output Range:** `AbilityClass` enum 4 個值之一。**注意**：`&"UNKNOWN"` 係 #9 嘅 honest「no signal」表態 — **NOT** auto-default 去 `STRIKE`（嗰個係 #14 EnemyDirector 嘅 fallback policy，唔關 WST 事）[→ CI-3]。

**Example:**

Set history (chronological order)：
1. PUSH (squat → STRIKE)
2. PULL (row → CONTROL)
3. PUSH (bench → STRIKE)
4. LEG (lunge → MOBILITY)
5. PULL (deadlift → CONTROL)
6. PUSH (press → STRIKE)
7. PULL (curl → CONTROL)
8. LEG (calf → MOBILITY)

- `set_counts = {STRIKE: 3, CONTROL: 3, MOBILITY: 2}`
- `leaders = [STRIKE, CONTROL]`（tie at 3）
- Tiebreak walk（reverse 由 i=8 行落 i=1）：
  - i=8: counts = {S:3, C:3, M:2} → tie，continue
  - i=7: counts = {S:3, C:3, M:1} → tie，continue
  - i=6: counts = {S:3, C:2, M:1} → **STRIKE solo leader**，stop
- Return `STRIKE`，更新 `previous_dominant_class = STRIKE`

**Notes:**
- **Sticky 行為 rationale**: 避免 Pillar 4 ability 喺 workout 中段反覆 flicker（player 會覺得無 logic）。Tie 時 stick to last known leader → 提供 narrative continuity。
- **Edge: pure tie from scratch** — workout 第一個 set logged 之後即刻有兩個 class 同分（impossible，因為一個 set 只 increment 一個 class），所以 first-set scenario 永遠 unambiguous。Tie 只可能喺 ≥ 2 sets 之後出現。

---

### Formula 4 — `total_volume` aggregation

The `total_volume` formula is defined as:

`total_volume = Σ (s.reps × s.weight) for s in set_history`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Set history this workout | `set_history` | Array[Dictionary] | [0, ∞) entries | 同 Formula 3 input |
| Per-set reps | `s.reps` | int | [0, ∞) | From `set_logged` event payload |
| Per-set weight (kg) | `s.weight` | float | [0.0, ∞) | From `set_logged` event payload；bodyweight set = 0.0 |
| Aggregate volume (kg-reps) | `total_volume` | float | [0.0, ~50000) typical | `WorkoutSummaryRO.total_volume` 嘅值 |

**Output Range:** [0.0, theoretical_max]，hard cap 只有 float64 precision。Typical session 5,000–30,000 kg-reps；power-lifting heavy session 可以去到 40,000+。Bodyweight-only session 會係 0.0（valid）。

**Example:**
- 5 sets squat × 100 kg × 5 reps each = 5 × 100 × 5 = 2,500 kg-reps
- 3 sets deadlift × 120 kg × 5 reps each = 3 × 120 × 5 = 1,800 kg-reps
- `total_volume = 2,500 + 1,800 = 4,300 kg-reps`

**Notes:**
- **Bodyweight handling**: `weight = 0.0` makes contribution 0 — by design。如果 future 要 normalize bodyweight exercise，會係 #11 GymSys 嗰邊嘅 enrichment、唔關 WST 事（Pillar 1：唔 fabricate data）。
- **Unit convention**: kg-reps（純 multiplicative product，無 unit conversion）。Telemetry 同 ADR-005 都 consume 同一 unit。

---

### Cross-Formula Invariants (CF) + Cross-System Invariants (CI)

| ID | Type | Invariant | Enforcement |
|----|------|-----------|-------------|
| **CF-1** | within-formula | `set_progress` MUST be monotonic non-decreasing within a single workout (Rule 4 + Formula 1 outer clamp) | Section H AC + unit test |
| **CF-2** | cross-formula | `WorkoutSummaryRO.final_set_progress = set_progress` at `workout_completed` event (Rule 10 binding) | Section H AC |
| **CF-3** | execution-order | Formula 2 必須喺 `workout_completed` handler 入面、`WorkoutSummaryRO` 封口之後、workout state reset 之前執行 (避免讀到 reset 後嘅 0) | Section H AC |
| **CF-4** | within-formula | `set_history` MUST be append-only within workout duration (保證 Formula 3 tiebreak walk deterministic) | Closed-API Rule 14 CI lint |
| **CF-5** | execution-order | `WorkoutSummaryRO.total_volume` (Formula 4) frozen at `workout_completed` — post-workout late `set_logged` events do NOT mutate sealed summary | Section H AC |
| **CI-1** | cross-system | `set_progress >= 0.8` 觸發 #14 boss anchor pre-spawn (owned by #14, registry-locked `pre_spawn_threshold = 0.8`) | #14 Rule 13 binding |
| **CI-2** | cross-system | 當 `set_progress` signal 唔 available (initialization 或 history empty) 時，#14 fallback 去 `pre_spawn_fallback_reps_frac = 0.5` heuristic (registry-locked) | #14 Rule 13 fallback path |
| **CI-3** | cross-system | WST 返 `&"UNKNOWN"` 時，#14 EnemyDirector 應用自己嘅 fallback policy (typically `STRIKE`)；WST 自己唔做 fallback、唔 fabricate signal (Pillar 1) | #14 EC-09 |
| **CI-4** | cross-system | `total_volume` indirectly feeds ADR-005 嘅 `volume_factor` — 由 #15 LootDrop 透過 `WorkoutSummaryRO` 讀取，再 normalize 入 `workout_score`。WST 自己唔做 normalization | #15 GDD (Not Started — provisional contract) |
| **CI-5** | cross-system | ADR-005 嘅 `exercise_target_count = 5` 應用喺 `get_completed_exercises_count()` (distinct `exercise_id` count，**唔係** set count)，由 #15 計算 `volume_factor = min(1.0, completed_exercises_count / 5)` | #15 GDD (Not Started — provisional contract) |

## Edge Cases

呢個 section 列出 #9 Workout State Tracker 嘅 37 個 edge cases，按 9 個 category 分類。每個 EC 標明 severity + 對應 Rule/Formula/CF/CI。

> **Cross-system overlap note**: EC 牽涉 UNKNOWN class downstream behavior (boss anchor / enemy spawn fallback) 已經喺 #14 EnemyDirector EC-09/14/15/16/19 covered — #9 嘅 ECs 只負責 source-of-truth derivation，唔重複 downstream consumption logic。

---

### Category 1 — Phase Machine Invariants (Rule 2)

**EC-01 [Phase | CRITICAL]**: 如果 `workout_completed` 喺 `IDLE` phase 到達，**則** drop event + log `WST_INV_VIOL_001` (level=ERROR, payload=signal_name+current_phase+transition_id)，**phase 保持 IDLE**，**唔 emit `workout_completed_forwarded`**。Pillar 1 anti-fabrication — 冇 `workout_started` 就唔可以有 completion。(Rule 2 transition matrix ✗ + Rule 16 NEVER #3)

**EC-02 [Phase | CRITICAL]**: 如果 `set_logged` 喺 `IDLE` phase 到達（冇 preceding `workout_started`），**則** drop event + log `WST_INV_VIOL_002`，**phase 保持 IDLE**，set 唔入 `set_history`。GymSys 理論上唔會送呢個 sequence，但 anti-fabrication 強制 drop。(Rule 2 + Rule 16 NEVER #1)

**EC-03 [Phase | HIGH]**: 如果 `rest_started` 喺 `WARM_UP` 到達（即第一個 set 都未 log），**則** drop event + log `WST_INV_VIOL_003` (level=WARN)，**phase 保持 WARM_UP**。GymSys client UX bug 嘅可能，唔應該因為呢個推進 phase。(Rule 2)

**EC-04 [Phase | HIGH]**: 如果 `rest_ended` 到達但 current phase 唔係 `REST_PERIOD`（例如 `SET_ACTIVE`），**則** drop event + log `WST_INV_VIOL_004`。Idempotent — 唔影響 phase。(Rule 2)

**EC-05 [Phase | MEDIUM]**: 如果同一個 `transition_id` 嘅 signal 重複到達（GSM tombstone race），**則** 第二次 drop + log `WST_DUP_TXN_001` (level=INFO)，**保留首次 emission 結果**。ADR-006 tombstone forward-recovery 處理。(Rule 11)

**EC-06 [Phase | MEDIUM]**: 如果 `workout_started` 喺 `SET_ACTIVE` / `REST_PERIOD` 到達（即上一場 workout 冇收到 `workout_completed`），**則** 強制 emit `phase_changed(WORKOUT_COMPLETE)` → flush current state → 即時 transition 到新 workout 嘅 `WARM_UP`，log `WST_FORCED_FLUSH_001` (level=WARN)，舊 workout 標記 `was_force_flushed=true` 入 telemetry。(Rule 2 + Rule 11.1)

---

### Category 2 — Substate Lifecycle (Rule 3)

**EC-07 [Substate | HIGH]**: 如果 `INITIALISING._ready()` 超出 80ms budget（例如 PersistenceLayer cold-read 慢），**則** 繼續 INITIALISING（**唔 timeout 進 READY**），log `WST_BOOT_SLOW_001` (level=WARN, payload=elapsed_ms)，#11 Stat queue 繼續 buffer signals（cap 100）。Pillar 2 不可省略 boot validation。(Rule 3 + ADR-006 Contract 4)

**EC-08 [Substate | CRITICAL]**: 如果 `SUSPENDED` entry 喺 `WORKOUT_COMPLETE` tick 之內（即 `workout_completed_forwarded` 已 emit 但 #11 stat apply 仲未完成），**則** **延遲 SUSPENDED 進入直到當前 frame 嘅 `call_deferred` queue 清空**，期間 incoming signals buffer。保證 loot pipeline 唔斷。(Rule 8 + Rule 10)

**EC-09 [Substate | MEDIUM]**: 如果 `READY → SUSPENDED → READY` 喺 500ms 內快速循環（bfcache flap），**則** 第二次 READY 重 hydrate 但 **skip persistence re-write**（debounce 1000ms 仍然 active），log `WST_SUBSTATE_FLAP_001` (level=INFO, payload=cycle_count_in_5s)。(Rule 3 + Rule 7 debounce)

**EC-10 [Substate | MEDIUM]**: 如果 SUSPENDED 期間 `is_expired()` 變 true（超過 ADR-003 24h window），**則** unsuspend 時唔 hydrate stale snapshot，**phase 重設 IDLE**，emit `workout_state_discarded(reason="ttl_expired")`，log `WST_TTL_DISCARD_001`。(Rule 3 + ADR-006 Contract 9)

---

### Category 3 — Suspended Drop + Frozen Orthogonality (Rule 8/9)

**EC-11 [Suspended | CRITICAL]**: 如果 `workout_completed` 喺 `SUSPENDED` 期間到達，**則** drop event（**唔 queue**）+ log `WST_SUSPENDED_DROP_COMPLETE_001` (level=WARN)。**Player 唔失 loot**：unsuspend 時 #2 GymSysClient 會 re-poll 並重 emit（ADR-002 idempotent polling）。Pillar 3「玩家永遠唔輸於 system」靠 #2 redundant emission 保證，唔靠 #9 buffer。(Rule 8)

**EC-12 [Frozen | HIGH]**: 如果 `poll_failed` 到達後即刻 SUSPENDED entry（tab 切走），**則** 兩個 flag 共存：`is_frozen=true` + `substate=SUSPENDED`。Unsuspend 後 **frozen 仍然 true**，要等 `poll_recovered` 先 unfreeze。Frozen 同 Suspended orthogonal — Rule 9 明確要求。(Rule 9)

**EC-13 [Frozen | MEDIUM]**: 如果 `poll_recovered` 到達時 phase 係 `IDLE` 且 `is_frozen=false`（即冇 preceding `poll_failed`），**則** drop event + log `WST_SPURIOUS_RECOVER_001` (level=INFO)，唔 emit `frozen_changed`。(Rule 9)

**EC-14 [Frozen | HIGH]**: 如果 frozen 持續超過 30s，**則** emit `wst.frozen_extended(duration_s)` 信號（供 #14 EnemyDirector freeze enemy spawn — 已 covered 喺 EnemyDirector EC-15），#9 本身 **唔自動 unfreeze**。Frozen 只由 `poll_recovered` 解除。(Rule 9 + 與 #14 overlap, 唔重複 enemy behavior)

---

### Category 4 — set_progress Formula Edges (Formula 1)

**EC-15 [Formula | HIGH]**: 如果 GymSys 送 `planned_reps = 0`（schema drift / drafted workout），**則** set_progress 退入 estimator path（用 `historical_avg_sets`），log `WST_PLANNED_ZERO_001` (level=WARN)。如果 historical 都 null，**set_progress 鎖 0.5**（neutral）— 避免 #14 prematurely pre-spawn。(Formula 1 + Formula 2 cold start)

**EC-16 [Formula | MEDIUM]**: 如果 `current_set_index > planned_total_sets`（bonus set），**則** set_progress **clamp 0.95**（唔 1.0，保留 buffer 俾真正 workout_completed），log `WST_BONUS_SET_001` (level=INFO)。Monotonicity 維持（0.95 ≥ prev value）。(Formula 1 + Rule 4)

**EC-17 [Formula | CRITICAL]**: 如果 estimator mid-workout 修正令 set_progress 應該下降（例如 historical_avg 重新計算），**則** **抑制 downward revision**，保持 prev value 直到下一個 `set_logged` push 上去。Rule 4 monotonicity invariant — 違反會令 #14 enemy spawn 退場。(Rule 4 + Formula 1 + CF-1)

**EC-18 [Formula | LOW]**: 如果 set_progress 計算結果係 NaN / Inf（divide-by-zero 防線穿透），**則** 鎖 0.0 + emit `WST_NAN_GUARD_001` (level=ERROR, payload=numerator+denominator)。Defensive — 理論上 EC-15 已堵截。(Formula 1)

---

### Category 5 — dominant_class Edges (Formula 3 + Rule 5)

**EC-19 [Class | MEDIUM]**: 如果 workout 內所有 `set_logged.exercise_class` 都係 `UNKNOWN`（GymSys schema drift / new exercise 未 tag），**則** `dominant_class = UNKNOWN`，downstream #11 唔 apply stat delta（routing table miss）。Telemetry log `WST_ALL_UNKNOWN_001` (level=WARN, payload=workout_id+set_count)。Downstream enemy behavior 由 #14 EC-09 處理。(Rule 5 + Rule 13)

**EC-20 [Class | HIGH]**: 如果首 3 個 set 三 class 各佔一個（STRIKE=1, CONTROL=1, MOBILITY=1 三 way tie），**則** 走 Formula 3 tiebreak walk：reverse-chronologically 搵 last index where one class is solo leader — 由於第一個 set 永遠係單一 class，walk 必定喺 i=1 找到 solo leader，返回第一個 set 嘅 class。「`previous_dominant_class = null`（第一次 workout）」唔影響呢個邏輯，tiebreak walk 會自然成功。**Rule 5 case 4（UNKNOWN）理論上唔可達**（第一個 set 永遠打破 tie），唔需要 alphabetical fallback。若因 bug 確實到達 case 4 → 跟從 Rule 5/Formula 3 返 `&"UNKNOWN"`（唔係 STRIKE），per AC-18。Pillar 1 determinism 由 tiebreak algorithm 本身保證。(Rule 5 + Formula 3)

**EC-21 [Class | MEDIUM]**: 如果 mid-workout dominant class 由 STRIKE 切去 CONTROL（leader change），**則** emit `dominant_class_changed(old, new)` 但 **30s cooldown** 內唔再 emit（防止 #14 enemy 重組 thrash）。30s 內如果再變返 STRIKE，suppress emission。(Formula 3 cooldown)

**EC-22 [Class | LOW]**: 如果 `workout_completed` 後新 `workout_started`，**則** `previous_dominant_class` **保留**（cross-workout sticky 用於 EC-20 tiebreak），但 current workout 嘅 `set_class_counts` map 清零。(Rule 5)

---

### Category 6 — Persistence Edges (Rule 7)

**EC-23 [Persist | HIGH]**: 如果 `wst.current_workout.set_history` snapshot 超過 256 KB（極長 workout，例如 100+ sets），**則** **truncate 至最近 50 sets** 寫入，log `WST_SNAPSHOT_TRUNC_001` (level=WARN, payload=original_count+kept_count)。Aggregate stats（total_volume 等）已經 derived，唔失 progression。(Rule 7)

**EC-24 [Persist | CRITICAL]**: 如果 PersistenceLayer.write 失敗（IndexedDB quota exhausted / Private Mode），**則** **唔 retry inline**，emit `wst.persist_failed(key, reason)`，downstream UI banner（ADR-003 gating），#9 in-memory state **繼續正常運作**直到 unload。(Rule 7 + ADR-003)

**EC-25 [Persist | MEDIUM]**: 如果 `migrate()` called 但冇 prior snapshot（首次 install），**則** initialise empty state，**唔 log 為 error**（log INFO `WST_MIGRATE_COLDSTART_001`）。(Rule 7)

**EC-26 [Persist | HIGH]**: 如果 `is_expired()` 返 true 喺 TTL 邊界（exactly 24h），**則** 用 strict greater-than（`elapsed > 86400s`，唔係 ≥）— 邊界當 valid，避免時鐘 jitter 誤判。Snapshot discard 路徑同 EC-10。(ADR-006 Contract 9 + Rule 7)

**EC-27 [Persist | MEDIUM]**: 如果 debounce window（500ms）內收到 5+ `set_logged`，**則** 只寫一次 snapshot（trailing edge），唔係 5 次。如果 debounce timer 期間 `workout_completed` 到達，**強制 flush write**（bypass debounce），保證 completion state 落地。(Rule 7)

---

### Category 7 — Cross-system Race Conditions

**EC-28 [Race | HIGH]**: 如果 #14 EnemyDirector 喺 4Hz tick 中 call `get_dominant_ability_class()`，而 `_on_set_logged` 正在 `call_deferred` 更新 cache，**則** getter 返 **上一個 stable snapshot**（double-buffered read），唔返 mid-update state。Godot main-thread guarantee + double-buffer pattern。(Rule 5 + gameplay-programmer Q3)

**EC-29 [Race | CRITICAL]**: 如果 #11 Stat 喺 #9 boot 後仍 INITIALISING，#9 queue `apply_stat_delta` 已達 cap 100，**則** **drop oldest entry**（FIFO），log `WST_QUEUE_OVERFLOW_001` (level=ERROR, payload=dropped_count)，emit `wst.queue_overflow` 信號。Pillar 3 風險 — 但 cap 100 = 100 個 completed workouts 未 drain，呢個係 #11 boot 問題唔係 #9 問題。(Rule 6)

**EC-30 [Race | MEDIUM]**: 如果同一個 `transition_id` 喺兩個 signals 上出現（GSM helper bug），**則** 第二個 signal 用 tombstone 認出並 drop，log `WST_TXN_COLLIDE_001` (level=ERROR)。ADR-006 forward-recovery — 唔 throw，唔 corrupt state。(Rule 11 + ADR-006)

---

### Category 8 — Signal Delivery Edges (Rule 8/11.1)

**EC-31 [Signal | HIGH]**: 如果 `workout_completed.completed_at < workout_started_at`（clock skew / NTP correction mid-session），**則** **唔 reject completion**，但 `duration_s` clamp 至 60s minimum + log `WST_CLOCK_SKEW_001` (level=WARN, payload=skew_s)。Pillar 3 — 唔因為 clock 食 loot。(Rule 10)

**EC-32 [Signal | CRITICAL]**: 如果 `set_logged` 喺 `workout_completed` 之後 0-3s 內到達（late polling backfill），**則** **drop event**（phase 已 WORKOUT_COMPLETE）+ log `WST_LATE_SET_001` (level=WARN, payload=delay_ms)。Workout summary 已 forward，#11 stat 已 apply，不能 retroactively 改動 — Rule 16 NEVER #5。(Rule 2 + Rule 10)

**EC-33 [Signal | MEDIUM]**: 如果 duplicate `workout_started`（rapid retry，相同 client-derived workout_id），**則** 第二個 drop（transition_id 已 seen），phase 保持。如果 workout_id 不同（真係新 workout），按 EC-06 force-flush。(Rule 11.1)

**EC-34 [Signal | LOW]**: 如果 `poll_recovered` 到達但 `is_frozen=false`，**則** drop + INFO log（同 EC-13）。Idempotent。(Rule 9)

---

### Category 9 — Bfcache / Web Export Edges (ADR-003 + Rule 12)

**EC-35 [Bfcache | HIGH]**: 如果 tab freeze 30s+ 喺 `REST_PERIOD` 中間，**則** resume 後 #2 GymSysClient 補 poll，如果 GymSys backend 顯示 workout 仍 active，#9 hydrate snapshot + phase 保持 REST_PERIOD；如果 GymSys backend poll response 顯示 `workout.status ≠ "active"`（即 backend 已 complete / expire 該 workout）且自 `workout_started` 後冇收到 `workout_completed` signal，**#9 synthesise client-side `workout_completed`**（與 EC-06 同 path）+ log `WST_BFCACHE_SYNTH_COMPLETE_001`。**必要條件**：synthesis trigger 只能係 #2 polling 返回嘅 backend status，唔係 elapsed time heuristic（時間推算屬 fabrication，違反 Rule 16 NEVER #1 精神）。(Rule 12 + ADR-003)

**EC-36 [Bfcache | CRITICAL]**: 如果 bfcache resume 後發現 snapshot 嘅 `workout_id` ≠ GymSys 當前 active workout_id（user 喺另一部 device 開咗新 workout），**則** **discard local snapshot**，phase 重設 IDLE，emit `workout_state_discarded(reason="device_handoff")`，log `WST_DEVICE_HANDOFF_001` (level=WARN)。Q-X2 已解決：client-derived workout_id 唯一識別 session。(Rule 11.1 + Rule 12)

**EC-37 [Bfcache | MEDIUM]**: 如果 bfcache resume 喺 `INITIALISING` substate（signals 仲未 subscribed），**則** **等 INITIALISING → READY 之後**再 hydrate snapshot，期間 incoming signals 入 #2 buffer（唔係 #9 buffer）。Boot order critical — Pillar 2。(Rule 3 + Rule 15 + ADR-006 Contract 4)

---

**Severity 統計**: CRITICAL ×9, HIGH ×13, MEDIUM ×11, LOW ×4 = 37 ECs。所有 ECs 對應至少一條 Rule / Formula / ADR contract，符合 Pillar 1 anti-fabrication + Pillar 3 player-never-loses-to-system。

## Dependencies

### Upstream Dependencies (3 — all Approved)

| # | System | Type | Interface | Critical Path |
|---|--------|------|-----------|---------------|
| #2 | GymSys Backend Client | Hard subscription | 7 typed signals (workout_started / set_logged / rest_started / rest_ended / workout_completed / poll_failed / poll_recovered) — locked payload schema | Read-only consumer per #2 GDD line 477; #9 NEVER calls back to #2 |
| #3 | PersistenceLayer | Hard caller (read + write) | `IPersistence.read/write/is_expired`; `wst.*` namespace (Rule 12 first adopter) | Snapshot bfcache survival; ADR-003 input scope |
| #1 | GameStateMachine | Hard subscription + caller | `state_changed` subscription via `connect_for_initial_state` (ADR-006 Contract 6); `acquire_transition_id()` (Rule 11) | Suspended detection; transition_id provenance |

### "Implicit" / Non-Dependency Resolved Clarifications

| Mistaken claim | Reality | Resolution |
|---------------|---------|------------|
| systems-index lists #9 → #8 Streak dep | #8 Streak GDD line 145 directly subscribes `GymSysBackendClient.workout_completed`; #8 declares NO public mutator method | **#9 and #8 are SIBLING consumers of `#2.workout_completed`** — neither calls the other. systems-index dep arrow should be removed in next-revision batch |
| Session state handoff claim "#9 calls Streak.record_today_workout()" | No such public API exists on #8 | Same — session handoff was incorrect |

### Soft Upstream / Provisional (NOT YET DESIGNED)

| # | System | Type | Interface needed | Fallback |
|---|--------|------|------------------|----------|
| #10 | Exercise → Class Mapping (Pre-MVP) | Soft caller | `IExerciseClassMapper.classify(exercise_id) -> AbilityClass` | VS-tier inline stub: bench_press→STRIKE, row→CONTROL, squat→MOBILITY; replaced by #10 when designed |
| #4 | Audio Manager (MVP) | None — boot order only | (none) | If #4 deferred past VS, #9 boot position 5 → 4 |

> **EG-1 resolution (2026-06-03 — Option B, user-ratified)**: #4 audio-manager.md once carried a forward contract assigning "workout SFX forwarding during LOCKED" (buffer mid/high SFX until `audio_unlocked`, then flush) to a "#9 WST forwarding layer". That conflicts with #9's locked **pure data/event layer** architecture (Rule 16; Section "audio binding to #9 = architectural smell"). **#9 is NOT patched and NEVER calls `play_sfx` / subscribes `audio_unlocked` / buffers SFX.** #9 only forwards workout events (`workout_completed_forwarded` / `workout_summary_available`); per-set SFX triggers come from consumers subscribing `#2.set_logged` directly (the #18 PR Detection precedent — Interactions row #18). The audio SFX forwarding/buffering + `set_complete`×`streak_chime` same-frame stagger now belong to a **presentation-layer audio-trigger consumer (#20 Gym-Mode HUD, EG-2 scope, or a dedicated workout-feedback adapter)**. #4 audio-manager.md Dependencies forward contract amended accordingly. #9 stays a pure data layer.

### Downstream Consumers (5 — all but #14 Not Started)

| # | System | Type | Reads from #9 | Status |
|---|--------|------|---------------|--------|
| #14 | EnemyDirector (Approved) | Subscriber + 4Hz reader | `get_dominant_ability_class()` (Rule 12 wave archetype), `get_set_progress()` (Rule 13 boss pre-spawn — FR-9-SetProgress), `workout_summary_available` (boss commit data), `workout_completed_forwarded` (commit trigger) | **Approved 2026-05-27** — locked contract |
| #15 | Loot Drop System (Not Started, Pre-MVP) | Subscriber | `workout_completed_forwarded(completed_at, transition_id)` (必爆 daily trigger), `workout_summary_available(summary)` (rarity score input via summary.total_volume + summary.completed_exercises_count → ADR-005) | Provisional contract — #15 GDD authoring will lock |
| #18 | PR Detection & Avatar Progression (Not Started, Pre-MVP) | **SIBLING consumer of #2** — NOT via #9 | (subscribes #2.set_logged directly per #2 GDD line 467) | #18 owns PR derivation independently |
| #28 | Telemetry / Analytics (Not Started, Pre-MVP) | Subscriber | All `phase_changed` + `dominant_class_changed` + `frozen_extended` events; `wst.history.*` read-only snapshot | Provisional |
| (planned) #20 | Gym-Mode HUD (Not Started, MVP) | Reader | `get_workout_snapshot()` for HUD display | Provisional |

### ADR Dependencies

| ADR | Status | What #9 inherits |
|-----|--------|-----------------|
| **ADR-002 GymSys Integration Protocol** | Proposed | 7 workout signal payload contract locked; polling 5s ± 0.5s cadence; `workout_completed.completed_at` unix timestamp source-of-truth |
| **ADR-003 Save State Strategy** | Proposed | `wst.*` namespace authority; IPersistence.read/write/is_expired/migrate API; 24h bfcache window via `is_expired()` |
| **ADR-005 Loot Rarity Formula** | **Accepted 2026-05-27** | `volume_factor = min(1.0, completed_exercises_count / EXERCISE_TARGET_COUNT=5)` — #9 provides `completed_exercises_count` input via `WorkoutSummaryRO` |
| **ADR-006 State Machine Contract** | Proposed | Contract 4 (autoload sequential boot — #9 position 5); Contract 6 (`connect_for_initial_state` subscription); Contract 9 (drift-tolerant `is_expired` for snapshot TTL); Contract 2 (`acquire_transition_id()` for workout_completed) |
| **ADR-001 Web Export Budget Caps** | Proposed | Core layer CPU budget — `get_dominant_ability_class()` O(1) cache read for #14 4Hz tick; `_ready()` ≤ 80ms boot budget |

### Bidirectional Sync Gap Flags (for next-revision batch)

| GDD | What needs reciprocal lock |
|-----|----------------------------|
| **systems-index** | Remove #9 → #8 dependency arrow (per Section F clarification above) |
| **#2 GymSysClient** | Optional next-revision: add `workout_id: String` to `workout_started()` payload to eliminate #9 Rule 11.1 client-derived fallback (Q-X2) |
| **#11 Stat System** | Confirm `apply_stat_delta(stat_id, delta, source, source_key: String)` accepts `source_key` param (per-set client-derived idempotency key per Rule 6 B-1 fix — NOT ADR-006 transition_id) + "buffer-while-not-ready" caller contract |
| **#14 EnemyDirector** | Re-verify FR-9-SetProgress (`set_progress` field exposure) post-#9 lock — currently flagged as PROVISIONAL in #14 AC-20 |
| **#3 PersistenceLayer** | Confirm `wst.*` as first registered new namespace per Rule 12 convention; update #3 GDD line 358 stub to point to #9 GDD as live reference |
| **systems-index** | Update #9 status: Not Started → Approved (Phase 5d) |

### Failure Mode Matrix

| Upstream failure | #9 behavior | Downstream impact |
|------------------|-------------|-------------------|
| #2 `poll_failed` | Set `_is_frozen=true`; freeze phase machine + cached values (Rule 9) | #14 receives stale `get_dominant_ability_class()` + stale `set_progress`; #14 OK per its EC-15 |
| #2 `poll_recovered` | `_is_frozen=false`; process backfilled events normally | #14 recomputes wave archetype on resume |
| #3 PersistenceLayer write fail | Emit `wst.persist_failed`; continue in-memory operation (EC-24) | UI banner via ADR-003 gating |
| #3 snapshot expired (24h+) | Discard snapshot, boot IDLE (EC-10) | #14 sees IDLE phase, wave archetype = UNKNOWN → fallback STRIKE per #14 EC-09 |
| #1 GSM Suspended | Substate → SUSPENDED, drop incoming workout signals (Rule 8 + EC-11) | #2 backfill on resume restores state |
| #11 Stat not READY | Queue `apply_stat_delta` calls cap 100 (Rule 6 + EC-29) | Stat updates batched on #11 ready |
| #10 ExerciseClassMapper unavailable | Fall back to inline 3-exercise stub | Unknown exercises → skip tally → potential UNKNOWN dominant_class |

## Tuning Knobs

### Owned by #9 (11 knobs)

| Knob | Default | Safe Range | Affects | Breaking behavior |
|------|---------|-----------|---------|-------------------|
| `WORKOUT_SNAPSHOT_TTL_HOURS` | 24 | [12, 72] | Rule 7 + EC-10/26 — bfcache resume validity window | < 12 → genuine multi-day workout splits lose state; > 72 → IDB quota pressure |
| `HISTORICAL_EWMA_ALPHA` | 0.3 | [0.1, 0.5] | Formula 2 — responsiveness to recent workout style change | < 0.1 → 半衰期過長，user 由 strength 轉 hypertrophy 後 set_progress estimator 跟唔上；> 0.5 → 單次異常 workout (e.g., 30-set blitz) 拉歪 baseline |
| `SNAPSHOT_DEBOUNCE_MS` | 500 | [100, 2000] | Rule 7 — persistence write amplification control | < 100 → write amplification + mobile Safari jank；> 2000 → tab close mid-rest 失 multi-set state |
| `PENDING_STAT_DELTAS_MAX` | 100 | [50, 500] | Rule 6 + EC-29 — #11 boot-delay buffer | < 50 → #11 slow boot drops events；> 500 → memory bloat unbounded |
| `SNAPSHOT_TRUNCATION_MAX_SETS` | 50 | [30, 200] | EC-23 — keep recent set_history when snapshot exceeds byte threshold | < 30 → typical leg-day workout (8 exercises × 4 sets = 32) loses history mid-workout；> 200 → truncation never triggers (degenerate) |
| `SNAPSHOT_BYTE_TRUNCATION_THRESHOLD` | 262144 (256 KB) | [131072, 1048576] (128 KB - 1 MB) | EC-23 — when to truncate | < 128 KB → premature truncation；> 1 MB → exceeds `MAX_STATE_FILE_BYTES` from #3 (1 MB) |
| `DOMINANT_CLASS_CHANGE_COOLDOWN_S` | 30 | [10, 120] | EC-21 — prevent #14 wave re-routing thrash | < 10 → #14 enemy spawn flicker per set；> 120 → mid-workout class switch (user 改練 leg) 唔反映 |
| `FROZEN_EXTENDED_THRESHOLD_S` | 30 | [10, 180] | EC-14 — emit `wst.frozen_extended` for #14 enemy spawn freeze | < 10 → spurious 5-10s poll failures 都觸發 #14 freeze；> 180 → 真係斷網嗰陣 #14 仲喺度生 enemies (Pillar 2 violation) |
| `SET_PROGRESS_NEUTRAL_FALLBACK` | 0.5 | [0.3, 0.7] | EC-15 — set_progress when historical estimator cold-start AND GymSys planned_reps=0 | < 0.3 → #14 boss pre-spawn 太遲，違反 Pillar 2 sub-500ms；> 0.7 → boss spawn 過早，violation of player anticipation |
| `SET_PROGRESS_BONUS_SET_CLAMP` | 0.95 | [0.9, 0.99] | EC-16 — clamp value when current_set_index > planned_total_sets | < 0.9 → bonus set 完全唔觸發 boss pre-spawn；> 0.99 → too close to 1.0 → #14 emergency-spawn 過早 |
| `CLOCK_SKEW_DURATION_MIN_S` | 60 | [30, 300] | EC-31 — clamp `duration_s` when completed_at < started_at | < 30 → 真實 < 1min workout (test-only) 被 clamp；> 300 → 真大 skew 都當 5min workout |

### Referenced Knobs (cross-system, NOT owned by #9 — registry-locked)

| Knob | Owner | Value | #9 uses for |
|------|-------|-------|-------------|
| `pre_spawn_threshold` | #14 EnemyDirector | 0.8 | #14 boss anchor trigger threshold reads `set_progress` (Formula 1 binding) |
| `pre_spawn_fallback_reps_frac` | #14 EnemyDirector | 0.5 | #14 fallback heuristic when `set_progress` unreliable (CI-2) |
| `exercise_target_count` | ADR-005 | 5 | `volume_factor` denominator — #9 provides `get_completed_exercises_count()` as numerator |
| `wall_clock_drift_tolerance_seconds` | #3 PersistenceLayer | 300 | `is_expired()` drift detection per ADR-006 Contract 9 |
| `max_state_file_bytes` | #3 PersistenceLayer | 1048576 (1 MB) | Upper bound for `SNAPSHOT_BYTE_TRUNCATION_THRESHOLD` |

### Cross-Knob Invariants (INV)

| INV | Constraint | Rationale |
|-----|------------|-----------|
| **INV-1** | `SNAPSHOT_DEBOUNCE_MS` ≤ `WORKOUT_SNAPSHOT_TTL_HOURS × 3600 × 1000` (always trivially true at default) | Sanity check |
| **INV-2** | `SET_PROGRESS_BONUS_SET_CLAMP` < 1.0 | Must preserve buffer for true `workout_completed` event |
| **INV-3** | `SET_PROGRESS_NEUTRAL_FALLBACK` < `pre_spawn_threshold` (0.8) | Neutral fallback shouldn't trigger boss pre-spawn before real progress |
| **INV-4** | `DOMINANT_CLASS_CHANGE_COOLDOWN_S` ≥ #14 perception_tick_interval × min_visible_frames (≈ 30s = 4Hz × 120 ticks) | Class change must persist long enough for #14 to visibly re-route |
| **INV-5** | `PENDING_STAT_DELTAS_MAX` ≥ typical max_sets_per_workout × max_concurrent_workouts (100 ≥ 50 × 2 = 100) | Buffer entire workout if #11 boot delayed |
| **INV-6** | `FROZEN_EXTENDED_THRESHOLD_S` ≥ ADR-002 polling cadence × 5 (≥ 25s) | Don't false-alarm on routine polling jitter |
| **INV-7** | `SNAPSHOT_BYTE_TRUNCATION_THRESHOLD` ≤ #3 `MAX_STATE_FILE_BYTES` (256 KB ≤ 1 MB ✓) | Cannot exceed PersistenceLayer hard limit |
| **INV-8** | `WORKOUT_SNAPSHOT_TTL_HOURS × 3600` ≥ typical max workout duration × 4 (24h ≥ 120min × 4 = 8h ✓) | TTL must comfortably exceed legitimate workout window |

### Knob Stability Classification (4-tier per #11 / #14 precedent)

- **LOCKED** (changing requires GDD revision + CI lint update): `exercise_target_count` (ADR-005), `pre_spawn_threshold` (#14)
- **DESIGN-FROZEN** (safe range narrow, requires #14/15/28 coordination): `DOMINANT_CLASS_CHANGE_COOLDOWN_S`, `SET_PROGRESS_NEUTRAL_FALLBACK`, `FROZEN_EXTENDED_THRESHOLD_S`
- **TUNABLE** (designer-adjustable within safe range, single-system): `WORKOUT_SNAPSHOT_TTL_HOURS`, `HISTORICAL_EWMA_ALPHA`, `SNAPSHOT_DEBOUNCE_MS`, `PENDING_STAT_DELTAS_MAX`, `CLOCK_SKEW_DURATION_MIN_S`
- **PROVISIONAL** (subject to playtest evidence or Q-X resolution): `SET_PROGRESS_BONUS_SET_CLAMP` (pending real-world bonus-set frequency data), `SNAPSHOT_TRUNCATION_MAX_SETS` (pending max-workout-length telemetry), `SNAPSHOT_BYTE_TRUNCATION_THRESHOLD` (pending IDB quota field data)

## Visual/Audio Requirements

**N/A — #9 has no direct visual or audio surface.**

#9 Workout State Tracker 係 Core-layer data aggregator — 唔 instantiate Node2D / Sprite / AudioStreamPlayer，唔 emit shake / particles / sound。所有 player-perceptible effect 都係 downstream consumers 間接造成：

| Visual/Audio surface | Owning system | #9 contribution |
|---------------------|---------------|-----------------|
| Wave archetype visual flavor (MOBILITY mob vs STRIKE mob) | #14 EnemyDirector | `get_dominant_ability_class()` driven |
| Boss anchor pre-spawn animation timing | #14 EnemyDirector + #6 ScreenEffects + #5 Particles | `set_progress >= 0.8` trigger via #14 Rule 13 |
| Workout phase HUD readout | #20 Gym-Mode HUD (Not Started) | `get_workout_snapshot()` query result |
| Loot drop fanfare on `workout_completed` | #21 Loot Drop Modal + #15 Loot Drop System + #5 Particles | `workout_completed_forwarded` signal trigger |
| Stat number increment animation per set_logged | #22 Character Screen + #11 Stat System | #11 emits stat_changed downstream of #9's `apply_stat_delta` call |

呢個 N/A 係 architectural correct — 跟 #11 Stat / #3 PersistenceLayer / #1 GSM 同款 Foundation/Core data-layer pattern。任何 visual/audio 直接綁定 #9 都係 architectural smell (Rule 16 NEVER #6 indirect violation)。

> **Asset Spec Flag**: N/A — no asset production triggered by #9 directly. Asset spec relevant 嘅 trigger 點喺 #14 / #20 / #21 GDDs。

## UI Requirements

**N/A — #9 has no direct UI surface.**

#9 不會 instantiate Control / CanvasLayer / Widget。所有 UI-visible state queries 由 #20 Gym-Mode HUD (Not Started, MVP-tier) 透過 `get_workout_snapshot()` API consume：

| HUD element | Source query | Cross-ref |
|-------------|--------------|-----------|
| Current workout phase indicator | `get_current_phase()` → display name mapping | #20 design owns |
| Set progress bar | `get_set_progress()` + `set_progress_is_estimated` flag for visual treatment差別 | #20 design owns |
| Today's class label | `get_dominant_ability_class()` → STRIKE/CONTROL/MOBILITY/UNKNOWN display | #20 design owns |
| Exercise count badge | `get_completed_exercises_count()` | #20 design owns |
| Offline/frozen banner | `WorkoutSnapshotRO.is_stale_due_to_poll_failure == true` | #20 + ADR-002 |
| Bfcache resume banner | `bfcache_resumed(was_mid_workout=true)` signal subscription | #20 + ADR-003 |

> **UX Flag — #20 Gym-Mode HUD**: Pre-Production 階段 run `/ux-design` 為 Gym-Mode HUD 寫 UX spec **before** epics — Stories 引用 UI 應 cite `design/ux/gym-mode-hud.md`，唔係直接 cite #9 GDD。同時 update systems-index 標註 #9 UI consumer = #20。

## Acceptance Criteria

43 ACs total — covering 17 Rules + 4 Formulas + 5 CF + 5 CI + 9 critical ECs + 5 Falsifiable Tests + 3 FR Risk Register + 4 Knobs。Distribution: 30 Unit / 7 Integration / 2 Static / 1 Manual + 3 multi-kind。Gate: 41 BLOCKING + 1 ADVISORY (FR-1 playtest) + 1 ADR-RATIFICATION-GATED (AC-37 Q-X2 pending)。

### 一、Core Rules Coverage (17 Rules → ACs)

- **AC-01 [Logic | BLOCKING | Unit]** (Rule 1: 訂閱 7 個 #2 typed signals): **GIVEN** `WorkoutStateTracker._ready()` 完成且 #2 GymSysClient mock 注入, **WHEN** 檢查 connected signals 清單, **THEN** 必定訂閱以下 7 個：`workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`, `poll_failed`, `poll_recovered`；任何缺漏 assert fail。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_signal_subscription.gd`

- **AC-02 [Logic | BLOCKING | Unit]** (Rule 2: WorkoutPhase 5-state machine + valid transition matrix): **GIVEN** initial `phase == IDLE`, **WHEN** 順序 emit `workout_started → set_logged → rest_started → rest_ended → set_logged → workout_completed`, **THEN** phase 依序變為 `WARM_UP → SET_ACTIVE → REST_PERIOD → REST_PERIOD (rest_ended internal flag) → SET_ACTIVE → WORKOUT_COMPLETE`，每次 transition 觸發 `phase_changed(old, new)` signal。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_phase_transitions.gd`

- **AC-03 [Logic | BLOCKING | Unit]** (Rule 3: Substate INITIALISING/READY/SUSPENDED + Rule 9 frozen flag orthogonal): **GIVEN** `_ready()` 剛開始, **WHEN** 查 substate, **THEN** 回傳 `INITIALISING`；snapshot restored + #2 signals subscribed 之後變 `READY`；收到 #1 GSM `state_changed → Suspended` 變 `SUSPENDED`；收到 `poll_failed` 任何 substate 都 set `_is_frozen=true`（orthogonal），`poll_recovered` 解除。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_substate_and_frozen.gd`

- **AC-04 [Logic | BLOCKING | Unit]** (Rule 4: set_progress monotonicity within workout — bind CF-1): **GIVEN** `phase == SET_ACTIVE` + `set_progress == 0.42`, **WHEN** estimator 重新計算返 0.31（後退）, **THEN** WST 抑制 downward revision，forwarded 值維持 0.42；`set_progress_changed` 唔 emit；log `WST_PROGRESS_MONOTONIC_BLOCKED` (INFO)。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_set_progress_monotonic.gd`

- **AC-05 [Logic | BLOCKING | Unit]** (Rule 5: 5 read-only queries + immutable RO resources): **GIVEN** WST 任何 state, **WHEN** 呼叫 `get_current_phase()`, `get_dominant_ability_class()`, `get_set_progress()`, `get_completed_exercises_count()`, `get_workout_snapshot()`, **THEN** 全部回傳 immutable RO（試圖 mutate field 觸發 GDScript error）；無任何 `set_*` / `mutate_*` / `force_*` public method (introspection via `get_method_list()`)。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_readonly_queries.gd`

- **AC-06 [Integration | BLOCKING | Static]** (Rule 14 CI lint — Closed-API + namespace discipline): **GIVEN** 全 repo `src/`, **WHEN** 執行 `tools/ci/check_workout_state_caller.gd` + `tools/ci/check_wst_namespace.gd`, **THEN** (a) `WorkoutStateTracker\.(set_|_)` 命中 0 處 outside `src/core/workout_state_tracker.gd`；(b) `PersistenceLayer.write\(["']wst\.` 命中 0 處 outside same file；任何命中 → CI build fail。
  - **Test type**: Static
  - **Evidence path**: `tools/ci/check_workout_state_caller.gd` + `tools/ci/check_wst_namespace.gd` + `tests/static/test_wst_ci_lint.gd`

- **AC-07 [Logic | BLOCKING | Unit]** (Rule 1 + Rule 10 forwarded signals — 6 outbound): **GIVEN** #2 mock emit 各 signal, **WHEN** 觀察 WST 對外 emit, **THEN** 收到以下 6 個 forwarded signals: `workout_started_forwarded`, `workout_completed_forwarded(completed_at, transition_id)`, `workout_summary_available(summary)`, `set_progress_changed(new_progress)` (debounced 500ms), `dominant_class_changed(new_class)` (only on flip), `phase_changed(from, to)`；`poll_failed`/`poll_recovered` 內部消化 NOT forwarded。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_forwarded_signals.gd`

- **AC-08 [Logic | BLOCKING | Unit]** (Rule 4 + CF-4: set_history append-only): **GIVEN** `current_workout_ro.set_history` 已有 N 個 entry, **WHEN** 再 emit set_logged, **THEN** `set_history.size() == N+1`；既有 N 個 entry deep_equal 無變化；任何 in-place mutation 或 pop 操作 assert fail。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_set_history_append_only.gd`

- **AC-09 [Logic | BLOCKING | Unit]** (Rule 11.1: workout_id 對應 lifecycle isolation): **GIVEN** 第一個 workout `id=W1` 完成 + `previous_dominant_class` 鎖死, **WHEN** 第二個 `workout_started` 觸發 (新 client-derived workout_id), **THEN** `_current_workout_id` 更新；舊 W1 嘅 `WorkoutSummaryRO.transition_id` 保留；`set_history` 重置 empty；兩個 workout 數據唔互相污染。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_workout_id_isolation.gd`

- **AC-10 [Logic | BLOCKING | Unit]** (Rule 5 + EC-21: dominant_class hysteresis — bind Knob `DOMINANT_CLASS_CHANGE_COOLDOWN_S = 30s`): **GIVEN** `dominant_class == MOBILITY` 且 last change time = T, **WHEN** 30 秒內出現 STRIKE 主導 set count, **THEN** `dominant_class_changed` 唔 emit；T+30s 後再評估先准 switch；INV-4 cooldown 違反即 assert fail。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_dominant_class_hysteresis.gd`

- **AC-11 [Logic | BLOCKING | Unit]** (Rule 6 + Rule 13: #11 Stat caller obligation + class→stat routing): **GIVEN** #11 Stat mock + #10 stub mapping bench_press→STRIKE, **WHEN** `set_logged(bench_press, 8, 60.0)` 到達, **THEN** WST 呼叫 `Stat.apply_stat_delta(STR, 480.0, VOLUME_TICK, source_key="wst_<workout_id>_set_<index>")`；squat 樣本 → VIT，row → DEX；UNKNOWN exercise 跳過 (zero invocation)。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_stat_caller_routing.gd`

- **AC-12 [Logic | BLOCKING | Unit]** (Rule 4 + WorkoutSnapshotRO.set_progress_is_estimated flag — bind CI-2): **GIVEN** GymSys 冇 `planned_total_sets` 但 `historical_avg_sets > 0`, **WHEN** 讀 `get_workout_snapshot().set_progress_is_estimated`, **THEN** 回傳 `true`（caller 知道行 fallback path）；當 #2 future signal extension expose `planned_total_sets` 時，呢個 flag 回 `false`。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_set_progress_estimated_flag.gd`

- **AC-13 [Logic | BLOCKING | Unit]** (Rule 5 + CI-3: UNKNOWN class 誠實回傳): **GIVEN** 收到 `set_logged` 但 `exercise_id` 喺 #10 mapping stub 內找唔到, **WHEN** 計算 dominant_class, **THEN** 該 set 跳過 set_counts tally（UNKNOWN exercises don't contribute）；如果整個 workout 全部 UNKNOWN → `get_dominant_ability_class()` 返 `&"UNKNOWN"`；**WST 唔強行 fallback STRIKE**（嗰個係 #14 responsibility per EC-09）。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_unknown_class.gd`

- **AC-14 [Logic | BLOCKING | Unit]** (Rule 1 + CI-5: completed_exercises_count = distinct exercise_id): **GIVEN** 同一 workout 內 emit set_logged 5 次：exercise_id ∈ {E1, E1, E2, E1, E3}, **WHEN** 讀 `get_completed_exercises_count()`, **THEN** 值 == 3（distinct），唔係 5（set count）。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_completed_exercises_distinct.gd`

- **AC-15 [Logic | BLOCKING | Unit]** (Rule 10 + CF-5: total_volume 累加 + frozen at workout_completed): **GIVEN** workout 進行中已累積 `total_volume = 5000`, **WHEN** emit `workout_completed` → `WorkoutSummaryRO` 封口 → late `set_logged(.., reps=5, weight=60.0)` 到達, **THEN** `WorkoutSummaryRO.total_volume == 5000`（凍結），late event drop per EC-32。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_total_volume_frozen.gd`

- **AC-16 [Integration | BLOCKING | Integration]** (Rule 7 + Rule 12: snapshot bfcache persist + resume): **GIVEN** workout 進行中 phase=SET_ACTIVE + set_history N=5, **WHEN** mobile Safari bfcache pagehide → 30s → pageshow → autoload `_ready()` re-run, **THEN** snapshot restored from `wst.*` namespace；phase / set_history / set_progress 重建；recomputed `_cached_dominant_class` 同 freeze 前一致；substate → READY；emit `bfcache_resumed(was_mid_workout=true, restored_phase=SET_ACTIVE)`。
  - **Test type**: Integration
  - **Evidence path**: `tests/integration/core/workout_state_tracker/test_snapshot_persist_resume.gd`

- **AC-17 [Static | BLOCKING | Static]** (Rule 15 + Rule 16: autoload singleton + 12 NEVERs sweep): **GIVEN** repo 內任何呼叫 WST 嘅 site, **WHEN** static analyze, **THEN** (a) 一定係 `WorkoutStateTracker.xxx` (autoload name)，唔准 `preload(..).new()`；(b) Rule 16 NEVERs grep sweep — 任何 `_workout_phase = ` / `_dominant_class = ` outside autoload file → CI fail；(c) 任何 `Stat.get_*` reference inside `src/core/workout_state_tracker.gd` → CI fail (Rule 16 NEVER #6)。
  - **Test type**: Static
  - **Evidence path**: `tools/ci/check_wst_singleton_and_nevers.gd`

### 二、Formulas Coverage (4 Formulas → ACs)

- **AC-18 [Logic | BLOCKING | Unit]** (Formula 3: dominant_class set-count weighted + last-solo-leader tiebreak): **GIVEN** 8 sets per Section D Example: 3 STRIKE + 3 CONTROL + 2 MOBILITY (chronological mixed), **WHEN** 計算 `dominant_class`, **THEN** 返 `STRIKE` (tiebreak walk found solo leader at index 6)；如果 prior workout `previous_dominant_class == null` + 全 tie → return UNKNOWN per Rule 5 case 4。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_formula3_dominant_class.gd`

- **AC-19 [Logic | BLOCKING | Unit]** (Formula 2 EWMA + CF-3 execution order): **GIVEN** prior `historical_avg_sets = 6.0`, alpha=0.3, 新 workout 4 sets completed, **WHEN** `workout_completed` 觸發 finalise, **THEN** call order spy assert == `[build_summary, emit_summary_available, emit_completed_forwarded, compute_ewma=5.4, persist_snapshot, transition_to_idle]`；EWMA execution 喺 reset 之前；新 ewma 寫返 `wst.history.avg_sets == 5.4 ± 0.001`。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_formula2_ewma_order.gd`

- **AC-20 [Logic | BLOCKING | Unit]** (Formula 1 set_progress full-data + estimated paths — bind Knob `SET_PROGRESS_BONUS_SET_CLAMP=0.95`, INV-2/INV-3): **GIVEN** Section D Example A (planned 6 sets × 10 reps, current set 5 reps 8/10), **WHEN** 計算, **THEN** set_progress == 0.800 ± 0.001；同 Example B (estimated path, historical_avg_sets=5.2, reps_per_set=9.4) → set_progress == 0.815 ± 0.005；bonus set (current > planned) → clamp ≤ 0.95。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_formula1_set_progress.gd`

- **AC-21 [Logic | BLOCKING | Unit]** (Formula 4 + CF-2: total_volume + final_set_progress at workout_completed): **GIVEN** workout 進行中最後一個 `set_progress = 0.87` + set_history total = (5×100×5 + 3×120×5) kg-reps, **WHEN** 緊接收 `workout_completed`, **THEN** `WorkoutSummaryRO.final_set_progress == 0.87` AND `WorkoutSummaryRO.total_volume == 4300.0`；late events 唔 overwrite。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_formula4_and_cf2.gd`

### 三、Cross-Formula Invariants CF-1..CF-5 (independent ACs)

- **AC-22 [Logic | BLOCKING | Unit]** (CF-1 set_progress monotonicity fuzz): **GIVEN** 100 個 random set_progress events (seeded), **WHEN** apply Formula 1 monotonic clamp, **THEN** forwarded 序列嚴格 non-decreasing；任何 downward step assert fail。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_cf1_monotonic_fuzz.gd`

- **AC-23 [Logic | BLOCKING | Unit]** (CF-3 EWMA pre-reset guard — independent of AC-19): **GIVEN** spy on workout state reset, **WHEN** Formula 2 EWMA computation occurs, **THEN** assert `_current_workout_id != null` 喺 EWMA 計算嗰刻（即 reset 仲未 run）；reset_after_ewma 順序 invariant 強制 enforce。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_cf3_pre_reset_guard.gd`

- **AC-24 [Logic | BLOCKING | Unit]** (CF-4 set_history prefix invariant): **GIVEN** 50 個 set_logged events, **WHEN** 全部處理後, **THEN** `set_history[0..N-1]` 喺任何中間時刻嘅 snapshot 都係前綴關係 (prefix invariant)，中段 entry 永唔變；CI-friendly assertion harness。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_cf4_append_only_fuzz.gd`

- **AC-25 [Logic | BLOCKING | Unit]** (CF-5 total_volume frozen stress): **GIVEN** workout_completed 後 1 秒內 emit 20 個 late `set_logged`, **WHEN** 讀 `WorkoutSummaryRO`, **THEN** `total_volume` 不變、`dropped_late_events_count == 20`、telemetry `WST_LATE_SET_001` log 20 條 WARN。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_cf5_total_volume_stress.gd`

### 四、Cross-System Invariants CI-1..CI-5 (independent ACs)

- **AC-26 [Integration | BLOCKING | Integration]** (CI-1 set_progress >= 0.8 → #14 boss anchor): **GIVEN** WST + #14 真實 instance (mocked render layer), **WHEN** WST forward `set_progress_changed(0.82)`, **THEN** #14 boss anchor pre-spawn pipeline 觸發 (observable via #14 spy signal `_boss_anchor_pre_spawn_started`)；`set_progress_changed(0.78)` 唔觸發。
  - **Test type**: Integration
  - **Evidence path**: `tests/integration/core/workout_state_tracker/test_ci1_boss_anchor_trigger.gd`

- **AC-27 [Integration | BLOCKING | Integration]** (CI-2 set_progress estimated → #14 fallback heuristic): **GIVEN** WST `WorkoutSnapshotRO.set_progress_is_estimated == true` AND set_progress 一直 < 0.8, **WHEN** #14 query 4Hz tick, **THEN** #14 啟動 fallback `reps_completed_in_set >= ceil(planned_reps × 0.5)` 路徑 (per #14 Rule 13 + Formula 5 fallback)；#9 zero responsibility for fallback computation。
  - **Test type**: Integration
  - **Evidence path**: `tests/integration/core/workout_state_tracker/test_ci2_unreliable_fallback.gd`

- **AC-28 [Logic | BLOCKING | Unit]** (CI-3 UNKNOWN class — #9 honest return, #14 自己 fallback): **GIVEN** WST 返 `&"UNKNOWN"` per AC-13, **WHEN** #14 收到 `dominant_class_changed(UNKNOWN)`, **THEN** #14 內部 fallback policy 啟動 STRIKE (per #14 EC-09)；#9 spy 確認從未 emit `STRIKE` 作為 fallback (Pillar 1 honest)。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ci3_unknown_honest.gd`

- **AC-29 [Integration | BLOCKING | Integration]** (CI-4 total_volume → ADR-005 via #15): **GIVEN** workout_completed `total_volume=8000` + completed_exercises_count=5, **WHEN** #15 LootDrop (mock) reads `WorkoutSummaryRO`, **THEN** ADR-005 `volume_factor = min(1.0, 5/5) = 1.0`；input wiring correct via #15 spy。
  - **Test type**: Integration
  - **Evidence path**: `tests/integration/core/workout_state_tracker/test_ci4_volume_to_loot.gd`

- **AC-30 [Logic | BLOCKING | Unit]** (CI-5 completed_exercises_count distinct stress): **GIVEN** 100 sets random exercise_id 池 = 10 個, **WHEN** 完成, **THEN** `get_completed_exercises_count() == 10` (distinct)；absolutely never > distinct cardinality；fuzz harness with 1000 random sequences。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ci5_distinct_stress.gd`

### 五、Critical Edge Cases (9 CRITICAL severity ECs)

- **AC-31 [Logic | BLOCKING | Unit]** (EC-01: workout_completed in IDLE — truth gate): **GIVEN** WST `phase == IDLE`, **WHEN** mock 收到 `workout_completed(now)`, **THEN** event dropped + log `WST_INV_VIOL_001` (ERROR)；phase 保持 IDLE；`workout_completed_forwarded` 唔 emit；boss 唔 spawn (verified via #14 spy) — bind Falsifiable Test #3 truth-gate。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec01_orphan_completed.gd`

- **AC-32 [Integration | BLOCKING | Integration]** (EC-36 + Falsifiable Test #5: bfcache resume integrity): **GIVEN** workout 進行中 + bfcache pagehide → 30 min → pageshow + #2 reconnect, **WHEN** WST `_ready()` re-run, **THEN** 若 snapshot TTL (24h) 未過期 → resume 成功 phase 一致；若已過期 → discard snapshot + reset IDLE + emit `workout_state_discarded(reason="ttl_expired")`；**NO half-state corruption** (phase/set_history/set_progress consistent OR all reset)。
  - **Test type**: Integration
  - **Evidence path**: `tests/integration/core/workout_state_tracker/test_ec36_bfcache_ttl_expiry.gd`

- **AC-33 [Logic | BLOCKING | Unit]** (EC-08: SUSPENDED entry during WORKOUT_COMPLETE call_deferred tick): **GIVEN** `phase == WORKOUT_COMPLETE` + `workout_completed_forwarded` 已 emit + #11 stat apply 仍 pending, **WHEN** #1 GSM `state_changed → Suspended` 到達, **THEN** SUSPENDED 進入 **延遲** 至當前 frame `call_deferred` queue 清空；#11 stat delta 完成 apply；loot pipeline 唔斷。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec08_suspended_during_complete.gd`

- **AC-34 [Logic | BLOCKING | Unit]** (EC-11: workout_completed dropped during SUSPENDED — verify #2 redundant emission saves loot): **GIVEN** substate=SUSPENDED + Pillar 3 guarantee, **WHEN** mock `workout_completed` 到達 + drop, **THEN** drop + log；unsuspend 後 #2 backfill mechanism re-emits same `workout_completed` (per ADR-002 idempotent polling)；最終 loot pipeline 觸發 1 次（NOT 0 次 NOT 2 次）。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec11_suspended_drop_loot_safe.gd`

- **AC-35 [Logic | BLOCKING | Unit]** (EC-17 + EC-23: snapshot byte truncation — bind Knob `SNAPSHOT_BYTE_TRUNCATION_THRESHOLD=256KB`, INV-7): **GIVEN** set_history 超大導致 serialized snapshot > 256KB, **WHEN** persist, **THEN** truncate 至最近 50 sets + log `WST_SNAPSHOT_TRUNC_001` (WARN)；aggregate stats (total_volume, completed_exercises_count) 已 derived 唔失；resume 後讀 truncated snapshot 可以重建 partial state。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec17_snapshot_truncate.gd`

- **AC-36 [Logic | BLOCKING | Unit]** (EC-24: PersistenceLayer write fail — in-memory continuity): **GIVEN** PersistenceLayer mock returns false on `write("wst.current_workout.phase", _)`, **WHEN** WST encounters write fail, **THEN** **NOT retry inline**；emit `wst.persist_failed(key, reason)`；#9 in-memory state 繼續正常運作直到 unload；後續 set_logged events 仍然 process。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec24_persist_fail_continuity.gd`

- **AC-37 [Logic | ADR-RATIFICATION-GATED | Unit]** (EC-30: transition_id collision — ADR-006 tombstone forward-recovery): **GIVEN** mock #1 GSM `acquire_transition_id()` returns same ID twice (impossible normally but tested via mock injection), **WHEN** 第二個 signal use 同 ID, **THEN** WST drop second event via tombstone detection；log `WST_TXN_COLLIDE_001` (ERROR)；no state corruption。**Gate**: ADR-RATIFICATION-GATED on ADR-006 Contract 2 tombstone behavior finalization。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec30_txn_collision.gd`

- **AC-38 [Logic | BLOCKING | Unit]** (EC-32: late set_logged after workout_completed): **GIVEN** `phase == WORKOUT_COMPLETE` 後 0-3s 內收 `set_logged(.., reps=5, weight=60.0)`, **WHEN** processed, **THEN** drop event + log `WST_LATE_SET_001` (WARN, payload=delay_ms)；`WorkoutSummaryRO.total_volume` 不變；Rule 16 NEVER #5 (no retroactive mutation) enforced。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec32_late_set_logged.gd`

- **AC-39 [Logic | BLOCKING | Unit]** (EC-29: #11 Stat queue overflow at cap 100 — bind Knob `PENDING_STAT_DELTAS_MAX=100`): **GIVEN** #11 Stat substate 仍 INITIALISING + #9 queue 已達 100 entries, **WHEN** 101st `set_logged` 到達 → trigger Rule 6 buffer overflow, **THEN** drop oldest entry (FIFO)；emit `wst.queue_overflow`；log `WST_QUEUE_OVERFLOW_001` (ERROR, payload=dropped_count=1)。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_ec29_stat_queue_overflow.gd`

### 六、Falsifiable Tests + Fantasy Risk Register

- **AC-40 [Visual/Feel | ADVISORY (VS-tier) → BLOCKING (MVP gate) | Manual]** (Falsifiable Test #1 + FR-1 binding — blind A/B dominant_class playtest): **GIVEN** playtester pool 完成「Leg-dominant workout」(15 leg sets) vs「Push-dominant workout」(15 push sets) vs「Pull-dominant workout」vs「Mixed workout」, **WHEN** 玩 Mirror Hero session 30 分鐘後填問卷 (without seeing menu labels), **THEN** ≥ 70% 受試者報告 leg/push/pull session 「fight feel 有明顯差異」(divergent feel hypothesis)；A 講「敵人走得快、要閃」(MOBILITY)，B 講「敵人扛得實、要打硬」(STRIKE)；冇差異即 Pillar 4 mechanical home failure。**Sample size**: **n ≥ 2 for VS-tier ADVISORY** (Pillar 4 binding remains EXPLICITLY UNVALIDATED until MVP gate)；**n ≥ 8 covering all 4 class types (STRIKE/CONTROL/MOBILITY/UNKNOWN-fallback) at least once for MVP gate (BLOCKING)** — per CD F-11 statistical power requirement (n=2 對 4-way dispatch baseline 25% 完全無 power)。Solo dev 嘅 8 sessions = 1-2 週 personal gym data, 唔過分。
  - **Test type**: Manual playtest
  - **Evidence path**: `production/qa/evidence/wst_blind_playtest.md`

- **AC-41 [Integration | BLOCKING | Integration]** (Falsifiable Test #2 — sub-500ms boss anchor latency): **GIVEN** scripted workout ending sequence (set_progress crossing 0.8 → workout_completed 30s later), **WHEN** 量度 `workout_completed_forwarded` emit timestamp → boss visible-on-screen frame timestamp, **THEN** p95 ≤ 500ms (100 trials, automated harness, mock #14 render)；FR-1 secondary binding (fallback path 也滿足同 budget)。
  - **Test type**: Integration
  - **Evidence path**: `tests/integration/core/workout_state_tracker/test_falsifiable2_boss_latency.gd`

- **AC-42 [Logic | BLOCKING | Unit]** (Falsifiable Test #3 + FR-3 binding — truth-gate integrity end-to-end): **GIVEN** scenario：skip `workout_started`、直接 emit set_logged + workout_completed, **WHEN** 觀察整個 5-system anti-fabrication chain (#2 + #3 + #11 + #14 + #9), **THEN** boss 唔 spawn、loot 唔 drop、set_progress 維持 0、`Stat.apply_stat_delta` 從未 invoked；任何「無 workout 都有 reward」即 anti-fabrication 鏈第五件套失敗。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_falsifiable3_truth_gate.gd`

- **AC-43 [Logic | BLOCKING | Unit]** (FR-2 binding — VS-tier #10 stub boundary correctness): **GIVEN** VS-tier inline stub mapping `{bench_press: STRIKE, row: CONTROL, squat: MOBILITY}`, **WHEN** 餵 20 個 exercise_id (3 in-stub + 17 out-of-stub), **THEN** in-stub 正確分類；out-of-stub 一律返 `&"UNKNOWN"` (NEVER guess STRIKE)；驗證 stub 邊界 zero hallucination。
  - **Test type**: Unit
  - **Evidence path**: `tests/unit/core/workout_state_tracker/test_fr2_stub_boundary.gd`

---

### Coverage Map

| Source | AC IDs |
|---|---|
| Rule 1 | AC-01, AC-07 |
| Rule 2 | AC-02 |
| Rule 3 | AC-03 |
| Rule 4 | AC-04, AC-12, AC-22 |
| Rule 5 | AC-05, AC-13 |
| Rule 6 | AC-11, AC-39 |
| Rule 7 | AC-16, AC-35, AC-36 |
| Rule 8 | AC-34 |
| Rule 9 | AC-03 |
| Rule 10 | AC-07, AC-15, AC-21 |
| Rule 11 | AC-37 |
| Rule 11.1 | AC-09 |
| Rule 12 | AC-16, AC-32 |
| Rule 13 | AC-11 |
| Rule 14 | AC-06, AC-17 |
| Rule 15 | AC-17 (boot position via singleton lint) |
| Rule 16 | AC-17, AC-38 |
| Formula 1 | AC-20 |
| Formula 2 | AC-19, AC-23 |
| Formula 3 | AC-18 |
| Formula 4 | AC-21 |
| CF-1 | AC-04, AC-22 |
| CF-2 | AC-21 |
| CF-3 | AC-19, AC-23 |
| CF-4 | AC-08, AC-24 |
| CF-5 | AC-15, AC-25 |
| CI-1 | AC-26 |
| CI-2 | AC-12, AC-27 |
| CI-3 | AC-13, AC-28 |
| CI-4 | AC-29 |
| CI-5 | AC-14, AC-30 |
| EC-01 | AC-31 |
| EC-08 | AC-33 |
| EC-11 | AC-34 |
| EC-17/23 | AC-35 |
| EC-24 | AC-36 |
| EC-29 | AC-39 |
| EC-30 | AC-37 |
| EC-32 | AC-38 |
| EC-36 | AC-32 |
| Falsifiable Test #1 | AC-40 |
| Falsifiable Test #2 | AC-41 |
| Falsifiable Test #3 | AC-31, AC-42 |
| Falsifiable Test #4 (CI lint) | AC-06, AC-17 |
| Falsifiable Test #5 (bfcache) | AC-32 |
| FR-1 | AC-40, AC-41 |
| FR-2 | AC-43 |
| FR-3 | AC-42 |
| Knob WORKOUT_SNAPSHOT_TTL_HOURS | AC-32 |
| Knob DOMINANT_CLASS_CHANGE_COOLDOWN_S | AC-10 |
| Knob SET_PROGRESS_BONUS_SET_CLAMP | AC-20 |
| Knob SNAPSHOT_BYTE_TRUNCATION_THRESHOLD | AC-35 |
| Knob PENDING_STAT_DELTAS_MAX | AC-39 |

### Test Type Distribution (actuals)

| TestKind | Count | % | Target | Variance |
|---|---|---|---|---|
| Unit | 30 | 69.8% | 60% | +9.8% |
| Integration | 7 | 16.3% | 20% | −3.7% |
| Static | 2 | 4.7% | 10% | −5.3% |
| Manual playtest | 1 | 2.3% | 10% | −7.7% |
| **Multi-kind (Integration + Static)** | (AC-06 counted as Static primary) | — | — | — |
| **Total** | **43** | 100% | — | — |

Unit 偏多 (+9.8%) 反映 #9 係 logic-heavy autoload；Manual playtest 只 1 條 (FR-1 blind A/B) 係刻意 — Pillar 4 「肌群預言家」需要主觀 fight feel 驗證，唔可以 mock。

### Gate Distribution

| Gate | Count |
|------|-------|
| **BLOCKING** | 41 |
| **ADVISORY** | 1 (AC-40 blind playtest) |
| **ADR-RATIFICATION-GATED** | 1 (AC-37 transition_id collision — pending ADR-006 Contract 2 finalization) |

### Coverage Gaps (誠實清單)

1. **EC-03/04/05/06/07/09/10/12/13/14/15/16/18/19/20/21/22/25/26/27/28/31/33/34/35/37** (non-CRITICAL severity) — Section H 只覆蓋 9 個 CRITICAL ECs；HIGH / MEDIUM / LOW ECs 推遲到 `tests/unit/core/workout_state_tracker/edge_cases_minor_test.gd` 喺 sprint 3 補做，唔 block release。
2. **#10 Exercise→Class Mapping 完整 mapping** (AC-43 只驗 VS-tier stub 邊界) — 完整 mapping 屬於 #10 嘅 AC，唔重複喺 #9 度寫。
3. **WORKOUT_SNAPSHOT_TTL_HOURS 安全範圍邊界 [12h, 72h]** — AC-32 只測 expired path (TTL 過期 vs 未過期 binary)；boundary 12h / 72h 留俾 knob sweep test (`tests/unit/core/workout_state_tracker/knob_sweep_test.gd` 屬 ADVISORY)。
4. **AC-37 EC-30 transition_id collision** gate 升為 ADR-RATIFICATION-GATED — 等待 Q-X3 (ADR-006 Contract 2 tombstone behavior) ratify 之前，呢條 AC 只用 best-effort mock injection 行為，未必 100% covered。
5. **AC-40 blind playtest n=2** — 樣本細，建議擴至 n=8 喺 milestone 2 之前；MVP 接受 n=2 + 質性回饋作為 ADVISORY evidence。
6. **`poll_failed`/`poll_recovered` NOT forwarded explicit negative assertion** — 由 Rule 1 隱含 (forwarded 6 個唔包)，未有獨立 AC 明確 assert「該 2 個 signals 唔對外 emit」，建議補一條 negative assertion test (追蹤 issue: WST-AC-followup-01)。
7. **Formula 1 raw value parity test** — AC-20 only verifies 2 worked examples + clamp boundary，未有 exhaustive parametric coverage；標記為 advisory follow-up。

## Open Questions

### Cross-system Questions (Q-X) — resolve via downstream GDD authoring or next-revision batch

| ID | Question | Owner | Target resolution | Affects |
|----|----------|-------|-------------------|---------|
| **Q-X1** | Class naming alternative: STRIKE/CONTROL/MOBILITY → STRIKE/GRAPPLE/STANCE? Game-designer flagged Pull→"Control" 同 Leg→"Mobility" 直覺斷層；但 #11/#12/#14 已 Approved with 現有 enum，rename cascade cost ~1-2h pass。**CD F-9 recommendation**: 喺 VS-tier kickoff 之前 (即 #15 hero-visual GDD 寫之前) run short `/architecture-decision` ADR-0007 鎖死 enum naming convention。Recommended approach: **technical enum keep 英文** (`CLASS_WARRIOR / CLASS_RANGER / CLASS_MONK` or current STRIKE/CONTROL/MOBILITY) + **narrative display name 用 localization table 分離** → 兩邊可以 evolve 而唔 break 對方 | game-designer + #14 owner | **Pre-VS-tier kickoff** (per CD F-9 ADVISORY) — author ADR-0007 first | Section C Rule 5/13 + #11 + #12 + #14 enum rename |
| **Q-X2** | #2 GymSysClient `signal workout_started()` payload 應否 next-revision 加 `workout_id: String` field? 而家 #9 Rule 11.1 client-derived workout_id 解決 single-device session，但 future multi-device handoff (Mirror Hero v0.2+) 會需要 server-assigned ID | systems-designer + #2 owner | #2 next-revision batch OR ADR-002 ratification | Rule 11.1 + EC-36 device handoff path |
| **Q-X3** | `is_set_progress_reliable` exposure approach — 而家 via `WorkoutSnapshotRO.set_progress_is_estimated` bool，但 #14 4Hz tick 每次都要 read 整個 snapshot Resource。Performance concern at 240 reads/min × workout duration。**CD recommended answer (F-10 strong opinion)**: when `is_estimated == true` → **#14 應 use last known good value + log telemetry**，**NOT dampen aggression**（dampening 會令 partial-data 用家覺得 enemy 變弱，violates Pillar 1 真實感）。Also recommend: introduce dedicated cheap getter `is_set_progress_reliable() -> bool` to avoid 4Hz Resource read overhead | gameplay-programmer + #14 owner | **MUST resolve before #14 Production sprint** (CD CONCERN F-10) — pre-resolve via cross-GDD coordination session | Rule 4 + AC-12 |
| **Q-X4** | systems-index 應否 remove #9 → #8 Streak dependency arrow? Section F clarification confirmed #9 同 #8 都係 sibling consumers of `#2.workout_completed`，無 direct call relationship | producer + systems-designer | Next /map-systems revision OR systems-index manual update | Systems-index dependency map |

### ADR-Ratification-Gated Questions (Q-A)

| ID | Question | Owner | Gates on | Affects |
|----|----------|-------|----------|---------|
| **Q-A1** | EC-30 `transition_id` collision behavior — current AC-37 ADR-RATIFICATION-GATED on ADR-006 Contract 2 final tombstone semantics. 唔確定 forward-recovery 喺 same-frame collision case 嘅精確 behavior | engine-programmer + ADR-006 author | ADR-006 ratification (currently Proposed) | AC-37 + Rule 11 |
| **Q-A2** | EC-15 fallback policy when GymSys `planned_reps = 0` AND `historical_avg_sets = null` (cold start)：呢個 case set_progress 應 lock 0.5 (neutral) vs 0.0 (zero)？ Current design 推 0.5 per Knob `SET_PROGRESS_NEUTRAL_FALLBACK` but 影響 #14 boss pre-spawn timing — 0.5 < 0.8 唔觸發但 < 0.95 BONUS_CLAMP 內，意味第二 set 一 logged 就可能 cross threshold | systems-designer + #14 owner | #14 GDD validation OR sprint playtest | EC-15 + Knob safe range |

### Followup-Tracked Items (test gaps from Section H — NOT blocking)

- **WST-AC-followup-01**: `poll_failed` / `poll_recovered` NOT forwarded — negative assertion test 待補
- **WST-AC-followup-02**: Formula 1 raw value parametric parity test — exhaustive coverage 待補
- **WST-AC-followup-03**: 非 CRITICAL ECs (28 items) → `tests/unit/core/workout_state_tracker/edge_cases_minor_test.gd` sprint 3 補做
- **WST-AC-followup-04**: AC-40 blind playtest sample size n=2 (VS-tier) → n=8 by MVP gate (BLOCKING per CD F-11)
- **WST-AC-followup-05**: Knob safe range boundary tests (sweep [12h, 72h] for `WORKOUT_SNAPSHOT_TTL_HOURS`)
- **WST-AC-followup-06** (per CD F-12 ADVISORY): Formula 4 `total_volume` bodyweight handling refinement — current spec sets contribution=0 when `weight=0` (bodyweight exercise)，CD recommends `weight_effective = max(weight, user_weight × exercise.bw_coefficient)` (pushup ≈ 0.65, pullup ≈ 1.0)；implementation refinement pre-#15 hero-visual
- **WST-AC-followup-07** (per CD F-13 ADVISORY): EC-35 / EC-37 bfcache resume should trigger one immediate out-of-cycle GymSys poll (bypass ADR-002 5s timer) to minimize stale state window — flag for #2 GDD next-revision batch (poll cadence is #2's responsibility, NOT #9)
- **WST-AC-followup-08** (per CD F-9 ADVISORY): Pre-VS-tier ADR-0007 (Class Enum Naming Convention) authoring — gates Q-X1 resolution + locks `dominant_class` enum before #15 hero-visual GDD begins
