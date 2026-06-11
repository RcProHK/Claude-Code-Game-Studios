# Story 016: G-CV-5 registry — 17 knobs + dual-critical disambiguation + routing reconcile

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(§Tuning Knobs + R-12 + Q-CV7)
**Requirement**: `TR-cvf-016`

**ADR Governing Implementation**: ADR: N/A — data registry registration,no architectural pattern required
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `design/registry/entities.yaml`;gameplay 值 data-driven(coding-standards)。

**Control Manifest Rules (Presentation)**:
- Required: #25-owned 值入 registry;dual-critical disambiguation 註記
- Forbidden: hardcode gameplay 值
- Guardrail: registry 對賬 shipped routing(reconcile aspirational vs 真實)

---

## Acceptance Criteria

*From GDD Tuning Knobs + Q-CV7:*

- [x] #25 **17 owned knobs** 入 `entities.yaml`(`cvf_` namespaced,各 value + unit + safe-range note + source #25):cvf_hit_pause_heavy/critical_sec、cvf_critical_degrade_pause_sec、cvf_hit_particle_coalesce_ms、cvf_max_concurrent_damage_numbers、cvf_damage_number_lifetime/rise/fade、cvf_critical/overkill_flash_duration_sec、cvf_overlay_max_opacity_critical/overkill、cvf_anchor_forward/vertical/jitter_px、cvf_max_frame_delta、cvf_overlay_respects_motion_intensity(grep count==17)
- [x] **dual-critical disambiguation note**:#25 block header + damage_tier_enum notes(L1998)`DamageTier.CRITICAL`(ratio ≥40% maxHP)≠ `is_crit`(crit roll)R-12(design phase 已加 + block header 再述)
- [x] **shipped-routing 對賬 note**:damage_tier_enum notes(L1998)reconcile aspirational「MEDIUM 0.2 / HEAVY 0.4 / CRITICAL 0.6」vs #25 binary(MEDIUM=HIT_LIGHT 無 shake;HEAVY+CRITICAL 共用 HIT_HEAVY → #6 auto 0.4)— #25 R-4..R-11 authoritative
- [x] 活化 `damage_tier_enum`(L1987)/ `hit_outcome_enum`(L1972)#25 referrer(design phase 已活化)

---

## Implementation Notes

*Q-CV7 registry pass:*

- entities.yaml:加 `combat_visual_feedback` constant block(17 knob,各 default+range)。
- dual-critical note:喺 `damage_tier_enum` 旁加 disambiguation comment(ratio vs roll)。
- routing reconcile:若 registry 有早期 aspirational trauma ladder(MEDIUM 0.2 / HEAVY 0.4 / CRITICAL 0.6),加 note 標「pre-#25 intent;#25 真實 binary(共用 HIT_HEAVY auto 0.4)為準」。

---

## Out of Scope

- Story 015: interaction-patterns.md
- 各 knob 喺 code 嘅實際使用(分散喺 005-013)

---

## QA Test Cases

- **Manual check: 17 knob 註冊**
  - Setup: 讀 entities.yaml combat_visual_feedback block
  - Verify: 17 knob 各有 default + safe range
  - Pass: grep 17 knob name 全在
- **Manual check: dual-critical + reconcile**
  - Setup: 讀 damage_tier disambiguation note + routing reconcile note
  - Verify: CRITICAL(ratio)≠ is_crit(roll)明寫;aspirational vs 真實 binary 對賬
  - Pass: 兩 note 在

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check — entities.yaml 17 knob + 2 note 存在(grep)
**Status**: [x] Verified 2026-06-11 — grep `  - name: cvf_` count==17 + dual-critical note ×2 + reconcile/aspirational note ×2。block 喺 constants section 尾(L3070+),格式跟 mirror_moment const 先例,notes 無 embedded quote。⚠️ NOTE:entities.yaml 整體非 strict-YAML(pre-existing L363 未轉義 embedded quotes,2026-05-26,非本 story 引入)→ project 用 grep 非 parse;我 block 獨立乾淨

---

## Dependencies

- Depends on: None(doc-only,可 parallel)
- Unlocks: None
