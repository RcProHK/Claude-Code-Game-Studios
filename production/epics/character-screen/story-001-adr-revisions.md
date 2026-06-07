# Story 001: G-CS-7 + G-CS-8 — ADR-0001 layer 60 revision + ADR-0008 autoload insertion

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)— ADR-0001 status amendment + 拓撲圖 layer 60 + capture enumeration ×2 + #22 section;ADR-0008 status amendment + insertion row;technical-preferences 兩行 revision 註記
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/character-screen.md` — Rule 34 + G-CS-7 / G-CS-8 rows
**Requirement**: direct GDD trace(#22 無 TR-IDs — #21 先例)

**ADR Governing Implementation**: ADR-0001(primary)+ ADR-0008
**ADR Decision Summary**: ADR-0001 topology 係 project architectural standard,改動須 ADR revision(#21 G-LM-1 先例);ADR-0008 係 autoload 位置 sole ground truth,新 autoload 必行 insertion procedure(G-LM-5/G-PR-3/G-Z-1 先例)。

**Engine**: Godot 4.6 | **Risk**: LOW(doc-only)
**Engine Notes**: 無 — 純文檔修訂

**Control Manifest Rules (Presentation)**:
- Required: 無 code
- Forbidden: 無 code
- Guardrail: ADR-0008「do NOT write absolute position numbers into any GDD」

---

## Acceptance Criteria

- [ ] ADR-0001 revision merged:CanvasLayer **60**(PAUSABLE)註冊 + L107 capture enumeration「0/10/50」→「0/10/50/60」+「P-07 preview 要求 <100」mechanism note(canonical cite:ADR-0001 L107+L122;code-side screen_effects.gd L363-364)
- [ ] ADR-0008 revision merged:#22 `CharacterScreenCoordinator` insertion rule — tail append 喺 LootRevealCoordinator 後;predecessor constraints `{GSM(C6), StatSystem, InventorySystem, AvatarRenderer, ScreenEffects, CameraController, PlatformDetect, AudioManager, PersistenceLayer} ≺ #22`;#28 Telemetry 維持 last
- [ ] technical-preferences.md ADR log 兩行 update(revision 註記)

## Implementation Notes

- 跟 #21 G-LM-1 revision 格式(ADR-0001 內 revision history section);layer 60 三條約束寫入:>50(#20 HUDLayer)/ <100(BackBufferCopy capture — P-07 preview 字面兌現)/ <110-120(#21 layers)
- ADR-0008:只寫 partial-order constraints,**唔寫 absolute number**(ADR-0008 L107-109)
- Mood chain 注記(GDD Rule 34 binding):IDLE/DISCONNECTED steady state saturation = identity(`u_world_saturation_drop` 只由 #21 ceremony 驅動)— 可引 GDD,唔使再 grep

## Out of Scope

- Story 002:coordinator code + project.godot 登記(本 story 只係 ADR 授權)

## QA Test Cases

- **Doc check**: ADR-0001 diff 含 layer 60 + enumeration update;ADR-0008 diff 含 #22 insertion rule;grep「0/10/50/60」hit ADR-0001 L107 區域

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: doc diff(ADR-0001 + ADR-0008)+ smoke check pass
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: Story 002(scaffold 須 ADR 授權)
