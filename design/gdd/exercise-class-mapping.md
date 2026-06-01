# Exercise → Class Mapping

> **Status**: In Design
> **Author**: Frank + (lean — no specialist agents this pass)
> **Last Updated**: 2026-06-01
> **Implements Pillar**: Pillar 4 (Muscle = Class) — data-layer foundation
> **System #**: 10 (Core / Pre-MVP tier)
> **Depends On**: ADR-0007 Class Enum Convention (Accepted), #2 GymSysBackendClient (exercise data source)
> **Depended On By**: #9 WorkoutStateTracker (dominant_class lookup), #12 AbilitySystem (class routing), #16 Boss System (archetype), #18 PR Detection (PR→class routing), #11 Stat System (class-aware stat gate)
> **Governing ADRs**: ADR-0007 (AbilityClass enum {STRIKE,CONTROL,MOBILITY,UNKNOWN}), ADR-0008 (autoload position — Accepted), ADR-0003 (no per-player persistence — static config)

## Overview

ExerciseClassMapping 係 Mirror Hero Pillar 4「Muscle = Class」嘅 canonical 資料層 — 將 gym exercise 映射到 RPG ability class {STRIKE, CONTROL, MOBILITY}。佢係一個 **closed lookup 服務 autoload**，暴露 `get_class_for_exercise(exercise_id) -> AbilityClass`（+ movement-pattern fallback），data-driven 經 `ExerciseRegistry.tres`（exercise_id → class，無 hardcode）。核心映射規則：**push movement → STRIKE（對 STR）、pull → CONTROL（對 DEX）、leg → MOBILITY（對 VIT）**，1:1:1 嚴格對應 #11 Stat 嘅 STR/DEX/VIT + #12 Ability 嘅 3-class × 3-tier scope（**禁止 hybrid class** per #12 FR-1）。未識別嘅 exercise 返 `UNKNOWN` sentinel（ADR-0007 — 唔 fabricate zero-default class）。本系統只擁有 **per-exercise lookup + class taxonomy**；workout 期間嘅 streaming `dominant_class` 聚合（sticky-last-leader）由 **#9 WorkoutStateTracker 擁有**，#9 每 set call 本系統 lookup。Mapping table 係 static config，**無 per-player persistence**（唔寫 user state）。玩家唔直接見到呢個系統，但佢 enable 咗「我今日練乜 = 我變成邊個 class」嘅 Pillar 4 因果。

## Player Fantasy

**Indirect Pillar 4 Fantasy — 練乜變乜（You Are What You Train）**

felt promise：「**我 push day 操胸同三頭，打開 game 我個 avatar 就係 STRIKE 型 — 大隻、近身、重擊。第二日 pull day 練背同二頭，系統知道我今日傾向 CONTROL。我冇揀過 class，冇課金解鎖，我嘅 class 傾向係我真實肌群訓練嘅誠實鏡像 — 練咩肌群，就係咩 RPG 身份。**」

唔由本系統 emit 任何嘢，而係由 **architectural posture** 強制：
- **Honest 1:1:1, no fabrication** — push→STRIKE / pull→CONTROL / leg→MOBILITY。唔識嘅 exercise 老實返 `UNKNOWN`，唔猜、唔默默 default 落 STRIKE（fabrication = Pillar 1/4 違反；fallback 由 consumer 明確處理 — 如 #16 boss UNKNOWN→STRIKE 係 consumer 嘅明示決定，唔係 #10 偷偷塞）。
- **Static taxonomy, not gameable** — mapping 係 fixed config，玩家改唔到、課金買唔到「做 cardio 當練胸」。Real muscle → real class。
- **Invisible truth-teller** — 本身無 UI/VFX/SFX；class identity 由 #12 Ability / #16 Boss / avatar 呈現。#10 只係安靜噉講真話。

**Pillar links**：Pillar 4（Muscle = Class）PRIMARY data foundation；Pillar 1 supporting（class 由真實 exercise 推導，無 in-game shortcut）。

## Detailed Design

### Core Rules

**Rule 1 — AbilityClass enum (reference ADR-0007)**：`AbilityClass { STRIKE, CONTROL, MOBILITY, UNKNOWN }`（declaration order load-bearing，UNKNOWN sentinel **last**，per ADR-0007 Classification family）。#10 **引用** canonical 共享 enum，唔自己重定義。

**Rule 2 — Closed lookup API**
```gdscript
func get_class_for_exercise(exercise_id: StringName) -> AbilityClass   # 主 lookup；未知→UNKNOWN
func get_class_for_movement_pattern(pattern: MovementPattern) -> AbilityClass  # fallback
func is_known_exercise(exercise_id: StringName) -> bool
# 無 mutator — static config，read-only（CI ban 外部寫）
```

**Rule 3 — `ExerciseRegistry.tres` 結構（data-driven）**：entry = `{exercise_id, movement_pattern, ability_class, muscle_group, aliases: Array}`；boot load，runtime immutable。

