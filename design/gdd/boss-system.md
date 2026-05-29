# Boss System

> **Status**: Revised 2026-05-28 (Pass 4 — addressing Pass 3 fresh-session /design-review TIER A 12 BLOCKING items; TIER B/C deferred to sprint-kickoff polish per CD adjudication)
> **Author**: user + claude (Pass 4 = TIER A spec authoring: contract definitions + Web Export knowledge gaps + Pillar-breaking design + cross-doc contract drift)
> **Last Updated**: 2026-05-28
> **Implements Pillar**: Pillar 3 (Drop Euphoria) PRIMARY climax — boss kill = signature loot ritual trigger; Pillar 5 (Mirror Moment) secondary — boss reveal ritual = climactic mirror moment instance; Pillar 2 (Frictionless Companion) supporting (inherits #14 boss anchor sub-500ms); Pillar 1 (Real Body, Real Power) supporting (boss difficulty scales with player real PR progression)
> **NOT serving Pillar 4 (Muscle = Class) in MVP** — Pillar 4 mechanical expression requires multi-archetype boss roster (≥3 final bosses) which is honestly deferred to post-MVP. MVP class differentiation is presentation-layer only (silhouette + audio signature + palette family). See [Pillar 4 Scope Honesty Note](#pillar-4-scope-honesty-note) below.
> **Key ADRs**: ADR-005 Loot Rarity Formula (boss kill → loot_rarity_score chain via transition_id); ADR-001 Web Export Budget Caps (boss reveal particle storm budget); ADR-006 State Machine Contract (transition_id propagation)

## Pillar 4 Scope Honesty Note

**Decision (2026-05-27, CD + user)**: Pillar 4 「肌群即職業」嘅 boss-level mechanical expression **honestly deferred to post-MVP**。

**Rationale**: MVP scope 只有 1 final boss template (STRIKE UNKNOWN fallback per Rule 13) + 3 mini-boss templates。喺呢個 scope 下：
- 玩家無論今日係 push / pull / leg day 都會見到同一個 final boss
- Test #2 (class archetype distinctness playtest) 喺 MVP 無法 falsifiable demonstrate Pillar 4 claim
- 全自動戰鬥 (Pillar 2) + 玩家「眼角瞄到」嘅 peripheral vision context 下，mechanical 區別 (speed / damage / range) invisible

**MVP class differentiation = presentation-layer only**：
- Silhouette family (STRIKE = large humanoid + heavy weapon / CONTROL = caped + extended gestures / MOBILITY = multi-segment + agile)
- Audio signature family (per Section I Audio Direction)
- Particle palette family (per Section I Visual)

呢三個 sensory channel 喺 peripheral vision context 下 deliverable，唔需要 player-controlled combat vocabulary。

**Post-MVP path** (v0.2+): 引入 3 archetype × N tier 嘅 multi-boss roster，每個 archetype 有 distinct mechanical behavior (movement pattern + attack pattern set + arena constraint)，Test #2 可以 falsifiable validate Pillar 4 boss-level expression。

## Overview

Boss System (#16) 係 Feature layer 嘅 **boss content owner** + **#14 EnemyDirector BossAnchor lifecycle consumer**：定義 boss 嘅數據 schema (per-boss stats / defense / attack patterns / phase scripts)、3 個 class archetype 嘅 boss variation (STRIKE→攻擊型 / CONTROL→機關房 / MOBILITY→移動關卡)、boss 難度跟玩家 real-world progression 嘅 scaling 規則、同埋 mini-boss vs final-boss 嘅 dramatic weight 區分。喺 player-facing 層面，#16 owns 嘅係 Pillar 3「DNF 式爆裝刺激」climax 嘅整個 moment：當玩家完成最後一 rep，#14 BossAnchor PRE_SPAWN→COMMITTED 嘅 transition 觸發 #16 final boss instance 出場 — 玩家眼角瞄到 boss 倒地 → `enemy_killed(boss_id, transition_id)` → #15 LootDrop 用 transition_id seed RNG → ADR-005 loot_rarity_score 計分 → 必爆裝。

**Negative contract**：#16 **唔 own** spawn timing / BossAnchor state machine (屬 #14)、damage computation (屬 #13 CombatResolver)、loot rarity formula (屬 ADR-005 + #15)。#16 純粹 deliver「boss 係咩、做咩、值幾多」嘅 data + behavior spec。

**MVP scope**：1 個 final boss (per game-concept MVP requirement #6) + 3 個 mini-boss archetype templates (push/pull/leg)。v0.2+ extend：多 boss 池、phase scripting、boss 招式 specialization。

**Key ADR references**：
- **ADR-005 Loot Rarity Formula** (Accepted 2026-05-27) — defines `volume_factor / pr_factor / streak_factor` consumer chain; #16 boss kill emits `enemy_killed.transition_id` 作為 RNG seed source
- **ADR-001 Web Export Budget Caps** (Proposed) — boss reveal 嘅 particle storm 必須 respect MAX_ACTIVE_PARTICLES=200; mobile auto-degrade per FR-4
- **ADR-006 State Machine Contract** — boss transition_id 來自 #1 GSM via #14 BossAnchor pipeline

## Player Fantasy

### Identity: 「Workout 終點嘅 dramatic 對手 / The Set's Final Witness」

Boss 係 workout 嘅 dramatic climax — 唔係 generic enemy 嘅升級版，而係玩家完成今日訓練嘅 **儀式對手**。玩家做最後一組嘅最後一 rep 時，眼角瞄到 phone，boss 已經喺度等緊 (#14 BossAnchor PRE_SPAWN at set_progress ≥ 0.8)；完成最後一 rep 嗰刻，boss commit 出場 → avatar 用今日累積能力打 → boss 倒地 → 必爆裝。「冇咗呢一組 reps，呢個 boss 就唔會喺度 / 唔會死」呢個信任落腳點 = Pillar 3 + Pillar 1 共同 mechanical home。

### Central Player Moments (3 個 anchor 場景)

**Moment A — Push day final set 最後 3 reps**：玩家咬牙做緊 bench press 最後一組。眼角望 phone，**STRIKE 型 final boss** 已經喺度 — 揮舞重武器、攻擊動作大開大合。完成最後一 rep 嘅 instant，#14 BossAnchor COMMITTED → boss 衝向 avatar → 一輪 DNF combo → boss 倒地 → 爆裝。「我嗰一 rep 唔做完，呢條 boss 就會繼續行」 — Pillar 3 ritual 嘅落地。

**Moment B — Leg day final set，MOBILITY presentation family boss 出現** (v0.2+ scope; MVP 只有 STRIKE fallback)：boss silhouette 採用 multi-segment agile 形象（唔係 punching tank），audio signature 偏呼嘯 / 風聲，particle palette 用 yellow dash streak。**注意**：MVP 階段呢個 Moment 唔 deliverable — MVP 一律 STRIKE fallback。Moment B 列出做 post-MVP path 樣本，唔係 MVP commitment。

**Moment C — Light workout (≤2 sets) 嘅 mini-boss 體面退場**：玩家因為時間關係只做 2 sets warm-up squat。冇 final boss，但有 **scaled-down mini-boss with reduced ritual** (per #14 LIGHT_WORKOUT_THRESHOLD_SETS=2) — 短一啲嘅 focal camera、淡一啲嘅 particle burst、相應 minor loot。「我冇練重，但我有上 gym」呢一刻嘅 acknowledged but not trivialized 感覺 = Pillar 1 honesty + Pillar 3 anti-trivialization。

### Architectural Protection (Pillar 1/3 cohesion)

1. **Boss 唯一 spawn trigger = #14 BossAnchor commit on `workout_completed`** — 冇任何 code path 可以唔經 real workout 召喚 boss
2. **Boss 嘅 stats / scaling 唯一 input source = player real stat snapshot (#11 ATTACK_POWER / MAX_HP / CRIT_CHANCE)** — boss HP / damage 跟住 player real progression scale
3. **Boss kill → loot 唯一 path = `enemy_killed(boss_id, transition_id)` → #15 LootDrop with ADR-005 formula**，唔接受任何 in-game grind 替代
4. **Dramatic weight 由 light_workout_threshold_sets 區分** — mini-boss / final-boss 嘅 visual + loot tier 差距體現「練得多 / 練得少」嘅 honesty

### What It WOULDN'T Be (anti-patterns rejected)

- **NO boss bullet sponge** — boss HP scaling 必須俾 typical 9-hit window 殺到 (per #13 Q-D8 mid-game calibration)；late-game player stat 高 = boss 變 tougher 但 hit count 維持相近
- **NO unkillable boss** — 唔可以 progression-block；冇 retry pattern (per game-concept Recovery from failure "缺一日 workout = 唔損 avatar 能力，只損 streak buff")
- **NO mid-fight player input demand** — 戰鬥全 auto-play，Pillar 2 absolute
- **NO simultaneous multi-boss climax** — single dramatic target per workout completion
- **NO mini-boss visual that overshadows final boss** — dramatic weight gradient locked (camera focal 0.4s vs 0.6s, particle caller_mult 1.0 vs 1.2 per #14 EC-19)
- **NO randomly-generated boss** — boss roster 係 designed content；#15 RNG only affects loot rarity 唔係 boss identity

### Falsifiable Tests (5 tests bound to Section H ACs)

| # | Test | Expected outcome | Failure = framing broken |
|---|------|------------------|--------------------------|
| **1** | **「值得 cap 圖」sensation playtest** — 5 個 playtester 完成 workout，問「啱啱嗰一刻你想 screenshot 嗎」 | ≥3/5 答 yes | <3/5 → Pillar 3 climax 失效 → boss reveal ritual 重新 design |
| **2** | **Class archetype distinctness** — 同一 player 喺 push / pull / leg 日各打 final boss，盲測問「fight feel 一樣嗎」 | 3 個 session feel 明顯唔同 | 同樣 feel → Pillar 4 boss-level distinction 失敗 |
| **3** | **Sub-500ms boss visible** (inherited #9 AC-41 + #14 FR-2) | p95 ≤ 500ms 由 `workout_completed_forwarded` emit 到 boss visible frame | > 500ms → Pillar 2 frictionless 承諾失敗 |
| **4** | **Boss kill → loot 單一 coherent climax** — measure 時間軸 boss visible-down → first loot particle | ≤ 800ms (allowing for kill VFX + loot reveal sequence) | > 800ms → climax 斷裂感 |
| **5** | **Light-workout dignity test** — 5 個 playtester 做 2-set warm-up only workout，問「呢個 mini-boss 收尾感覺有冇 acknowledge 我做過 gym」 | ≥4/5 答 yes | <4/5 → 光感不夠 → boss tier 變 dismissive |

### Fantasy Risk Register (3 FR — gate-bound)

| FR | Risk | Mitigation gate | Status |
|----|------|------------------|--------|
| **FR-1** | Boss scaling 公式 (Section D) 若令 late-game boss 變 trivial → Pillar 3 climax 退場 OR 過難變 progression-block | Section D Formula 1 + Section E EC-04 emergency-killable floor | OPEN — pending Section D |
| **FR-2** | 3 class archetype 嘅 mechanical distinctness MVP 只有 1 boss → 點 demonstrate Pillar 4 boss-level expression? | Section C mini-boss 3 archetype templates 補足 + Falsifiable Test #2 deferred to v0.2 full boss roster | OPEN — pending Section C |
| **FR-3** | Mini-boss vs final-boss dramatic weight 區分若 gradient 太薄 → 玩家分唔出 light workout 同 full workout 感受差異 | Section C visual treatment spec + Section H AC test 5 light-workout dignity | OPEN — pending Section C + H |

### Pillar Ties (explicit — revised 2026-05-27)

- **Pillar 3 DNF 式爆裝刺激 (PRIMARY climax)**：boss kill = signature loot ritual trigger；`enemy_killed.transition_id` 直接 seed #15 ADR-005 formula
- **Pillar 5 鏡像時刻 (secondary)**：boss reveal ritual = climactic mirror moment instance — 玩家完成最後一 rep + boss commit 出場 + 視覺 ritual = 「呢一刻 captured」嘅 screenshot-worthy moment（覆蓋 #29 Mirror Moment MVP minimum scope）
- **Pillar 2 無壓力陪伴 (supporting via #14)**：inherits BossAnchor sub-500ms pre-spawn pipeline
- **Pillar 1 真身真力 (supporting honesty floor)**：boss difficulty scales with player real stat progression；light-workout dignity preserved；冇 in-game shortcut 召喚 boss
- **NOT serving Pillar 4 in MVP** — see [Pillar 4 Scope Honesty Note](#pillar-4-scope-honesty-note) above. MVP class differentiation = presentation-only (silhouette / audio / palette family)

## Detailed Design

### Core Rules

#### Rule 1 — Boss Data Schema (BossTemplate Resource) — revised 2026-05-27

**Rationale**: Data-driven content per Coding Standards + ADR-001 pattern。Revision: 移除 STANDARD tier（dead code per /design-review CRIT-2）；BossTemplate 只用於 FINAL boss（mini-boss 改用 EnemyTemplate via #14 wave system per CRIT-4 decision）。

```gdscript
class_name BossTemplate extends Resource
@export var boss_id: StringName              # unique identifier (e.g., "STRIKE_FINAL_01")
@export var class_archetype: AbilityClass    # STRIKE | CONTROL | MOBILITY | UNKNOWN-fallback (presentation family only — see Pillar 4 Note)
@export var tier: BossTier                   # FINAL only for MVP (MINI dropped — see CRIT-2 + CRIT-4)
@export var base_hp: int                     # pre-scaling baseline HP, range [50, 500]
@export var base_defense: int                # per #13 Formula 1 input
@export var attack_patterns: Array[AttackPatternResource]   # min 2, max 4 for MVP
@export var visual_template: BossVisualResource             # see schema stub below — Q-V2 ownership pending #26 finalize
@export var audio_template_id: StringName                   # audio cue id for #4 (when available)
@export var loot_guarantee_min_tier: RarityTier             # RARE for FINAL (Pass 4 A3.1 — raised UNCOMMON→RARE to preserve dramatic weight gradient now that mini ceiling restored to RARE per game-concept promise)
@export var reveal_ritual_intensity: float = 1.0            # caller_mult for #5/#6/#7 (default 1.0 for final)
@export var arena_constraint_mode: ArenaConstraintMode = ArenaConstraintMode.SPAWN_RELATIVE  # see Rule 14
@export var arena_constraint_px: Vector2                    # interpretation depends on arena_constraint_mode

# Supporting enums + schemas
enum BossTier { FINAL }   # MVP: FINAL only. STANDARD removed per CRIT-2. Mini-boss = EnemyTemplate (separate resource).
enum ArenaConstraintMode { WORLD_ABSOLUTE, SPAWN_RELATIVE, AVATAR_LEASH }   # see Rule 14

# BossVisualResource stub schema (Q-V2 — #16 owns until #26 Avatar Renderer finalizes)
class_name BossVisualResource extends Resource
@export var sprite_texture: Texture2D          # base sprite atlas
@export var sprite_scale: Vector2 = Vector2.ONE
@export var anim_set: SpriteFrames             # idle / telegraph / attack / staggered / death animations
@export var silhouette_test_size_px: int = 32  # used by silhouette identifiability test (Section I)
@export var rim_light_color: Color = Color.WHITE
# TODO (Q-V2): refactor when #26 finalizes shared visual interface — may extract IVisualResource @abstract (Godot 4.5+)
```

##### BossInstance class — Pass 4 A1.1 spec (runtime scene tree contract)

**Rationale**: Pass 3 fresh-session re-review identified `BossInstance` as undefined cross-specialist consensus gap (systems-designer #3+#4 + gameplay-programmer #1+#2). Implementation cannot begin without complete signature. Pass 4 locks the full contract:

```gdscript
class_name BossInstance extends Node2D
# Extends Node2D — world-space entity with global_position + transform (NOT Control/CanvasItem;
# boss lives in game world, NOT UI layer). Inherits process loop for AI state machine ticking.

# === Spawn-time immutable fields (set in spawn_boss, never mutated post-spawn) ===
@export var boss_id: StringName                          # mirrors BossTemplate.boss_id
@export var boss_template: BossTemplate                  # source template reference (read-only)
@export var transition_id: String                        # from #14 BossAnchor commit (Pillar 1 chain)
@export var player_stat_snapshot: StatSnapshot           # Pass 3 CF-3 cached snapshot — frozen-at-spawn

# === Runtime mutable state (per Rule 12 transient — NOT persisted) ===
var current_hp: int                                       # initialized to boss_max_hp from Formula 1
var max_hp: int                                           # cached output of Formula 1
var attack_count: int = 0                                 # per Formula 3 anti-spam state
var _last_emitted_pattern_id: StringName = &""            # per Formula 3 anti-spam state
var _spawned_emitters: Array[GPUParticles2D] = []         # Rule 11 cleanup tracking
var _ai_state: int = EnemyAIState.SPAWNING                # Rule 15 inherits #14 enemy_ai_state_enum

# === Required child node contract (BLOCKING — CI lint enforced via BossRegistry validation) ===
# Scene tree structure for every BossInstance.tscn:
# BossInstance (Node2D)
# ├── $AnimationPlayer (AnimationPlayer)  — REQUIRED, animation library see below
# ├── $CollisionShape2D (CollisionShape2D) — REQUIRED, hit detection per #13
# ├── $Sprite2D (Sprite2D)                 — REQUIRED, visual surface; texture from boss_template.visual_template.sprite_texture
# └── $HitArea2D (Area2D)                  — REQUIRED, projectile/attack receive area per #13

# === Required AnimationPlayer animation library (animations MUST exist by name) ===
# - "idle"          — looping idle pose during IDLE state
# - "telegraph"     — pre-attack windup during ATTACKING entry (per AttackPatternResource.telegraph_duration_sec)
# - "attack_<id>"   — per-pattern attack animation (one per AttackPatternResource.pattern_id)
# - "staggered"     — STAGGERED state animation (Rule 15)
# - "death"         — DYING state animation (Rule 11 cleanup waits for animation_finished)
# CI lint (BOSS-AC-followup-08 tooling story scope): BossRegistry validation asserts every
# BossTemplate.visual_template.anim_set SpriteFrames contains the 5 required animation names
# plus one "attack_<id>" entry per BossTemplate.attack_patterns[].pattern_id.

# === Lifecycle hooks ===
func _ready() -> void:
    # Pillar 1 invariant — BossInstance MUST be initialized via spawn_boss(); direct instantiation forbidden
    assert(transition_id != "", "BossInstance MUST have transition_id set by spawn_boss before _ready")
    assert(player_stat_snapshot != null, "BossInstance MUST have cached snapshot before _ready")
    assert(has_node("AnimationPlayer"), "BossInstance scene tree contract: $AnimationPlayer required")
    assert(has_node("CollisionShape2D"), "BossInstance scene tree contract: $CollisionShape2D required")
    # Formula 1 + 2 computed here (single eval per spawn — CF-3 caching)
    max_hp = BossFormulas.compute_max_hp(boss_template, player_stat_snapshot)
    current_hp = max_hp
    $AnimationPlayer.play("idle")

func _exit_tree() -> void:
    # Rule 11 cleanup safety net — if queue_free called outside _on_enemy_killed_self_listen
    _cleanup_resources()  # idempotent per Rule 11 GP6
```

**Direct instantiation forbidden**: `BossInstance.new()` or `preload(...).instantiate()` outside `BossSystem.spawn_boss()` violates Pillar 1 chain (transition_id null). CI lint scope: `tools/ci/check_boss_direct_instantiate.gd` added to BOSS-AC-followup-08 tooling story.

**Field immutability**: `boss_id`, `boss_template`, `transition_id`, `player_stat_snapshot` set once in `spawn_boss` BEFORE `add_child(boss)`; runtime mutation = bug (Rule 16 NEVER #8).

---

- All boss content stored in `res://data/bosses/*.tres`
- `BossRegistry` singleton at `res://data/boss_registry.tres` maps `boss_id` → template
- Templates **immutable at runtime**；read-only consumer pattern
- Mini-boss content stored separately under `res://data/enemies/mini_boss_*.tres` as EnemyTemplate (owned by #14 wave system, NOT #16)
- BossInstance scenes stored at `res://scenes/bosses/*.tscn` with root node type = `BossInstance` + required children per contract above

---

#### Rule 2 — Boss Spawn Selection Algorithm

**Triggered by**: #14 EnemyDirector BossAnchor pipeline (per #14 Rule 13 + Formula 5)

**Input snapshot at COMMITTED state**:
- `dominant_class` from `WorkoutSummaryRO.dominant_class` (already cached via #9 Rule 10 emission order)
- `total_planned_sets` from workout summary (for mini vs final classification)
- `transition_id` from BossAnchor commit (per ADR-006 Contract 2)

**Selection** (revised 2026-05-27 — STANDARD removed; mini-boss path moved to #14):
```
# #16 only spawns FINAL boss. Mini-boss spawn = #14 wave system responsibility.
if total_planned_sets <= LIGHT_WORKOUT_THRESHOLD_SETS (=2 per #14):
    # Light-workout path — #16 does NOT spawn final boss. #14 wave system handles
    # light-workout mini-boss via EnemyTemplate. See Rule 10 for spec.
    return  # no #16 action

selected_class = dominant_class if dominant_class != UNKNOWN else STRIKE  # Rule 13 (presentation-only)
candidates = BossRegistry.query(tier == FINAL, class_archetype == selected_class)
boss_template = pick_deterministic(candidates, seed=DeterministicHash.deterministic_hash(transition_id))   # Pass 4 A2.2 — FNV-1a; cross-platform stable
```

- **MVP**: 1 final boss (STRIKE UNKNOWN fallback per Rule 13) — multi-archetype roster deferred per Pillar 4 Scope Honesty Note
- **Post-MVP path**: 1 final boss per archetype × 3 = 3 final boss templates
- Selection 100% deterministic for same `transition_id` (Pillar 1 anti-fabrication chain integrity)

---

#### Rule 3 — Mini-boss vs Final-boss Architecture (revised 2026-05-27 — CRIT-4 resolution)

**Mini-boss = EnemyTemplate via #14 wave system. #16 only owns Final-boss.** Per CRIT-4 decision, mini-boss bypass #16 entirely — uses EnemyTemplate resource type, spawn via #14 wave/light-workout path, cleanup via #14 wave despawn. #16 GDD documents mini-boss expectations as forward constraint to #14 (NOT as #16 implementation).

| Aspect | Mini-boss (owned by #14) | Final-boss (owned by #16) |
|--------|--------------------------|---------------------------|
| **Resource type** | `EnemyTemplate` (with elevated HP/damage stats + boss flag) | `BossTemplate` (this GDD's schema) |
| **Spawn pipeline** | #14 wave system (mid-workout) OR #14 light-workout fallback (Rule 10) | #16 `spawn_boss()` via #14 BossAnchor COMMITTED |
| **Spawn trigger** | Mid-workout exercise switch OR `total_planned_sets ≤ 2` light-workout | `workout_completed` via #14 BossAnchor COMMITTED |
| **Loot guarantee** | **Guaranteed 1 drop, UNCOMMON floor / RARE ceiling** (Pass 4 A3.1 — restores game-concept「uncommon-rare 範圍」public promise) | GUARANTEED 1 drop, ≥ RARE floor (Pass 4 A3.1 — raised UNCOMMON→RARE to preserve gradient now mini ceiling = RARE), no ceiling (ADR-005 can push EPIC/LEGENDARY via volume + PR + streak modifiers) |
| **Reveal ritual** | Rule 7 **lite** (particle burst + shake; **NO camera focal**) at intensity 0.6× | Rule 7 **full** (camera focal + shake + particle) at intensity 1.0× |
| **HP scaling target** | 4-6 hit kill window (per #14 EnemyTemplate config) | 9-12 hit kill window (per Formula 1) |
| **Attack patterns** | 1 EnemyTemplate.attack_pattern (single) | 2-3 patterns array (Rule 6 + Formula 3 round-robin) |
| **Cleanup** | #14 wave despawn (NOT Rule 11) | Rule 11 with `_spawned_emitters` release |
| **enemy_killed.transition_id source** | Wave transition_id (per #14 Rule 12) | BossAnchor commit transition_id |
| **`reveal_ritual_intensity` field** | NOT on EnemyTemplate — hardcoded 0.6 by #14 wave system | BossTemplate.reveal_ritual_intensity (default 1.0) |
| **`loot_guarantee_min_tier` field** | NOT on EnemyTemplate — hardcoded `UNCOMMON_CEILING` semantics by #14 | BossTemplate.loot_guarantee_min_tier (default COMMON) |

**Forward constraint to #14**：Mini-boss spawn pipeline 同 EnemyTemplate elevated stats 嘅 spec 由 #14 GDD next-revision 補足。#16 GDD 純 document expected behavior 作為 reference。

**Why this split**：
- 避免 mini-boss 同 final boss share BossTemplate schema 但有唔同 spawn path 嘅 dual-path ambiguity (per CRIT-4 gameplay-programmer concern)
- Loot guarantee semantics 用 EnemyTemplate flag (per #14) 而唔係 BossTemplate.loot_guarantee_min_tier — 避免 #15 LootDrop 雙重 contract
- Reveal ritual lite (NO camera focal) avoids mini-boss 喺 mid-workout 中斷 player 視覺 flow (Pillar 2 protection)

---

#### Rule 4 — Class Presentation Family Mapping (revised 2026-05-27 — CRIT-7 reframe)

**Per CRIT-7 resolution**：全自動戰鬥下 mechanical archetype 喺 peripheral vision invisible — reframe 做 **presentation family**（silhouette + audio + palette），唔係 mechanical archetype。Movement speed / attack range 嘅 mechanical 差異仍喺 BossTemplate 配置，但唔再聲稱 deliver Pillar 4 mechanical distinctness — 純粹係 visual variety。

| Class | Silhouette family | Audio signature | Particle palette | Mechanical (MVP STRIKE fallback only) |
|-------|-------------------|-----------------|------------------|--------------------------------------|
| **STRIKE** (push muscles) | Large humanoid + oversized weapon | Heavy low brass + drum impacts | Red / orange dust + impact bursts | Slow MOVE_SPEED (60-90 px/s), wide-sweep melee, ATTACK_POWER-driven HP scaling per Formula 1 |
| **CONTROL** (pull muscles, post-MVP) | Caped figure + extended arm gestures | Mechanical / electric synth | Purple / violet projectile trails | Medium MOVE_SPEED (90-150 px/s), ranged stagger application |
| **MOBILITY** (leg muscles, post-MVP) | Multi-segment insectoid / agile creature | Whoosh / wind / chime | Yellow / cyan dash streaks | High MOVE_SPEED (180-300 px/s, capped by #14 ENEMY_MOVE_CAP=420), hit-and-run |
| **UNKNOWN** (fallback) | Per STRIKE (per Rule 13) | Per STRIKE | Per STRIKE | Per STRIKE |

**MVP scope**: Only STRIKE family is actually shipped (per Rule 13 UNKNOWN fallback + Pillar 4 Scope Honesty Note). CONTROL / MOBILITY rows above are spec for post-MVP — programmer 唔需要 implement 呢兩 class 嘅 mechanical 差異 in MVP sprint。

**Silhouette identifiability test** (per Section I): 縮圖至 32 px 純剪影 → 應辨認 family。Mechanical 差異 secondary — primary deliverable 係 sensory differentiation。

---

#### Rule 5 — Boss Difficulty Scaling Formula (addresses **D-2 gap** from /review-all-gdds)

**Rationale**: Per game-concept Flow State Design「靠真實訓練強度自然增長，Boss tier 跟玩家 1RM 進度自動調整 enemy stats」。Boss HP / damage 跟住 player stat snapshot scale。

**HP scaling** — target ~9-hit kill window at avg player ATTACK_POWER：
```
boss_max_hp = clamp(
    base_hp + (avg_player_attack_power × TARGET_KILL_HITS × HP_SCALE_FACTOR),
    MIN_BOSS_HP,   # anti-trivialize floor (e.g., 50)
    MAX_BOSS_HP    # anti-impossible ceiling (e.g., 10000)
)
```
- `avg_player_attack_power` = player StatSnapshot.ATTACK_POWER at boss commit time
- `TARGET_KILL_HITS` = 9 for final, 5 for mini (per #13 Q-D8 calibration)
- `HP_SCALE_FACTOR` = 1.0 (knob)

**Damage scaling** — target ~3-4 hit avatar window：
```
boss_attack_damage = clamp(
    round(avg_player_max_hp × DAMAGE_RATIO_PER_HIT),
    MIN_BOSS_DAMAGE,
    MAX_BOSS_DAMAGE   # anti-one-shot ceiling
)
```
- `avg_player_max_hp` = player StatSnapshot.MAX_HP at boss commit time
- `DAMAGE_RATIO_PER_HIT` = 0.28 for final (3-4 hits to kill), 0.18 for mini (5-6 hits) — knob

Snapshot frozen at COMMITTED state；boss fight uses same values throughout (Pillar 1 anti-fabrication chain)。Full Formula breakout in Section D。

**Snapshot caching enforcement (Pass 4 — A1.2 caller-passed ownership + CF-3 mechanism per systems-designer)**:
- **Owner**: #14 EnemyDirector caller captures `Stat.create_snapshot()` at BossAnchor COMMITTED tick + passes via `spawn_boss(..., player_snapshot)` 4th param (Pass 4 A1.2 + A1.3 canonical signature). BossSystem autoload does NOT hold global `_player_snapshot` state.
- `BossInstance.player_stat_snapshot: StatSnapshot` — frozen-at-spawn cached reference (assigned BEFORE add_child in spawn_boss per Rule 7 pseudocode)
- Formula 1 + Formula 2 **必須** read `boss.player_stat_snapshot.ATTACK_POWER` / `.MAX_HP` — **never** live-query `Stat` autoload mid-fight
- CI lint enforce: `tools/ci/check_boss_snapshot_caching.gd` greps for `Stat.get_attack_power()` / `.MAX_HP` calls inside `src/systems/boss/` and rejects
- Null-snapshot path: spawn_boss returns null + emits `boss.null_snapshot` telemetry + #14 BossAnchor rolls back to IDLE (no boss spawned); Pillar 1 forbids fabricating default snapshot
- Lifecycle: snapshot reference released via Godot GC when BossInstance freed (`_exit_tree`); no explicit clear API
- Resolves CF-3 invariant from wishful-thinking to architectural enforcement

**base_hp source** (Pass 3 — Formula 1 branching clarification per systems-designer):
- `base_hp` 直接 read from `boss_template.base_hp` (BossTemplate `.tres` per-boss configured value, e.g., STRIKE final = 200)
- 冇 if/else branch — designer 喺 `.tres` 入面 author per-archetype baseline，Formula 1 純讀
- Mini-boss base_hp 屬 #14 `EnemyTemplate.base_hp` (separate ownership per CRIT-4 split)

---

#### Rule 6 — Attack Pattern System

```gdscript
class_name AttackPatternResource extends Resource
@export var pattern_id: StringName
@export var telegraph_duration_sec: float = 0.5   # pre-attack windup
@export var hit_radius_px: float
@export var damage_multiplier: float = 1.0        # multiplied with boss_attack_damage (Rule 5)
@export var cooldown_sec: float = 2.0
@export var animation_name: StringName
```

- Boss cycles patterns per encounter
- Selection: deterministic round-robin OR sub-RNG seeded on transition_id + tick_count
- **Anti-spam rule**: same pattern NOT used twice in a row (force variety)
- v0.2: phase scripting (BOSS_PHASE_TRANSITION state per #14 hook)

---

#### Rule 7 — Boss Reveal Ritual Coordination (revised 2026-05-28 Pass 4 — A1.3 canonical signature lock + A1.4 async semantics + A2.3 GP3 post-add_child assert with is_equal_approx)

**Pass 4 canonical spawn_boss signature (A1.3 — supersedes Pass 3 3-param form)**:

```gdscript
func spawn_boss(
    template: BossTemplate,            # boss content data (immutable resource)
    transition_id: String,             # from #14 BossAnchor commit (NEVER empty, NEVER self-generated)
    spawn_pos: Vector2,                # world-space spawn position (per Rule 14 ArenaConstraintMode)
    player_snapshot: StatSnapshot      # A1.2 caller-passed; frozen at COMMITTED per CF-3 (NOT pulled from BossSystem global state)
) -> BossInstance
```

**Why 4 params (caller-passed snapshot — A1.2 owner/lifecycle resolution)**:
- **Owner**: #14 EnemyDirector (caller — captures `Stat.create_snapshot()` at BossAnchor COMMITTED before invoking spawn_boss). BossSystem autoload 唔 hold global `_player_snapshot` state — eliminates ownership ambiguity.
- **Capture timing**: #14 calls `Stat.create_snapshot()` at the same tick as BossAnchor.commit() — single snapshot reference passed straight through to BossInstance field. Removes the「whose responsibility to snapshot」question.
- **Clear timing**: snapshot reference released when BossInstance freed (`_exit_tree`). No external clear API; GC follows BossInstance lifecycle.
- **Null guard**: `spawn_boss` asserts `player_snapshot != null` at entry; null = #14 caller bug → emit `boss.null_snapshot(transition_id)` ERROR + early-return null + #14 BossAnchor rollback. NEVER fabricate a default StatSnapshot (Pillar 1 — fabrication forbidden).

**Spawn-then-position-then-add-then-reset-then-assert-then-emit ordering contract** (Pass 4 A2.3 — addresses Pass 3 GP3 fix bug per gameplay-programmer #4 + godot-specialist #1):
1. Caller (#14 EnemyDirector) computes `spawn_pos` per Rule 14 + captures `player_snapshot` per #11 Stat.create_snapshot()
2. `spawn_boss(template, transition_id, spawn_pos, player_snapshot)` 必須:
   - Entry-guard: `assert(transition_id != "" and player_snapshot != null)` + null-snapshot early-return path per A1.2
   - `boss = _instantiate_boss(template)` — `BossInstance.new()` via scene preload, NOT bare Resource
   - Set boss immutable fields BEFORE add_child: `boss.boss_id = template.boss_id`, `boss.boss_template = template`, `boss.transition_id = transition_id`, `boss.player_stat_snapshot = player_snapshot`
   - `boss.global_position = spawn_pos` (pre-add_child set — sets local position since not in tree yet)
   - synchronous `add_child(boss)` (NOT `call_deferred` — main-thread only contract)
   - **Re-set `boss.global_position = spawn_pos` AFTER add_child** (Pass 4 A2.3 fix — Pass 3 pre-add set was BEFORE node had parent reference; transform inheritance from parent applied at add_child time may translate the boss away from intended spawn_pos. Re-set forces global resolution AGAINST parent's current transform.)
   - `assert(boss.is_inside_tree(), ...)`
   - `assert(boss.global_position.is_equal_approx(spawn_pos), ...)` — **Pass 4 A2.3 fix** — `is_equal_approx()` tolerates Vector2 float drift from non-identity parent transform; exact `==` was false-positive prone per godot-specialist #1
   - emit `boss_committed` signal **with `spawn_pos` cached in payload** (downstream consumers 唔再依賴 boss.global_position late-read)
3. Signal payload typed: `signal boss_committed(template: BossTemplate, boss: BossInstance, snapshot: StatSnapshot, spawn_pos: Vector2, transition_id: String)`

**Parent-must-be-identity-transform contract (Pass 4 A2.3)**: BossSystem autoload root MUST have identity transform (`Transform2D.IDENTITY`). CI lint scope: `tools/ci/check_boss_parent_identity_transform.gd` (added to BOSS-AC-followup-08). Documented invariant: BossInstance only added as direct child of BossSystem autoload — never nested under transform-modifying parent (e.g., camera follower, world container with zoom).

**boss_committed async semantics (Pass 4 A1.4 — supersedes Pass 3 implicit assumption)**:
- **Emission**: synchronous immediately after position+assert, BEFORE spawn_boss returns. Subscribers receive signal callback before caller resumes.
- **Subscriber connection lifecycle**: subscribers (#5, #6, #7, AudioManager, #28 telemetry) connect via `_ready` using `connect_for_initial_state` pattern per ADR-006 Contract 6. NOT auto-connected by BossSystem (caller-managed).
- **Return value**: spawn_boss returns BossInstance reference immediately. Caller can chain (e.g., `var boss = BossSystem.spawn_boss(...); boss.hp_changed.connect(...)`) — but typically subscribers prefer signal payload over caller-chained access since payload is type-safe.
- **No await inside spawn_boss**: spawn_boss itself does NOT await; it is a synchronous one-shot. Any post-emit async work (e.g., Camera focal hold tail) happens inside subscriber handlers (`_on_boss_committed`), NOT inside spawn_boss.
- **No duplicate emit**: spawn_boss MAY be called multiple times across boss fights, but EC-01 idempotency guards against same-transition_id replay; legitimate re-calls with new transition_id are independent emit events.

**Camera-LEADING timeline diagram** (Pass 3 — F2 Hades/Hollow Knight pattern; Camera focal = attention director, must precede shake/particles):

```
Frame 0           Frame 1            Frame 2          Frame 3+        T=600ms+
│                 │                  │                │               │
├─────────────────┤ Camera focal     │                │               │
│ DISPATCH (lead) │ request_focal()  │                │               │
│ - attention     │ — zoom 1.0→1.4   │                │               │
│   anchor LOCK   │   begin (entry   │                │               │
│                 │   ease-out)      │                │               │
│                 │                  │
│                 ├──────────────────┤ Screen shake + Particles dispatch
│                 │                  │ - shake(0.5×mult, 0.3s)
│                 │                  │ - particles spawn
│                 │                  │ - audio cue
│                 │                  │
│                 │                  │
├──────────────────────────────────────┤ "Reveal dispatch budget" complete (≤2 frames)
│                                      │ - boss sprite visible
│                                      │ - HUD bar fade-in started
│
├─────────────────────────────────────────────────────┤ Camera focal hold (0.6s × mult)
│                                                     │ (async, runs in background; NOT blocking)
│
│                 ├─────────────────────────────────────────────────────┤  Gameplay interactive
│                 │ player avatar auto-combat enabled                    │
│                 │ (camera still holding focal — non-blocking)
```

**Key invariants** (Pass 3 reorder):
- **Camera focal entry = LEADING event** (frame 0 dispatch — claims player attention BEFORE shake/particles disperse it). Resolves F2 Mirror Moment psychological violation.
- **Shake + Particles + Audio = following events** (frame 1-2 dispatch — released after attention anchor locked).
- **"Reveal dispatch budget"** = ≤ 200ms (≤ 2 process frames, frame-count-based per AC-07).
- **"Camera focal hold tail"** = 0.6s × ritual_mult, runs async AFTER dispatch (non-blocking).
- All these are **separate measurements** — Pillar 2 sub-500ms boss-visible budget satisfied + Pillar 5 ritual anchor preserved.

**Pseudocode at COMMITTED state** (Pass 4 — A1.3 4-param signature + A2.3 post-add_child re-set + is_equal_approx + A1.2 caller-passed snapshot + A1.4 sync emit before return):

```gdscript
# Typed signal declaration (Godot 4.6 — runtime not enforced but tooling catches typos)
signal boss_committed(template: BossTemplate, boss: BossInstance, snapshot: StatSnapshot, spawn_pos: Vector2, transition_id: String)

# Position float tolerance — Pass 4 A2.3 per godot-specialist #1
const POSITION_TOLERANCE_PX: float = 0.5  # sub-pixel parent-transform drift acceptable

# spawn_boss: A1.3 canonical 4-param + A2.3 post-add_child re-set + is_equal_approx
func spawn_boss(
    template: BossTemplate,
    transition_id: String,
    spawn_pos: Vector2,
    player_snapshot: StatSnapshot   # A1.2 caller-passed (NOT BossSystem global state)
) -> BossInstance:
    # Pass 4 A1.4 — entry guards
    assert(OS.get_thread_caller_id() == OS.get_main_thread_id(), "spawn_boss MUST run on main thread")
    assert(transition_id != "", "Pillar 1 — transition_id MUST be non-empty (no fabrication)")
    if player_snapshot == null:
        # A1.2 null-guard — Pillar 1 forbids fabricating default snapshot
        push_error("BOSS_NULL_SNAPSHOT_001: spawn_boss invoked with null player_snapshot for transition_id=%s" % transition_id)
        _emit_telemetry("boss.null_snapshot", {"transition_id": transition_id})
        return null  # #14 BossAnchor caller MUST handle null return + rollback

    # EC-01 idempotency — same transition_id replay rejected (Pillar 1 chain integrity)
    if _spawned_transition_ids.has(transition_id):
        push_error("BOSS_DUP_SPAWN_001: duplicate spawn for transition_id=%s" % transition_id)
        return null
    _spawned_transition_ids[transition_id] = true

    var boss = _instantiate_boss(template)
    # Pass 4 A1.1 — set immutable fields BEFORE add_child (boss._ready asserts them)
    boss.boss_id = template.boss_id
    boss.boss_template = template
    boss.transition_id = transition_id
    boss.player_stat_snapshot = player_snapshot

    boss.global_position = spawn_pos          # pre-add_child set (local-position equivalent since detached)
    add_child(boss)                            # synchronous; NOT call_deferred
    boss.global_position = spawn_pos          # Pass 4 A2.3 — re-set AFTER add_child to force resolution against parent transform

    assert(boss.is_inside_tree(), "Boss MUST be in tree before commit signal")
    # Pass 4 A2.3 — is_equal_approx tolerates Vector2 float drift; exact == was false-positive prone
    assert(boss.global_position.is_equal_approx(spawn_pos),
        "Position must persist through add_child within %f px tolerance (got %s, expected %s)" %
        [POSITION_TOLERANCE_PX, boss.global_position, spawn_pos])

    # Pass 4 A1.4 — synchronous emit BEFORE return; subscribers receive callback before caller resumes
    boss_committed.emit(template, boss, player_snapshot, spawn_pos, transition_id)
    return boss

# A1.4 subscriber connection lifecycle — connected at _ready via connect_for_initial_state per ADR-006 Contract 6
# (NOT auto-connected by BossSystem; each #5/#6/#7/AudioManager/Telemetry consumer owns its subscription)
func _on_boss_committed(template: BossTemplate, boss: BossInstance, snapshot: StatSnapshot, spawn_pos: Vector2, transition_id: String):
    var ritual_mult = template.reveal_ritual_intensity   # 1.0 for final (mini handled by #14 lite path; F4 categorical)

    # FRAME 0 — Camera focal LEADING (attention anchor lock per Pass 3 F2)
    Camera.request_focal(
        target = spawn_pos,                              # cached payload; never boss.global_position late-read
        duration = 0.6 * ritual_mult,
        zoom = 1.4
    )

    # FRAME 1-2 — Shake + Particles + Audio follow (released after attention captured)
    await get_tree().process_frame
    ScreenEffects.shake(intensity = 0.5 * ritual_mult, duration = 0.3)
    ParticleSystem.spawn(
        preset = ParticlePreset.LOOT_RARE_BURST,   # MVP reuse; flag for BOSS_REVEAL preset addition (Q-X1)
        position = spawn_pos,
        caller_mult = ritual_mult
    )
    if AudioManager:
        AudioManager.play_cue(template.audio_template_id)
```

- All dispatch via existing wrapper APIs；唔加新 coupling
- **Camera focal MUST lead** (frame 0) — Pass 3 F2 fix
- **Dispatch budget ≤ 200ms / ≤ 2 process frames** (per Pillar 2 sub-500ms boss visible budget per #9 AC-41 + #14 FR-2)
- **Camera focal hold 0.6s** runs async AFTER dispatch — NOT blocking gameplay
- **CF-3 snapshot caching**: `boss.player_stat_snapshot` 喺 spawn 時凍結，Formula 1+2 永遠 read 呢個 cached snapshot (NOT live #11 query) — see Rule 5 revision
- **Open Question Q-X1**: 應否喺 #5 GDD next-revision 加 `BOSS_REVEAL` preset，定 reuse `LOOT_RARE_BURST`？MVP reuse；v0.2 dedicated preset

---

#### Rule 8 — Boss Kill → enemy_killed Emission

**Sequence on boss HP ≤ 0** (per #13 Rule 9 + #14 Rule 5):
1. #13 CombatResolver detects damage_dealt ≥ boss.current_hp → outcome = KILLED
2. #14 EnemyDirector receives hit_resolved, emits `enemy_killed` with payload per #14 enemy_killed_signal_signature
3. Payload fields filled by #14 (NOT #16): enemy_id=boss_id, enemy_instance_id, killer_id=player, killing_ability, transition_id (matches BossAnchor commit), is_overkill, overkill_excess
4. #14 BossAnchor transitions COMMITTED → IDLE
5. #16 boss instance plays death animation, then call_deferred(queue_free) (Rule 11)
6. #15 LootDrop (Not Started) subscribes enemy_killed → uses transition_id as RNG seed → ADR-005 formula → loot drop

**Anti-fabrication chain**: `transition_id` 必須 match #14 BossAnchor commit ID。#16 唔 generate own transition_id (Pillar 1 chain integrity per ADR-006 Contract 2).

---

#### Rule 9 — Loot Guarantee (revised 2026-05-27 — CRIT-2 STANDARD removed + E2 mini-boss reframe)

| Boss Tier | Owner | Loot count | Rarity range | Implementation |
|-----------|-------|-----------|---------------|----------------|
| Mini-boss (`EnemyTemplate` flag) | **#14 wave system** | **1 (guaranteed)** | **UNCOMMON floor / RARE ceiling** (Pass 4 A3.1 — restores game-concept「uncommon-rare 範圍」public promise; Pass 3 COMMON-UNCOMMON violated this promise) | `EnemyTemplate.loot_modifier = MINI_BOSS_LOOT` + `loot_rarity_floor = UNCOMMON` + `loot_rarity_ceiling = RARE`; #14 owns three fields per next-revision (Followup #15 expanded scope) |
| FINAL (`BossTemplate`) | **#16 (this GDD)** | 1 (guaranteed) | **≥ RARE floor** (Pass 4 A3.1 — raised Pass 3 UNCOMMON→RARE to preserve dramatic weight gradient over mini ceiling RARE; final boss climax 必須超越 light-workout reward), no ceiling (ADR-005 modifiers push EPIC/LEGENDARY) | `BossTemplate.loot_guarantee_min_tier = RARE` |

**Removed**: STANDARD tier — was dead code per CRIT-2 (Rule 2 spawn algorithm 永遠唔 spawn STANDARD).

**Rationale for mini-boss UNCOMMON-RARE band** (Pass 4 A3.1 — restores game-concept promise):
- **Pillar 3 ritual preserved**: 每個 mini-boss kill 都有 loot drop = ritual feel 唔斷層
- **Pillar 1 honesty preserved via tier cap, not via floor depression**: ceiling = RARE (NOT EPIC/LEGENDARY) — light workout 唔會 deliver top-tier rewards = effort honesty intact
- **Avoids「做咗 mini-boss 但 COMMON skip」punishment**: COMMON tier inflation (per Pass 3 fresh-session economy-designer #1 + game-designer #2) was forming「又係 COMMON」player frustration. UNCOMMON floor lifts mini-boss out of the「skip-able junk」rarity stratum.
- **Game-concept public promise restored**: game-concept Section「Short-Term (5-15 minutes) — Exercise-switch Loop」literally states「擊敗 mini-boss → minor loot drop（uncommon-rare 範圍）」— Pass 3 COMMON-UNCOMMON violated this explicit promise. Pass 4 restores it.

**Dramatic weight gradient preservation** (Pass 4 A3.1 — final raised to RARE floor):
- Mini ceiling = RARE; final floor = RARE (joint at RARE)
- Gradient mechanism = ADR-005 modifiers (workout_score: volume + PR + streak), NOT static tier comparison. Final boss benefits from full workout's accumulated volume_factor + PR breakthroughs + streak buff → ADR-005 lifts mean tier toward EPIC/LEGENDARY for full workouts.
- Mini-boss has compressed modifier window (single exercise volume) — mean tier sits at UNCOMMON-RARE band edge, not pushing into EPIC zone.
- **Net effect**: light workout median = UNCOMMON-RARE, full workout median = RARE-EPIC (modifier-driven), with both anchored to「mini ≤ RARE ≤ final」joint floor.

- #16 only carries the FINAL flag；#15 LootDrop implements actual loot generation
- **Mini-boss loot semantics 移交 #14**：`EnemyTemplate.loot_modifier` 屬 #14 next-revision spec scope (forward constraint)
- **#15 LootDrop tier alignment** (per CRIT-5): #15 upgraded to VS tier (joint with #16) — VS milestone delivers complete Pillar 3 reward loop。See systems-index for tier change confirmation。

---

#### Rule 10 — Light-Workout Path (revised 2026-05-27 — mini-boss 移交 #14)

When `workout_summary.total_planned_sets <= LIGHT_WORKOUT_THRESHOLD_SETS` (=2 per #14 owned constant):
- **#14 wave system spawns mini-boss as final encounter** (EnemyTemplate with `MINI_BOSS_LOOT` flag)
- **#16 does NOT trigger** — `spawn_boss()` early-return per Rule 2 revised algorithm
- BossAnchor 仍然 transition COMMITTED→IDLE 作為 workout_completed acknowledgment，但唔 invoke #16
- Mini-boss reveal ritual = lite (particle burst + shake, NO camera focal — per Rule 3 revised table)
- Loot = guaranteed 1, **UNCOMMON floor / RARE ceiling** (Pass 4 A3.1 — per Rule 9 revised; restores game-concept promise)
- Pillar 1 honesty: light workout 唔 deliver final boss climax，但 mini-boss kill ritual 仍 acknowledge effort

**Open Question Q-X5 (new — per Q2 light-workout framing concern)**:
應否引入 `session_intent` flag (玩家喺 GymSys self-mark「recovery day」/「full session」/「quick warm-up」)，作為 light-workout-vs-full-workout 嘅 primary trigger，而唔係用 set count threshold？

- **Pro**: 解決「2 sets 對某啲玩家係完整 mobility/deload session」嘅 punishment framing 問題 (per game-designer Q2)
- **Con**: 需要 GymSys backend extension + UI add (額外 scope)
- **MVP path**: 沿用 set count threshold；session_intent 列為 Pre-MVP feature candidate (gates on GymSys API extension feasibility)

---

#### Rule 11 — Boss Resource Cleanup (revised 2026-05-27 Pass 3 — GP2 await guards + GP4 wall-clock timeout + GP6 idempotent release)

**Pass 3 fixes vs Pass 2:**
- **GP4** `Awaitable.race()` 喺 Godot 4.6 唔存在 — 改用 explicit CONNECT_ONE_SHOT + wall-clock deadline pattern
- **GP4** `SceneTreeTimer(3.0)` 跟 process_frame，Web Export tab freeze 期間唔 advance — 改用 `Time.get_ticks_msec()` wall-clock deadline + visibilitychange hook
- **GP6** `_spawned_emitters` double-release risk — ParticleSystem.release() 必須 idempotent (cleared from set after release)

```gdscript
const CLEANUP_TIMEOUT_MS: int = 3000  # 3.0s wall-clock deadline (bfcache-safe)

func _on_enemy_killed_self_listen() -> void:
    # GP2 resolution: guard against node freed before signal arrives
    if not is_instance_valid(self) or not is_inside_tree():
        return

    var anim_player := $AnimationPlayer
    anim_player.play("death")

    # GP4 Pass 3 — wall-clock deadline (NOT SceneTreeTimer; bfcache-safe)
    var deadline_ms := Time.get_ticks_msec() + CLEANUP_TIMEOUT_MS
    var anim_done := false
    var on_finished := func(): anim_done = true
    anim_player.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)

    # Poll loop — yields each frame, checks wall-clock deadline + animation completion
    while not anim_done and Time.get_ticks_msec() < deadline_ms:
        await get_tree().process_frame
        if not is_instance_valid(self):
            return   # freed during await

    if anim_player.animation_finished.is_connected(on_finished):
        anim_player.animation_finished.disconnect(on_finished)

    # GP2 resolution: re-check validity after polling loop
    if not is_instance_valid(self):
        return

    _cleanup_resources()
    queue_free()

func _cleanup_resources() -> void:
    # GP6 Pass 3 — idempotent: clear set after release to prevent double-release on bfcache resume re-entry
    for emitter in _spawned_emitters:
        if is_instance_valid(emitter):
            ParticleSystem.release(emitter)
    _spawned_emitters.clear()

# Bfcache emergency cleanup — Pass 4 A2.1 Web Export multi-hook handler
# (NOTIFICATION_APPLICATION_RESUMED doesn't fire reliably on Web Export per godot-specialist + gameplay-programmer Pass 3 finding)
func _ready() -> void:
    # Subscribe to platform_detect.gd autoload signal (per ADR-001 routing)
    # PlatformDetect autoload owns the JavaScriptBridge `pageshow` event listener via
    # `JavaScriptBridge.eval()` (the only allowed eval callsite per ADR-001).
    if PlatformDetect.has_signal("page_shown_from_bfcache"):
        PlatformDetect.page_shown_from_bfcache.connect(_on_resume_detected)

func _notification(what: int) -> void:
    # Multi-hook coverage — different Godot 4.6 Web Export builds + browser combinations
    # fire different subset of focus notifications on bfcache resume:
    # - NOTIFICATION_APPLICATION_FOCUS_IN: desktop + most Web Export resume paths
    # - NOTIFICATION_WM_WINDOW_FOCUS_IN: window-manager focus (covers tab switch on Chromium)
    # - Safari bfcache: NEITHER fires; only `pageshow` JS event → PlatformDetect signal
    if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        _on_resume_detected()
    # NOTE: NOTIFICATION_APPLICATION_RESUMED intentionally NOT listed —
    # Godot 4.6 Web Export docs confirm this notification only fires on mobile native (Android/iOS),
    # NOT on browser bfcache. Pass 4 A2.1 removes Pass 3 reliance on it.

func _on_resume_detected() -> void:
    # Idempotent emergency cleanup — _spawned_emitters may have orphaned refs after bfcache
    _cleanup_resources()
```

**Web Export lifecycle hook coverage matrix (Pass 4 A2.1)**:

| Resume scenario | Reliable signal | Pass 4 handler |
|-----------------|-----------------|----------------|
| Chromium tab switch back | `NOTIFICATION_APPLICATION_FOCUS_IN` | `_notification` branch |
| Chromium WindowFocus return | `NOTIFICATION_WM_WINDOW_FOCUS_IN` | `_notification` branch |
| Safari bfcache restore | JavaScriptBridge `pageshow` event | `PlatformDetect.page_shown_from_bfcache` signal subscribe in `_ready` |
| Mobile native (post-MVP) | `NOTIFICATION_APPLICATION_RESUMED` | NOT applicable to Web Export MVP target |

**Forward dependency**: `platform_detect.gd` autoload MUST declare `page_shown_from_bfcache` signal + own the `JavaScriptBridge.eval()` callsite per ADR-001 "no eval outside platform_detect.gd" forbidden-pattern. If `PlatformDetect.has_signal("page_shown_from_bfcache")` returns false (autoload not yet implemented), BossInstance falls back to `_notification` paths only — Safari bfcache will skip emergency cleanup until autoload lands. Added to BOSS-AC-followup-08 + new BOSS-AC-followup-18 (Web Export lifecycle reference doc) cross-system constraint.

- Cleanup ≤ 2 frames post-death animation (normal path)
- `is_instance_valid()` guards required before AND after every `await` (per GP2 — Godot 4.6 Web Export async safety)
- **Wall-clock deadline (3000ms)** prevents indefinite hang on bfcache-dropped `animation_finished` signal (per GP4 Pass 3)
- **Bfcache freeze-safe**: `Time.get_ticks_msec()` continues during frozen frames (wall-clock), unlike SceneTreeTimer which pauses with process loop
- **Idempotent release** (per GP6 Pass 3): `_spawned_emitters.clear()` after release loop — `_notification(NOTIFICATION_APPLICATION_RESUMED)` re-entry safe
- #14 BossAnchor IDLE transition handled by #14, NOT #16
- Free particle / audio resources via wrapper APIs (Pillar 2 budget compliance)
- **Bfcache mid-fight contract (Pass 4 A2.1 Web Export multi-hook)**: If tab freeze occurs mid-death-animation, resume triggers ONE of three reliable paths: (a) `_notification(NOTIFICATION_APPLICATION_FOCUS_IN)`, (b) `_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)`, (c) `PlatformDetect.page_shown_from_bfcache` signal (Safari path) — any of them invokes `_cleanup_resources()` defensively. Already-released emitters cleared from set on first release, second call no-ops. 具體實現見 EC-17 revised。

---

#### Rule 12 — Persistence Considerations (revised 2026-05-28 Pass 4 A3.2 — mid-fight bfcache hybrid per CD Pillar 1 vs Pillar 2 adjudication)

- Boss instance **transient** — NOT persisted to `wst.*` / `boss.*` namespace
- BossTemplate definitions = read-only `.tres` resources (no migration concerns)
- **Mid-fight bfcache resume hybrid (Pass 4 A3.2 — CD adjudicated game-designer position correct)**: Pass 3 「always restart at FULL HP」 erased honest-derived state (HP IS derived from honest workout output via Formula 1+2; resetting fabricates a higher-effort fight than honest progression earned). Pass 4 implements skip-to-kill / restart hybrid:

  ```
  On bfcache resume mid-fight (detected via Rule 11 _on_resume_detected multi-hook):
    if workout_completed emitted pre-freeze (transition_id committed in #14 BossAnchor):
      if boss.current_hp < boss.max_hp × MID_FIGHT_SKIP_HP_THRESHOLD (default 0.30):
        # SKIP-TO-KILL path — Pillar 2 continuity + Pillar 3 reward chain preserved
        # Boss already meaningfully wounded; bfcache resume must not erase ≥70% damage progress.
        # Skip remaining HP, trigger death animation directly, emit enemy_killed with cached transition_id.
        boss.current_hp = 0
        boss._enter_state(EnemyAIState.DYING)   # AnimationPlayer.play("death") via Rule 11
        # enemy_killed emit happens via #14 standard pipeline on DYING state
        emit_telemetry("boss.bfcache_skip_to_kill", {boss_id, hp_at_freeze, threshold})
      else:
        # RESTART-AT-FULL-HP path — Pillar 1 honesty (boss had ≥70% HP, fight scarcely started)
        # No fabrication concern — boss restarts from designed initial state, NOT mid-derived state.
        boss.current_hp = boss.max_hp
        boss._enter_state(EnemyAIState.SPAWNING)   # re-runs reveal ritual (Rule 7)
        emit_telemetry("boss.bfcache_restart_full_hp", {boss_id, hp_at_freeze})
    else:
      # workout_completed NOT emitted (e.g., PRE_SPAWN freeze before commit)
      # — boss shouldn't exist mid-resume; cleanup defensively. Real workout flow re-triggers via #14.
      boss._cleanup_resources()
      boss.queue_free()
  ```

- **Rationale (Pillar 1 vs Pillar 2 adjudication per Pass 3 fresh-session CD synthesis)**: Pillar 1「real_body real_power」protects against FABRICATED values (e.g., spoofed PR, synthetic class assignment) — boss HP at 30% IS derived honestly from real player damage. Reset-to-full erases that honest derivation. CD verdict: "Pillar 1 anti-fabrication spirit 守 transition_id chain，HP 已 derived from honest workout output 唔係 fabricated value。Reset 反而 erase 咗 honest derived state."
- **Threshold 30% selected because**: (a) below 30% = fight psychologically「nearly done」— player expects kill payoff; (b) above 30% = fight just begun — restart feels less disruptive than fabricated mid-state; (c) tunable via `MID_FIGHT_SKIP_HP_THRESHOLD` knob if playtest reveals different boundary.
- **Open Question Q-X2 resolved (Pass 4 A3.2)**: mid-fight resume = hybrid skip-to-kill (HP<30%) / restart-at-full (HP≥30%) / cleanup (no commit). Closed. Telemetry events allow Pre-MVP playtest to calibrate threshold.

---

#### Rule 13 — UNKNOWN Class Fallback (Pillar 1 honesty)

When `WorkoutSummaryRO.dominant_class == &"UNKNOWN"` (per #9 Rule 5 sticky-last-leader returning UNKNOWN OR per #9 CI-3):
- #16 spawn selection uses STRIKE class archetype (consistent with #14 EC-09 fallback policy)
- Boss template tag = `class_archetype = STRIKE` in registry
- Telemetry log: `boss.unknown_class_fallback(workout_id, transition_id)` for #28 future consumer
- **#16 NEVER fabricates a synthetic「mixed」or「balanced」class boss** — Pillar 1 honesty: 冇明確 dominant class = 用 simplest archetype

---

#### Rule 14 — Boss Spawn Position + Arena Constraint (revised 2026-05-27 Pass 3 — GP5 coordinate space spec + GP7 ARENA_WIDTH_PX source resolution)

**ARENA_WIDTH_PX source (Pass 3 — GP7 resolution)**:
- 新增 `res://data/arena_config.tres` (ArenaConfig Resource) 作 **single source of truth** for arena dimensions
- `ArenaConfig.arena_width_px: float` (default 1920.0 — Web Export base resolution; mobile downscales but world units 不變)
- `ArenaConfig.arena_height_px: float` (default 1080.0)
- 由 `#14 EnemyDirector` autoload load + cache，#16 spawn_boss 透過 `EnemyDirector.arena_config.arena_width_px` 讀取（避免重複 load）
- **Cross-system 一致使用**：Camera bounds (#7) + spawn algorithm (#16) + enemy AI patrol bounds (#14) 全部 reference 同一個 `ArenaConfig.tres`
- **Forward constraint to #14 GDD next-revision**: ArenaConfig Resource ownership + autoload exposure path

- Default spawn: `avatar.position + Vector2(EnemyDirector.arena_config.arena_width_px × 0.6, 0)` — right side off-screen near edge
- Per-boss arena constraint via **`BossTemplate.arena_constraint_mode` enum** + `BossTemplate.arena_constraint_px: Vector2`

**`ArenaConstraintMode` enum semantics** (per GP5 resolution):

| Mode | Interpretation | Use case |
|------|----------------|----------|
| `WORLD_ABSOLUTE` | `boss.position.clamp(arena_min_world, arena_max_world)` where bounds = `Vector2.ZERO ± arena_constraint_px` | Fixed arena (single screen) |
| `SPAWN_RELATIVE` (default) | `boss.position.x ∈ [spawn_pos.x ± arena_constraint_px.x]` 同 y axis | Boss tied to spawn point, avatar can wander away |
| `AVATAR_LEASH` | `boss.position` follows avatar but `abs(boss.position - avatar.position) ≤ arena_constraint_px` | Boss leash-chase, never escapes player |

**Default**: `SPAWN_RELATIVE` with `arena_constraint_px = Vector2(300, 200)` — boss stays within 300px x / 200px y of spawn position。

**Coordinate space**:
- `arena_constraint_px` values 係 **world-space pixels** at Camera2D zoom = 1.0
- 唔受 Camera2D zoom (1.4× during reveal ritual per Rule 7) 影響 — constraint check 用 world position 唔係 screen position
- Web Export SubViewport oversample (per ADR-001) 不影響 — constraint 全部喺 game world unit 度量

**MVP**: single-screen arena；v0.2 multi-screen boss room

---

#### Rule 15 — Boss AI State Inheritance

- Boss inherits `#14 enemy_ai_state_enum` (SPAWNING | IDLE | PURSUING | ATTACKING | STAGGERED | DYING)
- MVP: 冇新 state；boss 用同 enemy 一樣 state lifecycle (但 transition timing 可以 differ via BossTemplate tuning)
- v0.2 hook: `BOSS_PHASE_TRANSITION` state for multi-phase bosses (per #14 Q-Boss-Phase-Script)

---

#### Rule 16 — Anti-fabrication Invariants (12 NEVERs)

#16 **NEVER** does:

1. **NEVER spawns a boss without #14 BossAnchor commit transition_id** (Pillar 1 chain)
2. **NEVER fabricates a non-STRIKE fallback when class UNKNOWN** (Rule 13)
3. **NEVER generates own transition_id** — always inherits from #14 (Pillar 1)
4. **NEVER allows boss HP < MIN_BOSS_HP floor** (Rule 5 anti-trivialize)
5. **NEVER allows boss damage > MAX_BOSS_DAMAGE ceiling** (Rule 5 anti-one-shot)
6. **NEVER guarantees a loot drop without enemy_killed emission** (chain integrity — guarantee is #15's job, signaled by #16's `loot_guarantee_min_tier` flag)
7. **NEVER spawns multiple final-bosses concurrently** (single climax target)
8. **NEVER mutates BossTemplate at runtime** (read-only resources)
9. **NEVER permits player input mutation of boss state** (Pillar 2)
10. **NEVER persists boss instance HP / position** (Rule 12 — transient)
11. **NEVER spawns boss from non-workout trigger** (Pillar 1 — real workout required)
12. **NEVER allows mini-boss visual to exceed final-boss intensity** (Rule 7 dramatic weight gradient `reveal_ritual_intensity` mini ≤ 0.6 < final 1.0)

---

### States and Transitions

**Boss instance reuses #14 enemy_ai_state_enum** (no new states for MVP):

| State | Entry | Exit | #16 specific behavior |
|-------|-------|------|----------------------|
| SPAWNING | #14 BossAnchor COMMITTED → boss instance created | Reveal ritual complete (Rule 7) | Play boss reveal animation; emit visual ritual signals |
| IDLE | Reveal complete | First attack cooldown elapsed | Avatar enters arena range |
| PURSUING | Avatar not in attack range | Avatar in attack range OR boss stagger | Move toward avatar bounded by arena_constraint_px (Rule 14) |
| ATTACKING | Attack pattern triggered | Pattern cooldown begins | Execute attack pattern from Rule 6 |
| STAGGERED | Avatar lands HEAVY+ hit (#13 damage_tier) | Stagger duration elapsed | Defensive animation, no attack |
| DYING | HP reaches 0 | Death animation finishes | Trigger Rule 8 emission; cleanup per Rule 11 |

**v0.2 hook**: `BOSS_PHASE_TRANSITION` state — boss with multi-phase scripting transitions through phases at HP thresholds (e.g., 66% / 33%) firing visual / pattern set changes.

---

### Interactions with Other Systems

| # | System | Direction | Interface | Owner | Notes |
|---|--------|-----------|-----------|-------|-------|
| #9 | Workout State Tracker | upstream subscriber | `workout_summary_available(summary)` for dominant_class + total_planned_sets snapshot at boss spawn time | #9 | Read at COMMITTED via #14 |
| #11 | Stat System | upstream snapshot reader | `Stat.create_snapshot()` at boss commit → reads ATTACK_POWER / MAX_HP / CRIT_CHANCE for Rule 5 scaling formula | #11 | Snapshot frozen for duration of boss fight |
| #13 | CombatResolver | upstream caller | `compute_hit_damage(boss as target)` + `hit_resolved` emission with damage_tier classification | #13 | Boss = standard EnemyState target |
| #14 | EnemyDirector | upstream caller + downstream listener | (a) calls `BossSystem.spawn_boss(template: BossTemplate, transition_id: String, spawn_pos: Vector2, player_snapshot: StatSnapshot) -> BossInstance` on BossAnchor COMMITTED (Pass 4 A1.3 canonical 4-param + A1.2 caller-passed snapshot); (b) emits `enemy_killed` on boss death | #14 | Locked BossAnchor lifecycle contract |
| #15 | Loot Drop System (Not Started) | downstream subscriber | Receives `enemy_killed(boss_id, transition_id)` from #14; reads `BossTemplate.loot_guarantee_min_tier` flag for guarantee logic | #15 | Provisional contract |
| #5 | Particle System Wrapper | downstream caller | `ParticleSystem.spawn(preset=LOOT_RARE_BURST, caller_mult=ritual_mult)` per Rule 7 reveal | #5 | MVP reuse; v0.2 BOSS_REVEAL preset (Q-X1) |
| #6 | Screen Effects | downstream caller | `ScreenEffects.shake(intensity=0.5*ritual_mult, duration=0.3)` per Rule 7 | #6 | Direct call path |
| #7 | Camera System | downstream caller | `Camera.request_focal(target=boss_pos, duration=0.6*ritual_mult, zoom=1.4)` per Rule 7 | #7 | Direct call path |
| #4 | Audio Manager (Not Started) | downstream caller | `AudioManager.play_cue(boss_template.audio_template_id)` per Rule 7 | #4 | MVP placeholder (graceful no-op if #4 absent) |
| #1 | GameStateMachine | upstream | transition_id inherited via #14 BossAnchor pipeline (ADR-006 Contract 2) | #1 | NEVER generates own transition_id |
| #3 | PersistenceLayer | NONE | Boss instance transient per Rule 12 — no `boss.*` namespace registered | #3 | No persistence dependency |
| #28 | Telemetry (Not Started) | downstream subscriber | `boss.spawned / killed / fallback_unknown_class / mid_fight_resume` events | #28 | Provisional |

**Bidirectional sync gaps** (Rule 14 batch for next-revision):
- #14 EnemyDirector: confirm `BossSystem.spawn_boss(template_id, transition_id)` API signature
- #5 Particle System: flag for v0.2 `BOSS_REVEAL` preset addition (Q-X1)
- #15 LootDrop (Not Started): `loot_guarantee_min_tier` consumer contract
- systems-index: confirm #16 → 9/13/14/15 + add #16 → 5/6/7 (visual ritual)

## Formulas

#16 owns 4 formulas — all derive boss-fight params from player real-stat snapshot (Pillar 1 chain) at BossAnchor COMMITTED time。

---

### Formula 1 — `boss_max_hp_scaling`

**Rationale**: addresses **D-2 gap** — boss HP 隨 player ATTACK_POWER scale，目標維持 stable kill-hit window (per #13 Q-D8 calibration)，避免 late-game bullet sponge OR trivial one-shot。

The `boss_max_hp_scaling` formula is defined as (Pass 4 A3.3 — first-session duration fallback per game-designer first-session frustration finding):

```
# Pass 4 A3.3 — first-session bootstrap when player_attack_power == 0 (degenerate boot OR true first session)
# Without fallback, EC-05 path produces boss_max_hp = MIN_BOSS_HP = 50 → 2-3 hit kill → trivial reveal ritual
# → Pillar 3 climax 失效 喺 player 第一次體驗。This is the worst possible first impression — fallback ensures
# meaningful (not trivial, not impossible) fight even before #11 StatSnapshot has real lift data.
if player_attack_power == 0:
    # Duration-based bootstrap — uses workout_duration_sec (#9 WorkoutSummaryRO field) as proxy
    # for "player has been in gym for X seconds → estimated effort level"
    duration_factor = clampf(workout_duration_sec / FIRST_SESSION_DURATION_TARGET_SEC, 0.0, 1.0)
    effective_atk = max(BOOTSTRAP_ATTACK_POWER, duration_factor × FIRST_SESSION_BASELINE_ATK)
    # Emit telemetry — Pre-MVP playtest validates duration→effort mapping
    emit_telemetry("boss.first_session_bootstrap", {workout_duration_sec, effective_atk})
else:
    effective_atk = player_attack_power

boss_max_hp_raw = base_hp + (effective_atk × TARGET_KILL_HITS × HP_SCALE_FACTOR)
boss_max_hp = clamp(boss_max_hp_raw, MIN_BOSS_HP, MAX_BOSS_HP)
```

**Knob defaults (Pass 4 A3.3)**:
- `BOOTSTRAP_ATTACK_POWER = 10` (matches #11 ATTACK_POWER floor — boss winnable in ~9 hits at base_hp=200, HP_SCALE_FACTOR=1.0)
- `FIRST_SESSION_BASELINE_ATK = 28` (matches CF-1 baseline ATTACK_POWER per #13 calibration — yields engaging fight by mid-workout)
- `FIRST_SESSION_DURATION_TARGET_SEC = 600` (10 minutes — typical "first set done" milestone; ramps fallback to baseline)

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Per-boss baseline | `base_hp` | int | [50, 500] | BossTemplate-defined floor (default 80 for STRIKE mini, 200 for STRIKE final) |
| Player ATTACK_POWER snapshot | `player_attack_power` | float | [1.0, 4500.0] | From #11 Formula 4 via StatSnapshot at BossAnchor COMMITTED |
| Target hits to kill | `TARGET_KILL_HITS` | int | [3, 18] | Final boss = 9, mini-boss = 5 (knob) |
| HP scale factor | `HP_SCALE_FACTOR` | float | [0.5, 2.0] | Default 1.0；tunable per-boss-class for archetype balance |
| Anti-trivialize floor | `MIN_BOSS_HP` | int | [10, 200] | Default 50 — avoid 1-hit boss kill |
| Anti-impossible ceiling | `MAX_BOSS_HP` | int | [1000, 50000] | Default 10000 — avoid 30+ hit fight (per Pillar 2 boredom) |
| Boss max HP (output) | `boss_max_hp` | int | [50, 10000] | Used to initialize EnemyState.max_hp at SPAWNING |

**Output Range:** [50, 10000] at default knobs.

**Worked example** (mid-game final boss vs CF-1 baseline+):
- player STR=80, DEX=30, equipment_atk_mod=20 → ATTACK_POWER = 10 + 80×1.5 + 30×0.3 + 20 = 159
- Final boss: base_hp=200, TARGET_KILL_HITS=9, HP_SCALE_FACTOR=1.0
- `boss_max_hp_raw = 200 + (159 × 9 × 1.0) = 200 + 1431 = 1631`
- `boss_max_hp = clamp(1631, 50, 10000) = 1631`
- 玩家用 JAB (ability_mult=1.0) 大約 8-9 hit 殺，配合 TIER_3 (mult=3.0) 大概 3 hit。✓ within target window

**Notes:**
- Snapshot frozen at COMMITTED — boss HP 唔 mid-fight 調整 (Pillar 1 chain integrity)
- Floor/ceiling clamp 觸發時 emit `boss.scaling_clamp(boss_id, side, raw, clamped)` for telemetry
- Anti-fabrication: `player_attack_power` MUST come from #11 StatSnapshot；NEVER hardcoded
- **Saturation zone disclosure (per systems-designer P5)**: 當 `player_attack_power ≥ 1056`，`boss_max_hp_raw > MAX_BOSS_HP=10000` → boss_max_hp 進入 saturation zone（constant 10000）。Player progression past ~23% 嘅 ATTACK_POWER ceiling 後，TARGET_KILL_HITS=9 intent 失效 — 高 stat player 用更少 hit 殺 boss。**Design intent**: 接受呢個 saturation 作為「hardcore player = faster kill = reward for real-world strength progression」(Pillar 1 alignment)。Post-MVP path: 加 TIER_4 bosses 或 dynamic MAX_BOSS_HP scaling if playtest shows late-game boredom。

---

### Formula 2 — `boss_attack_damage_scaling`

**Rationale**: boss damage 跟 player MAX_HP scale，目標維持 stable avatar-survive window (per game-concept Recovery from failure「缺一日 workout = 唔損 avatar 能力」)。

The `boss_attack_damage_scaling` formula is defined as:

`boss_attack_damage_raw = round(player_max_hp × DAMAGE_RATIO_PER_HIT × pattern_damage_multiplier)`

`MAX_BOSS_DAMAGE_dynamic = floor(player_max_hp × MAX_BOSS_DAMAGE_RATIO)   # default ratio 0.5`

**CRIT-6 fix (clamp inversion guard)** — if `MAX_BOSS_DAMAGE_dynamic < MIN_BOSS_DAMAGE` (degenerate low-HP case, e.g., player_max_hp ∈ [1, 9]), apply `MAX_BOSS_DAMAGE = MIN_BOSS_DAMAGE` so clamp range is always valid:

`MAX_BOSS_DAMAGE = max(MAX_BOSS_DAMAGE_dynamic, MIN_BOSS_DAMAGE)`

`boss_attack_damage = clamp(boss_attack_damage_raw, MIN_BOSS_DAMAGE, MAX_BOSS_DAMAGE)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Player MAX_HP snapshot | `player_max_hp` | int | [1, 10000] | From #11 Formula 3 via StatSnapshot at BossAnchor COMMITTED |
| Damage ratio per hit | `DAMAGE_RATIO_PER_HIT` | float | [0.10, 0.40] | Final = 0.28 (3-4 hit kill), mini = 0.18 (5-6 hit) — knob |
| Pattern damage multiplier | `pattern_damage_multiplier` | float | [0.5, 2.5] | AttackPatternResource.damage_multiplier per Rule 6 (signature attacks = 1.5+) |
| Anti-tap-of-nothing floor | `MIN_BOSS_DAMAGE` | int | [1, 10] | Default 5 — boss attack 總有 visible impact |
| Anti-one-shot ceiling | `MAX_BOSS_DAMAGE` | int | [50, 5000] | Default ⌊player_max_hp × 0.5⌋ — boss 攻擊 ≤ 50% avatar HP (anti-instant-kill) |
| Boss attack damage (output) | `boss_attack_damage` | int | [5, ⌊player_max_hp × 0.5⌋] | Per-pattern damage input to #13 compute_hit_damage |

**Output Range:** [5, ~boss-tier-balanced] at default knobs.

**Worked example**:
- Player VIT=15 → MAX_HP = 80 + 15×8 = 200
- Final boss, standard attack pattern (pattern_damage_multiplier=1.0), DAMAGE_RATIO_PER_HIT=0.28
- `raw = round(200 × 0.28 × 1.0) = 56`
- `MAX_BOSS_DAMAGE = ⌊200 × 0.5⌋ = 100`
- `boss_attack_damage = clamp(56, 5, 100) = 56`
- 玩家承受 ~3.5 hit 死 ✓ within target window

**Notes:**
- Snapshot frozen at COMMITTED (same as Formula 1)
- `MAX_BOSS_DAMAGE = ⌊player_max_hp × 0.5⌋` 係 **dynamic ceiling** based on snapshot — anti-one-shot guarantee
- Signature attack patterns 用 `pattern_damage_multiplier > 1.0` 但仍受 MAX_BOSS_DAMAGE clamp 保護

---

### Formula 3 — `attack_pattern_selection` (deterministic round-robin with anti-spam)

**Rationale**: per Rule 6，pattern selection 必須 deterministic (Pillar 1 reproducibility) + variety (NO same pattern twice in row)。

The `attack_pattern_selection` formula is defined as:

```gdscript
# Pass 4 A2.2 — replace GDScript hash() with FNV-1a 32-bit deterministic_hash()
# Reason: Godot 4.6 hash() is build-implementation-dependent (different Web Export builds + Desktop
# builds may produce different hash values for the same input). FNV-1a is a fixed-algorithm,
# pure-GDScript impl — identical output cross-platform + cross-version. AC-34 requires
# cross-platform determinism; only deterministic_hash() satisfies the contract.
#
# FNV-1a 32-bit reference impl (place in res://src/utils/deterministic_hash.gd autoload OR
# static helper class — single source of truth for any seed-from-string operation):
#
#   const FNV_OFFSET_BASIS_32: int = 2166136261
#   const FNV_PRIME_32: int = 16777619
#   const FNV_MASK_32: int = 0xFFFFFFFF
#
#   static func deterministic_hash(s: String) -> int:
#       var h: int = FNV_OFFSET_BASIS_32
#       for byte in s.to_utf8_buffer():
#           h = (h ^ byte) & FNV_MASK_32
#           h = (h * FNV_PRIME_32) & FNV_MASK_32
#       return h   # always non-negative 32-bit; % operator safe without posmod()

# Pass 3 posmod() guard kept as defense-in-depth — deterministic_hash always returns
# non-negative but posmod() is cheap insurance against future helper changes
candidates = boss_template.attack_patterns  # Array, size [1, 4]
if candidates.is_empty():
    # Defensive — EC-10 should prevent but BossRegistry CI lint may fail; return null + emit ERROR
    return null
if candidates.size() == 1: return candidates[0]

last_pattern = _last_emitted_pattern_id  # null on first attack
valid_candidates = candidates.filter(func(p): return p.pattern_id != last_pattern)

# Defensive: if all candidates share same pattern_id (data error), bypass anti-spam
if valid_candidates.is_empty():
    valid_candidates = candidates

# Pass 4 A2.2 — use deterministic_hash() FNV-1a; posmod() kept as cheap safety net
seed_str = "%s_pattern_%d" % [transition_id, attack_count]
seed = posmod(DeterministicHash.deterministic_hash(seed_str), valid_candidates.size())
selected = valid_candidates[seed]
_last_emitted_pattern_id = selected.pattern_id
return selected
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attack patterns array | `candidates` | Array[AttackPatternResource] | size [1, 4] | BossTemplate-defined patterns per Rule 1 |
| Last pattern ID | `last_pattern` | StringName ∪ null | enum or null | _last_emitted_pattern_id (in-memory state, reset on boss spawn) |
| Filtered candidates | `valid_candidates` | Array | size [1, len(candidates)] | Candidates excluding last (size ≥ 1 guaranteed) |
| Boss transition ID | `transition_id` | String | non-empty | From BossAnchor commit (per Rule 8) |
| Attack tick count | `attack_count` | int | [0, ∞) | Per-boss attack counter, increments per attack |
| Selected pattern | `selected` | AttackPatternResource | one of candidates | Output to ATTACKING state execution |

**Output Range:** one element of `candidates` array.

**Edge case**: when `candidates.size == 1`，return that single pattern (anti-spam rule waived — design constraint enforces ≥ 2 patterns for MVP final bosses).

**Notes:**
- Deterministic for same `transition_id + attack_count` — replay reproducible
- Variety enforced via `last_pattern` filter
- NO randf() — sub-RNG via hash seed (per #13 Formula 2 pattern)

---

### Formula 4 — `reveal_ritual_intensity_scaling` (Pass 3 — F4 categorical scope per game-designer Weber-Fechner finding)

**Rationale**: per Rule 3 + Rule 7，final boss visual treatment 嘅 caller_mult。**Pass 3 scope clarification**: Formula 4 **ONLY applies to FINAL boss** (BossTemplate via #16 spawn_boss path)。Mini-boss reveal ritual = **categorical NO camera focal** per Rule 3 (lite path handled by #14 wave system，唔行呢個 formula)。Categorical distinction (presence vs absence of focal) 替代原本嘅 magnitude difference (0.36s vs 0.6s prone to Weber-Fechner JND failure)。Worked example mini-boss row 仍保留作 historical reference 但 marked **DEAD PATH — #16 never executes for mini-boss**。

`ritual_caller_mult = clamp(boss_template.reveal_ritual_intensity, MIN_RITUAL_INTENSITY, MAX_RITUAL_INTENSITY)`

Used in 3 downstream calls per Rule 7:
- `Camera.request_focal(.., duration = BASE_FOCAL_DURATION * ritual_caller_mult, ..)`
- `ScreenEffects.shake(intensity = BASE_SHAKE_INTENSITY * ritual_caller_mult, ..)`
- `ParticleSystem.spawn(.., caller_mult = ritual_caller_mult)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BossTemplate value | `boss_template.reveal_ritual_intensity` | float | [0.4, 1.0] | Per Rule 1 default: 0.6 mini, 1.0 final |
| Floor | `MIN_RITUAL_INTENSITY` | float | [0.3, 0.5] | Default 0.4 — anti-invisible mini-boss reveal |
| Ceiling | `MAX_RITUAL_INTENSITY` | float | [1.0, 1.5] | Default 1.0 — clamp to #5 max_caller_multiplier per ADR-001 (registry confirms 1.5 ceiling) |
| Effective multiplier | `ritual_caller_mult` | float | [0.4, 1.0] | Passed to downstream #5/#6/#7 |
| Base focal duration | `BASE_FOCAL_DURATION` | float | seconds | Per #7 FOCAL_ENTRY_DURATION registry value (0.6) |
| Base shake intensity | `BASE_SHAKE_INTENSITY` | float | [0.0, 1.0] | 0.5 per Rule 7 |

**Output Range:** [0.4, 1.0]

**Worked example** (final boss):
- `boss_template.reveal_ritual_intensity = 1.0`
- Clamped to [0.4, 1.0] → 1.0
- Camera focal: 0.6 × 1.0 = 0.6s ✓ within #7 FOCAL_ENTRY_DURATION safe range
- Screen shake: 0.5 × 1.0 = 0.5 intensity
- Particles: caller_mult = 1.0

**Worked example** (mini boss — **DEAD PATH for #16; reference only**):
> ⚠️ Pass 3 — F4 categorical scope: #16 Formula 4 NEVER executes for mini-boss. Mini-boss reveal handled by #14 wave system lite path (hardcoded 0.6 intensity, NO camera focal). 以下保留作 historical / reference 用 — implementer **must not** path mini-boss through Formula 4。
- `boss_template.reveal_ritual_intensity = 0.6` (historical)
- Camera focal: **N/A — Rule 3 categorical NO focal for mini**
- Screen shake: 0.5 × 0.6 = 0.3 intensity (handled by #14 lite path)
- Particles: caller_mult = 0.6 (handled by #14 lite path)

**Notes:**
- Dramatic weight gradient 由呢個 single multiplier 控制 — 改 BossTemplate value 一處，3 個 visual system 同步 scale
- Anti-overscaling: MAX_RITUAL_INTENSITY clamp 防止 designer typo (e.g., 5.0) 觸發 violations of #5/#6/#7 各自 budget

---

### Cross-Formula Invariants (CF) + Cross-System Invariants (CI)

| ID | Type | Invariant | Enforcement |
|----|------|-----------|-------------|
| **CF-1** | within-formula | `boss_max_hp ≥ MIN_BOSS_HP` 永遠成立 (Formula 1 clamp) | Section H AC |
| **CF-2** | within-formula | `boss_attack_damage ≤ max(MIN_BOSS_DAMAGE, ⌊player_max_hp × 0.5⌋)` 永遠成立 (Pass 3 — floor exception per systems-designer CRIT-6 vs CF-2 contradiction fix; when player_max_hp < MIN_BOSS_DAMAGE × 2, MIN floor wins per Formula 2 clamp inversion guard, telemetry emits degenerate state warning per EC-06) | Section H AC |
| **CF-3** | execution-order | Formulas 1 + 2 必須 read same player StatSnapshot (single source) at COMMITTED time | Section H AC |
| **CF-4** | within-formula | `attack_pattern_selection` never returns same pattern twice consecutively when candidates ≥ 2 (Formula 3 anti-spam) | Section H AC |
| **CF-5** | within-formula | `ritual_caller_mult ≤ MAX_RITUAL_INTENSITY=1.0` (Formula 4 ceiling) | Section H AC |
| **CI-1** | cross-system | `player_attack_power` input source = #11 StatSnapshot ATTACK_POWER (no hardcoded value) — Pillar 1 chain | Section H AC + CI lint |
| **CI-2** | cross-system | `player_max_hp` input source = #11 StatSnapshot MAX_HP — Pillar 1 chain | Section H AC + CI lint |
| **CI-3** | cross-system | `transition_id` source = #14 BossAnchor commit (NOT #16-generated) — Pillar 1 chain | Section H AC + CI lint |
| **CI-4** | cross-system | `ritual_caller_mult` 必須 ≤ #5 `max_caller_multiplier=1.5` (registry-locked) — ADR-001 budget | Section H AC |
| **CI-5** | cross-system | `boss_max_hp` indirectly feeds #13 Formula 1 (`compute_hit_damage` reads target.max_hp) — values consistent | #13 GDD already locks |

## Edge Cases

呢個 section 列出 #16 嘅 24 個 edge cases，按 9 個 category 分類。

### Category 1 — Boss Spawn Race Conditions

**EC-01 [Spawn | CRITICAL]**: 如果 `BossSystem.spawn_boss()` 被 call 兩次 with same `transition_id` (race condition / replay)，**則** 第二個 call drop + log `BOSS_DUP_SPAWN_001` (ERROR)，**保留首個 boss instance**。Tombstone-style idempotency per ADR-006 Contract 2。(Rule 8 + Rule 16 NEVER #1)

**EC-02 [Spawn | CRITICAL]**: 如果 `transition_id` 係空字串或 null，**則** **拒絕 spawn** + log `BOSS_INVALID_TXN_001` (ERROR)，#14 BossAnchor 應 rollback 至 IDLE。Pillar 1 — 冇 transition_id = 唔係 real workout trigger。(Rule 16 NEVER #11)

**EC-03 [Spawn | HIGH]**: 如果 `BossRegistry` query 返 0 個 candidate (e.g., MOBILITY mini-boss 未 design)，**則** fallback STRIKE class candidate per Rule 13；若 STRIKE 都冇 → spawn placeholder boss + log `BOSS_REGISTRY_EMPTY_001` (ERROR) + emit telemetry。MVP build 必須 ship ≥ 3 mini + 3 final candidates。(Rule 2 + Rule 13)

**EC-04 [Spawn | MEDIUM]**: 如果 `BossRegistry` query 返多個 candidates 但 hash seed 撞 boundary (e.g., len=3, seed%3=0 vs 1 vs 2)，**則** 用 `pick_deterministic` 確保跨 session 同 transition_id 一致 (Pillar 1 reproducibility)。冇 floating randomness。(Rule 2)

---

### Category 2 — Scaling Formula Edge Cases

**EC-05 [Scaling | CRITICAL]** (revised 2026-05-28 Pass 4 A3.3 — first-session duration fallback supersedes pass-through path): 如果 player StatSnapshot `ATTACK_POWER = 0` (true first session OR degenerate boot state — #11 not yet loaded real lift data)，**則** Formula 1 invokes the Pass 4 A3.3 bootstrap branch: `effective_atk = max(BOOTSTRAP_ATTACK_POWER=10, duration_factor × FIRST_SESSION_BASELINE_ATK=28)` where `duration_factor = workout_duration_sec / 600`。Resulting boss fight remains engaging (~9 hit kill at mid-session duration), avoiding Pass 3 trivial 2-3 hit「first impression failure」path。Telemetry `boss.first_session_bootstrap` emit。**Why fallback > clamp-to-MIN**: clamp-to-MIN produces boring trivial fight on player's very first boss kill (Pillar 3 climax 失效 在 most-critical first-impression moment). Duration-based bootstrap gives「effort earned, even on first session」honest framing. (Formula 1 + CF-1)

**EC-06 [Scaling | CRITICAL]** (revised 2026-05-27 — CRIT-6 P4 fix): 如果 player `MAX_HP ∈ [0, 9]` (degenerate state — #11 INV-2 enforces max(1, ...) so MAX_HP=0 唔應該發生，但 [1, 9] range 仍然 possible at boot before equipment loads)，**則** `MAX_BOSS_DAMAGE_dynamic = floor(MAX_HP × 0.5) ∈ [0, 4]` < `MIN_BOSS_DAMAGE = 5`。Per CRIT-6 clamp inversion guard：`MAX_BOSS_DAMAGE = max(MAX_BOSS_DAMAGE_dynamic, MIN_BOSS_DAMAGE) = 5`，clamp range becomes [5, 5] = fixed 5。Boss attack damage = 5 (single-hit player kill at MAX_HP < 5 — telemetry emit `boss.degenerate_player_hp(workout_id, hp)` for emergency tuning). Pillar 3 protection: boss 唔會 0 damage feels broken；MIN_BOSS_DAMAGE floor preserved。(Formula 2 + CRIT-6 P4)

**EC-07 [Scaling | HIGH]**: 如果 `boss_max_hp_raw > MAX_BOSS_HP=10000` (player 達 endgame stat)，**則** clamp 至 10000 + log `BOSS_HP_CEILING_HIT_001` (WARN, payload=raw, player_atk)。Anti-fabrication: real-stat-driven 但唔讓 design impossible。Long-term: re-tune MAX_BOSS_HP or introduce TIER_4 bosses v0.2。(Formula 1)

**EC-08 [Scaling | HIGH]**: 如果 `pattern_damage_multiplier > 2.5` (BossTemplate typo)，**則** clamp at 2.5 + log + push_warning。Anti-fabrication: 防止 designer 不慎 lock 一個 9-shot avatar kill pattern。(Formula 2)

**EC-09 [Scaling | MEDIUM]**: 如果 boss 喺 STAGGERED state，**則** outgoing attack 喺 stagger period skip，但 incoming damage scaling 不變 (player 嘅 ATTACK_POWER snapshot frozen at COMMITTED — Pillar 1 chain integrity)。(Rule 15)

---

### Category 3 — Attack Pattern Edge Cases

**EC-10 [Pattern | HIGH]**: 如果 boss 嘅 `attack_patterns` array empty (BossTemplate config bug)，**則** boss 進入 IDLE state 但唔 ATTACK + emit `boss.empty_patterns(boss_id)` (ERROR)。Avatar 仍可攻擊 boss，但 boss 變 punching bag。CI lint: BossRegistry validation step assert each template has ≥ 1 pattern。(Rule 6 + Rule 1 CI)

**EC-11 [Pattern | MEDIUM]**: 如果 boss `attack_patterns.size() == 1`，**則** anti-spam rule (Formula 3) waived — 同一 pattern 必然連續使用。冇 ERROR。Mini-boss 設計上接受 1-pattern 重複。(Formula 3 + Rule 3)

**EC-12 [Pattern | LOW]**: 如果 `attack_count` overflow (int32 limit 2.1B)，理論上不可能 — 60s boss fight ~30 attacks，需要 222 億秒先 overflow。Defensive: reset `attack_count = 0` on boss spawn (Rule 11)。(Formula 3)

---

### Category 4 — Reveal Ritual Race Conditions

**EC-13 [Reveal | HIGH]** (severity upgraded from MEDIUM per qa-lead Q7): 如果 #7 Camera substate ≠ READY 喺 reveal 時 (e.g., Camera 正在 SUSPENDED — possible during bfcache resume mid-reveal)，**則** Camera.request_focal 被 #7 拒絕 + 返 false (per #7 EC-XX behavior)；#16 boss reveal **繼續** without focal — emit `boss.partial_reveal(boss_id, missing="camera")` (WARN)。Boss 仍出現，只係冇 cinematic zoom — UX impact: boss reveal moment 感覺平淡 (Pillar 3 climax 部分 degrade)。Severity HIGH because Pillar 3 PRIMARY climax 嘅 reveal moment 失去 cinematic 元素。Recommend AC coverage in next sprint。(Rule 7)

**EC-14 [Reveal | HIGH]**: 如果 ParticleSystem `_dropped_play_calls` 拒絕 reveal preset (mobile budget exhausted)，**則** boss 仍 spawn 但冇 reveal particles。Visual 體驗降級但 Pillar 3 boss-kill loot 仍正常 trigger。Log `boss.reveal_particles_dropped`。(Rule 7 + #5 EC-12)

**EC-15 [Reveal | MEDIUM]**: 如果 reveal sequence 內三個 visual call (#5/#6/#7) 有任一個 throw exception，**則** 餘下 call 繼續 (try/except 包圍每個 call)；boss 仍 spawn。No-cascade-failure invariant。(Rule 7)

---

### Category 5 — Mid-fight Bfcache Resume

**EC-16 [Bfcache | CRITICAL]**: 如果 tab freeze 喺 boss fight 中間 (e.g., player 做緊 set 同時 game 喺 boss DYING animation)，**則** resume 後 #14 BossAnchor 已喺 IDLE state (per #14 EC-37) — #16 boss instance **唔 restore**。`workout_completed` 已 emit + enemy_killed 已 emit (assume normal flow) → #15 loot 已 trigger。Resume 顯示 IDLE world view。(Rule 12 + #14 EC-37)

**EC-17 [Bfcache | HIGH]** (revised 2026-05-28 Pass 4 A3.2 hybrid): 如果 tab freeze 喺 boss fight 中間 (COMMITTED 之後)，**則** resume 行為由 `boss.current_hp` 決定 (per Rule 12 Pass 4 hybrid): (a) HP < 30% → skip-to-kill (DYING state + enemy_killed via cached transition_id + loot chain完成); (b) HP ≥ 30% → restart-at-FULL-HP (SPAWNING state + reveal ritual re-runs); (c) workout_completed 未 emit → cleanup boss instance (PRE_SPAWN freeze edge case)。`workout_completed` 必須 already emit before COMMITTED，所以 player 唔重新做 last set。Loot integrity preserved: skip-to-kill path 觸發 enemy_killed，restart path 等 player avatar 再殺一次 (transition_id 不變 → ADR-005 deterministic seed → same loot rarity outcome). (Rule 12 Pass 4 A3.2)

**EC-18 [Bfcache | MEDIUM]**: 如果 `workout_completed` 已 emit 但 #14 BossAnchor 仲未 reach COMMITTED 時 freeze (e.g., PRE_SPAWN 中間)，**則** resume 後 #14 自動 re-trigger COMMITTED (per #14 own EC) → #16 spawn boss normally。(Rule 12)

---

### Category 6 — UNKNOWN Class Fallback

**EC-19 [Class | HIGH]**: 如果 `WorkoutSummaryRO.dominant_class == UNKNOWN` (per #9 Rule 5 sticky-null OR #9 CI-3)，**則** spawn STRIKE class boss per Rule 13 + emit `boss.unknown_class_fallback(workout_id, transition_id)` (INFO)。Pillar 1 honesty — 唔 fabricate「multi-class」boss。(Rule 13)

**EC-20 [Class | LOW]**: 如果 dominant_class 喺 boss fight 中段被 #9 改變 (e.g., mid-fight workout extension — unlikely but defensive)，**則** boss class 不變 — snapshot frozen at COMMITTED (Rule 5 CF-3 invariant)。(Rule 5 + CF-3)

---

### Category 7 — Persistence Boundary

**EC-21 [Persist | LOW]**: 如果 任何 code 嘗試 PersistenceLayer.write("boss.\*", ...)，**則** CI lint reject (`tools/ci/check_boss_no_persist.gd`)。#16 transient by design — 任何 persistence attempt = bug。(Rule 12)

---

### Category 8 — Light-Workout Boundary

**EC-22 [LightWorkout | MEDIUM]**: 如果 `total_planned_sets == LIGHT_WORKOUT_THRESHOLD_SETS (=2)`，**則** boundary inclusive — spawn MINI tier。同 #14 EC-19 light-workout boundary 一致 (≤ 2 → mini)。CI lint 確保 #14 + #16 boundary 同步。(Rule 10)

**EC-23 [LightWorkout | LOW]**: 如果 `total_planned_sets == 0` (空 workout 但 backend 莫名其妙 emit workout_completed)，**則** **拒絕 boss spawn** + emit `boss.empty_workout(workout_id)` (ERROR)。Pillar 1 — 冇 set 唔可能有 boss。(Rule 16 NEVER #11)

---

### Category 9 — Boss Kill Race

**EC-24 [Kill | CRITICAL]**: 如果 boss 喺同一 frame 收到 multiple killing-blow hits (AOE per #13 MAX_TARGETS_PER_CAST=8)，**則** **僅第一 hit 觸發 enemy_killed emission** (per #14 Rule 15 idempotency dedupe by enemy_instance_id)。後續 hits drop + log `boss.dup_kill_blow(boss_id, count)` (INFO)。Loot 只爆 1 次。(Rule 8 + #14 Rule 15)

---

**Severity 統計**: CRITICAL ×6, HIGH ×7, MEDIUM ×6, LOW ×5 = 24 ECs。覆蓋 16 個 Rules + 4 Formulas + 5 CF + 5 CI。

## Dependencies

### Upstream Dependencies (4 — 3 Approved + 1 Approved)

| # | System | Type | Interface | Status |
|---|--------|------|-----------|--------|
| #9 | Workout State Tracker | Hard subscriber (via #14) | `WorkoutSummaryRO.dominant_class` + `total_planned_sets` snapshot at BossAnchor COMMITTED | Approved 2026-05-27 |
| #11 | Stat System | Hard reader | `Stat.create_snapshot()` → ATTACK_POWER / MAX_HP / CRIT_CHANCE frozen at COMMITTED | Approved 2026-05-27 |
| #13 | CombatResolver | Hard caller | `compute_hit_damage(boss as target)` + `hit_resolved` emission with damage_tier classification | Approved 2026-05-27 |
| #14 | EnemyDirector | Hard caller + listener | `BossSystem.spawn_boss(template, transition_id, spawn_pos, player_snapshot) -> BossInstance` on COMMITTED (Pass 4 A1.3 canonical signature); `enemy_killed` emission on death | Approved 2026-05-27 |

### Downstream Consumers (5 — 3 Approved visual ritual + 2 Not Started)

| # | System | Type | Interface | Status |
|---|--------|------|-----------|--------|
| #5 | Particle System Wrapper | Direct caller (visual ritual) | `ParticleSystem.spawn(preset, caller_mult=ritual_mult)` per Rule 7 | Approved 2026-05-26 |
| #6 | Screen Effects | Direct caller (visual ritual) | `ScreenEffects.shake(intensity*ritual_mult, duration)` per Rule 7 | Approved 2026-05-26 |
| #7 | Camera System | Direct caller (visual ritual) | `Camera.request_focal(target, duration*ritual_mult, zoom)` per Rule 7 | Approved 2026-05-26 |
| #15 | Loot Drop System (Pre-MVP) | Indirect via #14 enemy_killed | Reads `BossTemplate.loot_guarantee_min_tier` flag for guarantee gating | Not Started |
| #28 | Telemetry (Pre-MVP) | Subscriber | `boss.spawned / killed / fallback_unknown_class / mid_fight_resume / scaling_clamp` events | Not Started |

### Provisional / Soft Dependencies

| # | System | Type | Interface needed | Fallback |
|---|--------|------|------------------|----------|
| #4 | Audio Manager (MVP) | Optional caller | `AudioManager.play_cue(boss_template.audio_template_id)` per Rule 7 | Graceful no-op if #4 absent (MVP build OK without audio) |

### ADR Dependencies

| ADR | Status | What #16 inherits |
|-----|--------|-----------------|
| **ADR-005 Loot Rarity Formula** | Accepted 2026-05-27 | `transition_id` chain seed: #16 boss kill → #14 enemy_killed.transition_id → #15 RNG seed → loot_rarity_score |
| **ADR-001 Web Export Budget Caps** | Proposed | Boss reveal particle storm respects MAX_ACTIVE_PARTICLES=200 + mobile FR-4 auto-degrade |
| **ADR-006 State Machine Contract** | Proposed | transition_id provenance: Contract 2 (acquire via #1 GSM, propagate via #14 BossAnchor); Contract 6 (`connect_for_initial_state`) for any signal subscriptions |

### Bidirectional Sync Gap Flags (for next-revision batch)

| GDD / Doc | What needs reciprocal lock |
|-----------|----------------------------|
| **systems-index** | Update #16 status: Not Started → Designed pending review; add visual-ritual dep arrows #16 → 5/6/7; confirm #16 → 9/13/14/15 |
| **#14 EnemyDirector** | Confirm `BossSystem.spawn_boss(template, transition_id, spawn_pos, player_snapshot) -> BossInstance` 4-param canonical signature in #14 Rule 13 (Pass 4 A1.3); caller-side StatSnapshot capture at BossAnchor COMMITTED tick (Pass 4 A1.2) |
| **#5 Particle System** | Decide BOSS_REVEAL preset addition (Q-X1) — MVP defers, v0.2 adds |
| **#15 LootDrop** (Not Started) | `loot_guarantee_min_tier` consumer contract — must respect when designed |
| **#28 Telemetry** (Not Started) | 5 boss event types subscriber list |
| **registry** | Add `boss_template_resource`, `boss_tier_enum`, `attack_pattern_resource`, 4 formulas, 7 new knobs (Section G) |

### Failure Mode Matrix

| Upstream failure | #16 behavior | Downstream impact |
|------------------|-------------|-------------------|
| #9 WST returns UNKNOWN class | Fallback STRIKE per Rule 13 + telemetry | Boss visual = STRIKE archetype |
| #11 StatSnapshot unavailable (boot-time race) | Use BossTemplate `base_hp` baseline; scaling formula degenerate path EC-05 | Boss HP defaults to floor; player TIER_1 2-3 hit kill (still playable) |
| #13 CombatResolver missing damage_tier | Boss STAGGER state non-trigger; boss continues attack patterns | Visual / audio routing degraded; no shake on HEAVY hits |
| #14 BossAnchor commit failure | #16 NOT spawn boss; #14 own rollback path | No boss climax; emit telemetry; player workout completion 仍 trigger #15 loot via fallback path (per ADR-005 Pillar 3 floor) |
| #5 budget exhausted | Boss spawn but skip reveal particles (EC-14) | Visual ritual incomplete; loot still flows |
| #7 Camera SUSPENDED | Boss spawn but skip focal (EC-13) | No cinematic zoom; functional boss fight |

## Tuning Knobs

### Owned by #16 (9 knobs — Pass 3: 2 mini knobs forward-migrated to #14 per CRIT-4 split tail)

| Knob | Default | Safe Range | Affects | Breaking behavior |
|------|---------|-----------|---------|-------------------|
| `TARGET_KILL_HITS_FINAL` | 9 | [6, 15] | Formula 1 — hit window for final boss | < 6 → boss feels trivial; > 15 → fight 拖太耐 violates Pillar 2 |
| `HP_SCALE_FACTOR` | 1.0 | [0.5, 2.0] | Formula 1 — global scaling sensitivity to player ATK | < 0.5 → boss HP 跟唔上 player progression; > 2.0 → late-game ceiling hit |
| `MIN_BOSS_HP` | 50 | [10, 200] | Formula 1 + EC-05 — anti-trivialize floor | < 10 → boss 1-hit 死 (Pillar 3 fail); > 200 → boot-time degenerate case 不 kill-able |
| `MAX_BOSS_HP` | 10000 | [1000, 50000] | Formula 1 — anti-impossible ceiling; **TTK target band: 4-12 seconds** (Pass 3 — F5 anti-bullet-sponge per game-designer) | < 1000 → late-game ceiling 太早 hit; > 50000 → boss 變 sponge (Pillar 2 fail); TTK > 12s → bullet sponge anti-pattern triggered |
| `DAMAGE_RATIO_PER_HIT_FINAL` | 0.28 | [0.20, 0.40] | Formula 2 — avatar-survive window final boss | < 0.20 → final boss 完全冇威脅; > 0.40 → 2-hit avatar death feels unfair |
| `MIN_BOSS_DAMAGE` | 5 | [1, 20] | Formula 2 + EC-06 — anti-tap-of-nothing floor | < 1 → 0-damage attack visible 但冇 impact; > 20 → MIN floor 覆寫 designed mini-boss |
| `MAX_BOSS_DAMAGE_RATIO` | 0.5 | [0.3, 0.5] | Formula 2 — multiplier on player_max_hp for hard ceiling (Pass 3 — capped 0.5 per INV-5 STRICT, prevents F4 high-mult pattern variety loss) | < 0.3 → boss attack feels weak; > 0.5 → one-shot avatar kill risk violates INV-5 |
| `MIN_RITUAL_INTENSITY` | 0.5 | [0.4, 0.6] | Formula 4 — anti-invisible final-boss reveal (Pass 3 — raised 0.4→0.5 per systems-designer Weber-Fechner: 0.6×0.4=0.24s camera focal below human perception threshold ~200ms) | < 0.4 → final boss reveal feels weak; > 0.6 → mini-vs-final gradient 收窄 (但 mini 用 categorical NO focal — gradient by presence/absence) |
| `MAX_RITUAL_INTENSITY` | 1.0 | [1.0, 1.5] | Formula 4 — clamp to #5 max_caller_multiplier ceiling | > 1.5 → violates ADR-001 #5 budget; < 1.0 → final boss treatment 上限 受限 |
| `MID_FIGHT_SKIP_HP_THRESHOLD` | 0.30 | [0.10, 0.50] | Rule 12 Pass 4 A3.2 bfcache hybrid — HP fraction below which resume skips-to-kill; above which restarts at full HP | < 0.10 → almost all resumes restart (Pillar 2 continuity violated); > 0.50 → nearly any damage triggers skip-to-kill (Pillar 1 honesty drift — fights feel skippable) |
| `BOOTSTRAP_ATTACK_POWER` | 10 | [5, 30] | Formula 1 Pass 4 A3.3 first-session fallback — minimum effective_atk when player_attack_power=0 | < 5 → boss HP floor 撞 MIN_BOSS_HP=50 (trivial fight); > 30 → first session bootstrap too punishing (defeats "first impression must be engaging" goal) |
| `FIRST_SESSION_BASELINE_ATK` | 28 | [20, 50] | Formula 1 Pass 4 A3.3 — ATTACK_POWER target after duration ramp completes (≥10 min into first workout) | < 20 → bootstrap too lenient; > 50 → first session boss tougher than mid-game stat player (paradox) |
| `FIRST_SESSION_DURATION_TARGET_SEC` | 600 | [300, 1800] | Formula 1 Pass 4 A3.3 — workout_duration_sec ramp denominator (linear ramp from 0 → 1.0 over this duration) | < 300 → bootstrap ramps before player has done meaningful work; > 1800 → bootstrap never reaches baseline within typical workout |

**Forward-migrated to #14 (Pass 3 — orphan knobs post CRIT-4 split):**

| Knob | Owner (Pass 3 →) | Reason |
|------|------------------|--------|
| ~~`TARGET_KILL_HITS_MINI`~~ → `MINI_BOSS_TARGET_KILL_HITS` | **#14 EnemyDirector** | #16 唔再 spawn mini-boss (CRIT-4); mini-boss combat formula 屬 #14 EnemyTemplate scaling scope |
| ~~`DAMAGE_RATIO_PER_HIT_MINI`~~ → `MINI_BOSS_DAMAGE_RATIO_PER_HIT` | **#14 EnemyDirector** | 同上 — #14 GDD next-revision 必須 declare ownership |

### Referenced (cross-system, NOT owned by #16 — registry-locked)

| Knob | Owner | Value | #16 uses for |
|------|-------|-------|-------------|
| `LIGHT_WORKOUT_THRESHOLD_SETS` | #14 EnemyDirector | 2 | Rule 10 mini vs final boundary |
| `FOCAL_ENTRY_DURATION` (BASE_FOCAL_DURATION alias) | #7 Camera | 0.6s | Formula 4 base × ritual_mult |
| `max_caller_multiplier` | #5 Particle System | 1.5 | Formula 4 ceiling (CI-4 constraint) |
| `EXERCISE_TARGET_COUNT` | ADR-005 | 5 | Indirectly via #15 LootDrop volume_factor |

### Per-BossTemplate Tuning (content data, NOT global knobs)

- `base_hp` per boss (Section C Rule 1) — designed per archetype: STRIKE final 200, STRIKE mini 80, etc.
- `base_defense` per boss (input to #13 Formula 1)
- `attack_patterns` array per boss (Rule 6)
- `reveal_ritual_intensity` per boss (default 0.6 mini / 1.0 final, but designable per-template)
- `arena_constraint_px` per boss (Rule 14)
- `audio_template_id` per boss (#4 audio cue id)

### Cross-Knob Invariants (INV)

| INV | Constraint | Rationale |
|-----|------------|-----------|
| ~~**INV-1**~~ | ~~`TARGET_KILL_HITS_MINI < TARGET_KILL_HITS_FINAL`~~ | **REMOVED 2026-05-28 Pass 4 A4.1** — orphan reference to migrated #14 knob. Equivalent invariant forward-constrained to #14 GDD (per Followup #14 expanded scope): #14 GDD next-revision MUST declare `MINI_BOSS_TARGET_KILL_HITS < #16's TARGET_KILL_HITS_FINAL` as a cross-system invariant in #14's Cross-Knob Invariants section. |
| ~~**INV-2**~~ | ~~`DAMAGE_RATIO_PER_HIT_MINI < DAMAGE_RATIO_PER_HIT_FINAL`~~ | **REMOVED 2026-05-28 Pass 4 A4.1** — orphan reference to migrated #14 knob. Equivalent invariant forward-constrained to #14 GDD (per Followup #14 expanded scope): #14 GDD next-revision MUST declare `MINI_BOSS_DAMAGE_RATIO_PER_HIT < #16's DAMAGE_RATIO_PER_HIT_FINAL` as a cross-system invariant. |
| **INV-3** | `MIN_BOSS_HP × max_player_attack_baseline ≤ MAX_BOSS_HP × HP_SCALE_FACTOR` | Sane scaling envelope (avoid floor/ceiling 撞死) |
| **INV-4** | `MAX_RITUAL_INTENSITY ≤ #5 max_caller_multiplier (1.5)` | CI-4 binding — #5 budget |
| **INV-5** | `MAX_BOSS_DAMAGE_RATIO ≤ 0.5` STRICT | Anti-one-shot avatar — Pillar 3 protection |
| **INV-6** | `MIN_RITUAL_INTENSITY < default final ritual_intensity (1.0)` | Default final template falls inside safe range (mini ritual_intensity 屬 #14 EnemyTemplate post CRIT-4 split — removed from #16's invariant scope per A4.1) |
| **INV-7** | `LIGHT_WORKOUT_THRESHOLD_SETS == #14 owned value (2)` — single source of truth | Avoid #14 / #16 boundary divergence (pattern from consistency-failures log) |
| **INV-8** (Pass 4 A3.1) | `BossTemplate.loot_guarantee_min_tier (RARE) > EnemyTemplate.loot_rarity_ceiling (RARE)` joint at RARE; final boss tier ≥ mini boss ceiling, gradient via ADR-005 modifiers | Preserves dramatic weight gradient post Pass 4 mini UNCOMMON-RARE band restoration; cross-system constraint requires #14 GDD next-revision to lock `EnemyTemplate.loot_rarity_ceiling = RARE` |
| **INV-9** (Pass 4 A3.3) | `BOOTSTRAP_ATTACK_POWER ≤ FIRST_SESSION_BASELINE_ATK` | Bootstrap floor 不可高過 ramp target (otherwise ramp downward — semantically broken) |
| **INV-10** (Pass 4 A3.2) | `0.10 ≤ MID_FIGHT_SKIP_HP_THRESHOLD ≤ 0.50` | Outside this range, bfcache hybrid degenerates to「always skip」OR「never skip」— defeats Pillar 1/2 balance per CD adjudication |

### Knob Stability Classification

- **LOCKED** (changing requires GDD revision + CI lint update): `LIGHT_WORKOUT_THRESHOLD_SETS` (referenced from #14), `MAX_RITUAL_INTENSITY` (CI-4 bound)
- **DESIGN-FROZEN** (safe range narrow, requires #11/#13/#15 coordination): `TARGET_KILL_HITS_*`, `DAMAGE_RATIO_PER_HIT_*`, `MAX_BOSS_DAMAGE_RATIO`
- **TUNABLE** (designer-adjustable per playtest evidence): `HP_SCALE_FACTOR`, `MIN_BOSS_HP`, `MAX_BOSS_HP`, `MIN_BOSS_DAMAGE`, `MIN_RITUAL_INTENSITY`
- **PROVISIONAL** (pending real playtest data): all per-BossTemplate values

## Visual/Audio Requirements

### Boss Visual Specification

Per game-concept Visual Identity Anchor — **「乾淨剪影 + 骯髒粒子」** rule applies。Boss = scale-up enemy 嘅 silhouette + heavy particle overlay。

**Sprite specs:**
- Base size: 64×64 px (mini) / 96×96 px (final) — 2-3× standard enemy sprite (16-32 px per game-concept)
- Silhouette test: 縮圖至 32 px 純剪影 → 應辨認 boss class (STRIKE / CONTROL / MOBILITY)
- Animation set per boss: idle (4 frames), telegraph (8 frames), attack (12 frames), staggered (4 frames), death (16 frames)
- LPC asset modified pipeline per game-concept Solo-Dev Path (cost-efficient)

**Class archetype visual distinction:**

| Class | Silhouette feature | Telegraph color | Particle overlay |
|-------|--------------------|--------------------|------------------|
| **STRIKE** | Large humanoid, oversized weapon | Red wind-up arc | Dust + impact particles on attack |
| **CONTROL** | Caped figure with extended arm gestures | Purple projectile trail | Wisp / cloth particles trailing |
| **MOBILITY** | Multi-segment insectoid OR agile creature | Yellow dash streak | Trail particles per movement |

**Reveal ritual visual sequence** (per Rule 7):
1. Camera focal (0.6s final / 0.4s mini) → zoom 1.4×
2. Particle BOSS_REVEAL preset (MVP reuses LOOT_RARE_BURST) at boss position, caller_mult=ritual_mult
3. Screen shake (intensity 0.5×ritual_mult, duration 0.3s)
4. Boss silhouette fade-in then full saturate over 200ms (rim light burst)
5. Total ≤ 200ms within Pillar 2 sub-500ms boss-visible budget

**Death animation:**
- Final boss: slow-mo collapse (frame-by-frame 16 frames at 30fps = ~530ms) + signature death particle storm
- Mini boss: quick dispel (8 frames at 60fps = ~130ms) + light particle puff

### Boss Audio Direction

Per game-concept Audio Needs — Moderate, SFX-heavy。Boss audio dispatch via #4 AudioManager (MVP placeholder graceful no-op if #4 absent)。

**Audio cue spec per boss event:**

| Event | Final boss cue | Mini boss cue |
|-------|----------------|---------------|
| **Reveal (BossAnchor COMMITTED)** | Low brass hit (≈400ms sustained) + drum kick | Single drum hit (≈150ms) |
| **Attack telegraph** | Vocal sample + sustained build (≈500ms) | Short whoosh (≈200ms) |
| **HEAVY+ damage tier received (per #13)** | Layered impact + reverb tail | Single impact |
| **Death** | Full orchestral hit + decay (≈1500ms) + signature stinger | Single dispel sound (≈400ms) |
| **Background loop during fight** | Brief leitmotif loop (60-90s typical) | None (silence emphasizes mini-boss compressed pace) |

**Q-V1 (Open Question)**: Boss music loop should pause on hit_pause (#6 Rule 7) OR continue? — defer to #4 Audio Manager GDD authoring time。

### Asset Spec Flag

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:boss-system` to produce per-boss visual descriptions, sprite dimensions, animation frame counts, and generation prompts (for LPC asset modification pipeline).

**Cross-ref Visual/Audio system table:**

| Visual/Audio surface | Owning system | #16 contribution |
|---------------------|---------------|-----------------|
| Boss silhouette sprite + animation | #26 Avatar Renderer (extension) OR #16 owns boss sprite Resource? | Open Question Q-V2 — defer to Avatar Renderer GDD |
| Boss reveal particle burst | #5 Particle System | Caller (`spawn(LOOT_RARE_BURST, caller_mult=ritual_mult)`) |
| Boss reveal screen shake | #6 ScreenEffects | Caller (`shake(0.5*mult, 0.3)`) |
| Boss reveal camera focal | #7 Camera System | Caller (`request_focal(boss_pos, 0.6*mult, 1.4)`) |
| Boss attack VFX | #25 Combat Visual Feedback (Not Started) + #5 | hit_resolved.damage_tier 觸發 standard #25 path; boss-specific telegraph VFX 屬 #25 |
| Boss audio cues | #4 Audio Manager (Not Started) | `audio_template_id` per BossTemplate (Section C Rule 1) |

## UI Requirements

**N/A — #16 has no direct UI surface.**

Boss = world-space entity；冇 Control / Canvas widget。Boss-related UI 屬其他 system:

| UI element | Owning system | Cross-ref |
|-----------|---------------|-----------|
| Boss HP bar (HUD overlay) | #20 Gym-Mode HUD (Not Started) | Read EnemyState.current_hp + max_hp from boss instance |
| Boss name banner | #20 Gym-Mode HUD (Not Started) | Read BossTemplate.boss_id + visual_template.display_name |
| Boss kill loot drop modal | #21 Loot Drop Modal (Not Started) | Receives ADR-005 loot generation result |

> **UX Flag — #20 Gym-Mode HUD**: Boss HP bar appears in HUD during BossAnchor COMMITTED+ENGAGED states. Pre-Production 階段 /ux-design 為 Gym-Mode HUD 寫 UX spec **before** epics — Stories 引用 UI 應 cite `design/ux/gym-mode-hud.md`，唔係直接 cite #16 GDD。

## Acceptance Criteria

**49 effective ACs total (Pass 4)** — Pass 3 46 + Pass 4 (AC-41 first-session bootstrap / AC-42 bfcache hybrid / AC-43 null_snapshot rejection) = 49。Covers 16 Rules + 4 Formulas + 5 CF + 5 CI + 7 critical ECs + 5 Falsifiable Tests + 3 FR Risk Register + Pass 3 gameplay-programmer GP3/GP4 + systems-designer CF-3 + game-designer F1 + qa-lead F5 NEVER traceability + Pass 4 A1.2/A3.2/A3.3 contract enforcement。Distribution: 32 Unit / 5 Integration / 3 Static / 9 Manual。Gate breakdown 見 Section H 末尾 Test Type + Gate Distribution tables。

### 一、Core Rules Coverage

- **AC-01 [Logic | BLOCKING | Unit]** (Rule 1: BossTemplate Resource schema): **GIVEN** `BossRegistry` loaded with 6+ templates (3 mini + 3 final), **WHEN** introspect each template's @export fields, **THEN** required fields (boss_id, class_archetype, tier, base_hp, base_defense, attack_patterns, loot_guarantee_min_tier, reveal_ritual_intensity) all present + types correct + immutable at runtime。
  - **Evidence**: `tests/unit/feature/boss_system/test_template_schema.gd`

- **AC-02 [Logic | BLOCKING | Unit]** (Rule 2: Boss spawn selection deterministic): **GIVEN** mock #14 BossAnchor commits with `transition_id="abc123"`, `dominant_class=STRIKE`, `total_planned_sets=5`, **WHEN** `spawn_boss()` called twice with same inputs, **THEN** same `boss_template_id` selected both times (deterministic pick via hash seed)。
  - **Evidence**: `tests/unit/feature/boss_system/test_spawn_selection_determinism.gd`

- **AC-03 [Logic | BLOCKING | Unit]** (Rule 3: Mini vs Final tier distinction — revised 2026-05-28 Pass 4 A3.1 UNCOMMON-RARE band restoration): **GIVEN** workout summaries with `total_planned_sets=2` vs `=5`, **WHEN** boss spawn algorithm runs, **THEN** (a) sets=2 → **#16 early-return per Rule 10; #14 wave system spawns mini-boss as EnemyTemplate with MINI_BOSS_LOOT flag** (guaranteed 1 drop, UNCOMMON floor / RARE ceiling per Rule 9 Pass 4 revision); (b) sets=5 → #16 spawns FINAL BossTemplate boss with `loot_guarantee_min_tier = RARE` (Pass 4 — raised UNCOMMON→RARE to preserve gradient over mini ceiling RARE per A3.1). **Scope clarification**: AC tests #16 spawn-or-skip branching + final-boss field value (RARE). Mini-boss field-side validation belongs to #14 GDD (forward constraint — `EnemyTemplate.loot_rarity_floor = UNCOMMON` + `loot_rarity_ceiling = RARE` next-revision per Followup #15 expanded scope).
  - **Evidence**: `tests/unit/feature/boss_system/test_tier_distinction.gd`

- **AC-04 [Logic | BLOCKING | Unit]** (Rule 4: Class archetype mapping): **GIVEN** dominant_class=STRIKE/CONTROL/MOBILITY, **WHEN** spawn_boss runs, **THEN** selected boss template has matching `class_archetype` field；fallback STRIKE for UNKNOWN per Rule 13。
  - **Evidence**: `tests/unit/feature/boss_system/test_class_archetype_routing.gd`

- **AC-05 [Logic | BLOCKING | Unit]** (Rule 5: Snapshot frozen at COMMITTED): **GIVEN** boss spawn at t=0 with player ATTACK_POWER=159, **WHEN** mid-fight player ATTACK_POWER somehow 改變 (e.g., #11 mutation event during boss fight), **THEN** boss damage taken per hit unchanged (still treats 159 as input)；snapshot integrity preserved。
  - **Evidence**: `tests/unit/feature/boss_system/test_stat_snapshot_freeze.gd`

- **AC-06 [Logic | BLOCKING | Unit]** (Rule 6: Attack pattern anti-spam): **GIVEN** boss with 3 patterns, **WHEN** 100 consecutive attack pattern selections via Formula 3, **THEN** zero consecutive same-pattern sequences detected。
  - **Evidence**: `tests/unit/feature/boss_system/test_attack_pattern_anti_spam.gd`

- **AC-07 [Integration | BLOCKING | Integration]** (Rule 7: Reveal ritual dispatch — revised 2026-05-27 Pass 3 per F2 Camera-Leading reorder + GP3 position fix): **GIVEN** mock #5/#6/#7 spies, **WHEN** boss commits (COMMITTED state entered, `boss_committed` signal emitted with `spawn_pos` payload), **THEN** (a) **Camera.request_focal dispatched FIRST (frame 0)** — assert call_order_index = 0; (b) ScreenEffects.shake + ParticleSystem.spawn dispatched frame 1-2 AFTER Camera (assert call_order_index for shake/particles > Camera); (c) all 3 visual calls + boss visible within ≤ 2 process frames total (frame-count-based, NOT wall-clock ms); (d) Camera target argument === `spawn_pos` payload (NOT boss.global_position late-read — GP3 fix); (e) each call's `caller_mult` argument == `boss_template.reveal_ritual_intensity`; (f) `boss.global_position == spawn_pos` post-add_child (GP3 transform persistence assertion); (g) **scope = dispatch contract + order test, NOT visual outcome**. Visual outcome covered by AC-29 manual playtest.
  - **Evidence**: `tests/integration/feature/boss_system/test_reveal_ritual_sequence.gd`

- **AC-08 [Logic | BLOCKING | Unit]** (Rule 8: enemy_killed.transition_id chain integrity): **GIVEN** boss spawned with transition_id="abc123" + boss dies, **WHEN** observe #14 enemy_killed emission, **THEN** payload.transition_id == "abc123" (exact match, not regenerated)。
  - **Evidence**: `tests/unit/feature/boss_system/test_kill_txn_chain.gd`

- **AC-09 [Logic | BLOCKING | Unit]** (Rule 9: loot_guarantee_min_tier flag — revised 2026-05-28 Pass 4 A3.1 final floor raised RARE): **GIVEN** all FINAL BossTemplate `.tres` files loaded into BossRegistry, **WHEN** mock #15 reads `loot_guarantee_min_tier` field, **THEN** every FINAL template has `loot_guarantee_min_tier = RARE` (Pass 4 — raised UNCOMMON→RARE per A3.1 to preserve dramatic weight gradient over mini ceiling RARE); ADR-005 Pillar 3 floor honored by #15 (workout_score modifiers can push EPIC/LEGENDARY but never below RARE). **Mini-boss field-side validation belongs to #14 EnemyTemplate** — `EnemyTemplate.loot_rarity_floor = UNCOMMON` + `loot_rarity_ceiling = RARE` tested in #14 GDD next-revision, NOT here.
  - **Evidence**: `tests/unit/feature/boss_system/test_loot_guarantee_flag.gd`

- **AC-10 [Logic | BLOCKING | Unit]** (Rule 10: Light-workout boundary — #16 spawn-or-skip branching only, revised 2026-05-28 Pass 4 A4.2 stale MINI tier removal): **GIVEN** mock #14 BossAnchor invokes `BossSystem.spawn_boss(...)` with `total_planned_sets=2` vs `=3` (carried in caller-side WorkoutSummaryRO context — note: spawn_boss signature itself per A1.3 doesn't take sets count, but the upstream gate check happens at #14 caller side per Rule 2 early-return), **WHEN** Rule 2 light-workout check runs, **THEN** (a) sets=2 (≤ LIGHT_WORKOUT_THRESHOLD_SETS) → **#16 early-returns null without creating BossInstance** — assert no BossInstance child added to BossSystem autoload + no `boss_committed` signal emit; (b) sets=3 → #16 spawns FINAL BossInstance with `reveal_ritual_intensity == 1.0` (from `BossTemplate.reveal_ritual_intensity` default). **Scope clarification (Pass 4 A4.2)**: AC tests #16-owned spawn-or-skip branching + final-boss-only field (`reveal_ritual_intensity == 1.0`). Mini-boss spawn assertion (EnemyTemplate path) belongs to #14 EnemyDirector GDD AC scope (forward constraint per Followup #14/#15) — NOT validated here. Pass 4 explicitly removes Pass 3's dead「MINI tier with reveal_ritual_intensity=0.6」reference: (i) `BossTier` enum has only `FINAL` value (MINI dropped per CRIT-2 + CRIT-4), (ii) mini-boss `reveal_ritual_intensity` field doesn't exist on EnemyTemplate (hardcoded 0.6 by #14 wave system per Rule 3 split).
  - **Evidence**: `tests/unit/feature/boss_system/test_light_workout_boundary.gd`

- **AC-11 [Logic | BLOCKING | Unit]** (Rule 11: Boss cleanup): **GIVEN** boss DYING state animation finishes, **WHEN** cleanup runs, **THEN** all _spawned_emitters released via #5 wrapper + boss instance queue_free called within 2 frames。
  - **Evidence**: `tests/unit/feature/boss_system/test_boss_cleanup.gd`

- **AC-12 [Static | ADVISORY (CI-blocked) → BLOCKING (when tooling ready) | Static]** (Rule 12 + Rule 16 NEVER #10: No persistence — Pass 3 downgraded per qa-lead AC-12/16/33 CI self-contradiction finding): **Pre-condition (BLOCKED-ON: BOSS-AC-followup-08 tooling story)**: `tools/ci/check_boss_no_persist.gd` MUST exist + integrated into CI pipeline; until then, AC status = ADVISORY (manual grep acceptable during sprint, gate-promoted to BLOCKING when CI script lands). **GIVEN** repo src/, **WHEN** static grep `PersistenceLayer.write\("boss\.` outside any whitelisted file, **THEN** 0 matches；CI script enforces。
  - **Evidence**: `tools/ci/check_boss_no_persist.gd` + `tests/static/test_boss_no_persist.gd`

- **AC-13 [Logic | BLOCKING | Unit]** (Rule 13: UNKNOWN fallback): **GIVEN** WorkoutSummaryRO.dominant_class=UNKNOWN, **WHEN** spawn_boss runs, **THEN** STRIKE class boss spawned + emit `boss.unknown_class_fallback` telemetry signal。
  - **Evidence**: `tests/unit/feature/boss_system/test_unknown_class_fallback.gd`

- **AC-14 [Logic | BLOCKING | Unit]** (Rule 14: Spawn position bounded): **GIVEN** boss spawn with default settings, **WHEN** boss spawns + pursues avatar past arena_constraint_px.x, **THEN** boss position clamped to constraint；never exits arena bounds。
  - **Evidence**: `tests/unit/feature/boss_system/test_spawn_position_bounded.gd`

- **AC-15 [Logic | BLOCKING | Unit]** (Rule 15: AI state inheritance): **GIVEN** boss instance, **WHEN** observe state_changed transitions, **THEN** state IDs match #14 enemy_ai_state_enum exactly (SPAWNING | IDLE | PURSUING | ATTACKING | STAGGERED | DYING)；無 BOSS_PHASE_TRANSITION for MVP。
  - **Evidence**: `tests/unit/feature/boss_system/test_ai_state_inheritance.gd`

- **AC-16 [Static | ADVISORY (CI-blocked) → BLOCKING (when tooling ready) | Static]** (Rule 16: 12 NEVERs CI lint sweep — Pass 3 downgraded per qa-lead AC-12/16/33 CI self-contradiction finding): **Pre-condition (BLOCKED-ON: BOSS-AC-followup-08 tooling story)**: `tools/ci/check_boss_nevers.gd` MUST exist + integrated into CI pipeline; until then, AC status = ADVISORY (sprint-level manual code-review check acceptable). **GIVEN** repo src/, **WHEN** static analyze, **THEN** zero patterns of: BossSystem.generate_transition_id, boss spawn without #14 path, boss.persistence write, BossTemplate runtime mutation (replace_at_runtime patterns). CI script: `tools/ci/check_boss_nevers.gd`。
  - **Evidence**: `tools/ci/check_boss_nevers.gd`

### 二、Formulas Coverage

- **AC-17 [Logic | BLOCKING | Unit]** (Formula 1: boss_max_hp_scaling worked example): **GIVEN** player_attack_power=159, base_hp=200, TARGET_KILL_HITS=9, HP_SCALE_FACTOR=1.0, **WHEN** compute Formula 1, **THEN** boss_max_hp == 1631 ± 1。
  - **Evidence**: `tests/unit/feature/boss_system/test_formula1_hp_scaling.gd`

- **AC-18 [Logic | BLOCKING | Unit]** (Formula 1 + CF-1: floor/ceiling clamp): **GIVEN** edge case ATTACK_POWER=0 OR ATTACK_POWER=4500 (max), **WHEN** Formula 1, **THEN** floor case → boss_max_hp=MIN_BOSS_HP=50; ceiling case → boss_max_hp=MAX_BOSS_HP=10000 + telemetry emit。
  - **Evidence**: `tests/unit/feature/boss_system/test_formula1_clamps.gd`

- **AC-19 [Logic | BLOCKING | Unit]** (Formula 2 + CF-2: anti-one-shot ceiling): **GIVEN** player_max_hp=200, DAMAGE_RATIO_PER_HIT=0.28, pattern_damage_multiplier=2.5 (max), **WHEN** Formula 2, **THEN** boss_attack_damage ≤ ⌊200×0.5⌋ = 100 always；MAX_BOSS_DAMAGE clamp triggered。
  - **Evidence**: `tests/unit/feature/boss_system/test_formula2_one_shot_protection.gd`

- **AC-20 [Logic | BLOCKING | Unit]** (Formula 3 + CF-4: Pattern selection determinism + anti-spam): **GIVEN** boss with patterns A/B/C, transition_id="seed1", attack_count=0..99, **WHEN** Formula 3 100 iterations, **THEN** (a) same seed+count → same pattern (determinism); (b) zero consecutive identical patterns。
  - **Evidence**: `tests/unit/feature/boss_system/test_formula3_pattern_selection.gd`

- **AC-21 [Logic | BLOCKING | Unit]** (Formula 4 + CF-5: Ritual intensity clamp): **GIVEN** boss_template.reveal_ritual_intensity=0.6/1.0/1.5(invalid), **WHEN** Formula 4, **THEN** outputs 0.6/1.0/1.0 (last clamped to MAX_RITUAL_INTENSITY)。
  - **Evidence**: `tests/unit/feature/boss_system/test_formula4_ritual_clamp.gd`

### 三、Cross-System Invariants

- **AC-22 [Integration | BLOCKING | Integration]** (CI-1 + CI-2: StatSnapshot source — revised 2026-05-27 per qa-lead Q6): **GIVEN** mock #11 Stat with snapshot tracking, **WHEN** boss spawn, **THEN** **object identity check**: `Formula1.input_snapshot === Formula2.input_snapshot` (Godot Resource reference equality, NOT call count). Recommended architectural enforcement: introduce `BossSpawnContext` resource that wraps single snapshot + pass to both formulas — makes AC architectural (BossSpawnContext exists + immutable) rather than behavioral (call count). CF-3 invariant ensured by data identity, not invocation count.
  - **Evidence**: `tests/integration/feature/boss_system/test_ci1_ci2_snapshot_source.gd`

- **AC-23 [Integration | DEFERRED-TO-#15 | Integration]** (CI-3 + CI-5: transition_id chain to #15 LootDrop): **GIVEN** boss kill emits enemy_killed(transition_id="abc"), **WHEN** mock #15 receives + #13 compute_hit_damage runs on boss target, **THEN** #15 uses "abc" as RNG seed + #13 reads boss.max_hp from Formula 1 output。**Gate**: DEFERRED-TO-#15 — #15 not yet designed; AC validates after #15 implementation。
  - **Evidence**: `tests/integration/feature/boss_system/test_ci3_ci5_txn_chain.gd`

- **AC-24 [Logic | BLOCKING | Unit]** (CI-4: #5 max_caller_multiplier compliance): **GIVEN** all BossTemplate.reveal_ritual_intensity values in registry, **WHEN** static validate, **THEN** all ≤ 1.0 (well below #5 max_caller_multiplier=1.5)；prevents violating #5 budget。
  - **Evidence**: `tests/unit/feature/boss_system/test_ci4_caller_mult_compliance.gd`

### 四、Critical Edge Cases

- **AC-25 [Logic | BLOCKING | Unit]** (EC-01: Duplicate spawn idempotency): **GIVEN** spawn_boss called twice with same transition_id within 1 frame, **WHEN** observe boss instances, **THEN** exactly 1 boss instance exists + 2nd call logged BOSS_DUP_SPAWN_001。
  - **Evidence**: `tests/unit/feature/boss_system/test_ec01_dup_spawn_idempotency.gd`

- **AC-26 [Logic | BLOCKING | Unit]** (EC-02 + EC-23: Invalid spawn rejection): **GIVEN** spawn_boss with empty transition_id OR total_planned_sets=0, **WHEN** invoked, **THEN** boss NOT spawned + error logged + #14 BossAnchor rollback signal emit。
  - **Evidence**: `tests/unit/feature/boss_system/test_ec02_ec23_spawn_rejection.gd`

- **AC-27a [Logic | BLOCKING | Unit]** (EC-16/EC-17 mock-based — revised 2026-05-27 per qa-lead Q2): **GIVEN** boss in COMMITTED state, **WHEN** simulate `NOTIFICATION_APPLICATION_PAUSED` then `NOTIFICATION_APPLICATION_RESUMED` via mock, **THEN** boss state machine branching logic matches expected resume behavior: (a) if `workout_completed` + `enemy_killed` emitted pre-pause → boss IDLE, no instance; (b) if only COMMITTED → boss respawns at FULL HP from template; (c) emergency cleanup path runs for any orphaned `_spawned_emitters`.
  - **Evidence**: `tests/unit/feature/boss_system/test_ec16_ec17_resume_logic.gd`
- **AC-27b [Visual/Feel | ADVISORY | Manual]** (EC-16/EC-17 real-browser): **GIVEN** Web Export build deployed + Chromium/Safari with bfcache enabled, **WHEN** human tester: boss commits → switch tab 60s → return tab, **THEN** observable behavior matches AC-27a expected branches; no visual artifacts; no orphaned particles. Tester documents result in evidence file. **Reason for manual**: Godot headless cannot simulate browser bfcache (JavaScriptBridge is stub).
  - **Evidence**: `production/qa/evidence/boss_bfcache_browser_[date].md`

- **AC-28 [Logic | BLOCKING | Unit]** (EC-24: AOE kill blow idempotency): **GIVEN** boss HP=10 + AOE hit dealing damage 50 to 3 targets including boss, **WHEN** kill resolves, **THEN** exactly 1 enemy_killed emission for boss + 2 dup_kill_blow drops logged。
  - **Evidence**: `tests/unit/feature/boss_system/test_ec24_aoe_kill_dedupe.gd`

### 五、Falsifiable Tests + Fantasy Risk Register

- **AC-29a [Visual/Feel | ADVISORY (VS-tier) → BLOCKING (MVP gate) | Manual]** (Falsifiable Test #1 — Pillar 3「值得 cap 圖」sensation — revised 2026-05-27 per qa-lead Q3): **GIVEN** n≥5 playtesters (VS) / n≥15 (MVP gate) complete full workout (3+ sets), **WHEN** post-workout 5-point Likert survey「呢一刻你幾想 screenshot boss kill?」(1=完全冇 / 5=絕對想), **THEN** mean score ≥ 4.0 across cohort. Binary count threshold (3/5) replaced with Likert mean per qa-lead Q3 — statistical power 同 nuance 大幅提升。
  - **Evidence**: `production/qa/evidence/boss_playtest_test1_[date].md`

- **AC-29b [Visual/Feel | DEFERRED-TO-v0.2 | Manual]** (Falsifiable Test #2 — class archetype distinctness): **GIVEN** post-MVP multi-archetype boss roster exists (≥3 final boss templates per Pillar 4 Scope Honesty Note), **WHEN** same playtester plays push/pull/leg-day workouts, **THEN** post-session blind survey reports「fight feel distinct across class days」mean ≥ 4.0 Likert. **MVP cannot test** — only 1 final boss in MVP. Defer until multi-archetype roster delivered (post-MVP).
  - **Evidence**: (deferred — v0.2 milestone)

- **AC-29c [Visual/Feel | ADVISORY (VS-tier) → BLOCKING (MVP gate) | Manual]** (Falsifiable Test #5 — light-workout dignity): **GIVEN** n≥5 (VS) / n≥15 (MVP gate) playtesters complete light workout (≤2 sets), **WHEN** post-workout Likert「呢個 mini-boss 收尾感覺幾acknowledge 我做過 gym?」(1=完全冇 / 5=完全 acknowledge), **THEN** mean ≥ 4.0. Fail → light-workout reward framing needs revision (per Q2 + E2 — possibly introduce session_intent flag per Q-X5).
  - **Evidence**: `production/qa/evidence/boss_playtest_test5_[date].md`

- **AC-29d [Visual/Feel | ADVISORY (post-MVP playtest) | Manual]** (new per game-designer Q4 — ritual fatigue long-term test): **GIVEN** n≥5 playtesters complete ≥30 workout sessions (≥1 month real play), **WHEN** survey「最近一次 boss kill 你想睇完定 skip?」, **THEN** mean「want to watch」 score ≥ 4.0 Likert. Validates Pillar 3 climax 嘅 long-term retention beyond first playthrough novelty.
  - **Evidence**: `production/qa/evidence/boss_ritual_fatigue_[date].md`

**MVP gate enforcement mechanism** (per qa-lead Q3): AC-29a + AC-29c **must be re-run with n≥15 sample** at MVP gate-check (per `/gate-check pre-production` skill). Mechanism: gate-check skill 必須 grep `production/qa/evidence/boss_playtest_*` for evidence file with `n=15+` sample size — without it, MVP gate verdict = CONCERNS。

- **AC-30a [Integration | ADVISORY | Integration]** (Falsifiable Test #3 + #4 logical headless — revised 2026-05-27 per qa-lead Q4): **GIVEN** scripted workout ending + boss spawn pipeline in headless Godot, **WHEN** measure timestamps via signal-emit timing for n≥30 iterations, **THEN** (Test #3 logical) workout_completed_forwarded → boss_node.visible=true p95 ≤ 500ms (logical visibility, not rendered pixel); (Test #4 logical) boss DYING signal → first loot particle emit p95 ≤ 800ms. **Caveat**: Headless ≠ production WASM browser timing — pass here is sanity-check only.
  - **Evidence**: `tests/integration/feature/boss_system/test_falsifiable3_4_logical_latency.gd`

- **AC-30b-vs [Visual/Feel | ADVISORY (VS-tier) | Manual]** (Pass 3 split per qa-lead AC-30b n≥30 bar finding — VS = internal tech demo, 30 sessions × 2 browsers = effectively soft-launch QA bar): **GIVEN** Web Export deployed + Performance.now() instrumentation + screen capture recording, **WHEN** human tester completes workout × **n≥5 sessions** across Chromium + Safari (≥3 Chromium + ≥2 Safari OR similar split), **THEN** measured timestamps satisfy: (Test #3) workout→boss visible p95 ≤ 500ms; (Test #4) boss kill → first loot particle visible p95 ≤ 800ms。Smoke-level confidence; full statistical power deferred to Polish gate per AC-30b-polish。
  - **Evidence**: `production/qa/evidence/boss_latency_browser_vs_[date].md`

- **AC-30b-polish [Visual/Feel | BLOCKING (Polish gate, NOT VS) | Manual]** (Pass 3 — full statistical power evidence for MVP→Polish transition): **GIVEN** Web Export deployed + Performance.now() instrumentation + screen capture recording, **WHEN** human tester completes workout × **n≥30 sessions** across Chromium + Safari, **THEN** measured timestamps satisfy: (Test #3) p95 ≤ 500ms; (Test #4) p95 ≤ 800ms。**Reason for manual**: Headless cannot measure rendered-pixel visibility; production WASM has GC pause + browser overhead not reproducible in CI。**Gate**: Polish phase only, NOT VS-tier 阻塞 (per Pass 3 split)。
  - **Evidence**: `production/qa/evidence/boss_latency_browser_polish_[date].md`

### 六、Newly Added ACs (Pass 2 revision per /design-review BLOCKING items)

- **AC-31 [Logic | BLOCKING | Unit]** (EC-07: boss_max_hp ceiling clamp — per qa-lead Q7): **GIVEN** player_attack_power = 4500 (max), TARGET_KILL_HITS = 9, **WHEN** Formula 1 computes boss_max_hp_raw = 200 + 4500×9×1.0 = 40700, **THEN** boss_max_hp clamped to MAX_BOSS_HP = 10000 + emit `BOSS_HP_CEILING_HIT_001` WARN telemetry with payload {raw, player_atk, clamped}。
  - **Evidence**: `tests/unit/feature/boss_system/test_ec07_hp_ceiling.gd`

- **AC-32 [Logic | BLOCKING | Unit]** (EC-08: pattern_damage_multiplier typo guard — per qa-lead Q7): **GIVEN** BossTemplate `.tres` loaded with `pattern_damage_multiplier = 25.0` (typo, should be 2.5), **WHEN** boss attack resolves, **THEN** value clamped to 2.5 + emit `BOSS_PATTERN_MULT_TYPO_001` WARN + push_warning。Validation runs at BossTemplate load time AND Formula 2 invocation time。
  - **Evidence**: `tests/unit/feature/boss_system/test_ec08_pattern_mult_clamp.gd`

- **AC-33 [Logic | BLOCKING (runtime path) + ADVISORY (CI lint path) | Unit]** (EC-10: empty attack_patterns array — Pass 3 split per qa-lead AC-12/16/33 CI self-contradiction finding): **GIVEN** BossTemplate with `attack_patterns.size() == 0` (config bug), **WHEN** boss enters ATTACKING state, **THEN** (a) **BLOCKING runtime path**: boss falls back to IDLE + emit `BOSS_EMPTY_PATTERNS_001` ERROR + boss_id payload (Formula 3 defensive empty check per Pass 3 pseudocode); (b) **ADVISORY (BLOCKED-ON: BOSS-AC-followup-08)**: BossRegistry CI lint at load time rejects empty array — CI script `tools/ci/check_boss_template_validity.gd` (deferred until tooling story completes)。
  - **Evidence**: `tests/unit/feature/boss_system/test_ec10_empty_patterns.gd` + `tools/ci/check_boss_template_validity.gd` (deferred)

- **AC-34 [Logic | BLOCKING | Unit]** (Formula 3 hash determinism cross-platform — Pass 4 A2.2 deterministic_hash() FNV-1a): **GIVEN** identical `transition_id` (String, NOT StringName) + identical `attack_count`, **WHEN** Formula 3 runs on Web Export (WASM) vs Desktop binary vs different Godot 4.6 build patches, **THEN** identical pattern selected (cross-platform + cross-build deterministic). Test MUST assert: (a) `DeterministicHash.deterministic_hash("abc")` returns the FNV-1a 32-bit value `1454761972` (golden vector — fixed by algorithm, NOT build-dependent); (b) Formula 3 with identical inputs produces identical selected pattern across (Web Export build × Desktop build × at least 2 Godot 4.6 patch versions); (c) `(deterministic_hash(seed) % len(candidates))` always non-negative (FNV-1a 32-bit masked output guaranteed ≥ 0); posmod() retained as defense-in-depth.
  - **Evidence**: `tests/unit/feature/boss_system/test_formula3_hash_determinism.gd` + `tests/unit/utils/test_deterministic_hash_fnv1a.gd`

- **AC-35 [Visual/Feel | ADVISORY | Manual]** (new per game-designer Q5 — boss fight duration vs gym rest synchronization): **GIVEN** n≥5 playtesters in real gym session completes last set, **WHEN** observe behavior, **THEN** boss fight duration + reveal ritual + loot reveal total ≤ player's post-last-rep stay time (median ≥ 45s ideally; tester documents leave-time vs boss-complete-time gap)。Validates Q5 synchronization concern。
  - **Evidence**: `production/qa/evidence/boss_gym_sync_[date].md`

### 七、Pass 3 Newly Added ACs (per Pass 2 fresh-session /design-review blocking findings)

- **AC-36 [Logic | BLOCKING | Unit]** (Rule 5 CF-3 snapshot caching enforcement — per systems-designer CF-3 unenforceable invariant finding): **GIVEN** mock #11 Stat with snapshot tracking, boss spawned with cached `player_stat_snapshot`, **WHEN** mid-fight #11 emits `stat_changed` (ATTACK_POWER 159 → 200), **THEN** (a) Formula 1 re-evaluation (if any) reads `boss.player_stat_snapshot.ATTACK_POWER == 159` (cached, NOT live); (b) Formula 2 same — cached snapshot identity preserved across N attack pattern selections; (c) CI lint `tools/ci/check_boss_snapshot_caching.gd` rejects any `Stat.get_*()` call inside `src/systems/boss/` (CI part is ADVISORY pending tooling per AC-12 pattern)。
  - **Evidence**: `tests/unit/feature/boss_system/test_ac36_snapshot_caching.gd`

- **AC-37 [Logic | BLOCKING | Unit]** (Rule 7 GP3 spawn position persistence — per gameplay-programmer global_position lazy-update finding): **GIVEN** spawn_boss called with `spawn_pos=Vector2(800, 300)`, **WHEN** observe boss immediately post-add_child, **THEN** (a) `boss.global_position == spawn_pos` exact equality (NOT Vector2.ZERO due to lazy transform); (b) `boss_committed` signal payload `spawn_pos == Vector2(800, 300)`; (c) Camera.request_focal target argument === payload spawn_pos (NOT boss.global_position late-read)。Validates GP3 explicit position-before-add_child contract。
  - **Evidence**: `tests/unit/feature/boss_system/test_ac37_spawn_position_persistence.gd`

- **AC-38 [Logic | BLOCKING | Unit]** (Rule 11 GP4 wall-clock cleanup timeout — per gameplay-programmer SceneTreeTimer bfcache finding): **GIVEN** boss in DYING state, AnimationPlayer plays "death" but `animation_finished` signal NEVER fires (simulate bfcache drop), **WHEN** observe cleanup behavior using mock `Time.get_ticks_msec()` advancing past `deadline_ms`, **THEN** (a) cleanup proceeds after wall-clock 3000ms (NOT after process_frame count — wall-clock independent of frame rate); (b) `_spawned_emitters.clear()` called exactly once; (c) `queue_free()` called。Validates bfcache-safe wall-clock pattern。
  - **Evidence**: `tests/unit/feature/boss_system/test_ac38_cleanup_wallclock_timeout.gd`

- **AC-39 [Visual/Feel | ADVISORY (post-MVP retention) | Manual]** (new Pass 3 per game-designer F1 — single-boss novelty collapse risk; Test #1b session 5+ retention): **GIVEN** n≥5 playtesters complete ≥5 workout sessions across ≥1 week (testing same single STRIKE boss content), **WHEN** post-session-5 Likert「session 5 boss kill 想 screenshot 嘅感覺對比 session 1 點?」(1=失去全部 / 3=維持 / 5=更強), **THEN** mean ≥ 3.0 (no collapse). Fail (< 3.0) → MVP boss content roster expansion 提前到 Pre-MVP，唔可以等 v0.2。Validates F1 paper fantasy → real-fantasy 收斂風險。
  - **Evidence**: `production/qa/evidence/boss_novelty_retention_[date].md`

- **AC-40 [Static | ADVISORY (CI-blocked) | Static]** (Pass 3 — Rule 16 NEVER → AC 1:1 traceability matrix per qa-lead F5): **GIVEN** Rule 16 NEVERs list (12 items), **WHEN** maintain `design/gdd/boss-system-never-traceability.md` mapping NEVER #N → covering AC IDs, **THEN** every NEVER has ≥1 AC coverage (runtime test OR CI lint OR architectural assertion); zero NEVERs marked「lint-only」without runtime check。Format: markdown table NEVER ID | covered_by_AC_ids | coverage_type (runtime/lint/arch)。
  - **Evidence**: `design/gdd/boss-system-never-traceability.md`

### 八、Pass 4 Newly Added ACs

- **AC-41 [Logic | BLOCKING | Unit]** (Pass 4 A3.3 — Formula 1 first-session duration fallback): **GIVEN** player_stat_snapshot.ATTACK_POWER == 0 (boot-time degenerate OR true first session) + workout_duration_sec scenarios {0, 300, 600, 1200}, **WHEN** Formula 1 computes boss_max_hp, **THEN** (a) workout_duration_sec=0 → effective_atk == BOOTSTRAP_ATTACK_POWER=10; (b) workout_duration_sec=300 → effective_atk == max(10, 0.5×28) = 14; (c) workout_duration_sec=600 → effective_atk == max(10, 1.0×28) = 28; (d) workout_duration_sec=1200 → effective_atk == max(10, clampf(1200/600,0,1)×28) = 28 (ramp saturates); (e) telemetry `boss.first_session_bootstrap` emit with payload {workout_duration_sec, effective_atk}; (f) ATTACK_POWER>0 path bypasses fallback unchanged. Validates Pass 4 A3.3 first-impression protection.
  - **Evidence**: `tests/unit/feature/boss_system/test_ac41_first_session_bootstrap.gd`

- **AC-42 [Logic | BLOCKING | Unit]** (Pass 4 A3.2 — mid-fight bfcache hybrid branching): **GIVEN** boss in COMMITTED state with workout_completed pre-freeze emitted, scenarios {hp_at_freeze ∈ [10%, 29%, 30%, 31%, 70%]} of max_hp, **WHEN** `_on_resume_detected` invoked (mock multi-hook resume signal), **THEN** (a) hp_at_freeze < 30% → boss enters DYING state + `boss.bfcache_skip_to_kill` telemetry; (b) hp_at_freeze ≥ 30% → boss re-enters SPAWNING state + current_hp reset to max_hp + `boss.bfcache_restart_full_hp` telemetry; (c) workout_completed NOT emitted (PRE_SPAWN freeze) → cleanup + queue_free; (d) MID_FIGHT_SKIP_HP_THRESHOLD knob tunable validated (set to 0.5, hp_at_freeze=40% → skip-to-kill).
  - **Evidence**: `tests/unit/feature/boss_system/test_ac42_bfcache_hybrid_branching.gd`

- **AC-43 [Logic | BLOCKING | Unit]** (Pass 4 A1.2 — spawn_boss null_snapshot path): **GIVEN** mock #14 calls `spawn_boss(template, "txn123", spawn_pos, player_snapshot=null)`, **WHEN** spawn_boss processes entry guards, **THEN** (a) returns null (NOT a BossInstance); (b) no `add_child` call (no boss instance created); (c) `BOSS_NULL_SNAPSHOT_001` push_error emit; (d) `boss.null_snapshot` telemetry emit with transition_id payload; (e) #14 BossAnchor caller-side rollback expected (out of scope for #16 AC; covered by #14 GDD next-revision).
  - **Evidence**: `tests/unit/feature/boss_system/test_ac43_null_snapshot_rejection.gd`

### Coverage Map

| Source | AC IDs |
|---|---|
| Rule 1 | AC-01 |
| Rule 2 | AC-02 |
| Rule 3 | AC-03 |
| Rule 4 | AC-04 |
| Rule 5 | AC-05, AC-17, AC-18 |
| Rule 6 | AC-06, AC-20 |
| Rule 7 | AC-07 |
| Rule 8 | AC-08 |
| Rule 9 | AC-09 |
| Rule 10 | AC-10 |
| Rule 11 | AC-11 |
| Rule 12 | AC-12 |
| Rule 13 | AC-13 |
| Rule 14 | AC-14 |
| Rule 15 | AC-15 |
| Rule 16 | AC-12, AC-16 (CI lint sweep) |
| Formula 1 | AC-17, AC-18 |
| Formula 2 | AC-19 |
| Formula 3 | AC-20 |
| Formula 4 | AC-21 |
| CF-1 | AC-18 |
| CF-2 | AC-19 |
| CF-3 | AC-22 |
| CF-4 | AC-20 |
| CF-5 | AC-21 |
| CI-1 | AC-22 |
| CI-2 | AC-22 |
| CI-3 | AC-23 |
| CI-4 | AC-24 |
| CI-5 | AC-23 |
| EC-01 | AC-25 |
| EC-02 | AC-26 |
| EC-16/17 | AC-27 |
| EC-23 | AC-26 |
| EC-24 | AC-28 |
| Falsifiable Test #1/2/5 | AC-29 |
| Falsifiable Test #3/4 | AC-30 |
| FR-1 | AC-29 |
| FR-2 | AC-29 |
| FR-3 | AC-29 |
| Pass 3 CF-3 snapshot caching | AC-36 |
| Pass 3 GP3 spawn position persistence | AC-37, AC-07 (revised) |
| Pass 3 GP4 wall-clock cleanup | AC-38 |
| Pass 3 F1 session 5+ retention | AC-39 |
| Pass 3 F5 NEVER traceability | AC-40 |
| Pass 3 F2 Camera-Leading reorder | AC-07 (revised) |
| Pass 4 A1.1 BossInstance class | AC-01 (revised — scene tree contract assertions), AC-37 |
| Pass 4 A1.2 spawn_boss null_snapshot | AC-43 |
| Pass 4 A1.3 4-param canonical signature | AC-07 (revised), AC-37 |
| Pass 4 A1.4 boss_committed sync emit | AC-07 (revised) |
| Pass 4 A2.1 Web Export multi-hook | AC-27a (revised), AC-42 |
| Pass 4 A2.2 deterministic_hash() FNV-1a | AC-34 (revised) |
| Pass 4 A2.3 GP3 post-add_child + is_equal_approx | AC-37 (revised), AC-07 (revised) |
| Pass 4 A3.1 mini UNCOMMON-RARE band | AC-03 (revised), AC-09 (revised) |
| Pass 4 A3.2 bfcache hybrid skip-to-kill | AC-42 |
| Pass 4 A3.3 first-session bootstrap | AC-41, EC-05 (revised) |
| Pass 4 A4.1 INV-1/INV-2 removal | Forward-constrained to #14 GDD (Followup #14) |
| Pass 4 A4.2 AC-10 stale MINI rewrite | AC-10 (revised) |

### Test Type Distribution (revised 2026-05-28 Pass 4)

| TestKind | Count | % |
|---|---|---|
| Unit | 32 | 65.3% |
| Integration | 5 | 10.2% |
| Static | 3 | 6.1% |
| Manual | 9 | 18.4% |
| **Total** | **49** | 100% |

### Gate Distribution (Pass 4)

| Gate | Count | AC IDs |
|------|-------|--------|
| BLOCKING (runtime) | 36 | Pass 3 BLOCKING set + {AC-41 Pass 4 A3.3 first-session bootstrap, AC-42 Pass 4 A3.2 bfcache hybrid, AC-43 Pass 4 A1.2 null_snapshot} |
| ADVISORY (VS playtest / sanity check / CI-blocked) | 11 | AC-12, AC-16, AC-33 (CI path), AC-27b, AC-29a/c (VS), AC-29d, AC-30a, AC-30b-vs, AC-35, AC-39, AC-40 |
| DEFERRED | 2 | AC-23 (→#15 implementation), AC-29b (→v0.2 multi-archetype) |
| BLOCKING (MVP gate / Polish gate escalation) | 3 | AC-29a/c MVP gate (escalation), AC-30b-polish |

**Note**: Pass 3 had 46 effective ACs. Pass 4 adds 3 BLOCKING Unit ACs: (a) AC-41 (Formula 1 first-session duration bootstrap per A3.3); (b) AC-42 (Rule 12 mid-fight bfcache hybrid branching per A3.2); (c) AC-43 (spawn_boss null_snapshot rejection per A1.2). Total = 49 effective ACs。

### Coverage Gaps (誠實清單)

1. **EC-03..EC-22 (non-CRITICAL severity)** — 18 個 HIGH/MEDIUM/LOW ECs 推遲到 `tests/unit/feature/boss_system/edge_cases_minor_test.gd` sprint 3 補做
2. **Visual/Audio playtest beyond AC-29** — boss reveal "screenshot worthy" + class archetype distinctness 嘅 binary survey 唔等於 visual treatment full validation；建議 Pre-MVP 階段做 dedicated visual playtest session
3. **Boss death animation timing precision** — 30fps vs 60fps platform differences 未測；defer to Visual Polish phase
4. **v0.2 BOSS_PHASE_TRANSITION state inheritance** — MVP 唔覆蓋；待 v0.2 GDD revision
5. **Q-V2 boss sprite ownership resolution** — #16 vs #26 Avatar Renderer 邊個 own boss sprite 仲未定 (Section J Open Questions)
6. **MVP 只有 1 final boss content** — AC-29 class archetype playtest n=15 dependency on having 3 final boss templates designed (Pre-MVP authoring requirement)

## Open Questions

### Cross-system Questions (Q-X) — resolve via downstream GDD authoring or next-revision batch

| ID | Question | Owner | Target resolution | Affects |
|----|----------|-------|-------------------|---------|
| **Q-X1** | 應否喺 #5 Particle System next-revision 加 dedicated `BOSS_REVEAL` preset (vs MVP reuse `LOOT_RARE_BURST`)? Dedicated preset 可以有 boss-specific particle shape + slower decay (建立 「different from loot」 visual identity)。MVP reuse 接受；v0.2 budget 多個 preset entry | technical-artist + #5 owner | #5 GDD next-revision batch OR v0.2 milestone | Rule 7 + Section I |
| ~~**Q-X2**~~ | ~~Mid-fight bfcache resume 嘅 boss restart timing~~ — **RESOLVED 2026-05-28 Pass 4 A3.2** per CD Pillar 1 vs Pillar 2 adjudication: hybrid skip-to-kill (HP<30%) / restart-at-full (HP≥30%) / cleanup (no commit). See Rule 12 + EC-17 revised. Threshold calibration deferred to Pre-Production playtest (telemetry `boss.bfcache_skip_to_kill` + `boss.bfcache_restart_full_hp` data) but mechanism locked. | ~~gameplay-programmer + #14 owner~~ | **CLOSED** | ~~Rule 12 + EC-17~~ |
| **Q-X3** | Boss HP / damage formula 應否 expose per-archetype scaling 倍率 (e.g., MOBILITY boss HP × 0.8 但 MOVE_SPEED × 1.3 嘅 net challenge equivalence)? MVP 用 single HP_SCALE_FACTOR；v0.2 per-archetype tuning | systems-designer + #14 owner | Post-AC-29 playtest evidence + v0.2 | Formula 1 + Knob `HP_SCALE_FACTOR` |
| **Q-X4** | systems-index 應否 add #16 → 5/6/7 visual ritual dependency arrows? 目前 systems-index 入面 #16 依賴 = 9/13/14/15。但 #16 Rule 7 direct call #5/#6/#7。為 next-revision propagate-design-change task | producer + systems-designer | Next /map-systems revision OR systems-index manual update | Systems-index dependency map |
| **Q-X6** (Pass 3 — per economy-designer E2 loot sink finding) | 30 sessions × ~6 guaranteed drops = 180 drop inflation。Loot sink 喺邊度 own? 候選: (a) #17 Equipment & Inventory (salvage / disenchant on item replace); (b) 新增 #34 LootSink GDD; (c) inventory cap auto-discard。冇 sink → COMMON-UNCOMMON 數量 unbounded growth → loot ritual 失去意義 (玩家「又係 COMMON skip」)。 | economy-designer + producer (cross-doc #17 owner) | Pre-MVP — #17 Equipment & Inventory GDD authoring time | Section F downstream consumers; potentially Section E new EC for inventory-full case |

### Visual/Audio Questions (Q-V)

| ID | Question | Owner | Target resolution | Affects |
|----|----------|-------|-------------------|---------|
| **Q-V1** | Boss background music loop 應否 pause on hit_pause (#6 Rule 7) OR continue? Pause = unified hit pause feeling; continue = music continuity | audio-director + #4 owner | #4 Audio Manager GDD authoring | Section I |
| **Q-V2** | Boss sprite ownership — #16 BossTemplate own `visual_template` resource OR #26 Avatar Renderer extension 處理 all character sprites including boss? 目前 #16 假設 own，但 #26 future-design 可能更 holistic | art-director + #26 owner (Not Started) | #26 Avatar Renderer GDD authoring | Section I + Rule 1 schema |

### Content Questions (Q-C)

| ID | Question | Owner | Target resolution | Affects |
|----|----------|-------|-------------------|---------|
| **Q-C1** | MVP 1 final boss content — 應該設計 push 定 pull 定 leg archetype 作為 first boss? Per game-concept MVP 5 exercises 包含 1 push + 1 pull + 1 leg，所以 boss archetype 唔可以 limit player choice。Recommendation: spawn UNKNOWN-class fallback STRIKE final boss (universal coverage), defer multi-archetype to Pre-MVP tier | game-designer + creative-director | MVP content authoring sprint | Rule 2 + AC-29 |
| **Q-C2** | Mini-boss content count for VS tier — 3 archetype templates (1 per class) 夠 demonstrate Pillar 4 distinctness? OR 需要 6+ templates 確保 variation within archetype? | game-designer + level-designer | VS-tier content scope | Rule 2 + AC-29 |
| **Q-C3** | Boss attack pattern count per template — MVP target 2-3 patterns per final boss。應該全部 hand-designed OR 部分 procedurally varied? Hand-designed simpler + tighter feel; procedural 可能 broader replay | game-designer | Pre-MVP playtest evidence | Rule 6 + AC-06 |

### Followup-Tracked Items (test gaps from Section H — NOT blocking; revised 2026-05-27 Pass 2)

- **BOSS-AC-followup-01**: Non-CRITICAL ECs (15 remaining items after EC-07/08/10 promoted to AC-31/32/33) → `tests/unit/feature/boss_system/edge_cases_minor_test.gd` sprint 3 補做
- **BOSS-AC-followup-02**: Visual playtest beyond AC-29 survey — dedicated visual treatment validation session at Pre-MVP
- **BOSS-AC-followup-03**: Boss death animation 30fps vs 60fps platform precision testing at Visual Polish phase
- **BOSS-AC-followup-04**: AC-29a/c sample size n=5 → n=15 MVP gate enforcement (gate-check skill grep for evidence file)
- **BOSS-AC-followup-05**: Knob safe range boundary tests (sweep MIN_BOSS_HP / MAX_BOSS_HP / TARGET_KILL_HITS extremes for degenerate detection)
- **BOSS-AC-followup-06**: v0.2 BOSS_PHASE_TRANSITION state design (per #14 enemy_ai_state_enum v0.2 hook)
- **BOSS-AC-followup-07**: Q-V2 boss sprite ownership resolution — Pass 2 revision stubs `BossVisualResource` in #16 with TODO note; refactor when #26 Avatar Renderer finalizes shared visual interface
- **BOSS-AC-followup-08**: CI tooling stories (per qa-lead Q5) — `tools/ci/check_boss_no_persist.gd` + `check_boss_nevers.gd` + `check_boss_template_validity.gd` need separate implementation stories before AC-12/16/33 can pass
- **BOSS-AC-followup-09**: Q-X5 session_intent flag feasibility — GymSys API extension needed if pursued; gate on Pre-MVP backend evaluation
- **BOSS-AC-followup-10**: AC-29d ritual fatigue long-term test — needs ≥30 sessions data, gates on real users completing 1-month play
- **BOSS-AC-followup-11**: Pre-fight grace window design (per game-designer Q5) — boss reveal vs gym last-rep stay-time synchronization; needs real-gym observational data first (AC-35 evidence)
- **BOSS-AC-followup-12** (Pass 3): Loot sink cross-doc design (per economy-designer E2 + Q-X6) — #17 Equipment & Inventory GDD authoring 必須 land disenchant / salvage / cap mechanism before MVP gate；inventory rot risk gates Pillar 3 long-term integrity
- **BOSS-AC-followup-13** (Pass 3): ArenaConfig.tres ownership + autoload exposure (per gameplay-programmer GP5/GP7 + Rule 14 Pass 3) — `res://data/arena_config.tres` Resource schema + `#14 EnemyDirector` load + cache path 必須 喺 #14 GDD next-revision declare ownership boundary
- **BOSS-AC-followup-14** (Pass 3 — expanded Pass 4 A4.1): Mini-boss knob ownership migration (per systems-designer orphan knobs) — `MINI_BOSS_TARGET_KILL_HITS` + `MINI_BOSS_DAMAGE_RATIO_PER_HIT` 必須喺 #14 GDD next-revision declare ownership 同 safe range. **Pass 4 expansion**: #14 GDD MUST also declare the cross-system invariants formerly held by #16 INV-1/INV-2 (now removed per A4.1) — `MINI_BOSS_TARGET_KILL_HITS < #16 TARGET_KILL_HITS_FINAL` + `MINI_BOSS_DAMAGE_RATIO_PER_HIT < #16 DAMAGE_RATIO_PER_HIT_FINAL` as #14's Cross-Knob Invariants entries (gradient guards owned by mini-boss side post split).
- **BOSS-AC-followup-15** (Pass 3 — expanded Pass 4 A3.1): EnemyTemplate loot rarity field schema — #14 GDD next-revision 必須 add THREE fields: `loot_modifier = MINI_BOSS_LOOT` (existing) + `loot_rarity_floor = UNCOMMON` (NEW Pass 4 A3.1) + `loot_rarity_ceiling = RARE` (Pass 4 A3.1 — raised UNCOMMON→RARE per game-concept promise restoration). Plus AC test for mini-boss range enforcement (currently #16 AC-09 narrowed to FINAL only post Pass 3).
- **BOSS-AC-followup-16** (Pass 3): CI tooling scope expansion — `tools/ci/check_boss_snapshot_caching.gd` (AC-36 CI part) added to BOSS-AC-followup-08 tooling story scope
- **BOSS-AC-followup-17** (Pass 3 fresh-session re-review B1.2): `IClock` dependency injection seam architectural decision — AC-38 wall-clock test 需要 mockable Time abstraction; pre-implement seam before sprint per TIER B deferral
- **BOSS-AC-followup-18** (Pass 3 fresh-session re-review godot-specialist + Pass 4 A2.1 expansion): Web Export lifecycle reference doc at `docs/engine-reference/godot/modules/web-lifecycle.md` MUST document: (a) NOTIFICATION_APPLICATION_RESUMED Mobile-only scope (NOT Web), (b) Web Export resume detection requires NOTIFICATION_APPLICATION_FOCUS_IN + NOTIFICATION_WM_WINDOW_FOCUS_IN + JavaScriptBridge `pageshow` event multi-hook coverage, (c) `platform_detect.gd` autoload as the only allowed `JavaScriptBridge.eval()` callsite per ADR-001, (d) `page_shown_from_bfcache` signal contract. Owner: technical-director.
- **BOSS-AC-followup-19** (Pass 4 A2.2): `res://src/utils/deterministic_hash.gd` autoload/static helper — FNV-1a 32-bit implementation. Single source of truth for any seed-from-string operation across the codebase (Formula 3, Rule 2 spawn algorithm, future formula authoring). Includes golden vector test asserting `deterministic_hash("abc") == 1454761972`.
- **BOSS-AC-followup-20** (Pass 4 A1.1): BossInstance scene tree contract CI lint — `tools/ci/check_boss_scene_tree_contract.gd` validates every `res://scenes/bosses/*.tscn` has root type = `BossInstance` + required child nodes ($AnimationPlayer / $CollisionShape2D / $Sprite2D / $HitArea2D) + AnimationPlayer animation library contains required animation names (idle / telegraph / staggered / death + attack_<id> per BossTemplate.attack_patterns). Added to BOSS-AC-followup-08 tooling story scope.
- **BOSS-AC-followup-21** (Pass 4 A2.3): BossSystem autoload parent transform identity CI lint — `tools/ci/check_boss_parent_identity_transform.gd` validates BossSystem autoload root node has `Transform2D.IDENTITY` + no parent-transform-modifying ancestor (camera follower, world container with zoom). Added to BOSS-AC-followup-08 tooling story scope.
