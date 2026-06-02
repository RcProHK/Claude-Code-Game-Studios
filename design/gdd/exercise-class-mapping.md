# Exercise → Class Mapping

> **Status**: **Approved 2026-06-02** (Pass 2 NEEDS REVISION — 9 BLOCKING resolved inline per CD-supplied resolutions; CD verdict: fix 完即 APPROVE, no Pass 3 required)
> **Author**: Frank + (lean author pass; Pass 1 full 4-specialist adversarial review 2026-06-02 — 13 BLOCKING resolved inline; Pass 2 fresh 4-specialist re-review 2026-06-02 — 9 BLOCKING + ~12 RECOMMENDED, core 5 textual fixes resolved inline)
> **Last Updated**: 2026-06-02
> **Implements Pillar**: Pillar 4 (Muscle = Class) — data-layer foundation
> **System #**: 10 (Core / Pre-MVP tier)
> **Depends On**: ADR-0007 Class Enum Convention (Accepted), #2 GymSysBackendClient (exercise data source)
> **Depended On By**: #9 WorkoutStateTracker (dominant_class lookup), #12 AbilitySystem (class routing), #16 Boss System (archetype), #18 PR Detection (PR→class routing), #11 Stat System (class-aware stat gate)
> **Governing ADRs**: ADR-0007 (AbilityClass enum {STRIKE,CONTROL,MOBILITY,UNKNOWN}), ADR-0008 (**Autoload pos 5** — after GymSys pos 4, before StatSystem; insertion rule + binding constraint 7 **added 2026-06-02, TD sign-off done**), ADR-0003 (no per-player persistence — static config)

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

> **[godot-gdscript-specialist] Pass 1 BLOCKING 修正 — `int` return type**：`AbilityClass` 係 `AbilitySystem` autoload（`ability_system.gd:49`）嘅 inner enum；GDScript 無法在另一個 file 用 inner enum 作 return type annotation（compile error）。**現有 consumer precedent**：WST（`workout_state_tracker.gd:200/723`）、`enemy_director.gd:774` 全部用 `int` + `AbilitySystem.AbilityClass.*` 存取。**#10 統一採用 `int`**（`AbilitySystem.AbilityClass` ordinal）；doc-comment 標明係 `AbilityClass` ordinal。ADR-0007 migration step 1（起 shared `class_name AbilityClass` file）係獨立跨 consumer 工作，**唔**混入 #10 epic。`int` 嘅 ordinal-0 靜默 fabrication 風險由 boot validation loop 封堵（Rule 3）。

**Rule 2 — Closed lookup API**
```gdscript
# 返回 AbilitySystem.AbilityClass ordinal (int)；唔係裸 AbilityClass type（見 Rule 1 note）
func get_class_for_exercise(exercise_id: StringName) -> int   # 主 lookup；normalize input → exact registry match → UNKNOWN
func get_class_for_movement_pattern(pattern: int) -> int      # pattern = MovementPattern ordinal；直接 pattern_map → UNKNOWN
func is_known_exercise(exercise_id: StringName) -> bool       # normalize input → check registry
# 無 mutator — static config，read-only（CI ban 外部寫）
```
> **兩個 API 係獨立 entry point，唔互相呼叫**（見 Formula 1 重寫）：`get_class_for_exercise` 只做 registry id lookup + alias；`get_class_for_movement_pattern` 只做 pattern_map lookup。`get_class_for_exercise` 唔 fallback 入 `get_class_for_movement_pattern`（見 Formula 1 pass 1 BLOCKING 修正）。

> **[Pass 2 BLOCKING — StringName/String type contract]（systems-designer BLK-4 + godot-gdscript F4）**：API 收 `StringName`，但 registry field（`exercise_id` / `aliases`）係 `String`。GDScript 4.x `Dictionary` 入面 `&"bench_press"` 同 `"bench_press"` 係 **唔同 key** → 若內部 lookup dict 用 `String` key 而直接攞 `StringName` 查，會 **silent miss 返 UNKNOWN**（test 過、runtime 全錯）。**Resolution**：(1) 定義單一 `_normalize(raw) -> String` helper — 第一步 `var s := String(raw)` 強制 cast `StringName→String`，再 `s.to_lower().strip_edges()` + collapse 連續空格為單一 `_`；(2) **內部 lookup dict（canonical + alias）一律 `String` key、`int` value（AbilityClass ordinal）**；(3) `get_class_for_exercise` / `is_known_exercise` 入口第一件事就係 `_normalize()`，之後全程 `String`。API signature 保留 `StringName`（consumer 方便），但 cast point 明確喺 `_normalize` 第一行。**`_normalize` + empty-check order**：先 `_normalize` 再 `is_empty()` 判 empty（`&""` → `String` → `""` → empty branch，見 AC-11）。

