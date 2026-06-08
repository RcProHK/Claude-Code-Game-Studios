# Story 014: Logout drain(optimistic + 非阻塞 banner + part-fail persistent)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 12 + AC-41/42;EC-B6/B8/E2)
**Requirement**: Q-X10 閉環 — logout 非阻塞 drain（Mid-Set Logout Test binding）

**ADR Governing**: ADR-0002(primary — drain 程序 + tombstone)
**ADR Decision Summary**: CD path (a) optimistic + silent drain;`clear_session_token(USER_EXPLICIT)` → #2 background drain;tombstone + #3 persist 下次 boot 接返。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 玩家 drain 中途熄 app → 冇所謂（#2 tombstone + #3 persist,下次 boot 接返）。

**Control Manifest Rules**:
- Required: logout = optimistic（即時「已登出」）+ 背景 drain;永不 blocking modal
- Required: drain banner non-interactive,text + ✓ glyph（唔純 spinner）

---

## Acceptance Criteria

*GDD AC-41 / AC-42:*

- [ ] **AC-41**: SHELL_IDLE,logout tap → `clear_session_token(USER_EXPLICIT)` 即時 call + 「已登出」banner(count=N) + 入 DRAINING + **零** blocking modal（Fantasy Test 3）
- [ ] **AC-42**: DRAINING,`drain_completed(5, 2)` → drain banner **替換**做 persistent banner 含「2 樣嘢今次冇儲到」(acknowledge-dismiss,WIPE-weight 視覺 — EC-B6,永不 silent)
- [ ] `drain_started(N)` → bottom banner「已登出 — 緊要嘅嘢背景儲緊({N} 樣),可以安心熄 app。」;`drain_completed(_,0)` → 「全部儲好喇 ✓」→ 2s auto-expire
- [ ] **sequencing**：`auth_required` 入 LOGIN 時 drain success 通知 banner 先清除（唔同 form 共存);但 drain **部分失敗** WIPE-weight persistent banner 保留到 re-login 後
- [ ] `drain_completed(0, 0)`（零 pending）→ 照顯示「全部儲好喇 ✓」→ 2s expire（EC-B8）

---

## Implementation Notes

- logout 擺 settings 角落（gear icon,破壞性動作收一層防誤撳）→ tap → 即時 optimistic「已登出」+ `clear_session_token(USER_EXPLICIT)` → #2 background drain。
- drain banner（text 狀態 + ✓ glyph,non-interactive）;part-fail（`timeout_count > 0`）→ persistent WIPE-weight acknowledge-dismiss「有 {N} 樣嘢今次冇儲到,登入返之後系統會試返。」（永不 silent — #2 tombstone「會試返」係真）。
- sequencing（game-designer R3）：drain ✓ 通知 banner 入 LOGIN 時先清（否則「可以安心熄 app」疊「請再登入」= 語意打架);WIPE-weight part-fail 保留（誠實）。

---

## Out of Scope

- Story 010/011:banner stack 機制（本 story 用其 enqueue + WIPE weight）
- Story 007:F2 drain expire（本 story 用 DRAIN_SUCCESS_EXPIRE_SEC）

---

## QA Test Cases

- **AC-41**: optimistic logout
  - Given: SHELL_IDLE;When: logout tap;Then: `clear_session_token(USER_EXPLICIT)` 即 call + 「已登出」banner(N) + DRAINING + 零 blocking modal
- **AC-42**: part-fail persistent
  - Given: DRAINING;When: `drain_completed(5, 2)`;Then: drain banner 替換 persistent「2 樣嘢今次冇儲到」(acknowledge-dismiss,WIPE-weight)
  - Edge cases: `drain_completed(0,0)` → 「全部儲好喇 ✓」2s expire（EC-B8）;sequencing — drain ✓ 入 LOGIN 先清

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_logout_drain.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(FSM — DRAINING)+ Story 010(banner)
- Unlocks: None
