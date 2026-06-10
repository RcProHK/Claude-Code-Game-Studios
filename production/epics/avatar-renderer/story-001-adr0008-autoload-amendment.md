# Story 001: G-AR-1 — ADR-0008 autoload amendment + project.godot 登記

> **Epic**: Avatar Renderer (#26)
> **Status**: ✅ Complete (2026-06-10)
> **Completion Note**: pre-existing `AvatarRenderer` autoload 排錯位(喺 #5 ParticleSystemWrapper 之前,v1「pos 11/F-5」ghost)→ 移去 #5 之後(滿足 hard-pred partial-order)。`project.godot` 重排 + comment 清 v1;`adr-0008-autoload-position-map.md` table row 11/12 對調 + **constraint 4b**(`{#11,#12,#3,#1,#5} ≺ AvatarRenderer ≺ MirrorMomentCoordinator`)+ traceability(#26 v2.1 / #29 tail)。**驗證**:`--import` exit 0 + GUT `tests/unit/core` 85/86 pass(1 pre-existing pending AC-37,0 fail)autoload harness 乾淨 boot。**Learning**:project 冇 main scene → boot-smoke 用 GUT,唔用 `--quit-after`。
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` §「Autoload Boot Position (ADR-0008 ground truth)」+ init sequence
**Requirement**: G-AR-1 cross-system gate(#26 未有 TR-IDs — requirement 由 GDD 直接 trace;/architecture-review Phase 8 未跑,#22/#23/#24 先例)
**ADR Governing Implementation**: ADR-0008 Autoload Position Map(primary)
**ADR Decision Summary**: project.godot 係 absolute autoload position 嘅 sole ground truth;新 autoload 用 partial-order constraint 插入,amendment 記錄絕對位置。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: autoload 註冊喺 `project.godot [autoload]` section;sequential boot per ADR-0006 Contract 4。

**Control Manifest Rules (Presentation layer)**:
- Required: autoload position 由 ADR-0008 + project.godot owns,GDD 唔 hardcode 數字(v1 hardcode「pos 11」錯咗)
- Forbidden: assert 絕對 position number 喺 GDD body
- Guardrail: hard predecessors 必須 boot 喺 #26 前

---

## Acceptance Criteria

- [ ] `AvatarRenderer` 插入 `project.godot [autoload]`,位置在 hard predecessors 之後:#11 StatSystem / #12 AbilitySystem / #3 PersistenceLayer / #1 GSM / #5 ParticleSystemWrapper(全部已 registered)
- [ ] ADR-0008 doc amendment 加一條:`AvatarRenderer` 絕對位置 + partial-order constraint(preds {#11,#12,#3,#1,#5};零 #14/#15/#21/#22/#23/#24 constraint)
- [ ] 無 #29 MirrorMomentCoordinator 預先註冊(#29 story 001 G-MM-1 另行 tail-append after #26)
- [ ] boot 後 autoload 載入無 error(headless `--import` + boot smoke)

---

## Implementation Notes

*Derived from ADR-0008 + GDD §Autoload Boot Position:*

- 喺 `project.godot` `[autoload]` section append `AvatarRenderer="*res://src/autoload/avatar_renderer.gd"`(`*` = singleton autoload)。實際 line 位置:排喺 `ParticleSystemWrapper`(#5)之後即可滿足 5 個 hard pred(#11/#12/#3/#1/#5 全部更早)。
- ADR-0008 doc(`docs/architecture/adr-0008-autoload-position-map.md`)加 amendment entry,跟 #24 G-LS-2 / #23 G-IU-2 amendment 格式:記 `AvatarRenderer` insertion + preds + 「零下游 ordering constraint(只讀 #11/#12/#3/#1/#5)」。
- technical-preferences.md ADR-0008 entry 同步加一行 amendment 摘要(#22/#23/#24 先例)。
- **唔好** hardcode position number 入 GDD body(Pass 2 F-5 anti-pattern)。

---

## Out of Scope

- Story 002: coordinator scaffold + 實際 cfis subscription wiring
- #29 story 001: MirrorMomentCoordinator tail-append(G-MM-1,after #26)

---

## QA Test Cases

- **AC-1**: `AvatarRenderer` registered after predecessors
  - Given: project.godot `[autoload]` section
  - When: parse autoload order
  - Then: `AvatarRenderer` index > index of each {StatSystem, AbilitySystem, PersistenceLayer, GameStateMachine, ParticleSystemWrapper}
  - Edge cases: 確認無重複註冊;`*` singleton prefix 在
- **AC-2**: boot smoke
  - Given: registered autoload
  - When: `godot --headless --import` then boot
  - Then: 零 autoload load error;`AvatarRenderer` singleton 可達

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass(`production/qa/smoke-*.md`)— autoload boot green
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None(scaffold 前提 — 最先做)
- Unlocks: Story 002(coordinator scaffold)
