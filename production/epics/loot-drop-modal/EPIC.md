# Epic: Loot Drop Modal (#21)

> **Layer**: Presentation(第二個 Presentation epic;首個 Pillar 3 presentation surface)
> **GDD**: design/gdd/loot-drop-modal.md(✅ APPROVED 2026-06-06 Pass 3 — 三 pass 同 session 收斂,0 phantom)
> **UX Spec**: design/ux/loot-drop-modal.md(✅ APPROVED 2026-06-06 — 0 blocking / 3 advisory;stories 引用 UX spec,唔直接 cite GDD UI 細節)
> **Architecture Module**: `LootRevealCoordinator` autoload @ `src/autoload/loot_reveal_coordinator.gd`(thin Node;`_ready` instantiate + 持有 `ModalLayer`(CanvasLayer 120)+ `CelebrationVFXLayer`(CanvasLayer 110)— >100 層 single owner,layer 數值 ground truth 屬 G-LM-1 ADR-0001 revision)。Autoload 位置:tail append 喺 ZoneSystem 後(#28 keep last)— G-LM-5 ADR-0008 amendment;predecessor constraints `{#15, #1(C6), #33, Camera, ScreenEffects, Particle, Audio, PlatformDetect} ≺ #21`
> **Status**: Ready
> **Stories**: **27 created**(1 Config/Data + 21 Logic + 4 Integration + 1 Visual/Feel;baseline 22–28 內)— QL-STORY-READY degraded inline ADEQUATE(spawn blocked 1M-context credits,#17/#18 同款;GDD 94 ACs 3-pass verified GWT = qa-plan-import-equivalent,story 直接 embed)
> **Producer gate (PR-EPIC)**: **CONCERNS → adjustments 採納**(2026-06-07 full-mode spawn)— 維持單一 epic(gate-inside-epic pattern,#17/#18 grep 實證先例;「gates epic」係 dependency-epic anti-pattern);story 估算 re-baseline **22–28**(18–22 係 force-compress 訊號 — AC density 唔可以超歷史值 ~2.6/story 兩倍);4 項 binding structural directives 見下文「Story breakdown directives」

## Overview

實作 Mirror Hero 嘅 **Pillar 3 signature presentation surface** — ceremonial reveal modal,將 #15 LootDropSystem 每件 FULL_CEREMONY loot 兌現成「值得截圖」嘅 flashbulb moment。GSM `LOOT_DROP` entry 係唯一開 modal trigger(`connect_for_initial_state` — ADR-0006 C6);#15 reveal queue 係 content source of truth(pull model);#21 只 own choreography sequencing(S0–S4 五段 pipeline、8-state FSM + `in_catchup` flag、D2 freeze-as-hold ladder 調用序)+ modal UI 本身。**INV-M3**:S3 = 唯一 banking + dequeue commit point(`receive_loot()` @ S3,tap 純 ceremonial);**INV-M1**:所有 cancel path 經單一 idempotent freeze-release 出口(time-stop dangling = 全 game 凍結,最高危 failure mode);**INV-M2**:RARE+ breakdown bar(ADR-0005 75/25 binding 可視化)workout 段嚴格大過 RNG 段。同時 own micro_ack toast(F4 aggregation + safe-state flush gate)、catch-up contact-sheet mode(stream + top-K ceremonies + grid,F3 provable bound 15.8s)、banner stack、force-close pre/post-S3 split(D1 cancel+re-reveal vs stash-exit)。冇 #21,loot 只係 silent data row — MVP hypothesis 成敗直接繫於本系統。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0001**: Web Export Budget Caps | CanvasLayer topology + particle caps(LOOT_RARE_BURST 3× ceiling);**G-LM-1 revision 對象**(CelebrationVFXLayer 110 / ModalLayer 120 + viewport residence + 8% blur 第二次 BackBufferCopy priced fallback) | **HIGH**(Compatibility/WebGL2 rendering) |
| ADR-0005: Loot Rarity Formula | 75/25 公式 — F2 breakdown bar 係 binding 可視化;rarity 計算 #15 own,#21 唔 re-derive | LOW |
| ADR-0006: State Machine Contract | C4 sequential boot;C6 `connect_for_initial_state`(AC-6 boot force-reveal);GSM exit 行 #15 `loot_confirmed` chain(zero-direct-call) | LOW |
| ADR-0007: Class & Domain Enum Convention | RarityTier classification enum;EC-M5 `RarityTier.get(s, COMMON)` coercion 同 #17 同源 | LOW |
| ADR-0008: Autoload Position Map | **G-LM-5 insertion amendment 待做**(本 epic story)— tail append ZoneSystem 後,#28 keep last | LOW |
| ADR-0009: Signal Payload Schema | `modal_dismissed(drop_id, terminal)` minimal+intrinsic;telemetry 6 hooks payload | LOW |
| ADR-0003: Save State Strategy | #21 **stateless presentation — 零 persistence 寫入**(reveal pending 係 #15 + GSM own);約束性引用 | LOW |

## GDD Requirements

> #21 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#18 先例一致)。Requirements 由 GDD 直接 trace:**15+13b Core Rules + 3 named invariants(INV-M1/M2/M3)+ D1–D5 CD 裁決 + 6 Formulas(F1–F6)+ 20 Edge Cases(EC-M1–M20)+ 8-state FSM × in_catchup + 94 ACs + 6 telemetry hooks**,全部有 Accepted ADR cover(上表)。

**Untraced requirements**: None(TR-ID granularity 留 /architecture-review batch)。

**AC 分佈**:71 unit Logic(BLOCKING)/ 9 Integration(BLOCKING — 全 gated)/ 3 Static-CI(AC-21 owner-exempt lint / AC-79 boot order / AC-76b process-mode property)/ 10 Manual(ADVISORY)/ 1 mapping(AC-35)。**23 條 gated ACs** 全部有 #21-side fake-seam 先行斷言(gate-tag 準則:斷言外部 API shape → gated;純 #21-side 行為 over fake → ungated)。**G-LM-2 無獨立 gated key**(AC-75/87 joint gate G-LM-1+2 — story-readiness grep 要記得)。

## Cross-system gates(G-LM-1..10 — 全部係本 epic 內 stories;#18 G-PR-* 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-LM-1** | ADR-0001 revision:CelebrationVFXLayer(110, ALWAYS, follow_viewport)+ ModalLayer(120, ALWAYS);>100 = BackBufferCopy capture 外;viewport residence 釘實;8% blur = 第二次 framebuffer copy priced 或 opacity-only fallback | ADR-0001 | doc-only |
| **G-LM-2** | #5 amendment:LOOT pool nodes reparent 入 CelebrationVFXLayer + per-slot `PROCESS_MODE_ALWAYS`;reparent 時序 = post-#21-boot handshake(`register_celebration_layer(layer)`,idempotent) | #5 `particle_system_wrapper.gd` | code(G-LM-1 後) |
| **G-LM-3** | #6 amendment(**最大單一 gate,最高 regression risk**):① 新 `ceremony_freeze(duration)`(`CEREMONY_FREEZE_MAX_SEC=0.4`,唔受 `MAX_PAUSE_SEC=0.12` 管)② freeze 記帳 scalar→per-entry ledger 重構 ③ 新 idempotent `release(handle)` ④ saturation API 全新(shipped 零實現)⑤ 繼承 Suspended 安全網 ⑥ `hit_pause` ledger 隔離 | #6 `screen_effects.gd` | code(**producer 指令:拆 2 stories**) |
| **G-LM-4** | #15 reverse-wire(**critical path**):① revealed-state/sync-state 分離 ② ceremony kind 持久化 ③ `modal_dismissed` handler(drop_id dequeue)④ terminal → `loot_confirmed` ⑤ `report_receive_failure(drop_id)` ⑥ defer retry-suppression + GSM-side wiring(`_check_pending_loot_reveal` 零 caller)⑦ #4 catalog source sync ⑧ fast-victory marker 持久化(`BossPayload.outcome` → record) | #15 `loot_drop_system.gd` + GSM wiring | code(**producer 指令:拆 2–3 stories**) |
| **G-LM-5** | ADR-0008 insertion + `project.godot` 登記 | ADR-0008 | doc + config |
| **G-LM-6** | `platform_detect.gd` 新增 `announce_aria(text)` gateway(boot inject hidden `aria-live` div;先 verify 4.6 web build native a11y tree 防 double-announcement) | platform_detect | code(獨立) |
| **G-LM-7** | `interaction-patterns.md`:P-05 撤 5s auto-dismiss + ladder 數值 sync #15 + OQ-P3 close;P-06 hex 確認 | design/ux | doc-only |
| **G-LM-8** | #4 cue catalog co-design:4 新 cue(shutter mid/mono/no-duck;contactsheet/stash/tick low/mono;stream aggregated cue 單 duck handle)入 freeze 表 + `SfxCatalog.tres`;voice pool 重估;lint scope 裁決 | #4 + SfxCatalog | code |
| **G-LM-9** | #4 process-mode amendment:AudioManager(或 SFX pool)+ Coordinator `PROCESS_MODE_ALWAYS`;`check_autoload_process_modes.gd` lint 新開 | #4 + project.godot + CI | code |
| **G-LM-10** | #17 public batch seam:`begin_receive_batch()` / `end_receive_batch()` wrap internal `_batch_depth`(external caller 連發 = N 次 full persist 問題) | #17 `inventory_system.gd` | code |

**CD 裁定 gate 順序**(review log Pass 3 entry,binding):doc-only G-LM-1/5/7 先 → critical path **G-LM-4** → parallel G-LM-3 / G-LM-10 / G-LM-8+9;G-LM-2 排 G-LM-1 後;G-LM-6 獨立。**#21-side 實作:coordinator + FSM + F1/F5 timing core 先行**(71 unit ACs ungated,唔等 gates)。

**G-flag-1..4 grep verification**(story-readiness 時做;唔對齊 → escalate CD):
1. G-flag-1:player tap dismiss 唔受 `MIN_REVEAL_WINDOW`(15s)阻(未 grep)
2. G-flag-2:**已解** — `_check_pending_loot_reveal()` 零 caller → 併入 G-LM-4 ⑥
3. G-flag-3:**主體已解**(exit = `loot_confirmed` chain);殘餘:intra-queue 語意 + GSM L128 drain cadence erratum
4. G-flag-4:#7 `FOCAL_EXIT_DURATION`(0.5)const grep — `FOCAL_EXIT_MARGIN_SEC` 下限約束

**Upstream GDD errata(隨對應 gate story 執行)**:#15 ×9(L204 sting / Visual Spec hex + duck 列 / FR-2 anchor / L1102 K-cap / AC-18+EC-28 catch-up / orbit cut 等)· #17 ×3(doc comment caller / EC-1 locus / batch 語意)· #4 ×2(catalog source / 新 cue + process-mode)· GSM ×2(L128 drain cadence / L375(b) defer v0.2)。

## Story breakdown directives(PR-EPIC adjustments — binding)

1. **G-LM-4 拆 2–3 stories**:#15 state 分離+ceremony-kind 持久化 / handlers+signals(dismiss/confirmed/report)/ GSM wiring + fast-victory marker ⑧;errata 跟對應 story
2. **G-LM-3 拆 2 stories**:(a) scalar→ledger refactor + **behaviour-parity tests 先**(#6 existing tests 零變紅係驗證準則);(b) `ceremony_freeze`/`release`/saturation 新 API 後
3. **Doc-only gates bundle**:G-LM-1+5+7 併 1–2 story;G-LM-6 掛 a11y story
4. **單一 epic PR + 每個 gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊跑)— amend 6+ 已 merged systems 係歷來最大 regression surface
5. Story 總數 baseline **22–28**(>28 = scope creep 重審;<22 = AC force-compress 重審)

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **94 ACs verified**:71 unit + 3 static BLOCKING 全過;9 integration BLOCKING 喺對應 gate story 落地後解封並過;10 manual ADVISORY 有 evidence docs + lead sign-off @ `production/qa/evidence/loot-drop-modal/`;AC-35 mapping 自查
- Combined GUT gate green(`tests/unit` + `tests/integration`,per gate story + epic 收線)
- **G-LM-3 落地時 #6 existing tests 零變紅**(producer 驗證準則)
- `LootRevealCoordinator` 登記 `project.godot` tail(G-LM-5)+ AC-79 boot-order CI 過
- AC-21 owner-exempt CI lint(`receive_loot` 唯一 external caller)+ AC-76b process-mode property assert 落地
- 4 組 upstream errata 全部隨 gate story 執行(#15/#17/#4/GSM)
- 6 telemetry hooks(local signal,#28 sink 唔需存在)+ N-2 threshold pin(`re_reveal_count` EPIC+ >5% over 首 100 RARE+ → 重開 D1)記錄在案
- Test evidence:unit `tests/unit/loot_reveal/` / integration `tests/integration/loot_reveal/`

**唔屬本 epic**:AC-9 wall-clock(真 browser,VS-tier)+ manual ADVISORY 嘅 sign-off 唔做 merge gate(#20 先例);OQ-1 stat-delta ticker(#22 裁)/ OQ-2 telemetry envelope(#28)/ OQ-3 PWA share(v0.2)/ OQ-6 未開封 entry(v0.2)。

## Stories

| # | Story | Type | Status | Primary ADR | ACs |
|---|-------|------|--------|-------------|-----|
| 001 | Doc gates bundle(G-LM-1+5doc+7) | Config/Data | ✅ Complete | ADR-0001/0008 | gate 前提(blur=opacity-only 裁決)|
| 002 | Coordinator 骨架 + layers + 登記 + GSM trigger | Logic | ✅ Complete | ADR-0006 C6 | 4,5,6,7,79 |
| 003 | FSM 8-state × in_catchup table-driven | Logic | ✅ Complete | ADR-0006 | 37 |
| 004 | F1 timeline + motion_reduction | Logic | ✅ Complete | N/A(formula) | 38-41(55→006)|
| 005 | Input policy + F5 fast-complete + keyboard | Logic | ✅ Complete | N/A | 11,15,16,50,37c½(ui_cancel→014)|
| 006 | Ceremony ladder D2 調用序 + EC-M9 | Logic | ✅ Complete | ADR-0001 | 8,10,12,13,14,55,60½(margin wiring→010)|
| 007 | INV-M1 release 出口 + EC-M1/M2 | Logic | ✅ Complete | N/A | 1(×2/4 path),2,52,53 |
| 008 | F2 breakdown bar + INV-M2 + EC-M15/M12 | Logic | ✅ Complete | **ADR-0005** | 3,42-45,63,66 |
| 009 | INV-M3 S3 commit + EC-M14/M5 + AC-21 lint | Logic | ✅ Complete | ADR-0007 | 20,21,56,65½ |
| 010 | Queue drain + terminal + EC-M6/M20 | Logic | ✅ Complete | ADR-0009 | 18,19½,32,34,57,70,60 margin |
| 011 | Force-close D1 split + stash F6 | Logic | ✅ Complete | ADR-0006 | 22,22b,23,51,62 |
| 012 | Rollback paths | Logic | ✅ Complete | N/A | 30,30b,31 + **AC-1 ×4 收線** |
| 013 | micro_ack banking + F4 toast | Logic | ✅ Complete | ADR-0009 | 24,25,34b½,48,49,68 |
| 014 | Catch-up prompt/stream/F3 | Logic | ✅ Complete | N/A | 26,27,46,47,59,64,69,37c完 |
| 015 | Catch-up ceremonies/grid/commit | Logic | ✅ Complete | ADR-0005(C-1) | 28½,29½,58½,67 |
| 016 | Banner stack + telemetry + #33 exempt | Logic | ✅ Complete | ADR-0009 | 17,33,36,61(62→011)|
| 017 | **G-LM-4a** #15 state 分離 + kind 持久化 + ②b breakdown 載體 + errata ×9 | Logic | ✅ Complete | ADR-0003 | (#15-side) |
| 018 | **G-LM-4b** #15 handlers/signals(+micro_ack emit-order bug fix)| Integration | ✅ Complete | ADR-0009 | 解封 19/29/34b/65/71 |
| 019 | **G-LM-4c** GSM wiring + fast-victory ⑧ + GSM errata ×2 | Integration | ✅ Complete | ADR-0006 | 37b |
| 020 | **G-LM-3a** #6 ledger(hybrid 裁決)+ parity | Logic | ✅ Complete | ADR-0001 | (#6 零變紅) |
| 021 | **G-LM-3b** #6 freeze/release/saturation API | Logic | ✅ Complete | ADR-0001 | 解封 1/12/54 |
| 022 | **G-LM-2** #5 reparent handshake | Integration | Ready | ADR-0001 | 75 |
| 023 | **G-LM-8+9** #4 catalog + process-mode + lint + #4 errata ×2 | Logic | Ready | ADR-0008 | 76,76b |
| 024 | **G-LM-10** #17 batch seam + #17 errata ×3 | Logic | Ready | ADR-0003 | 解封 72/28/58 |
| 025 | **G-LM-6** announce_aria + SR | Logic | Ready | N/A(gateway) | 77 |
| 026 | Cross-system integration suite | Integration | Ready | ADR-0006 | 54,71-74,78 |
| 027 | Visual/UI evidence pack(ADVISORY) | Visual/Feel | Ready | ADR-0001 | 9,80-88 |

**AC-35** = mapping AC(→ AC-11/16/17/31/71)— epic 收線自查,無獨立 story。
**建議實作順序**(CD gate 順序 + dependency):001 → 002 → **017(critical path 並行開)** → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015 → 016 → 018 → 019 → 020 → 021 → 022 → 023 → 024 → 025 → 026 → 027。017-019 同 003-016 可 interleave(#15-side vs #21-side 唔同檔);020/024 任何時候可插(無 #21 dep)。
**Story-readiness grep 任務**(OQ-5):G-flag-1(026)/ G-flag-3 殘餘(010/019)/ G-flag-4(006)。

## Next Step

Run `/story-readiness production/epics/loot-drop-modal/story-001-doc-gates-bundle.md` → `/dev-story` pipeline(auto-advance)。
