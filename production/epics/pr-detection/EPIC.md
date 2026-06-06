# Epic: PR Detection & Avatar Progression (#18)

> **Layer**: Feature
> **GDD**: design/gdd/pr-detection.md(✅ APPROVED 2026-06-06 Pass 3 — 同日三 pass 收斂,0 phantom)
> **Architecture Module**: `PrDetection` autoload @ `src/autoload/pr_detection.gd`(ADR-0011 §D-4 — `src/feature/` 係 phantom path;G-PR-3:append 鏈尾 AttentionBudget 之後,constraint `#2 ≺ #10 ≺ StatSystem ≺ {AbilitySystem, WST} ≺ PrDetection`)+ shared static `PRDeltaCalc` @ `src/core/pr_delta_calc.gd`(D3 — 讀 #11 Formula 2 config 常數,單一 source)
> **Status**: ✅ **INTERNAL COMPLETE 14/14**(2026-06-06 同 session GDD APPROVED → epic → stories → implemented;combined gate 295 scripts / 1913 tests / 1912 pass / 0 fail / 1 pre-existing pending + 53/53 CI lints;015 = EXTERNAL blocked G-PR-1)
> **Stories**: **15 created**(12 Logic + 3 Integration;14 Ready + 015 Blocked-EXTERNAL;AC coverage 31/31)— QL-STORY-READY degraded inline ADEQUATE(GDD ACs 啱啱經 qa-lead Pass 2/3 逐條 verify,GWT + pinned vectors,等同 qa-plan import)
> **Producer gate (PR-EPIC)**: REALISTIC(degraded inline assessment 2026-06-06 — subagent spawning blocked by 1M-context credits,#17 同款處理;單 epic 正確 [一 autoload + 一 shared calc];est. 13-15 stories 對標 #17 42ACs→16;G-PR-5 story 必須先於 #12 integration story;G-PR-1 EXTERNAL posture safe — INV-PR-1 fail-closed 令 client 冇 backend 都 ship 得)

## Overview

實作 Mirror Hero 嘅 **Pillar 1 心臟**:訂閱 #2 `set_logged` 原始流(SIBLING split,唔經 #9),對每 set 計 rep-clamped Epley e1RM(D7:`min(reps, 12)`),同 trusted baseline 比較判定 PR。**INV-PR-1**(no trusted baseline no PR — establishment window = 該 exercise 首個 workout,fail-closed BASELINE_SYNCING)+ **INV-PR-2**(magnitude log-additivity + D8 commit-time 重計)係 anti-fabrication 骨幹。PR confirmed → `PRDeltaCalc` 計 delta → `apply_stat_delta(stat_id, PR_BREAKTHROUGH, δ)`(δ==0 cap short-circuit)→ baseline 升 + `pr.state` 單 envelope flush → emit `pr_breakthrough`(reverse-wire 落 #12 `_on_pr_breakthrough` + #9 G-PR-2 handler;Rule 6.7 emit gate + one-slot pending buffer)。Soft-confirm(D8:`SUSPECT_PR_MAGNITUDE` 0.30 → PENDING → corroborate/discard)防 typo fabrication。Server baseline reconcile 按 ADR-0011 §D-2(per-entry validation / confirmed-ratchet / session-confirmed floor / polling-field timing)。另:session PR summary(Formula 5 raw tuple — receipt 鏈)、lifetime count/score + milestone(MVP telemetry only)、Baseline Forged moment(AC-28 binding)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0011**: PR Detection Topology & Server Baseline Contract | facts server-authoritative + client derivation(Q3 supersession);G-PR-1 四 sub-spec;#11 EC-36 / #12 FR-2+EC-35+EC-16 guarantee mapping;caller path | LOW(contract;backend 實作 VS-gated) |
| ADR-0002: GymSys Integration Protocol | `set_logged` payload schema Locked;cursor/idempotency #2 own;epoch full-resync 語意 | LOW(#2 own transport) |
| ADR-0003: Save State Strategy | `pr.state` backend-primary;flush=true anchor moments;localStorage FORBIDDEN | LOW |
| ADR-0005: Loot Rarity Formula | `PR_BASE=6.0` PROVISIONAL — #11/ADR-0005 own,#18 只引用(D3) | LOW |
| ADR-0006: State Machine Contract | C3(envelope to_dict/from_dict)/ C4(sequential boot)/ C6(GSM 訂閱) | LOW |
| ADR-0008: Autoload Position Map | G-PR-3 insertion amendment 待做(本 epic story 1) | LOW |
| ADR-0009: Signal Payload Schema | payload minimal + intrinsic;telemetry append-log pattern | LOW |

## GDD Requirements

> #18 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17 先例一致)。Requirements 由 GDD 直接 trace:**10 Core Rules + D1-D8 decisions + 2 named invariants(INV-PR-1/2)+ 5 Formulas + 16 ECs + 31 ACs + 8 test seams + 16 telemetry events**,全部有 Accepted ADR cover(上表)。

**Untraced requirements**: None(TR-ID granularity 留 /architecture-review batch)。

**Cross-epic touches(各一 story / story 內步驟)**:
- **G-PR-5(#12 additive 四件套)**:`_on_stat_changed` skip `source == 0(PR_BREAKTHROUGH)` 一行 + **shipped test 反轉**(`tests/unit/ability_system/test_unlock_path_b_multi_tier.gd:98-99` 現 assert PR-source 經 Path B — 唔反轉 CI 即紅)+ `is_boot_completed()` getter(mirror #11 G-2)+ L890 comment 修(magnitude = relative ratio)。**必須先於 #12 integration story(AC-21)。**
- **G-PR-2(#9 additive)**:`pr_breakthrough` handler(#18 reverse-wire)+ `get_pr_count_today()` + daily reset 語意(#9 own,TimeProvider seam #9-side)。**AC-22 BLOCKED-ON 呢個** — 可後置。
- **G-PR-6(#3)**:VALID_NAMESPACES `pr.` 一行 + #3 GDD Rule 12 registry 一行 + namespace lint **create-or-amend**(未 shipped)。
- **G-PR-3(ADR-0008 amendment)**+ **CI whitelist amend**(`check_stat_mutation_callers.gd`:`src/feature/` → `src/autoload/pr_detection.gd`)— 綑入 wiring story。
- **G-PR-1(GymSys backend)**:**EXTERNAL story**(user 自有 backend;ADR-0011 §D-2 contract 已 spec;client 冇佢照 ship — INV-PR-1 establishment-only)。
- **lead-programmer escalation(獨立 CI-tooling story,唔 block)**:`check_stat_mutation_callers.gd` vacuous(regex 被 DI 繞過 + 2/4 whitelist stale)。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- 31 ACs verified(**AC-22 = GATED on G-PR-2** — BLOCKED-ON 標記,deferred-tracked 可接受;AC-28 binding experience AC 嘅 #18-side signal assert 必須過)
- All Logic/Integration stories 有 passing tests(combined GUT gate green:`tests/unit` + `tests/integration`)
- 8 test seams 落實(#2 signal 注入 / baseline async capture-release mock / #10 / #11 / telemetry append-log spy / persistence / #12+#9 handler spy / GSM)
- `PrDetection` autoload 登記 `project.godot`(G-PR-3 amendment)+ CI whitelist amend 落地
- 16 telemetry events 齊(append-log pattern,#15/#17 verbatim)

## Stories

| # | Story | Type | Status | Primary ADR | ACs |
|---|-------|------|--------|-------------|-----|
| 001 | PRDeltaCalc + Formula 1 goldens | Logic | ✅ Complete | ADR-0005(D3) | 11/12/05f/13c |
| 002 | Autoload 骨架 + wiring gates(G-PR-3/G-PR-6/CI whitelist) | Logic | ✅ Complete | ADR-0008/0011 | 27 |
| 003 | `pr.state` envelope + round-trip | Integration | ✅ Complete | ADR-0006 C3 | 17/26 |
| 004 | Eligibility gate + class routing | Logic | ✅ Complete | ADR-0011 | 04/09/25 |
| 005 | 判定 pipeline core | Logic | ✅ Complete | ADR-0011 | 01/02/06/10/24/05p |
| 006 | Establishment window INV-PR-1 + Baseline Forged | Logic | ✅ Complete | ADR-0011 | 03/28 |
| 007 | Soft-confirm D8 + INV-PR-2 property | Logic | ✅ Complete | ADR-0011 | 07/29/31 |
| 008 | Server baseline reconcile | Logic | ✅ Complete | ADR-0011 §D-2 | 14/15/16/23 |
| 009 | Stat 生效 path | Logic | ✅ Complete | ADR-0006 | 08/13s |
| 010 | Summary + counters + milestone | Logic | ✅ Complete | ADR-0009 | 18/19/20 |
| 011 | Emit gate + buffer + GSM | Logic | ✅ Complete | ADR-0006 C6 | 30 |
| 012 | **G-PR-5** #12 additive 四件套 | Logic | ✅ Complete | ADR-0006 | supports 21 |
| 013 | #12 reverse-wire integration | Integration | ✅ Complete | ADR-0011 | 21 |
| 014 | **G-PR-2** #9 additive + count 鏈 | Integration | ✅ Complete | ADR-0009 | 22 |
| 015 | **G-PR-1** GymSys backend(EXTERNAL) | Integration | **Blocked** | ADR-0011 §D-2 | live 驗證 |

**建議實作順序**:001 → 002 → 003 → 004 → 005 → 012 → 006 → 007 → 008 → 009 → 010 → 011 → 013 → 014;015 external wave。**012 必須先於 013**(double-path)。

## Next Step

Internal stories complete(14/14)。剩 015 EXTERNAL(GymSys backend,ADR-0011 §D-2 contract)。NEXT: #19 zone-system implementation → push + CI。
