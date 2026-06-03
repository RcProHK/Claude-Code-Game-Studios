# Story 008: Dim states + DIM_PRODUCT_FLOOR + emphasis alpha + EC-R6

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (Constants alpha 三軸, Tuning Knobs dim, KNOB-A/B, EC-R6, EC-S3 LOOT defer)
**Requirement**: GDD AC-KNOB-B / AC-EC-S3 + emphasis alpha (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps (primary)
**ADR Decision Summary**: dim 係 alpha 層,同 MoodController saturation 層正交;HUD layer topology。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: dim = HUD alpha/明度(非降飽和,保 amber semantic);`world_desaturation` × `base_dim` 正交無 joint danger(不同 layer/channel)。

**Control Manifest Rules**:
- Required: dim 讀 config const(`base_dim`/`loot_dim_multiplier`/`disconnect_dim_multiplier`/`freeze_dim_extra`);effective dim clamp `≥ DIM_PRODUCT_FLOOR`
- Forbidden: 字面 dim multiplier;降飽和(只降 alpha/明度)
- Guardrail: `DIM_PRODUCT_FLOOR=0.30`(防近全黑似 crash);alpha 三軸 invariant

---

## Acceptance Criteria

- [ ] **AC-KNOB-B(dim product floor systemic)**:`effective_dim = max(base_dim × state_multiplier, DIM_PRODUCT_FLOOR)`(兩 multiplier 均讀 const)。三 case:LOOT `max(0.5×0.4,0.30)==0.30`(clamp-active)/ SUSPENDED `max(0.5×0.7,0.30)==0.35`(at-product no-clamp)/ DISCONNECTED `max(0.5×1.0,0.30)==0.50`(no-clamp)。
- [ ] **emphasis alpha 三軸**:`◉`/`○` element effective alpha == `ambient_alpha(0.55)` 或更高(> threshold,餘光可見);`◐` == `deep_dim_element_alpha(0.22)`(< threshold,退出餘光);invariant `0.22 < deep_dim_alpha_threshold(0.35) < 0.55`。
- [ ] **EC-R6**:◐ deep-dim element 收 stat_changed → `set()` 更新值 skip tween(Story 003 機制);state 升 emphasis(◐→◉/○)→ 一次性 snap 到當前 value(唔回播 missed motion)。
- [ ] **AC-EC-S3(LOOT defer,fallback #21)**:GSM LOOT_DROP 但 #21 未 ready → HUD 主動 defer(HP/EXP ○dim、PROG ▽、絕不 fallback 自畫 loot 文字)。

---

## Implementation Notes

- dim 統一 `base_dim × state_multiplier` shape,clamp 落**最終乘積值**(KNOB-A:唔反推回 individual knob),log warning。
- `disconnect_dim_multiplier=1.0` 標 structural(非 tuning knob,留表只為 formula uniformity)。
- emphasis enum(◉/○/◐/▷/—/▽/❄)→ effective alpha 由 const derive(Story 009 CI 讀同一 const)。
- EC-R6 skip-tween 用 Story 003 `_active_tweens` 機制(◐ 唔 ++);emphasis-snap reconcile 對齊 bfcache(Story 010)「唔重播 missed motion」原則。
- LOOT defer:HUD 唔出 loot 文字(越界違 CR-13⑥ + Layer Discipline);留 seam #21 對接。

---

## Out of Scope

- Story 009:alpha invariant **CI boot-assert** + glance count(本 story 定 alpha 值 + emphasis apply)。
- Story 003:tween skip 機制本體(本 story EC-R6 只 apply 喺 ◐ element)。

---

## QA Test Cases

- **AC-KNOB-B**:Given base_dim=0.5 + 各 state multiplier const;When apply dim;Then LOOT==0.30(clamp)/SUSPENDED==0.35/DISCONNECTED==0.50(三 case 覆蓋 clamp-active/at-product/no-clamp);Edge: const 讀取非字面。
- **emphasis alpha**:Given element emphasis ◉/○/◐;Then effective alpha ≥0.55 / ==0.55 / ==0.22;invariant 0.22<0.35<0.55。
- **EC-R6**:Given ◐ element;When stat_changed;Then value set 無 tween;When ◐→○;Then 一次性 snap。
- **AC-EC-S3**:Given LOOT_DROP + #21 未 ready;Then HP/EXP ○dim、PROG ▽、無 loot 文字 node。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gym_mode_hud/test_dim_states_emphasis_alpha.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (matrix dispatch) · Story 003 (skip-tween 機制)
- Unlocks: Story 009 (glance CI 讀 alpha const)
