# Story 009: LOGIN sub-variant dispatch(get_auth_block_reason → normal / update / misconfig)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 2 + AC-04/05 + States LOGIN sub-variant)
**Requirement**: G-LS-4 — `get_auth_block_reason()` pull-model 分流

**ADR Governing**: ADR-0002(primary — #2 auth API)
**ADR Decision Summary**: forbidden-signal 禁令下,pull-model getter 係 P0-6/P0-7 prompt 唯一合法渠道。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: **G-LS-4 GATED** — `get_auth_block_reason() -> StringName` 係 #2 additive API（未實作）→ mock-scoped 先行。

**Control Manifest Rules**:
- Required: pull-model getter（forbidden-signal 禁令下唯一合法路徑）
- Forbidden: 訂閱 11 個 forbidden signal（4-signal whitelist）

---

## Acceptance Criteria

*GDD AC-04 / AC-05 [GATED G-LS-4]:*

- [ ] **AC-04 [GATED]**: LOGIN 入場,mock `get_auth_block_reason()` 返 `&"update_required"` → 顯示 update prompt、**唔顯示 form**
- [ ] **AC-05 [GATED]**: 同上 `&"carve_out_misconfig"` → operator prompt + `acknowledge_carve_out_fix()` 指引
- [ ] `&"none"` → normal form（username/password/toggle/submit）
- [ ] LOGIN 入場經 pull-model getter 分流（唔靠 signal）

---

## Implementation Notes

- LOGIN 入場 call `GymSysClient.get_auth_block_reason() -> StringName` 分流：`&"none"` → normal / `&"update_required"` → 「呢個版本舊咗,要更新先連到」prompt（唔顯示 form）/ `&"carve_out_misconfig"` → operator-facing prompt + `acknowledge_carve_out_fix()`（#2 L149 真存在）指引。
- **GATED**：`get_auth_block_reason` additive（mock-scoped 先行；真接線 #2 erratum story）。
- Q-LS3：misconfig prompt MVP 傾向 instruction text only（operator 用 console 都得）。

---

## Out of Scope

- Story 005:`is_auth_required()` boot-race（本 story 係 reason 分流,唔 cover「是否需 login」pull-state）
- Story 015:normal form 元素實作

---

## QA Test Cases

- **AC-04**: update-required
  - Given: LOGIN 入場,mock `get_auth_block_reason()==&"update_required"`;When: render;Then: update prompt + 無 form input
- **AC-05**: misconfig
  - Given: 同上 `&"carve_out_misconfig"`;When: render;Then: operator prompt + acknowledge 指引
  - Edge cases: `&"none"` → normal form

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_login_shell_block_reason.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(FSM — LOGIN entry)；**G-LS-4 mock-scoped**
- Unlocks: None
