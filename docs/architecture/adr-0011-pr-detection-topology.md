# ADR-0011: PR Detection Topology & Server Baseline Contract (#18)

## Status
Accepted-contract (2026-06-06) — topology ruling + baseline contract spec Accepted(spec-level,無 measurement gate;design-review CD mandate);**G-PR-1 GymSys backend 實作嘅 empirical validation 留 VS-tier-gated**(同 ADR-0002 transport-validation 同款 pattern)。

## Date
2026-06-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Feature(anti-fabrication topology + data contract) |
| **Knowledge Risk** | LOW — ownership/contract 決定,非 novel-API;HTTP/polling 面由 ADR-0002 own |
| **References Consulted** | `design/gdd/game-concept.md` L298 (Q3);`design/gdd/pr-detection.md` (#18);`design/gdd/stat-system.md` EC-36 (L553) + L616 fail-soft row;`design/gdd/ability-system.md` FR-2 (L57) / EC-16 (L498) / EC-35 (L532);ADR-0002 (data contract);ADR-0003 (backend-primary);`design/gdd/reviews/pr-detection-review-log.md` (Pass 1 verdict) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | G-PR-1 backend extension 落地時:per-exercise baseline 回傳值 spot-check 對照 client Epley 計算(formula parity 實證);VS-tier 真數據回放(Q-PR-1) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002(`set_logged` payload schema + polling cadence + cursor idempotency — facts 來源);ADR-0003(backend-primary + `pr.*` namespace);ADR-0005(PR_BASE / Formula 2 knobs — #11 own);ADR-0008(autoload position — G-PR-3 insertion) |
| **Enables** | #18 PR Detection GDD graduation(design-review exit bar item 2);#12 AC-32 integration test 嘅 #18-side 前提;GymSys backend G-PR-1 API extension 實作 |
| **Blocks** | #18 epic creation(ADR 必須 in place 先過 re-review);G-PR-1 backend story |
| **Ordering Note** | HIGH — #18 係 Pillar 1 PRIMARY 入口;systems-index risk register L280 預期本 ADR |

## Context

### Problem Statement
game-concept.md Q3(L298)原文:「PR detection — 真 1RM PR 觸發稀有 drop 要 **server-side 判定**,邊度比較 historical max?— 由 GymSys API extension ADR 處理」。#18 GDD authoring 時(Q-N3)選擇咗 **client-side derivation over server-sourced inputs** — 但 concept 級決定唔可以由 feature GDD 一段自行 supersede;同時 #11 EC-36 / #12 FR-2+EC-35 嘅措辭(「#18 必須 spec server-side validation」)同 Q-N3 結論未 reconcile。再者,design-review Pass 1 證實判定鏈嘅信任錨點 —— **server baseline(G-PR-1)—— 完全未 spec**:formula parity / value validation / ratchet 語意 / sync timing 四面全空,而四個 BLOCKING degenerate(÷0 假 max PR、microloading 永久壓制、double-count race、farmable sync window)全部由呢個缺口派生。

### Constraints
- **Pillar 1(Real Body, Real Power)**:PR 判定嘅每個 input 必須係 client 冇 fabricate 面嘅數據;判定結果唔可以因 timing/window 而 double-count 或被壓制。
- **Pillar 2(Frictionless)**:判定必須即時(set 完成 → 下一個 glance 已見效果)— 零額外 per-PR round-trip。
- ADR-0002:`set_logged` payload 冇 set id(schema locked);catch-up redelivery 係 normal path。
- ADR-0003:backend-primary;local 只係 cache。
- GymSys 係 user 自有 backend — API extension 可行,但 spec 必須夠精確俾 backend 實作。

## Decision

### D-1:Topology — Facts server-authoritative,derivation client-side,contract-pinned(supersedes game-concept Q3 嘅「server-side 判定」措辭)

PR 判定 = client-side deterministic 純函數,行喺三個 **server-authoritative facts** 上:

| Input | 來源 | Client fabricate 面 |
|-------|------|---------------------|
| set 數據(exercise_id / reps / weight) | GymSys 後端記錄,經 #2 polling 落地(ADR-0002) | 無 — client 唔產生 set 事件 |
| historical baseline(per-exercise best e1RM) | GymSys 後端計算,經 G-PR-1 API(本 ADR §D-2) | 無 — server-computed |
| 公式(Epley + magnitude + Formula 2) | 本 ADR + #18 GDD pin(deterministic,無 RNG 無 clock) | 無自由度 |

**判定數學行喺邊一邊唔影響 anti-fabrication,前提係 contract 釘死** — client 冇任何自由輸入可以偽造 PR。Threat model:單人 fitness companion,self-cheat 只損己(同 ADR-0003 已接受嘅 topology 一致);devtools-level tampering 唔喺 threat model 內(同 #11 Rule 10 嘅 release-build defense 同層)。**收益**:零 per-PR round-trip(Pillar 2),offline grace 可行(ADR-0003)。

Q3 嘅「server-side 判定」原意係「判定唔可以建基於 client 可捏造嘅 inputs」— 本 topology 以「facts server-authoritative + derivation deterministic」滿足呢個原意。game-concept Q3 條目 update 為指向本 ADR。

### D-2:G-PR-1 Server Baseline Contract(四 sub-spec,全部 binding)

GymSys 後端提供 per-exercise historical best e1RM。Contract:

1. **Formula parity** — server 端 e1RM 必須用**同一條 Epley**(`e1rm = weight × (1 + min(reps, 12) / 30.0)`,divisor 30.0 float,`effective_reps = min(reps, REP_CAP=12)` clamp,**無 reps=1 特判**)。兩邊唔同尺 = 系統性 phantom/suppressed PR。
2. **Value validation(client-side,reconcile 時 per-entry)** — server 回嘅每個 entry 必須過 `is_finite(v) and v >= WEIGHT_SANITY_MIN and v <= WEIGHT_SANITY_MAX × (1 + REP_CAP / 30.0)`(下界係 **WEIGHT_SANITY_MIN(1.0kg)唔係 0** — near-zero entry 係 ÷0 嘅 sibling degenerate:tiny baseline → 正常 set clamp-2.0 假 max PR,且 soft-confirm corroboration 對細 absolute 值 trivially pass 救唔到;上界用公式唔 hardcode,免 REP_CAP knob coupling),唔過 → **reject 該 entry(保留 local)** + `pr.baseline_invalid` telemetry。Server 回 0/near-zero → ÷0/tiny → clamp 2.0 = 保證假 max PR;負數 = 該 exercise PR 永久 silent 死 — 全部由呢條 if 擋。
3. **Ratchet 語意** — server baseline 必須係「**confirmed-PR ratchet 嘅 server 鏡像**」(同 client 同一條只喺 confirmed PR 先升嘅尺),**唔係 raw max e1RM over all sets**。否則 sub-floor 進步(microloading <1%)會被 server raw max 不斷吸收 → 誠實 microloader 一世零 PR(Pillar 1 正面違反)。實作上 server 可以 lazily 由 set 歷史推導,但推導規則必須 = client 判定規則(同一 noise floor 語意,**包埋 D8 corroboration 語意**:suspect-magnitude 跳升(> SUSPECT_PR_MAGNITUDE)只喺有後續 corroborating set(e1rm ≥ ratio)先入 ratchet — 否則 typo set 經 server 軸直入 baseline,下一 boot 覆寫後玩家所有真 PR 永久壓制,client 端 D8 防線被 server 路徑繞過;server 端 = 同一 algorithm 嘅 sequential scan + pending slot,實作平)。
4. **Sync timing** — baseline 隨 **#2 polling state response 加 field** 落地(唔開獨立 endpoint / round-trip)。咁 baseline 必然先於(或同於)catch-up replay set 到達 → 結構性消除「replay set 搶先建假 fresh baseline」race。

**Reconcile 規則(D2-floor,修正 #18 原 D2)**:server 贏 **pre-session 真相**;但本 session 內已 confirmed PR 嘅 e1RM 係 **floor** — reconcile 唔可以將 baseline 拉低過任何 session-confirmed 值(否則 #2 catch-up replay 重判同一 PR → stat double-count)。

### D-3:Guarantee mapping — #11 EC-36 / #12 FR-2+EC-35+EC-16(唔郁兩份 Approved 上游)

上游措辭「#18 必須 spec server-side validation」嘅**保證內容不變,保證 locus 由 server 移去 client+contract**:

| 上游 binding(原文) | 點滿足 |
|---------------------|--------|
| #11 EC-36(L553):「#18 GDD 必須 spec server-side validation rejecting `pr_magnitude > 2.0`」 | #18 自己層 clamp [0, 2.0] + `pr.magnitude_anomaly` telemetry + soft-confirm gate(`SUSPECT_PR_MAGNITUDE`)。#11 L616 嘅 Formula 2 clamp 係 **incidental fail-soft,唔係 designed defense**(#11 明文唔 own 呢個責任)— #18 GDD 唔可以再講「#11 係最後防線」。 |
| #12 FR-2(L57):「pr_magnitude 嘅 server-validated input 真實反映 1RM 突破,唔可以 client-side fabricate」 | D-1 topology:三 input 全部 server-authoritative facts,derivation deterministic — 滿足「唔可以 fabricate」嘅實質保證。#12 AC-32 integration test 嘅 #18-side 行為 = INV-PR-1 fail-closed(無 trusted baseline → 零 emit)。 |
| #12 EC-35(L532):「#18 GDD 必須 spec server-side validation;defensive `is_nan or < 0` → skip」 | #18 emit 前保證 `magnitude ∈ [MIN_PR_MAGNITUDE, 2.0]`(全 finite、非負 — pipeline 結構保證);#12 defensive check 保留做第二層。 |
| #12 EC-16(L498):「#18 必須 wait `boot_completed` + GSM Ready 後先 emit pr_breakthrough」 | #18 GDD Rule 10 binding 義務(本次 revision 落實)— emit gate on #12-ready lifecycle。 |

### D-4:Caller path 修正 + CI lint amendment

#18 autoload = **`src/autoload/pr_detection.gd`**(全部 18 個 shipped autoload 所在地;`src/feature/` 唔存在 — #11 GDD 嘅「檔名 LOCKED」係 phantom constraint)。`tools/ci/check_stat_mutation_callers.gd` whitelist 喺 #18 epic 第一個 story 內 amend(`res://src/feature/pr_detection.gd` → `res://src/autoload/pr_detection.gd`)— owner-exempt 修 lint 有先例(PR #12)。同時 escalate lead-programmer:該 lint whitelist 另有 2/4 條 stale(`src/core/workout_state_tracker.gd` / `src/feature/equipment_inventory.gd`)且 regex `StatSystem\.apply_stat_delta\(` literal 被 DI 慣例(`_stat_system.apply_stat_delta(`)繞過 = vacuous lint — 修 regex + whitelist 屬獨立 CI-tooling story,唔 block #18。

## Consequences

**Positive**:零 per-PR round-trip(Pillar 2);offline grace 可行;G-PR-1 由「加個 field」升級成完整 contract — 四個 Pass 1 BLOCKING degenerate(÷0 / 永久壓制 / double-count / farmable window)全部喺 contract 層閂死;#11/#12 Approved 上游零 churn(guarantee mapping 代替 rewording)。

**Negative / Risks**:GymSys backend 要實作 confirmed-ratchet 語意(唔係 trivial max query)— backend story 成本升;formula parity 係跨 codebase duplication(GDScript + Python)— 靠 G-PR-1 spot-check + Q-PR-1 真數據回放驗;client+contract 模式下,contract drift(backend 改公式冇同步)係新 failure mode → `pr.baseline_conflict` / `pr.baseline_invalid` telemetry 做 drift 偵測面。

**Supersedes**:game-concept.md Q3 L298 嘅「server-side 判定」措辭(原意以 D-1 滿足)。

## GDD Requirements Addressed

- #18 pr-detection.md:D1/D2(revision 後 cite 本 ADR)、G-PR-1 gate(→ 本 ADR §D-2)、Rule 10 EC-16 義務、caller path
- #11 stat-system.md EC-36 / L616(guarantee mapping §D-3 — 無需修改 #11)
- #12 ability-system.md FR-2 / EC-35 / EC-16 / AC-32(guarantee mapping §D-3 — 無需修改 #12)
- game-concept.md Q3(supersession pointer)
- systems-index L280 risk register(「ADR for PR detection logic」— 本 ADR 即係佢)
