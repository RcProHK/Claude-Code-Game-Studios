# Story 009: Glance-count CI tool + AC-U-3 + 0px anchor + alpha invariant

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic / UI
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (AC-U-3 per-state exact-count + scope, EC-S7, F1 joint invariant B7) · **UX**: AC-UX-3 0px anchor
**Requirement**: GDD AC-U-3 + UX AC-UX-3 (no TR-ID — cite GDD/UX AC-ID)

**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps (primary)
**ADR Decision Summary**: CI script gate 模式(同 check_particle_callers.gd 等 ADR-0001 CI 家族);glance budget design-time 硬約束。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: CI tool = headless GDScript(`tools/ci/`);讀 scene metadata + config const;**design-time 靜態 scan 睇唔到 runtime instantiate icon count**(故 cluster runtime ≤4 歸 AC-CR-12 / Story 004,本 tool 只驗 metadata 結構)。

**Control Manifest Rules**:
- Required: per-state exact-count assert(非 `≤5`);讀 config const 非 hardcode;CI tool epic deliverable
- Forbidden: runtime auto-hide(破餘光穩定);hardcode count/alpha
- Guardrail: alpha 三軸 invariant boot-assert(兩條 conjunctive,B7)

---

## Acceptance Criteria

- [ ] **AC-U-3(per-state exact-count CI)**:`tools/ci/check_glance_tier1_count.gd` 數「餘光可見 element」(metadata `glance_visible==true` 且 effective alpha > `deep_dim_alpha_threshold`;◉+○ 計、◐+—+▽ 不計)。per-state exact:`WORKOUT_ACTIVE==3` / `COMBAT_ACTIVE==3` / `BOSS_ENCOUNTER==4`(exact,非 `≤5`);並 assert 每 counted state `count ≤ glance_tier1_max`(讀 const)。scope **只跑 WORKOUT/COMBAT/BOSS 三 state**,其餘 6 state 由 state-rule 豁免(SUSPENDED/DISCONNECTED/LOOT/IDLE/BOOTING/REST_PERIOD)。
- [ ] **AC-U-3 cluster metadata(design-time,B10)**:cluster parent (i) `glance_group==true` (ii) `cluster_icon_cap` field == `skill_cluster_display_cap(=4)` const;CI 數 parent 不數 children(算 1 grouped element)。
- [ ] **alpha invariant boot-assert(B7,兩條 conjunctive)**:`deep_dim_element_alpha_max < deep_dim_alpha_threshold_min` **AND** `deep_dim_alpha_threshold_max < ambient_alpha_min`(讀 const 上下界)。current:0.24<0.25 ✅ AND 0.40<0.45 ✅。
- [ ] **AC-UX-3(0px anchor)**:跨所有 9 GSM state,Z1 L1 anchor(HP/EXP)螢幕座標位移 == 0px(Z3/Z5/Z6 overlay 升降唔 reflow Z1)。

---

## Implementation Notes

- `check_glance_tier1_count.gd` = **epic 首要 deliverable**(AC-U-3 依賴佢存在,Story 004/008 之後但其他 AC 前)。讀 `glance_visible`/`glance_group`/`cluster_icon_cap` metadata + `glance_tier1_max`/`deep_dim_alpha_threshold`/`ambient_alpha`/`deep_dim_element_alpha` const + per-state expected-count table。
- 拆 design-time / runtime(B10):本 tool design-time 驗 metadata 結構;runtime ≤4 摺疊歸 AC-CR-12(Story 004)。
- per-state exact 封死 count=5 phantom-pass(STAT/SKILLS 誤升 ○ 會被 exact 接住)。
- 0px anchor:Z1 absolute-positioned 獨立 layout context;test 量 Z1 rect 跨 9 state 不變。

---

## Out of Scope

- Story 004:cluster runtime display-cap 摺疊邏輯(本 tool 只 metadata)。
- Story 011:AC-V-1 glance playtest(本 story 只 design-time count CI)。

---

## QA Test Cases

- **AC-U-3 count**:Given per-state scene metadata;When CI run;Then WORKOUT/COMBAT==3、BOSS==4(exact);Edge: STAT 誤升 ○ 令 count=4(WORKOUT)→ CI fail(exact 接住);新增 glance element 必重驗。
- **AC-U-3 scope**:Given 9 state;Then 只 3 state per-element count,6 state state-rule 豁免(REST_PERIOD 對焦窗、SUSPENDED dim-collision 等)。
- **AC-U-3 cluster**:Given cluster parent;Then `glance_group==true` + `cluster_icon_cap==4`;CI 數 parent==1。
- **alpha invariant**:Given const 上下界;Then 0.24<0.25 AND 0.40<0.45(兩條 conjunctive);Edge: threshold 上界改近 ambient 下界 → upper assert fail。
- **AC-UX-3**:Given 9 state;Then Z1 rect 位移==0px。

---

## Test Evidence

**Story Type**: Logic / UI
**Required evidence**: `tools/ci/check_glance_tier1_count.gd`(tool itself)+ `tests/unit/gym_mode_hud/test_glance_count_ci.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (cluster metadata) · Story 008 (alpha const)
- Unlocks: Story 011 (AC-V-1 playtest 之 design-time 前置)

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 2/4 passing + 2 DEFERRED
- ✅ AC-U-3 per-state exact count (WORKOUT==3 / COMBAT==3 / BOSS==4，exact 接住 STAT-promotion regression) — CI tool + 7 unit tests
- ✅ B7 alpha invariant (deep_dim 0.22 < threshold 0.35 < ambient 0.55) — `alpha_invariants_hold()` boot-assert + CI tool
- ⏸️ **DEFERRED — AC-U-3 cluster metadata (glance_group / cluster_icon_cap)**：需 #20 HUD `.tscn` scene node metadata，scene 未建（Story 001-009 全係 .gd logic）。待 scene-build story（Story 011 visual 或專屬 scene story）建立 .tscn 後補 metadata 驗證。
- ⏸️ **DEFERRED — AC-UX-3 0px anchor**：需 .tscn layout（Z1 absolute rect 跨 9 state 量度），同上 scene 前置。屬 UI evidence（ADVISORY），Story 011 visual playtest 涵蓋。
**Deviations**: CI tool 用 instantiate-HUD + `_build_state_matrix()` 計 count（非 .tscn metadata scan），因 scene 未建；count 真相源 = `_state_matrix` + `get_emphasis_alpha`。CI tool standalone exit 0（autoload boot stderr noise 係 `--script` SceneTree 固有，同 GUT run 一致，exit-code gate 綠）。
**Test Evidence**: Logic — `tools/ci/check_glance_tier1_count.gd` (CI deliverable, exit 0) + `tests/unit/gym_mode_hud/test_glance_count_ci.gd` (7 test functions, 7/7 pass). Full gate 239 scripts / 1465 pass / 0 fail / 1 pending.
**Code Review**: Complete — APPROVED (per-state exact 封死 count=5 phantom；alpha invariant 兩條 ordering；CI tool ADR-0001 CI 家族風格)
**Files**: `tools/ci/check_glance_tier1_count.gd` (created), `tests/unit/gym_mode_hud/test_glance_count_ci.gd` (created), `src/ui/gym_mode_hud/gym_mode_hud.gd` (get_glance_tier1_count + alpha_invariants_hold + GLANCE_TIER1_MAX)
