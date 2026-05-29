# Review Log: GymSys Backend Client

## Review — 2026-05-26 — Verdict: APPROVED (Pass 2 lean re-review)
Scope signal: L (multi-system integration, 1 owned formula, 7+ dependents, ADR-002 + ADR-004 required)
Specialists: None (lean mode — single-session analysis)
Blocking items: 0 | Recommended: 4 (all resolved inline)
Summary: Pass 2 lean re-review after P0 surgical revision pass. All 7 P0 blocking items from Pass 1 verified resolved: tombstone Set dedupe holds under boundary analysis, Draining substate properly integrated in 6×6 FSM, confused-deputy defense architecturally sound, REMOVE-field fail-loud escalation correct, non-blocking logout API has static-check enforcement. Four advisory housekeeping items resolved inline: AC-28 signal count corrected 13→18 (drain_started + drain_completed + substate_changed + dropped_event + drain_in_progress formally added); three previously undeclared signals (drain_in_progress, dropped_event, substate_changed) added to Rule 5 declaration block with telemetry-class / test-seam annotations; Rule 11.1 latch-check 200 handling clarified to explicitly suppress lootdrop_committed emission during latch; 429+Draining interaction edge case added (honor Retry-After only if < WRITE_TIMEOUT, otherwise treat as timeout_count). GDD implementable as written.
Prior verdict resolved: Yes — Pass 1 NEEDS REVISION (7 P0 items, 2026-05-26)