**Rule 3 — `ExerciseRegistry.tres` 結構（data-driven）**：entry = `{exercise_id: String, movement_pattern: int, ability_class: int, muscle_group: String, aliases: Array[String]}`；boot load，runtime immutable。

> **[godot-gdscript-specialist] Pass 1 BLOCKING 修正 — schema spec**：
> - **`ExerciseEntry extends Resource`** with `@export` fields：`exercise_id: String`、`movement_pattern: int = -1`、`ability_class: int = -1`、`muscle_group: String`、`aliases: Array[String]`（唔係 `Array[StringName]` — alias 需 normalization，`String` 版更自然；boot 時 normalize 後建 lookup dict）。
>   - **[Pass 2 BLOCKING — sentinel default `-1`]（godot-gdscript F1/F8）**：`ability_class` / `movement_pattern` field default **必須係 `-1`（UNSET sentinel），唔可以係 `0`**。原因：GDScript `int` field 未填 → default `0` = STRIKE = **silent fabrication**，會 pass 「∈ {0,1,2,3}」嘅 boot 驗證（ADR-0007 zero-default FORBIDDEN 嘅核心漏洞）。default `-1` 令「作者忘記填」可被 boot loop 偵測（`-1 ∉ {0,1,2,3}` → push_error）。
> - **`ExerciseRegistry extends Resource`** with `@export var entries: Array[ExerciseEntry]`。`class_name ExerciseEntry` + `class_name ExerciseRegistry` 兩個都需要。
> - **[Pass 2 BLOCKING — runtime representation vs authoring schema]（godot-gdscript F2 + qa A1）**：`.tres`（`ExerciseEntry`/`ExerciseRegistry` Resource）係 **authoring-time schema only**。Boot 時 `_build_lookup()` 將 `Array[ExerciseEntry]` **flatten 成兩個 internal `Dictionary`**：`_class_by_id: Dictionary`（normalized `String` → `int` ability_class ordinal）+ `_canonical_by_alias: Dictionary`（normalized alias `String` → canonical `String`）。Runtime lookup 只讀呢兩個 Dictionary，**唔再 touch `ExerciseEntry` object**。
> - **GUT-safe loading strategy**：automated test 唔 load production `.tres`（headless CI 無 Godot 本地，class_name cache 可能未 register）——改用 **factory function** `_create_test_registry(entries: Array[Dictionary]) -> void`：直接收 `Array[Dictionary]`（**唔 instantiate `ExerciseEntry.new()`，零 class_name cache 依賴**），經 **同一條 `_validate_entries(rows) → _build_lookup(rows)` private path**（同 `_ready()` 共用），產生上述兩個 Dictionary。即 boot validation 喺 test 同 production 行同一套 code，符合 coding-standards「fixtures use factory functions」。
> - **Boot validation loop**（`_validate_entries()`，`_ready()` 同 factory 共用；防 ordinal-0 silent fabrication，ADR-0007 zero-default FORBIDDEN）：迭代全部 row →
>   - 驗 `ability_class != -1 AND ability_class ∈ {0,1,2,3}`（STRIKE/CONTROL/MOBILITY/UNKNOWN）；若 fail → `push_error("ExerciseRegistry: invalid/unset ability_class for [exercise_id]")` + 該 entry `ability_class` 強制回 `UNKNOWN(3)`。
>   - 驗 `movement_pattern ∈ {0..7}`（MovementPattern ordinals 含 UNKNOWN_PATTERN）；若 fail → `push_error` + 該 entry `movement_pattern` 強制回 `UNKNOWN_PATTERN(7)`。**注意：`movement_pattern` invalid 唔 discard 成個 entry** — `ability_class` 若有效照 serve（Formula 1a 唔讀 `movement_pattern`）。
>   - **Alias collision 檢查**（見 Edge Cases）：normalize 後若 alias 撞 canonical id、或撞另一 alias → `push_error` + **first-listed wins**（entries array index 序，entry 內 alias array 序），collision alias skip。

**Rule 4 — Movement-pattern → class 1:1:1 spine**：`PUSH→STRIKE`、`PULL→CONTROL`、`LEG→MOBILITY`（注意：entities.yaml 嘅 enum 係 `LEG` 單數，見 MovementPattern enum 定義）。

