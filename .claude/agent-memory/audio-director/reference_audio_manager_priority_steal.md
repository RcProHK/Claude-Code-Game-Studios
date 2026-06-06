---
name: audio-manager-priority-steal
description: "#4 Audio Manager Rule 3 priority-steal 嘅實際保證邊界 — same-priority 之間仍會 steal 最舊,mid 唔係絕對受保護"
metadata:
  type: reference
---

#4 Audio Manager (`design/gdd/audio-manager.md`) Rule 3 priority-aware voice stealing 嘅**實際**保證(grep-verified 2026-06-03,Rule 3 §81-86 + AC-03b §400):

- 保證:**high-priority voice 不可俾 lower-priority steal**(揀 victim 先揀最低 priority)。
- **同 priority 之間:steal 最舊(oldest)**。退化情況:全 pool 同級 → steal 最舊。
- 即 **mid priority SFX 受保護 ONLY 相對 low**;遇到另一個 mid 或 high 嘅 steal pressure,mid voice 仍可被 steal(同級 oldest-victim 或被 high 搶)。

**Why 重要**:任何 downstream consumer(如 #20 WorkoutAudioAdapter)聲稱「#4 priority-steal 保護 `audio_unlock_confirm`(mid)」嘅 rationale,**只在 contention 全部來自 low SFX 時成立**。若 unlock 同幀有第二個 mid(streak_chime)或 high(workout_complete/loot/boss)入 8-voice pool,`audio_unlock_confirm` 仍可被 steal — Rule 3 唔保證 mid 對 mid/high 安全。

**How to apply**:review 任何「priority-steal 自動保護 X」嘅閉合 rationale 前,核對 X 嘅 priority 同預期 contention 嘅 priority 分佈。同級或更高的並發 = 保護失效。catalog priority 真相:`set_complete`=low / `streak_chime`=mid / `audio_unlock_confirm`=mid / `workout_complete`/`loot_fanfare_*`/`boss_*`=high(audio-manager.md catalog freeze §359-374)。

關聯 [[gym-mode-hud-audio-scope]]。
