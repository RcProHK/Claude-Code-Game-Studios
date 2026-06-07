# Story 007: Lifecycle AC suite + subscriptions + zero-persist negative

> **Epic**: Inventory UI (#23)
> **Status**: Ready
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

- [ ] **AC-04**:全 GSM states 逐個 → 只 IDLE/DISCONNECTED 准(double guard;唔 hardcode 數)
- [ ] **AC-05**:BULK_CONFIRM 開緊 + GSM→WORKOUT_ACTIVE → modal cancel(#17 count/shards 不變)+ ≤FORCE_CLOSE_MAX_MS CLOSED + 零 play_sfx(**同 test positive control**:先 player-initiated open assert `ui_charscreen_open` 一響)
- [ ] **AC-06**:SUSPENDED → instant snap;resume 唔 auto-reopen
- [ ] **AC-07**:MAILBOX + WEAPON + modal + pending set → close→re-open 全 reset
- [ ] **AC-08**:先 assert GSM connect **存在**(positive)再 assert 只此一條;#11/#26 零 connect;零 `is_input_permitted` call(同一 introspect);3 close paths 後零 active
- [ ] **AC-37**:完整操作 session + 3 close paths → 零 #23-origin PersistenceLayer write(spy;positive control = #17 自己 write 照行)

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
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002(+ 006 嘅 open-path reads 已通)
- Unlocks: —(suite-level)
