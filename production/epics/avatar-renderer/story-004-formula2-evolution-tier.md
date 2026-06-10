# Story 004: Formula 2 — evolution_tier (generalist + specialist symmetric, F-2 fix)

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` Formula 2 / CR-4 / CR-12 / CF-2 / EC-TIER-1/3/4 / INV-G1
**Requirement**: AC-04 / AC-05(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0011 PR Detection Topology(primary — client-side deterministic derivation pattern)· data-driven config(CR-4)
**ADR Decision Summary**: facts server-authoritative,derivation client-side deterministic + contract-pinned。tier derivation 係 client-side deterministic（thresholds from `.tres`）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: thresholds load from `AvatarEvolutionConfig.tres`(零 hardcoded literal in `.gd` — CI-2/AC-24,story 017)。`#11.get_stat()->float`;`#12.get_unlocked_abilities()->Dictionary`。

**Control Manifest Rules (Presentation layer)**:
- Required: tier thresholds data-driven(`.tres`);effective_tier 經 CR-12 monotonic lock
- Forbidden: hardcoded threshold literal;tier 用 streak/loot/equipment/cosmetic
- Guardrail: 兩條 path **對稱獨立**,specialist 唔經 generalist sum gate(Pass-4 F-2 fix)

---

## Acceptance Criteria

- [ ] **AC-04**: pure STRIKE specialist `peak_stat=70, max_class_depth=3, stat_total=80, ability_count=3` → `evolution_tier==T3`(specialist path,NOT locked — **Pass-4 F-2 fix 核心**)
- [ ] **AC-05**: stat 升到 T2 後 drop 1 below threshold → tier 留 T2(monotonic + historical lock,CF-2)
- [ ] Formula 2 兩條 path:`generalist_ok(t)=(stat_total≥S_t)∧(ability_count≥A_t)`;`specialist_ok(t)=(peak_stat≥S_peak_t)∧(max_class_depth≥D_t)`;`computed_tier=max{t: gen_ok(t) ∨ spec_ok(t)}`;`effective_tier=max(computed_tier, historical_max)`
- [ ] thresholds from `.tres`:S_t{0,30,60,100} / A_t{0,1,3,6} / S_peak_t{0,20,40,70} / D_t{0,1,2,3}
- [ ] EC-TIER-1:stat-only(無 ability/depth)→ 留 T0(P1:tier 要 earned ability/depth)
- [ ] EC-TIER-3:exactly on threshold → inclusive upper tier(`>=`)
- [ ] EC-TIER-4:tier jump T1→T3 一次 derive → emit ONE milestone `{tier:T3, skipped_tiers:[T2]}`(story 012 emit;本 story 算值 + 標記 skip)

---

## Implementation Notes

*Derived from Formula 2(the Pass-4 F-2 fix):*

- **F-2 fix 命脈**:specialist path(`peak_stat` + `max_class_depth`)同 generalist path(`stat_total` + `ability_count`)**完全獨立對稱**,specialist **唔經** sum gate → pure specialist 唔會被 sum 鎖死。AC-04 = regression guard。
- `max_class_depth` 由 story 005(G-AR-2)resolve;本 story 接受 depth 值(EC-TIER-5 fail-safe → 0 時 generalist path 仍 work)。
- `effective_tier` monotonic non-decreasing(CF-2):tightened `.tres` 可降 `computed_tier` 但唔降 `effective_tier`(anti-pillar「缺日唔拎走嘢」)。
- INV-G1 load-time assert:S_t strictly increasing;A_t/S_peak_t/D_t monotonic non-decreasing。
- EC-TIER-2(hot-reload reject)+ EC-BOOT-3(config drift)= persistence/boot story 範疇,本 story 只 pure derive。

---

## Out of Scope

- Story 005:max_class_depth 解析(G-AR-2)— 本 story 接受 depth 作 input
- Story 011/012:milestone emit gate / emit(本 story 只算 tier 值 + skip 標記)
- Story 017:CI-2 data-driven lint(AC-24)

---

## QA Test Cases

- **AC-04**: specialist not locked
  - Given: peak=70, depth=3, stat_total=80, ability_count=3
  - When: Formula 2
  - Then: T3(specialist path)
  - Edge cases: golden table 全 row(generalist 102/34/6/2→T3;early specialist 45/40/2/2→T2;new 20/12/0/0→T0;drop-after-rebalance 55/30/2/1→T2 historical lock)
- **AC-05**: monotonic lock
  - Given: historical_max=T2,computed drops to T1
  - When: effective_tier
  - Then: T2
  - Edge cases: threshold boundary inclusive(`>=`,EC-TIER-3)
- **EC-TIER-4**: single milestone on jump
  - Given: computed jumps T1→T3
  - When: derive
  - Then: 標 `skipped_tiers:[T2]`,單一 tier 值 T3

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/avatar_renderer/formula2_evolution_tier_test.gd` — must pass;golden-vector table;**AC-04 pure-specialist regression case 必含**(F-2 fix guard);thresholds 從 fixture `.tres` 載,非 inline magic number
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline)/ Story 005(max_class_depth input — 可 mock depth 先行,005 接線後 full)
- Unlocks: Story 011/012(milestone gate 用 tier 值)
