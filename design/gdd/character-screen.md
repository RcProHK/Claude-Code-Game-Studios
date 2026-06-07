# Character Screen (#22)

> **Status**: In Design(skeleton — fresh-session `/design-system character-screen` 由此 resume)
> **Author**: frank + design-system pipeline
> **Last Updated**: 2026-06-07
> **Implements Pillar**: Pillar 1(stat 對比 —「我喺 gym 做嘅嘢留低咗刻度」)· Pillar 4(class posture 顯示)· 支援 Pillar 3(loadout 管理)

<!-- DESIGN CONTEXT(2026-06-07 pre-load — fresh session 唔使重 grep;全部 grep-verified)

## 上游 forward contracts(BINDING — 全部已 shipped/APPROVED)

### #11 Stat System(shipped)
- #22 = listens + reads on open:`get_stat(stat_id)` on screen open(static initial render)+ `connect_for_initial_state(stat_changed)` live update;**禁 poll、禁掂 internal `_base`**(stat-system.md L260/L586/L725)
- 3 base(STR/DEX/VIT)+ 4 derived(max_hp/attack_power/move_speed/crit_chance)
- `stat_changed(..., EQUIPMENT, _)` → #22 stat number animation 200-400ms ease +「↑/↓」arrow(L696)
- Historical comparison(上週 vs 今週)→ **#22 own snapshot via #28 Telemetry data**(L260 — #28 未 build:design 要裁 MVP 方案[local snapshot vs defer v0.2])

### #17 Equipment(shipped)
- #22 = manual override surface:equip/unequip/`set_lock(item_id,bool)`/salvage command sink(L127);**manual equip 唔受 score 限制但唔 lock 下次 auto-equip 換返** → **UX MUST 露 lock affordance 當 manual equip 較弱件**(L63 forward flag)
- AntiSnowball badge:`get_aggregate_raw_and_effective() -> {raw, effective}` →「+84 / +90(受真身上限約束)」+「練多啲,解放佢嘅全力」ledger voice(L64/L212/L335)
- Loadout:3 functional + cosmetic slot,per-slot equipped item + detail(L345);EC-11 lock 同 frame 永遠贏
- Provenance:`provenance_text` 全 tier(「拾於 6月3日・腿日」;**display timezone = #22 presentation 層 forward flag**)+ LEGENDARY `SourceReceipt.signature_text`(hover/inspect)(L66/L334)
- Craft/upgrade → v0.2 Forge(D5/A1)— #22 MVP 唔出 craft UI

### #18 PR Detection(shipped)
- PR 歷史/baseline 顯示 = **v0.2**(`get_baselines()` read-only copy;pr-detection.md L298/L353)— MVP #22 唔做 PR history panel

### #26 Avatar Renderer(GDD approved)
- Read-only 5 getters(CR-11):`get_visual_state()`(duplicate copy)/`get_class_posture()`/`get_evolution_tier()`/`is_ready_for_milestone_check()`/`get_animation_state()`;subscribe `avatar_visual_updated(state)` live;**NO setters**(L290/L734/L964 content contract 節有完整 spec — authoring 時讀)
- FR-AVATAR-1:AvatarVisualState schema stable — #22 consumption 對齊

### #21 Loot Modal(epic complete)
- **OQ-1 喺 #22 裁**:stat-delta ticker(modal 顯示 equip 前後 stat 變化)需要 #17 equip-result payload API(`receive_loot` 回 enum 冇 stats)— 裁「modal 加 slot vs 留俾 #22 screen」;P-06 rarity 語言共用(pattern 級)

### #7 Camera
- Camera story 011 BLOCKED on #22 GDD(camera-system epic)— grep camera-system.md「#22」確認 binding 內容

### 其他
- P-06 rarity 色/badge 語言(interaction-patterns.md,canonical hex = art bible §4.B)
- accessibility-requirements.md:CJK body 12px Zpix floor;P-07 motion-intensity-slider **住喺 #22 Accessibility Settings section**(interaction-patterns L232 — #22 要 host 個 slider!)
- ADR-0001(UI Presentation HIGH domain)/ ADR-0006 C6 / ADR-0003(#22 如要 local snapshot → namespace 申請 + #3 registry)

## 設計裁決待做(authoring 時 AskUserQuestion / CD)
1. OQ-1 stat-delta ticker 歸宿(#21 modal slot vs #22 screen 顯示)
2. 上週對比 MVP 方案:#28 未有 → local `charscreen.*` snapshot(要 #3 namespace)vs 裁 v0.2
3. Screen 入口/導航(GSM safe states only?Pillar 2 — gym mode 期間入唔入得?)
4. P-07 motion slider hosting + Accessibility Settings section scope
-->

## Overview

[To be designed]

## Player Fantasy

[To be designed]

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
