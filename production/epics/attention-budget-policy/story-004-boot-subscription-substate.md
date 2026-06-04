# Story 004: Boot subscription + Substate + derivation independence + CI lint

> **Epic**: Attention Budget & Interaction Policy
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/attention-budget-policy.md`
**Requirement**: `TR-ab-???`（subscription + Substate）
**ADR Governing Implementation**: ADR-0006 Contract 6（primary，`connect_for_initial_state`）+ Contract 4（boot order）
**ADR Decision Summary**: GSM autoload `_ready()` 唔 emit initial `state_changed`（downstream 未 connect → emit lost）；subscriber 用 `connect_for_initial_state(callable)` 攞 initial state，callable 必須 3-arg `(from, to, payload)` 簽名，**唔可 `.bind()`**（會錯位）。Boot order：AttentionBudget pos 11+，after GSM pos 2 + WST pos 5。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: WST **冇** `connect_for_initial_state` helper（GSM 專有）；WST `phase_changed(from, to)` = 2-arg 無 payload，與 Contract 6 3-arg+payload 不相容 → 用 **plain `.connect`**。CI Contract 12 scan `connect_for_initial_state(*.bind(*))` = error。

**Control Manifest Rules (Core layer, v2026-05-29)**:
- Required: GSM `state_changed` subscribe via `connect_for_initial_state`（ADR-0006 C6）
- Forbidden: `await` 喺 state-machine 路徑（ADR-0006 C12）— 本 autoload `_ready` 唔 await

---

## Acceptance Criteria

*From GDD `attention-budget-policy.md`, Rule 9 + Substate:*

- [ ] **AC-12（boot subscription，Integration/static）**：autoload `_ready()` 時 (a) #1 `state_changed` 透過 `connect_for_initial_state` subscribe（assert initial callback fired）；(b) #9 `phase_changed` 透過 plain `.connect` subscribe（WST 冇 helper）。**CI static check**：ban regex `state_changed\s*\.\s*connect\s*\(`（帶括號區分 `.connect_for_initial_state(`；錨定 `state_changed` 唔誤殺 `phase_changed.connect(`）→ 免 file-level 豁免清單。
- [ ] **AC-14（derivation independence）**：`state_changed` / `phase_changed` 從未 deliver（subscription 斷開）AND mock live 值 == `SET_ACTIVE`，query `is_input_permitted()` → `false`（證明 derivation 獨立於 subscription）。
- [ ] **AC-16（Substate boot fail-closed）**：autoload 未 READY（GSM == `BOOTING`），query `is_input_permitted()` → `false`。
- [ ] Substate enum `{INITIALISING, READY}`，**無 SUSPENDED substate**（#33 唔 cache）。subscription 用途 = 驅動 notification-suppression 邊界偵測，**唔影響** pure-pull derivation。

---

## Implementation Notes

*Derived from ADR-0006 Contract 6 + GDD Rule 9 + Substate:*

- `_ready()`：`GameStateMachine.connect_for_initial_state(_on_state_changed)` —— callable 3-arg `(from: String, to: String, payload)`，**無 `.bind()`**。`WorkoutStateTracker.phase_changed.connect(_on_phase_changed)` —— 2-arg `(from, to)` plain。
- Substate `INITIALISING → READY`：subscribe 完 + seed notification edge tracking → READY。**冇 SUSPENDED**。
- **關鍵**：subscription 只 drive notification-suppression edge（Rule 7 DROP 決定）；`is_input_permitted()` derivation **唔依賴** subscription 有冇 fire（Rule 2 pure-pull）。AC-14 正係驗呢點。
- AC-12 CI static check：寫 `tools/ci/check_attention_subscription.gd`（或入現有 lint），grep pattern `state_changed\s*\.\s*connect\s*\(` ban。fixtures violation/clean。
- boot order pos 11+ 絕對 integer 跟 ADR-0008 insertion rule + project.godot ground-truth 派（#4 Audio pos 16 先例）；本 story register autoload + 驗 size/位置 boot test。

---

## Out of Scope

- **Story 002 / 003**：derivation / notification predicate 邏輯本體。
- **Story 006**：suspend/resume recovery（本 story 只驗 boot-time subscription + substate）。
- ADR-0008 absolute integer 爭議 — impl-time 派，唔喺本 story 重開 ADR。

---

## QA Test Cases

*GDD-derived。mock GSM with state_changed signal + connect_for_initial_state；mock WST with phase_changed。*

- **AC-12(a)**: Given autoload _ready + mock GSM; When boot; Then `connect_for_initial_state` 被調用 + initial callback fired（assert handler 收到 initial state）。Edge: callable 無 `.bind()`（Contract 6 CI rule）。
- **AC-12(b)**: Given mock WST; When boot; Then `phase_changed.connect` plain 被調用（WST 無 connect_for_initial_state）。
- **AC-12 CI lint**: Given fixture file 用 `state_changed.connect(`; When grep `state_changed\s*\.\s*connect\s*\(`; Then match（violation）。Given fixture 用 `state_changed` + `connect_for_initial_state(` 同 `phase_changed.connect(`; Then 無 match（clean）。
- **AC-14**: Given subscription 永不 deliver（mock 唔 emit）+ mock live get_current_phase()==SET_ACTIVE; When query is_input_permitted; Then `false`（derivation 獨立）。
- **AC-16**: Given GSM==BOOTING（autoload INITIALISING）; When query is_input_permitted; Then `false`（fail-closed safe）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/attention-budget/test_boot_subscription.gd` — must exist and pass（+ `tools/ci/check_attention_subscription.gd` static check + fixtures）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（seam）DONE；Story 002（derivation，AC-14/16 需 is_input_permitted 真實作）建議 DONE
- Unlocks: None