**`pattern_map` 只含三條 locked row，唔再列 CORE/CARDIO/FLEX/COMPOUND**（[systems-designer] Pass 1 BLOCKING 修正）：`{PUSH→STRIKE, PULL→CONTROL, LEG→MOBILITY}`。其他 movement_pattern（CORE / CARDIO / FLEXIBILITY / COMPOUND）**不在 pattern_map** — 呢啲必須有明確 registry entry，否則 `get_class_for_movement_pattern(CORE)` 直接返 `UNKNOWN`（Rule 6 no-fabrication，唔猜）。

**Compound exercise 指派原則（[game-designer] Pass 1 BLOCKING B3 — CD 裁決）**：compound 按 **primary movement pattern** 指派 single class：
- `DEADLIFT` = hip-hinge pull → **CONTROL**（posterior-chain concentric = pull pattern；跟 pull→CONTROL spine）
- `CLEAN` / `SNATCH` = pull-dominant → **CONTROL**
- `SQUAT` = leg-dominant → **MOBILITY**（primary pattern = LEG）
- `THRUSTER` / `PUSH_PRESS` = push-dominant → **STRIKE**

呢個原則令不同作者對 compound 有 deterministic 裁決框架，唔係每個人自己估。新增 compound exercise 時，先識別其 primary movement pattern，再指派對應 class。

**Rule 4b — `MovementPattern` enum 定義（[systems-designer] Pass 1 BLOCKING B3 修正）**：`MovementPattern` 喺 GDD 用作 parameter type 同 registry field type，但從未定義。**此處正式定義**（需同步至 entities.yaml 更新 + `src/core/movement_pattern.gd` 或嵌入 exercise_class_mapping.gd）：

```gdscript
enum MovementPattern {
    PUSH = 0,        # chest press, overhead press, tricep dip, etc.
    PULL = 1,        # row, pulldown, deadlift-variant (per Rule 4 compound principle)
    LEG = 2,         # squat, lunge, leg press, hip hinge leg-dominant
    CORE = 3,        # ab work, plank
    CARDIO = 4,      # running, cycling, rowing-machine
    FLEXIBILITY = 5, # stretching, yoga
    COMPOUND = 6,    # complex multi-pattern; must have explicit registry entry → primary pattern decides class
    UNKNOWN_PATTERN = 7  # sentinel; 唔認識嘅 pattern → UNKNOWN class
}
```

> **Reconcile `LEG` vs `LEGS`（entities.yaml conflict）**：entities.yaml line 376 登記 3-member enum `{PUSH, PULL, LEG}`（單數，舊版）。本 GDD 擴展為 7-member（加 CORE/CARDIO/FLEXIBILITY/COMPOUND/UNKNOWN_PATTERN），保持 `LEG`（單數）同 entities.yaml 一致。先前 GDD body 用 `LEGS`（複數）係 typo，已改 `LEG`。entities.yaml 需 update 以反映完整 7-member definition。

**Rule 5 — Lookup precedence（deterministic, pure）**：兩個獨立 entry point，唔互相 fallback：
- `get_class_for_exercise(id)` path：(1) normalize input → check registry exact match → return `ability_class`（int）；(2) else → return `UNKNOWN`（ordinal 3）。**冇 pattern_map fallback**（[systems-designer] BLOCKING B1 修正：`movement_pattern` 係 registry entry 嘅 field，registry miss 即無 entry 可讀 movement_pattern — 原 formula step 2 係 dead code，已刪）。
- `get_class_for_movement_pattern(pattern: int)` path：(1) `pattern_map[pattern]` → return class（int）；(2) pattern ∉ {PUSH,PULL,LEG} → return `UNKNOWN`。

**Rule 6 — No fabrication**：冇 authored mapping 又冇 known pattern → **必返 UNKNOWN**，永不猜或 default 落 STRIKE。Consumer 自行決定 fallback（#16 boss UNKNOWN→STRIKE 係 consumer 明示）。

**Rule 7 — GymSys id 來源 + alias**：`exercise_id` 由 GymSys workout data（#2）嚟，consumer 傳入（#10 唔自己 fetch）。GymSys 命名差異經 registry `aliases` → canonical id 解決。

### States and Transitions

