# EnemyDirector

> **Status**: **APPROVED 2026-05-27** (full mode single-pass — CD-GDD-ALIGN passed first attempt with 10 ALIGN + 2 ADVISORY + 0 CONCERN + 0 BLOCKING findings)
> **Author**: Frank + main session (full mode) + specialist agents (game-designer + ai-programmer + systems-designer × Section C parallel spawn + qa-lead × Section H + creative-director × 2 [Section B framing × 3 candidates + CD-GDD-ALIGN gate])
> **Creative Director Review (CD-GDD-ALIGN)**: **APPROVED 2026-05-27 (single-pass, no revisions needed)** — CD assessment: "Strongest pillar-architecture coupling among Approved Core-tier set (#11 → #12 → #13 → #14)" + establishes 6 new cross-system template patterns (caller-side state owner architecture / architecture-as-narrative framing / quartet anti-fabrication chain extension trio→quartet→quintet / pre-spawn + late commit pattern / cross-knob INV table with violation-flag mechanism / forward constraint table for downstream contracts)。10/10 specific checks PASS。Pillar 1 anti-fabrication chain quartet 第四件套 (orchestration discipline guarantor) complete。
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 2 (Frictionless Companion) primary — background 為你戰鬥 orchestrator；Pillar 3 (Drop Euphoria) primary substrate — `enemy_killed` chain triggers Pillar 3 signature LootDrop ritual；Pillar 4 (Muscle = Class) supporting — wave variation per ability class (推→攻擊型 / 拉→機關房 / 腿→移動關卡)；Pillar 1 (Real Body, Real Power) supporting — per-cast Stat snapshot consumer
> **System #**: 14 (Core / VS tier, design order 10)
> **Depends On**: #5 Particle System Wrapper (Approved 2026-05-26) + #6 Screen Effects (Approved 2026-05-26) + #7 Camera System (Approved 2026-05-26) + #13 CombatResolver (Approved 2026-05-27)
> **Depended On By**: #15 LootDrop System, #16 Boss System, #20 Gym-Mode HUD, #25 Combat Visual Feedback, #28 Telemetry / Analytics
> **Governing ADRs**: ADR-001 Web Export Budget Caps (Proposed) — Foundation autoload CPU + 200 mobile particle cap + auto-degrade rules；ADR-002 GymSys Integration Protocol — ability_cast events 由 polling cadence 觸發；ADR-005 Loot Rarity Formula (Accepted 2026-05-27) — `enemy_killed.transition_id` chain seed binding；ADR-006 State Machine Contract (Accepted 2026-05-27) — Contract 2 (transition_id atomicity) + Contract 4 (sequential autoload `_ready()`) + Contract 6 (`connect_for_initial_state` helper)

## Overview

