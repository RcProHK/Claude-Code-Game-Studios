# Epic: Character Screen (#22)

> **Layer**: Presentation(第三個 Presentation epic — 「門框刻度」review + 控制 surface)
> **GDD**: design/gdd/character-screen.md(✅ APPROVED 2026-06-07 — 同日兩 pass:Pass 1 full 7-specialist + CD NEEDS REVISION → consolidated fix pass → 3-verifier re-pass 0 new phantom → CD sign-off)
> **UX Spec**: design/ux/character-screen.md(✅ APPROVED 2026-06-07 — /ux-review 0 blocking / 3 advisory 已修;stories 引用 UX spec,唔直接 cite GDD UI 細節)
> **Architecture Module**: `CharacterScreenCoordinator` autoload @ `src/autoload/character_screen_coordinator.gd`(thin Node;持有 CanvasLayer **60**(PAUSABLE),pre-warm `visible=false` — GDD Rule 34,跟 #21 LootRevealCoordinator pattern;>50 #20 HUD / <100 BackBufferCopy capture(ADR-0001 L107+L122)/ <110-120 #21)。Autoload 位置:tail append 喺 LootRevealCoordinator 後(#28 keep last)— G-CS-8 ADR-0008 amendment;predecessor constraints `{GSM(C6), StatSystem, InventorySystem, AvatarRenderer, ScreenEffects, CameraController, PlatformDetect, AudioManager, PersistenceLayer} ≺ #22`
> **Status**: ✅ **INTERNAL COMPLETE 20/20**(2026-06-07 單一 session full pipeline:GDD 兩 pass APPROVED → UX spec APPROVED → epic → 20 stories implemented)。**收線 gate:336 scripts / 2247 tests / 2246 pass / 0 fail / 1 pre-existing pending;7 條 CI lints PASS**。G-CS-1..11 全部執行(ADR-0001 layer 60 revision + L107 enumeration / ADR-0008 insertion + project.godot tail / #17 read getters 114/114 / #6 boot-read + preview shake-only 45/45(AC-22 ban scoped amendment)/ #4 catalog 9-cue 表 + linear setter+getter 49/49 / #7 motion_reduction 接線 48/48(AC-06a tripwire 反轉 + AC-21 amendment + L697 erratum;**camera epic story 011 → Complete**)/ namespace + VALID_NAMESPACES / G-CS-5 OQ-1 回寫 / G-CS-6 patterns errata + P-12..16 stubs / G-CS-10 contract pin(AC-12 GATED 持續))。**Deferred/EXTERNAL**(唔 block epic close):manual evidence 收集(protocol @ production/qa/evidence/character-screen/README.md — AC-43b/44/45b/46/47/48)/ AC-49 ADR-0001 RATIFICATION-GATED / UI visual skin(scene 實作)隨 /asset-spec → UI build(Q-CS7 audio assets 同步)/ G-CS-10 真機 validation = GSM story 017 EXTERNAL
> **Stories**: **20/20 ✅ Complete**(3 Logic + 14 Integration + 3 Config/Data;baseline 16-22 內)— QL-STORY-READY degraded inline ADEQUATE(spawn blocked 1M-credit,#17/#18/#21 同款;GDD 57 ACs 3-verifier verified GWT = qa-plan-import-equivalent,直接 embed)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | G-CS-7+8 ADR revisions(layer 60 + insertion)| Config/Data | Ready | ADR-0001+0008 |
| 002 | Coordinator scaffold + CanvasLayer 60 + 登記 | Integration | Ready | ADR-0008+0001 |
| 003 | G-CS-3 namespace + VALID_NAMESPACES + key pin | Config/Data | Ready | ADR-0003 |
| 004 | F1 tween core(injected clock)| Logic | Ready | N/A(pure formula)|
| 005 | F2/F3/F4 + Format Table + font floor | Logic | Ready | ADR-0007(sec)|
| 006 | Watermark Rule 31 | Logic | Ready | ADR-0003 |
| 007 | Lifecycle FSM + force-close + G-CS-10 pin | Integration | Ready | ADR-0006 |
| 008 | Subscriptions(cfis ×2 + #26 plain)| Integration | Ready | ADR-0006 C6 |
| 009 | Stat/avatar binding + breathing freeze | Integration | Ready | ADR-0006+0009 |
| 010 | G-CS-1 #17 additive getters | Integration | Ready | N/A(additive)|
| 011 | G-CS-4 #6 boot-read + preview(shake-only)| Integration | Ready | ADR-0003 |
| 012 | G-CS-9+11 #4 catalog + linear setter | Integration | Ready | N/A(catalog 先例)|
| 013 | G-CS-2 #7 motion_reduction 接線 | Integration | Ready | ADR-0003 |
| 014 | Loadout panel + nudge + badge | Integration | Ready | ADR-0007(sec)|
| 015 | Commands + errors + EC-04 + DISCONNECTED | Integration | Ready | ADR-0006 |
| 016 | Salvage + inspect + modal routing | Integration | Ready | ADR-0007(sec)|
| 017 | Slot picker(virtualized)| Integration | Ready | ADR-0001(sec)|
| 018 | Settings panel + volume | Integration | Ready | ADR-0003 |
| 019 | ARIA + audio assertions + 48px | Integration | Ready | N/A(seam shipped)|
| 020 | G-CS-5+6 errata + evidence protocol | Config/Data | Ready | N/A(doc)|
> **Producer gate (PR-EPIC)**: **REALISTIC with binding directives**(2026-06-07 — degraded inline,spawn blocked 1M-credit,#21 QL 先例)— 維持單一 epic(gate-inside-epic,#17/#18/#21 三重先例);story baseline **16–22**;6 項 binding directives 見「Story breakdown directives」

## Overview

實作 Mirror Hero 嘅 **Pillar 1 retention surface** — 玩家喺 GSM `IDLE`/`DISCONNECTED` 打開嘅全屏「門框刻度」:stat review(7 stats + F1 tween + **first-seen watermark** Rule 31)、loadout 管理(#17 command sink:equip/unequip/lock/salvage + AntiSnowball badge + provenance + 3-zone card entry map)、avatar preview(#26 5 read-only getters + reduce-motion breathing freeze)、同全 game 嘅 Settings panel(P-07 motion / P-08 reduce-motion / **MASTER volume** — #4 L275 contract 兌現)。#22 **唔 own 任何 game data** — 全部經 upstream public API;唯一 #22-owned persist = `charscreen.stat_watermark`(write-once presentation 記錄)。5-state FSM(CLOSED/OPENING/OPEN/CLOSING/FORCE_CLOSING)+ CLOSED 零-subscription invariant + force-close ≤150ms(modal 永不被 system event confirm)。「Formatter 就係 epsilon」原則貫穿 F1-F4(零 overshoot pinned / NaN ingestion guard / settle:=v_target / retarget 限 EQUIPMENT)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0001**: Web Export Budget Caps | CanvasLayer topology;**G-CS-7 revision 對象**(layer 60 PAUSABLE 註冊 + L107 capture enumeration「0/10/50」→「0/10/50/60」— P-07 preview 要 <100 先震到自己);UI Presentation HIGH domain budget;particle = 0 pinned | **HIGH**(Compatibility/WebGL2)|
| ADR-0003: Save State Strategy | `settings.*` + `charscreen.*` keys(G-CS-3 namespace);Private Mode detect-and-gate(persist-fail banner / watermark 唔 render);close path critical flush `write(key, value, true)` | LOW |
| ADR-0006: State Machine Contract | C6 `connect_for_initial_state`(#11 + GSM 兩條;**#26 plain connect** — cfis 對 #26 係 phantom,Pass 1 fix);ghost callv guard(EC-05 ∉{OPENING,OPEN} no-op);handler 內 GSM 行為 `call_deferred` | LOW |
| ADR-0007: Class & Domain Enum Convention | RarityTier display(P-06 badge);AbilityClass posture label | LOW |
| ADR-0008: Autoload Position Map | **G-CS-8 insertion amendment 待做**(本 epic story)— tail append LootRevealCoordinator 後,#28 keep last | LOW |
| ADR-0009: Signal Payload Schema | subscription payload 處理 minimal+intrinsic;#22 自己零 persisted signal payload | LOW |

## GDD Requirements

> #22 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#18/#21 先例一致)。Requirements 由 GDD 直接 trace:**34 Core Rules + 5-state FSM + 4 Formulas(F1 tween[clamp u/retarget qualifier/settle pin]/ F2 quantize+NaN guard / F3 picker total order / F4 badge predicate)+ Rule 31 watermark + 31 ECs + 57 ACs + CD 5 裁決(watermark / MASTER volume / no-reopen / Q-CS8 / layer 60)**,全部有 Accepted ADR cover(上表)。

**Untraced requirements**: None(TR-ID granularity 留 /architecture-review batch)。

**AC 分佈**:**50 BLOCKING**(11 Logic unit:Group A formulas + watermark + 43a font floor / 39 Integration:Group B lifecycle ×10 + C binding ×5 + D commands ×12 + E settings ×8 + F ARIA/audio ×3 + 45a)+ **6 ADVISORY**(manual:43b/44/45b/46/47/48)+ **1 RATIFICATION-GATED**(AC-49 ADR-0001 mobile)。**Gated 標記**:AC-20/31 = G-CS-1 partial-gated(只 `get_loadout`/`get_items_for_slot` 兩隻 getter);AC-12 production validity = G-CS-10 GATED(test 用 mock GSM emit)。Test seam(GDD AC header,binding):**injected clock screen-wide ×6 timing knobs** / process_frame only(禁 wait_frames)/ cfis 禁 .bind() / AC-33(iii) 真 #17 誘發禁 stub / AC-42 positive-control-先行。

## Cross-system gates(G-CS-1..11 — 全部係本 epic 內 stories;#21 G-LM 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-CS-1** | #17 additive read getters:`get_loadout() -> Dictionary`(copy)+ `get_items_for_slot(slot) -> Array[StringName]`(F3 排序 #22 做)| #17 `inventory_system.gd` | code(**AC-20/31 解封者 — 先行於 loadout/picker stories**)|
| **G-CS-2** | #7 story 011 接線:`set_motion_reduction(bool)` setter + boot self-read `settings.reduce_camera_motion`(#7 L697「SettingsManager」措辭 erratum)| #7 camera | code + erratum |
| **G-CS-3** | `settings.*` + `charscreen.*` namespace 註冊(#3 registry + entities.yaml)+ `persistence_layer.gd` L291 `VALID_NAMESPACES` array + **canonical key pin `settings.reduce_camera_motion`** + design/CLAUDE.md path erratum | #3 + registry | code + doc |
| **G-CS-4** | #6 additive:(a)boot self-read `settings.motion_intensity`;(b)preview API `preview_hit_heavy()` — **shake-only,不含 hit_pause**(#22 layer PAUSABLE freeze trap)| #6 `screen_effects.gd` | code(**#6 existing tests 零變紅** parity 準則)|
| **G-CS-5** | #21 OQ-1 回寫:loot-drop-modal.md OQ-1 → RESOLVED(ticker 留 #22 Rule 16)| design/gdd | doc-only |
| **G-CS-6** | interaction-patterns.md errata batch:P-03 sync note(F1 ≠ ticker)+ P-07/P-08 SR narrates 行更新 | design/ux | doc-only |
| **G-CS-7** | **ADR-0001 revision**:layer 60 PAUSABLE 註冊 + L107 capture enumeration update +「P-07 preview <100」mechanism note | ADR-0001 | doc-only(**scaffold 前提**)|
| **G-CS-8** | **ADR-0008 insertion** + `project.godot` 登記(tail append;predecessor constraints)| ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-CS-9** | #4 catalog co-design:9 新 cue(event_id/priority/channels)入 freeze 表 + `SfxCatalog.tres` + `ui_back`/`ui_error` 來源 column 補 #22 + cue naming 慣例裁定 + voice pool 重估 | #4 + SfxCatalog | code(G-LM-8 先例)|
| **G-CS-10** | GSM SUSPENDED emit-path contract:hide-time synchronous delivery pin(唔經 `_process` queue)— **contract-pin story(doc + mock test)**;真機 validation = EXTERNAL(同 GSM story 017 spike);AC-12 GATED 持續 | GSM contract | doc + mock test |
| **G-CS-11** | #4 additive:`set_bus_volume_linear(bus, s)`(或等效)— #22 MASTER slider 禁抄 Formula 2 | #4 `audio_manager.gd` | code |

## Story breakdown directives(PR-EPIC — binding)

1. **G-CS-7+8 做最早 stories**(ADR revisions = scaffold 前提 — layer 60 要 ADR 授權先寫 project.godot);G-CS-5+6 doc-only bundle 一個 story
2. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊)— G-CS-1/4/9/11 amend 已 merged systems
3. **G-CS-10 = contract-pin scope**(doc + mock-level test;真機 EXTERNAL)— 唔開 BLOCKED story
4. **Story 總數 baseline 16–22**(>22 = scope creep 重審;<16 = AC force-compress 重審)
5. **F1 tween core 獨立 early story**(manual interpolator + injected clock seam — Group C/D render 全部依賴)
6. **G-CS-1 先行於 loadout/picker stories**(AC-20/31 gated)

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **57 ACs verified**:50 BLOCKING 全過(11 Logic unit + 39 Integration;AC-12 mock-level + GATED 標記;AC-20/31 喺 G-CS-1 後解封並過);6 manual ADVISORY 有 evidence docs @ `production/qa/evidence/character-screen/`;AC-49 RATIFICATION-GATED 記錄在案
- Combined GUT gate green(per gate story + epic 收線)
- **G-CS-4 落地時 #6 existing tests 零變紅**(parity 準則)
- `CharacterScreenCoordinator` 登記 `project.godot` tail(G-CS-8)+ ADR-0001 revision merged(G-CS-7)
- G-CS-1..11 全部執行(各自 evidence 喺對應 story 收口;Rule 29 boot self-read 驗收屬 #6/#7 story — GDD AC header ownership 行)
- Watermark(Rule 31)write-once + suppress + persist-fail 三翼 unit-tested(AC-55)
- Test evidence:unit `tests/unit/character_screen/` / integration `tests/integration/character_screen/`

## Next Step

Run `/create-stories character-screen` to break this epic into implementable stories.
