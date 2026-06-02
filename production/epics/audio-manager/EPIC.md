# Epic: Audio Manager

> **Layer**: Foundation
> **GDD**: design/gdd/audio-manager.md ✅ (Approved 2026-06-02, Pass 6 lean — 6 passes total)
> **Architecture Module**: AudioManager (autoload, `src/autoload/audio_manager.gd`; position per ADR-0008 pos 11+ block)
> **Status**: In Progress — 2/9 Complete
> **Stories**: 9 stories created 2026-06-02 — Story 001-002 Complete (local-verified); 003-009 Ready

## Overview

AudioManager 係 Mirror Hero 嘅 Foundation 層 **audio gateway singleton autoload** — 全 game 所有 SFX 同 BGM 嘅唯一出聲入口。其他系統只能透過 closed API（`play_sfx` / `play_bgm` / `stop_bgm` / `set_bus_volume_db` / `set_bus_muted` / `is_audio_unlocked`）觸發音效，**永不**直接 `new AudioStreamPlayer` 或 mutate `AudioServer`（CI `check_audio_callers.gd` enforced，同 #5/#6/#7 single-gateway posture 一致）。佢管理三條 bus（Master → Music / SFX），透過 `connect_for_initial_state`（ADR-0006 C6）訂閱 #1 GameStateMachine 嘅 state 做 music transition（per-state fade override，含 BOSS_ENCOUNTER 短 fade 強化 stakes、LOOT_DROP-from-BOSS conditional fade-back），並接受 downstream（#5/#6/#8/#15/#25）one-shot SFX co-trigger（priority-aware voice stealing 保 Pillar 3 loot fanfare peak）。關鍵 Web Export constraint：mobile Safari AudioContext 要喺首個 user gesture 之後先 unlock（`_audio_unlocked` 正交 flag，杜絕 LOCKED×SUSPENDED 永久靜音）。音量設定經 #3 PersistenceLayer 持久化（`audio.*` namespace）。玩家唔直接操作 AudioManager，但佢 enable 嘅 audio feedback（loot fanfare dopamine peak、hit 體感印章、streak low-key chime）係 game feel 嘅 *sonic consequence channel*。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008 (Accepted ✅) | Autoload Position Map — #4 AudioManager 插入位（pos 11+ block，project.godot ground-truth） | LOW |
| ADR-0006 C4/C6 (Accepted ✅) | State Machine Contract — Contract 4 sequential autoload boot order + Contract 6 `connect_for_initial_state` sentinel delivery（#4 **消費**，唔實作 atomicity） | HIGH (contract owner risk; #4 consumes stable surface) |
| ADR-0001 (Accepted-structural ✅) | Web Export Budget Caps — SFX voice count web budget + crossfade 2× OGG decode CPU peak（VS-tier profiling 點） | HIGH (CPU numbers Provisional; audio scope light — SFX in-memory ~2.25MB / BGM streamed) |
| ADR-0003 (Accepted ✅) | Save State Strategy — `audio.*` namespace volume/mute 持久化 via PersistenceLayer | MEDIUM |

> **Epic Engine Risk: MEDIUM** — governing ADR 含 HIGH-risk 0006/0001，但 #4 只消費佢哋穩定 contract（C4/C6 boot、budget caps），唔實作。#4 自身 engine risk = Godot 4.6 Web Export **mobile Safari AudioContext unlock**（Q3 已由 godot-specialist resolve：引擎層首 user input 自動 resume suspended context，無需 JavaScriptBridge → 無 ADR-0001 衝突；real-device Safari 驗證 ADVISORY，post-cutoff 未驗）+ crossfade decode CPU peak（VS-tier，最差 ~0.2–0.6ms，fallback = instant-swap）。
> **全部 4 governing ADR 皆 Accepted → 無 ADR-Proposed 自動 block（不同 GSM epic 嘅 ADR-0003-Proposed gate）。**

## GDD Requirements

