# Story 018: AC-22 Pre-MVP gate data-completeness playtest evidence

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Complete (ADVISORY)
> **Layer**: Polish
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — AC-22(Pre-MVP gate data 完整性 — 系統使命驗收)。systems-index L331 Pre-MVP PIVOT/KILL gate 可量度前提。
**ADR Governing Implementation**: ADR-N/A — playtest evidence,no architectural pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 人手 / simulated session 驗證 metric set 完整。

**Control Manifest Rules (Polish layer)**:
- Required: 驗證 hypothesis 兩半 metric 齊
- Forbidden: —
- Guardrail: ADVISORY gate(唔 block CI,but block epic「使命達成」聲稱)

---

## Acceptance Criteria

- [x] **AC-22**:simulated representative session(`test_premvp_data_completeness.gd` 1/1 / 139 asserts)後 metric set 覆蓋 hypothesis 兩半:
  - 上半「glance」:`switch_latency {bucket}` + `get_foreground_ratio()` ∈ [0,1] + foreground tracker total_ms>0(visibility transition)
  - 下半「drop excitement」:`loot_dropped {rarity_tier}` + 下個 `session_started {last_session_max_rarity}` stamp
- [x] evidence doc:`production/qa/evidence/telemetry-premvp-data-completeness.md`(metric↔hypothesis 對應表 + sign-off)
- [x] **零 PII** end-to-end(test 對每 event payload 13-key denylist grep,0 命中 + G-TEL-3 lint)+ Pillar 2 invisible(G-TEL-2 lint exit 0 + observer-only)

---

## Implementation Notes

*Derived from GDD AC-22 + 系統使命:*

- 跑一個 representative session(simulated 或 real):workout phases + combat + loot drop。
- dump telemetry buffer / flush payload(dev-only),核對 metric set 涵蓋 hypothesis 兩半。
- **呢個 story 係系統使命驗收**:確認 telemetry 真係產出「足夠數據去 Month 4 做 PIVOT/KILL 判定」。
- 順帶人手驗 Pillar 2:整個 session 玩家完全察覺唔到 telemetry(零 popup/loading/lag)。

---

## Out of Scope

- 真 backend dashboard / hypothesis scoring(analysis-time,backend,非 client GDD)
- ADR-0012 transport(Story 011/012)— evidence 可用本地 buffer dump,唔等 flush

---

## QA Test Cases

- **AC-1 (data completeness, AC-22)**:
  - Setup: 跑完整 session(workout + combat + loot)
  - Verify: telemetry 輸出含 switch-latency bucket 分布 + foreground_ratio + visibility 計數 + rarity 分布 + last_session_max_rarity stamp
  - Pass condition: hypothesis 兩半各有對應 metric,缺一即 fail
- **AC-2 (Pillar 2 invisible + no PII)**:
  - Setup: 同上 session
  - Verify: 整個 session 零玩家可感知 telemetry artifact;dump payload grep 零原始身體數據
  - Pass condition: 零 artifact + 零 PII

---

## Test Evidence

**Story Type**: Visual/Feel(ADVISORY)
**Required evidence**: `production/qa/evidence/telemetry-premvp-data-completeness.md` + sign-off
**Status**: [x] evidence doc authored + `tests/integration/telemetry/test_premvp_data_completeness.gd`(1 test/139 asserts PASS,automated 取代手動 dump)。3-point sign-off 全 PASS

---

## Dependencies

- Depends on: Story 008 / 009 / 010(三大 proxy 來源)+ 006 / 007(glance proxy)
- Unlocks: None(系統使命驗收,epic 收口)
