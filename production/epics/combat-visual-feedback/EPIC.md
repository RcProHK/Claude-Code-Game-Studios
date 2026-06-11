# Epic: Combat Visual Feedback(#25)

> **Layer**: Presentation(第七個 Presentation epic — Pillar 3 *per-hit reaction* presentation 載體;#20 HUD / #21 Loot Modal / #22 Character / #23 Inventory / #24 Login-Shell / #26 Avatar 之後)
> **GDD**: design/gdd/combat-visual-feedback.md(✅ APPROVED 2026-06-11 — `/design-review` degraded-inline + grep-verify;NEEDS REVISION → revise-now → APPROVED 同 session;20 Rules / 5 Formula / 20 EC / 17 knobs / **35 ACs** / 7 OQ;1 BLOCKING + 9 RECOMMENDED 全 resolved,0 phantom)
> **UX Spec**: design/ux/combat-visual-feedback.md(✅ APPROVED 2026-06-11 — `/ux-review` 0 BLOCKING / 4 ADVISORY;output-only diegetic render-surface spec,Navigation/Entry-Exit/Interaction Map/Events 誠實 N/A-by-design[零玩家 input];8 UX AC + 8 OQ;與 avatar-renderer.md 先例一致)
> **Architecture Module**: `CombatVisualFeedback` autoload @ `src/autoload/combat_visual_feedback.gd`(event-driven reactive coordinator,near-stateless;`PROCESS_MODE_ALWAYS`)。持有兩個 #25-owned CanvasLayer:**`CombatNumberLayer`**(`follow_viewport_enabled=true`,sort 坐 ParticleLayer[10] 上 / HUDLayer[50] 下,**入 #6 world-shake shader-uniform 範圍**)+ **`CombatOverlayLayer`**(105,全屏,>100 shake/BBCopy-immune,<110 loot 永遠蓋過)。damage-number = 預生 `Label` object pool(`_process` 自管 rise+fade,**無 per-label Tween / 無 runtime alloc**);overlay = `ColorRect` + analytic shader(無 texture asset,single-instance latest-wins)。**所有 particle 經 #5 `play()`、所有 shake 經 #6 auto-dispatch、hit_pause 經 #6 direct call —— 從不 `new GPUParticles2D()` / mutate Camera2D**(ADR-0001 forbidden)。Autoload 位置 = **tail-append after {#14 / #6 / #5 / #1}**(G-CV-2 ADR-0008 amendment;非 disruptive tail,唔 shift 現有 autoload;絕對位置由 project.godot + ADR-0008 owns,GDD 唔 hardcode 數字)
> **Status**: ✅ IMPLEMENTED(2026-06-11 — 17/17 stories Complete,single-session full-autonomous run)
> **Stories**: **17 stories** ✅ ALL COMPLETE(5 Logic / 7 Integration / 4 Config-Data / 1 Visual-Feel)。Gate:cvf suite green(unit+integration+static)+ 3 #25 CI lint exit 0 + full combined gate 0 fail。3 must-not-regress guard 全落地(FR Test #4 / R-13 no-shake / critical-kill carve-out AC-30)。external/deferred:AC-24 overlay ratification + AC-28 mobile P95(both `pending()` honest)+ UX-02/03/05 art-director sign-off(human gate)+ playtest evidence

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | G-CV-2 ADR-0008 autoload amendment + project.godot | Config/Data | ✅ Complete | ADR-0008 |
| 002 | G-CV-1 ADR-0001 2-CanvasLayer topology amendment | Config/Data | ✅ Complete | ADR-0001 |
| 003 | Coordinator scaffold + cfis sub + bootstrap + lifecycle | Integration | ✅ Complete | ADR-0006/0008 |
| 004 | R-2/R-3 routing core: outcome-gate + FR Test #4 tier | Logic | ✅ Complete | ADR-0007/0009 |
| 005 | R-7/R-8 HEAVY/CRITICAL + F4 hit_pause + R-13 guard | Logic | ✅ Complete | ADR-0009/0001 |
| 006 | R-9/R-10 kill branch + critical-kill carve-out | Logic | ✅ Complete | ADR-0009 |
| 007 | R-12 dual-axis decoupling (is_crit vs CRITICAL-tier) | Logic | ✅ Complete | ADR-0009 |
| 008 | R-14 dedup + R-15 coalescing F3 + evict + FakeClock | Logic | ✅ Complete | ADR-0009 |
| 009 | F1 number rise+fade + R-19 Label pool (no Tween/alloc) | Integration | ✅ Complete | ADR-0001 |
| 010 | G-CV-1 overlay primitive F2 latest-wins + EC-20 degrade | Integration | ✅ Complete | ADR-0001 |
| 011 | F5 anchor camera-relative focal (#26 non-dep) | Integration | ✅ Complete | ADR-0001 |
| 012 | Lifecycle Suspended reset + bfcache clear + delta clamp | Integration | ✅ Complete | ADR-0006/0001 |
| 013 | a11y motion_intensity + colorblind + input non-interf | Integration | ✅ Complete | ADR-0001 |
| 014 | G-CV-3 #4 AudioManager cue contract (consumer-forward) | Integration | ✅ Complete | ADR-0009 |
| 015 | G-CV-4 pattern lib sync P-10 + 新 combat-climax-flash | Config/Data | ✅ Complete | N/A(doc) |
| 016 | G-CV-5 registry 17 knobs + dual-critical reconcile | Config/Data | ✅ Complete | N/A(data) |
| 017 | Peripheral legibility + tone playtest evidence | Visual/Feel | ✅ Complete | N/A(ADVISORY) |

> **Implementation order**:001+002(scaffold 前提:autoload + CanvasLayer amendment)→ 003(coordinator pipeline)→ routing(004 core → 005 HEAVY/CRITICAL → 006 kill carve-out → 007 dual-axis → 008 coalesce/dedup)→ render(009 number pool → 010 overlay → 011 anchor)→ 012 lifecycle → 013 a11y → 014 audio → doc(015 pattern / 016 registry,可 parallel)→ 017 playtest。**三 must-not-regress guard**:FR Test #4(AC-02,story 004)/ critical-kill carve-out(AC-30,story 006)/ R-13 double-shake grep(AC-11,story 005)。

## Overview

實作 Mirror Hero 嘅 **Pillar 3 per-hit reaction 層** —— 將抽象 combat resolution event 轉化成 peripheral-glance 之下嘅「DNF 重擊」感官回報。#25 subscribe #14 EnemyDirector 嘅 `hit_resolved` / `enemy_killed` signal,讀已判定嘅 `damage_tier` / `outcome` field,編排:(1)tier→particle preset routing(經 #5,`HIT_LIGHT` / `HIT_HEAVY`);(2)hit-pause 凝固(direct call #6 `hit_pause` **填 #6 auto-dispatch 對 HIT_HEAVY/DEATH 嘅 `pause=0` 缺口**;#25 **絕不** direct shake — shake 由 #6 auto-dispatch 提供,R-13 guard);(3)floating damage number(world-anchored Label pool);(4)CRITICAL/OVERKILL/critical-kill flash overlay。

**最關鍵 contract 約束(FR Test #4,inherit 自 #13)**:#25 **必須消費 payload 嘅 `damage_tier`** 作 routing key,**唔可**根據 raw damage value re-classify —— 確保 VFX 強度同 combat 判定永遠一致。#25 **唔 own 任何 combat 數學**(#13 CombatResolver pure static)、**唔 own entity-lifecycle VFX**(enemy spawn/death/boss = #14 自己 direct call)。純粹係「已判定命中之上嘅反應皮層」;缺席 = graceful degrade(combat 照 resolve,只係靜默 — Pillar 2 仍 work,Pillar 3 spectacle 缺席)。

**Player Fantasy 命脈(load-bearing)= 「Foveal punch, Peripheral pulse」**:tier escalation **必須走 peripheral channel**(hit-pause 定格時長 + 全屏 flash),**唔靠** number size/color(眼角讀唔到)。「稀疏即重量」—— 大部分 hit 安靜(floor),只有少數 climax 郁全屏(peak)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0001**: Web Export Budget Caps | **本 epic amends(G-CV-1)**:兩個 #25-owned CanvasLayer — `CombatNumberLayer`(follow-viewport,sort 10-50,入 world-shake uniform 範圍)+ `CombatOverlayLayer`(105,>100 immune,**唔入** BBCopy capture list,須明寫防 phantom-citation)。200 particle cap 全局共享(#25 coalescing 自律,唔自管預算)+ overlay ≤1 blend pass + bfcache resume clear。跟 #5/#6/#21-#24/#26 layer-amendment 先例 | **HIGH**(Compatibility/WebGL2 — CanvasLayer topology + overlay shader + mobile fillrate + bfcache;ratification-gated AC-24/EC-20 degrade) |
| **ADR-0009**: Signal Payload Schema | 消費 `hit_resolved(HitResolvedPayload)` — intrinsic field(`damage_tier`/`outcome`/`is_crit`/`target_id`/`transition_id`,**無 position**)+ `transition_id`;Foundation-consumer never-throw(`#5.play()→INVALID` fail-soft)| LOW |
| **ADR-0008**: Autoload Position Map | **G-CV-2 insertion amendment(本 epic story)**:`CombatVisualFeedback` tail-append after preds {#14 / #6 / #5 / #1};絕對位置 = project.godot + ADR-0008 ground truth(非 disruptive tail,類 #29 MirrorMomentCoordinator)| LOW |
| **ADR-0006**: State Machine Contract | Contract 4 sequential boot(`_ready()` 在 predecessors 後)+ Contract 6 `connect_for_initial_state`(#14 + #1 GSM subscription boot 即收 current)+ `PROCESS_MODE_ALWAYS`(EC-15:hit_resolved 喺 #6 HitPaused 期間照收;number/overlay `_process` 照 tick)| LOW |
| **ADR-0007**: Class Enum Convention | 消費 `DamageTier {NEGLIGIBLE,LIGHT,MEDIUM,HEAVY,CRITICAL}` + `HitOutcome {NORMAL_HIT,CRITICAL_HIT,KILLED,OVERKILL}`(#13 owned Classification family;`T_CRITICAL=0.40` + crit-override≥HEAVY)— #25 read-only 消費,唔定義新 enum | LOW |

## GDD Requirements

> #25 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#21/#22/#23/#24/#26 先例一致)。Requirements 由 GDD 直接 trace:**20 Core Rules(R-1..R-20)+ 5 Formula(F1 number rise+fade / F2 overlay decay / F3 coalescing gate / F4 tier→pause lookup / F5 anchor+jitter)+ 2 lifecycle sub-state(Active/Suspended)+ overlay primitive(IDLE/FLASHING)+ 20 ECs + 17 knobs + 35 ACs**,全部有 Accepted ADR cover(上表)+ **5 個 cross-system gate G-CV-1..5**。UX 層另加 **8 UX AC**(peripheral legibility / tier 區分 / input non-interference / a11y motion / colorblind greyscale / lifecycle / l10n)。

**Untraced requirements**: None(G-CV gates 係 cross-system amendment / forward-dep / pattern-sync / scope-gate,非 untraced ADR-gap;ADR-0001 amendment 為 #25 兩 layer Accepted-pending-ratify;TR-ID granularity 留 /architecture-review batch)。

**AC 分佈(GDD 35)**:**≈30 BLOCKING**(1 integration[AC-01 subscription]+ ~27 unit[routing R-2..R-15 + Formula F1/F2/F4 + carve-out AC-30 + coverage AC-31..34 + a11y AC-25]+ 2 static-CI[AC-11 no-direct-shake grep / AC-29 no-GPUParticles/Tween/Timer grep])+ **≈5 ADVISORY/GATED**(AC-24 ratification-gated[overlay flash 真渲染]+ AC-26/27 visual[peripheral legibility / tone]+ AC-28 perf[CI-testable 三項 + mobile-Safari P95 hardware-gated])。**+ UX 8 AC**(UX-01 perf / UX-02 peripheral-purpose / UX-03 tier 區分 / UX-04 motion a11y / UX-05 colorblind greyscale / UX-06 input non-interference / UX-07 lifecycle / UX-08 l10n)。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **35 GDD ACs verified**:~30 BLOCKING 全過(1 integration + ~27 unit + 2 static-CI)+ ADVISORY 有 evidence @ `production/qa/evidence/combat-visual-feedback/`;AC-24(ADR ratify)+ AC-28(mobile P95)= **`pending()` gated-honesty,唔可 auto-pass 假綠**
- **8 UX AC verified**(UX-02/03 art-director sign-off peripheral;UX-04/05/06 可 CI/spy 驗;UX-07 bfcache;UX-08 l10n)
- **R-13 double-shake guard CI-green**(AC-11:grep `src/autoload/combat_visual_feedback.gd` 確認**零** `ScreenEffects.shake(` — 只准 `.hit_pause(`)+ **AC-29**(零 `GPUParticles2D.new()` / per-label `Tween` / `Timer.new()`)
- **FR Test #4 驗證**(AC-02):`damage_tier=HEAVY, damage_dealt=1` 仍 route `HIT_HEAVY`(信 tier,唔 re-classify by value)
- **招牌 carve-out 驗證**(AC-30 / R-9):`KILLED + damage_tier=CRITICAL` → flash + `hit_pause(0.080)`(「一刀 CRITICAL 劈死」spectacle 可達,非只 OVERKILL)
- **#26 anchor 唔係 MVP dep**(grep 證實 render-only 無 position API);MVP 用 camera-relative fixed focal point(R-17/F5 primary,AC-18)
- `CombatVisualFeedback` 登記 `project.godot`(G-CV-2)+ ADR-0008 amendment merged
- G-CV-1..5 全部執行(各自 evidence 喺對應 story 收口)
- Test evidence:unit `tests/unit/combat_visual_feedback/` / integration `tests/integration/combat_visual_feedback/`;**injectable FakeClock**(F3/dedup time-dependent,唔靠 real `Time.get_ticks_msec()`)

## Cross-system gates(G-CV-1..5 — 全部係本 epic 內 stories;#21 G-LM / #22 G-CS / #24 G-LS / #26 G-AR 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-CV-1** | **ADR-0001 amendment — 兩個 #25-owned CanvasLayer**:(a)`CombatNumberLayer`(`follow_viewport_enabled`,sort 10-50,**入** world-shake shader-uniform 範圍 → 跟 world shake;確認接駁 vs reparent)+ (b)`CombatOverlayLayer(105)`(>100 immune,**唔入** BBCopy capture list,須明寫防 phantom-citation,[[feedback_lint_allowlist_adr_sync]]);ratification-gated(AC-24);未 ratify → overlay degrade(無 flash,`CRITICAL_DEGRADE_PAUSE_SEC=0.100` 補償)+ number fixed-viewport | technical-director + ADR-0001 owner | doc + ratification-gated(**scaffold 前提**)|
| **G-CV-2** | **ADR-0008 insertion amendment**:`CombatVisualFeedback` tail-append after preds {#14 / #6 / #5 / #1} + `project.godot` 登記(非 disruptive tail,類 #29)| ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-CV-3** | **#4 AudioManager combat-hit cue 契約(Q-CV1)**:tier→cue map(HEAVY thud / CRITICAL chime / OVERKILL impact / kill)+ onset 對齊 visual peak + cue catalog ownership(#25 trigger / #4 playback;**consumer-forward** per #4 EG-1 audio-trigger consumer);silent-mode 下 visual 必須獨立完整可讀 | audio-director + #4 owner | code(consumer-forward;cue catalog errata 隨 gate)|
| **G-CV-4** | **Pattern library sync(UX UXQ-P10-SYNC + UXQ-NEWPATTERN)**:(a)sync **P-10 damage-number-popup** 至 APPROVED #25 GDD(cap 6→12 / spawn-at-hit→camera-focal / overshoot→Formula 1 rise+fade / 移除 family-color / **tier 唔靠 number**)+ (b)加新 **combat-climax-flash**(建議 P-19;全屏 single-instance latest-wins luminance pulse,×motion_intensity,layer 105,無 texture)入 `interaction-patterns.md` | ux-designer | doc-only(G-CS-6 / G-LM-7 pattern-sync 先例)|
| **G-CV-5** | **registry 註冊(Q-CV7)**:#25 17 owned knobs 入 `entities.yaml` + **dual-critical disambiguation note**(`DamageTier.CRITICAL` ratio ≥40% maxHP **≠** `is_crit` roll;R-12 雙軸解耦)+ shipped-routing 對賬 note(reconcile registry 早期 aspirational「MEDIUM 0.2 / HEAVY 0.4 / CRITICAL 0.6 trauma」vs #25 真實 binary routing[MEDIUM=HIT_LIGHT 無 shake;HEAVY+CRITICAL 共用 HIT_HEAVY auto 0.4])| #25 owner | config/data |

## Story breakdown directives(PR-EPIC degraded inline — binding;producer assessment = REALISTIC)

1. **G-CV-2 做最早 doc/config story**(ADR-0008 amendment + project.godot 登記 = scaffold 前提;autoload 位置要 ADR 授權先寫 project.godot)。**G-CV-1 ADR-0001 amendment 亦 scaffold 前提**(兩 CanvasLayer 拓撲 + ratification gate;number-layer ratify 前 fixed-viewport degrade,overlay ratify 前 EC-20 degrade)。
2. **Coordinator scaffold + cfis 2-subscription(#14 hit_resolved/enemy_killed + #1 GSM)+ bootstrap(AC-01)早做**;`PROCESS_MODE_ALWAYS` + lifecycle Active/Suspended(EC-08/15)。
3. **Routing stories 按 R-3 outcome-first gate 拆**:tier 分支(R-4..R-8 + R-12 雙軸解耦)/ kill 分支(R-9 含 **CRITICAL carve-out** + R-10 OVERKILL)/ R-13 double-shake guard + R-14 dedup + R-15 coalescing(含 enemy_killed evict F3 dict 防 leak)。**FR Test #4(AC-02)+ carve-out(AC-30)+ R-13 grep(AC-11)係三個 must-not-regress guard**。
4. **Formula stories 獨立 early**(F1 number / F2 overlay decay / F4 tier→pause lookup 純函數;F3 coalescing 需 **injectable FakeClock**;F5 anchor = **camera-relative fixed focal point primary**,#26 anchor grep 證偽 → v0.2-only,AC-18 驗 MVP path)。
5. **G-CV-1 overlay primitive story(IDLE/FLASHING latest-wins + EC-20 degrade)**:ratification-gated AC-24 用 `pending()` honesty,degrade 行為(AC-07b)係 CI-testable。
6. **Damage-number pool story(R-19)**:`Label` pool acquire/release + `_process` 自管 rise/fade,**無 Tween / 無 runtime alloc**(AC-29 grep 守);`CombatNumberLayer` host(G-CV-1)。
7. **a11y story**:motion_intensity gate overlay(AC-25 — =0 → 無 flash + 無 shake,**hit_pause 保留**)+ colorblind greyscale(UX-05)+ WCAG 2.3.1。
8. **G-CV-3 #4 cue 契約 mock-scoped 先行**(consumer-forward;audio-trigger consumer per #4 EG-1)。**G-CV-4 pattern-sync + G-CV-5 registry = doc/config stories**(可 parallel,doc-only)。
9. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊 — 跨 file bug 防;[[feedback_ci_gate_command]])。
10. **Story 總數 baseline 14–18**(>18 = scope creep 重審;<14 = AC force-compress 重審)。
11. **UX advisory carry**:UX-02/03 peripheral legibility 需 art-director sign-off(playtest evidence);bounce reduced-motion(advisory)無硬 AC pin。

## Next Step

Run `/create-stories combat-visual-feedback` to break this epic into implementable stories。
