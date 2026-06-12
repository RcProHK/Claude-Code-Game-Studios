# Story 005: Formula 3 hit-sample + Formula 4 lossless aggregate

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — Formula 3 hit_sample_keep + Formula 4 CombatAggregate lossless; unit GUT 7/7, 27 asserts; AC-07 total_hits==real (sampling-decoupled) + AC-06 force_keep + k≤0 guard + determinism all green)
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 8(sampling)+ Formula 3(hit_sample_keep)+ Formula 4(combat_aggregate lossless 不變量)。AC-04/06/07。
**ADR Governing Implementation**: ADR-N/A — pure formula / deterministic sampling,no architectural pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: deterministic stride（mod）—— 無 RNG（測試確定性）。

**Control Manifest Rules (Polish layer)**:
- Required: aggregate 無條件 update（與 sampling 無關）
- Forbidden: sampling 影響 aggregate 真值
- Guardrail: crit 強制 keep（Pillar 3 signal 唔抽走）

---

## Acceptance Criteria

- [ ] **Formula 3**:`keep_individual = (hits_seen mod HIT_SAMPLE_STRIDE == 0)`,`hits_seen` sample 前已 +1
- [ ] **Formula 3 crit override**:`is_crit == true` 或 `damage_tier == CRITICAL` 嘅 hit 強制 keep（AC-06）
- [ ] **Formula 4**:每個 `hit_resolved` **無條件** update accumulator:`total_hits += 1` / `total_damage += damage_dealt` / `crit_count += is_crit?1:0` / `tier_count[tier] += 1`
- [ ] **AC-07 不變量**:`combat_aggregate.total_hits == 實際 hit_resolved 數`,與 `HIT_SAMPLE_STRIDE` 無關
- [ ] `combat_aggregate` event 喺 flush / workout boundary 整批送出（接 Story 009/011）

---

## Implementation Notes

*Derived from GDD Formula 3/4 + Rule 8:*

- accumulator 係 telemetry 內部 dict,**永遠** update（喺 handler 入口,sample 決策**之前或之後**都得,但必須無條件）。
- sample 決策只控**個別 hit event 入唔入 buffer**;aggregate 唔受影響。
- `HIT_SAMPLE_STRIDE` 由 config 注入（Story 017 registry）;測試用 injected stride。
- crit override:`keep = base_keep OR is_crit OR damage_tier==CRITICAL`。
- 本 story 只做 sample + accumulate 邏輯;真 `hit_resolved` 訂閱在 Story 009。測試用直接餵 payload。

---

## Out of Scope

- Story 009:真 `hit_resolved` 訂閱 wiring
- Story 011:flush 時送 combat_aggregate

---

## QA Test Cases

- **AC-1 (sampling stride)**:
  - Given: stride=10,餵 100 個 hit payload
  - When: sample
  - Then: 入 buffer 嘅個別 hit event = 恰好 10 個（hits 10,20,…,100）
  - Edge cases: stride=1 → 全保留 100;stride=100 → 1 個(第100)
- **AC-2 (crit override, AC-06)**:
  - Given: stride=10,一個 crit hit 喺第 7 位（非 stride 位）
  - When: sample
  - Then: 該 crit 個別 event 仍 keep
  - Edge cases: damage_tier==CRITICAL 同樣強制 keep
- **AC-3 (lossless, AC-07)**:
  - Given: 任意 stride ∈ [1,100],餵 N 個 hit
  - When: 讀 combat_aggregate.total_hits
  - Then: == N（精確，與 stride 無關）
  - Edge cases: total_damage == Σ damage_dealt;crit_count ≤ total_hits;tier_count 各 ≥ 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/telemetry/test_hit_sampling.gd` + `test_aggregate_lossless.gd` + `test_crit_always_kept.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(envelope）/ Story 004(buffer)
- Unlocks: Story 009（combat subscription wires this）
