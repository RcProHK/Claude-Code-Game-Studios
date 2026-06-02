# Story 001: CI lints + closed-API gateway scaffold

> **Epic**: Audio Manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-001`, `TR-audio-010`
*(Requirement text — see EPIC.md GDD Requirements table; tr-registry.yaml has no audio rows yet — GDD-owned closed-gateway contract.)*

**ADR Governing Implementation**: ADR-0008 (Autoload Position Map) — primary; ADR-0006 C4 (sequential autoload boot)
**ADR Decision Summary**: project.godot 係 autoload 絕對位置嘅 sole ground-truth；AudioManager 置於 pos 11+ block；sequential `_ready()` boot per ADR-0006 Contract 4。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: autoload 註冊喺 project.godot `[autoload]`；class 用 `class_name` 要 `godot --headless --import` 刷 class cache 先 GUT 跑得（session lesson）。

**Control Manifest Rules (Foundation)**:
- Required: closed-gateway single-owner posture（同 #5/#6/#7）；DI injection seam 用 **untyped** `var`（typed Node fails compile-time member check — GDScript DI seam rule）
- Forbidden: 非 gateway file 直接 `AudioServer.` / `new AudioStreamPlayer` / `AudioStreamPlayer….bus =`
- Guardrail: GUT 只收 `test_*.gd` prefix（`*_test.gd` suffix silently never runs — phantom pass）

---

## Acceptance Criteria

*From GDD, scoped to this story:*

- [ ] **AC-01** GIVEN codebase，WHEN `check_audio_callers.gd` scan，THEN gateway 外任何 `AudioServer.` / `new AudioStreamPlayer` / `.bus =` → exit 1
- [ ] Gateway public API surface 定義齊（`play_sfx` / `play_bgm` / `stop_bgm` / `set_bus_volume_db` / `get_bus_volume_db` / `set_bus_muted` / `is_audio_unlocked` + signals `audio_unlocked` / `bgm_changed`）—— body 可 stub，但 signature + `Bus` enum {MASTER,MUSIC,SFX} 鎖定
- [ ] Test-seam pure functions 存在且可 headless call：`_register_duck(offset)->int` / `_release_duck(handle)` / `_compute_duck_target(dict)->float` / `_test_get_active_voice_count()->int` / `_test_get_active_crossfade_count()->int`；member `_voice_busy`（per-slot）/ `_active_crossfade_count` / `_crossfade_progress`（sentinel `-1.0`）
- [ ] Injection seams `_gsm`（untyped）+ `_platform_detect`（untyped）存在，accept mock double
- [ ] Autoload boot：`_ready()` load catalogs + persisted volumes + subscribe GSM；無出聲；`is_audio_unlocked()→false`（web）/ `true`（desktop boot）

---

## Implementation Notes

*Derived from ADR-0008 + ADR-0006 C4 + GDD Rule 1:*

- CI lint **完全跟 `check_camera_callers.gd` / `check_particle_callers.gd` 先例**：`EXEMPT_FILES = ["res://src/autoload/audio_manager.gd"]` + `EXEMPT_FILES.has(file_path)`（full-path array，**唔好** filename substring）。`.bus =` pattern 用 anchor `AudioStreamPlayer[^\n]*\.bus\s*=`（**唔可**裸 ban `.bus\s*=`，否則封死 `event_bus =`）。`AudioServer\.` / `new AudioStreamPlayer` 裸 ban OK。
- gateway 本體 self-exempt：`player.bus = &"SFX"` 設 pool/BGM player bus 喺白名單內合法。
- `_voice_busy` 係 AudioManager **顯式管理**嘅邏輯佔用 state，**獨立於** engine `AudioStreamPlayer.playing`；內部邏輯（steal victim、voice-count、pool 佔用）**永不**讀 `.playing`（headless Dummy driver 唔 guarantee `.playing`）。
- injection seam **必須 untyped**（`var _gsm` / `var _platform_detect`，非 `var _gsm: GameStateMachine`）— typed Node 喺 compile-time member check 失敗（DI seam rule）。

---

## Out of Scope

- Story 002: bus volume/persistence 實際邏輯
- Story 003-005: pool/duck/crossfade 實際行為（此 story 只立 seam，body stub）
- Story 006-008: GSM transition / unlock / suspend 行為

---

## QA Test Cases

*Derived from GDD AC-01 + Rule 1 test-seam contract.*

- **AC-01**: CI lint bans non-gateway audio mutators
  - Given: 一個 fixture file 含 `AudioServer.set_bus_volume_db(...)` 喺非白名單路徑
  - When: 跑 `check_audio_callers.gd`
  - Then: exit code == 1 + 印出 violating file:line
  - Edge cases: (a) `audio_manager.gd` 自身用 `player.bus = &"SFX"` → exit 0（self-exempt）；(b) `event_bus =` / `message_bus =` 喺任意 file → exit 0（anchor 唔誤殺）；(c) `new AudioStreamPlayer` 喺非白名單 → exit 1
- **Seam smoke**: pure-function seams callable headless
  - Given: AudioManager instance（preload，無需 autoload）
  - When: call `_compute_duck_target({})`
  - Then: == `base_music_db`（empty-dict guard，唔 crash，唔 call `min([])`）
  - Edge cases: `_register_duck(-8.0)` 回 monotonic int handle；`_test_get_active_crossfade_count()` 初值 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tools/ci/check_audio_callers.gd`（CI lint script，self-test fixture）+ `tests/unit/audio/test_audio_gateway_scaffold.gd` — must exist and pass
