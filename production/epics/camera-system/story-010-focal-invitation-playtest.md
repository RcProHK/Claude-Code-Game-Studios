# Story 010: Focal Invitation Perceptual Playtest

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: AC-32（Pillar 3 supporting — perceptual validation of Formula 2 quart ease-out）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Focal entry quart ease-out 嘅「decisive invitation」property 要喺真人 panel 驗證 — AC-11 證 **math** front-load，AC-32 證 **feel** 讀得正確。ADVISORY gate（screenshot/clip + lead sign-off）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Visual/Feel — 唔可 headless 自動化。Web Export Compatibility renderer（position_smoothing HIGH risk 嘅 renderer）+ mobile Safari。

**Control Manifest Rules (this layer — Foundation)**:
- Required: manual evidence + lead sign-off（ADVISORY）
- Forbidden: 當作 BLOCKING（feel issue 唔 block build）
- Guardrail: ≥80% "invitation" not "pulled"

---

## Acceptance Criteria

*From GDD Section H, scoped to this story（Visual/Feel — ADVISORY）:*

- [ ] **AC-32** [Falsifiable #5 / Pillar 3] — human panel（n≥5）mobile Safari，BOSS_ENCOUNTER + LOOT_DROP Focal entry random order → ≥80%（≥4/5）描述 feel 為「invitation / 主動帶我望」NOT「pulled / 被迫聚焦」。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Falsifiable Test #5 / Formula 2:*

- 唔產生 GDScript logic — 係 perceptual playtest evidence collection。
- AC-11（Story 004）證 quart math front-load 75.99%；AC-32 係人類 counterpart — 喺真 device 驗 feel。
- 結果 + screenshots/clips 寫入 `production/qa/evidence/`，lead sign-off。<80% → ADVISORY fail，file feedback 畀 game-designer（ease curve tuning），唔 block build。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: quart math AC-11（headless）— 呢度只驗真人 perception
- Story 012: FR-2 frame smoothness（perf，唔同 perceptual feel）

---

## QA Test Cases

*Visual/Feel — manual playtest evidence（ADVISORY gate）。*

- **Manual check: AC-32** — Focal entry「invitation」perceptual validation
  - Setup: Web Export（Compatibility renderer）→ mobile Safari iOS；panel n≥5；trigger Focal under BOTH BOSS_ENCOUNTER + LOOT_DROP；唔 prime「invitation」字眼
  - Verify: 每 tester 用自己字眼描述 camera move feel；classify「invitation」-aligned（invites/draws-attention/gentle/leads-the-eye）vs「pull」-aligned（yanked/pulled/snapped/jarring）；每 scenario 1 screenshot/clip
  - Pass condition: ≥80%（≥4/5）描述「invitation」NOT「pulled」；validates quart ease-out front-load（AC-11）perceptually
  - Sign-off: qa-lead + design lead 寫入 evidence doc；<80% → ADVISORY fail（feel feedback，唔 block）

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/camera-focal-invitation-[date].md` — screenshots/clips + panel results + lead sign-off（ADVISORY）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（quart entry tween）、Story 005（exit tween）— 需可 trigger 完整 Focal
- Unlocks: None（perceptual validation，feeds ease-curve tuning if fail）
