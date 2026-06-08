# Login / GymSys Connection UI(Shell)

> **Status**: Designed → **fresh /design-review NEEDS REVISION → REVISED 2026-06-08**(同 session inline,跟 user full-autonomous 指示)
> **Author**: Frank + specialists(full mode:CD framing + game-designer/ux-designer/ui-programmer Section C + systems-designer D/E + art-director V/A + qa-lead H)
> **Last Updated**: 2026-06-08
> **Fresh /design-review(獨立 re-review,2026-06-08)**: **NEEDS REVISION → REVISED 同 session**(6 adversarial specialists [game/systems/qa/ux/uip/godot] + CD synthesis;scope M,唔 freeze)。6 BLOCKING 全收:(1)**auth_required boot-race**(致命 — #2 AC-08 `_ready()` 同步 emit,#24 tail miss → 黑屏)→ G-LS-4(c) `is_auth_required()` pull-check + EC-E5/AC-53 + 8-signal boot sweep 表;(2)**error_severity_map silent dead-end**(unmapped code 證偽 Pillar 1)→ default-deny + source-first dispatch(Rule 5)+ UNMAPPED row + EC-B9/AC-52;(3)**Honest Door vs debounce 自相矛盾**(+ cross-GDD 衝突:#22 EC-30 DISCONNECTED 全功能)→ **整套刪 debounce/F1/EC-C1/knob/invariant 1/AC-13-15**,入口 enabled/hidden 二態;(4)**AC phantom 群**→ AC-26 真斷言 / AC-21 _validate_knobs 兩路 / AC-35 拆 35a+35b / AC-06/07/08/22 改 GATED;(5)**BannerStack sort non-deterministic**→ total-order comparator + arrival_sequence + AC-29b;(6)**claim cancel await-hang**→ G-LS-3 cancellation 語意。RECOMMENDED 一併收:WIPE copy lead-with-impact / ONGOING acknowledge-to-minimize / region GDD-arbitration / a11y announce_aria / cross-knob invariant 2 cartesian fix / iOS 16px canvas caveat + dual-focus / F1 m:ss / credential residue(AC-50)/ clock seam(AC-51)/ banner 獨立性(AC-54)。
> **PRIOR — Creative Director Review(CD-GDD-ALIGN,authoring session)**: CONCERNS → REVISED 2026-06-08(C1 phantom immediate-poll API → G-LS-4(b);C2 lint zero-coverage → G-LS-9 + AC-25 GATED;C3 severity map 按 #3 outcome 重 carve;C4 ≤10% attribution 修正 [#2 Q-X9 L678] + Z5/Z6 region collision;A1 #9 transitive / A2 401 copy / A3 forbidden-signal + #8 L755 erratum 全收)
> **Implements Pillar**: Pillar 1(anti-lie error surfacing — indirect)+ Pillar 2(Frictionless Companion — 守護者角色)
> **System #**: 24(Presentation / MVP tier,size S)
> **Depends On**: #2 GymSys Backend Client(hard — sole auth/transport upstream);#1 GSM(state observer);#3 PersistenceLayer(error signal consumer);#33 Attention Budget(EC-13 carve-out)
> **Depended On By**: #27 Onboarding Flow(login step host);#22/#23(shell 入口 affordance);#8/#11/#12(error banner consumer 指定)

## Overview

Login / GymSys Connection UI 係 Mirror Hero 嘅**帳號連接 + 系統誠實層 shell** — 一個 Presentation 層 surface 集合,負責四件事:(1) **Login screen**:首次 boot(#2 AwaitingAuth substate / `auth_required()` signal)同 session 失效 re-login,行 `claim_session(username, password) -> SessionClaimResult` API,將 4 種 error_code(`invalid_credentials / network_error / rate_limited / server_error`)map 做 user-facing message(永不 leak raw HTTP code);(2) **Connection status surface**:GSM `DISCONNECTED` state 嘅 reconnect affordance(#33 EC-13 carve-out — 唔被 attention budget gate);(3) **Error banner 系統**:#3 PersistenceLayer `critical_save_failed`(12 error codes — Q-X12 閉環)+ #8 `streak_persistence_failed` + #11 `stat_critical_save_failed` + #12 `ability_unlock_save_failed` 嘅**唯一 UI consumer** — Pillar 1 anti-lie posture 喺 UI 層嘅收口;(4) **IDLE shell**:home 狀態嘅入口 affordance host(#22 Character Screen / #23 Inventory 入口 + 互斥接線 — Q-CS1/Q-IU1 閉環)+ logout 流程(#2 drain 程序嘅非阻塞 banner — Q-X10 閉環)。

玩家互動模式:**active 喺 login/logout 嗰幾下,passive 喺其餘全部時間**。冇咗呢個系統,game 冇入口(冇 login 冇 token,#2 polling 永不開始)、上游 4 個 error signal 全部變 silent no-op(anti-lie posture 喺 UI 層斷鏈)、#22/#23 冇 shell 接線。Deployment topology 行 ADR-0004 same-origin nginx(`/mirror-hero/` 靜態 + `/api/game/` proxy)— login 唔需要處理 CORS UX;session 協議行 ADR-0002(`POST /session/claim` + `X-Session-Token`)。實作層面嘅 lifecycle/topology 細節由 ADR-0001(CanvasLayer 拓撲)+ 本 GDD G-LS gates 釘實。

## Player Fantasy

**Indirect Infrastructure Fantasy —「肯認衰嘅守門人」(The Sentinel That Never Lies)**(creative-director Framing A 主敘事 + Framing B 護欄,2026-06-08):

玩家心入面嘅 felt promise:

> 「**個 game 喺最壞嗰一刻(斷線、存唔到、要重新登入)會誠實噉同我講 — 但唔會喺我練緊組嗰下撳醒我。佢肯認衰,所以我夠膽信佢冇衰嗰陣係真。**」

#24 同 #1 GSM(ms-scale continuity)/ #2(authenticity)/ #8 streak(unbroken chain)嘅沉默 enabler 唔同 — 佢係**唯一一個會主動現身嘅 infrastructure**:玩家正正喺最壞時刻(斷線 / storage 失敗 / session 過期)望住呢個 surface。所以佢嘅 fantasy 唔係「玩家唔感受佢」,而係「佢現身嘅方式塑造玩家對成個系統嘅信任」。

呢個 fantasy 唔由 copy 或 VFX 交付,由 **architectural posture** 強制:

- **零 silent-swallow path(Pillar 1 anti-lie 收口)** — #24 係 4 個上游 error signal 嘅唯一 UI consumer;每條 upstream error edge 都必須 terminate 喺一個 visible surface(banner / status / modal)。Architecture 上**根本冇一個 error 嘅 dead-end**。Falsifiable:grep #24 嘅 signal handlers,每個 error signal 必須對應一個 visible state change;任何 error 入到 #24 但唔產生 surface = bug,唔係 polish 問題。同 #2「Backend 唔識講大話」對稱:#2 保證好嘢真(authenticity),#24 保證壞嘢唔瞞(transparency)— Pillar 1 anti-lie 嘅一體兩面。冇 #24,#3「存咗就係存咗」/ #11/#12「never silently degrade」嘅 banner 承諾全部係空頭支票。
- **誠實,但用唔搶 attention 嘅方式誠實(Pillar 2 護欄)** — #24 嘅天職係喺壞時刻出聲,所以「點樣出聲」係 Pillar 2 嘅試金石:(a) logout drain 永不 mid-set modal(#2 Q-X10 CD binding);(b) DISCONNECTED 唔係一道牆 — reconnect affordance permissive(#33 EC-13 carve-out),斷線係「等緊」狀態唔係「停咗」狀態;(c) 所有 banner 屬 peripheral persistent class,唔用 gaze-drawing animation。Falsifiable(Pillar 2 design test):對 #24 每一個 surface(banner / status / drain / re-login)問「呢個會唔會逼玩家停 set?」必須全部 NO。
- **斷線唔拋低玩家(Pillar 2 陪伴)** — WiFi 喺更衣室 blip,connection status 變灰,但 avatar、進度、啱啱嗰組 set 一樣都冇少;surface 只係靜靜咁話「而家連唔到,得閒撳下試返」。

**Falsifiable design tests**:

1. **The Locker-Room WiFi Test** — 玩家 mid-set,gym WiFi 死咗 30 秒後自己返生。整個過程玩家唔 tap 任何嘢:HUD 顯示 peripheral 斷線指示,恢復後自動繼續,**零 modal 零 blocking**。Violation:任何 mid-set blocking surface → Pillar 2 失守。
2. **The Silent Corruption Test** — `critical_save_failed("QUOTA_EXHAUSTED", key)` fire 咗,但玩家望落去 game 一切如常冇任何 visible 變化 → **bug(anti-lie violation)**,唔係「冇崩潰就算數」。
3. **The Mid-Set Logout Test** — 玩家喺 set 之間 tap logout,有 3 個 pending loot commits 未完成。佢見到嘅係非阻塞「Logged out — saving…」banner,可以即刻熄 app;**永不**出現「等緊 saving 唔好走」嘅 blocking modal。
4. **The Honest Door Test** — 玩家喺 DISCONNECTED 狀態 tap #22 入口:affordance 嘅狀態(可入 / 唔可入 + 點解)必須喺 tap 前已經 visible — 唔可以 tap 咗先彈 error。

## Detailed Design

> **Section C 諮詢紀錄(2026-06-08,full mode)**:game-designer + ux-designer + ui-programmer 三方 parallel 諮詢,**零分歧收斂**;一項 main-session synthesis 修正(Rule 9 斷線 copy — ux 初稿「訓練暫時冇記低」被 ADR-0002 cursor-replay + #8 retro-credit + #21 catch-up ground truth 推翻,改為「GymSys 照記住,會自動補返」)。

### Core Rules

1. **單 coordinator 擁有權** — `LoginShellCoordinator` autoload(ADR-0008 tail insertion — G-LS-2)own 晒 4 個職責同兩個 CanvasLayer:`LoginShellLayer`(layer **62**,PAUSABLE,加入 BackBufferCopy capture enumeration → 0/10/50/60/61/62)+ `ErrorBannerLayer`(layer **111**,ALWAYS,>100 shake/saturation-immune;<120 — #21 loot modal 屬 sacred moment 可冚 banner,banner 完咗自然再現)— G-LS-1 ADR-0001 amendment。`_ready` pre-warmed `visible = false`(#21/#22/#23 先例;idle 時零 draw-call 貢獻)。內部拆 4 個 sub-controller(LoginPanel / ConnectionStatus / BannerStack / ShellEntry)— **唔開第二個 autoload**,但**跟 #22/#23 真實先例拆 `src/ui/login_shell/` helper file**(established pattern = 一個 autoload coordinator + 多個 `src/ui/[system]/` helper file,如 `character_screen_coordinator.gd` + `src/ui/character_screen/*.gd`)。**BannerStack + shell transitions 必須拆獨立 file**(`src/ui/login_shell/banner_stack.gd` + `shell_transitions.gd`)— 令 AC-35a banner 靜態紀律 grep scope 明確、唔誤殺合法 state-transition cross-fade tween(ui-programmer B1 / qa-lead B4);**AC-35a CI step 必須 assert target file 存在,no-file ≠ no-match(否則 grep 不存在檔案 = phantom pass — 見 AC-01 file-split 斷言)**。「唔開第二 autoload」(Rule 1 真正約束)同「拆 file」唔衝突 — 先例如此;Rule 14 講 `ScreenLifecycleFsm` FSM extraction,**唔等於** file-layout mandate。

2. **Login 接管條件 + TELEMETRY-CLASS 紀律** — #2 `auth_required()` fire → shell 入 `LOGIN` state(全屏 login form)。觸發源:首次 boot 零 token / Rule 11 401 latch / P0-7 410 update-required / P0-6 carve-out misconfig / logout 完成。**Boot-window race 收口(G-LS-4(c) — 致命 blocker)**:#2 GDD AC-08(gymsys-backend-client.md L596)已 contract 「`_ready()` completes → `auth_required()` emit count == 1」(grep-verified:空 token boot 同步 emit);但 #24 係 ADR-0008 tail autoload,#2 喺 pos 4 — #2 `_ready()` emit 嗰刻 #24 **仲未 `_ready()`/未 connect** → signal drop → LOGIN 永不觸發 → **首次開機黑屏**。Signal-only model 喺呢條最關鍵 signal 上同 #3 critical_save_failed boot-window gap(EC-B1)**同根**,所以對稱解:#24 `_ready()` 首批動作行 **pull-check** `GymSysClient.is_auth_required() -> bool`(#2 additive getter — **G-LS-4(c) gate**),返 `true` → 直入 LOGIN(唔靠 signal)。`get_auth_block_reason()` 只分流 *reason*,唔係「而家係咪需要 login」嘅 pull-state,故唔 cover 呢個 race。LOGIN 入場時經 **pull-model getter** `GymSysClient.get_auth_block_reason() -> StringName`(`&"none"` / `&"update_required"` / `&"carve_out_misconfig"` — #2 additive API,G-LS-4)分流:normal form / update-required prompt(「呢個版本舊咗,要更新先連到」+ 唔顯示 form)/ misconfig prompt(operator-facing,顯示 `acknowledge_carve_out_fix()` 指引)。**#24 全域只訂 4 個 signal**:`auth_required` / `drain_started` / `drain_completed`(#2)+ `state_changed`(GSM,經 `connect_for_initial_state`)— **11 個 forbidden signal**(10 TELEMETRY-CLASS + 1 TEST-SEAM `substate_changed` — #2 L120;CD-GDD-ALIGN A3 措辭對齊)永不訂閱。**注意(CD-GDD-ALIGN C2)**:lint script `check_no_ui_subscribes_telemetry.sh` 未 implement,且 #2 L120 spec scope 只 grep `src/ui/**` — #24 coordinator 喺 `src/autoload/` **唔會被掃** → G-LS-9 要求 scope erratum + script 創建,先有真 coverage。

3. **Claim flow** — submit → button disable + loading 態(防 double-submit)→ `await GymSysClient.claim_session(username, password)`(async 簽名 pin = G-LS-3 blocking gate — GDD 簽名返 `SessionClaimResult` 但 HTTP 係 async,await-coroutine vs completion-signal 要同 #2 釘實先做 login form story)→ **success**:token 由 #2 存(#24 永不掂 persistence — Rule 15),#2 開 polling,shell **等 GSM 離開 BOOTING 先轉場**(yield landing state — 唔假設 IDLE;reconciliation 可能直落 LOOT_DROP deferred reveal)→ form cross-fade 出;**failure**:inline error per Rule 4。await 期間玩家 background app(SUSPENDED)→ #2 cancel inflight(#2 State Matrix Cell 1)。**await-hang 收口(G-LS-3 連帶 blocking — godot B2)**:#2 GDD L184/L188(grep-verified)「cancel siblings 唔 wait `request_completed`」+「4.6 Web Export cancellation behavior 未 verify,`RESULT_CANCELED` 同 silent drop 都 acceptable」— 即 cancel 時 `request_completed` **唔保證 fire** → 若 `claim_session` 內部 `await http.request_completed`,#24 `await GymSysClient.claim_session(...)` 會**永不 resolve → submit 永久 disabled**(GDScript 冇 native await-timeout)。G-LS-3 簽名 pin 必須二擇一釘死:(a) `claim_session` 保證一定 resolve(SUSPENDED-cancel 時 return 一個 `error_code` 帶 cancelled 語意嘅 `SessionClaimResult`),fallback 由 result code 驅動;或 (b) 改 completion-signal pattern,#24 自己 race coroutine against injected-clock timer(`await` 兩者取其先)。兩者皆未做 → EC-A1 / AC-22 實作上不可滿足。釘實後:shell 收到 cancelled-result(或 timer 先到)→ timeout fallback copy + re-enable。

4. **Claim error map(4 codes,永不 leak raw HTTP — #2 L310 contract)** — `invalid_credentials` → form 內 field-level inline「username 或者 password 唔啱,再試下?」(唔分邊欄錯 — security 慣例);`network_error` → inline「而家連唔到伺服器,睇下 WiFi?搞掂再撳一次。」+ retry 掣;`rate_limited` → submit disable + `retry_after` **live 倒數**(「等 {N} 秒再試」,倒數到 0 re-enable — 唔 silent disable);`server_error` → inline「伺服器嗰邊出咗少少問題,陣間再試下。」+ retry 掣。Copy register = 廣東話口語 witness 語氣(同 #20 silent-mode banner 一致),零責備零 jargon。

5. **Banner 系統 = anti-lie 收口** — #24 係唯一 UI consumer of:#3 `critical_save_failed(error_code, key)` + #8 `streak_persistence_failed(error_code, key)` + #11 `stat_critical_save_failed(stat_id)` + #12 `ability_unlock_save_failed(ability_id)`。**每個 handler 必須產生 visible state change**(zero silent-swallow — Player Fantasy falsifiable test #2 binding)。**分類行 source-first dispatch(明文 — systems-designer B1)**:`if source ∈ {#8, #11, #12} → FEATURE_DEGRADED`(由 **signal source** 判定,唔睇 error_code — 防 #8 某 code string 撞中 #3 同名 code 被錯分做 WIPE acknowledge-dismiss);`elif source == #3 → error_severity_map.tres[error_code]` lookup(Rule 6)。**Unmapped code = default-deny(B1 修正 — 三命中核心)**:`error_severity_map.tres` lookup miss(#3 corrupt path 係 open-ended,將來加第 13 code)**唔可 silent drop** — 必須 fallback 去最高-safe ONGOING-weight 可見 banner(copy「偵測到未知存檔問題」),否則 lookup miss = GDD L30 自己定義「任何 error 入到 #24 但唔產生 surface = bug」+ 證偽 Pillar 1 zero-silent-swallow。Map 同 #3 enumeration 嘅 drift 由 G-LS-8 連帶 keyset-coverage test 防(`map.keys() ⊇ #3 live enumeration`)。

6. **Severity class(Q-X12 閉環;data-driven `error_severity_map.tres`)** — **4 個 semantic class,按 #3 嘅真實 outcome carve 推導**(CD-GDD-ALIGN C3 修正 2026-06-08:原 3-class 草案將 corrupt-wipe 事件標做「下次可能成功」係 anti-lie 自傷;#3 ground truth = corrupt path 8 codes 全部 wipe + re-init [persistence-layer.md Rule 9],QUOTA_EXHAUSTED 係 revert-no-wipe [L277]):

   | Class | #3 真實結局 | UX | 觸發 |
   |---|---|---|---|
   | **ONGOING**(環境持續不可用) | revert-no-wipe / 寫入持續失敗,環境唔變就唔會好返 | persistent banner,**acknowledge-to-minimize**(tap 確認已讀 → collapse 做一粒 peripheral status glyph,**唔係永久全 banner**;玩家下次試做被 block 嘅 action 時再 inline 彈)— 問題未解決所以唔完全消失,但讀完一次後唔再永久食 ≤10% 螢幕(game-designer B2:QUOTA_EXHAUSTED 係 Private Mode/低儲存 mobile 常見場景,玩家無 in-game action 可 fix,force-persistent = unactionable attention drain 違 Pillar 2;呼應 EC-B4 ONGOING 本來就會被 DISCONNECTED 降級做「+N」) | #3:`QUOTA_EXHAUSTED` `READ_ONLY_FILESYSTEM` |
   | **WIPE**(本機紀錄已重置 — 一次性已發生) | Rule 9 corrupt path → wipe + re-init(數據已經冇咗,唔係「下次再試」) | persistent banner,**可 acknowledge dismiss**(tap 確認已讀 — 事件已完結,誠實已交付);**copy lead-with-impact(game-designer B1 cry-wolf 修正)**:「**你喺 GymSys 嘅進度全部安全,會自動補返。**(啱啱本機快取重新整理咗;極少數情況:未上傳嘅戰利品要重爆。)」— 先講真實 impact(ADR-0003 backend-primary,WIPE path 真實 player-facing 損失通常零,下次 sync 補返),caveat 收喺括號;**唔再 lead with「重置咗 / 可能冇咗」**(機械誠實但情感誇大 → 玩家開 game 見一切如常 → 學識守門人會 cry-wolf → 摧毀「肯認衰所以我信佢」fantasy) | #3:`INVALID_JSON` `EMPTY_FILE` `UNREGISTERED_PAYLOAD_TYPE` `FLUSH_FAILED` `MIGRATION_TIMEOUT` `MIGRATION_CHAIN_TOO_LONG` `SCHEMA_DOWNGRADE` `FILE_TOO_LARGE` |
   | **FEATURE_DEGRADED**(單一 feature 寫入失敗) | 上游 feature 入 FAILED/degraded 態(#8 sticky 直至重啟) | persistent banner,auto-clear on 該 feature next success(sticky 情況自然留到重啟 — 誠實) | #8 `streak_persistence_failed` / #11 `stat_critical_save_failed` / #12 `ability_unlock_save_failed` 全部 |
   | **TRANSIENT**(race / 暫態) | block-reject,retry 大機會成功 | toast,~5s auto-dismiss,唔留 banner | #3:`NOT_READY` `MIGRATION_IN_PROGRESS` |
   | **UNMAPPED**(forward-compat 防線 — B1) | #3 corrupt path open-ended,將來新增 code 而 .tres 未更新 | **ONGOING-weight 重 banner**(acknowledge-to-minimize),**never silent**;copy「偵測到未知存檔問題 — 你嘅進度會由 GymSys 守住」 | 任何唔喺上述 12 code 嘅 #3 `error_code`(default-deny) |

   **視覺 weight 對應**(semantic 4 → visual 3,見 Visual/Audio):ONGOING + WIPE → 重(amber accent bar);FEATURE_DEGRADED → dim;TRANSIENT → toast。`QUOTA_EXHAUSTED` 喺 Private Mode 情境 = **ADR-0003 detect-and-gate 同一條 banner**(banner + loot disable — Q-E1 閉環跟 ADR-0003 已裁,唔係 refuse-to-start,唔開第二條 banner)。

7. **Banner stacking** — 單一 banner slot(`max_visible = 1`),顯示最高 severity;其餘 collapse 成「+N」counter(tap 展開 detail list)。Dedupe key = `(signal_source, error_code, key/id)` — 同 key 連 fire refresh 唔疊。Priority:DISCONNECTED status > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類(drain/reconnect 成功)。**Same-severity deterministic tie-break(systems-designer R3 / ui-programmer B2 / godot R3 三命中)**:同 class 兩條 banner(e.g. 同 frame 兩個 ONGOING,或 #11+#12 兩個 FEATURE_DEGRADED)嘅主-slot 揀選**唔可靠 `sort_custom`**(4.6 introsort **非 stable**)亦**唔可直接排 StringName**(本 project 已知 gotcha:`Array[StringName].sort()` 按 pointer/allocation order 唔按字面 — reference_stringname_sort)。Comparator 必須係 **total order `(severity_class, arrival_sequence)`**,`arrival_sequence` = 單調遞增 integer counter(每條 banner enqueue 時 assign);任何涉及 StringName 嘅比較(dedupe key)**先轉 `String`**。咁 EC-B2/AC-29 嘅「deterministic」斷言先可達(現狀不可滿足)。位置:**螢幕底部**,≤10% 螢幕高(peripheral class 數值沿用 **#2 Q-X9**(gymsys-backend-client.md L678)CD cascade 對 #20 spinner 嘅 binding[peripheral / ≤10% / 無 animation / 無 audio]— #24 採納同一 class 紀律)。**Bottom-region arbitration 原則(GDD-level — ux BF-1;唔純 punt 落 ux-design)**:#20 Z5 REST panel(bottom slide-up)+ Z6 silent-mode banner(bottom-center toast)+ #24 bottom banner 三方 bottom 撞,而 `ErrorBannerLayer`(111 ALWAYS)令「#24 永遠 draw 喺 #20 之上」變咗一個無人明選嘅 default。**GDD-level 釘三條 binding constraint**(`/ux-design` 喺呢三條之內出 layout spec):(1) **REST panel(Z5)出現時 #24 banner 讓位** — REST 嘅 next-exercise tap window 係 workout 神聖時刻(同 #21 loot modal sacred 同理),banner stack 到 REST panel **之上邊緣**或暫收做 status glyph,唔遮 tap target;(2) **Z6 silent-mode toast 同 #24 TRANSIENT toast 共用同一 bottom-toast slot**(唔同時雙 toast — 兩個都係 peripheral,排隊唔疊);(3) **ONGOING/WIPE persistent banner 同 REST panel 同時想出現** → persistent banner collapse 做 status glyph 讓 REST,REST 完再展開(誠實唔丟,但唔搶 workout)。確切 pixel region 由 `/ux-design` 釘,但**讓位方向同優先權已 GDD-locked**。

8. **Banner 靜態紀律** — #24 banner **零 animation / 零 audio / 零 pulse**;明文**唔援引** #20 silent-mode banner 嘅 alpha-pulse formula(#20 pulse 係邀請式「㩒一下開聲」;#24 係狀態誠實 — pulse = urgency gesture,壞時刻搶 attention 違反 Pillar 2)。Backdrop = opacity-only flat(**禁第二個 BackBufferCopy** — ADR-0001 #21 blur-CUT 裁決同源)。狀態唔純靠色:斷線 slash glyph / error ⚠ glyph / 完成 ✓ glyph。

9. **DISCONNECTED surface(誠實 + 唔築牆)** — GSM `DISCONNECTED`:(a)**workout 進行中**(由 WORKOUT_ACTIVE 系 state 跌入)→ bottom peripheral banner:「**連線斷咗 — 你嘅訓練 GymSys 照記住,連返之後自動補返。**」+ 細「再試一次」text 掣(tap → call #2 `request_immediate_poll()` — **G-LS-4 additive API**[#2 公開 surface 現時冇 immediate-poll API,「fire immediate poll」全部係 internal 行為 — CD-GDD-ALIGN C1 修正];**唔自己寫 backoff** — 重試節奏係 #2 職責;掣係 sense-of-agency affordance,功能上 #2 backoff 已 cover);(b)**non-workout** → shell `DISCONNECTED_SHELL` state:reconnect affordance + **入口照 enabled**(本地 view — 對齊 #22 EC-30,DISCONNECTED 全功能,**唔 grey**)+ 斷線 status。**斷線 copy 誠實依據(synthesis 修正)**:GymSys 係 workout 數據嘅 system of record(玩家喺 GymSys 度 log set,獨立於 game),ADR-0002 differential cursor replay + #8 retro-credit drift gate + #21 catch-up contact-sheet 三件套保證 reconnect 後 game 補返反映 — 斷線**唔損數據,只 delay 反映**;所以「照記住會補返」係真話,「數據冇收」先係靠估嘅嚇人話。#33 EC-13:DISCONNECTED + pending tap → input permitted(reconnect affordance 唔被 attention budget gate)。

10. **入口 affordance(Q-CS1/Q-IU1 閉環 — debounce 整套刪除,game-designer B4 / systems-designer B2 / qa-lead / ux 多命中)** — 入口喺 shell 可見嘅兩個 state(SHELL_IDLE / DISCONNECTED_SHELL)**一律 visible + enabled,冇 greyed 狀態**。**Cross-GDD 衝突修正(grep-verified)**:#22 character-screen.md L96 open 條件 = `GSM ∈ {IDLE, DISCONNECTED}` + L350 EC-30「DISCONNECTED 全功能 — equip/unequip/lock/salvage/settings 照行,唯一分別係 offline banner」(ADR-0003 unsynced-only client wins)→ #22/#23 喺 DISCONNECTED 係**全功能本地 view**,grey 一個全功能 surface = 細講大話。原 directional-debounce 草案同 EC-30 **直接矛盾**,且製造一個 2.5s「held-ENABLED 講大話窗口」(嗰窗口 tap → `can_open()` 若依賴 live connection 返 false → EC-E4 reject = Honest Door Test 4 明文禁止「tap 咗先彈 error」)。**整套移除**:Rule 10 directional debounce 機制 / Formula 1 / EC-C1 / `ENTRY_DISABLE_DEBOUNCE_SEC` knob / cross-knob invariant 1 / AC-13/14/15 一併刪。**Honest Door Test(Test 4)新義**:入口狀態 tap 前已 visible — 非 permitted state(workout 系)整個 shell HIDDEN(入口自然唔 render,對齊 #22 「pin:hidden 唔係 greyed」紀律 — workout nav 雜訊歸零 Pillar 2),permitted state 一律 enabled,**永不 tap 咗先彈 error**。入口由首次 render 就存在,shell state 切換用 cross-fade(`SHELL_FADE_SEC`)。Flicker(原 Q-CS1(b))喺新設計天然消失 — IDLE↔DISCONNECTED 之間入口狀態根本唔變(兩個都 enabled)。**Banner 永不 debounce**(error 一 fire 即現身,誠實優先)。

11. **互斥 arbiter(中央化)** — shell 暴露 `request_open(screen_id: StringName)`:close 現 open screen → `call_deferred` open 目標(**last-wins pending-target latch** — deferred window 內再 call `request_open` 只覆寫最後目標,唔排隊雙開;rapid-tap / G-LS-5 遷移後並發 race 防護,ui-programmer R6;本 project `check_inventory_reentrancy.gd` 證明 reentrancy 係已知風險區)。各 screen 嘅 `can_open()` double guard **保留**(defense-in-depth);shell **唔 subscribe** #22/#23 state(主動 call + `has_method` guard — #22 G-IU-4 glue 紀律同款);GSM force-close **唔經 shell**(各 screen 自己 `_on_gsm_state_changed` handle — shell 唔搶 GSM 嘅 job)。#22 `loadout_view_all_tap` 由直 call #23 遷移做 `request_open(&"inventory")`(G-LS-5 — Q-IU1 已承諾嘅遷移,非新 churn)。

12. **Logout(Q-X10 閉環 — CD path (a) optimistic)** — logout 擺 settings 角落(gear icon,唔同 #22/#23 主入口同級 — 破壞性動作收一層防誤撳)→ tap → **即時** optimistic「已登出」+ `clear_session_token(USER_EXPLICIT)` → #2 background drain。`drain_started(N)` → bottom banner:「已登出 — 緊要嘅嘢背景儲緊({N} 樣),可以安心熄 app。」;`drain_completed` → 「全部儲好喇 ✓」→ 2s auto-expire;drain 部分失敗(timeout_count > 0)→ persistent banner(WIPE-weight 視覺,acknowledge-dismiss — EC-B6)留到 re-login 後(誠實)。**永不**出「等緊 saving 唔好走」blocking modal(Mid-Set Logout Test binding)。玩家 drain 中途熄 app → 冇所謂(#2 tombstone + #3 persist,下次 boot 接返)。**Sequencing 修正(game-designer R3)**:`auth_required` 入 LOGIN 時,drain success 通知 banner(「全部儲好喇 ✓」)**先清除**,唔同 login form 共存 — 否則玩家見「已登出,可以安心熄 app」banner 疊住「請再登入」form = 一邊叫走一邊叫返,語意打架;但 drain **部分失敗**嘅 WIPE-weight persistent banner(EC-B6)**保留**到 re-login 後(誠實:有嘢未儲到要 surface)。「已登出」optimistic copy 行 CD Q-X10 path (a) 裁決(optimistic + silent drain),drain 真實結局由 `drain_completed` 兌現。

13. **Login form 規格** — username + password(`LineEdit.secret = true`)+ show-password toggle(眼睛 icon,≥44px)+ submit。**無** remember-me checkbox(token persist 係 default 行為 — 30 日 TTL 內唔會再見 login,假選擇唔出);**無** account creation / 忘記密碼 / 註冊(GymSys 帳號管理喺 GymSys 本體 — anti-scope);username 限 ASCII(GymSys schema 確認 — G-LS-3 連帶釘實)。**誠實申報**:MVP canvas `LineEdit` **攞唔到 browser password manager / Keychain autofill**(canvas 對 DOM 隱形 — Web Export 結構限制);mitigation = 30 日 token 令 re-login 罕見;DOM `<input>` overlay 列 v0.2 候選(必須經 `platform_detect.gd` JavaScriptBridge seam — ADR-001 forbidden pattern)。**iOS Safari keyboard / canvas-resize / IME / dual-focus spike = epic 第一個 story**(G-LS-6;HIGH risk — `DisplayServer.virtual_keyboard_show` web 行為 4.6 要 verify;**`input font ≥16px 防 auto-zoom` 只對 DOM `<input>` 路線可靠 — 對 MVP canvas `LineEdit` 路線大機會 no-op(false confidence,ui R8 / godot R4)**:iOS focus-zoom 由 DOM input font-size 觸發,canvas 對 iOS 只係一整塊 WebGL,16px 由 GDScript 設唔到嗰個 engine-internal 隱藏 DOM input;canvas path 嘅真 auto-zoom 行為係 spike **必驗項**,唔可預設已解決。**4.6 dual-focus breaking change(godot R5)**:4.5→4.6 把 mouse/touch focus 同 keyboard/gamepad focus 分離 — 「keyboard-only tab 順序」同 touch-tap 係兩條 path,`grab_focus()` 只郁 keyboard focus,spike **必須兩種 input 都實機驗**。IME 對 ASCII-only credential(本 rule)風險偏低,留作 verify 一項)。

14. **FSM extraction 裁決(#23 rule-of-three closure)** — **#24 唔觸發 `ScreenLifecycleFsm` extraction**:login form 喺 BOOTING/AwaitingAuth 係**主畫面**(token 都未有,根本未入 IDLE)唔係 overlay-on-IDLE;banner/status 係常駐 surface 冇 OPENING/CLOSING;shell entry 係 stateless affordance host。三個 lifecycle 都唔 fit #22/#23 嘅五態 overlay FSM — 夾硬 extract = 錯誤抽象。#22/#23 coordinator header 嘅 fork notice 以本 rule 作 closure(G-LS-7 doc edits)。將來如有第三個**真 overlay**(e.g. 獨立 settings screen)先 extract。

15. **Zero persist / zero gameplay state** — #24 唔寫任何 persistence key(token 由 #2 寫;a11y settings 由 #22 unified panel 寫);唔 own 任何 gameplay 數值;typed credentials 只存在於 form 提交瞬間嘅內存(#2 State Matrix:client 都唔 persist credentials)。**Credential residue 防護(ui-programmer R5)**:claim resolve(success 或任何 failure)後,password `LineEdit.text` **即清空**(唔留喺節點 property 超出「提交瞬間」);`invalid_credentials` 後保 username 清 password(同 EC-A3 「re-enter 保留已填」協調:auth_required re-enter 保 username,password 永不殘留)。Pillar 1 大量 error surfacing 令 web console observable(devtools),所以 claim / error path **零 credential var 入 `print(` / `push_error(`**(static grep AC 守 — AC-50)。

### States and Transitions

Shell internal FSM(5 states — **唔係** GSM states;shell observe GSM + #2 signals 自己分流。Banner stack 係 **orthogonal overlay**,任何 state 都可疊現,由 Rule 6/7 severity 機制獨立控制):

| Shell State | 入場條件 | 顯示 | 出場 |
|---|---|---|---|
| `HIDDEN` | GSM ∈ {BOOTING(有 token), WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED} | 冇 shell surface(login layer visible=false;banner layer 照常 per Rule 7) | GSM → IDLE / DISCONNECTED;或 `auth_required` |
| `LOGIN` | #2 `auth_required()` fire(任何 shell state 都可入 — 最高優先)**或 `_ready()` pull-check `is_auth_required()==true`(boot-race 收口 — Rule 2 / G-LS-4(c))** | 全屏 login form(LoginShellLayer visible);reason 分流 per Rule 2 | claim success + GSM 離開 BOOTING → cross-fade 去 landing state 對應 shell state |
| `SHELL_IDLE` | GSM `IDLE` 且有 token | 入口 affordance(#22/#23 兩張卡,enabled)+ connection status(綠)+ settings 角落;world view(avatar 由 #26 喺 GameLayer render — shell **唔** own avatar,avatar 經 world camera 自然置中) | GSM 離開 IDLE;或 `auth_required`;或 logout |
| `DISCONNECTED_SHELL` | GSM `DISCONNECTED`(non-workout 進入) | reconnect affordance + **入口照 enabled**(本地 view — 對齊 #22 EC-30,**唔 grey**,Rule 10)+ 斷線 status | GSM reconnect → IDLE;或 `auth_required`(401 latch) |
| `DRAINING` | logout tap(Rule 12) | optimistic「已登出」+ drain banner | `auth_required`(token cleared)→ LOGIN |

**轉場紀律**:全部 state 切換 cross-fade ≤ `SHELL_FADE_SEC`(default 0.25s),唔 hard cut;`LOGIN` 係最高優先 interrupt(`auth_required` 喺任何 state fire 都即入,但 mid-workout 嘅 401 latch 情境行 Rule 9(a) banner-defer — `auth_required` 喺 GSM 仍喺 workout 系 state 時**唔即彈全屏 form**,banner 先,GSM 落 IDLE/DISCONNECTED 先入 LOGIN;呢個 defer 係 Pillar 2 binding)。

**Mid-workout session 失效 flow(Rule 2 × Rule 9 合成)**:`auth_required` mid-set → 唔轉 LOGIN → bottom banner「**要再登入返 — 你嘅訓練 GymSys 照記住,登入返之後自動補返。撳一下登入。**」(tappable;copy 用 re-login family 唔用「斷線」— session 被另一 tab claim 時 WiFi 好地地,「斷線」會同玩家現實矛盾,CD-GDD-ALIGN A2)→ 玩家 set 之間 tap(或 GSM 自然落 IDLE)→ 先入 LOGIN。Escalation ladder(session 完結仍未 re-login 嘅加強提示)deferred → Q-LS2(#29 returning-player ritual 連動)。

### Interactions with Other Systems

| System | 方向 | Interface | 擁有權 |
|---|---|---|---|
| **#1 GSM** | observe | `state_changed(from, to, payload)` 經 `connect_for_initial_state`(ADR-0006 C6);shell 只 observe 分流,**永不 request transition**(login 成功後 GSM 自己由 #2 polling 反映度) | GSM owns states;#24 owns shell 分流 |
| **#2 GymSysClient** | bidirectional | 訂:`auth_required` / `drain_started` / `drain_completed`;call:`claim_session(u,p)`(G-LS-3)/ `clear_session_token(USER_EXPLICIT)` / `request_immediate_poll()`(G-LS-4 additive — Rule 9 retry 掣)/ `get_auth_block_reason()`(G-LS-4 additive)/ `acknowledge_carve_out_fix()`(#2 L149 真存在);**11 個 forbidden signals(10 TELEMETRY + 1 TEST-SEAM)永不訂**(G-LS-9 lint) | #2 owns auth/transport;#24 owns 全部 login/connection UI surface(#2 GDD L272 reciprocal) |
| **#3 PersistenceLayer** | observe | `critical_save_failed(error_code, key)` → Rule 6 severity map(12 codes 全 mapped — Q-X12 閉環) | #3 owns 12-code enumeration;#24 owns UX surface |
| **#8 / #11 / #12** | observe | `streak_persistence_failed(error_code, key)` / `stat_critical_save_failed(stat_id)` / `ability_unlock_save_failed(ability_id)` → FEATURE_DEGRADED class banner | 上游 owns signal;#24 owns banner(各上游 GDD「banner 由 #24」嘅 forward contract 兌現) |
| **#22 / #23** | arbiter | `request_open(&"character_screen"` / `&"inventory")`(Rule 11);**enabled-only** affordance(IDLE/DISCONNECTED 皆 enabled — 對齊 #22 EC-30,唔讀對方 state);#22 `loadout_view_all_tap` 遷移(G-LS-5) | #24 owns 互斥仲裁 + 入口 host;#22/#23 owns 各自 screen + `can_open()` double guard |
| **#33 Attention Budget** | carve-out | EC-13:DISCONNECTED + pending tap → `is_input_permitted` 唔 gate #24 reconnect/login surface(#33 已明文「嗰個係 #24 domain」) | #33 owns budget;#24 嘅 surface 喺 budget 之外 |
| **#20 Gym-Mode HUD** | spatial contract | banner 喺螢幕底部 ≤10%(數值沿用 #2 Q-X9 peripheral class — L678);**region collision 已 GDD-level arbitrate(Rule 7 — ux BF-1):REST panel(Z5)出現 #24 banner 讓位 / Z6 toast 同 #24 TRANSIENT toast 共用單 slot 排隊 / ONGOING-WIPE persistent 同 REST 同時 → collapse 做 glyph 讓 REST**;確切 pixel region 由 `/ux-design` 釘但讓位方向已 locked;#24 banner 唔援引 #20 pulse formula(Rule 8 — #20 F3 pulse 真存在 L226,刻意唔用) | 各 own region;讓位優先權 GDD-locked,pixel 由 /ux-design |
| **#9 WST** | transitive(note) | #9 EC-24 期望「`wst.persist_failed` → downstream UI banner」— **transitive 兌現**:同一 write failure #3 自己 emit `critical_save_failed`(帶 key)→ #24 banner 照出;#24 **唔**直訂 #9 任何 signal(channel enumeration 完整性 note — CD-GDD-ALIGN A1) | #9 doc 對齊喺 #9 next revision |
| **#4 AudioManager** | none(silent) | **#24 零 audio cue**:banner 零 audio(Rule 8);login 成功/失敗 silent(#23 silent 紀律先例);唔開 #4 catalog gate | — |
| **#27 Onboarding** | host 關係 | #27 choreograph 首 5 分鐘流程(連接帳號→demo→首爆裝),#24 只提供 login surface 本身;first-run tutorial 內容唔入 #24 | #27 owns flow;#24 owns surface |
| **#5 / #6 / #26** | none | 零 particle / 零 shake / 零 avatar render(#26 喺 GameLayer 自己 render — SHELL_IDLE 唔 duplicate) | — |


## Formulas

> **誠實申報**:#24 係 thin presentation shell,**零 gameplay 數值** — 本 section 唔發明唔存在嘅 math,只 formalize **兩條** UI timing/display logic(systems-designer 諮詢 2026-06-08;**原 Formula 1 Directional Debounce Gate 已隨 Rule 10 debounce 整套移除** — 入口喺 IDLE/DISCONNECTED 一律 enabled,flicker 天然消失)。全部 timing 用 `Time.get_ticks_msec()` monotonic clock(唔跟系統時間 — wall-clock tamper 免疫,見 EC-D2),test seam 用 injected clock(#22/#23 `advance(delta_ms)` 模式)。**Integer-ms 比較紀律(ui-programmer R2 / godot R3)**:knob 雖以 float sec 申報,但載入時 `knob_ms := int(knob_sec * 1000.0)`,**所有 formula 內部用 integer ms 比較**(`now_ms < t_start_ms + knob_ms`)— 徹底去除 float `2.49` 非精確可表示嘅 boundary-flaky 疑慮,同 injected-clock-in-ms seam 對齊。任何 formula 路徑**唔可直 call `Time.get_ticks_msec()`**(必須讀注入 clock,否則 `advance(delta_ms)` 影響唔到 → AC 變 wall-clock 依賴 phantom — AC-51 守)。

### Formula 1 — Rate-Limited Countdown(Rule 4)

```
display_seconds(t) = max(0, ceil(retry_after - (t - t_start)))
submit_enabled(t)  = (display_seconds(t) == 0)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| retry_after | r | int | [0, 3600] | #2 `SessionClaimResult.retry_after`(只喺 `rate_limited` populated) |
| t_start | t_0 | float | [0, ∞) monotonic sec | 收到 rate_limited 嘅 timestamp |
| display_seconds | N | int | [0, 3600] | 「等 {N} 秒再試」嘅整數倒數 |
| submit_enabled | — | bool | — | N == 0 即時 re-enable |

**Output Range:** N clamp 下界 0(永不顯示負數);`retry_after = 0`(或負/absent — N1)→ 即時 re-enable + **唔顯示**倒數 copy(EC-D1)。**Display format(systems-designer R1)**:`N ≤ 99` → 「等 {N} 秒再試」;`N > 99`(documented 上界 3600 = 一個鐘,live 倒數秒制不可讀)→ **`m:ss` format**「等 {m}:{ss} 再試」。**Integer-ms internal(intro 紀律 / N3)**:`display_seconds = max(0, ceili((r*1000 - (now_ms - t_start_ms)) / 1000.0))`(`ceili` 返 int 防「等 15.0 秒」)。
**Example:** r=30, t_0=100:t=115 → N=15;t=129.5 → N=1;t=130 → N=0 re-enable。r=3600 → 「等 60:00 再試」逐秒遞減。

### Formula 2 — Banner Auto-Expire(TRANSIENT + 通知類,Rules 6/12)

```
banner_visible(t) = (t - t_banner_start) < banner_ttl
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| t_banner_start | t_b | float | [0, ∞) monotonic sec | banner 出現 timestamp |
| banner_ttl | TTL | float | by class | TRANSIENT = `TRANSIENT_BANNER_TTL_SEC`(5.0);drain/reconnect 成功通知 = `DRAIN_SUCCESS_EXPIRE_SEC`(2.0);**ONGOING/WIPE/FEATURE_DEGRADED 唔用本 formula**(由 resolved / acknowledge / next-success trigger 消除,無限期 persistent — Rule 6) |

**Output Range:** boolean。strict `<` → **boundary `t = t_b + TTL` 已唔 visible**(t=202.0 exact = false — qa R4 boundary-exact 補測 AC-19)。**Per-banner timer(qa N2)**:每條 banner(含「+N」collapsed 嗰啲)各自行自己 `t_banner_start` timer,與主-slot 位置無關 — collapsed TRANSIENT 仍會自己 expire。
**Example:** drain ✓ banner @ t_b=200,TTL=2.0:t=201.5 visible;t=202.0 已消失;t=202.1 消失。

## Edge Cases

26 ECs,5 類(systems-designer 諮詢 2026-06-08;fresh re-review 2026-06-08 +3:EC-B9 unmapped / EC-E5 auth boot-race / EC-E6 上游 boot sweep,EC-C1 HIGH→LOW)。Severity:7 HIGH / 11 MED / 8 LOW。

### A — Login / Claim flow

- **EC-A1 [HIGH] — If claim await 期間玩家 background app(GSM → SUSPENDED,#2 cancel inflight)**:shell 收唔到 result → timeout fallback:re-enable submit + copy「程序中途中斷,請再試一次」(**唔係**「登入失敗」— credentials 冇壞,語意唔同)。*Rationale*:Rule 3 timeout path;唔可以 silent-lock submit。
- **EC-A2 [HIGH] — If token 喺 LOGIN state 期間被另一 browser tab claim(session conflict)**:本 tab claim 結果落 `server_error` bucket → generic copy + retry 掣。*Rationale*:#2 只 expose 4 個 error_code,session-conflict 冇獨立 code;Rule 4 唔 leak raw HTTP — `server_error` 係唯一合法 path。
- **EC-A3 [MED] — If `auth_required` fire 兩次而 shell 已喺 LOGIN**:idempotent 忽略 — **唔 reset 表單已填資料**,唔 double-render。*Rationale*:LOGIN 係 `auth_required` 嘅 idempotent target;re-enter 唔應重置用戶輸入。
- **EC-A4 [MED] — If retry 掣連打(rapid tap)**:第一 tap → submit disable + loading;後續 tap 喺 loading 態無效;result 返先 re-enable。*Rationale*:Rule 3 anti-double-submit 延伸;唔 throttle = 炸 #2 concurrent claims。
- **EC-A5 [LOW] — If claim 成功後 GSM 直落 LOOT_DROP(唔經 IDLE — deferred reveal reconciliation)**:shell 依 Rule 3 yield landing state → LOOT_DROP → shell 入 HIDDEN;#21 modal 接手。*Rationale*:Rule 3 明文唔假設 IDLE — 設計意圖,非特例。

### B — Banner / error signal

- **EC-B1 [HIGH] — If #3 `critical_save_failed` 喺 #24 `_ready()` 之前 fire(boot-window gap)**:#3 喺 autoload position 1,#24 喺 tail — boot 早期 signal fire 時 subscriber 唔存在 → silent drop = anti-lie violation。**Resolution**:#24 `_ready()` 首批動作行 **pull-check** `PersistenceLayer.get_pending_errors() -> Array`(#3 additive getter — **G-LS-8 gate**),補顯示 boot-window 積壓 errors。*Rationale*:ADR-0008 順序 + #3 boot-time fire 係架構事實;signal-only model 必然有呢個 gap;#3 既有嘅 push_error fallback 只係 console observable,唔滿足 zero-silent-swallow。
- **EC-B2 [HIGH] — If 同 frame 多個 error signal(slot 競爭)**:全部入 BannerStack queue → severity sort(ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT)→ 最高顯示,其餘「+N」(Rule 7)。Display order deterministic(severity,唔係 arrival order)。
- **EC-B3 [HIGH] — If Private Mode `QUOTA_EXHAUSTED` 喺 boot 第一秒 fire(banner layer 未 ready)**:同 EC-B1 同根 — pull-check 機制同時 cover,唔需獨立 mechanism。*Rationale*:ADR-0003 detect-and-gate banner 行 Rule 6 同一條 banner。
- **EC-B4 [MED] — If DISCONNECTED status 同 ONGOING/WIPE error banner 同時存在**:Rule 7 priority — DISCONNECTED 主 slot,error banner 入「+N」;DISCONNECTED resolved → 最高 severity 升上主 slot。*Rationale*:斷線係玩家可行動嘅即時資訊。
- **EC-B5 [MED] — If 同 dedupe key 連 fire**:refresh 現有 banner(timestamp 更新),唔疊 — 「+N」唔虛高。
- **EC-B6 [MED] — If drain 期間斷線(transport fail mid-drain)**:`drain_completed(committed, timeout_count > 0)` → drain banner **替換**做 persistent banner(WIPE-weight 視覺,acknowledge-dismiss):「有 {timeout_count} 樣嘢今次冇儲到,登入返之後系統會試返。」— 永不 silent。*Rationale*:Rule 12 誠實 path;#2 tombstone 下次 boot 接返(「會試返」係真 — 唔係 wipe)。
- **EC-B7 [LOW] — If「+N」detail list 展開時新 error 到**:即時 append 入 list + counter 更新;唔 close-reopen,唔阻斷閱讀。
- **EC-B8 [LOW] — If `drain_completed(0, 0)`(logout 時零 pending)**:照顯示「全部儲好喇 ✓」→ 2s expire。*Rationale*:一致性 — 玩家要知 logout 完成,唔因零 pending 靜音。
- **EC-B9 [HIGH] — If #3 emit 一個唔喺 12-code map 嘅 `error_code`(forward-compat:#3 corrupt path open-ended,將來加 code 而 .tres 未更新)**:`error_severity_map.tres` lookup miss → **default-deny fallback**:當作 ONGOING-weight 重 banner 顯示(copy「偵測到未知存檔問題 — 你嘅進度會由 GymSys 守住」),**never silent**(Rule 5/6 UNMAPPED row)。*Rationale*:silent drop = GDD L30「任何 error 入到 #24 但唔產生 surface = bug」+ 證偽 Pillar 1;40 條 BLOCKING AC 原本冇一條測 unknown code(systems-designer B1 / qa-lead R8)→ AC-52 補。Map↔#3 enum drift 由 G-LS-8 keyset-coverage test 防。

### C — DISCONNECTED / reconnect

- **EC-C1 [LOW] — If DISCONNECTED↔IDLE 高速 toggle(網絡 blip,500ms 級)**:入口喺 IDLE + DISCONNECTED **兩個 state 都 enabled**(Rule 10 — 對齊 #22 EC-30 全功能本地 view),toggle 唔改入口狀態 → **flicker 天然唔存在**(原 directional-debounce 機制 + Formula 1 已整套移除)。只有 connection status glyph 跟 GSM 變;banner 永不 debounce(error 即現)。*Rationale*:Q-CS1(b) flicker 問題喺「入口恆 enabled」設計下蒸發 — 唔需 debounce(severity 由 HIGH 降 LOW)。
- **EC-C2 [LOW] — If claim await 期間 GSM → SUSPENDED(FSM layer 視角)**:shell `_on_state_changed` 收 SUSPENDED → HIDDEN;claim result 冇返 → EC-A1 timeout path。兩個 EC 係同一事件兩個 layer,**零額外 mechanism**。
- **EC-C3 [MED] — If DISCONNECTED_SHELL 期間 `auth_required` fire(401 latch)**:LOGIN 係最高優先 interrupt → 即入 LOGIN。*Rationale*:States table 明文任何 shell state 可入 LOGIN。
- **EC-C4 [MED] — If mid-workout 401 latch 後 GSM 直落 DISCONNECTED(唔經 IDLE)**:#24 track `_pending_auth_required: bool` flag — Rule 9(a) banner-defer 期間 set;GSM 落 DISCONNECTED/IDLE 時 flag set → 即入 LOGIN。**LOGIN 入場唔以 IDLE 為 precondition**。*Rationale*:States table mid-workout defer 條款嘅 completion path。

### D — Timing

- **EC-D1 [MED] — If `retry_after == 0`(或 field absent)**:Formula 1 自然 handle — N=0 → 即時 re-enable,**唔顯示**「等 0 秒」copy。
- **EC-D2 [LOW] — If 玩家改系統時間(wall-clock tamper)**:Formulas 1-2 全部用 `Time.get_ticks_msec()` monotonic — 唔受影響。*Implementation requirement,非 behavior edge case。*

### E — Shell FSM

- **EC-E1 [LOW] — If GSM 喺 LOGIN cross-fade 途中直落 LOOT_DROP**:cross-fade 跑完(唔 abort mid-tween — hard-cut 嘅 onset transient 係 attention event,Rule 10 binding)→ fade 完 check GSM state → HIDDEN。*Rationale*:動畫 integrity > immediacy;GSM state continuously observable。
- **EC-E2 [MED] — If DRAINING 期間新 error signal fire**:BannerStack orthogonal — 新 banner 照 append(per Rule 6 class),priority 機制處理;drain 唔係 silent zone。
- **EC-E3 [MED] — If shell HIDDEN(e.g. WORKOUT_ACTIVE)期間 ONGOING/WIPE error fire**:`ErrorBannerLayer`(111 ALWAYS)獨立於 shell state — banner 照顯示喺 workout 之上。*Rationale*:Rule 1 兩 layer 分離;HIDDEN 只收 LoginShellLayer。
- **EC-E4 [LOW] — If `request_open()` 目標 screen `can_open()` 返 false**:shell 唔 force open;affordance **保持 enabled + tap 出 inline reason**(唔 silent + log warning;**唔再 greyed** — Rule 10 enabled/hidden 二態,greyed 已刪)。*Rationale*:Rule 11 double guard respect,唔 bypass。
- **EC-E5 [HIGH] — If #2 `auth_required()` 喺 #24 `_ready()`/connect 之前 fire(boot-race;#2 AC-08 contract `_ready()` 同步 emit,#2 pos 4 早過 #24 tail)**:signal drop → LOGIN 永不觸發 → **首次開機黑屏**。**Resolution**:#24 `_ready()` 首批動作 **pull-check** `GymSysClient.is_auth_required() -> bool`(G-LS-4(c) additive),返 true → 直入 LOGIN(唔靠 signal)。*Rationale*:同 EC-B1 boot-window gap 同根 — signal-only model 對 tail autoload 必有此 race;`get_auth_block_reason()` 只分流 reason 唔 cover「是否需 login」(godot B1)。
- **EC-E6 [MED] — If #8/#11/#12 喺自己 boot `_ready()` reconciliation 期間 emit persistence_failed(早過 #24 tail connect)**:FEATURE_DEGRADED banner 有 silent-drop 風險。**Grep-verified 現況**:#8 `streak_system.gd` 嘅 emit 喺 runtime `_persist_streak`(workout flow),boot `_ready()` 只 read 唔 write(L152「Called once during _ready, before READY」)→ boot-window 風險低但非零(若 #3 boot corrupt + #8 namespace match);#11/#12 handler body Story 009+。**Contract assert(GDD-level)**:上游 persistence_failed signal **唔可喺自己 `_ready()` 同步 emit**(對齊 #3 persistence_layer.gd file header「_ready 內用 `call_deferred` schedule emit」紀律)— 令 tail #24 connect 完先收到;此 assumption 列入 boot-window sweep 表(下),上游若將來改 boot-emit 須行 #3 同款 deferred pattern。*Rationale*:Rule 5 zero-silent-swallow 對 FEATURE_DEGRADED class 嘅對稱保證(godot R1 — systemic blind spot:「為 category 第一 instance 工程化 pattern 但冇 sweep 成個 category」)。

### Boot-Window Signal Sweep(CD exit bar 1 — systemic blind spot 收口)

**問題本質**:#24 係 ADR-0008 tail autoload,所有 upstream error/auth signal 嘅 producer 都喺 #24 之前 boot。Signal-only model 對 tail subscriber **必有 boot-window race**(producer `_ready()` emit 時 #24 未 connect → drop)。GDD 原本只為 #3 critical_save_failed(EC-B1)工程化 pull-check,**冇 sweep 成個 category** — 以下逐 signal 釘 cover 策略(全部 grep-verified against shipped code):

| Signal | Producer / pos | Boot-emit 風險 | #24 cover 策略 |
|---|---|---|---|
| `auth_required()` (#2) | #2 pos 4 | **HIGH 致命** — #2 AC-08(L596)contract `_ready()` 同步 emit count==1;drop = 首次開機黑屏 | `_ready()` pull-check `is_auth_required()`(G-LS-4(c) additive)— EC-E5 / AC-53 |
| `critical_save_failed(code,key)` (#3) | #3 pos 1 | MED — `_ready()` sync `_load_from_disk()` 可觸 corrupt path emit | `_ready()` pull-check `get_pending_errors()`(G-LS-8 additive)— EC-B1/B3 / AC-28 |
| `streak_persistence_failed(code,key)` (#8) | #8 Core | LOW — grep-verified:emit 喺 runtime `_persist_streak`(workout flow),boot `_ready()` 只 read(streak_system.gd L152) | Contract assert「上游唔喺 `_ready()` 同步 emit」(EC-E6);若改 boot-emit 須行 #3 deferred pattern |
| `stat_critical_save_failed(stat_id)` (#11) | #11 Core | LOW — handler body Story 009+,boot reconciliation `_ready()` | 同上 EC-E6 contract assert |
| `ability_unlock_save_failed(ability_id)` (#12) | #12 Core | LOW — 同 #11 | 同上 EC-E6 contract assert |
| `drain_started` / `drain_completed` (#2) | #2 pos 4 | None — 只喺 logout(USER_EXPLICIT)後 emit = post-boot,boot 期間不可能 fire | 無需 boot cover(by construction) |
| `state_changed` (#1 GSM) | #1 pos 1-2 | None — 行 `connect_for_initial_state`(ADR-0006 C6)boot 即 pull current state | AC-27 已驗 sentinel 即收 current state |

**驗證紀律**:呢張表係 epic 「上游 boot-emit contract」story 嘅 ground truth;任何上游將來改成 boot `_ready()` 同步 emit persistence-failed → 必須(a)行 #3 deferred-emit pattern,或(b)提供 pull-getter 畀 #24 boot pull-check,二擇一,唔可默認 signal-only。

### Cross-reference

- Player Fantasy falsifiable tests 覆蓋:Test 1(Locker-Room WiFi)→ EC-C1 + Rule 9;Test 2(Silent Corruption)→ EC-B1/B2/B3/**B9** + EC-**E5/E6** boot sweep + Rule 5;Test 3(Mid-Set Logout)→ Rule 12 + EC-B6;Test 4(Honest Door)→ Rule 10 + EC-E4。
- Sister presentation systems 零重疊:#22/#23 ECs 聚焦 overlay lifecycle/claim/salvage;#24 ECs 聚焦 auth/banner/connection — 唔 duplicate。

## Dependencies

### Upstream(#24 requires)

| # | System | Hard/Soft | Nature |
|---|--------|-----------|--------|
| **#2** GymSys Backend Client | **Hard(sole auth/transport)** | `claim_session` / `clear_session_token` / `auth_required` / `drain_started` / `drain_completed` / immediate-poll API + **兩個 additive API gate**:`get_auth_block_reason()`(G-LS-4)+ claim_session async 簽名 pin(G-LS-3)。#2 GDD「Depended On By」已 reciprocal 列 #24(P0-4 drain UI / P0-6 misconfig prompt / P0-7 update prompt)+ L272 interactions row + L481「必須引用」清單 — 全部本 GDD 兌現 |
| **#1** GameStateMachine | Hard(state observer) | `state_changed` 經 `connect_for_initial_state`(ADR-0006 C6);9-state enum 分流 shell FSM;#24 永不 request transition |
| **#3** PersistenceLayer | Soft(error consumer) | `critical_save_failed(error_code, key)` 12 codes → severity map(Q-X12 閉環);#3 GDD「UI surfaces owned by #24」prose 兌現;**#24 自己零 persistence keys** |
| **#33** Attention Budget | Soft(carve-out 引用) | EC-13:#24 reconnect/login surface 唔被 `is_input_permitted` gate(#33 已明文) |

### Upstream error-signal producers(#24 係指定 banner consumer — forward contracts 兌現)

| # | Signal | 上游 GDD 指定 |
|---|--------|--------------|
| **#8** Streak | `streak_persistence_failed(error_code, key)` | streak-system.md Section F「blocking message 由 #24」→ 本 GDD 兌現為 FEATURE_DEGRADED persistent banner(**修訂語意**:唔係 blocking modal — Pillar 2;「blocking」原意 = 唔可 dismiss 直至解決,persistent banner 滿足)。**上游 doc erratum(G-LS-9)**:#8 GDD L755 寫單參 `(error_code)` 係 stale — shipped `streak_system.gd` 係 `(error_code, key)` 雙參;#24 跟 shipped code(CD-GDD-ALIGN A3) |
| **#11** Stat System | `stat_critical_save_failed(stat_id)` | stat-system.md L697「persistent warning banner」→ FEATURE_DEGRADED class |
| **#12** Ability System | `ability_unlock_save_failed(ability_id)` | ability-system.md L671「persistent warning banner +『嘗試 retry』」→ FEATURE_DEGRADED class(auto-clear on next success = retry 語意) |

### Downstream(depends on #24)

| # | System | Nature |
|---|--------|--------|
| **#27** Onboarding Flow | host 關係:#27 choreograph 首次連接流程,#24 提供 login surface;#27 GDD authoring 時引用本 GDD shell states |
| **#22 / #23** | `request_open()` arbiter + 入口 affordance host(Q-CS1 / Q-IU1 閉環);#22 `loadout_view_all_tap` 遷移(G-LS-5) |
| **#29** Mirror Moment(v0.2) | Q-X8 returning-player ritual(Safari ITP 7d eviction)— #29 authoring 時同 #24 LOGIN state 對接(Q-LS2) |
| **#19** Zone System(v0.2) | zone 選擇 UI 掛喺 shell(#19 已 flag #22/#24)— MVP 零接觸 |

### ADRs referenced

- **ADR-0001**(layer 拓撲)— G-LS-1 amendment:LoginShellLayer 62 PAUSABLE + capture enumeration +62;ErrorBannerLayer 111 ALWAYS;banner 禁第二 BackBufferCopy
- **ADR-0002**(GymSys protocol)— claim/token/cursor-replay 契約;斷線「會補返」copy 嘅誠實依據
- **ADR-0004**(same-origin nginx)— login 零 CORS UX
- **ADR-0006** C6(`connect_for_initial_state`)+ C4(autoload 順序)
- **ADR-0008**(autoload position map)— G-LS-2 amendment:LoginShellCoordinator tail append
- **ADR-0003**(save state)— Private Mode detect-and-gate(banner + loot disable)= Q-E1 閉環依據

**Bidirectional 完整性**:#2(L9/L272/L481)/ #3(L438/L442)/ #8(L755)/ #11(L697)/ #12(L671)/ #22(Q-CS1)/ #23(Q-IU1/L225)/ #33(EC-13)全部已有 #24 反向 entry — 零 one-directional gap。#27/#29 未寫 GDD,佢哋 authoring 時引用本 GDD(provisional contract 由 #24 side lock,#8 Section F 先例)。

## Tuning Knobs

### Owned by #24(4 knobs + 1 data-driven map)

| Knob | Default | Safe Range | Source / Used By | Too high | Too low |
|------|---------|------------|------------------|----------|---------|
| `SHELL_FADE_SEC` | 0.25 | `[0.1, 0.5]` | States 轉場 / EC-E1 | > 0.5 → 轉場遲滯感,login 成功後遮住 landing state | < 0.1 → 接近 hard-cut,onset transient 變 attention event |
| `TRANSIENT_BANNER_TTL_SEC` | 5.0 | `[3.0, 10.0]` | Formula 2 / Rule 6 | > 10 → TRANSIENT 變偽 persistent,稀釋 ONGOING/WIPE/FEATURE_DEGRADED 嘅 persistent 語意 | < 3 → 玩家眼角未及讀完 |
| `DRAIN_SUCCESS_EXPIRE_SEC` | 2.0 | `[1.0, 3.0]`(**上界收窄 5.0→3.0 — systems R2 cartesian fix**:原 [1.0,5.0] × TRANSIENT [3.0,10.0] 有 DRAIN=5.0+TRANSIENT=3.0 兩個各自合法但違反 invariant 2 嘅組合;收窄令笛卡兒積恆安全) | Formula 2 / Rule 12 | > 3 → 「儲好喇」可能長過 TRANSIENT toast 語意倒錯 | < 1 → 玩家未見到 closure 確認 |
| `BANNER_MAX_HEIGHT_PCT` | 0.10 | `[0.06, 0.10]`(**#24 自有 knob**;上限數值沿用 #2 Q-X9 L678 peripheral class ≤10% — 對 #20 spinner 嘅 CD cascade binding,#24 採納同一紀律,**唔係** #20 契約 — CD-GDD-ALIGN C4 attribution 修正) | Rule 7 | > 0.10 → 脫離 peripheral class,banner 變 attention surface | < 0.06 → CJK 12px + glyph 擺唔落 |
| `error_severity_map.tres` | Rule 6 表 | data-driven(新 error code 加入時 designer 改 .tres 唔改 code) | Rules 5/6 | — | — |

### Read-only(owned elsewhere)

| Knob | Owner | #24 用途 |
|------|-------|---------|
| `SessionClaimResult.retry_after` | #2 | Formula 1 倒數 |
| `SESSION_TOKEN_TTL_HOURS`(720) | #2 | re-login 頻率假設(Rule 13 誠實申報嘅依據) |
| GSM 9-state enum | #1 | shell FSM 分流 |
| #3 12 error codes enumeration | #3 | severity map keys(#3 係 source of truth — code 列表變更 = #3 GDD 改,#24 map 跟) |

### 唔可 runtime tune(compile-time / 紀律鎖死)

| Constant | Value | Why locked |
|----------|-------|------------|
| Banner 靜態紀律 | 零 animation / pulse / audio | Rule 8 — Pillar 2 binding;改 = urgency gesture 入侵 |
| Banner `max_visible` | 1 | Rule 7 — 疊 banner = 迫近 modal 體感 |
| Banner backdrop | opacity-only,禁第二 BackBufferCopy | ADR-0001 #21 blur-CUT 同源裁決 |
| 入口 enabled/hidden 二態 | 永不 greyed | Rule 10 — 對齊 #22 EC-30 全功能本地 view;grey 全功能 surface = 細講大話 |
| TELEMETRY-CLASS 訂閱禁令 | 4-signal whitelist | #2 L120 CI lint |

### Cross-knob invariants

1. `DRAIN_SUCCESS_EXPIRE_SEC ≤ TRANSIENT_BANNER_TTL_SEC`(通知類唔可以長過 TRANSIENT — 語意一致);at defaults:2.0 ≤ 5.0 ✓。**DRAIN range 上界收窄 3.0 ≤ TRANSIENT 下界 3.0 → 笛卡兒積恆安全**(systems R2 — 原 invariant 1 `SHELL_FADE < ENTRY_DEBOUNCE` 隨 debounce 移除而刪)。
2. `BANNER_MAX_HEIGHT_PCT ≤ 0.10`(#20 契約 hard ceiling)。

**驗證紀律(qa-lead B2 — release-safe,非 raw assert)**:兩條 invariant + 每個 TTL/fade knob 喺自己 safe range 內(含 `> 0` 下界 — 防 `DRAIN_SUCCESS=0` 令 Formula 2 banner 永不顯示 — systems N4),由 `_validate_knobs() -> bool`(return false / `push_error` + clamp)守,**唔淨靠 raw `assert()`**(Godot release build strip `assert()` → shipped build 唔 trip;GUT 亦捉唔到 raw assert failure → tautological phantom pass)。AC-21 測 **pass + violation 兩路**(注入違反組合驗 `_validate_knobs()` 返 false)。

## Visual/Audio Requirements

(art-director 諮詢 2026-06-08;依 art bible §1.2 P3 Layer Discipline + §7.A Frameless HUD + §7.C Solid Silhouette + §7.D Snap+Settle)

**一句 synthesis**:#24 係 infrastructure surface — 視覺語言 = `ui_ink_bg #1A1D24` + `ui_text_primary #F5EFE0` flat base;amber `#F2A93B` 只有兩個用途(submit CTA + 重-weight banner [ONGOING/WIPE] accent bar);全部 icon 8px solid silhouette squint-passable;零 animation(只有 cross-fade ≤0.25s ease-out cubic);font = Zpix 12px CJK + m6x11 latin(#21 先例)。

### Login form

- 全屏 `ui_ink_bg` 底:BOOTING 時純底(零 world);re-login 時 opaque scrim 完全遮 world(context 切換明示)
- Form card:`ui_ink_bg` + 1px `ui_text_primary` @8% 邊框;input 底色 ink 加深 ~10%(下陷可輸入感);input text ≥16px display(iOS auto-zoom 防)
- Submit = **唯一 amber 元素**(`event_amber #F2A93B` fill + ink label);title lockup = m6x11 大階「MIRROR HERO」(`ui_text_primary`,唔用 amber,零 logo asset 需求)
- Inline error:`ui_text_primary` text + ⚠ glyph,**零 red**(色盲安全,glyph carry meaning)
- Form 內零 idle animation;cursor 閃爍係 native,唔干預

### Banner 視覺區分(semantic 4 class → visual 3 weight;色 + glyph 雙 encode — Rule 8)

| Visual weight | Semantic class | 背景 | Glyph | 文字 |
|---|---|---|---|---|
| 重 | **ONGOING + WIPE** | `ui_ink_bg` + **4px amber 左 accent bar** | ⚠ 8×8 amber | `ui_text_primary` — amber = 「真實且重要」嘅誠實感,唔係紅色驚嚇(WIPE 多一個 acknowledge tap 區) |
| 中 | **FEATURE_DEGRADED** | `ui_ink_bg` flat | ⚠ 8×8 dim | `ui_text_dim` ~70% — 唔需視覺緊張 |
| 輕 | **TRANSIENT** | `ui_ink_bg` @40% | ⓘ 8×8 dim | `ui_text_dim` toast |

- DISCONNECTED status banner 用 **中 weight 視覺**(dim — 斷線係等待狀態唔配 amber urgency)+ slash glyph 做 non-color encode
- 共用:1px ink hard shadow on text;固定底部 ≤10%;零 animation/pulse/audio;backdrop opaque flat 禁 blur
- 重 weight vs 中 weight 同 shape ⚠ 靠 modulate 區分 — acceptable,因為重 weight 有 left accent bar 做第二 encode(squint test 守住)

### 入口卡 + interactive-dimmed state(罕見 race)

- 卡:`ui_ink_bg` frameless + 16×16 solid silhouette icon(amber modulate @ enabled)+ Zpix label + 1px shadow;tap target ≥48px;可借用 #22 `ui_card_item_bg` 9-slice
- Settings gear:corner、`ui_text_dim`、唔用 amber(logout 係破壞性動作 — amber 保留畀可賺取 action)
- **入口卡喺 IDLE/DISCONNECTED 恆 enabled**(amber modulate;對齊 #22 EC-30 全功能本地 view — 唔 grey)。**Rule 10「enabled/hidden 二態」指 steady-state**;唯一例外係**罕見 race-window**(`can_open()` false — GSM 離開 IDLE 但 shell 未轉 HIDDEN 嗰瞬,SHELL_IDLE/DISCONNECTED_SHELL 下近乎不可達)出現嘅 **interactive-dimmed 態**:整卡 alpha 55% **但仍可 tap → inline reason**(≠ 已刪嘅 non-interactive greyed disable;alpha ≠ desaturate ≠ greyed — desaturate 係 §4.E World Layer/MoodController 工具,UI chrome dimmed 語言 = alpha)。**非 permitted state(workout 系)= 整個 shell hidden,入口唔 render**(對齊 #22「pin:hidden 唔係 greyed」紀律)。此 interactive-dimmed sub-case 由 AC-39 race-branch 斷言
- shell state 轉場 cross-fade 0.25s(`SHELL_FADE_SEC`;無 debounce settle — 已刪);enable↔interactive-dimmed 切換亦 cross-fade

### Audio

**零 audio**。Banner 零 cue(Rule 8);login 成功/失敗 silent(#23 silent 紀律先例);唔開 #4 catalog gate。

### Asset 需求(8 sprites — /asset-spec 用)

`ui_icon_disconnected_slash_8`(8×8)/ `ui_icon_warning_8`(8×8,amber+dim modulate 雙用)/ `ui_icon_info_8`(8×8)/ `ui_icon_check_8`(8×8)/ `ui_icon_eye_toggle_16`(16×16)/ `ui_icon_settings_gear_16`(16×16)/ `ui_icon_char_entry_16`(16×16 人形)/ `ui_icon_bag_entry_16`(16×16 背包形)。其餘全部 code-drawn(banner backdrop / accent bar / form card)。

> 📌 **Asset Spec** — Visual/Audio requirements 已定義。Art bible approved 後行 `/asset-spec system:login-gymsys-connection-ui` 產出 per-asset spec。

## UI Requirements

(ux-designer 諮詢 2026-06-08;`/ux-design login-gymsys-connection-ui` 出 wireframe-level spec 先入 epic — UX Flag 見文末)

- **Login form**:username + password + show-password toggle + submit;**無** remember-me(token persist 係 default)/ 無註冊 / 無忘記密碼;全部 interactive target ≥44×44px;input font ≥16px;keyboard-only 可完成(tab 順序 username → password → toggle → submit)
- **錯誤顯示**:inline(form 內),廣東話口語 witness register;`rate_limited` live 倒數;error 區 ARIA live `assertive` — **經 `PlatformDetect.announce_aria` JS-bridge 推入 DOM ARIA-live element,唔靠 4.5 AccessKit**(godot R6:AccessKit native-only,canvas 對 DOM accessibility tree 不透明,VoiceOver 讀唔到 canvas 內容;ADR-001 raw JavaScriptBridge.eval 只准喺 platform_detect.gd);唔純靠色(⚠ glyph)
- **IDLE shell 佈局**:world avatar 自然置中(#26 render — 情感焦點);#22/#23 兩張入口卡並排(平等、大 target、icon + text label 雙 channel);settings gear corner(logout 收一層);connection status dot
- **Banner**:固定底部 ≤10%;單 slot + 「+N」;**ONGOING acknowledge-to-minimize**(tap 確認 → collapse 做 status glyph,唔永久全 banner — game-designer B2,SR 唔被永久 re-announce nag)/ WIPE acknowledge-dismiss(一次性事件)/ FEATURE_DEGRADED auto-clear on success,TRANSIENT/通知 auto-expire;ARIA live `polite` **經 `PlatformDetect.announce_aria`**(peripheral 唔打斷 SR;唔靠 AccessKit — godot R6);零 flashing(WCAG;Rule 8 靜態紀律順帶滿足)
- **Drain banner**:non-interactive;text 狀態 + ✓ glyph(唔純 spinner — reduce-motion + SR)
- **Reconnect**:「再試一次」text 掣 ≥44px;狀態用 text(「連緊…」/「仲係連唔到」)唔純 spinner
- **A11y(canvas web 限制 — ux BF-2 / godot R6)**:canvas 對 DOM accessibility tree 不透明 → 所有 SR 公告(error / banner / status / drain)**必經 `PlatformDetect.announce_aria`**(#21/#22/#23 已建立 seam);keyboard tab 順序喺 banner 出現時唔搶 form focus;G-LS-6 spike 連帶驗 SR 實機行為
- **誠實申報(玩家預期管理)**:MVP 無 browser password manager / Keychain autofill(canvas 結構限制);靠 30 日 token TTL 令 re-login 罕見;DOM overlay v0.2 候選

> 📌 **UX Flag — Login / GymSys Connection UI**:本系統有 UI requirements。Epic 前必行 `/ux-design login-gymsys-connection-ui`(重點:login form wireframe + banner anatomy/region 同 #20 non-overlap 釘實 + shell 入口佈局 + enabled/disabled 狀態 spec)。Stories 引用 `design/ux/login-gymsys-connection-ui.md`,唔直接引 GDD。

## Acceptance Criteria

(qa-lead 起草 2026-06-08;main session 修正 breakdown 算術。全部 timing test 用 injected clock `advance(delta_ms)` — GUT 唔 tick child `_process`;persistence-consumer test 喺 `add_child` **前**注入 mock — 真 autoload cache 跨 file 污染先例。)

### Coordinator / FSM(Integration,BLOCKING)

- **AC-01**: GIVEN `LoginShellCoordinator._ready()` 完成,WHEN 驗證 coordinator shape,THEN 持有 `LoginShellLayer`(layer 62,PAUSABLE)+ `ErrorBannerLayer`(layer 111,ALWAYS),兩個初始 `visible=false`;零第二 autoload(coordinator-owned;但 BannerStack/shell-transitions **拆獨立 file** `src/ui/login_shell/banner_stack.gd` + `shell_transitions.gd` 存在 — Rule 1 file-split,AC-35a grep target 前提;Rule 14 講 FSM extraction 唔等於 file mandate)。Source: Rules 1/14 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_coordinator.gd`
- **AC-02**: GIVEN 完整 claim success + logout cycle(MockPersistenceLayer 注入於 add_child 前),WHEN cycle 完成,THEN mock `write_calls == 0`(#24 零 persistence write;token 寫入只來自 MockGymSysClient)。Source: Rule 15 | Integration | BLOCKING | 同上
- **AC-03**: GIVEN shell 喺任意 state,WHEN mock emit `auth_required`,THEN 下一 frame 入 `LOGIN` + `LoginShellLayer.visible == true`。Source: Rule 2 / States | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_fsm.gd`
- **AC-24**: GIVEN shell 已喺 LOGIN + form 有已填文字,WHEN `auth_required` 再 fire,THEN 仍喺 LOGIN、已填文字**保留**、唔 double-render(EC-A3 idempotent)。Source: EC-A3 | Integration | BLOCKING | 同上
- **AC-27**: GIVEN `_ready()` 執行,WHEN spy GSM connection,THEN 用 `connect_for_initial_state` 模式(唔係 plain connect)— boot 即收 current state。Source: ADR-0006 C6 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_coordinator.gd`

### Claim flow(Integration,BLOCKING)

- **AC-06 [GATED G-LS-3]**: GIVEN form submit enabled,WHEN tap submit,THEN 即時 disable + loading;`claim_session_calls == 1`(防 double-submit)。Source: Rule 3 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_claim_flow.gd`
- **AC-07 [GATED G-LS-3]**: GIVEN claim success,WHEN mock GSM 仍喺 BOOTING,THEN shell 唔切換 state — 等 `state_changed`(yield landing state)。Source: Rule 3 | Integration | BLOCKING | 同上
- **AC-08 [GATED G-LS-3]**: GIVEN claim success + mock GSM emit `(BOOTING → LOOT_DROP)`,THEN shell 入 `HIDDEN` 唔入 SHELL_IDLE(EC-A5 deferred reveal path)。Source: Rule 3 / EC-A5 | Integration | BLOCKING | 同上
- **AC-22 [GATED G-LS-3]**: GIVEN claim await 掛起,WHEN mock GSM emit SUSPENDED + injected clock 超 timeout,THEN submit re-enable + copy 含「程序中途中斷」、**唔**含「登入失敗」。Source: EC-A1 | Integration | BLOCKING | `tests/unit/login_shell/test_claim_edge_cases.gd`

### Error map(Integration,BLOCKING)

- **AC-09**: GIVEN claim 返 `invalid_credentials`,THEN inline copy 含「username 或者 password 唔啱」+ submit re-enable + **零** raw HTTP 字串 — copy 唔 match regex `\d{3}`(任何三位 code)**且**唔含字面 `HTTP`/`http`(qa R6 deny-list,非開放式「etc.」)。Source: Rule 4 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_error_map.gd`
- **AC-10**: GIVEN claim 返 `network_error`,THEN inline「而家連唔到」+ retry 掣 + 零 raw HTTP(deny-list regex 同 AC-09)。Source: Rule 4 | Integration | BLOCKING | 同上
- **AC-11**: GIVEN claim 返 `server_error`,THEN inline「伺服器嗰邊出咗少少問題」+ retry + re-enable + 零 raw HTTP(deny-list regex 同 AC-09)。Source: Rule 4 | Integration | BLOCKING | 同上
- **AC-23**: GIVEN session conflict 場景(另一 tab claim — #2 落 `server_error` bucket),THEN server_error copy,零 conflict-specific / raw HTTP 字串(EC-A2)。Source: EC-A2 / Rule 4 | Integration | BLOCKING | 同上
- **AC-12**: GIVEN form render,WHEN `find_children()` 檢查,THEN 存在 username/password(`secret==true`)/toggle/submit;**唔**存在 remember-me / 註冊 / 忘記密碼元素。Source: Rule 13 | Integration | BLOCKING | `tests/unit/login_shell/test_login_form_spec.gd`

### Formulas(Logic,BLOCKING — injected clock boundary-exact)

- **AC-13/14/15**: *(已移除 — 原 directional-debounce formula 隨 Rule 10 debounce 整套刪除,fresh re-review 2026-06-08;入口恆 enabled,flicker 天然消失,無 boundary 可測。編號留空避免 cascade renumber。)*
- **AC-16**: GIVEN `retry_after=30, t_start=100`,WHEN t=115,THEN `display_seconds == 15`。Source: F1 | Logic | BLOCKING | `tests/unit/login_shell/test_rate_limit_formula.gd`
- **AC-17**: GIVEN 同上,WHEN t=130,THEN `display_seconds == 0` + `submit_enabled == true` + 倒數 copy 消失。Source: F1 / EC-D1 | Logic | BLOCKING | 同上
- **AC-18**: GIVEN claim 返 `rate_limited` + `retry_after == 0`,THEN 即時 re-enable + **唔**顯示任何倒數 copy。Source: F1 / EC-D1 | Logic | BLOCKING | 同上
- **AC-19**: GIVEN drain ✓ banner @ t=200 + `DRAIN_SUCCESS_EXPIRE_SEC=2.0`,WHEN t=201.5 → visible;t=202.1 → 消失。Source: F2 / Rule 12 | Logic | BLOCKING | `tests/unit/login_shell/test_banner_expire_formula.gd`
- **AC-19b**: GIVEN drain ✓ banner @ t_b=200 + TTL 2.0,WHEN advance 到 **exactly t=202.0**,THEN banner **已唔 visible**(strict `<` boundary — qa R4)。Source: F2 boundary | Logic | BLOCKING | 同上
- **AC-20**: GIVEN `NOT_READY` TRANSIENT banner(TTL 5.0)**+ 同場一條 `READ_ONLY_FILESYSTEM` ONGOING persistent banner**,WHEN t 超 5.0 → TRANSIENT 消失而 **ONGOING/WIPE/FEATURE_DEGRADED 仍 visible**(不受 F2 影響 — qa R7 GIVEN 補 persistent)。Source: F2 / Rule 6 | Logic | BLOCKING | 同上
- **AC-21a/b**: GIVEN 合法 default knobs,WHEN `_validate_knobs()`,THEN 返 `true`;GIVEN **注入違反組合**(a: `DRAIN_SUCCESS_EXPIRE_SEC=3.5 > TRANSIENT_BANNER_TTL_SEC=3.0`;b: `BANNER_MAX_HEIGHT_PCT=0.12 > 0.10`),THEN 返 `false`(或 `push_error`)+ clamp。**用 `_validate_knobs()` 唔用 raw `assert()`**(release-safe — qa B2;原 invariant 1 debounce 已刪,3→2 條)。**註**:DRAIN range 上界收窄 3.0 = TRANSIENT 下界 3.0 後,invariant 1/2 與各自 knob range 邊界重合 = defensive-redundant;本 AC 實際驗 `_validate_knobs()` 嘅 reject 路徑(range + invariant 重疊保護)。Source: Cross-knob invariants 1-2 | Logic ×2(pass+fail 各) | BLOCKING | `tests/unit/login_shell/test_knob_invariants.gd`

### Banner 系統(BLOCKING)

- **AC-26**: GIVEN 空 BannerStack + 4 個 upstream error signal 已 connect,WHEN 逐一 mock emit 每條(帶已知 payload),THEN 每次 emit 後 `BannerStack.entries.size()` **恰好 +1**,且新 entry 嘅 `dedupe_key == 預期 (source, error_code, key)` **且** `severity_class == Rule 6 對應 class`(非 tautological「有嘢郁」— qa B1:錯 severity/錯 key/空 banner 都 fail)。Source: Rule 5 / Fantasy Test 2 | Integration | BLOCKING | `tests/unit/login_shell/test_zero_silent_swallow.gd`
- **AC-29**: GIVEN 空 stack,WHEN 同 frame emit FEATURE_DEGRADED(#8 sibling)+ ONGOING(`READ_ONLY_FILESYSTEM`),THEN 主 slot = ONGOING、FEATURE_DEGRADED 入「+N」(severity order 唔係 arrival order — EC-B2)。Source: Rule 7 / EC-B2 | Integration | BLOCKING | `tests/unit/login_shell/test_banner_stack.gd`
- **AC-29b**: GIVEN 空 stack,WHEN 同 frame emit **兩個同 class** banner(#11 + #12 兩個 FEATURE_DEGRADED),THEN 主 slot 由 `arrival_sequence`(單調 int counter)決定、跨 run 一致 — **deterministic tie-break**(`sort_custom` 非 stable + StringName pointer-sort gotcha 收口;comparator total-order `(severity, arrival_sequence)`,StringName 比較先轉 String)。Source: Rule 7 / EC-B2 | Integration | BLOCKING | 同上
- **AC-30/31/32**: GIVEN `error_severity_map.tres` 載入,WHEN 逐 code 查詢,THEN(30)ONGOING 2 codes(`QUOTA_EXHAUSTED`/`READ_ONLY_FILESYSTEM`)→ `dismissable=false`;(31)WIPE 8 codes 全部 → `acknowledge_dismissable=true` + 誠實 wipe copy key,#8/#11/#12 sibling 全部 → `FEATURE_DEGRADED + auto_clear_on_success=true`;(32)TRANSIENT 2 codes → F2 TTL(Rule 6 表逐項,12+3 mappings 全 assert)。Source: Rule 6 | Logic ×3 | BLOCKING | `tests/unit/login_shell/test_severity_map.gd`
- **AC-33**: GIVEN ONGOING banner 喺主 slot,WHEN DISCONNECTED status 出現,THEN DISCONNECTED 佔主 slot、ONGOING 入「+N」;DISCONNECTED resolved → ONGOING 升返(EC-B4)。Source: Rule 7 | Integration | BLOCKING | 同上
- **AC-34**: GIVEN `(FLUSH_FAILED, "k1")` banner 存在,WHEN 同 key 再 fire,THEN entry count 唔變、timestamp 更新、「+N」唔虛高(EC-B5)。Source: Rule 7 | Integration | BLOCKING | 同上
- **AC-25 [GATED G-LS-9]**: GIVEN `tools/ci/check_no_ui_subscribes_telemetry.sh` 已創建 **且 scope 已含 UI-class autoload coordinators**(#2 L120 原 spec 只掃 `src/ui/**` — 唔 cover #24,直接照 spec implement = zero-coverage 假 green,CD-GDD-ALIGN C2),WHEN 行 lint,THEN exit 0;coordinator 只 connect 4-signal whitelist,11 個 forbidden signal 零 `connect(` 痕跡。Source: Rule 2 / G-LS-9 | Static-CI | GATED | CI step(epic CI story 連 script 創建一齊做)
- **AC-35a**: GIVEN **獨立 banner file** `src/ui/login_shell/banner_stack.gd`(Rule 1 拆 file),WHEN source grep(排除 comment line — #21 `test_banner_telemetry.gd` 先例),THEN 零 `create_tween` / `pulse` / `AudioStreamPlayer` / `\.play(`(token 收窄,唔誤殺合法 state-transition cross-fade tween — 嗰啲喺 `shell_transitions.gd`)。Source: Rule 8 | Static-CI | BLOCKING | CI grep step(epic 新增)
- **AC-35b**: GIVEN `ErrorBannerLayer` scene,WHEN `find_children("*","AnimationPlayer",true)` 同 `find_children("*","AudioStreamPlayer",true)`,THEN **皆空**(鏡 AC-36 scene-tree pattern — 捉 .tscn instanced autoplay node,source grep 漏網嗰類;qa B4 / ui R1)。Source: Rule 8 / ADR-0001 | Integration | BLOCKING | `tests/unit/login_shell/test_layer_spec.gd`
- **AC-36**: GIVEN 兩個 #24 layer scene,WHEN `find_children("*","BackBufferCopy",true)`,THEN 空(禁第二 BackBufferCopy)。Source: Rule 8 / ADR-0001 | Integration | BLOCKING | `tests/unit/login_shell/test_layer_spec.gd`
- **AC-50**: GIVEN #24 claim / error 全部 source path,WHEN static grep,THEN 零 credential var(username/password)入 `print(` / `push_error(`;password `LineEdit.text` 喺 claim resolve 後 clear。Source: Rule 15 / ui R5 | Static-CI | BLOCKING | CI grep step + `tests/unit/login_shell/test_credential_residue.gd`
- **AC-51**: GIVEN Formula 1/2 路徑 source,WHEN grep,THEN **零直 call `Time.get_ticks_msec()`**(必讀注入 clock — 否則 advance() 影響唔到 → wall-clock phantom;ui R2 / qa R1)。Source: Formulas intro | Static-CI | BLOCKING | CI grep step
- **AC-52**: GIVEN `error_severity_map.tres` 載入,WHEN mock #3 emit 一個 **唔喺 12-code 嘅 error_code**(e.g. `"FUTURE_CODE_13"`),THEN BannerStack 出現 ONGOING-weight 可見 banner(`dismissable` per UNMAPPED row)— **零 silent drop**(default-deny;EC-B9 / B1)。Source: Rule 5/6 UNMAPPED | Integration | BLOCKING | `tests/unit/login_shell/test_severity_map.gd`
- **AC-54**: GIVEN shell `HIDDEN`(mock GSM WORKOUT_ACTIVE),WHEN mock #3 emit ONGOING(`READ_ONLY_FILESYSTEM`),THEN `ErrorBannerLayer` banner `visible == true` 而 `LoginShellLayer.visible == false`(two-layer 獨立性 — banner 喺 workout 之上;EC-E3 / qa R3)。Source: Rule 1 / EC-E3 | Integration | BLOCKING | `tests/unit/login_shell/test_layer_spec.gd`

### DISCONNECTED / 入口 / logout(Integration,BLOCKING)

- **AC-37**: GIVEN mock GSM `WORKOUT_ACTIVE → DISCONNECTED`,THEN shell **唔**入 DISCONNECTED_SHELL(留 HIDDEN);ErrorBannerLayer 顯示 peripheral banner 含「GymSys 照記住」copy + tappable「再試一次」;零全屏轉場。Source: Rule 9(a) / Fantasy Test 1 | Integration | BLOCKING | `tests/unit/login_shell/test_disconnected_surface.gd`
- **AC-37b [GATED G-LS-4]**: GIVEN AC-37 banner,WHEN tap「再試一次」,THEN spy 收到 `GymSysClient.request_immediate_poll()` call ==1(retry 掣真接 #2 — G-LS-4(b) additive,mock-scoped 先行;qa R4)。Source: Rule 9(a) / G-LS-4 | Integration | GATED | 同上
- **AC-38**: GIVEN `_pending_auth_required == true`(mid-workout defer),WHEN GSM → IDLE(或 DISCONNECTED — EC-C4),THEN 即入 LOGIN + flag 清零;LOGIN 入場唔以 IDLE 為 precondition。Source: EC-C4 / Rule 9 | Integration | BLOCKING | 同上
- **AC-39**: GIVEN DISCONNECTED_SHELL steady-state,WHEN render 入口,THEN #22/#23 卡 `visible == true` + **`modulate.a == 1.0`(enabled,非 greyed — 對齊 #22 EC-30 全功能本地 view)**。**Race-branch**:GIVEN `can_open()` 返 false(罕見 — GSM 離 IDLE 但 shell 未轉 HIDDEN 嗰瞬),THEN 卡 `modulate.a == 0.55`(interactive-dimmed)**但仍 tappable → tap 出 inline reason**(唔 force open — EC-E4;≠ non-interactive greyed)。**permitted state 零 hidden 入口**(Honest Door 新義 — Rule 10)。Source: Rule 10 / EC-E4 | Integration | BLOCKING | `tests/unit/login_shell/test_entry_affordance.gd`
- **AC-40**: GIVEN #22 open,WHEN `request_open(&"inventory")`,THEN #22 close(deferred)→ #23 open;`can_open()` 被查詢(double guard 唔 bypass);false → 唔 force open + log warning(EC-E4)。Source: Rule 11 | Integration | BLOCKING | `tests/unit/login_shell/test_shell_arbiter.gd`
- **AC-41**: GIVEN SHELL_IDLE,WHEN logout tap,THEN `clear_session_token(USER_EXPLICIT)` 即時 call + 「已登出」banner(count=N)+ 入 DRAINING + **零** blocking modal(Fantasy Test 3)。Source: Rule 12 | Integration | BLOCKING | `tests/unit/login_shell/test_logout_drain.gd`
- **AC-42**: GIVEN DRAINING,WHEN `drain_completed(5, 2)`,THEN drain banner **替換**做 persistent banner 含「2 樣嘢今次冇儲到」(acknowledge-dismiss,WIPE-weight 視覺 — EC-B6,永不 silent)。Source: Rule 12 / EC-B6 | Integration | BLOCKING | 同上

### GATED(G-LS-4 / G-LS-8 — mock-scoped 先行,真接線 story 另開)

- **AC-04 [GATED G-LS-4]**: GIVEN LOGIN 入場,WHEN mock `get_auth_block_reason()` 返 `&"update_required"`,THEN 顯示 update prompt、唔顯示 form。Source: Rule 2 | Integration | `tests/unit/login_shell/test_login_shell_block_reason.gd`
- **AC-05 [GATED G-LS-4]**: 同上 `&"carve_out_misconfig"` → operator prompt + `acknowledge_carve_out_fix()` 指引。Source: Rule 2 | Integration | 同上
- **AC-28 [GATED G-LS-8]**: GIVEN mock `get_pending_errors()` 返 `["QUOTA_EXHAUSTED"]`(add_child 前注入),WHEN `_ready()` 完成,THEN BannerStack 已有 ONGOING banner(`dismissable=false`)— boot-window gap 由 pull-check cover(EC-B1/B3)。Source: EC-B1 | Integration | `tests/unit/login_shell/test_boot_window_pull_check.gd`
- **AC-53 [GATED G-LS-4]**: GIVEN mock `is_auth_required()` 返 `true`(add_child 前注入,模擬 #2 `_ready()` 同步 emit 已走漏),WHEN #24 `_ready()` 完成,THEN shell 已入 `LOGIN`(`LoginShellLayer.visible == true`)— **boot-race 由 pull-check cover,唔靠 signal**(EC-E5 / godot B1)。Source: EC-E5 / Rule 2 | Integration | `tests/unit/login_shell/test_boot_window_pull_check.gd`

### ADVISORY / EXTERNAL(Manual — `production/qa/evidence/`)

- **AC-43 [ADVISORY]**: login form 截圖 sign-off:`ui_ink_bg` 全屏底 / submit 唯一 amber / error ⚠ 零 red / toggle ≥44px。`ac43-login-form-visual.png`
- **AC-44 [ADVISORY]**: banner 視覺截圖:重 weight(ONGOING/WIPE)amber bar / FEATURE_DEGRADED dim / TRANSIENT @40%;squint-test 可區分;零 pulse/flashing。`ac44-banner-visual.png`
- **AC-45 [ADVISORY]**: 入口截圖:IDLE/DISCONNECTED **皆 enabled(無 greyed)**;非 permitted state shell 整個 hidden;`can_open()` false 時 tap 出 inline reason + 0.25s cross-fade smooth。`ac45-entry-affordance.png`
- **AC-46 [ADVISORY]**: drain banner walkthrough:text + ✓ glyph(唔純 spinner)/ non-interactive / 底部 ≤10% / 零 modal。`ac46-drain-banner.md`
- **AC-47 [EXTERNAL]**: iOS Safari real-device(G-LS-6 spike 連動):keyboard 唔遮 form(或 scroll 補救)/ submit 可達 / **canvas LineEdit 路線實測 auto-zoom 是否存在**(16px 對 canvas 大機會 no-op — ui R8/godot R4,唔可預設已解決)/ **dual-focus 兩種 input(touch-tap + keyboard tab)都驗**(4.6 breaking change — godot R5)。`ac47-ios-keyboard.md`
- **AC-48 [ADVISORY]**: Locker-Room WiFi Test playtest:mid-set 斷線 30s 自動恢復全程零 tap 零 modal,進度完整。`ac48-locker-room-wifi-test.md`
- **AC-49 [ADVISORY]**: SHELL_IDLE 佈局 walkthrough:兩卡並排 icon+label / gear corner / status dot / avatar 由 #26 render(shell 唔 own)/ logout 收一層。`ac49-shell-idle-layout.png`

### Total count + breakdown

**56 ACs active**(AC-01..54 + AC-19b/29b/35b/37b 子條;**AC-13/14/15 已移除留空 placeholder**;fresh re-review 2026-06-08 大改 — debounce 刪 / claim relabel GATED / 4 條 AC-integrity / boot-race + unmapped + banner-獨立 + credential + clock seam 新增):
- **39 BLOCKING** = 11 Logic(rate-limit×3 [AC-16/17/18] + banner-expire×3 [AC-19/19b/20] + invariants×2 [AC-21a/b] + severity map×3 [AC-30/31/32])+ 25 Integration + 3 Static-CI(AC-35a/50/51)
- **10 GATED**:**G-LS-3 ← AC-06/07/08/22**(claim delivery mechanism 未釘 — qa B3,改 GATED);**G-LS-4 ← AC-04/05/37b/53**;**G-LS-8 ← AC-28**;**G-LS-9 ← AC-25** — mock-scoped / script-gated 先行
- **6 ADVISORY**(AC-43/44/45/46/48/49 — Manual/playtest)
- **1 EXTERNAL**(AC-47 iOS real-device — G-LS-6 連動)

### Coverage Map

| Source | ACs | Coverage |
|--------|-----|----------|
| Rules 1-15 | 每條 ≥1(Rule 14 = design decision / G-LS-7 doc edit,**唔由 AC-01 testable** — qa R9;Rule 13 → AC-12/47/49) | 15/15 ✓ |
| Formulas(2 active) | F1[rate-limit]→16/17/18;F2[banner-expire]→19/19b/20 | 2/2 ✓ boundary-exact(19b = exactly t=202.0) |
| HIGH ECs(7) | A1→22;A2→23;B1→28;B2→29;B3→28;**B9→52;E5→53**(C1 已降 LOW;E6 MED→EC-E6 sweep contract) | 7/7 ✓ |
| Cross-knob invariants | 1→21a;2→21b(原 invariant 1 debounce 已刪,3→2 條) | 2/2 ✓ pass+fail 兩路 |
| Fantasy Tests 1-4 | T1→37/48;T2→26/52/54(zero-silent-swallow 擴:真斷言 + unmapped + banner 獨立);T3→41;T4→39 | 4/4 ✓ |
| Gates | G-LS-3→06/07/08/22;G-LS-4→04/05/37b/53;G-LS-5→40;G-LS-6→47;G-LS-8→28;G-LS-9→25 | tracked |

## Open Questions / Cross-System Gates

### Cross-System Gates(G-LS-1..9)

| # | Gate | Resolution path | Owner |
|---|------|-----------------|-------|
| **G-LS-1** | ADR-0001 amendment:`LoginShellLayer`(62,PAUSABLE,capture enumeration → 0/10/50/60/61/62)+ `ErrorBannerLayer`(111,ALWAYS,>100 immune / <120 below loot modal)+ banner 禁第二 BackBufferCopy 注記 | #24 epic story(#22 G-CS-7 / #23 G-IU-2 先例) | technical-director |
| **G-LS-2** | ADR-0008 amendment:`LoginShellCoordinator` tail append(InventoryUICoordinator 之後;#28 仍最尾)— 零 #21/#22/#23 constraint | #24 epic story(同 G-LS-1 一齊) | technical-director |
| **G-LS-3** | **#2 `claim_session` async 簽名 + cancellation 語意 pin**(await-coroutine vs completion-signal — GDD 簽名返 Resource 但 HTTP async,#2 signal 列表冇 claim-completed signal;**blocking**:login form story 前必須釘實)。**新增 cancellation 約束(godot B2)**:#2 L184/L188 grep-verified「cancel 唔 wait `request_completed` + `RESULT_CANCELED` 同 silent drop 都 acceptable」→ SUSPENDED-cancel 時 `await claim_session()` 會掛死;必須二擇一:(a) `claim_session` 保證 resolve cancelled `SessionClaimResult`,或 (b) completion-signal + #24 race injected-clock timer。+ username charset(ASCII?)同 GymSys schema 確認 | #2 erratum / focused amendment | #2 owner / technical-director |
| **G-LS-4** | **#2 additive APIs ×2**:(a)`get_auth_block_reason() -> StringName`(`&"none"/&"update_required"/&"carve_out_misconfig"`)— P0-6/P0-7 prompt 嘅 pull-model 渠道(forbidden-signal 禁令下唯一合法路徑);(b)`request_immediate_poll()`(Rule 9 retry 掣 — #2 公開 surface 現時**冇** immediate-poll API,「fire immediate poll」全係 internal 行為;CD-GDD-ALIGN C1);**(c)`is_auth_required() -> bool`(boot-race pull-check — 致命:#2 AC-08 `_ready()` 同步 emit auth_required,#24 tail 必 miss → 黑屏;godot B1 / EC-E5 / AC-53)** | #2 erratum(additive,#23 G-IU-1 consumer-forward 先例) | #2 owner |
| **G-LS-5** | #22 `loadout_view_all_tap` 遷移:直 call #23 → `request_open(&"inventory")`(Q-IU1 已承諾嘅遷移);grep 晒 `_inventory_ui` / `loadout_view_all_tap` 全部 mention(orphan-cleanup 紀律) | #24 epic story | #24 epic / #22 |
| **G-LS-6** | **iOS Safari spike**:`DisplayServer.virtual_keyboard_show` web 行為 / keyboard→canvas resize reflow / IME(4.6 post-cutoff,全部要 verify)— epic 第一個 story,結果決定 LineEdit vs DOM overlay 路線 | #24 epic story 001(HIGH risk) | #24 epic |
| **G-LS-7** | FSM extraction closure:#22/#23 coordinator header fork notice 引到 Rule 14 裁決(唔 extract — login ≠ overlay lifecycle);兩個 header 加一行 closure 注記 | #24 epic story(doc edits;godot-specialist 覆核) | #24 epic |
| **G-LS-8** | **#3 additive API**:`get_pending_errors() -> Array`(boot-window error buffer — EC-B1/B3 嘅 pull-check;#3 push_error fallback 只係 console observable 唔滿足 zero-silent-swallow) | #3 erratum(additive) | #3 owner |
| **G-LS-9** | **上游 errata cluster + lint coverage(CD-GDD-ALIGN C2/A3)**:(a)#2 L120 lint scope erratum — `check_no_ui_subscribes_telemetry.sh` 原 spec 只掃 `src/ui/**`,唔 cover UI-class autoload coordinators(#20/#22/#23/#24 全部喺 `src/autoload/`)→ scope 擴展;(b)script 本身未 implement(#2 epic 未做)— #24 epic CI story 連創建一齊做,AC-25 GATED 直至生效;(c)#8 GDD L755 `streak_persistence_failed` 單參簽名 stale(shipped 係雙參 `(error_code, key)`)— #8 doc erratum | #2/#8 errata + #24 epic CI story(#23 story-018 errata-cluster 先例) | #24 epic |

### 上游 Open Questions 閉環紀錄(本 GDD 閉咗嘅)

| 上游 Q | 閉環 |
|---|---|
| #3 **Q-X12**(12 error codes UX) | Rule 6 — 4 semantic class(按 #3 outcome carve:2 ONGOING / 8 WIPE / 2 TRANSIENT + 3 sibling FEATURE_DEGRADED),data-driven map |
| #3 **Q-E1**(Private Mode UX) | Rule 6 — 跟 ADR-0003 detect-and-gate:banner + loot disable,同一條 banner,唔 refuse-to-start |
| #2 **Q-X10**(logout drain UX) | Rule 12 — CD path (a) optimistic + silent drain |
| #2 **Q-X4**(re-login UX 形態) | Rule 2 + States — 全屏 form(non-workout)/ banner-defer(mid-workout);唔用 modal-over-game |
| #22 **Q-CS1**(入口 affordance) | Rule 10 — **enabled/hidden 二態 + cross-fade**(debounce 刪除,對齊 #22 EC-30 全功能本地 view — fresh re-review 2026-06-08) |
| #23 **Q-IU1**(shell 入口/互斥) | Rule 11 — `request_open` 中央 arbiter |
| #23 FSM extraction 注記 | Rule 14 — 唔觸發 extraction(裁決 + closure G-LS-7) |

### #24 自己嘅 Open Questions

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| **Q-LS1** | DOM `<input>` overlay(password manager / Keychain / IME 完整支援)— v0.2 升級?定 G-LS-6 spike 結果差到 MVP 就要做? | ui-programmer + ux | OPEN — G-LS-6 spike 結果決定;若 LineEdit 喺 iOS Safari 連 keyboard 都彈唔出 → MVP 被迫行 DOM overlay(經 platform_detect seam) |
| **Q-LS2** | Mid-workout session 失效嘅 escalation ladder(成個 session 唔 re-login → IDLE 時加強提示?)+ Safari ITP 7d returning-player ritual(#2 Q-X8) | game-designer + #29 owner | OPEN — defer to #29 Mirror Moment GDD authoring(returning-player flow 一齊裁) |
| **Q-LS3** | Operator-facing carve-out misconfig prompt 嘅最終 copy + `acknowledge_carve_out_fix()` 觸發 UI(MVP:顯示 instruction text 就夠?定要 in-game 撳掣?) | #24 epic + operator(Frank) | OPEN — epic 時裁;傾向 instruction text only(operator 用 console 都得) |