| State | Entry | Behaviour |
|-------|-------|-----------|
| **BOOTING** | `_ready()` | load `ExerciseRegistry.tres` → **boot validation loop**（iterate 全部 entry，驗 `ability_class` ∈ {0,1,2,3} + `movement_pattern` ∈ known ordinals；invalid → push_error + force UNKNOWN）→ 建 normalized lookup dict。**Placement 正確（pos 5，先於所有 consumer）→ consumer 嘅 `_ready()` 呼叫時 #10 已 READY，冇實際 BOOTING race**。BOOTING-returns-UNKNOWN 係 defensive fallback，唔係設計依賴。 |
| **READY** | registry loaded + boot validation pass | 正常 serve lookups（pure，無 side effect）。`is_known_exercise()` + `get_class_for_exercise()` + `get_class_for_movement_pattern()` 全部可用。 |
| **FAILED** | registry 缺失 / corrupt | push_error 一次 + 所有 lookup 返 UNKNOWN（safe degrade，無 crash） |

純 stateless lookup — **無 GSM subscription、無 SUSPENDED、無 persistence**（唔同其他 autoload；佢係被動 truth-teller）。

### Interactions with Other Systems

1. **#2 GymSysBackendClient** — `exercise_id` 命名來源（alias table 對齊）。
2. **#9 WorkoutStateTracker** — 每 set call `get_class_for_exercise`；**#9 owns streaming `dominant_class` 聚合（sticky-last-leader）— #10 唔做 aggregation**。
3. **#12 AbilitySystem / #11 Stat System** — class routing（push→STRIKE→STR）+ class-aware stat gate 用同一 mapping。
4. **#16 Boss System / #18 PR Detection** — consume class enum。
5. **Forbidden coupling**：#10 唔 compute dominant_class、唔 persist、唔訂閱 gameplay signal、唔 fabricate non-UNKNOWN class。

> ⚠️ **Q1 已解決（[godot-gdscript-specialist + CD] Pass 1 BLOCKING）**：採用 **autoload**（跟 codebase 所有現有 consumer 嘅 singleton access posture）。插 ADR-0008 **pos 5**（GymSys pos 4 之後、StatSystem 之前），原 pos 5-14 全部 renumber +1。**Static class option dropped**（lazy-init singleton 係 GDScript 4.6 less-conventional pattern，solo dev 維護成本高；autoload placement 正確後 consumer 嘅 `_ready()` 呼叫時 #10 已 READY）。ADR-0008 insertion rule 需 TD sign-off。

> ⚠️ **UNKNOWN × sticky-last-leader — BINDING inter-system contract（[game-designer] Pass 2 BLOCKING-1，CD Pillar-level 升級）**：`#10` 返 UNKNOWN 係 honest（no fabrication）。但 #9 `dominant_class` 嘅 sticky-last-leader policy 令 UNKNOWN-dominant session（大量未收錄 exercise / yoga / cardio）維持上一 session 嘅 leader → 玩家見到舊 class。「練嘅嘢但 game 唔認」係 perceived fabrication，**直接破壞 Pillar 4「練乜變乜」promise**。
>
> **Binding contract（唔再只係 flag）**：當 `get_class_for_exercise` 返 UNKNOWN，consumer **MUST NOT 靜默 inherit 上一 session class**。具體：**#9 WorkoutStateTracker MUST 喺 #10 epic close 前，實作 UNKNOWN-dominant session 嘅 display policy**（e.g. 顯示「class undefined / today uncategorized」UI 提示，而非沿用舊 leader）。呢個係 #10 Pillar 4 promise 嘅 downstream enforcement requirement，列為 **#10 epic 解鎖 gate**（見 Dependencies §UNKNOWN contract）。#10 本身只負責 honest lookup；player-facing 呈現責任在 #9/#12/#26，但「唔可以靜默 fabricate」係 #10 對 consumer 施加嘅硬約束。

## Formulas

**Formula 1 — Class resolution（deterministic, categorical, pure）**

> ⚠️ **[systems-designer] Pass 1 BLOCKING 修正 — 兩條獨立 pure function（原 3-step formula 嘅 step 2 係 dead code）**：原 formula 嘅「elif movement_pattern known」branch 喺 `get_class_for_exercise` 呢個 entry point 永遠 unreachable（`movement_pattern` 係 registry entry 嘅 field，registry miss → 無 entry → 無 pattern 可讀）。已拆成兩條獨立 function。

**Formula 1a — exercise_id lookup**:
```
get_class_for_exercise(exercise_id) =
    normalize(exercise_id) → normalized_id
    registry[normalized_id].ability_class    if normalized_id ∈ registry    # Step 1: exact match
    UNKNOWN (ordinal 3)                      otherwise                       # Step 2: honest miss
```