EnemyDirector 係 Mirror Hero 嘅 **敵人指揮層 + auto-combat orchestrator** — Core 層 autoload (boot position N，即所有 downstream consumer #15 LootDrop / #28 Telemetry / #20 HUD 之後 ready，per ADR-006 Contract 4 sequential boot + #13 EC-43/EC-50 boot order lock)，向 5 個下游 consumer (#15 LootDrop / #16 Boss System / #20 Gym-Mode HUD / #25 Combat Visual Feedback / #28 Telemetry — 全部 NOT YET DESIGNED 但 forward contract 已 lock 由 #13 GDD 帶入) 廣播 3 條 combat signal (`hit_resolved` / `enemy_killed` / `combat_metric_anomaly`)。系統有雙重 framing：**data 層面**係 #13 CombatResolver pure-function (stateless `static func resolve_hit(ctx)`) 嘅 **caller-side state owner** — 訂閱 `#12 AbilitySystem.ability_cast(ability_id, caster, target)` signal via ADR-006 Contract 6 `connect_for_initial_state` helper、收 signal 即 sync read `GameStateMachine.current_state + current_transition_id` (Rule 12 gate input + Rule 7 RNG seed source per #13)、snapshot `#11 StatSystem.get_stat(ATTACK_POWER) + get_stat(CRIT_CHANCE)` 一次性 (Rule 6 per-cast pattern)、按 #12 `AbilityRegistry.tres.target_type` (single vs AOE_RADIUS) iterate target 列表 (max `MAX_TARGETS_PER_CAST=8` per #13 Section G)、組裝 `CombatContext` per target、call `CombatResolver.resolve_hit(ctx) -> HitResult`、翻譯 HitResult → 3 signal payload emit；同時 own enemy lifecycle (spawn / despawn / state mutation) + wave scheduling (per workout phase 同 ability class 配對：推→攻擊型 mini-boss / 拉→機關房 / 腿→移動關卡 per game-concept §Short-Term Loop) + boss encounter trigger (workout-complete → final boss spawn per game-concept §Session-Level Loop) + particle dispatch coordination (auto-degrade rules per ADR-001 200 mobile particle cap) + rate-limited anomaly emit (Rule 17 of #13 — 10/sec/reason caller-side) + catch-up × AOE serialization (Rule 18 of #13 — bfcache resume queue mutual exclusion)；**player-facing 層面**係玩家做緊 deadlift 嗰 45 秒，phone 喺枱頭，EnemyDirector 喺度自己跑：boss focal entry (`#7 Camera.focal_request(boss_target, 0.6s)` per #7 Rule 6 quart ease-out) + screen 一震 (`#6 ScreenEffects.shake(0.4, 0.08s)`) + 第一輪小怪 spawn (`#5 ParticleSystem.play(SPAWN_BURST, position)`) — 一個「重頭戲嚟啦」嘅 anticipation moment；玩家做完 set 抬頭，見到 boss HP 已經跌咗一截 + avatar 已企喺新位置 + 地下散咗幾粒 mob death particle — 即 **「Background 為你戰鬥」嘅 receptive contract evidence** (Pillar 2)、**Pillar 3 Drop Euphoria 嘅 signature LootDrop ritual trigger source** (`enemy_killed.transition_id` 鏈條 propagate 入 #15 RNG seed per ADR-005)、**Pillar 4 day-flavor 嘅 wave archetype 變奏 enactor** (推日 → 攻擊型 mini-boss spawn pool；腿日 → 移動關卡 mini-boss spawn pool)。MVP scope locked：**5 obligations 對 #13 (FR-4 Risk Register)** + **3 broadcast signals** + **3-class wave archetype** (STRIKE_MOB / CONTROL_MOB / MOBILITY_MOB enemy templates，data-driven via `EnemyRegistry.tres`) + **1 boss-fight trigger pattern** (workout-complete event from #9 Workout State Tracker → focal entry + spawn)；out-of-scope：複雜 boss phase logic (deferred 畀 #16 Boss System)、enemy AI behavior trees (v0.2 — MVP 用 simple pursue-and-attack state machine X-axis only locomotion，跟 game-concept side-scroller scope)、NavigationAgent2D pathfinding (MVP 唔需要 — 2D side-scroller 用 X-axis lerp + simple terrain collision)。系統屬「caller-side state owner」紀律 architecture — #13 CombatResolver 純 math (`static func` purity)、EnemyDirector own 全部 hidden state (queue / dedupe set / rate-limiter / spawn pool)，CI lint `tools/ci/check_enemy_director_purity_chokepoint.gd` enforce 全部 combat math 經 CombatResolver.resolve_hit() 唔可以喺 EnemyDirector 自己 compute damage。Governing ADRs: **ADR-001** Web Export Budget Caps (Proposed) — Foundation autoload total CPU ≤ 2.0ms p95 mobile (EnemyDirector 唔屬 Foundation 但 share frame budget；CombatResolver hot-path 1.0ms FR-3 已 50%，EnemyDirector orchestration overhead ≤ 0.5ms p95 mobile budget binding) + 200 mobile particle cap auto-degrade rule (#5 caller_mult discipline ≤ 1.5)；**ADR-002** GymSys Integration Protocol — `ability_cast` events 由 GymSys polling cadence (5s ±0.5s jitter) 觸發，catch-up backlog 上限受呢個 cadence 影響；**ADR-005** Loot Rarity Formula (Accepted 2026-05-27) — `enemy_killed.transition_id` 鏈條 binding propagate 入 #15 RNG seed；**ADR-006** State Machine Contract (Accepted 2026-05-27) — Contract 2 (transition_id atomicity for RNG seed) + Contract 4 (sequential autoload `_ready()` lock #14 boots LAST) + Contract 6 (`connect_for_initial_state` helper for `ability_cast` subscription per #12 Rule 10 step 5 pattern)。

## Player Fantasy

**Direct Fantasy ——「軍師排兵」(Pillar 4 Muscle = Class + Pillar 3 anticipation co-substrate)**:

玩家放低手機落長凳，cooldown 45 秒。佢知道返到嚟嘅時候戰場唔會係空白 —— 而係**有人幫佢排好咗**。今日 push day，畫面入面湧出嘅唔係 random mob，係一陣陣**舉盾抗推嘅 strike-resist 編隊** (STRIKE_MOB archetype，high defense + slow approach)；leg day 嗰陣就變做**會走位嘅 mobility 群** (MOBILITY_MOB archetype，low defense + lateral dodge + faster spawn cadence)；pull day 出 **fragile-burst 編隊** (CONTROL_MOB archetype，low HP + 死前 sticky AOE — 鼓勵玩家 pull ability 嘅 sustain damage 設計理念)。玩家唔需要按掣決定，但佢**讀得出**「啊，今日係 push 嘅劇本」。呢個係 readability without agency —— DNF stage director sense：你冇控制怪物出場，但你知 boss room 一打開就係 boss。EnemyDirector 嘅 wave scheduler 由 `#9 Workout State Tracker` 拎當前 dominant ability class (Section C Rule 12 binding)，data-driven 揀對應 archetype 由 `EnemyRegistry.tres` spawn — 唔靠 random spawn pool 偷雞，唔靠 stat-tier scaling 偷工，係**真正按你今日練乜嘢編劇本**。

**Indirect Fantasy ——「Boss 已經等緊你」(Pillar 2 Frictionless Companion 嘅 architectural promise)**:

最後一 set，最後一 rep，`workout_completed` event 由 `#9 Workout State Tracker` 經 `#1 GameStateMachine.state_changed(to: "BossEncounter")` transition propagate。Boss 唔係「忽然 spawn」—— 係 EnemyDirector 由你第一 set 開始就**埋伏緊**：wave scheduler 一路推進到 climax frame，當 `state_changed` 收到 `to == &"BossEncounter"` 嘅 transition_id 嗰一 frame，EnemyDirector 即 spawn boss、call `#7 Camera.focal_request(boss_target, 0.6s)` quart ease-out (per #7 Rule 6) + `#6 ScreenEffects.shake(0.4, 0.08s)` boss-tier trauma + `#5 ParticleSystem.play(BOSS_ENTRY, position, 1.2)` (caller_mult > 1.0，preserve Pillar 3 spectacle)。玩家完成最後一 rep 嘅瞬間抬頭，boss 啱啱破場入嚟。**「我冇做嘢，但故事跟住我嘅身體節奏走」**—— 呢個就係 Pillar 2 Frictionless Companion 嘅最深層含義：唔係冇敵人，係**敵人喺等緊你**。Receptive contract 嘅 architectural guarantee 來自 #14 嘅 5 obligations per #13 FR-4 — `ability_cast` signal subscription 永遠 connected (Contract 6 helper)、`EnemyState` struct 永遠 available、`RandomNumberGenerator` 永遠 seeded on `transition_id` (determinism 永遠可 replay)、3 個 broadcast signal 永遠 wire 到下游、anomaly rate-limiter 永遠 cap 緊 outlier event 唔淹冇玩家。冇呢 5 條 guarantee，「background 為你戰鬥」就變一句空口承諾。

**Cross-system orchestrator commitment ——「無形軍師」5 obligations 嘅 architectural manifesto** (Pillar 2 + Pillar 1 + Pillar 3 supporting framing):

軍師需要知戰場狀態 (obligation b: `EnemyState{hp, max_hp, defense, faction, instance_id}` struct provision)、需要骰子做決策 (obligation c: `RandomNumberGenerator` 注入 seeded on `transition_id`)、需要傳令官 (obligation d: 3 broadcast signal emit on CombatResolver's behalf)、需要鎮場令唔好亂 (obligation e: anomaly rate-limit 10/sec/reason + AOE-catch-up serialization per #13 Rule 18)、需要聽戰況 (obligation a: `ability_cast` signal subscription via Contract 6)。5 obligations 唔係 abstract architecture contract，係軍師職責清單 — architecture as narrative。Combat math 嘅 anti-fabrication quartet (per #13 Section B 三件套 + 第四件套) 喺 caller-side 由 EnemyDirector 嘅 RNG injection discipline (FR-3 below) 守住：軍師唔可以偷骰子 (RNG seed 必須 `hash(transition_id)`，唔可以 `randf()`)、唔可以偷 stat (StatSnapshot pattern Rule 6 of #13 enforce)、唔可以偷 abilities (AbilityRegistry.tres data-driven，CI lint 防靜默 schema drift)。**Pillar 1 anti-fabrication chain 由 #11 input guarantor → #13 output guarantor → #14 orchestration discipline guarantor → #15 loot rarity chain seed 一條 propagate 全程**。

### Falsifiable Tests

呢條 fantasy 嘅 testable promises — 任何路徑引致以下情境 = bug，唔係 acceptable behavior：

1. **Pillar 4 wave archetype readability gate** (most direct test of「軍師排兵」): 俾 3 個唔識 game 嘅 tester 各睇 10 秒 push wave / pull wave / leg wave silent gameplay (mute audio + hide HUD)，請佢哋估邊個係邊類動作日訓練。命中率 < 60% (3-class baseline = 33%；60% = significantly-above-chance threshold) → ❌ wave variation signature 唔夠 readable，Pillar 4 Muscle = Class enactment 失效 → wave archetype visual differentiation 須加強 (silhouette / palette / movement pattern 三軸分離)
2. **Pillar 2 boss anchor latency gate** (Frictionless receptive contract): 跑 100 次完整 workout session，記錄 `workout_completed` event timestamp 同 boss visible-on-screen frame timestamp 嘅 delta。p95 delta > 500ms → ❌ Pillar 2 receptive contract 破裂，boss 變偷襲 — 玩家「最後一 rep」嘅 emotional climax 同 boss 出場錯位，「為你戰鬥」嘅 evidence 缺失 → fallback per FR-2 (pre-spawn off-screen + workout_completed commit-trigger)
3. **Pillar 1 determinism replay gate** (anti-fabrication chain integrity): 同一 `transition_id` seed replay 同一 workout session，wave sequence + enemy spawn position + boss entry frame 必須 byte-identical。任何 frame divergence → ❌ 軍師變賭徒，#13 anti-fabrication quartet 第四件套 (output guarantor) 之上 #14 orchestration discipline guarantor 一層 缺失，整條 Pillar 1 chain 破。CI test `tests/integration/enemy_director/test_replay_determinism.gd` 跑 1000 個 replay pair byte-compare
4. **5-obligation availability gate** (architectural promise to #13 FR-4): CombatResolver any-time-query 5 obligations 全部 available — `_enemy_state_pool.get(instance_id)` 永遠 return non-null for live targets / `_rng_factory.create(transition_id)` 永遠 return seeded RNG / 3 signal emitter 永遠 connected / anomaly rate-limiter 永遠 enforced / `ability_cast` subscription 永遠 alive。任何 obligation 喺 100k-event 壓力 test 失約 → ❌ 軍師失職，戰場崩潰，#13 GDD 嘅 FR-4 Risk Register fallback path (5-obligation redesign) 啟動 — `tests/integration/enemy_director/test_5_obligations_availability.gd` 跑 stress test
5. **Mobile particle floor preservation gate** (Pillar 3 spectacle vs Pillar 2 budget tension): iPhone 12 (ADR-001 reference hardware) + iOS 17+ Safari、8-enemy AOE + LootDrop particle burst 同時觸發、frame time > 33ms (30fps floor) 持續 > 3 frames → ❌ 軍師為 spectacle 犧牲基礎，Pillar 3 Drop Euphoria spectacle 直接破壞 Pillar 2 Frictionless promise。Auto-degrade rules (Section C Rule + Section G `caller_mult` adaptive throttle knob) 必觸發保護 — `tests/performance/enemy_director/test_mobile_particle_floor.gd` benchmark gate

### Fantasy Risk Register

呢個「無形軍師」framing 係 contingent on 以下 invariants 喺 **ADR-001 ratification + ADR-002 ratification + GymSys polling cadence + autoload boot order Q-Boot-Order** 真正 enforced；否則 Player Fantasy 變 retroactive lie。

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | Wave archetype 3-class visual differentiation (silhouette / palette / movement) 必夠強，3 個 ability class 嘅 wave 玩家瞄一眼分得出 (Falsifiable Test #1 binding ≥60% accuracy) | art-director + `EnemyRegistry.tres` art spec authoring (post-art-bible) | 若 silhouette 唔夠分 → 加 colour-coded outline (push=紅厚甲 / pull=藍薄甲 / leg=綠快速)，CI lint check `EnemyRegistry.tres` 每 archetype 必含 `primary_outline_color` 字段 |
| FR-2 | Boss anchor latency ≤ 500ms p95 — `workout_completed` event arrival 嗰刻 boss 必須已 visible spawn (Falsifiable Test #2 binding) | #14 + ADR-002 GymSys integration timing | Pre-spawn boss off-screen 喺 final-set 預測 frame (用 `#9 Workout State Tracker` `set_progress > 0.8` heuristic)，`workout_completed` event arrival 時 just play 入場動畫 — event 用嚟 commit + visible reveal，唔係用嚟 trigger 整個 spawn cycle |
| FR-3 | EnemyDirector RNG injection 完全 seeded on `transition_id` derived hash，禁止任何 `randf()` / `Time.get_ticks_msec()` / wall-clock seed 入 wave generator 或 spawn position 計算 (per #13 Rule 7 + Pillar 1 anti-fabrication chain integrity) | 本 GDD Rule + CI lint `tools/ci/check_enemy_director_randf.gd` | 若 non-deterministic seed 入 wave / spawn / target-select path → Falsifiable Test #3 fail → Pillar 1 chain 破；fallback = blocking story to remove all non-deterministic source from `src/core/enemy_director.gd` 之前 ship 任何 release |
| FR-4 | Particle dispatch overload 自動 throttle — multi-enemy 同 frame 死亡觸發 LootDrop particle，#14 caller_mult adaptive 計算保證 ≤ 200 mobile particle cap (Falsifiable Test #5 binding) | 本 GDD Section C Rule + ADR-001 ratification | Rate-limiter on particle spawn (max N concurrent emitters per frame from Section G knob `MAX_CONCURRENT_PARTICLE_EMITTERS`)，超出嘅 queue 到下 frame；ADR-001 budget cap 強制；若 mobile 仍 spike → drop caller_mult 自 1.5 至 1.0 即時 emergency throttle |
| FR-5 | Anomaly rate-limiter 唔可以 silent fail — CombatResolver 出 1000 個 anomaly/sec，#14 rate-limiter throttle 但**必 emit `combat_metric_anomaly(aggregate: true, dropped_count: N)`** 反映 drop count，唔可以 drop 到 #28 Telemetry 完全唔知 (per #13 Rule 17 + EC-47 aggregate emit obligation) | 本 GDD Section C Rule 17 binding + qa-lead AC | rate-limiter 必須 emit aggregate signal at window end；CI test `tests/integration/enemy_director/test_anomaly_aggregate_emit.gd` verify 100 same-reason anomaly within 1 second → #28 收到 ≤ 11 個 signal (10 + 1 aggregate)，aggregate signal `dropped_count` 字段 ≥ 90 |

**Ratification gate binding**: 本 GDD 嘅 Section C / D / H 必須 include FR-1 / FR-2 / FR-3 / FR-4 / FR-5 對應嘅 rules + ACs (gated on ADR-001 Accepted + ADR-002 Accepted + Q-Boot-Order resolution)。若 ADR-001 ratification 後 particle cap 改變 → revisit Section C Rule for particle dispatch throttle + Section H AC for FR-5 threshold。

## Detailed Design

### Core Rules

#### Rule 1 — Caller-side state owner architecture (Autoload + state containers)

EnemyDirector 用 `class_name EnemyDirector extends Node` 註冊為 autoload，**擁有全部 caller-side hidden state**，補 CombatResolver pure-function purity 之不足 (Rule 1 of #13 inverse design)。

- **State 必 own 喺本 class instance** (8 containers):
  - `_catch_up_queue: Array[CombatContext]` — Rule 7 below (catch-up × AOE serialization queue)
  - `_anomaly_rate_tracker: Dictionary[StringName, RateWindow]` — Rule 6 sliding-window counter per `reason` enum value
  - `_enemy_state_pool: Dictionary[int, EnemyState]` — instance_id → EnemyState struct lookup (Rule 3 obligation b)
  - `_killed_dedupe_set: Dictionary[int, bool]` — `enemy_killed` once-only guard (Rule 15)
  - `_spawn_pool: Dictionary[StringName, PackedScene]` — preloaded enemy template scenes per `EnemyRegistry.tres`
  - `_rng_factory: RNGFactory` — Rule 4 seeded RNG provisioner
  - `_active_wave: WaveDescriptor` — Rule 12 current wave archetype descriptor
  - `_boss_anchor_state: BossAnchorState` — Rule 13 pre-spawn + commit state machine
- **Inverse of #13 Rule 1**: #13 stateless pure-function；#14 stateful chokepoint。互補設計 — purity 嘅 mathematical chokepoint vs orchestration 嘅 state chokepoint = clean separation
- **CI enforcement**: `tools/ci/check_enemy_director_state_locality.gd` — 上述 8 個 state container 必 declared 喺 `EnemyDirector` class body 而**唔可以**移去其他 class (防 silent state leak)
- **Serves**: Falsifiable Test #4 (5-obligation availability gate)

#### Rule 2 — `ability_cast` signal subscription via Contract 6 helper (#13 FR-4 obligation a)

訂閱 `#12 AbilitySystem.ability_cast(ability_id, caster, target)` 必經 ADR-006 Contract 6 `connect_for_initial_state` helper，**禁止 raw `connect()` call**。

- **Subscription site** (in `_ready()`, **LAST line** — defense against partial init):
  ```gdscript
  func _ready() -> void:
      _init_state_containers()       # Rule 1 state
      _wire_downstream_signals()     # Rule 5
      GameStateMachine.connect_for_initial_state(
          self, &"_on_state_changed", &"state_changed"
      )                              # Rule 10 gate
      AbilitySystem.connect_for_initial_state(
          self, &"_on_ability_cast", &"ability_cast"
      )                              # MUST be LAST line of _ready
  ```
- **CI enforcement**: `tools/ci/check_enemy_director_signal_subscription.gd` — AST scan reject 任何 `AbilitySystem.ability_cast.connect(...)` raw call；必 `connect_for_initial_state` helper
- **Serves**: Falsifiable Test #4 + #13 FR-4 obligation (a)

#### Rule 3 — `EnemyState` struct provision (#13 FR-4 obligation b)

EnemyDirector 喺 `_on_ability_cast` handler 內為每個 target 組裝 `EnemyState`，傳入 `CombatContext.target_state`:

```gdscript
class EnemyState extends RefCounted:
    var instance_id: int          # target.get_instance_id() — for dedupe + signal payload
    var enemy_id: StringName      # enemy template id (e.g., &"STRIKE_MOB_TIER_1") — for #15 loot table
    var hp: int                   # current HP — #13 Rule 4 Stage 1 input validation: hp > 0
    var max_hp: int               # template MAX_HP — #13 Rule 10 damage_tier ratio 分母
    var defense: int              # template DEF — #13 Formula 1 damage compute
    var faction: Faction          # PLAYER / ENEMY / BOSS / NEUTRAL — AOE friendly-fire filter
```

`enum Faction { PLAYER, ENEMY, BOSS, NEUTRAL }` declared in `EnemyDirector` (per Q-Faction-Schema decision)。

- **Source of truth**: `_enemy_state_pool` (Rule 1) — spawn 時 insert，despawn 時 erase
- **Mutation rule**: 收到 #13 `HitResult.target_hp_after` 後即時 update pool 內對應 EnemyState.hp
- **CI enforcement**: `tools/ci/check_enemy_state_fields.gd` — 6-field schema lock，新增 field 須對應 schema bump

#### Rule 4 — RNG factory: seeded on `transition_id` (FR-3 binding + #13 FR-4 obligation c)

EnemyDirector 持有 `_rng_factory: RNGFactory`，唯一 RNG 來源；**禁止任何 `randf()` / `Time.get_ticks_msec()` / wall-clock seed**:

```gdscript
class RNGFactory extends RefCounted:
    static func create(transition_id: String) -> RandomNumberGenerator:
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(transition_id)              # per ADR-005 + #13 Rule 7
        return rng

    static func create_sub(transition_id: String, sub_key: String) -> RandomNumberGenerator:
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("%s:%s" % [transition_id, sub_key])
        return rng
```

- **Combat RNG path**: 每次 `_on_ability_cast` handler 內 `var rng := _rng_factory.create(transition_id)`，注入 `CombatContext.rng` (per #13 Rule 7)
- **Non-combat RNG paths**: wave spawn position jitter (sub_key=`"wave_spawn_%d" % wave_seq`) + boss anchor entrance position (sub_key=`"boss_anchor"`) + MOBILITY_MOB lateral dodge offset (sub_key=`"dodge_%d" % enemy_instance_id`)
- **CI enforcement (2-layer)**:
  - `tools/ci/check_enemy_director_randf.gd` — AST scan reject `src/core/enemy_director.gd` 內任何 non-deterministic seed source
  - `tools/ci/check_rng_factory_purity.gd` — `RNGFactory` class body reject 任何 non-deterministic source
- **Serves**: FR-3 + Falsifiable Test #3 (determinism replay gate) + #13 FR-4 obligation (c) + #13 Rule 7 binding

#### Rule 5 — 3 broadcast signal emit (#13 FR-4 obligation d)

EnemyDirector autoload **唯一** declare + emit 以下 3 signals (NO others):

```gdscript
signal hit_resolved(payload: HitResolvedPayload)               # per #13 Rule 8
signal enemy_killed(payload: EnemyKilledPayload)               # per #13 Rule 9
signal combat_metric_anomaly(payload: CombatAnomalyPayload)    # per #13 Rule 13
```

Payload class definitions inherit from #13 GDD Rule 8/9/13 (NOT redefined — single source of truth at #13)。

- **Emit order** (sequential 喺 `_on_ability_cast` handler 內):
  1. `hit_resolved` per target (AOE 多 emit)
  2. `enemy_killed` if `HitResult.is_kill == true` AND `_killed_dedupe_set.has(instance_id) == false` (Rule 15 idempotency)
  3. `combat_metric_anomaly` if input validation fail OR Rule 6 rate-limit pass
- **CI enforcement**: `tools/ci/check_enemy_director_signal_emission.gd` — verify **exactly 3** `signal` declarations + emit 經本 instance (非 transit other autoload)
- **Serves**: #13 FR-4 obligation (d) + Falsifiable Test #4

#### Rule 6 — Anomaly rate-limiter (FR-5 binding + #13 FR-4 obligation e)

實現 #13 Rule 17 obligation — sliding-window rate counter per reason:

- **Window**: 1 second rolling per `reason: StringName` enum value (6 reasons: GSM_SUSPENDED / INVALID_ABILITY_ID / NEGATIVE_DAMAGE / CLAMP_TRIGGERED / DEAD_TARGET_RESOLVE / RNG_INJECTION_MISSING + future-extension reasons)
- **Cap**: 10 emits per window per reason
- **Aggregate emit**: window 結束時若 `dropped_count > 0` → emit 1 個 aggregate `combat_metric_anomaly` `{reason: <original>, dropped_count: N, aggregate: true}`
- **Context dump cap**: payload `context_dump: Dictionary` serialize size > 10KB → truncate + add `{truncated: true}`
- **CI test**: `tests/integration/enemy_director/test_anomaly_aggregate_emit.gd` — 100 same-reason anomaly within 1s → #28 收到 ≤ 11 signal (10 + 1 aggregate)，aggregate `dropped_count ≥ 90`
- **Serves**: FR-5 (must not silent fail) + #13 FR-4 obligation (e) + #13 Rule 17 binding

#### Rule 7 — Catch-up × AOE serialization (#13 Rule 18 binding + FR-3 budget protection)

實現 #13 Rule 18 obligation — mutual exclusion serialization:

- **Detection trigger**: `_catch_up_queue.size() > 0` AND new ability_cast `target_type == AOE_RADIUS`
- **Default path (a)**: AOE cast defer 入 `_catch_up_queue` tail，等 catch-up drain 先 process
- **Drain cadence**: `_process` 每 frame max `CATCH_UP_HITS_PER_FRAME_CAP = 12` (per #13 Section G knob) hits pop + process
- **Implementation guard**:
  ```gdscript
  func _on_ability_cast(ability_id, caster, target) -> void:
      var ability_def = AbilityRegistry.get(ability_id)
      if _catch_up_queue.size() > 0 and ability_def.target_type == TargetType.AOE_RADIUS:
          _catch_up_queue.append(_build_ctx(ability_id, caster, target))
          return  # Rule 7 / #13 Rule 18 serialization defer
      _process_cast_immediate(ability_id, caster, target)
  ```
- **CI test**: `tests/integration/combat/test_catch_up_aoe_mutex.gd` — catch-up 期間 8-target AOE cast → AOE 喺 catch-up drain 完成後先 process
- **Serves**: #13 FR-4 obligation (e) + #13 Rule 18 binding + FR-3 budget protection

#### Rule 8 — Per-cast StatSnapshot building (#13 Rule 6 obligation)

每次 `_on_ability_cast` handler 內 snapshot `#11 StatSystem.get_stat()` **一次性**：

```gdscript
func _build_stat_snapshot() -> StatSnapshot:
    var s := StatSnapshot.new()
    s.attack_power = StatSystem.get_stat(&"ATTACK_POWER")
    s.crit_chance = StatSystem.get_stat(&"CRIT_CHANCE")
    return s
```

- **AOE invariant**: 同一 ability_cast 嘅 N 個 AOE target 共用同一 `caster_stats` snapshot (per #13 Rule 6 mid-cast stat drift防護)
- **Enemy caster path** (per Q-Enemy-Stat-Source decision): enemy attacks 嘅 `caster_stats` 由 `EnemyTemplateRegistry.tres` synthesize (`{attack_power, crit_chance}` per template)，**NOT** read via `#11 StatSystem.get_stat()` — `#11` 只 own player avatar stat
- **CI enforcement**: `tools/ci/check_enemy_director_stat_calls.gd` — verify `src/core/enemy_director.gd` 內 `StatSystem.get_stat()` calls 全部喺 `_build_stat_snapshot()` 內

#### Rule 9 — Boot order: position N (LAST among combat-relevant autoloads)

EnemyDirector autoload 喺 `project.godot` `[autoload]` section 排 **after** 以下:

```
position 1: PersistenceLayer (#3)
position 2: GameStateMachine (#1)
position 3-N: PlatformDetect / AudioManager / StatSystem (#11) / AbilitySystem (#12) /
              ParticleSystemWrapper (#5) / ScreenEffects (#6) / CameraSystem (#7) /
              LootDropSystem (#15) / Telemetry (#28)
position N+1: EnemyDirector (#14) — BOOTS LAST
```

- Per ADR-006 Contract 4 + #13 EC-43/EC-50 — 所有 upstream + downstream consumer ready 之後 wire signal
- **CI enforcement**: `tools/ci/check_autoload_boot_order.gd` — verify `project.godot` autoload order strict match expected sequence
- **Serves**: #13 EC-43/EC-50 (boot order lock) + Falsifiable Test #4 (late subscriber 唔會 miss initial events via Contract 6 helper)

#### Rule 10 — GSM Suspended gate (#13 Rule 12 propagation)

`_on_ability_cast` handler **第一步** check GSM Suspended:

```gdscript
func _on_ability_cast(ability_id, caster, target) -> void:
    var gsm_state := GameStateMachine.current_state  # sync read
    if gsm_state == &"Suspended":
        _emit_anomaly(&"GSM_SUSPENDED", ability_id, ...)  # rate-limited (Rule 6)
        return
    var ctx := _build_ctx(ability_id, caster, target, gsm_state)
    # ... continue normal pipeline
```

- **Snapshot priority**: `ctx.gsm_state = gsm_state` 傳入 CombatContext (per #13 Rule 12) — defense-in-depth redundancy
- **Serves**: #13 Rule 12 binding (caller-side enforcement) + multi-device session lock protection

#### Rule 11 — Particle dispatch concurrency cap + auto-degrade (FR-4 binding)

per ADR-001 200 mobile particle cap + #5 ParticleSystemWrapper `caller_mult` discipline:

- **Concurrency tracking**: `_concurrent_emitters: int` — increment on `#5.play()` call，decrement on emitter `finished` signal
- **Cap**: `MAX_CONCURRENT_PARTICLE_EMITTERS = 8` mobile / 16 desktop (Section G knob)
- **Overflow handling**:
  - Path (a) defer: 超出嘅 particle request queue to next frame (FIFO)
  - Path (b) degrade: 若 mobile frame_time > 33ms 持續 3 frames → emergency drop `caller_mult` 由 1.5 → 1.0
- **Auto-recovery**: frame_time recover 到 < 20ms 持續 60 frames → restore `caller_mult` 至 1.5
- **Detection mechanism** (rolling 3-frame window, NOT EWMA — emergency cutoff needs immediate response):
  ```gdscript
  const FRAME_TIME_BUDGET_MS = 33.0    # mobile 30fps floor
  const FRAME_TIME_SAMPLE_SIZE = 3
  var _frame_time_window: Array[float] = []

  func _is_throttle_active() -> bool:
      if _frame_time_window.size() < FRAME_TIME_SAMPLE_SIZE: return false
      for ft in _frame_time_window:
          if ft <= FRAME_TIME_BUDGET_MS: return false
      return true  # all 3 frames > 33ms → throttle
  ```
- **CI test**: `tests/performance/enemy_director/test_mobile_particle_floor.gd` — iPhone 12 + iOS 17+ Safari + 8-enemy AOE + LootDrop burst → frame_time ≤ 33ms
- **Serves**: FR-4 (particle dispatch overload throttle) + Falsifiable Test #5 (mobile particle floor preservation gate)

#### Rule 12 — Wave archetype selection (data-driven from `EnemyRegistry.tres`, FR-1 binding)

Wave archetype 由 `#9 Workout State Tracker.get_dominant_ability_class()` driven，data-driven 查 `EnemyRegistry.tres`:

```gdscript
class EnemyRegistry extends Resource:
    @export var archetypes: Dictionary  # AbilityClass → WaveDescriptor

class WaveDescriptor extends Resource:
    @export var enemy_templates: Array[StringName]  # e.g., [&"STRIKE_MOB_T1", &"STRIKE_MOB_T2"]
    @export var spawn_cadence_sec: float            # default 4.0s, safe [3.0, 8.0]
    @export var archetype_cadence_mult: float       # STRIKE=1.0 / CONTROL=1.0 / MOBILITY=0.75
    @export var spawn_count_per_set: int            # default 6 mobile / 10 desktop
    @export var primary_outline_color: Color        # per FR-1 fallback
    @export var faction: Faction                    # ENEMY default; BOSS for boss subtype
```

**3 archetype mapping** (locked by FR-1):

| Player Ability Class | Wave Archetype | `faction` | Spawn Pool 來源 |
|---|---|---|---|
| `PUSH` (推日 / strike abilities) | **STRIKE_MOB** | `ENEMY` | `EnemyRegistry.tres → strike_pool` |
| `PULL` (拉日 / control abilities) | **CONTROL_MOB** | `ENEMY` | `EnemyRegistry.tres → control_pool` |
| `LEG` (腿日 / mobility abilities) | **MOBILITY_MOB** | `ENEMY` | `EnemyRegistry.tres → mobility_pool` |

> Per-archetype `EnemyState` baseline values (3-tier curve) — see **Wave Archetype Spec** subsection below。

- **CI lint**: `tools/ci/check_enemy_registry_schema.gd` — verify `EnemyRegistry.tres` 每 archetype 必含 `primary_outline_color` 字段 (FR-1 fallback)
- **Serves**: FR-1 (wave archetype 3-class readability) + Falsifiable Test #1 (≥60% silent-gameplay accuracy)

#### Rule 13 — Boss anchor: pre-spawn at `set_progress > 0.8` + commit on `workout_completed` (FR-2 binding)

**Predictive pre-spawn + late commit** pattern — 避 `workout_completed` event arrival 嗰刻先 spawn 引致延遲。

**BossAnchorState state machine** (own 喺 `_boss_anchor_state`):

```
IDLE → PRE_SPAWN (set_progress > 0.8 AND current_set == final_planned_set) →
COMMIT_PENDING (boss instance spawned off-screen) →
COMMITTED (workout_completed event arrives — visible reveal + focal entry) →
ENGAGED (boss in normal combat loop) → IDLE (boss dead)

Rollback paths:
  PRE_SPAWN → IDLE (set_progress drops < 0.8, e.g., player undo set)
  COMMIT_PENDING → IDLE (workout_abandoned event)
  any → IDLE (workout_abandoned)
```

**Pre-spawn trigger**:
```
WHEN  #9 WorkoutStateTracker.set_progress >= 0.8
  AND  current_set == final_planned_set
  AND  _boss_anchor_state == IDLE
THEN  pre_spawn_boss(off-screen X position)
      _boss_anchor_state = PRE_SPAWN
```

**Fallback** (if `#9 set_progress` not exposed at MVP): `reps_completed_in_set >= ceil(planned_reps * 0.5)` heuristic — flag for Open Question Q-9-SetProgress。

**Boss entry sequence** (deterministic frame order — `workout_completed` arrival frame):
```
Frame N (workout_completed event received, _boss_anchor_state == COMMIT_PENDING):
  Step 1: boss.visible = true
  Step 2: boss.ai_state = ENGAGE
  Step 3: Camera.focal_request(boss_target, 0.6s, "quart_ease_out")  # per #7 Rule 6
  Step 4: ScreenEffects.shake(amplitude=0.4, duration=0.08s)         # boss-tier trauma
  Step 5: ParticleSystem.play("BOSS_ENTRY", boss.global_position, caller_mult=1.2)
  Step 6: _boss_anchor_state = COMMITTED → ENGAGED (next frame)
```

**Edge case A — Workout 中途放棄**:
```
WHEN  GSM transitions to &"WorkoutAbandoned"
THEN  despawn_boss_silently()        # 唔 play BOSS_ENTRY，唔 emit boss_encounter_started
      cancel_wave_scheduler()
      _boss_anchor_state = IDLE
```

**Edge case B — Light workout (1-2 sets)**:
```
WHEN  total_planned_sets <= 2  # light workout threshold (Section G knob)
THEN  spawn_mini_boss (using boss pool 嘅 mini tier，唔係 final boss)
      Camera.focal_request duration = 0.4s     # vs full 0.6s
      ScreenEffects.shake amplitude = 0.25      # vs full 0.4
      ParticleSystem caller_mult = 1.0          # vs full 1.2
```

- **Latency budget**: PRE_SPAWN → COMMITTED 嘅 visible reveal latency ≤ 500ms p95 (FR-2)
- **#16 Boss System hand-off**: Rule 13 只 own anchor entry trigger；boss phase logic / HP transitions / phase-shift effects 全屬 #16 scope (provisional contract — #16 NOT YET DESIGNED)
- **CI test**: `tests/integration/enemy_director/test_boss_anchor_latency.gd` — 100 workout session，`workout_completed` 到 boss visible-on-screen frame delta p95 ≤ 500ms
- **Serves**: FR-2 + Falsifiable Test #2 (Boss anchor latency gate)

#### Rule 14 — MVP scope discipline (mirror #13 Rule 16 pattern)

v0.1 MVP 明確 OUT OF SCOPE，維 6-8 週 VS-tier realism:

| Feature | Defer to | Rationale |
|---|---|---|
| Multi-phase bosses (HP threshold → ability swap / arena shift / enrage timers) | **#16 Boss System** (NOT YET DESIGNED) | Boss phase logic 屬 boss system 內部 state machine |
| Enemy elites / champion modifiers (golden mob / shielded variant) | v0.2 | 需 modifier stacking rule + visual tier — break Falsifiable Test #1 3-class readability |
| Enemy cast abilities back at player (enemy strike / control / mobility 招式) | v0.2 + 需要 #12 enemy caster role | MVP 敵人純被動承受 damage — 簡化 #13 CombatContext 單向 flow |
| Spawn position randomness beyond simple X-axis lerp | v0.2 + NavigationAgent2D | MVP X-axis side-scroller only (per Overview) |
| Enemy-vs-enemy collision (physical pushback) | v0.2 | Mobile physics CPU budget tight (ADR-001) |
| Dynamic difficulty scaling (DDS) | v0.3+ | DDS 違 Pillar 1 anti-fabrication (難度 = 你嘅身體) |
| Wave RNG variation beyond `transition_id` seed | v0.2 | MVP 用 deterministic round-robin within archetype pool — preserve Falsifiable Test #3 byte-identical replay |
| Enemy aggro switching (threat-based target swap) | v0.2 | MVP enemy target = player avatar only |
| NavigationAgent2D pathfinding | v0.2 | MVP 用 X-axis lerp + `move_and_slide()` collision (per Rule 18 + engine-reference) |
| Friendly fire (faction-based PvE) | v0.2 | `EnemyState.faction` 已預留 hook |
| Damage falloff in AOE | v0.2 | Per #13 Rule 14 |
| Status effects on enemies (poison/burn/stun) | v0.2 | Per #13 Rule 16 |
| Dodge / evasion mechanic | v0.2 | Per #13 Rule 16 + Rule 5 |

#### Rule 15 — `enemy_killed` idempotency (once-per-instance guard, #13 Rule 9 binding)

per #13 Rule 9 idempotency invariant — `enemy_killed` 每 `enemy_instance_id` emit **exactly once**:

- **Dedupe set**: `_killed_dedupe_set: Dictionary[int, bool]` — instance_id → true 入 set 即標記已 emit
- **Guard logic**:
  ```gdscript
  if hit_result.is_kill and not _killed_dedupe_set.has(target.get_instance_id()):
      _killed_dedupe_set[target.get_instance_id()] = true
      enemy_killed.emit(_build_enemy_killed_payload(...))
  ```
- **Race scenario**: same-frame double-cast (AOE × catch-up) → first call 入 set + emit；second call check pool → `_enemy_state_pool[id].hp == 0` → #13 Rule 4 Stage 1 input validation reject → return + emit `combat_metric_anomaly(reason=DEAD_TARGET_RESOLVE)`，**唔重複 emit `enemy_killed`**
- **Cleanup**: enemy despawn 後 erase from set (防 long-session memory leak — 1000+ killed mob accumulation)
- **CI test**: `tests/integration/enemy_director/test_enemy_killed_idempotent.gd` — same-frame 2× resolve_hit on same target → exactly 1 `enemy_killed` emit + 1 `combat_metric_anomaly(DEAD_TARGET_RESOLVE)`
- **Serves**: #13 Rule 9 idempotency + #15 LootDrop double-roll 防護 (per ADR-005 Pillar 1 chain)

#### Rule 16 — Enemy lifecycle: spawn → despawn cleanup

防 `_enemy_state_pool` / `_killed_dedupe_set` long-session memory leak:

- **Spawn flow**:
  1. `_active_wave` 喺 cadence interval 觸發 → `_rng_factory.create_sub(transition_id, "wave_spawn_%d" % wave_seq)` 用 sub-RNG roll spawn position jitter
  2. instantiate enemy scene from `_spawn_pool[enemy_id]`
  3. add `EnemyState{instance_id, enemy_id, hp=max_hp, ...}` to `_enemy_state_pool`
  4. wire `enemy.tree_exited` signal → `_on_enemy_despawned(instance_id)`
- **Despawn flow** (`_on_enemy_despawned(instance_id)`):
  1. `_enemy_state_pool.erase(instance_id)`
  2. `_killed_dedupe_set.erase(instance_id)`
- **Leak detection**: `_active_wave` end → pool 必為空，否則 emit `combat_metric_anomaly(reason=POOL_LEAK)` + auto-cleanup orphan entries
- **CI test**: `tests/integration/enemy_director/test_pool_cleanup.gd` — spawn 100 enemy → kill all → verify pool + dedupe set 兩個 empty
- **Serves**: browser memory budget 512MB ceiling + Falsifiable Test #4 (long-session resilience)

#### Rule 17 — Per-enemy AI state machine (6 states, event-driven hit-feel)

每個 enemy node 持有自己 `_state: EnemyAIState` enum (NOT centralized in EnemyDirector — 避 8-enemy × per-frame state polling 0.4ms baseline overhead):

```gdscript
enum EnemyAIState {
    SPAWNING,    # spawn animation 播緊 + collision disabled；唔接受 hit
    IDLE,        # off-screen 或 leash exit；唔 pursue 唔 attack
    PURSUING,    # avatar X-distance ≤ PERCEPTION_RANGE，X-axis locomotion 收近
    ATTACKING,   # melee range 內，attack animation + 觸發自己 ability_cast emission
    STAGGERED,   # hit_resolved.damage_tier ≥ HEAVY 觸發，short freeze
    DYING,       # HP ≤ 0，play death animation + dispatch DEATH particle
}
```

**Transition matrix** (event-driven, NOT polling — hit-feel 16ms latency requirement):

| From | To | Trigger |
|------|----|---------|
| (boot) | SPAWNING | `EnemyDirector._spawn_enemy()` (Rule 12 wave cadence) |
| SPAWNING | IDLE | spawn animation done (timer `SPAWN_DURATION = 0.4s`) |
| IDLE | PURSUING | avatar X-distance ≤ `PERCEPTION_RANGE = 600 px` (4Hz perception batch from EnemyDirector — Rule 18) |
| PURSUING | IDLE | avatar X-distance > `LEASH_RANGE = 900 px` (hysteresis vs 600) |
| PURSUING | ATTACKING | avatar X-distance ≤ `MELEE_RANGE = 80 px` AND `_attack_cooldown == 0` |
| ATTACKING | PURSUING | attack animation done AND avatar 仍喺 perception 範圍 |
| ATTACKING | IDLE | attack animation done AND avatar 超 LEASH_RANGE |
| (any non-DYING) | STAGGERED | `hit_resolved` payload `damage_tier ≥ HEAVY` AND target_id == self.instance_id |
| STAGGERED | PURSUING | stagger duration done (`STAGGER_DURATION_BY_TIER`: HEAVY=0.15s / CRITICAL=0.30s) |
| (any non-DYING) | DYING | `hit_resolved` payload `is_kill == true` AND target_id == self.instance_id |
| DYING | (despawn) | death animation done (`DEATH_DURATION = 0.6s`) → `queue_free()` |

- **Enemies cast abilities** (decision per Q-Enemy-Cast-Mode): ATTACKING state mid-animation frame call `AbilitySystem.cast_ability(ability_id, self, avatar)` — 經 #12 + #13 chain (`caster_stats` 由 `EnemyTemplateRegistry.tres` synthesize per Rule 8 enemy caster path)。Hardcoded contact damage 違反 Pillar 1 anti-fabrication quartet 因為繞過 #13 chokepoint，**NOT permitted**。
- **NO behavior trees** in MVP — 6-state FSM 已 cover side-scroller scope；BT defer to v0.2 (boss phase / mini-boss script driver)
- **Serves**: Pillar 1 anti-fabrication chain (enemy attacks 經 same #13 chokepoint)

#### Rule 18 — Tick architecture: hybrid (per-enemy locomotion + EnemyDirector batch perception 4Hz)

**Per-enemy node** owns its own `_physics_process(delta)` for **PURSUING locomotion only** (X-axis lerp toward `_cached_avatar_distance`):

```gdscript
# Enemy node — own _physics_process for locomotion only
func _physics_process(delta: float) -> void:
    match _state:
        EnemyAIState.PURSUING:
            _do_locomotion(delta)              # See locomotion formula below
        # other states: timer-driven, no per-frame work
```

**EnemyDirector autoload** owns **4Hz batch perception update** (250ms cadence) — single Avatar position read distributed to all enemy `_cached_avatar_distance` field:

```gdscript
const PERCEPTION_TICK_HZ = 4.0  # 4Hz cadence — 250ms latency tolerance for side-scroller
var _perception_tick_accumulator: float = 0.0

func _physics_process(delta: float) -> void:
    _perception_tick_accumulator += delta
    if _perception_tick_accumulator >= 1.0 / PERCEPTION_TICK_HZ:
        _perception_tick_accumulator = 0.0
        _batch_perception_update()         # update all enemy._cached_avatar_distance
    _drain_particle_dispatch_queue()       # Rule 11 throttle
    _drain_catch_up_queue()                # Rule 7 catch-up serialization
```

**Locomotion formula** (per-enemy X-axis):

```gdscript
# In Enemy node _physics_process(delta) — state == PURSUING:
var avatar_x = _cached_avatar_position.x  # from EnemyDirector perception batch
var direction = sign(avatar_x - global_position.x)
var current_speed_x = velocity.x
var target_speed = direction * _template_move_speed  # from EnemyTemplateRegistry.tres
var accel_rate = MOVE_ACCEL_PX_PER_SEC2  # = 1200 px/s² (Section G knob)
current_speed_x = move_toward(current_speed_x, target_speed, accel_rate * delta)
velocity.x = clamp(current_speed_x, -ENEMY_MOVE_CAP, ENEMY_MOVE_CAP)  # ENEMY_MOVE_CAP = MOVE_CAP = 420 (per Q-Enemy-Move-Cap)
velocity.y = 0.0  # X-axis only — Y reserved for v0.2 jump
move_and_slide()
```

- **Predictable budget**: 8 enemy × (~0.02ms locomotion + ~0.005ms state check) + 1 EnemyDirector (~0.05ms perception batch + ~0.05ms queue drain) = ~0.3ms typical — well under ADR-001 0.5ms EnemyDirector orchestration budget
- **`process_mode` discipline**: enemy nodes default `PROCESS_MODE_PAUSABLE` → 自然受 GSM Suspended pause；EnemyDirector autoload 亦 `PAUSABLE`
- **Serves**: ADR-001 CPU budget binding + Falsifiable Test #4 (5-obligation availability under load)

---

### Wave Archetype Spec (FR-1 binding — supplements Rule 12)

Per Rule 12 mapping，3 archetype 嘅 `EnemyState` baseline values 跨 3-tier curve (Starter sets 1-3 / Mid sets 4-8 / Endgame sets 9+ — tier boundaries 為 placeholder pending #15/#16 GDD calibration)。Tier 跟 logarithmic-ish progression (Starter→Mid ≈ 2.5× / Mid→Endgame ≈ 2.4×) — 對齊 #13 Formula 1 worked example calibration。

#### STRIKE_MOB — 推日「舉盾抗推」

| 字段 | Starter | Mid | Endgame | Rationale |
|---|---|---|---|---|
| `max_hp` | 80 | 220 | 540 | 高 HP 配合 push class burst-damage profile — 玩家覺得「打得實」 |
| `defense` | 8 | 18 | 32 | **3 archetype 中 highest** — strike-resist signature |
| Movement | 0.6× base (slow approach) | 0.6× base | 0.6× base | 慢推進 — silhouette readability time window 加長 (Falsifiable Test #1) |
| `_template_move_speed` | 120 px/s | 120 | 120 | Slow tank — fixed regardless of tier |
| Silhouette | **闊厚** (盾型 outline) | 同 | 同 | FR-1 — 紅厚甲 outline (`primary_outline_color = Color.RED`) |
| Death particle preset | `STRIKE_DEATH` (盾碎飛裂) | 同 | 同 | `caller_mult = 1.0` baseline |

> Rationale: push class 自身已係 high-attack output；如果敵人都係 glass cannon，戰場變雙方 1-hit-kill blender。Defense-tank 設計提供「抗住你」嘅 receptive 對手。

#### CONTROL_MOB — 拉日「Fragile Burst」

| 字段 | Starter | Mid | Endgame | Rationale |
|---|---|---|---|---|
| `max_hp` | 35 | 95 | 230 | **3 archetype 中 lowest** — 配合 pull class sustain-low-damage profile，多 hit 多 sustain reward |
| `defense` | 2 | 5 | 10 | Lowest defense — pull 唔需 burst，但要感覺「殺得快」 |
| Movement | 1.0× base | 1.0× base | 1.0× base | 中速 — 標準節奏 baseline |
| `_template_move_speed` | 90 px/s | 90 | 90 | Slow caster — fixed |
| Silhouette | **幼長** (薄甲 outline) | 同 | 同 | FR-1 — 藍薄甲 outline (`primary_outline_color = Color.BLUE`) |
| Death particle preset | `CONTROL_DEATH` (sticky AOE 0.3s residue — **無 damage**，純 cosmetic) | 同 | 同 | Pull class「拖延戰場」signature — MVP **唔做 lingering AOE damage** (per #13 Rule 14 AOE 1-to-1) |

> Rationale: pull abilities (#12) 屬 control class，cast 頻率較低 + per-cast damage moderate；對手必須**死得乾脆**先有 satisfaction loop。

#### MOBILITY_MOB — 腿日「Lateral Dodge」

| 字段 | Starter | Mid | Endgame | Rationale |
|---|---|---|---|---|
| `max_hp` | 55 | 145 | 360 | 中等 HP — 介乎 STRIKE / CONTROL 之間 |
| `defense` | 4 | 10 | 20 | 中等 defense |
| Movement | 1.4× base + **lateral X-axis dodge** (每 1.5s 隨機 X-axis offset ±0.5m，**RNG seed = `_rng_factory.create_sub(transition_id, "dodge_%d" % instance_id)`** per FR-3) | 同 | 同 | 「走位」signature — but determinism preserved |
| `_template_move_speed` | 280 px/s | 280 | 280 | Fast harasser — 仍 ≤ ENEMY_MOVE_CAP = 420 |
| Spawn cadence | **0.75× base interval** | 同 | 同 | leg day 戰場「動態壓力」感 |
| Silhouette | **窄高** (細長 outline) | 同 | 同 | FR-1 — 綠快速 outline (`primary_outline_color = Color.GREEN`) |
| Death particle preset | `MOBILITY_DEATH` (dash-trail 散) | 同 | 同 | `caller_mult = 1.0` |

> Rationale: leg class 對應「移動關卡」(game-concept §Short-Term Loop)，敵人多 + 快動 = readable「跑步機」戰場。

#### Encounter Pacing (Rule 12 supplement)

- **`BASE_SPAWN_INTERVAL = 4.0s`** (Section G knob, safe [3.0, 8.0]) — aligned 玩家 deadlift cooldown 45s ÷ ~10 spawn = 個 set 之間恰好一波 mob
- `spawn_interval_seconds = BASE_SPAWN_INTERVAL × archetype_cadence_mult` (mult per archetype above)
- **`MAX_CONCURRENT_ENEMIES_ON_SCREEN = 6 mobile / 10 desktop`** (Section G knob) — 6 × ~30 particles/enemy ambient = 180 particles，留 20 headroom 畀 boss / LootDrop spike (per ADR-001 200 cap + FR-4)
- **REST_PERIOD handling** (per #1 GSM enum):
  ```
  WHEN  #1.current_state == &"RestPeriod"
  THEN  wave_scheduler.pause()                # 唔 spawn 新 mob
        existing_enemies.set_ai_state(IDLE)   # 唔追玩家 avatar，原地等
        # 玩家 cooldown 期間戰場「凝固」— Pillar 2「等緊你」visual cue
  ```
  **唔 despawn** — preserve「軍師按住戰局等你返嚟」continuity narrative (per Section B receptive contract)

### States and Transitions

EnemyDirector own **獨立 state machine** subordinate to #1 GSM。State 唔係 1:1 mapping GSM (#14 子狀態如 CatchingUp / BossEncounter pre-spawn 唔屬 GSM top-level)，但 **Suspended direct mirror GSM Suspended** + **BossEncounter triggered by GSM BossEncounter transition**。

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Booting** | `_ready()` running | `_ready()` complete (all 8 state containers init + 2 signal subscriptions wired via Contract 6) | Init state containers, preload `_spawn_pool` from `EnemyRegistry.tres`, wire signals — NO ability_cast processed |
| **Idle** | GSM in {Idle / WorkoutActive / RestPeriod} AND `_active_wave == null` | GSM `state_changed(to: "CombatActive")` arrives | 接 `ability_cast` 但無 active wave，無 enemy spawn；handler 仍 process player solo training animation effects，但 target list 為空 → 唔 emit `hit_resolved` |
| **WaveActive** | GSM `current_state == &"CombatActive"` AND `_active_wave != null` | Wave spawn_count 全部 killed OR `state_changed(to: "BossEncounter")` 提早 trigger | Per-frame: drain `_catch_up_queue` (Rule 7), spawn cadence tick, anomaly rate window walk, particle concurrency monitor (Rule 11) |
| **BossEncounter** | `_boss_anchor_state == COMMITTED` (Rule 13) — typically GSM `state_changed(to: "BossEncounter")` | Boss instance `tree_exited` (boss dead OR cleaned up) | Wave spawn paused, boss attached to camera focal, special particle budget reservation (caller_mult=1.2)，#16 Boss System takes over phase logic |
| **CatchingUp** | `_catch_up_queue.size() > 0` (bfcache resume backlog) | `_catch_up_queue.size() == 0` | Sub-state of WaveActive — Rule 7 mutex applied (defer AOE), `CATCH_UP_HITS_PER_FRAME_CAP=12` throttle, 視覺 VFX 可 collapse but damage application exact + ordered |
| **Suspended** | GSM `state_changed(to: "Suspended")` arrives (multi-device session force-boot) | GSM exits Suspended | All `_on_ability_cast` rejected (Rule 10 gate)，emit `combat_metric_anomaly(GSM_SUSPENDED)` rate-limited，pause wave cadence + boss anchor timer，preserve `_enemy_state_pool` for resume |

**Transition diagram** (text):
```
Booting → Idle  (boot complete)
Idle ↔ WaveActive  (CombatActive ↔ wave depleted)
WaveActive → BossEncounter  (boss anchor commit per Rule 13)
WaveActive → CatchingUp  (bfcache resume backlog detected)
CatchingUp → WaveActive  (queue drained)
BossEncounter → Idle  (boss dead — GSM transitions to LootDrop then RestPeriod)
{Any except Booting} → Suspended  (GSM Suspended arrives)
Suspended → {previous state}  (GSM exits Suspended)
```

**Per-enemy AI state machine** (separate from EnemyDirector's) per Rule 17 — 6 states with event-driven transitions。Per-enemy state lives on enemy node instance，唔 centralize 喺 EnemyDirector。

### Interactions with Other Systems

| # | System | Direction | API / Signal Used | Key Ownership | Notes |
|---|--------|-----------|-------------------|---------------|-------|
| **#1** | GameStateMachine (Approved) | subscribes + reads | `state_changed(from, to, payload)` via Contract 6; sync read `current_state` + `current_transition_id` | #1 owns state lifecycle + transition_id atomicity (ADR-006 Contract 2) | Rule 2 subscription site; Rule 4 RNG seed source; Rule 10 Suspended gate; Rule 13 BossEncounter commit trigger |
| **#5** | Particle System Wrapper (Approved) | direct caller | `play(preset_id, position, caller_mult)` | #5 owns particle lifecycle + 200 mobile cap auto-degrade (Rule 9 of #5) | Rule 11 concurrency monitor; Rule 13 BOSS_ENTRY burst (caller_mult=1.2); per-enemy SPAWN_BURST on wave cadence (caller_mult=0.8); Wave Archetype Spec death presets |
| **#6** | Screen Effects (Approved) | direct caller | `shake(intensity, duration)` + `hit_pause(duration)` | #6 owns trauma model + camera offset shader uniform | Rule 13 boss-tier shake (0.4, 0.08s); damage_tier-based shake routing via #25 (downstream chain, not direct from #14) |
| **#7** | Camera System (Approved) | direct caller | `focal_request(target_node, duration, easing)` | #7 owns Camera2D position/zoom/make_current (autoload chokepoint per ADR-001) | Rule 13 boss focal entry (0.6s quart ease-out per #7 Rule 6) |
| **#9** | Workout State Tracker (NOT YET DESIGNED) | reads + subscribes | `get_dominant_ability_class() -> AbilityClass`; `set_progress: float` (read); `workout_completed` signal subscription | #9 owns workout phase + set progress + completion event | Rule 12 wave archetype selection; Rule 13 boss pre-spawn trigger (set_progress > 0.8) + commit trigger (workout_completed)。**PROVISIONAL** — `set_progress` field 未 #9 GDD 鎖死；fallback per Rule 13 (50% reps of final set heuristic) |
| **#11** | Stat System (Approved) | reads (via snapshot) | `get_stat(stat_id) -> float` (sync, O(1)) | #11 owns stat values + `apply_stat_delta` chokepoint | Rule 8 per-cast snapshot pattern; ATTACK_POWER + CRIT_CHANCE only; **player avatar 專屬** — enemy caster path 行 `EnemyTemplateRegistry.tres` synthesize (per Q-Enemy-Stat-Source) |
| **#12** | Ability System (Approved) | subscribes + reads | `ability_cast(ability_id, caster, target)` signal via Contract 6; `AbilityRegistry.tres` lookup for `{target_type, aoe_radius_px, base_damage_multiplier}` | #12 owns ability registry + cast lifecycle | Rule 2 primary subscription; Rule 7 AOE_RADIUS detection via registry; Rule 12 archetype routing; Rule 17 enemy caster path。**CROSS-SYSTEM FORWARD CONSTRAINT FR-Q-F2** inherited from #13 — `base_damage_multiplier` schema extension propagate to #12 GDD revision |
| **#13** | CombatResolver (Approved) | direct caller (static) | `CombatResolver.resolve_hit(ctx: CombatContext) -> HitResult` (static func per #13 Rule 2) | #13 owns damage math purity + 5-stage pipeline | Sole damage chokepoint per Rule 1 CI lint; **5 obligations to #13 FR-4 全部 fulfilled at this site** (Rules 2 / 3 / 4 / 5 / 6+7) |
| **#15** | LootDrop System (Pre-MVP tier order 17, NOT YET DESIGNED) | emits (downstream) | `enemy_killed(payload: EnemyKilledPayload)` signal | **#15 NOT YET DESIGNED — provisional contract** | Rule 5 emit; FR-2 of #13 binding — `transition_id` field propagate as #15 RNG seed (ADR-005)。**[[autoload-boot-order]]**: #15 must boot BEFORE #14 (per #13 EC-43 + Rule 9) |
| **#16** | Boss System (VS tier order 12, NOT YET DESIGNED) | emits (downstream) + integrates | `enemy_killed` + `hit_resolved` signals; Rule 13 anchor hand-off | **#16 NOT YET DESIGNED — provisional contract** | Rule 13 boundary — #14 owns anchor entry trigger only, #16 owns phase logic + HP transitions + enrage |
| **#17** | Equipment & Inventory (MVP tier order 23, NOT YET DESIGNED) | indirect (via #11 stat aggregation) | #17 applies equipment modifiers to #11 stats BEFORE EnemyDirector reads | #17 owns equipment data + lifecycle; #14 sees post-equipment stats only (via #11) | Inherits #13 FR-Equipment-AntiSnowball forward constraint — equipment ATK ≤ 3× stat ATK invariant flag to #17 GDD authoring |
| **#20** | Gym-Mode HUD (MVP tier order 25, NOT YET DESIGNED) | emits (downstream) | `hit_resolved(payload: HitResolvedPayload)` signal | **#20 NOT YET DESIGNED — provisional contract** | Rule 5 emit; damage number popup rendering downstream consumer |
| **#25** | Combat Visual Feedback (MVP tier order 29, NOT YET DESIGNED) | emits (downstream) | `hit_resolved(payload: HitResolvedPayload)` signal | **#25 NOT YET DESIGNED — provisional contract** | Rule 5 emit; routes `damage_tier` → particle preset + popup color per #13 Rule 8 FR Test #4 binding |
| **#28** | Telemetry (Pre-MVP tier order 21, NOT YET DESIGNED) | emits (downstream) | All 3 signals: `hit_resolved` + `enemy_killed` + `combat_metric_anomaly` | **#28 NOT YET DESIGNED — provisional contract** | Rule 5 emit; Rule 6 anomaly aggregate emit critical channel; FR-5 binding (silent fail prevention)。**[[autoload-boot-order]]**: #28 must boot BEFORE #14 (per #13 EC-50 + Rule 9)。**[[28-recursion-guard]]** inherited from #13 EC-49 |

**Provisional contract caveat**: #9 / #15 / #16 / #17 / #20 / #25 / #28 全部 NOT YET DESIGNED — 本 GDD 鎖死 signal payload schema (per Rule 5 inherit from #13 Rule 8/9/13)，下游 GDD authoring 時須 match 呢個 contract，唔可以 redesign payload。

### CI Lint Suite (mirror #13 Rule 1 4-layer defense, inverse focus — state ownership + chokepoint discipline)

| # | CI Script | What It Checks | Layer |
|---|-----------|----------------|-------|
| 1 | `tools/ci/check_enemy_director_chokepoint.gd` | AST scan `src/core/enemy_director.gd` — all damage compute MUST go via `CombatResolver.resolve_hit()`; reject inline arithmetic resembling damage math (e.g., `caster.attack_power * 1.5`, `target.hp -= ...`) | Chokepoint discipline |
| 2 | `tools/ci/check_enemy_director_randf.gd` | Reject any `randf(` / `randi(` / `randf_range(` / `Time.get_ticks_msec(` / direct `RandomNumberGenerator.new()` outside `RNGFactory` class body — all RNG MUST go via `_rng_factory` | RNG anti-fabrication (Rule 4 FR-3) |
| 3 | `tools/ci/check_enemy_director_signal_emission.gd` | Verify exactly 3 `signal` declarations: `hit_resolved` / `enemy_killed` / `combat_metric_anomaly` — no extras, no missing | Signal surface lock (Rule 5) |
| 4 | `tools/ci/check_enemy_director_signal_subscription.gd` | All `AbilitySystem.ability_cast` + `GameStateMachine.state_changed` subscriptions MUST use `connect_for_initial_state` helper — reject raw `.connect()` | Contract 6 subscription discipline (Rule 2) |
| 5 | `tools/ci/check_enemy_director_stat_calls.gd` | All `StatSystem.get_stat()` calls in `enemy_director.gd` MUST be inside `_build_stat_snapshot()` method body | Stat snapshot discipline (Rule 8 + #13 Rule 6) |
| 6 | `tools/ci/check_enemy_director_state_locality.gd` | Verify 8 state containers declared in EnemyDirector class body, NOT migrated to other classes | State locality (Rule 1) |
| 7 | `tools/ci/check_enemy_registry_schema.gd` | Verify `EnemyRegistry.tres` schema — every WaveDescriptor entry has required fields incl. `primary_outline_color` | Data-driven schema lock (Rule 12 FR-1) |
| 8 | `tools/ci/check_autoload_boot_order.gd` | Verify `project.godot` `[autoload]` section — EnemyDirector boots LAST among combat-relevant autoloads | Boot order (Rule 9) |
| 9 | `tools/ci/check_rng_factory_purity.gd` | Verify `RNGFactory` class body reject non-deterministic seed sources (`Time` / `OS` / `Engine.get_process_frames` / wall-clock) | RNG factory purity (Rule 4) |
| 10 | `tools/ci/check_boss_anchor_state_transitions.gd` | `BossAnchorState` enum transitions whitelist — only allow legal transitions (IDLE → PRE_SPAWN → COMMIT_PENDING → COMMITTED → ENGAGED + rollback paths) | Boss anchor state machine (Rule 13) |
| 11 | `tools/ci/check_particle_concurrency_cap.gd` | `MAX_CONCURRENT_PARTICLE_EMITTERS` 必須 `const` 唔可以 `var` (防 runtime drift unbounded) | Concurrency cap constant lock (Rule 11) |
| 12 | `tools/ci/check_enemy_template_move_cap.gd` | Verify `EnemyRegistry.tres` 任何 entry `_template_move_speed ≤ ENEMY_MOVE_CAP=420` (INV-7 cross-system binding) | Enemy MOVE_CAP discipline (Rule 18) |

## Formulas

EnemyDirector 嘅 formula family — 6 條 orchestration math layer，唔重複 #13 CombatResolver 嘅 damage math (per Rule 1 chokepoint discipline + CI lint enforcement)。所有 formulas 用 `static func` (where possible) 或 instance method `var`-free，O(1) compute，無 allocation (RefCounted struct refs only)，符合 ADR-001 EnemyDirector orchestration 0.5ms p95 mobile budget binding。**Damage formulas (compute_hit_damage / roll_crit / classify_damage_tier / detect_overkill) 全部 owned by #13 — 唔喺本 GDD 重複**。

### Formula 1: `actual_spawn_interval` — Wave spawn cadence (Rule 12 supplement)

**Rationale**: 4.0s baseline align 玩家 deadlift cooldown 45s ÷ ~10 spawn = 個 set 之間恰好一波 mob — wave readable density without spam (per game-designer Pacing analysis)。Archetype-specific multiplier 體現 Pillar 4 day-flavor (MOBILITY 腿日「動態壓力」更頻密)。

`actual_spawn_interval = BASE_SPAWN_INTERVAL × archetype_cadence_mult`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `BASE_SPAWN_INTERVAL` | I_b | float | [3.0, 8.0] sec | Section G knob, default 4.0 |
| `archetype_cadence_mult` | μ_a | float | {0.75, 1.0} | STRIKE=1.0 / CONTROL=1.0 / MOBILITY=0.75 (data-driven via `EnemyRegistry.tres`) |
| `actual_spawn_interval` | I_a | float | [2.25, 8.0] sec | Output |

**Output Range**: [2.25, 8.0] sec at default knob; tightest = MOBILITY mid-knob (4.0 × 0.75 = 3.0 sec)。

**Cross-knob invariants**:
- `BASE_SPAWN_INTERVAL ≥ 3.0` (避免 spam — Pillar 2 attention-budget violation)
- `archetype_cadence_mult ≥ 0.75` (avoid sub-3-sec interval combinatorial — MAX_CONCURRENT_ENEMIES_ON_SCREEN=6 mobile cap 容易破)

**Worked Examples**:
- STRIKE_MOB default: 4.0 × 1.0 = 4.0s → 1 set (45s deadlift cooldown) spawn ~11 mob
- MOBILITY_MOB default: 4.0 × 0.75 = 3.0s → 1 set spawn ~15 mob — leg day faster pressure
- CONTROL_MOB default: same as STRIKE (1.0 mult) — pull day baseline tempo

### Formula 2: `mobility_dodge_offset` — MOBILITY_MOB lateral X-axis dodge (Wave Archetype Spec + FR-3 binding)

**Rationale**: MOBILITY_MOB「lateral dodge」signature 用 deterministic RNG 提供 visible 走位 variation 但保 replay byte-identical (FR-3 anti-fabrication chain integrity)。Per-instance sub-RNG 避免 multi-mob 共享 seed 引致全部同步 dodge degenerate。

`dodge_offset_x = sub_rng.randf_range(-DODGE_AMPLITUDE_PX, +DODGE_AMPLITUDE_PX)`

`where sub_rng = _rng_factory.create_sub(transition_id, "dodge_%d" % instance_id)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `transition_id` | t_id | String | UUID-like | GSM `current_transition_id` |
| `instance_id` | i_id | int | [0, ∞) | enemy `.get_instance_id()` — per-instance disambiguation |
| `DODGE_AMPLITUDE_PX` | A | float | [25.0, 100.0] | Section G knob, default 50.0 (≈ 0.5m at 100px/m) |
| `dodge_interval_sec` | T_d | float | [0.5, 3.0] | Section G knob, default 1.5 (re-roll every 1.5s) |
| `dodge_offset_x` | δ_x | float | [-50.0, +50.0] | Output offset applied to PURSUING X velocity |

**Output Range**: ±50px at default DODGE_AMPLITUDE_PX；replay deterministic per `(transition_id, instance_id, _process_time_bucket)` triple key。

**Cross-knob invariants**:
- `DODGE_AMPLITUDE_PX × 2 < MELEE_RANGE = 80 px` (dodge 唔可以將 mob 推出 melee range，否則永遠 ATTACKING ↔ PURSUING flicker)
- `dodge_interval_sec ≥ 0.5` (sub-second flicker = motion sickness risk — Pillar 2 a11y protection)

### Formula 3: `is_throttle_active` — Particle dispatch auto-degrade detection (Rule 11 supplement, FR-4 binding)

**Rationale**: Rolling 3-frame window simple-mean threshold (NOT EWMA) — emergency cutoff needs immediate response (1 frame spike OK from GC/texture upload；3 consecutive = real budget breach)。

```
is_throttle_active = (
    len(_frame_time_window) >= FRAME_TIME_SAMPLE_SIZE
    AND  all(ft > FRAME_TIME_BUDGET_MS for ft in _frame_time_window)
)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `_frame_time_window` | W | Array[float] | size [0, 3] | Last N frame times (msec) |
| `FRAME_TIME_BUDGET_MS` | B | float | [25.0, 50.0] | Section G knob, default 33.0 (mobile 30fps floor) |
| `FRAME_TIME_SAMPLE_SIZE` | N | int | [2, 6] | Section G knob, default 3 (rolling window size) |
| `is_throttle_active` | b_t | bool | {true, false} | Output — drives `caller_mult` adjustment |

**Output Range**: boolean — single-bit decision per frame。

**Cross-knob invariants**:
- `FRAME_TIME_BUDGET_MS ≥ 25.0` (低過 25ms = 40fps strict floor，正常 GC pause 都會 trigger false-positive throttle)
- `FRAME_TIME_SAMPLE_SIZE ∈ {2, 3, 4}` (size > 4 = latency too long，throttle 嚟得太遲；size < 2 = single-frame spike false-positive)

**Recovery formula**:
```
is_recovery_ready = (
    len(_recovery_window) >= RECOVERY_SAMPLE_SIZE
    AND  all(ft < FRAME_TIME_RECOVERY_MS for ft in _recovery_window)
)
```

Defaults: `FRAME_TIME_RECOVERY_MS = 20.0` (hysteresis vs budget 33.0) / `RECOVERY_SAMPLE_SIZE = 60` frames (1 sec at 60fps)。

### Formula 4: `rate_limit_check` — Anomaly emit sliding-window cap (Rule 6 supplement, FR-5 binding)

**Rationale**: Sliding 1-second window per `reason` — prevent infinite-loop anomaly emission flooding telemetry; aggregate emit ensures #28 知道 drop count，唔靜默失敗。

```
rate_limit_check(reason: StringName, now_ms: int) -> bool:
    var window = _anomaly_rate_tracker[reason]
    # Evict timestamps outside [now_ms - 1000, now_ms]
    while window.timestamps.size() > 0 and now_ms - window.timestamps[0] > RATE_WINDOW_MS:
        window.timestamps.pop_front()
    if window.timestamps.size() >= RATE_CAP_PER_REASON:
        window.dropped_count += 1
        return false  # rejected — caller does NOT emit signal
    window.timestamps.append(now_ms)
    return true  # accepted — caller emits signal
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `RATE_WINDOW_MS` | W_ms | int | [500, 5000] | Section G knob, default 1000ms (1s sliding window) |
| `RATE_CAP_PER_REASON` | C_r | int | [3, 50] | Section G knob, default 10 (per #13 Rule 17) |
| `now_ms` | t | int | [0, ∞) | Frame stable ms timestamp (`Time.get_ticks_msec()`) |
| `dropped_count` | D | int | [0, ∞) | Tracking counter for aggregate emit |
| `rate_limit_check` | b | bool | {true, false} | Output |

**Output Range**: boolean — accept/reject decision。

**Aggregate emit trigger**:
```
WHEN window.timestamps[0] expires (oldest > RATE_WINDOW_MS old)
  AND  window.dropped_count > 0
THEN emit combat_metric_anomaly({reason, dropped_count: window.dropped_count, aggregate: true})
     window.dropped_count = 0
```

**Cross-knob invariants**:
- `RATE_WINDOW_MS ≥ 500` (sub-500ms window = anomaly burst 之間 throttle 釋放太快，rate-limiter 失效)
- `RATE_CAP_PER_REASON × 6_reasons ≤ #28 ingestion rate cap` (1 sec window × 6 reasons × 10 cap = 60 signals/sec — #28 telemetry queue 必能承受)

### Formula 5: `boss_pre_spawn_trigger` — Boss anchor predictive pre-spawn (Rule 13 supplement, FR-2 binding)

**Rationale**: Pre-spawn off-screen 喺玩家 emotional climax window (final-set 最後 20% reps) — preserve workout_completed event arrival 嗰刻 visible reveal latency ≤ 500ms p95。

```
boss_pre_spawn_trigger(set_progress, current_set, final_planned_set, _boss_anchor_state) -> bool:
    return (
        _boss_anchor_state == BossAnchorState.IDLE
        AND  current_set == final_planned_set
        AND  set_progress >= PRE_SPAWN_THRESHOLD
    )
```

**Fallback formula** (if #9 `set_progress` not exposed at MVP):
```
boss_pre_spawn_trigger_fallback(reps_completed_in_set, planned_reps_in_set, current_set, final_planned_set, _boss_anchor_state) -> bool:
    return (
        _boss_anchor_state == BossAnchorState.IDLE
        AND  current_set == final_planned_set
        AND  reps_completed_in_set >= ceil(planned_reps_in_set * PRE_SPAWN_FALLBACK_REPS_FRAC)
    )
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `set_progress` | p_s | float | [0.0, 1.0] | From `#9 WorkoutStateTracker.set_progress` (PROVISIONAL — Q-9-SetProgress) |
| `PRE_SPAWN_THRESHOLD` | T_ps | float | [0.6, 0.95] | Section G knob, default 0.8 |
| `PRE_SPAWN_FALLBACK_REPS_FRAC` | F_r | float | [0.4, 0.7] | Section G knob, default 0.5 (fallback path) |
| `current_set` | s_c | int | [1, ∞) | From `#9.current_set` |
| `final_planned_set` | s_f | int | [1, ∞) | From `#9.total_planned_sets` |
| `boss_pre_spawn_trigger` | b_pst | bool | {true, false} | Output |

**Output Range**: boolean — single-bit decision per perception tick (4Hz)。

**Cross-knob invariants**:
- `PRE_SPAWN_THRESHOLD ≥ 0.6` (太早 pre-spawn = boss instance 浪費 memory 太長時間，rollback path 機率上升)
- `PRE_SPAWN_FALLBACK_REPS_FRAC ≤ 0.7` (fallback path 50% reps 已係 safety margin，不可遲過 70%)

### Formula 6: `enemy_locomotion_step` — Per-enemy X-axis movement (Rule 18 supplement)

**Rationale**: `move_toward` 提供 weight feel (vs instant lerp robotic feel)；hard clamp 維 INV-7 cross-system binding (ENEMY_MOVE_CAP ≤ camera follow speed)。Y velocity = 0 維 MVP X-axis side-scroller scope。

```
velocity.x_new = clamp(
    move_toward(velocity.x_old, direction × _template_move_speed, MOVE_ACCEL_PX_PER_SEC2 × delta),
    -ENEMY_MOVE_CAP, +ENEMY_MOVE_CAP
)
velocity.y_new = 0.0
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `direction` | d | int | {-1, 0, +1} | `sign(avatar_x - global_position.x)` |
| `_template_move_speed` | v_t | float | [60.0, 350.0] | Per-archetype value (STRIKE=120, CONTROL=90, MOBILITY=280) from `EnemyTemplateRegistry.tres` |
| `MOVE_ACCEL_PX_PER_SEC2` | a | float | [600.0, 2400.0] | Section G knob, default 1200.0 |
| `delta` | δ | float | [0, MAX_FRAME_DELTA=0.1] | Frame delta clamped per #6/#7 shared constant |
| `ENEMY_MOVE_CAP` | V_max | float | [300.0, 500.0] | Section G knob, default 420 (alias to #11 `MOVE_CAP`) |
| `velocity.x_new` | v_x | float | [-420, +420] | Output X velocity |

**Output Range**: X velocity bounded by ENEMY_MOVE_CAP；Y velocity hard 0。

**Cross-knob invariants**:
- `ENEMY_MOVE_CAP ≤ MOVE_CAP=420` (INV-7 cross-system — #11 player MOVE_CAP shared, prevents enemy outrunning camera focus)
- `MOVE_ACCEL_PX_PER_SEC2 × 0.35s ≥ max(_template_move_speed)` (acceleration must reach max template speed within 350ms — feel weight without sluggish)
- `MOBILITY_MOB._template_move_speed = 280 < ENEMY_MOVE_CAP = 420` ✓ (default values within cap)

**Worked Examples**:
- STRIKE_MOB (v_t=120) standing → pursue: 0 → 120 px/s in ~100ms (move_toward 1200 × 0.1 = 120 reached frame 6)
- MOBILITY_MOB (v_t=280) reverse direction: -280 → +280 in ~470ms — visible「轉身」weight feel
- All values clamped to ENEMY_MOVE_CAP=420 — Open Question Q-Enemy-Move-Cap reserved for v0.2 boost above cap

### Formula Family Integration

完整 EnemyDirector tick / handler pipeline (per Rule 18 hybrid architecture):

```
EnemyDirector._physics_process(delta):
    1. _drain_catch_up_queue(delta)              # Rule 7 — max 12 hits/frame
    2. _drain_particle_dispatch_queue(delta)     # Rule 11 — max 8 emitters/frame mobile
    3. _frame_time_window.append(...)            # Formula 3 — auto-degrade detection
    4. _perception_tick_accumulator += delta     # Rule 18
    5. if _perception_tick_accumulator >= 1.0/PERCEPTION_TICK_HZ:
           _batch_perception_update()            # 4Hz — update all enemy._cached_avatar_distance
    6. _walk_anomaly_rate_windows(delta)         # Formula 4 — aggregate emit on window expiry
    7. _check_boss_anchor_state(delta)           # Formula 5 — pre-spawn trigger / commit / rollback
    8. _spawn_cadence_tick(delta)                # Formula 1 — wave spawn schedule

EnemyDirector._on_ability_cast(ability_id, caster, target):
    1. gsm_state = GameStateMachine.current_state            # Rule 10
    2. if gsm_state == &"Suspended": emit anomaly + return
    3. transition_id = GameStateMachine.current_transition_id
    4. rng = _rng_factory.create(transition_id)              # Formula 4 RNG
    5. snapshot = _build_stat_snapshot()                     # Rule 8 + Formula 0 (#11 Formula 4/6)
    6. targets = _expand_targets(ability_id, target)         # Rule 14 of #13 (MAX 8)
    7. for target in targets:
         ctx = _build_ctx(ability_id, caster, target, snapshot, rng, transition_id, gsm_state, hit_seq++)
         hit_result = CombatResolver.resolve_hit(ctx)        # #13 Formulas 1-5 chain
         _apply_hit_result(target, hit_result)               # Rule 3 — update _enemy_state_pool
         hit_resolved.emit(_build_payload(hit_result))       # Rule 5
         if hit_result.is_kill and not _killed_dedupe_set.has(target.get_instance_id()):
             _killed_dedupe_set[target.get_instance_id()] = true
             enemy_killed.emit(_build_killed_payload(hit_result))  # Rule 5 + Rule 15
         if hit_result.outcome == HitOutcome.ANOMALY:        # input validation fail
             if rate_limit_check(reason, now_ms):           # Formula 4
                 combat_metric_anomaly.emit(_build_anomaly_payload(hit_result))  # Rule 5 + Rule 6

Enemy node._physics_process(delta):
    if _state == PURSUING:
        velocity = enemy_locomotion_step(...)              # Formula 6
        move_and_slide()
```

**Total CPU budget** (analytic estimate, mobile reference):
- `_physics_process` overhead: ~0.05ms (perception batch 4Hz amortized + queue drains)
- `_on_ability_cast` handler: ~0.02ms × N AOE hits + 0.005ms snapshot/rng build
- Per-enemy locomotion: ~0.02ms × 8 active enemies = 0.16ms

Typical wave-active frame: 0.05 + 0.02 + 0.16 = ~0.23ms — well under ADR-001 0.5ms EnemyDirector orchestration budget ✓ (留 ~54% headroom for boss-encounter peak + multi-AOE catch-up worst-case)

Catch-up worst-case (12 hits/frame): 0.05 + 0.02×12 + 0.16 = ~0.45ms — 仍 within 0.5ms cap，但 leaves only 10% headroom — Falsifiable Test #4 + AC binding。

## Edge Cases

42 concrete edge cases，按 10 category 分組。每個 case 用「If [condition]: [exact resolution]」格式，明確指定 state change / signal emit / anomaly route — 唔用含糊「handle gracefully」字眼。Cross-references 用 [[autoload-boot-order]] / EC-NN format 對應 #13。

### E.1 `_on_ability_cast` Input Validation Edge Cases (Rule 10 + Rule 8)

- **EC-01 [Validation]**: If `_on_ability_cast` 收到 signal 期間 `GameStateMachine.current_state == &"Suspended"` → Rule 10 reject + emit `combat_metric_anomaly(reason=&"GSM_SUSPENDED")` (rate-limited per Rule 6)。唔 build CombatContext，唔 call CombatResolver。
- **EC-02 [Validation]**: If `_on_ability_cast` 收到 signal 期間 EnemyDirector state == `Suspended` (per States table) → 同 EC-01 處理，但 anomaly `context_dump` 加 `{enemy_director_state: "Suspended"}` 標記
- **EC-03 [Validation]**: If `_on_ability_cast` 收到 signal 期間 `_boss_anchor_state == ENGAGED` AND target == boss instance → 正常 process (boss combat 用 same chokepoint per Rule 1)。#16 Boss System 之後 own boss-specific phase logic
- **EC-04 [Validation]**: If `caster` parameter is null (caller bug — #12 emits malformed signal) → reject + emit `combat_metric_anomaly(reason=&"INVALID_ABILITY_ID", context_dump={caster: null})`，唔 build ctx
- **EC-05 [Validation]**: If `target` parameter is null for SINGLE-target ability → reject + emit anomaly `{reason: INVALID_ABILITY_ID, context_dump: {target: null}}`。AOE_RADIUS 容許 `target == null` (radius origin = caster position fallback — Rule 14 of #13)
- **EC-06 [Validation]**: If `ability_id` 唔屬 `AbilityRegistry.tres` lookup keys → reject + emit anomaly `{reason: INVALID_ABILITY_ID}`，唔 process
- **EC-07 [Validation]**: If `ability_id` 屬 registry 但 `base_damage_multiplier` field missing (schema migration gap pre-FR-Q-F2 propagation) → emit anomaly `{reason: INVALID_ABILITY_ID, context_dump: {schema_gap: "base_damage_multiplier missing"}}` + skip ctx build
- **EC-08 [Validation]**: If `caster.get_instance_id() == target.get_instance_id()` (enemy targeting self — caller logic bug) → reject + emit anomaly `{reason: DEAD_TARGET_RESOLVE, context_dump: {self_target: true}}`

### E.2 Wave Scheduling Edge Cases (Rule 12 + Formula 1)

- **EC-09 [Wave]**: If `#9 WorkoutStateTracker.get_dominant_ability_class()` returns `&"UNKNOWN"` (e.g., player 啱啱開 app，未有 workout data) → EnemyDirector defaults `STRIKE` archetype + emit `combat_metric_anomaly(reason=&"UNKNOWN_ABILITY_CLASS_FALLBACK")` (rate-limited)。Pillar 4 fallback — 比完全冇 wave 好 (Pillar 2 visible companion)
- **EC-10 [Wave]**: If `EnemyRegistry.tres` lookup returns `null` for current archetype (registry schema bug or migration gap) → log error + emit anomaly `{reason: REGISTRY_LOOKUP_NULL}` + skip current wave；EnemyDirector falls back to `Idle` state until next `state_changed(to: CombatActive)`
- **EC-11 [Wave]**: If `MAX_CONCURRENT_ENEMIES_ON_SCREEN = 6` cap reached → wave_scheduler.pause() spawn cadence；resume when `_enemy_state_pool.size() < cap`。No anomaly emit (legitimate cap behavior)
- **EC-12 [Wave]**: If player completes set faster than expected (rep cadence super-fast) → `BASE_SPAWN_INTERVAL = 4.0s` 仍 fixed，wave spawn 唔加速；mob density visible「跟唔上」屬 design feature (rare edge case)，唔 trigger anomaly
- **EC-13 [Wave]**: If GSM transitions to `RestPeriod` mid-wave (per #1 Decision #3) → wave_scheduler.pause()；existing enemies state → `IDLE` (per Rule 12 REST_PERIOD handling)；唔 despawn (preserve「軍師等緊你」narrative per Section B receptive contract)

### E.3 Boss Anchor Edge Cases (Rule 13 + Formula 5)

- **EC-14 [Boss Anchor]**: If `#9 set_progress` not exposed at MVP (Q-9-SetProgress open) → Formula 5 fallback path activates；CI test `tests/integration/enemy_director/test_boss_anchor_fallback.gd` 驗 50% reps heuristic 達到 ≤500ms p95 latency target
- **EC-15 [Boss Anchor]**: If player 喺 `_boss_anchor_state == PRE_SPAWN` 期間 undo set (set_progress drops < 0.8) → rollback path → `despawn_boss_silently()` + `_boss_anchor_state = IDLE`，唔 emit anomaly (legitimate rollback)
- **EC-16 [Boss Anchor]**: If `workout_completed` event arrives 但 `_boss_anchor_state == IDLE` (pre-spawn 漏 trigger — `#9 set_progress` 跳變過 0.8 太快) → emergency-spawn boss immediately + skip PRE_SPAWN phase + log `combat_metric_anomaly(reason=&"BOSS_EMERGENCY_SPAWN", context_dump={set_progress_at_completion: <value>})`。Latency 可能 > 500ms — flag for sprint backlog story improvement
- **EC-17 [Boss Anchor]**: If `workout_completed` event arrives 但 `_boss_anchor_state == COMMITTED` (already revealed — duplicate event) → idempotency guard skip second commit；emit anomaly `{reason: DUPLICATE_WORKOUT_COMPLETED}`
- **EC-18 [Boss Anchor]**: If player 喺 `_boss_anchor_state == ENGAGED` 期間 GSM transitions to `Suspended` (multi-device session lock) → preserve `_boss_anchor_state = ENGAGED`，boss instance freeze (PAUSABLE process_mode 自然 handle)；resume 時 boss 仍喺度
- **EC-19 [Boss Anchor]**: If `total_planned_sets <= 2` (light workout per game-designer C.2 Edge Case B) → spawn mini-boss 而唔係 final boss；Camera focal duration = 0.4s (vs 0.6s)；ScreenEffects shake = 0.25 (vs 0.4)；ParticleSystem caller_mult = 1.0 (vs 1.2)

### E.4 AOE Target Acquisition Edge Cases (Rule 14 of #13 caller-side)

- **EC-20 [AOE]**: If AOE `targets.size() == 0` (empty radius — legitimate "swing 揮空") → silent skip (per #13 EC-30)，唔 emit `hit_resolved` 唔 emit anomaly
- **EC-21 [AOE]**: If AOE `targets.size() > MAX_TARGETS_PER_CAST = 8` → distance-sort descending by `target.global_position.distance_squared_to(origin)`，clip to 8 nearest，emit `combat_metric_anomaly(reason=&"CLAMP_TRIGGERED", context_dump={requested: <size>, capped: 8})`
- **EC-22 [AOE]**: If AOE 包含 caster (faction match) → friendly-fire filter exclude (per Rule 3 EnemyState.faction check)；唔減 targets.size() cap (clip 仍 對其他 8 target apply)
- **EC-23 [AOE]**: If AOE 包含 DYING / SPAWNING state enemy (transitional non-attackable) → exclude from targets list；唔 trigger DEAD_TARGET_RESOLVE anomaly (transition state ≠ already-dead state)

### E.5 Catch-up Queue Edge Cases (Rule 7 + #13 Rule 18)

- **EC-24 [Catch-up]**: If bfcache resume backlog → 50 pending `ability_cast` events → FIFO drain 12/frame × 5 frames = 60 frame budget OK。Queue size monotonic decreasing，order preserved
- **EC-25 [Catch-up]**: If `_catch_up_queue.size() > CATCH_UP_QUEUE_HARD_CAP = 1000` (extreme backlog) → drop oldest events 至 1000 + emit `combat_metric_anomaly(reason=&"CLAMP_TRIGGERED", context_dump={queue_overflow: true, dropped: <count>})` — #13 EC-36 binding
- **EC-26 [Catch-up]**: If catch-up draining 期間 new AOE_RADIUS cast arrives (Rule 7 mutex trigger) → defer 入 queue tail；不可 immediate process (FR-3 budget protection per #13 INV-5)
- **EC-27 [Catch-up]**: If user closes tab mid-catch-up → page unload → queue lost is acceptable (#13 EC-37 binding)；下次 boot 由 #11 stat replay + GymSys differential cursor 重建 state，EnemyDirector cold-start

### E.6 Particle Dispatch Edge Cases (Rule 11 + Formula 3)

- **EC-28 [Particle]**: If 8 enemies AOE-die same frame (worst-case from #13 Rule 14 MAX_TARGETS_PER_CAST=8) → 8 × DEATH preset request → cap 6 immediate emit + 2 defer next frame (per Rule 11 path a)。Visual collapse acceptable (DNF AOE cluster 1-frame stagger 唔可見)
- **EC-29 [Particle]**: If `frame_time > 33ms` 持續 3 frames → throttle engage → `caller_mult` drop 1.5 → 1.0；emit `combat_metric_anomaly(reason=&"PARTICLE_THROTTLE_ENGAGED")` (rate-limited)
- **EC-30 [Particle]**: If throttle engaged but `frame_time recover < 20ms` 持續 60 frames (1s) → throttle release → `caller_mult` restore 1.5；emit `combat_metric_anomaly(reason=&"PARTICLE_THROTTLE_RELEASED")` (rate-limited)
- **EC-31 [Particle]**: If `MAX_CONCURRENT_PARTICLE_EMITTERS` knob 改成 `var` mid-runtime (CI lint Layer 11 violation) → CI fail 阻 commit；唔可能 reach production

### E.7 Anomaly Rate-Limiter Edge Cases (Rule 6 + Formula 4)

- **EC-32 [Rate-Limit]**: If 100 anomaly emit attempts of same reason 喺 1 sec → 10 emit pass + 90 drop。Window expiry 時 emit aggregate `{reason, dropped_count: 90, aggregate: true}` — #13 EC-47 binding
- **EC-33 [Rate-Limit]**: If `context_dump` serialize size > 10KB → truncate + 加 `{truncated: true}` field — #13 EC-48 binding
- **EC-34 [Rate-Limit]**: If anomaly handler 喺 #28 內部 trigger 另一 anomaly (recursion infinite loop) → #28 own recursion guard ([[28-recursion-guard]] per #13 EC-49 flag) — EnemyDirector 唔負責，純 emit signal fire-and-forget

### E.8 Per-Enemy AI State Machine Edge Cases (Rule 17)

- **EC-35 [Enemy AI]**: If enemy 喺 `STAGGERED` state 期間收到 second `hit_resolved` payload `damage_tier ≥ HEAVY` → 唔重複 trigger STAGGERED (already in state)；但 staggered duration 唔 extend (避免「無限 stunlock」degenerate — preserve combat pacing)
- **EC-36 [Enemy AI]**: If enemy 喺 `ATTACKING` state mid-animation 收到 `is_kill == true` hit → transition `DYING` 即時 (DYING 優先於 ATTACKING completion)；attack animation 中斷；ability_cast 唔 emit
- **EC-37 [Enemy AI]**: If enemy 喺 `PURSUING` state，avatar position 突然 teleport (e.g., dev tool debug) → `_cached_avatar_distance` 4Hz batch update 250ms latency；mid-window enemy 可能短暫「跑錯方向」— acceptable (Pillar 2 a11y argument — 玩家做 set 唔睇螢幕，唔覺)
- **EC-38 [Enemy AI]**: If enemy `tree_exited` signal fire (despawn) 期間 `_enemy_state_pool` 仍持有 entry → Rule 16 cleanup flow auto-erase；no leak
- **EC-39 [Enemy AI]**: If enemy state == `DYING` 期間 GSM transitions to `Suspended` → preserve DYING state (PAUSABLE process_mode)；resume 時 death animation continue from frozen frame

### E.9 Cross-System Boot / Lifecycle Edge Cases

- **EC-40 [Boot]**: If `_ready()` 期間 `AbilitySystem` autoload 未 ready (boot order violation) → Contract 6 `connect_for_initial_state` helper 自動 deferred subscription，late-bind 後 replay initial state — no missed events (per ADR-006 Contract 6 sentinel pattern)
- **EC-41 [Boot]**: If `#15 LootDrop` autoload 未 ready (boot order violation — should be position N-1) → CI lint `check_autoload_boot_order.gd` fail，阻 commit；production reach 唔到 (defense-in-depth)
- **EC-42 [Boot]**: If `project.godot` autoload section manually edited 至 wrong order → CI lint catch；運行時 `_ready()` 第一 step verify expected upstream autoload `is_node_ready()` true — false 則 abort + push_error

### E.10 RNG Determinism Edge Cases (Rule 4 + Formula 2)

- **EC-43 [RNG]**: If `transition_id` 含 unicode / special chars → `hash()` 接受任何 String，不會 collide (per #13 EC-28 binding)
- **EC-44 [RNG]**: If two enemies 同 frame spawn with same `instance_id` (Godot impossibility 但 defensive check) → `_rng_factory.create_sub(transition_id, "dodge_%d" % id)` 兩個 sub-RNG 同 seed → same dodge sequence — visible「同步走位」degenerate；emit anomaly `{reason: INSTANCE_ID_COLLISION}` + log
- **EC-45 [RNG]**: If `transition_id == ""` (empty string post-malformed GSM `state_changed` payload) → reject all ability_cast handling，emit anomaly `{reason: RNG_INJECTION_MISSING, context_dump: {transition_id: ""}}` (per #13 EC-10 binding)
- **EC-46 [RNG]**: If replay test 1000 iterations 任一 frame diverge → CI test `test_replay_determinism.gd` fail → release blocker (Pillar 1 chain integrity break — FR-3 binding)

### E.11 Memory / Long-Session Resilience Edge Cases

- **EC-47 [Memory]**: If session run > 1 hour，`_killed_dedupe_set` 累積 1000+ enemy instance_id → Rule 16 cleanup flow 喺 enemy despawn 時 erase；no leak
- **EC-48 [Memory]**: If `_anomaly_rate_tracker` 累積 unbounded `reason` enum values → enum locked to 6 reasons (Rule 6 spec)；reject unknown reasons at emit site (defense-in-depth) + log

### Coverage Cross-Reference

每條 EC 對應一條 Section H AC (見 Section H Coverage Matrix Summary)。Rule coverage:

| Rule | ECs |
|------|-----|
| Rule 1 (State owner) | EC-47, EC-48 |
| Rule 2 (Signal subscription) | EC-40 |
| Rule 3 (EnemyState struct) | EC-04, EC-05, EC-22 |
| Rule 4 (RNG factory) | EC-43, EC-44, EC-45, EC-46 |
| Rule 5 (3 signal emit) | EC-17 (idempotency cross-link) |
| Rule 6 (Anomaly rate-limiter) | EC-32, EC-33, EC-34 |
| Rule 7 (Catch-up × AOE mutex) | EC-24, EC-25, EC-26, EC-27 |
| Rule 8 (StatSnapshot) | (Rule 6 of #13 inherited) |
| Rule 9 (Boot order) | EC-40, EC-41, EC-42 |
| Rule 10 (GSM Suspended gate) | EC-01, EC-02 |
| Rule 11 (Particle concurrency cap) | EC-28, EC-29, EC-30, EC-31 |
| Rule 12 (Wave archetype) | EC-09, EC-10, EC-11, EC-12, EC-13 |
| Rule 13 (Boss anchor) | EC-14, EC-15, EC-16, EC-17, EC-18, EC-19 |
| Rule 14 (MVP scope) | (negative coverage — out-of-scope items absence verified via #13 Rule 16 propagation) |
| Rule 15 (enemy_killed idempotency) | EC-17 |
| Rule 16 (Enemy lifecycle cleanup) | EC-38, EC-47 |
| Rule 17 (Per-enemy AI FSM) | EC-35, EC-36, EC-37, EC-38, EC-39 |
| Rule 18 (Hybrid tick architecture) | EC-37 |

## Dependencies

EnemyDirector dependency surface — hard (system 唔可能 function without it) vs soft (enhanced by, but fallback graceful)，upstream provider + downstream consumer + cross-system invariant + forward constraint。具體 API + signal contract spec 見 Section C Interactions with Other Systems table (避免重複)；本 section 重點喺 dependency type + ownership + bidirectional sync gap。

### Upstream Dependencies (EnemyDirector consumes)

| # | System | Hard/Soft | Status | Critical Failure Mode |
|---|--------|-----------|--------|------------------------|
| **#1** GameStateMachine | Hard | Approved 2026-05-25 | Without `state_changed` subscription + `current_state` + `current_transition_id` reads → Rule 4 RNG seed unavailable → Pillar 1 chain break；fallback impossible |
| **#11** Stat System | Hard | Approved 2026-05-27 | Without `get_stat(ATTACK_POWER)` + `get_stat(CRIT_CHANCE)` → caster_stats snapshot (Rule 8) impossible → CombatResolver Rule 4 Stage 1 input validation fail；blocking |
| **#12** Ability System | Hard | Approved 2026-05-27 | Without `ability_cast` signal subscription → 0 hits processed；entire combat orchestration dead；blocking。**FR-Q-F2 forward constraint inherited from #13** — `base_damage_multiplier` schema extension propagate to #12 GDD revision |
| **#5** Particle System Wrapper | Soft | Approved 2026-05-26 | Without `play()` direct caller path → visual VFX missing but combat math 正常 (graceful degrade — Pillar 2 still works, Pillar 3 spectacle missing) |
| **#6** Screen Effects | Soft | Approved 2026-05-26 | Without `shake()` + `hit_pause()` → boss spawn moment + critical hit feedback missing but combat math 正常 (graceful degrade) |
| **#7** Camera System | Soft | Approved 2026-05-26 | Without `focal_request()` → boss entry「重頭戲嚟啦」cinematographic moment missing but combat math 正常 (graceful degrade)。**INV-7 cross-system binding** inherited from #11 — `ENEMY_MOVE_CAP ≤ MOVE_CAP=420` Rule 18 + Formula 6 binding |
| **#9** Workout State Tracker | Hard | NOT YET DESIGNED (VS tier order 11) | Without `get_dominant_ability_class()` + `set_progress` + `workout_completed` → wave archetype selection (Rule 12) + boss anchor (Rule 13) impossible；blocking。**PROVISIONAL CONTRACT** — fallback path per Rule 13 EC-14 (50% reps heuristic) if `set_progress` not exposed at MVP |
| **#13** CombatResolver | Hard | Approved 2026-05-27 | Without `CombatResolver.resolve_hit(ctx) -> HitResult` → no damage compute → entire combat dead；blocking。**5 obligations to #13 FR-4 全部 fulfilled at this site** |
| **ADR-001** Web Export Budget Caps | Hard (Proposed) | Particle cap 200 mobile + EnemyDirector orchestration 0.5ms p95 budget binding (Rule 11 + Rule 18) |
| **ADR-002** GymSys Integration Protocol | Soft (Accepted) | `ability_cast` events 由 GymSys polling cadence (5s ±0.5s jitter) 觸發；catch-up backlog cadence-bounded (Rule 7) |
| **ADR-005** Loot Rarity Formula | Hard (Accepted 2026-05-27) | `enemy_killed.transition_id` propagates as #15 RNG seed (FR-2 binding)；唔可斷 chain |
| **ADR-006** State Machine Contract | Hard (Accepted 2026-05-27) | Contract 2 (transition_id atomicity) + Contract 4 (sequential autoload `_ready()` lock #14 boots LAST) + Contract 6 (`connect_for_initial_state` helper)；唔可違反 |

### Downstream Consumers (EnemyDirector outputs)

| # | System | Hard/Soft | Status | Cross-System Invariant |
|---|--------|-----------|--------|------------------------|
| **#14 self-listen** (own emissions) | Hard | This GDD | EnemyDirector own state mutation post-hit_resolved (per Section C handler pipeline) |
| **#15** LootDrop System | Hard (indirect via `enemy_killed.transition_id`) | NOT YET DESIGNED (Pre-MVP tier order 17) | **FR-LootDrop-TransitionId** forward constraint inherited from #13 — `transition_id` field MUST 維持 String non-null；#15 GDD authoring 必 verify field usage 一致 with ADR-005 transition_id chain。**[[autoload-boot-order]]**: #15 boots BEFORE #14 per Rule 9 |
| **#16** Boss System | Hard | NOT YET DESIGNED (VS tier order 12) | Rule 13 boss anchor boundary — #14 owns anchor entry trigger only, #16 owns phase logic / HP transitions / enrage |
| **#17** Equipment & Inventory | Hard (indirect via #11 stat aggregation) | NOT YET DESIGNED (MVP tier order 23) | **FR-Equipment-AntiSnowball** forward constraint inherited from #13 — equipment-derived ATK ≤ 3× stat-derived ATK invariant |
| **#20** Gym-Mode HUD | Hard | NOT YET DESIGNED (MVP tier order 25) | `hit_resolved` payload `damage_dealt + damage_tier + is_crit` consumer for damage number popup |
| **#25** Combat Visual Feedback | Hard | NOT YET DESIGNED (MVP tier order 29) | `hit_resolved` payload `damage_tier` routing — FR Test #4 of #13 binding (MUST use damage_tier, 唔可以 re-derive based on damage value) |
| **#28** Telemetry / Analytics | Hard | NOT YET DESIGNED (Pre-MVP tier order 21) | All 3 signals subscriber；**[[28-recursion-guard]]** inherited from #13 EC-49 — #28 own recursion guard。**[[autoload-boot-order]]**: #28 boots BEFORE #14 per Rule 9。**FR-5 binding** — aggregate emit channel critical |

### Autoload Boot Order Requirement (cross-system invariant)

Per ADR-006 Contract 4 sequential autoload boot + #13 EC-43/EC-50 + Rule 9 of this GDD，autoload `_ready()` 順序 MUST 為:

```
position 1: #3 PersistenceLayer  (Approved Foundation — locked)
position 2: #1 GameStateMachine  (Approved Foundation — locked)
position 3: PlatformDetect       (per ADR-001 ratified position [3..N])
position 4-N: #2 GymSys / #4 AudioManager (NOT YET DESIGNED) / #11 Stat / #12 Ability /
              #5 Particle / #6 ScreenEffects / #7 Camera / #15 LootDrop (NOT YET DESIGNED) /
              #28 Telemetry (NOT YET DESIGNED)
position N+1: #14 EnemyDirector  (boots LAST among combat-relevant autoloads)
```

Rationale: per Rule 9 + #13 EC-43 + EC-50 — 所有 upstream provider + downstream consumer 必 ready 之前 EnemyDirector wire signal；否則 `enemy_killed` / `combat_metric_anomaly` listener 未 connect → silent drop。

### Cross-System Forward Constraints (FR-Author flags for future GDDs)

| FR ID | Scope | Constraint | Owner GDD (future) |
|-------|-------|------------|---------------------|
| FR-Q-F2 (inherited from #13) | #12 Ability System | `AbilityRegistry.tres` schema 加 `base_damage_multiplier: float` + `aoe_radius_px: float` fields | #12 next /design-system revision OR /propagate-design-change |
| FR-EnemyRegistry-Schema | #14 own | `EnemyRegistry.tres` schema lock — `enemy_templates / spawn_cadence_sec / archetype_cadence_mult / spawn_count_per_set / primary_outline_color / faction` mandatory fields | Resolved this GDD (Rule 12) |
| FR-EnemyTemplate-StatSource | #14 own | Enemy attack `caster_stats` source = `EnemyTemplateRegistry.tres` synthesize (NOT `#11 StatSystem.get_stat`) — per Q-Enemy-Stat-Source resolution | Resolved this GDD (Rule 8 + Rule 17) |
| FR-9-SetProgress | #9 Workout State Tracker | `set_progress: float` field exposure (range [0.0, 1.0]) for Rule 13 boss anchor pre-spawn trigger — fallback heuristic available if not exposed | #9 GDD authoring (VS tier order 11) |
| FR-Equipment-AntiSnowball (inherited from #13) | #17 Equipment | equipment-derived ATK ≤ 3× stat-derived ATK invariant | #17 GDD authoring |
| FR-LootDrop-TransitionId (inherited from #13) | #15 LootDrop | `enemy_killed.transition_id` propagate to `loot_rarity_score.rng_roll` seed | #15 GDD authoring |
| FR-Telemetry-RecursionGuard (inherited from #13) | #28 Telemetry | anomaly handler recursion guard | #28 GDD authoring |
| FR-Boss-PhaseLogic | #16 Boss System | Rule 13 boundary — #16 owns boss internal state machine post `_boss_anchor_state == ENGAGED` | #16 GDD authoring |
| FR-Autoload-BootOrder (inherited from #13) | Project-wide | #15 + #28 boot before #14 — per #13 EC-43 + EC-50 + ADR-006 Contract 4 | `project.godot` autoload section + CI lint Layer 8 |

### Bidirectional Consistency Check

| Cross-system | Bidirectional listing status |
|--------------|------------------------------|
| #1 GSM (Approved) | ⚠ #1 GDD 唔具體 list 每個 downstream consumer — universal Suspended gate convention；本 GDD 通過 Rule 10 + Rule 2 subscribe，唔需 #1 GDD revision |
| #11 Stat System (Approved) | ⚠ #11 Interactions table 唔具體 list #14 — `get_stat()` 屬 read-only API。**Flag for #11 next-revision batch** — add `#14 EnemyDirector — reads via per-cast snapshot` row to #11 Interactions (non-blocking — same as #13 listing) |
| #12 Ability System (Approved) | ⚠ #12 Interactions table 列出 `#13 CombatResolver — subscribes ability_cast`，但 ALIGN 本 GDD Rule 3 — actually #14 EnemyDirector subscribes (caller-side) per #13 Rule 3 redirect。**Flag for #12 next-revision batch** — fix #12 Interactions row to mention #14 (non-blocking) |
| #13 CombatResolver (Approved) | ✓ #13 Section F「Depended on by #14 EnemyDirector」listed；本 GDD Rules 1-18 ALIGN 5 obligations per #13 FR-4 |
| #5 / #6 / #7 (Approved) | ✓ direct caller pattern — no formal subscription, no bidirectional sync gap |
| #9 / #15 / #16 / #17 / #20 / #25 / #28 (NOT YET DESIGNED) | Forward constraints flagged per FR-Author table above |

## Tuning Knobs

EnemyDirector 嘅 owned knobs — 17 個 (10 個 orchestration knobs + 4 個 archetype knobs + 3 個 boss anchor knobs)。所有 knobs 用 `const` 喺 `src/core/enemy_director.gd` declared (per Rule 1 const allowed) 或 `EnemyRegistry.tres` data-driven entries。冇 designer-runtime tuning UI (敏感於 deterministic replay — runtime mutation 違反 Pillar 1)。

### Owned Knobs (本 GDD ownership)

| # | Knob name | Type | Default | Safe range | What breaks if too high | What breaks if too low | Source |
|---|-----------|------|---------|------------|--------------------------|--------------------------|--------|
| 1 | `BASE_SPAWN_INTERVAL` | float (sec) | **4.0** | [3.0, 8.0] | > 8: wave 太疏，「軍師排兵」evidence 缺，Pillar 2 frictionless 失效 | < 3: wave spam，Pillar 2 attention-budget violation + MAX_CONCURRENT cap 容易破 | Formula 1 |
| 2 | `MAX_CONCURRENT_ENEMIES_ON_SCREEN` | int (mobile) | **6** | [4, 8] | > 8: particle budget breach + Pillar 2 visual overload | < 4: wave 力量 dilute，Pillar 4 archetype signature 顯不出 | Rule 12 + Wave Archetype Spec |
| 3 | `MAX_CONCURRENT_ENEMIES_DESKTOP` | int | **10** | [6, 16] | > 16: desktop budget marginal benefit | < 6: desktop 唔比 mobile 多 headroom 違反 desktop 2× tier | Wave Archetype Spec |
| 4 | `MAX_CONCURRENT_PARTICLE_EMITTERS` | int (mobile) | **8** | [4, 12] | > 12: ADR-001 200 mobile particle cap 容易破 (12 × 25 particle/emitter = 300) | < 4: AOE 8-target same-frame death scenario 全部 defer 太多 visual collapse | Rule 11 |
| 5 | `FRAME_TIME_BUDGET_MS` | float (msec) | **33.0** | [25.0, 50.0] | > 50: throttle 永遠唔 engage，frame drop 玩家可見 | < 25: 正常 GC pause false-positive throttle，Pillar 3 spectacle 永久降級 | Formula 3 |
| 6 | `FRAME_TIME_SAMPLE_SIZE` | int | **3** | [2, 6] | > 6: throttle latency too long，emergency response 慢 | < 2: single-frame spike false-positive throttle | Formula 3 |
| 7 | `RATE_WINDOW_MS` | int (msec) | **1000** | [500, 5000] | > 5000: anomaly burst 之間 throttle 釋放太慢，debug 困難 | < 500: window 太短，rate-limiter 失效 | Formula 4 |
| 8 | `RATE_CAP_PER_REASON` | int | **10** | [3, 50] | > 50: anomaly spam 唔被限，#28 ingestion queue overflow | < 3: 合法 burst (5 個 AOE INVALID_TARGET) 被過早 drop | Formula 4 (per #13 Rule 17) |
| 9 | `CATCH_UP_HITS_PER_FRAME_CAP` | int | **12** | [6, 20] | > 20: 20 × 0.05ms = 1ms 觸 ADR-001 budget ceiling | < 6: catch-up 太慢，5min bfcache backlog 需 > 17 frames | Rule 7 (inherited from #13 Section G) |
| 10 | `CATCH_UP_QUEUE_HARD_CAP` | int | **1000** | [500, 5000] | > 5000: memory 累積 + drop point 太遲 | < 500: 合法 5min bfcache backlog 可能 false-positive truncate | Rule 7 (inherited from #13 EC-36) |
| 11 | `MOVE_ACCEL_PX_PER_SEC2` | float | **1200.0** | [600.0, 2400.0] | > 2400: enemy 「秒衝」robotic feel | < 600: enemy 「sluggish 唔追到」DNF feel 失 | Formula 6 |
| 12 | `ENEMY_MOVE_CAP` | float (px/s) | **420.0** | [300.0, 500.0] | > 500: enemy outrun camera 視 INV-7 (per #11) | < 300: MOBILITY_MOB 280 px/s 之上冇 headroom | Formula 6 (alias to #11 MOVE_CAP) |
| 13 | `DODGE_AMPLITUDE_PX` | float | **50.0** | [25.0, 100.0] | > 100: MOBILITY_MOB dodge 推出 MELEE_RANGE 永遠 PURSUING ↔ ATTACKING flicker | < 25: dodge invisible，MOBILITY signature 失 | Formula 2 + Wave Archetype Spec |
| 14 | `dodge_interval_sec` | float | **1.5** | [0.5, 3.0] | > 3: dodge 太疏，「走位」感失 | < 0.5: sub-second flicker motion sickness | Formula 2 |
| 15 | `PRE_SPAWN_THRESHOLD` | float (ratio) | **0.8** | [0.6, 0.95] | > 0.95: pre-spawn 太遲，boss anchor latency target ≤ 500ms 難達 | < 0.6: pre-spawn 太早，rollback path 機率上升 | Formula 5 |
| 16 | `PRE_SPAWN_FALLBACK_REPS_FRAC` | float | **0.5** | [0.4, 0.7] | > 0.7: fallback path 50% reps 之後 = 安全 margin 失 | < 0.4: pre-spawn 太早 (fallback path) | Formula 5 |
| 17 | `LIGHT_WORKOUT_THRESHOLD_SETS` | int | **2** | [1, 4] | > 4: mini-boss 出嘅情境太多，final boss 失意義 | < 1: 永遠唔 spawn mini-boss | Rule 13 + EC-19 |

### Data-Driven Knobs (via `EnemyRegistry.tres` schema)

| # | Knob name | Type | Default per archetype | Safe range | Notes |
|---|-----------|------|------------------------|------------|-------|
| 18 | `archetype_cadence_mult` | float | STRIKE=1.0 / CONTROL=1.0 / **MOBILITY=0.75** | [0.5, 1.5] per entry | Cross-knob invariant: `BASE_SPAWN_INTERVAL × min(cadence_mult) ≥ 2.25s` |
| 19 | `_template_move_speed` (per archetype) | float (px/s) | STRIKE=120 / CONTROL=90 / **MOBILITY=280** | [60, 350] per entry | Cross-knob invariant: `max(template_speed) ≤ ENEMY_MOVE_CAP=420` (INV-7 binding) |
| 20 | `max_hp` (per archetype × tier) | int | See Wave Archetype Spec 3-tier table | [10, 1000] per entry | Calibrated against #13 Formula 1 worked example (mid-game 9-hit kill TTK) |
| 21 | `defense` (per archetype × tier) | int | See Wave Archetype Spec 3-tier table | [0, 100] per entry | Cross-knob invariant: `defense < #11.ATTACK_POWER × 0.5` (避免 defense overwhelm — #13 Formula 1 max(1, ...) floor 救返但 NEGLIGIBLE 太多 dilutes Pillar 3) |
| 22 | `primary_outline_color` (per archetype) | Color | STRIKE=RED / CONTROL=BLUE / MOBILITY=GREEN | RGB 任意 | FR-1 fallback binding — 3-class visual differentiation auxiliary channel |

### Knobs Referenced from Upstream (read-only — owned by other GDDs)

| Knob | Source GDD | Value | Why EnemyDirector reads |
|------|------------|-------|--------------------------|
| `MAX_TARGETS_PER_CAST` | #13 CombatResolver | 8 | Rule 14 of #13 — caller-side enforce in target acquisition (Rule 7 + EC-21) |
| `ATTACK_POWER` / `CRIT_CHANCE` derived | #11 Stat System | derived | Rule 8 per-cast StatSnapshot |
| `MOVE_CAP` | #11 Stat System | 420 px/s | Rule 18 + Formula 6 — ENEMY_MOVE_CAP alias |
| `MAX_OFFSET_PX` / `MAX_PAUSE_SEC` | #6 Screen Effects | 4.0px / 0.12s | Reference — #14 calls shake/hit_pause with values ≤ these caps |
| `MAX_ACTIVE_PARTICLES` | ADR-001 + #5 | 200 mobile / 400 desktop | Rule 11 budget binding |
| `gymsys_poll_interval_seconds` | game-concept | 5.0 | Reference — catch-up backlog source cadence |

### Cross-Knob Invariants (Hard + Soft)

| # | Invariant | Type | Default Status |
|---|-----------|------|----------------|
| INV-1 | `BASE_SPAWN_INTERVAL × min(archetype_cadence_mult) ≥ 2.25s` (avoid wave spam) | HARD | 4.0 × 0.75 = 3.0s ✓ |
| INV-2 | `MAX_CONCURRENT_ENEMIES_ON_SCREEN × 30 + boss reservation 20 ≤ MAX_ACTIVE_PARTICLES=200` (mobile particle budget) | HARD | 6 × 30 + 20 = 200 ✓ (mobile) |
| INV-3 | `MAX_CONCURRENT_PARTICLE_EMITTERS × 25 ≤ MAX_ACTIVE_PARTICLES` (per-frame emitter × avg particle count) | HARD | 8 × 25 = 200 ✓ (mobile) |
| INV-4 | `FRAME_TIME_BUDGET_MS > FRAME_TIME_RECOVERY_MS + 5ms` (hysteresis gap — avoid throttle oscillation) | HARD | 33.0 > 20.0 + 5 = 25 ✓ |
| INV-5 | `RATE_CAP_PER_REASON × 6_reasons ≤ #28 ingestion rate cap` (1 sec window × 6 × 10 = 60 signals/sec) | SOFT | 10 × 6 = 60 ≤ #28 expected 1000/sec ✓ (10× margin) |
| INV-6 | `CATCH_UP_HITS_PER_FRAME_CAP × 0.05ms ≤ ADR-001 budget 1.0ms` (per #13 INV-5) | HARD | 12 × 0.05 = 0.6 ≤ 1.0 ✓ |
| INV-7 | `max(template_speed) ≤ ENEMY_MOVE_CAP ≤ MOVE_CAP=420` (#11 INV-7 cross-system) | HARD | 280 ≤ 420 ≤ 420 ✓ |
| INV-8 | `DODGE_AMPLITUDE_PX × 2 < MELEE_RANGE=80` (avoid PURSUING/ATTACKING flicker) | HARD | 50 × 2 = 100 ✗ (default value violates — flag as KNOB TUNE NEEDED) |

**INV-8 violation flag**: `DODGE_AMPLITUDE_PX=50px` violates `2× < MELEE_RANGE=80` invariant (50×2=100 > 80)。**Resolution options**:
- (a) Lower `DODGE_AMPLITUDE_PX` to 30 → 30×2=60 < 80 ✓ (chosen — visible dodge feel preserved)
- (b) Raise `MELEE_RANGE` to 120px → 50×2=100 < 120 ✓ (but breaks side-scroller intimate-combat feel)
- (c) Change Formula 2 to clamp dodge within ±MELEE_RANGE/3 (defensive)

**Adopted resolution (a)** — flagged this knob default revision: `DODGE_AMPLITUDE_PX = 30` (revised from 50)。Section G knob #13 above updated。

### Knob Hierarchy (per game-concept Producer Hard Governance)

| Tier | Can change at... | Examples |
|------|------------------|----------|
| **LOCKED** (schema bump required) | Cross-GDD revision via /propagate-design-change | EnemyAIState 6 values + BossAnchorState 5 values + Faction 4 values |
| **HARD** (changing affects multiple ACs) | Major design revision | INV-1 / INV-2 / INV-3 / INV-4 / INV-6 / INV-7 / INV-8 |
| **SOFT** (designer can adjust) | Section H AC verifies safe range | knobs 1-17 within safe ranges |
| **DATA-DRIVEN** (per archetype via .tres) | EnemyRegistry.tres edit (no code change) | knobs 18-22 |
| **REFERENCE** (read-only) | Owner GDD revision | upstream knobs from #5 / #6 / #11 / #13 + ADR-001 |

## Visual/Audio Requirements

**Scope clarification**: EnemyDirector 係 **orchestration data layer + signal source + direct caller for spawn/boss-anchor moments**。本 GDD owns:
- Boss anchor entry visual orchestration trigger (Rule 13 — Camera focal + ScreenEffects shake + Particle BOSS_ENTRY)
- Per-enemy SPAWN_BURST particle dispatch (Rule 16 — wave cadence)
- Per-enemy DEATH particle dispatch by archetype (Wave Archetype Spec — STRIKE_DEATH / CONTROL_DEATH / MOBILITY_DEATH)
- Concurrent particle emitter cap + auto-degrade (Rule 11 + Formula 3)

**本 GDD 唔 own**: 個別 particle preset visual content (#5 owns)、shader / shake curve (#6 owns)、enemy sprite + animation (#26 Avatar Renderer + future #14 sub-asset)、damage number popup (#25 owns)、audio cue (#4 Audio Manager owns — NOT YET DESIGNED)、boss visual design (#16 owns — NOT YET DESIGNED)。

### Visual/Audio Contract Table (trigger source + downstream consumer mapping)

| Event | EnemyDirector action | Downstream consumer | Visual/Audio mapping (recommended default — actual spec owned by consumer) |
|-------|----------------------|---------------------|-----------------------------------------------------------------------------|
| **Enemy spawn** (per wave cadence) | `ParticleSystem.play(SPAWN_BURST, position, 0.8)` | #5 ParticleSystemWrapper | Subtle but visible spawn anticipation — 唔搶 combat hit feedback |
| **STRIKE_MOB death** | `ParticleSystem.play(STRIKE_DEATH, position, 1.0)` | #5 + #4 (audio) | 盾碎飛裂 visual + heavy thud audio (per #4 GDD spec when ready) |
| **CONTROL_MOB death** | `ParticleSystem.play(CONTROL_DEATH, position, 1.0)` | #5 + #4 | Sticky AOE 0.3s residue (純 cosmetic decal — 無 damage) + soft burst audio |
| **MOBILITY_MOB death** | `ParticleSystem.play(MOBILITY_DEATH, position, 1.0)` | #5 + #4 | Dash-trail 散 visual + light whoosh audio |
| **Mini-boss death** (light workout per EC-19) | `ParticleSystem.play(DEATH_HEAVY, position, 1.3)` | #5 + #4 | Stronger 但保 boss headroom |
| **Boss spawn** (Rule 13 commit frame) | Sequential dispatch:<br>1. `Camera.focal_request(boss, 0.6s, "quart_ease_out")`<br>2. `ScreenEffects.shake(0.4, 0.08s)`<br>3. `ParticleSystem.play(BOSS_ENTRY, position, 1.2)` | #5 + #6 + #7 + #4 | 「重頭戲嚟啦」anticipation moment — full Pillar 3 DNF sensory cascade trigger |
| **Boss death** (#16 handover post-engagement) | `ParticleSystem.play(BOSS_DEATH, position, 1.5)` (caller_mult max per #5 Section G) | #5 + #6 + #7 + #4 | Pillar 3 climax spectacle — max caller_mult 守 200 mobile cap (per Rule 11) |
| **REST_PERIOD pause** (per #1 Decision #3) | No particle dispatch；existing enemies freeze | (no consumer) | 戰場「凝固」visual cue — Pillar 2「等緊你」receptive contract |
| **CatchingUp throttle engaged** (EC-29 + EC-30) | `combat_metric_anomaly` emit only — no visual indicator (per Q-CatchingUp-Indicator decision) | #28 only | Hidden by design — Pillar 2 frictionless invisible orchestration |

### Visual Identity Alignment (per game-concept Visual Identity Anchor)

- **DNF 重擊 cultural reference** — boss entry triple-cascade (Camera focal + screen shake + particle burst) align Pillar 3 DNF sensory cascade per game-concept §MDA Sensation primary
- **Silhouette First principle** (per game-concept Visual Identity Anchor Principle 1) — 3 enemy archetype 必須 16×16 greyscale 都即時可識別類型 (STRIKE 闊厚盾型 / CONTROL 幼長薄甲 / MOBILITY 窄高細長) — per Falsifiable Test #1 +60% accuracy gate
- **Particle Budget Rule** (per game-concept Visual Identity Anchor Principle 2) — boss spectacle 3× ambient particle count，BOSS_ENTRY + BOSS_DEATH 用 caller_mult 1.2-1.5；mobile fallback per ADR-001 `MOBILE_FALLBACK_MULTIPLIER = 0.5` 自動 reduce — 此調整 由 #5 內部 handle，本 GDD 唔複製
- **Layer Discipline** (per Principle 3) — boss anchor world layer 接受 desaturated 30% baseline；BOSS_ENTRY particle 高飽和 (per #5 ParticleLayer high-saturation conventions)
- **Color Philosophy mapping for archetype outline (FR-1 fallback)**:
  - STRIKE_MOB outline = `Color.RED` (DNF 推日 cultural red 配 strike-resist「擋你」signal)
  - CONTROL_MOB outline = `Color.BLUE` (cool color 配 pull class sustain feel)
  - MOBILITY_MOB outline = `Color.GREEN` (active green 配 leg day vitality)
  - 三色 distinct enough for Pillar 4 readability without overlapping loot rarity ladder (white → green → blue → purple → orange — per game-concept Color Philosophy)
- **Cross-system: archetype outline color vs loot rarity color** potential confusion zone (`GREEN` mob outline vs `green` uncommon loot)。**Mitigation**: 加 mob outline border stroke 1-2px 將 mob silhouette 同 loot pickup 視覺 separate；藝術細節 defer to art-bible authoring (cf. Q-Visual-ArchetypeOutline open question)

📌 **Asset Spec**: EnemyDirector 本身 **無 owned VFX asset content** — 但 owns 5 particle preset trigger names (SPAWN_BURST / STRIKE_DEATH / CONTROL_DEATH / MOBILITY_DEATH / DEATH_HEAVY / BOSS_ENTRY / BOSS_DEATH) + 3 archetype outline colors。**After art bible approved**: run `/asset-spec system:enemy-director` 為 7 particle presets + 3 outline colors 產出 visual specs + AI generation prompts (per `/design-system` §Visual/Audio Required for AI/Behavior 類 systems)。Enemy sprite + animation assets 屬 #26 Avatar Renderer GDD authoring scope。

## UI Requirements

**Scope clarification**: EnemyDirector 純 **non-UI data layer orchestrator** — 唔 own HUD render / menu / damage number popup / enemy nameplate 任何 player-visible UI element。

### UI Binding Source Contract

下游 UI consumer subscribe 本 GDD 3 signals + read enemy state pool:

| Downstream UI | Signal/API binding | UI behavior (recommended — actual spec owned by consumer) |
|---------------|--------------------|-----------------------------------------------------------|
| **#20 Gym-Mode HUD** (MVP tier order 25, NOT YET DESIGNED) | `hit_resolved.damage_dealt + damage_tier + is_crit` (per #13 Rule 8 payload) | Damage number popup over target；color per damage_tier；crit 大字 + animation；HP bar realtime update per `target_hp_after` field |
| **#20 Gym-Mode HUD** (enemy nameplate) | `_enemy_state_pool[instance_id].hp + max_hp` reads (per Rule 3) | HP bar per enemy realtime — read on each frame to sync HUD with combat math |
| **#22 Character Screen** (MVP tier order 26, NOT YET DESIGNED) | `enemy_killed.enemy_id + transition_id` (historical aggregation via #28 Telemetry) | Stat-page combat history pane — total hits / kills / time-to-kill statistics per enemy archetype |
| **#25 Combat Visual Feedback** (MVP tier order 29, NOT YET DESIGNED) | `hit_resolved.damage_tier + is_crit` | Damage number rendering style (color / size / animation) + screen sweep on CRITICAL + obliterate overlay on OVERKILL |

### CatchingUp Visible Indicator (per Q-CatchingUp-Indicator decision)

Per Section B Pillar 2 receptive contract argument — **hide CatchingUp from player UI**。CatchingUp state (Rule 7 catch-up draining) **NOT exposed to UI**：

- **No "catching up..." text overlay** — Pillar 2 frictionless = seamless invisible orchestration，玩家唔需要知 backend serialization mechanics
- **HP bar realtime update applies** — even during catch-up，#20 HUD 用 `_enemy_state_pool` realtime read sees damage application 即時 reflect (per CatchingUp State table "damage application exact + ordered")
- **Telemetry channel only** — CatchingUp engagement / disengagement emit `combat_metric_anomaly(reason=&"CATCHUP_ENGAGED")` for #28 (rate-limited per Rule 6)

### Boss Anchor Pre-Spawn (Q-BossPreSpawn-AudioHint deferred decision)

Boss `_boss_anchor_state == PRE_SPAWN` 期間 boss instance off-screen。**Audio hint** (e.g., 遠處 boss 低吼) 算唔算 FR-2「無形軍師」承諾下嘅 visual/audio commit？

- **Option A (recommended pending audio-director review)**: No audio hint — preserve「Boss 已經等緊你」surprise reveal moment；workout_completed event arrival 嗰刻先 trigger 完整 cascade
- **Option B**: Subtle distant boss audio fade-in from PRE_SPAWN trigger frame — but **VIOLATES FR-2 「Boss 已經等緊你」surprise**；只可採用 if game-concept tone 變

📌 **UX Flag — EnemyDirector**: 本 GDD 唔 own 任何 UI screen，所以**唔需要** 直接 run `/ux-design` for EnemyDirector。但下游 #20 / #22 / #25 喺 Pre-Production phase 認 `/ux-design` 時，必 reference 本 GDD signal-contract 表 + Visual/Audio section 為 UI binding spec source。下游 Stories 認 UI 時 cite `design/ux/[downstream-screen].md`，唔可以 cite 本 GDD 直接 (per /design-system UI Flag convention)。

## Acceptance Criteria

**Total**: 38 ACs (31 BLOCKING + 5 ADVISORY + 2 ADR-RATIFICATION-GATED)

**Test category tag legend** (per #13 H pattern):
- Type: `[Logic | Integration | Visual | UI | Config]`
- Gate: `[BLOCKING | ADVISORY | ADR-RATIFICATION-GATED]`
- Test mode: `unit | integration | static | CI | benchmark | playtest`

### H.1 Architecture & Caller-side State Discipline (Rules 1, 9 + CI Lint Layers 1, 6, 8)

- **AC-01 [Logic | BLOCKING | static]**: GIVEN `src/core/enemy_director.gd` source, WHEN `tools/ci/check_enemy_director_state_locality.gd` scan, THEN 8 state containers (`_catch_up_queue` / `_anomaly_rate_tracker` / `_enemy_state_pool` / `_killed_dedupe_set` / `_spawn_pool` / `_rng_factory` / `_active_wave` / `_boss_anchor_state`) 必須 declared 喺 `EnemyDirector` class body — 唔可以移去其他 class。Rule 1 binding。
  - File: `tools/ci/check_enemy_director_state_locality.gd`

- **AC-02 [Logic | BLOCKING | unit]**: GIVEN EnemyDirector fresh autoload `_ready()` 剛完，WHEN inspect 8 state containers, THEN 全部 initialized to empty / zero-state (`_catch_up_queue.size() == 0` / `_killed_dedupe_set.is_empty()` / `_boss_anchor_state == BossAnchorState.IDLE` etc.)；冇任何外部 reference 被 cache。Rule 1 + Rule 3 binding。
  - File: `tests/unit/enemy_director/test_init_state.gd`

- **AC-03 [Logic | BLOCKING | static]**: GIVEN EnemyDirector source, WHEN `tools/ci/check_enemy_director_chokepoint.gd` scan, THEN 任何 damage compute path MUST go via `CombatResolver.resolve_hit()`；reject inline arithmetic resembling damage math (e.g., `caster.attack_power * 1.5`, `target.hp -= ...`)。Rule 1 + CI Lint Layer 1 binding。
  - File: `tools/ci/check_enemy_director_chokepoint.gd`

- **AC-04 [Logic | BLOCKING | static]**: GIVEN `project.godot` `[autoload]` section, WHEN `tools/ci/check_autoload_boot_order.gd` scan, THEN EnemyDirector autoload 必排 **LAST** among combat-relevant autoloads (after #1/#3/#5/#6/#7/#11/#12/#15/#28)。Rule 9 binding (per #13 EC-43 + EC-50 + ADR-006 Contract 4)。
  - File: `tools/ci/check_autoload_boot_order.gd`

- **AC-05 [Logic | BLOCKING | static]**: GIVEN EnemyDirector source, WHEN grep for direct `Camera2D.position` / `Camera2D.zoom` / `Camera2D.offset` / `GPUParticles2D.emitting = true` mutation, THEN 結果為 0 — 全部透過 #5 / #6 / #7 autoload API。ADR-001 forbidden-pattern enforcement (CI Lint Layer 6 + 11 cross-validation)。
  - File: `tools/ci/check_camera_callers.gd` + `tools/ci/check_particle_callers.gd` + `tools/ci/check_screen_effects_callers.gd` (extended coverage)

### H.2 Signal Subscription & Emission (Rules 2, 5, 6, 7)

- **AC-06 [Integration | BLOCKING | integration]**: GIVEN fresh autoload boot, WHEN EnemyDirector `_ready()` 完成, THEN 必須已 subscribe `#1 GameStateMachine.state_changed` + `#12 AbilitySystem.ability_cast` via Contract 6 `connect_for_initial_state` helper — late-bind initial state replay verified。Rule 2 + ADR-006 Contract 6 binding。
  - File: `tests/integration/enemy_director/test_contract6_subscription.gd`

- **AC-07 [Logic | BLOCKING | unit]**: GIVEN EnemyDirector signal surface inspection via `get_signal_list()`, WHEN enumerate emitted signals, THEN 必須**恰好 3 個** signal: `hit_resolved` / `enemy_killed` / `combat_metric_anomaly`；冇 internal/debug signal 洩漏。Rule 5 binding。
  - File: `tests/unit/enemy_director/test_signal_surface.gd`

- **AC-08 [Logic | BLOCKING | unit]**: GIVEN `HitResolvedPayload` / `EnemyKilledPayload` / `CombatAnomalyPayload` struct, WHEN test inspect schema, THEN 必須 inherit from #13 Rule 8/9/13 spec — 字段全部 present + types correct (per #13 GDD source of truth)。Rule 5 binding。
  - File: `tests/unit/enemy_director/test_signal_payload_schemas.gd`

- **AC-09 [Logic | BLOCKING | unit]**: GIVEN EnemyDirector `_anomaly_rate_tracker` initialized, WHEN test 100 same-reason anomaly attempts within 1 sec, THEN exactly 10 emit pass + 90 drop；window expiry 時 emit 1 aggregate `combat_metric_anomaly{reason, dropped_count: 90, aggregate: true}`。Rule 6 + Formula 4 + FR-5 binding。
  - File: `tests/integration/enemy_director/test_anomaly_aggregate_emit.gd`

- **AC-10 [Logic | BLOCKING | static]**: GIVEN EnemyDirector source, WHEN grep for `signal.disconnect(` / `signal.connect(` 喺 hot path (i.e., `_physics_process`, `_on_ability_cast`), THEN 結果為 0 — 所有 signal connection 必須喺 `_ready()` 一次性 set up。Rule 2 binding + Contract 6 stability。
  - File: `tools/ci/check_enemy_director_signal_lifecycle.gd`

- **AC-11 [Integration | BLOCKING | integration]**: GIVEN `_catch_up_queue.size() > 0` (catch-up draining), WHEN new ability_cast `target_type == AOE_RADIUS` arrives, THEN AOE cast 必 defer 入 `_catch_up_queue` tail；catch-up drain 完成後先 process — verify queue position + frame deferral。Rule 7 + #13 Rule 18 binding。
  - File: `tests/integration/combat/test_catch_up_aoe_mutex.gd`

### H.3 RNG Determinism (Rule 4 + Formula 2 + Falsifiable Test #3)

- **AC-12 [Logic | BLOCKING | unit]**: GIVEN `_rng_factory.create("TX-001")` + `_rng_factory.create_sub("TX-001", "wave_spawn_0")`, WHEN call `randf()` 1000 times each, THEN 兩 sequence byte-identical 跨 100 個 fresh process instantiation；同 seed → 同 output。Rule 4 + Formula 4 of #13 binding。
  - File: `tests/unit/enemy_director/test_rng_factory_determinism.gd`

- **AC-13 [Logic | BLOCKING | unit]**: GIVEN combat RNG (`_rng_factory.create("TX-001")`) AND wave-spawn sub-RNG (`_rng_factory.create_sub("TX-001", "wave_spawn_0")`), WHEN combat RNG advance 100 randf() calls, THEN wave-spawn sub-RNG internal state **unchanged** — sub-RNG instances independent，draw cross-contamination 唔存在。FR-3 + Formula 2 of #14 sub-RNG independence。
  - File: `tests/unit/enemy_director/test_sub_rng_independence.gd`

- **AC-14 [Logic | BLOCKING | static]**: GIVEN EnemyDirector source, WHEN `tools/ci/check_enemy_director_randf.gd` scan, THEN reject 任何 `randf(` / `randi(` / `randf_range(` / `Time.get_ticks_msec(` / direct `RandomNumberGenerator.new()` (must go via `_rng_factory` per Rule 4)。Rule 4 + CI Lint Layer 2 binding + FR-3。
  - File: `tools/ci/check_enemy_director_randf.gd`

- **AC-15 [Logic | BLOCKING | unit]** (Falsifiable Test #3 binding): GIVEN 兩個 EnemyDirector instance with `transition_id == "TX-replay-001"`, ability cast sequence + wave spawn schedule fixed, WHEN run identical 5-wave session 兩次 (fresh process each), THEN 兩 run 嘅 `(spawn_time, archetype, position, hp, hit_seq, damage_outcome)` tuple list 完全相同；diff = 0。Section B Falsifiable Test #3 + Pillar 1 anti-fabrication chain integrity。
  - File: `tests/integration/enemy_director/test_replay_determinism.gd`

- **AC-16 [Logic | BLOCKING | unit]**: GIVEN `transition_id` 含 unicode characters ("TX-測試-🎲-001"), WHEN `_rng_factory.create(transition_id)` 計算, THEN function 唔 throw / 不 return null / 不 collide with ASCII transition_id。EC-43 binding (per #13 EC-28 pattern)。
  - File: `tests/unit/enemy_director/test_rng_unicode.gd`

### H.4 Wave Archetype + Boss Anchor (Rules 12-13 + Formula 5 + Falsifiable Test #1 + #2)

- **AC-17 [Config | BLOCKING | static]**: GIVEN `EnemyRegistry.tres`, WHEN `tools/ci/check_enemy_registry_schema.gd` validate, THEN 3 archetype entries (STRIKE / CONTROL / MOBILITY) 各含 mandatory fields: `enemy_templates` (≥1) / `spawn_cadence_sec` (>0) / `archetype_cadence_mult` / `spawn_count_per_set` / `primary_outline_color` / `faction`。Rule 12 binding + FR-1 fallback。
  - File: `tools/ci/check_enemy_registry_schema.gd`

- **AC-18 [Logic | ADVISORY | playtest]** (Falsifiable Test #1 binding — wave archetype readability gate): GIVEN 3 個唔識 game 嘅 tester 各睇 10 秒 push wave / pull wave / leg wave silent gameplay (mute audio + hide HUD), WHEN 請佢哋估邊個係邊類動作日訓練, THEN 命中率 ≥ 60% (3-class baseline = 33%；60% = significantly-above-chance threshold)。Section B Falsifiable Test #1 + FR-1 binding。**ADVISORY** 因 playtest 需要 art assets ready。
  - File: `production/qa/evidence/enemy_director_archetype_readability_signoff.md`

- **AC-19 [Logic | BLOCKING | unit]**: GIVEN BOSS final-cast hit `HitResult.is_kill == true`, WHEN EnemyDirector handle 該 hit, THEN 必 emit `enemy_killed` 喺**同一 frame** (per Rule 5 emit order)；剩餘非-boss enemy 唔強制 despawn (preserve narrative continuity)。Rule 5 + Rule 13 boundary。
  - File: `tests/integration/enemy_director/test_boss_death_signal.gd`

- **AC-20 [Logic | ADVISORY | integration]** (Falsifiable Test #2 binding — Boss anchor latency gate): GIVEN 100 simulated workout session, WHEN 記錄 `workout_completed` event timestamp 同 boss visible-on-screen frame timestamp 嘅 delta, THEN p95 delta ≤ 500ms。Section B Falsifiable Test #2 + FR-2 binding。**ADVISORY** 因 #9 WorkoutStateTracker NOT YET DESIGNED — promote to BLOCKING post-#9 ready。
  - File: `tests/integration/enemy_director/test_boss_anchor_latency.gd` (deferred)

- **AC-21 [Logic | BLOCKING | unit]**: GIVEN `_boss_anchor_state == PRE_SPAWN`, WHEN player undo set (set_progress drops < 0.8), THEN rollback path: `despawn_boss_silently()` + `_boss_anchor_state = IDLE`；唔 emit `enemy_killed` 唔 emit anomaly (legitimate rollback)。EC-15 + Rule 13 binding。
  - File: `tests/unit/enemy_director/test_boss_rollback.gd`

- **AC-22 [Logic | BLOCKING | unit]**: GIVEN `total_planned_sets <= LIGHT_WORKOUT_THRESHOLD_SETS = 2`, WHEN final set complete, THEN spawn mini-boss (NOT final boss)；Camera focal duration = 0.4s (vs full 0.6s)；ScreenEffects shake amplitude = 0.25 (vs full 0.4)；ParticleSystem `caller_mult = 1.0` (vs full 1.2)。EC-19 + Rule 13 light-workout edge case。
  - File: `tests/unit/enemy_director/test_light_workout_mini_boss.gd`

### H.5 Particle Dispatch & Auto-degrade (Rule 11 + Formula 3 + Falsifiable Test #5)

- **AC-23 [Logic | BLOCKING | unit]**: GIVEN Formula 3 `_frame_time_window`, WHEN 3 consecutive frame_time > 33ms registered, THEN `_is_throttle_active()` returns `true`；`caller_mult` drop 自 1.5 → 1.0；emit `combat_metric_anomaly(reason=&"PARTICLE_THROTTLE_ENGAGED")` rate-limited。EC-29 + Rule 11 binding。
  - File: `tests/unit/enemy_director/test_throttle_engagement.gd`

- **AC-24 [Logic | BLOCKING | unit]**: GIVEN throttle engaged, WHEN 60 consecutive frames frame_time < 20ms (recovery hysteresis), THEN `caller_mult` restore 1.5；emit `combat_metric_anomaly(reason=&"PARTICLE_THROTTLE_RELEASED")` rate-limited。EC-30 + Formula 3 binding + INV-4 hysteresis gap。
  - File: `tests/unit/enemy_director/test_throttle_recovery.gd`

- **AC-25 [Logic | BLOCKING | unit]** (Falsifiable Test #5 binding — mobile particle floor preservation gate): GIVEN iPhone 12 (ADR-001 reference hardware) + iOS 17+ Safari, WHEN 8-enemy AOE + LootDrop particle burst 同時觸發 (worst-case from #13 Rule 14 MAX_TARGETS_PER_CAST=8), THEN frame_time ≤ 33ms (30fps floor) — auto-degrade rules trigger preserve mobile floor；持續 > 3 frames > 33ms = ❌ FAIL。Section B Falsifiable Test #5 + FR-4 + Rule 11 binding。
  - File: `tests/performance/enemy_director/test_mobile_particle_floor.gd`

- **AC-26 [Logic | BLOCKING | static]**: GIVEN EnemyDirector source, WHEN grep for `GPUParticles2D.new()` 或 `preload("res://.*particles.*.tscn").instantiate()`, THEN 結果為 0 — 全部 particle 透過 `ParticleSystemWrapper.play(preset, position, caller_mult)` (per Rule 11 + ADR-001 forbidden pattern)。CI Lint Layer 11 + #5 caller contract binding。
  - File: `tools/ci/check_particle_callers.gd` (extended coverage)

### H.6 Per-Enemy AI State Machine + Locomotion (Rule 17 + Rule 18 + Formula 6)

- **AC-27 [Logic | BLOCKING | unit]**: GIVEN enemy in `IDLE` state, WHEN avatar X-distance ≤ `PERCEPTION_RANGE = 600 px` (cached via 4Hz batch perception per Rule 18), THEN transition `IDLE → PURSUING`；reverse direction with `LEASH_RANGE = 900 px` hysteresis (PURSUING → IDLE only when distance > 900)。Rule 17 transition matrix binding。
  - File: `tests/unit/enemy_director/test_enemy_ai_perception.gd`

- **AC-28 [Logic | BLOCKING | unit]**: GIVEN enemy in non-DYING state, WHEN `hit_resolved` payload `damage_tier == HEAVY` AND `target_id == self.instance_id`, THEN transition `→ STAGGERED` with duration 0.15s；CRITICAL tier → 0.30s。Rule 17 + Pillar 3 hit-feel binding。
  - File: `tests/unit/enemy_director/test_enemy_ai_stagger.gd`

- **AC-29 [Logic | BLOCKING | unit]**: GIVEN enemy in `ATTACKING` state mid-animation, WHEN `hit_resolved` payload `is_kill == true`, THEN transition `→ DYING` 即時 (priority over ATTACKING completion)；attack animation 中斷；ability_cast 唔 emit。EC-36 + Rule 17 transition priority。
  - File: `tests/unit/enemy_director/test_enemy_ai_dying_priority.gd`

- **AC-30 [Logic | BLOCKING | unit]**: GIVEN Formula 6 `enemy_locomotion_step` with `_template_move_speed = 120 px/s`, `direction = +1`, `delta = 1/60`, `velocity.x_old = 0`, WHEN compute `move_toward(0, 120, 1200 × 1/60) = 20`, THEN `velocity.x_new = clamp(20, -420, 420) = 20`；不超 cap。Formula 6 worked example + INV-7 binding。
  - File: `tests/unit/enemy_director/test_locomotion_formula.gd`

- **AC-31 [Logic | BLOCKING | static]**: GIVEN `EnemyRegistry.tres` archetype entries, WHEN `tools/ci/check_enemy_template_move_cap.gd` validate, THEN 全部 `_template_move_speed ≤ ENEMY_MOVE_CAP = 420` (INV-7 cross-system binding per #11 MOVE_CAP)；STRIKE=120 / CONTROL=90 / MOBILITY=280 全部 pass。INV-7 + CI Lint Layer 12 binding。
  - File: `tools/ci/check_enemy_template_move_cap.gd`

- **AC-32 [Logic | BLOCKING | static]**: GIVEN Section G knob defaults, WHEN validate INV-8 `DODGE_AMPLITUDE_PX × 2 < MELEE_RANGE = 80`, THEN `DODGE_AMPLITUDE_PX = 30` (post-fix) — `30 × 2 = 60 < 80 ✓`。INV-8 post-fix verification binding。
  - File: `tools/ci/check_dodge_amplitude_invariant.gd`

### H.7 Cross-system Integration (#5/#6/#7/#9/#11/#12/#13/#15/#28 contracts)

- **AC-33 [Integration | BLOCKING | integration]**: GIVEN boss spawn moment (Rule 13 commit frame), WHEN `_boss_anchor_state == COMMITTED`, THEN EnemyDirector dispatch sequential calls: `Camera.focal_request(boss, 0.6s, "quart_ease_out")` + `ScreenEffects.shake(0.4, 0.08s)` + `ParticleSystem.play("BOSS_ENTRY", position, 1.2)` (per Rule 13 sequence)。#5 + #6 + #7 caller contracts。
  - File: `tests/integration/enemy_director/test_boss_entry_cascade.gd`

- **AC-34 [Logic | BLOCKING | unit]**: GIVEN AOE cast with `targets.size() == 12`, WHEN EnemyDirector caller-side clip, THEN 只 process 頭 8 targets (距離 sort 取最近 8 個 per #13 Rule 14)，emit `combat_metric_anomaly(reason=&"CLAMP_TRIGGERED", context_dump={requested: 12, capped: 8})`。EC-21 + #13 Rule 14 caller-side enforcement。
  - File: `tests/unit/enemy_director/test_aoe_target_clamp.gd`

- **AC-35 [Integration | BLOCKING | integration]**: GIVEN `_on_ability_cast` handler, WHEN process AOE 5-target cast, THEN EnemyDirector 必 (a) call `StatSystem.get_stat()` exactly 2 times in `_build_stat_snapshot()` (for ATTACK_POWER + CRIT_CHANCE) per Rule 8 — NOT 10 times per-target；(b) call `CombatResolver.resolve_hit(ctx)` exactly 5 times — 1 per target；(c) emit 5 `hit_resolved` signals + (if kill) `enemy_killed` per dedupe；(d) inject same `caster_stats` snapshot to all 5 ctx。Rule 8 + Rule 14 of #13 + Rule 15 idempotency binding。
  - File: `tests/integration/enemy_director/test_aoe_handler_pipeline.gd`

- **AC-36 [Integration | BLOCKING | integration]**: GIVEN `HitResult.is_kill == true`, WHEN EnemyDirector emit `enemy_killed`, THEN payload 必須 propagate 原 `ctx.transition_id` (string identity check) — 為 #15 LootDrop RNG seed source per ADR-005 chain。FR-LootDrop-TransitionId + #13 FR-2 + #13 Rule 9 binding。
  - File: `tests/integration/enemy_director/test_enemy_killed_transition_id.gd`

- **AC-37 [Logic | BLOCKING | unit]**: GIVEN same-frame double-resolve on same target (AOE × catch-up race scenario), WHEN second resolve_hit returns `is_kill = true` after first already emitted enemy_killed, THEN second emit blocked by `_killed_dedupe_set` guard (Rule 15)；emit `combat_metric_anomaly(reason=&"DEAD_TARGET_RESOLVE")` instead。EC-17 + Rule 15 binding。
  - File: `tests/integration/enemy_director/test_enemy_killed_idempotent.gd`

### H.8 Performance & Determinism (FR-3 + Falsifiable Test #4 — ADR-001 RATIFICATION-GATED)

- **AC-38 [Logic | ADR-RATIFICATION-GATED | benchmark]** (Falsifiable Test #4 binding — 5-obligation availability + CPU budget): GIVEN AOE cast 8-target × 3 AOE hits per frame (worst-case combined), WHEN benchmark `_physics_process` + `_on_ability_cast` handler on mobile reference hardware (iPhone 12 + iOS 17+ Safari per ADR-001), THEN total CPU time p95 ≤ 0.5ms (EnemyDirector orchestration budget per ADR-001) + p99 ≤ 0.7ms。**ADR-001 RATIFICATION-GATED** — provisional pending VS-tier mobile profiling；若 ADR-001 ratify 新 budget figure，更新本 AC threshold。
  - File: `tests/performance/enemy_director/test_orchestration_cpu_budget.gd`

### Coverage Matrix Summary

**Rule coverage** (18/18):

| Rule | ACs |
|---|---|
| Rule 1 (Caller-side state owner) | AC-01, AC-02, AC-03 |
| Rule 2 (Contract 6 subscription) | AC-06, AC-10 |
| Rule 3 (EnemyState struct) | AC-02, AC-35 |
| Rule 4 (RNG factory FR-3) | AC-12, AC-13, AC-14, AC-15, AC-16 |
| Rule 5 (3-signal emit) | AC-07, AC-08, AC-19 |
| Rule 6 (Anomaly rate-limiter) | AC-09 |
| Rule 7 (Catch-up × AOE mutex) | AC-11 |
| Rule 8 (StatSnapshot) | AC-35 |
| Rule 9 (Boot order) | AC-04 |
| Rule 10 (GSM Suspended gate) | (covered via Rule 13 EC-18 + #13 Rule 12 propagation) |
| Rule 11 (Particle concurrency + auto-degrade) | AC-23, AC-24, AC-25, AC-26 |
| Rule 12 (Wave archetype data-driven) | AC-17, AC-18 |
| Rule 13 (Boss anchor) | AC-19, AC-20, AC-21, AC-22, AC-33 |
| Rule 14 (MVP scope discipline) | (negative coverage — out-of-scope absence via #13 Rule 16 propagation) |
| Rule 15 (enemy_killed idempotency) | AC-35, AC-37 |
| Rule 16 (Enemy lifecycle cleanup) | AC-02 + EC-38 implicit pool cleanup |
| Rule 17 (Per-enemy AI FSM) | AC-27, AC-28, AC-29 |
| Rule 18 (Hybrid tick architecture) | AC-30 |

**Formula coverage** (6/6): ✓ 全部 covered (F1: AC-17 + AC-18；F2: AC-12 + AC-13；F3: AC-23 + AC-24；F4: AC-09；F5: AC-19 + AC-20 + AC-21；F6: AC-30 + AC-31)

**Falsifiable Test coverage** (5/5):
- FR Test #1 (Pillar 4 wave archetype readability) — AC-18 ✓ (ADVISORY pending art-bible)
- FR Test #2 (Pillar 2 boss anchor latency) — AC-20 ✓ (ADVISORY pending #9 GDD)
- FR Test #3 (Pillar 1 determinism replay) — AC-15 ✓
- FR Test #4 (5-obligation availability gate) — AC-38 ✓ (ADR-001 RATIFICATION-GATED)
- FR Test #5 (mobile particle floor preservation) — AC-25 ✓

**FR Risk Register coverage** (5/5):
- FR-1 (wave archetype visual differentiation) — AC-17 + AC-18
- FR-2 (boss anchor latency) — AC-20 + AC-21
- FR-3 (RNG injection determinism) — AC-12 + AC-13 + AC-14 + AC-15
- FR-4 (particle dispatch overload) — AC-23 + AC-24 + AC-25
- FR-5 (anomaly rate-limiter aggregate emit) — AC-09

**Cross-knob INV coverage** (8/8):
- INV-1 (BASE_SPAWN_INTERVAL × min mult ≥ 2.25s) — covered via Section G static check
- INV-2 (concurrency × particle ≤ 200 mobile) — AC-25
- INV-3 (emitters × avg particle ≤ cap) — AC-26
- INV-4 (throttle hysteresis gap) — AC-23 + AC-24
- INV-5 (rate cap × reasons ≤ telemetry capacity) — AC-09
- INV-6 (catch-up frame budget) — AC-11 + AC-38
- INV-7 (enemy_move_cap ≤ MOVE_CAP) — AC-31
- INV-8 (DODGE_AMPLITUDE × 2 < MELEE_RANGE — post-fix) — AC-32

**Cross-system contracts** (9/9):
- #5 ParticleSystem caller — AC-26 + AC-33
- #6 ScreenEffects caller — AC-33
- #7 Camera caller — AC-33
- #9 WorkoutStateTracker — AC-20 (ADVISORY pending #9 GDD)
- #11 StatSystem snapshot — AC-35
- #12 AbilitySystem subscription — AC-06
- #13 CombatResolver chokepoint — AC-03 + AC-34 + AC-35
- #15 LootDrop transition_id chain — AC-36 (provisional)
- #28 Telemetry — AC-09 + (gated AC awaiting #28 GDD)

### Test Infrastructure Additions (recommended sprint backlog stories)

對齊 #13 Section H pattern + qa-lead 推薦 12 個 new tools/helpers:

1. **`tests/helpers/enemy_director_test_harness.gd`** — spin up EnemyDirector + minimal mock #5/#6/#7/#11/#12 autoload；factory method `make_harness(run_seed: int, archetype: StringName)`
2. **`tests/helpers/rng_determinism_helper.gd`** — utility comparing two RNG sequence outputs；produces diff report (AC-12, AC-15)
3. **`tests/helpers/enemy_signal_recorder.gd`** — connect to all 3 EnemyDirector signal，record (timestamp, payload) tuple for assertion (AC-07, AC-09, AC-19, AC-37)
4. **`tests/helpers/archetype_resource_factory.gd`** — synthesize `EnemyRegistry.tres` + `WaveDescriptor` in-memory for unit tests (AC-17)
5. **`tests/helpers/combat_context_factory.gd`** (inherited from #13) — build valid/invalid CombatContext fixtures including null target / dead target / NaN multiplier edge cases
6. **`tests/helpers/mock_workout_state_tracker.gd`** — provides `get_dominant_ability_class() + set_progress` for AC-18/20/21 (deferred until #9 ready — stub interface defined)
7. **`tools/ci/check_enemy_director_chokepoint.gd`** — AC-03 / CI Layer 1
8. **`tools/ci/check_enemy_director_randf.gd`** — AC-14 / CI Layer 2
9. **`tools/ci/check_enemy_director_signal_emission.gd`** — AC-07 / CI Layer 3
10. **`tools/ci/check_enemy_director_signal_subscription.gd`** — AC-06 / CI Layer 4
11. **`tools/ci/check_enemy_director_stat_calls.gd`** — AC-35 / CI Layer 5
12. **`tools/ci/check_enemy_director_state_locality.gd`** — AC-01 / CI Layer 6
13. **`tools/ci/check_enemy_registry_schema.gd`** — AC-17 / CI Layer 7
14. **`tools/ci/check_autoload_boot_order.gd`** — AC-04 / CI Layer 8
15. **`tools/ci/check_rng_factory_purity.gd`** — Rule 4 / CI Layer 9
16. **`tools/ci/check_boss_anchor_state_transitions.gd`** — Rule 13 / CI Layer 10
17. **`tools/ci/check_particle_concurrency_cap.gd`** — Rule 11 / CI Layer 11
18. **`tools/ci/check_enemy_template_move_cap.gd`** — AC-31 / CI Layer 12
19. **`tools/ci/check_dodge_amplitude_invariant.gd`** — AC-32 / INV-8 post-fix
20. **`tests/performance/enemy_director/test_orchestration_cpu_budget.gd`** — AC-38 benchmark harness (mobile reference hardware spec pending ADR-001 ratification)

### Existing CI Scripts (extension required)
- `tools/ci/check_camera_callers.gd` (already exists) — extend coverage to EnemyDirector path (AC-05)
- `tools/ci/check_screen_effects_callers.gd` (already exists) — extend coverage (AC-05)
- `tools/ci/check_particle_callers.gd` (already exists) — extend coverage (AC-05 + AC-26)

### Evidence Folder Setup
- `production/qa/evidence/enemy_director_archetype_readability_signoff.md` (AC-18 ADVISORY template — playtest sign-off)
- `production/qa/evidence/enemy_director_visual_feel_signoff.md` (boss anchor cascade visual feel signoff template)

## Open Questions

15 條 open questions — surface 喺 GDD 各 section 期間，按 owner + timeline + resolve gate 分類。Resolve 後 update GDD 對應 section + close OQ entry。Includes 3 inherited from #13 + 12 net new from #14 authoring。

| OQ ID | Question | Owner | Timeline / Resolve Gate | Impact |
|-------|----------|-------|--------------------------|--------|
| **Q-9-SetProgress** | `#9 Workout State Tracker` MVP 是否 expose `set_progress: float` (range [0.0, 1.0]) — 若否，Rule 13 boss anchor pre-spawn 用 50% reps fallback heuristic (Formula 5 fallback path)。Fallback latency target ≤ 500ms p95 (FR-2) — 仍 reliable? | systems-designer + #9 owner | #9 GDD authoring (VS tier order 11) | Rule 13 + Formula 5 fallback selection + AC-23 test threshold |
| **Q-Enemy-Stat-Source** | Enemy attack `caster_stats` source 鎖 `EnemyTemplateRegistry.tres` synthesize (NOT `#11 StatSystem`) — confirm Rule 8 enemy caster path + Rule 17 enemy ability cast pattern (per Section C systems-designer recommendation) | systems-designer + game-designer | Pre-implementation | Rule 8 + Rule 17 + CI lint Layer 5 enforcement |
| **Q-Enemy-Move-Cap** | `MOBILITY_MOB.move_speed = 280 px/s` 限 ENEMY_MOVE_CAP=420 (per #11 INV-7)。Designer 是否想要 catch-up tension (e.g., MOBILITY 280 → 500 px/s 超 player cap)? v0.1 lock 420，v0.2 introduce `ENEMY_MOVE_CAP_OVERRIDE` ? | game-designer | VS-tier playtest after #14 implementation | Formula 6 ENEMY_MOVE_CAP knob + Section G safe range |
| **Q-Faction-Schema** | `Faction` enum declaration location — Section C Rule 3 提議 EnemyDirector own enum (4 values: PLAYER / ENEMY / BOSS / NEUTRAL)。若 v0.2 加 BOSS_ALLY (boss spawn minion) → extend enum 還是 hierarchical? | systems-designer + ai-programmer | v0.2 planning gate | Rule 3 EnemyState schema + AOE friendly-fire filter |
| **Q-INV-7-Resolution-Wait** | `#11 Stat System` Q-X4 (INV-7 precise math for camera follow speed) PENDING — 本 GDD Section 3.3 of ai-programmer subagent 假設 effective Camera follow speed ≈ 1920 px/s > 420 hold。若 Q-X4 改變 follow speed 計算 → Section 3.3 + Formula 6 revisit | #11 owner + #7 owner | #11 next-revision batch | Formula 6 ENEMY_MOVE_CAP cross-system invariant |
| **Q-Enemy-Ability-Registry** | `AbilityRegistry.tres` 應 same registry hold enemy + player abilities (single source + `caster_type` field)，定分 `PlayerAbilityRegistry` + `EnemyAbilityRegistry`? Section C ai-programmer 推薦 single registry — confirm? | game-designer + #12 owner | #12 next-revision batch (FR-Q-F2 propagate) | Rule 17 enemy cast path + #12 schema extension |
| **Q-CatchingUp-Indicator** | CatchingUp state Pillar 2 frictionless argument — hide vs show "catching up..." indicator? Section C systems-designer 推 hide (default invisible orchestration)；UI Requirements section confirm decision | game-designer + ux-designer | Pre-Production UI authoring gate | UI Requirements section + #20 HUD authoring constraint |
| **Q-BossPreSpawn-AudioHint** | Boss `PRE_SPAWN` 期間 distant boss audio fade-in 算唔算 FR-2 「Boss 已經等緊你」violation? Section UI Requirements 推 Option A (no audio hint)；audio-director review pending | game-designer + audio-director | #4 Audio Manager GDD authoring (MVP tier order 22) | Rule 13 boss anchor sequence + #4 GDD authoring constraint |
| **Q-ParticleConcurrencyCap-Tuning** | `MAX_CONCURRENT_PARTICLE_EMITTERS = 8 mobile / 16 desktop` placeholder — VS-tier 必驗 ADR-001 reference hardware (iPhone 12 + iOS 17+ Safari) 真正 ceiling，調 cap 可能引致 Section G knob revisit | performance-analyst + devops-engineer | VS-tier mobile profiling (per ADR-001 ratification) | Section G knob #4 safe range + Rule 11 binding |
| **Q-BossAnchorState-Persistence** | `_boss_anchor_state` v0.1 NO persist (cold boot reset to IDLE)。若 player suspend mid-PRE_SPAWN → resume cold boot 時 set_progress 拎到 stale value → boss 唔 spawn? Section C systems-designer 推 v0.1 NO persist；confirm acceptable edge case | systems-designer + #3 PersistenceLayer | Pre-implementation | Rule 13 + EC-18 lifecycle |
| **Q-DodgeAmplitude-Tuning** | `DODGE_AMPLITUDE_PX = 30` (post INV-8 fix from 50)。MOBILITY visible dodge feel 是否 sufficient? VS-tier playtest verify — 若 30px 太細 invisible → 加 visual effect (e.g., motion blur trail) 而唔係 raise amplitude (preserve INV-8) | game-designer + technical-artist | VS-tier playtest | Section G knob #13 + Formula 2 |
| **Q-Tier-Boundary-Calibration** | Wave Archetype Spec 3-tier (Starter sets 1-3 / Mid 4-8 / Endgame 9+) placeholder — finalize after #15 LootDrop + #16 Boss System 設計時對齊 | game-designer + economy-designer | After #15 + #16 GDD authoring | Wave Archetype Spec table HP / defense baseline values |
| Q-D8 (inherited from #13) | Boss TTK calibration vs MVP scope — VS-tier first playtest verify | game-designer + economy-designer | VS-tier first playtest after #14 + #16 完成 | Wave Archetype Spec calibration + #13 Formula 1 worked example alignment |
| Q-F1 (inherited from #13) | bfcache lifecycle behavior verification on iOS Safari 17+ — Rule 7 catch-up reliable? | gameplay-programmer + engine-programmer | VS-tier engine smoke test | Rule 7 + AC-26 bfcache replay test |
| Q-Boot-Order (inherited from #13) | `project.godot` autoload order ratification — #14 boots LAST after #15/#28 | technical-director + lead-programmer | VS-tier autoload integration story | Rule 9 + EC-41 + CI lint Layer 8 |
