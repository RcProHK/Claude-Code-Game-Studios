# Review Log: Game State Machine

## Review — 2026-05-25 — Verdict: MAJOR REVISION NEEDED → Revised same day
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, gameplay-programmer, creative-director (synthesis)
Blocking items: 15 | Recommended: 15 | Nice-to-have: 7
Summary: First /design-review pass surfaced 15 BLOCKING issues across pillar violations, architectural ambiguity, and untestable ACs. Most critical: (1) Rule 5 backend-wins reconciliation could DROP a forward-recovery LootDrop — direct Pillar 3 hard-guarantee violation; (2) AC-11 line 305 contradicted edge case line 149 on whether boss_defeated flag enters LootDrop payload on Rule 7 abort; (3) GDD conflated "localStorage" (11 references) with Godot Web Export's `user://` (IndexedDB-backed) with materially different quota and Safari ITP eviction semantics. Revised same session: locked client-wins LootDrop forward-recovery + non-modal reveal; boss_defeated flag IS in payload; IndexedDB via user:// with TTL capped to 6 days; bfcache restore rule moved from Open Question into Detailed Rules; Rule 2 split into 8 steps with exception-safe fallback unlock; Event Intake Queue defined; formula preconditions added; 27 ACs (was 21) with mock injection / IClock / IPersistence / dropped_event signal observability mechanisms; EXERCISE_SWITCH_TIMEOUT 5s→60s. Q-E3, Q-E4, Q-A1 resolved; Q-A3 partially resolved; Q-A4/X1/X2 added.
Prior verdict resolved: First review

**Pending**: Re-review in fresh session to validate revisions hold under independent specialist scrutiny.

---

