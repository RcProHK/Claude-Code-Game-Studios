# Story 008: Persistence schema mirror_moment.* + boot rebuild + G-MM-6 namespace

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M13 / EC-MM-17 / Dependencies #3
**Requirement**: AC-19(GDD 直接 trace)+ G-MM-6 cross-system gate(#3 namespace)
**ADR Governing Implementation**: ADR-0003 Save State Strategy(primary)
**ADR Decision Summary**: IPersistence;schema migration 900ms ceiling;`mirror_moment.*` namespace 並列 #8 `streak.*` / #17 `inventory.*`;#3 namespace-agnostic。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: PersistenceLayer IPersistence(`user://` FileAccess)。`mirror_moment.*` 新 namespace。

**Control Manifest Rules (Polish layer)**:
- Required: persist via IPersistence;只 `mirror_moment.*` namespace;zero `avatar.*` write(CI-MM-4)
- Forbidden: `window.localStorage`(ADR-003);write `avatar.*`(ownership boundary);tier-derivation state
- Guardrail: schema migration ≤900ms

---

## Acceptance Criteria

- [ ] **AC-19**(CR-M13): 慶典 dismiss → persist 只寫 `mirror_moment.*` namespace,**零** write `avatar.*`(CI-MM-4 + `schema_version=1`)
- [ ] CR-M13 schema `mirror_moment.*`:`last_ceremony_unix:int`(0=never)、`last_ceremony_tier:int`、`pending_evolution_ceremony:bool`、`pending_tier:int`、`pending_source_metrics:Dictionary`、`week_had_change:bool`、`ceremony_count:int`、`last_shared_unix:int`、`schema_version:int=1`
- [ ] **零 evolution-tier 計算 state**(無 threshold / 無 historical-max — 嗰啲係 #26 `avatar.evolution_tier_history.*`)
- [ ] **G-MM-6**:`mirror_moment.*` namespace 註冊(#3 namespace-agnostic,additive,並列 #8/#17)
- [ ] boot read rebuild latch(CR-M11,story 002 consume);field change → ADR-0003 900ms migration
- [ ] EC-MM-17:crash 喺呈現中途 → 全部 persist;crash 喺 set marker 前 → re-boot re-arm 重呈現(idempotent);後 → 唔重呈現

---

## Implementation Notes

*Derived from CR-M13 + ADR-0003:*

- 用 #3 IPersistence read/write `mirror_moment.*`(#3 namespace-agnostic）。
- **CI-MM-4 命脈(story 014 lint)**:#29 persist write 只落 `mirror_moment.*`,零 `avatar.*`(ownership boundary — tier-state 係 #26)。
- boot rebuild feed FSM latch(story 002)。
- **persistence-consumer test 隔離**:MockPersistenceLayer 注入 add_child 前(reference_test_persistence_isolation)。

---

## Out of Scope

- Story 002:FSM latch rebuild consume(本 story 提供 schema + read/write)
- Story 014:CI-MM-4 namespace lint
- Story 012:window marker write(本 story 提供 schema field)

---

## QA Test Cases

- **AC-19**: namespace + schema
  - Given: 慶典 dismiss
  - When: persist
  - Then: 只寫 `mirror_moment.*`,零 `avatar.*`;schema_version=1
  - Edge cases: 全 9 field round-trip;zero tier-state
- **EC-MM-17**: crash mid-ceremony
  - Given: crash 前/後 set marker
  - When: re-boot
  - Then: 前 → re-arm 重呈現(idempotent);後 → 唔重呈現

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/persistence_schema_test.gd` — MockPersistenceLayer 注入 add_child 前;namespace isolation + crash-recovery case
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(FSM consume latch)
- Unlocks: Story 006(latch persist)/ Story 012(window marker)/ Story 014(CI-MM-4)
