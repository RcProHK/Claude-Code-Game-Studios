# Story 013: G-CS-2 — #7 set_motion_reduction setter + boot self-read(camera story 011 解鎖)

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation(對象係 Foundation #7 — gate-inside-epic;= camera epic story 011 嘅實現)
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` G-CS-2 row + Rule 25;camera-system.md AC-27/AC-06b(P-08 contract:`request_focal()` silent no-op + dead-zone 0% hard-lock)+ L697 SettingsManager 措辭 erratum
**Requirement**: direct GDD trace(#7 camera epic story 011 BLOCKED-on-#22 — 本 GDD pin 後解鎖,呢個 story 就係佢)

**ADR Governing Implementation**: ADR-0003(boot read)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: camera_controller.gd 係 Camera2D 唯一 owner(CI lint)— setter 喺佢入面

**Control Manifest Rules (Presentation)**:
- Forbidden: Camera2D mutation 出 camera_controller.gd 外(CI enforced)

---

## Acceptance Criteria

- [ ] `CameraController.set_motion_reduction(bool)` setter:ON ⇒ `request_focal()` silent no-op(唔 push_warning — 預期 opt-out)+ Following mode `position_smoothing_enabled=false` + drag margins 全 0(dead-zone 0% hard-lock — camera-system.md AC-27)
- [ ] Boot self-read `settings.reduce_camera_motion`(documented default false)並 apply
- [ ] camera-system.md L697「SettingsManager autoload」措辭 erratum(→ consumer-self-read,引 #22 Rule 29)
- [ ] **#7 existing tests 零變紅** + combined CI gate green;camera epic story 011 標記 Complete(cross-ref)

## Implementation Notes

- camera-system.md AC-27/AC-06b 嘅 GWT 係實現 ground truth — grep 落實;#22 只係 UI surface(Rule 25)
- OFF→ON 喺 focal 進行中 → 即場 exit focal(或下次 request 起 no-op — 跟 #7 AC-06b 細節)

## Out of Scope

- Story 018:#22-side P-08 toggle wiring;Story 009:avatar breathing freeze(同一 key 嘅另一 consumer — #22 自己)

## QA Test Cases

camera-system.md AC-27/AC-06b GWT embed(該 epic 嘅 test file 名:`tests/integration/camera/camera_motion_reduction_test.gd` — 留意 GUT test_ prefix 慣例,實檔用 `test_camera_motion_reduction.gd`):ON → request_focal no-op + margins 0;boot persisted true → 生效;OFF 恢復

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/camera/test_camera_motion_reduction.gd` + combined CI
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003(namespace)
- Unlocks: Story 018(P-08 toggle)
