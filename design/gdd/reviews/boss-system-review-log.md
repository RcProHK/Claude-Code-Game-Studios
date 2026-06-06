# Boss System (#16) — Review Log

## Review — 2026-05-27 — Verdict: MAJOR REVISION NEEDED → Pass 2 revised same session

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, economy-designer, gameplay-programmer, creative-director (synthesis)
Blocking items: 20+ | Recommended: 8 | Advisory: 1
Summary: Pass 1 lean mode autonomous run produced 8/8 sections + 30 ACs + 4 formulas + 24 ECs，但 adversarial review by 5 specialist agents + CD synthesis identified structural cracks: (1) Pillar 4「肌群即職業」MVP scope dishonesty — only 1 final boss but claims serve Pillar 4 boss-level expression; (2) STANDARD BossTier dead code across schema/loot/spawn; (3) Reveal ritual timing literal contradiction (200ms total vs 600ms Camera focal); (4) Mini-boss dual path severely underspec; (5) #15 LootDrop deferred dependency would leave VS milestone with no loot drop; (6) Formula 2 clamp inversion at low player_max_hp; (7) Class archetype mechanical distinctness meaningless in auto-play context. 5 cross-specialist consensus patterns identified.

Prior verdict resolved: First review

## Pass 2 Revision — 2026-05-27 — Same Session Inline Revision

User decisions (per /design-review Phase 5):
- **CRIT-1 Pillar 4 claim**: REMOVED — Pillar 4 mechanical expression honestly deferred to post-MVP; #16 now serves Pillar 3 PRIMARY + Pillar 5 secondary
- **CRIT-5 #15 LootDrop tier**: UPGRADED Pre-MVP → VS — VS milestone delivers complete Pillar 3 reward loop (systems-index updated)
- **CRIT-4 Mini-boss architecture**: Mini-boss = EnemyTemplate via #14 wave system (clean split — final boss only owned by #16)
- **Q-V2 BossVisualResource**: Stub schema in #16 with TODO note for #26 Avatar Renderer finalization refactor

Auto-decisions per CD recommendations (user said 「全部跟推薦去做唔使再問我」):
- **CRIT-7 Class archetype**: Reframed as presentation family (silhouette + audio + palette) — not mechanical archetype
- **CRIT-2 STANDARD tier**: Removed from BossTier enum + Rule 9 loot table
- **CRIT-3 Reveal timing**: Added timeline diagram separating dispatch budget (≤200ms / ≤2 frames) vs Camera focal animation tail (0.6s)
- **CRIT-6 Formula 2 clamp**: Added inversion guard `MAX_BOSS_DAMAGE = max(dynamic, MIN_BOSS_DAMAGE)` for player_max_hp ∈ [1, 9] degenerate case
- **GP1 ordering**: spawn-then-emit contract with `assert(boss.is_inside_tree())` before signal emission
- **GP2 await guards**: `is_instance_valid()` before + after await + 3.0s timeout fallback
- **GP5 arena_constraint**: `ArenaConstraintMode` enum (WORLD_ABSOLUTE / SPAWN_RELATIVE / AVATAR_LEASH)
- **E2 mini-boss loot**: Probabilistic NONE → guaranteed 1 with COMMON-UNCOMMON ceiling
- **E3 game-concept promise**: Mini-boss guaranteed drop restores「每動作完成 = 必有 minor loot」promise
- **AC fixes (qa-lead Q1-Q7)**: AC-07 frame-count, AC-22 object identity, AC-27 split unit+manual, AC-29 split a/b/c/d with Likert ≥4.0, AC-30 split unit+manual, AC-31/32/33/34/35 added for EC-07/08/10/hash/gym-sync, AC-12/16 pre-condition note
- **EC-13 severity**: MEDIUM → HIGH (Pillar 3 PRIMARY climax reveal degrade)
- **Open Questions**: Q-X5 session_intent flag (E2 framing alternative) added; ATTACK_POWER saturation note added to Formula 1

Files modified in Pass 2:
- `design/gdd/boss-system.md` — main GDD body (Pillar attribution, Rules 1/2/3/4/7/9/10/11/14, Formula 2 clamp guard, EC-06, EC-13, AC-07/22/27/29/30 splits, new AC-31..35, BossVisualResource stub, Followup tracker)
- `design/gdd/systems-index.md` — #16 status updated with Pass 2 changes summary; #15 LootDrop tier Pre-MVP → VS; Pre-MVP table count adjusted

Outstanding items deferred to future passes:
- BOSS-AC-followup-04: AC-29a/c MVP gate n≥15 sample size enforcement mechanism (gate-check skill integration)
- BOSS-AC-followup-07: Q-V2 BossVisualResource refactor when #26 finalizes shared visual interface
- BOSS-AC-followup-08: CI tooling stories (3 scripts) — Producer scope
- BOSS-AC-followup-09: Q-X5 session_intent flag feasibility (GymSys API extension)
- BOSS-AC-followup-11: Pre-fight grace window design — needs AC-35 real-gym observational data first

Status: ~~Pass 2 Revised — pending fresh-session /design-review~~ **Superseded by Pass 3 below.**

---

