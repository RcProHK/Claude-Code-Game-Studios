# Story 023: G-LM-8+9 — #4 cue catalog + process-mode amendment + CI lint

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation(epic)/ 改動喺 Foundation #4
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-8 / G-LM-9 / Visual-Audio §G 表 + silent-mode fallback chain)
**ADR**: ADR-0008(autoload process-mode 屬 boot/registry 面)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(engine pause × audio 互動 — AC-16 spy 結構上驗唔到,要 property assert)

**Control Manifest Rules**:
- Required:cue 經 `play_sfx(event_id)` gateway;catalog freeze 表 + `SfxCatalog.tres` 同步
- Forbidden:per-beat fanfare(D4 — 機關槍 + duck 釘死 + voice pool 洪水)

## Acceptance Criteria(G-LM-8+9 — 解封 AC-76 / AC-76b / AC-28 cue 半句)

- [ ] **G-LM-8 4 新 cue 入 catalog + `SfxCatalog.tres`**:`sfx_loot_shutter_dismiss`(mid/mono/**no-duck** — 儀式錨點唔俾 combat-class 食)/ `sfx_loot_contactsheet_enter`(low/mono)/ stream aggregated cue(low/單 duck handle,≤stream 長度,禁 per-beat fanfare)/ toast tick(low/mono);grid hero-cell sting 條件化(hero 未經 ceremony 先播);`sfx_loot_stash_put` default silent;voice pool concurrency 重估(catch-up 包絡);lint scope 裁決(原 OQ-4)
- [ ] **G-LM-9 process-mode amendment**:AudioManager(或最少 SFX pool players)+ LootRevealCoordinator 本體 `PROCESS_MODE_ALWAYS`(`ceremony_freeze` 用 `get_tree().paused` — PAUSABLE audio freeze 期間 stutter,fanfare 啱起音即停 0.4s 喺 dopamine peak)
- [ ] **`tools/ci/check_autoload_process_modes.gd` lint 新開** + whitelist(未存在 — grep 證實)
- [ ] **AC-76**(#4 fanfare):reveal onset → **#21 coordinator** call `play_sfx(loot_fanfare_{tier})` @ S0 frame(LEG pre-roll 0.1s pre-shake);toast flush → toast tick,**零 fanfare/sting call**(#15 L204 erratum 兌現)
- [ ] **AC-76b**(property assert):AudioManager/SFX pool + Coordinator `process_mode == PROCESS_MODE_ALWAYS`
- [ ] **#4 GDD errata ×2**:catalog source 列 #15→#21 + 新 cue entries / process-mode 記錄
- [ ] **Combined CI gate green**(#4 audio 66/66 零變紅)

## Implementation Notes

- catch-up 全程另落 −4dB sustained 淺 duck(單 handle);per-ceremony fanfare duck 照行(#4 multiset 自然疊加);exit release。
- Silent-mode(LOCKED)fallback chain:`play_sfx` = drop + warn;rarity fallback = badge shape + label + hold;首 session 首 reveal 接受首件靜音(dismiss tap 兼任 unlock gesture)。
- Lint 跟 gateway-lint owner-exempt 教訓(PR #12):grep owner file 防 main RED。

## Out of Scope

- S0 調用序(006 已寫,本 story 解封 AC-76);AC-88 stutter 聽感(027);audio asset 檔案本體(asset-spec flow)。

## QA Test Cases

GDD AC-76/76b GWT + G-LM-8/9 gate text(qa-plan-import-equivalent);AC-28 cue 半句(aggregated cue exactly-once + 單 duck handle)喺 015 tests 解封重跑。

## Test Evidence

**Required**: `tests/unit/audio/test_loot_cues.gd` + `tests/integration/loot_reveal/test_audio_process_mode.gd` + CI lint
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 026、027(AC-88)
