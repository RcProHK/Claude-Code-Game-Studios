---
name: project-gym-mode-hud-visual
description: #20 Gym-Mode HUD visual identity contract — fantasy, locked constraints, what #20 owns vs defers
metadata:
  type: project
---

#20 Gym-Mode HUD = Pillar 2 PRIMARY owner; 做gym set期間唯一持續顯示嘅 game UI overlay. GDD skeleton-staged at `design/gdd/gym-mode-hud.md`.

**Fantasy:** 「餘光戰報 The Glance Dispatch」+「沉默見證者 Silent Witness」— 餘光0.3秒接收, 絕不搶mid-set注意力, 事件驅動motion, 零祈使句, 視覺即聲音. 主雷 = 「焦慮儀表板」(anxiety dashboard).

**Why:** Pillar 2 無壓力陪伴 — 玩家舉鐵時用眼角掃畫面, HUD唔可以搶中央焦點 (現實世界).

**Locked constraints:** HUD=高飽和amber-gold, HP/EXP ≤0.3s glanceable. world_desaturation=0.7. `hud_shakes_with_world=true` (HUD跟shake, 文字shake期間仍可讀). MSDF font + thick outline. 事件驅動motion only — 禁idle抖動 (silent-mode banner脈動係唯一豁免, 因banner非HUD element). Silent-mode banner脈動: amber alpha base 0.7±0.1 period 2s, 非scale. icon_flash_duration=0.6s one-shot→退L3 ambient. Dim states: DISCONNECTED base_dim 0.5 / SUSPENDED freeze-dim ×0.7 / LOOT_DROP defer dim.

**HP = MAX_HP身體力量顯示 (NON-depleting bar)** — 唔係血量消耗條.

**Ownership boundary:** Loot ceremony 唔屬#20 (屬#21 loot modal); #20喺LOOT_DROP主動defer/dim. #20係audio-trigger consumer (visual×audio co-trigger), audio palette由#4 own.

**How to apply:** spec #20 visual events要服務glanceability但唔搶焦點; amber張力點=飽和度high但motion克制(event-driven, settle快). 引用art-bible §3.C/§3.D (HUD shape grammar + attention hierarchy), §7.A (frameless), §7.D (Snap+Settle), §4.E (mood override). See [[art-bible-structure]].
