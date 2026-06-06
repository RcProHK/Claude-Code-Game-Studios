# UX Spec: Loot Drop Modal

> **Status**: ✅ APPROVED(/ux-review 2026-06-07 — 0 blocking / 3 advisory:header Platform Target 欄、numeric char limits、resolution list — G-LM-7/epic 時補)
> **Platform Target**: Web(primary)+ Desktop(secondary)· Touch primary(single-tap)+ KB/Mouse · 零 gamepad
> **Author**: frank + ux-designer(/ux-design,FULL AUTONOMOUS — 內容嚴格衍生自 APPROVED #21 GDD,零新設計決策)
> **Last Updated**: 2026-06-07
> **Journey Phase(s)**: unknown — 無 player journey map(見 Open Questions)
> **Template**: UX Spec
> **Source GDD**: `design/gdd/loot-drop-modal.md`(✅ APPROVED 2026-06-06 Pass 3)— 本 spec 係 per-screen 整合,設計決策以 GDD 為 ground truth;衝突時 GDD wins
> **Patterns**: P-05(loot-drop-modal — **stale,G-LM-7 更新對象**;本 spec + GDD 係現行 authoritative)· P-06(rarity-color-tier)· P-08(reduce-motion)

---

## Purpose & Player Need

玩家想做嘅嘢:「**見證並收藏我啱啱用身體賺返嚟嘅嘢**」。本 screen 將 #15 產生嘅每件 FULL_CEREMONY loot 兌現成「值得截圖」嘅 dopamine moment(Pillar 3 signature — MVP hypothesis「爆裝感覺值得做返第二日」成敗繫於佢)。冇佢,loot 只係 silent data row =「不知不覺發生」(Pillar 3 禁令)。

Fantasy anchor:「**一下閃光,將你成個 set 定格落一件裝備度**」(The Flashbulb)— tap 嘅意義係「影低佢」(撳快門),唔係「關 popup」。

---

## Player Context on Arrival

- **幾時**:GSM `LOOT_DROP` state — 只發生喺 natural pause(rest period / workout 完成 / boss 死後;mid-set 由 #15 Pending pool + GSM Rule 13 deferral 兜住,**永不打斷 set**)。
- **啱啱做完**:一個 set / 一場 boss fight — **攰住、流緊汗、單手攞機上嚟望**。
- **情緒狀態**:疲勞 + expectancy(知道有嘢爆)。設計假設:**唔閱讀,只 glance**;手汗;tap 精度低。
- **自願 vs 被送入**:被 GSM 送入(state-driven),但時機係 natural pause — 玩家本來就攞起部機。
- 三條 entry 情境:① live(啱啱爆)② boot force-reveal(隔咗一段時間返嚟,GSM 已喺 LOOT_DROP)③ catch-up(積落 ≥5 件)。

---

## Navigation Position

本 screen **唔喺 navigation hierarchy 入面** — 佢係 GSM state-driven 嘅 full-screen overlay(ModalLayer,CanvasLayer 120),唔可以由 menu 主動去,唔可以 re-open 已 dismiss 嘅 reveal。位置:`[gameplay] → (GSM → LOOT_DROP) → 本 modal → (loot_confirmed) → [gameplay]`。冇 alternate 玩家主動入口(inventory「未開封」tap entry = defer v0.2,GDD OQ-6)。

---

## Entry & Exit Points

### Entry

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Gameplay(#20 HUD 後面) | GSM `state_changed → LOOT_DROP`(唯一 trigger;`connect_for_initial_state` 兜 boot)且 queue 1-4 件 | 啱完成 set/boss;HUD 已 dim(入場 skew 係 feature:dim 先、burst 後 = 影相前調光) |
| Boot(force-reveal) | Boot 時 GSM 已喺 LOOT_DROP(sentinel delivery) | 隔咗一排返嚟;期望「攞返上次嘅嘢」 |
| Catch-up prompt | 同上 trigger 但 queue ≥ `CATCH_UP_THRESHOLD`(5) | 積落多件;可能趕時間 → 必須可 defer |

Empty-queue entry(rollback race)→ modal **唔開**,即 terminal emit(GDD Rule 13)。

### Exit

| Exit Destination | Trigger | Notes |
|---|---|---|
| Gameplay(GSM exit LOOT_DROP) | Terminal dismiss:最後一件 tap dismiss → S4 exit anim 完 → `modal_dismissed(terminal=true)` → #15 `loot_confirmed` → GSM | **#21 對 GSM zero-direct-call**;intra-queue dismiss(仲有件)GSM 唔郁 |
| Gameplay | Catch-up「稍後再拆」/ prompt defer | 已 commit 件保留;剩餘原封 Pending,下次以更新 N 重現 — **零懲罰,never-trap** |
| Gameplay(被動) | 外部 force-close(`rest_ended` 等) | **Pre-S3**:cancel + 留 pending → 下次 re-reveal(未撳快門 = 未影相);**Post-S3**:stash 收埋 ≤0.3s + auto-collect(已 banked)→ 下次 safe state 出「+N 已收藏」toast。冇 one-way loss — #15 Pending pool 保證零 item 損失 |

---

## Layout Specification

### Information Hierarchy(疲勞 glance 優先序 — GDD §C)

1. **Rarity**(「使唔使理?」— 三條時間線:burst 色 ~100ms pre-attentive → frame edge tint → badge)
2. **Item icon**(picture superiority — 攰人讀 icon 快過讀字)
3. **Item name**
4. **Source attribution**(Pillar 1 meaning layer — 第二 fixation)
5. **Breakdown bar**(RARE+ only,75/25 「汗水/運氣」— 張相嘅 EXIF)

單欄、單一 top→bottom 閱讀軸,冇 side-by-side。Rarity badge 貼 icon 上方同一 foveal cluster(~2° 一個 fixation 食晒 rarity+identity)。

### Layout Zones

- **Full-screen scrim**(tap surface — 全屏,唔要求瞄準;Fitts + 汗手):`ui_ink_bg #1A1D24` 92% opacity + 8% modal-local blur
- **Center stage(sacred reveal space)**:dirty pixel frame 相框(irregular silhouette,禁 clean rectangle)內 7 個 content slot — 永遠唔俾 toast/banner 侵佔
- **Bottom CTA**:「影低佢」label,visual ≥48px(純 affordance — 真 tap surface 係全屏)
- **Corner(catch-up only)**:「稍後再拆」獨立 Control,z-order 喺 scrim 之上 input 優先,≥48px
- **Top edge(parallel surface)**:banner stack(同 #20 共用,同屏最多一條,固定 top margin)— 唔屬 modal 本體
- **Screen edge corner(parallel surface)**:micro-ack toast(永不佔 center)

### Component Inventory(GDD UI Requirements §B 兌現)

| # | Component | Type | Interactive | Pattern |
|---|---|---|---|---|
| 1 | Rarity badge(色+形+text label 三重編碼) | badge | 否 | P-06 |
| 2 | Item icon 64×64 @2×(128×128 render)— 唯一 hero | image | 否 | — |
| 3 | Item name | H1 text | 否 | font 表(下) |
| 4 | Source attribution(四 variant:boss 擊殺/健身完成/mini-boss/**快勝**)+ provenance「180kg × 5 — Stamped」 | text | 否 | — |
| 5 | Breakdown bar(RARE+ only;`ui_amber_primary` vs `ui_ink_hi`;bar 內純數字 %,legend 行喺上方) | bar + labels | 否 | — |
| 6 | Dismiss CTA「影低佢」 | label(scrim 係真 surface) | **是** | — |
| 7 | SR announcement(S3 fire 一次,assertive) | aria | — | G-LM-6 |
| 8 | 「稍後再拆」(catch-up) | button | **是** | — |
| 9 | Contact-sheet grid(catch-up 收尾;hero cell 2×2;RARE+ 獨立 cell + label;「+N」只准 sub-RARE) | grid | tap close | P-06 list rule |
| 10 | micro-ack toast(icon+tint,無文字;「×N」aggregate) | toast | 否(non-interactive) | — |
| 11 | Disabled banner(Private Mode copy #15 own) | banner | 否 | #20 stack contract |

P-05 嘅 stat-delta ticker(P-03)slot **MVP 唔做**(GDD OQ-1 — #17 equip-result payload 未有 API)。

### ASCII Wireframe

**Full reveal modal(LEGENDARY 例)**:

```
┌─────────────────────────────────────┐
│ [banner stack — 最多一條,通常無]    │ ← top edge,parallel
│                                     │
│   ╔═══~~═══════════~~═══╗          │ ← dirty frame(irregular,
│   ║   ◆ LEGENDARY ◆     ║          │    per-tier ornament)
│   ║   ┌───────────┐     ║          │
│   ║   │           │     ║          │
│   ║   │ item icon │     ║  ← 128×128,唯一 hero
│   ║   │  128×128  │     ║          │
│   ║   └───────────┘     ║          │
│   ║   蝕刻者長劍          ║  ← name(Zpix 12px CJK)
│   ║   180kg × 5 — Stamped║  ← 數字行先
│   ║   來自 boss 擊殺      ║          │
│   ║   汗水 ▏運氣          ║  ← legend 行(bar 上方)
│   ║   ███████████▓▓▓▓▓   ║  ← breakdown bar
│   ║      75%      25%    ║  ← bar 內純數字
│   ╚═══~~═══════════~~═══╝          │
│                                     │
│           [ 影低佢 ]                │ ← CTA ≥48px(scrim 全屏可 tap)
│  (toast 角落區 — modal 開時 defer)  │
└─────────────────────────────────────┘
     ↑ 成個 viewport = scrim tap surface
```

**Catch-up contact-sheet grid**:

```
┌─────────────────────────────────────┐
│  ▤ session/date stamp(film-edge)   │
│  ┌────────┬────┬────┬────┐         │
│  │ HERO   │ R  │ R  │ R  │  ← hero = 最高 tier 2×2
│  │ (2×2)  ├────┼────┼────┤         │
│  │ LEGEND.│ U  │ U  │ C  │  ← 每 cell: icon + mini dirty
│  ├────┬───┴┬───┴┬───┴────┤    frame + rarity text label
│  │ C  │ C  │ C  │  +12   │  ← 「+N」只准 sub-RARE 溢出
│  └────┴────┴────┴────────┘         │
│            [ 收好 ]                 │
└─────────────────────────────────────┘
  入場:left-to-right exposure sweep ≤0.4s(禁 per-cell stagger)
```

**Catch-up prompt(center surface,唔用 top banner)**:

```
┌─────────────────────────────────────┐
│                            [稍後再拆]│ ← corner ≥48px,input 優先
│      ╔══════════════════╗          │
│      ║ 您有 7 個未拆 loot ║          │
│      ║   (tap 全屏拆晒)   ║          │
│      ╚══════════════════╝          │
└─────────────────────────────────────┘
```

### Font 指派(GDD Pass 1 修正 — CJK 斷裂收線)

| String 類 | Font | Size |
|---|---|---|
| CJK(name 中文/caption/attribution/「影低佢」/「稍後再拆」) | **Zpix** | **12px floor** |
| Latin/數字(「180kg × 5」/%/×N/tier 英文名) | m6x11 | 11px |
| 細註 | m5x7 | 7px(**latin/數字 only,CJK 禁**) |

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| HIDDEN | boot / terminal 出口 | modal pre-warmed `visible=false` |
| ENTRY(S0+S1) | reveal 開始 | burst frame-0 + scale 0.8→1.0 elastic-light;**S1 完成 frame 視覺 slots 1-6 全 final(禁 staggered pop-in)** |
| CEREMONY(S2) | entry 完 | per-tier ladder:S2a hold/focal-push → S2b freeze @ peak(D2 freeze-as-hold);tap = fast-complete |
| STEADY(S3) | ladder 完 / fast-complete | 靜態 dismissable;SR announce + banking 喺呢度 fire;tap = dismiss |
| EXITING(S4) | dismiss / post-S3 force-close | 快門三段:white flash(≥1 presented frame,~33ms cap)→ flat snapshot 1 frame → shrink/fade ≤200ms 飛向 stash anchor |
| CATCHUP_PROMPT | entry 且 queue ≥5 | center prompt;全屏 tap = reveal-all;corner = defer |
| CATCHUP_STREAM | reveal-all | sub-RARE 0.15s/件流水(luminance-stable beats,零 per-beat flash);零 tap |
| CATCHUP_GRID | ceremonies 完 | contact-sheet;tap close → terminal |
| Per-tier variant | rarity | T_block 200/350/650/950/1200ms;frame ornament escalation(COMMON bare → LEGENDARY 光柱+vignette);RARE+ 先有 breakdown bar + camera |
| Fast-victory variant | `BossPayload.outcome == INTERRUPTED_WITH_CREDIT`(G-LM-4 ⑧ marker) | attribution slot「快勝」copy;ceremony 不變 |
| motion_reduction(P-08) | toggle on | timestop=0 全 tier、零 focal call(→ fade-in vignette)、shake 0、particle ×0.5、S1 改 150ms fade、flash 收單 1 frame;hold/dismiss/queue 不變 |
| Disabled | `loot_disabled(reason)` | top banner(Private Mode copy);modal active 時等 dismiss 後先出 |
| Empty | LOOT_DROP entry 但 queue 空 | 乜都唔顯示,即 terminal emit |
| Error(數據 corrupt) | EC-M15 / EC-M6 | breakdown 矛盾 → 信 tier 隱藏 bar;dangling drop → skip,**永不 render placeholder** |

Loading state:**不存在** — content 由 local committed store(`get_drop()`)填充,S1 content-final 係 hard rule;backend sync 永不出 spinner(Pillar 2 唔輸出 infra 焦慮,EC-M10)。

---

## Interaction Map

Mapping for: **Touch(primary,single-tap)+ Keyboard/Mouse(desktop secondary)**。Gamepad: None。Tap 直接食 `gui_input`/`pressed`,**唔依賴 focus state**(Godot 4.6 dual-focus)。

| Action | Input | Stage policy | Feedback | Outcome |
|---|---|---|---|---|
| Tap scrim(任何位置) | touch tap / mouse click / `ui_accept` | **S0/S1:ignore**(t<D_entry 兜 tap-through);**S2:fast-complete**(content snap `SNAP_SEC`,freeze release/skip,sting 照播,**零 audio feedback — deliberate**);**S3:dismiss**(快門 flash + `sfx_loot_shutter_dismiss`);**S4:ignore**;debounce 0.25s 錨 S3 entry | per stage | S2→S3 / S3→S4→advance queue 或 terminal |
| Tap「稍後再拆」(catch-up) | touch / click / `ui_cancel` | 常駐;S2 行緊時 = 當前件 fast-complete→commit→收埋 | 收埋 anim | 剩餘留 Pending,terminal emit |
| Tap prompt(全屏) | touch / click / `ui_accept` | CATCHUP_PROMPT | stream 開始 | reveal-all |
| Tap grid | touch / click / `ui_accept` | CATCHUP_GRID | 收埋 | terminal emit |
| 周邊 gameplay 操作 | — | **唔存在** — modal is the input(GSM AC-11b);dismiss tap 行 #33 exempt handler | — | — |
| Toast | — | **non-interactive** | — | — |

玩家**唔可以**:mid-ceremony dismiss(只可 fast-complete — terminal frame 永遠被見)、re-open 已 dismiss reveal、skip audio sting(colorblind backup channel)。

---

## Events Fired

| Player Action / Moment | Event | Payload | Persistent state? |
|---|---|---|---|
| S3 到達(唔係 tap!) | `InventorySystem.receive_loot(drop)` | drop record | **是 — banking(INV-M3 唯一 commit point);architecture 已裁(GDD Rule 7)** |
| receive_loot 回 FAILED_ROLLBACK | `LootDropSystem.report_receive_failure(drop_id)` | drop_id | 是(#15 寫 recovery namespace)[G-LM-4] |
| Tap dismiss / post-S3 stash | `modal_dismissed(drop_id, terminal)` | drop_id + terminal flag | 是 — #15 dequeue;terminal → `loot_confirmed` → GSM [G-LM-4] |
| Pre-S3 force-close | **無 event(deliberate)** — cancel 唔 emit,件留 queue | — | 否 |
| S2 skip tap | `ceremony_skip_attempted(tier)` | tier | telemetry only |
| dismiss timing | `time_to_dismiss_ms`(EPIC+ <500ms 帶 `suspicious_dismiss`) | ms + flag | telemetry |
| pre-S3 force-close | `re_reveal_count(tier)` | tier | telemetry(CD N-2:EPIC+ >5% over 首 100 RARE+ → 重開 D1) |
| post-S3 stash | `stash_exit_count(tier)` | tier | telemetry |
| catch-up defer/截斷 | `catchup_abandoned(remaining)` / `catchup_truncated(remaining, reason)` | counts | telemetry |
| degrade paths | `loot_reveal.freeze_rejected` / `.focal_fallback` / `.dangling_drop` / `.breakdown_mismatch` / `.late_rollback` / `.unknown_tier` / `.receive_failed` | per GDD EC | telemetry |

---

## Transitions & Animations

- **Enter**:S0 burst(frame-0,tier color pre-attentive,localized radial @ avatar anchor)+ fanfare 同 frame → S1 scale 0.8→1.0 elastic-light overshoot ~1.03×(非 bounce),**同 S2 並行計時**(LEGENDARY 1650ms additive = 超 ceiling,overlap 係必要條件)。
- **Ceremony(D2 freeze-as-hold)**:camera 推鏡入 peak(S2a = #15 hold 數值,EPIC/LEG 經 `request_focal`)→ `focal_completed` → `ceremony_freeze`(S2b)— **世界連 camera 一齊定格 = 快門凍結嘅字面實現**;freeze expiry = S3,camera exit 喺背景行完。
- **Exit(快門)**:white flash(限 modal 局部,≥1 presented frame + ~33ms time cap)→ 內容凍結 flat snapshot 1 frame → shrink+fade ≤200ms 飛向**固定 stash anchor**(spatial memory);ease-in,**無 bounce**(§7.D Snap+Settle)。
- **Stash-exit(post-S3 force-close)**:collapse ≤0.2s + 總 ≤0.3s;tier 色短 trail(收納唔係慶祝);SUSPENDED-triggered → 跳 anim 即 emit。
- **Grid 入場**:left-to-right exposure sweep ≤0.4s + `sfx_loot_contactsheet_enter` whoosh;禁 per-cell stagger。
- **Toast**:entry 0.15s ease-out → plateau 1.2s → fade 0.15s;frameless 零 particle 零 idle motion。
- **Motion sickness**:photosensitivity 規則(≤3 flash/s、≤25% viewport、零 strobe loop、光柱 ≥0.3s rise)+ motion_reduction full matrix(P-08)— GDD Visual §C binding。

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Pending drops(FULL_CEREMONY only)| #15 `get_pending_drops()` / `get_drop(drop_id)` | Read | pull model;content source = committed store,**唔係 signal payload**(AC-32) |
| rarity_tier / item_type / item name | #15 drop record | Read | unknown tier → COMMON coercion(同 #17 同源) |
| workout_score / rng_roll / score | #15(ADR-0005) | Read | clamp-on-read → identity gate → F2 幾何 |
| Fast-victory marker | #15 record(G-LM-4 ⑧) | Read | 未 gate 落地前 variant 不可達 |
| Banking | #17 `receive_loot()` | **Write** | S3 唯一 commit point;#21 唯一 caller(owner-exempt lint);batch 經 G-LM-10 seam |
| Queue advance | #15 `modal_dismissed` emit | **Write** | drop_id dequeue;terminal → `loot_confirmed` |
| GSM state | #1 `state_changed` | Read | 唯一 trigger;**#21 永不 write GSM** |
| `reveal_anchor_pos` | #26 `avatar_anchor` group query | Read | fallback viewport center |
| 時間敏感 | 全部 ceremony timing | — | global reveal clock(delta 累積),非 wall-clock |
| Persistence | — | **零** | #21 stateless presentation(deferred-ack 計數 session-local) |

UI 唔 own 任何 game state — 全部 read + 兩個 contract-defined write(banking/dequeue),architecture 已由 GDD + gates 裁定。

---

## Accessibility

(Tier source:`design/accessibility-requirements.md`;GDD §E 全文 binding)

- **Color 永不係 sole indicator**:tier = 色 + badge shape + hold 時長 + sting character(P-06 三重編碼);silent-mode fallback chain = shape + label + hold(colorblind + silent 雙重 degrade 企得住)。
- **SR**:`announce_aria()`(G-LM-6)— S3 fire 一次 assertive `"[Rarity] loot: [Name],來自 [source]. [Workout X%, RNG Y%]"`;intra-queue short variant;catch-up 收尾單一 aggregate announce;banner `role=status` polite。
- **Keyboard-only**(desktop):`ui_accept` = scrim tap 等價(per-stage policy 同);`ui_cancel` = 稍後再拆 — 全部 interactive elements 可達。
- **Touch targets**:CTA/affordance ≥48px;真 tap surface = 全屏(零瞄準要求)。
- **Motion**:P-08 reduce-motion full matrix(見 States);photosensitivity WCAG 2.3.1 規則(Visual §C)。
- **無 auto-dismiss**:望得最慢嗰個唔會被「炒」;SR 讀 >5s 都安全;never-trap 由 system 層兜(force-close + Pending pool)。
- **文字**:CJK Zpix 12px floor;% claim 唔依賴 pixel discrimination(text label 必須)。

---

## Localization Considerations

- 全部 user-facing string 行 `tr()`(GDD §E)。
- **Layout-critical(HIGH PRIORITY)**:①「影低佢」CTA — 單行,≥48px button 內,40% expansion 後要 fit(德/法翻譯風險);② breakdown 「汗水/運氣」legend 行 — 自由寬度但單行;③ bar 內 % label 係純數字(刻意 — 免疫翻譯膨脹);④「+N」/「×N」badge — 數字 only ✓。
- **最長 strings**:caption 句(證人聲線,~20 CJK 字)— caption 區要容納 wrap 2 行;「您有 N 個未拆 loot」prompt。
- 數字格式:weight ×reps(「180kg × 5」)固定格式;百分比無 locale 小數。
- Tone 指引(present tense、零正向運氣歸因、數字行先)係 per-locale 翻譯 brief 事項 — flag 俾 localization engineer。

---

## Acceptance Criteria

(UX-level,QA 可獨立驗證;GDD 94 ACs 係 implementation 層 ground truth,呢度唔重複)

- [ ] **Perf**:reveal trigger → burst onset ≤100ms(6 frames@60fps,真 web build — GDD AC-9)
- [ ] **Navigation**:terminal dismiss 後 GSM 離開 LOOT_DROP 返 gameplay;catch-up defer 後可即返 gameplay 且下次 prompt 以正確 N 重現(GDD AC-27/29)
- [ ] **Empty/Error**:LOOT_DROP entry + 空 queue → 零 modal 閃現,GSM 唔 stuck;corrupt breakdown → bar 隱藏但 modal 照行(GDD AC-34/66)
- [ ] **Accessibility**:keyboard-only 可完成 dismiss + catch-up exit 全 flow;colorblind 模擬下五 tier 可分(shape/label/hold);SR 讀出完整 announcement 一次唔 double(GDD AC-37c/77)
- [ ] **Core purpose**:LEGENDARY terminal frame 截圖經 lead sign-off「值得 cap 圖」(Pillar 3 design test — GDD AC-80);S1 完成 frame 全部視覺 slots 已 final,錄影肉眼無 staggered pop-in(GDD AC-83)
- [ ] **疲勞輸入**:S2 tap-mash 三連擊必然落入 fast-complete→(debounce)→dismiss 序,零 silent swallow 超過 debounce 窗(GDD AC-15)
- [ ] **CJK render**:全部中文 copy 以 Zpix 12px 渲染,窄屏(W_bar<120)stacked variant 唔破版(GDD AC-84 CJK variant)

---

## Open Questions

| ID | Question | Owner |
|---|---|---|
| UX-OQ-1 | **Player journey map 未建立**(`design/player-journey.md` 唔存在)— 本 spec 嘅「Player Context on Arrival」基於 GDD/game-concept 假設;journey session 後要 back-check。Template: `.claude/docs/templates/player-journey.md` | producer |
| UX-OQ-2 | Stash anchor 固定 corner 位 — 要同 #20 layout zones + #22/#23 inventory 入口協調(GDD §E stash 視覺)| #22/#23 design 時 |
| UX-OQ-3 | GDD OQ-1(stat-delta ticker slot)/ OQ-3(grid PWA share button)— v0.2 嘅 modal 擴展位 | #22 / #27 |
| UX-OQ-4 | P-05 pattern 更新(G-LM-7)— 本 spec approved 後 ux-designer 執行(撤 5s auto-dismiss / ladder sync #15 / 加 two-stage tap + freeze-as-hold) | G-LM-7 story |

---

## Cross-Reference Check

- **GDD requirements**:UI Requirements §A-E 全部 11 components + font 表 + glance hierarchy + input policy 覆蓋 ✓(stat-delta ticker 明文 MVP-out per GDD OQ-1)
- **New patterns to add**:無新 pattern — P-05 係**更新**(G-LM-7 已 gate),two-stage tap / freeze-as-hold 屬 P-05 更新內容,唔開新 entry
- **Navigation mismatches**:gym-mode-hud.md — exit 序 pin(S4 完 → GSM → #20 un-dim)同 GDD Interactions #20 row 一致;banner stack 共用 contract 一致 ✓
- **Accessibility gaps**:無 — GDD §E 全文承接;G-LM-6(aria gateway)係 implementation gate 唔係 spec gap
- **Missing empty states**:無 — empty queue / corrupt data / dangling drop 全部有定義
