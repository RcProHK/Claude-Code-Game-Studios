# Onboarding Coach-Mark — Visual Restraint Evidence (#27 Story 013, ADVISORY)

> Type: UI / Visual restraint sign-off. **Structural guarantees are CI-verified**; the
> subjective "feels peripheral / unobtrusive" judgement is a human art-director gate
> (deferred — placeholder visuals; real art via `/asset-spec system:onboarding-flow`).

## CI-verified (BLOCKING, automated — `tests/integration/onboarding_flow/test_overlay_layer.gd`)

| Guarantee | Test | Status |
|---|---|---|
| OnboardingOverlayLayer at layer **63** (captured band <100) | `test_overlay_layer_is_63_captured_band_prewarmed_hidden` | ✅ |
| Pre-warmed `visible=false` (idle zero draw-call) | same | ✅ |
| **NO BackBufferCopy** under the overlay (opacity-only, no blur) | `test_overlay_has_no_backbuffercopy` | ✅ |
| Single coach-mark slot (≤1 card at a time) | `test_single_coach_mark_slot` | ✅ |
| Class coach-mark copy names the class (color-independent) | `test_coach_mark_copy_names_class` | ✅ |

## Structural restraint (code-enforced — `src/ui/onboarding/coach_mark.gd`)

- **No pulse / no gaze-drawing animation** — fade is `modulate:a` opacity-only via `coach_fade_sec` (reduced-motion → hard cut). No `AnimationPlayer`, no scale/position tween (#24 banner / P-17 restraint).
- **`mouse_filter = IGNORE`** on the card + all children — never steals the player's one-tap (UX-06).
- **Peripheral anchor** — `PRESET_TOP_WIDE` top strip, never the central one-tap zone.
- HUD palette (warm-white #F5EFE0 text; amber #F2A93B accent) — desaturation-immunity is moot (R-2: coach-mark defers during all world-desaturating states, AC-10).

## Human art-director sign-off (DEFERRED — ADVISORY)

- [ ] Coach-mark card reads as *peripheral & calm*, not an alert/notification (subjective).
- [ ] Fade timing (0.25s) feels gentle, not laggy or abrupt.
- [ ] Placeholder visuals → real art via `/asset-spec system:onboarding-flow` (UXQ-02/04).
- [ ] Live playtest: AC-14 "zero coach-mark mid-set" + AC-24 "player doesn't recall a tutorial" (story 016).

**Verdict (automated portion)**: ✅ PASS — all structural/topology guarantees CI-verified.
Human visual sign-off pending real art + playtest (Pre-Production gate, non-blocking for MVP code).
