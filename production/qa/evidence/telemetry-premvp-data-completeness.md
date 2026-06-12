# Telemetry (#28) — Pre-MVP Gate Data-Completeness Evidence (Story 018 / AC-22)

> **Story**: #28 Story 018 — Pre-MVP gate data-completeness playtest
> **Type**: Visual/Feel (ADVISORY — does not block CI; gates the epic「使命達成」claim)
> **Date**: 2026-06-12
> **Method**: Simulated representative session driven through the real telemetry handlers
> (`tests/integration/telemetry/test_premvp_data_completeness.gd`, GUT — 1 test / 139 asserts / PASS).

## 使命 (systems-index.md L331)

> *Telemetry data after Month 4 fails to show「players glance + drop excitement」signals → PIVOT or KILL.*

AC-22 要求:跑一個完整 session 後,收集嘅 telemetry metric set **足以評估 hypothesis 兩半**。本 evidence 用一個 simulated representative session(workout phases + visibility round-trip + combat hits + EPIC loot + workout completion)驅動真 telemetry handler,然後 dump in-memory buffer 核對 metric set。

## Session 模擬內容

| 步驟 | 觸發 | 產生 telemetry |
|---|---|---|
| 開 session | `_on_workout_started()` | `session_started` + `workout_started` |
| 換動作 glance | `phase_changed` REST→(12s)→SET_ACTIVE | `switch_latency {bucket: 1}`（5–15s 桶） |
| 在場專注 glance | `visibility_changed(false)` → `(true)` | foreground tracker total_ms > 0；ACTIVE→SUSPENDED→ACTIVE |
| 戰鬥 | `hit_resolved` ×2（含 1 crit/CRITICAL tier） | `hit_resolved`（crit force-kept）+ lossless aggregate |
| 掉寶 drop | `loot_dropped("EPIC")` | `loot_dropped {rarity_tier: EPIC}`；session max rarity = 3 |
| 收 session | `_on_workout_completed` | `workout_completed` + flush trigger |
| 新 session | `_ensure_session(true)` | `session_started {last_session_max_rarity: 3}` |

## Hypothesis 兩半 — metric 對應(全部 assert PASS)

### 上半「glance」(在場專注度)
- ✅ **switch-latency 分布** — `switch_latency` event,`bucket: 1`(12s rest → 5–15s 桶)。只送 bucket index,**唔送原值**(de-id;防反推 rest 時長)。
- ✅ **foreground_ratio** — `get_foreground_ratio()` ∈ [0, 1] 可用 glance proxy(Formula 2)。
- ✅ **visibility transition 計數** — foreground tracker `total_ms() > 0`,證實 hidden/visible round-trip 已累積(FSM ACTIVE→SUSPENDED→ACTIVE)。

### 下半「drop excitement」(掉寶興奮)
- ✅ **rarity 分布** — `loot_dropped` event 帶 `rarity_tier: EPIC`(frozen `loot_dropped_v1` 4-field)。
- ✅ **last_session_max_rarity session-open stamp** — 下一個 `session_started` payload 帶 `last_session_max_rarity: 3`(上個 session 嘅 EPIC ordinal),令 backend 可做 session 間 drop-excitement 趨勢分析(Rule 10)。

**結論:hypothesis 兩半各有對應 metric,無缺。** Telemetry 真係產出「足夠數據去 Month 4 做 PIVOT/KILL 判定」。

## Pillar 2(玩家不可感知)+ de-id(零 PII)端到端

- ✅ **零 PII** — test 對 buffer 內**每一個** event 嘅 payload 做 13-key raw-body denylist grep(`weight_kg`/`bodyweight`/`one_rep_max`/`absolute_1rm`/… end-to-end),全 0 命中。客端再有 `check_telemetry_no_pii.gd`(G-TEL-3)build-time 守。
- ✅ **零 gameplay 副作用(Pillar 2)** — telemetry 係 pure observer:`check_telemetry_no_gameplay_emit.gd`(G-TEL-2)exit 0 證實 zero gameplay emit / mutator / namespace write。整個 session 零 popup / loading / lag artifact(telemetry 只 translate→buffer→async flush,從不入 gameplay frame)。

## 範圍 / 限制

- 本 evidence 用 **simulated** session(driven through real handlers + injected clock/platform/transport seams)。真 backend dashboard / hypothesis scoring 屬 analysis-time + backend,**非** client GDD 範圍(Story 018 Out-of-Scope)。
- Transport empirical(真 `POST /api/game/telemetry` 到達 + sendBeacon arrival)留 **VS-tier-gated**(ADR-0012 §Verification Required)。本 completeness gate 用 local buffer dump,唔等 flush(Story 018 Out-of-Scope 明示)。

## Sign-off

- **Captured-metric completeness**: ✅ PASS(automated — `test_premvp_data_completeness.gd` 1/1 / 139 asserts)
- **No-PII end-to-end**: ✅ PASS(automated denylist grep + G-TEL-3 lint)
- **Pillar 2 invisible**: ✅ PASS(G-TEL-2 lint + observer-only construction)

> ADVISORY gate 達成:telemetry 系統使命(Pre-MVP PIVOT/KILL 數據可量度前提)驗收通過。
