# Story 009: Expanded Caller Whitelist CI Lint (AC-39 / FR-3)

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save State Strategy, **Accepted 2026-05-30**) primary; ADR-0006 Contract 12 (CI static analysis) secondary
**ADR Decision Summary**: ADR-0003 Accepted confirms `#15 Loot Drop System` + `#29 Mirror Moment` 係 streak rarity modifier 嘅 ONLY authorized callers（FR-3 binding，Q-O3/Q-R3 resolved post-ratification）。AC-39 將 Rule 13 caller whitelist 由現有 shell-script（`check_streak_caller_whitelist.sh`，只 scan loot + mirror_moment）升級為 GDScript CI lint，擴展覆蓋所有未來 avatar-power 路徑（`src/gameplay/stats/`, `abilities/`, `pr/`, `zones/`），防 streak 經任何途徑變成 avatar power（Pillar 1 anti-pillar #1）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Mirror `check_camera_callers.gd` / `check_particle_preset_magic.gd` 嘅 GDScript CI lint pattern — inline RegEx + comment-skip + violation/clean fixtures + real-source 三段。**實際 method 名係 `get_streak_buff_multiplier()`**（GDD Section C 寫 `get_loot_rarity_modifier` 係 stale；以 `src/autoload/streak_system.gd:245` 實作為準）。**實際 autoload 檔案係 `src/autoload/streak_system.gd`**（GDD 寫 `src/autoload/streak.gd` 係 stale）。owner-exempt：`streak_system.gd` 自己可 define + return。

**Control Manifest Rules (Foundation layer)**:
- Required: CI enforces caller whitelist for `get_streak_buff_multiplier()`；exit(1) on violation
- Forbidden: streak rarity modifier read 喺 `src/gameplay/stats/`、`abilities/`、`pr/`、`zones/`（avatar-power path）
- Guardrail: whitelist expansion requires PR review（Q-R3 governance）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-39** [FR-3 / Rule 13] — `tools/ci/check_streak_callers.gd` scan `src/` 全範圍：任何 `get_streak_buff_multiplier()` call OUTSIDE `WHITELIST_PATHS = ["src/gameplay/loot/", "src/gameplay/mirror_moment/", "src/autoload/streak_system.gd", "tests/"]` → exit(1) blocking；whitelist 內 call → exit(0)。
- [ ] **AC-39a** [fixtures] — violation fixture（`get_streak_buff_multiplier()` call 喺 banned path，e.g. `src/gameplay/abilities/`）→ lint matches；clean fixture（whitelisted call + commented banned call）→ 0 matches。
- [ ] **AC-39b** [owner + whitelist exempt] — real `src/autoload/streak_system.gd`（define + return site）→ NOT flagged；real `src/gameplay/loot/`、`src/gameplay/mirror_moment/` callers（if present）→ NOT flagged。

---

## Implementation Notes

*Derived from ADR-0003 FR-3 + ADR-0006 Contract 12 + GDD Rule 13:*

- 新 `tools/ci/check_streak_callers.gd`（mirror `check_camera_callers.gd` 結構）：
  - `const PATTERN := "get_streak_buff_multiplier\\s*\\("` （RegEx，scan call-sites）
  - `const WHITELIST_PATHS := ["src/gameplay/loot/", "src/gameplay/mirror_moment/", "src/autoload/streak_system.gd", "tests/"]`
  - walk `src/`（recursive），skip comment lines（`#` strip via 同 camera lint 一致 helper），對每個 match 嘅 file path 檢查 `begins_with` 任一 whitelist entry；非 whitelist → collect violation
  - violations 非空 → print 每個 file:line + `OS.set_exit_code(1)` / return 1；否則 exit 0
