# Epic: PersistenceLayer

> **Layer**: Foundation
> **GDD**: design/gdd/persistence-layer.md
> **Architecture Module**: PersistenceLayer (autoload pos 1, `src/autoload/persistence_layer.gd`)
> **Status**: Ready
> **Stories**: 16 stories — **15/16 Complete** ✅ (Story 016 BLOCKED: ADR-0003 Proposed)

## Overview

PersistenceLayer 係 Mirror Hero 嘅唯一 storage gateway，autoload position 1（最先 boot），擁有所有 IndexedDB namespaced storage、schema migration chain、clock-drift TTL、同 Safari ITP touch() 機制。佢採用 backend-primary + IndexedDB secondary cache 策略（ADR-0003）：in-memory write-through cache 確保 `read()` O(1) 無 file I/O，FileAccess 寫入確保 IndexedDB persistence，backend sync 提供 cross-device recovery。7 個 namespace（`gsm.*` / `gym.*` / `streak.*` / `wst.*` / `stat.*` / `ability.unlocked.*` / `_internal.*`）確保每個系統擁有獨立 storage domain。係所有其他 14 個 autoloads 嘅 dependency root。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003 (Proposed ⚠️) | Save State Strategy — backend-primary, IndexedDB secondary, Private Mode gate, Safari ITP, schema migration ≤900ms | MEDIUM |
| ADR-0006 Contracts 3/4/9/10/11/14 (Accepted ✅) | SerializableResource envelope, boot order, is_expired TTL, schema migration ceiling, IPersistence interface, Suspended gate | MEDIUM |

> ⚠️ ADR-0003 係 Proposed — 3 個 ADR-RATIFICATION-GATED ACs (AC-37/38/39) blocked 直至 ADR-0003 Accepted。核心 contracts (ADR-0006) 已 Accepted，基礎 implementation 可先行。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-persist-001 | Sync IPersistence interface — no `await` in 4 public methods | ADR-0006 Contract 11 ✅ |
| TR-persist-002 | In-memory write-through cache; `read()` O(1) zero file-I/O | ADR-0003 ⚠️ |
| TR-persist-003 | Atomic file flush via single `store_string(JSON.stringify(_cache))` blob | ADR-0003 ⚠️ |
| TR-persist-004 | SerializableResource: `payload_type` via `get_script().get_global_name()` | ADR-0006 Contract 3 ✅ |
| TR-persist-006 | Schema migration chain ≤6 steps × ≤150ms = 900ms ceiling | ADR-0006 Contract 10 ✅ |
| TR-persist-007 | Test spy contract: MockPersistenceLayer + `attach_write_spy/clear_spies` | ADR-0006 Contract 11 ✅ |
| TR-persist-009 | `is_expired(anchor_unix, ttl_seconds, anchor_monotonic_ms)` with drift tolerance ±300s | ADR-0006 Contract 9 ✅ |
| TR-persist-015 | Substate machine: Initialising/Migrating/Ready/Corrupt + API-rejection matrix | ADR-0006 ✅ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 17 TR-persist-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/persistence-layer.md` (32 ACs) are verified
- Logic stories: passing unit tests in `tests/unit/persistence/`
- Integration stories: IndexedDB round-trip tests on target browser (Chrome + Safari)
- `MockPersistenceLayer` test spy available for use by other systems' tests
- `is_expired()` helper passing all 5 scenarios from ADR-0006 Validation Criteria
- FileAccess `store_string()` bool return semantics verified against Godot 4.6 (MEDIUM engine risk)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [sync-interface-no-await](story-001-sync-interface-no-await.md) | Logic | **Complete** ✅ | ADR-0006 C4/C11 |
| 002 | [in-memory-cache](story-002-in-memory-cache.md) | Logic | **Complete** ✅ | ADR-0006 C11 |
| 003 | [atomic-flush-path](story-003-atomic-flush-path.md) | Logic | **Complete** ✅ | ADR-0006 C11 |
| 004 | [serializable-resource-envelope](story-004-serializable-resource-envelope.md) | Logic | **Complete** ✅ | ADR-0006 C3 |
| 005 | [test-spy-contract](story-005-test-spy-contract.md) | Logic | **Complete** ✅ | ADR-0006 C14 |
| 006 | [idb-fence-telemetry](story-006-idb-fence-telemetry.md) | Logic | **Complete** ✅ | ADR-0006 C11 |
| 007 | [clock-drift-ttl](story-007-clock-drift-ttl.md) | Logic | **Complete** ✅ | ADR-0006 C9 |
| 008 | [schema-migration-chain](story-008-schema-migration-chain.md) | Integration | **Complete** ✅ | ADR-0006 C10 |
| 009 | [corrupt-save-detection](story-009-corrupt-save-detection.md) | Integration | **Complete** ✅ | ADR-0006 |
| 010 | [substate-machine](story-010-substate-machine.md) | Integration | **Complete** ✅ | ADR-0006 C4 |
| 011 | [safari-itp-touch-delete](story-011-safari-itp-touch-delete.md) | Logic | **Complete** ✅ | ADR-0006 C9 |
| 012 | [namespace-migration-idempotency](story-012-namespace-migration-idempotency.md) | Logic | **Complete** ✅ | N/A |
| 013 | [boot-edge-cases](story-013-boot-edge-cases.md) | Integration | **Complete** ✅ | ADR-0006 C4 |
| 014 | [cross-system-contracts](story-014-cross-system-contracts.md) | Integration | **Complete** ✅ | ADR-0006 C11/C14 |
| 015 | [adr006-binding-gate](story-015-adr006-binding-gate.md) | Logic | **Complete** ✅ | ADR-0006 (all) |
| 016 | [storage-edge-cases-blocked](story-016-storage-edge-cases-blocked.md) | Integration | **Blocked** | ADR-0003 ⚠️ |

## Next Step

Run `/story-readiness production/epics/persistence-layer/story-001-sync-interface-no-await.md` then `/dev-story` to begin implementation.

> **Highest priority epic** — all 13 other implemented autoloads depend on PersistenceLayer. Implement first.
> Work through stories in dependency order: 001 → 002 → 003 → 004+005 → 006+007 → 008 → 009 → 010 → 011+012 → 013 → 014 → 015. Story 016 is BLOCKED until ADR-0003 Accepted.
