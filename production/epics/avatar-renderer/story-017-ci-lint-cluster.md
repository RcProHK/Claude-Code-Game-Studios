# Story 017: CI lint suite CI-1..6 + AC-29 schema + AC-30 zero-ceremony grep

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data (Static-CI)
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CI Lint Suite (CI-1..6) / CR-6/7/11/16/17 / AvatarVisualState schema / INV
**Requirement**: AC-23/24/25/26/27/28/29/30(GDD 直接 trace — 8 static AC)
**ADR Governing Implementation**: ADR-0010 Mirror Moment Ownership(primary — AC-30 CR-17 zero-ceremony 係 ownership 命脈)· ADR-0001(z-order)
**ADR Decision Summary**: ADR-0010 render-only boundary — #26 source 零 ceremony composition,CI-grep 守(同 #29 CI-MM-1 對稱守 seam 兩邊)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: lint scripts = `tools/ci/check_avatar_*.gd`;headless `--script` run,exit≠0 = fail。**lint sweep check exit code,唔係 grep FAIL**(reference lint_allowlist lesson)。

**Control Manifest Rules (Presentation layer)**:
- Required: 6 CI lint(CR-6/4/11/7/16 + AnimationPlayer)+ zero-ceremony grep(CR-17)
- Forbidden: lint 漏 owner file;`AnimationPlayer` token in #26 source
- Guardrail: 每 lint exit-code-checked,non-zero blocks CI

---

## Acceptance Criteria

- [ ] **AC-23**(CI-1):任何 `AvatarVisualState.*` field write 喺 `avatar_renderer.gd::_derive_state_from_canonical()` 外 → exit≠0
- [ ] **AC-24**(CI-2):零 hardcoded tier-threshold literal in `.gd`(全 from `.tres`)+ `BFCACHE_CONTINUE_THRESHOLD_MS` parity assert(== #15.Rule17,INV-5)
- [ ] **AC-25**(CI-3):零 `set_/mutate_/force_/inject_` prefix on `avatar_renderer.gd` public surface
- [ ] **AC-26**(CI-4):avatar z_index∈[-10,10];CanvasLayer.layer==10;particle Z≥20
- [ ] **AC-27**(CI-5):`dominant_class` path 只 reference `#11.get_stat(STR/DEX/VIT)` — no derived/ability/loot/streak/workout
- [ ] **AC-28**(CI-6):`AnimatedSprite2D.sprite_frames` assignment 只喺 `avatar_renderer.gd` AND 零 `AnimationPlayer` token in #26 source
- [ ] **AC-29**:`AvatarVisualState` resource 全 declared field present + 每個 trace canonical source in `derived_from`;`schema_version` present
- [ ] **AC-30**(CR-17 / ADR-0010 命脈):grep #26 source(`src/autoload/avatar_renderer.gd` + `src/ui/avatar*`)→ **zero ceremony composition**(no 9:16 canvas, no ghost-overlay compositing, no screenshot prompt, no share UI)

---

## Implementation Notes

*Derived from CI Lint Suite + AC-30 ownership 命脈:*

- 6 lint script `tools/ci/check_avatar_*.gd`:CI-1 derivation / CI-2 data-driven+parity / CI-3 no-setter / CI-4 z-order / CI-5 class-purity / CI-6 sprite_frames-assign+no-AnimationPlayer。
- **AC-30 zero-ceremony grep = ADR-0010 ownership 命脈**(同 #29 CI-MM-1 對稱守 render-vs-ceremony seam 兩邊):grep `src/autoload/avatar_renderer.gd` + `src/ui/avatar*` 零 ceremony token(9:16/portrait/ghost-compositing/screenshot/share)。可做獨立 `check_avatar_renderer_no_ceremony.gd`。
- **lint 必 grep owner file**(防 main RED — feedback_full_agent_review_gatekeep);CI-1/CI-3 等 gateway-lint 要 exempt owner-that-defines-seam(若適用)。
- AC-29 schema static = `AvatarVisualState` field completeness + derived_from attribution。

---

## Out of Scope

- 各 CR 行為實現(本 story 只 lint enforcement;行為喺 003-016)
- #29 CI-MM-1(對稱 lint,#29 epic)

---

## QA Test Cases

- **AC-23..28 (CI-1..6)**: lint enforcement
  - Given: 違規 fixture(field write outside derive / hardcoded threshold / setter prefix / z_index>50 / impure class path / AnimationPlayer token)
  - When: run lint script headless
  - Then: exit≠0 on violation;exit==0 on clean
  - Edge cases: owner-file self-match exempt;CI-2 parity assert fires on mismatch
- **AC-30**: zero ceremony grep
  - Given: #26 source
  - When: grep ceremony token
  - Then: zero match(9:16/ghost-compositing/screenshot/share)
  - Edge cases: token only in「NO ceremony」guard comment OK
- **AC-29**: schema
  - Given: AvatarVisualState
  - When: static field check
  - Then: 全 field present + derived_from + schema_version

---

## Test Evidence

**Story Type**: Config/Data (Static-CI)
**Required evidence**: lint scripts 存在 + 跑 green(`tools/ci/check_avatar_*.gd` exit 0 on clean tree);violation-fixture 驗 exit≠0;smoke `production/qa/smoke-*.md` lint sweep green
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002-016(lint targets 實現後)
- Unlocks: epic 收線(static gate)
