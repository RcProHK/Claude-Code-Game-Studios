# Login / GymSys Connection UI(Shell)

> **Status**: Designed(pending fresh `/design-review`)
> **Author**: Frank + specialists(full mode:CD framing + game-designer/ux-designer/ui-programmer Section C + systems-designer D/E + art-director V/A + qa-lead H)
> **Last Updated**: 2026-06-08
> **Creative Director Review(CD-GDD-ALIGN)**: CONCERNS → **REVISED 2026-06-08**(C1 phantom immediate-poll API → G-LS-4(b);C2 lint zero-coverage → G-LS-9 + AC-25 GATED;C3 severity map 按 #3 outcome 重 carve [3 class → 4 class:2 ONGOING / 8 WIPE / 2 TRANSIENT + 3 sibling FEATURE_DEGRADED];C4 ≤10% attribution 修正 [#20 Q-X9 → #2 Q-X9 L678] + Z5/Z6 region collision 列 /ux-design 必解;A1 #9 transitive note / A2 401 copy re-login family / A3 forbidden-signal 措辭 + #8 L755 簽名 erratum 全收)
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

1. **單 coordinator 擁有權** — `LoginShellCoordinator` autoload(ADR-0008 tail insertion — G-LS-2)own 晒 4 個職責同兩個 CanvasLayer:`LoginShellLayer`(layer **62**,PAUSABLE,加入 BackBufferCopy capture enumeration → 0/10/50/60/61/62)+ `ErrorBannerLayer`(layer **111**,ALWAYS,>100 shake/saturation-immune;<120 — #21 loot modal 屬 sacred moment 可冚 banner,banner 完咗自然再現)— G-LS-1 ADR-0001 amendment。`_ready` pre-warmed `visible = false`(#21/#22/#23 先例;idle 時零 draw-call 貢獻)。內部拆 4 個 sub-controller(LoginPanel / ConnectionStatus / BannerStack / ShellEntry)— 全部喺 coordinator 內,**唔開第二個 autoload**。

2. **Login 接管條件 + TELEMETRY-CLASS 紀律** — #2 `auth_required()` fire → shell 入 `LOGIN` state(全屏 login form)。觸發源:首次 boot 零 token / Rule 11 401 latch / P0-7 410 update-required / P0-6 carve-out misconfig / logout 完成。LOGIN 入場時經 **pull-model getter** `GymSysClient.get_auth_block_reason() -> StringName`(`&"none"` / `&"update_required"` / `&"carve_out_misconfig"` — #2 additive API,G-LS-4)分流:normal form / update-required prompt(「呢個版本舊咗,要更新先連到」+ 唔顯示 form)/ misconfig prompt(operator-facing,顯示 `acknowledge_carve_out_fix()` 指引)。**#24 全域只訂 4 個 signal**:`auth_required` / `drain_started` / `drain_completed`(#2)+ `state_changed`(GSM,經 `connect_for_initial_state`)— **11 個 forbidden signal**(10 TELEMETRY-CLASS + 1 TEST-SEAM `substate_changed` — #2 L120;CD-GDD-ALIGN A3 措辭對齊)永不訂閱。**注意(CD-GDD-ALIGN C2)**:lint script `check_no_ui_subscribes_telemetry.sh` 未 implement,且 #2 L120 spec scope 只 grep `src/ui/**` — #24 coordinator 喺 `src/autoload/` **唔會被掃** → G-LS-9 要求 scope erratum + script 創建,先有真 coverage。

3. **Claim flow** — submit → button disable + loading 態(防 double-submit)→ `await GymSysClient.claim_session(username, password)`(async 簽名 pin = G-LS-3 blocking gate — GDD 簽名返 `SessionClaimResult` 但 HTTP 係 async,await-coroutine vs completion-signal 要同 #2 釘實先做 login form story)→ **success**:token 由 #2 存(#24 永不掂 persistence — Rule 15),#2 開 polling,shell **等 GSM 離開 BOOTING 先轉場**(yield landing state — 唔假設 IDLE;reconciliation 可能直落 LOOT_DROP deferred reveal)→ form cross-fade 出;**failure**:inline error per Rule 4。await 期間玩家 background app(SUSPENDED)→ #2 cancel inflight(#2 State Matrix Cell 1),shell 收唔到 result → timeout fallback copy + re-enable。

4. **Claim error map(4 codes,永不 leak raw HTTP — #2 L310 contract)** — `invalid_credentials` → form 內 field-level inline「username 或者 password 唔啱,再試下?」(唔分邊欄錯 — security 慣例);`network_error` → inline「而家連唔到伺服器,睇下 WiFi?搞掂再撳一次。」+ retry 掣;`rate_limited` → submit disable + `retry_after` **live 倒數**(「等 {N} 秒再試」,倒數到 0 re-enable — 唔 silent disable);`server_error` → inline「伺服器嗰邊出咗少少問題,陣間再試下。」+ retry 掣。Copy register = 廣東話口語 witness 語氣(同 #20 silent-mode banner 一致),零責備零 jargon。

5. **Banner 系統 = anti-lie 收口** — #24 係唯一 UI consumer of:#3 `critical_save_failed(error_code, key)` + #8 `streak_persistence_failed(error_code, key)` + #11 `stat_critical_save_failed(stat_id)` + #12 `ability_unlock_save_failed(ability_id)`。**每個 handler 必須產生 visible state change**(zero silent-swallow — Player Fantasy falsifiable test #2 binding);分類行 Rule 6 severity map。

6. **Severity class(Q-X12 閉環;data-driven `error_severity_map.tres`)** — **4 個 semantic class,按 #3 嘅真實 outcome carve 推導**(CD-GDD-ALIGN C3 修正 2026-06-08:原 3-class 草案將 corrupt-wipe 事件標做「下次可能成功」係 anti-lie 自傷;#3 ground truth = corrupt path 8 codes 全部 wipe + re-init [persistence-layer.md Rule 9],QUOTA_EXHAUSTED 係 revert-no-wipe [L277]):

   | Class | #3 真實結局 | UX | 觸發 |
   |---|---|---|---|
   | **ONGOING**(環境持續不可用) | revert-no-wipe / 寫入持續失敗,環境唔變就唔會好返 | persistent banner,**唔可 dismiss**(問題仲存在唔畀眼不見為淨),直至環境恢復 / 重啟 | #3:`QUOTA_EXHAUSTED` `READ_ONLY_FILESYSTEM` |
   | **WIPE**(本機紀錄已重置 — 一次性已發生) | Rule 9 corrupt path → wipe + re-init(數據已經冇咗,唔係「下次再試」) | persistent banner,**可 acknowledge dismiss**(tap 確認已讀 — 事件已完結,誠實已交付);copy 誠實:「本機紀錄重置咗 — 會由 GymSys 補返;未同步嘅戰利品可能冇咗」(ADR-0003 backend-primary + unsynced-LootDrop client-wins caveat 係真) | #3:`INVALID_JSON` `EMPTY_FILE` `UNREGISTERED_PAYLOAD_TYPE` `FLUSH_FAILED` `MIGRATION_TIMEOUT` `MIGRATION_CHAIN_TOO_LONG` `SCHEMA_DOWNGRADE` `FILE_TOO_LARGE` |
   | **FEATURE_DEGRADED**(單一 feature 寫入失敗) | 上游 feature 入 FAILED/degraded 態(#8 sticky 直至重啟) | persistent banner,auto-clear on 該 feature next success(sticky 情況自然留到重啟 — 誠實) | #8 `streak_persistence_failed` / #11 `stat_critical_save_failed` / #12 `ability_unlock_save_failed` 全部 |
   | **TRANSIENT**(race / 暫態) | block-reject,retry 大機會成功 | toast,~5s auto-dismiss,唔留 banner | #3:`NOT_READY` `MIGRATION_IN_PROGRESS` |

   **視覺 weight 對應**(semantic 4 → visual 3,見 Visual/Audio):ONGOING + WIPE → 重(amber accent bar);FEATURE_DEGRADED → dim;TRANSIENT → toast。`QUOTA_EXHAUSTED` 喺 Private Mode 情境 = **ADR-0003 detect-and-gate 同一條 banner**(banner + loot disable — Q-E1 閉環跟 ADR-0003 已裁,唔係 refuse-to-start,唔開第二條 banner)。

7. **Banner stacking** — 單一 banner slot(`max_visible = 1`),顯示最高 severity;其餘 collapse 成「+N」counter(tap 展開 detail list)。Dedupe key = `(signal_source, error_code, key/id)` — 同 key 連 fire refresh 唔疊。Priority:DISCONNECTED status > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類(drain/reconnect 成功)。位置:**螢幕底部**,≤10% 螢幕高(peripheral class 數值沿用 **#2 Q-X9**(gymsys-backend-client.md L678)CD cascade 對 #20 spinner 嘅 binding[peripheral / ≤10% / 無 animation / 無 audio]— #24 採納同一 class 紀律)。**已知 region collision(CD-GDD-ALIGN C4)**:#20 UX spec **Z5 REST panel(bottom slide-up)+ Z6 silent-mode banner(bottom-center toast)**同 #24 bottom banner 真係會撞 — 確切 region 劃分係 `/ux-design` **必解項**(見 UI Requirements UX Flag)。

8. **Banner 靜態紀律** — #24 banner **零 animation / 零 audio / 零 pulse**;明文**唔援引** #20 silent-mode banner 嘅 alpha-pulse formula(#20 pulse 係邀請式「㩒一下開聲」;#24 係狀態誠實 — pulse = urgency gesture,壞時刻搶 attention 違反 Pillar 2)。Backdrop = opacity-only flat(**禁第二個 BackBufferCopy** — ADR-0001 #21 blur-CUT 裁決同源)。狀態唔純靠色:斷線 slash glyph / error ⚠ glyph / 完成 ✓ glyph。

9. **DISCONNECTED surface(誠實 + 唔築牆)** — GSM `DISCONNECTED`:(a)**workout 進行中**(由 WORKOUT_ACTIVE 系 state 跌入)→ bottom peripheral banner:「**連線斷咗 — 你嘅訓練 GymSys 照記住,連返之後自動補返。**」+ 細「再試一次」text 掣(tap → call #2 `request_immediate_poll()` — **G-LS-4 additive API**[#2 公開 surface 現時冇 immediate-poll API,「fire immediate poll」全部係 internal 行為 — CD-GDD-ALIGN C1 修正];**唔自己寫 backoff** — 重試節奏係 #2 職責;掣係 sense-of-agency affordance,功能上 #2 backoff 已 cover);(b)**non-workout** → shell `DISCONNECTED_SHELL` state:reconnect affordance + greyed 入口 + 斷線 status。**斷線 copy 誠實依據(synthesis 修正)**:GymSys 係 workout 數據嘅 system of record(玩家喺 GymSys 度 log set,獨立於 game),ADR-0002 differential cursor replay + #8 retro-credit drift gate + #21 catch-up contact-sheet 三件套保證 reconnect 後 game 補返反映 — 斷線**唔損數據,只 delay 反映**;所以「照記住會補返」係真話,「數據冇收」先係靠估嘅嚇人話。#33 EC-13:DISCONNECTED + pending tap → input permitted(reconnect affordance 唔被 attention budget gate)。

10. **入口 affordance(Q-CS1/Q-IU1 閉環)** — **greyed(visible-but-disabled)+ tap 出 inline reason**,唔用 hidden(Honest Door Test binding:狀態 tap 前已 visible)。入口由首次 render 就存在,enable/disable 切換用 cross-fade 唔用 pop-in/out(onset-transient 自己係 attention event — Q-CS1(a) 重審結論)。**Directional debounce(Q-CS1(b) flicker 閉環)**:變差方向(enabled→greyed)等 `ENTRY_DISABLE_DEBOUNCE_SEC`(default 2.5s)settle window 先郁;變好方向(greyed→enabled)**即時**。Debounce 只用於入口 — **banner 永不 debounce**(error 一 fire 即現身,誠實優先)。

11. **互斥 arbiter(中央化)** — shell 暴露 `request_open(screen_id: StringName)`:close 現 open screen → `call_deferred` open 目標。各 screen 嘅 `can_open()` double guard **保留**(defense-in-depth);shell **唔 subscribe** #22/#23 state(主動 call + `has_method` guard — #22 G-IU-4 glue 紀律同款);GSM force-close **唔經 shell**(各 screen 自己 `_on_gsm_state_changed` handle — shell 唔搶 GSM 嘅 job)。#22 `loadout_view_all_tap` 由直 call #23 遷移做 `request_open(&"inventory")`(G-LS-5 — Q-IU1 已承諾嘅遷移,非新 churn)。

12. **Logout(Q-X10 閉環 — CD path (a) optimistic)** — logout 擺 settings 角落(gear icon,唔同 #22/#23 主入口同級 — 破壞性動作收一層防誤撳)→ tap → **即時** optimistic「已登出」+ `clear_session_token(USER_EXPLICIT)` → #2 background drain。`drain_started(N)` → bottom banner:「已登出 — 緊要嘅嘢背景儲緊({N} 樣),可以安心熄 app。」;`drain_completed` → 「全部儲好喇 ✓」→ 2s auto-expire;drain 部分失敗(timeout_count > 0)→ persistent banner(WIPE-weight 視覺,acknowledge-dismiss — EC-B6)留到 re-login 後(誠實)。**永不**出「等緊 saving 唔好走」blocking modal(Mid-Set Logout Test binding)。玩家 drain 中途熄 app → 冇所謂(#2 tombstone + #3 persist,下次 boot 接返)。

13. **Login form 規格** — username + password(`LineEdit.secret = true`)+ show-password toggle(眼睛 icon,≥44px)+ submit。**無** remember-me checkbox(token persist 係 default 行為 — 30 日 TTL 內唔會再見 login,假選擇唔出);**無** account creation / 忘記密碼 / 註冊(GymSys 帳號管理喺 GymSys 本體 — anti-scope);username 限 ASCII(GymSys schema 確認 — G-LS-3 連帶釘實)。**誠實申報**:MVP canvas `LineEdit` **攞唔到 browser password manager / Keychain autofill**(canvas 對 DOM 隱形 — Web Export 結構限制);mitigation = 30 日 token 令 re-login 罕見;DOM `<input>` overlay 列 v0.2 候選(必須經 `platform_detect.gd` JavaScriptBridge seam — ADR-001 forbidden pattern)。**iOS Safari keyboard / canvas-resize / IME spike = epic 第一個 story**(G-LS-6;HIGH risk — `DisplayServer.virtual_keyboard_show` web 行為 4.6 要 verify;input font ≥16px 防 iOS auto-zoom)。

14. **FSM extraction 裁決(#23 rule-of-three closure)** — **#24 唔觸發 `ScreenLifecycleFsm` extraction**:login form 喺 BOOTING/AwaitingAuth 係**主畫面**(token 都未有,根本未入 IDLE)唔係 overlay-on-IDLE;banner/status 係常駐 surface 冇 OPENING/CLOSING;shell entry 係 stateless affordance host。三個 lifecycle 都唔 fit #22/#23 嘅五態 overlay FSM — 夾硬 extract = 錯誤抽象。#22/#23 coordinator header 嘅 fork notice 以本 rule 作 closure(G-LS-7 doc edits)。將來如有第三個**真 overlay**(e.g. 獨立 settings screen)先 extract。

15. **Zero persist / zero gameplay state** — #24 唔寫任何 persistence key(token 由 #2 寫;a11y settings 由 #22 unified panel 寫);唔 own 任何 gameplay 數值;typed credentials 只存在於 form 提交瞬間嘅內存(#2 State Matrix:client 都唔 persist credentials)。

### States and Transitions

Shell internal FSM(5 states — **唔係** GSM states;shell observe GSM + #2 signals 自己分流。Banner stack 係 **orthogonal overlay**,任何 state 都可疊現,由 Rule 6/7 severity 機制獨立控制):

| Shell State | 入場條件 | 顯示 | 出場 |
|---|---|---|---|
| `HIDDEN` | GSM ∈ {BOOTING(有 token), WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED} | 冇 shell surface(login layer visible=false;banner layer 照常 per Rule 7) | GSM → IDLE / DISCONNECTED;或 `auth_required` |
| `LOGIN` | #2 `auth_required()` fire(任何 shell state 都可入 — 最高優先) | 全屏 login form(LoginShellLayer visible);reason 分流 per Rule 2 | claim success + GSM 離開 BOOTING → cross-fade 去 landing state 對應 shell state |
| `SHELL_IDLE` | GSM `IDLE` 且有 token | 入口 affordance(#22/#23 兩張卡,enabled)+ connection status(綠)+ settings 角落;world view(avatar 由 #26 喺 GameLayer render — shell **唔** own avatar,avatar 經 world camera 自然置中) | GSM 離開 IDLE;或 `auth_required`;或 logout |
| `DISCONNECTED_SHELL` | GSM `DISCONNECTED`(non-workout 進入) | reconnect affordance + greyed 入口(directional debounce per Rule 10)+ 斷線 status | GSM reconnect → IDLE;或 `auth_required`(401 latch) |
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
| **#22 / #23** | arbiter | `request_open(&"character_screen"` / `&"inventory")`(Rule 11);greyed affordance 狀態讀 GSM(唔讀對方 state);#22 `loadout_view_all_tap` 遷移(G-LS-5) | #24 owns 互斥仲裁 + 入口 host;#22/#23 owns 各自 screen + `can_open()` double guard |
| **#33 Attention Budget** | carve-out | EC-13:DISCONNECTED + pending tap → `is_input_permitted` 唔 gate #24 reconnect/login surface(#33 已明文「嗰個係 #24 domain」) | #33 owns budget;#24 嘅 surface 喺 budget 之外 |
| **#20 Gym-Mode HUD** | spatial contract | banner 喺螢幕底部 ≤10%(數值沿用 #2 Q-X9 peripheral class — L678);**已知 collision:#20 Z5 REST panel(bottom slide-up)+ Z6 silent-mode banner(bottom-center)同 #24 bottom banner 撞 region** — `/ux-design` 必解(CD-GDD-ALIGN C4);#24 banner 唔援引 #20 pulse formula(Rule 8 — #20 F3 pulse 真存在 L226,係刻意唔用) | 各 own 各 region;確切劃分由 /ux-design layout spec 釘 |
| **#9 WST** | transitive(note) | #9 EC-24 期望「`wst.persist_failed` → downstream UI banner」— **transitive 兌現**:同一 write failure #3 自己 emit `critical_save_failed`(帶 key)→ #24 banner 照出;#24 **唔**直訂 #9 任何 signal(channel enumeration 完整性 note — CD-GDD-ALIGN A1) | #9 doc 對齊喺 #9 next revision |
| **#4 AudioManager** | none(silent) | **#24 零 audio cue**:banner 零 audio(Rule 8);login 成功/失敗 silent(#23 silent 紀律先例);唔開 #4 catalog gate | — |
| **#27 Onboarding** | host 關係 | #27 choreograph 首 5 分鐘流程(連接帳號→demo→首爆裝),#24 只提供 login surface 本身;first-run tutorial 內容唔入 #24 | #27 owns flow;#24 owns surface |
| **#5 / #6 / #26** | none | 零 particle / 零 shake / 零 avatar render(#26 喺 GameLayer 自己 render — SHELL_IDLE 唔 duplicate) | — |

### Interactions with Other Systems

[To be designed]

## Formulas

> **誠實申報**:#24 係 thin presentation shell,**零 gameplay 數值** — 本 section 唔發明唔存在嘅 math,只 formalize 三條 UI timing/display logic(systems-designer 諮詢 2026-06-08)。全部 timing 用 `Time.get_ticks_msec()` monotonic clock(唔跟系統時間 — wall-clock tamper 免疫,見 EC-D2),test seam 用 injected clock(#22/#23 `advance(delta_ms)` 模式)。

### Formula 1 — Directional Debounce Gate(入口 affordance,Rule 10)

```
entry_state(t) =
    current_entry_state    if direction == WORSE and t < t_signal + ENTRY_DISABLE_DEBOUNCE_SEC   # hold
    target_entry_state     otherwise                                                              # BETTER 即時 / WORSE settle 完
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| direction | d | enum | `{WORSE, BETTER}` | WORSE = enabled→greyed;BETTER = greyed→enabled |
| t_signal | t_s | float | [0, ∞) monotonic sec | 呢次方向改變嘅 timestamp;**每次 WORSE signal 重置**(flicker 期間永不 settle — EC-C1) |
| ENTRY_DISABLE_DEBOUNCE_SEC | G | float | [1.0, 5.0](knob,default 2.5) | WORSE 方向 settle window |
| entry_state | — | enum | `{ENABLED, GREYED}` | 本 frame rendered 狀態 |

**Output Range:** discrete 2-value;BETTER 方向 delay 恆等 0(誠實:好消息即時)。
**Example:** t=0 WORSE fire → 保持 ENABLED;t=1.2 仍 ENABLED;t=2.5 settle → GREYED;t=3.0 BETTER fire → **即時** ENABLED。

### Formula 2 — Rate-Limited Countdown(Rule 4)

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

**Output Range:** N clamp 下界 0(永不顯示負數);`retry_after = 0` → 即時 re-enable + **唔顯示**倒數 copy(EC-D1)。
**Example:** r=30, t_0=100:t=115 → N=15;t=129.5 → N=1;t=130 → N=0 re-enable。

### Formula 3 — Banner Auto-Expire(TRANSIENT + 通知類,Rules 6/12)

```
banner_visible(t) = (t - t_banner_start) < banner_ttl
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| t_banner_start | t_b | float | [0, ∞) monotonic sec | banner 出現 timestamp |
| banner_ttl | TTL | float | by class | TRANSIENT = `TRANSIENT_BANNER_TTL_SEC`(5.0);drain/reconnect 成功通知 = `DRAIN_SUCCESS_EXPIRE_SEC`(2.0);**ONGOING/WIPE/FEATURE_DEGRADED 唔用本 formula**(由 resolved / acknowledge / next-success trigger 消除,無限期 persistent — Rule 6) |

**Output Range:** boolean。
**Example:** drain ✓ banner @ t_b=200,TTL=2.0:t=201.5 visible;t=202.1 消失。

## Edge Cases

23 ECs,5 類(systems-designer 諮詢 2026-06-08)。Severity:6 HIGH / 10 MED / 7 LOW。

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

### C — DISCONNECTED / reconnect

- **EC-C1 [HIGH] — If DISCONNECTED↔IDLE 高速 toggle(網絡 blip,500ms 級)**:Formula 1 — 每次 WORSE signal 重置 `t_signal`,flicker 持續 < debounce window 期間入口一直 ENABLED(唔 flash grey);BETTER 方向仍即時。*Rationale*:Q-CS1(b) 閉環嘅 formalization。
- **EC-C2 [LOW] — If claim await 期間 GSM → SUSPENDED(FSM layer 視角)**:shell `_on_state_changed` 收 SUSPENDED → HIDDEN;claim result 冇返 → EC-A1 timeout path。兩個 EC 係同一事件兩個 layer,**零額外 mechanism**。
- **EC-C3 [MED] — If DISCONNECTED_SHELL 期間 `auth_required` fire(401 latch)**:LOGIN 係最高優先 interrupt → 即入 LOGIN。*Rationale*:States table 明文任何 shell state 可入 LOGIN。
- **EC-C4 [MED] — If mid-workout 401 latch 後 GSM 直落 DISCONNECTED(唔經 IDLE)**:#24 track `_pending_auth_required: bool` flag — Rule 9(a) banner-defer 期間 set;GSM 落 DISCONNECTED/IDLE 時 flag set → 即入 LOGIN。**LOGIN 入場唔以 IDLE 為 precondition**。*Rationale*:States table mid-workout defer 條款嘅 completion path。

### D — Timing

- **EC-D1 [MED] — If `retry_after == 0`(或 field absent)**:Formula 2 自然 handle — N=0 → 即時 re-enable,**唔顯示**「等 0 秒」copy。
- **EC-D2 [LOW] — If 玩家改系統時間(wall-clock tamper)**:Formulas 1-3 全部用 `Time.get_ticks_msec()` monotonic — 唔受影響。*Implementation requirement,非 behavior edge case。*

### E — Shell FSM

- **EC-E1 [LOW] — If GSM 喺 LOGIN cross-fade 途中直落 LOOT_DROP**:cross-fade 跑完(唔 abort mid-tween — hard-cut 嘅 onset transient 係 attention event,Rule 10 binding)→ fade 完 check GSM state → HIDDEN。*Rationale*:動畫 integrity > immediacy;GSM state continuously observable。
- **EC-E2 [MED] — If DRAINING 期間新 error signal fire**:BannerStack orthogonal — 新 banner 照 append(per Rule 6 class),priority 機制處理;drain 唔係 silent zone。
- **EC-E3 [MED] — If shell HIDDEN(e.g. WORKOUT_ACTIVE)期間 ONGOING/WIPE error fire**:`ErrorBannerLayer`(111 ALWAYS)獨立於 shell state — banner 照顯示喺 workout 之上。*Rationale*:Rule 1 兩 layer 分離;HIDDEN 只收 LoginShellLayer。
- **EC-E4 [LOW] — If `request_open()` 目標 screen `can_open()` 返 false**:shell 唔 force open;affordance 保持/回復 greyed + log warning(唔 silent)。*Rationale*:Rule 11 double guard respect,唔 bypass。

### Cross-reference

- Player Fantasy falsifiable tests 覆蓋:Test 1(Locker-Room WiFi)→ EC-C1 + Rule 9;Test 2(Silent Corruption)→ EC-B1/B2/B3 + Rule 5;Test 3(Mid-Set Logout)→ Rule 12 + EC-B6;Test 4(Honest Door)→ Rule 10 + EC-E4。
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

### Owned by #24(5 knobs + 1 data-driven map)

| Knob | Default | Safe Range | Source / Used By | Too high | Too low |
|------|---------|------------|------------------|----------|---------|
| `ENTRY_DISABLE_DEBOUNCE_SEC` | 2.5 | `[1.0, 5.0]` | Formula 1 / Rule 10 | > 5 → 真斷線後入口好耐先誠實反映(Honest Door 變鈍) | < 1 → blip flicker 重現(Q-CS1(b) 問題返晒嚟) |
| `SHELL_FADE_SEC` | 0.25 | `[0.1, 0.5]` | States 轉場 / EC-E1 | > 0.5 → 轉場遲滯感,login 成功後遮住 landing state | < 0.1 → 接近 hard-cut,onset transient 變 attention event |
| `TRANSIENT_BANNER_TTL_SEC` | 5.0 | `[3.0, 10.0]` | Formula 3 / Rule 6 | > 10 → TRANSIENT 變偽 persistent,稀釋 ONGOING/WIPE/FEATURE_DEGRADED 嘅 persistent 語意 | < 3 → 玩家眼角未及讀完 |
| `DRAIN_SUCCESS_EXPIRE_SEC` | 2.0 | `[1.0, 5.0]` | Formula 3 / Rule 12 | > 5 → 「儲好喇」霸住 banner slot | < 1 → 玩家未見到 closure 確認 |
| `BANNER_MAX_HEIGHT_PCT` | 0.10 | `[0.06, 0.10]`(**#24 自有 knob**;上限數值沿用 #2 Q-X9 L678 peripheral class ≤10% — 對 #20 spinner 嘅 CD cascade binding,#24 採納同一紀律,**唔係** #20 契約 — CD-GDD-ALIGN C4 attribution 修正) | Rule 7 | > 0.10 → 脫離 peripheral class,banner 變 attention surface | < 0.06 → CJK 12px + glyph 擺唔落 |
| `error_severity_map.tres` | Rule 6 表 | data-driven(新 error code 加入時 designer 改 .tres 唔改 code) | Rules 5/6 | — | — |

### Read-only(owned elsewhere)

| Knob | Owner | #24 用途 |
|------|-------|---------|
| `SessionClaimResult.retry_after` | #2 | Formula 2 倒數 |
| `SESSION_TOKEN_TTL_HOURS`(720) | #2 | re-login 頻率假設(Rule 13 誠實申報嘅依據) |
| GSM 9-state enum | #1 | shell FSM 分流 |
| #3 12 error codes enumeration | #3 | severity map keys(#3 係 source of truth — code 列表變更 = #3 GDD 改,#24 map 跟) |

### 唔可 runtime tune(compile-time / 紀律鎖死)

| Constant | Value | Why locked |
|----------|-------|------------|
| Banner 靜態紀律 | 零 animation / pulse / audio | Rule 8 — Pillar 2 binding;改 = urgency gesture 入侵 |
| Banner `max_visible` | 1 | Rule 7 — 疊 banner = 迫近 modal 體感 |
| Banner backdrop | opacity-only,禁第二 BackBufferCopy | ADR-0001 #21 blur-CUT 同源裁決 |
| 入口 affordance 模式 | greyed,永不 hidden | Honest Door Test binding |
| Debounce 方向性 | 只 delay 變差方向 | Formula 1 — 「好消息即時」係誠實紀律,變 knob 會畀人 tune 反咗 |
| TELEMETRY-CLASS 訂閱禁令 | 4-signal whitelist | #2 L120 CI lint |

### Cross-knob invariants

1. `SHELL_FADE_SEC < ENTRY_DISABLE_DEBOUNCE_SEC`(fade 必須完成於 settle window 內 — 否則 grey cross-fade 同 debounce 重置互相打架);at defaults:0.25 < 2.5 ✓
2. `DRAIN_SUCCESS_EXPIRE_SEC ≤ TRANSIENT_BANNER_TTL_SEC`(通知類唔可以長過 TRANSIENT — 語意一致);at defaults:2.0 ≤ 5.0 ✓
3. `BANNER_MAX_HEIGHT_PCT ≤ 0.10`(#20 契約 hard ceiling);boot assert(ADR-0006 C8 pattern)

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

### 入口卡 + greyed state

- 卡:`ui_ink_bg` frameless + 16×16 solid silhouette icon(amber modulate @ enabled)+ Zpix label + 1px shadow;tap target ≥48px;可借用 #22 `ui_card_item_bg` 9-slice
- Settings gear:corner、`ui_text_dim`、唔用 amber(logout 係破壞性動作 — amber 保留畀可賺取 action)
- **Greyed = alpha 55%(整卡)+ slash glyph 疊 icon** — 唔用 desaturate(desaturate 係 §4.E World Layer/MoodController 工具,UI chrome disabled 語言 = alpha,#22 offline banner / #17 greyed slots 同款);disabled tap → inline text strip(#22 lock nudge 同款 L2 motion)「連線返先撳得」
- 變差 cross-fade 0.25s @ settle 後;變好即時 cross-fade — 玩家感知:**恢復永遠比斷線反應快**

### Audio

**零 audio**。Banner 零 cue(Rule 8);login 成功/失敗 silent(#23 silent 紀律先例);唔開 #4 catalog gate。

### Asset 需求(8 sprites — /asset-spec 用)

`ui_icon_disconnected_slash_8`(8×8)/ `ui_icon_warning_8`(8×8,amber+dim modulate 雙用)/ `ui_icon_info_8`(8×8)/ `ui_icon_check_8`(8×8)/ `ui_icon_eye_toggle_16`(16×16)/ `ui_icon_settings_gear_16`(16×16)/ `ui_icon_char_entry_16`(16×16 人形)/ `ui_icon_bag_entry_16`(16×16 背包形)。其餘全部 code-drawn(banner backdrop / accent bar / form card)。

> 📌 **Asset Spec** — Visual/Audio requirements 已定義。Art bible approved 後行 `/asset-spec system:login-gymsys-connection-ui` 產出 per-asset spec。

## UI Requirements

(ux-designer 諮詢 2026-06-08;`/ux-design login-gymsys-connection-ui` 出 wireframe-level spec 先入 epic — UX Flag 見文末)

- **Login form**:username + password + show-password toggle + submit;**無** remember-me(token persist 係 default)/ 無註冊 / 無忘記密碼;全部 interactive target ≥44×44px;input font ≥16px;keyboard-only 可完成(tab 順序 username → password → toggle → submit)
- **錯誤顯示**:inline(form 內),廣東話口語 witness register;`rate_limited` live 倒數;error 區 ARIA live `assertive`;唔純靠色(⚠ glyph)
- **IDLE shell 佈局**:world avatar 自然置中(#26 render — 情感焦點);#22/#23 兩張入口卡並排(平等、大 target、icon + text label 雙 channel);settings gear corner(logout 收一層);connection status dot
- **Banner**:固定底部 ≤10%;單 slot + 「+N」;ONGOING 唔可 dismiss(問題未解決唔畀眼不見為淨)/ WIPE acknowledge-dismiss(一次性事件,確認已讀)/ FEATURE_DEGRADED auto-clear on success,TRANSIENT/通知 auto-expire;ARIA live `polite`(peripheral 唔打斷 SR 朗讀);零 flashing(WCAG;Rule 8 靜態紀律順帶滿足)
- **Drain banner**:non-interactive;text 狀態 + ✓ glyph(唔純 spinner — reduce-motion + SR)
- **Reconnect**:「再試一次」text 掣 ≥44px;狀態用 text(「連緊…」/「仲係連唔到」)唔純 spinner
- **誠實申報(玩家預期管理)**:MVP 無 browser password manager / Keychain autofill(canvas 結構限制);靠 30 日 token TTL 令 re-login 罕見;DOM overlay v0.2 候選

> 📌 **UX Flag — Login / GymSys Connection UI**:本系統有 UI requirements。Epic 前必行 `/ux-design login-gymsys-connection-ui`(重點:login form wireframe + banner anatomy/region 同 #20 non-overlap 釘實 + shell 入口佈局 + greyed/disabled 狀態 spec)。Stories 引用 `design/ux/login-gymsys-connection-ui.md`,唔直接引 GDD。

## Acceptance Criteria

(qa-lead 起草 2026-06-08;main session 修正 breakdown 算術。全部 timing test 用 injected clock `advance(delta_ms)` — GUT 唔 tick child `_process`;persistence-consumer test 喺 `add_child` **前**注入 mock — 真 autoload cache 跨 file 污染先例。)

### Coordinator / FSM(Integration,BLOCKING)

- **AC-01**: GIVEN `LoginShellCoordinator._ready()` 完成,WHEN 驗證 coordinator shape,THEN 持有 `LoginShellLayer`(layer 62,PAUSABLE)+ `ErrorBannerLayer`(layer 111,ALWAYS),兩個初始 `visible=false`;零第二 autoload(sub-controllers 全部 coordinator 內 — Rule 14 no-extraction shape 連帶驗證)。Source: Rules 1/14 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_coordinator.gd`
- **AC-02**: GIVEN 完整 claim success + logout cycle(MockPersistenceLayer 注入於 add_child 前),WHEN cycle 完成,THEN mock `write_calls == 0`(#24 零 persistence write;token 寫入只來自 MockGymSysClient)。Source: Rule 15 | Integration | BLOCKING | 同上
- **AC-03**: GIVEN shell 喺任意 state,WHEN mock emit `auth_required`,THEN 下一 frame 入 `LOGIN` + `LoginShellLayer.visible == true`。Source: Rule 2 / States | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_fsm.gd`
- **AC-24**: GIVEN shell 已喺 LOGIN + form 有已填文字,WHEN `auth_required` 再 fire,THEN 仍喺 LOGIN、已填文字**保留**、唔 double-render(EC-A3 idempotent)。Source: EC-A3 | Integration | BLOCKING | 同上
- **AC-27**: GIVEN `_ready()` 執行,WHEN spy GSM connection,THEN 用 `connect_for_initial_state` 模式(唔係 plain connect)— boot 即收 current state。Source: ADR-0006 C6 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_coordinator.gd`

### Claim flow(Integration,BLOCKING)

- **AC-06**: GIVEN form submit enabled,WHEN tap submit,THEN 即時 disable + loading;`claim_session_calls == 1`(防 double-submit)。Source: Rule 3 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_claim_flow.gd`
- **AC-07**: GIVEN claim success,WHEN mock GSM 仍喺 BOOTING,THEN shell 唔切換 state — 等 `state_changed`(yield landing state)。Source: Rule 3 | Integration | BLOCKING | 同上
- **AC-08**: GIVEN claim success + mock GSM emit `(BOOTING → LOOT_DROP)`,THEN shell 入 `HIDDEN` 唔入 SHELL_IDLE(EC-A5 deferred reveal path)。Source: Rule 3 / EC-A5 | Integration | BLOCKING | 同上
- **AC-22**: GIVEN claim await 掛起,WHEN mock GSM emit SUSPENDED + injected clock 超 timeout,THEN submit re-enable + copy 含「程序中途中斷」、**唔**含「登入失敗」。Source: EC-A1 | Integration | BLOCKING | `tests/unit/login_shell/test_claim_edge_cases.gd`

### Error map(Integration,BLOCKING)

- **AC-09**: GIVEN claim 返 `invalid_credentials`,THEN inline copy 含「username 或者 password 唔啱」+ submit re-enable + **零** raw HTTP 字串(「401」「HTTP」etc.)。Source: Rule 4 | Integration | BLOCKING | `tests/unit/login_shell/test_login_shell_error_map.gd`
- **AC-10**: GIVEN claim 返 `network_error`,THEN inline「而家連唔到」+ retry 掣 + 零 raw HTTP。Source: Rule 4 | Integration | BLOCKING | 同上
- **AC-11**: GIVEN claim 返 `server_error`,THEN inline「伺服器嗰邊出咗少少問題」+ retry + re-enable + 零 raw HTTP。Source: Rule 4 | Integration | BLOCKING | 同上
- **AC-23**: GIVEN session conflict 場景(另一 tab claim — #2 落 `server_error` bucket),THEN server_error copy,零 conflict-specific / raw HTTP 字串(EC-A2)。Source: EC-A2 / Rule 4 | Integration | BLOCKING | 同上
- **AC-12**: GIVEN form render,WHEN `find_children()` 檢查,THEN 存在 username/password(`secret==true`)/toggle/submit;**唔**存在 remember-me / 註冊 / 忘記密碼元素。Source: Rule 13 | Integration | BLOCKING | `tests/unit/login_shell/test_login_form_spec.gd`

### Formulas(Logic,BLOCKING — injected clock boundary-exact)

- **AC-13**: GIVEN ENABLED + `ENTRY_DISABLE_DEBOUNCE_SEC=2.5`,WHEN WORSE @ t=0 + advance 到 t=2.49,THEN `entry_state == ENABLED`(settle 未到)。Source: F1 / EC-C1 | Logic | BLOCKING | `tests/unit/login_shell/test_debounce_formula.gd`
- **AC-14**: GIVEN 同上,WHEN advance 到 t=2.50,THEN `GREYED`(boundary inclusive)。Source: F1 | Logic | BLOCKING | 同上
- **AC-15**: GIVEN WORSE @ t=0 + BETTER @ t=1.0,THEN ENABLED 即時(delay 0);再 WORSE @ t=1.2 → `t_signal` 重置(flicker 期間永不 settle — EC-C1)。Source: F1 / EC-C1 | Logic | BLOCKING | 同上
- **AC-16**: GIVEN `retry_after=30, t_start=100`,WHEN t=115,THEN `display_seconds == 15`。Source: F2 | Logic | BLOCKING | `tests/unit/login_shell/test_rate_limit_formula.gd`
- **AC-17**: GIVEN 同上,WHEN t=130,THEN `display_seconds == 0` + `submit_enabled == true` + 倒數 copy 消失。Source: F2 / EC-D1 | Logic | BLOCKING | 同上
- **AC-18**: GIVEN claim 返 `rate_limited` + `retry_after == 0`,THEN 即時 re-enable + **唔**顯示任何倒數 copy。Source: F2 / EC-D1 | Logic | BLOCKING | 同上
- **AC-19**: GIVEN drain ✓ banner @ t=200 + `DRAIN_SUCCESS_EXPIRE_SEC=2.0`,WHEN t=201.5 → visible;t=202.1 → 消失。Source: F3 / Rule 12 | Logic | BLOCKING | `tests/unit/login_shell/test_banner_expire_formula.gd`
- **AC-20**: GIVEN `NOT_READY` TRANSIENT banner + TTL 5.0,WHEN t 超 TTL → 消失;同場 ONGOING/WIPE/FEATURE_DEGRADED banner 不受 F3 影響(persistent)。Source: F3 / Rule 6 | Logic | BLOCKING | 同上
- **AC-21a/b/c**: GIVEN `_ready()`,THEN 三條 cross-knob invariants boot assert:(a) `SHELL_FADE_SEC < ENTRY_DISABLE_DEBOUNCE_SEC`;(b) `DRAIN_SUCCESS_EXPIRE_SEC ≤ TRANSIENT_BANNER_TTL_SEC`;(c) `BANNER_MAX_HEIGHT_PCT ≤ 0.10`;違反 → debug assert trip。Source: Cross-knob invariants 1-3 | Logic ×3 | BLOCKING | `tests/unit/login_shell/test_knob_invariants.gd`

### Banner 系統(BLOCKING)

- **AC-26**: GIVEN 4 個 upstream error signal 已 connect,WHEN 逐一 mock emit 每條,THEN 每次 emit 後 BannerStack 內容有可量度變化 — **零** silent-swallow path。Source: Rule 5 / Fantasy Test 2 | Integration | BLOCKING | `tests/unit/login_shell/test_zero_silent_swallow.gd`
- **AC-29**: GIVEN 空 stack,WHEN 同 frame emit FEATURE_DEGRADED(#8 sibling)+ ONGOING(`READ_ONLY_FILESYSTEM`),THEN 主 slot = ONGOING、FEATURE_DEGRADED 入「+N」— severity order 唔係 arrival order(EC-B2)。Source: Rule 7 / EC-B2 | Integration | BLOCKING | `tests/unit/login_shell/test_banner_stack.gd`
- **AC-30/31/32**: GIVEN `error_severity_map.tres` 載入,WHEN 逐 code 查詢,THEN(30)ONGOING 2 codes(`QUOTA_EXHAUSTED`/`READ_ONLY_FILESYSTEM`)→ `dismissable=false`;(31)WIPE 8 codes 全部 → `acknowledge_dismissable=true` + 誠實 wipe copy key,#8/#11/#12 sibling 全部 → `FEATURE_DEGRADED + auto_clear_on_success=true`;(32)TRANSIENT 2 codes → F3 TTL(Rule 6 表逐項,12+3 mappings 全 assert)。Source: Rule 6 | Logic ×3 | BLOCKING | `tests/unit/login_shell/test_severity_map.gd`
- **AC-33**: GIVEN ONGOING banner 喺主 slot,WHEN DISCONNECTED status 出現,THEN DISCONNECTED 佔主 slot、ONGOING 入「+N」;DISCONNECTED resolved → ONGOING 升返(EC-B4)。Source: Rule 7 | Integration | BLOCKING | 同上
- **AC-34**: GIVEN `(FLUSH_FAILED, "k1")` banner 存在,WHEN 同 key 再 fire,THEN entry count 唔變、timestamp 更新、「+N」唔虛高(EC-B5)。Source: Rule 7 | Integration | BLOCKING | 同上
- **AC-25 [GATED G-LS-9]**: GIVEN `tools/ci/check_no_ui_subscribes_telemetry.sh` 已創建 **且 scope 已含 UI-class autoload coordinators**(#2 L120 原 spec 只掃 `src/ui/**` — 唔 cover #24,直接照 spec implement = zero-coverage 假 green,CD-GDD-ALIGN C2),WHEN 行 lint,THEN exit 0;coordinator 只 connect 4-signal whitelist,11 個 forbidden signal 零 `connect(` 痕跡。Source: Rule 2 / G-LS-9 | Static-CI | GATED | CI step(epic CI story 連 script 創建一齊做)
- **AC-35**: GIVEN #24 全部 source files,WHEN grep banner code path,THEN 零 `create_tween`/pulse/`AudioStreamPlayer`/`play(` 出現(banner 靜態紀律 + login 零 audio)。Source: Rule 8 | Static-CI | BLOCKING | CI grep step(epic 新增)
- **AC-36**: GIVEN 兩個 #24 layer scene,WHEN `find_children("*","BackBufferCopy",true)`,THEN 空(禁第二 BackBufferCopy)。Source: Rule 8 / ADR-0001 | Integration | BLOCKING | `tests/unit/login_shell/test_layer_spec.gd`

### DISCONNECTED / 入口 / logout(Integration,BLOCKING)

- **AC-37**: GIVEN mock GSM `WORKOUT_ACTIVE → DISCONNECTED`,THEN shell **唔**入 DISCONNECTED_SHELL(留 HIDDEN);ErrorBannerLayer 顯示 peripheral banner 含「GymSys 照記住」copy + tappable「再試一次」;零全屏轉場。Source: Rule 9(a) / Fantasy Test 1 | Integration | BLOCKING | `tests/unit/login_shell/test_disconnected_surface.gd`
- **AC-38**: GIVEN `_pending_auth_required == true`(mid-workout defer),WHEN GSM → IDLE(或 DISCONNECTED — EC-C4),THEN 即入 LOGIN + flag 清零;LOGIN 入場唔以 IDLE 為 precondition。Source: EC-C4 / Rule 9 | Integration | BLOCKING | 同上
- **AC-39**: GIVEN DISCONNECTED_SHELL,WHEN render 入口,THEN #22/#23 卡 `visible == true` + `modulate.a < 1.0`(greyed)+ tap 出 inline reason — **零** hidden 入口(Honest Door)。Source: Rule 10 | Integration | BLOCKING | `tests/unit/login_shell/test_entry_affordance.gd`
- **AC-40**: GIVEN #22 open,WHEN `request_open(&"inventory")`,THEN #22 close(deferred)→ #23 open;`can_open()` 被查詢(double guard 唔 bypass);false → 唔 force open + log warning(EC-E4)。Source: Rule 11 | Integration | BLOCKING | `tests/unit/login_shell/test_shell_arbiter.gd`
- **AC-41**: GIVEN SHELL_IDLE,WHEN logout tap,THEN `clear_session_token(USER_EXPLICIT)` 即時 call + 「已登出」banner(count=N)+ 入 DRAINING + **零** blocking modal(Fantasy Test 3)。Source: Rule 12 | Integration | BLOCKING | `tests/unit/login_shell/test_logout_drain.gd`
- **AC-42**: GIVEN DRAINING,WHEN `drain_completed(5, 2)`,THEN drain banner **替換**做 persistent banner 含「2 樣嘢今次冇儲到」(acknowledge-dismiss,WIPE-weight 視覺 — EC-B6,永不 silent)。Source: Rule 12 / EC-B6 | Integration | BLOCKING | 同上

### GATED(G-LS-4 / G-LS-8 — mock-scoped 先行,真接線 story 另開)

- **AC-04 [GATED G-LS-4]**: GIVEN LOGIN 入場,WHEN mock `get_auth_block_reason()` 返 `&"update_required"`,THEN 顯示 update prompt、唔顯示 form。Source: Rule 2 | Integration | `tests/unit/login_shell/test_login_shell_block_reason.gd`
- **AC-05 [GATED G-LS-4]**: 同上 `&"carve_out_misconfig"` → operator prompt + `acknowledge_carve_out_fix()` 指引。Source: Rule 2 | Integration | 同上
- **AC-28 [GATED G-LS-8]**: GIVEN mock `get_pending_errors()` 返 `["QUOTA_EXHAUSTED"]`(add_child 前注入),WHEN `_ready()` 完成,THEN BannerStack 已有 ONGOING banner(`dismissable=false`)— boot-window gap 由 pull-check cover(EC-B1/B3)。Source: EC-B1 | Integration | `tests/unit/login_shell/test_boot_window_pull_check.gd`

### ADVISORY / EXTERNAL(Manual — `production/qa/evidence/`)

- **AC-43 [ADVISORY]**: login form 截圖 sign-off:`ui_ink_bg` 全屏底 / submit 唯一 amber / error ⚠ 零 red / toggle ≥44px。`ac43-login-form-visual.png`
- **AC-44 [ADVISORY]**: banner 視覺截圖:重 weight(ONGOING/WIPE)amber bar / FEATURE_DEGRADED dim / TRANSIENT @40%;squint-test 可區分;零 pulse/flashing。`ac44-banner-visual.png`
- **AC-45 [ADVISORY]**: greyed 入口截圖:alpha 55% + slash glyph + tap inline reason + 0.25s cross-fade smooth。`ac45-entry-greyed.png`
- **AC-46 [ADVISORY]**: drain banner walkthrough:text + ✓ glyph(唔純 spinner)/ non-interactive / 底部 ≤10% / 零 modal。`ac46-drain-banner.md`
- **AC-47 [EXTERNAL]**: iOS Safari real-device:keyboard 唔遮 form(或 scroll 補救)/ font ≥16px 零 auto-zoom / submit 可達 / tab 順序正確(G-LS-6 spike 連動)。`ac47-ios-keyboard.md`
- **AC-48 [ADVISORY]**: Locker-Room WiFi Test playtest:mid-set 斷線 30s 自動恢復全程零 tap 零 modal,進度完整。`ac48-locker-room-wifi-test.md`
- **AC-49 [ADVISORY]**: SHELL_IDLE 佈局 walkthrough:兩卡並排 icon+label / gear corner / status dot / avatar 由 #26 render(shell 唔 own)/ logout 收一層。`ac49-shell-idle-layout.png`

### Total count + breakdown

**51 ACs total**(AC-01..49,其中 AC-21 = a/b/c 三條;CD-GDD-ALIGN C2 後 AC-25 轉 GATED):
- **40 BLOCKING** = 14 Logic(F1×3 + F2×3 + F3×2 + invariants×3 + severity map×3)+ 25 Integration + 1 Static-CI(AC-35)
- **4 GATED**(AC-04/05 ← G-LS-4;AC-28 ← G-LS-8;AC-25 ← G-LS-9)— mock-scoped / script-gated 先行
- **6 ADVISORY**(AC-43/44/45/46/48/49 — Manual/playtest)
- **1 EXTERNAL**(AC-47 iOS real-device — G-LS-6 連動)

### Coverage Map

| Source | ACs | Coverage |
|--------|-----|----------|
| Rules 1-15 | 每條 ≥1(Rule 14 由 AC-01 shape 驗證;Rule 13 → AC-12/47/49) | 15/15 ✓ |
| Formulas 1-3 | F1→13/14/15;F2→16/17/18;F3→19/20 | 3/3 ✓ boundary-exact |
| HIGH ECs(6) | A1→22;A2→23;B1→28;B2→29;B3→28;C1→13/15 | 6/6 ✓ |
| Cross-knob invariants | 1→21a;2→21b;3→21c | 3/3 ✓ |
| Fantasy Tests 1-4 | T1→37/48;T2→26;T3→41;T4→39 | 4/4 ✓ |
| Gates | G-LS-4→04/05;G-LS-6→47;G-LS-8→28;G-LS-9→25;G-LS-5→40(arbiter 面) | tracked |

## Open Questions / Cross-System Gates

### Cross-System Gates(G-LS-1..8)

| # | Gate | Resolution path | Owner |
|---|------|-----------------|-------|
| **G-LS-1** | ADR-0001 amendment:`LoginShellLayer`(62,PAUSABLE,capture enumeration → 0/10/50/60/61/62)+ `ErrorBannerLayer`(111,ALWAYS,>100 immune / <120 below loot modal)+ banner 禁第二 BackBufferCopy 注記 | #24 epic story(#22 G-CS-7 / #23 G-IU-2 先例) | technical-director |
| **G-LS-2** | ADR-0008 amendment:`LoginShellCoordinator` tail append(InventoryUICoordinator 之後;#28 仍最尾)— 零 #21/#22/#23 constraint | #24 epic story(同 G-LS-1 一齊) | technical-director |
| **G-LS-3** | **#2 `claim_session` async 簽名 pin**(await-coroutine vs completion-signal — GDD 簽名返 Resource 但 HTTP async,#2 signal 列表冇 claim-completed signal;**blocking**:login form story 前必須釘實)+ username charset(ASCII?)同 GymSys schema 確認 | #2 erratum / focused amendment | #2 owner / technical-director |
| **G-LS-4** | **#2 additive APIs ×2**:(a)`get_auth_block_reason() -> StringName`(`&"none"/&"update_required"/&"carve_out_misconfig"`)— P0-6/P0-7 prompt 嘅 pull-model 渠道(forbidden-signal 禁令下唯一合法路徑);(b)`request_immediate_poll()`(Rule 9 retry 掣 — #2 公開 surface 現時**冇** immediate-poll API,「fire immediate poll」全係 internal 行為;CD-GDD-ALIGN C1) | #2 erratum(additive,#23 G-IU-1 consumer-forward 先例) | #2 owner |
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
| #22 **Q-CS1**(入口 affordance) | Rule 10 — greyed + cross-fade + directional debounce |
| #23 **Q-IU1**(shell 入口/互斥) | Rule 11 — `request_open` 中央 arbiter |
| #23 FSM extraction 注記 | Rule 14 — 唔觸發 extraction(裁決 + closure G-LS-7) |

### #24 自己嘅 Open Questions

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| **Q-LS1** | DOM `<input>` overlay(password manager / Keychain / IME 完整支援)— v0.2 升級?定 G-LS-6 spike 結果差到 MVP 就要做? | ui-programmer + ux | OPEN — G-LS-6 spike 結果決定;若 LineEdit 喺 iOS Safari 連 keyboard 都彈唔出 → MVP 被迫行 DOM overlay(經 platform_detect seam) |
| **Q-LS2** | Mid-workout session 失效嘅 escalation ladder(成個 session 唔 re-login → IDLE 時加強提示?)+ Safari ITP 7d returning-player ritual(#2 Q-X8) | game-designer + #29 owner | OPEN — defer to #29 Mirror Moment GDD authoring(returning-player flow 一齊裁) |
| **Q-LS3** | Operator-facing carve-out misconfig prompt 嘅最終 copy + `acknowledge_carve_out_fix()` 觸發 UI(MVP:顯示 instruction text 就夠?定要 in-game 撳掣?) | #24 epic + operator(Frank) | OPEN — epic 時裁;傾向 instruction text only(operator 用 console 都得) |
