# Epic: Gym-Mode HUD

> **Layer**: Presentation
> **GDD**: design/gdd/gym-mode-hud.md ✅ APPROVED (R8 fresh-session re-review, 2026-06-03)
> **UX Spec**: design/ux/gym-mode-hud.md ✅ APPROVED (`/ux-review`, 2026-06-03)
> **Architecture Module**: Presentation Layer — persistent HUD overlay (CanvasLayer 50, below ScreenEffects layer 100)
> **System #**: 20
> **Status**: In Progress — 12 stories (001-010 Complete, 011 Partial, 012 Ready). Implementation commit 8df3a8a (2026-06-04). ⚠️ epic-close still gated (see Entry Gates)
> **Stories**: 12 (5 Logic, 5 Integration, 2 Visual/UI) — 001-009/010 self-contained AC done CI-green; 011 visual + 012 scene-build remain

## Stories

| # | Story | Type | Status | ADR | Gate |
|---|-------|------|--------|-----|------|
| 001 | HUD scaffold + 3-state view + GSM boot wiring | Integration | ✅ Complete | ADR-0006 | — |
| 002 | EXP bar + Formula 1/2 + tween core + reduce_motion | Logic | ✅ Complete | ADR-0001 | — |
| 003 | Tween circuit-breaker + handle-map (spike-grounded) | Logic | ✅ Complete | ADR-0001 | — |
| 004 | HP/stat + SkillIconRegistry sort + cluster cap | Logic | ✅ Complete | ADR-0009 | — |
| 005 | #9-validated count/progress + anti-fabrication | Integration | ✅ Complete | ADR-0009/0002 | — |
| 006 | Silent banner + audio-buffer gate + Formula 3 | Integration | ✅ Complete | ADR-0002/0001 | fallback #33 (AC-EC-S5) ✅ |
| 007 | WorkoutAudioAdapter + GSM gate + buffer policy + stagger | Integration | ✅ Complete* | ADR-0002/0009 | AC-CR-9 #2-GDD doc / AC-CR-11 #8 gated |
| 008 | Dim states + DIM_PRODUCT_FLOOR + emphasis alpha + EC-R6 | Logic | ✅ Complete | ADR-0001 | fallback #21 (AC-EC-S3) ✅ |
| 009 | Glance-count CI tool + AC-U-3 + 0px anchor + alpha invariant | Logic/UI | ✅ Complete* | ADR-0001 | cluster-metadata + 0px deferred → 012 |
| 010 | bfcache/resume reconcile + SUSPENDED | Integration | ✅ Complete* | ADR-0006/0003 | S9b ADVISORY BLOCKED Q-OQ12 |
| 011 | Glance playtest (AC-V-1) + a11y + min-floors + REST cockpit + L10n | Visual/UI | ◐ Partial | ADR-0001 | AC-V-1 N=12 playtest + visual sign-off + scene (012) |
| 012 | HUD .tscn scene build + node binding + glance metadata | UI | ✅ Complete | ADR-0001/0006 | — (unlocked 009 metadata + 011 visual base) |

`*` = self-contained AC done CI-green; remaining AC external/cross-system (see Story completion notes).

