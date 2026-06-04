# Story 004: HP/stat + SkillIconRegistry sort + cluster display cap

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (CR-12, CR-13⑨, EC-S7 cluster) · **UX**: P-04 skill-family-icon
**Requirement**: GDD AC-CR-12 / AC-CR-13⑨ + UX AC-UX-4 (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0009 Signal Payload Schema (primary)
**ADR Decision Summary**: #20 consume `stat_changed`/`ability_unlocked` payload(minimal intrinsic);late-bind cross-cutting context at handler。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: LOW
**Engine Notes**: `get_unlocked_abilities()`(ability-system.md L233)返 read-only view;**L413 invariant 1 明文「無視 insertion order」→ #12 insertion-order-agnostic**,#20 唔可依賴 iteration order;**L696 NEVER access internal**。tier_ordinal/class_ordinal mapping published L386/L405。

**Control Manifest Rules**:
- Required: #20-owned intrinsic data(SkillIconRegistry),非 upstream query
- Forbidden: 依賴 #12 collection iteration order / 讀 timestamp / 讀 internal;fabricate depleting HP
- Guardrail: cluster glance cap `skill_cluster_display_cap=4`

---

## Acceptance Criteria

- [ ] **AC-CR-12**:HP fill 綁 `get_stat(MAX_HP)`(non-depleting,只 MAX_HP 升級時 step);技能列表 == `get_unlocked_abilities()`(無 fabricated current-HP)。
- [ ] **AC-CR-12 cluster sort(R8 B1+B13)**:注入混合 tier 嘅 ability_id set,BOSS_ENCOUNTER display cap → 用 #20-owned `SkillIconRegistry` `tier_ordinal` 施 `tier_ordinal DESC, class_ordinal ASC` sort,顯示頭 `skill_cluster_display_cap(=4)` == 最高 tier 4 個,其餘摺疊「+N」;**deterministic、唔依賴 collection iteration order、唔讀 timestamp、唔讀 #12 internal**。
- [ ] **AC-CR-13⑨(anti-Stagnation Mirror)**:cluster 顯示最強(tier DESC)非最舊 insertion-order → 反映玩家當前實力。
- [ ] **AC-UX-4(empty/locked)**:`get_unlocked_abilities()` 返空 → cluster 顯示空 group(無 crash / void);HP 首 frame 無 confirmed 值 → fallback 不顯 NaN。

---

## Implementation Notes

- `SkillIconRegistry` = #20-owned **static** map:9 MVP-locked canonical ability_id → `{glyph_shape, tier_ordinal, class_ordinal}`。tier 係 slot identity intrinsic 屬性(`STRIKE_TIER_3` 恆 tier 2,非 runtime state);#20 render icon 本身已需此 registry。tier_ordinal 由 ability-system.md L386/L405 published mapping derive(design-time 建 registry)。
- sort:`tier_ordinal DESC`(最強先)→ `class_ordinal ASC` tie-break(deterministic)→ 取頭 cap 個。direction DESC 係 #20 presentation choice(有意異於 #12 emit-order tier-ASC)。
- HP = P-02 frameless-hud-bar(6px,non-depleting);MAX_HP 升級 step = P-03 ticker。
- skill icon = P-04 skill-family-icon(16×16 solid silhouette + 1px ink;Strike=diagonal/sharp、Control=symmetric/arc、Mobility=flowing/negative-space)。
- cluster = 單一 `glance_group==true` parent(Story 009 CI 數 parent 不數 children)+ `cluster_icon_cap` field == `skill_cluster_display_cap`。

---

## Out of Scope

- Story 009:cluster icon design-time CI metadata 驗(本 story 只 runtime display-cap 邏輯 + 摺疊)。
- Story 011:skill silhouette colorblind evidence(AC-UX-7)。
- depleting HP runtime owner(Q-OQ3 post-MVP,#25)。

---

## QA Test Cases

- **AC-CR-12 HP**:Given `get_stat(MAX_HP)` stub;When render HP;Then fill 綁 MAX_HP、無 deplete 動畫;Edge: MAX_HP 升 → step 跳格一次。
- **AC-CR-12 sort**:Given fixture ability_id set 含混合 tier(如 STRIKE_T1/CONTROL_T3/MOBILITY_T2/STRIKE_T3/CONTROL_T1)、cap=4;When apply display cap;Then 顯示頭 4 == sort by (tier_ordinal DESC, class_ordinal ASC);Edge: tie tier → class_ordinal ASC;>4 → 摺疊「+1」;同 set 不同注入順序 → 相同結果(insertion-order-agnostic)。
- **AC-CR-13⑨**:Given set 含舊 T1 + 新 T3;Then cluster 含 T3(最強)非永久舊 T1 霸位。
- **AC-UX-4**:Given 空 ability set;Then 空 group 無 crash;Given HP NaN first-frame;Then 0.0 fallback。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gym_mode_hud/test_hp_stat_skill_registry.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scaffold) · #11 Stat (merged) · #12 Ability (merged)
- Unlocks: Story 009 (cluster CI metadata) · Story 011 (skill silhouette evidence)

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 4/4 passing (AC-CR-12 HP + sort / AC-CR-13⑨ anti-Stagnation / AC-UX-4 empty+NaN)
**Deviations**: None. SkillIconRegistry tier/class_ordinal 對映 #12 AbilityClass(STRIKE0/CONTROL1/MOBILITY2) + AbilityTier(T1=0/T2=1/T3=2) 同 9 canonical AbilityId（ability_system.gd L76-84）。HP non-depleting（無 current-HP owner，Q-OQ3 deferred #25）。
**Test Evidence**: Logic — `tests/unit/gym_mode_hud/test_hp_stat_skill_registry.gd` (11 test functions, 11/11 pass). Full combined gate green: 237 scripts / 1449 pass / 0 fail / 1 pre-existing pending.
**Code Review**: Complete — APPROVED (#20-owned registry 無讀 #12 internal/order/timestamp；sort key 唯一→deterministic+insertion-order-agnostic；對 GDD CR-12/CR-13⑨ + ADR-0009)
**Files**: `src/ui/gym_mode_hud/gym_mode_hud.gd` (HP value + SkillIconRegistry + cluster sort), `tests/unit/gym_mode_hud/test_hp_stat_skill_registry.gd` (created)
