# Review Log: Camera System

`design/gdd/camera-system.md`

---

## Review — 2026-05-26 — Verdict: APPROVED (Pass 4 lean re-review)
Scope signal: L
Specialists: None (lean mode)
Blocking items: 1 resolved inline (AC-27 stale snap-follow spec) | Recommended: 3 resolved inline (count/coverage-map/UI-hint)
Summary: Pass 4 lean re-review after 13 Pass 3 inline patches. Found 1 BLOCKING (AC-27 still described old "snap follow" behavior incompatible with Q-V1 Pass 3 dead-zone 0% accessibility fix) + 3 ADVISORY (total count 35→36, coverage map 06→06a/06b, UI hint "snap follow" text). All 4 resolved inline. Systems-index updated to Approved (6/33). 17 total patches across all 4 review passes.
Prior verdict resolved: Yes — Pass 3 NEEDS REVISION (7 BLOCKING) resolved via 13 patches.

---

## Review — 2026-05-26 — Verdict: NEEDS REVISION (Pass 3 full adversarial — revised inline)
Scope signal: L
Specialists: game-designer, systems-designer, godot-gdscript-specialist, qa-lead, ux-designer, creative-director (senior synthesis)
Blocking items: 7 + Batch 2 (8 total) | Recommended: 8 (advisory carry-forward from Pass 1)
Summary: Pass 3 full adversarial re-review of previously APPROVED (Pass 2) GDD. 5 independent specialists found 13 issues that Pass 2 lean mode missed: (1) AC-30/AC-G1 safe range values were stale (Section G revised to [5.0,8.0]/[3.0,8.0] but AC-30 still referenced old [3.0,8.0]/[1.0,8.0]); (2) EC-10 `_focal_exit_pending` contradicted Rule 8 kill-all + `TWEEN_PROCESS_PAUSABLE` misconception for Web Export bfcache; (3) AC-06 future-reserved method split needed; (4) AC-29 `assert()` crashes GUT runner; (5) AC-35 CI heuristic undefined since Pass 1; (6) Rule 4 GSM ordering contract not documented; (7) Rep-phase/BOSS_ENCOUNTER timing contract missing in Section F #14; (8) Q-V1 snap-follow was accessibility regression. All 13 items + Pass 4 follow-up (AC-27) patched inline. CD verdict: "Pass 2 APPROVED was premature — Foundation layer GDD required full adversarial review to surface platform-assumption, test-contract, and inline-patch-sync class of issues."
Prior verdict resolved: Yes — Pass 2 APPROVED reclassified to CONCERNS, 13 + 4 patches applied.

---

## Review — 2026-05-26 — Verdict: APPROVED
Summary: CD-GDD-ALIGN gate (2026-05-26) 已通過嘅 GDD 喺 implementation-readiness adversarial review 揭示 7 個 BLOCKING issues。Creative-director synthesis 判定 architectural skeleton 正確 (state machine 4 states + formula structure + signal contract + CI enforcement) — 唔需要重寫結構，全部係 localized spec fixes。godot-gdscript-specialist 揭示 3 個 GDScript crash risks (Rule 6 tween orphaning + Rule 7 truthiness check + Rule 8 SUSPENDED state leak) + signal naming inconsistency (`camera_target_lost` vs `follow_target_lost` 兩個名指同一個 signal) + EC-20 引用未定義 `unregister_camera()` API。systems-designer 揭示 Formula 1 bfcache resume jarring (delta=0.1s 跳 39.3%) + cross-knob safe range table 講大話 (LOCK_ON=1.0/SMOOTH=3.0 corner fail Pillar 2 500ms hard contract)。ux-designer 揭示 "snap-cut 0.3s" semantic contradiction。qa-lead 揭示 AC-09 testability blocker (real `_process(delta)` 不可 measure in GUT — Camera 必須 expose `update(delta)` for dependency injection)。
Prior verdict resolved: First /design-review session (CD-GDD-ALIGN was skill-external full mode review)

