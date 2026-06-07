# Story 022: G-LM-2 — #5 LOOT pool reparent + PROCESS_MODE_ALWAYS + handshake

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — handshake + AC-75 property asserts + lazy-build EC1 + lifecycle hygiene(null deregister re-home — test isolation 發現);#5 GDD sync appendix;combined 2086/2085/0 fail;commit b8f6af7)
> **Layer**: Presentation(epic)/ 改動喺 Foundation #5
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-2 + Interactions #5 row + 其他 sync「#5 GDD」項)
**ADR**: ADR-0001(particle topology — G-LM-1 revision 前提)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(reparent 時序 + process mode;改 shipped #5)

**Control Manifest Rules**:
- Required:particle 經 wrapper(CI enforced);reparent 只可由 #5 自己做(owner)
- Forbidden:#21 直接掂 pool nodes

## Acceptance Criteria(G-LM-2 — 解封 AC-75 joint G-LM-1+2)

- [ ] **LOOT preset pool nodes reparent 入 CelebrationVFXLayer + per-slot `PROCESS_MODE_ALWAYS`**(現時 INHERIT + layer 0 — freeze 時 burst 凍結 + 被 saturation 降格雙 bug 修復)
- [ ] **`register_celebration_layer(layer)` handshake**:#5 expose,idempotent;reparent 時序 = post-#21-boot(pool 喺 #5 boot 已 add_child 到 wrapper,layer 等 #21 tail `_ready` 先存在)
- [ ] **AC-75**(freeze-immune property assert):freeze active(tree paused)→ LOOT pool nodes parent == CelebrationVFXLayer 且 `PROCESS_MODE_ALWAYS`
- [ ] **#5 GDD sync**:Section C #21 interaction contract + EC-18 [PROVISIONAL] actualize(無 re-peek,dedup by design)+ tier→preset mapping 確認(white/green/blue→LOOT_BURST、purple/orange→LOOT_RARE_BURST)+ Q-V4 部分閉
- [ ] **Combined CI gate green**(#5 existing tests 零變紅)

## Implementation Notes

- 非 LOOT presets 唔郁(combat particles 照 layer 0 + INHERIT — saturation 降格係 deliberate 明度尺)。
- Handshake idempotent:重複 register 同一 layer = no-op;#21 喺 `_ready` tail call。
- AC-75 係 property assert(integration),唔係 visual(visual 半邊 AC-87 → 027)。

## Out of Scope

- CelebrationVFXLayer 本體(002);ADR-0001 doc(001);burst 調用(006)。

## QA Test Cases

GDD AC-75 GWT + G-LM-2 gate text(qa-plan-import-equivalent);handshake idempotency + 時序 test(register 早於/遲於 pool warm)。

## Test Evidence

**Required**: `tests/integration/loot_reveal/test_particle_reparent.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 001(G-LM-1)、002(layer 存在)
- Unlocks: 026、027(AC-87)
