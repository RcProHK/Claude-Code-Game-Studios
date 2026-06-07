---
name: unlock-gesture-sfx-not-dropped
description: "shipped #4 _input() unlock 行喺 GUI stage 之前 ⇒ 由 gesture 本身觸發嘅 UI SFX 永不被 LOCKED drop;真正 drop class = 非 gesture-triggered call(boot force-reveal 類)"
metadata:
  type: reference
---

Grep-verified 2026-06-07(#22 character-screen audio adversarial review 期間發現):

- `src/autoload/audio_manager.gd` L222-226:`_input(event)` 收到首個 `InputEventScreenTouch`/`InputEventMouseButton` 即 `_do_unlock()`。Godot input 順序 = `_input()` stage **先於** Control GUI stage(`_gui_input`/`pressed`)⇒ 任何「玩家 tap 一個 button → handler call `play_sfx`」嘅 path,執行 `play_sfx` 嗰刻 `_audio_unlocked` 已經 true(L235-240 嘅 LOCKED drop 唔會觸發)。
- 真實現象係:`audio_unlock_confirm`(mid chime,`_do_unlock()` L205)同該 UI cue 同 gesture 疊聲;另有 browser AudioContext async resume 首 frame 可能 clip 兩者(engine-level,非 Rule 5 drop)。
- **真正會被 LOCKED drop 嘅 class** = 非 gesture-triggered 嘅 `play_sfx`(例:#21 L538 boot force-reveal 早於首 gesture — 嗰個 drop 先係真)。

**How to apply**:任何 consumer GDD(#23/#24/#27 等)寫「首 gesture 觸發嘅 open/tap SFX 會撞 LOCKED 被 drop」= 機制錯,要打回(#22 EC-31 係首例)。正確寫法 = 接受 unlock-chime 疊聲 / resume-latency clip。關聯 [[audio-manager-priority-steal]]。