**Formula 1b — movement_pattern lookup**:
```
get_class_for_movement_pattern(pattern) =
    pattern_map[pattern]                     if pattern ∈ {PUSH, PULL, LEG}  # Step 1: 3 locked entries
    UNKNOWN (ordinal 3)                      otherwise                        # Step 2: all other patterns
```

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `exercise_id` | StringName | — | GymSys exercise id（or alias → canonical，normalize applied） |
| `pattern_map` | const | fixed | `{PUSH→STRIKE(0), PULL→CONTROL(1), LEG→MOBILITY(2)}` **只含三條 locked row**（CORE/CARDIO/FLEX/COMPOUND → UNKNOWN via else branch） |
| output | int | {0,1,2,3} | `AbilitySystem.AbilityClass` ordinal（STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3） |

**Property**：deterministic + pure（同 input → 同 output，無 RNG / 無 time / 無 global state）。**Example**：`get_class_for_exercise("bench_press")` → normalize → registry hit → STRIKE(0)；`get_class_for_exercise("unknown_yoga_flow_x")` → normalize → 無 entry → UNKNOWN(3)；`get_class_for_movement_pattern(PUSH)` → STRIKE(0)；`get_class_for_movement_pattern(CORE)` → UNKNOWN(3)。

> **Note**：本系統**無 balance / scaling 公式**（唔似 #11 Stat / #13 Combat）。唯一「math」係上述 categorical resolution。dominant_class 嘅 weighted aggregation 公式屬 **#9 WST**，唔喺度。

## Edge Cases

- **If `exercise_id` 唔喺 registry 又無 known movement_pattern**：返 `UNKNOWN`（Rule 6，no fabrication）。
- **If `exercise_id` 係 alias**：先 resolve 去 canonical id，再返其 class。
- **If registry 有 duplicate `exercise_id`**：boot validation push_error + first entry wins（**first = `entries` array index 序，即 `.tres` serialization order**，deterministic）。
- **[Pass 2 BLOCKING — alias collision]** **If normalize 後 alias 撞 canonical id，或撞另一條 alias**（例如 alias `"Bench Press"` normalize 後 = `"bench_press"` 而已有 canonical `bench_press`；或兩個 entry 嘅 alias normalize 後相同）：boot validation `push_error` 一次（naming 撞嘅 key）+ **first-listed wins**（canonical 優先於 alias；alias 之間按 entries array 序 + entry 內 alias array 序），後來嘅 collision alias **skip 唔入 lookup dict**。保證 `_canonical_by_alias` 無歧義 → `get_class_for_exercise` 維持 deterministic + pure（AC-08）。
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

> ⚠️ **§UNKNOWN contract — #10 epic 解鎖 gate（[game-designer] Pass 2 BLOCKING-1）**：#9 WorkoutStateTracker **MUST** 實作 UNKNOWN-dominant session display policy（唔可靜默 inherit 舊 class，見 Interactions §UNKNOWN binding contract）先可 close #10 epic。#9 epic 現 11/12 Complete — 此 contract 可能需要一條 #9 follow-up patch story（owner：game-designer + #9 WST GDD patch，對應 Open Questions Q5）。**呢條係 cross-system gate，唔係 #10 內部工作**。

> ⚠️ **三組平行 1:1:1 enum 嘅 ordinal 共用（[systems-designer] Pass 2 BLOCKING-5 — entities.yaml pre-condition clarification）**：`MovementPattern {PUSH=0,PULL=1,LEG=2,...}`、`AbilityClass {STRIKE=0,CONTROL=1,MOBILITY=2,UNKNOWN=3}`、`target_stat {STR=0,DEX=1,VIT=2}` 三個 enum 嘅 ordinal 0/1/2 **故意對齊**（PUSH↔STRIKE↔STR …），呢個係 Pillar 4 1:1:1 spine 嘅 by-design 特性。**但三者係唔同 enum TYPE，consumer 唔可以 conflate** — 例如將 #10 嘅 `AbilityClass` ordinal 直接當 Stat System `class_id`（movement-pattern 語義）傳，雖然 ordinal 撞啱「work」，但任一 enum 將來改 declaration order 即 silent break。
> - **entities.yaml 現狀**：line 376 `class_id # enum {PUSH, PULL, LEG}` 係 Stat System `volume_tick_delta` formula 嘅 variable，語義係 **movement-pattern**（唔係 AbilityClass）。#11 已 merged，**唔做 rename**（破壞已實作 formula 風險高）；改為喺 entities.yaml 補 disambiguation 註解 + 喺度記錄語義邊界。
> - **Pre-condition（非 #10 內部）**：entities.yaml 需 (a) 將 `class_id` 註解澄清為 movement-pattern 語義並 cross-ref #10；(b) 登記完整 7-member `MovementPattern` enum。Owner：systems-designer（registry note，已隨本次 review 補 disambiguation 註解）。