**Implementation done (001-010 + 011 logic + 012 scene, commits 8df3a8a + follow-up)**: 100 tests, full gate 245 scripts / 1525 pass / 0 fail / 1 pre-existing pending. All self-contained code/logic/scene AC complete.
**Remaining (all external, non-code)**: N=12 glance playtest (AC-V-1) · colorblind/shake human visual sign-off · real art assets (P-04/P-11) · main-scene CanvasLayer 50 mount · 3 cross-GDD doc-gates (#2 Q-OQ5 / #8 Q-OQ1 / Q-OQ12 SUSPENDED producer).

## Overview

Gym-Mode HUD 係玩家做 gym set 期間唯一持續顯示嘅 game UI overlay。佢將三條 **read-only** 數據流——#11 Stat 嘅 HP/EXP/stat、#12 Ability 嘅已解鎖技能、#9 WorkoutStateTracker 嘅 set/workout 進度——composite 成一個高飽和 amber-gold、≤0.3 秒餘光可讀嘅 status overlay,疊喺 desaturated auto-combat 世界之上。玩家**零互動**(Pillar 2 cardinal rule),只用餘光「眼角瞄」。除顯示外,#20 孭起兩個由 #4 Audio EG-2 relocate 落嚟嘅 presentation 職責:**(1) silent-mode unlock banner**(只 gate audio buffer flush,絕不 gate workout 計數/EXP 視覺)+ **(2) `WorkoutAudioAdapter` audio-trigger consumer**(訂 #2 `set_logged` 觸發 SFX,GSM-state-level gate,LOCKED 時 buffer mid/high → unlock flush)。#20 係 PRIMARY owner of **Pillar 2 無壓力陪伴**。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Web Export Budget Caps | 常駐 overlay 疊 combat + GPU particles,須遵兩-tier draw-call/memory/frame budget;CanvasLayer topology;`max_concurrent_tweens=6` burst cap | **HIGH** (web export, persistent overlay) |
| ADR-0006: State Machine Contract | `connect_for_initial_state` sentinel (boot 即收 current value);#20 唔起第二 state machine,作為 external GSM reader 須同步 generation (reconcile generational guard);薄 view 3-state derive GSM | MEDIUM |
| ADR-0009: Signal Payload Schema | #20 consume `stat_changed`/`state_changed`/`set_progress_changed`/`phase_changed`/`ability_unlocked`/`audio_unlocked` payload | LOW |
| ADR-0002: GymSys Integration Protocol | `set_logged` source for `WorkoutAudioAdapter`(audio path only,無 transition_id,server single-flight monotonic dedup) | MEDIUM (transport VS-gated) |
| ADR-0003: Save State Strategy | `banner_dismissed_this_session` 刻意 **non-persisted**(session-scoped gesture,非 user setting);#20 無其他持久化 | LOW |

**Highest engine risk: HIGH** — ADR-0001 web-export persistent overlay。GDD Performance Budget flag(HUD draw-call sub-budget / MSDF font shader 成本 / `max_concurrent_tweens` allocation 峰值)須 `/architecture-review` + technical-artist 實機驗。

## GDD Requirements

#20 係 Presentation/display 系統 —— requirements 由 **GDD ACs + UX spec ACs** 定義,**冇 cross-cutting TR-registry TR-ID**(無 formal architecture TR;display/layout 唔產生新 cross-system contract)。Cross-cutting concern 由 governing ADR(0001 budget / 0006 state contract / 0009 payload)覆蓋。

| Requirement source | 內容 | ADR Coverage |
|-------|-------------|--------------|
| GDD Core Rules CR-1..CR-13 | 雙層資訊架構 / 事件驅動 motion / signal-driven update / state-gated visibility / banner soft-gate / audio consumer / buffer policy / stagger / 數據語意 + sort key / Pillar 2 9 紅線 | ADR-0006 (state) + ADR-0001 (motion budget) |
| GDD Formulas F1-F3 | exp_fill clamp / tween duration reduce_motion / banner alpha 脈動 | self-contained (no ADR) |
| GDD Edge Cases EC-F4/R6/S7 etc. (23) | tween circuit-breaker (spike-grounded) / ◐ skip-tween / glance count CI | ADR-0001 (budget) |
| GDD ACs (~30) + UX ACs (11) | Logic/Integration BLOCKING + Visual/Glance ADVISORY | — |
| `hud_shakes_with_world` knob | HUD layer position toggle (TR-screen-effects, **#6-owned**, #20 referrer) | ADR-0001 ✅ |

**Untraced note**: #20 嘅 display requirements **無 formal TR-ID** —— 屬正常(presentation layer,display-only,唔新增 architecture contract)。Stories 直接 cite GDD AC-ID(AC-CR-*/AC-F*/AC-EC-*/AC-U-*/AC-V-1)+ UX AC-ID(AC-UX-*),非 TR-ID。

## Entry Gates (⚠️ sprint-entry — stories authorable but gated)

呢個 epic 嘅 **stories 可以 author**,但部分 story **入 active sprint / `/story-done` 前**有未滿足 gate:

1. **AC-V-1 BINDING ENTRY GATE**（Player Fantasy 命脈)— glance playtest protocol **已交付**(UX spec,protocol-delivery gate ✅ 滿足),但實際 **N=12 真人 tachistoscope playtest 結果**(point estimate ≥80% × WORKOUT_ACTIVE/BOSS_ENCOUNTER × static/shake 四格 + Likert ≥4/5 + 0px anchor)係 **external human action**,headless 驗唔到。AC-V-1 story 標 **ADVISORY-RESULT / BINDING-DELIVERY**;playtest 未跑 = AC-V-1 CANNOT-VERIFY。
2. **5 dep/gate**（`/story-readiness` 須 re-check）:
   - **#33 Attention Budget**（Not Started)— AC-CR-5 input-gate / AC-CR-13⑦。Fallback **AC-EC-S5**(banner tap 直接 unlock)self-contained 可過。
   - **#8 Streak**（streak signal 未 expose,Prov-3)— AC-CR-9 streak 路由 / AC-CR-11 stagger + correlation key(Q-OQ1)。Fallback **AC-EC-S6**(即播無 stagger)可過;#20 已 spec 兩分支 consumer stub。
   - **#2 GymSys GDD bidirectional**（Q-OQ5)— #2 GDD 須補列 #20 為 `set_logged` subscriber(AC-CR-9 整合測前置)。
   - **#21 Loot Drop Modal**（Not Started)— defer handshake;Fallback **AC-EC-S3**(自 defer,絕不自畫 loot 文字)self-contained 可過。
   - **Q-OQ12 SUSPENDED producer**（#1/platform_detect/TD 缺口)— AC-EC-S9b bfcache wiring 須 upstream `pageshow`→SUSPENDED 落地。
3. **Cross-doc reconcile**（UX OQ-U2)— accessibility-requirements「bitmap m5x7 / font-scaling v0.2+ deferred」vs GDD「MSDF + `text_scale` player-facing knob」須 reconcile（`min_font_size_px=7` 與兩者一致,但 scaling knob MVP 地位待裁)。

