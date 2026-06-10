# Story 015: Ceremony overlay a11y + transient-IDLE delay + G-MM-7 2 patterns

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` UI Requirements §Accessibility / EC-MM-14 / CEREMONY_PRESENT_DELAY_FRAMES
**UX Spec**: `design/ux/mirror-moment.md`(APPROVED — a11y + 2 新 pattern flagged)
**Requirement**: AC-26(GDD 直接 trace)+ UX AC(announce_aria / 44px / reduced-motion)+ G-MM-7 cross-system gate
**ADR Governing Implementation**: N/A — a11y + UI(seam shipped #21/#22/#24);secondary ADR-0001(overlay topology)
**ADR Decision Summary**: N/A;`platform_detect.announce_aria` 已 ship(#24 Story 019 additive 2-arg + polite region)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `platform_detect.announce_aria(text, polite)`(#24 Story 019 additive,back-compat)。`motion_intensity` slider(#6 owns)。

**Control Manifest Rules (Polish layer)**:
- Required: announce_aria(polite);≥44×44px touch target;reduced-motion(motion_intensity)；one-tap
- Forbidden: 資訊靠 motion 傳遞(reduced-motion 下 information loss)；hover-only / drag
- Guardrail: stable-IDLE 確認(CEREMONY_PRESENT_DELAY_FRAMES=6)防 transient flicker

---

## Acceptance Criteria

- [ ] **AC-26**(EC-MM-14): ARMED 等緊兼 GSM IDLE 一閃即入 COMBAT(< `CEREMONY_PRESENT_DELAY_FRAMES`=6)→ 慶典**唔**閃,留 ARMED 等下次 stable IDLE
- [ ] **a11y**(UX spec): 慶典彈出 → `platform_detect.announce_aria("Mirror Moment：第 N 週進化到 T{tier}", polite)`;截圖掣 + ✕ 有 ARIA label
- [ ] **reduced-motion**:尊重 `motion_intensity`(#6)— celebration burst 降密度/關(slider=0 → 靜態 share-card,無粒子動畫);慶典**內容**(avatar+caption+badge)唔受影響(資訊唔靠 motion)
- [ ] **touch target**:截圖掣 + ✕ ≥ 44×44 px;dismiss/screenshot 全部 one-tap(無 hover-only/drag)
- [ ] **G-MM-7**:2 新 UX pattern 入 `design/ux/interaction-patterns.md` — **Share-Card**(bounded screenshot-target + chrome-hide on capture)+ **Screenshot-Share Affordance**(native-screenshot prompt flow);catalog Gaps「Avatar portrait frame — P5 Mirror Moment」slot 已預留

---

## Implementation Notes

*Derived from UI Requirements §Accessibility + EC-MM-14 + G-MM-7:*

- **AC-26 transient-IDLE delay**:`CEREMONY_PRESENT_DELAY_FRAMES`(6≈0.1s)stable-IDLE 確認先呈現;delay 內離開 IDLE → 留 ARMED(避免閃一下被 combat 蓋)。
- **a11y**:`announce_aria(..., polite)`(#24 Story 019 已 ship,seam back-compat);ARIA label on 掣;reduced-motion(motion_intensity#6)降/關 burst,內容不變。
- **G-MM-7 doc**:2 pattern stub 入 `interaction-patterns.md` catalog 表 + full spec(Share-Card chrome-hide-on-capture / Screenshot-Share native-prompt flow);引用 #29 UX spec 為行為 ground truth。

---

## Out of Scope

- Story 010:share-card chrome render(本 story 係 a11y + transient delay + pattern doc)
- Story 011:burst(reduced-motion 影響 burst,但 burst 實現喺 011)

---

## QA Test Cases (Manual + interaction)

- **AC-26**: transient-IDLE delay
  - Setup: ARMED,GSM IDLE 一閃即 COMBAT(<6 frame)
  - Verify: 慶典唔閃,留 ARMED
  - Pass condition: stable-IDLE ≥6 frame 先呈現
- **a11y**: announce + targets
  - Setup: 慶典呈現
  - Verify: announce_aria(polite)fired;掣 ARIA label;≥44px;reduced-motion 靜態 share-card 內容不變
  - Pass condition: 資訊無 motion-loss;one-tap
- **G-MM-7**: patterns
  - Verify: Share-Card + Screenshot-Share Affordance 入 interaction-patterns.md catalog

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/mirror-moment-a11y-evidence.md`(manual walkthrough — announce/targets/reduced-motion)+ interaction test `tests/integration/mirror_moment/transient_idle_delay_test.gd`(AC-26)+ interaction-patterns.md diff
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010(overlay)/ Story 005(present gate)/ Story 011(burst reduced-motion)
- Unlocks: None
