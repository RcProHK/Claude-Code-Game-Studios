# Story 004: Ring buffer + 3-tier priority + Rule 7 overflow (CRITICAL reserved 不滅)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 5(3-tier priority ring buffer)+ Rule 7(overflow policy)+ EC-01/EC-05/EC-15。
**ADR Governing Implementation**: ADR-N/A — pure in-memory data structure,no architectural pattern required
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 512MB browser memory ceiling → buffer cap 必守;int64 counter 安全(EC-15 soak)。

**Control Manifest Rules (Polish layer)**:
- Required: buffer capped;CRITICAL reserved 區永不 evict
- Forbidden: 無界增長(memory)
- Guardrail: overflow drop 計入 `dropped_count`(CRITICAL meta 不靜默)

---

## Acceptance Criteria

- [ ] capped ring buffer，cap = `TELEMETRY_BUFFER_MAX`
- [ ] 三層 priority:CRITICAL / STANDARD / LOW(envelope metadata 分流)
- [ ] **Rule 7 overflow**:滿時先 evict 最舊 LOW,再最舊 STANDARD;**CRITICAL 有獨立 reserved 容量永不被 evict**
- [ ] 每次 evict 累加 `telemetry.buffer.dropped_count`(本身 CRITICAL meta-event)
- [ ] CRITICAL reserved 都滿 → emergency `user://` spool hook(Story 016 接 non-private 判定;此處 stub call)
- [ ] INV-T1 `TELEMETRY_CRITICAL_RESERVED < TELEMETRY_BUFFER_MAX` 啟動斷言

---

## Implementation Notes

*Derived from GDD Rule 5/7 + INV-T:*

- 結構建議:CRITICAL 用獨立 reserved deque（容量 `TELEMETRY_CRITICAL_RESERVED`）;STANDARD+LOW 共用 main ring（容量 `TELEMETRY_BUFFER_MAX − TELEMETRY_CRITICAL_RESERVED`）。
- evict 順序:main ring 滿時,**先掃最舊 LOW,無 LOW 先 evict 最舊 STANDARD**（priority 標記在 envelope）。
- `dropped_count` 自身係 CRITICAL —— 確保「我哋有掉嘢」唔會連同被掉嘅 event 一齊消失。
- emergency spool 只係 call hook（`_emergency_spool(events)`）;真 `user://` 寫 + non-private 判定喺 Story 016。

---

## Out of Scope

- Story 005:sampling 決定邊個 LOW event 入 buffer
- Story 011:flush 清 buffer
- Story 016:真 emergency spool（user:// + private-mode 判定）

---

## QA Test Cases

- **AC-1 (CRITICAL 不滅)**:
  - Given: buffer cap 細（e.g. 10）,塞超量混合 priority
  - When: overflow
  - Then: 全部 CRITICAL 保留;最舊 LOW 先走,再 STANDARD
  - Edge cases: 全 CRITICAL 塞爆 reserved → emergency spool hook 被 call;drop 計入 dropped_count
- **AC-2 (dropped_count)**:
  - Given: 連續 overflow N 次
  - When: 讀 dropped_count
  - Then: == N（精確）;dropped_count event 本身 priority == CRITICAL
  - Edge cases: 無 overflow → dropped_count == 0
- **AC-3 (INV-T1)**:
  - Given: config `CRITICAL_RESERVED >= BUFFER_MAX`
  - When: 啟動
  - Then: 斷言 fail（push_error）—— 非法配置唔啟動

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/telemetry/test_buffer_overflow_priority.gd`(AC-03 GDD binding)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(envelope + priority metadata）
- Unlocks: Story 005 / 008 / 009 / 010 / 011
