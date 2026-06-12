# Epic: Onboarding Flow(#27)

> **Layer**: Polish / Presentation(Pre-MVP tier — first-run choreography 層;**純 downstream consumer**,無 coupled-pair blocking,deps 全 implemented 可獨立推)
> **GDD**: design/gdd/onboarding-flow.md(✅ APPROVED 2026-06-11 — /design-review NEEDS REVISION→revise-now→APPROVED 同 session;8 Core Rules / 3 Formula(may_show gate / auto-dismiss / boot-resume,全 UI gating/timing 零 balance math)/ 5-state FSM(DORMANT/WELCOME/PREVIEW/COACHING/COMPLETE)/ 17 EC / **24 AC** / CI lint **G-OB-2** / 6 own knob;B-1 SET_ACTIVE→WORKOUT_ACTIVE 純 GSM fix + B-2 tail-after-#25 fix)
> **UX Spec**: design/ux/onboarding-flow.md(✅ APPROVED 2026-06-11 — /ux-review 0 BLOCKING / 5 ADVISORY;output overlay flow spec;4 coach-mark + preview screen + 單一 slot + **12 UX-AC**;2 新 pattern flagged:coach-mark + preview-watermark)
> **Architecture Module**: `OnboardingCoordinator` autoload @ `src/autoload/onboarding_coordinator.gd`(thin Node;持有 first-run **4-step latch** + `OnboardingOverlayLayer` CanvasLayer coach-mark host;內部可拆 `src/ui/onboarding/` helper [coach_mark / preview_director],**唔開第二個 autoload**)。**Holds ZERO gameplay state**(G-OB-2 CI lint 守:`src/autoload/onboarding_coordinator.gd` + `src/ui/onboarding/*` 零 write 去 `loot.*`/`stat.*`/`ability.*`/`streak.*`、零 #15 drop-gen/daily-claim、零 #11/#12 mutator)。Autoload 位置:**tail-append 喺 current tail(#25 `CombatVisualFeedback`,project.godot L162)之後**(G-OB-1 ADR-0008 amendment;terminal — 冇下游;**非** #29 — B-2 stale-fix)
> **Status**: Ready
> **Stories**: **16 stories**（3 Logic + 6 Integration + 3 UI + 2 Config/Data + 1 Static-CI + 1 Visual/Feel）— run `/story-readiness` → `/dev-story`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | G-OB-1 ADR-0008 autoload tail amendment + project.godot register | Config/Data | Ready | ADR-0008 |
| 002 | Coordinator scaffold + 5-state FSM + cfis subscription bootstrap | Integration | Ready | ADR-0006/0008 |
| 003 | Formula 3 boot-resume state selection | Logic | Ready | N/A(pure formula) |
| 004 | Persistence onboarding.* latch + per-step latch + idempotency | Integration | Ready | ADR-0003 |
| 005 | Formula 1 may_show gate(WORKOUT_CRITICAL all-GSM,B-1) | Logic | Ready | N/A(pure formula) |
| 006 | Formula 2 auto-dismiss + tap-dismiss(injected clock) | Logic | Ready | N/A(pure formula) |
| 007 | Step 1 Connect + welcome coach-mark + step_connect latch | Integration | Ready | ADR-0006 |
| 008 | Step 2 非綁定 preview + watermark + skip + real-workout abort | UI | Ready | ADR-0001 |
| 009 | Step 3 muscle=class coach-mark + #10 lookup + UNKNOWN defer | Integration | Ready | ADR-0009 |
| 010 | Step 4 first-drop framing coach-mark(post-ceremony #21) | Integration | Ready | ADR-0009 |
| 011 | Coach-mark defer loop + stale-latch(max_defer) + queue order | Integration | Ready | ADR-0006 |
| 012 | G-OB-2 CI lint no-gameplay-mutator(Pillar 1 命脈) | Static-CI | Ready | N/A(CI tooling) |
| 013 | G-OB-3 ADR-0001 OnboardingOverlayLayer amendment + coach-mark overlay UI | UI | Ready | ADR-0001 |
| 014 | a11y screen-reader announce + reduced-motion + escape hatch | UI | Ready | N/A(seam) |
| 015 | Registry knobs + 2 新 UX pattern + UX advisory carry | Config/Data | Ready | N/A(config+doc) |
| 016 | Playtest evidence(AC-14 mid-set + AC-24 fantasy) | Visual/Feel | Ready(ADVISORY) | N/A(playtest) |

> **Implementation order**:001(autoload scaffold 前提)→ 002(FSM scaffold)→ formula stories(003 resume / 005 may_show / 006 dismiss,獨立 early)→ 004(latch persist)→ step stories(007 connect → 008 preview → 009 class → 010 first-drop)→ 011(defer/queue)→ 012(G-OB-2 lint,非綁定 impl 落地後驗)→ 013(overlay UI/G-OB-3)→ 014(a11y)→ 015(registry/pattern/advisory)→ 016(playtest,ADVISORY)。**must-not-regress guard**:G-OB-2 zero-gameplay-mutator(Pillar 1)/ AC-10 defer-mid-set(Pillar 2,WORKOUT_CRITICAL 全 #1 GSM — B-1)/ AC-04/05 DORMANT-terminal-once + completed-first / AC-17 observe-only never-drive。

## Overview

實作 Mirror Hero 嘅 **first-run choreography/coaching 層** —— game-concept L106「首 5 分鐘 onboarding curve」(連接 GymSys → demo workout → 必爆首件裝備 → 教 muscle=class,**NO tutorial wall,一切 in-context**)。OnboardingCoordinator 純 **orchestrate 既有系統**:host #24 login surface、觀察 #9 workout lifecycle、引用 #10 muscle=class 真相、慶祝 #15 真實首個 daily drop。

佢 own 三樣嘢:(1) **first-run 4-step persisted latch**(connect / preview / class / first-drop,每步恰好 fire 一次永不重播,backend-primary 跨 device);(2) **dismissible peripheral non-blocking coach-mark overlay**(in-context 解釋,**唔係** modal tutorial wall);(3) **非綁定零真實 progress 嘅 combat preview**(Pillar 1 safe,即時交付 auto-combat fantasy)。

設計命脈兩條,落地為兩個 CI/test guard:**Pillar 1 — 首件裝備 = 真 #15 daily drop**(onboarding 永不 script/client-trigger,G-OB-2 CI lint 守零 gameplay mutator);**Pillar 2 — coach-mark 永不 mid-set 出現**(workout-critical state defer,AC-10 守)。做完即永久 DORMANT,零 runtime cost。Onboarding 係 navigation graph 上一條 transient 首遇路徑,行完即從圖上消失 —— 引路人,唔係主角。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0008**: Autoload Position Map | **G-OB-1 tail-insertion amendment 待做**(本 epic story)— `OnboardingCoordinator` tail-append 喺 current tail(#25 `CombatVisualFeedback`)之後;terminal;`project.godot` 登記。**Impl-time grep current tail**(64ebbb5 係 #25;勿照搬 GDD 早期「#29」措辭 — B-2 stale-fix) | LOW |
| **ADR-0001**: Web Export Budget Caps | **G-OB-3 CanvasLayer amendment 待做**:`OnboardingOverlayLayer` 喺既有 enumeration 之內,**captured band <100 acceptable**(R-2:coach-mark 永不同 world desaturation 同框 → 無需 >100 immune;候選 ~63,above #24 LoginShellLayer 62);opacity-only NO BackBufferCopy(無 blur);BBCopy capture enumeration sync(positional <100;[[feedback_lint_allowlist_adr_sync]] 防 stale-enumeration phantom) | **MEDIUM**(captured-band amendment 比 #21/#29 嘅 >100 immune layer 低風險;但 enumeration sync 要做足)|
| **ADR-0003**: Save State Strategy | `onboarding.*` namespace(`completed` + 4 step latch,全 bool,backend-primary);**唔掂其他 namespace**;IPersistence | LOW |
| **ADR-0006**: State Machine Contract | Contract 6 `connect_for_initial_state`(訂 #1 GSM `state_changed` boot 即收,landing + workout-critical gating,replay-safe);5-state shell FSM ≠ GSM state(orthogonal,同 #24 banner 先例) | LOW |
| **ADR-0009**: Signal Payload Schema | observe-only:訂 #9/#21 signal payload minimal+intrinsic;cross-cutting context late-bind null-safe;`transition_id` correlation | LOW |

## GDD Requirements

> #27 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#21/#22/#23/#24/#25/#26/#29 先例一致)。Requirements 由 GDD 直接 trace:**8 Core Rules(Rule 1..8)+ 3 Formula(F1 may_show gate / F2 auto-dismiss / F3 boot-resume — 全 UI gating/timing,零 balance math)+ 5-state FSM(DORMANT/WELCOME/PREVIEW/COACHING/COMPLETE)+ 17 ECs(真實優先/persistence/teaching-trigger/退化)+ 24 ACs + CI lint G-OB-2**,全部有 Accepted ADR cover(上表)+ **3 個 cross-system gate G-OB-1..3**。UX 層另加 **12 UX-AC**(purpose / non-interference / defer-mid-set / tap-dismiss / auto-dismiss / preview-watermark / preview-skip / graceful-degrade / a11y-contrast / reduced-motion / screen-reader / one-way-exit)。

**Untraced requirements**: None(G-OB gates 係 cross-system amendment/CI-lint/config,非 untraced ADR-gap;所有 requirement 有 Accepted ADR cover;TR-ID granularity 留 /architecture-review batch)。

**AC 分佈**:24 GDD AC(latch/idempotency 5 + 四步流程 4 + Pillar-2 non-blocking 5 + Pillar-1 CI-lint 3 + 真實優先/退化 5 + autoload/boot 2)+ **CI lint G-OB-2**(no-gameplay-mutator,Pillar 1 命脈)+ **12 UX AC**。**ADVISORY playtest**:AC-14(mid-set 零 coach-mark 人手驗)+ AC-24(玩家事後唔覺有 tutorial + 能自述三概念 — Pillar 2 fantasy 驗)。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **24 GDD ACs verified**(latch/idempotency + 四步 + non-blocking gating 全過)+ **12 UX AC verified** + G-OB-2 CI lint green
- **CI lint G-OB-2 green**:`tools/ci/check_onboarding_no_gameplay_mutator.gd` — grep `onboarding_coordinator.gd` + `src/ui/onboarding/*` 零 write 去 `loot.*`/`stat.*`/`ability.*`/`streak.*`、零 call #15 drop-gen/daily-claim、零 call #11/#12 mutator(Pillar 1 命脈)
- `OnboardingCoordinator` 登記 `project.godot` tail(G-OB-1,after current tail #25;impl-time grep 確認)+ ADR-0008 amendment merged
- **G-OB-3 ADR-0001 amendment**:`OnboardingOverlayLayer` layer 數值釘喺既有 enumeration(captured band <100)+ BBCopy enumeration sync;boot 乾淨
- **5-state FSM** 正確:DORMANT terminal / WELCOME→PREVIEW(或 COACHING 若 workout active)/ PREVIEW→COACHING / COACHING→COMPLETE→DORMANT;四 latch driven,boot-resume(F3)file-backed 跨中斷
- **Pillar 2 non-blocking 驗**:coach-mark 喺 GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD, LOOT_DROP}(B-1 全 #1 GSM)一律 defer,**零 mid-set 出現**(AC-10);tap-anywhere + auto-dismiss(6s);input non-interference(底層 single-tap 唔被 overlay 偷)
- **Pillar 1 real-drop-only 驗**:preview 非綁定(零 loot/stat/ability/persistence/daily-token,AC-16);首件裝備 = 真實 `workout_completed` → #15 daily drop,onboarding 唔 fabricate(AC-17)
- **真實優先 interrupt**(EC-02/03):preview 期間 `#9 workout_started_forwarded` → abort + COACHING;connect 時 mid-workout → skip PREVIEW
- **退化**:preview load fail → graceful skip 零 crash(AC-21);`onboarding.*` read fail → default-false 永不 fabricate completed(AC-22);`dominant_class_changed(UNKNOWN)` → 唔 naming UNKNOWN(AC-20)
- G-OB-1..3 全部執行(各自 evidence 喺對應 story 收口)
- Test evidence:unit `tests/unit/onboarding_flow/` / integration `tests/integration/onboarding_flow/` / static `tests/static/`(G-OB-2 lint + autoload position)

## Cross-system gates(G-OB-1..3 — 全部係本 epic 內 stories;#21 G-LM / #24 G-LS / #29 G-MM 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-OB-1** | ADR-0008 tail-insertion amendment:`OnboardingCoordinator` tail-append 喺 current tail(#25 `CombatVisualFeedback`)後;terminal;`project.godot` 登記。**Impl-time grep current tail**(勿照 GDD 早期「#29」措辭 — B-2 stale-fix);predecessor 集 {#1 GSM C6,#2,#3,#9,#10,#21,#24,#25,...全現有 coordinator} | ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-OB-2** | **CI lint `check_onboarding_no_gameplay_mutator.gd`**(Pillar 1 命脈):grep onboarding source 零 gameplay namespace write、零 #15 drop-gen/daily-claim、零 #11/#12 mutator。違反 = fail。**must-not-regress guard** | CI tooling(新 lint)| code(early — Pillar 1 命脈)|
| **G-OB-3** | ADR-0001 CanvasLayer amendment:`OnboardingOverlayLayer` layer 數值釘喺既有 enumeration(**captured band <100**,R-2;候選 ~63 above #24 LoginShellLayer 62);opacity-only NO BackBufferCopy;BBCopy capture enumeration 明寫 sync([[feedback_lint_allowlist_adr_sync]] 防 stale-enumeration phantom — 同 G-CS-7/G-IU-2/G-LS-1/G-CV-1 先例)| ADR-0001 + layer infra | doc + config |

## Story breakdown directives(PR-EPIC degraded inline REALISTIC — binding)

1. **G-OB-1 做最早 doc story**(ADR-0008 tail amendment + project.godot 登記 = scaffold 前提;tail after current tail #25 — **impl-time grep 確認 current tail,勿硬寫 #29**[B-2 教訓])。
2. **純 downstream consumer,無 coupled-pair blocking**:deps {#1,#2,#3,#9,#10,#15,#21,#24} 全 implemented + grep-verified contract(/design-review 已驗 11 contract EXACT)→ onboarding 可獨立 implement(異於 #29 等 #26)。
3. **G-OB-2 CI lint 早做**(Pillar 1 命脈;同 #29 CI-MM-1 / #25 AC-11 先例 — 命脈 guard 早落地 + must-not-regress)。
4. **G-OB-3 ADR-0001 amendment**:captured band <100(R-2;coach-mark 永不同 world desaturation 同框);BBCopy enumeration sync 要做足([[feedback_lint_allowlist_adr_sync]])。
5. **Formula stories(F1 may_show / F2 auto-dismiss / F3 boot-resume)獨立 early**;timing test 用 injected clock `advance(delta_ms)`(#22/#23/#24 先例);persistence-consumer test 喺 `add_child` **前**注入 mock([[reference_test_persistence_isolation]]);integer-ms 紀律(knob float sec → int ms,formula 內全 int 比較)。
6. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` + `tests/static` 一齊;[[feedback_ci_gate_command]])。
7. **Story 總數 baseline 14–18**(>18 = scope creep 重審;<14 = AC force-compress 重審 — 薄 observe-only orchestrator,純 gating/timing)。
8. **must-not-regress guards**:**G-OB-2** zero-gameplay-mutator(Pillar 1)/ **AC-10** defer-mid-set zero-coach-mark(Pillar 2,WORKOUT_CRITICAL 全 #1 GSM — B-1)/ **AC-04/05** DORMANT-terminal-once + completed-first / **AC-17** observe-only never-drive(無 GSM transition / 無 #15 client-trigger,spy/grep 驗)。
9. **UX advisory carry(5 + 2 pattern)**:UX spec header `Platform Target` field 補 + appear-latency AC + resolution/aspect-ratio AC + preview-loading state 明寫 + keyboard focus order 明寫;**2 新 pattern 入庫** `coach-mark` + `preview-watermark` → `design/ux/interaction-patterns.md`(catalog 加 P-20/P-21 或對應編號)。
10. **B-1/B-2 fix 落實**:WORKOUT_CRITICAL = {WORKOUT_ACTIVE, REST_PERIOD, LOOT_DROP} 全 #1 GSM(may_show gate single-enum membership,零 cross-enum);autoload tail after #25(grep current tail)。

## Next Step

Run `/create-stories onboarding-flow` to break this epic into implementable stories。
