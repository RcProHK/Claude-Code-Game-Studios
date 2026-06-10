# Story 009: Persistence schema avatar.evolution_tier_history + boot counters rebuild

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-12 / INV-4 / EC-BOOT-1/3/4/5 / init sequence
**Requirement**: CR-12 persistence schema(GDD 直接 trace;AC-05 historical lock 依賴 persisted current_tier)
**ADR Governing Implementation**: ADR-0003 Save State Strategy(primary)
**ADR Decision Summary**: backend-primary + IndexedDB(`user://`)secondary;IPersistence interface;schema migration 900ms ceiling;Private Mode detect-and-gate;localStorage FORBIDDEN。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: PersistenceLayer IPersistence(`user://` via FileAccess — 唔用 localStorage)。`avatar.evolution_tier_history` namespace 由 #3 register。

**Control Manifest Rules (Presentation layer)**:
- Required: persist via PersistenceLayer IPersistence;`avatar.*` namespace;load-time INV-4 assert
- Forbidden: `window.localStorage`(ADR-003);hardcoded fallback on config missing
- Guardrail: schema migration ≤900ms;append-only log FIFO cap 52

---

## Acceptance Criteria

- [ ] CR-12 schema `avatar.evolution_tier_history`:`current_tier:int`(max ever,monotonic)、`last_emitted_tier:int`、`last_milestone_emit_unix:int`、`last_micro_emit_unix:int`、`tier_attainment_log:Array`(append-only FIFO cap 52)、`pending_milestone`。schema v1。
- [ ] boot 讀 persistence rebuild counters(init sequence step 4);無 persisted posture-switch timestamp(CR-9 monotonic per-session — dead field 已刪)
- [ ] INV-4 load-time assert:`current_tier ≥ last_emitted_tier ≥ 0`;違反 → migration
- [ ] EC-BOOT-1(CRITICAL):`user://` unavailable(Private Mode)→ skip load;`last_emitted_tier=current_tier`;`persistence_degraded=true`;suppress milestone+micro emit this session(防 dup next restore)
- [ ] EC-BOOT-3:config `version_hash` ≠ persisted `config_hash_at_last_emit` → re-derive `last_emitted_tier` from current stats;clear pending;log `config_drift_recovery`;NO cross-version replay
- [ ] EC-BOOT-4:persisted `current_tier > 3`(future T4+)→ clamp T3;`last_emitted_tier=current_tier` post-clamp;log `tier_downgrade_migration`
- [ ] EC-BOOT-5(CRITICAL):persisted `last_emitted_tier > current_tier`(INV-4 violation)→ 當 corruption;`last_emitted_tier=current_tier`;no emit this session;log `persistence_corruption`

---

## Implementation Notes

*Derived from CR-12 + ADR-0003:*

- 用 #3 IPersistence read/write `avatar.*`(namespace-agnostic #3,#26 register consumer per Dependencies)。
- boot rebuild:read → INV-4 assert → 4 EC-BOOT recovery branch → feed Formula 2 historical_max + milestone gate(story 011/012)。
- field schema change → ADR-0003 900ms migration path。
- **persistence-consumer test 隔離**:test instance 喺 `add_child` 前注入 MockPersistenceLayer(reference_test_persistence_isolation — 真 autoload cache 跨 file 污染)。

---

## Out of Scope

- Story 011/012:milestone gate/emit 用 counters(本 story 只 schema + rebuild + boot recovery)
- Story 010:suspend snapshot(runtime,非 persistence schema)

---

## QA Test Cases

- **CR-12 schema**: round-trip
  - Given: write full schema
  - When: read back
  - Then: 全 field round-trip equal;log FIFO cap 52
  - Edge cases: append 第 53 → drop oldest
- **EC-BOOT-1**: Private Mode
  - Given: `user://` unavailable
  - When: boot
  - Then: skip load;degraded flag;milestone+micro suppressed this session
- **EC-BOOT-5**: corruption
  - Given: persisted last_emitted_tier > current_tier
  - When: load-time INV-4
  - Then: last_emitted_tier=current_tier;no emit;log corruption
  - Edge cases: EC-BOOT-4 clamp T4→T3

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/persistence_schema_test.gd` — MockPersistenceLayer 注入 add_child 前;4 EC-BOOT recovery case 必含
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline)
- Unlocks: Story 011/012(milestone gate 用 persisted counters)