**Self-contained stories**（無外部 gate,可先做)涵蓋:F1-F3 formula、tween circuit-breaker(spike-grounded EC-F4/AC-EC-F4b)、glance-count CI tool(`check_glance_tier1_count.gd`,epic 首 story deliverable)、state matrix visibility、banner gate logic、buffer policy、`SkillIconRegistry` tier_ordinal DESC sort、dim product floor — 大部分 BLOCKING Logic AC 自足。

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed (`/code-review`), and closed (`/story-done`)
- All GDD ACs (`design/gdd/gym-mode-hud.md`) + UX ACs (`design/ux/gym-mode-hud.md`) verified
- All Logic/Integration stories have passing test files in `tests/unit/gym_mode_hud/` + `tests/integration/gym_mode_hud/`
- `tools/ci/check_glance_tier1_count.gd` exists + green (CI count gate, AC-U-3)
- Visual/Feel/Glance stories (AC-V-1/V-2/V-5 + AC-CR-1/13⑧) have evidence docs + lead sign-off in `production/qa/evidence/`
- **AC-V-1 glance playtest executed** with passing results (binding entry gate) OR epic explicitly ships with AC-V-1 deferred-and-tracked per user decision
- 5 dep/gates resolved OR their fallback ACs (AC-EC-S5/S6/S3) verified as the shipped path

## Next Step

Run `/create-stories gym-mode-hud` to break this epic into implementable stories (embed GDD AC-IDs + UX AC-IDs + governing ADR guidance + dep-gate / fallback markers per story).
