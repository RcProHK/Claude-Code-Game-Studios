# Story 025: G-LM-6 — platform_detect announce_aria + SR announcement

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation(epic)/ 改動喺 platform_detect + #21
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-6 / UI §B slot 7 / §E Accessibility)+ UX spec
**ADR**: N/A — platform gateway 慣例(`JavaScriptBridge.eval()` 只准經 `platform_detect.gd` — CI enforced)
**Engine**: Godot 4.6 | **Risk**: MEDIUM;**Engine Note**:4.5+ AccessKit 引入 — story 先 spike verify 4.6 web build 有冇 native a11y tree(防 double-announcement)

**Control Manifest Rules**:
- Required:`JavaScriptBridge.eval()` 經 platform_detect only(CI `check_platform_detect_callers.gd`)
- Forbidden:#21 直接 eval JS

## Acceptance Criteria(G-LM-6 — 解封 AC-77)

- [ ] **`announce_aria(text)` gateway 新增**(`platform_detect.gd` — 現時唔存在,grep 零 aria match;native build = no-op)
- [ ] **Boot inject hidden `aria-live` div**:live region 必須 first announcement 前已存在於 DOM
- [ ] **4.6 native a11y tree spike**:verify web build AccessKit 行為,防 double-announcement(結論記入 story 收線 note)
- [ ] **AC-77**(once-only):S3 entry → `announce_aria` exactly once(`"[Rarity] loot: [Item Name],來自 [source]. [Workout X%, RNG Y%]"`,RARE+ 先讀 breakdown,`aria-live=assertive`);fast-complete 入 S3 唔 double-announce;timing 唔受 motion_reduction 影響
- [ ] **Intra-queue short variant**:連環 reveal 用「[Rarity]:[Name]」(assertive 互斬下 full read 讀唔完);catch-up 收尾單一 aggregate announce(「N 件 loot 已收,最高 [tier]」— stream 逐件零 announce,grid 一次)
- [ ] **Combined CI gate green**

## Implementation Notes

- Banner `role=status` polite(016);reveal announcement assertive(本 story)。
- 全部 user-facing string 行 `tr()`(i18n)。
- 真 browser SR 行為 = manual ADVISORY(027 收)。

## Out of Scope

- Banner announce(016);真 SR 聽感 evidence(027);CJK font 指派(008/UX 已 locked)。

## QA Test Cases

GDD AC-77 GWT(qa-plan-import-equivalent);gateway spy:S3 natural / fast-complete 兩路 exactly-once;native no-op path。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_announce_aria.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 026、027
