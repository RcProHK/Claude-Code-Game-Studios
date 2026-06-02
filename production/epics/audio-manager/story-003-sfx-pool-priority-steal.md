# Story 003: SFX pool + priority-aware voice stealing

> **Epic**: Audio Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

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

- Depends on: 001 (pool seam scaffold)
- Unlocks: 004 (duck release on steal/finished)
