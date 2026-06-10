# Story 016: Particle presets (#5) + mobile fallback (G-AR-3 preset 策略)

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-14 / Visual E / FC-6 / EC-XSYS-1 / Q-OQ-ASSET
**Requirement**: AC-20(GDD 直接 trace)+ G-AR-3 cross-system gate(#5 preset coupling)
**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps(primary — particle budget + GPUParticles2D forbidden)
**ADR Decision Summary**: 粒子只經 `ParticleSystemWrapper`(直接 `GPUParticles2D` instantiate FORBIDDEN);mobile 0.5× density。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(cross-system #5 preset enum)
**Engine Notes**: `#5.play(preset_id: PresetId, position: Vector2, multiplier: float=1.0) -> ParticleHandle`(`particle_system_wrapper.gd:419`);`preset_id` 係 **PresetId enum**(NOT StringName)。**shipped #5 有 `play()` reflection-validation + 2 硬 `PRESET_TABLE.size()==9` test**(test_preset_library:20 / test_pool_tier_selection:58)。

**Control Manifest Rules (Presentation layer)**:
- Required: particle 經 `#5.play()`;mobile sprite UNCHANGED,只 particle degrade
- Forbidden: 直接 `GPUParticles2D` instantiate(ADR-0001)
- Guardrail: 加新 PresetId → #5 enum 9→N + PRESET_TABLE + amend 2 size==9 test(R-5/G-AR-3)

---

## Acceptance Criteria

- [ ] **AC-20**: `platform_detect==mobile` → sprite layer quality/frame-rate/posture **UNCHANGED**;只 particle 經 #5 degrade(0.5×)
- [ ] CR-14:mobile fallback — sprite 不變;particle density 0.5×(delegated #5);idle outline shader MAY disable on mobile
- [ ] EC-XSYS-1:#5 unavailable for avatar preset → emit milestone to #29 anyway;skip particle;log `particle_wrapper_unavailable`(silhouette > decoration)
- [ ] **G-AR-3 preset 策略決定**:3 avatar preset(`AVATAR_STAT_GLOW` / `AVATAR_CAST_BURST` / `AVATAR_EVOLUTION_REVEAL`,FC-6)— **若加新 PresetId entry** → 須 #5 amendment **兩件**(enum 9→N + PRESET_TABLE entry **加** amend test_preset_library:20 + test_pool_tier_selection:58 嘅 `size()==9` assertion);default 評估復用 vs 新增(coupled pair 同 #29 G-MM-3 一齊決定)
- [ ] particle 經 `#5.play(preset_id, position)`;NEVER 直接 instantiate `GPUParticles2D`

---

## Implementation Notes

*Derived from CR-14 + Visual E + FC-6(the #5 closed-set-of-9 coupling — R-5 advisory):*

- **G-AR-3 命脈(R-5)**:shipped #5 有 `play()` reflection-validation(membership oracle)+ 2 硬 `PRESET_TABLE.size()==9` test。加 3 avatar preset → #5 RED 除非同步 amend enum(9→12)+ PRESET_TABLE + 嗰 2 test。**先評估**:cast burst / stat glow / evolution reveal 可唔可以復用既有 preset(免 closed-set coupling)?若必須新增 → #5 erratum story（mock-scoped 先行,真接線隨後）。
- mobile:`platform_detect` gate;sprite UNCHANGED,只 particle multiplier 0.5×(#5 internal)。AC-20 = regression guard。
- EC-XSYS-1:#5 unavailable → 仍 emit milestone(silhouette > decoration)。
- **與 #29 G-MM-3 coupling**:#29 celebration burst 必復用 LOOT preset(B-1);#26 自己 preset 策略喺呢度定 — coupled pair epic 一齊 align cross-#5 forward-dep。

---

## Out of Scope

- Story 007:cast queue logic(本 story 只 cast-release particle hook)
- #5 GDD 真 amendment(若新增 preset — follow-up erratum story)
- shader file 創作(asset-spec)

---

## QA Test Cases

- **AC-20**: mobile sprite unchanged
  - Given: platform_detect==mobile
  - When: render
  - Then: sprite quality/fps/posture 不變;particle 0.5× via #5
  - Edge cases: idle outline shader disable on mobile(combat-only)
- **G-AR-3**: preset coupling
  - Given: avatar preset trigger
  - When: `#5.play(preset_id, pos)`
  - Then: 經 wrapper,zero direct GPUParticles2D;若新 PresetId → #5 enum+table+2 test amended
  - Edge cases: EC-XSYS-1 #5 unavailable → skip particle,milestone 照 emit

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/particle_mobile_test.gd` — mock #5 wrapper seam;mobile-gate sprite-unchanged assertion;preset trigger via wrapper(zero direct instantiate)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 015(z-order topology)/ Story 007(cast release frame)/ Story 012(evolution reveal trigger)
- Unlocks: None(#5 erratum follow-up if new presets)
