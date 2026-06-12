# Story 016: DEGRADED private-mode + opt-out + clock-skew monotonic

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Complete
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — EC-07(clock skew)/ EC-08(private mode)/ EC-17(opt-out)+ DEGRADED state。AC-15/16/21。
**ADR Governing Implementation**: ADR-0003(primary,save-state/private-mode)+ ADR-0006(Contract 9 drift-tolerant monotonic)
**ADR Decision Summary**: `user://` only(localStorage FORBIDDEN);private-mode gate;Contract 9 drift-tolerant timing。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `private_mode_detected` 由 PersistenceLayer(#3)report;monotonic vs wall-clock(EC-07,同 ADR-0006 Contract 9 posture)。

**Control Manifest Rules (Polish layer)**:
- Required: private-mode → 唔寫 user:// spool;opt-out → 零數據離 device
- Forbidden: localStorage(ADR-0003);opt-out 下 flush
- Guardrail: 排序用 monotonic(drift-immune)

---

## Acceptance Criteria

- [x] **EC-08 DEGRADED private-mode**:boot `is_private_mode()` + mid-session `private_mode_detected` signal(defensive has_method/has_signal,#3 SOFT) → ACTIVE→DEGRADED;`_can_spool()` gate **唔寫 `user://` spool**;`_record` 喺 DEGRADED 繼續 buffer
- [x] **EC-17 opt-out**:`set_telemetry_enabled(false)` → `_request_flush` short-circuit + `_record` 只保 CRITICAL;零數據離 device
- [x] **EC-07 clock skew**:ordering/TTL/dup window **一律 `_now_monotonic_ms()`**(by construction);test 注入 jumping-unix/steady-mono clock 驗 ordering 穩定 + dup 用 monotonic
- [x] Story 004 emergency spool hook 接真 `user://` 寫(`_default_spool_write` FileAccess append JSONL,**非** localStorage,ADR-0003)+ injectable `_spool_writer` test seam
- [x] DEGRADED ⇄ ACTIVE transition(`_on_private_mode_detected` + `notify_private_mode_cleared` 罕見 recovery)

---

## Implementation Notes

*Derived from GDD EC-07/08/17 + DEGRADED state:*

- private-mode 判定:讀 #3 `private_mode_detected`(boot + 中途變化監聽);true → `_transition_to(DEGRADED)` + 停 spool。
- opt-out:`telemetry_enabled` config(Story 017 registry)= false → flush path short-circuit;capture 降到只 in-memory CRITICAL。default = true(first-party premium)。
- clock skew:已喺 Story 003 stamp 兩個 ts;此 story 確保**排序/TTL 一律用 monotonic**(EC-07 + ADR-0006 Contract 9 drift-tolerant)。
- emergency spool(Story 004 hook)真實寫 `user://`(FileAccess,**非** localStorage,ADR-0003)。

---

## Out of Scope

- Story 017:`telemetry_enabled` knob 本身(registry)
- Story 004:buffer overflow → spool hook(此處接真寫)

---

## QA Test Cases

- **AC-1 (opt-out, AC-15)**:
  - Given: `telemetry_enabled=false`
  - When: 任何 event 產生
  - Then: 零 flush、零數據離 device;只 in-memory CRITICAL
  - Edge cases: opt-out 中途切 true/false 行為一致
- **AC-2 (private mode, AC-21)**:
  - Given: `private_mode_detected=true`
  - When: 進 DEGRADED
  - Then: 唔寫 user:// spool;in-memory 繼續;有得 flush 就 flush
  - Edge cases: 中途 private→non-private → 回 ACTIVE
- **AC-3 (clock skew, AC-16)**:
  - Given: session 中途 wall-clock +3600s
  - When: 排序
  - Then: 用 monotonic,順序穩定;unix 跳唔影響
  - Edge cases: TTL check(bfcache/dup)同樣用 monotonic

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/telemetry/test_degraded_private_mode.gd` + `test_opt_out.gd` + `test_clock_skew.gd`
**Status**: [x] 3 files / 15 tests / 31 asserts ALL PASS(degraded 8 + opt_out 4 + clock_skew 3);telemetry combined gate 14scr/88/0 fail;3 lint exit 0

---

## Dependencies

- Depends on: Story 002(FSM)/ 003(ts stamp)/ 004(spool hook)/ 017(telemetry_enabled knob)
- Unlocks: None