- 新 test `tests/unit/ci/test_streak_caller_whitelist.gd`（GutTest）+ fixtures `tests/fixtures/streak_callers_violation.gd`（banned-path call 一個）、`tests/fixtures/streak_callers_clean.gd`（whitelisted + commented banned）。test inline 用同 lint 一致嘅 const PATTERN 對 fixtures assert match-count（mirror `test_camera_ci_lint.gd`）。
- **保留** 現有 `check_streak_caller_whitelist.sh`（Story 007）— 唔刪，呢個係 superset GDScript 版本（CI 兩個都跑，shell 係 fast-path，.gd 係 expanded-path）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: 現有 2 個 shell CI scripts（mutator ban + 基本 caller whitelist）— 已 Complete，唔重做
- Story 010: AC-37 retro-credit（呢度只 CI lint，唔掂 workout event 邏輯）
- AC-38（FR-2 drift FPR）: 仍 DEFERRED — 需 VS-tier playtest telemetry，唔 story-scope

---

## QA Test Cases

> **Seams**: inline `const PATTERN` 對齊 lint script；fixtures violation/clean；real-source scan（owner + whitelist exempt）。mirror `test_camera_ci_lint.gd` 三段結構。

- **AC-39 / AC-39a**: fixtures match
  - Given: `tests/fixtures/streak_callers_violation.gd`（`get_streak_buff_multiplier()` call，模擬喺 `src/gameplay/abilities/` path）；`streak_callers_clean.gd`（whitelisted call + 一行 commented `# get_streak_buff_multiplier()`）
  - When: 用 lint 嘅 const PATTERN scan 兩個 fixture
  - Then: violation fixture match_count == 1；clean fixture match_count == 0（comment-skip 生效）
  - Edge: commented call 唔算 violation；多個 call 喺同一 banned file → 各算

- **AC-39b**: real-source owner + whitelist exempt
  - Given: real `src/autoload/streak_system.gd`（line 245 define + return）；real `src/` tree
  - When: 跑完整 `check_streak_callers.gd` 邏輯
  - Then: streak_system.gd NOT flagged（owner-exempt via whitelist entry）；任何現存 loot/mirror_moment caller NOT flagged；clean codebase → exit 0
  - Edge: whitelist `begins_with` match 唔可以 partial-prefix false-match（e.g. `src/gameplay/loot_archive/` 唔應該被 `src/gameplay/loot/` whitelist 誤放行 — 確認 trailing slash 精確）

---

## Test Evidence

**Story Type**: Logic (CI enforcement)
**Required evidence**:
- `tools/ci/check_streak_callers.gd` — exit 0 on clean codebase, exit 1 on violation fixture
- `tests/unit/ci/test_streak_caller_whitelist.gd` — must exist and pass（AC-39, 39a, 39b）
- `tests/fixtures/streak_callers_{violation,clean}.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（`get_streak_buff_multiplier` 存在）、Story 007（現有 shell whitelist — superset 唔重做）、**ADR-0003 Accepted (2026-05-30)**
- Unlocks: AC-39 closed → FR-3 Pillar 1 anti-pillar #1 architecturally enforced across all future paths

---

## Completion Notes
**Completed**: 2026-06-01
**Criteria**: AC-39 / 39a / 39b passing（lint PASS exit 0 on 38 src files；GUT 5 tests green）
**Deviations**: ADVISORY — GDD Section H 寫 whitelist 為 `src/gameplay/loot/` + `src/gameplay/mirror_moment/`（stale）；實際 sanctioned consumer 喺 `src/autoload/loot_drop_system.gd`，lint whitelist 對應真實 basename-anchored path。GDD method 名 `get_loot_rarity_modifier` 亦 stale → 實際 `get_streak_buff_multiplier`。
**Test Evidence**: `tools/ci/check_streak_callers.gd`（exit 0）+ `tests/unit/ci/test_streak_caller_whitelist.gd`（5 tests）+ `tests/fixtures/streak_callers_{violation,clean}.gd`
**Code Review**: Self-review — mirrors check_camera_callers.gd pattern (comment-skip, basename anchor, exit codes)
