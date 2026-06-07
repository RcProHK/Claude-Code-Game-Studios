# Story 016: Banner stack + EC-M10/M11 + telemetry hooks + #33 exempt

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-17/33/36/61(AC-62 已喺 011 收);GUT 126/126;combined 2056/2055/0 fail;commit 05d1234)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 12 / Rule 15 / EC-M10 / EC-M11 / Rule 5 exempt)
**ADR**: ADR-0009(telemetry payload — append-log pattern,#15/#17 verbatim)+ ADR-0006 C13(IInputPolicy — exempt 即「唔 call」)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:`IInputPolicy` 經 injection;exempt handler = #21 全程零 call `is_input_permitted()`(#33 EC-15 / GSM AC-11b)
- Forbidden:banner 侵 #20 L1 anchor zone;web `get_display_safe_area()` 依賴(固定 top margin 兜)

## Acceptance Criteria

- [ ] **AC-17**(#33 exempt):`is_input_permitted()==false` 時 dismiss tap → tap 照被消費且 #21 全程零 call 該 predicate(negative spy)
- [ ] **AC-33**(banner deferral + priority):modal active 時 `loot_disabled` → banner dismiss 後先出;同時收 rollback → rollback 先;stack 同屏最多 1 條且 `private_mode` > audio silent-mode
- [ ] **AC-36**(telemetry hooks ×6):`ceremony_skip_attempted(tier)` / `time_to_dismiss_ms`(EPIC+ <500ms 帶 `suspicious_dismiss` flag)/ `re_reveal_count(tier)` / `stash_exit_count(tier)` / `catchup_abandoned(remaining)` / `catchup_truncated(remaining, reason)` — 6 情境各觸發一次正確 payload(local signal;#28 sink 唔需存在)
- [ ] **AC-61**(EC-M10):DISCONNECTED reveal 同 connected 完全一致:無 spinner/sync badge node、receive_loot 照 call
- [ ] **AC-62**(EC-M11):safe→safe(DISCONNECTED→IDLE)繼續無 stash-exit;→ 非 safe 先觸發

## Implementation Notes

- Banner stack:top edge full-width、固定 top margin;displacement 語意 = 被 displace banner 喺高 priority 清走後 re-render(predicate 仍 true 返嚟 — ≠ one-shot dismissal,防 audio banner 永鎖);#20-side suppress 接線屬 Q-OQ6(AC-78 → 026)。
- Catch-up summary banner 唔屬 banner stack(interactive CTA,CATCHUP_PROMPT state,center)。
- Telemetry:append-log pattern(#15/#17 verbatim);N-2 threshold pin 記錄(EPIC+ re-reveal >5% over 首 100 RARE+ → 重開 D1)。
- `role=status` announce 一次(polite;reveal announcement assertive 係 025)。

## Out of Scope

- `announce_aria` gateway(025);#20 real banner arbitration(026 AC-78);safe-state set 定義(GSM own)。

## QA Test Cases

GDD AC-17/33/36/61/62 GWT(qa-plan-import-equivalent);AC-36 ×6 parametrized payload assert。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_banner_telemetry.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002、011
- Unlocks: 026
