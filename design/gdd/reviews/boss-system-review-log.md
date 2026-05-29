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