> tr-registry.yaml 暫無 audio TR entries — #4 同其他純-inherit Foundation system 一樣，9 Rules 大多係 GDD 自有 closed-gateway contract（唔需獨立 ADR；GDD 即 spec）。下表由 GDD Detailed Design 9 Rules 派生，ADR-governed 嗰啲已 trace 到 Accepted ADR。

| TR-ID | Requirement (GDD Rule) | ADR Coverage |
|-------|------------------------|--------------|
| TR-audio-001 | Rule 1: Closed API gateway（8 public func + 2 signal）+ CI lint `check_audio_callers.gd`（full-path EXEMPT_FILES + `AudioStreamPlayer[^\n]*\.bus\s*=` anchor）+ test-seam pure functions（`_register_duck`/`_release_duck`/`_compute_duck_target` + `_voice_busy`/`_active_crossfade_count`/`_crossfade_progress`） | GDD-owned（single-gateway posture，同 #5/#6/#7）✅ |
| TR-audio-002 | Rule 2: Bus topology `Master→{Music,SFX}`，dB volume，default 0 / −6 / 0 | GDD-owned ✅ |
| TR-audio-003 | Rule 3: SFX pool（`SFX_VOICE_COUNT`=8）+ priority-aware voice stealing（high 唔俾 low steal，保 Pillar 3）+ steal 路徑 explicit duck release（防 permanent duck） | GDD-owned；ADR-0001（voice web budget）✅ |
| TR-audio-004 | Rule 4: BGM equal-power crossfade（單一 retained Tween，kill-before-respawn latest-wins，`_crossfade_progress` sentinel `<0`）+ idempotent same-track no-op | GDD-owned；ADR-0001（decode CPU peak）✅ |
| TR-audio-005 | Rule 5: Mobile Safari unlock gate（`_audio_unlocked` 正交 flag；LOCKED×SUSPENDED 共存；`_do_unlock()` idempotent `_input()` fallback + #20 banner canonical；`audio_unlock_confirm` mid-priority） | ADR-0001（web export；Q3 godot-resolved engine auto-resume，Safari ADVISORY）✅ |
| TR-audio-006 | Rule 6: GSM `state→track` map via `connect_for_initial_state`（per-state fade override；BOSS_ENCOUNTER 0.25s；REST_PERIOD→rest_calm；LOOT_DROP-from-BOSS conditional `LOOT_BGM_TRANSITION_SEC` fade-back；sentinel noop） | ADR-0006 C6（sentinel）+ C4（boot order）✅ |
| TR-audio-007 | Rule 7: Ducking（stinger 一律 SFX bus；release 由 `finished`/steal 觸發；單一 retained tween_method lambda-closure + idle gate；`_active_ducks` multiset recompute-on-release de-escalation；SUSPENDED duck-kill hard-set base） | GDD-owned（Formula 3）✅ |
| TR-audio-008 | Rule 8: Foundation no-throw（未知 event_id/track_id → push_warning + no-op + `_unknown_event_count++`；catalog missing → safe no-op 模式） | GDD-owned（Foundation no-throw 家族，同 #5/#6/#7/#8）✅ |
| TR-audio-009 | Rule 9: Volume persistence（`audio.master_db`/`music_db`/`sfx_db`/`*_muted` via PersistenceLayer；boot load + corrupt fallback/clamp） | ADR-0003（`audio.*` namespace）✅ |
| TR-audio-010 | Autoload placement（pos 11+ block per ADR-0008；sequential boot per ADR-0006 C4） | ADR-0008 + ADR-0006 C4 ✅ |

> Formulas: F1 equal-power crossfade gain（instant-swap fade_sec≤0 guard + endpoint hard-set）· F2 slider 0–1→dB（NaN/inf guard + `MAX_BUS_DB` clamp）· F3 ducking target（multiset `min(values())` + empty-dict guard + `MUTE_FLOOR_DB` floor）。
> ACs: 34 ACs（AC-01..AC-34；大多 Logic GUT `tests/unit/audio/`，BLOCKING）。

## Cross-System External Gates (story-level，唔阻 epic 開)