### Patches applied inline (2026-05-26):
1. **Rule 6 tween orphaning** → `_camera.create_tween()` (bound to Camera2D, auto-killed on scene change)
2. **Rule 7 truthiness check** → `is_instance_valid(_follow_target)` guard
3. **Rule 7 tween ownership** → `_camera.create_tween()` exit tween
4. **Rule 8 SUSPENDED state leak** → manual `position_smoothing_enabled = true` cleanup BEFORE killing `_exit_tween`; `is_instance_valid` for `_cached_target_path`
5. **Signal naming** → unified `camera_target_lost` across Rule 1 + EC-01 + EC-16 + AC-22 (was混用 `follow_target_lost`)
6. **`unregister_camera()` API gap** → added to Rule 1 public API + AC-06 updated to 5 methods
7. **Formula 1 bfcache jarring** → Rule 9 `_restore_from_suspend()` snap-to-target + `reset_smoothing()` BEFORE Following transition
8. **Cross-knob safe range** → POSITION_SMOOTHING_SPEED [3.0,8.0]→[5.0,8.0]; LOCK_ON_TOLERANCE_PX [1.0,8.0]→[3.0,8.0]; joint constraint derivation added: `SMOOTH_min ≥ 2 × ln(30/LOCK_ON_min)`
9. **snap-cut contradiction** → UI Requirements Q-V1 改為 "instant hard cut (0s — zero frames, true snap)"
10. **AC-09 testability** → `update(delta)` dependency injection spec'd as BLOCKING architectural requirement
11. **AC-07 misleading expression** → cumulative-form rewrite `pos(t) = target × (1 - exp(-k × t))` with t = n/60
12. **`focal_target_clamped` signal** → added to Rule 1 signals block (was orphaned in EC-23 + AC-06)
13. **Header status** → "Approved with revisions" reflecting /design-review patches

### Recommended Revisions deferred to next-revision batch (8 items):
- [game-designer] First-Focal onboarding contract missing
- [game-designer] Pillar 2 vs Pillar 3 tension at rep_phase — Rule 4 唔 gate WorkoutTracker.rep_phase
- [game-designer] GSM transition same-frame race in Rule 4 `current_state` read
- [systems-designer] Formula 4 boundary undefined (d_initial ≤ d_tol case)
- [systems-designer] Formula 5 zoom direction confirmation (`× zoom` vs `÷ zoom` for screen-space-constant intent)
- [qa-lead] AC-32 ADVISORY → BLOCKING upgrade for VS milestone gate
- [qa-lead] EC-15 race condition → BLOCKING tested (untested race = ticking bomb)
- [game-designer] Rule 4 runtime band-aid → caller authorization token (production-grade enforcement)

### Architectural spin-off (NEW work item):
- **AccessibilityBus.reduce_motion ADR** — cross-system motion accessibility (Camera #7 motion_reduction + ScreenEffects #6 motion_intensity + future #15 VFX / #18 Animation 共用 signal bus)。SettingsManager autoload owns; Camera GDD 改為 subscribe contract，唔再 own toggle。Parallel work item — 唔阻塞 camera sprint。Suggested next: `/architecture-decision`.

### Specialist Disagreements (recorded):
- **game-designer #1 vs Rule 3 drag margin**: game-designer 觀察 Follow mode continuous smoothing 違反 Silent Showrunner，但 Rule 3 已定義 8%×12% drag margin = de facto dead-zone for micro-jitter。Creative-director synthesis: drag margin 處理 micro-jitter 但 macro-following 仍有 continuous smoothing。**User adjudication deferred** — option (a) drag margin already enough close issue, or (b) add "stationary detection" target velocity < threshold completely freeze camera。

---

## Review — 2026-05-26 — Verdict: APPROVED
Scope signal: L
Specialists: None (lean mode — single reviewer)
Blocking items: 2 | Recommended: 2 (advisory)
Summary: Pass 2 lean re-review (fresh session, independent of GDD authoring context). 2 BLOCKING items found — both minor naming consistency issues. (1) Section F #26 downstream entry still used stale `follow_target_lost` signal name instead of canonical `camera_target_lost` (other instances fixed in Pass 1 inline patches). (2) Rule 8 comment described cleanup order as "BEFORE killing tweens" but code correctly kills tweens first then does cleanup — comment was misleading/wrong. Both fixed inline. 2 ADVISORY items addressed: Section F private `_force_clear_focal_sync()` reference updated to public `unregister_camera()`. All 5 formulas numerically verified correct. 35 ACs structure verified. Dependency graph: #1 GSM exists; #14/#21/#25/#26 all Pending GDD (expected). APPROVED with 8 Pass-1 deferred recommended revisions queued for next-revision batch.
Prior verdict resolved: Yes — Pass 1 NEEDS REVISION (7 BLOCKING) resolved via 12 inline patches.
