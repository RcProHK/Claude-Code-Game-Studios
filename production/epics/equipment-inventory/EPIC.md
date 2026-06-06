# Epic: Equipment & Inventory (#17)

> **Layer**: Feature
> **GDD**: design/gdd/equipment-inventory.md(✅ APPROVED 2026-06-06 Pass 3 — 3-pass same-day convergence,零 phantom 零 new orphan)
> **Architecture Module**: `InventorySystem` autoload(ADR-0008 constraint 8:`StatSystem ≺ InventorySystem ≺ LootDropSystem`;insertion rule = WorkoutStateTracker 同 LootDropSystem 之間)
> **Status**: ✅ **COMPLETE 16/16 — CI-green, merged main PR #21(b7ded42)2026-06-06**
> **Stories**: 16/16 Complete(13 Logic + 3 Integration;42/42 GDD ACs;~108 tests;combined gate 281 scripts / 1844 tests / 1843 pass / 0 fail / 1 pre-existing pending;全 tools/ci/*.gd lints PASS)
> **Local-gate lessons**(commit d533086):#11 StatId 值係 lowercase StringName(Q-1 reprise — 驗 enum 要驗到 value 層)· unit test 必須 inject 全部 seams(real-autoload state leak)· batch gate 要 push+flush 對稱 · GSM typed signal 係 int GameState args
> **Deferred(非 #17-core)**:AC-32b VS-tier Private Mode playtest(ADR-0003 gate)· G-7 #2 server-time wiring(grace fallback 已 safe)· G-8 #3 namespace 表一行 · #21/#22/#23 UI surfaces(Presentation tier)
> **Producer gate (PR-EPIC)**: REALISTIC(degraded inline assessment 2026-06-06 — subagent spawning blocked by 1M-context credits;單 epic 結構同 boss-system 15-story 先例相若,估 14-16 stories;A1 salvage-only 已大幅減 scope)

## Overview

實作 Mirror Hero 嘅「戰利品歸宿」系統:接收 #15 Loot Drop 嘅 `loot_drop_record`,hydrate 成 typed `EquipmentItem`(stat 由 D9 fixed Stat Assignment Table 賦值,零 runtime RNG),管理 inventory(`MAX_INVENTORY=120` + mailbox 7日 TTL **auto-salvage**,receipt 件永不 silent expire)、auto-equip-if-better(loadout-level clamp-aware 比較)、salvage/bulk-salvage → `forge_shard`(MVP salvage-only sink;craft/upgrade → v0.2 Forge),並經單一 `&"equipment_aggregate"` modifier 將 clamp 後(`FR-Equipment-AntiSnowball`:`clamp(raw, 0, min(max(30, 3×SDA), 300))`)嘅 4 個 derived-key 加成餵入 #11。Derived-keys-only(D8)— item 永不帶 STR/DEX/VIT。Persistence 跟 ADR-0003(`inventory.*` namespace,per-action batched write);boot 8 步 + SUSPENDED durable queue(`inventory.pending_queue`)+ `ReceiveResult` contract 守 Pillar 3 no-loss。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Save State Strategy | backend-primary + `user://` `inventory.*`;localStorage FORBIDDEN;migration ≤900ms;per-action flush 粒度 | LOW |
| ADR-0006: State Machine Contract | Contract 2(transition_id opaque — tombstone 唔 parse)/ 3(SerializableResource dict envelope;`.tres`→`user://` FORBIDDEN)/ 4(sequential boot — `is_boot_completed()` assert,唔 await)/ 5(`process_frame` ONE_SHOT deferred idiom)/ 6(`connect_for_initial_state`);**Contract 9 明確唔 reuse**(cross-session 時基取代) | LOW |
| ADR-0008: Autoload Position Map | constraint 8 + InventorySystem insertion rule(2026-06-06 amendment) | LOW |
| ADR-0009: Signal Payload Schema | persisted payloads = typed SerializableResource envelopes | LOW |
| ADR-0001: Web Export Budget Caps | bulk-salvage 50 件 = 1 write(frame budget);boot flush 單 write | LOW |

## GDD Requirements

> #17 未有 TR-IDs(/architecture-review Phase 8 未跑 — 同 #16 先例一致)。Requirements 由 GDD 直接 trace:**15 Core Rules + 6 Formulas + 22 ECs + 42 ACs(AC-01..AC-41 + AC-32a/b)**,全部有 Accepted ADR cover(上表)。Cross-system gates G-1/G-1b/G-2/G-3/G-4 已喺 design 階段執行落上游;唔 block 本 epic。

**Untraced requirements**: None(TR-ID granularity 係 registry bookkeeping,留 /architecture-review batch)。

**Cross-epic touch(1 story)**:#11 G-2 嘅兩個 additive API(`get_attack_power_excluding_equipment()` + `is_boot_completed()`)已落 spec,**GDScript 實作**要喺 `src/autoload/stat_system.gd` 加(細;先例:prior epics 嘅 additive cross-system stories)。

**Soft gates(epic 內處理或 defer)**:
- G-5:#3 `IPersistence.write_batch`(optional — per-action 單 write 已可實現,story 實作時決定)
- G-7:#2 expose last-known server time(mailbox sweep sanity;offline fallback = grace,可以 stub + followup)
- G-8:#3 namespace 表一行修字(`gsm.inventory.*` TBD → `inventory.*`)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 42 acceptance criteria from `design/gdd/equipment-inventory.md` are verified(AC-32b = VS-tier playtest ADVISORY,可 deferred-tracked)
- All Logic and Integration stories have passing test files in `tests/`(combined GUT gate green)
- 8 test seams 落實(TimeProvider / untyped #11 mock / IPersistence mock / GSM mock / server_unix / 分層 persistence mock 等)
- CI lint `tools/ci/check_inventory_reentrancy.gd` 落地(owner-exempt #17)
- `InventorySystem` autoload 登記入 `project.godot`(per ADR-0008 insertion rule)+ boot 順序 CI-verified

## Stories

| # | Story | Type | Status | Primary ADR | ACs |
|---|-------|------|--------|-------------|-----|
| 001 | Data types + Stat Assignment Table | Logic | Ready | ADR-0006 C3 | AC-01(schema) |
| 002 | receive_loot hydration + ReceiveResult | Logic | Ready | ADR-0006 | AC-01/02/03/04/35 |
| 003 | Idempotency + timestamped tombstone | Logic | Ready | ADR-0006 C2 | AC-07/39 |
| 004 | Inventory cap + mailbox routing + claim | Logic | Ready | ADR-0003 | AC-08/11 |
| 005 | Mailbox TTL auto-salvage + 時基 | Logic | Ready | ADR-0006 | AC-09/10 |
| 006 | Slot model + auto-equip orchestration | Logic | Ready | ADR-0006 | AC-12/13/14/15/23/41 |
| 007 | Formula 1 loadout_score | Logic | Ready | N/A(pure formula) | AC-18/19 |
| 008 | Aggregation + AntiSnowball + #11 push | Logic | Ready | ADR-0009 | AC-16/17/22/38 |
| 009 | #11 G-2 additive APIs(cross-epic) | Logic | Ready | ADR-0006 C4 | supports AC-16 |
| 010 | Salvage + bulk-salvage + atomicity | Logic | Ready | ADR-0003 | AC-20/24/25 |
| 011 | Manual override + item-level lock | Logic | Ready | N/A | AC-34 |
| 012 | Cosmetic pipeline + dupe + provenance | Logic | Ready | ADR-0009 | AC-05/37 |
| 013 | Persistence round-trip + Private Mode | Integration | Ready | ADR-0003 | AC-27/31/32a/32b |
| 014 | Boot INITIALISING 8 步 | Integration | Ready | ADR-0006 C4 | AC-06/26/28/36/40 |
| 015 | SUSPENDED queue + rejection retry | Integration | Ready | ADR-0006 C5/C6 | AC-21/29/30 |
| 016 | Re-entrancy guard + CI lint + autoload 登記 | Logic | Ready | ADR-0008 | AC-33 |

**AC coverage**: 42/42(AC-32b = VS-tier ADVISORY deferred-tracked)。
**建議實作順序**:001 → 009 → 002 → 003 → 004 → 007 → 005 → 006 → 008 → 010 → 011 → 012 → 013 → 014 → 015 → 016。

## Next Step

Run `/story-readiness production/epics/equipment-inventory/story-001-data-types-stat-table.md` then `/dev-story` to begin implementation.
