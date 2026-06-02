# Story 009: BGM variant rotation + BGM_MIN_LOOP_SEC

> **Epic**: Audio Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-004`, `TR-audio-008`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: N/A — GDD-owned BGM variation strategy（anti-fatigue rotation + no-throw loop-length warning）。Secondary: ADR-0001（BGM bundle size budget — `MAX_BGM_BUNDLE_MB`）。
**ADR Decision Summary**: BGM variation 係 #4 自有 spec（multi-variant rotation pool，non-immediate-repeat）；無獨立 architectural ADR。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `AudioStreamOggVorbis.loop=true` 永遠**唔** emit `finished`（Godot 4.6 confirmed）→ rotation 需 **non-looping OGG**（`loop=false`）+ `AudioStreamPlayer.finished`（deferred signal，~1 frame gap）→ rotate + 第二 BGM player crossfade。「near-gap-free（≤1 frame）」，真無縫 = 提前 fade_sec（post-MVP）。

**Control Manifest Rules (Foundation)**:
- Required: non-looping OGG authoring（loop=false）；non-immediate-repeat rotation；no-throw loop-length warning
- Forbidden: looped OGG 靠 `finished` rotate（永不 fire）；claim 真 gap-free（實 ≤1 frame）
- Guardrail: BGM bundle ≤ `MAX_BGM_BUNDLE_MB`（CI build-time gate）；`FOCUS_LOW_VARIANT_COUNT × BGM_MIN_LOOP_SEC` cross-knob 互鎖

---

## Acceptance Criteria

- [ ] **AC-27** GIVEN BGM track loop length < `BGM_MIN_LOOP_SEC`，WHEN boot / load BgmCatalog，THEN push_warning 一次（帶 track_id + actual_loop_sec）+ track 仍可正常播（非 reject / 非 push_error / 唔 crash）
- [ ] **AC-29** GIVEN `focus_low_pool` variant count==`FOCUS_LOW_VARIANT_COUNT`（N=3），WHEN 連續 rotate N×3（=9）次，THEN 冇任何兩個**相鄰** rotation 播同一 variant（non-immediate-repeat）

---

## Implementation Notes

*Derived from GDD Visual/Audio BGM rotation note + Rule 8:*

- BGM variant = **non-looping OGG**（`loop=false`）；`AudioStreamPlayer.finished`（自然播完）→ rotate 下一 variant（non-immediate-repeat）+ 用第二 BGM player（Story 005 crossfade 架構）equal-power crossfade。重用 `_crossfade_tween`，把「loop-boundary crossfade」同「state-transition crossfade」統一。
- **`finished` 係 deferred signal**（~1 frame gap）→ wording「near-gap-free（≤1 frame）」，**唔** claim 真 gap-free。AC-29 只驗 rotation **順序**（non-immediate-repeat），**唔斷言 zero-gap**（headless 無法量 frame-level gap）。
- **non-immediate-repeat 算法**：每次 rotation 從 pool 排除剛播完嘅 variant，再 seeded pick；GUT 可 deterministic 斷言順序。
- `BGM_MIN_LOOP_SEC`（default 90s）：boot warning（runtime no-throw）+ **CI build-time lint 掃 BgmCatalog 所有 track loop_sec**，任一 < min → CI fail（同 bundle-size gate posture）。

---

## Out of Scope

- Story 005: crossfade primitive（rotation 重用，唔重寫）
- stem-based intensity ramp（Q-A1，post-MVP）
- 真 gap-free 提前排程 crossfade（post-MVP）
- BGM bundle-size CI gate script（屬 tools/ci，可併入呢 story 或獨立 CI task）

---

## QA Test Cases

- **AC-27**: short-loop boot warning — Given BgmCatalog 有 track loop_sec=30 < 90 / When boot load / Then push_warning once（含 track_id + 30）+ track 仍播（無 push_error，無 crash）。Edge: loop_sec >= 90 → 無 warn。
- **AC-29**: rotation non-immediate-repeat — Given `focus_low_pool` N=3 variants / When rotate 9 次（seeded）/ Then 序列無相鄰重複（v[i] != v[i-1] 全程）。Edge: N=1 → 只一 variant（無得避免重複，spec 允許 — 或 warn）；N=2 → 嚴格交替。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/test_bgm_rotation_min_loop.gd` — must exist and pass（+ optional CI lint `tools/ci/check_bgm_loop_length.gd`）（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 005 (crossfade primitive reused for rotation)
- Unlocks: None
