# Story 014: G-CV-3 #4 AudioManager combat-hit cue contract (consumer-forward)

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(Visual/Audio §Audio direction + Q-CV1)
**Requirement**: `TR-cvf-014`

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)
**ADR Decision Summary**: #25 係 combat-hit SFX 嘅 audio-trigger consumer(per #4 EG-1 — workout/presentation SFX forwarding 落 presentation consumer);#4 own playback + cue catalog,#25 只 trigger。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioManager.play_sfx(event_id: StringName)`(grep-verified audio_manager:235);onset 對齊 visual peak(pause 入 / flash 起 / number peak);silent-mode 下 visual 必須獨立完整可讀。

**Control Manifest Rules (Presentation)**:
- Required: #25 trigger only;cue catalog ownership = #4
- Forbidden: #25 own playback / cue 資源
- Guardrail: consumer-forward(唔 patch #4 GDD;cue catalog errata 隨 gate)

---

## Acceptance Criteria

*From GDD Audio direction + Q-CV1:*

- [x] tier/outcome → `play_sfx`:LIGHT/MEDIUM=`sfx_hit_light` / HEAVY=`sfx_hit_heavy` / CRITICAL=`sfx_hit_critical` / OVERKILL=`sfx_overkill` / KILLED=`sfx_kill` / critical-kill=`sfx_hit_critical`(test_tier_cue_map + test_outcome_cue_map)
- [x] onset 對齊 visual peak:`_play_cue` call 喺各 routing branch 末(flash/pause/number 之後同 frame)
- [x] silent-mode:`_audio` = bare RefCounted 無 play_sfx → visual(flash+number+pool)完整 + 無 crash(test_silent_mode_visual_intact_no_crash)
- [x] **consumer-forward**:cue id consts 喺 #25(trigger 契約);#4 own catalog;unknown id → #4 push_warning no-op(audio_manager:243 Rule 8)→ 唔 patch #4 GDD,cue 資源 land = Q-CV1 erratum
- [x] mock `AudioManager` spy(FakeAudio.cues)各 tier/outcome 對應恰好 1 次 `play_sfx`;NEGLIGIBLE → 0(test_negligible_is_silent)。grep-verified `play_sfx(event_id: StringName)` audio_manager:235

---

## Implementation Notes

*Derived from #4 EG-1 / Q-CV1:*

- routing(story 004-006)tier/outcome 分支末加 `_audio.play_sfx(_cue_for(tier, outcome))`;`_cue_for` map = tier/outcome → StringName cue id。
- cue id catalog 由 #4 own;MVP mock-scoped(test 注入 mock AudioManager spy 驗 cue 對應)。真 cue 資源落地 = #4 audio cue 落地時 / epic-time(Q-CV1)。
- `_audio` DI seam(可 null → fail-soft 唔 crash,Pillar 2 — silent-mode visual 獨立完整)。

---

## Out of Scope

- #4 真 cue 資源 catalog（#4 owns;Q-CV1 epic-time）
- Story 004-006: visual routing 本身

---

## QA Test Cases

- **AC-cue**: tier→cue trigger
  - Given: mock AudioManager spy + `damage_tier=HEAVY`
  - When: route
  - Then: `play_sfx` 收 1 次 expected HEAVY cue
  - Edge cases: CRITICAL/OVERKILL/kill 各對應 cue;`_audio==null` → fail-soft 無 crash
- **AC-silent**: visual 獨立
  - Given: `_audio==null`(silent)
  - When: route CRITICAL
  - Then: visual(flash+pause+number)完整 + 無 crash

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat_visual_feedback/test_cvf_audio_trigger.gd`(cue map + silent fail-soft;mock AudioManager spy)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_audio_trigger.gd` 4/4(tier-map / outcome-map / negligible-silent / silent-fail-soft)。`_audio` SOFT seam + 5 cue consts + `_play_cue`/`_cue_for`

---

## Dependencies

- Depends on: Story 004/005/006(routing 分支)
- Unlocks: None