**Rule 4 — Movement-pattern → class 1:1:1 spine**：`PUSH→STRIKE`、`PULL→CONTROL`、`LEGS→MOBILITY`。其他 pattern（CORE / CARDIO / FLEXIBILITY / COMPOUND）由 registry entry **明確** authored class 決定（compound 如 deadlift = 作者明示，唔由系統猜）。

**Rule 5 — Lookup precedence（deterministic, pure）**：(1) exact `exercise_id` → its class；(2) else known `movement_pattern` → pattern map；(3) else → `UNKNOWN`。

**Rule 6 — No fabrication**：冇 authored mapping 又冇 known pattern → **必返 UNKNOWN**，永不猜或 default 落 STRIKE。Consumer 自行決定 fallback（#16 boss UNKNOWN→STRIKE 係 consumer 明示）。

**Rule 7 — GymSys id 來源 + alias**：`exercise_id` 由 GymSys workout data（#2）嚟，consumer 傳入（#10 唔自己 fetch）。GymSys 命名差異經 registry `aliases` → canonical id 解決。

### States and Transitions

| State | Entry | Behaviour |
|-------|-------|-----------|
| **BOOTING** | `_ready()` | load `ExerciseRegistry.tres`；lookup 未 ready 前返 UNKNOWN |
| **READY** | registry loaded | 正常 serve lookups（pure，無 side effect） |
| **FAILED** | registry 缺失 / corrupt | push_error 一次 + 所有 lookup 返 UNKNOWN（safe degrade，無 crash） |

純 stateless lookup — **無 GSM subscription、無 SUSPENDED、無 persistence**（唔同其他 autoload；佢係被動 truth-teller）。

### Interactions with Other Systems

1. **#2 GymSysBackendClient** — `exercise_id` 命名來源（alias table 對齊）。
2. **#9 WorkoutStateTracker** — 每 set call `get_class_for_exercise`；**#9 owns streaming `dominant_class` 聚合（sticky-last-leader）— #10 唔做 aggregation**。
3. **#12 AbilitySystem / #11 Stat System** — class routing（push→STRIKE→STR）+ class-aware stat gate 用同一 mapping。
4. **#16 Boss System / #18 PR Detection** — consume class enum。
5. **Forbidden coupling**：#10 唔 compute dominant_class、唔 persist、唔訂閱 gameplay signal、唔 fabricate non-UNKNOWN class。

> ⚠️ **Open Question（boot order）**：ADR-0008 map（pos 1-14）**未包含 #10**。若做 autoload，必須 insert 喺 StatSystem(5) / Ability(6) / WST(8) consumer **之前**（after GymSys 4）。替代方案：做 **static lookup class**（無 boot-order concern，registry lazy-load）。→ 見 Open Questions，需 ADR-0008 insertion 或 static 決定。

## Formulas

**Formula 1 — Class resolution（deterministic, categorical, pure）**

```
resolve_class(exercise_id) =
    registry[exercise_id].ability_class              if exercise_id ∈ registry
    pattern_map[ movement_pattern(exercise_id) ]     elif movement_pattern known
    UNKNOWN                                          otherwise
```

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `exercise_id` | StringName | — | GymSys exercise id（or alias → canonical） |
| `pattern_map` | const | fixed | `{PUSH→STRIKE, PULL→CONTROL, LEGS→MOBILITY, CORE/CARDIO/FLEX/COMPOUND→authored}` |
| output | AbilityClass | {STRIKE, CONTROL, MOBILITY, UNKNOWN} | categorical（無 numeric range） |

**Property**：deterministic + pure（同 input → 同 output，無 RNG / 無 time / 無 state）。**Example**：`resolve_class("bench_press")` → registry hit → STRIKE；`resolve_class("unknown_yoga_flow_x")` → 無 entry + 無 known pattern → UNKNOWN。

> **Note**：本系統**無 balance / scaling 公式**（唔似 #11 Stat / #13 Combat）。佢係純 categorical lookup；唯一「math」係上述 resolution function。dominant_class 嘅 weighted aggregation 公式屬 **#9 WST**，唔喺度。

## Edge Cases

- **If `exercise_id` 唔喺 registry 又無 known movement_pattern**：返 `UNKNOWN`（Rule 6，no fabrication）。
- **If `exercise_id` 係 alias**：先 resolve 去 canonical id，再返其 class。
- **If registry 有 duplicate `exercise_id`**：boot validation push_error + first entry wins（deterministic）。
- **If `exercise_id` 係 empty / null**：返 `UNKNOWN` + push_warning（唔 crash）。
- **If `ExerciseRegistry.tres` 缺失 / corrupt**：進入 FAILED，所有 lookup 返 `UNKNOWN` + push_error 一次（safe degrade）。
- **If registry entry 明確 author 落 `UNKNOWN`**：合法返 UNKNOWN（作者有意，唔當 error）。
- **If compound exercise（e.g. deadlift = pull+legs）**：registry 明確 author **單一** class（作者決定，如 MOBILITY 或 CONTROL）— 無 multi-class、無 hybrid（#12 FR-1）。
- **If GymSys 送新 `exercise_id`（registry 未收錄）**：返 `UNKNOWN`（graceful）+ log 一次提示 registry 需更新（consumer fallback 處理）。
- **If `exercise_id` 大小寫 / 空格差異（"Bench Press" vs "bench_press"）**：lookup 前 normalize（lowercase + trim + 空格→`_`），避免 false miss。
- **If `movement_pattern` 係 pattern_map 無嘅新值**：返 `UNKNOWN`。

