# Story 007: Formula 3 — before_after collapse + CR-M6 snapshot-at-present

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` Formula 3 / CR-M5 / CR-M6 / EC-MM-1/7/9/10/11
**Requirement**: AC-10 / AC-11 / AC-12(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0010 Mirror Moment Ownership(primary — snapshot seam,#29 zero compute)
**ADR Decision Summary**: #29 read `get_evolution_snapshot()` 零計算;collapse 由 #26 snapshot prior_tier 保證。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `#26.get_evolution_snapshot() -> AvatarEvolutionSnapshot`(8 field:tier/class_posture/sprite path/hero_pose_frame/prior_tier/prior path/source_metrics/snapshot_taken_unix)。

**Control Manifest Rules (Polish layer)**:
- Required: 呈現時先 call snapshot(fresh);全部 reveal source 由 snapshot 讀入
- Forbidden: cache stale state;用 milestone payload 做 render source(只 latch+telemetry)
- Guardrail: collapse 信 #26 snapshot prior_tier(中間 tier 唔逐格)

---

## Acceptance Criteria

- [ ] **AC-10**(CR-M5 / EC-MM-1): 一 window 內收 `milestone(1)→(2)→(3)` + last-ceremonied tier=0 → present **單一**慶典,snapshot prior_tier=0 / tier=3 → 一個 T0→T3 before→after(**唔開 3 次**),caption net 跳(「T0 → T3」)
- [ ] **AC-11**(CR-M6): milestone latch 咗 3 日期間 avatar 再 micro-evolve → present 用 **present-time** `get_evolution_snapshot()`(fresh),唔用 latch 時 payload 做 render source
- [ ] **AC-12**(EC-MM-7): 首次 tier-up(`prior_sprite_frames_resource_path==""`)→ `show_ghost==false`,單 frame + caption「首次進化」(無 ghost,無 crash)
- [ ] Formula 3:`show_ghost = (content==EVOLUTION) ∧ (prior_tier < after_tier) ∧ (prior_sprite != "")`;全部由 snapshot 讀,#29 零計算
- [ ] EC-MM-9:REFLECTION 但 prior_tier==after_tier → 無 ghost,單 frame +「本週回顧」
- [ ] EC-MM-10:`pending_source_metrics` 損壞 → null-safe drop,用 fresh snapshot render,narrative「成因」行略過
- [ ] EC-MM-11:`get_evolution_snapshot()` boot 未 ready 返 null → 留 ARMED,下個 frame/tick 重試(唔 crash)

---

## Implementation Notes

*Derived from Formula 3 + CR-M6(snapshot-at-present, collapse-aware):*

- **CR-M6 命脈**:呈現嗰一刻先 call `get_evolution_snapshot()`(fresh)— milestone signal payload `source_metrics` 只用 latch + telemetry + narrative「成因」,**唔**做 render source(latch 可能幾日前,avatar 已再變)。AC-11 = regression guard。
- **CR-M5 collapse**:`prior_tier` = #26 snapshot 嘅 last-ceremonied tier,`tier` = current → 一個 before→after,中間 tier 唔逐格(#26 已保證語意,#29 trust)。
- `show_ghost` 三條件 AND;first-ever(prior_sprite=="")→ false（AC-12「首次進化」）。
- snapshot null(EC-MM-11)→ 留 ARMED 重試(唔 crash)。

---

## Out of Scope

- Story 011:celebration burst(本 story 只 reveal 構圖 source)
- Story 010:share-card render(本 story 決定 show_ghost + sprite source)
- Story 013:narrative caption 行

---

## QA Test Cases

- **AC-10**: collapse single ceremony
  - Given: milestone 1→2→3,last-ceremonied=0
  - When: present
  - Then: 單一慶典,prior=0/after=3,T0→T3;唔開 3 次
- **AC-11**: snapshot-at-present
  - Given: latch 3 日,期間 micro-evolve
  - When: present
  - Then: 用 present-time fresh snapshot,唔用 latch payload
- **AC-12**: first-ever no ghost
  - Given: prior_sprite==""
  - When: present EVOLUTION
  - Then: show_ghost==false,單 frame +「首次進化」,無 crash
  - Edge cases: EC-MM-9 REFLECTION 同 tier;EC-MM-11 null snapshot 重試

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/mirror_moment/formula3_before_after_test.gd` — mock snapshot seam;collapse + first-ever + null cases;golden table
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(content)/ Story 005(present)/ Story 006(latch)
- Unlocks: Story 010(reveal render)/ Story 011(burst)
