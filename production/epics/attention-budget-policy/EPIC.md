# Epic: Attention Budget & Interaction Policy

> **Layer**: Core
> **GDD**: design/gdd/attention-budget-policy.md ✅ Approved 2026-06-04 (re-review pass 2)
> **Architecture Module**: AttentionBudget (`src/autoload/attention_budget.gd` — pos 11+ per ADR-0008 insertion rule; absolute integer assigned impl-time per #4 Audio precedent)
> **Status**: ✅ IMPLEMENTED — 6/6 stories Complete (CI-green) 2026-06-04
> **Stories**: 6/6 Complete (3 Logic, 3 Integration) — attention-budget 93/93 GUT; final combined gate 258 scripts / 1685 / 0 fail

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | Stub migration — IInputPolicy seam + ctor + factory + constants | Integration | ✅ Complete | ADR-0006 C13/C14 | Rule 1/10, AC-05 (GUT 17/17) |
| 002 | `is_input_permitted()` Hybrid derivation + hot-path perf | Logic | ✅ Complete | ADR-0006 C13 | Formula 1; AC-01a/01b/02/03/04/09/10/19/17a/17b + B1 sentinel (GUT 29/29) |
| 003 | `is_notification_permitted()` + CRITICAL_NOTIFICATION_KINDS | Logic | ✅ Complete | N/A (GDD Rule 7) | Formula 2; AC-07/08/18a + B1 sentinel (GUT 18/18) |
| 004 | Boot subscription + Substate + derivation independence + CI lint | Integration | ✅ Complete | ADR-0006 C6/C4 | Rule 9; AC-12/14/16 + autoload register + CI lint (GUT 78/78 dir) |
| 005 | Glance budget ceiling + Formula 3 | Logic | ✅ Complete | N/A (cross-system const) | Rule 8; AC-13 (GUT 8/8) |
| 006 | Phone-lock / app-switch recovery | Integration | ✅ Complete | ADR-0006 C13/C4 | EC-6/7; AC-11 (zero prod code — Rule 2; GUT 7/7) |

**Deferred（唔開 story，已記下）**: AC-06（unlock exemption Integration）→ #20 epic；AC-15 full Integration + AC-18b（producer-compliance grep）→ #8 Streak / #28 Telemetry producer epic。

**Implementation order**: 001（seam）→ 002（derivation）→ 003 / 004 / 005（並行 OK）→ 006（recovery，需 002）。

## Overview

AttentionBudget 係 Mirror Hero **Pillar 2（無壓力陪伴 / Frictionless Companion）嘅憲法執行層**（CD-SYSTEMS gate 加入，防止 Pillar 2 enforcement 喺 GDD authoring drift 中消失）。佢係一個 autoload service（pos 11+），對外只暴露兩個 read-only pure-pull predicate：`is_input_permitted() -> bool`（透過 ADR-0006 Contract 13 `IInputPolicy` interface，由 input handler constructor-injected；handler 永不直接 reference autoload）+ `is_notification_permitted() -> bool`。職責 = 喺玩家 workout / combat / loot ceremony 期間（**Hybrid 模型**：GSM floor `{WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}` 憲法鎖 + `LOOT_DROP` ceremony lock + WST `SET_ACTIVE` refinement 收緊）保證 game **完全唔會要求、消費或打斷玩家任何注意力**：HUD tap early-return、required modal 唔彈、non-critical notification 全部 DROP。純 pull-based derivation（無 cached gate）→ 架構性滿足 phone-lock / app-switch recovery。系統本身唔擁有任何 UI。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006 Contract 13 (Accepted ✅) | `IInputPolicy extends RefCounted` + `is_input_permitted()` / `is_notification_permitted()`；`AttentionBudgetPolicy` concrete + `MockInputPolicy` for tests；untyped ctor `_init(gsm,wst)` + `create_policy()` factory；enforcement at input-handler boundary | LOW |
| ADR-0006 Contract 4 (Accepted ✅) | Autoload boot order — AttentionBudget pos 11+（after PersistenceLayer pos 1 + GSM pos 2 + WST pos 5）；per-instance sequential boot | LOW |
| ADR-0006 Contract 6 (Accepted ✅) | `connect_for_initial_state(callable)` subscription（GSM `state_changed`；WST `phase_changed` 用 plain `.connect`，WST 冇此 helper） | LOW |
| ADR-0008 (Accepted ✅ 2026-06-01) | Autoload Position Map — reserve pos 11+ for #33；absolute integer 由 insertion rule + project.godot ground-truth impl-time 派（#4 Audio 先例 pos 16） | LOW |

> **Engine Risk: LOW**（純 GDScript boolean predicate logic，無 shader / physics / post-cutoff API；兩個 governing ADR 都 Accepted）。
> **無 blocking ADR gap** — 核心契約 ADR-0006 + autoload position ADR-0008 均 Accepted。Q-OQ1（絕對 autoload integer）= impl-time 派位，非 blocker。

## GDD Requirements

> ⚠️ **無 dedicated `TR-ab-*` registry block** — #33 核心契約 traced via **TR-gsm-023**（IInputPolicy Contract 13，GSM-owned）；其餘 requirements 由 ADR-0006 contracts + GDD 自身 ACs governed（self-contained GDScript logic，非 untraced-to-ADR）。`/architecture-review` Phase 8 或 `/create-stories` 時可 append `TR-ab-*` IDs 補 registry completeness（非 blocker）。

| Requirement cluster | GDD source | Governing |
|---|---|---|
| `is_input_permitted()` Hybrid derivation（GSM floor + LOOT_DROP ceremony + WST refinement + lifecycle） | Rule 3 / 3b / 4 / 5 + Formula 1 | ADR-0006 C13 + GDD AC-01a/01b/02/03/19 |
| Pure pull-based（no cached gate）→ phone-lock recovery | Rule 2 + Formula 1 | ADR-0006 C13 + GDD AC-04/11/16 |
| Injection seam（untyped ctor + factory + IInputPolicy 2-method） | Rule 1 + injection seam spec | ADR-0006 C13 + GDD AC-05 |
| `is_notification_permitted()` + `CRITICAL_NOTIFICATION_KINDS` closed allowlist + CI | Rule 7 + Formula 2 | GDD AC-07/08/18a（AC-18b deferred #8/#28） |
| Unlock gesture exemption（supersedes #20 AC-EC-S5）+ loot modal exempt | Rule 6 + Rule 3b + EC-5/15 | GDD AC-06（#20 scope）/ AC-19 |
| Subscription（GSM `connect_for_initial_state` / WST plain `.connect`）+ derivation independence | Rule 9 + Substate | ADR-0006 C6 + GDD AC-12/14 |
| Glance budget ceiling（cross-system cap 2000ms） | Rule 8 + Formula 3 | GDD AC-13 |
| Perf hot-path（O(1) 無 allocation） | EC-10 | GDD AC-17a（BLOCKING static）/ AC-17b（ADVISORY runtime） |
| Stub migration（rewrite `src/systems/attention_budget_policy.gd`） | Rule 10 | epic 第一個 story（implementation gate） |

## Story-level Gates（traced into stories，唔 block epic 創建）

- **Rule 10 stub migration** — epic 第一個 story **必須** rewrite 現存 stub（static autoload call + `INPUT_BLOCKED_STATES` array → `_init(gsm,wst)` untyped ctor injection + Formula 1 Hybrid derivation）；廢除/更新依賴舊 pure-GSM-state 路徑嘅 tests。未 rewrite 前唔可 mark any story Complete。
- **AC-06**（unlock exemption Integration）→ re-scoped 去 **#20 epic** story（handler 屬 #20 scope）；#33 只 own Rule 6 binding（unlock 永不 gated）。
- **AC-15**（drop-not-queue 完整 Integration）+ **AC-18b**（producer-compliance grep）→ **BLOCKED-deferred to #8 Streak / #28 Telemetry** producer epic（producer 實作後方可開 test）。#33 epic 先實作 `CRITICAL_NOTIFICATION_KINDS` const + `is_critical_notification()`（AC-18a BLOCKING）+ AC-15 unit-scoped（mock producer）。
- **Q-OQ1** autoload absolute position → impl-time 派（ADR-0008 insertion rule）。**Q-OQ4** DISCONNECTED gate → EC-13 spec permitted（#24 domain，非 blocker）。

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All BLOCKING acceptance criteria from `design/gdd/attention-budget-policy.md` are verified（AC-01a/01b/02/03/04/05/07/08/09/10/11/12/13/14/16/17a/18a/19；AC-17b ADVISORY）
- 現存 stub `src/systems/attention_budget_policy.gd` 已 rewrite 成 Hybrid + injection seam（Rule 10）
- Hard contracts verified: `MAX_SET_ACTIVE_INTERACTIONS == 0`（mid-set 0 互動）；LOOT_DROP ceremony lock 對齊 GSM AC-11b；phone-lock recovery（pure-pull 無 stale gate）
- All Logic stories have passing test files in `tests/unit/attention-budget/`；Integration stories in `tests/integration/attention-budget/`
- Deferred gates (AC-06 #20 / AC-15+AC-18b #8/#28) tracked but NOT blocking epic close（story-level external gates，同 #4 Audio EG 先例）

## Next Step

Run `/create-stories attention-budget-policy` to break this epic into implementable stories.
