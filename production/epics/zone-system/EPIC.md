# Epic: Zone System (#19)

> **Layer**: Feature
> **GDD**: design/gdd/zone-system.md(✅ APPROVED 2026-06-06 Pass 3 — 同日三 pass 收斂,0 phantom)
> **Architecture Module**: `ZoneSystem` autoload @ `src/autoload/zone_system.gd`(G-Z-1:constraint `PersistenceLayer ≺ WST ≺ ZoneSystem`,append 鏈尾 PrDetection 之後;#28 仍最尾)+ `ZoneRegistry.tres` data asset(`Array[ZoneDef]`,**editor-saved** — typed-array-of-script-class 手寫易 silent null;3 個新 class_name 要 `--import` 刷 class cache 先 GUT 跑得)
> **Status**: ✅ **COMPLETE 8/8**(2026-06-06 同 session GDD APPROVED → epic → stories → implemented;combined gate 299/1930/1929/0 fail + lints;G-Z-1/G-Z-3 executed)
> **Stories**: **8 created**(6 Logic + 2 Integration;全 Ready;AC coverage 12/12)— QL-STORY-READY degraded inline ADEQUATE(GDD ACs qa-lead Pass 2 verified:10 PASS / 2 WEAK 已修)
> **Producer gate (PR-EPIC)**: REALISTIC(degraded inline assessment 2026-06-06 — spawning blocked,#17/#18 同款處理;薄容器 scope S-M,est. 8-10 stories;G-Z-1 同 #18 G-PR-3 **共用一次 ADR-0008 amendment**(一個 story 做兩個 insertion);AC-08 typed `Array[StringName]` JSON round-trip 係 codebase 首例 — test risk 已喺 AC spec 內 pin)

## Overview

實作遊戲世界嘅**關卡容器層**:data-driven `ZoneRegistry.tres`(MVP 1 zone ALWAYS,pools 空 = unfiltered sentinel)、**training-day count** unlock framework(訂 #9 `workout_completed_forwarded` [unix **ms** payload];transition_id dedup + monotone `<=` UTC-date guard — per-day cap 1 + epoch-resync replay 免疫)、`zone.state` 單 envelope persist(write-success-then-emit,rollback 範圍 = unlocked_zone_ids + ceremony_pending 兩個 append;count/cursors keep)、boot retroactive sweep(純 local recovery — 零 backend 依賴)、`ceremony_pending` persisted queue + aggregated reveal(drain 後 persist;over-deliver accepted)、**lateral loot forward contract**(zone loot 必須 power-budget-neutral)。MVP 玩家不可見(1 zone),交付物係 contract 正確性 + 永久解鎖 anti-pillar binding(ALWAYS derived-not-persisted;manifest 只加不減)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Save State Strategy | `zone.state` backend-primary posture;unlock flush=true;recovery = local sweep(零 server 面) | LOW |
| ADR-0006: State Machine Contract | C3(envelope to_dict/from_dict — typed Array rebuild)/ C4(sequential boot);**C6 唔適用**(GDD States 段理由) | LOW |
| ADR-0007: Class & Domain Enum Convention | `UnlockCondition.kind {ALWAYS, WORKOUT_COUNT, UNKNOWN}` — Classification enum,sentinel last,UNKNOWN = config error | LOW |
| ADR-0008: Autoload Position Map | G-Z-1 insertion amendment(同 G-PR-3 一齊做) | LOW |
| ADR-0009: Signal Payload Schema | `zone_unlocked(zone_id)` minimal;telemetry append-log | LOW |

> 無新 ADR(Pass 1 已確認)。

## GDD Requirements

> #19 未有 TR-IDs(/architecture-review Phase 8 未跑 — 先例一致)。Requirements 由 GDD 直接 trace:**10 Core Rules + 8 ECs + 12 ACs(AC-09 三件套)+ 4 test seams + 4 telemetry events + 1 Formula(training-day count)+ lateral loot forward contract**,全部有 Accepted ADR cover。

**Untraced requirements**: None。

**Cross-epic touches**:
- **G-Z-3(#3)**:VALID_NAMESPACES `zone.` 一行 + #3 GDD Rule 12 registry 一行 + namespace lint create-or-amend(同 #18 G-PR-6 共用 lint story 面)。
- **G-Z-1(ADR-0008 amendment)**:**同 #18 G-PR-3 共用一個 amendment story**(兩個 tail-append insertion 一次過寫)。
- **G-Z-2(#14 v0.2)**:唔喺本 epic — workout-start runtime read,#14 amendment 一行留 v0.2。
- **BLOCKED-ON(consumer 面,唔 block epic)**:#20 ceremony surface story / #29 Mirror Moment(`drain_ceremony_queue()` consumer)— MVP queue 實際空(1 zone ALWAYS),#19-side queue 語意 AC-11 照測。
- **EG-4**(#8 streak reachability)— 獨立 track,唔 block(#19 已刪 streak 軸)。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- 12 ACs verified(AC-09 三件套:data assert + regression gate + static grep)
- Combined GUT gate green;**AC-08 round-trip 必須行 fresh-load 真 path**(同 instance cache read = phantom pass — review log Pass 3 note)
- 4 test seams 落實(persistence / registry 注入 / workout source / telemetry append-log)
- `ZoneSystem` autoload 登記 + `ZoneRegistry.tres` editor-saved + class cache import step 喺 CI 確認
- `zone.` namespace 註冊(G-Z-3)落地

## Stories

| # | Story | Type | Status | Primary ADR | ACs |
|---|-------|------|--------|-------------|-----|
| 001 | ZoneDef / Registry resources + validation | Logic | ✅ Complete | ADR-0007 | 07 |
| 002 | Autoload 骨架 + boot + gates(G-Z-1/G-Z-3) | Logic | ✅ Complete | ADR-0008 | 01/12 |
| 003 | `zone.state` envelope + round-trip | Integration | ✅ Complete | ADR-0006 C3 | 04/08 |
| 004 | Training-day count(dedup + monotone guard) | Logic | ✅ Complete | ADR-0002 | 06/03d |
| 005 | Unlock 評估 + write-then-emit + rollback | Logic | ✅ Complete | ADR-0003 | 02/03/10 |
| 006 | Boot sweep recovery | Logic | ✅ Complete | ADR-0003 | 05 |
| 007 | Ceremony queue + drain | Logic | ✅ Complete | ADR-0009 | 11 |
| 008 | #14 data face(zero-churn 三件套) | Integration | ✅ Complete | N/A(data contract) | 09abc |

**建議實作順序**:001 → 002 → 003 → 004 → 005 → 006 → 007 → 008。G-Z-1 同 #18 story 002 共用 ADR-0008 amendment(邊個先行邊個做)。

## Next Step

Epic complete(8/8)。G-Z-2 = v0.2(#14 workout-start runtime read)。