> ⚠️ **Registry Coverage Invariant（[game-designer] Pass 1 BLOCKING B1 — 修正）**：`ExerciseRegistry` 必須覆蓋 GymSys MVP-emitted 全部 resistance exercise_id，否則玩家做的動作返 UNKNOWN → sticky-last-leader 破壞 Pillar 4。Coverage enforcement：
> - **Q2a（MVP）**：registry 必須含 ≥1 push / ≥1 pull / ≥1 leg entry，對應 game-concept 5 MVP exercises（bench_press=STRIKE, bent_over_row=CONTROL, barbell_squat=MOBILITY 三條 canonical entry — **已 locked，見 Open Questions Q2a resolved**）。
> - **CI build-time gate**：build 時對住 GymSys exercise taxonomy snapshot（`assets/data/gymsys_exercise_taxonomy.json`）驗 coverage；任何 GymSys 已知 resistance exercise 不在 registry → CI warning；鼓勵但 MVP 唔 fail（完整 taxonomy 係 Q2b post-MVP）。
> - **Registry owner**：game-designer 負責維護 `ExerciseRegistry.tres` 內容，隨 GymSys taxonomy 更新同步。

## Tuning Knobs

| Knob | Type | 安全 / 危險 |
|------|------|------------|
| `ExerciseRegistry.tres` entries（exercise→class + aliases） | data | 唯一 designer-adjustable surface。安全：加新 exercise / alias；危險：mis-map 常見 exercise → 錯 class identity（玩家信任受損） |
| `pattern_map`（PUSH→STRIKE / PULL→CONTROL / **LEG**→MOBILITY） | **LOCKED — 唔係 knob** | 改動破壞 #12 FR-1 1:1:1（3 class × 3 tier scope）+ #11 stat routing。唔可調。只含 3 entries，CORE/CARDIO/FLEX/COMPOUND 不在其中（見 Rule 4 修正）。 |
| normalize rule（lowercase + trim + 空格→`_`） | fixed | 確保 lookup 穩定，唔當 knob |

實際可調嘅淨係 registry 內容（content authoring），唔係 numeric tuning。

## Visual/Audio Requirements

**None** — pure data layer，無 visual / audio。Class identity 由 #12 AbilitySystem / #16 Boss / avatar 呈現，唔由本系統 emit。

## UI Requirements

**None player-facing** — 無 runtime UI。`ExerciseRegistry.tres` 編輯係 dev-time（Godot inspector / `.tres` 編輯），唔係玩家介面。

## Acceptance Criteria

