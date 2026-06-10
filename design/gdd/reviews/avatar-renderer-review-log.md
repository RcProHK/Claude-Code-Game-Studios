# Avatar Renderer (#26) — Review Log

## Review — 2026-05-28 — Verdict: APPROVED (inline same-session)
- Scope signal: L
- Specialists: creative-director (×2 — Section B framing + Phase 5a-bis CD-GDD-ALIGN gate) + game-designer + art-director + technical-artist + gameplay-programmer (Section C parallel) + systems-designer ×2 (Section D + E) + qa-lead (Section H)
- Blocking items: 0 | Recommended: 2 inline-resolved (F-7 + F-8 promoted to Open Questions) + 1 inline-applied (F-10 ceremony anti-pattern)
- Summary: CD-GDD-ALIGN Pass 1 verdict CONCERNS (acceptable) → APPROVED inline same-session — 6 ALIGN findings + 2 CONCERN promoted to pre-sprint scope decision gates + 2 ADVISORY inline-fixed。CD assessment: "Strongest anti-fabrication closure to date (F-3 — 第七件套 chain coherent) + strongest cross-system voice consistency to date (F-1 — ledger metaphor)。"
- Prior verdict resolved: First review (Pass 1) — **subsequently RESCINDED by Pass 2 fresh-session re-review**

