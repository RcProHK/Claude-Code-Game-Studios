# Story 003: G-CS-3 — settings.* + charscreen.* namespace + VALID_NAMESPACES + canonical key pin

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)— entities.yaml +2 namespace entries(canonical key pin 寫入 notes)+ persistence_layer.gd VALID_NAMESPACES +2 + design/CLAUDE.md path erratum;persistence-layer 65/65 green
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — G-CS-3 row + Rule 27/28/31
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0003
**ADR Decision Summary**: persistence namespace 須 #3 registry process 註冊;localStorage FORBIDDEN;`user://` 經 PersistenceLayer。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 無

**Control Manifest Rules**: Forbidden `window.localStorage`(CI: check_local_storage_calls.gd)

---

## Acceptance Criteria

- [ ] `settings.*` + `charscreen.*` 註冊入 #3 registry + `design/registry/entities.yaml`
- [ ] `persistence_layer.gd` L291-296 `VALID_NAMESPACES` array 加 `"settings."` + `"charscreen."`(debug push_warning spam 消除)
- [ ] Canonical key pin 記錄:`settings.reduce_camera_motion`(accessibility-requirements.md L63 + interaction-patterns.md L272 一致;#22 GDD 已統一)
- [ ] `design/CLAUDE.md` accessibility-requirements path erratum(寫 `design/ux/` 實際喺 `design/`)

## Implementation Notes

- 跟 G-PR-6 / G-Z-3 namespace story 先例;documented defaults 記錄(`motion_intensity` 1.0 / `reduce_camera_motion` false)
- `charscreen.stat_watermark.[stat_id]` key shape 記錄({value, date})

## Out of Scope

- Story 006:watermark 實作;Story 018:settings write 實作

## QA Test Cases

- **Lint**: Given debug build write `settings.x` / `charscreen.x`,When `_validate_namespace`,Then 零 push_warning
- **Registry**: grep entities.yaml hit 兩個 namespace

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check + grep evidence;combined CI gate(VALID_NAMESPACES 係 code edit)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: Story 006(watermark persist)/ Story 018(settings persist)
