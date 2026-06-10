# Epic: Mirror Moment System(#29)

> **Layer**: Polish(MVP-minimum screenshot-only scope — coupled pair 同 #26 Avatar Renderer 一齊建立;系統完成 Pillar 5「identity vs celebration」雙生縫)
> **GDD**: design/gdd/mirror-moment.md(✅ APPROVED 2026-06-10 — /design-review NEEDS REVISION→revise→APPROVED 同 session;15 CR / 3 Formula(全 gating logic 零 balance math)/ 4-state FSM(DORMANT/ARMED/PRESENTING/PAUSED)/ 20 EC / **26 AC** / **4 CI lint(CI-MM-1..4)** / 9 own knob)
> **UX Spec**: design/ux/mirror-moment.md(✅ APPROVED 2026-06-10 — /ux-review 0 BLOCKING / 5 ADVISORY;ceremony overlay 真互動 spec;3-zone[backdrop + CelebrationVFXLayer 110 + ModalLayer 120]+ screenshot flow + **8 UX AC**;2 新 pattern flagged:Share-Card + Screenshot-Share Affordance)
> **Architecture Module**: `MirrorMomentCoordinator` autoload @ `src/autoload/mirror_moment_coordinator.gd`(thin Node;持有 ceremony overlay CanvasLayer — **復用既有** CelebrationVFXLayer 110 + ModalLayer 120,#21-owned shared infra;**唔開新 layer**)。**Holds ZERO tier-derivation state**(CI-MM-1 守:`src/**/mirror_moment*.gd` 零 `S_t`/`A_t`/`D_t` threshold compare、零 `effective_tier=max()` — tier 只經 `get_evolution_snapshot().tier` 讀入)。Autoload 位置:**tail append 喺 `AvatarRenderer`(#26)之後**(G-MM-1 ADR-0008 amendment;單向 #29→#26 boot order;terminal — 冇下游)
> **Status**: ✅ **IMPLEMENTED 2026-06-10**(coupled pair — #26 implemented 先,#29 後;full gate GREEN:GUT unit+integration+static **2698 / 2697 pass / 0 fail**(+1 pre-existing pending)+ 68 .gd + 10 .sh lint exit 0;#29 suite 自身 38 tests)。015 a11y/pattern done;016 playtest = ADVISORY 人手 gate(protocol authored,execution deferred)。
> **Stories**: **16 stories**(15 implemented + green;016 ADVISORY protocol-authored,playtest deferred)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | G-MM-1 ADR-0008 tail amendment + project.godot + G-MM-4 cadence registry | Config/Data | ✅ Done | ADR-0008 |
| 002 | Coordinator scaffold + 4-state FSM + cfis 3-sub + bootstrap latch rebuild | Integration | ✅ Done | ADR-0006/0008 |
| 003 | Formula 1 ceremony_arm_check (cadence + change + once-per-window) | Logic | ✅ Done | N/A(pure formula) |
| 004 | Formula 2 content_tier_selection (EVOLUTION/REFLECTION/NONE honest skip) | Logic | ✅ Done | N/A(pure formula) |
| 005 | CR-M3 non-workout presentation gate + #33 soft + LOOT_DROP exclude | Integration | ✅ Done | ADR-0006 |
| 006 | CR-M4 pending-milestone latch + persist (tier-up never lost) | Integration | ✅ Done | ADR-0003/0009 |
| 007 | Formula 3 before_after collapse + CR-M6 snapshot-at-present | Logic | ✅ Done | ADR-0010 |
| 008 | Persistence schema mirror_moment.* + boot rebuild + G-MM-6 namespace | Integration | ✅ Done | ADR-0003 |
| 009 | CR-M12 suspend/bfcache PAUSED | Integration | ✅ Done | ADR-0006/0001 |
| 010 | Screenshot prompt + share-card (CR-M7) | UI | ✅ Done | ADR-0001 |
| 011 | Celebration VFX #5 burst + G-MM-2 layer + G-MM-3 LOOT preset | Integration | ✅ Done | ADR-0001/0005 |
| 012 | CR-M9 once-per-window + dismiss markers | Integration | ✅ Done | ADR-0003 |
| 013 | Narrative payload CR-M10 + G-MM-5 #9 caption enrich | Integration | ✅ Done | N/A(null-safe read) |
| 014 | CI lint CI-MM-1..4 + AC-20/AC-25 no-fabrication audit + cadence parity | Static-CI | ✅ Done | ADR-0010 |
| 015 | Ceremony overlay a11y + transient-IDLE delay + G-MM-7 2 patterns | UI | ✅ Done | N/A(seam shipped) |
| 016 | Playtest evidence FT-2 / FT-M1 | Visual/Feel | ⏸ ADVISORY (protocol authored, playtest deferred) | N/A(ADVISORY) |

> **Implementation note (2026-06-10)**: `MirrorMomentCoordinator` autoload + `MirrorMomentFormulas`(static pure F1/F2/F3 + resume)+ `MirrorMomentConfig`(.gd + .tres)+ 4 CI-MM lints。Tests:`tests/unit/mirror_moment/test_mirror_moment_formulas.gd`(17)+ `tests/integration/mirror_moment/test_coordinator_fsm.gd`(21)。G-MM-1 boot-order lint allowlist sync(`check_loot_reveal_boot_order` + `test_invui_lifecycle` 加 MirrorMomentCoordinator,feedback_lint_allowlist_adr_sync)。**Deferred**:CI-MM violation-fixtures(test-evidence completeness,lint CI-gated + clean-pass,#26 同款先例)/ 016 playtest(human)/ #17·#18·#9 真 narrative surface 接線(consumer-forward null-safe extension point shipped,upstream wires later)。

> **Implementation order**:#26 epic 先收線(coupled pair HARD dep,mock-scoped 先行)→ 001(scaffold 前提)→ 002(FSM)→ formula stories(003/004/007 + gate 005)→ latch/persist(006/008)→ suspend(009)→ UI(010/011/012)→ narrative(013)→ CI(014)→ a11y/pattern(015)→ playtest(016)。**must-not-regress guard**:AC-09 tier-up-never-lost / AC-10 collapse-single / AC-11 snapshot-at-present / AC-03 non-workout-gate / AC-20 zero-tier-compute(CI-MM-1 對稱守 #26 AC-30)/ G-MM-3 LOOT-preset-only(B-1)。

## Overview

實作 Mirror Hero 嘅 **Pillar 5 weekly 慶典 orchestrator** ——「停低,認返自己」。每週一次,當玩家喺**非 workout** context 打開 app(GSM `IDLE`、cadence window 開、has_change),系統 pause 落嚟 show 玩家真實訓練點樣改變咗個 avatar:**before→after reveal 可截圖分享**。截圖之所以值得分享,正因為**唔造得假** —— 個 character 變咗係因為玩家真係去咗 gym(Pillar 1)。

ADR-0010 將 Pillar 5 沿「**identity vs celebration**」一分為二。#29 owns **慶典 only**:cadence(weekly)+ non-workout gate + before→after reveal + screenshot prompt + celebration VFX。**Holds ZERO evolution-tier state** —— 全部 tier 數字經 `#26.get_evolution_snapshot()` 讀入(CR-M14 / CI-MM-1 守)。單向 dep `#29→#26`,**永無 back-edge**;#29 係 **terminal Polish system**(冇任何下游 read 佢 output)。

Content-adaptive 單一 weekly cadence(Formula 2):pending tier-up → **EVOLUTION** 大慶典(before→after ghost + #5 celebration burst + screenshot)/ micro-only 週 → **REFLECTION** 輕慶典(單 frame + 回顧 caption + screenshot,無 burst)/ 零變化 → **NONE** honest skip(Pillar 1 — overlay 根本唔開)。MVP = **screenshot-only**(native screenshot;in-app capture-to-PNG → v0.2);v0.2 = full layered ceremony(9:16 portrait / 多 beat / ghost morph / share funnel)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0010**: Mirror Moment Ceremony Ownership Split | #29 owns 慶典 composition(reveal/screenshot/celebration),**zero tier-state**;單向 #29→#26;**CI-MM-1** grep `src/**/mirror_moment*.gd` 零 tier-derivation | LOW(Accepted 2026-06-10,本 GDD + #26 v2.1 一齊 ratify)|
| **ADR-0001**: Web Export Budget Caps | CanvasLayer topology:**復用** CelebrationVFXLayer 110(celebration burst residence — LOOT preset → LARGE tier)+ ModalLayer 120(chrome/CTA);**opacity-only backdrop,NO 2nd BackBufferCopy**(#24 AC-36 budget);particle 只經 #5.play() | **HIGH**(modal topology + particle budget;G-MM-2 confirm 110 persistent infra)|
| **ADR-0003**: Save State Strategy | `mirror_moment.*` namespace(latch + window markers + `ceremony_count` + `last_shared_unix`);**CI-MM-4** 守零 `avatar.*` write;IPersistence | LOW |
| **ADR-0006**: State Machine Contract | Contract 6 `connect_for_initial_state`(訂 #26 milestone/micro signal boot 即收,replay-safe CR-M11);non-workout gating via GSM `get_current_state()`;4-state shell FSM ≠ GSM state | LOW |
| **ADR-0009**: Signal Payload Schema | `transition_id` correlation;subscription payload minimal+intrinsic;GSM payload null late-bind | LOW |
| **ADR-0008**: Autoload Position Map | **G-MM-1 tail-insertion amendment 待做**(本 epic story)— `MirrorMomentCoordinator` tail append 喺 `AvatarRenderer`(#26)後;terminal;`project.godot` 登記 | LOW |
| **ADR-0005**: Loot Rarity Formula(間接)| celebration burst **復用 LOOT preset**(`LOOT_BURST`/`LOOT_RARE_BURST`)→ LARGE tier → CelebrationVFXLayer 110 residence(B-1 HARD);新 preset 須 #5 amendment | LOW(經 #5 preset 復用,G-MM-3)|

## GDD Requirements

> #29 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#18/#21/#22/#23/#24/#26 先例一致)。Requirements 由 GDD 直接 trace:**15 Core Rules(CR-M1..M15)+ 3 Formula(F1 ceremony-arm gate / F2 content-select EVOLUTION-vs-REFLECTION / F3 show_ghost — 全 gating/selection,零 balance math)+ 4-state FSM + 20 ECs(EC-MM-*)+ 26 ACs + 4 CI lint(CI-MM-1..4)**,全部有 Accepted ADR cover(上表)+ **7 個 cross-system gate G-MM-1..7**。UX 層另加 **8 UX AC**(safe-context / screenshot flow / EVOLUTION-vs-REFLECTION / zero-friction dismiss / burst-above-backdrop / a11y / suspend-safety / caption null-safety)。

**Untraced requirements**: None(G-MM gates 係 cross-system amendment/registry/wiring,非 untraced ADR-gap;ADR-0010 為 coupled pair 量身 Accepted;TR-ID granularity 留 /architecture-review batch)。

**AC 分佈**:26 GDD AC(gating logic 為主 — safe-context / cadence-window / content-select / dismiss-marker / suspend / null-safe caption)+ **4 CI lint**(CI-MM-1 no-tier-compute / CI-MM-2 no-particle-instantiate / CI-MM-3 cadence-data-driven+parity / CI-MM-4 persistence-namespace)+ **8 UX AC**。**FT-2 share-rate(由 #26 遷移嚟,ADR-0010)= #29 owns** —— weekly self-initiated screenshot/share < 30% playtest telemetry `mirror.shared`(falsifiable)。

## Definition of Done

This epic is complete when:
- #26 Avatar Renderer epic 已 implement(coupled pair HARD dep;#29 訂 #26 signal + 讀 snapshot)
- All stories implemented, reviewed, closed via `/story-done`
- **26 GDD ACs verified**(gating logic 全過)+ **8 UX AC verified** + 4 CI lint green
- **4 CI lint green**:CI-MM-1(`mirror_moment*.gd` 零 tier-derivation literal/pattern)+ CI-MM-2(零直接 `GPUParticles2D` instantiate — 只經 `#5.play()`)+ CI-MM-3(cadence 常數 data-driven from `mirror_moment_config.tres` + parity assert `== #26.MILESTONE_CADENCE_SECONDS`)+ CI-MM-4(persistence write 只落 `mirror_moment.*`,零 `avatar.*`)
- `MirrorMomentCoordinator` 登記 `project.godot` tail(G-MM-1,after #26)+ ADR-0008 amendment merged
- **B-1 burst-above-backdrop 驗證**:EVOLUTION celebration burst 用 LOOT preset → CelebrationVFXLayer 110,喺 dimmed modal backdrop **之上**可見(唔被遮)
- **EVOLUTION vs REFLECTION vs NONE** 三態正確:EVOLUTION ghost+badge+burst / REFLECTION 單 pose+caption 無 burst / NONE honest skip(overlay 唔開,emit `mirror.no_change_skip`)
- **Screenshot flow**:tap「截圖分享」→ 非-card chrome 暫隱 + native-screenshot hint + emit `mirror.share_prompted`;確認 → emit `mirror.shared`(FT-2)
- **Suspend safety**(CR-M12):SUSPENDED mid-ceremony freeze;resume ≤30s 續,>30s collapse 保 window marker
- G-MM-1..7 全部執行(各自 evidence 喺對應 story 收口)
- Test evidence:unit `tests/unit/mirror_moment/` / integration `tests/integration/mirror_moment/`

## Cross-system gates(G-MM-1..7 — 全部係本 epic 內 stories;#21 G-LM / #24 G-LS 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-MM-1** | ADR-0008 tail-insertion amendment:`MirrorMomentCoordinator` tail append 喺 `AvatarRenderer`(#26)後;terminal;單向 #29→#26 boot order;`project.godot` 登記 | ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-MM-2** | **確認 CelebrationVFXLayer 110 + ModalLayer 120 = persistent shared infra**(Q-UX-CELEB-LAYER):IDLE 慶典(當 #21 loot modal NOT active)仍有 layer render onto;opacity-only backdrop NO 2nd BackBufferCopy 確認 | #5 / #21 layer infra | doc + dependency-note(layer 已 #21-owned;確認復用 reachability)|
| **G-MM-3** | **Q-OQ-PRESET(B-1 HARD)**:EVOLUTION celebration burst **必須復用 LOOT preset**(LOOT_BURST/LOOT_RARE_BURST → LARGE tier → 110 residence);若加新 #5 preset → #5 amendment(size==9→N **加** LARGE-tier/celebration-residence carve-out,闊過 #26 R-5);**SHARED 同 #26 G-AR-3** | #5 preset(若加)| code(**default 復用,coupled pair 一齊決定**)|
| **G-MM-4** | **Registry**:`MIRROR_CADENCE_SECONDS`(604800)同 #26 `MILESTONE_CADENCE_SECONDS` **一齊 registry 註冊**;**從 source #26 GDD 註冊**(registry-5b 教訓:唔由 referrer 註冊 duplicate);CI-MM-3 code parity assert 守 | entity registry + #26 const | doc + config(coupled pair 一齊)|
| **G-MM-5** | **Q-OQ-CAPTION-N**:招牌 caption「第 N 週 · 練咗 M 次」需週數+訓練次數,但 `snapshot.source_metrics` 砌唔到 → wire **#9 WST** surface;null-safe → 缺則 caption 退化純 tier/class(R-1,AC-06)| #9 forward-wire(SOFT)| code(null-safe degrade)|
| **G-MM-6** | **#3 namespace**:`mirror_moment.*` persistence namespace 註冊(同 #8 `streak.*` / #17 `inventory.*` 並列;#3 namespace-agnostic);CI-MM-4 守 | #3 namespace(additive)| code |
| **G-MM-7** | **2 新 UX pattern 入庫**:Share-Card(bounded screenshot-target + chrome-hide on capture)+ Screenshot-Share Affordance(native-screenshot prompt flow)→ `design/ux/interaction-patterns.md`(catalog Gaps 已預留「Avatar portrait frame — P5 Mirror Moment」slot)| UX pattern library | doc-only |

## Story breakdown directives(PR-EPIC degraded inline — binding)

1. **G-MM-1 做最早 doc story**(ADR-0008 tail amendment + project.godot 登記 = scaffold 前提;#29 tail after #26)。
2. **#26 coupled pair 先行**:#29 唔可獨立收線 —— `connect_for_initial_state` 訂 #26 signal、`get_evolution_snapshot()` 讀 snapshot 都要 #26 ship 先;mock-scoped #26 seam 可先行驗 gating logic(consumer-forward 先例),真接線喺 #26 epic 收口後。
3. **G-MM-3 default = 復用 LOOT preset**(B-1 HARD;新 preset 代價闊過 #26 R-5);SHARED 同 #26 G-AR-3,coupled pair 一齊決定 preset 策略。
4. **G-MM-4 cadence parity**:`MIRROR_CADENCE_SECONDS == #26.MILESTONE_CADENCE_SECONDS`,從 #26 source 註冊,CI-MM-3 code assert 守(唔 referrer-duplicate)。
5. **4 CI lint(CI-MM-1..4)早做**:CI-MM-1 zero-tier-compute 係 ADR-0010 命脈(同 #26 AC-30 對稱守 ownership seam 兩邊);CI-MM-2/3/4 隨 particle/cadence/persistence story。
6. **Formula stories(F1 arm-gate / F2 content-select)獨立 early**;timing test 用 injected clock `advance(delta_ms)`,persistence-consumer test 喺 `add_child` **前**注入 mock(reference_test_persistence_isolation)。
7. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊;memory ci_gate_command)。
8. **Story 總數 baseline 14–18**(>18 = scope creep 重審;<14 = AC force-compress 重審 — 薄 orchestrator,純 gating)。
9. **UX advisory carry**:header `Platform Target` field 補 + G-MM-7 2 新 pattern 入庫 + perf/resolution AC 補(present-latency)。

## Next Step

Run `/create-stories mirror-moment` to break this epic into implementable stories(建議 #26 epic 先收線,coupled pair 一齊推)。
