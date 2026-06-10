# Story 005: G-AR-2 — max_class_depth resolution + EC-TIER-5 fail-safe

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` Formula 2 specialist path / Q-OQ-DEPTH / EC-TIER-5 / CI-INV-2
**Requirement**: G-AR-2 cross-system gate(Q-OQ-DEPTH forward dep on #12)+ AC-04 specialist-path input
**ADR Governing Implementation**: ADR-0011 PR Detection Topology(primary — client-side derivation pattern)
**ADR Decision Summary**: derivation client-side deterministic + contract-pinned;client 可 derive 但要 contract-pin id-convention。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(cross-system forward dep on shipped #12)
**Engine Notes**: shipped `#12.get_unlocked_abilities()->Dictionary`(key=ability_id;value=UnlockRecord {first_unlocked_at_unix, source, source_event_id} — **NO class/tier field**)。`get_max_unlocked_class_tier()` **唔存在**(v1 phantom — grep-verified absent)。

**Control Manifest Rules (Presentation layer)**:
- Required: `max_class_depth` from `#12.get_unlocked_abilities()` keys,deterministic;EC-TIER-5 fail-safe
- Forbidden: 引用唔存在嘅 `get_max_unlocked_class_tier()`;從 stat/equipment 推 depth(CI-INV-2)
- Guardrail: depth 解唔到 → 0(generalist path 仍 work),never crash tier derivation

---

## Acceptance Criteria

- [ ] **G-AR-2**: `max_class_depth` = max tier ordinal(1..3)reached in ANY single class,0 if none — resolve per一條揀定嘅路徑(見 Implementation Notes)
- [ ] **EC-TIER-5**: (class,tier) 解唔到(ambiguous)→ depth 當 0(specialist path off);generalist path 仍 work;log `class_depth_unresolved` — **fail-safe,never crash tier derivation**
- [ ] CI-INV-2:depth 純由 `get_unlocked_abilities()` 推,never inferred from stat/equipment
- [ ] feed Formula 2 specialist path(story 004 consumes);AC-04 pure-STRIKE depth=3 → 解析正確

---

## Implementation Notes

*Derived from Q-OQ-DEPTH(GDD-recommended Option A,fail-safe to Option B):*

- **Option A(GDD-recommended,clean)**:細小 additive #12 read `get_max_unlocked_class_tier() -> int`(或 `get_unlocked_class_tiers() -> Dictionary`)— zero string-parse coupling,#12-erratum(additive,no behaviour change)。**Consumer-forward 先例**(#23 G-IU-1 / #24 G-LS-4):mock-scoped 先行(mock #12 read 驗 specialist path),真 #12 erratum story 隨後接線。
- **Option B(self-contained fallback)**:#26 client-side parse `tier_1/2/3` marker embedded in ability_id StringName(ADR-0011 derivation pattern)— works today,但 couple #26 到 #12 id-naming convention → **必須 CI-lint-guard 該 convention**。
- **決定**:default 行 Option A(additive #12 read,GDD-recommended clean architecture),mock-scoped 先驗 specialist path;若 #12 erratum 接線受阻 → fall back Option B(client parse + convention lint)。**兩者 EC-TIER-5 fail-safe 一樣**(解唔到 → 0)。
- **G-AR-3 coupling 提示**:呢個 gate 同 #29 G-MM-3 唔同軸(G-AR-3 = #5 particle preset);但 coupled pair epic 一齊決定 cross-#12/#5 forward-dep 策略。

---

## Out of Scope

- Story 004:Formula 2 tier 計算(本 story 只供 depth input)
- #12 真 erratum 接線(若 Option A):mock-scoped 先行,真接線 follow-up

---

## QA Test Cases

- **G-AR-2**: depth resolution
  - Given: #12 unlocked abilities spanning STRIKE tier_1/2/3
  - When: resolve max_class_depth
  - Then: 3
  - Edge cases: 多 class 各有 depth → max;無 ability → 0
- **EC-TIER-5**: fail-safe
  - Given: ability_id (class,tier) ambiguous/unresolvable
  - When: resolve
  - Then: depth=0;log `class_depth_unresolved`;tier derivation 用 generalist path 唔 crash
  - Edge cases: 全 unresolvable → 仍 derive tier via generalist

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/max_class_depth_resolution_test.gd` — mock #12 seam(MockAbilitySystem)注入 add_child 前;EC-TIER-5 fail-safe case 必含
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline)
- Unlocks: Story 004(specialist path depth input)— 可並行(004 mock depth 先行)
