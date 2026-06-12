# Story 008: Step 2 非綁定 combat preview + watermark + skip + real-workout abort

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 3.2 / Rule 5 / AC-07 / AC-16 / AC-18 / AC-21 / EC-03 / EC-15 — **Pillar 1 命脈**)
**UX**: `design/ux/onboarding-flow.md`（Preview screen + 試演 watermark + skip;UX-06/07/08）
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary,preview 借既有 combat render)
**ADR Decision Summary**: CanvasLayer topology;preview 借 #25/#14 既有 combat render,非綁定 scripted wave。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: preview showcase = 借既有 combat render（avatar auto-fight）;preview overlay `mouse_filter=IGNORE` 防偷 one-tap（UX-06,#25 先例）。preview scene config = Q-OB-1（MVP zone-1 enemy + CF-1 TIER_1 ability showcase）。

**Control Manifest Rules(this layer)**:
- Required: preview 明確「試演」watermark(Pillar 1 anti-deception)
- Forbidden: preview 寫 `loot.*`/`stat.*`/`ability.*`/`streak.*`、call #15 drop/daily-claim、call #11/#12 mutator（Rule 5;G-OB-2 守）
- Guardrail: preview load fail → graceful skip 零 crash（永不 block boot）

---

## Acceptance Criteria

- [ ] **AC-07** — GIVEN `PREVIEW`,WHEN preview 完成或 skip,THEN latch `step_preview`、轉 `COACHING`。
- [ ] **AC-16** — GIVEN preview 播放中,WHEN preview 整段運行,THEN persistence 無任何 gameplay namespace 寫入、#15 無 drop 生成、daily token 無 claim（非綁定驗證,Pillar 1）。
- [ ] **AC-18**（must-not-regress）— GIVEN `PREVIEW`,WHEN `#9 workout_started_forwarded` fire,THEN preview abort、`step_preview` latch as done-by-workout、轉 `COACHING`（EC-03,真實優先）。
- [ ] **AC-21** — GIVEN preview scene load 失敗,WHEN `PREVIEW` 入場,THEN graceful skip（`step_preview` latch）、零 crash、繼續流程（EC-15）。
- [ ] 「試演 / Preview」watermark 全程可見;skip affordance ≥44px;退場 cross-fade（UX-06/07）。

---

## Implementation Notes

*Derived from ADR-0001 / GDD Rule 5:*

- `src/ui/onboarding/preview_director.gd`（helper,非 autoload）:PREVIEW state 入場 → load preview scene（借既有 combat render）→ 播 scripted dummy wave + watermark + skip。
- **AC-16 非綁定**:preview 路徑零 gameplay namespace write、零 #15 call、零 #11/#12 mutator（G-OB-2 lint story 012 守）。純 cosmetic showcase。
- **AC-18 真實優先**:`workout_started_forwarded` → preview 即 abort、cross-fade 讓位真實 combat、`step_preview` latch as done-by-workout、COACHING。
- **AC-21 graceful degrade**:scene/asset load 失敗 → skip（step_preview latch）、零 crash、零空白屏（永不 block boot 喺 preview 上）。
- `preview_enabled=false` knob → 跳過（step_preview 即 latch）。
- preview overlay 非互動區 `mouse_filter=IGNORE`（UX-06 防偷玩家 one-tap）。

---

## Out of Scope

- Story 009: Step 3 class coach-mark（preview 之後）。
- Story 012: G-OB-2 lint（呢度 impl 非綁定;lint 驗 喺 012）。
- Q-OB-1: preview scripted wave 具體內容（epic/asset — MVP zone-1 + CF-1 TIER_1 showcase placeholder）。

---

## QA Test Cases

**AC-07(preview 完成/skip → COACHING)**:
- Given: FSM=PREVIEW
- When: preview 播完 OR tap skip
- Then: step_preview latched;FSM=COACHING
- Edge cases: skip 中途 = 合法完成

**AC-16(非綁定 — Pillar 1)**:
- Given: preview 整段運行
- When: 監察 persistence + #15
- Then: 零 gameplay namespace write;#15 零 drop;daily token 零 claim
- Edge cases: spy #15 claim-daily 未被 call;spy persistence write 只 `onboarding.*`

**AC-18(真實優先 abort)**:
- Given: FSM=PREVIEW 播緊
- When: `workout_started_forwarded` fire
- Then: preview abort;step_preview latch;FSM=COACHING
- Edge cases: abort 後底層真實 combat render 接管

**AC-21(graceful degrade)**:
- Given: preview scene load 失敗（fake load error）
- When: PREVIEW 入場
- Then: skip;step_preview latch;零 crash;FSM=COACHING
- Edge cases: 零空白屏卡死

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `tests/integration/onboarding_flow/test_step2_preview.gd`（AC-07/16/18/21）+ `production/qa/evidence/onboarding-preview-watermark-evidence.md`（UX-06 watermark + skip 視覺,人手）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007（step_connect → PREVIEW）
- Unlocks: Story 009（COACHING step 3）