## Review — 2026-05-26 — Verdict: NEEDS REVISION → Revised same session
Scope signal: L (multi-system integration, 1 owned formula, 7+ dependencies, ADR-002 + ADR-004 required)
Specialists: game-designer, systems-designer, network-programmer, godot-specialist, qa-lead, creative-director (synthesis)
Blocking items: 7 P0 | Recommended: 13 P1 | Nice-to-have: 9 P2
Summary: First /design-review (full depth) pass. 5 specialists adversarial scan + creative-director senior synth re-opened prior CD-GDD-ALIGN CONCERNS verdict → REJECT. Three P0 findings mapped directly to pillar violations the prior gate did not cover: (1) Rule 15 FIFO commit cache eviction → Pillar 3 double-fire ritual (game-designer + systems-designer cross-corroborated); (2) AC-18 client-owned 10s logout drain blocks UI mid-rest → Pillar 2 violation (cascade Q-X10 to #24 insufficient because blocking primitive lives in client); (3) Tuning Knob safe ranges (POLL_TIMEOUT=4.5 + POLL_JITTER=0.5) self-contradict Invariant #1 → boot assert crash WASM (Pillar 1 indirectly — anti-fabrication architectural posture cannot work if app never runs). Four additional P0s: (4) FSM 5×5 transition matrix incomplete with 4 undefined cells, making AC-26 "exhaustive" claim undeliverable; (5) JavaScriptBridge.eval("navigator.storage.estimate()") quota probe broken-as-written because GDScript 4.6 cannot await JS Promise; (6) Confused-deputy defense missing — browser auto-attaches studiosys session cookie on same-origin even when client only sets X-Session-Token; (7) X-Protocol-Version REMOVE-field handling silently drops required field → #18 PR Detection silent corruption.

Revised same session via surgical pass (~7 edits across 11 sections):
- POLL_TIMEOUT safe range tightened 2.0..4.5 → 2.0..4.0 (honors Invariant #1 unconditionally)
- Rule 15 FIFO cache replaced with `_committed_tombstones: Dictionary[String, int]` (tids + timestamps only, NO payload), age-based eviction with new knob `COMMITTED_TOMBSTONE_RETENTION_DAYS = 35` (matches ADR-006 Contract 15 37d - 2d safety buffer); AC-16 expanded with byte-不等 sub-case + new `protocol_error("idempotent_commit_response_drift")`
- JavaScriptBridge quota probe deleted entirely; reactive detection via `IPersistence.write → false` → `persistence_volatile()` (one-shot latched); AC-02 simplified to "zero JavaScriptBridge.eval matches"
- Two-tier `clear_session_token(reason: ClearTokenReason)` API: USER_EXPLICIT returns within 1 process frame + enters new `Draining` substate + background commit drain + emits `drain_started(pending)` / `drain_completed(committed, timeout_count)`; SESSION_KILLED cancels all immediately; CI static check `check_clear_session_token_sync_return.sh`; AC-18 + AC-29 rewritten
- FSM expanded from 5 → 6 substates (added Draining); full 6×6 transition matrix (36 cells, 1 self-loops per state + ~17 legal transitions + ~13 illegal `dropped_event` cells); 3 user-decision cells RESOLVED [A]/[A]/[A]: AwaitingAuth→Suspended (cancel claim_session), Backoff→AwaitingAuth direct on retry-401, Backoff→Suspended reset n=1; AC-26 enhanced with named sub-assertions for Cells 1/2/3
- Rule 8.1 NEW — defensive `Set-Cookie` response check with `_carve_out_misconfig_detected` latch + `acknowledge_carve_out_fix()` admin API + new AC-31
- X-Protocol-Version REMOVE-field split: Sub-case A (ADD-only forward compat — continue) vs Sub-case B (REMOVE breaking — fail loud `auth_required()` + `_protocol_skew_detected` latch); new knob `MAX_KNOWN_VERSION = 1`; Rule 10 + Rule 12 `(SUCCESS, 410)` rows added; deprecation path = explicit `410 Gone` with `X-Required-Version` header

Bonus P1 items applied per CD synthesis arbitration:
- D1 arbitrated: Rule 11.1 NEW response classification precedence chain (epoch → substate → latch); each filter protects orthogonal scenarios
- P1-1 game-designer: Player Fantasy Risk Register subsection (FR-1/FR-2/FR-3 ADR-002 ratification contingencies)
- P1-3 game-designer: Telemetry-class signals UI-binding ban + CI static check `check_no_ui_subscribes_telemetry.sh`

Three new CD cascades flagged to ADR-002 ratification gate:
- CD-CASCADE-A: Drain must be non-blocking by client design (B2)
- CD-CASCADE-B: Schema versioning REMOVE semantics with 410 Gone (B7)
- CD-CASCADE-C: ADR-002 UNIQUE constraint scope `(transition_id, account_id)` composite key (network-programmer P0-3)

Stats post-revision: 8 required sections intact + Open Questions; ~606 → ~696 lines; 30 → 31 ACs; 13 → 15 signals (drain_started + drain_completed); 5 → 6 substates (Draining); 1 → 2 new knobs (COMMITTED_TOMBSTONE_RETENTION_DAYS replacing MAX_COMMITTED_CACHE_ENTRIES + MAX_KNOWN_VERSION); 1 new enum ClearTokenReason; 1 new Resource SessionClaimResult (already present); 1 new Rule 8.1 + 1 new Rule 11.1.

Prior verdict resolved: First review

**Specialist disagreements** (arbitrated by creative-director):
- D1 3-layer defense precedence — systems-designer (undefined = bug) vs godot-specialist (justified defense-in-depth). Resolution: BOTH win — defense-in-depth structurally correct (keep all 3 layers); precedence must be spec-explicit (Rule 11.1 added).
- D2 JavaScriptBridge probe — godot-specialist DELETE recommended; no other specialist commented. Resolution: DELETE per Rule 4 principle (reactive detection sufficient).
- D3 5xx retry knob axis — game-designer total-time vs systems-designer tighten count. Resolution: Game-designer's total-time wins as P1 ADVISORY (NOT applied in this P0 pass; recommended for next revision pass).
- D4 Rule 15 cache fix — game-designer server-dedupe-ack vs systems-designer tombstone Set. Resolution: tombstone Set (client-side only, no ADR-002 coordination cost).

**Path forward**:
1. /clear before re-review (current session used ~60% context: 5 specialist agents + CD synth + ~30 surgical edits)
2. Fresh session: `/design-review design/gdd/gymsys-backend-client.md --depth lean` (0 specialist agents, single-session analysis)
3. If APPROVED → mark systems-index #2 Approved + queue /design-system 3 PersistenceLayer
4. If NEEDS REVISION again → assess whether new findings vs. fix-quality issues from this pass

**Decisions resolved during this session** (user-driven via AskUserQuestion widgets):
- Q-FSM1 (AwaitingAuth → Suspended): RESOLVED [A] — Cancel inflight claim_session + persist nothing + resume re-enter AwaitingAuth
- Q-FSM2 (Backoff → AwaitingAuth): RESOLVED [A] — Legal direct transition on retry-401, cancel pending retry timer
- Q-FSM3 (Backoff → Suspended): RESOLVED [A] — Cancel retry, reset n=1, on resume fire fresh poll

**Next milestone after re-review APPROVED**: ADR-002 GymSys Integration Protocol authoring (must address CD-CASCADE-A/B/C); then /design-system 3 PersistenceLayer (whose IPersistence.write failure path is load-bearing for P0-3 quota reactive detection).
