# Visual Evidence — Camera AC-32 (Focal "invitation" perceptual playtest)

**Story**: camera-system / Story 010 (Focal Invitation Perceptual Playtest)
**AC**: AC-32 (Visual/Feel — ADVISORY gate)
**Date**: 2026-06-01
**Status**: ⏳ PENDING — deferred to VS-tier playtest panel + Web Export build

## What AC-32 verifies

The Focal-entry quart ease-out (Formula 2) "decisive invitation" property reads correctly to
humans: ≥80% of an n≥5 panel describe the camera push-in as "invitation / 主動帶我望", NOT
"pulled / 被迫聚焦". This is the human counterpart to the headless AC-11 (which proves the math
front-loads 75.99% of distance in 30% of time).

## Why pending

Requires a Web Export (Compatibility renderer) build deployed to mobile Safari iOS — the
primary target and the renderer where Camera2D.position_smoothing stability is HIGH risk
(ADR-0001 Q-R2). No VS-tier build/scene scaffolding exists yet.

## Verification protocol (to run at VS-tier playtest)

1. Web Export (Compatibility renderer) → mobile Safari iOS device.
2. Panel: n ≥ 5 testers.
3. Trigger Focal under BOTH permitting GSM states (BOSS_ENCOUNTER, LOOT_DROP) in random order.
4. Without priming the word "invitation", ask each tester to describe how the camera move FEELS.
5. Classify each description: "invitation"-aligned (invites / draws-attention / gentle /
   leads-the-eye) vs "pull"-aligned (yanked / pulled / snapped / jarring).
6. Capture 1 screenshot/clip per scenario.

## Pass condition

≥ 80% (≥ 4 of 5) describe the feel as "invitation". < 80% → ADVISORY fail: file feedback to
game-designer for ease-curve tuning (does NOT block the build — feel issue, not a defect).

## Sign-off

| Role | Name | Verdict | Date |
|------|------|---------|------|
| QA Lead | — | [ ] Approved | — |
| Design Lead | — | [ ] Approved | — |

> Headless counterpart AC-11 (quart front-load math) is covered + passing in
> `tests/unit/camera/test_focal_entry_quart.gd`. Both are needed for the focal-feel DoD.
