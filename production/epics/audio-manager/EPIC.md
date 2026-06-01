# Epic: Audio Manager

> **Layer**: Foundation
> **GDD**: [design/gdd/audio-manager.md](../../../design/gdd/audio-manager.md) — Designed (pending review) 2026-06-01, lean pass
> **Architecture Module**: AudioManager (autoload pos 11+, `src/autoload/audio_manager.gd`)
> **Status**: GDD authored (pending `/design-review`) — stories still BLOCKED on ADR-0008 Accept (autoload position)
> **Stories**: Cannot be created until GDD reviewed/approved AND ADR-0008 Accepted (Open Question Q5)

## Overview

AudioManager 負責 Mirror Hero 嘅所有音頻 routing、SFX/BGM 播放同音量控制。作為 Foundation infrastructure，佢係 audio bus 嘅唯一 gateway，其他系統只能透過 `play_sfx(event_id)` 同 `play_bgm(track_id)` APIs 觸發音效，唔可直接操控 AudioStreamPlayer2D。訂閱 GameStateMachine `state_changed` 信號做 music transitions（例如 WorkoutActive → BossEncounter 觸發 boss theme）。Mobile Safari 有 audio autoplay restriction，需要在首次 user interaction 後先 unlock。此系統係 MVP tier，唔係 VS 實現目標。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008 (Accepted ✅ 2026-06-01) | Autoload Position Map — AudioManager 置於 Presentation block 頂（~pos 11，around AvatarRenderer）；order-resilient via `connect_for_initial_state` | LOW |
| ADR-0006 Contract 4 (Accepted ✅) | Boot order constraint — AudioManager 必須喺 GSM 之後 boot | LOW |

> ✅ ADR-0008 Accepted（2026-06-01）— autoload placement 已定。GDD 已 authored（Designed，pending review）。**Stories 仲 blocked 直至**：
> 1. `/design-review design/gdd/audio-manager.md`（fresh session）→ Approved
> 2. 確認 Open Question Q3（Web AudioContext unlock 機制）— 影響 unlock story 實作

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| *(未定)* | Audio bus routing — SFX/BGM 分開管理 | 待 GDD |
| *(未定)* | `play_sfx(event_id)` / `play_bgm(track_id)` / `set_volume(bus, db)` public API | 待 GDD |
| *(未定)* | Mobile Safari audio autoplay unlock on first user interaction | 待 GDD |
| *(未定)* | GSM `state_changed` subscription for music transitions | 待 GDD |

> 無 tr-registry.yaml entries — GDD authoring 時由 /architecture-review 填入。

## Definition of Done

This epic is complete when:
- GDD is authored (`/design-system 4`) and passes `/design-review`
- ADR-0008 is written and Accepted (specifying AudioManager autoload position)
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from the future GDD are verified
- Mobile Safari audio unlock tested on target hardware

## Next Step

1. Run `/design-system 4` to author the Audio Manager GDD (MVP tier)
2. Run `/architecture-decision "Autoload Full Position Registry"` for ADR-0008
3. Then run `/create-stories audio-manager`
