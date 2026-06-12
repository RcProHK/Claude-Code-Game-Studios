# Epic: Telemetry / Analytics(#28)

> **Layer**: Polish(Pre-MVP tier — Pre-MVP PIVOT/KILL gate 量度儀器;**純 observer,零 downstream**,deps 全 implemented 可獨立推;**G-TEL-5 ADR-0012 gate ✅ CLEARED 2026-06-12 — 全 18 stories 現可 implement**)
> **GDD**: design/gdd/telemetry.md(✅ APPROVED 2026-06-12 — `/design-system` + `/design-review` 同 session degraded-inline,NEEDS REVISION→revise-now→APPROVED,1 BLOCKING phantom[`out_of_order_signal`→derived]+ 2 REC inline-fixed;15 Rules / 5 Formula(F1 switch-latency / F2 foreground-ratio / F3 hit-sample / F4 lossless-aggregate / F5 backoff cross-ref)/ 5-state FSM(BOOTING/ACTIVE/FLUSHING/SUSPENDED/DEGRADED)/ 18 EC / **22 AC** / 13 knob / 4 INV-T / **CI-1/2/3**)
> **UX Spec**: N/A — **無 player-facing UI**(Pillar 2 invisible;opt-out toggle UI 歸別系統 #24/settings,telemetry 只 own boolean 行為語意)。**無 UX Flag、無 /ux-design**
> **Architecture Module**: `Telemetry` autoload @ `src/autoload/telemetry.gd`(thin pure observer Node;持有 ring buffer + 5-state FSM + lossless accumulator;內部可拆 `src/telemetry/` helper [event envelope / buffer / flush / glance / proxy],**唔開第二個 autoload**)。**Holds ZERO gameplay state + emits ZERO gameplay signal**(G-TEL-2 CI lint 守:`src/autoload/telemetry.gd` + `src/telemetry/*` 零 `emit_signal(<gameplay>)`、零 upstream mutating-method call、零 write 去 `loot.*`/`stat.*`/`ability.*`/`streak.*`)。Autoload 位置:**Last**(ADR-0008 §insertion reserved「Last」;`connect_for_initial_state` order-resilience;**G-TEL-1 amendment 待做**)
> **Status**: ✅ **COMPLETE — 18/18 stories IMPLEMENTED + GUT-verified 2026-06-12**(single fresh session)。final full-project gate **440 scr / 2969 / 2966 pass / 0 fail / 3 honest pending(VS-tier+ADR-ratify,無關)**;telemetry combined 19 scr/114;5 lint(G-TEL-2/3/4 + platform-callers + boot-order)exit 0;**zero regression**(full-gate 揭發 + 修 Story 008 `_on_workout_completed transition_id:int→String` latent type bug 連帶 20 WST integration fail)。transport(真 POST/sendBeacon arrival)留 VS-tier-gated(ADR-0012 §Verification)— injectable seam 全可測。**未 commit**。
> **Stories**: **18 stories** ✅ ALL COMPLETE(5 Logic + 7 Integration + 3 Static-CI + 2 Config/Data + 1 Visual/Feel ADVISORY)

## Overview

實作 Mirror Hero 嘅 **被動觀察 / 量度層** —— systems-index L331 嘅 **Pre-MVP PIVOT/KILL gate 量度儀器**(「Telemetry data after Month 4 fails to show『players glance + drop excitement』signals → PIVOT or KILL」)。Telemetry **純 subscribe 上游 signal**,將每個有意義事件翻譯成結構化、版本化、**去識別化**嘅 telemetry event,buffer 本地,批次 flush 去玩家自己嘅 GymSys backend。佢**唔產生 gameplay signal、唔 mutate game state、玩家永遠睇唔到佢**。

佢 own 幾樣嘢:(1) **event envelope schema + de-id**(永不送原始 kg/1RM/體重);(2) **三層 priority ring buffer**(CRITICAL 異常永不 drop/sample);(3) **glance-proxy + euphoria-proxy 捕捉**(switch-latency / foreground-ratio / rarity 分布 —— 全被動,零玩家互動);(4) **async batch flush + page-hide beacon**(at-least-once,backend session_id+client_event_id 去重)。

兩條設計命脈,落地為 CI guard:**Pillar 2 — 100% passive**(G-TEL-2:零 gameplay emit、零 mutator call);**隱私 + Pillar 1 — first-party de-id**(G-TEL-3:no-PII denylist,數據只去玩家自己 backend,無第三方 SaaS)。Telemetry 係儀錶板背後嗰條無聲嘅線 —— 量度一切,影響零嘢。

## Stories(✅ created 2026-06-12;18 stories;**全部 Ready** — 011+012 ADR-0012 unblock 2026-06-12)

| # | Story | Type | ADR | Gate-note |
|---|-------|------|-----|-----------|
| 001 | **G-TEL-1** ADR-0008 boot-**Last** amendment + project.godot register + **#14 L593 erratum**(Q-T1) | Config/Data | ADR-0008 | scaffold 前提 |
| 002 | Telemetry autoload scaffold + 5-state FSM + `connect_for_initial_state` GSM bootstrap | Integration | ADR-0006/0008 | |
| 003 | Event envelope schema + `TelemetryEvent` type + **Rule 4 de-id** | Logic | ADR-0009 | |
| 004 | Ring buffer + 3-tier priority + **Rule 7 overflow(CRITICAL reserved 不滅)** | Logic | N/A | must-not-regress |
| 005 | **Formula 3 hit-sample + Formula 4 lossless aggregate**(AC-07 不變量 + AC-06 crit override) | Logic | N/A(pure formula) | |
| 006 | **Formula 1 switch-latency** glance proxy(bucketed;首-SET_ACTIVE edge) | Logic | N/A(pure formula) | |
| 007 | **Formula 2 foreground-ratio** + platform_detect Page Visibility hook | Integration | N/A(seam) | |
| 008 | #9 workout lifecycle subscription(7 signal incl `bfcache_resumed`)+ Rule 11 session lifecycle | Integration | ADR-0006/0009 | |
| 009 | #14 combat subscription(3 signal)+ anomaly critical channel + **Rule 15 recursion guard** | Integration | ADR-0009 | must-not-regress |
| 010 | #15 loot subscription(`loot_dropped` + 5 telemetry-only)+ drop-euphoria proxy(Rule 10) | Integration | ADR-0009 | |
| 011 | **Flush model async batch POST**(Rule 6 at-least-once + backoff F5) | Integration | **ADR-0012 ✅ Ready** | G-TEL-5 ✅ |
| 012 | **Page-hide beacon**(Rule 12 sendBeacon seam + XHR fallback EC-18) | Integration | **ADR-0012 ✅ Ready** | G-TEL-5 ✅ |
| 013 | **G-TEL-2** CI-1 `check_telemetry_no_gameplay_emit.gd`(pure observer,Pillar 2 命脈) | Static-CI | N/A(CI tooling) | must-not-regress |
| 014 | **G-TEL-3** CI-2 `check_telemetry_no_pii.gd`(de-id denylist,隱私命脈) | Static-CI | N/A(CI tooling) | must-not-regress |
| 015 | **G-TEL-4** CI-3 `check_telemetry_frozen_schema.gd`(frozen `loot_dropped_v1`,#15 FR-LOOT-3) | Static-CI | N/A(CI tooling) | must-not-regress |
| 016 | DEGRADED private-mode(EC-08)+ opt-out(EC-17)+ clock skew monotonic(EC-07) | Logic | ADR-0003/0006 | |
| 017 | Registry knobs `TelemetryConfig.tres` + 4 cross-knob INV-T | Config/Data | N/A(config) | |
| 018 | **AC-22** Pre-MVP gate data-completeness playtest evidence | Visual/Feel | N/A(playtest) | ADVISORY |

> **Implementation order**:001(autoload Last + erratum,scaffold 前提)→ 002(FSM scaffold)→ 003(envelope/de-id)→ 004(buffer)→ formula stories(005/006/007 獨立 early)→ subscription stories(008 workout → 009 combat → 010 loot)→ 013/014/015(三 CI lint,命脈 guard 早落地 + must-not-regress)→ 016(degraded/opt-out/clock)→ 017(registry)→ **011/012(flush+beacon)= ✅ ADR-0012 Accepted-contract,可 implement**(dedicated 第 5 HTTP channel + token-in-body beacon)→ 018(playtest ADVISORY)。**must-not-regress guard**:G-TEL-2 zero-gameplay-emit(Pillar 2)/ G-TEL-3 no-PII(隱私)/ G-TEL-4 frozen-schema(#15)/ AC-07 lossless-aggregate / Rule 7 CRITICAL-不滅 / Rule 15 recursion-guard。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0008**: Autoload Position Map | **G-TEL-1 boot-Last amendment 待做**(本 epic story)— `Telemetry` 排 **Last**(ADR-0008 §insertion reserved「Last」;`connect_for_initial_state` order-resilience);`project.godot` 登記。**同 story 回填 #14 L593 erratum**(Q-T1:「#28 boot BEFORE #14」係 stale → 改「Last per ADR-0008;combat signals runtime」)。[[feedback_lint_allowlist_adr_sync]] boot-order allowlist sync | LOW |
| **ADR-0006**: State Machine Contract | Contract 6 `connect_for_initial_state`(訂 #1 GSM `state_changed(from,to,payload)` boot 即收 back-fill current_state,`game_state` envelope stamp);Contract 9 drift-tolerant monotonic(EC-07 clock-skew 排序);5-state FSM ≠ GSM state(orthogonal) | LOW |
| **ADR-0009**: Signal Payload Schema | observe-only:訂 #9/#14/#15 signal payload minimal+intrinsic;cross-cutting context late-bind null-safe;`transition_id` correlation | LOW |
| **ADR-0003**: Save State Strategy | `user://` spool only(Rule 7 emergency / DEGRADED);**localStorage FORBIDDEN**;private-mode gate(EC-08) | LOW |
| **ADR-0004**: CORS / Cross-Origin Topology | flush 走 same-origin `POST /api/game/telemetry`,relative URL,**無第三方 SaaS** | LOW |
| **ADR-0002**: GymSys Integration Protocol | `session_id` source(session claim);transport baseline | LOW |
| **ADR-0012**: Telemetry Data Pipeline & Privacy | ✅ **Accepted (contract) 2026-06-12**。endpoint pair(`/api/game/telemetry` header-auth + `/api/game/telemetry/beacon` token-in-body)/ dedicated 第 5 HTTP channel(隔離 #2 pool)/ `UNIQUE(session_id, client_event_id)` dedup / retention 180d / opt-out 兩層 / de-id backend reject。**Stories 011 + 012 ✅ unblocked**(G-TEL-5 cleared)。empirical transport 留 VS-tier-gated | **MEDIUM**(sendBeacon JS seam empirical 留 VS-tier;contract 已 locked)|

## GDD Requirements

> #28 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#21/#22/#23/#24/#25/#26/#27/#29 先例一致)。Requirements 由 GDD 直接 trace:**15 Core Rules + 5 Formula(F1 switch-latency / F2 foreground-ratio / F3 hit-sample / F4 lossless-aggregate / F5 backoff cross-ref)+ 5-state FSM(BOOTING/ACTIVE/FLUSHING/SUSPENDED/DEGRADED)+ 18 ECs + 22 ACs + 13 knob + 4 INV-T + CI-1/2/3**,大部分有 Accepted ADR cover(上表)+ **5 個 cross-system gate G-TEL-1..5**。

**Untraced requirements**: ✅ **NONE remaining** — transport-flush + retention/privacy(Rule 6 flush + Rule 12 beacon + retention/opt-out)現由 **ADR-0012 Accepted (contract) 2026-06-12** trace。Stories 011 + 012 ✅ unblocked(G-TEL-5 cleared)。全 18 stories 有 Accepted ADR cover,可 implement。

**AC 分佈**:22 GDD AC(3 Static-CI[CI-1/2/3]+ 16 Logic + 2 Integration[flush/boot-order]+ 1 Advisory[AC-22 playtest])。**ADVISORY playtest**:AC-22(Pre-MVP gate data 完整性 —— 一個完整 session 產出足以評估 hypothesis 兩半嘅 metric set,系統使命驗收)。

## Definition of Done

This epic is complete when:
- **All 18 stories** implemented, reviewed, closed via `/story-done`(011 + 012 flush/beacon ✅ unblocked by ADR-0012 Accepted-contract 2026-06-12)
- **22 GDD ACs verified** + CI-1/2/3 green
- **CI-1 G-TEL-2 green**:`tools/ci/check_telemetry_no_gameplay_emit.gd` — `telemetry.gd` + `src/telemetry/*` 零 `emit_signal(<gameplay>)`、零 upstream mutating-method call、零 gameplay-namespace write(Pillar 2 / anti-fabrication 命脈)
- **CI-2 G-TEL-3 green**:`tools/ci/check_telemetry_no_pii.gd` — forbidden-field denylist(原始 kg / 絕對 1RM / bodyweight)零命中(隱私命脈)
- **CI-3 G-TEL-4 green**:`tools/ci/check_telemetry_frozen_schema.gd` — frozen `loot_dropped_v1` field set(`drop_id, rarity_tier, item_type, transition_id`)增/刪欄位無 version bump → fail(#15 FR-LOOT-3 binding)
- `Telemetry` 登記 `project.godot` **Last**(G-TEL-1,ADR-0008 amendment merged)+ **#14 L593 erratum 回填**(Q-T1)
- **5-state FSM** 正確:BOOTING→ACTIVE / ACTIVE⇄FLUSHING(失敗留 ACTIVE + backoff)/ ACTIVE⇄SUSPENDED(beacon flush)/ ACTIVE⇄DEGRADED;flush 失敗永不影響 gameplay
- **Lossless aggregate 驗**(AC-07):`combat_aggregate.total_hits` == 實際 `hit_resolved` 數,與 `HIT_SAMPLE_STRIDE` 無關;crit 強制 keep(AC-06)
- **CRITICAL 不滅驗**(Rule 7 / AC-03):overflow 下 CRITICAL 全保 + 最舊 LOW→STANDARD 先 evict + `dropped_count` 累加
- **Recursion guard 驗**(Rule 15 / AC-12,#13 EC-49):telemetry self-error 入 diagnostic channel,**永不** re-emit `combat_metric_anomaly`,無遞迴
- **Order-resilient late boot 驗**(AC-10):#28 排 Last,boot 後 emit 3 combat signal 全部 capture(零 silent drop)+ `game_state` stamp == back-filled
- **Glance/euphoria proxy 驗**(AC-05/08/22):switch-latency bucket + foreground-ratio + rarity 分布 + last_session_max_rarity stamp 齊
- **DEGRADED/opt-out 驗**(AC-15/21):opt-out → 零數據離開 device;private-mode → 唔寫 spool,in-memory 繼續
- Test evidence:unit `tests/unit/telemetry/` / integration `tests/integration/telemetry/` / static `tests/static/`(G-TEL-2/3/4 lint + autoload Last position)
- G-TEL-1..5 全部執行(✅ G-TEL-5 ADR-0012 gate CLEARED 2026-06-12,011+012 可 implement)

## Cross-system gates(G-TEL-1..5 — 全部係本 epic 內 stories;#27 G-OB / #29 G-MM / #25 G-CV 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-TEL-1** | ADR-0008 boot-**Last** amendment:`Telemetry` 排 Last(reserved per ADR-0008 §insertion)+ `project.godot` 登記 + **#14 L593 erratum 回填**(Q-T1)。boot-order allowlist sync([[feedback_lint_allowlist_adr_sync]])| ADR-0008 + config | doc + config(**scaffold 前提**)|
| **G-TEL-2** | **CI-1 `check_telemetry_no_gameplay_emit.gd`**(Pillar 2 命脈):grep telemetry source 零 gameplay signal emit、零 upstream mutator call、零 gameplay-namespace write。違反 = fail。**must-not-regress** | CI tooling(新 lint)| code(early — Pillar 2 命脈)|
| **G-TEL-3** | **CI-2 `check_telemetry_no_pii.gd`**(隱私命脈):forbidden-field denylist(原始 kg / 絕對 1RM / bodyweight / 可識別身體原值)。違反 = fail。**must-not-regress** | CI tooling(新 lint)| code(early — 隱私命脈)|
| **G-TEL-4** | **CI-3 `check_telemetry_frozen_schema.gd`**(#15 FR-LOOT-3):frozen `loot_dropped_v1` field set 比對,增/刪欄位無 version bump → fail | CI tooling(新 lint)| code |
| **G-TEL-5** | **ADR-0012 Telemetry Data Pipeline & Privacy gate**:✅ **CLEARED 2026-06-12** — ADR-0012 Accepted (contract);transport-flush(011)+ beacon(012)可 implement。endpoint pair / dedicated channel / dedup / retention / opt-out 全定(Q-T2/T3/T6/T7 RESOLVED)| ADR-0012 ✅ | **CLEARED**(empirical 留 VS-tier)|

## Story breakdown directives(PR-EPIC degraded inline REALISTIC — binding)

1. **G-TEL-1 做最早 doc story**(ADR-0008 boot-Last amendment + project.godot 登記 = scaffold 前提;**同 story 回填 #14 L593 erratum** Q-T1 —「#28 boot BEFORE #14」改「Last per ADR-0008;combat signals runtime」)。
2. **純 observer,無 coupled-pair blocking**:deps {#1,#3,#9,#13,#14,#15,platform_detect} 全 implemented + grep-verified contract(/design-review 已驗 14/15 signal EXACT,B-1 phantom 已修)→ telemetry 可獨立 implement(異於 #29 等 #26)。
3. **三 CI lint 早做**(G-TEL-2/3/4 = Pillar 2 + 隱私 + #15 命脈;同 #27 G-OB-2 / #29 CI-MM / #25 AC-11 先例 — 命脈 guard 早落地 + must-not-regress)。
4. **G-TEL-5 ADR-0012 = ✅ CLEARED 2026-06-12**:ADR-0012 Accepted (contract) → Stories 011(flush)+ 012(beacon)unblocked。transport = **dedicated 第 5 HTTP channel**(隔離 #2 pool,pure-observer 永不餓死 loot_commit)+ **token-in-body beacon**(`/api/game/telemetry/beacon`,sendBeacon 無 header)+ `UNIQUE(session_id, client_event_id)` dedup + 401-no-force-boot。全 18 story 可 implement。**系統使命(數據到 backend 做 Pre-MVP gate)已完整可達**。
5. **Formula stories(F1 switch-latency / F2 foreground-ratio / F3 hit-sample / F4 lossless-aggregate)獨立 early**;timing/sampling test 用 injected clock + deterministic stride;**integer-ms 紀律**(knob float sec → int ms,monotonic 排序用 `client_ts_monotonic_ms`)。
6. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` + `tests/static` 一齊;[[feedback_ci_gate_command]])。
7. **Story 總數 baseline 16–20**(>20 = scope creep 重審;<16 = AC force-compress 重審 —— observer 有 buffer/sampling/flush/3-CI/5-FSM,比 #27 略重)。
8. **must-not-regress guards**:**G-TEL-2** zero-gameplay-emit(Pillar 2)/ **G-TEL-3** no-PII(隱私)/ **G-TEL-4** frozen-schema(#15)/ **AC-07** lossless-aggregate(sampling≠失真)/ **Rule 7** CRITICAL-不滅 / **Rule 15** recursion-guard(#13 EC-49,grep/spy 驗)。
9. **#14 L593 erratum**(Q-T1)+ **WST bfcache_resumed decl erratum**(Q-T8)= 跨 file doc edit,隨 G-TEL-1 / subscription story 回填;勿 block telemetry impl。
10. **registry referrer 已回填**(R-2:`state_changed_signal_signature` 加 #28);epic 內無新 registry entry(telemetry owns 零 cross-boundary fact)。

## Next Step

Run `/create-stories telemetry` to break this epic into implementable stories。
