# Story 003: SFX pool + priority-aware voice stealing

> **Epic**: Audio Manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-003`, `TR-audio-008`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps) — SFX voice count web budget
**ADR Decision Summary**: two-tier GPU/CPU budgets；SFX voice count 受 web budget 限（`SFX_VOICE_COUNT`=8 provisional，mobile profiling 可降 6）；CPU 數字 Provisional pending VS-tier。

**Engine**: Godot 4.6 | **Risk**: MEDIUM (CPU numbers Provisional — Q1 profiling)
**Engine Notes**: Godot 4.6 `stop()`/replay **唔** emit `AudioStreamPlayer.finished`（只自然播完先 emit）→ steal 路徑必須顯式 release duck refcount。non-positional `AudioStreamPlayer`（非 2D）。`event_id→AudioStream` 經 `SfxCatalog.tres`。

**Control Manifest Rules (Foundation)**:
- Required: data-driven catalog（無 hardcode path）；no-throw on unknown
- Forbidden: gateway 外 `new AudioStreamPlayer`；hardcode stream path
- Guardrail: voice cap = memory-safety invariant（無 unbounded slot 生成）

---

## Acceptance Criteria

- [ ] **AC-03** GIVEN pool 全忙（各 `_voice_busy==true`，`assigned_sequence` s0<…<s7，全 low），WHEN `play_sfx(new_low)`，THEN 最舊 slot 被重指派 + 其餘 7 個 stream 不變 + `_test_get_active_voice_count()==SFX_VOICE_COUNT`
- [ ] **AC-03b** GIVEN pool 全忙全 low + 一個正播 high `loot_fanfare_*`，WHEN `play_sfx(new_low)`，THEN 被 steal 係某 low voice，**high fanfare 不受影響**（保 Pillar 3）
- [ ] **AC-10** GIVEN 未知 event_id，WHEN `play_sfx`，THEN 無 crash + warn + `_unknown_event_count++`
- [ ] **AC-16** GIVEN catalog 缺失，WHEN boot，THEN push_error 一次 + no-op 模式，無 crash
- [ ] **AC-17** GIVEN READY，WHEN 連發 SFX（> `SFX_VOICE_COUNT` 次），THEN `_test_get_active_voice_count()==SFX_VOICE_COUNT` + 無 unbounded slot 生成

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 3/8:*

- **priority-aware steal**：揀 victim 先揀**最低 priority** active voice；同 priority steal **最舊**（`assigned_sequence` 最細）。high（loot fanfare / boss stinger）**不可**俾 lower-priority steal。退化（全 high，罕見）→ steal 最舊 high。
- **voice-count 斷言用 `_voice_busy` 邏輯佔用**（`_test_get_active_voice_count()` 數 `_voice_busy==true`），**唔斷言 `AudioStreamPlayer.playing`**（headless Dummy driver `.playing` 未驗，可能 vacuous）。
- **steal × duck 安全**：被 steal 嘅 voice 唔 emit `finished` → 若該 voice 曾 `_register_duck`，steal 路徑**必須**顯式 `_release_duck(handle)`（同 `finished` path 同一 callback）。否則 permanent duck（Story 004 驗）。
- `event_id→AudioStream` 經 data-driven `SfxCatalog.tres`（priority + channels field per catalog freeze v0）。

---

## Out of Scope

- Story 004: ducking refcount / Music bus 壓低（呢度只 fire release callback hook，duck 數學喺 004）
- Story 001: pool seam scaffold（前置）
- Catalog asset craft（Q8 / `/asset-spec`）

---

## QA Test Cases

- **AC-03**: steal oldest same-priority — Given 8 slot 全 `_voice_busy` 全 low，`assigned_sequence` 0..7 / When `play_sfx(low)` / Then slot(seq=0) 重指派（`.stream==new`）+ 其餘 7 不變 + count==8。Edge: 連發 16 次 → count 恆 8。
- **AC-03b**: priority gate protects high — Given 7 low + 1 high(`loot_fanfare_legendary`) 全忙 / When `play_sfx(low)` / Then stolen.priority==low，high voice `_voice_busy` 仍 true。Edge: 全 8 high → steal 最舊 high。
- **AC-10**: unknown no-throw — Given event_id 唔喺 catalog / When `play_sfx` / Then 無 crash + `_unknown_event_count` +1 + push_warning。
- **AC-16**: catalog missing — Given `SfxCatalog.tres` load fail / When boot / Then push_error once + 後續 `play_sfx` 全 no-op，無 crash。
- **AC-17**: voice cap invariant — Given READY / When `play_sfx` ×20 / Then `_test_get_active_voice_count()==8`，無 9th slot。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/test_sfx_pool_voice_steal.gd` — must exist and pass（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 001 (pool seam scaffold) ✅ Complete
- Unlocks: 004 (duck release on steal/finished)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 5/5 covered + local-verified (AC-03/03b/10/16/17)
**Files**: `src/autoload/audio_manager.gd`（`_build_sfx_pool` 8× AudioStreamPlayer on SFX bus + `_voice_priority`/`_voice_seq` arrays；`play_sfx` real impl；`_acquire_slot` priority-aware steal [lowest-priority, oldest seq; high protected unless all-high degenerate]；`_on_voice_finished` frees slot;`_lookup_sfx`/`_load_sfx_catalog` [injectable `_sfx_catalog` seam, missing .tres → `_sfx_safe_mode` + push_error once]；`SfxPriority` enum；`SFX_CATALOG_PATH`）· `tests/unit/audio/test_sfx_pool_voice_steal.gd`（5 tests）
**Test Evidence**: Logic — `test_sfx_pool_voice_steal.gd` ✅ **LOCAL GUT VERIFIED 5/5**（audio 26/26 total）。**Full gate 235 scripts / 1426 tests / 1425 pass / 1 pending(AC-37) / 0 fail** — no regression (autoload boot now builds pool + push_error on missing catalog, like #10 registry pattern).
**Deviations**: ADVISORY — `play_sfx` includes the LOCKED-drop guard (`if not _audio_unlocked`), which is Story 007's AC-06 behaviour implemented early (forward-compatible; Story 007 owns the full unlock flow + deferred BGM). No out-of-scope files touched.
**Code Review**: Complete (/code-review APPROVED WITH SUGGESTIONS — Story 004 must wire duck-release on steal/finished per Rule 7b [`_on_voice_finished` hook left]; `_build_catalog_dict` is a defensive stub pending /asset-spec catalog schema).
**Real audio note**: catalog streams are null until /asset-spec (Q8) — production runs safe-mode; priority/steal logic fully implemented + unit-tested via injection.