- **AC-01 [Rule 5 / registry exact hit]** GIVEN a test fixture entry `{exercise_id: "test_push_a", movement_pattern: PUSH, ability_class: STRIKE(0)}`（injected via `_create_test_registry()`，唔依賴 production `.tres`），WHEN `get_class_for_exercise("test_push_a")`，THEN returns `0`（STRIKE ordinal）。**[qa-lead] Pass 1 BLOCKING 修正：AC 唔再假設 production registry 內容（Q2 deferred），改用 test-owned synthetic fixture。**
- **AC-02 [Rule 4]** GIVEN pattern_map，WHEN `get_class_for_movement_pattern(PUSH(0)/PULL(1)/LEG(2))`，THEN returns STRIKE(0)/CONTROL(1)/MOBILITY(2) 對應。**[Pass 2 BLOCKING 修正：`LEGS`(複數,enum 無此 member,會 compile error)→ `LEG`;用 ordinal 明確。]**
- **AC-03 [Rule 6]** GIVEN unknown exercise + unknown pattern，WHEN lookup，THEN `UNKNOWN`（never fabricated）。
- **AC-04 [Rule 5 precedence]** GIVEN fixture `{exercise_id:"test_conflict", movement_pattern:PUSH(0), ability_class:CONTROL(1)}`（**故意** push pattern 但 registry assign CONTROL），WHEN `get_class_for_exercise("test_conflict")`，THEN returns `CONTROL(1)` NOT `STRIKE(0)`。**[Pass 2 RECOMMENDED 修正:fixture 須明確構造 pattern↔class 衝突,否則 precedence 無從驗;亦印證兩 entry point 互不 fallback。]**
- **AC-05 [alias + normalize]** GIVEN alias `"Bench Press"→bench_press`，WHEN `lookup("Bench Press")`，THEN STRIKE。
- **AC-05b [alias normalize order]** GIVEN alias stored as `"Bench Press"`(title case)，WHEN `get_class_for_exercise("bench press")`(全小寫)，THEN returns same class as canonical `bench_press`(驗 `_normalize` 喺 alias resolution **之前**生效)。**[Pass 2 RECOMMENDED]**
- **AC-06 [FAILED — headless seam]** GIVEN `_load_registry()` 係可 override 嘅 seam,test override 令其 return `null`(模擬 registry 缺失/corrupt)，WHEN `get_class_for_exercise(any_id)`，THEN returns `UNKNOWN(3)` + push_error 一次,無 crash。**[Pass 2 BLOCKING — qa B8:FAILED state 必須有 injectable `_load_registry()` seam 先可 headless verify;否則 downgrade 為 Advisory + manual evidence。]**
- **AC-07 [boot validation / shared `_validate_entries()`]** GIVEN `_create_test_registry([{exercise_id:"bad_entry", ability_class:99, movement_pattern:PUSH}])`(經 **同一個 `_validate_entries()` helper**,同 `_ready()` 共用)，WHEN validation 行，THEN `push_error` once naming "bad_entry" AND `get_class_for_exercise("bad_entry")` returns `UNKNOWN(3)`。**[Pass 2 BLOCKING — qa A1:factory path MUST 觸發同一套 `_validate_entries()`,否則 boot validation 根本冇被測。涵蓋 ordinal ∉{0,1,2,3} 及 sentinel `-1`(unset)兩種 invalid。]**
- **AC-07b [boot validation / invalid movement_pattern]** GIVEN a registry entry with `movement_pattern` ∉ {0..7}(e.g. 99) but valid `ability_class`，WHEN `_validate_entries()` 行，THEN `push_error` once naming exercise_id AND `movement_pattern` 強制回 `UNKNOWN_PATTERN(7)` AND **`get_class_for_exercise` 仍返該 entry 嘅有效 `ability_class`**(movement_pattern invalid ≠ discard 成個 entry)。**[Pass 2 BLOCKING — systems BLK-2 + qa B5:invalid movement_pattern 零 AC coverage + force 邊個 field 未定義。]**
- **AC-08 [determinism]** GIVEN 同 exercise_id，WHEN lookup 兩次，THEN identical。
- **AC-09 [dup]** GIVEN duplicate exercise_id，WHEN boot，THEN push_error + first wins。
- **AC-10 [normalize]** GIVEN `"bench press"` / `"Bench_Press"`，THEN 兩者 resolve 去同一 class。

- **AC-11 [EC / empty-null input]** GIVEN `exercise_id` 為 `""` 或 `&""`（empty StringName），WHEN `get_class_for_exercise`，THEN returns `UNKNOWN(3)` + `push_warning` once，no crash。[qa-lead] Pass 1 — Logic BLOCKING。
- **AC-12 [EC / authored UNKNOWN legal]** GIVEN a test registry entry with `ability_class: UNKNOWN(3)`（作者有意標 UNKNOWN），WHEN lookup，THEN returns `UNKNOWN(3)` with **NO push_error**（intentional，唔係 failure）。[qa-lead] Pass 1 — Logic BLOCKING。
- **AC-13 [EC / 所有 non-spine movement_pattern]** GIVEN `get_class_for_movement_pattern(pattern)` for **each of {CORE(3), CARDIO(4), FLEXIBILITY(5), COMPOUND(6), UNKNOWN_PATTERN(7)}**，THEN all return `UNKNOWN(3)`（pattern_map only 3 spine entries）。**[Pass 2 BLOCKING — qa A4/B4:原 AC-13 只測 CARDIO,漏 COMPOUND 同 sentinel UNKNOWN_PATTERN。COMPOUND→UNKNOWN 係 design intent:compound exercise 必須有 registry entry,caller 要用 `get_class_for_exercise` 而非 pattern API。]**
- **AC-14a [is_known_exercise / known]** GIVEN known `exercise_id`(in registry)，THEN `is_known_exercise(id) == true`。
- **AC-14b [is_known_exercise / unknown]** GIVEN unknown `exercise_id`，THEN `is_known_exercise(id) == false`。
- **AC-14c [is_known_exercise / unnormalized alias]** GIVEN unnormalized alias `"Bench Press"`(alias of `bench_press`)，THEN `is_known_exercise("Bench Press") == true`(共用 `_normalize` + alias resolution path,同 `get_class_for_exercise` 一致)。
- **AC-14d [is_known_exercise / empty]** GIVEN `""` 或 `&""`，THEN `is_known_exercise("") == false`,no crash。
  **[Pass 2 BLOCKING — qa A5:原 AC-14 將 unnormalized alias 同 empty 混入一條,且 empty input 零 coverage;拆成 a/b/c/d 獨立 assert。]**