## Dependencies

- **Upstream**：
  - **ADR-0007**（hard, design）— AbilityClass enum {STRIKE,CONTROL,MOBILITY,UNKNOWN} 必須一致。
  - **#2 GymSysBackendClient**（soft）— `exercise_id` 來源（命名差異經 alias 對齊）。
  - **`ExerciseRegistry.tres`**（hard data）— exercise→class mapping table。
- **Downstream**（呢啲 GDD 應反向列「depends on #10」）：
  - **#9 WorkoutStateTracker**（hard）— 每 set lookup（#9 owns dominant streaming）。
  - **#12 AbilitySystem + #11 Stat System**（hard）— class routing / class-aware stat gate。
  - **#16 Boss System + #18 PR Detection**（soft）— consume class enum。
- **Bidirectional flag**：consumer GDD 應列「depends on #10」（#12 ability-system.md 已有 provisional 條目，#10 authored 後升 confirmed）。

## Tuning Knobs

| Knob | Type | 安全 / 危險 |
|------|------|------------|
| `ExerciseRegistry.tres` entries（exercise→class + aliases） | data | 唯一 designer-adjustable surface。安全：加新 exercise / alias；危險：mis-map 常見 exercise → 錯 class identity（玩家信任受損） |
| `pattern_map`（PUSH→STRIKE / PULL→CONTROL / LEGS→MOBILITY） | **LOCKED — 唔係 knob** | 改動破壞 #12 FR-1 1:1:1（3 class × 3 tier scope）+ #11 stat routing。唔可調。 |
| normalize rule（lowercase + trim + 空格→`_`） | fixed | 確保 lookup 穩定，唔當 knob |

實際可調嘅淨係 registry 內容（content authoring），唔係 numeric tuning。

## Visual/Audio Requirements

**None** — pure data layer，無 visual / audio。Class identity 由 #12 AbilitySystem / #16 Boss / avatar 呈現，唔由本系統 emit。

## UI Requirements

**None player-facing** — 無 runtime UI。`ExerciseRegistry.tres` 編輯係 dev-time（Godot inspector / `.tres` 編輯），唔係玩家介面。

## Acceptance Criteria

- **AC-01 [Rule 2/5]** GIVEN registry `bench_press→STRIKE`，WHEN `get_class_for_exercise("bench_press")`，THEN STRIKE。
- **AC-02 [Rule 4]** GIVEN pattern_map，WHEN `get_class_for_movement_pattern(PUSH/PULL/LEGS)`，THEN STRIKE/CONTROL/MOBILITY 對應。
- **AC-03 [Rule 6]** GIVEN unknown exercise + unknown pattern，WHEN lookup，THEN `UNKNOWN`（never fabricated）。
- **AC-04 [Rule 5 precedence]** GIVEN exercise_id 喺 registry 但其 pattern 會 map 去另一 class，WHEN lookup，THEN registry exact class 勝過 pattern。
- **AC-05 [alias + normalize]** GIVEN alias `"Bench Press"→bench_press`，WHEN `lookup("Bench Press")`，THEN STRIKE。
- **AC-06 [FAILED]** GIVEN registry 缺失，WHEN lookup，THEN `UNKNOWN` + push_error 一次，無 crash。
- **AC-07 [no hybrid]** GIVEN 任何 registry entry，WHEN introspect `ability_class`，THEN ∈ {STRIKE,CONTROL,MOBILITY,UNKNOWN}（無 hybrid 值）。
- **AC-08 [determinism]** GIVEN 同 exercise_id，WHEN lookup 兩次，THEN identical。
- **AC-09 [dup]** GIVEN duplicate exercise_id，WHEN boot，THEN push_error + first wins。
- **AC-10 [normalize]** GIVEN `"bench press"` / `"Bench_Press"`，THEN 兩者 resolve 去同一 class。

> *Lean pass — `systems-designer` / `qa-lead` not consulted (user opted no agent spawns). Validate before story creation.*

## Open Questions

- **Q1（boot order，HIGH）**：autoload-vs-static lookup 決定 + 若 autoload 需 ADR-0008 insertion（before StatSystem 5 / AbilitySystem 6 / WST 8，after GymSys 4）。ADR-0008 map 目前未含 #10。Owner：technical-director。
- **Q2**：完整 authored exercise→class table 內容（需 GymSys exercise taxonomy — 邊啲 exercise_id GymSys 實際 emit）。MVP 至少覆蓋 game-concept 5 MVP exercises（≥1 push / 1 pull / 1 leg）。Owner：game-designer + GymSys ref。
- **Q3**：compound exercise（deadlift / clean / thruster）canonical 單一 class 指派。Owner：game-designer。
- **Q4**：unknown-exercise telemetry → #28 registry-update feedback loop。Defer（#28 Not Started）。