## Review — 2026-05-28 — Verdict: MAJOR REVISION NEEDED (Pass 2 fresh-session re-review)
- Scope signal: L→XL (Pass 2 escalation per F-9 prereq + F-13 #29 dependency + F-2 P4 substrate restructure)
- Specialists: 4 independent fresh-session adversarial — game-designer + systems-designer + qa-lead + godot-gdscript-specialist → creative-director Opus tier senior synthesis
- Blocking items: 16 (F-1 through F-14 BLOCKING + F-15 + F-16 CONCERN) — 13 inline-fixed Pass 2 same-session per user autonomous mode + 3 followup-tracked (F-9 helper implementation prereq, F-13 #29 producer escalation, F-15 cumulative posture post-MVP tech-debt)
- Summary: **Pass 1 inline APPROVAL RETROSPECTIVELY RESCINDED**。Fresh-session adversarial review by 4 independent specialists surfaced 16 BLOCKING findings with 5 convergent unanimous patterns — replicates #15 Pass 1→2 anti-pattern at higher severity。Three of five pillars (P1/P4/P5) compromised by GDD as Pass 1 written。Pass 2 inline fixes applied: (F-1 BLOCKING UNANIMOUS) Formula 3 first-boot epoch=0 milestone storm guard — added `MIN_OBSERVED_SESSIONS≥1` + `FIRST_BOOT_GRACE_SECONDS=48h` gates - closes Pillar 1 anti-fabrication "cosplay" leak from GymSys historical backfill; (F-2 BLOCKING UNANIMOUS) Formula 2 T3 specialist build path — added `max_single_class_tier >= 3` alternative path - pure STRIKE specialist now reaches T3 via TIER_3 ability, Pillar 4 specialist promise mechanically honored; (F-3 BLOCKING) Pass 1 F-8 escalated → Formula 3 micro-evolution layer NEW — `avatar_micro_evolution` signal weekly cadence (shader-only delta, no sprite asset cost) - Pillar 5 weekly cadence honored without ceremony budget consumption; (F-4 BLOCKING UNANIMOUS) AvatarVisualState schema NEW — explicit Resource class definition with 12 fields + source signal mapping table - resolves "spec ghost" (referenced 14× but never defined); (F-5 BLOCKING) Autoload Boot Position corrected — #11 + #12 inserted explicitly (were ABSENT from list) - effective #26 position = 11; (F-6 BLOCKING) Formula 5 monotonic clock + max(0,delta) clamp — NTP/DST anomaly defense; (F-7 BLOCKING) CR-9 hysteresis exclusion aligned with CR-15 (both WORKOUT_ACTIVE + REST_BETWEEN_SETS); (F-8 BLOCKING) CR-8 API corrected (AnimatedSprite2D.stop() not AnimationPlayer.pause()) + frame_progress field added; (F-10 BLOCKING) Q-OQ2 promoted BLOCKING for sprint planning; (F-11 BLOCKING) AC-14 reworked with transition_id traceability; (F-12 BLOCKING) PostureConfig.tres LUT NEW — resolves "posture_lut spec ghost"; (F-14 BLOCKING) AC-50 NEW for tier transition memory spike; (F-16 CONCERN) Q-OQ11 NEW recommending WebGL VRAM monitor replacement。Pass 2 added 11 new BLOCKING ACs (AC-42 through AC-52)。AC count Pass 1: 41 → Pass 2: 52。
- Cross-system anti-pattern guards established (Pass 1→2 codification, 5 rules to append to `.claude/docs/coordination-rules.md`):
  - (1) Epoch-zero gate test — time-gates MUST enumerate first-boot state behavior
  - (2) Pillar-promise vs trigger-gate audit — milestones MUST be checked against specialist builds
  - (3) Schema-before-signal rule — payload structs MUST be defined in same GDD
  - (4) Autoload-position ground-truth lock — GDDs MUST cite project.godot line numbers
  - (5) Helper-before-card rule — helpers referenced ≥3× become prerequisite stories
- Project rule codified: **"Inline same-session approval is forbidden for cards touching ≥2 pillars OR ≥3 systems OR formula-bearing milestones"** (#15 + #26 empirical validation)
- Pillar substrate post-fix: P1 anti-fabrication 第七件套 restored (F-1 epoch=0 guard closes the "cosplay" leak) / P4 specialist build mechanically honored (F-2 max_single_class_tier path) / P5 weekly cadence delivered (F-3 micro-evolution layer + F-13 #29 dependency producer escalation tracked) / P2 silhouette-first preserved (F-7 + F-8 + F-6 protect cooldown integrity)
- Prior verdict resolved: **Yes — Pass 1 inline APPROVED RESCINDED 2026-05-28; Pass 2 inline-fixed 13 BLOCKING items pending Pass 3 fresh-session re-verification**
- Next action: `/clear` → fresh-session `/design-review design/gdd/avatar-renderer.md` Pass 3 for independent verification of Pass 2 inline F-1..F-14 resolutions; OR direct progression to `/gate-check pre-production` if user accepts Pass 2 inline + Pass 3 deferral risk + F-9/F-13 followup-tracked items

## Review — 2026-05-28 — Verdict: MAJOR REVISION NEEDED (Pass 3 fresh-session re-verification)
- Scope signal: **XL** (cross-cutting concern, 24+ BLOCKING items, 2 pillar-substrate design issues, 3 Godot API unverified items requiring empirical runtime test, 11-deep autoload boot budget concern)
- Specialists: 4 independent fresh-session adversarial — game-designer + systems-designer + qa-lead + godot-gdscript-specialist → creative-director senior synthesis (Opus)
- Blocking items: **24** (game-designer 3 + systems-designer 4 + qa-lead 11 + godot-gdscript-specialist 6) | Recommended: 22 CONCERN
- **5 convergent UNANIMOUS patterns (≥2 specialists)**: (1) Formula 4 missing F-7 REST_BETWEEN_SETS fix ×3, (2) States table AnimationPlayer.pause() ×2, (3) EC-25 AnimationPlayer reference ×2, (4) INV-6 Performance.MEMORY_STATIC ×2, (5) F-6 monotonic clock not propagated to Formula 4 ×2
- Summary: **Pass 2 inline fixes were applied to PRIMARY representations (rule text + new ACs) but NOT propagated to SECONDARY representations (formula code bodies, States table, EC entries, INV entries, Coverage Map, Test Distribution Summary table, variable tables)**. Same anti-pattern as Pass 1→2 at deeper cascade-propagation layer — validated for a **THIRD time** at #26. Most alarming finding: **CR-8 `AnimatedSprite2D.stop()` "pauses-in-place" claim may be LLM hallucination** — historical 4.x behavior is `stop()` resets to frame 0, "pause-in-place" is `pause()`. Pass 2 F-8 fix may be fundamentally wrong, not just incomplete. **Two pillar-substrate design defects** (not just propagation): (a) F-2 specialist path breaks T1 transitive balance symmetry — pure specialist locked at T0 + permanently via CR-12 historical lock, (b) Q-OQ5 NOT actually resolved by F-3 — micro-evolution shader shifts won't pass FT-2 share rate, post-T3 ledger death persists.
- Pillar substrate post-Pass 3: **P1 COMPROMISED** (F-7 incomplete) / **P2 AT RISK** (CR-8 hallucination + micro-evolution invisibility @16×16) / **P4 COMPROMISED** (F-2 specialist gate) / **P5 AT RISK** (Q-OQ5 ledger death post-T3)
- **Creative-director binding judgment**: **DO NOT inline-fix same-session** — would replicate anti-pattern a 4th time. Required workflow: close review session → open dedicated revision session → fix primary-then-secondary representations → `/clear` → Pass 4 fresh-session adversarial re-review. If Pass 4 still BLOCKING → escalate to **v2 rewrite from clean template**.
- **Strengthened project rule (Pass 3 codification — "Avatar Renderer Rule")**: Inline same-session FIX (not just approval) forbidden when ≥2 pillars OR ≥3 systems OR formula bodies present OR >5 BLOCKING items OR secondary-representation drift flagged OR Godot 4.4+ API call (LLM cutoff May 2025, empirical verification mandatory). New required GDD template section: "Representation Map" — track every location each rule/formula/constant appears (primary + secondary) so fixes update all sites.
- Prior verdict resolved: **No — Pass 2 inline fixes verified as incomplete; cascade defects continue at secondary-representation layer**
- Next action: **(A) Open dedicated revision session** (NOT this session) → apply 24 BLOCKING fixes with primary-then-secondary discipline + empirical Godot 4.6 verification for CR-8 / set_frame_and_progress / RENDERING_INFO_TEXTURE_MEM_USED + design work for Q-OQ5 post-T3 progression + F-2 T1 symmetry → `/clear` → Pass 4 fresh-session `/design-review design/gdd/avatar-renderer.md`. **(B) Alternative if revision scope exceeds 50% sections**: rewrite as v2 from clean template using existing CR/AC/Formula as reference material rather than base text.

## Review — 2026-05-28 — Verdict: MAJOR REVISION NEEDED — REJECT inline-fix, BLOCKED on 4 dependencies, v2 fresh-template rewrite required (Pass 4 fresh-session adversarial re-verification)
- Scope signal: **XL** (v2 rewrite + 4 dependency unblocks + Pillar 5 substrate ownership reframe + #29 coordination — producer must reserve independent sprint slot)
- Specialists: 4 independent fresh-session adversarial — game-designer + systems-designer + qa-lead + godot-gdscript-specialist → creative-director senior synthesis
- Blocking items: **16** (game-designer 3 + systems-designer 4 + qa-lead 5 + godot-gdscript-specialist 4) | Recommended: 6 CONCERN
- **Root cause**: **Pass 3 mandate「open dedicated revision session」WAS IGNORED**。GDD header 仍寫「Pass 2 Revised」，Pass 3 嘅 24 BLOCKING 從未被處理。Pass 4 16 BLOCKING 大部分係 Pass 3 carry-over residue (Formula 4 REST_BETWEEN_SETS / AnimationPlayer.pause() / Performance.MEMORY_STATIC / Test Distribution stale) 加 3 個 first-discovery architectural faults (Q-OQ5 substrate failure / Pillar 5 ownership 斷鏈 / CR-8 fundamental API hallucination)。
- **Pass 4 convergent unanimous patterns (≥2 specialists)**:
  1. Test Distribution Summary 41 vs 52 mismatch (systems-designer + qa-lead) — stale Pass 3 carry-over
  2. AnimationPlayer/AnimatedSprite2D API confusion 仍喺 Section States + EC-25 (godot-gdscript + Pass 3 confirmed)
  3. CR-8 `AnimatedSprite2D.stop()` 「pauses-in-place」claim 極可能係 LLM hallucination — historic 4.x `stop()` reset frame=0 (godot-gdscript-specialist NEEDS EMPIRICAL VERIFICATION)
  4. Formula 4 secondary representations 同 CR-9 rule text 衝突 — line 522 + line 530 variable table + example table 三處仍未修
- **Pass 4 first-discovery architectural faults (NOT carry-over)**:
  - Q-OQ5 micro-evolution shader-only (F-3 fix) 冇 silhouette delta — Section E ghost overlay 對比兩張一樣 silhouette → FT-2 ≥30% share rate 必然 fail → Pillar 5 retention 心臟 post-T3 仍然 dead (game-designer BLOCKING)
  - Mirror Moment ceremony spec ownership chain 斷鏈 — Section E detailed composition spec but UI Section B 寫明 #26 唔擁有，#29 Mirror Moment System 仍 Not Started → Pillar 5 PRIMARY substrate 落喺非存在系統 (game-designer BLOCKING)
  - CR-8 `AnimatedSprite2D.stop()` 可能 fundamental hallucination (not just incomplete) — Pass 2 F-8 fix 整條 snapshot mechanism 可能基於錯 API；正確應該係 `pause = true` property (godot-gdscript-specialist BLOCKING)
- Pillar substrate post-Pass 4: **P1 CONCERN** (Formula 4 state gating 未解 + AC-05 un-testable) / **P2 CONCERN** (CR-10 cast window vs gym context mismatch) / **P4 CONCERN** (mini-cutscene fantasy boundary leak risk) / **P5 FAILED** (substrate ownership 斷鏈 + micro-evolution 無 silhouette delta — retention 心臟未跳)
- **Creative-director binding judgment**: **REJECT inline-fix Pass 4 same-session** — 第 4 次 anti-pattern 必須避免。**REJECT dedicated revision session option** — revision surface 已超 50% threshold (16 BLOCKING + 6 CONCERN + Q-OQ5 substrate 重寫 + #29 ownership reframe)，等於重寫但保住舊 doc cognitive baggage。**ADOPT Option (c) + (d) hybrid**: 進入 BLOCKED 狀態，等 4 個 dependency 解決，再開 **v2 fresh-template rewrite session**。Pass 1-3 GDD + review log 保留做 reference material，唔再 patch。
- **Pillar 5 substrate ownership reframe (binding for v2 rewrite)**: #26 binding 必須限縮到「render avatar evolution states」— ceremony composition (9:16 portrait / hero pose / ghost overlay) 整個 spec 搬去 #29 GDD。#26 只 expose `get_evolution_snapshot()` API。否則 Pillar 5 substrate 永遠模糊。
- **4 blockers gating v2 rewrite kickoff**:
  1. **Q-OQ2 GSM contract resolution** — COMBAT_TICK state 存唔存在 (blocks AC-05 + Formula 4 state gating)
  2. **ADR-0006 `connect_for_initial_state` helper implementation story** — blocks Section G code spec + 6 個其他 autoload subscriber
  3. **#29 Mirror Moment ceremony sprint slot 確認** — blocks Pillar 5 substrate ownership reframe
  4. **Godot 4.6 empirical API verification** — `AnimatedSprite2D.stop()` vs `pause = true` 實測 + `set_frame_and_progress()` signature + `RENDERING_INFO_TEXTURE_MEM_USED` enum on Compatibility renderer (blocks CR-8 + F-1 + F-8 整條 snapshot chain)
- Prior verdict resolved: **No** — Pass 3 mandate was ignored; Pass 4 confirms cascade defects persist + architectural faults newly surfaced
- Next action: **DO NOT REVIEW AGAIN until 4 blockers resolved**。Producer escalation: reserve XL sprint slot for v2 rewrite。GDD enters BLOCKED state — no further inline patches。systems-index status 更新為 **MAJOR REVISION NEEDED — BLOCKED on 4 deps, v2 rewrite pending**。

## Resolution Note — 2026-05-28 — **Q-OQ2 (v2 rewrite blocker 1 of 4) RESOLVED — Option C** (NOT a Pass 5 attempt)

> **Explicit framing**: 呢個 entry **唔係 Pass 5 review attempt** — Pass 4 mandate「DO NOT REVIEW AGAIN until 4 blockers resolved」+「no further inline patches」全部尊重。本 entry 純粹係 **resolution work for blocker 1 of 4 (Q-OQ2 GSM COMBAT_TICK contract)** — 提供 v2 fresh-template rewrite 嘅 reference seed text。GDD 仍處於 BLOCKED state，3 個 dependency 未解。

- **Resolution owner**: Frank (architectural call) + creative-director (autonomous mode approval per [feedback_autonomous_decisions])
- **Specialists invoked**: 0 (read-only ground-truth verification from 2 Approved GDDs — no specialist spawn required for a yes/no architectural question)
- **Question recap (Pass 2 F-10 PROMOTED BLOCKING + Pass 4 listed blocker 1 of 4)**: CR-2 + AC-05 reference `COMBAT_TICK` GSM state — does `COMBAT_TICK` exist as GSM enum value? If not, what's the correct signal source for avatar combat animation enter/exit?

### Ground-truth verification (2 source GDDs)

**Source 1 — `design/gdd/game-state-machine.md` line 585-589** (GSM `GameState` enum):
```gdscript
enum GameState {
    BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE,
    REST_PERIOD,                # renamed from EXERCISE_SWITCHING (Decision #3)
    COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED
}
```
→ **`COMBAT_TICK` 不存在**。Combat-bearing states are `COMBAT_ACTIVE` (regular combat) AND `BOSS_ENCOUNTER` (boss combat — Pillar 3 mid-workout euphoria spike per GSM Rule 7)。

**Source 2 — `design/gdd/enemy-director.md`** (#14 Approved 2026-05-27):
- Rule 5 (line 144-146): `signal hit_resolved` / `signal enemy_killed` / `signal combat_metric_anomaly` — **exactly 3 signals**
- AC-07 (line 1220): "enumerate emitted signals THEN 必須**恰好 3 個** signal: `hit_resolved` / `enemy_killed` / `combat_metric_anomaly`；冇 internal/debug signal 洩漏。Rule 5 binding"
- CI lint #3 (line 603): `tools/ci/check_enemy_director_signal_emission.gd` — "Verify exactly 3 signal declarations: hit_resolved / enemy_killed / combat_metric_anomaly — no extras, no missing"
→ **`combat_started` / `combat_ended` 唔存在 AND 不可加** — adding violates #14 Rule 5 + AC-07 + CI lint #3。

**Source 3 — `design/gdd/game-state-machine.md` line 230-231** (architectural precedent):
> "**GameStateMachine → #14 EnemyDirector** (signal-only). GameStateMachine emit `state_changed(from, to, payload)`. EnemyDirector 監聽進入 `CombatActive` / `BossEncounter` 啟動 sub-machine，監聽離開做 cleanup（包括 Rule 7 嘅 boss abort 動畫）。GameStateMachine 從不直接 call EnemyDirector method。"

→ **#14 自己已經 subscribe GSM `state_changed` filtered by `to ∈ {CombatActive, BossEncounter}`** — Avatar Renderer 跟同一 pattern = architectural consistency。

### Resolution — Option C (third path; original Option 2 + Option 3 both invalid)

CR-2 + AC-05 + Section C States rows + Transition Diagram + Section F Animation Specs Table 全部改用 GSM `state_changed(from, to, payload)` signal (已 wired via ADR-006 Contract 6 `connect_for_initial_state` per CR-13)，filter 條件:

- **Combat enter trigger**: `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` — boss combat shares same combat animation per MVP single-sprite scope CR-1 (no separate boss combat anim state)
- **Combat exit trigger**: `from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` AND `to ∉ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` — catches all exit paths: combat→loot_drop, boss→loot_drop, boss→suspended emergency, etc.
- **Casting state return** (CR-2 d): use GSM `current_state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` membership check (sync read, no new signal)

### Architectural benefit
- **Zero cross-GDD blast radius** — #14 signal surface 不郁，#14 Approved GDD 不需要 revise
- **Mirrors #14's own established subscription pattern** — architectural consistency
- **Uses existing wired connection** — CR-13 `connect_for_initial_state` already includes GSM `state_changed`
- **Handles boss combat correctly without separate code path** — `BOSS_ENCOUNTER` triggers combat anim via same handler

### v2 rewrite seed scope (Pass 4 mandate compliance)

呢個 Q-OQ2 resolution 嘅 reference text 已 inline-edit 到 6 處 `design/gdd/avatar-renderer.md` 位置 (CR-2 / AC-05 / States table Idle row / States table Combat row / States table Casting row exit / Transition Diagram / Animation Specs combat row / Q-OQ2 entry header)，目的：
- (i) 確保 v2 rewrite team 有 **canonical resolution text** 可以直接 reference (避免 re-derive from scratch)
- (ii) 確保 read 緊 BLOCKED GDD 嘅人見到 CR-2/AC-05 唔再有 broken `COMBAT_TICK` reference

**重點**: 呢個係 blocker resolution work，**唔係 Pass 5 inline-fix attempt** — Pass 4 mandate「no further inline patches」應用喺 BLOCKING items / CONCERN items / new design fixes，**唔應用喺 unblocking dependency resolution work** (否則 v2 rewrite 永遠開唔到工)。GDD status 仍係 BLOCKED；3 個 dependency 未解；v2 rewrite 未 kickoff。

### Remaining 3 blockers gating v2 rewrite kickoff
- **Blocker 2**: ADR-0006 `connect_for_initial_state` helper implementation story (godot-gdscript-specialist owner — also gates 6 其他 autoload subscribers per Q-OQ8)
- **Blocker 3**: #29 Mirror Moment ceremony sprint slot 確認 (producer escalation — Pillar 5 substrate ownership reframe per Pass 4 CD binding judgment)
- **Blocker 4**: Godot 4.6 empirical API verification (`AnimatedSprite2D.stop()` vs `pause = true` + `set_frame_and_progress()` signature + `RENDERING_INFO_TEXTURE_MEM_USED` enum on Compatibility renderer)

### Files modified this resolution
- `design/gdd/avatar-renderer.md` — 10 surgical edits at Q-OQ2-touched sites only (Status header + CR-2 + States table 3 rows + Transition Diagram + Animation Specs combat row + AC-05 + Q-OQ2 entry; EC-11 verified no change needed)
- `design/gdd/reviews/avatar-renderer-review-log.md` — this entry (Resolution Note, NOT Pass 5)
- `design/gdd/systems-index.md` — #26 row metadata: blocker 1 marked RESOLVED + 3 remaining blockers listed unchanged

### Next action

- Producer to scope blocker 2 + blocker 3 + blocker 4 resolution work
- godot-gdscript-specialist to implement `connect_for_initial_state` helper (also addresses Q-OQ8 / Pass 2 F-9 prereq for ALL #26 stories)
- Once 3 remaining blockers resolved → v2 fresh-template rewrite session (NOT inline patches to current GDD)

## Resolution Note — 2026-06-10 — **Blockers 2 + 3 + 4 (of 4) RESOLVED — v2 rewrite now unblocked** (NOT a Pass 5 attempt)

> **Explicit framing** (same discipline as the Q-OQ2 Resolution Note above): this entry is **blocker-resolution work**, not a Pass-5 review or an inline GDD fix. The Pass-4 mandate「DO NOT REVIEW AGAIN until 4 blockers resolved」+「no further inline patches」is fully respected — **zero edits to `avatar-renderer.md` in this entry**. With this note, all 4 v2-rewrite blockers are cleared and the GDD can transition BLOCKED → ready-for-v2-fresh-template-rewrite.

- **Resolution owner**: Frank (architectural call) + autonomous mode per [feedback_autonomous_decisions] / [feedback_auto_advance]
- **Trigger**: Godot Engine is now installed locally (Steam **4.6.3-stable**) — the original hard blocker (no engine → no empirical API test) is removed. Blocker 4 became actually executable for the first time.

### Blocker 2 (of 4) — ADR-0006 `connect_for_initial_state` helper implementation — ✅ RESOLVED
- Ground truth: `func connect_for_initial_state(callable: Callable)` is **defined** at `src/autoload/game_state_machine.gd:271` and **consumed by 18+ shipped autoloads** (stat_system / ability_system / enemy_director / attention_budget / login_shell_coordinator / inventory_ui_coordinator / loot_reveal_coordinator / … grep-verified). The entire Foundation tier shipped since 2026-05-28, including this helper (ADR-0006 Contract 6). The Pass-2 F-9 / Q-OQ8 prerequisite is satisfied by existing production code — no new helper story required for #26.

### Blocker 3 (of 4) — #29 Mirror Moment ceremony sprint slot / ownership reframe — ✅ RESOLVED (design-binding)
- The Pass-4 **Pillar-5 substrate ownership reframe** is binding and is now codified in **ADR-0010 (Proposed)** — *Mirror Moment Ceremony Ownership Split*: **#26 owns visible avatar state + evolution-tier + `get_evolution_snapshot()` / hook API (render-only); #29 owns the weekly ceremony** (cadence + non-workout gate + reveal + screenshot prompt + celebration VFX), one-directional dep #29→#26. systems-index #29 row = MVP screenshot-only, Polish tier, deps {17,18,26}. The v2 rewrite of #26 is therefore **slimmed** (ceremony composition spec removed — it migrates to the #29 GDD). Sprint sequencing: #26 v2 rewrite → #29 GDD authoring are a coupled pair (the Pillar-5 substrate completion), #29 GDD is the home for the migrated ceremony spec. No further producer escalation needed — the ownership question is answered by ADR-0010.

### Blocker 4 (of 4) — Godot 4.6 empirical API verification — ✅ RESOLVED (empirical, locally executed)
Run headless on Godot 4.6.3-stable. Full evidence + reproducible probe script: `production/qa/evidence/avatar-renderer/blocker4-empirical-api-verification.md` (+ `blocker4_api_probe.gd`).

1. **`AnimatedSprite2D.stop()` "pauses-in-place" (CR-8) = CONFIRMED HALLUCINATION.** Empirically: `stop()` → `frame == 0` (RESETS); `pause()` → `frame` held (PAUSES in place); `pause()` **is a real method** in 4.6.3. The F-8 snapshot chain must be rebuilt on **`pause()`**, not `stop()`. (Pass-4's "`pause = true` property" wording also corrected: it is a **method**.)
2. **`set_frame_and_progress(frame: int, progress: float)` = CONFIRMED EXISTS** (ClassDB method-list introspection).
3. **Texture-memory monitor**: correct enum is **`Performance.RENDER_TEXTURE_MEM_USED` (15)** / **`RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED` (3)** — both present in 4.6.3. Original GDD `Performance.MEMORY_STATIC` (=4, total static mem, not texture) is wrong → INV-6 corrected to `RENDER_TEXTURE_MEM_USED`. **Caveat**: verified on Vulkan desktop; meaningful value on **Compatibility/WebGL2** web backend stays a **VS-tier** empirical item → **Q-OQ11 remains open as a VS-tier gate** (enum name now verified, code can be written correctly regardless).

### Net status
- **All 4 v2-rewrite blockers RESOLVED**: 1 (Q-OQ2 Option C, 2026-05-28) · 2 (cfis shipped) · 3 (ADR-0010 ownership split) · 4 (empirical API, 2026-06-10).
- These ground-truth facts become **canonical reference seed** for the v2 fresh-template rewrite (alongside the Q-OQ2 Option-C seed text). The current Pass-1..4 `avatar-renderer.md` stays **reference material — NO further inline patches**.
- systems-index #26 row status updated: BLOCKED-on-4-deps → **ready for v2 fresh-template rewrite (all 4 deps RESOLVED 2026-06-10)**.

### Next action
- Open **v2 fresh-template rewrite session** for `design/gdd/avatar-renderer.md` (fresh-template, slimmed render-only scope per ADR-0010; Q-OQ2 Option-C + Blocker-4 empirical facts as seed; Representation-Map section mandatory per Pass-3 "Avatar Renderer Rule"). Then `/design-review` Pass 5 fresh-session adversarial verification.
- Author **#29 Mirror Moment GDD** (MVP screenshot-only) as the home for the migrated ceremony spec — coupled pair with #26 v2.
