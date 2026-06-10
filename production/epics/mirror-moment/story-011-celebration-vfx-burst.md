# Story 011: Celebration VFX #5 burst + G-MM-2 layer + G-MM-3 LOOT preset

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M8 / Visual EVOLUTION / B-1 layer-residence 註記 / Q-OQ-PRESET
**Requirement**: AC-14 / AC-15(GDD 直接 trace)+ G-MM-2 + G-MM-3 cross-system gates
**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps(primary — particle budget + GPUParticles2D forbidden)· ADR-0005(loot preset reuse)
**ADR Decision Summary**: 粒子只經 `#5.play()`(直接 instantiate forbidden);LOOT preset → LARGE tier → CelebrationVFXLayer 110 residence。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(cross-system #5 layer-residence)
**Engine Notes**: `#5.play(preset_id: PresetId, position, multiplier)`(`particle_system_wrapper.gd:419`)。**grep-verified**:只有 LOOT preset(`LOOT_BURST`/`LOOT_RARE_BURST`)→ LARGE tier(`_select_tier:599`)→ `register_celebration_layer` reparent 上 `_celebration_layer`(CelebrationVFXLayer 110)。非-LOOT preset 留 world z≤7 → 被 modal backdrop 遮。

**Control Manifest Rules (Polish layer)**:
- Required: 粒子經 `#5.play()`;EVOLUTION burst on CelebrationVFXLayer 110(LOOT preset)
- Forbidden: 直接 `GPUParticles2D` instantiate(CI-MM-2);非-LOOT preset(上唔到 110)
- Guardrail: `CELEBRATION_PARTICLE_MULTIPLIER` ≤2.0(ADR-0001 budget);mobile 0.5× 由 #5

---

## Acceptance Criteria

- [ ] **AC-14**(CR-M8): content==EVOLUTION → celebration 經 `#5.play(CELEBRATION_BURST_PRESET, …)`(唔自 instantiate `GPUParticles2D`);content==REFLECTION → **無** `#5.play` burst call
- [ ] **AC-15**(CR-M8 / ADR-0001,ADVISORY/visual): mobile → 粒子 0.5× density(由 #5),avatar silhouette 可辨識度不變(screenshot 對比 desktop)
- [ ] **G-MM-3**(Q-OQ-PRESET B-1 HARD): `CELEBRATION_BURST_PRESET` **必須係 LOOT preset**(`LOOT_BURST`/`LOOT_RARE_BURST`)→ LARGE tier → CelebrationVFXLayer 110 residence;**MVP 鎖定復用現有 loot-celebration preset**(唯一免 #5 amendment 而 burst 正確 layer);若加新 preset → #5 amendment 兩件(size==9→N + LARGE-tier/celebration-residence carve-out)
- [ ] **G-MM-2**(Q-UX-CELEB-LAYER): 確認 CelebrationVFXLayer 110 persistent shared infra(`register_celebration_layer` handshake live)— IDLE 慶典(#21 loot modal NOT active)仍有 layer render onto
- [ ] burst 唔遮 silhouette(由中心向外、密度向邊緣遞減,中心留空俾 avatar)

---

## Implementation Notes

*Derived from CR-M8 + B-1 HARD 約束(layer-residence):*

- **G-MM-3 命脈(B-1)**:grep-verified #5 只 reparent LOOT-preset/LARGE-tier 節點上 `_celebration_layer`(110)。所以 `CELEBRATION_BURST_PRESET` **必為 LOOT preset** —— 非-LOOT 留 world z≤7 被 modal backdrop(110+)遮 → 慶典睇唔到 burst。MVP 鎖定復用(coupled pair 同 #26 G-AR-3 一齊定 cross-#5 策略)。
- **G-MM-2**:確認 CelebrationVFXLayer 110 = #21-owned persistent infra,IDLE 慶典時(#21 modal 唔 active)layer 仍 registered(`register_celebration_layer` handshake live)。
- REFLECTION → 無 burst(輕慶典唔放大,CR-M8)。
- 直接 `GPUParticles2D` forbidden(CI-MM-2,story 014)。
- mobile 0.5× 由 #5 內部(ADR-0001),#29 platform-transparent。

---

## Out of Scope

- Story 010:share-card chrome(本 story 係 burst)
- Story 014:CI-MM-2 no-particle-instantiate lint
- #5 amendment（若新 preset — follow-up,MVP 復用免）

---

## QA Test Cases

- **AC-14**: burst via #5
  - Given: content==EVOLUTION
  - When: present
  - Then: `#5.play(LOOT preset, …)` called;zero direct GPUParticles2D;REFLECTION → 無 burst call
  - Edge cases: G-MM-3 preset 必 LOOT;G-MM-2 layer 110 live
- **AC-15**(visual): mobile density
  - Setup: mobile platform,EVOLUTION burst
  - Verify: 粒子 0.5×(#5);avatar silhouette 可辨識度不變
  - Pass condition: desktop/mobile screenshot 對比 silhouette 一致

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/celebration_burst_test.gd` — mock #5 wrapper seam(assert play() called with LOOT preset,zero direct instantiate);AC-15 visual → `production/qa/evidence/mirror-moment-mobile-burst-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(EVOLUTION content)/ Story 010(share-card)/ #5(layer infra — mock 先行)
- Unlocks: None(#5 amendment follow-up if new preset)
