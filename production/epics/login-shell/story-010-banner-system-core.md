# Story 010: Banner 系統 core(severity map + source-first dispatch + UNMAPPED + total-order comparator)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 5/6/7 + AC-26/29/29b/30/31/32/52;EC-B9)
**Requirement**: anti-lie 收口 — 4-system error consumer，zero-silent-swallow

**ADR Governing**: ADR-0003(primary — Private Mode QUOTA detect-and-gate)+ ADR-0009(signal payload)
**ADR Decision Summary**: `error_severity_map.tres` data-driven；signal payload minimal+intrinsic。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 4.6 `sort_custom` **非 stable** + `Array[StringName].sort()` 按 pointer 唔按字面（reference_stringname_sort）→ comparator 必須 **total order `(severity_class, arrival_sequence)`**，StringName 比較先轉 String。

**Control Manifest Rules**:
- Required: signal payload minimal+intrinsic；late-bind 經 read API + null branch（ADR-0009）
- Required: 每 error handler 產生 visible state change（zero silent-swallow）

---

## Acceptance Criteria

*GDD AC-26/29/29b/30/31/32/52:*

- [ ] **AC-26**: 空 BannerStack + 4 upstream error signal connect,逐一 mock emit（帶 payload）→ 每次 `entries.size()` 恰好 +1,新 entry `dedupe_key == (source, error_code, key)` 且 `severity_class == Rule 6 對應 class`（非 tautological — 錯 severity/錯 key/空 banner 都 fail）
- [ ] **AC-29**: 同 frame FEATURE_DEGRADED(#8)+ ONGOING(`READ_ONLY_FILESYSTEM`) → 主 slot = ONGOING、FEATURE_DEGRADED 入「+N」（severity order）
- [ ] **AC-29b**: 同 frame 兩個同 class（#11+#12 FEATURE_DEGRADED）→ 主 slot 由 `arrival_sequence`（單調 int）決定、跨 run 一致（deterministic tie-break）
- [ ] **AC-30/31/32**: `error_severity_map.tres` — ONGOING 2 codes(`dismissable=false`) / WIPE 8 codes(`acknowledge_dismissable=true` + wipe copy key)、#8/#11/#12 sibling(`FEATURE_DEGRADED + auto_clear_on_success=true`) / TRANSIENT 2 codes(F2 TTL)
- [ ] **AC-52**: mock #3 emit 唔喺 12-code 嘅 `error_code`（e.g. `"FUTURE_CODE_13"`）→ ONGOING-weight 可見 banner（UNMAPPED default-deny）— 零 silent drop（EC-B9）

---

## Implementation Notes

- **source-first dispatch（明文）**：`if source ∈ {#8,#11,#12} → FEATURE_DEGRADED`（由 signal source 判定，唔睇 error_code — 防同名 code 撞）；`elif source == #3 → error_severity_map.tres[error_code]` lookup。
- **UNMAPPED default-deny**：lookup miss → fallback ONGOING-weight 重 banner（copy「偵測到未知存檔問題」），never silent。
- **total-order comparator**：`(severity_class, arrival_sequence)`,`arrival_sequence` = 單調遞增 int counter（每條 enqueue assign）；StringName 比較（dedupe key）先轉 String。
- `error_severity_map.tres` data-driven（新 code designer 改 .tres）。Map↔#3 enum drift 由 G-LS-8 keyset-coverage test 防（map.keys() ⊇ #3 live enumeration）。

---

## Out of Scope

- Story 011:stacking/dedupe/priority + two-layer 獨立性
- Story 007:F2 TTL formula（本 story 引用）

---

## QA Test Cases

- **AC-26**: zero-silent-swallow（真斷言）
  - Given: 空 stack + 4 signal connect;When: 逐一 emit(帶 payload);Then: entries.size() 每次 +1 + dedupe_key 正確 + severity_class 正確
  - Edge cases: 錯 severity / 錯 key / 空 banner = fail（非 tautological）
- **AC-29/29b**: severity order + tie-break
  - Given: 同 frame 兩 banner;When: enqueue;Then: 主 slot per (severity, arrival_sequence) deterministic 跨 run 一致
- **AC-30/31/32**: severity map
  - Given: .tres 載入;When: 逐 code 查;Then: 2 ONGOING / 8 WIPE / 3 sibling FEATURE_DEGRADED / 2 TRANSIENT（12+3 全 assert）
- **AC-52**: UNMAPPED default-deny
  - Given: mock #3 emit `"FUTURE_CODE_13"`;When: dispatch;Then: ONGOING-weight banner 出現，零 silent drop

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_zero_silent_swallow.gd` + `test_severity_map.gd` + `test_banner_stack.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(banner_stack.gd 殼)+ Story 007(F2 TTL)
- Unlocks: Stories 005/011/012/014(全部依賴 banner stack)

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 全 pass —
- **AC-26**:4 upstream signal(#3/#8/#11/#12)wire → 逐 emit `entries.size()` 恰好 +1 + `dedupe_key == (source, error_code, key)` + `severity_class` 正確(non-tautological:#8 FLUSH_FAILED → FEATURE_DEGRADED by SOURCE,**唔** WIPE — collision guard)
- **AC-29**:同 frame FEATURE_DEGRADED + ONGOING → main slot = ONGOING(severity order,arrival 唔override)
- **AC-29b**:同 class(#11+#12)→ main slot 由 `arrival_sequence`(monotonic int)deterministic,跨 5 run 一致
- **AC-30/31/32**:`error_severity_map.tres` — 2 ONGOING(dismissable=false)/ 8 WIPE(acknowledge-dismissable)/ 2 TRANSIENT(F2 TTL 5.0)/ 3 sibling source-first FEATURE_DEGRADED(auto_clear_on_success)— 12+3 全 assert
- **AC-52**:unmapped #3 code(FUTURE_CODE_13)→ UNMAPPED(ONGOING-weight)可見 banner,零 silent drop(EC-B9 default-deny)
**Test Evidence**: `test_severity_map.gd`(8)+ `test_zero_silent_swallow.gd`(5)+ `test_banner_stack.gd`(6)— **本地 19/19**(login_shell 全 65/65)。Combined **2439 tests / 2438 pass / 0 fail / 1 pre-existing pending**;全 `.gd`+`.sh` CI lint PASS。
**Design**:
- `error_severity_map.gd`(Resource,**no class_name** 避 global-class cache risk)+ `assets/data/error_severity_map.tres`(data-driven 12 codes)— Severity{TRANSIENT/FEATURE_DEGRADED/WIPE/ONGOING/UNMAPPED} + Source{PERSISTENCE/STREAK/STAT/ABILITY} + classify + priority_weight(UNMAPPED 同 ONGOING weight)+ flags(is_dismissable/is_auto_clear/ttl_sec)。
- `banner_stack.gd` rework:`dispatch_error` source-first + `main_slot` total-order comparator `(priority_weight desc, arrival_sequence asc)`(唔用 sort_custom / StringName pointer sort — reference_stringname_sort;dedupe_key StringName→String)。
- coordinator extend:+#8/#11/#12 seams + `_wire_error_consumers`(load .tres + plain-connect 4 error signal — transient event 非 state,boot-race 由 story 005 pull-check 收;has_signal 防禦 erratum)。真 #3/#8/#11/#12 signal shipped 都係 2/2/1/1 arg(#8 shipped 2-arg,G-LS-9 doc-erratum 係指 #8 GDD 寫單參 stale)。
**Lint safety**:`critical_save_failed`/`streak_persistence_failed`/`stat_critical_save_failed`/`ability_unlock_save_failed` 全部唔 match domain lint(stat_changed / ability_(unlocked|cast|...) / get_streak_buff_multiplier)。
**Deviations**:
- **OUT OF SCOPE(scaffold→core)**:rework 咗 story 003 `banner_stack.gd` scaffold(enqueue→dispatch_error）— story 003 test 只驗 node 存在,零 enqueue 斷言,無 regression。
- **ADVISORY(story 011)**:dedupe(同 key 唔疊)/「+N」collapse/DISCONNECTED priority/two-layer 獨立 = story 011(本 story `overflow_count` 係 raw size-1,full collapse 留 011)。
- **DEFERRED(G-LS-8)**:map↔#3 live enum drift keyset-coverage test 留 #3 additive erratum(get_pending_errors)story；本 story test 直驗 12+3 mapping。
**Code Review**: N/A spawn(本地全套 GUT + lint 等效)。
