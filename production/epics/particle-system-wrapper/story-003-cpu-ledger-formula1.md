# Story 003: CPU Ledger + Formula 1 Multiplier Composition

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-005`, `TR-particle-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30** — cap 結構 Accepted；perf 數字 Provisional)
**ADR Decision Summary**: CPU ledger O(1) incremental tracking active particle total，±15% drift tolerance（只可 over-estimate，永不 under-estimate），2 秒 reconcile poll。Formula 1：`final = clamp(round(base × loot_mult × mobile_mult × caller_mult), 1, 256)`。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript `round()` 係 half-away-from-zero（非 banker's rounding）— `round(0.5)==1`、`round(1.5)==2`。Ledger update 唔可以 iterate pool（dict insert/erase only）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: ledger O(1) update；gameplay 數值 data-driven（base count 喺 preset 定義，唔 hardcode）
- Forbidden: ledger 全 pool scan
- Guardrail: drift ≤ ±15%，over-estimate only

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-05** — Ledger O(1) incremental，drift ≤ ±15%：50 次連續 play + 對應 expire 後 `_active_particle_total` 等於 live ledger 總和；update path 唔 iterate pool；`|total - ground_truth| / ground_truth <= 0.15`；任何時刻 `total >= ground_truth`（never under-estimate）；double-expire no-op。
- [ ] **AC-06** — Formula 1 canonical worked examples 全 8 case exact（GDD Section D 表）：Desktop HIT_LIGHT→8、Mobile HIT_HEAVY(18×0.5)→9、Desktop LOOT_BURST(24×3)→72、Mobile LOOT_BURST(24×3×0.5)→36、Desktop LOOT_RARE_BURST(48×3)→144、Desktop LOOT_RARE_BURST caller1.5→216、caller2.0 clamp→216(+warning)、Mobile HIT_LIGHT(8×0.5)→4。
- [ ] **AC-07** — Formula 1 clamp + round boundaries：intermediate 288→clamp 256(+warning)；0.2→round 0→clamp floor 1；round half-away（0.5→1、1.5→2）；exactly 256/1 無 warning。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- **強烈建議** Formula 1 抽成 static pure func `compute_final_count(base, loot_mult, mobile_mult, caller_mult) → int`（mirror CombatResolver static func pattern [[project_combat_resolver_done]]）— 令 AC-06/07 零 stub 純 deterministic test。
- Formula 1 步驟（GDD Section D / Rule 7）：base → ×loot_mult(3.0 if LOOT) → ×mobile_mult(0.5 if mobile) → ×caller_mult(clamped) → round() → clamp(1, 256)，clamp 命中 ceiling 時 `push_warning`。
- Ledger：`Dictionary` keyed by handle/slot id → count；`_active_particle_total` 增減同步 dict insert/erase；`LEDGER_EXPIRE_SAFETY_MS=50` 但 test 用直接 call `_on_expire` 驅動（非 wall clock）。
- Reconcile poll（2 秒）喺 Story 007（lifecycle）詳細處理；呢個 story 只建 ledger primitive + over-estimate invariant。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: tier selection（接收 final_count；呢個 story 計 final_count）
- Story 004: LRU eviction（用 ledger 嘅 total 判斷滿）
- Story 007: 2-秒 reconcile scheduler（lifecycle timer 驅動）+ EC15 drift reconciliation

---

## QA Test Cases

- **AC-05**: ledger O(1) incremental, drift ±15%
  - Given: SUT booted, stub nodes, expiry 用直接 call 驅動（NOT real timer）
  - When: 50 次連續 play + 對應 `_on_expire()`
  - Then: 每 op 後 `_active_particle_total` == live ledger 總和 AND update 唔 full-scan AND final drift ≤0.15
  - Edge cases: 任何時刻 `total >= ground_truth`（over-estimate only）；double `_on_expire` no-op total 不變；expiry 用 direct call 保 determinism

- **AC-06**: Formula 1 canonical 8 cases exact（見 AC 列表 8 case，全 assert_eq integer）
  - Edge cases: boundary-value test，magic number IS the point（coding-standards exception）；round half-away

- **AC-07**: clamp + round boundaries
  - Given: `compute_final_count` pure func
  - When: intermediate 288 → 256(+warning)；0.2 → 1（floor）
  - Edge cases: round half-away 0.5→1/1.5→2；exactly 256 無 warning；exactly 1 無 warning；負 intermediate 不可能（防禦 lower clamp）

> **Note**: AC-06/07 係全 epic 最高價值自動化 test — 純算術、全 deterministic、無 GPU。抽 static pure func 後零 stub。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/particle/test_ledger_and_formula1.gd` — must exist and pass（AC-05 + AC-06 + AC-07）

**Status**: [x] Created; GUT 9/9 PASS（particle dir 28/28）+ combined 1122/1123（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 001（play surface）、Story 002（pool — ledger track slot usage）
- Unlocks: Story 004（LRU 用 ledger total）、Story 007（reconcile scheduler）

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3（AC-05 ledger O(1) + over-estimate-only + double-expire no-op + 50-cycle reconcile；AC-06 Formula 1 八個 canonical case exact；AC-07 ceiling 256 / floor 1 / round half-away / exact boundary）
**Implementation**:
- `particle_handle.gd` 加 `handle_id`（ledger key）。
- `particle_system_wrapper.gd` 加：Formula consts（LOOT_BURST_MULTIPLIER 3.0、MOBILE_FALLBACK_MULTIPLIER 0.5、FINAL_COUNT_FLOOR 1、MAX_ACTIVE_PARTICLES 200）、`_is_mobile`（Story 005 wire；default false）、ledger 狀態（`_active_particle_total`/`_ledger`/`_next_handle_id`）。
- **Static pure func**（qa-lead 建議）：`compose_raw_count()`（roundi pre-clamp）+ `compute_final_count()`（clampi [1,256]）— 零 stub deterministic test，mirror CombatResolver static pattern。
- `_is_loot()` static、`_compose_for_preset()` instance（loot/mobile/caller compose + ceiling-clamp warn）。
- `_on_expire(handle_id)` idempotent（ledger erase + total decrement + slot release）。
- `play()` 用 `_compose_for_preset` 計 final_count（取代 Story 002 base placeholder）+ assign handle_id + ledger insert + total increment。
**Key discoveries**:
1. `roundi()` half-away-from-zero 符合 GDD Rule 7（roundi(0.5)=1, roundi(1.5)=2），非 banker's rounding。
2. Ceiling-clamp warning（raw>256）喺 v1 preset 唔可達（最大 LOOT_RARE_BURST 48×3×1.5=216）— warn branch defensive，AC-07 test 驗 clamp **值**（compute_final_count(96,3,1,1)==256）而非 unreachable warn（anti-fabrication：唔 assert 跑唔到嘅 path）。
**Deviations**: expiry **timer 排程**（create_timer lifetime+50ms）deferred 去 Story 007 lifecycle（lifetime data 屬 Story 008；2-sec reconcile poll 係 Story 007 AC-20）— Story 003 只實作 ledger primitive + `_on_expire`，test 直接 call（per qa-lead，no real timer in headless）。`_is_mobile` default false 待 Story 005 wire。
**Test Evidence**: `tests/unit/particle/test_ledger_and_formula1.gd`（9 test functions）
**Code Review**: Pending（lean mode — 後續 batch review）
