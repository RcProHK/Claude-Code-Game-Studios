# Story 007: Formula 2 — Banner Auto-Expire(strict-< boundary)+ _validate_knobs()

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Formula 2 + Tuning Knobs + AC-19/19b/20/21a/21b)
**Requirement**: Rule 6/12 TRANSIENT + 通知類 auto-expire;cross-knob invariants

**ADR Governing**: N/A — pure UI timing formula + knob validation
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot release build strip `assert()` → **唔可淨靠 raw assert()**(GUT 亦捉唔到 raw assert failure = tautological phantom);用 `_validate_knobs() -> bool`(return false / push_error + clamp)。

**Control Manifest Rules**:
- Required: injected clock seam;integer-ms 比較
- Required: knob validation 用 `_validate_knobs()`（release-safe）唔用 raw assert

---

## Acceptance Criteria

*GDD AC-19 / AC-19b / AC-20 / AC-21a / AC-21b:*

- [ ] **AC-19**: drain ✓ banner @ t=200 + `DRAIN_SUCCESS_EXPIRE_SEC=2.0`,t=201.5 → visible;t=202.1 → 消失
- [ ] **AC-19b**: 同上,advance 到 **exactly t=202.0** → banner **已唔 visible**（strict `<` boundary）
- [ ] **AC-20**: `NOT_READY` TRANSIENT(TTL 5.0)+ 同場 `READ_ONLY_FILESYSTEM` ONGOING persistent,t 超 5.0 → TRANSIENT 消失而 **ONGOING/WIPE/FEATURE_DEGRADED 仍 visible**(不受 F2 影響)
- [ ] **AC-21a/b**: 合法 default knobs → `_validate_knobs()` 返 `true`;注入違反組合(a: `DRAIN_SUCCESS=3.5 > TRANSIENT=3.0`;b: `BANNER_MAX_HEIGHT_PCT=0.12 > 0.10`)→ 返 `false`(或 push_error)+ clamp
- [ ] `banner_visible(t) = (t - t_banner_start) < banner_ttl`（strict `<`）
- [ ] **per-banner timer**：每條 banner（含「+N」collapsed）各自 `t_banner_start` timer

---

## Implementation Notes

- F2:`banner_visible(t) = (t - t_banner_start) < banner_ttl`;strict `<` → `t = t_b + TTL` 已唔 visible（t=202.0 exact = false）。
- ONGOING/WIPE/FEATURE_DEGRADED **唔用 F2**（由 resolved / acknowledge / next-success trigger 消除，無限期 persistent）。
- `_validate_knobs() -> bool`：兩 invariant（`DRAIN_SUCCESS ≤ TRANSIENT`;`BANNER_MAX_HEIGHT_PCT ≤ 0.10`）+ 每 TTL/fade knob 喺 safe range（含 `> 0` 下界 — 防 `DRAIN_SUCCESS=0` 令 banner 永不顯示）；違反 return false / push_error + clamp。AC-21 測 pass + violation 兩路。
- clock 注入 seam（唔直 call ticks — AC-51）。

---

## Out of Scope

- Story 014:drain banner 整合（本 story 只做 expire formula + knob validation）
- Story 010：banner severity 機制

---

## QA Test Cases

- **AC-19/19b**: expire boundary
  - Given: drain ✓ banner @ t_b=200, TTL=2.0(injected clock);When: advance;Then: t=201.5 visible / t=202.0 NOT visible（strict <）/ t=202.1 NOT visible
  - Edge cases: exact boundary t=202.0 = false（strict）
- **AC-20**: persistent 不受 F2 影響
  - Given: TRANSIENT(5.0) + ONGOING persistent 同場;When: t 超 5.0;Then: TRANSIENT 消失、ONGOING 仍 visible
- **AC-21a**: valid knobs pass
  - Given: default knobs;When: `_validate_knobs()`;Then: 返 true
- **AC-21b**: violation reject
  - Given: 注入 `DRAIN_SUCCESS=3.5 > TRANSIENT=3.0`（或 `BANNER_MAX_HEIGHT_PCT=0.12`);When: `_validate_knobs()`;Then: 返 false（或 push_error）+ clamp
  - Edge cases: `DRAIN_SUCCESS=0` → reject（防 F2 永不顯示）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/login_shell/test_banner_expire_formula.gd` + `test_knob_invariants.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(coordinator — clock seam）
- Unlocks: Story 010/014(banner expire 機制）

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 全 pass —
- **AC-19/19b**:`banner_visible` strict-`<`(t=201.5 visible / t=202.0 exact **唔** visible / t=202.1 gone）
- **AC-20**:TRANSIENT(TTL 5.0)過期 expire,而 ONGOING persistent(`PERSISTENT_TTL_SENTINEL` ttl≤0)永遠 visible(F2 唔 govern persistent class)
- **AC-21a/b**:`validate_knobs()` default → true;注入違反(DRAIN=3.5>TRANSIENT=3.0 / HEIGHT=0.12>0.10 / DRAIN=0 >0下界 / range 越界)→ false + push_error(release-safe,唔用 raw assert)
- per-banner timer 獨立 + clamp helper
**Test Evidence**: `test_banner_expire_formula.gd`(8 funcs)+ `test_knob_invariants.gd`(7 funcs)— **本地 15/15 pass**(login_shell 全 46/46;reject-path 的 push_error backtrace 係預期輸出,GUT exit 0)。
**Design**: extend `src/ui/login_shell/shell_formulas.gd`(F2 `banner_visible` strict-< + 4 knob consts + safe-range bounds + `validate_knobs()` + `clamp_knob()`)。`ttl≤0` = persistent sentinel(Rule 6)。integer-ms internal;injected `now_ms`(AC-51)。
**Deviations**: None(pure formula;`SHELL_FADE_SEC` knob 喺 formula file validate,coordinator `SHELL_FADE_MS=250` = 0.25s 一致 — 同源值無衝突)。
**Code Review**: N/A spawn(本地 GUT 等效;release-safe validate_knobs 非 raw assert — qa B2 binding)。
