# AC-UX-6 — Keyboard Tab Order Walkthrough (Login / Shell #24, Story 019)

> **Story**: `production/epics/login-shell/story-019-a11y-acux.md`
> **AC**: AC-UX-6 (keyboard tab order) — *UI · ADVISORY*
> **Date**: 2026-06-09
> **Spec**: `design/ux/login-gymsys-connection-ui.md` L404-405, L493 + `design/gdd/login-gymsys-connection-ui.md` UI Requirements (WCAG AA keyboard path)

## Tab-order contract (the order the widgets MUST honour)

### LOGIN state
`username → password → show-password toggle → submit`
- A banner appearing **does NOT** steal form focus (`banner_grabs_focus() == false`,
  verified by `test_banner_does_not_steal_form_focus`). SR announcements go through a
  separate hidden ARIA-live DOM region (PlatformDetect seam), never the canvas/form,
  so focus is never pulled out of the form.

### SHELL_IDLE state
`character entry card → inventory entry card → settings gear`
- If a banner is interactive (reconnect/retry), it tabs **last** — it never preempts the
  primary navigation flow (UX L405).

## Verification status

| Aspect | Method | Status |
|--------|--------|--------|
| Tab-order **contract** documented | This doc + UX L404-405 | DONE |
| Focus-steal prevention (`banner_grabs_focus()==false`) | Automated `test_a11y_acux.gd::test_banner_does_not_steal_form_focus` | DONE (code-verified) |
| SR politeness routing (error assertive / banner polite) | Automated `test_a11y_acux.gd` (4 announce tests) | DONE (code-verified) |
| Touch targets ≥44/48px (toggle/submit/retry/reconnect/gear/entry) | `acux_layout.gd` constants + `test_acux8_*` | DONE (contract) |
| **Physical keyboard walkthrough** (actual Tab key through real widgets) | Manual — requires the story-015 form widget | **DEFERRED → story-015** |
| **iOS Safari VoiceOver / keyboard real-device** (AC-47) | Manual on device | **DEFERRED → story-001 external spike** |

> The physical Tab-key walkthrough cannot be executed until the story-015 LOGIN form
> widget exists (LineEdit-vs-DOM route is itself gated on the story-001 iOS Safari
> spike). The **contract** above is the binding spec those widgets must implement, and
> the focus-steal / politeness / touch-target halves are code-verified now.

## Sign-off

| Role | Name | Approval | Date |
|------|------|----------|------|
| UX / a11y (contract + code-verified scope) | frank (solo) | [x] Approved | 2026-06-09 |
| Physical-device walkthrough | — | [ ] Deferred → story-015 / story-001 | — |
