# Loot Drop System (#15) — Review Log

## Review — 2026-05-28 — Verdict: APPROVED (inline same-session)
- Scope signal: L
- Specialists: creative-director (×2 — Section B framing + Phase 5a-bis Opus gate) + game-designer + economy-designer + systems-designer (×3 Section C parallel) + systems-designer + economy-designer (Section D parallel) + systems-designer (Section E) + qa-lead (Section H) + art-director (Visual/Audio + UI)
- Blocking items: 0 | Recommended: 6 inline-resolved (F-3 + F-4 + F-5 + F-6 + F-9 + F-10) + 2 deferred (F-8 + F-12)
- Summary: CD-GDD-ALIGN Pass 1 verdict CONCERNS resolved inline same-session — 6 of 8 findings inline-fixed (cap=6 rationale + daily NO pity boundary + FR-1 emotional microcopy + class_affinity Pillar 4 substrate + AC-38/AC-40 BLOCKING promotion + anti-pillar drift guard)。Pass 1 declared APPROVED post-resolution。
- Prior verdict resolved: First review (Pass 1)

## Review — 2026-05-28 — Verdict: MAJOR REVISION NEEDED (Pass 2 fresh-session re-review)
- Scope signal: L
- Specialists: 4 independent in fresh /clear session — game-designer + systems-designer + economy-designer + qa-lead → creative-director Opus tier senior synthesis
- Blocking items: 8 (F-1 through F-8) all inline-fixed same-session per user autonomous mode | Recommended: 4 followup-tracked (F-9..F-12)
- Summary: Pass 1 inline same-session APPROVAL **rescinded** by Pass 2 fresh-session re-review。4 independent specialists surfaced 8 convergent BLOCKING items invisible to Pass 1 inline review。Pass 2 inline fixes applied: (F-1) workout_id resolution via `WorkoutStateTracker.get_active_workout_id()` with explicit null branch (Rule 7.5 NEW) — closes signal payload schema gap; (F-2) ceremony cap split into MINI_BOSS_CEREMONY_CAP=5 + FINAL_BOSS_RESERVED=1 — final boss ceremony guaranteed, restoring P3 PRIMARY substrate; (F-3) NEW micro_ack ceremony tier — mini-boss #6 acknowledged via toast + mailbox badge, restoring P1 multi-effort acknowledgment; (F-4) E3 while-loop with max_iterations=10 + monotonic assert — anti-pillar soft-clamp termination guaranteed; (F-5) dual-gate Rule 4 with workout-score tier ceiling `floor(workout_score × 5)` — preserves「肉身決定 ceiling」P1 substrate against mini-boss 100% drop fantasy contradiction; (F-6) rename「daily guaranteed」→「workout-locked daily」throughout — aligns game-concept anti-entitlement spirit; (F-7) NEW AC-43 daily token gate BLOCKING; (F-8) NEW AC-44 EC-22 unknown rarity tier BLOCKING。AC-38/40/41 BLOCKING→ADVISORY downgrade (F-9) per Testing Standards catch-22 compliance。Total 44 ACs (24 unit + 12 integration + 5 static-analysis + 1 composite + 4 ADVISORY playtest)。
- Convergent patterns established: (1) Signal payload schema convention gap → followup ADR-007 candidate (F-1 generalized); (2) Floor + ceiling pattern for pillar tension (F-5 method); (3) Ceremony budget = finite resource requiring reservation logic (F-2/F-3 method); (4) Testing-Standards-downgraded ACs MUST pair with followup spec (F-9 method)
- Anti-pattern guards established: (1) Inline same-session APPROVAL insufficient for convergent structural defects — fresh-session adversarial gate required for Phase 5a-bis (Pass 1 → Pass 2 confirms); (2) Signal payload contracts must be declared in Dependencies section (F-1 generalized)
- Pillar substrate post-fix: P1 anti-fabrication chain 第六件套 honest (workout_id resolution closes ceremony-binding gap + workout-score tier-ceiling gate closes RNG shadowing) / P3 PRIMARY substrate intact (final boss ceremony reservation guarantee) / P4 dominant-class derivation unchanged / P5 decoupled (acceptable for #15)
- Prior verdict resolved: **Yes — Pass 1 inline APPROVED retrospectively rescinded; Pass 2 inline-fixed pending Pass 3 fresh-session re-verification**
- Next action: `/clear` → fresh-session `/design-review design/gdd/loot-drop-system.md` for Pass 3 CD-GDD-ALIGN re-verification (independent verification of inline F-1..F-8 resolutions); OR direct progression to #26 Avatar Renderer if user accepts Pass 2 inline + Pass 3 deferral

---

## EG-3 (audio #4 cross-system gate) RESOLVED — 2026-06-03

**Gate**: #4 Audio Manager 情境A (LOOT_DROP-from-BOSS_ENCOUNTER → boss_theme→rest_calm quick fade) needed confirmation that boss-kill loot enters the GSM LOOT_DROP state with `from_state == BOSS_ENCOUNTER`.

**Finding — CONFIRMED, no #15 change needed**:
- The GSM owns the LOOT_DROP state transition, NOT #15. game-state-machine.md line 213 (BossEncounter state) defines `Boss defeated → LootDrop (BossOutcome.DEFEATED)` AND `workout_completed → LootDrop (INTERRUPTED_WITH_CREDIT)` → final-boss-kill LOOT_DROP `from_state == BOSS_ENCOUNTER`. ✓
- #15 (this GDD) is a pure data/event layer (Rule: receives boss_killed/enemy_killed/workout_completed → generate loot + emit `loot_dropped` ceremony signal). It does NOT own or alter the GSM state transition, so it cannot contradict the from-state. ✓
- Nuance: mini-boss kills happen during COMBAT_ACTIVE (not BOSS_ENCOUNTER — GSM line 213: BossEncounter is promoted from CombatActive = final boss); deferred-reveal loot (GSM Decision #1) enters LOOT_DROP from a safe state. Both → `from ≠ BOSS_ENCOUNTER`, and boss_theme is not playing then, so the audio handler correctly does NOT fire 情境A. The only path where boss_theme plays AND we enter LOOT_DROP is the final boss via BOSS_ENCOUNTER — exactly the `from == BOSS_ENCOUNTER` discriminator.

**Outcome**: EG-3 CLOSED. audio-manager.md Q-PENDING-BLK8-CO marked RESOLVED. No edit required to loot-drop-system.md (data layer, GSM-owned transition confirmed correct). This is independent of #15's still-pending Pass 3 CD-GDD-ALIGN re-review (which is about #15's own internal design, not this audio from-state question).