| Gate | 影響 | Owner |
|------|------|-------|
| EG-1 #9 WST patch（`audio_unlocked` subscribe + mid/high SFX buffer/flush + set_complete×streak_chime stagger 80–120ms） | pre-unlock workout SFX forwarding 相關 AC | #9 WST GDD（已 Approved，需 patch）— **與 #10 epic-close gate 重疊** |
| EG-2 #20 Gym-Mode HUD GDD authoring（banner soft-gate；#4 只定 `is_audio_unlocked()` + `audio_unlocked` contract） | banner UX AC（屬 #20，#4 只 contract） | #20 GDD（Not Started） |
| EG-3 #15 LootDrop Pass 3 — confirm boss kill → LOOT_DROP from_state == BOSS_ENCOUNTER | Rule 6 scenario A conditional fade-back AC | #15 LootDrop GDD Pass 3 re-review |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 34 acceptance criteria from `design/gdd/audio-manager.md` (AC-01..AC-34) are verified
- All Logic and Integration stories have passing test files in `tests/unit/audio/` and `tests/integration/`
- CI lint `tools/ci/check_audio_callers.gd` passes with no violations（ban `AudioServer.` / `new AudioStreamPlayer` / `AudioStreamPlayer…\.bus =` outside gateway self-exempt）
- Pure-function duck seam ACs（AC-09/09c/09d/15）pass headless（no wall-clock，no `AudioStreamPlayer.playing` 依賴）
- ADVISORY items（AC-24b OS notification wiring / Q7 real-device Safari AudioContext / Q8 asset craft / Q9 gym playtest）有 evidence doc 或 deferred 標記

## Stories

| # | Story | Type | Status | ADR | Covers AC |
|---|-------|------|--------|-----|-----------|
| 001 | [ci-lints-closed-api-scaffold](story-001-ci-lints-closed-api-scaffold.md) | Logic | **Complete** ✅ (CI-gated) | ADR-0008 (+0006 C4) | AC-01 + seams |
| 002 | [bus-topology-volume-persistence](story-002-bus-topology-volume-persistence.md) | Logic | **Complete** ✅ (local-verified) | ADR-0003 | AC-02/11/13/20/22/23/28 |
| 003 | [sfx-pool-priority-steal](story-003-sfx-pool-priority-steal.md) | Logic | Ready | ADR-0001 | AC-03/03b/10/16/17 |
| 004 | [ducking-formula3-multiset](story-004-ducking-formula3-multiset.md) | Logic | Ready | N/A (GDD F3) | AC-09/09b/09c/09d/15/25 |
| 005 | [bgm-equalpower-crossfade-formula1](story-005-bgm-equalpower-crossfade-formula1.md) | Logic | Ready | ADR-0001 | AC-04/12/18/21 |
| 006 | [gsm-music-transition](story-006-gsm-music-transition.md) | Integration | Ready | ADR-0006 C6 | AC-07/08/32 (情境A ⚠️EG-3) |
| 007 | [safari-unlock-gate](story-007-safari-unlock-gate.md) | Integration | Ready | ADR-0001 | AC-05/06/06b/19a/19b/26/31/32b (⚠️EG-1/EG-2 external) |
| 008 | [suspended-multisource-resume](story-008-suspended-multisource-resume.md) | Integration | Ready | ADR-0006 C4 | AC-14/14b/14c/24a/24b/30/33/34 |
| 009 | [bgm-rotation-min-loop](story-009-bgm-rotation-min-loop.md) | Logic | Ready | N/A (GDD) | AC-27/29 |

**9 stories: 6 Logic + 3 Integration.** All 34 GDD ACs covered。
**Implementation order**（dependency-safe）：001 → 002 → 003 → 005 → 004 → 006 → 007 → 008 → 009

## Next Step

Run `/story-readiness production/epics/audio-manager/story-001-ci-lints-closed-api-scaffold.md` then `/dev-story` to begin implementation.

> 3 external gates（EG-1/2/3）在各自 GDD 軌道處理，唔阻 #4 epic 開或 #4-self stories；只係特定 forwarding/conditional-fade AC（Story 006 情境 A / Story 007 forwarding+banner）喺對應 gate resolve 前標 Blocked（同 #10 cross-system gate 先例）。
