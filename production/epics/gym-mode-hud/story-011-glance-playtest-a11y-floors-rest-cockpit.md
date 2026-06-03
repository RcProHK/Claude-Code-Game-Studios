# Story 011: Glance playtest (AC-V-1) + a11y evidence + min-floors + REST cockpit + L10n

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Ready (AC-V-1 result BLOCKED on external playtest — 見 Dependencies)
> **Layer**: Presentation
> **Type**: Visual/Feel · UI
> **Estimate**: L (4h + external playtest session)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (AC-V-1/V-2/V-5, AC-U-2/U-5/U-6, AC-CR-1/13⑧) · **UX**: `design/ux/gym-mode-hud.md` (AC-V-1 protocol RESOLVED, AC-UX-5/6/7/8/10, Visual Primitives, Localization)
**Requirement**: GDD AC-V-1 + UX AC-UX-5/6/7/10 + AC-U-2/U-6 (no TR-ID — cite GDD/UX AC-ID)

**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps (primary — MSDF font shader cost, peripheral readability)
**ADR Decision Summary**: 常駐 overlay MSDF font 成本 + draw-call sub-budget 須實機驗(technical-artist + `/architecture-review`)。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: HIGH
**Engine Notes**: AC-V-1 / colorblind / shake readability = **headless 驗唔到**(體感,要 screenshot/playtest + lead sign-off);AC-V-1 = **external human tachistoscope playtest**(N=12)。

**Control Manifest Rules**:
- Required: min_font_size_px=7 / min_bar_height_px=4 hard floor;touch ≥44×44;color-independent(≥2 non-color channel)
- Forbidden: 色盲靠單一 color channel;REST cockpit 無限展開
- Guardrail: AC-V-1 BINDING entry gate(protocol 交付 + point≥80% + Likert≥4/5 + 0px)

---

## Acceptance Criteria

- [ ] **AC-V-1(BINDING entry gate — external playtest)**:per UX spec protocol — peripheral(偏心 ≥10–15° fixation cross)+ dual-task load + 300ms tachistoscope + static/shake 兩變體 × **WORKOUT_ACTIVE AND BOSS_ENCOUNTER** 四格,**point estimate 答中率 ≥80%(N=12)四格各自** + Likert「需唔需對焦」median ≥4/5 + Z1 anchor 位移 0px。Wilson 95% CI 下界 = **ADVISORY report-only**(非 gate)。未交付 protocol = CANNOT-VERIFY。
- [ ] **AC-UX-5 / AC-U-6(min visual floors)**:HP=6px、EXP ≥`min_bar_height_px(4)`、字號 ≥`min_font_size_px(7)`;`text_scale` 0.8 時 effective 字號仍 ≥7(hard floor)。
- [ ] **AC-UX-6 / AC-V-5(色盲)**:BOSS_ENCOUNTER 截圖 deuteranopia/protanopia/tritanopia + greyscale → Boss HP vs Player HP 靠 threat glyph + angular geometry single-frame 可分;skill class 靠 P-04 silhouette(8×8 squint)可分;Strike vs Boss crimson 可分。
- [ ] **AC-UX-10 / AC-U-2(REST cockpit bound)**:REST_PERIOD SKILLS list 可見 ≤8 + scroll(非無限展開);STAT ≤3 block。
- [ ] **AC-UX-8(touch target)**:banner hit-area ≥44×44 CSS px。
- [ ] **AC-V-2 / AC-CR-1 / AC-CR-13⑧**:shake figure-ground / reward 喺 L1 餘光 / shake 期 Tier 1 可讀(screenshot + sign-off)。
- [ ] **AC-UX-9(reduce_motion)** *(已喺 Story 002/006 unit 覆 Logic 面;本 story 補 visual 確認)*。

---

## Implementation Notes

- min floors:EXP render `= max(round(hp_height × 0.5 × dpr), min_bar_height_px)`;font `= max(base_font_px × text_scale, min_font_size_px)`。
- Boss HP = P-11 enemy-threat-hud-bar(threat-chevron glyph prefix + angular notched end-caps,non-color load-bearing)。
- skill icon = P-04(Strike=diagonal/sharp、Control=symmetric/arc、Mobility=flowing)。
- REST cockpit:SKILLS top-8 + scroll(對焦層 list cap,非 BOSS 4-icon glance cap);STAT ≤3 block。
- **AC-V-1 playtest**:用 UX spec protocol。tooling = web 閃現 harness(OQ-U4)。tester N=12 經 gym community。**gross-fail(任一格 <70%)= BLOCKING exit,escalate ux 重設計**。
- evidence docs 落 `production/qa/evidence/`(多 state screenshot + colorblind simulation + playtest 數據表 + lead sign-off)。

---

## Out of Scope

- Story 002/006:reduce_motion Logic 斷言(本 story 只 visual 確認)。
- Story 009:design-time glance count CI(本 story 係 human glance playtest 結果)。
- OQ-U2 reconcile(bitmap m5x7 vs MSDF text_scale)— cross-doc,epic-level follow-up。

---

## QA Test Cases

*Manual verification (Visual/Feel/UI — ADVISORY + AC-V-1 BINDING-result):*

- **AC-V-1**:Setup: web 閃現 harness,N=12 tester,fixation cross 偏心 ≥10–15°,dual-task,300ms,static+shake × WORKOUT+BOSS;Verify: 四格答中率 + Likert + 0px;Pass: 四格各 point estimate ≥80% AND Likert median ≥4/5 AND 0px;Wilson CI report-only。
- **AC-UX-6/V-5**:Setup: BOSS_ENCOUNTER 截圖;Verify: 3 色盲 sim + greyscale 下 Boss vs Player + skill class 可分;Pass: lead sign-off single-frame 可分(唔靠色/deplete)。
- **AC-UX-5/U-6**:Setup: 量度;Verify: HP=6 / EXP≥4 / font≥7,text_scale 0.8 → font≥7;Pass: floor 守住。
- **AC-UX-10/U-2**:Setup: REST_PERIOD;Verify: SKILLS ≤8+scroll、STAT ≤3 block;Pass: 非無限展開。
- **AC-UX-8**:Verify: banner hit-area ≥44×44。
- **AC-V-2/CR-1/13⑧**:Setup: shake 中餘光讀;Verify: outline+shadow figure-ground、reward 喺 L1;Pass: lead sign-off。

---

## Test Evidence

**Story Type**: Visual/Feel · UI
**Required evidence**: `production/qa/evidence/gym-mode-hud-glance-playtest.md`(AC-V-1 數據 + sign-off)+ `production/qa/evidence/gym-mode-hud-colorblind.md`(3 sim 截圖)+ `production/qa/evidence/gym-mode-hud-visual.md`(shake/floors/REST + sign-off)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (bars) · Story 004 (skills) · Story 008 (Boss HP/dim) · Story 009 (design-time glance CI 前置)
- **BLOCKED (AC-V-1 result)**: external human tachistoscope playtest(N=12,OQ-U4 tooling + tester 招募)— protocol-delivery gate ✅(UX spec);result gate 待 playtest 執行。**epic 可選 ship-with-AC-V-1-deferred-and-tracked(user decision,見 EPIC Definition of Done)**
- Unlocks: epic close
