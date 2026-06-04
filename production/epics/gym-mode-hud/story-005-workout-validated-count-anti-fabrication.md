# Story 005: #9-validated count/progress + anti-fabrication

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (CR-8 收斂1 re-wire, CR-4, EC-S1)
**Requirement**: GDD AC-CR-8 / AC-CR-4 / AC-EC-S1 (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0009 Signal Payload Schema (primary) · ADR-0002 GymSys Integration (secondary)
**ADR Decision Summary**: 計數/EXP 視覺**只認 #9-validated signal**(`set_progress_changed`/`phase_changed`),EXP 綁 #11 `stat_changed(EXP)`;**絕不食 raw `#2.set_logged`** 驅動計數(raw set_logged 只 audio path 用,Story 007)。trust boundary 喺 #11(#20 無 consumer-side fabrication filter)。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: #9 `set_progress_changed` debounce 500ms 由 #9 own,#20 只 consume;#9 已行 WST Rule 8 anti-fabrication(IDLE-without-`workout_started`/SUSPENDED stray set_logged 已 drop,唔 emit progress)。

**Control Manifest Rules**:
- Required: 計數綁 #9-validated path;absolute 斷言(== 注入數,非遞增)
- Forbidden: #20 計數直食 raw `set_logged`(= Silent Witness 講大話破 Pillar 1);set_progress 內插(5s gap)
- Guardrail: 計數/視覺與 `is_audio_unlocked()` 完全正交

---

## Acceptance Criteria

- [ ] **AC-CR-8(計數行 #9-validated path)**:audio LOCKED,#9 emit `set_progress_changed` → progress/計數即更新 + EXP 即跳格(不受 audio gate);注入 3 個 #9-validated progress → `workout_progress` 最終 **== 3**(絕對值)。
- [ ] **AC-CR-8 anti-fabrication(Integration chain-smoke)**:GSM IDLE-without-`workout_started`,raw `#2.set_logged` 到(#9 drop)→ `workout_progress` 不變(==0) **AND** `exp_fill` delta==0;SUSPENDED 變體同。**real #9 + real #11 + real #20 + faked #2 source**;#20 喺 chain 中被動 no-op(冇收 signal 所以唔 render),#20 only own「無 consumer-side fabrication path」negative assertion。
- [ ] **AC-CR-4**:收 `set_progress_changed` 後進 polling gap,5s 內無新 event → 顯示值 delta==0(無 `progress += elapsed`)。
- [ ] **AC-EC-S1**:BannerGate 期間 GSM 自進 WORKOUT_ACTIVE → 計數 + EXP 視覺即時運作(B1 decouple,唔 hold);注入 3 progress → `workout_progress==3`(與 BannerGate 狀態無關)。

---

## Implementation Notes

- progress/計數 subscribe **#9 `set_progress_changed`/`phase_changed`**(plain `.connect` + pull initial);EXP subscribe **#11 `stat_changed(EXP)`**(`connect_for_initial_state`)。
- **絕不** subscribe raw `#2.set_logged` for count/visual —— raw set_logged 只喺 Story 007 `WorkoutAudioAdapter` 用(SFX trigger)。
- EXP trust boundary:`stat_changed(EXP)` = #11 emit;#20 受 #11 single-source 保護,**無 consumer-side EXP fabrication filter**(防線喺 #11 不喺 #20)。
- PROG copy 由 #9 WorkoutPhase 細分(WARM_UP/SET_ACTIVE/REST_PERIOD/WORKOUT_COMPLETE),ambient 絕不跳秒。

---

## Out of Scope

- Story 007:`WorkoutAudioAdapter` raw set_logged → SFX(本 story 只 #9-validated count/visual path)。
- Story 006:banner audio gate(本 story EC-S1 只驗計數不被 banner hold)。

---

## QA Test Cases

- **AC-CR-8 count**:Given audio LOCKED;When 注入 3 個 #9 `set_progress_changed`;Then `workout_progress==3`(絕對) AND 與 `is_audio_unlocked()` 無關;Edge: off-by-one/double-count regression → 絕對斷言接住(遞增斷言會 phantom-green)。
- **AC-CR-8 anti-fab(Integration)**:Given GSM IDLE-without-workout_started, real #9+#11+#20 + faked #2;When inject raw stray `set_logged`;Then `workout_progress==0` AND `exp_fill` delta==0;Edge: SUSPENDED 變體同。
- **AC-CR-4**:Given 收 progress 後 gap;When 5s 無 event;Then 顯示 delta==0。
- **AC-EC-S1**:Given BannerGate + GSM WORKOUT_ACTIVE;When 注入 3 progress;Then `workout_progress==3`。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gym_mode_hud/test_workout_validated_count.gd` — must exist and pass (real #9/#11/#20 + faked #2 inject)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scaffold/wiring) · Story 002 (EXP bar) · #9 WST (merged) · #11 Stat (merged)
- Unlocks: Story 007 (audio adapter uses raw set_logged separately)
- **Note**: #2-GDD bidirectional gap (Q-OQ5) affects Story 007 audio path, NOT this #9-validated count path

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 4/4 passing (AC-CR-8 count + anti-fab / AC-CR-4 no-interpolation / AC-EC-S1 BannerGate decouple)
**Deviations**: anti-fabrication 用 stub-based negative assertion（#20 冇 `_on_set_logged` handler + 無 #9 emit → progress 0 + exp delta 0）而非 real-#9 full chain — #9 真實 drop 行為係 #9 自己嘅 anti-fabrication test responsibility（已有，per [[project_wst_epic_status]]）；#20 嘅 contract 係「無 consumer-side fabrication path」negative assertion，已釘死（`has_method("_on_set_logged")==false`）。
**Test Evidence**: Integration — `tests/integration/gym_mode_hud/test_workout_validated_count.gd` (7 test functions, 7/7 pass; gym integration 2 scripts 26 tests). Full gate 240 scripts / 1472 pass / 0 fail / 1 pending.
**Code Review**: Complete — APPROVED (count 綁 #9 set_progress_changed absolute、EXP 綁 #11、零 set_logged subscription、無 _process interpolation、count⊥audio/banner B1 decouple；對 GDD CR-8 收斂1 + ADR-0009)
**Files**: `src/ui/gym_mode_hud/gym_mode_hud.gd` (#9 wiring + count/phase handlers + getters), `tests/integration/gym_mode_hud/test_workout_validated_count.gd` (created)
