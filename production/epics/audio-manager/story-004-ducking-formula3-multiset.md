# Story 004: Ducking system (Formula 3 + multiset de-escalation)

> **Epic**: Audio Manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-007`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: N/A — GDD-owned Formula 3（ducking）。Secondary: ADR-0001（Music bus dB tween 喺 web budget；單一 retained tween + idle gate 杜絕 idle per-frame call）。
**ADR Decision Summary**: ducking 數學係 #4 自有 spec（multiset refcount + recompute-on-release）；無獨立 architectural ADR。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: bus-level duck 必須用 **lambda closure** `tween_method(func(db): AudioServer.set_bus_volume_db(music_idx, db), from, to, sec)`。**禁止** `AudioServer.set_bus_volume_db.bind(music_idx)` — Godot 4.x `bind()` **APPENDS** args → `set_bus_volume_db(dB, idx)` 參數反轉，ducking 靜默失效 + GUT spy phantom-pass（session memory lesson）。autoload `create_tween()` 唔隨 scene change kill → 必須 retained handle kill-before-respawn。

**Control Manifest Rules (Foundation)**:
- Required: 單一 retained `tween_method` Tween（handle 存成員）+ idle gate（refcount==0 → kill）
- Forbidden: `.bind()` 落 AudioServer setter；`_process()` per-frame lerp；多條疊加 duck Tween
- Guardrail: idle（90%+ session）唔可每 frame call `set_bus_volume_db`

---

## Acceptance Criteria

- [ ] **AC-09** GIVEN `base_music_db` set，WHEN `_register_duck(DUCK_OFFSET_DB)→handle`，THEN `_compute_duck_target(_active_ducks)==max(base+DUCK_OFFSET_DB, MUTE_FLOOR_DB)`（−6+−8=−14）；release → `_compute_duck_target({})==base_music_db`
- [ ] **AC-09b** GIVEN 任一 stinger player，THEN `player.bus==&"SFX"`；除 2 個 BGM crossfade player 外無 AudioStreamPlayer bus==Music（duck 只壓 Music，防自我抵消）
- [ ] **AC-09c** GIVEN `_register_duck(...)→handle`，WHEN `_release_duck(handle)`（模擬 steal explicit release），THEN `_active_ducks.has(handle)==false` + `_compute_duck_target({})==base_music_db`（永不 permanent duck）
- [ ] **AC-09d** GIVEN READY，WHEN `_register_duck(+8.0)`（誤傳正 offset），THEN stored clamp 到 0.0 + warn once + `_compute_duck_target<=base_music_db`（music 永不被升）
- [ ] **AC-15** GIVEN `_register_duck(−8)→L` + `_register_duck(−5)→S`，THEN target==−14；`_release_duck(L)`（erase→recompute）→ target==−11（分級 step）；`_release_duck(S)`（dict 空）→ target==base
- [ ] **AC-25** GIVEN priority∈{low,mid,high} 各播，THEN duck target == base(low,不 duck) / max(base+STREAK_CHIME_DUCK_OFFSET_DB,floor)(mid −11) / max(base+DUCK_OFFSET_DB,floor)(high −14)

---

## Implementation Notes

*Derived from GDD Rule 7 + Formula 3:*

- `_active_ducks: Dictionary[handle→offset]` = duck 唯一 source-of-truth（**multiset**，唔去重 — 兩件 −8 各佔一 entry）。refcount = `.size()`。target 只用 `_compute_duck_target(_active_ducks)`。
- 操作順序**嚴格依序**：(1) `_active_ducks.erase(finishing_handle)` (2) `_compute_duck_target(...)` (3) kill 舊 duck tween + respawn 由當前 bus dB lerp toward new_target。錯序（先 recompute 後 erase）→ AC-15 fail。
- `_compute_duck_target(d) = d.is_empty() ? base_music_db : max(base_music_db + d.values().min(), MUTE_FLOOR_DB)`（`min(values())` 因 offset 負，最深 = min；empty guard 防 `min([])` null runtime error）。
- `_register_duck(offset)`：`assert(offset<=0.0)`（debug）+ `stored=clamp(offset, MUTE_FLOOR_DB, 0.0)`（release 防呆）+ warn once。
- duck attack `ATTACK_SEC`；release `RELEASE_SEC`（長 stinger）/ `SHALLOW_RELEASE_SEC`（短 mid stinger，防 pumping）by `finished`/steal 觸發（**唔用固定時長**）。
- **SUSPENDED duck 行為喺 Story 008**（kill tween + hard-set base，`_active_ducks` 唔清）。

---

## Out of Scope

- Story 003: voice steal victim 選擇（呢度只接 release callback）
- Story 008: SUSPENDED 期間 duck-kill（AC-33）
- 實際 stinger 播放（Story 003）+ `finished` wiring（共用 003 release hook）

---

## QA Test Cases

*全部 pure-function 斷言（`_register_duck`/`_release_duck`/`_compute_duck_target`）— 無 wall-clock，無 AudioStreamPlayer instance。*

- **AC-09**: single duck target — Given base=−6 / When register(−8) / Then compute==−14；release→base。Edge: base==MUTE_FLOOR → duck 自然失效（target==base）。
- **AC-09b**: bus isolation — Given stinger players / Then 全 `.bus==&"SFX"`；無 non-BGM player bus==Music。
- **AC-09c**: steal release idempotent — Given register→handle / When release(handle) ×2 / Then dict erase，second call no-op，target==base（`Dictionary.erase(absent)` no-op）。
- **AC-09d**: positive-offset guard — Given register(+8) / Then stored==0 + warn + target<=base。子: register(0)→target==base。
- **AC-15**: multiset de-escalation — register(−8)+register(−5)→−14；release(−8 handle)→−11；release(−5 handle)→base。Edge: 兩件 −8（multiset 唔去重）→ 第一件 release 後仍 −14。
- **AC-25**: priority dispatch — low→base、mid→−11、high→−14。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/test_ducking_formula3.gd` — must exist and pass（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 002 (`_base_music_db` from bus volume) ✅, 003 (steal/finished release hook) ✅
- Unlocks: 008 (SUSPENDED duck-kill builds on duck tween)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 6/6 covered + local-verified (AC-09/09b/09c/09d/15/25)
**Files**: `src/autoload/audio_manager.gd`（`_apply_duck` single retained lambda-closure `tween_method` + idle gate [refcount 0 → kill + hard-set base, never spawn]; `_priority_duck_offset` LOW→0/MID→-5/HIGH→-8; play_sfx registers duck for mid/high + releases stolen voice's duck [Rule 7b]; `_on_voice_finished` releases duck; `set_bus_volume_db` MUSIC → `_compute_duck_target` [duck-aware]; `_register_duck` assert→push_error; `_voice_duck_handle` per-slot; DUCK_ATTACK/RELEASE/SHALLOW_RELEASE consts; `_duck_tween` member）· `tests/unit/audio/test_ducking_formula3.gd`（7 tests）
**Test Evidence**: Logic — `test_ducking_formula3.gd` ✅ **LOCAL GUT 7/7**（audio 33/33）。**Full gate 236 scripts / 1433 tests / 1432 pass / 1 pending(AC-37) / 0 fail** — no regression (play_sfx + set_bus_volume_db changes safe).
**Deviations** (ADVISORY): (1) `_register_duck` `assert(offset<=0)`→`push_error` so AC-09d's positive-offset clamp is testable in debug GUT (assert would abort); production safety = the clamp (unchanged). (2) `SHALLOW_RELEASE_SEC` const added but unused — release_class dispatch (short vs long stinger) deferred to catalog per GDD Pass-3 rec. (3) `set_bus_volume_db` MUSIC path now routes through `_compute_duck_target` (duck-aware; verified no story-002 regression). No out-of-scope files touched.
**Code Review**: Complete (/code-review APPROVED WITH SUGGESTIONS).
