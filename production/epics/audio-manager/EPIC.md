# Epic: Audio Manager

> **Layer**: Foundation
> **GDD**: — (Not Started — Tier: MVP)
> **Architecture Module**: AudioManager (autoload pos 11+, `src/autoload/audio_manager.gd`)
> **Status**: Placeholder — GDD required
> **Stories**: Cannot be created until GDD is authored and approved

## Overview

AudioManager 負責 Mirror Hero 嘅所有音頻 routing、SFX/BGM 播放同音量控制。作為 Foundation infrastructure，佢係 audio bus 嘅唯一 gateway，其他系統只能透過 `play_sfx(event_id)` 同 `play_bgm(track_id)` APIs 觸發音效，唔可直接操控 AudioStreamPlayer2D。訂閱 GameStateMachine `state_changed` 信號做 music transitions（例如 WorkoutActive → BossEncounter 觸發 boss theme）。Mobile Safari 有 audio autoplay restriction，需要在首次 user interaction 後先 unlock。此系統係 MVP tier，唔係 VS 實現目標。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008 (Queued ❌) | Autoload Full Position Registry — AudioManager 確切 autoload position 未定 | LOW |
| ADR-0006 Contract 4 (Accepted ✅) | Boot order constraint — AudioManager 必須喺 pos 11+ boot | LOW |

> ⚠️ 無 GDD — 此 epic 係 **placeholder**，所有 stories blocked 直至：
> 1. GDD 寫好並 Approved（run `/design-system 4`）
> 2. ADR-0008 Autoload Full Position Registry 寫好（指定確切 position）

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
