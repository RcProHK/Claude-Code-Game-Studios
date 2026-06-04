# Attention Budget & Interaction Policy (#33) — Review Log

## Re-review (pass 3) — 2026-06-04 — Verdict: MAJOR REVISION NEEDED → **REVISED inline → APPROVED**

Depth: **full**（4 specialist agents:game-designer + systems-designer + qa-lead + godot-gdscript-specialist + CD senior synthesis）
Prior verdict resolved: **Yes** — pass 2 Hybrid + pass AC-11 fix；本輪揾到 7 新 BLOCKING + 3 recommended
Blocking items: **7（全 resolved inline）** | Recommended: **3（noted/flagged）**

### Root findings(grep-verified,prioritised by CD)
**Tier 1 — day-one implementation-blocking:**
- **B1(systems-designer)**: No enum sentinel → unknown GSM int fails OPEN（直接 Pillar 2 breach）→ **Formula 1 加 null+sentinel guard；KNOWN_GSM_STATES/KNOWN_WST_PHASES 入 Constitutional constants**。
- **B2(systems-designer)**: WORKOUT_COMPLETE 錯放 GSM `current_state` column(gate table L138);`GameState.WORKOUT_COMPLETE` 唔存在 = compile error →**從 GSM column 移除,只保留 WST phase column**。
- **MAJOR-5(godot-gdscript)**: CI ban regex `state_changed.connect(` 自己 match `game_state_machine.gd:272`(GSM 自身 helper 內部用法) → **main RED on commit 1**；GDD 錯稱「唔需要 file-level 豁免清單」→ **加 GSM owner-exempt**（同 PR #12 debug_override 教訓完全一樣）。
- **CRITICAL-4/H3(godot-gdscript + systems-designer)**: `FAIL_CLOSED_ON_NULL_DEP` 列為 Tuning Knob(`var bool`) 可 runtime mutate；`false` 嘅真正後果係 null method call crash，唔係「safe fail-open」→ **移至 Constitutional constants(`const true`)；修正 failure mode 文件**。

**Tier 2 — story-closure blocking:**
- **G1(qa-lead)**: AC-18 未 split 成 18a/18b —— blocking part(CRITICAL_NOTIFICATION_KINDS const + method)可喺「deferred」cover 下被 skip → **split AC-18a(BLOCKING unit) + AC-18b(deferred)**。
- **CRITICAL-3(godot-gdscript)**: 無 AC 驗 3-arg callback arity → wrong arity = deferred off-stack crash → **新 AC-20(arity BLOCKING)**。
- **CRITICAL-1(godot-gdscript)**: `_init` 冇 `has_method` duck-typed guard → 錯誤 ref order 喺 query time crash → **新 AC-21(has_method guard BLOCKING)**。

