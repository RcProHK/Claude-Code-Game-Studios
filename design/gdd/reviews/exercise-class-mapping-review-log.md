# Exercise → Class Mapping (#10) — Review Log

## Review — 2026-06-02 — Verdict: MAJOR REVISION NEEDED (revised same-session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (synthesis)
Blocking items: 13 | Recommended: 9
Prior verdict resolved: First full review (prior was lean author pass, no specialists)

### Summary (creative-director synthesis)
14 BLOCKING findings collapse into three root causes: (1) `AbilityClass` is an inner enum of `AbilitySystem` autoload — `-> AbilityClass` return type fails to compile in any other GDScript file; all existing consumers use `int`; (2) Formula 1 step 2 (pattern_map fallback) is dead code — `movement_pattern` is a registry entry field, so if exercise not in registry, movement_pattern is unknowable via `get_class_for_exercise`; (3) registry coverage floor has no guardian — UNKNOWN-heavy sessions betray Pillar 4 "honest mirror" promise without any CI enforcement, owner, or SLA. Architecture vision (invisible truth-teller, pure categorical lookup, no fabrication) is sound. All 13 BLOCKING resolved inline in single session.

### Blocking items (13) — all resolved inline
1. [godot-gdscript-specialist] `AbilityClass` inner enum → `-> AbilityClass` uncompilable → Rule 1/2: changed to `-> int` (WST precedent) + boot validation loop to prevent ordinal-0 silent STRIKE
2. [systems-designer] Formula 1 step 2 dead code → Formula 1a/1b rewritten as two independent pure functions
3. [systems-designer] pattern_map `CORE/CARDIO/FLEX/COMPOUND→authored` inconsistency → pattern_map fixed to exactly {PUSH→STRIKE, PULL→CONTROL, LEG→MOBILITY}
4. [systems-designer] `MovementPattern` enum undefined + `LEGS` vs `LEG` conflict → Rule 4b: 7-member MovementPattern enum defined, `LEG` singular throughout
5. [systems-designer] `ability_class` null → ordinal-0 → silent STRIKE fabrication → Rule 3: boot validation loop + AC-07 rewritten
6. [godot-gdscript-specialist] `ExerciseRegistry.tres` schema unspecified → Rule 3: ExerciseEntry/ExerciseRegistry schema specced + GUT-safe factory function loading strategy
7. [qa-lead] Q1 unresolved → all ACs have no test runner → Q1 RESOLVED: autoload pos 5 (after GymSys pos 4, before StatSystem); static option dropped
8. [qa-lead] AC-01 depends on unverified production fixture → rewritten against test-owned synthetic fixture
9. [qa-lead] AC-07 no boot validation loop → rewritten with boot loop spec
10. [qa-lead] 5 authored edge cases no ACs → AC-11 (null input), AC-12 (authored UNKNOWN legal), AC-13 (unknown pattern)
11. [qa-lead] is_known_exercise() no AC → AC-14 added (coverage + alias consistency)
12. [game-designer] Registry coverage no SLA/owner → Dependencies: Coverage Invariant + CI build-time gate + game-designer as registry owner
13. [game-designer] Q2 not split; Q3 no principle → Q2 split (Q2a MVP 3 entries LOCKED; Q2b post-MVP); Q3 compound principle CD ruling: assign by primary movement pattern (deadlift→CONTROL)

### Recommended items (9)
1. Alias collision/circular alias boot validation; 2. normalize edge cases (digits, unicode); 3. AC-04 mismatched fixture explicit; 4. AC-08 determinism strengthened; 5. UNKNOWN player-facing owner flag to #9 (Q5 added); 6. mis-map no-recourse = anti-gaming design document explicitly; 7. sticky-last-leader × UNKNOWN fantasy gap flagged to #9; 8. AbilityClass int pure/immutable claim reframe; 9. boot-race fantasy consequence of Q1 (now moot — Q1 resolved)

### ADR-0008 pending
ADR-0008 needs insertion rule for #10 at pos 5 (renumber pos 5-14 all +1). Needs technical-director sign-off.

### Next
Awaiting Pass 2 fresh-session full re-review. Pre-condition: ADR-0008 insertion rule TD sign-off.

---

## Review — 2026-06-02 (Pass 2, fresh-session full re-review) — Verdict: NEEDS REVISION → **APPROVED** (9 BLOCKING resolved inline, no Pass 3)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (synthesis)
Blocking items: 9 | Recommended: ~12
Prior verdict resolved: Pass 1 (13 BLOCKING) — confirmed held except 1 residual typo (AC-02 `LEGS`); ADR-0008 insertion rule + binding constraint 7 TD sign-off done 2026-06-02 (pre-condition satisfied)

