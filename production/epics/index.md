# Epics Index

Last Updated: 2026-06-08 (+ **#24 Login/Shell — 第四個 Presentation epic**; GDD REVISED+cold-verify + UX spec APPROVED 2026-06-08 同日; PR-EPIC degraded inline REALISTIC w/ 7 binding directives [單一 epic; baseline 16–20; story 001 = G-LS-6 iOS spike; G-LS-1+2 ADR amendment scaffold 前提; G-LS-3 claim signature+cancellation = login form 前 blocking; per-gate combined CI; formula stories early]) — prior: #22 Character Screen 2026-06-07
Engine: Godot 4.6 (Web Export, Compatibility Renderer)
Created by: /create-epics Foundation + Core (16 systems); #10 Exercise→Class Mapping promoted Placeholder→Ready 2026-06-02; #4 Audio Manager promoted Placeholder→Ready 2026-06-02 (GDD Approved Pass 6 + ADR-0008 Accepted); **#20 Gym-Mode HUD (first Presentation epic) created 2026-06-03** (GDD R8 APPROVED + UX spec APPROVED); **#33 Attention Budget promoted Placeholder→Ready 2026-06-04** (GDD Approved re-review pass 2 + ADR-0006/0008 Accepted)

> **Implementation order**: Foundation layer first (pos 1→10 boot order), then Core layer.
> **Critical pre-requisites before any stories start**:
> - ADR-0007 Class Enum Naming Convention (blocks #12 + #14 class-archetype stories)
> - ADR-0008 Autoload Full Position Registry (blocks #4 + #10 + #33 placeholder epics)
> - ADR-0002 + ADR-0004 **full** ratification (data contract + topology Accepted 2026-05-31; **live-transport/CORS empirical validation still gated** — blocks #2 GymSys live-HTTP stories)
> - `/create-control-manifest` (no control-manifest.md exists — required before /create-stories)
> - `/design-review design/gdd/loot-drop-system.md` Pass 3 (before /create-stories loot-drop-system)

---

## Foundation Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [PersistenceLayer](persistence-layer/EPIC.md) | Foundation | #3 | persistence-layer.md ✅ | **16 stories** (15 Ready, 1 Blocked ADR-0003) | Ready — **START HERE** (pos 1, all others depend on it) |
| [Game State Machine](game-state-machine/EPIC.md) | Foundation | #1 | game-state-machine.md ✅ | **17 stories** (16 Ready, 1 Complete) | Ready — Story 010 already done (Foundation chain) |
| [GymSys Backend Client](gymsys-backend-client/EPIC.md) | Foundation | #2 | gymsys-backend-client.md ✅ | Not yet created | **Blocked** — ADR-0002 + ADR-0004 Proposed |
| [Particle System Wrapper](particle-system-wrapper/EPIC.md) | Foundation | #5 | particle-system-wrapper.md ✅ | **9 stories** (8 Complete CI-green, 1 Blocked: 009 ADR-0001 CPU ratification) | **Implemented 8/9** — CI-green 1220/1221 (2026-06-01); 009 perf-gated (VS hardware) |
| [Screen Effects System](screen-effects-system/EPIC.md) | Foundation | #6 | screen-effects-system.md ✅ | **11 stories** (10 Complete CI-green, 1 Blocked: 011 ADR-0001 hw) | **Implemented 10/11** — CI-green 1266/1267 (2026-06-01); 011 perf-gated (VS hardware) |
| [Camera System](camera-system/EPIC.md) | Foundation | #7 | camera-system.md ✅ | **12 stories** (10 Complete CI-green, 011 Blocked #22, 012 Blocked ADR-001 hw) | **Implemented 10/12** — CI-green 1312/1313 (2026-06-01); 011 (#22 GDD) + 012 (VS hardware) gated |
| [Streak System](streak-system/EPIC.md) | Foundation | #8 | streak-system.md ✅ | **10 stories** (all Complete CI-green) | **Complete 10/10** — CI-green 1321/1322; 009 (AC-39 CI) + 010 (AC-37 retro + Story 002 drift-gate directional fix) closed 2026-06-01; AC-38 deferred (VS-tier) |
| [Audio Manager](audio-manager/EPIC.md) | Foundation | #4 | audio-manager.md ✅ Approved 2026-06-02 (Pass 6) | **9/9 Complete** ✅ (local-verified — 6 Logic, 3 Integration) | **✅ INTERNAL COMPLETE 9/9** — 001-009 done 2026-06-02 (gateway/bus/sfx/ducking/BGM crossfade/GSM/unlock/SUSPENDED/rotation; local GUT audio 66/66, full gate 241scr/1466t/0fail). Branch feat/audio-manager-story-001 (9 commits) pushed; awaiting PR + CI merge. 3 external gates (EG-1 #9 / EG-2 #20 / EG-3 #15) story-level, don't block epic close |

## Core Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [Stat System](stat-system/EPIC.md) | Core | #11 | stat-system.md ✅ | **13 stories** (12 Complete, 1 Blocked ADR-003+ADR-005) | **Complete 12/13** — CI green 343/343 (PR #5 merged 2026-05-30) |
| [Ability System](ability-system/EPIC.md) | Core | #12 | ability-system.md ✅ | **10 stories** (9 Complete, 1 Blocked ADR-002+ADR-003+#10) | **Complete 9/10** — CI-green 104/104 (verified 2026-06-01); merged PR #6 2026-05-30 |
| [Combat Resolver](combat-resolver/EPIC.md) | Core | #13 | combat-resolver.md ✅ | **10 stories** (8 Complete, 2 Blocked) | **Complete 8/10** — CI-green 90/90 (verified 2026-06-01); merged PR #7 2026-05-30 |
| [Enemy Director](enemy-director/EPIC.md) | Core | #14 | enemy-director.md ✅ | **24 stories** (20 Ready, 4 Blocked) | Ready — 001 START HERE; 021 Blocked (art); 022 Blocked (hardware); 023 Blocked (#9 WST); 024 Blocked (ADR-0001 CPU) |
| [Workout State Tracker](workout-state-tracker/EPIC.md) | Core | #9 | workout-state-tracker.md ✅ | **12 stories** (11 Complete, 1 Blocked: 011 ADR-0002-transport/#14) | **Complete 11/12** — 012 done mock-scoped (GUT local: Story 012 13/13, WST integ 27/27 + unit 85/86; CI verify on push); 011 needs #14 + live transport |
| [Loot Drop System](loot-drop-system/EPIC.md) | Core | #15 | loot-drop-system.md ✅ Pass 2 | **15 stories** (12 Ready, 3 Blocked #2/#9/#14) | Ready — ADR-0005 Accepted 2026-05-30 |
| [Exercise → Class Mapping](exercise-class-mapping/EPIC.md) | Core | #10 | exercise-class-mapping.md ✅ Approved 2026-06-02 | **5 stories** (001 ✅ Complete CI-green, 002-005 Ready) | **In progress 1/5** — 001 done CI-green 2026-06-02; ADR-0007/0008/0003 Accepted; 2 cross-system close-gates (Q5 #9 patch + entities.yaml 7-member) |
| [Attention Budget & Interaction Policy](attention-budget-policy/EPIC.md) | Core | #33 | attention-budget-policy.md ✅ Approved 2026-06-04 (pass 3) | **6/6 Complete** | **✅ IMPLEMENTED** — 6/6 stories CI-green 2026-06-04 (attention-budget 93/93; combined 1685/0 fail). Hybrid + B1 sentinel + LOOT_DROP ceremony lock + CI lint (GSM owner-exempt). Deferred: AC-06→#20, AC-15/18b→#8/#28; Story 001 AC-21 assert-fires test-debt. ★ Pillar 2 PRIMARY |

## Feature Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [Boss System](boss-system/EPIC.md) | Feature | #16 | boss-system.md ✅ APPROVED 2026-06-05 (Pass 11 — STRUCTURAL FREEZE lifted) | **15 stories** (9 Logic, 6 Integration; Ready) | **✅ MERGED** — 15/15 implemented + CI-green, merged main PR #19 (5d03ad7) 2026-06-06. Pillar 3 PRIMARY climax. |
| [Equipment & Inventory](equipment-inventory/EPIC.md) | Feature | #17 | equipment-inventory.md ✅ APPROVED 2026-06-06 (Pass 3 — 3-pass same-day, 零 phantom) | **16/16 Complete** ✅ (13 Logic, 3 Integration; 42/42 ACs) | **✅ MERGED** — CI-green, merged main PR #21 (b7ded42) 2026-06-06。Same-day full pipeline: GDD 3-pass APPROVED → epic → 16 stories → implemented → local combined gate green (1843/1844) → CI green → merged。InventorySystem autoload live (Stat ≺ Inventory ≺ LootDrop)。Salvage-only MVP; derived-keys-only; #11 G-2 APIs shipped。Deferred: AC-32b VS-tier / G-7 / G-8 / UI tiers。Pillar 3 歸宿 + Pillar 1 AntiSnowball 護欄 |
| [PR Detection & Avatar Progression](pr-detection/EPIC.md) | Feature | #18 | pr-detection.md ✅ APPROVED 2026-06-06 (Pass 3 — 同日三 pass, 0 phantom) + **ADR-0011** | **14/14 internal Complete** ✅(015 EXTERNAL G-PR-1)| **✅ IMPLEMENTED 2026-06-06** — 同 session full pipeline(GDD 三 pass APPROVED → epic → 15 stories → implemented;gate 295/1913/1912/0 fail + 53 lints;bonus 修復 phantom-pass test_rule6_zero_input)。INV-PR-1/2 invariants; D7 rep-clamp; D8 soft-confirm; `pr.state` envelope。Cross-epic: G-PR-5 (#12 四件套, 先於 integration story) / G-PR-2 (#9, AC-22 BLOCKED-ON) / G-PR-6 (#3 namespace) / G-PR-3+CI whitelist (wiring story)。G-PR-1 = EXTERNAL (GymSys backend; INV-PR-1 fail-closed 令 client 可先 ship)。★ Pillar 1 PRIMARY 入口 |
| [Zone System](zone-system/EPIC.md) | Feature | #19 | zone-system.md ✅ APPROVED 2026-06-06 (Pass 3 — 同日三 pass, 0 phantom) | **8/8 Complete** ✅ | **✅ IMPLEMENTED 2026-06-06** — 同 session full pipeline(GDD 三 pass APPROVED → epic → 8 stories → implemented;gate 299/1930/1929/0 fail)。薄容器 S-M:training-day count (monotone `<=` guard) + `zone.state` envelope + boot sweep + ceremony_pending queue + lateral loot contract。G-Z-1 同 G-PR-3 共用 ADR-0008 amendment story;G-Z-3 (#3 namespace) 同 G-PR-6 共用 lint 面;AC-08 typed-array round-trip = codebase 首例。EG-4 (#8 streak reachability) 獨立 track 唔 block |

## Presentation Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [Gym-Mode HUD](gym-mode-hud/EPIC.md) | Presentation | #20 | gym-mode-hud.md ✅ APPROVED (R8 2026-06-03) + UX spec ✅ APPROVED | **11 stories** (5 Logic, 5 Integration, 1 Visual/UI) | **Ready** — ⚠️ sprint-entry gated: AC-V-1 playtest (external, Story 011) + dep-gates (#33/#8/#2-GDD/#21/Q-OQ12) w/ fallback ACs (S5/S6/S3). Self-contained Logic 001-004/008/009 先做. Governing ADR-0001 (HIGH) + ADR-0006. ★ Pillar 2 PRIMARY owner |
| [Loot Drop Modal](loot-drop-modal/EPIC.md) | Presentation | #21 | loot-drop-modal.md ✅ APPROVED (Pass 3 2026-06-06, 0 phantom) + UX spec ✅ APPROVED | **27 stories — 26 ✅ Complete + 027 protocol** | **✅ INTERNAL COMPLETE**(2026-06-07 單日 pipeline;gate 2101/2100/0 fail;AC-78 BLOCKED-ON #20;manual evidence EXTERNAL)— `LootRevealCoordinator` autoload (tail, G-LM-5)。94 ACs (71 unit ungated 先行; 23 gated 有 fake-seam); 10 cross-system gates G-LM-1..10 全部 epic 內 stories (CD 順序: doc-only 1/5/7 → G-LM-4 critical path → parallel 3/10/8+9); G-LM-3 拆 2 + G-LM-4 拆 2–3 (producer 指令); 4 組 upstream errata 隨 gate stories。Governing ADR-0001 (HIGH) + 0005/0006/0007/0008/0009。★ Pillar 3 signature ritual |
| [Character Screen](character-screen/EPIC.md) | Presentation | #22 | character-screen.md ✅ APPROVED (2026-06-07 同日兩 pass, 0 new phantom) + UX spec ✅ APPROVED | **20/20 ✅ Complete** | **✅ INTERNAL COMPLETE**(2026-06-07 單 session GDD→UX→epic→20 stories;gate 336scr/2247/2246/0 fail + 7 lints PASS;G-CS-1..11 全落地;camera story 011 連帶 Complete;deferred = manual evidence protocol / AC-49 GATED / UI skin ← /asset-spec) — `CharacterScreenCoordinator` autoload + CanvasLayer 60 PAUSABLE (G-CS-8 tail)。57 ACs (50B=11L+39I / 6A / 1 GATED); 11 cross-system gates G-CS-1..11 全部 epic 內 stories (G-CS-7+8 ADR revisions = scaffold 前提; G-CS-10 contract-pin, AC-12 GATED; G-CS-1 先行 loadout/picker)。PR-EPIC REALISTIC inline (baseline 16–22)。Governing ADR-0001 (HIGH) + 0003/0006/0007/0008/0009。★ Pillar 1 retention surface(門框刻度)|
| [Inventory UI](inventory-ui/EPIC.md) | Presentation | #23 | inventory-ui.md ✅ APPROVED (2026-06-07 同日全 pipeline, 0 phantom) + UX spec ✅ APPROVED | **18 stories** (1 Logic, 15 Integration, 2 Config/Data) | **Ready** — `InventoryUICoordinator` autoload + CanvasLayer 61 PAUSABLE (G-IU-2 tail after #22; NO-#22-constraint);FSM fork #22 (extraction 留 #24)。37 ACs (33B=3L+30I / 3A / 1 GATED; G-IU-1 run-level blocks 全 integration); 5 cross-system gates G-IU-1..5 全部 epic 內 stories (G-IU-2 = story 001 scaffold 前提; G-IU-1 最早 code story; G-IU-5 #22-churn 單 story 管控)。PR-EPIC REALISTIC degraded inline (baseline 14–18)。Governing ADR-0001 (HIGH) + 0003/0006/0007/0008/0009。★ Pillar 1 收據庫(儲物房)|
| [Login / GymSys Connection UI (Shell)](login-shell/EPIC.md) | Presentation | #24 | login-gymsys-connection-ui.md ✅ REVISED+cold-verify (2026-06-08 fresh /design-review NEEDS REVISION→REVISED inline) + UX spec ✅ APPROVED (2026-06-08) | **19 stories** (2 Logic, 11 Integration, 2 Static-CI, 4 Config/Data/doc/spike) | **Ready** — `LoginShellCoordinator` autoload + 2 CanvasLayer (LoginShellLayer **62** PAUSABLE + ErrorBannerLayer **111** ALWAYS;G-LS-2 tail after #23)。56 GDD ACs (39B=11L+25I+3CI / 10 GATED / 6A / 1 EXTERNAL) + 11 AC-UX (9 measure / 2 visual; AC-UX-4 GATED)。9 cross-system gates G-LS-1..9 全部 epic 內 stories (**story 001 = G-LS-6 iOS spike HIGH**;G-LS-1+2 ADR amendment = scaffold 前提;G-LS-3 claim signature+cancellation = login form story 前 blocking;G-LS-3/4/8/9 errata cluster mock-scoped 先行)。PR-EPIC REALISTIC degraded inline (baseline 16–20;現 19)。Governing ADR-0001 (HIGH) + 0002/0004/0006/0003/0009。★ Pillar 1 anti-lie 收口 + Pillar 2 守護者(肯認衰嘅守門人)|

---

## Summary

| Metric | Count |
|--------|-------|
| Total epics | 24 (16 Foundation+Core + 4 Feature + 4 Presentation) |
| Ready (GDD Approved) | 23 |
| Blocked (ADR Proposed — stories auto-blocked) | 1 (#2 GymSys — ADR-0002/0004 transport VS-gated) |
| Placeholder (no GDD) | 0 |
| Pending GDD approval | 0 |

---

## Recommended Implementation Sequence

```
Phase 1 — Foundation ADR-0006 (already Accepted):
  1. /create-stories persistence-layer      → implement PersistenceLayer (pos 1 root)
  2. /create-stories game-state-machine     → Rule 2 full transition + Contracts 1/2/3
  3. /create-stories streak-system          → closed API + milestone thresholds

Phase 2 — After ADR-0007 written + Accepted:
  4. /create-stories stat-system            → closed mutation API + VOLUME_TICK
  5. /create-stories ability-system         → PR breakthrough unlock chain
  6. /create-stories combat-resolver        → stateless pure-function damage math
  7. /create-stories workout-state-tracker  → dominant_class + set_progress

Phase 3 — VS spike (ADR-0001 hardware verification):
  8. /create-stories particle-system-wrapper → pool + 9 presets + mobile tier
  9. /create-stories screen-effects-system  → Trauma² shake + hit pause
 10. /create-stories camera-system          → follow + focal modes

Phase 4 — After ADR-0002 + ADR-0004 ratified:
 11. /create-stories gymsys-backend-client  → HTTP polling + session lock

Phase 5 — After #9 + #13 + #14 + #15 GDD pass:
 12. /create-stories enemy-director         → wave archetype + boss anchor
 13. /create-stories loot-drop-system       → rarity formula + ceremony budget
```

---

## Next Steps

1. Run `/create-control-manifest` — generates `docs/architecture/control-manifest.md` (required before /create-stories)
2. Run `/architecture-decision "Class Enum Naming Convention"` — ADR-0007 (unblocks #12 + #14)
3. Run `/create-stories persistence-layer` — first implementable epic
