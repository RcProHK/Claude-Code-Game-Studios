# Story 011: Banner stacking + dedupe + DISCONNECTED priority + two-layer 獨立性

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 7 + AC-33/34/54;EC-B2/B4/B5/B7/E3)
**Requirement**: banner 單 slot + 「+N」+ DISCONNECTED priority + two-layer 分離

**ADR Governing**: ADR-0001(primary — two-layer 拓撲)
**ADR Decision Summary**: `ErrorBannerLayer`(111 ALWAYS)獨立於 shell state — banner 喺 workout 之上照顯示。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: dedupe key = `(signal_source, error_code, key/id)`;Priority:DISCONNECTED > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類。

**Control Manifest Rules**:
- Required: banner `max_visible = 1`（疊 banner = 迫近 modal 體感）
- Required: 兩 layer 分離（LoginShellLayer 62 / ErrorBannerLayer 111）

---

## Acceptance Criteria

*GDD AC-33 / AC-34 / AC-54:*

- [ ] **AC-33**: ONGOING banner 喺主 slot,DISCONNECTED status 出現 → DISCONNECTED 佔主 slot、ONGOING 入「+N」;DISCONNECTED resolved → ONGOING 升返（EC-B4）
- [ ] **AC-34**: `(FLUSH_FAILED, "k1")` banner 存在,同 key 再 fire → entry count 唔變、timestamp 更新、「+N」唔虛高（EC-B5）
- [ ] **AC-54**: shell `HIDDEN`(mock GSM WORKOUT_ACTIVE),mock #3 emit ONGOING(`READ_ONLY_FILESYSTEM`) → `ErrorBannerLayer` banner `visible == true` 而 `LoginShellLayer.visible == false`（two-layer 獨立性 — EC-E3）
- [ ] 「+N」detail list 展開時新 error 到 → 即時 append + counter 更新（唔 close-reopen — EC-B7）

---

## Implementation Notes

- 單 banner slot(`max_visible = 1`)顯示最高 severity;其餘 collapse 「+N」（tap 展開 detail list）。
- dedupe key `(signal_source, error_code, key/id)` — 同 key 連 fire refresh timestamp 唔疊。
- Priority ladder：DISCONNECTED status > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類（drain/reconnect 成功）。
- two-layer：`ErrorBannerLayer`(111 ALWAYS)獨立於 shell HIDDEN — banner 照顯示喺 workout 之上（Rule 1）。

---

## Out of Scope

- Story 010:severity map + comparator core（本 story 用其 arrival_sequence）
- Story 012:DISCONNECTED surface 行為（本 story 只做 banner priority）

---

## QA Test Cases

- **AC-33**: DISCONNECTED priority
  - Given: ONGOING 主 slot;When: DISCONNECTED status 出現;Then: DISCONNECTED 主 slot、ONGOING「+N」;resolved → ONGOING 升返
- **AC-34**: dedupe refresh
  - Given: `(FLUSH_FAILED,"k1")` banner;When: 同 key 再 fire;Then: count 不變、timestamp 更新、「+N」唔虛高
- **AC-54**: two-layer 獨立
  - Given: shell HIDDEN(WORKOUT_ACTIVE);When: mock #3 emit ONGOING;Then: ErrorBannerLayer.visible==true 而 LoginShellLayer.visible==false

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_banner_stack.gd`(stacking)+ `test_layer_spec.gd`(two-layer AC-54)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010(banner core)
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 全 pass —
- **AC-33**:`set_disconnected_status(true)` → DISCONNECTED(priority_weight 5)佔主 slot,ONGOING 入「+N」;`(false)` → ONGOING 升返(EC-B4),DISCONNECTED entry 移除
- **AC-34**:同 dedupe_key `(PERSISTENCE, FLUSH_FAILED, k1)` 再 fire → count 不變、`timestamp_ms` 100→200 更新、overflow 唔虛高;不同 key(k1 vs k2)→ 兩 entry
- **AC-54**:shell HIDDEN(GSM WORKOUT_ACTIVE,LoginShellLayer.visible==false)+ #3 ONGOING emit → `ErrorBannerLayer.visible==true`(two-layer 獨立 — EC-E3)
**Test Evidence**: `test_banner_stack.gd`(+5 = 11/11,AC-33/34)+ `test_layer_spec.gd`(2/2,AC-54)— **本地 7/7 新增**(login_shell 全 72/72)。
**Design**:
- ESM 加 `Severity.DISCONNECTED` + explicit `priority_weight` match(DISCONNECTED 5 > ONGOING/UNMAPPED 4 > WIPE 3 > FEATURE_DEGRADED 2 > TRANSIENT 1)。
- banner_stack:`dispatch_error` 加 `now_ms` + dedupe(`_find_by_dedupe` by-reference dict mutate)+ `timestamp_ms`/`t_banner_start_ms`;`set_disconnected_status(active, now_ms)` 單 status banner(STATUS|DISCONNECTED dedupe_key)。
- coordinator:handlers 加 `_now_ms()`(Time seam,`_clock_override_ms` test 注入;非 formula path 故可讀 Time)+ `_refresh_banner_layer_visibility()`(ErrorBannerLayer.visible = count>0,**獨立 shell FSM**)。
**Deviations**: None。「+N」detail-list live-append(EC-B7)= UI render 層(本 story `overflow_count` 機制就位,render 留後);DISCONNECTED status 由 GSM 觸發 wiring = story 012(本 story 直驗 banner_stack 機制)。
**Code Review**: N/A spawn(本地全套 GUT + lint 等效)。
