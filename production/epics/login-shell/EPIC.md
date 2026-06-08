# Epic: Login / GymSys Connection UI(Shell)(#24)

> **Layer**: Presentation(第五個 Presentation epic — 帳號連接 + 系統誠實層 shell;#20 HUD / #21 Loot Modal / #22 Character / #23 Inventory 之後)
> **GDD**: design/gdd/login-gymsys-connection-ui.md(✅ REVISED + cold-verify 2026-06-08 — fresh /design-review NEEDS REVISION → 6 BLOCKING inline 收 → 5 MINOR cold-verify cleared;15 Rules / 5-state FSM / 2 formula / 26 EC / 56 AC / G-LS-1..9)
> **UX Spec**: design/ux/login-gymsys-connection-ui.md(✅ APPROVED 2026-06-08 — /ux-review 0 BLOCKING / 4 ADVISORY inline 收;stories 引用 UX spec for layout/pixel/glance,引用 GDD for FSM/severity/formula)
> **Architecture Module**: `LoginShellCoordinator` autoload @ `src/autoload/login_shell_coordinator.gd`(thin Node;持有兩個 CanvasLayer:`LoginShellLayer`(layer **62**,PAUSABLE,capture enumeration → 0/10/50/60/61/62)+ `ErrorBannerLayer`(layer **111**,ALWAYS,>100 shake/saturation-immune / <120 below #21 loot modal);pre-warm `visible=false` — #21/#22/#23 先例)。**唔開第二 autoload**,但拆 `src/ui/login_shell/` helper file(established pattern;**`banner_stack.gd` + `shell_transitions.gd` 必須獨立 file** — AC-35a grep target 前提)。Autoload 位置:tail append 喺 `InventoryUICoordinator` 後(G-LS-2 ADR-0008 amendment;#28 keep last;**零 #21/#22/#23 constraint**)
> **Status**: Ready — **19/19 stories written**(2026-06-08),未 implement。NEXT `/story-readiness production/epics/login-shell/story-001-ios-safari-spike.md` → `/dev-story`
> **Stories**: 見下表(baseline 16–20;現 19 ✓;story 001 = G-LS-6 iOS spike;各 story 嵌 GDD AC + ADR guidance + QA Test Cases GWT)

## Overview

實作 Mirror Hero 嘅 **Pillar 1 anti-lie 收口 + Pillar 2 守護者** shell ——「肯認衰嘅守門人」。四個職責:(1) **Login screen**:#2 `auth_required()` / boot pull-check `is_auth_required()` → 全屏 form,`claim_session` 4-code error map(永不 leak raw HTTP);(2) **Connection status surface**:GSM `DISCONNECTED` reconnect affordance(#33 EC-13 carve-out);(3) **Error banner 系統**:#3/#8/#11/#12 四個 upstream error signal 嘅**唯一 UI consumer**(zero-silent-swallow — 每條 error edge 必 terminate 喺 visible surface);(4) **IDLE shell**:#22/#23 入口 affordance host + 中央 `request_open` 互斥 arbiter + logout 非阻塞 drain。

5-state shell FSM(HIDDEN/LOGIN/SHELL_IDLE/DISCONNECTED_SHELL/DRAINING — **唔係** GSM state,observe GSM + #2 signal 自己分流);banner stack 係 orthogonal overlay(任何 state 可疊現,severity 機制獨立)。**#24 零 persist**(token 由 #2 寫)/ 零 gameplay 數值 / typed credentials 只存提交瞬間內存。**全域只訂 4 signal**(`auth_required`/`drain_started`/`drain_completed`/`state_changed`),**11 個 forbidden signal**(10 TELEMETRY + 1 TEST-SEAM)永不訂(G-LS-9 lint)。Signal-only model 對 tail autoload 必有 **boot-window race** → 對最關鍵 signal 行 **pull-check**(致命 auth_required boot-race 收口 G-LS-4(c))。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0001**: Web Export Budget Caps | CanvasLayer topology;**G-LS-1 amendment 對象**:`LoginShellLayer` 62 PAUSABLE 註冊 + capture enumeration +62 / `ErrorBannerLayer` 111 ALWAYS / **banner 禁第二 BackBufferCopy**(#21 blur-CUT 同源);UI Presentation HIGH domain;particle=0 | **HIGH**(Compatibility/WebGL2)|
| **ADR-0008**: Autoload Position Map | **G-LS-2 insertion amendment 待做**(本 epic story)— `LoginShellCoordinator` tail append 喺 InventoryUICoordinator 後,#28 keep last;零 #21/#22/#23 constraint | LOW |
| **ADR-0002**: GymSys Integration Protocol | `POST /session/claim` + `X-Session-Token`;cursor-replay = 斷線「會補返」copy 誠實依據;**G-LS-3/4 errata 對象**(claim async 簽名 + cancellation + 3 additive API) | MEDIUM(VS-tier validation gated)|
| **ADR-0004**: CORS / Cross-Origin Auth Topology | same-origin nginx(`/mirror-hero/` 靜態 + `/api/game/` proxy)→ login **零 CORS UX** | MEDIUM(deploy validation gated)|
| **ADR-0006**: State Machine Contract | C6 `connect_for_initial_state`(GSM state_changed boot 即收 current — AC-27);C4 autoload sequential boot | LOW |
| **ADR-0003**: Save State Strategy | Private Mode `QUOTA_EXHAUSTED` detect-and-gate(banner + loot disable,同一條 banner — Q-E1 閉環);**#24 自己零 persist key** | LOW |
| **ADR-0009**: Signal Payload Schema | subscription payload minimal+intrinsic;GSM payload null late-bind(shell 只讀 from/to state) | LOW |

## GDD Requirements

> #24 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#18/#21/#22 先例一致)。Requirements 由 GDD 直接 trace:**15 Core Rules + 5-state FSM + 2 active Formula(F1 rate-limit countdown[integer-ms + m:ss]/ F2 banner auto-expire[strict-< boundary])+ 26 ECs + 56 ACs**,全部有 Accepted ADR cover(上表)+ **9 個 cross-system gate G-LS-1..9**。UX 層另加 **11 AC-UX**(layout/pixel/glance — AC-UX-1..11)。

**Untraced requirements**: None(G-LS gates 係 cross-system errata/amendment,非 untraced ADR-gap;TR-ID granularity 留 /architecture-review batch)。

**AC 分佈(GDD 56)**:**39 BLOCKING**(11 Logic:rate-limit×3 / banner-expire×3 / invariants×2 / severity-map×3 + 25 Integration + 3 Static-CI [AC-35a/50/51])+ **10 GATED**(G-LS-3 ← AC-06/07/08/22 claim delivery;G-LS-4 ← AC-04/05/37b/53 additive API;G-LS-8 ← AC-28;G-LS-9 ← AC-25 lint)+ **6 ADVISORY**(manual 43/44/45/46/48/49)+ **1 EXTERNAL**(AC-47 iOS real-device — G-LS-6 連動)。**+ UX 11 AC-UX**(2 ADVISORY-visual / 9 BLOCKING-measure,其中 AC-UX-4 GATED-OQ-UX2)。

## Stories

| # | Story | Type | Status | Gate / ADR |
|---|-------|------|--------|-----|
| 001 | **G-LS-6 iOS Safari spike**(virtual_keyboard / canvas resize / IME / **canvas auto-zoom 真實行為** / **4.6 dual-focus 兩 input path**)— 結果決定 LineEdit vs DOM overlay 路線 | Integration(spike) | Ready | **G-LS-6 HIGH** — EXTERNAL real-device(AC-47)|
| 002 | **G-LS-1 ADR-0001 + G-LS-2 ADR-0008 amendment**(layer 62/111 + capture enum + banner no-2nd-BBCopy + tail insertion)— **scaffold 前提** | Config/Data(doc+config) | Ready | ADR-0001+0008 |
| 003 | Coordinator scaffold + 兩 CanvasLayer + `project.godot` tail 登記 + **file split**(`banner_stack.gd` + `shell_transitions.gd`)+ cfis GSM connect(AC-01/02/27)| Integration | Ready | ADR-0008+0001+0006 C6 |
| 004 | Shell 5-state FSM + cross-fade(`SHELL_FADE_SEC`)+ LOGIN 最高優先 interrupt + mid-workout banner-defer(AC-03/24/38;EC-E1/C3/C4)| Integration | Ready | ADR-0006 |
| 005 | **Boot-window pull-check sweep**:`is_auth_required()`(G-LS-4(c) 致命)+ `get_pending_errors()`(G-LS-8)+ sweep 表 contract assert(AC-53/28;EC-E5/B1/B3/E6)| Integration | Ready | **G-LS-4(c) + G-LS-8 GATED** |
| 006 | Formula 1 rate-limit countdown(injected clock,integer-ms,m:ss,N=0 re-enable;AC-16/17/18)| Logic | Ready | N/A(pure formula)|
| 007 | Formula 2 banner auto-expire(strict-< boundary AC-19/19b/20)+ `_validate_knobs()` pass+fail 兩路(AC-21a/b)| Logic | Ready | N/A(pure formula)|
| 008 | **Claim flow**(submit→disable+loading→4-code error map,零 raw HTTP deny-list;AC-06/07/08/09/10/11/12/22/23)| Integration | Ready | **G-LS-3 GATED**(claim delivery + cancellation pin)|
| 009 | LOGIN sub-variant dispatch(`get_auth_block_reason()` → normal/update-required/misconfig;AC-04/05)| Integration | Ready | **G-LS-4 GATED** |
| 010 | **Banner 系統 core**:BannerStack + `error_severity_map.tres`(12+3 mapping)+ source-first dispatch + **UNMAPPED default-deny** + **total-order comparator**(arrival_sequence,StringName→String)(AC-26/29/29b/30/31/32/52)| Integration | Ready | ADR-0003 + ADR-0009 |
| 011 | Banner stacking + dedupe + DISCONNECTED priority + two-layer 獨立性(AC-33/34/54;EC-B2/B4/B5/E3)| Integration | Ready | ADR-0001 |
| 012 | **DISCONNECTED surface**:workout banner-defer(Rule 9a)+ non-workout DISCONNECTED_SHELL + reconnect 掣 `request_immediate_poll()`(AC-37/37b)| Integration | Ready | **G-LS-4 GATED**(37b)|
| 013 | **入口 affordance + 互斥 arbiter**:`request_open` last-wins latch + 三態(enabled/interactive-dimmed/hidden)+ `can_open()` double guard + **G-LS-5 #22 `loadout_view_all_tap` 遷移**(orphan-cleanup grep)(AC-39/40)| Integration | Ready | **G-LS-5** |
| 014 | **Logout drain**:`clear_session_token(USER_EXPLICIT)` optimistic + drain banner + part-fail persistent(WIPE-weight)+ sequencing(drain ✓ 先清先入 LOGIN)(AC-41/42;EC-B6/B8)| Integration | Ready | ADR-0002 |
| 015 | **Login form 規格**:username/password(secret)/show-toggle(≥44px)/submit;無 remember-me/註冊/忘記;**credential residue**(resolve 即清 password)+ ASCII charset(AC-12/50)| Integration | Ready | **依賴 G-LS-3 + G-LS-6 路線** |
| 016 | **Static-CI grep cluster**:banner 靜態紀律(AC-35a source grep + AC-35b/36 scene-tree)+ credential grep(AC-50)+ clock grep(AC-51)| Static-CI | Ready | Rule 8/15;ADR-0001 |
| 017 | **G-LS-9 lint + errata cluster**:`check_no_ui_subscribes_telemetry.sh` 創建 + scope 擴 `src/autoload/` UI coordinators + #2 L120 scope erratum + **#8 L755 雙參簽名 erratum**(AC-25)| Static-CI(+doc) | Ready | **G-LS-9 GATED** |
| 018 | **G-LS-7 doc closure**:#22/#23 coordinator header FSM-extraction fork notice → Rule 14 closure 注記(godot-specialist 覆核)| Config/Data(doc) | Ready | **G-LS-7** |
| 019 | **a11y + AC-UX assertions**:`announce_aria`(error assertive / banner polite)+ tab order + ≥44/48px + AC-UX-2/3/5/8/9 region/三態/cross-fade 量度 | Integration | Ready | N/A(seam shipped #21/#22/#23)|

> **Producer gate (PR-EPIC)**: **REALISTIC — degraded inline**(2026-06-08;harness no-spawn 約束 + 單一 Presentation epic structure self-evident;#22/#17/#18/#21 degraded-inline 先例)。維持單一 epic(gate-inside-epic);story baseline **16–20**(現 19 ✓);binding directives 見下。

## Cross-system gates(G-LS-1..9 — 全部係本 epic 內 stories;#21 G-LM / #22 G-CS 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-LS-1** | ADR-0001 amendment:LoginShellLayer 62 PAUSABLE + capture enum +62 / ErrorBannerLayer 111 ALWAYS / banner 禁第二 BackBufferCopy | ADR-0001 | doc-only(**scaffold 前提**)|
| **G-LS-2** | ADR-0008 amendment:LoginShellCoordinator tail append(InventoryUICoordinator 後;零 #21/#22/#23 constraint)+ `project.godot` 登記 | ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-LS-3** | **#2 `claim_session` async 簽名 + cancellation 語意 pin**(await-coroutine vs completion-signal;SUSPENDED-cancel 唔掛死 — 二擇一:resolve cancelled result / completion-signal + injected-clock timer race)+ ASCII charset 確認 | #2 erratum / focused amendment | code(**login form story 前 blocking**)|
| **G-LS-4** | **#2 additive API ×3**:(a)`get_auth_block_reason() -> StringName`;(b)`request_immediate_poll()`;(c)`is_auth_required() -> bool`(boot-race 致命收口)| #2 erratum(additive — #23 G-IU-1 consumer-forward 先例)| code |
| **G-LS-5** | #22 `loadout_view_all_tap` 遷移:直 call #23 → `request_open(&"inventory")`(Q-IU1 已承諾)+ grep 晒 `_inventory_ui`/`loadout_view_all_tap` mention | #24 epic + #22 | code(orphan-cleanup 紀律)|
| **G-LS-6** | **iOS Safari spike**(virtual_keyboard / canvas resize / IME / canvas auto-zoom / dual-focus)— epic **story 001**;結果決定 LineEdit vs DOM overlay 路線 | #24 epic story 001 | spike(**HIGH risk**)|
| **G-LS-7** | FSM extraction closure:#22/#23 header fork notice → Rule 14 裁決(唔 extract — login ≠ overlay lifecycle)| #22/#23 doc | doc-only |
| **G-LS-8** | **#3 additive API**:`get_pending_errors() -> Array`(boot-window error buffer pull-check)| #3 erratum(additive)| code |
| **G-LS-9** | 上游 errata + lint coverage:(a)#2 L120 lint scope erratum(`src/autoload/` UI coordinators 唔 cover → 擴 scope);(b)`check_no_ui_subscribes_telemetry.sh` 創建;(c)#8 GDD L755 單參簽名 stale erratum | #2/#8 errata + #24 CI story | code + doc(#23 story-018 errata-cluster 先例)|

## Story breakdown directives(PR-EPIC degraded inline — binding)

1. **Story 001 = G-LS-6 iOS spike**(HIGH risk,FIRST)— 結果決定 LineEdit vs DOM overlay,login form story(015)路線依賴;spike 連帶驗 a11y 實機(VoiceOver/dual-focus)。
2. **G-LS-1 + G-LS-2 做最早 doc stories**(002 — ADR revisions = scaffold 前提,layer 62/111 要 ADR 授權先寫 project.godot);**file split(banner_stack.gd + shell_transitions.gd)喺 scaffold story 003 落地**(AC-35a grep target 前提,**AC-35a CI step 必須 assert target file 存在,no-file ≠ no-match**)。
3. **G-LS-3 = login form story(015)前 blocking**:claim delivery mechanism + cancellation pin 未釘 → AC-06/07/08/22 GATED;釘實前 mock-scoped 先行(cancelled-result mock 驗 timeout fallback)。
4. **G-LS-3/4/8/9 errata cluster**:additive API mock-scoped 先行(#23 G-IU-1 consumer-forward 先例),真接線 #2/#3/#8 erratum story 隨後;AC-25(G-LS-9 lint)GATED 直至 script 創建 + scope 擴。
5. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊 — 跨 file bug 防;memory ci_gate_command)。
6. **Story 總數 baseline 16–20**(>20 = scope creep 重審;<16 = AC force-compress 重審)。
7. **Formula stories(006/007)獨立 early**(injected clock seam,banner/countdown render 依賴);timing test 全用 injected clock `advance(delta_ms)`,persistence-consumer test 喺 `add_child` **前**注入 mock(reference_test_persistence_isolation)。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **56 GDD ACs verified**:39 BLOCKING 全過(11 Logic + 25 Integration + 3 Static-CI)+ 10 GATED(mock-scoped 先行,真接線 story 解封)+ 6 manual ADVISORY 有 evidence @ `production/qa/evidence/login-shell/` + 1 EXTERNAL(AC-47 iOS real-device 記錄在案)
- **11 AC-UX verified**(9 BLOCKING-measure / 2 ADVISORY-visual;AC-UX-4 GATED-OQ-UX2)
- Combined GUT gate green(per gate story + epic 收線)
- `LoginShellCoordinator` 登記 `project.godot` tail(G-LS-2)+ ADR-0001 amendment merged(G-LS-1)
- G-LS-1..9 全部執行(各自 evidence 喺對應 story 收口)
- **Zero-silent-swallow 驗證**(Fantasy Test 2 binding):4 upstream error signal + UNMAPPED default-deny 全部產生 visible banner(AC-26/52/54)
- **Banner 靜態紀律**(AC-35a/35b/36)+ **credential residue zero**(AC-50)+ **clock seam**(AC-51)CI-green
- Test evidence:unit `tests/unit/login_shell/` / integration `tests/integration/login_shell/`

## Next Step

Run `/create-stories login-shell` to break this epic into implementable stories。
