# Story 004: Shell 5-state FSM + cross-fade + LOGIN interrupt + mid-workout banner-defer

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(States and Transitions + AC-03/24/38;EC-E1/C3/C4)
**Requirement**: 5-state shell FSM(HIDDEN/LOGIN/SHELL_IDLE/DISCONNECTED_SHELL/DRAINING)

**ADR Governing**: ADR-0006(primary — state observer + cfis + C5 follow-up)
**ADR Decision Summary**: shell observe GSM `state_changed`,**永不 request transition**;follow-up transition 用 `process_frame.connect` ONE_SHOT。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: cross-fade `SHELL_FADE_SEC` 0.25s ease-out cubic;唔 hard-cut(onset transient = attention event)。

**Control Manifest Rules**:
- Required: GSM follow-up 用 `process_frame.connect` ONE_SHOT(C5);handler 內 GSM 行為 call_deferred
- Forbidden: shell request GSM transition(GSM owns states;#24 owns 分流)

---

## Acceptance Criteria

*GDD AC-03 / AC-24 / AC-38 + States table:*

- [ ] **AC-03**: shell 任意 state,mock emit `auth_required` → 下一 frame 入 `LOGIN` + `LoginShellLayer.visible == true`
- [ ] **AC-24**: 已喺 LOGIN + form 有已填文字,`auth_required` 再 fire → 仍 LOGIN、已填文字保留、唔 double-render(EC-A3 idempotent)
- [ ] **AC-38**: `_pending_auth_required == true`(mid-workout defer),GSM → IDLE(或 DISCONNECTED — EC-C4)→ 即入 LOGIN + flag 清零;**LOGIN 入場唔以 IDLE 為 precondition**
- [ ] States table 5 state 入/出場條件全落地;轉場 cross-fade ≤ `SHELL_FADE_SEC`
- [ ] **mid-workout 401 latch banner-defer**:`auth_required` 喺 GSM 仍 workout 系 state 時唔即彈全屏 form(Rule 9a / Pillar 2 binding)
- [ ] **EC-E1**: GSM 喺 LOGIN cross-fade 途中直落 LOOT_DROP → cross-fade 跑完唔 abort → 完 check state → HIDDEN

---

## Implementation Notes

- shell FSM 喺 coordinator 內部(或 `shell_transitions.gd` helper);observe GSM `_on_state_changed`(from,to,payload)分流。
- `_pending_auth_required: bool` flag — Rule 9(a)banner-defer 期間 set;GSM 落 DISCONNECTED/IDLE 時 flag set → 即入 LOGIN(EC-C4 completion path)。
- LOGIN 係最高優先 interrupt,但 mid-workout 行 banner-defer(`auth_required` 喺 workout 系 state 唔即彈;banner 先,GSM 落 IDLE/DISCONNECTED 先入 LOGIN)。
- cross-fade 唔 abort mid-tween(EC-E1:動畫 integrity > immediacy;GSM state continuously observable)。

---

## Out of Scope

- Story 009:LOGIN sub-variant(get_auth_block_reason 分流)
- Story 010/011:banner stack(本 story 只做 shell FSM,banner orthogonal)

---

## QA Test Cases

- **AC-03**: auth_required → LOGIN
  - Given: shell 任意 state;When: mock emit `auth_required`;Then: 下一 frame LOGIN + LoginShellLayer.visible==true
  - Edge cases: 由 HIDDEN / SHELL_IDLE / DISCONNECTED_SHELL 三起點各驗
- **AC-24**: idempotent re-enter
  - Given: LOGIN + form 已填;When: `auth_required` 再 fire;Then: 仍 LOGIN、文字保留、唔 double-render
- **AC-38**: mid-workout defer completion
  - Given: `_pending_auth_required==true`;When: GSM → IDLE 或 DISCONNECTED;Then: 即入 LOGIN + flag 清零
  - Edge cases: DISCONNECTED path(EC-C4)同 IDLE path 都驗;LOGIN 入場唔 require IDLE
- **AC-E1**: cross-fade integrity
  - Given: LOGIN cross-fade 途中;When: GSM 直落 LOOT_DROP;Then: fade 跑完 → check state → HIDDEN(唔 abort mid-tween)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_login_shell_fsm.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(coordinator scaffold + GSM connect)
- Unlocks: Stories 009/012/013/014(各 state surface 依賴 FSM)
