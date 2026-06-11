# Story 013: Accessibility — motion_intensity gate + colorblind + input non-interference

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(AC-25 + Visual/Audio Accessibility + UI Accessibility)+ UX spec(UX-04/05/06)+ `design/accessibility-requirements.md`
**Requirement**: `TR-cvf-013`

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary)
**ADR Decision Summary**: overlay opacity × #6 `motion_intensity`(=0 → 無 flash);hit_pause **唔**乘(time perturbation ≠ vestibular);tier 走 pause/flash 非 color(colorblind safe)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: a11y tier = WCAG AA Core + Motion Safety;`motion_intensity` 0-1 read from #6/settings;motion_intensity=0 → shake off **但 hit_pause 保留**(a11y doc §2);CanvasLayer `mouse_filter=IGNORE`(唔偷 one-tap)。

**Control Manifest Rules (Presentation)**:
- Required: overlay opacity × motion_intensity;color-independent tier;CanvasLayer 唔截 input
- Forbidden: tier 靠 color 單獨傳達;overlay 截走 GymSys/HUD one-tap
- Guardrail: WCAG 2.3.1 ≤3 flash/sec(single-instance latest-wins 結構保證)

---

## Acceptance Criteria

*From GDD AC-25 + UX-04/05/06:*

- [x] **AC-25**:`motion_intensity==0` CRITICAL → `_overlay_rect.color.a==0`(test_motion_zero_kills_flash_but_keeps_hit_pause);0.5→0.175 / 1.0→0.35
- [x] **UX-04(motion a11y)**:motion=0 → flash opacity 0 + **hit_pause(0.080)照 fire 不乘**(visual freeze ≠ vestibular);#25 從不 direct shake(R-13)
- [x] **UX-05(colorblind)**:`production/qa/evidence/cvf-colorblind-evidence.md` protocol authored(tier 靠 particle-size/pause/flash 非 color;is_crit color = foveal bonus only,R-12 CI-verified);art-director sign-off = external human gate
- [x] **UX-06(input non-interference)**:overlay ColorRect + 全 12 number Label `mouse_filter=IGNORE`(test_render_nodes_never_consume_input);唔偷 GymSys/HUD one-tap
- [x] WCAG 2.3.1:5 連續 CRITICAL → overlay layer 仍只 1 ColorRect(single-instance latest-wins 結構保證 >3 flash/sec 不可能,test_wcag_single_instance_structural)
- ⚠️ **grep erratum**:#6 **無** public `get_motion_intensity()`(GDD impl note phantom)→ `_motion_intensity()` seam:`_screen_fx.get_motion_intensity()` has_method future-proof → `_persistence.read("settings.motion_intensity")`(真源,#22 寫入)→ 1.0 fail-soft;注入 `_persistence` SOFT seam

---

## Implementation Notes

*Derived from ADR-0001 + a11y-requirements:*

- overlay render:`effective_opacity = MAX_OPACITY × _screen_fx.get_motion_intensity()`(=0 → 無 flash)。hit_pause **唔**乘(a11y doc:visual freeze distinct from vestibular — motion_intensity=0 仍有 climax 定格)。
- colorblind:tier 已由 story 005/006/010 keyed on pause/flash(非 color);number color 只 is_crit foveal bonus。本 story 加 QA desaturated evidence。
- input:兩 CanvasLayer 上 node 設 `mouse_filter=Control.MOUSE_FILTER_IGNORE`(或純 Node2D Label/ColorRect 唔 consume);test 驗 flash active 時下層仍收 input。

---

## Out of Scope

- Q-CV6 v0.2: 獨立 photosensitivity toggle(reduce-motion ≠ reduce-flash)
- Story 010: overlay primitive 本身

---

## QA Test Cases

- **AC-25 / UX-04**: motion gate
  - Given: `motion_intensity==0`
  - When: CRITICAL/OVERKILL
  - Then: overlay effective opacity==0 + #6 shake==0 + **hit_pause 照 fire**(0.080)
  - Edge cases: motion_intensity=0.5 → opacity × 0.5
- **UX-06**: input non-interference
  - Given: flash active + 下層 tap target
  - When: 玩家 tap
  - Then: tap 到下層(overlay `mouse_filter=IGNORE`,唔偷)
- **UX-05**: colorblind(manual)
  - Setup: combat CRITICAL desaturated screenshot
  - Verify: tier escalation 可讀(pause/flash 非 color)
  - Pass: greyscale 下分得到 climax vs 普通

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat_visual_feedback/test_cvf_a11y.gd`(AC-25/UX-04/UX-06)+ `production/qa/evidence/cvf-colorblind-evidence.md`(UX-05 desaturated)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_a11y.gd` 5/5(motion 0/0.5/1.0 + input-IGNORE + WCAG single-instance)+ colorblind evidence protocol authored(ADVISORY external gate)。`_motion_intensity()` seam + `_overlay_motion_scale` capture + Label mouse_filter IGNORE。cvf suite 71 pass / 1 pending / 0 fail

---

## Dependencies

- Depends on: Story 010(overlay)、Story 003(scaffold)
- Unlocks: None