## Review — 2026-05-25 (re-review #2) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, gameplay-programmer, creative-director (synthesis)
Blocking items: 6 clusters | Recommended: 9 | Nice-to-have: 6
Summary: Revision genuinely closed 15 prior blockers (Boot Sequence, Event Intake Queue, tombstone forward-recovery, Formula 1 overflow safety, safe-range knob table). Three specialists independently hit Rule 2 step 7/8 ordering bug — lock releases before emit, allowing synchronous subscriber re-entrance to nest a full transition inside the outer one (direct Pillar 3 violation if outer was LootDrop). Five additional blocking clusters: (1) Step 2→3→4 persistence write order creates phantom intermediate state on quota fail; (2) GymSys transition_id dedupe is unratified upstream contract — must verify against existing GymSys at C:\Users\frank\Desktop\GYM; (3) Pillar 2/3 reveal-flow inversions — non-modal toast on resume IS the attention demand it was meant to avoid; AC-19 deferred reveal silently auto-commits then queues toast on new session (Pillar 3 ritual is dead); (4) Autoload _enter_tree ordering claim factually incorrect for Godot; subscribers WILL miss initial state_changed emit; (5) Knob-invariant math errors — STATE_TRANSITION_FALLBACK_MS / EXERCISE_SWITCH_TIMEOUT × 0.1 violated within published safe ranges, TOMBSTONE_TTL_SECONDS < SUSPENSION_TTL_SECONDS violated at equality, LATE_THRESHOLD_SECONDS orphan, bfcache fast-resume skips schema migration. Creative-director: gameplay-programmer lens dominates (atomicity bugs corroborated 3-way) but NEEDS REVISION not MAJOR — gaps surgical, architecture sound.
Prior verdict resolved: Partially — 15 prior blockers genuinely closed; the revision introduced 2 new atomicity bugs in Rule 2 itself (Findings #1 + #2 of this round) that need re-addressing.

**Path forward** (per creative-director):
1. Stop this session (atomicity fixes deserve fresh context)
2. /clear, fresh session for revision
3. Single revision session (~2-3h) addressing the 6 blocking clusters surgically
4. Verify GymSys transition_id dedupe via 10-min grep against C:\Users\frank\Desktop\GYM
5. Schedule Q-A4 VS spike (Godot 4.6 web export: IndexedDB sync timing, COOP/COEP threading default, pagehide marshalling)
6. Then re-re-review in another fresh session

**Decisions still required from user** (cannot be resolved from existing docs):
- AC-19 reveal flow: force LootDrop on next foreground / accept tail loss explicitly / suppress until natural pause
- Rule 7 boss credit: rename `boss_defeated` → `boss_interrupted`, OR threshold-gate the credit
- EXERCISE_SWITCH_TIMEOUT: 60s default unsafe (below 90-180s rest periods) — raise to 180s, remove entirely, or soft-confirm with override
- Two-device assumption: scope to single-device with server session lock, OR make loot payload backend-authoritative

**Key decisions locked (binding on dependent GDDs)**:
- Storage backend: IndexedDB via Godot `user://` (constrains #3 PersistenceLayer GDD)
- Reconciliation precedence: client-wins LootDrop forward-recovery, server-wins non-LootDrop, offline-tolerant otherwise (constrains #2 GymSys Backend Client + #3 PersistenceLayer)
- Boss interrupt: `boss_defeated: true` + `boss_id` + `boss_hp_at_interrupt` in LootDrop payload (constrains #14 EnemyDirector + #15 Loot Drop System)
- Non-modal LootDrop reveal toast/badge on resume (constrains #21 Loot Drop Modal + #33 Attention Budget)
- transition_id dedupe protocol (constrains #2 GymSys Backend Client backend write contract)
- ADR-006: State Machine Contract recommended (Q-A2 confirmed)

---

## Review — 2026-05-25 (re-review #3) — Verdict: NEEDS REVISION → Surgical Revision Applied (Hybrid path)
Scope signal: M (surgical) + L (architectural — escalated to ADR-006)
Specialists: game-designer, systems-designer, godot-specialist, gameplay-programmer, qa-lead, creative-director (synthesis)
Blocking items: 14 | Recommended: 13 | Nice-to-have: 5
Summary: Pass 3 adversarial review found 14 BLOCKING issues + 5 specialists pulling in same direction with **NO disagreements** (notable — Pass 2 had godot vs gameplay-programmer signal contract divergence; Pass 3 reinforces same architectural seam). Atomicity bugs **diverging not converging**: Pass 1=2, Pass 2=3, Pass 3=4 new vectors (synchronous request_completed re-entry, cross-transition timer unlock, add_child deferred-insertion, forward-recovery transition_id regeneration). Plus **2 critical corroborated bugs**: transition_id WASM-reload collision (systems-designer R3 + gameplay-programmer B4 independent) → double-grant LootDrop; JSON.stringify(Resource) silent loss of BossPayload (godot-specialist R8) → AC-11a cannot pass under current spec. Plus **Pillar violations**: B1 30-day silent commit (Pillar 3 「不知不覺發生」anti-pattern), B3 401 mid-WORKOUT force-boot (Pillar 2 mid-set attention demand), B12 toast deferred when player needs immediate context. Plus **Pillar 5 design hole**: weekly_tick missed-window collision with Suspended/Disconnected completely unprotected. Creative-director synthesis: "architecture sound, gaps surgical" no longer holds; GDD has accumulated implementation-coupled load that belongs in ADR. **Recommended Hybrid path** (user accepted): apply surgical pillar fixes here (~30 min) + escalate architectural rigor to ADR-006 State Machine Contract (next session ~2-3h) + Pass 4 light verification (~30 min after ADR ratified).
Prior verdict resolved: Partially — Pass 2's 6 clusters genuinely closed; Pass 3 surfaced 4 NEW atomicity vectors at same architectural seam + 2 critical corroborated bugs + Pillar 2/3/5 inversions revealed by adversarial scrutiny.

**Surgical fixes applied this session** (Pass 3 → Pass 3-surgical):
1. **B1 reframed** (Decision #1 hard backstop): Replaced silent auto-commit with **Rule 5 priority 0.5 force-transition `Booting → LootDrop`** on next boot after 30 days; auto-commit + 「未開封」badge demoted to fallback path (force-transition retry exhaustion only). AC-19 rewritten; AC-19b added for fallback. Pillar 3 anti-pattern「不知不覺發生」防禦.
2. **B2 added** (Decision #5 new): **Rule 5.5 — Weekly Tick Missed-Window Replay** — on boot, enqueue catch-up `weekly_tick` events for missed windows (capped at `MAX_WEEKLY_TICK_CATCHUP = 8`); fires BEFORE priority-1 LootDrop reveal. New persistence key `_last_weekly_tick_unix`. New knobs `WEEKLY_TICK_INTERVAL_SECONDS` + `MAX_WEEKLY_TICK_CATCHUP`. AC-34a + AC-34b added. Pillar 5 falsifiable test 受保護.
3. **B3 added** (Rule 5 priority 0 active-state deferral): 401 in `{WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER}` **defers** force-boot until next natural-pause `state_changed`; phone meanwhile runs cached GymSys data as Disconnected mode. New persistence key `_pending_401_reconciliation`. AC-31 split into AC-31a (deferred active path) + AC-31b (immediate non-active path) + AC-31c (claim exhaustion). Pillar 2 mid-set attention 防禦.
4. **B12 added** (Rule 5 priority 0 toast immediate on state mismatch): post-401 reconciliation landing on DIFFERENT state from pre-401 → toast fires **immediate** on that `state_changed` (bypass Decision #1 gating). AC-32 split into AC-32a (state-agree gated) + AC-32b (state-mismatch immediate). Player gets context NOW not 90s later.
5. **ADR-006 Escalation Boundary** (new section): enumerates 15 architectural items deferred to ADR-006 (atomicity primitives, transition_id collision-safety, JSON-Resource serialization, autoload ordering, Callable signature, null payload sentinel, race conditions, knob invariant math, clock-drift formula, migration chain caps, IndexedDB flush, static-analysis transitive enforcement, AC-15b interface-indirection, mock spy contract, cross-device pending_since). GDD prose on these items is provisional pending ADR-006 ratification.
6. **Q-A5 + Q-A6 opened**: Q-A5 = ADR-006 next-session authoring confirmed; Q-A6 = returning-player ritual for `weekly_tick_catchup_capped` defers to #29.

**Items intentionally NOT fixed in this session** (escalated to ADR-006):
- 4 new atomicity vectors (Pass 3 gameplay-programmer B1-B4): request_completed sync re-entry, cross-transition timer unlock, add_child deferred ordering, forward-recovery transition_id regen
- transition_id WASM-reload collision-safety (systems-designer R3 + gameplay-programmer B4 corroborated)
- JSON-Resource silent loss (godot-specialist R8)
- Phase B/C autoload model contradiction (godot-specialist B1)
- Callable.call_deferred() variadic signature uncertainty (godot-specialist B2)
- null payload typed-signal violation (godot-specialist B3)
- connect_for_initial_state race vs real transition (godot-specialist B4)
- 4 invariant boundary math errors (systems-designer B1-B4)
- Wall-clock drift unbounded (systems-designer R2)
- Schema migration chain cost unbounded (systems-designer R4)
- IndexedDB flush semantics (gameplay-programmer N1 / godot-specialist R1)
- AC-18 transitive await missed (gameplay-programmer R3 + qa-lead B3)
- AC-15b interface indirection (qa-lead B4)
- Mock spy contract canonicalisation (qa-lead B2)
- Cross-device `loot_reveal_pending` authoritative clock (game-designer B5)

**Path forward** (per creative-director hybrid recommendation):
1. ✅ Surgical pillar fixes applied (this session)
2. **NEXT**: Author ADR-006 State Machine Contract (~2-3h focused work, next session) — covers all 15 escalated items
3. **AFTER ADR-006**: Pass 4 light verification of GDD against ratified ADR-006 contracts (~30 min) — not adversarial
4. Once Pass 4 sign-off: queue Q-A4 VS spike + proceed `/design-system 2` (GymSys Backend Client) — needs Decision #4 backend extension scope + ADR-006 contracts as ADR-002 input

---

## Review — 2026-05-25 (Pass 4 light verification) — Verdict: NEEDS REVISION → REVISED (same session — ADR-006 sync)
Scope signal: S (single-file mechanical edits, no design decisions)
Specialists: none (lean mode — `--depth lean`)
Blocking items: 8 | Recommended: 10 | Nice-to-have: 3
Summary: Pass 4 trace check against ratified ADR-006 (15 Contracts) found GDD prose / ACs **structurally sound** but with **8 BLOCKING sync items** + 10 recommended where ADR contracts were not yet propagated back into GDD text. **NO new design decisions** — all gaps were mechanical propagation. Surgical sync pass applied same session (~30 distinct edits across 11 sections): (1) Rule 2 step 2 `transition_id` formula updated to Contract 2 algorithm; (2) Forward-recovery transition_id reuse binding added; (3) Storage Backend gains `_transition_id_counter` key; (4) Boot Sequence Phase B/C rewritten per Contract 4 per-autoload sequential model; (5) `connect_for_initial_state` helper rewritten in both Phase D + Signal Contract per Contract 6 sentinel + Contract 7 race guard; (6) 2 new signals added (`tombstone_write_completed`, `weekly_tick_catchup_capped`); (7) Tuning Knob safe ranges tightened (`STATE_TRANSITION_FALLBACK_MS` 100..1499, `MIN_REVEAL_WINDOW_SECONDS` 11..30); (8) 3 new knobs added (`WALL_CLOCK_DRIFT_TOLERANCE_SECONDS`, `MAX_MIGRATION_CHAIN_LENGTH`, `MIGRATION_BUDGET_MS`); (9) ACs rewritten — AC-11a-extra round-trip, AC-15b IInputPolicy injection (was literal-name regex), AC-18 file-wide await scan (was prefix-only), AC-19 server-authoritative `pending_since_server`, AC-21 Contract 11 risk note, AC-26 + AC-27a/b migration cap tests, AC-30 sentinel payload (was null), AC-30a NEW race guard, AC-22a/b NEW drift fallback, AC-33-collision-safety + AC-33-NEW telemetry, Contract 14 spy naming canonicalised across AC-04a/16/21; (10) §ADR-006 Escalation Boundary flipped from "provisional pending ratification" to "RESOLVED — Resolved by Contract N" markers on all 15 items; (11) Header status, Q-A2 + Q-A5 closed. AC count grew from ~33 to ~45.
Prior verdict resolved: Yes — Pass 3 verdict (NEEDS REVISION → Surgical + escalate to ADR-006 Hybrid path) fully closed. All 15 escalated items now resolved by ADR-006 Contracts 1-15.

**Pending**: Re-review in fresh session (`/clear` then `/design-review design/gdd/game-state-machine.md --depth lean`) to validate sync edits hold under independent scan. If Pass 5 lean re-review returns APPROVED → mark GDD #1 Approved + proceed to `/design-system 2` (GymSys Backend Client).

**Decisions still required from user**: none — Pass 4 was pure mechanical propagation.

**Knowledge-gap items**: Q-A4 VS spike (Godot 4.6 COOP/COEP threading default + IndexedDB sync timing + bfcache reinit rate) — schedule before VS implementation; does NOT block Pass 5 re-review.

---

## Review — 2026-05-25 (Pass 5 lean re-review) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean mode — `--depth lean`)
Blocking items: 0 | Recommended: 3 (all stylistic / clarity polish) | Nice-to-have: 2
Summary: Pass 5 independent scan confirms Pass 4 ADR-006 sync edits hold under cold re-review. All 15 ADR-006 Contracts (atomicity primitive, transition_id collision-safe, SerializableResource envelope, autoload sequential, process_frame idiom, sentinel payload, race guard, knob invariants, wall-clock drift, migration chain bounded, best-effort IDB telemetry, file-wide await scan, IInputPolicy injection, Test Spy Contract, server-authoritative pending_since) traced into both prose AND ACs. All 5 Decisions (#1 natural-pause gated reveal + 30d force-boot; #2 BossOutcome enum; #3 RestPeriod rename + GymSys-owned timer; #4 single-device lock + idempotent commit + B3/B12 surgical fixes; #5 Weekly Tick Missed-Window Replay) traced through header / rules / storage / knobs / signals / ACs. Cross-section invariants math-checked against published safe ranges. AC corpus grew 27 → ~45 captures all new obligations with Given-When-Then format + evidence paths. Three advisory polish items (Rule 2 step 0 generational-lock prose cross-ref, "Detailed Design" → "Detailed Rules" heading per 8-section standard, removed-knobs quote-block formatting) — none blocking. GDD ready for implementation; downstream GDDs (#2, #3, #9, #14, #15, #21, #33) will reciprocate during their own authoring per provisional lock note.
Prior verdict resolved: Yes — Pass 4 NEEDS REVISION → REVISED sync edits validated by independent Pass 5 scan.

**Next**: Mark systems-index #1 as Approved (done same session). Queue `/design-system 2` (GymSys Backend Client) — inherits ADR-006 Contracts 2/15 + Decision #4 backend extension scope as ADR-002 input. Q-A4 VS spike still queued before VS implementation begins.

---

## Review — 2026-05-26 (Pass 6 lean re-review) — Verdict: APPROVED
Scope signal: L (re-review of Approved GDD; scope mostly historical)
Specialists: none (lean mode — `--depth lean`)
Blocking items: 0 | Recommended: 3 (all metadata polish) | Nice-to-have: 3
Summary: Pass 6 independent re-review triggered after #5/#6 bidirectional Soft dependents added to Section F lines 370-371 + Bidirectional Consistency Check line 384 (same-day inline fix from /design-review screen-effects-system.md Pass). Verified prior Pass 5 APPROVED verdict holds post-modification — all 15 ADR-006 Contracts still traced cleanly, all 5 Decisions still aligned, ~51 ACs intact, dependency graph now bidirectionally complete with #5 + #6. Three advisory polish items found + applied inline same pass: (1) header status updated from "Revised (4th pass)" to "Approved (Pass 5 + Pass 6)" reflecting actual verdict; (2) AC count reconciled — Section H said "~45" while ADR-006 Escalation Boundary line 823 said "38" → both updated to canonical "~51" with full subdivision breakdown; (3) section heading "Detailed Design" → "Detailed Rules" per 8-section standard (.claude/rules/design-docs.md + design/CLAUDE.md). Nice-to-have unaddressed: CI script owner for `tools/ci/check_no_await.gd` (AC-18) — Open Question track; removed-knobs quote-block formatting lines 515-516 — cosmetic; autoload global position table missing (cross-ref with #6 GDD Q-F4). No design decisions required; GDD remains implementation-ready.
Prior verdict resolved: Yes — Pass 5 APPROVED verdict reaffirmed; bidirectional gap to #5/#6 surfaced from /design-review #6 session also resolved inline pre-Pass 6.

**Next**: Continue /design-system [next-system] queue per systems-index order; Pass 6 polish edits do NOT require Pass 7 re-review (metadata-only).

