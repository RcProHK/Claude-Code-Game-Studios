# Story 012: Lifecycle — Suspended force-reset + bfcache resume clear + delta clamp

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(States and Transitions + EC-08/09 + AC-16/17)
**Requirement**: `TR-cvf-012`

**ADR Governing Implementation**: ADR-0006: State Machine Contract(primary)、ADR-0001(secondary)
**ADR Decision Summary**: 對齊 #6「Suspended 永遠覆蓋一切」契約;bfcache resume(Safari pagehide→pageshow)force clear + `_process` delta clamp。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GSM `state_changed → Suspended`;bfcache resume handler;`delta = min(delta, MAX_FRAME_DELTA=0.1)` clamp(防大 delta 令 number 一 frame 跳完 / overlay 殘留)。

**Control Manifest Rules (Presentation)**:
- Required: Suspended force reset 覆蓋一切;resume delta clamp
- Forbidden: Suspended 後仍處理 incoming signal
- Guardrail: bfcache resume 無殘留 number/flash

---

## Acceptance Criteria

*From GDD States table + EC-08/09:*

- [x] **AC-16**:flash + 2 numbers + coalesce entry → GSM SUSPENDED → overlay IDLE+hidden + `_active_numbers`==0 + `_last_particle_ms`/`_seen` empty + 後續 hit reject(test_suspended_force_resets_everything)
- [x] **AC-17**:`_process(0.5)` → `_last_clamped_delta`==MAX_FRAME_DELTA(0.1)clamp(test_process_clamps_large_resume_delta)
- [x] **EC-08**:Suspended force reset(`_force_reset` = overlay off + pool release + dict clear)+ reject + `_rejected_while_suspended++`(test 驗 reject spawns nothing)
- [x] **EC-09**:`_notification(NOTIFICATION_APPLICATION_RESUMED / WM_WINDOW_FOCUS_IN)` → `_force_reset()`(test_bfcache_notification_force_resets,mirror screen_effects:530)+ leave-Suspended belt-and-braces clear(test_resume_from_suspended_returns_active_clean)

---

## Implementation Notes

*Derived from ADR-0006:*

- `_on_gsm_state_changed(from, to, payload)`:`to == Suspended` → `_force_reset()`(overlay→IDLE+hide / pool 全 release / `_last_particle_ms.clear()` / `_seen.clear()` / 設 `_suspended=true` reject flag + debug counter)。`to != Suspended` → `_suspended=false`(Active)。
- incoming `hit_resolved` 喺 `_suspended` → silent no-op + counter。
- `_process(delta)` 入口:`delta = minf(delta, MAX_FRAME_DELTA)`;resume(notification / GSM 離開 Suspended)→ 再 `_force_reset()` 保證無殘留。

---

## Out of Scope

- Story 008: coalescing/dedup 機制本身（本 story 只 clear 佢哋）
- Story 010: overlay primitive（本 story 只 force OFF）

---

## QA Test Cases

- **AC-16 / EC-08**: Suspended force reset
  - Given: overlay FLASHING + 3 numbers active + coalescing entries
  - When: `state_changed → Suspended`
  - Then: overlay IDLE + pool 全 release + `_last_particle_ms` empty + 後續 `hit_resolved` no-op(counter++)
- **AC-17 / EC-09**: bfcache resume
  - Given: residual state + 大 delta(0.5s)
  - When: resume notification
  - Then: overlay OFF + pool clear + `_process` delta clamp 到 ≤0.1

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat_visual_feedback/test_cvf_lifecycle.gd`(AC-16/17 + EC-08/09)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_lifecycle.gd` 4/4(suspend force-reset / resume-active-clean / delta-clamp / bfcache-notification)。`_force_reset` 抽出 + `_notification` resume + `_last_clamped_delta` observable。lesson:`var x := typed_node.member` 推斷失敗 → 用 untyped `=`(DI-seam 家族)

---

## Dependencies

- Depends on: Story 008(coalescing/dedup)、Story 009(pool)、Story 010(overlay)
- Unlocks: None
