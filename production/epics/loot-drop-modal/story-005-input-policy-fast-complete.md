# Story 005: Per-stage input policy + F5 fast-complete + two-stage tap + keyboard

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 5 / F5 / UI §D Input / EC-M19)+ UX spec `design/ux/loot-drop-modal.md`
**ADR**: N/A — presentation input policy;#33 exempt pattern 引用(story 016 斷言)
**Engine**: Godot 4.6 | **Risk**: LOW;**Engine Note**:4.6 dual-focus — tap 直接食 `gui_input`/`pressed`,**唔依賴 focus state**(`grab_focus()` 4.6 只影響 keyboard)

**Control Manifest Rules**:
- Required:knob 數值 config 讀(`SNAP_SEC`/`DISMISS_DEBOUNCE_SEC`)
- Forbidden:hover-only interaction(touch primary)

## Acceptance Criteria

- [ ] **AC-11**(×5):tap 喺 S0(t<D_entry)/S1/S4 一律 ignore;S2 → fast-complete;S3 → dismiss(S0/S1 ignore 兼兜 tap-through EC-M19)
- [ ] **AC-15**(debounce,錨點 = S3 entry):S2 tap @t → S3 @t+`SNAP_SEC`;第二 tap @S3+0.2s(<debounce,config 讀)ignore;第三 tap @S3+0.3s dismiss;natural 到達 S3 → 零 lockout
- [ ] **AC-16**(fast-complete 副作用):content snap over `SNAP_SEC`、freeze active 即 frame release / 未 issue 唔 issue(spy count 不增)、particle `stop()` natural fade 非 hard-cut、audio sting **零** stop/cut call(negative spy)、fast-complete tap **零 audio feedback call**(negative spy — deliberate silence)
- [ ] **AC-50**(F5):tap @t<D_entry ignore;@t∈[D_entry,T_block) → S3 @**min(t+SNAP_SEC, T_block)**(clamp);同 frame race natural supersede,S3 副作用 exactly-once;boundary frame tap = fast-complete(tiebreak:state 以 frame 開始時評估)
- [ ] **AC-37c**(keyboard):`ui_accept` 喺 S2/S3 == scrim tap(同一 handler、同一 per-stage policy);S0/S1/S4 ignore;catch-up `ui_cancel` == 「稍後再拆」

## Implementation Notes

- Tap surface = 全屏 scrim;CTA「影低佢」≥48px 只係 labelled affordance。
- Two-stage:S2 fast-complete → S3 commit 照 INV-M3(009);debounce min-readable 0.25s。
- Snap 用 SNAP_SEC=0.1 tween snap-to-final(0-frame 只留俾 rollback)。
- Freeze release 行 INV-M1 單一出口(007 實作 — 本 story 經 fake seam spy)。

## Out of Scope

- INV-M1 出口本體(007);S3 receive_loot(009);catch-up「稍後再拆」行為主體(014/015);#33 exempt negative spy(016)。

## QA Test Cases

GDD AC-11/15/16/50/37c GWT + pinned vectors(qa-plan-import-equivalent;F5 example:LEG tap@500ms→S3@600/dismiss@850;tap@1150→S3@1200 clamp)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_input_policy_f5.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 003、004
- Unlocks: 006、011
