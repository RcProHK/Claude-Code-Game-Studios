# Story 002: Coordinator scaffold + autoload boot + cfis 4-subscription + bootstrap derive

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` §Overview / CR-1 / CR-6 / CR-13 / init sequence / AvatarVisualState schema
**Requirement**: AC-01 / AC-02 / AC-16 / AC-22(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary — Contract 6 `connect_for_initial_state`)· ADR-0008(autoload)
**ADR Decision Summary**: Contract 6 `connect_for_initial_state` 令 subscriber boot 即收 current state(sentinel `payload.source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT`,`game_state_machine.gd:96`)。Contract 4 sequential boot。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot 4 `connect` arg 數要 match signal arity(#11.stat_changed 係 **5-arg**;少 arg = emit-time runtime error)。`get_current_state()` 係 method(`game_state_machine.gd:241`),無 public `current_state` var。

**Control Manifest Rules (Presentation layer)**:
- Required: 所有 canonical subscription 經 `connect_for_initial_state`(ADR-0006 C6);mutation 只喺 `_derive_state_from_canonical()`
- Forbidden: 自訂 bootstrap path(共用 normal derivation pipeline);foreign subscription
- Guardrail: subscription set 必須 == exactly 4

---

## Acceptance Criteria

- [ ] **AC-01**: autoload boot → subscription set == exactly {#11.stat_changed, #12.ability_unlocked, #12.ability_cast, GSM.state_changed},零 foreign
- [ ] **AC-16**: boot 用 `connect_for_initial_state` sentinel 接全部 4 subscription(ADR-0006 C6)
- [ ] **AC-02**: 每個 visible(`derived_from`-attributed)`AvatarVisualState` field → 100% derivable from #11/#12/GSM snapshot via pure fn(identical input = equal output);milestone-tracking field(`last_emitted_tier`/`last_milestone_emit_unix`)source = #3 persistence(attribution-check,非 pure-fn re-derive)
- [ ] **AC-22**: bootstrap 有 historical milestone in persistence → boot re-derive emit ZERO historical milestone(idempotent via `last_emitted_tier`)
- [ ] init sequence per GDD:load config(fail-hard EC-BOOT-2)→ preload sprite → cfis 4 sub → read persistence → derive + apply posture(first-boot CR-9 exempt)→ emit one `avatar_visual_updated` → IDLE

---

## Implementation Notes

*Derived from ADR-0006 C6 + GDD init sequence:*

- `src/autoload/avatar_renderer.gd`:thin autoload Node;持 Character-Layer `AnimatedSprite2D`(CanvasLayer.layer==10,story 015 set asset)。
- cfis 4 subscription:`#11.stat_changed`(5-arg handler — match shipped signature `stat_changed(stat_id, old_value, new_value, source, is_base_change)`)、`#12.ability_unlocked(ability_id, source)`、`#12.ability_cast(ability_id, caster, target)`、`GSM.state_changed(from, to, payload)`。
- sentinel:handler 檢 `payload.source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT`(const,`game_state_machine.gd:96`)→ `_derive_state_from_canonical()` via `#11.get_stat()` + `#12.get_unlocked_abilities()` sync read(無 special path)。
- `AvatarVisualState`(`src/data/avatar_visual_state.gd`)per GDD schema;每 visible field 寫 `derived_from[field]=source_signal`(CR-6 / INV-1)。
- EC-SIG-1:`stat_changed` 喺 `_ready()` 完成前 fire → drop(唔 queue),post-ready re-derive from `get_stat()` snapshot。
- EC-BOOT-2:`AvatarEvolutionConfig.tres` missing → hard assert + crash(NO hardcoded fallback,P1)。
- milestone replay-safe:CR-5 gate(a)`current_tier > last_emitted_tier` 令 bootstrap re-derive 唔重發 historical(AC-22)。

---

## Out of Scope

- Story 003/004:Formula 1/2 derivation 細節(本 story 只搭 pipeline + attribution)
- Story 009:persistence schema read/rebuild 細節(本 story 假設 read API 可用)
- Story 011/012:milestone emit gate(本 story 只驗 bootstrap 唔重發)

---

## QA Test Cases

- **AC-01**: subscription set exact
  - Given: AvatarRenderer autoload booted
  - When: enumerate connected signals
  - Then: == {stat_changed, ability_unlocked, ability_cast, state_changed};zero foreign
  - Edge cases: 重複 connect 防護;signal arity match(5-arg stat_changed)
- **AC-16**: cfis sentinel
  - Given: boot
  - When: 4 subscription connect
  - Then: 全部經 `connect_for_initial_state`;INITIAL_STATE sentinel 觸發 derive
  - Edge cases: sentinel payload `source_event` 值 == const
- **AC-02**: derivation purity
  - Given: fixed #11/#12/GSM snapshot
  - When: `_derive_state_from_canonical()` ×2
  - Then: 兩次 output equal;每 visible field 有 `derived_from` attribution
  - Edge cases: milestone-tracking field attribution = #3(非 pure-fn)
- **AC-22**: idempotent bootstrap
  - Given: persistence 有 `last_emitted_tier=T2` + historical log
  - When: boot re-derive
  - Then: zero `avatar_evolution_milestone` emit
  - Edge cases: current_tier == last_emitted_tier → gate(a) false

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/coordinator_scaffold_test.gd`(persistence-consumer test 喺 add_child 前注入 MockPersistenceLayer — reference_test_persistence_isolation)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001(autoload registered)
- Unlocks: Story 003/004/009(derivation + persistence build on this pipeline)
