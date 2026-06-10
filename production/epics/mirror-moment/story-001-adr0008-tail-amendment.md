# Story 001: G-MM-1 ADR-0008 tail amendment + project.godot 登記 + G-MM-4 cadence registry

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` §「接線方向註記」/ Tuning Knobs / Cross-knob INV
**Requirement**: G-MM-1 + G-MM-4 cross-system gates(#29 未有 TR-IDs — GDD 直接 trace;#24/#26 先例)
**ADR Governing Implementation**: ADR-0008 Autoload Position Map(primary)
**ADR Decision Summary**: project.godot 係 autoload position sole ground truth;tail-append 用 partial-order constraint。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `MirrorMomentCoordinator` tail-append **喺 `AvatarRenderer`(#26)之後**(單向 #29→#26 boot order);terminal autoload(冇下游)。

**Control Manifest Rules (Polish layer)**:
- Required: autoload position 由 ADR-0008 + project.godot owns;cadence 常數從 source #26 註冊(registry-5b)
- Forbidden: referrer 註冊 duplicate const(`MIRROR_CADENCE_SECONDS` parity-bound 到 #26)
- Guardrail: #29 tail after #26(coupled pair boot order)

---

## Acceptance Criteria

- [ ] **G-MM-1**: `MirrorMomentCoordinator` 插入 `project.godot [autoload]` **tail,在 `AvatarRenderer`(#26)之後**;ADR-0008 amendment 記絕對位置 + partial-order(pred #26;terminal,冇下游 constraint)
- [ ] **G-MM-4**: `MIRROR_CADENCE_SECONDS`(604800)同 #26 `MILESTONE_CADENCE_SECONDS` **一齊 registry 註冊**;**從 source #26 GDD 註冊**(registry-5b 教訓:唔由 referrer 註冊 duplicate);entity registry 記 parity-bound 關係
- [ ] `BFCACHE_CONTINUE_THRESHOLD_MS`(30000)parity 到 #26 同名 const(記 registry)
- [ ] boot 後 autoload 載入無 error(headless `--import` + boot smoke)

---

## Implementation Notes

*Derived from ADR-0008 + registry-5b lesson:*

- `project.godot` `[autoload]` append `MirrorMomentCoordinator="*res://src/autoload/mirror_moment_coordinator.gd"`,排喺 `AvatarRenderer`(#26)之後(#28 Telemetry 若有則 keep last;#29 之前)。
- ADR-0008 doc amendment(跟 #24 G-LS-2 格式):記 `MirrorMomentCoordinator` tail-insertion + pred {#26}(+ #1/#3/#5 全更早)+「terminal,冇下游 ordering constraint」。
- technical-preferences ADR-0008 entry 同步加 amendment 摘要。
- **G-MM-4 registry**:`MIRROR_CADENCE_SECONDS` parity-bound 到 #26 `MILESTONE_CADENCE_SECONDS` —— 喺 entity registry **從 #26 source** 註冊兩個 const,記 parity 關係;CI-MM-3 code assert(story 014)守 runtime 相等。**唔好** referrer-register duplicate。

---

## Out of Scope

- Story 002: coordinator scaffold + cfis wiring
- Story 014: CI-MM-3 parity assert lint(本 story 只 registry doc)

---

## QA Test Cases

- **G-MM-1**: tail registration after #26
  - Given: project.godot `[autoload]`
  - When: parse order
  - Then: `MirrorMomentCoordinator` index > `AvatarRenderer` index;terminal
  - Edge cases: boot smoke green
- **G-MM-4**: cadence registry parity
  - Given: entity registry
  - When: read `MIRROR_CADENCE_SECONDS` + `MILESTONE_CADENCE_SECONDS`
  - Then: 兩者註冊 from #26 source;parity-bound 關係記低;值相等(604800)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass(autoload boot green)+ registry doc diff
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: #26 epic story 001(AvatarRenderer registered — tail-after 前提)
- Unlocks: Story 002(coordinator scaffold)