- **AC-15 [alias collision determinism]** GIVEN two entries where entry B 嘅 normalized alias 撞 entry A 嘅 canonical id(或撞另一 alias)，WHEN boot `_validate_entries()`，THEN `push_error` once naming the collision AND lookup 用 first-listed(canonical/低 index)勝出,collision alias 被 skip;`get_class_for_exercise` 對撞 key 嘅 output deterministic。**[Pass 2 BLOCKING — systems BLK-3:alias collision 違反 pure-function/AC-08 determinism claim。]**

> *Pass 1 full adversarial review 2026-06-02 — `game-designer` / `systems-designer` / `qa-lead` / `godot-gdscript-specialist` / `creative-director` consulted. 13 BLOCKING resolved inline.*
> *Pass 2 fresh full re-review 2026-06-02 — same 5 agents. 9 BLOCKING + ~12 RECOMMENDED. Core fixes resolved inline:AC-02 `LEGS`→`LEG`、StringName/String cast point(`_normalize`)、`ability_class`/`movement_pattern` sentinel default `-1`、runtime Dictionary vs authoring `.tres` schema、shared `_validate_entries()` factory path、invalid movement_pattern handling(AC-07b)、alias collision policy(AC-15)、Q5 UNKNOWN binding contract、entities.yaml ordinal disambiguation。CD verdict:NEEDS REVISION → fix 完即 APPROVE,no Pass 3。*
>
> **Pass 2 RECOMMENDED disposition（CD:impl-time resolved,唔 block MVP）**:normalize 連字符/non-ASCII 邊界、`pattern_map` 用 `match` statement(避 `const Dictionary` 非真 immutable)、CI taxonomy gate absent-file → silent skip、Web Export `load()` vs `load_threaded`(MVP 3 entries 安全,post-MVP 50+ 再評)、CI mutator ban self-exempt scope、registry path = `res://assets/data/exercise_registry.tres`、`is_known_exercise` 共用 `_normalize` helper(已隱含於 type contract)、compound 反直覺嘅 player-facing 解說 ownership → #12/#26/UX。呢啲喺 `/create-stories` 落 implementation note,唔需 GDD 重設計。

## Open Questions

- **Q1（RESOLVED 2026-06-02）**：autoload，pos 5（GymSys pos 4 → #10 pos 5 → StatSystem shift to 6 → … pos 5-14 all +1）。Static class option dropped。ADR-0008 insertion rule 需 TD sign-off + PR。Owner：technical-director（ADR-0008 amendment）。
- **Q2a（MVP — RESOLVED 2026-06-02）**：MVP 3 canonical entries locked：`bench_press → STRIKE(push)`、`bent_over_row → CONTROL(pull)`、`barbell_squat → MOBILITY(leg)`。這三條 unblock MVP epic 嘅 stories。GymSys id spelling 待 #2 GDD cross-ref 驗證（alias 機制覆蓋差異）。Owner：game-designer（content author）。
- **Q2b（post-MVP）**：完整 GymSys resistance exercise taxonomy 收錄（50+ exercises）。CI coverage gate 對住 taxonomy snapshot 驗。Owner：game-designer（ongoing registry maintenance）。
- **Q3（RESOLVED 2026-06-02 — CD 裁決）**：compound 按 **primary movement pattern** 指派 single class（見 Rule 4 compound principle）：deadlift→CONTROL、clean/snatch→CONTROL、squat→MOBILITY、thruster/push_press→STRIKE。Owner：game-designer（content authoring）。
- **Q4**：unknown-exercise telemetry → #28 registry-update feedback loop。Defer（#28 Not Started）。
- **Q5（Pass 2 升級為 BINDING contract — 仍 OPEN，屬 #10 epic 解鎖 gate）**：UNKNOWN-dominant session 嘅 player-facing display strategy。Pass 2 CD 將呢條由「flag」升為 **binding inter-system contract**（見 Interactions + Dependencies §UNKNOWN contract）:#9 WST **MUST** 唔可靜默 inherit 舊 class,需實作 undefined/uncategorized 顯示。**Resolution path**:#9 WST GDD 需一條 follow-up patch（#9 現 11/12 Complete）。Owner：game-designer + #9 WST GDD patch。**呢條係 #10 epic close gate,但唔 block #10 GDD APPROVE**（屬 cross-system 實作 dependency,非 #10 GDD 內容缺陷）。
