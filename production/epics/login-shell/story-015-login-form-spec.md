# Story 015: Login form 規格 + credential residue 防護

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 13/15 + AC-12/50;EC-A3)
**UX Spec**: `design/ux/login-gymsys-connection-ui.md`(LZ-Form wireframe + Component Inventory + Localization)
**Requirement**: login form 元素 + credential residue zero

**ADR Governing**: N/A — form UI（依賴 G-LS-3 claim signature + G-LS-6 spike 路線）
**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: MVP canvas `LineEdit` **攞唔到 browser password manager / Keychain autofill**（canvas 對 DOM 隱形)；DOM `<input>` overlay v0.2 候選（必經 platform_detect JavaScriptBridge seam — ADR-001 forbidden pattern)。**路線由 Story 001 G-LS-6 spike 裁決**。

**Control Manifest Rules**:
- Required: 全 interactive target ≥44×44px;input font ≥16px;keyboard-only 可完成
- Forbidden: credential var 入 `print(` / `push_error(`（web console observable）

---

## Acceptance Criteria

*GDD AC-12 / AC-50:*

- [ ] **AC-12**: form render,`find_children()` → 存在 username/password(`secret==true`)/toggle/submit;**唔**存在 remember-me / 註冊 / 忘記密碼元素
- [ ] **AC-50**: #24 claim/error 全 source path,static grep → 零 credential var(username/password)入 `print(` / `push_error(`;password `LineEdit.text` 喺 claim resolve 後 clear
- [ ] show-password toggle（眼睛 icon,≥44px);keyboard tab 順序 username → password → toggle → submit
- [ ] username 限 ASCII（GymSys schema — G-LS-3 連帶);input font ≥16px display
- [ ] **credential residue**：claim resolve(success 或任何 failure)後 password `LineEdit.text` 即清空;`invalid_credentials` 後保 username 清 password（同 EC-A3 re-enter 保留協調）

---

## Implementation Notes

- form：username + password(`LineEdit.secret=true`) + show-password toggle(眼睛 ≥44px) + submit。**無** remember-me（token persist 係 default — 30 日 TTL）/ 無註冊 / 無忘記密碼（GymSys 帳號管理喺本體 — anti-scope）。
- **credential residue（ui R5）**：claim resolve 後 password text 即清;Pillar 1 大量 error surfacing 令 console observable → claim/error path 零 credential var 入 print/push_error（AC-50 static grep 守)。
- **路線依賴 Story 001**：若 spike 裁 LineEdit MVP-OK → canvas LineEdit;若 iOS 連 keyboard 都彈唔出 → DOM overlay（platform_detect seam）。
- 誠實申報：MVP 無 password manager / Keychain autofill（靠 30 日 token 令 re-login 罕見)。

---

## Out of Scope

- Story 008:claim 行為 + error map（本 story 做 form 元素 + residue）
- Story 016:credential grep CI（AC-50 static — 本 story 做 runtime clear,016 做 grep step）
- Story 001:iOS spike（本 story 消費其裁決）

---

## QA Test Cases

- **AC-12**: form 元素
  - Given: form render;When: `find_children()`;Then: username/password(secret)/toggle/submit 存在;remember-me/註冊/忘記 不存在
- **AC-50**: credential residue
  - Given: claim resolve(success/failure);When: 檢查 password LineEdit.text;Then: 已清空;static grep 零 credential 入 print/push_error
  - Edge cases: `invalid_credentials` → 保 username 清 password;EC-A3 re-enter 保 username

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_login_form_spec.gd` + `test_credential_residue.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001(G-LS-6 路線裁決)+ Story 008(claim flow);**G-LS-3 pin**
- Unlocks: None
