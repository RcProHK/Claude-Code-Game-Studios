# Story 005: Boot-window pull-check sweep(is_auth_required + get_pending_errors + sweep contract)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 2 boot-race + Boot-Window Signal Sweep 表 + AC-53/28;EC-E5/B1/B3/E6)
**Requirement**: G-LS-4(c)致命 + G-LS-8 — tail autoload boot-window race 收口

**ADR Governing**: ADR-0006(primary — boot order C4)+ ADR-0008(tail position)+ ADR-0003(Private Mode QUOTA boot)
**ADR Decision Summary**: signal-only model 對 tail subscriber 必有 boot-window race(producer `_ready()` emit 時 #24 未 connect → drop)→ pull-check 收口。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #2 AC-08(gymsys-backend-client.md L596)contract `_ready()` 同步 emit `auth_required` count==1 → #24 tail 必 miss → 黑屏(致命)。

**Control Manifest Rules**:
- Required: tail autoload 對最關鍵 boot signal 行 pull-check(唔靠 signal)
- Required: persistence-consumer test add_child 前注入 mock

---

## Acceptance Criteria

*GDD AC-53 [GATED G-LS-4] / AC-28 [GATED G-LS-8] + Boot-Window Sweep 表:*

- [ ] **AC-53 [GATED G-LS-4]**: mock `is_auth_required()` 返 `true`(add_child 前注入,模擬 #2 `_ready()` 同步 emit 已走漏)→ #24 `_ready()` 完成後 shell 已入 `LOGIN`(`LoginShellLayer.visible == true`)— **boot-race 由 pull-check cover,唔靠 signal**(EC-E5)
- [ ] **AC-28 [GATED G-LS-8]**: mock `get_pending_errors()` 返 `["QUOTA_EXHAUSTED"]`(add_child 前注入)→ `_ready()` 完成後 BannerStack 已有 ONGOING banner(`dismissable=false`)— boot-window gap pull-check cover(EC-B1/B3)
- [ ] `_ready()` 首批動作行 pull-check:`GymSysClient.is_auth_required()`(true → 直入 LOGIN)+ `PersistenceLayer.get_pending_errors()`(補顯示積壓 error)
- [ ] **EC-E6 contract assert**:上游 #8/#11/#12 persistence_failed signal 唔可喺自己 `_ready()` 同步 emit(boot-window sweep 表 contract;若改 boot-emit 須行 #3 deferred pattern)

---

## Implementation Notes

- `_ready()` 首批:`if GymSysClient.is_auth_required(): enter LOGIN`(唔等 signal — G-LS-4(c)additive getter);然後 `for e in PersistenceLayer.get_pending_errors(): banner_stack.enqueue(e)`(G-LS-8 additive)。
- `get_auth_block_reason()` 只分流 *reason*,唔 cover「是否需要 login」pull-state(godot B1)— 必須用 `is_auth_required()`。
- **GATED**:`is_auth_required` / `get_pending_errors` 係 #2/#3 additive API(未實作)→ mock-scoped 先行;真接線喺 #2/#3 erratum story(本 epic 後段或 cross-epic)。
- Boot-Window Signal Sweep 表係 ground truth:`auth_required`(HIGH 致命,pull)/ `critical_save_failed`(MED,pull)/ #8/#11/#12(LOW,contract assert)/ drain(None)/ GSM state_changed(cfis)。

---

## Out of Scope

- Story 010:banner stack severity 機制(本 story 只驗 boot-window enqueue)
- #2/#3 真 additive API 實作(cross-epic erratum;本 story mock-scoped)

---

## QA Test Cases

- **AC-53**: auth boot-race pull-check
  - Given: mock `is_auth_required()==true`(add_child 前注入);When: #24 `_ready()` 完成;Then: shell 已 LOGIN(LoginShellLayer.visible==true)
  - Edge cases: signal **唔** fire(模擬 drop)仍入 LOGIN — 證明唔靠 signal
- **AC-28**: pending error pull-check
  - Given: mock `get_pending_errors()` 返 `["QUOTA_EXHAUSTED"]`;When: `_ready()` 完成;Then: BannerStack 已有 ONGOING banner(dismissable=false)
  - Edge cases: 空 array → 零 banner;多 code → 多 banner enqueue

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_boot_window_pull_check.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(coordinator)+ Story 010(banner stack — pending error 要 enqueue 落 stack)
- Unlocks: None(boot-window 收口)
