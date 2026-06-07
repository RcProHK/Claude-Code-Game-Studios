# Story 007: Lifecycle AC suite + subscriptions + zero-persist negative

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 1/3/4/6 + States + EC-12(cancel 邊)
**Requirement**: direct GDD trace(AC-04 / AC-05 / AC-06 / AC-07 / AC-08 / AC-37)

**ADR Governing Implementation**: ADR-0006(primary — C6 cfis + ghost guard + call_deferred)+ ADR-0003(AC-37 zero-persist)
**ADR Decision Summary**: cfis 同步 connect 只 defer initial delivery;#23 唯一 subscription = GSM;零 persist = 連 namespace 都唔開。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: mock GSM emit(G-CS-10 同款 mock-level);injected clock advance() 行 FORCE_CLOSE_MAX_MS

**Control Manifest Rules (Presentation)**: cfis 禁 .bind()(CI lint 已存在)

---

## Acceptance Criteria

- [x] **AC-04**:全 GSM states 逐個 → 只 IDLE/DISCONNECTED 准(double guard;唔 hardcode 數)— 002 段 `test_can_open_only_in_permitted_states` + `test_open_rejected_outside_permitted`
- [x] **AC-05**:BULK_CONFIRM 開緊 + GSM→WORKOUT_ACTIVE → modal cancel(#17 count/shards 不變)+ ≤FORCE_CLOSE_MAX_MS CLOSED + 零 play_sfx(**同 test positive control**:先 player-initiated open assert `ui_charscreen_open` 一響)
- [x] **AC-06**:SUSPENDED → instant snap;resume 唔 auto-reopen
- [x] **AC-07**:MAILBOX + WEAPON + modal + pending set → close→re-open 全 reset — 002 段 `test_open_clean_slate_resets_all_axes_and_pending`
- [x] **AC-08**:先 assert GSM connect **存在**(positive)再 assert 只此一條;#11/#26 零 connect(seam 不存在 introspect);零 `is_input_permitted` call(source-level);3 close paths 後零 active
- [x] **AC-37**:完整操作 session + 3 close paths → 零 #23-origin PersistenceLayer write(spy;positive control = #17 `set_lock` write 照行 + 全部 keys `inventory.*`)

## Implementation Notes

- FSM 行為已喺 002 fork — 本 story 係 AC 級驗收 suite(mechanism-agnostic — Group B 口徑)
- AC-37 spy:IPersistence mock 注入 #17 seam,收集 writes,filter #23-origin keys(應為空集 — #23 根本冇 key prefix)

## Out of Scope

- Story 016:AC-09(G-IU-4 gated);Story 012:EC-12 executed 邊(AC-36)

## QA Test Cases

(= 上面 ACs GWT — GDD 3-verifier verified,直接 implement against)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_lifecycle.gd`
**Status**: [x] Created — suite 而家 17 tests(13 scaffold + 4 AC suite)全 pass;combined gate CLEAN 2302/2301/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 6/6 passing(AC-04/07 由 story 002 tests cover — mechanism-agnostic suite 口徑,標註喺 file header)
**Deviations**: None — AC-08「零 is_input_permitted」用 source-level introspect(doc-comment 提及位豁免);AC-37 spy 注入 #17 `_persistence` seam
**Test Evidence**: +4 tests — AC-05(真 #17 + positive SFX control)/ AC-06(snap + resume)/ AC-08(positive-first introspect + 3 paths)/ AC-37(spy + positive control + key prefix sweep)
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續;本 story 零 production code 改動 — 純 test suite)

## Dependencies

- Depends on: Story 002(+ 006 嘅 open-path reads 已通)
- Unlocks: —(suite-level)