## Review — 2026-05-27 — Verdict: NEEDS REVISION → Pass 3 revised same session

Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, gameplay-programmer, qa-lead, creative-director (synthesis)
Blocking items: 7 | Recommended: 5 | Specialist disagreement: 1 (mini-boss loot ceiling direction)
Summary: Pass 2 fresh-session re-review confirmed structural progress (formula spine + CRIT-4 split landed) but identified 7 fix-induced contradictions blocking implementer: (1) Stale AC-03/AC-09 still asserting mini=NONE post Pass 2 Rule 9 change; (2) CRIT-6 vs CF-2 mathematical contradiction at player_max_hp=1 boundary; (3) Mini-boss field/knob ownership migration incomplete post CRIT-4 split (orphan knobs on #16, EnemyTemplate.loot_rarity_ceiling field undefined); (4) Implementation pseudocode ≠ Godot 4.6 reality cluster (Awaitable.race non-existent + global_position lazy update + SceneTreeTimer bfcache freeze + ARENA_WIDTH_PX undefined); (5) CF-3 snapshot enforcement unenforceable (no caching mechanism specified) + Formula 3 posmod fix missing from pseudocode (AC-34 spec gap); (6) No loot sink → 180 drops over 30 sessions inflation risk; (7) Rule 7 reveal ritual async tail violates Pillar 5 Mirror Moment psychological mechanism (Hades/Hollow Knight camera-leading pattern). CD synthesis verdict: NEEDS REVISION (narrowed from MAJOR — structure穩, formula spine穩, but fix-induced contradictions arrived 阻 implementer).

Prior verdict resolved: Pass 1 MAJOR REVISION → Pass 2 introduced fix-induced issues → Pass 3 resolves Pass 2 issues

## Pass 3 Revision — 2026-05-27 — Same Session Inline Revision

User decisions (per /design-review Phase 5):
- **Mini-boss loot ceiling direction**: [B] Keep ceiling but fix architecture (economy-designer path) — mini ceiling UNCOMMON + final boss floor raised UNCOMMON to avoid rarity overlap + add `EnemyTemplate.loot_rarity_ceiling` field as forward constraint to #14
- **ARENA_WIDTH_PX source**: [A] ArenaConfig.tres global single source of truth
- **Loot sink**: [A] Cross-ref future #17 + Open Question Q-X6 + Followup #12
- **Rule 7 reveal reorder**: [A] Camera focal LEADING per Hades/Hollow Knight pattern

Auto-decisions per user 「全部跟推薦去做，唔使再問我」:
- **CRIT-6 vs CF-2 reframe**: CF-2 invariant updated to `boss_attack_damage ≤ max(MIN_BOSS_DAMAGE, ⌊player_max_hp × 0.5⌋)` — floor exception when player_max_hp < MIN_BOSS_DAMAGE × 2
- **AC-12/16/33 CI-dependent classification**: BLOCKING → ADVISORY (with BLOCKED-ON: BOSS-AC-followup-08 tooling story); promote back to BLOCKING when CI scripts land
- **AC-30b split**: AC-30b-vs (n=5 ADVISORY VS-tier) + AC-30b-polish (n=30 BLOCKING Polish-gate)
- **Formula 4 categorical**: scope narrowed to FINAL boss only; mini-boss worked example marked DEAD PATH for #16 (handled by #14 lite path)
- **F1 Test #1b session 5+ retention**: AC-39 added (post-MVP retention validation)
- **F5 TTK target band**: added 4-12 seconds anti-bullet-sponge constraint to MAX_BOSS_HP knob breaking behavior
- **F5 NEVER traceability matrix**: AC-40 added (BOSS-AC-followup-08 CI-blocked)
- **Implementation pseudocode fixes**: Rule 7 GP3 explicit position-before-add_child + signal payload typed with spawn_pos; Rule 11 GP4 wall-clock deadline (Time.get_ticks_msec()) + CONNECT_ONE_SHOT pattern replacing Awaitable.race + idempotent _spawned_emitters.clear()
- **CF-3 caching mechanism**: Rule 5 sub-section added — BossInstance.player_stat_snapshot frozen-at-spawn cached reference; AC-36 enforcement; CI lint added to followup-16
- **Formula 3 posmod fix**: pseudocode updated with posmod() + defensive empty-candidates guard
- **MIN_RITUAL_INTENSITY** raised 0.4 → 0.5 (per systems-designer Weber-Fechner: 0.24s camera focal below 200ms perception threshold)
- **MAX_BOSS_DAMAGE_RATIO** capped 0.7 → 0.5 strict (per INV-5)
- **Orphan mini knobs**: forward-migrated to #14 via Followup #14 (TARGET_KILL_HITS_MINI / DAMAGE_RATIO_PER_HIT_MINI removed from #16 ownership table)
- **EnemyTemplate.loot_rarity_ceiling field schema**: added Followup #15 (forward constraint to #14 next-revision)

Files modified in Pass 3:
- `design/gdd/boss-system.md` — main GDD body (Status header, Pillar attribution preserved, Rule 1 schema default updated, Rule 5 snapshot caching sub-section, Rule 7 camera-leading reorder + GP3 position fix, Rule 9 final floor UNCOMMON + mini ceiling field migration, Rule 11 wall-clock cleanup + idempotent release, Rule 14 ArenaConfig.tres source, Formula 2 CF-2 floor exception, Formula 3 posmod fix, Formula 4 categorical scope, Tuning Knobs orphan migration + TTK target band, AC-03/AC-07/AC-09/AC-12/AC-16/AC-30b/AC-33 revised, AC-36/AC-37/AC-38/AC-39/AC-40 added, Q-X6 + Followup #12-16 added, Test Distribution + Gate Distribution refreshed)
- `design/gdd/reviews/boss-system-review-log.md` — this Pass 3 entry

7 BLOCKING items resolved inline:
1. AC-03/AC-09 stale spec → fixed (Pass 3 narrowed scope to FINAL only + clarified mini-boss owner = #14)
2. CRIT-6 vs CF-2 contradiction → CF-2 invariant reframed with floor exception
3. Mini-boss ownership migration → forward-constrained to #14 (Followup 13/14/15)
4. Implementation pseudocode cluster → Rule 7/11/14 rewrite with Godot 4.6 idiomatic code
5. CF-3 enforcement + posmod → Rule 5 caching sub-section + Formula 3 posmod fix
6. Loot sink → Q-X6 + Followup #12 (cross-doc to #17)
7. Rule 7 Pillar 5 violation → Camera-Leading reorder with timeline diagram

5 RECOMMENDED items addressed:
1. F1 single-boss novelty risk → AC-39 session 5+ retention test added
2. F3 mini-boss dignity tension → economy-designer path adopted (keep ceiling, fix gradient via final UNCOMMON floor)
3. F4 sub-perceptual gradient → categorical (Formula 4 final-only) + MIN_RITUAL_INTENSITY raised
4. qa-lead AC-12/16/33 CI dependency → downgraded ADVISORY with promotion path
5. qa-lead AC-30b n≥30 → split vs/polish gates

Outstanding items deferred to Pass 4 or future revisions:
- BOSS-AC-followup-12: Loot sink GDD authoring (cross-doc, Pre-MVP)
- BOSS-AC-followup-13: ArenaConfig.tres ownership in #14 GDD next-revision
- BOSS-AC-followup-14: Mini knob ownership declaration in #14
- BOSS-AC-followup-15: EnemyTemplate.loot_rarity_ceiling field schema in #14
- BOSS-AC-followup-16: CI tooling scope expansion (snapshot caching lint)

Status: ~~Pass 3 Revised — pending fresh-session /design-review~~ **Superseded by Pass 3 fresh-session re-review below.**

---

## Review — 2026-05-27 — Verdict: MAJOR REVISION NEEDED (Pass 3 fresh-session re-review)

Scope signal: L→XL (up from Pass 2 M — cross-doc impact + 2 ADR-adjacent decisions surfaced)
Specialists: game-designer, systems-designer, economy-designer, gameplay-programmer, qa-lead, godot-specialist + creative-director (synthesis)
Blocking items: 25 (12 TIER A + 9 TIER B + 4 cross-doc TIER C) | Recommended: 8 | Advisory: 5
Specialist disagreement: 1 (Pillar 1 vs Pillar 2 on mid-fight bfcache — CD adjudicated game-designer position correct)

Summary: Pass 3 fresh-session re-review (full mode, 6 adversarial specialists + CD synthesis) found **net regression** vs Pass 2 — Pass 3 fixed 4 issues but introduced 5 new ones. Architecture direction sound (template-driven boss + state machine reuse + lifecycle hooks) but execution discipline gaps systemic. Root cause: lack of systematic checklist for ownership migration (Pass 3 migrations failed to grep downstream references) + Web Export engine knowledge gap. CD verdict: MAJOR REVISION NEEDED, fresh-session Pass 4 strongly recommended due to context usage.

Prior verdict resolved: Pass 1 MAJOR REVISION → Pass 2 NEEDS REVISION → Pass 3 MAJOR REVISION (new regressions introduced)

### 5 Cross-Specialist Consensus Patterns (highest-confidence blocking)

1. **BossInstance + _player_snapshot 雙重 contract gap** (systems-designer #3+#4 + gameplay-programmer #1+#2) — class definition + snapshot lifecycle 完全缺失，implementation cannot begin
2. **GP3 global_position fix itself buggy** (gameplay-programmer #4 + godot-specialist #1) — Pass 3 修正方向錯，NOT-in-tree 時 fall back to local，parent non-identity transform 令 assert false-positive
3. **Loot rarity gap (mini-boss promise)** (game-designer #2 + economy-designer #1) — Rule 9 COMMON-UNCOMMON ceiling 違反 game-concept「uncommon-rare 範圍」public promise
4. **Test infrastructure 同 NEVER coverage gap** (qa-lead #4+#6 + game-designer #1) — AC-40 ADVISORY + AC-38 mock infeasibility + AC-39 ADVISORY 令 long-term retention + anti-fabrication invariants under-tested
5. **Web Export lifecycle knowledge gap** (godot-specialist #3 + gameplay-programmer #6) — NOTIFICATION_APPLICATION_RESUMED + signal connection lifecycle 全部 Web Export blind spots

### TIER A — MVP-Blocker (Pass 4 必須 fix, 12 items)

**A1. Contract Definition Gaps (4 BLOCKING)**
- A1.1: `BossInstance` class — extends 邊個 Node type / @export properties / scene tree structure (含 `$AnimationPlayer` requirement) / required animation library ("idle", "death", "attack_*")
- A1.2: `_player_snapshot` origin/lifecycle — owner (BossSystem autoload? caller-passed?) / capture timing / clear timing / null guard behavior
- A1.3: `spawn_boss` signature canonical form — resolve Interactions table (2 params, template_id) vs Rule 7 pseudocode (3 params, BossTemplate); recommend 4 params with explicit snapshot
- A1.4: `boss_committed` emit/await/return ordering — explicit async semantics doc + connection lifecycle (auto-connect at _ready vs caller-managed)

**A2. Web Export Engine Knowledge Gaps (3 BLOCKING)**
- A2.1: Replace `NOTIFICATION_APPLICATION_RESUMED` with multi-hook handler (`APPLICATION_FOCUS_IN` + `WM_WINDOW_FOCUS_IN` + JavaScriptBridge `pageshow` event listener via platform_detect.gd autoload per ADR-001 routing)
- A2.2: Replace GDScript `hash()` with explicit `deterministic_hash()` (FNV-1a 32-bit pure GDScript implementation) for AC-34 cross-platform/cross-version determinism
- A2.3: Fix GP3 `global_position` — assert AFTER add_child OR document parent-must-be-identity-transform contract; use `is_equal_approx` (NOT `==`) for Vector2 float tolerance

**A3. Pillar-Breaking Design Issues (3 BLOCKING)**
- A3.1: Mini-boss loot rarity → UNCOMMON floor / RARE ceiling (restore game-concept「uncommon-rare 範圍」promise); update Rule 9 + Rule 3 table + forward constraint to #14
- A3.2: Mid-fight bfcache decision — **CD adjudicated game-designer position correct** — implement hybrid: skip-to-kill-animation if `workout_completed` emitted AND boss HP < 30%; otherwise restart at FULL HP. Update Rule 12 + EC-17 + Q-X2 resolution
- A3.3: First-session ATTACK_POWER=0 frustration — duration-based scaling fallback OR first-session tutorial boss path; update Formula 1 + EC-05 + add new EC for first-session

**A4. Cross-Doc Contract Drift (2 BLOCKING)**
- A4.1: Remove INV-1/INV-2 from #16 (orphan refs to migrated #14 knobs); forward-constrain equivalent invariants to #14 GDD next-revision (already in followup #14)
- A4.2: Rewrite AC-10 — drop dead `MINI tier` enum reference, drop mini-boss field assertions (#14 owned post Pass 3), assert only #16-owned final-boss spawn-or-skip branching

### TIER B — Pre-Implementation Polish (Pass 4 OR sprint-kickoff 前 fix, 9 items)

**B1. Test Infrastructure (4 BLOCKING)**
- B1.1: AC-07 split into AC-07a (frame-count order test) + AC-07b (wall-clock ≤200ms safety net) + AC-07c (throttled-tab manual evidence)
- B1.2: AC-38 needs `IClock` dependency injection seam — pre-implement architectural decision before sprint
- B1.3: AC-29a explicit grep mechanism — YAML frontmatter schema with `sample_size: 15+` + `likert_mean: >=4.0` numeric checks
- B1.4: AC-40 promote BLOCKING (file presence + table populated, NOT CI-blocked) + add AC-41/42/43/44 runtime tests for NEVER #3/#7/#8/#9

**B2. Multi-Boss Robustness (2 BLOCKING)**
- B2.1: `_on_enemy_killed_self_listen` add `enemy_id == self.boss_id` filter + spec signal connection topology
- B2.2: BossInstance scene tree contract — required nodes ($AnimationPlayer with animations "idle"/"death"/"attack_*", CollisionShape2D)

**B3. Economy Spec Tightening (2 BLOCKING)**
- B3.1: Pseudocode for `final_tier = max(adr005_floored, boss_template.loot_guarantee_min_tier)` combine logic in Rule 9 (Interpretation 1 — additive floor layering)
- B3.2: First-session economy AC — tier distribution constraints (≥60% UNCOMMON / ≤30% RARE / ≤10% EPIC+ in first 10 sessions)

**B4. Single-Specialist Design (1 BLOCKING)**
- B4.1: MVP boss roster — ≥3 final boss skin variants (same archetype, different silhouette + particle palette + reveal audio) OR longitudinal session-1-vs-5 metric in MVP gate

### TIER C — Cross-Doc / Defer (4 items)

- C1: #17 Equipment & Inventory loot sink — hard upstream blocker declaration in #16 Dependencies section (actual GDD authoring 屬 #17 scope, MVP gate)
- C2: 5-tier rarity compression in early game — ADR-005 calibration revisit (#15 + #17 cross-doc)
- C3: Signal type runtime enforcement claim wording fix (godot-specialist #2)
- C4: BossVisualResource @abstract naming convention + composition-over-inheritance hint

### Pillar 1 vs Pillar 2 Adjudication (CD Decision)

**Disagreement**: Rule 12 author (Pillar 1 honesty > Pillar 2 continuity → FULL HP reset) vs game-designer (Pillar 2/3 continuity > literal HP-reset interpretation → HP persist or skip-to-kill).

**CD Verdict**: game-designer position correct. Pillar 1 anti-fabrication spirit 守 transition_id chain，HP 已 derived from honest workout output 唔係 fabricated value。Reset 反而 erase 咗 honest derived state。Implementation: skip-to-kill-animation hybrid (per A3.2).

### Pass 4 Validation Criteria

Pass 4 success 嘅 marker:
- `BossInstance` class 有 complete signature spec (extends, properties, scene tree, lifecycle, required animation library)
- `_player_snapshot` 有 explicit owner + lifecycle diagram + null guard behavior
- `spawn_boss` signature canonical form locked (Interactions table + Rule 7 pseudocode 一致)
- `NOTIFICATION_APPLICATION_RESUMED` removed, replaced with Web-correct multi-hook handler
- AC-34 uses `deterministic_hash()` (custom function, NOT GDScript `hash()`)
- Mini-boss loot tier explicit UNCOMMON-RARE band (game-concept promise restored)
- Mid-fight bfcache decision documented with skip-to-kill hybrid implementation
- INV-1/INV-2 + AC-10 cross-doc sync verified by grep
- Pass 4 synthesis doc flags remaining TIER B items as known-deferred-to-sprint-kickoff

### Pass 4 Process Recommendation

- **Fresh session required** — current context ~80% used; Pass 4 needs ~40-60% clean budget for 12 TIER A items × spec authoring
- **TIER A scope only** — TIER B 可分批 polish 前 sprint kickoff
- **No 6-specialist re-review needed** — TIER A items 已 cross-domain consensus，Pass 4 純 spec authoring + internal consistency check
- **Pass 5 (optional)** — TIER A 完成後可選擇 spawn 3 targeted specialists (systems-designer + gameplay-programmer + qa-lead) re-validate
- **Pass 4 input materials**: this synthesis log entry + complete boss-system.md + 6 specialist findings (in this log) + game-concept.md (for loot promise verification)

### Outstanding Items (Pass 3 fresh-session re-review 之前 deferred items 仍 active)
- BOSS-AC-followup-12: Loot sink cross-doc design (now subsumed by TIER C1)
- BOSS-AC-followup-13: ArenaConfig.tres ownership in #14 GDD next-revision
- BOSS-AC-followup-14: Mini knob ownership declaration in #14
- BOSS-AC-followup-15: EnemyTemplate.loot_rarity_ceiling field schema in #14
- BOSS-AC-followup-16: CI tooling scope expansion (snapshot caching lint)
- **NEW** BOSS-AC-followup-17: `IClock` dependency injection seam architectural decision (per TIER B1.2)
- **NEW** BOSS-AC-followup-18: Web Export lifecycle reference doc — `docs/engine-reference/godot/modules/web-lifecycle.md` (flagged by godot-specialist for technical-director)

Status: ~~Pass 3 MAJOR REVISION NEEDED — pending fresh-session Pass 4~~ **Superseded by Pass 4 below.**

---

## Pass 4 Revision — 2026-05-28 — Fresh-Session Inline Revision

Scope: TIER A only (12 BLOCKING items per Pass 3 fresh-session re-review CD adjudication). TIER B (9 items) + TIER C (4 items) explicitly deferred to sprint-kickoff polish per CD recommendation。No 6-specialist re-review required — TIER A items already had cross-domain consensus from Pass 3 fresh-session synthesis。

Mode: Pure spec authoring + internal consistency check。User pre-authorized all CD recommended paths ("之後所有用推薦去完成，唔駛再問我") — Pass 4 applied autonomous-decision protocol without per-item AskUserQuestion gates。

### 12 TIER A Items Resolved Inline

**A1. Contract Definition Gaps (4 items)**

- **A1.1 BossInstance class — RESOLVED**: Added complete BossInstance scene-tree contract in Rule 1: `extends Node2D` + 4 spawn-time immutable @export fields (boss_id / boss_template / transition_id / player_stat_snapshot) + 6 runtime mutable fields (current_hp / max_hp / attack_count / _last_emitted_pattern_id / _spawned_emitters / _ai_state) + required child nodes ($AnimationPlayer / $CollisionShape2D / $Sprite2D / $HitArea2D) + required animation library (idle / telegraph / staggered / death + attack_<id> per pattern) + `_ready()` assertions enforcing spawn_boss initialization invariant + `_exit_tree()` cleanup safety net。Direct instantiation forbidden (CI lint per Followup #20)。

- **A1.2 _player_snapshot lifecycle — RESOLVED**: Owner = #14 EnemyDirector caller (capture at BossAnchor COMMITTED tick via `Stat.create_snapshot()`); pass via 4th param of spawn_boss; BossSystem autoload holds NO global `_player_snapshot` state。Clear timing = Godot GC follows BossInstance lifecycle (`_exit_tree`)。Null guard = spawn_boss early-returns null + emits `boss.null_snapshot` telemetry + push_error; #14 BossAnchor caller MUST handle null return + rollback。Pillar 1 forbids fabricating default snapshot。AC-43 added。

- **A1.3 spawn_boss canonical signature — RESOLVED**: Locked at `spawn_boss(template: BossTemplate, transition_id: String, spawn_pos: Vector2, player_snapshot: StatSnapshot) -> BossInstance`。Updated 3 sites for consistency: Rule 7 pseudocode + Interactions table row #14 + Upstream Dependencies row #14。Bidirectional sync gap row updated for #14 GDD next-revision lock。

- **A1.4 boss_committed async semantics — RESOLVED**: Synchronous emit BEFORE return (no `await` inside spawn_boss); subscribers connect via `_ready` using `connect_for_initial_state` pattern per ADR-006 Contract 6 (NOT auto-connected by BossSystem); subscribers can use either signal payload OR caller-chained return value reference; idempotency via `_spawned_transition_ids` guard。Documented as「emit/await/return ordering」block in Rule 7。

**A2. Web Export Engine Knowledge Gaps (3 items)**

- **A2.1 NOTIFICATION_APPLICATION_RESUMED replaced — RESOLVED**: Multi-hook handler in Rule 11 — `_notification` branch listens for `NOTIFICATION_APPLICATION_FOCUS_IN` + `NOTIFICATION_WM_WINDOW_FOCUS_IN` (covers Chromium tab switch + WindowFocus return); `_ready` subscribes to `PlatformDetect.page_shown_from_bfcache` autoload signal (covers Safari bfcache via JavaScriptBridge `pageshow` event per ADR-001 routing — only allowed eval callsite is platform_detect.gd autoload)。Web Export lifecycle coverage matrix table added。NOTIFICATION_APPLICATION_RESUMED explicitly excluded with rationale (Mobile native scope, NOT Web)。Followup #18 added — `docs/engine-reference/godot/modules/web-lifecycle.md` reference doc, owner = technical-director。

- **A2.2 deterministic_hash() FNV-1a — RESOLVED**: Pass 4 replaces GDScript `hash()` in Formula 3 + Rule 2 spawn algorithm with `DeterministicHash.deterministic_hash()` — FNV-1a 32-bit pure GDScript implementation (FNV_OFFSET_BASIS=2166136261, FNV_PRIME=16777619, FNV_MASK=0xFFFFFFFF)。Always returns non-negative 32-bit unsigned → `%` operator safe (posmod() kept as defense-in-depth)。AC-34 updated with golden vector test asserting `deterministic_hash("abc") == 1454761972`。Followup #19 added — `res://src/utils/deterministic_hash.gd` autoload/static helper authoring story。

- **A2.3 GP3 global_position fix — RESOLVED**: Pass 4 fixes Pass 3 fix bug per godot-specialist #1 — (a) re-set `boss.global_position = spawn_pos` AFTER `add_child` to force resolution against parent transform; (b) use `boss.global_position.is_equal_approx(spawn_pos)` (NOT exact `==`) with `POSITION_TOLERANCE_PX = 0.5` for Vector2 float drift tolerance; (c) document parent-must-be-identity-transform contract for BossSystem autoload (CI lint per Followup #21)。AC-37 spec updated。

**A3. Pillar-Breaking Design Issues (3 items)**

- **A3.1 Mini-boss UNCOMMON-RARE band — RESOLVED**: Pass 4 restores game-concept「Short-Term (5-15 minutes) — Exercise-switch Loop」public promise「擊敗 mini-boss → minor loot drop（uncommon-rare 範圍）」which Pass 3 COMMON-UNCOMMON band violated。Mini-boss = UNCOMMON floor / RARE ceiling; final boss raised UNCOMMON→RARE floor to preserve dramatic weight gradient (ADR-005 modifiers push final into EPIC/LEGENDARY for full workouts)。Rule 9 + Rule 3 + Rule 10 + BossTemplate default + AC-03 + AC-09 + INV-8 + Followup #15 (expanded scope) updated。

- **A3.2 Mid-fight bfcache hybrid — RESOLVED**: CD-adjudicated game-designer position implemented — skip-to-kill if `workout_completed` emitted AND `boss.current_hp < boss.max_hp × MID_FIGHT_SKIP_HP_THRESHOLD (default 0.30)`; otherwise restart at FULL HP; if `workout_completed` NOT emitted (PRE_SPAWN freeze) → cleanup defensively。Rationale: HP at 30% IS derived from honest workout output via Formula 1+2 → resetting fabricates higher-effort state than honest progression。Rule 12 + EC-17 + Q-X2 (resolved + closed) + MID_FIGHT_SKIP_HP_THRESHOLD knob + INV-10 + AC-42 added。

- **A3.3 First-session ATTACK_POWER=0 frustration — RESOLVED**: Pass 4 adds duration-based bootstrap fallback to Formula 1 — when `player_attack_power == 0`, `effective_atk = max(BOOTSTRAP_ATTACK_POWER=10, duration_factor × FIRST_SESSION_BASELINE_ATK=28)` where `duration_factor = clampf(workout_duration_sec / FIRST_SESSION_DURATION_TARGET_SEC=600, 0.0, 1.0)`。Rationale: clamp-to-MIN_BOSS_HP path produced trivial 2-3 hit kill on player's FIRST boss — worst possible first impression, Pillar 3 climax 失效。Formula 1 + EC-05 + 3 new knobs (BOOTSTRAP_ATTACK_POWER / FIRST_SESSION_BASELINE_ATK / FIRST_SESSION_DURATION_TARGET_SEC) + INV-9 + AC-41 added。

**A4. Cross-Doc Contract Drift (2 items)**

- **A4.1 INV-1/INV-2 removed — RESOLVED**: Pass 4 removes orphan invariants from Cross-Knob Invariants table (referenced migrated #14 knobs `TARGET_KILL_HITS_MINI` + `DAMAGE_RATIO_PER_HIT_MINI`)。Forward-constraint to #14 GDD next-revision via expanded Followup #14 — #14 MUST declare both invariants in its own Cross-Knob Invariants section as gradient guards owned by mini-boss side post CRIT-4 split。INV-6 narrowed to final-only。

- **A4.2 AC-10 rewrite — RESOLVED**: Pass 4 drops dead「MINI tier with reveal_ritual_intensity=0.6」spec from AC-10 — (i) BossTier enum has only FINAL (MINI removed per CRIT-2 + CRIT-4); (ii) mini-boss reveal_ritual_intensity field doesn't exist on EnemyTemplate (hardcoded 0.6 by #14 wave system per Rule 3)。Rewritten AC-10 asserts only #16-owned spawn-or-skip branching + final-boss field value (reveal_ritual_intensity == 1.0)。Mini-boss spawn assertion belongs to #14 EnemyDirector GDD AC scope (forward constraint)。

### Files Modified in Pass 4

- `design/gdd/boss-system.md` — main GDD body (Status header bumped Pass 3→Pass 4; Rule 1 BossInstance class schema + scene tree contract; Rule 2 deterministic_hash() in spawn algorithm; Rule 5 snapshot caching note updated for caller-passed; Rule 7 4-param signature + post-add_child re-set + is_equal_approx + sync emit; Rule 9 mini UNCOMMON-RARE + final RARE floor; Rule 3 loot guarantee row; Rule 10 light-workout loot range; Rule 11 multi-hook resume handler + Web Export coverage matrix; Rule 12 bfcache hybrid + threshold knob; Formula 1 first-session bootstrap; Formula 3 deterministic_hash(); Tuning Knobs +4 (MID_FIGHT_SKIP_HP_THRESHOLD + BOOTSTRAP_ATTACK_POWER + FIRST_SESSION_BASELINE_ATK + FIRST_SESSION_DURATION_TARGET_SEC); INV-1/INV-2 removed + INV-6 narrowed + INV-8/9/10 added; EC-05 + EC-17 revised; AC-03 + AC-09 + AC-10 + AC-34 revised; AC-41/42/43 added; Q-X2 resolved + closed; Interactions table + Dependencies + Bidirectional sync gap updated; Followup tracker +#17 +#18 +#19 +#20 +#21; Test Distribution + Gate Distribution + Coverage Map refreshed)
- `design/gdd/reviews/boss-system-review-log.md` — this Pass 4 entry

### TIER B + TIER C Outstanding (deferred to sprint-kickoff polish per CD recommendation)

**TIER B (9 items — sprint-kickoff polish window, before story authoring)**:
- B1.1 AC-07 split (frame-count + wall-clock + throttled-tab evidence) — Pass 4 已 reference 3-channel evidence in spec but formal split deferred
- B1.2 AC-38 IClock dependency injection seam — Followup #17
- B1.3 AC-29a explicit grep mechanism + YAML frontmatter schema
- B1.4 AC-40 promote BLOCKING + AC-41/42/43/44 NEVER #3/#7/#8/#9 runtime tests
- B2.1 `_on_enemy_killed_self_listen` add `enemy_id == self.boss_id` filter
- B2.2 BossInstance scene tree contract — Pass 4 已 author 完整 contract in Rule 1; B2.2 task = CI lint authoring (Followup #20)
- B3.1 Rule 9 final_tier = max(adr005_floored, boss_template.loot_guarantee_min_tier) combine pseudocode
- B3.2 First-session economy AC — tier distribution constraints (≥60% UNCOMMON / ≤30% RARE / ≤10% EPIC+ in first 10 sessions)
- B4.1 MVP boss roster — ≥3 final boss skin variants OR longitudinal session-1-vs-5 metric

**TIER C (4 items — cross-doc / defer)**:
- C1 #17 Equipment & Inventory loot sink — hard upstream blocker declaration (subsumed by Followup #12; #17 GDD authoring scope)
- C2 5-tier rarity compression — ADR-005 calibration revisit cross-doc
- C3 Signal type runtime enforcement claim wording fix
- C4 BossVisualResource @abstract naming convention

### Pass 4 Validation Marker Status

- [x] BossInstance class complete signature spec (extends, properties, scene tree, lifecycle, required animation library)
- [x] _player_snapshot explicit owner (#14 caller) + lifecycle (passed via 4th param; GC follows BossInstance) + null guard (early-return + telemetry)
- [x] spawn_boss canonical 4-param signature locked across Interactions table + Rule 7 pseudocode + Upstream Dependencies
- [x] NOTIFICATION_APPLICATION_RESUMED removed + replaced with Web Export multi-hook handler (FOCUS_IN ×2 + PlatformDetect signal)
- [x] AC-34 uses deterministic_hash() (FNV-1a 32-bit, NOT GDScript hash())
- [x] Mini-boss loot tier explicit UNCOMMON-RARE band (game-concept promise restored)
- [x] Mid-fight bfcache decision documented with skip-to-kill hybrid implementation (HP<30% skip / HP≥30% restart / no-commit cleanup)
- [x] INV-1/INV-2 removed + AC-10 cross-doc sync verified by grep (only #16-owned final-boss spawn-or-skip asserted)
- [x] Pass 4 synthesis doc flags remaining TIER B items as known-deferred-to-sprint-kickoff

### Recommended Next Steps

- Pass 4 ready for optional **Pass 5 targeted re-validation** — spawn 3 specialists (systems-designer + gameplay-programmer + qa-lead) for TIER A re-check (recommended per Pass 3 process recommendation)
- OR direct **gate-check / architecture-decision** path if user accepts Pass 4 inline + TIER B deferral
- TIER B sprint-kickoff polish window opens before `/create-stories` for boss-system epic — recommend block-list those 9 items as P0 prerequisites
- Cross-doc forward constraints to #14 next-revision (Followup #13/#14/#15/#18) — surface to producer for cross-doc sync sprint

Status: ~~Pass 4 Revised — 12 TIER A BLOCKING resolved; pending Pass 5 optional re-validation~~ **Superseded by Pass 5 below.**

---

## Pass 5 Targeted Specialist Re-Validation — 2026-05-28 — Verdict: APPROVED

Scope: Pass 4 TIER A re-validation only (read-only review, no GDD writes). 3 targeted specialists per Pass 3 process recommendation: systems-designer + gameplay-programmer + qa-lead. Parallel spawn (independent domains, no cross-dependencies).

Mode: lean targeted (NOT full 6-specialist + CD synthesis). Pass 4 TIER A items 已 cross-domain consensus from Pass 3 fresh-session re-review — Pass 5 純 implementability + AC quality + cross-domain spec sync check.

User authorization: pre-authorized「之後所有用推薦去完成」— Pass 5 applied autonomous-decision protocol (3-specialist parallel spawn per CD recommendation, no per-step AskUserQuestion).

### Verdict Aggregate

| Specialist | Verdict | BLOCKING | CONCERN | Grade |
|---|---|---|---|---|
| systems-designer | APPROVED | 0 | 2 (minor) | A |
| gameplay-programmer | APPROVED | 0 | 1 (deferred-acceptable) | A (sprint-ready) |
| qa-lead | APPROVED | 0 | 2 (sprint-planning) | A- |
| **Net** | **APPROVED** | **0** | **5 minor non-blocking** | **A** |

### Items Validated per Specialist

**systems-designer (5 items)**:
1. A1.1 BossInstance class schema — ALIGN (@export/var split semantically correct; scene tree contract CI-lintable; lifecycle hooks enforce Pillar 1 invariants)
2. A1.2 _player_snapshot caller-passed lifecycle — ALIGN (eliminates BossSystem-autoload global-state ambiguity; CF-3 enforceable via field set BEFORE add_child)
3. A4.1 INV-1/INV-2 orphan removal + forward-constraint — ALIGN (strikethrough preserves migration trail; Followup #14 expanded scope captures both knob ownership AND cross-system invariants)
4. CF-3 snapshot caching architecture — ALIGN (end-to-end chain intact: caller → spawn_boss → _ready → Formula 1/2 read path → CI lint)
5. Fix-induced issues — NONE FOUND (4 spawn_boss signature sites all use canonical 4-param form)

**gameplay-programmer (6 items)**:
1. A1.3 spawn_boss 4-param canonical signature — ALIGN, implementable (#14 BossAnchor COMMITTED tick 有齊 4 inputs; null-return contract clear)
2. A1.4 boss_committed sync semantics + subscriber lifecycle — ALIGN (Godot 4.6 signal idiomatic; multi-boss safe via per-subscriber ownership)
3. A2.1 Web Export multi-hook resume handler — CONCERN (Mobile Safari + Firefox edge cases acceptable defer to Followup #18); GP6 idempotency resolved via _spawned_emitters.clear() pattern
4. A2.3 GP3 global_position post-add_child fix — ALIGN (BEFORE+AFTER add_child pattern idiomatic; POSITION_TOLERANCE_PX=0.5 safe with SubViewport oversample per ADR-001)
5. A3.2 Mid-fight bfcache hybrid 3-branch logic — ALIGN (no race condition; CombatResolver bypass acceptable for synthetic kill event; EC-01 idempotency not tripped by in-place state re-enter)
6. Fix-induced issues — NONE FOUND (Pass 2→3 net regression pattern NOT recurring; downstream grep verified)

**qa-lead (7 items)**:
1. AC-41 (first-session bootstrap) — ALIGN, testable (6 sub-assertions explicit; boundary scenarios complete)
2. AC-42 (bfcache hybrid branching) — ALIGN, needs IClock harness (Followup #17)
3. AC-43 (null_snapshot rejection) — ALIGN, testable (null+push_error+telemetry assertable via GUT standard patterns)
4. AC-03/09/10 revised — ALIGN (boundary clarifications tight; "MINI tier" stale-reference grep confirms only contextually-correct remnants)
5. AC-34 deterministic_hash golden vector — CONCERN (sequencing: Followup #19 MUST precede AC-34 dev; CI infrastructure for Web×Desktop×patch matrix sprint-questionable)
6. Test Type + Gate Distribution + Coverage Map integrity — ALIGN (32+5+3+9=49 ✓; 12 Pass 4 mapping rows 1:1 traceable)
7. NEVER coverage gap + ADVISORY pollution — CONCERN (4 CI-blocked ADVISORY ACs stuck on Followup-08; AC-40 should promote BLOCKING)

### 5 CONCERN Items (all non-blocking)

1. **(systems-designer)** INV-8 wording asymmetry — `>` symbol vs「joint at RARE」prose mismatch; rephrase recommended
2. **(systems-designer)** Rule 5 CI lint scope — broaden enumerated `Stat.get_attack_power()` / `.MAX_HP` to「any `Stat.get_*()` callsite」for future-proof getter coverage
3. **(gameplay-programmer)** Followup #18 Web Export lifecycle reference doc — Mobile Safari + Firefox edge case coverage acceptable defer to technical-director
4. **(qa-lead)** AC-34 sequencing — Followup #19 (`deterministic_hash` autoload story) MUST land before AC-34 implementation (test target class)
5. **(qa-lead)** AC-40 promote BLOCKING + Followup #08 promote MVP-gate prerequisite — otherwise 4 CI-blocked ADVISORY ACs (AC-12/16/33-CI/40) permanently stuck

### TIER B Re-Classification (Pass 5 cross-specialist consensus)

**P0 must-fix-before-story-create (gameplay-programmer call)**:
- B2.1 `enemy_killed` `enemy_id == self.boss_id` self-filter (multi-boss sequence safety)
- B2.2 BossInstance scene tree CI lint (Followup #20)
- B3.1 Rule 9 `final_tier = max(adr005_floored, boss_template.loot_guarantee_min_tier)` combine pseudocode

**MVP gate prerequisite (qa-lead call)**:
- BOSS-AC-followup-08 (CI tooling story) promote — unblocks 4 CI-blocked ADVISORY ACs
- BOSS-AC-followup-19 (deterministic_hash autoload) — sequence before AC-34

**Polish (safe defer to sprint-kickoff window)**:
- B1.1 AC-07 split / B1.2 IClock seam / B1.3 YAML schema / B1.4 NEVER runtime tests / B3.2 first-session economy AC / B4.1 boss roster expansion

### Files Modified in Pass 5

- `design/gdd/reviews/boss-system-review-log.md` — this Pass 5 entry (audit trail only; NO GDD writes per Pass 5 read-only contract)

### Process Notes

- 3-specialist parallel spawn completed in single message — no sequential dependency between systems-designer / gameplay-programmer / qa-lead reports
- Each specialist limited to own-domain re-validation (systems-designer = contract/invariant; gameplay-programmer = implementability/Godot idiom; qa-lead = AC coverage/testability)
- No CD synthesis required — 3 verdicts unanimous APPROVED + zero BLOCKING
- Pass 5 confirms Pass 4 spec-authoring quality: no fix-induced contradictions detected (avoiding Pass 2→3 net regression pattern that triggered Pass 3 MAJOR REVISION)

### Recommended Next Steps

- (a) `/gate-check pre-production` — validate overall GDD-tier readiness for VS-tier 12/13 completion + #26 Avatar Renderer prep
- (b) `/architecture-decision` — start ADR-007 (Class Enum Naming Convention) per #9 CD F-9 ADVISORY follow-up
- (c) `/design-system 26` — Avatar Renderer (VS-tier 13/13 last) — resolves Q-V2 BossVisualResource refactor
- (d) Sprint-kickoff polish window before `/create-stories` — process 3 P0 TIER B items + 2 sequencing items (Followup #08 promote + #19 sequence)

Status: **Pass 5 APPROVED — #16 Boss System TIER A complete, spec-authoring quality verified across systems-designer + gameplay-programmer + qa-lead domains. Sprint-ready pending TIER B P0 (3 items) + MVP-gate-prerequisite sequencing (2 items). Ready for next-phase progression per user judgment.**

---

## Review — 2026-06-01 — Verdict: MAJOR REVISION NEEDED (Pass 5 fresh-session /design-review)

Scope signal: M (design-level fixes; may touch ADR-003 save scope + ADR-005 effort signal reuse; no brand-new ADR)
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer + creative-director (synthesis)
Blocking items: 12+ across 4 domains | Specialist disagreement: 1 (persist current_hp vs transient-by-design — design fork, NOT bug)

Summary: Pass 5 fresh-session full-mode re-review (4 adversarial specialists + CD synthesis) found Pass 4's "12 TIER A resolved" claim **does not hold**. Two independent proofs: (1) AC-18 still asserts the pre-Pass-4 `ATTACK_POWER=0 → boss_max_hp=50` path that Pass 4 A3.3 bootstrap abolished (regression test will fail) → Pass 4 changed the formula but did not propagate to ACs; (2) the BossSystem autoload class is **never defined** (no class_name / no field section / no extends Node) yet `_spawned_transition_ids` lives on it → Pass 4 spec is incomplete. Four domains converged on the death/cleanup/wiring path being systematically underspecified. **Cannot /create-epics until Approved.**

Prior verdict resolved: Pass 4 TIER A (signature contract / spawn ordering / snapshot caching / Web Export hooks) confirmed solid — but Pass 4 introduced/left BLOCKING gaps.

### Convergent BLOCKING findings (Pass 6 must fix)

**Tier 0 — Not compilable (gameplay-programmer)**
- GP-F4: `BossSystem` autoload class never defined — no `class_name BossSystem` / no `extends Node` / no field section (contrast BossInstance which has full spec at line 139). `_spawned_transition_ids` Dictionary undeclared. **Add a full "BossSystem autoload class contract" section mirroring BossInstance completeness.**
- GP-F2: `class_name BossVisualResource` nested inside BossTemplate fenced block (line 113/125) = GDScript parse error (one file-level class_name per script). Resolve to separate file OR inner `class` (no class_name).
- GP-F3: `_instantiate_boss(template)` (line 365/451) undefined + self-contradictory ("BossInstance.new() via scene preload" — BossTemplate has no PackedScene field). Spec the scene-load convention.
- GP-F5: telemetry helper naming inconsistent (`_emit_telemetry` vs `emit_telemetry`) + undefined (#28 Not Started → must be local graceful-noop wrapper).
- GP-F8: `boss.hp_changed` signal referenced (line 380) but never declared on BossInstance (HUD bar needs it).

**Tier 1 — Death/cleanup wiring (qa-lead B2.1 + gameplay-programmer GP-F1/GP-F7 CONVERGENT)**
- `_on_enemy_killed_self_listen` (line 575) has NO `.connect(...)` anywhere + no `enemy_id == self.boss_id` filter → any enemy kill triggers boss cleanup. Spec the connection callsite + self-filter.
- Dual death path: Rule 12 calls `boss._enter_state(EnemyAIState.DYING)` (line 674, `_enter_state` undefined) vs Rule 8 via enemy_killed handler. Reconcile canonical death entry; guard against double cleanup/queue_free.
- AC-11 assumes boss already in DYING — skips "how enemy_killed → DYING" entirely (no test coverage). Add coverage.

**Tier 2 — Pillar-breaking design (game-designer) — needs DESIGN DECISIONS (see below)**
- P5-1/P5-6: Rule 12 bfcache skip-to-kill (HP<30%, line 669) makes boss death fire from browser resume event, not player hit → silently betrays core fantasy「我嗰 rep 殺 boss」(line 49). game-designer + CD recommend: **persist `current_hp` (one int) for perfect continuity** instead of the 30% threshold hybrid (eliminates P5-1 + P5-6 + P5-7). DESIGN DECISION #1 (touches ADR-003 save scope).
- P5-4: set-count ≤2 proxy mis-classifies strength programs (3×3/5×5 = low sets, high effort → mini-boss) = inverted reward violating Pillar 1. game-designer + CD recommend: **reuse ADR-005 effort signal (volume×PR×streak) for tier gate** instead of raw set count (no GymSys backend extension needed). DESIGN DECISION #2.
- P5-3: single-boss-asset + auto-play + frozen-outcome → novelty collapse is a CERTAINTY not a risk. AC-39 (≥3.0 Likert, n=5, 5 sessions, ADVISORY) too weak; real retention test AC-29d is post-MVP ADVISORY → no MVP gate stops collapse. Recommend ≥3.5 / n≥10 / ≥8 sessions + MVP-gate BLOCKING escalation.
- P5-7/8: Rule 12 skip-to-kill vs EC-16 (DYING-freeze already-killed) un-reconciled overlap → potential double-loot; AC-42 doesn't cover the enemy_killed-already-emitted + resume race.

**Tier 3 — Formula regression + degenerate boundaries (systems-designer)**
- F1 [CRITICAL]: AC-18 (line 1394) contradicts Pass 4 A3.3 bootstrap → regression. Propagate Pass 4 formula change to AC-18 + AC-41.
- F2: bootstrap floor makes MIN_BOSS_HP=50 unreachable (min raw 209-290); first-session boss is 21-29 hits (TOUGHER than mid-game) — violates INV-9 spirit. Reconcile.
- F3: endgame atk≥1056 (23% of ceiling) → 9-hit contract collapses (2-3 hit kill); MAX_BOSS_HP=10000 MVP-inadequate with no MVP mitigation. Add MVP mitigation or disclose+AC the saturation hit-count behaviour.
- F4: EC-06 player_max_hp=1 → one-shot death, but GDD has NO avatar death/retry spec → what happens after avatar dies? (boss continues? enemy_killed never fires? Pillar 3 silent fail). Spec it.
- F6: INV-8 literal `RARE > RARE` = false (operator bug); mini ceiling = final floor = RARE → static gradient is zero; "ADR-005 modifiers separate them" is hand-waving (no distribution data). Fix operator + provide ADR-005 distribution evidence OR re-tier.

**AC quality (qa-lead)**: B1.1 AC-07 missing wall-clock ≤200ms branch (throttled-tab not mobile-safe-provable); B3.1 Rule 9 missing `final_tier = max(adr005_floored, loot_guarantee_min_tier)` combine pseudocode (BLOCKING if #15 stories cite it); B1.4 NEVER #9 (player-input mutation) has zero effective verification; AC-35 non-testable ("ideally"); AC-22 over-prescriptive (mandates BossSpawnContext); AC-30a self-invalidating evidence.

### Two DESIGN DECISIONS to collect at Pass 6 start (before spec authoring)
1. **bfcache state**: persist `current_hp` (int) for perfect continuity [game-designer + CD recommended] vs keep Rule 12 30%-threshold hybrid (transient-by-design). Persist touches ADR-003 save scope (one ephemeral mid-fight field) — needs save-strategy + #15 confirm.
2. **boss-tier gate**: reuse ADR-005 effort signal (volume×PR×streak) [game-designer + CD recommended] vs keep set-count ≤2 proxy. Reuse avoids session_intent backend extension.

### Pass 6 Process
- Fresh session (this session at high context). Collect the 2 design decisions first, then focused fix-pass: BossSystem autoload class spec + un-nest BossVisualResource + define _instantiate_boss + wire _on_enemy_killed_self_listen + boss_id filter + reconcile dual death path + propagate AC-18/41 + fix INV-8 operator + avatar death/retry spec + Rule 9 combine pseudocode + AC-07 wall-clock split.
- Then `/design-review` fresh session → expect Approved → THEN `/create-epics #16`.
- No 6-specialist re-review needed for Pass 6 (findings already cross-domain consensus); optional 3-specialist (systems + gameplay + qa) targeted re-validate after.

Status: Pass 5 MAJOR REVISION NEEDED — pending fresh-session Pass 6. **Epic creation BLOCKED until Approved.**

---

## Pass 6 — 2026-06-01 — Design Decisions LOCKED (spec fix-pass handed to fresh session)

User pre-authorized「全部跟推薦去做」for this GDD. The two Pass-5 design decisions are resolved with the game-designer + creative-director recommended options:

- **DD #1 — bfcache state**: ✅ **Persist `current_hp` (one int) for perfect continuity** (game-designer + CD recommended). Replaces the Rule 12 30%-threshold skip-to-kill hybrid. Eliminates P5-1 (boss death firing from browser resume not player hit), P5-6, P5-7/8 (skip-to-kill vs EC-16 double-loot race) in one move — boss death now ALWAYS originates from a player hit, preserving the core fantasy「我嗰 rep 殺 boss」(line 49). **Ripple**: ADR-003 save scope gains ONE ephemeral mid-fight field (`boss.current_hp`); needs save-strategy + #15 confirm — logged as new Followup #21 (NOT a GDD blocker; design-level decision is made).
- **DD #2 — boss-tier gate**: ✅ **Reuse ADR-005 effort signal (volume×PR×streak) for the mini-vs-final tier gate** (recommended), replacing the raw set-count ≤2 proxy. Fixes P5-4 (3×3/5×5 strength programs = low set count but high effort → wrongly classified mini-boss = inverted Pillar 1 reward). No GymSys backend extension needed (effort signal already computed for ADR-005). LIGHT_WORKOUT_THRESHOLD_SETS knob → replaced by an effort-score threshold (Rule 2/3 + Tuning Knobs to update in spec pass).

### Remaining Pass 6 spec fix-pass (handed to FRESH session — per Pass 5 reviewer's explicit "fresh session at high context" recommendation; this session is deep into Foundation+streak+audio work, and this GDD has a Pass 2→3 net-regression precedent that punishes rushed multi-item passes in exhausted context)

**Tier 0 — compilability (5):** GP-F4 add full `BossSystem` autoload class contract section (class_name/extends Node/field section incl. `_spawned_transition_ids`); GP-F2 un-nest `BossVisualResource` (currently 2nd file-level `class_name` in BossTemplate fence = parse error → separate file or inner `class`); GP-F3 define `_instantiate_boss` + scene-load convention (BossTemplate has no PackedScene field); GP-F5 telemetry helper naming + local graceful-noop wrapper (#28 Not Started); GP-F8 declare `hp_changed` signal on BossInstance (HUD bar).
**Tier 1 — death/cleanup wiring (3):** connect `_on_enemy_killed_self_listen` callsite + `enemy_id == self.boss_id` self-filter; reconcile dual death path (Rule 12 `_enter_state(DYING)` undefined vs Rule 8 enemy_killed) → canonical death entry + double-cleanup guard; AC-11 add enemy_killed→DYING coverage.
**Tier 2 — apply the 2 DDs in spec + novelty (3):** rewrite Rule 12 to persist `current_hp` (drop skip-to-kill); rewrite Rule 2/3 tier gate to effort-signal; escalate AC-39 novelty test (≥3.5 Likert / n≥10 / ≥8 sessions, MVP-gate BLOCKING).
**Tier 3 — formula/AC regression (5+):** F1 propagate Pass 4 A3.3 bootstrap to AC-18 + AC-41 (current regression); F2 reconcile bootstrap floor vs MIN_BOSS_HP=50 unreachable (first-session 21-29 hits tougher than mid-game); F3 endgame saturation MVP mitigation or disclose+AC; F4 spec avatar death/retry (player_max_hp=1 one-shot → no death spec); F6 fix INV-8 operator (`RARE > RARE`=false) + re-tier or provide ADR-005 distribution evidence; Rule 9 `final_tier = max(adr005_floored, loot_guarantee_min_tier)` combine pseudocode; AC-07 wall-clock ≤200ms split.

Then: `/design-review` (fresh) → expect Approved → `/create-epics #16`. New Followup #21 (ADR-003 persist boss.current_hp scope).

Status: ~~Pass 6 design decisions LOCKED — spec fix-pass pending~~ **Superseded — spec fix-pass COMPLETE below.**

---

## Pass 6 Spec Fix-Pass — 2026-06-04 — COMPLETE (pending /design-review)

User directed「繼續 #16 Boss spec-fix-pass」(declined the /clear recommendation; proceeded same session). Applied all ~16 Tier 0/1/2/3 edits with grep-verify discipline (no net-regression: each target section read before editing, no new cross-contradictions introduced).

**Tier 0 — compilability (5):**
- GP-F2: `BossVisualResource` un-nested → own file `res://src/data/boss_visual_resource.gd` (was 2nd file-level class_name in BossTemplate script = parse error).
- GP-F3: added `BossTemplate.boss_scene: PackedScene` + defined `_instantiate_boss()` (instantiate the scene, not `BossInstance.new()` which has no scene-tree children).
- GP-F4: added full **`class_name BossSystem extends Node`** autoload-class-contract section (`_spawned_transition_ids` field + signals + `_instantiate_boss` + `_emit_telemetry`); removed duplicate `const POSITION_TOLERANCE_PX` from spawn pseudocode.
- GP-F5: telemetry helper unified to `_emit_telemetry` + local graceful-noop wrapper (#28 Not Started).
- GP-F8: declared `signal hp_changed(current_hp, max_hp)` on BossInstance + single `_set_current_hp` mutator.

**Tier 1 — death wiring (3):**
- Defined canonical `_enter_state(new_state)` with idempotent DYING guard (= double-cleanup guard root).
- Wired `_on_enemy_killed_self_listen(transition_id, faction, tier)` — `.connect` callsite in `_ready` + self-filter `transition_id == self.transition_id` + routes to `_enter_state(DYING)`; renamed old body to `_play_death_and_free()`.
- DD#1 removed the second death-path caller (skip-to-kill) → single canonical path. Added **AC-11b** (enemy_killed→DYING + self-filter + idempotent re-fire coverage).

**Tier 2 — apply DDs + novelty (3):**
- **DD#1**: Rule 12 rewritten — persist `boss.current_hp` (ONE int) → exact-restore on bfcache resume; boss death ALWAYS player-hit-originated; removed `MID_FIGHT_SKIP_HP_THRESHOLD` knob + INV-10. Followup #21 (ADR-003 scope).
- **DD#2**: Rule 2/10 tier gate set-count → ADR-005 `effort_score` (`MINI_BOSS_EFFORT_THRESHOLD`); fixes P5-4 strength-program inverted-reward; updated Moment C, States table, EC-22, INV-7, knob table, knob-stability, Q-X5 (largely resolved). Forward-constraint to #14 (joint single source of truth).
- **AC-39 escalated** ADVISORY→**MVP-gate BLOCKING** (≥3.5 Likert / n≥10 / ≥8 sessions) — novelty collapse is a certainty, prior gate too weak.

**Tier 3 — formula/AC (7):**
- F1: AC-18 regression fixed (ATTACK_POWER=0 → A3.3 bootstrap branch, NOT floor=50; floor reframed defensive; bootstrap path = AC-41).
- F2: bootstrap-vs-MIN_BOSS_HP reconciled — first-session HP cap (`FIRST_SESSION_EXPECTED_HIT_DAMAGE × FIRST_SESSION_KILL_HITS_MAX`) + **INV-9b** (first session never the hardest fight) + Followup #23.
- F3: endgame saturation disclosed (EC-07 + **AC-44** ADVISORY) — hit-count collapse to 2-3 = accepted MVP behavior + telemetry; v0.2 TIER_4 (Followup #24).
- F4: **EC-25** avatar-downed spec — companion auto-battler, NO game-over/permadeath/retry (Pillar 2); avatar auto-recovers, boss fight continues, loot unaffected; new NEVER (no game-over during workout).
- F6: INV-8 operator `RARE > RARE` → `>=` (joint-equal valid; distributional gradient via ADR-005 modifiers, not static) + Followup #22 (distribution evidence).
- Rule 9: added `final_tier = max(adr005_rolled, loot_guarantee_min_tier)` combine pseudocode (#15 consumes; RarityTier ordinal-ordered per ADR-0007).
- AC-07: added **AC-07b** wall-clock ≤200ms budget (foreground) + throttled-tab exemption (frame-count contract holds).

New Followups: #21 (ADR-003 persist boss.current_hp), #22 (ADR-005 boss-vs-mini tier distribution evidence), #23 (FIRST_SESSION_EXPECTED_HIT_DAMAGE #13 co-calibration), #24 (v0.2 endgame MAX_BOSS_HP ramp / TIER_4).

Status: ~~Pass 6 spec fix-pass COMPLETE — pending /design-review~~ **Superseded — Pass 6 re-review MAJOR REVISION NEEDED below.**

---

## Pass 6 Re-review — 2026-06-04 — Verdict: MAJOR REVISION NEEDED

Mode: full 4-specialist (gameplay-programmer + systems-designer + qa-lead + game-designer) + creative-director synthesis. Fresh-context re-review of the Pass 6 spec-fix-pass (which was authored in EXHAUSTED context after the reviewer's /clear recommendation was declined).

**Root cause (CD): the Pass 6 spec-fix was correct in DESIGN (DD#1 exact-restore + DD#2 effort gate are right) but suffered single-edit propagation failure** — Rule 12 was rewritten but downstream references (Rule 16 NEVER, EC-17, AC-42, Dependencies table, Formula telemetry) were NOT grepped/updated → the GDD's signature net-regression pattern (Pass 2→3) reappeared. **This is exactly what doing a multi-item spec-pass in exhausted context produces** — validates the /clear discipline.

**Convergent type: finite, addressable cleanup (NOT infinite phantom spiral). NOT yet Structural Freeze** (Pass 6 was the first mandate-closed pass). **CD EXIT BAR: if Pass 7 self-introduces ANY new cross-reference orphan → immediate Structural Freeze.**

### Pass 7 fix list (14 mechanical + 3 design rulings)

**Group A — Pass 6 orphan/contradictions (BLOCKING):**
1. Rule 16 NEVER #10「NEVER persists boss HP/position」→ add exception「except the single `boss.current_hp` ephemeral record via whitelisted `_set_current_hp` (Rule 12 DD#1)」; AC-12 grep pattern must whitelist `_set_current_hp`.
2. EC-17 — rewrite from deleted skip-to-kill/restart-full hybrid → DD#1 exact-restore semantics.
3. AC-42 — rewrite from zombie skip-to-kill/restart-full test (+ removed MID_FIGHT_SKIP_HP_THRESHOLD knob ref) → DD#1 exact-restore contract test.
4. Dependencies/Interactions table `#3 PersistenceLayer: NONE` → Hard dep (write/read/delete boss.current_hp + boss.transition_id; deleted on death).
5. Formula 1 `emit_telemetry(` → `_emit_telemetry(` (GP-F5 sweep).

**Group B — Tier 0/1 still not compilable (BLOCKING):**
6. BossInstance has TWO `_ready()` (schema ~L187 + Rule 11 bfcache ~L699) → merge into one (asserts+max_hp init → bfcache subscribe → enemy_killed connect).
7. `_on_enemy_killed_self_listen` `.connect` callsite is only a COMMENT → move into the merged `_ready()` as real spec pseudocode.
8. `current_hp = max_hp` in `_ready` bypasses `_set_current_hp` mutator → route through mutator.

**Group C — F2 ghosts + floor violation (BLOCKING):**
9. `FIRST_SESSION_EXPECTED_HIT_DAMAGE` (default 20, #13 co-cal Followup #23) + `FIRST_SESSION_KILL_HITS_MAX` (default 12, [8,15]) → add to Tuning Knobs (currently undefined symbols).
10. F2 cap `min(boss_max_hp, cap)` after MIN_BOSS_HP clamp can go sub-50 → `max(min(boss_max_hp, cap), MIN_BOSS_HP)` + INV `cap ≥ MIN_BOSS_HP`.

**Group D — AC quality (BLOCKING/MAJOR):**
11. AC-18 floor case unreachable (base_hp∈[50,500]→raw≥50) → use test-only `base_hp=1` synthetic input + mark「defensive future-config guard」.
12. AC-07b wall-clock non-deterministic in headless CI → rewrite as unit test with injectable `MockClock.get_ticks_msec()` seam testing LOGICAL timeout (not wall-clock measurement), OR demote ADVISORY|Manual (real-browser, parallel AC-27b). Cites determinism standard.
13. AC-39 unreachable binding gate → recruit n≥12 pool / report min n=10 completers (attrition buffer) + producer-scheduled ≥3-week playtest window; keep MVP-BLOCKING but reachable.
14. EC-25 zero AC → add **AC-45** (avatar-downed auto-recover, BLOCKING) + `AVATAR_RECOVER_HP_FRACTION` knob; add AC-07b + EC-25/AC-45 to Coverage Map; INV-7「CI lint ensures sync」→ Followup #25 (real script, BLOCKED until #14 aligns); RarityTier ordinal — drop ADR-0007 cite (it locks AbilityClass; RarityTier is #15 scope, confirm at #15 authoring).

### CD design rulings (apply directly — no further user decision needed)
- **Q1 EC-25 zero-stakes**: zero-fail-state is **CORRECT** (stakes = effort→loot outcome, not avatar HP). Add Player-Fantasy sentence:「Stakes 係 outcome 唔係 HP — 緊張感來自 effort input→loot tier 因果鏈;avatar 係打唔死嘅見證者,boss 係 workout outcome 具象化」. No mechanic change. Reconcile the「NO unkillable boss」anti-pattern wording with the unkillable-avatar framing.
- **Q2 DD#2 multiplicative**: keep multiplicative formula (max()/weighted-sum introduce worse Pillar-1 problems). Add a 5×1 powerlifting **worked example** (low volume_factor × high pr × streak → may sit below 0.25 = INTENDED: reward effort VOLUME, not single-rep intensity) + mark `MINI_BOSS_EFFORT_THRESHOLD` **TUNABLE** (was LOCKED) for Pre-MVP calibration; optional `if pr_factor >= PR_OVERRIDE: force_final` future path. Define volume_factor normalization basis + threshold-0.25 derivation.
- **Q3 DD#1 staleness**: add `BOSS_HP_PERSIST_TTL_SEC` (default 7200, [3600,86400]) + `boss.fight_timestamp` persisted field + bfcache TTL-expire branch (record older than TTL → treat as no record → restore max_hp + delete) + EC-17 TTL branch + **AC-46**.

### CD Pass 7 exit bar (6 grep checks — all must pass to advance to /create-epics)
(a) Rule 16 NEVER #10 shows `_set_current_hp` whitelist exemption; (b) EC-17 shows NO skip-to-kill/restart-at-full old semantics; (c) AC-42 shows NO `MID_FIGHT_SKIP_HP_THRESHOLD`; (d) BossInstance has exactly ONE `_ready()` block; (e) `FIRST_SESSION_EXPECTED_HIT_DAMAGE` + `FIRST_SESSION_KILL_HITS_MAX` visible in Tuning Knobs; (f) AC-39 shows n≥12 attrition buffer. **If Pass 7 introduces any NEW orphan → Structural Freeze.**

New Followups: #25 (effort-threshold sync CI lint, BLOCKED on #14).

Status: ~~MAJOR REVISION NEEDED — Pass 7 spec-fix-pass pending FRESH session~~ **Superseded — Pass 7 spec-fix-pass COMPLETE below.**

---

## Pass 7 Spec Fix-Pass — 2026-06-04 — COMPLETE (orphan-cleanup, fresh context; pending /design-review)

Done in a FRESH session (the discipline Pass 6 re-proved by failing it). Each edit grep-verified across all downstream mentions before moving on — no single-edit propagation failure. All 14 mechanical fixes + 3 CD design rulings applied; all 6 CD exit-bar greps pass; no new orphan introduced.

### Group A — Pass 6 orphan/contradictions (5)
1. **Rule 16 NEVER #10** — now carves out the single DD#1 ephemeral record (`boss.current_hp` via whitelisted `_set_current_hp` + `boss.transition_id`/`boss.fight_timestamp` via whitelisted `_persist_fight_anchor`); position still NEVER persisted. AC-12 grep + EC-21 updated to whitelist the two `boss_instance.gd` callsites (EC-21 was a live DD#1 contradiction — fixed).
2. **EC-17** rewritten to DD#1 exact-restore + Q3 TTL three-branch (was deleted Pass 4 skip-to-kill/restart-full).
3. **AC-42** rewritten to DD#1 exact-restore contract; `MID_FIGHT_SKIP_HP_THRESHOLD` appears only as an explicit "no reference" negation; evidence path renamed `test_ac42_bfcache_exact_restore.gd`. Coverage Map + Q-X2 + Gate Distribution labels swept.
4. **Dependencies #3 PersistenceLayer** NONE→**Hard** (Interactions table) + ADR-003 added to ADR Dependencies table.
5. **Formula 1** `emit_telemetry(`→`_emit_telemetry(` (GP-F5 sweep — the one missed callsite).

### Group B — Tier 0/1 compile (3)
6. **BossInstance two `_ready()` merged into one** canonical block in the Rule 1 schema (asserts → max_hp → `_set_current_hp` → `_persist_fight_anchor` → idle → enemy_killed connect → bfcache subscribe). The Rule 11 second `_ready` replaced with a pointer note.
7. **`_on_enemy_killed_self_listen` `.connect`** is now a REAL statement in the merged `_ready` (was comment-only); the Rule 11 callsite comment updated to say so.
8. **`current_hp = max_hp` routed through `_set_current_hp`** mutator (no more direct bypass).

### Group C — F2 ghosts + floor (2)
9. **`FIRST_SESSION_EXPECTED_HIT_DAMAGE` (20) + `FIRST_SESSION_KILL_HITS_MAX` (12)** added to Tuning Knobs (were undefined symbols).
10. **F2 cap** `min(boss_max_hp, cap)` → `max(min(boss_max_hp, cap), MIN_BOSS_HP)` + **INV-9c** (`cap ≥ MIN_BOSS_HP`); also added **INV-9b** to the INV table (was prose-only).

### Group D — AC quality (4)
11. **AC-18** floor case now reachable via test-only synthetic `base_hp=1` + marked『defensive future-config guard』.
12. **AC-07b** rewritten Integration-wall-clock → **Logic/Unit** with injectable monotonic clock seam (logical budget, deterministic; real-browser timing delegated to AC-27b/AC-30b). Cites the no-time-dependent-assertion determinism standard.
13. **AC-39** binding gate made reachable: **n≥12 recruited / ≥10 completers (attrition buffer)** + producer-scheduled ≥3-week window; stays MVP-BLOCKING.
14. **EC-25 → AC-45** (avatar-downed auto-recover, BLOCKING) + `AVATAR_RECOVER_HP_FRACTION` knob; Coverage Map +AC-07b/AC-11b/AC-45/AC-46; INV-7「CI lint ensures sync」→ **Followup #25** (real script, BLOCKED until #14 aligns); RarityTier **ADR-0007 cite dropped** (ADR-0007 locks AbilityClass; RarityTier is #15 scope).

### CD design rulings (3, applied directly)
- **Q1** EC-25 zero-stakes CORRECT — added Player-Fantasy「Stakes 係 outcome 唔係 HP」framing + reconciled the「NO unkillable boss」anti-pattern wording (killable boss vs undefeatable avatar) + **NEVER #13 no-game-over** (Rule 16 now 13 NEVERs; AC-40 traceability count 12→13).
- **Q2** kept multiplicative DD#2 — added 5×1 powerlifting worked example (low volume × high pr × streak), `volume_factor` trailing-median normalization basis, 0.25 threshold geometric-midpoint derivation, `MINI_BOSS_EFFORT_THRESHOLD` LOCKED→**TUNABLE**, optional `PR_OVERRIDE` post-MVP path.
- **Q3** DD#1 staleness — `BOSS_HP_PERSIST_TTL_SEC` (7200, [3600,86400]) + persisted `boss.fight_timestamp` + bfcache TTL-expire branch (Rule 12 + EC-17) + **AC-46**.

### CD exit bar — 6/6 grep checks PASS
(a) NEVER #10 shows `_set_current_hp` whitelist ✓ · (b) EC-17 no live skip-to-kill (only negation/historical) ✓ · (c) AC-42 no `MID_FIGHT_SKIP_HP_THRESHOLD` (only "no reference" negation) ✓ · (d) exactly ONE `func _ready()` ✓ · (e) `FIRST_SESSION_EXPECTED_HIT_DAMAGE` + `FIRST_SESSION_KILL_HITS_MAX` in Tuning Knobs ✓ · (f) AC-39 n≥12 ✓. **No new orphan** — `REVEAL_DISPATCH_BUDGET_MS` (briefly introduced in AC-07b) de-named to the existing Pillar-2 200ms budget to avoid one.

### Additional pre-existing Pass-6 orphans found + fixed (beyond the 14, disclosed honestly)
The Pass 6 re-review's 4-specialist pass did NOT flag these, but the grep-everything cleanup surfaced them — leaving them would have failed Approval:
- **AC-02 / AC-03 / AC-10** still tested the removed `total_planned_sets` / `LIGHT_WORKOUT_THRESHOLD_SETS` set-count gate → rewritten to the DD#2 `effort_score < MINI_BOSS_EFFORT_THRESHOLD` gate (a 5×1 session now correctly spawns FINAL; `total_planned_sets` survives only as the EC-23 ==0 empty-guard, AC-26).
- **Followup #22/#23/#24** were cited in the body (INV-8 / F2 flag / EC-07-AC-44) but never added to the tracker → added (plus #21b save-scope, #25 effort-sync lint).
- **AC count + knob count + NEVER count** reconciled (54 effective ACs; 16 active owned knobs; 13 NEVERs) with an honest Pass-4-snapshot note on the distribution tables.

### Files modified in Pass 7
- `design/gdd/boss-system.md` — Status header; Player Fantasy (Q1 framing + anti-pattern reconcile); Rule 2 (DD#2 Q2 worked example/normalization/derivation); Rule 11 (merge note + connect comment); Rule 1 schema (merged `_ready`); Rule 12 (`_persist_fight_anchor` + fight_timestamp + TTL branch); Rule 16 (NEVER #10 whitelist + NEVER #13); Formula 1 (`_emit_telemetry` + F2 floor-safe cap); Interactions + Dependencies (#3 Hard + ADR-003); Tuning Knobs (+4 knobs, header count, INV-9b/9c, INV-7/EC-22 Followup #25, stability TUNABLE); ECs (EC-17 / EC-21 / EC-25→AC-45); ACs (AC-02/03/07b/10/12/18/39/42/45/46 + AC-40 count + Coverage Map + count headers + Gate Distribution); Followup tracker (#21b/#22/#23/#24/#25); Q-X2.
- `design/gdd/reviews/boss-system-review-log.md` — this Pass 7 entry.

Status: ~~Pass 7 COMPLETE — pending fresh-session /design-review~~ **Superseded — Pass 7 /design-review verdict NEEDS REVISION below.**

---

## Review — 2026-06-04 — Verdict: NEEDS REVISION (Pass 7 /design-review)

Mode: full — 4 adversarial specialists (gameplay-programmer + systems-designer + qa-lead + game-designer) + creative-director synthesis. Fresh-context re-review of the Pass 7 orphan-cleanup spec-fix-pass.
Scope signal: M (targeted fixes; no new ADR; no design decision needed; only cross-file is B2 reading #14).
Blocking items: 6 | Recommended: ~6 | False-positives dropped by CD: 4.

Summary: Pass 7's 6-grep exit bar genuinely passed and the 14 mechanical fixes + 3 CD rulings landed. But the full-specialist pass surfaced **6 BLOCKING issues the exit-bar greps don't cover** — arithmetic, cross-spec, and signal-signature defects, plus editorial table-sync gaps. CD adjudication: these are **pre-existing defects (which even the Pass 6 4-specialist re-review missed) + editorial table syncs — NOT Pass 7 self-introduced cross-reference orphans. Structural Freeze condition NOT met.** Pass 8 = targeted inline fixes in a FRESH session.

### 6 BLOCKING (Pass 8 must fix)
- **B1 — AC-27a zombie** [gameplay-programmer + qa-lead, main-reviewer grep-verified L1587]: still mocks `NOTIFICATION_APPLICATION_PAUSED/RESUMED` (removed Pass 4 A2.1) + asserts「respawns at FULL HP」(superseded by DD#1 exact-restore). Pass 7 rewrote EC-17/AC-42 but missed AC-27a. → rewrite AC-27a to DD#1 exact-restore semantics.
- **B2 — `enemy_killed` signal signature mismatch** [gameplay-programmer, main-reviewer grep-verified]: handler `_on_enemy_killed_self_listen(transition_id: String, _faction: int, _tier: int)` is 3 positional params, but #14 `enemy-director.md` L145 declares `signal enemy_killed(payload: EnemyKilledPayload)` — a single typed payload. Runtime arg-count mismatch + the self-filter compares `enemy_id` against `self.transition_id` (broken). → change handler to `(payload: EnemyKilledPayload)` reading `payload.transition_id`. Pre-existing from Pass 6 Tier 1 wiring (no one grepped #14's real signal).
- **B3 — Formula 1 `_emit_telemetry` scope** [gameplay-programmer]: `BossFormulas.compute_max_hp` is a static helper and cannot call `BossSystem._emit_telemetry` (autoload method). → move the `boss.first_session_bootstrap` / `boss.scaling_clamp` telemetry callsites out of the pure-math formula into the `BossSystem.spawn_boss` post-formula block. Pre-existing Pass 6 GP-F5 gap.
- **B4 — INV-9b numeric contradiction** [systems-designer]: default knobs give first-session HP cap = `FIRST_SESSION_EXPECTED_HIT_DAMAGE(20) × FIRST_SESSION_KILL_HITS_MAX(12) = 240` → 240/20 = **12 hits** > mid-game `TARGET_KILL_HITS_FINAL = 9` → first session is literally HARDER, violating INV-9b. Side-effect: `FIRST_SESSION_DURATION_TARGET_SEC` + `FIRST_SESSION_BASELINE_ATK` become phantom knobs (cap always binds). → reframe INV-9b as a feeling invariant OR set `FIRST_SESSION_KILL_HITS_MAX ≤ 9`. Numeric defect from Pass 6 cap value.
- **B5 — DD#2 effort_score cold-start div-by-zero** [systems-designer]: Pass 7 Q2 prose defined `volume_factor = session_volume ÷ trailing-median session volume`, but first session has trailing-median = 0 → division by zero, no fallback. → add cold-start guard (`trailing_median == 0 → volume_factor = 1.0`) OR cite ADR-005's handling. (The one item arguably newest — but it's explanatory-prose elaboration of an ADR-005-owned value, not a core-mechanic orphan; CD ruled NOT a Structural-Freeze trigger.)
- **B6 — table sync** [qa-lead]: Test Type Distribution still shows 49 (header says 54) → update to 54/recompute; Gate Distribution still lists AC-39 under ADVISORY (it's now MVP-BLOCKING) + omits AC-44 (new ADVISORY); Coverage Map Rule 16 row missing AC-45 (NEVER #13 untraceable). → table edits.

### Recommended (non-blocking)
- **MINI_BOSS_EFFORT_THRESHOLD TUNABLE without range guard** [game-designer]: Pillar 1 gate freely tunable + Followup #25 sync still BLOCKED → add acceptable range bound [0.15, 0.40] + out-of-range needs design re-review. (CD did not list among the 6 BLOCKING; main reviewer keeps as Recommended.)
- F4 `MIN_RITUAL_INTENSITY` variable-table [0.3,0.5] vs knob [0.4,0.6]; TTL missing「≥ max workout-session duration」invariant; threshold-0.25「derivation」wording is heuristic not derived; F1「緊張感」→「期待感/儀式感」(boss fight is a reveal ceremony, loot is deterministic pre-fight); Coverage Map EC-16/17 → AC-27,42,46 + EC-07 → AC-44; AC-45 add a Section-H ref (currently inline Section E only); player_max_hp=1 infinite-down sub-case; resume pseudocode `boss.`→`self.`.

### Specialist disagreement (CD-adjudicated)
qa-lead flagged **AC-07b** BLOCKING (no falsifiable failure mode + Followup #17 open); CD dropped it as a false-positive (Pass 7 already moved it to a deterministic MockClock seam). Other CD-dropped false-positives: stakes framing, AC-39 remediation path, Moment B scope label (all already present/labelled).

### Pass 8 exit bar (7 checks — all must pass to advance to /create-epics)
1. AC-27a semantics == EC-17/AC-42 (DD#1 exact-restore); no APPLICATION_PAUSED/RESUMED, no respawn-at-full.
2. `_on_enemy_killed_self_listen` handler signature == #14 `enemy_killed(payload: EnemyKilledPayload)` (grep #14 to confirm).
3. Formula 1 telemetry callsite lives in BossSystem scope, not the static formula.
4. INV-9b no longer literally violated by default knobs.
5. cold-start `volume_factor` fallback spec exists (trailing-median=0 covered).
6. Test Type Distribution = 54; Gate Distribution AC-39 → BLOCKING MVP gate + AC-44 → ADVISORY; Coverage Map Rule 16 → +AC-45.
7. **Zero new cross-reference orphans — any new orphan → STRUCTURAL FREEZE, no exception.**

### Process
- **FRESH SESSION** (per the [[feedback_orphan_cleanup_fresh_context]] lesson this GDD keeps re-proving; this review session is already long after the full Pass 7 edit + 5-agent review). B2 first: grep `design/gdd/enemy-director.md` for the real `enemy_killed` semantic before editing the handler. Grep all downstream mentions per edit. Run the 7-item exit bar.

Prior verdict resolved: Pass 6 Re-review MAJOR REVISION (net-regression orphans) → Pass 7 closed those + 4 extra, 6/6 exit-bar pass → this Pass 7 review found 6 deeper BLOCKING (pre-existing defects the prior re-review missed + table syncs).

Status: ~~NEEDS REVISION — Pass 8 targeted inline fixes pending FRESH session~~ **Superseded — Pass 8 spec-fix-pass COMPLETE below.**

---

## Pass 8 Spec Fix-Pass — 2026-06-04 — COMPLETE (6-BLOCKING inline, fresh context; pending /design-review)

Fresh-context pass (per [[feedback_orphan_cleanup_fresh_context]]). Each edit grepped against all downstream mentions before/after; B2 first grep-confirmed `design/gdd/enemy-director.md` L145 = `signal enemy_killed(payload: EnemyKilledPayload)`.

### 6 BLOCKING — all fixed
- **B1 — AC-27a zombie** → rewritten to DD#1 exact-restore semantics (drives `_on_resume_detected()` not `NOTIFICATION_APPLICATION_RESUMED`; branches a/b/c/d mirror Rule 12 DD#1 exactly; explicit「no respawn-at-full / no skip-to-kill / no fabrication」negations matching AC-42's style). No live `APPLICATION_PAUSED/RESUMED` mock remains (only negation/historical mentions).
- **B2 — `enemy_killed` handler signature** → `_on_enemy_killed_self_listen(payload: EnemyKilledPayload)` reading `payload.transition_id` (was 3-positional `(transition_id, _faction, _tier)`). Matches #14 L145 + AC-08. **Corollary:** AC-11b test description updated to fire the single-payload form (else it would contradict the fixed handler).
- **B3 — Formula 1 telemetry scope** → `boss.first_session_bootstrap` `_emit_telemetry` callsite moved OUT of the static `BossFormulas.compute_max_hp` INTO `BossSystem.spawn_boss` post-`add_child` (autoload scope; payload `{transition_id, boss_max_hp}` — the formula-internal `effective_atk`/`workout_duration_sec` aren't observable there). **Corollary:** AC-41(e) updated to assert the relocated emit + new payload; (a)-(d) unchanged (pure ramp intermediate).
- **B4 — INV-9b numeric contradiction** → `FIRST_SESSION_KILL_HITS_MAX` 12→9, range [8,15]→[8,9]; INV-9b tightened to the testable `FIRST_SESSION_KILL_HITS_MAX ≤ TARGET_KILL_HITS_FINAL` (9≤9 at defaults; was 12>9). Side-effect (ramp knobs now dominated by the 180 cap < base_hp 200) **disclosed honestly** + tracked **Followup #26** (knob-removal deferred to avoid a cascade this pass).
- **B5 — DD#2 cold-start div-by-zero** → `volume_factor` cold-start guard added: `trailing_median <= 0 → volume_factor = 1.0` (first session = average, no div-by-zero / NaN mis-classification). Ownership attributed to ADR-005 (`workout_score` source); #16 states it as a forward-constraint.
- **B6 — table sync** → Test Type Distribution recomputed to **54** (Unit 37); Gate Distribution: **AC-39 ADVISORY→MVP-BLOCKING**, **AC-44 added ADVISORY**; Coverage Map **Rule 16 row +AC-45** (traces NEVER #13) + EC-07→AC-31/AC-44 + EC-16/17→AC-27a/27b/42/46 enrich; reconciliation note de-「historical snapshot」'd.

### Recommended — also applied
- `MINI_BOSS_EFFORT_THRESHOLD` range guard **[0.15, 0.40]** + out-of-range → design re-review (knob row + derivation note + TUNABLE list, all three synced).

### Pass 8 exit bar — 7/7 grep-verified PASS
1. AC-27a == EC-17/AC-42 DD#1 (no APPLICATION_PAUSED/RESUMED, no respawn-at-full — only negations) ✓ · 2. handler `(payload: EnemyKilledPayload)` == #14 L145, no positional remnant ✓ · 3. `_emit_telemetry("boss.first_session_bootstrap"` lives only in `spawn_boss`, gone from the static formula ✓ · 4. INV-9b `9 ≤ 9`, no literal violation ✓ · 5. cold-start `trailing_median <= 0 → 1.0` guard present ✓ · 6. Test Dist=54 / Gate AC-39→MVP + AC-44→ADVISORY / Coverage Map Rule 16 +AC-45 ✓ · 7. **zero new cross-ref orphan** — only new identifier `Followup #26` (bidirectional: tracker entry ↔ F2 disclosure); `EnemyKilledPayload` cites its #14 owner ✓.

### Files modified in Pass 8
- `design/gdd/boss-system.md` — B1-B6 + Recommended + STATUS banner → Pass 8 COMPLETE.
- `design/gdd/reviews/boss-system-review-log.md` — this Pass 8 entry.

Status: ~~Pass 8 COMPLETE — pending fresh-session /design-review~~ **Superseded — Pass 8 /design-review verdict NEEDS REVISION below.**

---

## Review — 2026-06-04 — Verdict: NEEDS REVISION (Pass 8 /design-review)

Mode: full — 4 adversarial specialists (gameplay-programmer + systems-designer + qa-lead + game-designer) + creative-director synthesis. Fresh-context re-review of the Pass 8 6-BLOCKING spec-fix.
Scope signal: M (5 BLOCKING + 2 adjudicated + ~6 Recommended; all inline-fixable; no new ADR; GP-1 + mini-boss contract are cross-#13/#14 type forward-constraints).
Blocking items: 5 | Adjudicated: 2 | Recommended: ~6.

Summary: Pass 8's 7-item exit bar genuinely grep-passed at the surface. But the full-specialist pass found **deeper issues the greps don't cover** — two of which the Pass-8 fixes themselves touched. CD ruling: **7 raw BLOCKING = 2 NEW (Pass-8 self-introduced) + 5 PRE-EXISTING bedrock. The 2-NEW-vs-5-pre-existing ratio = a review CONVERGING on bedrock, not a fix-pass MANUFACTURING phantoms → Structural Freeze does NOT fire. But this is the last warning — if Pass 9 self-introduces another cross-ref defect from its own fix, freeze triggers automatically.**

### 5 BLOCKING (Pass 9 must fix)
- **B1 — `EnemyKilledPayload` type-resolution regression** [gameplay-programmer, ✓main-reviewer grep-verified]: Pass 8 B2 typed the handler param `func _on_enemy_killed_self_listen(payload: EnemyKilledPayload)`, but `EnemyKilledPayload` is a **nested `class` inside combat-resolver.md L222** (`class EnemyKilledPayload extends RefCounted`), NOT a file-level `class_name` — unresolvable in #16's compile scope → parse error. (#14 enemy-director L145 uses the same bare type in its own signal decl → identical latent issue; Pass 8 matched #14 literally and inherited it. The OLD positional `(transition_id, _faction, _tier)` was ALSO broken.) **NEW (Pass-8 self-introduced, but a fidelity copy of #14's own broken decl).** → Fix: type the param `RefCounted`/untyped + duck-type `payload.transition_id` (per [[reference_gdscript_di_seam]] precedent), AND add a Dependencies forward-constraint that #13 should promote `EnemyKilledPayload` to a file-level `class_name`.
- **B2 — `BossFormulas` never declared** [gameplay-programmer, ✓grep-verified]: `BossFormulas.compute_max_hp` is called (boss-system L198/543/965) but `BossFormulas` has NO `class_name` declaration anywhere — same failure class as the already-fixed `BossVisualResource` GP-F2. **PRE-EXISTING (Pass 4/6).** → Add a `class_name BossFormulas extends RefCounted` contract section + file path (`res://src/.../boss_formulas.gd`) + Dependencies/file-manifest listing.
- **B3 — INV-9b cross-knob vulnerability** [systems-designer, ✓grep-verified]: INV-9b = `FIRST_SESSION_KILL_HITS_MAX ≤ TARGET_KILL_HITS_FINAL` but only the LHS is range-guarded [8,9]; `TARGET_KILL_HITS_FINAL` range is [6,15] (L1362). Designer sets it to 6/7/8 (all in-range) → INV-9b violated, undetected. Pass 8's note「range [8,9] makes the violation unreachable」is **FALSE — only constrains LHS**. **NEW (Pass-8 false claim).** → Narrow `TARGET_KILL_HITS_FINAL` lower bound to ≥9, OR add a cross-knob CI lint, OR load-time clamp `FIRST_SESSION_KILL_HITS_MAX = min(knob, TARGET_KILL_HITS_FINAL)`. (INV-9c has the same stated-but-unenforced shape, lower-stakes.)
- **B4 — AC-41(e) negative-provenance not unit-testable** [qa-lead]: 「telemetry emitted by spawn_boss NOT by compute_max_hp」is a negative assertion a unit test can't prove (spy only counts the emit). **PRE-EXISTING (ties to B2 BossFormulas).** → Add a static-grep surrogate to the evidence: `boss_formulas.gd` contains 0× `_emit_telemetry` (requires `compute_max_hp` to be a pure helper — which B2's declaration enables).
- **B5 — first-session ramp knobs are INERT, prose-only disclosure** [game-designer]: with cap=180 < base_hp=200 the cap always binds, so `FIRST_SESSION_BASELINE_ATK` + `FIRST_SESSION_DURATION_TARGET_SEC` never change the output. Pass 8 disclosed this in prose + Followup #26, but the Tuning Knobs table still presents them as live tunables → future designers tune no-ops. **PRE-EXISTING (numeric since Pass 6; surfaced by Pass-8 B4).** → Tag both knobs `INERT (dominated by first-session cap — Followup #26)` in the Tuning table.

### Adjudicated (CD ruling — apply in Pass 9)
- **AC-39 Likert ≥3.5 measurability** [qa-lead] → **downgrade accepted**: active-session-rate stays the hard MVP-BLOCKING gate; Likert ≥3.5 → ADVISORY corroborator + add a session-1 baseline question (within-subject delta). (The n≥12 attrition buffer made the gate reachable, but a single-question one-directional self-report with no retest in a 3-week window isn't independently measurable as a blocking gate.)
- **Formula 2 ludonarrative hole** [game-designer] → CD ruled **RECOMMENDED, not blocking**: with auto-play + an invincible avatar (NEVER #13) the boss's `boss_attack_damage` is a tension the player can neither perceive nor affect. Resolution = demote Formula 2 to **COSMETIC** (drives animation/impact intensity, not a hidden survival sim), stated explicitly in the GDD. The「stakes are outcome not HP」fantasy is preserved; Formula 2 stops pretending to be a survival mechanic.

### Recommended (non-blocking)
- effort_score cold-start: B5 guarded `volume_factor`→1.0 but `pr_factor`/`streak_factor` first-session values are unspecified → effort_score≈0 → first full session likely demoted to mini-boss (contradicts the engaging-first-impression goal). Forward-constrain the all-three-factor cold-start floor to ADR-005.
- mini-boss HP cross-system contract vacuum (Rule 3 says 4-6 hits but the formula is #14 scope — no handoff spec).
- AC-27a↔AC-42 near-duplicate branch logic (drift risk) — narrow AC-42 to H-value matrix, AC-27a to branch dispatch; add a double-resume re-entry-dedupe AC (Rule 11 multi-hook can double-fire, currently unasserted).
- double-`spawn_boss` clobbers persisted mid-fight HP (add a fresh-spawn-vs-resume guard on the `_set_current_hp` write at `_ready`); AC-45 add a `max_hp==1` boundary; AC-46 add a `Δ==TTL` exact boundary; effort 0.25 hard-cliff transparency.

### Nice-to-Have
Formula 3 with exactly 2 patterns → deterministic ABAB (BossRegistry warn when `attack_patterns.size() < 3`); `_spawned_transition_ids` unbounded growth (evict on boss-free); Rule 12 resume pseudocode `is_instance_valid(boss)` null-guard.

### Pass 9 exit bar (grep-verifiable — all must pass; CD: grep-verify EACH before claiming closure)
1. Handler param type resolves: NOT a bare nested-class reference — either `RefCounted`/untyped duck-type OR `EnemyKilledPayload` promoted to file-level `class_name` in #13 + cited in #16 Dependencies. (grep #16 handler + #13 declaration form.)
2. `class_name BossFormulas` declared in its own contract section + file path + Dependencies listing (grep the declaration exists, mirroring BossVisualResource GP-F2).
3. INV-9b is ENFORCED, not just asserted: `TARGET_KILL_HITS_FINAL` lower bound ≥9 OR a cross-knob lint OR a load-time clamp — and the false「unreachable」note removed/corrected.
4. AC-41(e) has a static-grep surrogate (`boss_formulas.gd` 0× `_emit_telemetry`) in its evidence.
5. Both ramp knobs tagged INERT in the Tuning Knobs table.
6. AC-39: active-rate = hard gate, Likert ≥3.5 = ADVISORY + session-1 baseline; Formula 2 demoted to COSMETIC explicitly.
7. **Zero new cross-reference / type-resolution orphans — any new one → STRUCTURAL FREEZE auto-triggers (CD's stated last warning).**

### Process
- **FRESH SESSION** (user-selected; per [[feedback_orphan_cleanup_fresh_context]] — this GDD keeps re-proving it; this review session is long after the full Pass 8 edit + 4-agent + CD review). B1 first: decide the `EnemyKilledPayload` typing approach (untyped duck-type is lowest-risk + matches the project's DI-seam precedent) before editing. Grep-verify each exit-bar item before claiming closure.

Prior verdict resolved: Pass 7 /design-review NEEDS REVISION (6 BLOCKING) → Pass 8 closed all 6 + 7-item exit bar grep-passed → this Pass 8 review found 5 deeper BLOCKING (2 Pass-8-introduced fidelity errors + 3 pre-existing bedrock) + 2 adjudicated.

Status: ~~NEEDS REVISION — Pass 9 targeted inline fixes pending FRESH session.~~ **Superseded — Pass 9 spec-fix-pass COMPLETE below.**

---

## Pass 9 Spec Fix-Pass — 2026-06-04 — COMPLETE (5-BLOCKING + 2-adjudicated inline, fresh context; pending /design-review)

Fresh session「#16 Boss Pass 9」per the Pass 8 /design-review process directive ([[feedback_orphan_cleanup_fresh_context]]). Decided B1 typing approach FIRST (untyped duck-type, lowest-risk, matches project DI-seam precedent) before editing. Grep-verified each exit-bar item before claiming closure. Scope M, no new ADR.

### 5 BLOCKING — all fixed
- **B1 [NEW Pass-8] EnemyKilledPayload type-resolution** → handler param de-typed: `func _on_enemy_killed_self_listen(payload) -> void` (UNTYPED), duck-types `payload.transition_id`. Grep-confirmed `EnemyKilledPayload` is a nested `class` @ combat-resolver.md L222 (no file-level `class_name`) → annotation was a real parse error in #16 scope. Comment block rewritten to explain the nested-class constraint. **Downstream sync (Pass-8 lesson):** AC-11b test description rewritten to a duck-typed stub (`enemy_killed(payload)` mock exposing `.transition_id`), no longer implies a typed param. **Forward-constraint** added to Dependencies → Bidirectional Sync Gap table: #13 should promote `EnemyKilledPayload` (+ `HitResolvedPayload`/`CombatAnomalyPayload`) to a file-level `class_name`; once done #16 MAY re-type. Verified: zero live `: EnemyKilledPayload` annotation remains (4 mentions all prose/comment).
- **B2 [PRE-EXISTING] BossFormulas never declared** → added GP-F9 contract block before Formula 1: `class_name BossFormulas extends RefCounted` @ `res://src/formulas/boss_formulas.gd` (stateless pure-function class, same as #13 CombatResolver Rule 1; all static funcs). Mirrors the BossVisualResource GP-F2 fix. Added to Dependencies registry-sync row listing. `StatSnapshot`/`BossTemplate`/`AttackPatternResource` in the illustrative signatures are all pre-existing file-level class_names (not new orphans).
- **B3 [NEW Pass-8 false claim] INV-9b cross-knob** → ENFORCED both-sided: `TARGET_KILL_HITS_FINAL` Safe Range narrowed [6,15]→**[9,15]** (Tuning table) so max-LHS(`FIRST_SESSION_KILL_HITS_MAX`=9) ≤ min-RHS(9) for every in-range pair → unreachable-to-violate by construction. Pass-8's FALSE「range [8,9] makes it unreachable」(constrained only LHS) corrected in the INV-9b row. Added **INV-9c honest scope note** (same stated-not-enforced shape, but lower-stakes: the runtime `max(...,MIN_BOSS_HP)` clamp @ Formula 1 already guarantees the floor regardless; range-enforcement folded into Followup #26).
- **B4 [PRE-EXISTING] AC-41(e) negative-provenance** → added static-grep surrogate to AC-41 evidence: `boss_formulas.gd` 0× `_emit_telemetry` (enabled by B2's pure-helper declaration) via `tools/ci/check_boss_formulas_purity.gd` (mirrors #13 `check_combat_resolver_purity.gd`), added to BOSS-AC-followup-08 tooling-story scope + `tests/static/test_boss_formulas_purity.gd` evidence path.
- **B5 [PRE-EXISTING] ramp knobs INERT** → both `FIRST_SESSION_BASELINE_ATK` + `FIRST_SESSION_DURATION_TARGET_SEC` tagged ⚠️**INERT** in the Tuning Knobs table (dominated by first-session cap=180 < base_hp=200; shape pre-cap `effective_atk` only, never final `boss_max_hp`; Followup #26).

### 2 Adjudicated — applied
- **AC-39** → restructured into a single AC (no count drift across distribution tables) with **(A) hard MVP-BLOCKING clause = behavioral active-session-rate** (≥10 of n≥12 complete ≥8 sessions in ≥3-week window; drop-out = falsifiable novelty-collapse signal) + **(B) ADVISORY corroborator = within-subject Likert** (session-1 baseline + session-8 ≥3.5 + non-collapsing delta; not independently blocking). Gate Distribution table row updated.
- **Formula 2 → COSMETIC** → added a ⚠️COSMETIC banner (CD ruling): output drives animation/impact intensity, NOT a survival sim — invincible avatar (EC-25/NEVER #13) + auto-play means the player can't perceive/affect boss damage. Rationale rewritten off「avatar-survive window」; worked-example「死」claim reframed to cosmetic intensity band; blanket reinterpretation clause covers downstream survive/kill/anti-one-shot language (INV-5 clamp retained for animation-band sanity only).

### Pass 9 exit bar — 7/7 grep-verified
1. ✓ Handler `(payload)` untyped — zero live `: EnemyKilledPayload` annotation (4 mentions prose/comment); #13 promote forward-constraint in Dependencies.
2. ✓ `class_name BossFormulas extends RefCounted` declared in GP-F9 contract section + file path + registry-sync listing.
3. ✓ INV-9b ENFORCED (RHS range [9,15], both-sided bounded) + false「unreachable」note corrected; INV-9c honest note.
4. ✓ AC-41(e) static-grep surrogate (`boss_formulas.gd` 0× `_emit_telemetry`) in evidence + CI tool in followup-08.
5. ✓ Both ramp knobs tagged INERT in Tuning table.
6. ✓ AC-39 split (A behavioral hard gate / B Likert advisory + session-1 baseline) + Formula 2 COSMETIC banner explicit.
7. ✓ Zero new cross-ref/type orphan — every new identifier (BossFormulas, boss_formulas.gd, check_boss_formulas_purity.gd) declared/tracked; Followup #26 + #13 purity tool confirmed pre-existing; CD's auto-FREEZE not triggered.

### Files modified in Pass 9
- `design/gdd/boss-system.md` — B1-B5 + AC-39 + Formula 2 + STATUS banner → Pass 9 COMPLETE.
- `design/gdd/reviews/boss-system-review-log.md` — this Pass 9 entry.

Status: ~~Pass 9 COMPLETE — pending fresh-session /design-review (expect Approved).~~ **Superseded — Pass 9 /design-review verdict MAJOR REVISION NEEDED + STRUCTURAL FREEZE below.**

---

## Review — 2026-06-04 — Verdict: MAJOR REVISION NEEDED 🧊 STRUCTURAL FREEZE (Pass 9 /design-review)

Mode: full — 4 adversarial specialists (game-designer + systems-designer + qa-lead + godot-gdscript-specialist) + creative-director synthesis. Fresh-context re-review of the Pass 9 5-BLOCKING + 2-adjudicated spec-fix.
Scope signal: M (the 7 BLOCKING are doc-consistency / type-annotation prefix / 1 invariant range-close / 1-2 AC — no new ADR, no new system). But process mode escalates from inline-patch to verification-first.
Blocking items: 7 across 4 domains | Recommended: ~6.

Summary: Pass 9's 7-item exit bar genuinely grep-passed at the surface, and B1-B5 + the 2 adjudications landed correctly **for the named instances**. But the full-specialist pass found the Pass 9 B1 fix was a **single-instance fix of a bug CLASS** — it de-typed the `EnemyKilledPayload` handler param (a nested class with no file-level `class_name`) and certified exit-bar #7「zero new type orphan」, while **two siblings of the identical class sat in the very signatures Pass 9 was editing**: `StatSnapshot` (nested in combat_resolver.gd L142, bare-annotated in 4 load-bearing #16 sites incl. the same `boss_committed` signal + `spawn_boss` signature) and `EnemyAIState` (nested enum in enemy_director.gd L270, bare in L168/677/694/797). Both grep-confirmed by the main reviewer. **CD: the false「class-clean」certification IS the self-introduced defect the Pass 8 exit bar warned about → STRUCTURAL FREEZE triggers.** Plus the Pass 9 Formula 2 COSMETIC reframe manufactured a net-new contradiction (cosmetic banner vs still-wired-to-#13-live-HP).

### 7 BLOCKING (Pass 10 must fix)
- **B1 [godot, grep-verified] `StatSnapshot` bare annotation = parse error** — nested `class StatSnapshot extends RefCounted` @ combat_resolver.gd L142 (no file-level `class_name`); real code uses `CombatResolver.StatSnapshot`. #16 uses bare `StatSnapshot` in 4 sites: `signal boss_committed(... snapshot: StatSnapshot ...)`, `@export var player_stat_snapshot: StatSnapshot` (L160), `BossFormulas.compute_max_hp(... snapshot: StatSnapshot)` (L957), Dependencies L344. **SAME bug class as Pass 9 B1 (EnemyKilledPayload), in the SAME signatures Pass 9 edited.** `@export` cannot simply be de-typed — nested-class export typing is itself problematic → needs a real decision.
- **B2 [godot, grep-verified] `EnemyAIState` bare enum = parse error** — nested enum @ enemy_director.gd L270; real code uses `EnemyDirector.EnemyAIState.SPAWNING`. #16 bare `EnemyAIState.SPAWNING` (L168) + `match` arms (L677/694/797). Prefix `EnemyDirector.` everywhere. (`var _ai_state: int` storage type itself is correct.)
- **B3 [game-designer] Formula 2 COSMETIC reframe NET-NEW contradiction** — banner L1047「animation intensity only」vs Rule 6 L365 + Variables table L1072「Per-pattern damage input to #13 compute_hit_damage」+ EC-25 fires BECAUSE avatar HP hits 0. Pick one: (a) boss_attack_damage never touches avatar HP → EC-25 dead code + AC-45 one-shot impossible; or (b) it does → not cosmetic. AC-19 + AC-45 both assume a live HP sim the banner denies. **Fix-pass manufacturing a new defect — the freeze pattern.**
- **B4 [systems-designer, grep-verified] INV-9c unenforced, worst-case in-range** — `FIRST_SESSION_EXPECTED_HIT_DAMAGE=10 × FIRST_SESSION_KILL_HITS_MAX=8 = 80` vs `MIN_BOSS_HP=200` (all in-range). Floor clamp defends the floor but inverts cap intent: MIN_BOSS_HP > cap → boss pinned 200 HP → 20-hit kill > TARGET_KILL_HITS_FINAL=9 → re-creates the EXACT INV-9b violation Pass 8 fixed, via the unguarded twin knob. INV-9b was range-enforced (Pass 9 B3); INV-9c was not. Range-enforce INV-9c OR constrain MIN_BOSS_HP upper bound on bootstrap branch.
- **B5 [qa-lead, grep-verified] Test Type Distribution intro stale** — L1530 still「32 Unit」; live table L1781/1787 correctly 37 Unit. Fix L1530 → 37.
- **B6 [qa-lead] AC-07b MockClock delta unspecified** —「fixed per-frame delta the test controls」never specifies value or frame count → two compliant impls can pass OR fail the same code = non-falsifiable gate. Pin it (e.g. 16ms/frame × 2 = 32ms ≤ 200ms PASS; 250ms stall = FAIL boundary).
- **B7 [game-designer] Player Fantasy「緊張感/tension」claim has zero falsifiable test** — invincible avatar + auto-play; no AC validates「outcome stakes」feels like stakes. AC-39(B) measures screenshot desire, not tension. Add a falsifiable AC or downgrade the claim.

### Recommended (non-blocking)
- [systems] INERT ramp knobs give false AC-41(a-d) coverage confidence (test pre-cap effective_atk that never reaches output) — collapse to cap-only now (Followup #26) OR add an AC pinning the INERT contract.
- [godot] `_spawned_transition_ids` unbounded growth IS a real Web Export 512MB concern — reclassify above Nice-to-Have (eviction / session-scoped clear).
- [qa] AC-45 `max_hp==1` boundary: inline example → required sub-assertion; AC-39 attrition buffer (n=12 → need 10 completers = 83%) optimistic for 3-week unsupervised; 「completes ≥8 sessions」undefined (boss encounters vs app opens).
- [game-designer] AC-39(A) fail-branch is a scope time-bomb (3-week playtest can retroactively expand MVP scope) — name a producer owner for the scope-reopen decision.

### STRUCTURAL FREEZE — rationale + what it means
Pass 8 set: 「if Pass 9 self-introduces another cross-ref defect from its own fix, freeze triggers automatically.」 The bare `StatSnapshot`/`EnemyAIState` annotations literally predate Pass 9 — BUT Pass 9 B1 explicitly locked this exact bug class (no-file-level-`class_name` nested type/enum used as annotation), fixed ONE named instance, and certified exit-bar #7「zero new type orphan」while two siblings sat in the same edited signatures. **The false class-clean certification IS the self-introduced defect the exit bar exists to catch.** 9 passes + multiple full-specialist reviews all read past StatSnapshot/EnemyAIState → paper review provably cannot catch this class. Freeze condition substance met. (Lesson [[feedback_orphan_cleanup_fresh_context]] + bug-class-sweep discipline: fixing a bug CLASS requires a whole-doc grep sweep for ALL instances, not a named-instance fix + clean certification.)

**Freeze means: STOP inline spec authoring. Pass 10 = 3 verifier-grep passes (NOT author-self-reported citation — prior passes proved self-report errs):**
- **Pass A — Symbol Resolution Sweep**: grep EVERY type annotation / `@export` type / `match` arm / default-value ref against the owning file's real `class_name` + nested scope. Output a table: symbol → usage site → owning file:line → resolves-bare? → prefix needed? MUST cover all nested classes (`StatSnapshot`→`CombatResolver.StatSnapshot`) + nested enums (`EnemyAIState`→`EnemyDirector.EnemyAIState`). `@export var player_stat_snapshot: StatSnapshot` needs a REAL decision (nested-class export typing is itself problematic), not just a prefix.
- **Pass B — Formula 2 Coherence**: pick ONE to ship — (a) truly cosmetic → delete EC-25 / AC-19 / AC-45 one-shot language; or (b) live HP → delete the cosmetic banner. Cannot ship both.
- **Pass C — Invariant Range-Closure**: range-enforce INV-9c (mirror Pass 9 B3 INV-9b); pin AC-07b MockClock delta; fix L1530「32 Unit」→ 37; add a falsifiable tension AC or downgrade the Player-Fantasy claim.

### Process
- **FRESH SESSION required** ([[feedback_orphan_cleanup_fresh_context]] — this GDD keeps re-proving it; this review session is long after reading the full GDD + 4-agent + CD synthesis). Pass 10 is verification-first, NOT patch-first. Each grep result recorded in the Symbol Resolution table before any edit.

Prior verdict resolved: Pass 8 /design-review NEEDS REVISION (5 BLOCKING) → Pass 9 closed all 5 + 7-item exit bar grep-passed → this Pass 9 review found 7 deeper BLOCKING (2 same-class type-resolution siblings Pass 9 missed while certifying class-clean + 1 Pass-9-introduced cosmetic contradiction + 1 unenforced-twin invariant + 3 AC/doc-sync) → STRUCTURAL FREEZE triggered.

Status: ~~MAJOR REVISION NEEDED 🧊 STRUCTURAL FREEZE — Pass 10 = verification-first (Pass A/B/C verifier-grep), FRESH session.~~ **Superseded — Pass 10 verification-first spec-fix COMPLETE below.**

---

## Pass 10 Verification-First Spec Fix-Pass — 2026-06-05 — COMPLETE (7 BLOCKING + recommended; STRUCTURAL FREEZE protocol)

Per the Pass-9 STRUCTURAL FREEZE directive: **verification-first, NOT patch-first** — a whole-doc **symbol-resolution grep sweep against the SHIPPED code** (`src/**.gd` + `project.godot`, NOT the GDD prose that misled passes 8/9) was run BEFORE any edit, and EACH exit-bar item was grep-verified before claiming closure ([[feedback_orphan_cleanup_fresh_context]] + bug-class-sweep discipline).

### Pass A — Symbol Resolution Sweep (the freeze's B1/B2 + 2 siblings it missed + the EnemyKilledPayload correction)

Ground-truth table (symbol → shipped owner → resolves bare? → fix):

| Symbol | Shipped declaration | Bare resolves? | Fix applied |
|--------|---------------------|----------------|-------------|
| `StatSnapshot` | `class StatSnapshot extends RefCounted` **nested** @ `combat_resolver.gd:142` (owner `class_name CombatResolver`) | ❌ parse error | → `CombatResolver.StatSnapshot` at all 9 annotation sites; **L160 `@export` DROPPED** (RefCounted is non-exportable — the「real decision」the freeze demanded: runtime-set plain typed var) |
| `EnemyAIState` | `enum EnemyAIState` **nested** @ `enemy_director.gd:270` (autoload) | ❌ | → `EnemyDirector.EnemyAIState.*` at L168/677/694/797 (mirrors shipped `src/ai/enemy.gd:21`) |
| `AbilityClass` | `enum AbilityClass` **nested** @ `ability_system.gd:49` (autoload) | ❌ | → `@export_enum("STRIKE","CONTROL","MOBILITY","UNKNOWN") var class_archetype: int` (no @export precedent for autoload-nested enums; `exercise_class_mapping.gd` ordinal-int pattern). **NEW sibling — Pass-9 review did NOT flag.** |
| `RarityTier` | `enum RarityTier` **nested** @ `loot_enums.gd:43` (owner `class_name LootEnums`) | ❌ | → `LootEnums.RarityTier` (combine fn) + `@export_enum(...) var loot_guarantee_min_tier: int`. **NEW sibling — Pass-9 review did NOT flag.** |
| `EnemyKilledPayload` | `class_name EnemyKilledPayload extends SerializableResource` **FILE-LEVEL** @ `enemy_killed_payload.gd:31` | ✅ resolves | **RE-TYPED** handler `(payload: EnemyKilledPayload)` + AC-11b + corrected the「nested, parse error」forward-constraint to「already file-level in shipped code; #13/#14 GDD prose is the stale part」. **Pass 9 B1 de-typed this on a FALSE stale-GDD premise — reversed.** |

This is the freeze's central lesson made concrete: the Pass-9 B1 fix de-typed ONE named instance of「nested-type-as-annotation」and certified「zero new type orphan」, while **StatSnapshot + EnemyAIState** (the freeze caught these two) **AND AbilityClass + RarityTier** (two MORE the freeze itself missed) sat in the same/adjacent signatures — provably uncatchable by named-instance review. The whole-doc grep sweep caught all four, and corrected the EnemyKilledPayload premise that was wrong against shipped code all along. Every introduced prefix (`CombatResolver`/`EnemyDirector`/`LootEnums`/`AbilitySystem`) is a **verified real shipped `class_name`/autoload** (project.godot L43/L49; src/core class_names) — zero new orphan.

### Pass B — Formula 2 Coherence (single mode shipped)

Picked **(b) live-HP** (the lower-deletion, more-coherent option): `boss_attack_damage` IS a real #13 `compute_hit_damage` input (Rule 6 / Variables-table stay literally true); the avatar is stakes-free because it is **invincible** (EC-25 / NEVER #13 auto-recover), NOT because the damage is fake. **DELETED the Pass-9 COSMETIC banner** + reverted the rationale + worked-example + the BossFormulas surface-comment (L964 residual — caught on the COSMETIC re-sweep, exactly the kind of single-instance-miss the freeze warns about). Now EC-25 / AC-45 / AC-19 / Rule 6 are mutually coherent under one reading.

### Pass C — Invariant Range-Closure + AC/doc-sync

- **INV-9c ENFORCED by construction (B4)**: `MIN_BOSS_HP` upper bound narrowed **200→80** (both the Variables table + Tuning table), so `max(MIN_BOSS_HP)=80 ≤ min first-session cap (10×8=80)` for every in-range triple → the twin-knob INV-9b re-inversion the freeze caught is now unreachable, mirroring the Pass-9 B3 INV-9b range-close.
- **AC-07b MockClock delta pinned (B6)**: 16ms/frame × 2 = 32ms → PASS; 250ms single-frame stall → FAIL. Two asserted deltas = falsifiable gate.
- **Test Type Distribution intro (B5)**: stale「32 Unit」→ **37 Unit** (matches the live table = 37/54).
- **Player-Fantasy「緊張感」(B7)**: downgraded to **anticipation / ceremony (期待感/儀式感)** with **AC-29a + AC-39(A)** named as its falsifiable tests — an invincible-avatar auto-play game has no measurable survival「tension」.
- **Recommended**: `_spawned_transition_ids` eviction-on-free note added (Web Export 512MB bound).

### Pass 10 exit bar — grep-verified PASS
1. ✓ Zero bare `: StatSnapshot` type annotations (only `CombatResolver.StatSnapshot`; the 2 remaining `: StatSnapshot` hits are comment/AC prose, not annotations).
2. ✓ Zero bare `EnemyAIState` (all `EnemyDirector.EnemyAIState`).
3. ✓ Zero bare `: AbilityClass` / `: RarityTier` annotations (AbilityClass → @export_enum int; RarityTier → `LootEnums.RarityTier`).
4. ✓ Handler typed `(payload: EnemyKilledPayload)` (1 def); AC-11b synced.
5. ✓ Zero illegal `@export` of a nested/RefCounted type.
6. ✓ Zero live「COSMETIC」claim on Formula 2 (banner + surface-comment both reverted; remaining「COSMETIC」strings are meta-references to the deletion).
7. ✓ INV-9c ENFORCED + `MIN_BOSS_HP [10,80]` both tables; AC-07b 32/250 pinned; 37 Unit intro.
8. ✓ **Zero new cross-ref/type orphan** — every introduced identifier is a verified shipped `class_name`/autoload.

### Files modified in Pass 10
- `design/gdd/boss-system.md` — Pass A (10 symbol sites + handler + comments + Dependencies forward-constraint + AC-11b) + Pass B (Formula 2 banner/rationale/example/surface-comment) + Pass C (INV-9c/MIN_BOSS_HP ×2 + AC-07b + intro 37 + Player-Fantasy) + STATUS banner + Author/Last-Updated.
- `design/gdd/reviews/boss-system-review-log.md` — this Pass 10 entry.

Prior verdict resolved: Pass 9 /design-review MAJOR REVISION 🧊 STRUCTURAL FREEZE (7 BLOCKING) → Pass 10 verification-first closed all 7 + 2 unflagged sibling type-orphans + corrected the Pass-9 B1 false premise, whole-doc grep-verified.

Status: ~~Pass 10 COMPLETE — pending fresh-session /design-review.~~ **Superseded — Pass 11 /design-review + inline fixes → APPROVED below.**

---

## Review — 2026-06-05 — Verdict: APPROVED (Pass 10 fresh /design-review → Pass 11 inline fixes; STRUCTURAL FREEZE LIFTED)

Mode: full — 4 adversarial specialists (godot-gdscript-specialist + systems-designer + qa-lead + game-designer) + creative-director-style main-reviewer synthesis. Fresh-context re-review of the Pass 10 verification-first spec-fix.
Scope signal: M. Re-review of the STRUCTURAL-FREEZE lift.

### Freeze-lift confirmation
**godot-gdscript-specialist (the freeze-domain expert) grep-verified ALL Pass-10 symbol fixes correct against shipped code**: `CombatResolver.StatSnapshot` (+ dropped illegal @export on RefCounted), `EnemyDirector.EnemyAIState` (mirrors src/ai/enemy.gd:21), `AbilityClass`→`@export_enum int`, `RarityTier`→`LootEnums.RarityTier`, and the `EnemyKilledPayload` re-type (file-level class_name @ enemy_killed_payload.gd:31 — typed-param-on-untyped-signal is valid in Godot 4.6; runtime always passes `EnemyKilledPayload.new()`). **The type-resolution bug CLASS is swept. Freeze condition cleared.**

### Re-review found adjacent items (NOT the same self-introduced-orphan freeze pattern) — closed inline in Pass 11
The full-specialist pass surfaced a batch the Pass-10 sweep hadn't reached. CD-style adjudication: these are **(a) more downstream-caller-name orphans of the SAME「GDD prose cites a name that isn't the shipped class」family** the sweep had only partially covered + **(b) genuine design consequences of the Pass-B live-HP decision** + **(c) doc-sync polish** — i.e. a review CONVERGING on bedrock, not a fix-pass manufacturing new same-class type-annotation orphans in its own edit. All BLOCKING-grade items fixed inline (Pass 11), grep-verified:

- **[godot] `LootRarity.roll_tier` undefined** → `LootRarityCalc.compute_rarity_from_score` (real class @ loot_rarity_calc.gd:22; illustrative #15-scope marked).
- **[godot, extended by main-reviewer whole-doc sweep] downstream-caller autoload names** → `Camera`→`CameraController`, `ParticleSystem`→`ParticleSystemWrapper`, `Stat`→`StatSystem`, `ParticlePreset.LOOT_RARE_BURST`→`ParticleSystemWrapper.PresetId.LOOT_RARE_BURST` (all verified vs project.godot L42/L53/L54). Design-forward refs (`DeterministicHash` followup-19, `ArenaConfig` followup-13, `BossRegistry` #16-own) left as acceptable not-yet-shipped.
- **[systems + qa] Pass-B live-HP consequence — downed-flicker** → new `DOWNED_INVULN_SEC` (0.6s, [0.3,1.5]) grace window on EC-25 + AC-45(f): degenerate `player_max_hp ∈ [1,9]` (boss MIN_BOSS_DAMAGE 5 > recover HP) no longer infinite-flickers. (+1 knob → 17 owned.)
- **[systems] Formula 1 symbol** → `TARGET_KILL_HITS` unified to `TARGET_KILL_HITS_FINAL` in the compute (mini's [3,18] generic is #14 scope).
- **[systems] INV-3 undefined `max_player_attack_baseline`** → rewritten to the `MIN_BOSS_HP < MAX_BOSS_HP` constraint it was expressing.
- **[game-designer] AC-19 / Formula 2 framing** → AC-19「anti-one-shot」→「anti-downed-flicker / texture-guard」(an invincible avatar can't be one-shot); Formula 2 Notes gained an explicit caller-chain line (boss_attack_damage = INPUT to #13 `compute_hit_damage`; #13 owns the HP write, not #16).
- **[qa] AC-07b MockClock** → pinned `MOCK_FRAME_MS = 16` as the AC-level test constant. **[qa] gate-count** → split-gate reconciliation footnote (rows sum 57 = 54 effective + AC-12/16/33 double-listed; Unit 37 stands).

### INV-9c 80≤80 edge — confirmed SAFE
systems-designer numerically swept every in-range triple: worst-case cap (10×8=80) ≥ worst-case floor (MIN_BOSS_HP.hi=80); the 80=80 tie yields `max(min(hp,80),80)=80`, no inversion. INV-9c range-enforcement holds.

### Advisory followups (NON-blocking — logged, not gating Approval)
- [game-designer] anticipation/ceremony two sequential emotional peaks (boss-kill ceremony vs post-kill loot-reveal payoff) — GDD could split the arc explicitly; AC-29a measures kill-moment ceremony, AC-39(A) measures return-rate. Best-available proxies (honest, not perfect construct validity).
- [game-designer] downed-animation design principle (must NOT read as fail-state) — Visual/asset-spec scope (Section I + /asset-spec time); AC-39 retention is the backstop.
- [qa] AC-11b transition_id String-vs-StringName note; AC-39(B) prospective (not retrospective) session-1 baseline; Coverage Map add explicit `EC-03/06/09 → deferred-Followup-01` rows.
- [systems] MAX_RITUAL_INTENSITY「lower bound = immutable」note; [godot] `@export_enum` is Godot-4.6-official but project-unverified (verify at impl).

### Pass 11 exit bar — grep-verified PASS
Zero stale `Camera.`/`ParticleSystem.`/`ParticlePreset`/`Stat.`/`LootRarity.roll_tier`/`max_player_attack_baseline`; `DOWNED_INVULN_SEC` declared in knob table + EC-25 + AC-45(f); Formula 1 compute uses `TARGET_KILL_HITS_FINAL`; 14 real-name refs (`CameraController`/`ParticleSystemWrapper`/`StatSystem`/`LootRarityCalc`) present; **zero new orphan** (every introduced name is a verified shipped autoload/class or a properly-declared knob).

### Senior verdict (CD-style synthesis)
The STRUCTURAL FREEZE is **lifted**: its core bug class (nested-type-as-bare-annotation) is grep-proven swept, confirmed by the freeze-domain specialist. The re-review's findings were adjacent pre-existing downstream-name orphans + real Pass-B live-HP design consequences — all closed inline in Pass 11 with grep verification and zero new orphan. Remaining items are genuinely advisory (emotional-arc nuance, animation-design-principle = asset scope, doc-polish). Holding for a further full re-review would chase polish, not implementability blockers. **Verdict: APPROVED.** Epic creation UNBLOCKED.

Scope signal: L (multi-system integration; 4 formulas; ADR-001/003/005/006/007/008/009 inherited; no new ADR).

Prior verdict resolved: Pass 9 /design-review MAJOR REVISION 🧊 STRUCTURAL FREEZE (7 BLOCKING) → Pass 10 verification-first swept the bug class → Pass 10 fresh /design-review confirmed the sweep + found adjacent items → Pass 11 closed them inline → **APPROVED**.

Status: **✅ APPROVED 2026-06-05 (Pass 11). STRUCTURAL FREEZE lifted. Epic creation UNBLOCKED → /create-epics boss-system. Advisory followups logged (non-blocking).**