**Recommended(noted,唔改 #33 scope):**
- AC-01a 加 SET_ACTIVE 閉 double-lock cartesian(qa-lead) → **done**。
- H1 WORKOUT_COMPLETE notification permit = intentional milestone window(systems-designer) → **documented in Formula 2**。
- H2 CEREMONY ⊆ NOTIFICATION invariant note → **added to CEREMONY_LOCKED_STATES constitutional row**。
- game-designer #1 loot ceremony timing concern → **cross-system flag to #21 in Interactions table**。
- game-designer #3 DISCONNECTED inconsistency → **Q-OQ4 updated with flag note**（defer to #24）。

### Lesson recorded
「Approved GDD 喺 /create-stories 後 re-review 仍揾到 7 BLOCKING」=「pass 2 嘅 lean grep-verify 嗰次因為 Bash EEXIST 唔能 spawn full agents,只做 single-session lean → 漏咗 B1/B2/MAJOR-5/CRITICAL-4 呢類需要 grep 多個文件嘅 cross-file findings。」lesson:**full-agent review 係 design review 嘅正確 mode,唔係 polish；lean 係例外(context 唔夠或 agent 環境壞)。CI-self-match 係 gateway-lint 特有嘅 day-one-RED 陷阱,每次新增 CI ban 都要 grep 現有 codebase 先。**

### Decision
User 指示「順住做曬」→ all 7 blocking + 3 recommended resolved inline。Systems-index + review log 更新。Story files(001/003)受影響 AC 變化 — AC-20/AC-21 新增(story-001 先知道 ctor + arity 需求);Story-003 AC-18a/18b split 已反映喺 GDD(story files 可於 /dev-story 時 re-read GDD sync)。GDD status → Approved(pass 3)。

---

## Re-review (pass 2) — 2026-06-04 — Verdict: NEEDS REVISION → REVISED inline → **ACCEPTED / APPROVED**

> **User decision 2026-06-04**: Accept revisions（B-NEW-1 fix 由 locked GSM AC-11b 唯一確定 + grep-verify 對齊所有 consumer，零 design 自由度，低新-矛盾風險）→ #33 標 **Approved**，推進 `/create-epics`。systems-index #33 → ✅ Approved。


Depth: **lean**（single-session，grep-verified against 上游 ground-truth；既揾到決定性 blocker + Bash 環境壞，唔 spawn 5 agent 重複確認）
Prior verdict resolved: **Yes** — 上輪 13 BLOCKING 全部 grep-verify 真‧閉合（Hybrid floor = stub `INPUT_BLOCKED_STATES` ✓；WST `get_current_phase()` L111 / `phase_changed(from,to)` 2-arg L123 ✓；Rule 10 stub 描述準確 ✓）
Blocking items: **1（新揾）** | Recommended: **4**

### Root finding（grep-verified）
> **B-NEW-1 — `LOOT_DROP` input-permission 同 locked GSM AC-11b 直接矛盾。**
> #33 原將 `LOOT_DROP` 設 `is_input_permitted()==true`（default-open）；但 **GSM AC-11b（game-state-machine.md L696，locked + tested `test_rule7_no_mid_set_input.gd`）** 明文：LOOT_DROP 期間（modal 開住未 dismiss）`is_input_permitted()` 返 **`false`**——「modal is the input, not the surroundings」。功能後果：true 會令 #20 AC-CR-5 input gate 喺 loot ceremony 期間放行背景 HUD tap → 偷咗 loot tap，正係 AC-11b 要堵嘅漏洞。上輪 revision 嘅 grep 只盯 AC-15a（WORKOUT_ACTIVE），漏咗 sibling AC-11b。**非 phantom——真上游 contract + 真功能 bug。**

### Fixes applied（B-NEW-1 + R1–R4）
- **B-NEW-1**：`LOOT_DROP` 加入 `is_input_permitted()` lock（Formula 1 加 `CEREMONY_LOCKED_STATES` term）；loot modal dismiss tap 用 Rule 6-style exempt handler（#21 唔注入 gating policy）。連帶改：Rule 3b 新增 · Rule 5 移除 LOOT_DROP · gate table L137 · AC-03 收窄 · 新 **AC-19**（ceremony lock）· 新 **EC-15** · interaction table #21 row · Formula 1 Example D。**唔 patch 上游**（純收緊 #33 自己 derivation 對齊 locked GSM AC-11b）。
- **R1**：清 stale「phase 壓倒」措辭（EC-3 + AC-09 → 「WST refinement 收緊」；AC-09 標明 = AC-01b `IDLE` instance）。
- **R2**：data-driven lock-set 常數 `GSM_FLOOR_LOCKED_STATES` / `CEREMONY_LOCKED_STATES` / `LIFECYCLE_LOCKED_STATES`（Formula 1 全用 named set，唔字面 hardcode；對齊 coding standard + stub `INPUT_BLOCKED_STATES`）。
- **R3**：AC-17 拆 **AC-17a 結構性 BLOCKING**（code-inspection：method body 無 allocating 構造）+ **AC-17b runtime ADVISORY**（headless monitor diff 噪音，唔可作 deterministic gate；避免不可達 binding gate）。
- **R4**：AC-12 grep pattern 精確化 `state_changed\s*\.\s*connect\s*\(`（帶括號區分 `.connect_for_initial_state(`；錨定 `state_changed` 唔誤殺 `phase_changed.connect(`）→ 免 file-level 豁免清單，消除 over-broad lint 風險（main-RED 前科）。

### Residual nit（未 fix，留下輪 / impl-time）
- gate table L138 左欄將 `WORKOUT_COMPLETE` 列作 GSM `current_state`，但佢實係 #9 WorkoutPhase（GSM 無此 state）。display-row 混淆，非 blocking（AC-03 GSM set 已乾淨）。

### Next
本輪 fix 由 locked 上游唯一確定（零 design 自由度）+ grep-verify 對齊所有 consumer（GSM AC-11b / #20 AC-CR-5 / #21 modal / stub Rule 10）→ 低新-矛盾風險。可選：(a) fresh-session 5-agent re-review 保守確認；(b) accept + `/create-epics`。

---

## Revision Pass — 2026-06-04 — Status: REVISED / PENDING FRESH-SESSION RE-REVIEW

Scope signal: **XL**
Action: Inline revision after /design-review [A] Revise now (fresh-session)
Prior verdict resolved: Yes — all 13 BLOCKING from 2026-06-04 first review addressed
Blocking items resolved: **13/13** | Recommended actioned: top 8/23 (remainder deferred to re-review)

### Changes Made

**Permission model (B-A1/A2):** Rule 3 全面重寫 → Hybrid model (`is_input_permitted() = GSM_floor AND WST_refinement`)；GSM floor `{WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}` = 憲法強制鎖；WST `SET_ACTIVE` = refinement（只可收緊）；廢棄「phase 壓倒 state」舊語意；derived gate table 更新；Formula 1 重寫（null guard 入 named expression 最高優先 + Hybrid derivation）；AC-01 split AC-01a (GSM floor) + AC-01b (WST refinement)；AC-03 移除 floor states 出 default-open list。

**Injection seam (B-B1/B2/B-B3):** Rule 1 加 seam spec（untyped ctor `_init(gsm_ref,wst_ref)` + factory `create_policy()`）；Formula 1 null guard 提升入 named expression；IInputPolicy interface 明文含 `is_notification_permitted()`；MockInputPolicy 兩 stub 獨立。

**Notification enforcement (B-C1/C2):** Rule 7 加 `CRITICAL_NOTIFICATION_KINDS` closed allowlist + `is_critical_notification()` method + CI static check；AC-18 新增（producer-compliance BLOCKING）；Tuning Knobs 加 `CRITICAL_NOTIFICATION_KINDS` 常數。

**Contract physics (B-D1):** Rule 9 修正 `phase_changed` = plain `.connect`（WST 冇 helper）；AC-12 CI scope 收窄 + 豁免清單（防 over-broad lint）；Substate 表 subscription 描述修正。

**AC suite (B-E1/E2/E3):** AC-06 re-scope to #20 Integration；AC-15 降 ADVISORY / BLOCKED-deferred；EC-4 + Rule 9 標 `input_policy_changed` cut from v1。

**Escalation resolved:** AC-17 升 BLOCKING（O(1) 無 allocation，可量度化 spec）。

**Migration gate (B-A3):** 新增 Rule 10 — 現存 stub rewrite gate（唔可 story Complete 前未 rewrite）。

**Auto-picked decisions:** B-C2 is_notification_permitted in IInputPolicy ✓；B-E3 cut v1 ✓；AC-17→BLOCKING ✓

### Next
`/clear` → fresh-session `/design-review design/gdd/attention-budget-policy.md` (5 specialists + CD synthesis re-verify Hybrid model)

---

## Review — 2026-06-04 — Verdict: MAJOR REVISION NEEDED

Scope signal: **L → XL**
Specialists: game-designer · systems-designer · qa-lead · godot-gdscript-specialist · creative-director (senior synthesis)
Blocking items: **13** | Recommended: **23** | Prior verdict resolved: First review

### Completeness: 8/8 sections present ✅

### Root Cause (一個，唔係十三個)
> **#33 GDD 將 permission 模型由「GSM-state-driven」靜靜地重寫成「WST-phase-driven」，但冇 reconcile 上游 GSM AC-15a、冇 flag 現存 stub migration、冇開 ADR。**

13 BLOCKING 入面 6 個係呢同一個未決架構問題嘅不同切面。Main reviewer grep-verified 三個互相佐證嘅事實：
1. GSM GDD line 707 **AC-15a**（標 Pillar 2）：`WORKOUT_ACTIVE` → `is_input_permitted()` 返 `false`；GSM line 210 標 WorkoutActive = 「Attention Budget (no-input mode)」。
2. #33 GDD Rule 5 + AC-03：`WORKOUT_ACTIVE` = default-open `true`。← 直接矛盾。
3. 現存 stub `src/systems/attention_budget_policy.gd`（Story 015, #20 epic）：`INPUT_BLOCKED_STATES = [WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER]`，純 GSM-state-driven + static autoload call（無 injection seam）。
4. #9 WST `phase_changed(from_phase, to_phase)` = 2-arg 無 payload；WST **冇** `connect_for_initial_state`（GSM 專有 helper）。
5. #9 WST `SET_ACTIVE` 語意 = 「last event was set_logged, before rest_started」≠「玩家正在用力嗰刻」。

### CD 中央裁決 — Hybrid permission 模型
```
is_input_permitted() = GSM_floor AND WST_refinement
```
- **GSM floor** `{WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER}` 強制鎖，**phase 永遠 override 唔到**（Pillar 2 憲法；對齊 GSM AC-15a + 現存 stub）
- **WST phase** 只可由 open→closed **收緊**，唔可放鬆（保留作者 phase-driven instinct 做 refinement layer）
- 「SET_ACTIVE 做唯一 cardinal lock」被推翻（grep-verified 語意證據：SET_ACTIVE ≠ 用力中）

### 13 BLOCKING（收斂落 3 條 root/fault line）

**Group A — Permission 模型重新架構未閉合（→ Hybrid）**
- B-A1 [game-designer B1 + qa BLOCKING-2]：WORKOUT_ACTIVE 與 GSM AC-15a + 現存 stub 矛盾 → 採 Hybrid，重寫 Rule 3/5 + derived gate table + Formula 1
- B-A2 [game-designer B2]：SET_ACTIVE 語意 ≠ 用力中（over-lock + under-lock）→ Hybrid GSM floor 兜底 under-lock，reconcile fantasy↔phase timing
- B-A3 [qa BLOCKING-2]：加 migration note — 第一個 story rewrite 現存 stub + 廢除/更新舊 INPUT_BLOCKED_STATES test

**Group B — Injection seam 缺失（半數 AC unsatisfiable）**
- B-B1 [qa BLOCKING-1 + godot B-3]：現存 stub 用 static autoload call 冇 injection seam → AC-01/02/03/04/09/10/14/16 set 唔到 GIVEN。Spec `AttentionBudgetPolicy._init(gsm, wst)` **untyped** ctor injection（cite reference_gdscript_di_seam — typed Node compile-fail）
- B-B2 [godot B-2]：Injection point ownership 未定義 → 建議 `AttentionBudget.create_policy() -> IInputPolicy` factory
- B-B3 [systems-designer B2]：fail-closed null-dep 唔喺 Formula 1 named expression → implementer 會寫成 **fail-OPEN**（`null == SET_ACTIVE`=false → `NOT(false)=true`）。null guard 提升入 named expression 最高 precedence + 入 variable table

**Group C — Notification 通道完全冇 enforcement（Pillar 2 正交盲點）**
- B-C1 [systems-designer B1 + qa BLOCKING-5]：`is_notification_permitted()` 純 producer 自律無 seam + critical 冇 closed allowlist（The Nag Engine leak 口）→ `CRITICAL_NOTIFICATION_KINDS` closed allowlist + CI static check + producer-compliance AC
- B-C2 [godot B-2]：`is_notification_permitted()` 唔喺 IInputPolicy interface → 決定 interface placement

**Group D — Contract physics 行唔通**
- B-D1 [godot B-1]：Rule 9 + AC-12 對 #9 phase_changed 用 connect_for_initial_state **物理上行唔通**（WST 冇此 helper，2-arg vs 3-arg+payload 不相容；AC-12 CI ban 自相矛盾）→ **採 Option A**：phase_changed 用 plain `.connect`，state_changed 用 connect_for_initial_state，AC-12 CI scope 縮到只 state_changed

**Group E — AC suite 缺口**
- B-E1 [qa BLOCKING-3]：AC-06 unlock exemption #33 內部 unit-test 唔到（缺席狀態）→ re-scope 去 #20
- B-E2 [qa BLOCKING-4]：AC-15 drop-not-queue phantom integration（冇 producer）→ 降 unit test 或 BLOCKED-deferred
- B-E3 [qa BLOCKING-6]：input_policy_changed EC-4 double-emit 零 AC + idempotency 無 gate → cut from v1 或補 AC + downstream idempotency

### Recommended Revisions（23 條，重點）
- [game-designer R1 + systems R3 + qa REC-3] Glance 2000ms 太鬆（vs 0.3s）；Formula 3 = measurement stub，AC-13 = tautology → 拆 AC-13a unit / AC-13b playtest，定 measurement protocol
- [systems R6 + qa REC-1] AC-17 hot-path 升 BLOCKING + 可量度化 — **escalate creative-director / 你拍板**
- [systems R5] Rule 2 pure-pull 加 CI static check（禁 member write / _cached_*）
- [systems R1 + qa REC-8] REST_PERIOD GSM/WST 同名碰撞 → fully-qualified；AC-03 28-combo cartesian enumerate
- [game-designer R2] Notification DROP lose reward-class → binding constraint「reward-class producer own WORKOUT_COMPLETE re-fire」
- [game-designer R3 + qa REC-5] DISCONNECTED default-open 不一致 → 考慮 gated + Rule 6 exemption；EC-7/11/12/14 缺 AC（EC-12 critical-bypass = data-loss risk 須補）
- [godot R-6] GDD 全篇 `.current_state` property syntax 錯（只有 get_current_state()）→ 全文修正
- [qa REC-2] AC-12 CI check pin exact grep pattern + 豁免清單（防 over-broad lint 重演 main-RED 事故）
- [godot R-5] assert_glance 用 OS.is_debug_build() + push_error，唔好用 assert()
- [systems R7] Q-OQ1 ADR-0008 boot-order 升 explicit blocking dep 或加 boot-order-independent AC — **escalate technical-director**
- [qa REC-7/9] AC-02/AC-16 重疊；blanket「全部可獨立驗證」前言 false 須刪

### Specialist Disagreement（CD 已裁決）
- **game-designer**：應全盤推翻 phase-driven 回 GSM-state model（under-protect fantasy）
- **作者（GDD）**：刻意揀 phase-driven 做更細粒度保護
- **CD 裁決 Hybrid**：兩邊各啱一半啱喺唔同層 — GSM floor 憲法強制鎖 + WST refinement 只可收緊；SET_ACTIVE 唯一 cardinal lock 被推翻

### Senior Verdict [creative-director]
設計理念 sound（pure-pull constitutional-NO + closed API + 基建 IInputPolicy/MockInputPolicy 已 ship CI-green），但 root cause = 偷偷重寫 permission 模型而冇 reconcile 上游。三條 root/fault line 必須 implement 前閉合：(1) Permission 模型 → Hybrid + injection seam；(2) Notification enforcement → closed allowlist + 真 gate + producer compliance；(3) Contract physics → phase_changed plain .connect / fail-closed 入 named formula / IInputPolicy 補齊。Pillar 2 致命盲點 = notification 通道無 enforcement seam（同 input 通道正交，要獨立堵）。

### Escalations
- AC-17 升 BLOCKING？→ creative-director / user
- ADR-0008 boot-order ratification timing → technical-director

### Next
`/clear` → fresh-session `/design-review design/gdd/attention-budget-policy.md` 接住改（user 選擇停手留新 session）。
