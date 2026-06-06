# Story 012: Boss cleanup + bfcache DD#1 exact-restore

> **Epic**: Boss System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06

**Completion Notes (2026-06-06)**: refined the Story-002 BossInstance scaffold to full death/bfcache + `tests/integration/boss_system/test_bfcache_cleanup.gd` (8 tests; combined 272scr/1783/1782pass/0fail/1pending). `_play_death_and_free` (play "death" + wall-clock poll loop with injectable `_now_ms_provider` + is_instance_valid guards + `_delete_persist_record` + queue_free), `_restore_from_bfcache` (extracted for testability — AC-42 a/b/c + AC-46 TTL via injectable `_now_unix_provider`), `_delete_persist_record`. AC-11 (cleanup+free), AC-38 (wall-clock deadline when anim never finishes), AC-42/27a (exact-restore a / HP-0→DYING b / mismatch+null→max_hp c), AC-46 (Δ==TTL fresh / Δ>TTL stale).
- **#5 API FIX**: `ParticleSystemWrapper.release(emitter)` **does NOT exist** (auto-pool); `_spawned_emitters` type `GPUParticles2D`→`ParticleHandle`, `_cleanup_resources` now `handle.stop()` (ParticleHandle.stop, src/core/particle_handle.gd). In MVP `_spawned_emitters` is empty (reveal=coordinator, attack VFX=#25) so it was dead code — corrected the design anyway.
- Injectable clock seams = Followup #17 IClock. Branch (d) PRE_SPAWN-freeze is #14 BossAnchor-layer (an existing instance does a/b/c only).

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 11 (cleanup) + Rule 12 (DD#1 persist current_hp) + Rule 16 NEVER #10
**Requirement**: `TR-boss-011` (cleanup ≤2 frames, emitters released), `TR-boss-015` (bfcache DD#1 exact-restore)

**ADR Governing Implementation**: ADR-0003 (Save State Strategy — ephemeral mid-fight record) — primary; ADR-0001 (cleanup budget) secondary
**ADR Decision Summary**: backend-primary + IndexedDB (`user://`); ephemeral mid-fight `boss.*` record (current_hp + transition_id + fight_timestamp); deleted on death/cleanup/TTL-expiry.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Web Export — `Awaitable.race` doesn't exist → CONNECT_ONE_SHOT + `Time.get_ticks_msec()` wall-clock deadline (bfcache-safe, NOT SceneTreeTimer). Multi-hook resume: `_notification(NOTIFICATION_APPLICATION_FOCUS_IN / WM_WINDOW_FOCUS_IN)` + Safari `PlatformDetect.page_shown_from_bfcache`. `NOTIFICATION_APPLICATION_RESUMED` is mobile-only (NOT Web). `is_instance_valid()` before AND after every await.

**Control Manifest Rules (Feature)**: only the 2 whitelisted `boss.*` write callsites (`_set_current_hp` + `_persist_fight_anchor`) legal — position NEVER persisted (NEVER #10 + AC-12 lint).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-11**: DYING anim finishes → all `_spawned_emitters` released via `ParticleSystemWrapper.release` + `queue_free` within 2 frames; `_cleanup_resources` idempotent (`.clear()` after release).
- [ ] **AC-38**: anim_finished never fires (bfcache drop) → cleanup proceeds after wall-clock 3000ms (`CLEANUP_TIMEOUT_MS`); `_spawned_emitters.clear()` once; `queue_free` called.
- [ ] **AC-42 / AC-27a** (DD#1 exact-restore): `_on_resume_detected` — (a) workout_completed + restored_hp>0 + matching tid + not stale → `_set_current_hp(restored_hp)` exact, no re-reveal/skip/fabrication; (b) restored_hp==0 → `_enter_state(DYING)` idempotent (EC-16/24 dedupe single loot); (c) no record/tid-mismatch → `_set_current_hp(max_hp)` + delete; (d) workout_completed NOT emitted (PRE_SPAWN freeze) → cleanup + queue_free + delete.
- [ ] **AC-46** (Q3 TTL): record `fight_timestamp=T`; resume at `T+Δ` — Δ≤`BOSS_HP_PERSIST_TTL_SEC=7200` → exact-restore; Δ>TTL OR missing ts → restore max_hp + delete. Injectable clock (no wall-clock; determinism).

---

## Implementation Notes

*From GDD Rule 11 + Rule 12:*

- `_play_death_and_free`: play "death"; poll loop yields each frame checking `Time.get_ticks_msec() < deadline_ms` AND anim_done; `is_instance_valid` re-checks; `_cleanup_resources()`; `queue_free()`; delete the `boss.*` ephemeral record.
- `_persist_fight_anchor` writes `boss.transition_id` + `boss.fight_timestamp` once at `_ready`. `_set_current_hp` writes `boss.current_hp`. Both whitelisted.
- Resume pseudocode reads all three persisted keys + `is_stale` TTL check.

---

## Out of Scope

- **Story 013**: avatar-downed. **Story 015**: `check_boss_no_persist.gd` lint. PlatformDetect `page_shown_from_bfcache` signal (forward dep — if absent, Safari falls back to _notification paths).

---

## QA Test Cases

- **AC-11**: DYING → emitters released + queue_free ≤2 frames; double `_cleanup_resources` → no double-release.
- **AC-38**: mock `Time.get_ticks_msec` advancing past deadline, anim_finished never fires → cleanup after 3000ms, clear once.
- **AC-42**: scenarios H∈{1, ⌊max×0.3⌋, max, 0} via `_on_resume_detected` mock → exact restore / DYING@0 / max_hp+delete / cleanup. Edge: H==0 → single loot.
- **AC-46**: injected clock Δ=7199 → restore; Δ=7201 → max_hp+delete; Δ==7200 exact boundary.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/feature/boss_system/test_boss_cleanup.gd` + `test_ac38_cleanup_wallclock_timeout.gd` + `test_ac42_bfcache_exact_restore.gd` + `test_ec16_ec17_resume_logic.gd` + `test_ac46_persist_ttl_staleness.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 011 (death path entry), Story 002 (`_set_current_hp` / `_persist_fight_anchor`)
- Unlocks: None
