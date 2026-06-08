# Story 008: Claim flow + 4-code error map(零 raw HTTP)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 3/4 + AC-06/07/08/09/10/11/22/23;EC-A1/A2/A4)
**Requirement**: claim flow + 4-code error map（永不 leak raw HTTP）

**ADR Governing**: ADR-0002(primary — claim/token 契約)+ ADR-0006(GSM yield landing)
**ADR Decision Summary**: `POST /session/claim` + `X-Session-Token`;token 由 #2 存（#24 永不掂 persistence — Rule 15）；shell 等 GSM 離開 BOOTING 先轉場（yield landing，唔假設 IDLE）。
**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: **G-LS-3 BLOCKING** — `claim_session` async 簽名 + cancellation 語意未釘（await-coroutine vs completion-signal；SUSPENDED-cancel 唔掛死）。AC-06/07/08/22 **GATED** mock-scoped 先行。

**Control Manifest Rules**:
- Required: shell 唔 own persistence（token 由 #2 — Rule 15）
- Forbidden: leak raw HTTP code（#2 L310 contract — 4 code map）

---

## Acceptance Criteria

*GDD AC-06/07/08 [GATED G-LS-3] / AC-09/10/11/22/23:*

- [ ] **AC-06 [GATED]**: form submit enabled,tap submit → 即時 disable + loading;`claim_session_calls == 1`（防 double-submit）
- [ ] **AC-07 [GATED]**: claim success,mock GSM 仍 BOOTING → shell 唔切換 state（yield landing）
- [ ] **AC-08 [GATED]**: claim success + mock GSM emit `(BOOTING → LOOT_DROP)` → shell 入 `HIDDEN` 唔入 SHELL_IDLE（EC-A5 deferred reveal）
- [ ] **AC-22 [GATED]**: claim await 掛起,mock GSM emit SUSPENDED + injected clock 超 timeout → submit re-enable + copy 含「程序中途中斷」、**唔**含「登入失敗」（EC-A1）
- [ ] **AC-09**: `invalid_credentials` → inline「username 或者 password 唔啱」+ re-enable + copy 唔 match regex `\d{3}` **且** 唔含字面 `HTTP`/`http`
- [ ] **AC-10**: `network_error` → inline「而家連唔到」+ retry 掣 + 零 raw HTTP（deny-list 同 AC-09）
- [ ] **AC-11**: `server_error` → inline「伺服器嗰邊出咗少少問題」+ retry + re-enable + 零 raw HTTP
- [ ] **AC-23**: session conflict（#2 落 `server_error` bucket）→ server_error copy、零 conflict-specific / raw HTTP（EC-A2）

---

## Implementation Notes

- submit → button disable + loading 態 → `await GymSysClient.claim_session(u, p)`。
- **G-LS-3 cancellation pin（blocking）**：#2 cancel 唔 wait `request_completed` + `RESULT_CANCELED` / silent drop 都 acceptable → `await claim_session()` 可掛死（GDScript 冇 native await-timeout）。二擇一釘死:(a) `claim_session` 保證 resolve（SUSPENDED-cancel 返 cancelled-語意 `SessionClaimResult`）；或 (b) completion-signal + #24 race injected-clock timer。**未釘前 mock-scoped**：mock 返 cancelled-result 驗 timeout fallback。
- 4-code map：`invalid_credentials`（field-level，唔分邊欄）/ `network_error`（+retry）/ `rate_limited`（→ Story 006 倒數）/ `server_error`（+retry）。Copy = 廣東話口語 witness register。
- deny-list regex（AC-09 qa R6）：copy 唔 match `\d{3}` 且唔含 `HTTP`/`http`。

---

## Out of Scope

- Story 006:rate_limited 倒數 formula（本 story dispatch 落 Story 006）
- Story 015:login form 元素 spec（本 story 做 claim 行為）
- Story 009:update-required / misconfig sub-variant

---

## QA Test Cases

- **AC-06**: anti-double-submit
  - Given: submit enabled;When: tap;Then: 即 disable + loading + `claim_session_calls==1`
  - Edge cases: rapid tap → 後續無效（EC-A4）
- **AC-07/08**: yield landing
  - Given: claim success;When: mock GSM 仍 BOOTING / emit BOOTING→LOOT_DROP;Then: 唔切換 / 入 HIDDEN（非 SHELL_IDLE）
- **AC-22**: cancel fallback
  - Given: claim await 掛起;When: SUSPENDED + 超 timeout;Then: re-enable + copy 含「程序中途中斷」唔含「登入失敗」
- **AC-09/10/11/23**: error map + 零 raw HTTP
  - Given: claim 返 4 code 各；When: 收 result;Then: 對應 copy + re-enable/retry + copy 唔 match `\d{3}` 且唔含 `HTTP`
  - Edge cases: session conflict → server_error bucket（無獨立 code）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_login_shell_claim_flow.gd` + `test_login_shell_error_map.gd` + `test_claim_edge_cases.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(coordinator)+ Story 006(rate_limited 倒數)；**G-LS-3 pin（login form story 前 blocking）**
- Unlocks: Story 015(login form）

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 全 pass —
- **AC-06 [GATED]**:submit → 即 disable + loading + `claim_session_calls==1`;rapid re-tap no-op(EC-A4)
- **AC-07/08 [GATED]**:claim success + GSM BOOTING → 留 LOGIN(yield landing,唔假設 IDLE);GSM→IDLE → SHELL_IDLE;GSM→LOOT_DROP → **HIDDEN 唔 SHELL_IDLE**(EC-A5 deferred reveal)
- **AC-22 [GATED]**:claim 掛起 + GSM SUSPENDED **或** injected-clock 超 `CLAIM_TIMEOUT_MS` → cancel → re-enable + copy 含「程序中途中斷」**唔**含「登入失敗」(EC-A1);ghost result after cancel 被 ignore
- **AC-09/10/11/23**:4-code map(invalid_credentials inline 唔分欄 / network_error + retry / server_error + retry / session conflict → server_error bucket 無獨立 code)+ **零 raw HTTP**(deny-list:copy 唔 match `\d{3}` 且唔含 HTTP)
- rate_limited → Formula 1 countdown dispatch(story 006);unknown code → default-deny surfaced 唔 leak raw
**Test Evidence**: `test_login_shell_claim_flow.gd`(8)+ `test_login_shell_error_map.gd`(7)+ `test_claim_edge_cases.gd`(4)— **本地 19/19**(login_shell 全 95/95)。Combined gate + 全 lint(見 commit)。
**Design**: coordinator claim flow — `submit_claim`(anti-double-submit guard)+ `notify_claim_result(code, retry_after)`(completion callback,4-code match + default-deny)+ `_cancel_claim`(SUSPENDED/timeout,INTERRUPTED ≠ FAILED)+ `_try_complete_landing`(yield landing:`_claim_succeeded` + GSM 離 BOOTING 先清 auth)。advance() 加 claim-timeout(injected clock,GDScript 無 native await-timeout)。`_on_gsm` 加 SUSPENDED-cancel + yield-landing。
**G-LS-3 mock-scoped**: #2 `claim_session` async 簽名 + cancellation 未釘 + #2 stub → mock-scoped;test drive `notify_claim_result` 模擬 async 完成。真接線 = #2 erratum external。
**Deviations**: None。notify_claim_succeeded(story 003/004 簡化 path,即清 auth)同 notify_claim_result(&"success")(yield-landing)並存 — 前者係 scaffold,後者係正式 claim flow;story 003/004 test 仍用前者(GSM 已 IDLE,行為等效)。
**Code Review**: N/A spawn(本地全套 GUT + lint 等效)。
