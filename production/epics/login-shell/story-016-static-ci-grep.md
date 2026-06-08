# Story 016: Static-CI grep cluster(banner 靜態紀律 + credential + clock seam)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Config/Data(Static-CI)
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 8/15 + AC-35a/35b/36/50/51)
**Requirement**: banner 靜態紀律 + credential zero + clock seam（static-CI 守）

**ADR Governing**: ADR-0001(primary — 禁第二 BackBufferCopy)
**ADR Decision Summary**: banner backdrop opacity-only flat,禁第二 BackBufferCopy（#21 blur-CUT 同源）。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: source grep 排除 comment line（#21 `test_banner_telemetry.gd` 先例);scene-tree pattern 捉 .tscn instanced autoplay node（source grep 漏網）。

**Control Manifest Rules**:
- Required: banner 零 animation/pulse/audio（Rule 8 — Pillar 2 binding）
- Required: Formula 路徑唔直 call `Time.get_ticks_msec()`（讀注入 clock）

---

## Acceptance Criteria

*GDD AC-35a / AC-35b / AC-36 / AC-50(static) / AC-51:*

- [ ] **AC-35a**: 獨立 banner file `src/ui/login_shell/banner_stack.gd`,source grep(排除 comment) → 零 `create_tween` / `pulse` / `AudioStreamPlayer` / `\.play(`(token 收窄,唔誤殺合法 state-transition cross-fade tween — 嗰啲喺 `shell_transitions.gd`)。**CI step 必須 assert target file 存在,no-file ≠ no-match**
- [ ] **AC-35b**: `ErrorBannerLayer` scene,`find_children("*","AnimationPlayer",true)` + `find_children("*","AudioStreamPlayer",true)` → 皆空（捉 .tscn instanced node）
- [ ] **AC-36**: 兩 #24 layer scene,`find_children("*","BackBufferCopy",true)` → 空（禁第二 BackBufferCopy）
- [ ] **AC-50(static)**: #24 claim/error source path grep → 零 credential var 入 `print(`/`push_error(`
- [ ] **AC-51**: Formula 1/2 路徑 source grep → 零直 call `Time.get_ticks_msec()`（必讀注入 clock）

---

## Implementation Notes

- AC-35a CI grep step：target `banner_stack.gd` 必存在（assert file 存在 — 否則 grep 不存在檔案 = phantom pass);token 收窄至 banner-only,合法 cross-fade tween 喺 `shell_transitions.gd` 唔誤殺。
- AC-35b/36：scene-tree assertion（鏡 AC-36 pattern）— 捉 source grep 漏網嘅 .tscn instanced autoplay node。
- AC-50 static grep + AC-51 clock grep = CI step（同 #22/#23 credential/clock grep 先例）。

---

## Out of Scope

- Story 015:credential runtime clear（本 story 做 static grep）
- Story 006/007:formula 實作（本 story 守 clock seam grep）

---

## QA Test Cases

- **AC-35a**: banner 靜態 source grep
  - Given: `banner_stack.gd` 存在;When: grep(排除 comment);Then: 零 create_tween/pulse/AudioStreamPlayer/`.play(`
  - Edge cases: file 不存在 → fail（no-file ≠ pass）
- **AC-35b/36**: scene-tree
  - Given: ErrorBannerLayer + LoginShellLayer scene;When: find_children;Then: AnimationPlayer/AudioStreamPlayer/BackBufferCopy 皆空
- **AC-50/51**: credential + clock grep
  - Given: #24 source;When: grep;Then: 零 credential 入 print/push_error;Formula 路徑零直 call ticks

---

## Test Evidence

**Story Type**: Config/Data(Static-CI)
**Required evidence**: CI grep step + `tests/unit/login_shell/test_layer_spec.gd`(AC-35b/36 scene-tree)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010(banner_stack.gd)+ Story 015(credential path)+ Story 006/007(formula clock)
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 全 pass —
- **AC-35a**:`tools/ci/check_login_shell_static_discipline.gd` — banner_stack.gd source grep(strip full-line + trailing comment)→ 零 `create_tween`/`pulse`/`AudioStreamPlayer`/`.play(`;**target file 存在 assert**(missing → exit 2 FAIL,no-file ≠ phantom pass)。合法 cross-fade tween 喺 shell_transitions.gd 唔掃。
- **AC-35b**:`test_layer_spec.gd` — `ErrorBannerLayer.find_children("*","AnimationPlayer",true,false)` + AudioStreamPlayer 皆空(scene-tree,捉 .tscn instanced autoplay)
- **AC-36**:兩 #24 layer `find_children("*","BackBufferCopy",true,false)` 皆空(禁第二 BackBufferCopy)
- **AC-50(static)**:coordinator grep `(print|push_error|push_warning)\(.*(username|password|credential|secret|passwd)` → 零
- **AC-51**:shell_formulas.gd grep `Time.get_ticks_msec`(strip comment)→ 零(formula 讀注入 clock;AC-51 comment 提及 token 但 strip 後唔誤殺)
**Test Evidence**: CI lint `check_login_shell_static_discipline.gd`(本地 exit 0)+ `test_layer_spec.gd` AC-35b/36(本地 121/121)。Combined gate + 全 lint(見 commit)。
**Design**: 一個 `.gd` lint 三 check(AC-35a/50/51 source grep,comment-strip)+ GUT scene-tree(AC-35b/36)。codify 已建紀律(banner_stack 無 animation/audio;layers 無 BackBufferCopy;shell_formulas 無 Time 直 call;coordinator 無 credential log)。
**Deviations**: None。AC-50 credential runtime-clear 實作 = story 015(本 story static grep 守);現有 coordinator submit_claim 唔 log credential。
**Code Review**: N/A spawn(本地全套 GUT + lint 等效)。
