# Epic: Avatar Renderer(#26)

> **Layer**: Presentation(第六個亦最後一個 Presentation epic — Pillar 5 PRIMARY *render* substrate;#20 HUD / #21 Loot Modal / #22 Character / #23 Inventory / #24 Login-Shell 之後)
> **GDD**: design/gdd/avatar-renderer.md(✅ APPROVED 2026-06-10 — **Pass 6 fresh-session /design-review,8-pass saga 收線**;v2.1 = render-only fresh-template rewrite per ADR-0010;17 CR / 5+1 Formula / 28 EC / **33 AC(30 BLOCKING / 3 ADVISORY)** / 8 CI lint)
> **UX Spec**: design/ux/avatar-renderer.md(✅ APPROVED 2026-06-10 — /ux-review 0 BLOCKING / 4 ADVISORY;render-surface spec,4 互動 section 誠實 N/A-by-design;7 UX AC;Hero-Pose Shared-Asset Contract = ADR-0010 視覺 seam)
> **Architecture Module**: `AvatarRenderer` autoload @ `src/autoload/avatar_renderer.gd`(thin Node;持有 Character-Layer `AnimatedSprite2D`,internal z_index ∈ [-10,10];**零 mutation API** — visible state 純 derive from canonical data via `_derive_state_from_canonical()`;CR-6 anti-fabrication)。**唔開第二 autoload**,helper data resource `posture_config.tres`(posture×tier → SpriteFrames LUT)。Autoload 位置:insert after hard predecessors {#11 Stat / #12 Ability / #3 Persistence / #1 GSM / #5 Particle}(G-AR-1 ADR-0008 amendment;絕對位置由 project.godot + ADR-0008 owns,GDD 唔 hardcode 數字)
> **Status**: 🔧 In Progress(2026-06-10）— core derivation + bootstrap + read-only API + 3 CI lint **verified green**(30 GUT tests + 3 lints,local Godot 4.6.3）
> **Stories**: **19 stories** created;**story 001 ✅ Complete**。Implemented + GUT-green core(see active.md per-story status）:002 bootstrap / 003 F1 / 004 F2(AC-04 guard）/ 008 F4(AC-09/10）/ 010 F5-logic / 011 F3-logic / 013 F3b-logic / 014 snapshot+API(AC-13/CR-11）/ 015 sprite-resolve(AC-12 path）/ 017 partial(3/8 lint:AC-30 ownership 命脈 + CI-3 + CI-6）。**餘**:005 depth / 006-007 cast FSM / 009 EC-BOOT-3 / 010 SUSPENDED-wire / 012 milestone-tests / 016 particle / CI-1/2/4/5 / 018 doc / 019 playtest。Gate:`-gdir=res://tests/unit/avatar_renderer,res://tests/integration/avatar_renderer`。

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | G-AR-1 ADR-0008 autoload amendment + project.godot 登記 | Config/Data | ✅ Complete | ADR-0008 |
| 002 | Coordinator scaffold + autoload boot + cfis 4-subscription + bootstrap | Integration | Ready | ADR-0006/0008 |
| 003 | Formula 1 dominant_class derivation + class purity | Logic | Ready | ADR-0007 |
| 004 | Formula 2 evolution_tier (generalist+specialist symmetric, F-2 fix) | Logic | Ready | ADR-0011 |
| 005 | G-AR-2 max_class_depth resolution + EC-TIER-5 fail-safe | Integration | Ready | ADR-0011 |
| 006 | Animation FSM (IDLE/COMBAT/CAST) GSM-driven | Logic | Ready | ADR-0006 |
| 007 | Cast timing + 1-deep queue | Logic | Ready | N/A(pure timing) |
| 008 | Formula 4 posture hysteresis + workout-window lock | Logic | Ready | N/A(pure formula) |
| 009 | Persistence schema avatar.evolution_tier_history + boot counters | Integration | Ready | ADR-0003 |
| 010 | Formula 5 bfcache suspend/resume (pause() API) | Integration | Ready | ADR-0006/0001 |
| 011 | Formula 3 milestone two-gate + epoch-zero guard | Logic | Ready | N/A(pure formula) |
| 012 | Milestone emit + workout-defer (CR-15) + pending buffer never-drop | Integration | Ready | ADR-0010/0009 |
| 013 | Micro-evolution weekly delta (shader-only) | Integration | Ready | ADR-0009 |
| 014 | get_evolution_snapshot() + read-only API closure (#29 seam) | Integration | Ready | ADR-0010 |
| 015 | PostureConfig LUT + sprite resolution + EMERGENCY fallback + z-order + VRAM | Integration | Ready | ADR-0001 |
| 016 | Particle presets (#5) + mobile fallback (G-AR-3 preset 策略) | Integration | Ready | ADR-0001 |
| 017 | CI lint suite CI-1..6 + AC-29 schema + AC-30 zero-ceremony grep | Static-CI | Ready | ADR-0010 |
| 018 | G-AR-4 upstream doc errata (R-3) + G-AR-5 asset scope note | Config/Data | Ready | N/A |
| 019 | Silhouette / glance playtest evidence | Visual/Feel | Ready | N/A(ADVISORY) |

> **Implementation order**:001(scaffold 前提)→ 002(pipeline)→ formula stories(003/004/005 + 008/011 pure logic early)→ FSM(006/007)→ persistence/suspend(009/010)→ milestone(011/012/013)→ snapshot(014)→ sprite/particle(015/016)→ CI(017)→ doc/playtest(018/019)。**AC-04 specialist regression + AC-11 pause() regression + AC-09 REST_PERIOD drift + AC-08 epoch-zero + AC-30 zero-ceremony 係五個 must-not-regress guard**。

## Overview

實作 Mirror Hero 嘅 **Pillar 5 PRIMARY render substrate** ——「身體就係收據」。#26 將玩家真實訓練 derive 出嚟嘅 canonical data(stats / abilities / tier)render 成一個**0.3s 一眼可辨**嘅 avatar silhouette:class(silhouette mass)+ action-state(pose/anim)+ evolution-tier(mass 大小/definition)。**全部靠剪影,唔靠 palette**(FT-4:16×16 黑剪影 ≥80% classify class — palette-swap 被 art-director REJECTED,色盲下唔 legible)。

ADR-0010 將 Pillar 5 沿「**identity vs celebration**」一分為二:**#26 owns visible state + evolution-tier + sprite + snapshot/signal(render-only)**,**#29 Mirror Moment owns 慶典 composition**(9:16 portrait / hero-pose layout / ghost overlay / screenshot prompt / share)。#26 expose ceremony seam **只得** `get_evolution_snapshot() -> AvatarEvolutionSnapshot` + emit `avatar_evolution_milestone` / `avatar_micro_evolution` 兩個 signal —— **零 ceremony render code**(CR-17 / AC-30,CI-grep 守)。單向 dep #29→#26,#26 對 #29 一無所知。

核心 anti-drift 機制 = **Representation Map**(每個 const/formula/API fact + 佢出現嘅每個 site 嘅 single source of truth;Pass-5/6 靠 grep 驗)。Formula 2 tier derivation 用**兩條對稱獨立路徑**:generalist(stat sum `S_t` + ability breadth `A_t`)OR specialist(peak_stat `S_peak_t` + class depth `D_t`)—— specialist 唔再經 sum gate(4-pass-surviving F-2 defect 嘅真修復;AC-04 驗 pure-STRIKE→T3)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0010**: Mirror Moment Ceremony Ownership Split | render-vs-ceremony seam:#26 owns visible-state/tier/sprite/snapshot/signal(render-only),#29 owns 慶典 composition;**單向 #29→#26**;CR-17 + AC-30 grep 守 #26 零 ceremony code | LOW(Accepted 2026-06-10,coupled pair ratified)|
| **ADR-0001**: Web Export Budget Caps | CanvasLayer topology:Character layer 10(`Z_INDEX_CHARACTER_LAYER`,LOCKED)/ Particle layer 20;avatar `z_index=0` internal [-10,10],NEVER raw >50(CR-7);sprite draw-call + atlas budget;bfcache 30s parity(Formula 5)| **HIGH**(Compatibility/WebGL2 — sprite/atlas/VRAM domain;Web-runtime VRAM accuracy → Q-OQ-VRAM VS-gated)|
| **ADR-0003**: Save State Strategy | `avatar.*` namespace(`avatar.evolution_tier_history` / `last_emitted_tier`,CR-12);IPersistence;900ms migration;Private Mode EC-BOOT-1(suppress milestone/micro emits 防 dup)| LOW |
| **ADR-0006**: State Machine Contract | Contract 4 sequential boot(#26 `_ready()` 在 predecessors 後)+ Contract 6 `connect_for_initial_state`(4 subscriptions boot 即收 current,AC-16)| LOW |
| **ADR-0008**: Autoload Position Map | **G-AR-1 insertion amendment 待做**(本 epic story)— `AvatarRenderer` insert after {#11/#12/#3/#1/#5};絕對位置 = project.godot + ADR-0008 ground truth(GDD 唔 hardcode 數字 — v1 hardcode「pos 11」錯咗)| LOW |
| **ADR-0011**: PR Detection Topology | client-side derivation pattern:`max_class_depth` client-derived from `get_unlocked_abilities()` keys(non-server,deterministic);(class,tier)-of-ability_id resolution = **G-AR-2 Q-OQ-DEPTH** forward dep on #12 | LOW |
| **ADR-0007**: Class Enum Convention | `AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN}`;dominant_class derive STRIKE=argmax(STR)/CONTROL=argmax(DEX)/MOBILITY=argmax(VIT),tie-break STRIKE>CONTROL>MOBILITY(CR-3/CR-16)| LOW |
| **ADR-0009**: Signal Payload Schema | `avatar_evolution_milestone(tier, source_metrics)` / `avatar_micro_evolution(delta_kind, source_metrics)` payload minimal+intrinsic;source_metrics envelope | LOW |

## GDD Requirements

> #26 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#18/#21/#22/#23/#24 先例一致)。Requirements 由 GDD 直接 trace:**17 Core Rules + 5+1 Formula(F1 class-derive / F2 tier-derive 兩對稱路徑 / F3 show_ghost / F4 bfcache-action / F5 suspend-restore + micro-cadence helper)+ 28 ECs + 33 ACs + 8 CI lint**,全部有 Accepted ADR cover(上表)+ **5 個 cross-system gate G-AR-1..5**。UX 層另加 **7 UX AC**(silhouette readability / hero-pose composability / reduced-motion / render-purity)。

**Untraced requirements**: None(G-AR gates 係 cross-system amendment/forward-dep/scope-gate,非 untraced ADR-gap;ADR-0010 為 #26 量身 Accepted;TR-ID granularity 留 /architecture-review batch)。

**AC 分佈(GDD 33)**:**30 BLOCKING**(13 unit + 9 integration + 8 static-analysis)+ **3 ADVISORY**(manual playtest:AC-31 glance FT-1 / AC-32 silhouette FT-4 / AC-33 FT-5)。**8 CI lint**(CI-1 mutation-boundary / CI-3 no-setter-API / CI-5 class-derivation-purity / CR-17 zero-ceremony grep[AC-30]等)。**+ UX 7 AC**(AC-UX:5 playtest-measure[glance/silhouette/tier-delta/hero-pose/reduced-motion] / 2 static[no-cutscene/render-purity])。**FT-2 share-rate 唔屬 #26 — 由 #29 owns**(ADR-0010)。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **33 GDD ACs verified**:30 BLOCKING 全過(13 unit + 9 integration + 8 static-CI)+ 3 manual ADVISORY 有 evidence @ `production/qa/evidence/avatar-renderer/`(AC-31/32/33 playtest — silhouette quiz 可 desaturated screenshot 驗)
- **7 UX AC verified**(5 playtest-measure / 2 static)
- **8 CI lint green**:CI-1 mutation-boundary + CI-3 no-setter-API + CI-5 class-derivation-purity + **AC-30 CR-17 zero-ceremony grep**(`src/autoload/avatar_renderer.gd` + `src/ui/avatar*` → 零 9:16 canvas / ghost-compositing / screenshot prompt / share UI)+ 其餘
- `AvatarRenderer` 登記 `project.godot`(G-AR-1)+ ADR-0008 amendment merged
- **F-2 真修復驗證**:AC-04 pure-STRIKE specialist 路徑 → T3(唔經 sum gate);Formula 2 兩對稱路徑各自可達 tier-up
- **Anti-fabrication 驗證**(CR-6):每個 `AvatarVisualState` visible field 有 `derived_from` source attribution,無 source = unit fail
- G-AR-1..5 全部執行(各自 evidence 喺對應 story 收口;G-AR-5 asset scope 由 /asset-spec 收)
- Test evidence:unit `tests/unit/avatar_renderer/` / integration `tests/integration/avatar_renderer/`

## Cross-system gates(G-AR-1..5 — 全部係本 epic 內 stories;#21 G-LM / #22 G-CS / #24 G-LS 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-AR-1** | ADR-0008 insertion amendment:`AvatarRenderer` insert after {#11/#12/#3/#1/#5}(hard predecessors)+ `project.godot` 登記 | ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-AR-2** | **Q-OQ-DEPTH:(class,tier)-of-ability_id resolution for `max_class_depth`**(specialist path D_t)— #12 additive read `get_ability_class_tier(ability_id)` OR client-side LUT(ADR-0011 client-derive);**EC-TIER-5 fail-safe → depth 0**(generalist path 仍 work)| #12 forward-dep(additive — #23 G-IU-1 / #24 G-LS-4 consumer-forward 先例)| code(default:client-side LUT,免 #12 churn)|
| **G-AR-3** | **#5 preset coupling(R-5 / FC-6)**:若 #26 加新 PresetId(cast/evolution micro burst)→ 須 #5 amendment **兩件**(enum 9→N **加** PRESET_TABLE entry + amend 2 硬 `PRESET_TABLE.size()==9` test [test_preset_library:20 / test_pool_tier_selection:58]);**SHARED 同 #29 G-MM-3**。Default:盡量復用既有 preset,免 closed-set-of-9 coupling | #5 erratum(若加 preset)| code(**default 復用,scope gate 先審**)|
| **G-AR-4** | 上游 doc errata(R-3):#11 GDD L261 / #12 GDD L227 downstream-framing errata(描述 #26 嘅措辭 stale)— cross-file doc cleanup | #11/#12 doc errata | doc-only(#23 story-018 / #24 G-LS-9 errata-cluster 先例)|
| **G-AR-5** | **Asset scope gate(Q-OQ-ASSET)**:36 sprite sheets(4 tier × 3 class × 3 anim)+ 12 hero-pose stills,solo-dev throughput;palette-swap REJECTED(silhouette-mass required for FT-4);Q-UX-HEROPOSE(dedicated still vs idle-frame index)| art-director + /asset-spec | **pre-`/create-stories` scope gate**(art pipeline;唔 block code stories,但 visual AC 需 asset 落地)|

## Story breakdown directives(PR-EPIC degraded inline — binding)

1. **G-AR-1 做最早 doc story**(ADR-0008 amendment + project.godot 登記 = scaffold 前提;autoload 位置要 ADR 授權先寫 project.godot)。
2. **Formula stories(F1 class-derive / F2 tier-derive 兩對稱路徑)獨立 early**;**F-2 specialist path 必有獨立 AC-04 pure-STRIKE→T3 驗證**(4-pass-surviving defect 真修復,唔可再經 sum gate)。
3. **G-AR-2 default = client-side LUT**(EC-TIER-5 fail-safe → depth 0,免 #12 churn);若揀 #12 additive API 則 mock-scoped 先行(consumer-forward 先例)。
4. **G-AR-3 default = 復用既有 #5 preset**;新 preset 須喺 scope gate 先審(closed-set-of-9 coupling 代價:enum + table + 2 硬 size==9 test 同步 amend)。SHARED 同 #29 G-MM-3 —— coupled pair 一齊決定。
5. **CR-17 / AC-30 zero-ceremony grep story 早做**(render-only boundary 係成個 ADR-0010 epic 嘅命脈;CI-grep `src/autoload/avatar_renderer.gd` + `src/ui/avatar*` 零 ceremony composition)。
6. **N-1 / N-2 advisory fold-in**:CR-5「two-gate」label 對齊 3 sub-gate(N-1);INV-2 timing assert 補 AC pin(N-2)。
7. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊 — 跨 file bug 防;memory ci_gate_command)。
8. **Story 總數 baseline 16–20**(>20 = scope creep 重審;<16 = AC force-compress 重審)。
9. **UX advisory carry**:header `Platform Target` field 補(spec)+ Hero-Pose Shared-Asset Contract 喺 /asset-spec 落地(G-AR-5)。

## Next Step

Run `/create-stories avatar-renderer` to break this epic into implementable stories。
