# Story 006: Formula 1 — Rate-Limited Countdown(injected clock, integer-ms, m:ss)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Formula 1 + AC-16/17/18;EC-D1/D2)
**Requirement**: Rule 4 rate_limited live 倒數

**ADR Governing**: N/A — pure UI timing formula(無架構模式)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_msec()` monotonic(wall-clock tamper 免疫);**所有 formula 路徑唔可直 call `Time.get_ticks_msec()`** — 必讀注入 clock(否則 advance() 影響唔到 → wall-clock phantom,AC-51)。

**Control Manifest Rules**:
- Required: timing 用 injected clock seam（#22/#23 `advance(delta_ms)` 模式）
- Required: integer-ms 比較（`knob_ms := int(knob_sec*1000.0)`;`now_ms < t_start_ms + knob_ms`）— 去 float boundary-flaky

---

## Acceptance Criteria

*GDD AC-16 / AC-17 / AC-18:*

- [ ] **AC-16**: `retry_after=30, t_start=100`,t=115 → `display_seconds == 15`
- [ ] **AC-17**: 同上,t=130 → `display_seconds == 0` + `submit_enabled == true` + 倒數 copy 消失
- [ ] **AC-18**: claim 返 `rate_limited` + `retry_after == 0` → 即時 re-enable + **唔**顯示任何倒數 copy(EC-D1)
- [ ] `display_seconds = max(0, ceili((r*1000 - (now_ms - t_start_ms)) / 1000.0))`(ceili 返 int 防「等 15.0 秒」)
- [ ] **Display format**:`N ≤ 99` →「等 {N} 秒再試」;`N > 99` →「等 {m}:{ss} 再試」(live 秒制不可讀)
- [ ] retry_after 負/absent → N=0 即 re-enable(N1)

---

## Implementation Notes

- `display_seconds(t) = max(0, ceil(retry_after - (t - t_start)))`;`submit_enabled = (display_seconds == 0)`。
- Internal integer-ms:`r*1000 - (now_ms - t_start_ms)`,`ceili(... / 1000.0)`。
- clock 注入 seam(test `advance(delta_ms)`);runtime 讀注入 clock wrapper(唔直 call `Time.get_ticks_msec()` — AC-51 守)。
- m:ss format 喺 N>99(documented 上界 r=3600 → 「等 60:00 再試」逐秒遞減）。

---

## Out of Scope

- Story 008:claim flow rate_limited bucket dispatch（本 story 只做 formula）
- Story 016:clock-seam grep CI（AC-51）

---

## QA Test Cases

- **AC-16**: countdown value
  - Given: `retry_after=30, t_start=100`(injected clock);When: advance 到 t=115;Then: `display_seconds==15`
  - Edge cases: t=129.5 → N=1;t=129.999 → N=1（ceil）
- **AC-17**: re-enable boundary
  - Given: 同上;When: advance 到 t=130;Then: `display_seconds==0` + `submit_enabled==true` + copy 消失
  - Edge cases: t=130.0 exact boundary
- **AC-18**: retry_after==0
  - Given: `rate_limited` + `retry_after==0`;When: 收 result;Then: 即 re-enable + 零倒數 copy
  - Edge cases: retry_after 負 / absent → 同 path
- **Format**: m:ss
  - Given: `retry_after=3600`;When: 倒數;Then: 「等 60:00 再試」→ 逐秒遞減;N=99 → 「等 99 秒再試」;N=100 → 「等 1:40 再試」

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/login_shell/test_rate_limit_formula.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(coordinator — clock seam）
- Unlocks: Story 008(claim flow rate_limited path 用本 formula）

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 全 pass — AC-16(t=115 → 15;ceil t=129.5→1 / t=129.999→1)/ AC-17(t=130 → 0 + submit_enabled)/ AC-18(retry_after 0/負 → 0 即 re-enable)+ display format(N≤99 inline / N=100→1:40 / 3600→60:00 / zero-pad ss)。
**Test Evidence**: `tests/unit/login_shell/test_rate_limit_formula.gd` — **9 funcs,本地 9/9 pass**(login_shell 全 31 pass,零 regression)。
**Design**: `src/ui/login_shell/shell_formulas.gd`(RefCounted static funcs;F1 = `display_seconds`/`submit_enabled`/`format_countdown`)。Integer-ms internal(`r*1000 - (now_ms - t_start_ms)`,`ceili(/1000.0)`)去 float boundary-flaky;injected `now_ms`(AC-51 — 零 `Time.get_ticks_msec()` 直 call)。
**Deviations**: None(pure formula,無 ADR / 無 boot impact)。F2 + knob validation = story 007(同 file 增量)。
**Code Review**: N/A spawn(本地 GUT 等效)。
