# External-Gate Burndown & Risk Register

> **Created**: 2026-06-12 (Production Sprint 1 — PR-PHASE-GATE condition C1 + TD-PHASE-GATE CONCERN-C)
> **Owner of this file**: producer / main session
> **Purpose**: Single集中 view of every gate that blocks a "done-in-code" story from being *verified*.
> All internal code is implemented + CI-green; the remaining work is **external execution + human validation**.

## How to read this

A story marked "Implemented + CI-green" is **code-complete** but may carry an acceptance criterion that can
only be confirmed against a real backend, real hardware, a real human, or real art. Those ACs are the gates
below. **The critical path of Production is no longer in the codebase — it is in these external lines.**

Each gate: ETA + Owner are **TBD until the user (frank) sets them** — they depend on external resources
(GymSys deploy schedule, test devices, art capacity) that only the user controls.

---

## Line A — GymSys Backend Deploy (live HTTP / CORS / session-token)

**The biggest fan-out.** One action (deploy GymSys + nginx same-origin) unblocks a whole cluster.

| Gate | ADR / Source | Blocks (story/AC) | Owner | ETA |
|------|--------------|-------------------|-------|-----|
| GymSys live HTTP polling round-trip | ADR-0002 (transport empirical) | #2 GymSys epic; #9 WST story-011 | external (GymSys deploy) | TBD |
| CORS same-origin via nginx reverse proxy | ADR-0004 | #2; transport for #9/#18 | external (nginx config — **not in repo**) | TBD |
| COOP/COEP cross-origin isolation (Q-A4) | ADR-0004 + ADR-0006 atomicity | SharedArrayBuffer / WASM threads assumption | external | TBD |
| PR server baseline empirical | ADR-0011 G-PR-1 | #18 PR Detection G-PR-1 | external (GymSys backend) | TBD |
| `gym_sys_backend_client.gd` real endpoint wiring | — | Pillar 1 anti-fabrication命脈 | frank | TBD |

**Unblock fan-out**: deploying GymSys + nginx + wiring the real endpoint clears #2 (whole epic), #9/011, #18/G-PR-1, and is the **prerequisite for the vertical slice** (cannot run a real end-to-end loop without it; a *mock-fed* slice can run sooner — see Milestone 1).

---

## Line B — Hardware Profiling (iOS Safari WebGL2 + mobile P95)

One real-device profiling pass unblocks a cluster of perf-gated ACs.

| Gate | ADR / Source | Blocks (story/AC) | Owner | ETA |
|------|--------------|-------------------|-------|-----|
| GPUParticles2D + Camera2D position_smoothing on iOS Safari WebGL2 | ADR-0001 ratification | #5 story-009; #6 story-011; #7 story-012 | frank (needs iOS device) | TBD |
| CPU budget *numbers* ratification (mobile 200/2ms tier) | ADR-0001 (Provisional) | #14 stories 022/024; combat CPU ACs | frank (device profiling) | TBD |
| Mobile P95 frame-time | ADR-0001 §G-CV | #25 AC-28 (pending) | frank | TBD |
| First real Web Export build smoke (WASM / Compatibility renderer / touch / 512MB ceiling) | ADR-0001 | **R2 — nothing render-verified on real browser yet** | frank | TBD |

**Unblock fan-out**: a single iOS-Safari + Android-Chrome profiling session clears #5/009, #6/011, #7/012,
#14/022+024, #25/AC-28, and validates the HIGH-risk Godot 4.6 render domains (Jolt/glow/D3D12) flagged in
`docs/engine-reference/godot/VERSION.md`.

---

## Line C — Art Sign-Off (real sprites replace placeholders)

Gated on **asset pipeline sprint-0 first** (see Line E), then art capacity.

| Gate | Source | Blocks (story/AC) | Owner | ETA |
|------|--------|-------------------|-------|-----|
| Enemy art sign-off | #14 EnemyDirector story-021 | #14/021 | frank / art | TBD |
| Avatar 36 anim sheets + 12 hero stills | #26 Avatar Renderer G-AR-5 | #26 visual ACs | frank / art | TBD |
| Combat VFX art-director sign-off | #25 UX-02/03/05 | #25 visual ACs | art-director review | TBD |
| Onboarding art placeholder → final | #27 story-013 | #27/013 (deferred) | frank / art | TBD |

---

## Line D — ADR Ratification / Overlay (depends on B + real build)

| Gate | Source | Blocks | Owner | ETA |
|------|--------|--------|-------|-----|
| CombatOverlayLayer overlay-ratify | #25 AC-24 (`pending()`) | #25 ratification | TD + real-build evidence | TBD |
| ADR-0001 full ratification (currently Accepted-structural; CPU numbers Provisional) | ADR-0001 | perf-gated AC cluster | TD (after Line B) | TBD |

---

## Line E — Asset Pipeline Sprint-0 (AUTONOMOUS — done 2026-06-12)

AD-PHASE-GATE conditions C-AD-1/2/3. **These are NOT external — done in this Production Sprint 1 by the main session.**

| Gate | Source | Status |
|------|--------|--------|
| `design/assets/entity-inventory.md` | AD C-AD-1 | ✅ created 2026-06-12 |
| `tools/ci/asset_validator.gd` (5 HARD checks, art-bible §8.D) | AD C-AD-2 | ✅ created 2026-06-12 |
| `assets/.godot_import_presets/pixel_art.tres` | AD C-AD-3 | ✅ created 2026-06-12 |

---

## Line F — Human Playtest / Fun Validation (the core bet)

| Gate | Source | Status | Owner |
|------|--------|--------|-------|
| Core hypothesis ① mid-set glance watchable in ≤1s | game-concept.md L305 / L275 | ❌ never tested | frank (mid-workout) |
| Core hypothesis ② 爆裝值得返第二日 | game-concept.md L305 | ❌ never tested | frank |
| Vertical slice end-to-end (mock-fed acceptable) | game-concept.md L333 | ❌ never built | frank + main session |
| Pillar 2「永不干擾健身」mid-workout playtest | #33 / Pillar 2 | ❌ headless can't verify | frank (real workout) |
| ADVISORY playtest stories | #16, #26/019, #27/016, #29/016 | protocols authored, sessions pending | frank |

---

## Summary — the ~14 gates collapse into 4 real external lines + 1 fun line

1. **Deploy GymSys + nginx** (Line A) → clears backend cluster + enables real vertical slice
2. **Profile on real iOS/Android** (Line B) → clears perf cluster + validates render domains
3. **Make real sprites** (Line C, after Line E tooling) → clears art cluster
4. **TD ratify after real-build evidence** (Line D)
5. **Human playtest the fun** (Line F) → answers the one question 2861 automated tests cannot

> **Set ETAs**: edit the ETA column above as you schedule each line. Review weekly (coordination-rules
> responsibility #4). When a gate clears, mark the blocked story's AC verified and move it out of this register.
