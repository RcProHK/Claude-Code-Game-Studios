# Story 005: Mailbox TTL auto-salvage + hard-cap FIFO + cross-session 時基

> **Epic**: Equipment & Inventory (#17)
> **Status**: Implemented (pending CI verification)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 4(A3 binding)+ EC-8/9
**ADR Governing Implementation**: ADR-0006(primary — **Contract 9 明確唔 reuse**;Contract 15 server-clock 先例)
**ADR Decision Summary**: Contract 9 persisted monotonic anchor 跨 WASM reload 歸零會 poison drift branch → mailbox sweep 用 wall-clock + server-time sanity + grace(寧可唔 expire)。

**Engine**: Godot 4.6(Web Export — WASM reload 重置 monotonic clock)| **Risk**: LOW-MEDIUM(時基係本 epic 唯一 web-specific 位)
**Control Manifest Rules**: Required: deterministic tests(injected time)。Forbidden: `Time.get_ticks_msec()` 做 cross-session 比較。

---

## Acceptance Criteria

- [ ] **AC-09**:GIVEN injected `now_unix = T`,mailbox item A(`acquired_at = T-8d`,無 receipt)+ item B(`T-8d`,**有 receipt**),WHEN boot sweep,THEN A auto-salvage(shard += `salvage_yield(rarity)` + emit `inventory.mailbox.auto_salvaged`),B 保留(**A3:receipt 件永不 silent expire**);AND server-time sanity 偏差超 `CLOCK_SANITY_TOLERANCE_SEC` THEN 兩件都保留(grace)
- [ ] **AC-10**:GIVEN mailbox 達 `MAILBOX_HARD_CAP`(=180,最舊 = 無 receipt 件),WHEN 新 overflow 到,THEN 最舊者(min `acquired_at_unix`,**FIFO 唔係 LRU**)auto-salvage + telemetry;AND 最舊係 receipt 件 THEN skip 拆次舊
- [ ] All-receipt fallback(EC-9):全 mailbox receipt-bearing → soft-admit 超 cap + telemetry alert
- [ ] 時基:`TimeProvider.now_unix()` + `TimeProvider.server_unix()`(nullable;null = offline → grace)

---

## Implementation Notes

- Auto-salvage = 同一條 `salvage_yield` formula(單一價值軌;Story 010 提供 formula — 如未實作,本 story 先實作 Formula 2 pure function 或調整依賴順序)。
- `OVERFLOW_MAILBOX_TTL_DAYS = 7` / `CLOCK_SANITY_TOLERANCE_SEC = 3600`(config knobs)。
- Sweep 喺 boot INITIALISING step 4 行(Story 014 wire;本 story 提供 pure-ish `sweep_mailbox(items, now, server_now) -> SweepResult`)。
- G-7 server time:#2 GymSysBackendClient 暴露 last-known server time 係 soft gate — 本 story 用 seam 7 注入,production wiring 留 followup(offline grace 令缺佢 safe)。

## Out of Scope

- Story 010:manual salvage flow(本 story 用 Formula 2 做 auto-convert)
- Story 014:boot wiring

## QA Test Cases

GDD AC-09/AC-10 GWT(injected TimeProvider)。Edge cases:
- TTL boundary 啱啱 7.0d → 唔 expire(嚴格 > 7d 先 expire)
- server_unix = null(offline)→ grace,無 expire
- server_unix 偏差 3599s → 正常 sweep;3601s → grace
- hard-cap 180 全 receipt → soft-admit 第 181 件 + alert telemetry

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_mailbox_ttl_auto_salvage.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004(mailbox 結構)
- Unlocks: Story 014(boot sweep wiring)
