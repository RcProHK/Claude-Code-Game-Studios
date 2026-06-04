# Story 012: HUD .tscn scene build + node binding + glance metadata

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: L (4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (States 矩陣, CR-1 雙層資訊架構, Visual/UI Requirements) · **UX**: `design/ux/gym-mode-hud.md` (Zones Z1-Z6, Visual Primitives P-02/03/04/09/11, layout-isolation rule)
**Requirement**: GDD AC-U-3 cluster metadata + UX AC-UX-3 (0px anchor) / AC-UX-8 (touch target) + emphasis→render binding (no TR-ID — cite GDD/UX AC-ID)

**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps (primary — persistent overlay draw-call) · ADR-0006 (CanvasLayer topology, secondary)
**ADR Decision Summary**: 常駐 overlay 須遵 draw-call sub-budget;HUD = CanvasLayer 50(< ScreenEffects 100);#20 唔係 autoload,喺 main scene instantiate(所有 autoload `_ready()` 已完)。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: `.tscn` headless instantiate 可驗 node hierarchy + `get_meta()`;Z1 absolute anchor 用 anchor preset(0px reflow);emphasis→`modulate.a` 由 `get_emphasis_alpha()` derive;node binding 用 nullable `@onready`(scene 有 node → update;純 logic test 無 node → skip,**唔破現有 90 test**)。

**Control Manifest Rules (Presentation layer)**:
- Required: CanvasLayer 50 topology;node binding 保留 internal var seam(test-injectable);draw-call ≤ persistent-overlay sub-budget
- Forbidden: HUD own loot 文字 node(越界 #21);Z1 被 overlay 升降 reflow(layout-isolation)
- Guardrail: ADR-0001 draw-call budget(常駐 overlay node count)

---

## Acceptance Criteria

- [ ] **AC-SCENE-1(scene loads + root + adapter)**:`GymModeHud.tscn` headless instantiate 無 error;root == Control attach `gym_mode_hud.gd`;`WorkoutAudioAdapter`(attach `workout_audio_adapter.gd`)為 child node 存在。
- [ ] **AC-SCENE-2(node hierarchy per zones)**:HP bar + EXP bar(Z1)· STAT block(Z3)· SKILLS cluster(Z5)· PROG copy · Boss HP bar(Z6)· banner — 全部喺預期 node path 存在(逐 path assert)。
- [ ] **AC-SCENE-3(glance metadata — 解鎖 009 deferred B10)**:SKILLS cluster parent `get_meta("glance_group")==true` 且 `get_meta("cluster_icon_cap")==SKILL_CLUSTER_DISPLAY_CAP(4)`;每個 Tier-1 element `get_meta("glance_visible")` 已設;`check_glance_tier1_count.gd` 對 scene metadata 仍 green(cluster 算 1 grouped element)。
- [ ] **AC-SCENE-4(banner — AC-UX-8 / AC-U-4 actual node)**:banner node `focus_mode==Control.FOCUS_NONE`;hit-area `size >= Vector2(44,44)`;bottom-center non-fullscreen,**不重疊 Z1 rect**(layout-isolation)。
- [ ] **AC-SCENE-5(0px anchor — 解鎖 011 AC-UX-3)**:跨 9 GSM state `_apply_state_matrix()` 後,Z1(HP/EXP)`get_global_rect()` 位移 == 0px(Z3/Z5/Z6 emphasis 升降唔 reflow Z1;absolute anchor)。
- [ ] **AC-SCENE-6(emphasis→render binding)**:`_apply_state_matrix(state)` → 每 element 真 node `modulate.a == get_emphasis_alpha(emphasis)`(HIDDEN/DEFER → `visible==false` 或 a==0);`_exp_bar_value` → EXP bar node value/size 反映(non-depleting HP 同理)。

---

## Implementation Notes

- `.tscn`:root Control(full-rect,`mouse_filter=IGNORE` 除 banner)→ children per UX Zones。**唔加 autoload**;main-scene 喺 CanvasLayer 50 instantiate(layer wiring 屬 main-scene story,本 story 只交付可 instantiate 嘅 .tscn + main-scene mount 指引)。
- **node binding(改 `gym_mode_hud.gd`)**:加 nullable `@onready var _hp_bar` / `_exp_bar` / `_stat_block` / `_skills_cluster` / `_prog_label` / `_boss_bar` / `_banner`。喺 `_apply_state_matrix` / `_redraw_stat` / `_set_immediate` / `_snap_bars_to_current` 末端 `if node != null: node.modulate.a = get_emphasis_alpha(...)` / `node.value = _exp_bar_value`。**internal var 仍係真相源**(test 無 scene 注 var,有 scene 額外 update node)——現有 90 test 零改動。
- metadata 用 `set_meta()` 喺 .tscn(或 `_ready` 補設):`glance_group` / `cluster_icon_cap` / `glance_visible`。
- Z1 absolute:anchor preset top-left fixed offset(唔受 sibling resize 影響);Z3/Z5/Z6 separate layout container。
- banner:`Button`(或 Control + `gui_input`)`focus_mode=FOCUS_NONE`,`custom_minimum_size=(44,44)`,bottom-center anchor;`pressed` → `_on_banner_tapped()`。
- emphasis→visible:HIDDEN/DEFER → `visible=false`;其餘 `visible=true` + `modulate.a=get_emphasis_alpha()`。

---

## Out of Scope

- Story 011:N=12 真人 glance playtest(AC-V-1)+ colorblind/shake **human visual sign-off**(本 story 只交付可截圖嘅 rendered scene,唔做 sign-off)。
- Art assets:P-04 skill silhouette glyph / P-11 threat-chevron 實際美術(art-director / asset pipeline;本 story 用 placeholder shape + 正確 metadata/geometry channel)。
- Main-scene CanvasLayer 50 mount + layer ordering(屬 main-scene composition story;本 story 交付 .tscn + mount 指引)。
- #21 loot modal node(絕不喺 #20 scene)。

---

## QA Test Cases

- **AC-SCENE-1/2**:Given `load("res://.../GymModeHud.tscn").instantiate()`;Then 無 error、root is Control with script、WorkoutAudioAdapter child + 6 zone nodes 喺 path。
- **AC-SCENE-3**:Given instantiated scene;Then SKILLS cluster `glance_group==true` + `cluster_icon_cap==4`;run `check_glance_tier1_count.gd` → exit 0。
- **AC-SCENE-4**:Given banner node;Then `focus_mode==FOCUS_NONE`、`size>=44×44`、rect 不交疊 Z1。
- **AC-SCENE-5**:Given scene;When 依次 apply 9 state matrix;Then Z1 `get_global_rect()` 跨 state 不變(0px)。
- **AC-SCENE-6**:Given scene;When apply WORKOUT_ACTIVE;Then HP/EXP node `modulate.a==1.0`、STAT/SKILLS `modulate.a==0.22`(◐);When LOOT_DROP;Then PROG `visible==false`(▽)、HP `modulate.a==0.55`(○dim)。

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `tests/integration/gym_mode_hud/test_hud_scene_structure.gd`(headless scene instantiate + node path + metadata + 0px anchor + emphasis→render) — must exist and pass · `production/qa/evidence/gym-mode-hud-scene-walkthrough.md`(manual visual walkthrough + lead sign-off, ADVISORY)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HUD .gd scaffold + matrix) · Story 002 (EXP bar value) · Story 004 (HP + SkillIconRegistry) · Story 006 (banner logic) · Story 007 (WorkoutAudioAdapter) · Story 008 (emphasis alpha) · Story 009 (glance count CI)
- **Unlocks**:
  - Story 009 deferred — AC-U-3 cluster metadata (glance_group / cluster_icon_cap) + AC-UX-3 0px anchor (now scene-backed, headless-verifiable)
  - Story 011 — AC-UX-6/V-5 colorblind + AC-V-2/CR-1/13⑧ shake + AC-V-1 N=12 playtest (all need a rendered scene to screenshot/playtest)
- **Note**: 仍須 external — colorblind/shake **human sign-off** + AC-V-1 **N=12 playtest** + 真 art assets。本 story 移除「scene 未建」呢個 blocker,令 visual evidence 可開始收集。

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 6/6 passing (AC-SCENE-1..6 全部 headless-verified)
**Deviations**: node binding 用 nullable `@onready` + `_sync_nodes_to_state()` — internal var 仍係真相源，pure-logic test（script `.new()` 無 scene children）node null → no-op，**90 個現有 test 零改動**。WorkoutAudioAdapter 加 autoload fallback（scene-mount 時無人 inject DI → resolve real autoload；stub-inject test 不受影響）。mid-tween smooth bar animation 留 polish（node 喺 discrete sync points 反映 = apply_state / set_immediate / tween_finished / snap）;art assets（P-04 silhouette / P-11 threat glyph 實際美術）+ main-scene CanvasLayer 50 mount 屬 out-of-scope。
**Test Evidence**: UI — `tests/integration/gym_mode_hud/test_hud_scene_structure.gd` (10 test functions, 10/10 pass; gym dirs 12 scripts 131 tests). Full gate 245 scripts / 1525 pass / 0 fail / 1 pre-existing pending. Manual visual walkthrough (`production/qa/evidence/gym-mode-hud-scene-walkthrough.md`) deferred 到有真渲染 + art assets。
**Code Review**: Complete — APPROVED (.tscn headless instantiate、nullable binding backward-safe、cluster metadata 解鎖 009、banner FOCUS_NONE+44、Z1 0px reflow 解鎖 011 AC-UX-3、emphasis→modulate.a 鏡射、adapter autoload fallback;對 GDD States 矩陣 + UX Zones + ADR-0001/0006)
**Unlocked**: Story 009 deferred (cluster metadata CI + 0px anchor 而家 scene-backed headless-verifiable) · Story 011 visual base (rendered scene 可截圖/playtest)
**Files**: `src/ui/gym_mode_hud/GymModeHud.tscn` (created), `src/ui/gym_mode_hud/gym_mode_hud.gd` (@onready node refs + _node_for_element + _sync_nodes_to_state + 4 sync call-sites), `src/ui/gym_mode_hud/workout_audio_adapter.gd` (autoload fallback), `tests/integration/gym_mode_hud/test_hud_scene_structure.gd` (created)
