# Story 012: DISCONNECTED surface + reconnect(workout banner-defer / non-workout shell)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 9 + AC-37/37b;EC-C1/C3)
**UX Spec**: `design/ux/login-gymsys-connection-ui.md`(DISCONNECTED_SHELL wireframe + disconnect banner)
**Requirement**: DISCONNECTED 誠實 + 唔築牆;reconnect affordance

**ADR Governing**: ADR-0002(primary — cursor-replay「會補返」依據)+ ADR-0003(unsynced-only client wins)
**ADR Decision Summary**: GymSys = workout 數據 system of record;cursor replay + #8 retro-credit + #21 catch-up 保證 reconnect 後補返 — 斷線唔損數據只 delay 反映。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: **G-LS-4 GATED(37b)** — `request_immediate_poll()` 係 #2 additive（公開 surface 現冇 immediate-poll API）。

**Control Manifest Rules**:
- Required: reconnect 唔自己寫 backoff（節奏 #2 職責;掣係 sense-of-agency affordance）
- Required: #33 EC-13 carve-out（DISCONNECTED + pending tap → input permitted）

---

## Acceptance Criteria

*GDD AC-37 / AC-37b [GATED G-LS-4]:*

- [ ] **AC-37**: mock GSM `WORKOUT_ACTIVE → DISCONNECTED` → shell **唔**入 DISCONNECTED_SHELL（留 HIDDEN）;ErrorBannerLayer 顯示 peripheral banner 含「GymSys 照記住」copy + tappable「再試一次」;零全屏轉場
- [ ] **AC-37b [GATED]**: AC-37 banner,tap「再試一次」→ spy 收 `GymSysClient.request_immediate_poll()` call==1
- [ ] non-workout DISCONNECTED → shell `DISCONNECTED_SHELL` state:reconnect affordance + 入口照 enabled（對齊 #22 EC-30,唔 grey）+ 斷線 status
- [ ] DISCONNECTED↔IDLE 高速 toggle → 入口狀態唔變（flicker 天然消失 — EC-C1）;banner 永不 debounce

---

## Implementation Notes

- (a) workout 進行中（WORKOUT_ACTIVE 系跌入）→ bottom peripheral banner「連線斷咗 — 你嘅訓練 GymSys 照記住,連返之後自動補返。」+「再試一次」text 掣（tap → `request_immediate_poll()` — G-LS-4 additive,**唔自己寫 backoff**）。
- (b) non-workout → `DISCONNECTED_SHELL` state:reconnect + 入口 enabled（本地 view）+ status。
- 斷線 copy 誠實依據：cursor-replay + retro-credit + catch-up 保證補返 →「照記住會補返」係真話。
- **GATED**：`request_immediate_poll()` additive（mock-scoped spy 驗 call==1;真接線 #2 erratum）。

---

## Out of Scope

- Story 013:入口 affordance 三態 + arbiter（本 story 只 DISCONNECTED status + reconnect）
- Story 004:mid-workout 401 banner-defer（本 story 係 DISCONNECTED 唔係 auth）

---

## QA Test Cases

- **AC-37**: workout 斷線 peripheral
  - Given: mock GSM WORKOUT_ACTIVE→DISCONNECTED;When: 轉換;Then: shell 留 HIDDEN + ErrorBannerLayer peripheral banner「GymSys 照記住」+ tappable「再試一次」+ 零全屏轉場
- **AC-37b**: reconnect 接 #2
  - Given: AC-37 banner;When: tap「再試一次」;Then: spy `request_immediate_poll()` call==1
- **EC-C1**: flicker-free
  - Given: DISCONNECTED↔IDLE 500ms toggle;When: toggle;Then: 入口狀態唔變（兩 state 都 enabled）;banner 唔 debounce

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_disconnected_surface.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(FSM)+ Story 010(banner)；**G-LS-4 mock-scoped(37b)**
- Unlocks: None
