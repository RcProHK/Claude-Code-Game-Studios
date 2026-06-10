# Story 010: Screenshot prompt + share-card (CR-M7)

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M7 / UI Requirements / EC-MM-12/13
**UX Spec**: `design/ux/mirror-moment.md`(APPROVED — 3-zone layout / share-card / screenshot flow;stories 引用 UX spec for layout/pixel,GDD for FSM/behaviour)
**Requirement**: AC-13(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps(primary — CanvasLayer topology + opacity-only backdrop)
**ADR Decision Summary**: >100 modal topology;opacity-only backdrop NO 2nd BackBufferCopy(#24 AC-36 budget);game 唔 pause(overlay)。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(WebGL2 modal topology)
**Engine Notes**: share-card 坐 ModalLayer 120;backdrop opacity-only dim(無 BackBufferCopy);**in-app capture-to-PNG NOT MVP**(web `get_viewport().get_texture()` file-save 跨瀏覽器唔可靠 → native-only)。

**Control Manifest Rules (Polish layer)**:
- Required: bounded share-card region(`SHARE_CARD_ASPECT`=viewport MVP);chrome-hide on capture;native-screenshot only
- Forbidden: 2nd BackBufferCopy;in-app capture-to-PNG(v0.2)
- Guardrail: dismiss 零摩擦(Pillar 2)

---

## Acceptance Criteria

- [ ] **AC-13**(CR-M7): 慶典呈現 → 玩家撳「截圖分享」→ 非-card chrome 暫隱 + 顯示 native-screenshot hint「用裝置截圖功能影低呢個畫面 📸」+ emit `mirror.share_prompted`;確認後 emit `mirror.shared` + `last_shared_unix=now`
- [ ] CR-M7 share-card:bounded Control(`SHARE_CARD_ASPECT`=viewport MVP)內含 avatar hero pose + caption + tier badge + narrative 行;**呢個 region 就係玩家截圖嘅嘢** — 邊界乾淨(capture 時周邊 chrome 暫隱)
- [ ] 撳掣 flow:暫隱非-card chrome → hint → 3秒後/再撳 → chrome 復原 + 「影咗喇 ✓ / 跳過」二選 → `mirror.shared` / `mirror.share_skipped`
- [ ] backdrop opacity-only dim(NO 2nd BackBufferCopy);game 唔 pause(GSM 仍 IDLE,慶典係 overlay)
- [ ] EC-MM-12:dismiss 但唔截圖 → set window markers + emit `mirror.share_skipped`,唔重彈(CR-M9 by story 012)
- [ ] EC-MM-13:截圖後即 dismiss → emit `mirror.shared` + `last_shared_unix=now`

---

## Implementation Notes

*Derived from CR-M7 + UX spec(MVP screenshot-only):*

- share-card region = bounded Control(viewport MVP;9:16 layered → v0.2)— 截圖目標,chrome-hide on capture(CR-M7)。
- ModalLayer 120(chrome/CTA/✕)+ backdrop opacity-only(無 BackBufferCopy — #24 AC-36 budget,沿 #21 blur-cut)。
- **native-only**:MVP 唔做 in-app capture-to-PNG(Q-OQ-CAPTURE locked)。撳掣 → hint + emit `mirror.share_prompted`。
- 引用 `design/ux/mirror-moment.md` 嘅 layout/pixel/interaction-map(3-zone + one-tap flow);GDD 為 behaviour/event。

---

## Out of Scope

- Story 011:celebration burst(本 story 係 share-card chrome)
- Story 012:window marker on dismiss(CR-M9)
- Story 015:a11y(announce_aria / 44px — story 015)

---

## QA Test Cases (Manual walkthrough + interaction test)

- **AC-13**: screenshot flow
  - Setup: 慶典呈現(EVOLUTION 或 REFLECTION)
  - Verify: 撳「截圖分享」→ 非-card chrome 暫隱 + native hint + `mirror.share_prompted`;確認 → `mirror.shared` + last_shared_unix
  - Pass condition: chrome-hide 乾淨;event emit 正確;backdrop opacity-only(無 2nd BBCopy)
- **EC-MM-12/13**: dismiss vs share
  - Setup: 呈現
  - Verify: dismiss 唔截圖 → share_skipped;截圖後 dismiss → shared + last_shared_unix

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/mirror-moment-screenshot-evidence.md`(manual walkthrough)+ interaction test `tests/integration/mirror_moment/screenshot_flow_test.gd`(event emit assertion)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007(reveal source)/ Story 005(present gate)
- Unlocks: Story 011(burst on share-card)/ Story 012(dismiss marker)
