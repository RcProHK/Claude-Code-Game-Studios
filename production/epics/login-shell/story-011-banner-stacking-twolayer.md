# Story 011: Banner stacking + dedupe + DISCONNECTED priority + two-layer 獨立性

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 7 + AC-33/34/54;EC-B2/B4/B5/B7/E3)
**Requirement**: banner 單 slot + 「+N」+ DISCONNECTED priority + two-layer 分離

**ADR Governing**: ADR-0001(primary — two-layer 拓撲)
**ADR Decision Summary**: `ErrorBannerLayer`(111 ALWAYS)獨立於 shell state — banner 喺 workout 之上照顯示。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: dedupe key = `(signal_source, error_code, key/id)`;Priority:DISCONNECTED > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類。

**Control Manifest Rules**:
- Required: banner `max_visible = 1`（疊 banner = 迫近 modal 體感）
- Required: 兩 layer 分離（LoginShellLayer 62 / ErrorBannerLayer 111）

---

## Acceptance Criteria

*GDD AC-33 / AC-34 / AC-54:*

- [ ] **AC-33**: ONGOING banner 喺主 slot,DISCONNECTED status 出現 → DISCONNECTED 佔主 slot、ONGOING 入「+N」;DISCONNECTED resolved → ONGOING 升返（EC-B4）
- [ ] **AC-34**: `(FLUSH_FAILED, "k1")` banner 存在,同 key 再 fire → entry count 唔變、timestamp 更新、「+N」唔虛高（EC-B5）
- [ ] **AC-54**: shell `HIDDEN`(mock GSM WORKOUT_ACTIVE),mock #3 emit ONGOING(`READ_ONLY_FILESYSTEM`) → `ErrorBannerLayer` banner `visible == true` 而 `LoginShellLayer.visible == false`（two-layer 獨立性 — EC-E3）
- [ ] 「+N」detail list 展開時新 error 到 → 即時 append + counter 更新（唔 close-reopen — EC-B7）

---

## Implementation Notes

- 單 banner slot(`max_visible = 1`)顯示最高 severity;其餘 collapse 「+N」（tap 展開 detail list）。
- dedupe key `(signal_source, error_code, key/id)` — 同 key 連 fire refresh timestamp 唔疊。
- Priority ladder：DISCONNECTED status > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類（drain/reconnect 成功）。
- two-layer：`ErrorBannerLayer`(111 ALWAYS)獨立於 shell HIDDEN — banner 照顯示喺 workout 之上（Rule 1）。

---

## Out of Scope

- Story 010:severity map + comparator core（本 story 用其 arrival_sequence）
- Story 012:DISCONNECTED surface 行為（本 story 只做 banner priority）

---

## QA Test Cases

- **AC-33**: DISCONNECTED priority
  - Given: ONGOING 主 slot;When: DISCONNECTED status 出現;Then: DISCONNECTED 主 slot、ONGOING「+N」;resolved → ONGOING 升返
- **AC-34**: dedupe refresh
  - Given: `(FLUSH_FAILED,"k1")` banner;When: 同 key 再 fire;Then: count 不變、timestamp 更新、「+N」唔虛高
- **AC-54**: two-layer 獨立
  - Given: shell HIDDEN(WORKOUT_ACTIVE);When: mock #3 emit ONGOING;Then: ErrorBannerLayer.visible==true 而 LoginShellLayer.visible==false

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_banner_stack.gd`(stacking)+ `test_layer_spec.gd`(two-layer AC-54)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010(banner core)
- Unlocks: None
