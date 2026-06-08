# Story 010: Banner 系統 core(severity map + source-first dispatch + UNMAPPED + total-order comparator)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

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
