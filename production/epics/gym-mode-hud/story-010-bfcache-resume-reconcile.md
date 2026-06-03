# Story 010: bfcache/resume reconcile + SUSPENDED

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Ready (S9b ADVISORY BLOCKED — 見 Dependencies)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (bfcache reconcile SM-A/B/C/D, EC-S2/S9/S9a/S9b, Suspended state, EC-R4)
**Requirement**: GDD AC-EC-S9a / AC-EC-S9b / AC-EC-R4 + EC-S2 (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0006 State Machine Contract (primary) · ADR-0003 Save State (secondary)
**ADR Decision Summary**: generational lock read-side drift — #20 作為 external GSM reader reconcile 只喺 GSM idle 時 pull(in-flight transition → defer 一幀);Safari ITP / bfcache touch-refresh。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: `pageshow`/visibilitychange → SUSPENDED **producer 未存在**(Q-OQ12,JavaScriptBridge 受 ADR-0001 鎖 platform_detect.gd)— S9b headless 物理上無 DOM/bfcache;S9a 純邏輯 reconcile 可 headless 測。`get_current_state()` method。

**Control Manifest Rules**:
- Required: reconcile pull 真值一次性 snap;generational guard(GSM idle pull);double-flush guard
- Forbidden: 信 stale frame;逐格補播 missed motion;double-popup/double-SFX
- Guardrail: 離開 Suspended ⟺ DOM visible AND GSM≠SUSPENDED(AND guard 非 OR)

---

## Acceptance Criteria

- [ ] **AC-EC-S9a(reconcile 純邏輯,headless)**:抽出 `reconcile(pulled_state)` method(不依賴 browser event),注入 freeze@WORKOUT_ACTIVE → pulled@LOOT_DROP → 一次性 snap、apply LOOT_DROP 矩陣、`banner_dismissed_this_session` 防重彈、SFX flush 只觸發一次(double-flush guard)。
- [ ] **EC-S2(banner 復現)**:進 SUSPENDED 但 banner 未 dismiss → Freeze-dim 疊 banner,pulse 暫停;Resume 仍 LOCKED 且 `banner_dismissed_this_session==false` → banner 復現 + pulse 重啟;期間被 unlock 過 → 永不重出。
- [ ] **EC-S9 / SM-A/B/C/D**:離開 Suspended ⟺ DOM visible AND GSM≠SUSPENDED(AND guard);終點 branch `is_audio_unlocked() ? Active : BannerGate`;reconcile generational guard(GSM in-flight transition → defer 一幀)。
- [ ] **AC-EC-R4(unlock×WORKOUT 同幀)**:`audio_unlocked` 同 `state_changed→WORKOUT_ACTIVE` 同幀 → 計數/EXP 視覺結果與 ordering 無關;注入 3 progress + 任意 ordering → `workout_progress==3`(絕對值);audio flush 喺 reconcile pass(call_deferred)內完成,無 atomic 要求。
- [ ] **AC-EC-S9b** *(ADVISORY,BLOCKED Q-OQ12)*:真 web-export tab-switch/back-forward `pageshow` → `reconcile()` 被正確 wire 調用。

---

## Implementation Notes

- reconcile 序:① 唔信 stale,先 pull 真值(`is_audio_unlocked()`/GSM `get_current_state()`/#11 stat/#9 phase);**generational guard**:若 resume 嗰刻 GSM in-flight transition → defer 一幀再 pull ② bar frozen→真值一次性 snap(唔逐格補播)③ 離開 ⟺ DOM visible AND GSM≠SUSPENDED ④ banner 防重彈 flag ⑤ 唔 double-flush SFX。
- 不變量:resume 後 HUD == 當刻真值,零 stale / 零 double-popup / 零 double-SFX。
- EC-R4:兩 handler 各 set flag + `call_deferred` 一個 reconcile pass(避 signal connect-order race);**`call_deferred` 只限 EC-R4**(normal stat_changed tween path 用 plain sync,Story 003)。
- S9a headless 可測(抽 method);S9b 須 Q-OQ12 SUSPENDED producer 落地先 wire,evidence = 真 browser bfcache playtest。

---

## Out of Scope

- Story 006:banner UI 本體 + dismiss flag(本 story 只 reconcile 復現邏輯)。
- Story 007:audio flush 本體(本 story 只 double-flush guard + ordering)。

---

## QA Test Cases

- **AC-EC-S9a**:Given `reconcile(pulled)` method;When freeze@WORKOUT → pulled@LOOT;Then 一次性 snap + LOOT 矩陣 + 防重彈 + flush 一次;Edge: double-flush guard。
- **EC-S2**:Given SUSPENDED banner 未 dismiss;When resume LOCKED;Then banner 復現 + pulse 重啟;unlock 過 → 永不重出。
- **EC-S9/SM**:Given resume DOM visible 但 GSM SUSPENDED;Then HUD 停 Suspended(AND guard);GSM in-flight → defer 一幀。
- **AC-EC-R4**:Given unlock×WORKOUT 同幀 + 3 progress 任意 ordering;Then `workout_progress==3`(絕對);flush 無 atomic 要求。
- **AC-EC-S9b**(BLOCKED):真 browser `pageshow` → reconcile wired(playtest evidence)。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gym_mode_hud/test_bfcache_resume_reconcile.gd`(S9a/EC-S2/EC-R4 headless)+ `production/qa/evidence/bfcache-reconcile-evidence.md`(S9b ADVISORY browser playtest)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (state machine) · Story 006 (banner dismiss flag) · Story 007 (flush)
- **BLOCKED (partial)**: AC-EC-S9b — Q-OQ12 SUSPENDED producer(#1/platform_detect/TD)`pageshow`→SUSPENDED 落地;S9a/EC-S2/EC-R4 headless 部分**唔 blocked**
- Unlocks: —