> ⚠️ **GUT filename convention**：test file 必須 `test_*.gd` **prefix**（GUT 只收 prefix；`*_test.gd` suffix silently never runs = phantom pass）。見 [[reference_gut_filename_convention]]。
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（Foundation scaffold — 第一個 audio story）
- Unlocks: 002, 003, 004, 005, 006, 007（全部 build on 呢個 scaffold + seams）

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 5/5 covered（AC-01 lint + API surface + pure seams + injection seams + boot gate）；0 UNTESTED
**Files**: `src/autoload/audio_manager.gd`（gateway scaffold）· `tools/ci/check_audio_callers.gd`（CI lint）· `tests/unit/audio/test_audio_gateway_scaffold.gd`（12 tests，**LOCAL GUT 12/12 pass / 156 asserts**）· `tests/fixtures/audio_callers_{violation,clean}.gd` · `project.godot`（AudioManager autoload 註冊 pos 16，ADR-0008 11+ block）
**Deviations**: 2 ADVISORY —（1）`TR-audio-001/010` 未喺 tr-registry（epic-wide，fix via /architecture-review）；（2）tuning 值 script const（scaffold；data-driven catalog 留 story 003，對齊 particle 先例）
**Test Evidence**: Logic — `tests/unit/audio/test_audio_gateway_scaffold.gd`（12 functions）✅ **LOCAL GUT VERIFIED 12/12 pass / 156 asserts**（Godot 4.6.3 Steam，Bash 復活後本地跑）。**Full gate（unit+integration+static）233 scripts / 1412 tests / 1411 pass / 1 pre-existing pending(AC-37) / 0 fail** — 無 regression（新 autoload 唔破壞 position/boot test）。
> ⚠️ **PHANTOM-PASS CAUGHT pre-commit**：原 filename `audio_gateway_scaffold_test.gd`（`_test.gd` suffix）→ GUT「Nothing was run」phantom。改 `test_audio_gateway_scaffold.gd`（prefix）後 12/12 真綠。見 [[reference_gut_filename_convention]]。
**Code Review**: Complete（/code-review APPROVED WITH SUGGESTIONS，0 blocking，3 suggestion 留 story 004/007：AC-09d assert-vs-test、`_compute_duck_target` `.values()` alloc、`_is_web` OS.has_feature fallback）
**Status note**: COMPLETE（5/5 AC，local GUT 12/12 verified，full gate 0 fail）