### Summary (creative-director synthesis)
架構 vision（pure categorical lookup / no fabrication / honest truth-teller）完全 sound，Pass 2 冇一條係設計方向錯。但 **9 BLOCKING 入面 6 條係 Pass 1 inline-fix 自己引入嘅 regression**（int→ordinal-0 / String+StringName→dict-key miss / typo 漏改 / factory seam 含糊）— root cause 係 Pass 1 inline resolution 太快、新 spec 細節冇第二眼 cross-check，同 Audio GDD 一模一樣嘅 churn pattern。核心 5 條（typo / StringName cast / sentinel default / alias policy / Q5 binding contract）唔係 review bar 過嚴 — 每條都係「寫完 test 即 compile fail 或 runtime silent-wrong」。CD 裁：呢 5 條係純文字 fix，fix 完即 APPROVE，**唔需要 Pass 3 full specialist round**。

### Blocking items (9) — all resolved inline (autonomous mode, CD-supplied resolutions)
1. [全 4 specialist] AC-02 `LEGS` typo（enum 係 `LEG`，照寫 compile error）→ AC-02 改 `LEG` + ordinal
2. [systems BLK-4 + godot F4] StringName vs String dict-key silent miss → `_normalize(raw)->String`（第一行 `String(raw)` cast）+ 內部 lookup dict 一律 String key / int value（Rule 2 新 note）
3. [godot F1/F8] ordinal-0 fabrication 繞過 boot loop（ADR-0007 zero-default）→ `ability_class`/`movement_pattern` field default `-1` sentinel + boot 驗 `!=-1 AND ∈range`（Rule 3 + AC-07）
4. [systems BLK-3] alias collision（alias-vs-canonical / alias-vs-alias）→ push_error + first-listed wins + skip（Edge Cases + Rule 3 + AC-15）；severity 分歧（systems BLOCKING / qa REC / game NICE）CD 裁 BLOCKING（破壞 pure-function/AC-08 determinism）
5. [game BLOCKING-1, CD Pillar-level] Q5 UNKNOWN × #9 sticky-last-leader 仍係 flag → 升 BINDING inter-system contract（Interactions + Dependencies §UNKNOWN + Q5）；列 #10 epic close gate（#9 WST patch）
6. [systems BLK-2 + qa B5] invalid movement_pattern boot 處理未定義 + 零 AC → force UNKNOWN_PATTERN(7)，entry 唔 discard（ability_class 照 serve），AC-07b
7. [godot F2 + qa A1] factory ExerciseEntry vs Dictionary 矛盾 → `.tres` = authoring schema；runtime flatten 成 2×Dictionary；factory 收 `Array[Dictionary]` 經同一 `_validate_entries()`（零 class_name cache 依賴）（Rule 3 新 note）
8. [qa A1/A4/A5/B8] AC testability gaps → AC-06 `_load_registry()` injectable seam；AC-07 shared `_validate_entries()`；AC-13 全 non-spine ordinal {CORE/CARDIO/FLEX/COMPOUND/UNKNOWN_PATTERN}；AC-14 拆 a/b/c/d（known/unknown/unnormalized-alias/empty）
9. [systems BLK-5] entities.yaml `class_id enum{PUSH,PULL,LEG}` ordinal collision（同 AbilityClass 0-2 撞）→ GDD 記三組平行 1:1:1 enum 共用 ordinal by-design + 唔 conflate type；entities.yaml line 376 補 disambiguation 註解（**唔 rename，保 merged #11**）

### Recommended items (~12) — deferred to /create-stories impl-notes (CD: impl-time resolved, 唔 block MVP)
normalize 連字符/non-ASCII 邊界；`pattern_map` 用 `match` statement（避 const Dictionary 非真 immutable）；CI taxonomy gate absent-file → silent skip + schema spec；Web Export `load()` vs `load_threaded`（MVP 3 entries 安全，post-MVP 50+ 再評）；CI mutator ban self-exempt scope；registry path = `res://assets/data/exercise_registry.tres`；`is_known_exercise` 共用 `_normalize`（已隱含 type contract）；compound 反直覺 player-facing 解說 ownership → #12/#26/UX；AC-04 explicit conflict fixture（已改）；AC-05b normalize order（已加）；AC-11 null variant。

### Meta — churn pattern flagged (CD)
#10 同 Audio Manager 都係 lean GDD 走「Pass 1 MAJOR → inline fix → Pass 2 又掘新 BLOCKING」嘅路。共同 root cause：inline resolution 太快、新 spec 冇 cross-check，4 個 specialist 平行睇唔同角度，一個 fix 悄悄引入另一個 specialist 嘅問題。CD codify：呢類 lean data-layer GDD Pass 2 fix 後應為 LAST pass，CD-audit 收尾，唔需無限 re-review。

### Cross-system gates (tracked, not GDD defects — 唔 block APPROVE)
- Q5: #9 WorkoutStateTracker follow-up patch（UNKNOWN-dominant display policy）— #10 epic close gate，owner game-designer + #9 GDD
- entities.yaml: 補登記完整 7-member MovementPattern enum（disambiguation 註解已補）— owner systems-designer

### Next
APPROVED. #10 GDD 完成。可進 /create-epics（#10 epic governing ADR-0007/0008/0003）。Epic close 前需滿足上述 2 個 cross-system gate。
