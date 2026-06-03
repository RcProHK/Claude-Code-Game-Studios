# Audio Manager (#4) — Review Log

## Review — 2026-06-01 — Verdict: NEEDS REVISION (revised same-session)
Scope signal: L
Specialists: audio-director, game-designer, systems-designer, qa-lead, godot-specialist, performance-analyst, creative-director (synthesis)
Blocking items: 6 | Recommended: 9
Prior verdict resolved: First full review (prior was lean author pass, no specialists)

### Summary (creative-director synthesis)
GDD 結構完整（8/8 sections），audio direction 忠於 Player Fantasy「The Audible Consequence」+ Pillar 3，但有兩個 fantasy 缺口 + formula 邊界 + catalog freeze 未做。三大 specialist convergence：(1) **pre-unlock feedback 丟失** — 4 domain 夾擊，LOCKED 期間 `play_sfx` drop 食咗玩家首組 squat 嘅 hit/streak SFX，破壞「每個動作有聲音回應」承諾；(2) **stinger bus + ducking 自我抵消** — audio + systems 夾擊 Pillar 3 唯一容許爆嘅 peak；(3) **formula degeneracy** — systems + godot 獨立驗到 F1 除零 + F2 `linear_to_db(0)=-inf` 污染插值。Verdict NEEDS REVISION（非 MAJOR）— 結構 sound，缺口可逐項修補。

### Disagreement adjudication
Q3 (AudioContext unlock) 非真 disagreement：performance-analyst 標 BLOCKING gate，但 godot-specialist 權威確認 Godot 4.6 Web Export audio driver 引擎層喺首 user input 自動 resume suspended AudioContext，無需 JSBridge → ADR-0001 衝突消解。CD 裁決 godot 已 RESOLVE，降為真機 Safari 驗證 ADVISORY。

### Blocking items (6) — all resolved inline (autonomous mode)
1. [game-designer] Pre-unlock feedback 丟失 → Rule 5 LOCKED-window 取捨 + #20 silent-mode banner contract + LOCKED state row + EC note + AC-06b + UI Requirements banner
2. [audio-director] Stinger bus 自我抵消 → Rule 7(a) 所有 stinger 一律 SFX bus + AC-09b
3. [systems-designer] F1 fade_sec=0 除零 → Formula 1 instant-swap + clamp(p,0,1) + AC-21
4. [audio-director] SFX catalog 不完整 → Visual/Audio event_id freeze v0 表（13 類 + priority field）
5. [godot-specialist] CI lint 誤殺自己 → Rule 1 audio_manager.gd self-exempt
6. [qa-lead] 3 缺失 Logic AC → AC-18 (mid-crossfade latest-wins) / AC-19 (multi pre-unlock) / AC-20 (corrupt volume fallback)

### Recommended items (9) — all resolved inline
1. BGM 30-90min 疲勞 → BGM_MIN_LOOP_SEC=90 + focus_low multi-variant rotation (stem ramp → Q-A1 post-MVP)
2. Boss theme transition → Rule 6 per-state fade override + BOSS_THEME_FADE_SEC=0.25
3. Loot duck release → Rule 7(b) + F3 + AC-09: release 由 SFX finished signal driven
4. Tween API → Formula 區 tween_method note
5. F2 -inf → maxf(s, 0.0001) 保護
6. F2/F3 邊界 → NaN guard + MAX_BUS_DB 常數引用 + duck target max(..., MUTE_FLOOR_DB)
7. ducking 競態 → Rule 7(c) 單一 lerp-toward-target + MAX_BGM_BUNDLE_MB knob
8. Recommended ACs → AC-14b + AC-22/23/24
9. Stale Q5 + Q3/Q4 → Open Questions RESOLVED；Q1 reword「mixing CPU」

### Dependency graph note
#25 Combat Visual Feedback 列為 dependency 但無 GDD 檔案 — #25 未到 design order，屬可接受 forward reference。其餘 dependencies（#1/#3/#2/#5/#6/#8/#15）GDD 全部存在。

### Next
Awaiting fresh-session full re-review (recommended /clear first — this session used ~60% context).

---

## Review — 2026-06-01 (Pass 2, fresh-session full re-review) — Verdict: NEEDS REVISION (revised same-session, autonomous mode)
Scope signal: L
Specialists: audio-director, game-designer, systems-designer, qa-lead, godot-specialist, performance-analyst, creative-director (synthesis)
Blocking items: 8 | Recommended: 8
Prior verdict resolved: Pass 1 (6 BLOCKING + 9 RECOMMENDED) — confirmed held, no regression

### Summary (creative-director synthesis)
Pass 1 fix 守得住,架構 sound → NEEDS REVISION 非 MAJOR。Pass 2 撞出更深一層(runtime Tween 生命週期 / Godot 4.6 `finished` 語意 / voice-steal priority)。三大收斂:(A) **voice-steal × ducking × P3** — Godot 4.6 steal 唔 emit `finished` → permanent duck;steal-oldest 偷 high fanfare → 殺 P3(godot #5 + perf R-b + audio STEREO 匯流);(B) **`_process` ducking** — frame-rate-dependent + idle 浪費(godot #4 = perf B1,同一 fix 兩面:單一 retained tween + idle gate);(C) **ducking de-escalation 語意矛盾** — Rule 7c dynamic-max vs EC/AC hold-peak,AC-15 non-deterministic(systems + qa);(D) **LOCKED+SUSPENDED undefined arc** → 永久靜音 hole(game-designer + qa);(E) **AC 不可 headless 測**(qa B1-B6)。冇真 disagreement(godot vs perf 係同一 fix 互補)。

### Blocking items (8) — all resolved inline (autonomous mode)
1. [godot+perf] Voice-steal refcount 漏 + priority-aware → Rule 3 priority-aware steal + steal 路徑 fire release callback;EC + AC-03b/09c
2. [godot+perf] `_process` ducking → Rule 7(c) 單一 retained `tween_method` Tween + idle gate(refcount==0 → kill+set_process(false))
3. [systems] Ducking de-escalation → Rule 7(c) recompute-on-release + EC-153 + AC-15 改寫(分級 step,refcount→0 先回 base)
4. [game-designer] LOCKED+SUSPENDED → `_audio_unlocked` 改正交 flag(非 state) + States 雙軸 + EC + AC-14c
5. [audio-director] Mono 殺 P3 fanfare → catalog `channels` field;`loot_fanfare_*`/`boss_*` STEREO 例外
6. [godot] CI lint over-ban + 豁免 → Rule 1 full-path EXEMPT_FILES array + `AudioStreamPlayer[^\n]*\.bus\s*=` anchor;AC-01
7. [godot] Retained crossfade Tween kill → Rule 4 kill prior tween before new + EC + AC-18 state-machine 斷言
8. [qa] AC B1-B6 不可測 → AC-03/09/09b/18/19/20/24 改 assert readable property/state-machine/純函數;新 AC-25 priority dispatch + AC-26 unlock confirm

### Recommended items (8) — all resolved inline
1. [game-designer] `audio_unlock_confirm` one-shot(首 real action 有聲)→ Rule 5 + catalog + AC-26
2. [game-designer] streak duck −3→−5dB(JND 太淺)→ knob + Q9 noisy-gym playtest
3. [audio-director] `SHALLOW_RELEASE_SEC=0.15`(短 stinger pumping)→ Rule 7b + knob
4. [audio-director] FOCUS_LOW_VARIANT_COUNT 2→3 + non-immediate-repeat
5. [audio-director] ability_cast 3 sub-id freeze(strike/control/mobility,P4)
6. [systems] Formula 2 +6dB unreachable → 註明需 separate gain mapping,MVP 鎖 0
7. [game-designer] unlock 重 query GSM current(防 stale boss_theme churn)
8. [perf] bundle CI gate + cross-knob 互鎖警告(VARIANT×LOOP×MAX_BGM_BUNDLE_MB)

### Nice-to-Have (resolved)
刪重複 MAX_BUS_DB row;BGM_MIN_LOOP_SEC 標 authoring guideline + boot push_warning;set_complete/streak_chime 時序 co-design flag。

### Advisory (tracked, not blocking)
Q7 真機 Safari AudioContext 驗證;Q8 asset-spec craft constraint;Q9 streak duck gym playtest;PlatformDetect 引用「after PlatformDetect」非絕對 pos。

### Next
Awaiting fresh-session full re-review (recommended /clear first — this session used high context across 2 passes + 12 specialist spawns).

---

## Review — 2026-06-01 (Pass 3, fresh-session full re-review) — Verdict: NEEDS REVISION (revised same-session, autonomous mode)
Scope signal: M
Specialists: audio-director, game-designer, systems-designer, qa-lead, godot-specialist, performance-analyst, creative-director (synthesis)
Blocking items: 10 | Recommended: 14
Prior verdict resolved: Pass 2 (8 BLOCKING + 8 RECOMMENDED) — confirmed held, no regression

### Summary (creative-director synthesis)
架構 sound，Pass 1/2 fix 守得住。Pass 3 暴露兩類問題：(A) **Pass 2 propagation miss**——`STREAK_CHIME_DUCK_OFFSET_DB −3→−5` 更新漏咗 Rule 7c + EC 兩個 normative 段落（三處 `streak(−3)/−9`），加上 de-escalation「dynamic max」sign convention 自相矛盾（min vs max，offset 係負數）；(B) **GDD 過度具體嘅 engine code snippet 引入 implementer trap**——`bind()` arg 順序反轉令 ducking 靜默失效，`tween_property(volume_db)` 係 linear dB 非 equal-power 違反 Formula 1。附加：unlock window gym contract gap（backend event 可早過 tap）、double-pause 無去重、AC testability（steal seam、disjunction、wall-clock、缺 warning AC）。所有 10 個 blocking 均 localized fix，零設計 re-litigation。

### Blocking items (10) — all resolved inline (autonomous mode)
1. [godot-specialist] `tween_method bind()` arg 反轉 → ducking 靜默失效 + phantom-pass → lambda closure
2. [godot-specialist] crossfade `tween_property(volume_db)` linear dB ≠ equal-power → tween_method p-space + `_crossfade_progress` source-of-truth
3. [game-designer+systems-designer] streak duck stale 三處（Rule 7c + EC `−3/−9` → `−5/−11`）+ EC + Rule 7c 已修
4. [systems-designer] de-escalation「dynamic max」sign convention 矛盾（min vs max）+ Formula 3 補 multi-duck variable table
5. [game-designer] unlock contract: gym backend event 可早過 tap → #20 banner soft-gate contract clause
6. [godot-specialist] double-pause/resume 無去重 → `_suspend_sources` bitmask last-exit
7. [qa-lead] AC-03 無 steal-order seam → 補 assigned_sequence + pool accessor 要求
8. [qa-lead] AC-09「RELEASE_SEC 內」wall-clock flaky → 改 mock-emit 驗法
9. [qa-lead] AC-17 misclassified smoke/perf → Logic BLOCKING + AC-19 拆 19a/19b 解 disjunction phantom coverage
10. [qa-lead] 補 AC-27 BGM_MIN_LOOP_SEC boot warning

### Recommended items (14, not resolved — deferred)
1. SHALLOW_RELEASE_SEC dispatch catalog `release_class` field；2. workout_complete 保 mono + rationale；3. BGM channel policy + SFX memory re-estimate + SFX bundle CI gate；4. set_complete × streak_chime stagger → Q8；5. Rule 7c retarget kill+respawn；6. release callback per-voice idempotent latch；7. `_input` vs `_unhandled_input` rationale；8. AC-15 純函數斷言 vs bus 實時值；9. AC-05 web 前置（已修）；10-11. AC-28/AC-29；12. focus_low re-entry resume vs restart；13. BGM rotation pool stream cap + OGG decode early profiling；14. duck Tween churn AC

### Next
Awaiting fresh-session full re-review (Pass 4). Recommended /clear — session used substantial context across 3 passes + 18 specialist spawns total.

---

## Review — 2026-06-02 (Pass 4, fresh-session full re-review) — Verdict: NEEDS REVISION (first batch resolved inline; second batch deferred for co-design)
Scope signal: L
Specialists: audio-director, game-designer, systems-designer, qa-lead, godot-specialist, performance-analyst, creative-director (synthesis)
Blocking items: 8 (distinct, after de-dup) | Recommended: 12 (inline-resolved batch)
Prior verdict resolved: Pass 3 (10 BLOCKING + 14 RECOMMENDED) — confirmed held, no regression on prior items

### Summary (creative-director synthesis)
架構成熟，Pass 1-3 fix 全部守住。Pass 4 暴露兩類新問題：(A) **state-sequence audio continuity**——BGM loop-boundary rotation 不可實現（looped OGG 永不 emit `finished`），focus_low boss-exit restart 破壞「BGM 一直低沉」，LOOT_DROP 後 boss_theme 殘留破壞 Pillar 3 peak；(B) **cross-system contract gap**——`_active_ducks` set vs multiset 語意未定（duplicate offset stingers 會提早 release duck），`_suspend_sources` bitmask 漏掉 web-primary `WM_WINDOW_FOCUS_OUT` trigger，test seam contract 不完整令多個 Logic ACs 無法 headless verify。8 BLOCKING 分兩批：第一批（BLK-2/3/4/5 + 12 RECOMMENDED）機械性確定性 → inline resolved today；第二批（BLK-1/6/7/8 + game-designer B1 stale-replay 裁決）需 cross-system co-design → deferred to next session。

### Blocking items resolved inline (first batch — 4 items)
1. [systems-designer] `active_offsets` set vs multiset → Rule 7c/Formula 3/EC 改用 `_active_ducks: Dictionary[voice_handle→offset]`，multiset 語意，min(values())，by-handle erase，idempotent
2. [systems-designer] `min(active_offsets)` 空集合 → Formula 3 加 `is_empty()` guard branch
3. [qa-lead+godot-specialist] Test seam contract → Rule 1 加 `_register_duck/_release_duck/_compute_duck_target` pure functions + `_test_get_active_voice_count()/_test_get_active_crossfade_count()` + `_voice_busy` per-slot + `_active_crossfade_count` + `_crossfade_progress` writer/sentinel + 2-player mid-crossfade rule；AC-03/09/09c/15/17/18 全部改用 pure function / logical occupancy 驗法
4. [godot-specialist+qa-lead] `_suspend_sources` bitmask 加 bit 2 = `WM_WINDOW_FOCUS_OUT`；`_handle_focus_change()` 走 bitmask；新增 AC-30

### Recommended items resolved inline (12 items)
1. BGM channel policy normative（STEREO，CI gate 基準）；2. `audio_unlock_confirm` 升 mid priority（prevent steal on unlock）；3. set_complete × streak_chime MVP stagger default（80-120ms）；4. workout_complete mono explicit rationale；5. loot-duck-boss_theme Pillar 3 裁決 note；6. rest/calm BGM state Rule 6 map placeholder；7. BGM_MIN_LOOP_SEC 升 CI build-time fail；8. Formula 1 endpoint hard-set note；9. duck recompute operation order explicit（erase→recompute→lerp）；10. SFX memory 估算更新 ~2.25MB；11. BLK-6 `_do_unlock()` idempotent contract（`_input()` fallback + banner `pressed` canonical）；12. AC-28/29/31/32 新增（mute persist / rotation non-repeat / desktop negative / mock-GSM seam）

### Blocking items resolved (second batch — same session, co-design decisions adopted)
- BLK-1: BGM loop-boundary rotation → non-looping OGG + `finished`-driven rotate + equal-power crossfade via second BGM player（gap-free）; `_suspended_bgm_state` 升級為 `{variant_id, position_sec}`
- BLK-7: focus_low boss-exit → resume-from-position policy（`_paused_focus_low: {variant_id, position_sec}`，BOSS_ENCOUNTER 期間 record，WORKOUT_ACTIVE re-entry seek + crossfade）; fallback = continue-same-variant
- BLK-8: LOOT_DROP from BOSS_ENCOUNTER → conditional boss_theme→rest_calm early fade-back（Rule 6 updated）; from-state check in `_on_gsm_state_changed`; #15 co-design marker added
- BLK-6 / B1: `_do_unlock()` idempotent contract（batch 1）+ #9 WST forwarding forward contract（Dependencies section）; CD ruling: #9 holds mid/high workout SFX until `audio_unlocked`, AudioManager stays stateless

### Next
All 8 BLOCKING resolved. Awaiting Pass 5 fresh-session full re-review. Prerequisite actions before re-review:
- #9 WST GDD patch（add `audio_unlocked` subscribe + SFX buffer/flush contract）
- #15 LootDrop Pass 3 re-review（confirm BOSS_ENCOUNTER → LOOT_DROP from-state for BLK-8 conditional）
- BGM asset authoring brief（non-looping OGG spec）→ /asset-spec system:audio-manager after art bible

---

## Review — 2026-06-02 (Pass 5, fresh-session full re-review) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: audio-director, godot-specialist, qa-lead, game-designer, systems-designer, creative-director (synthesis)
Blocking items: 9 internal + 4 external gates | Recommended: ~12 (deferred)
Prior verdict resolved: Pass 4 (8 BLOCKING) — confirmed held, no regression

### Summary (creative-director synthesis)
架構仍 sound，Pass 1-4 fix 全部守住無 regression。CD **駁回** game-designer 嘅「APPROVED WITH GATES」立場 — 除咗 cross-system gates，仲有多個 GDD **internal** 矛盾/空白，implementer 即刻撞到（最嚴重 = BLK-5-3 自相矛盾）。第 5 passes 仍搵到新一批，churn pattern 同既往一致。Verdict: NEEDS REVISION（非 MAJOR — 全部係 localized inline fix，無核心設計方向改變）。

### Internal BLOCKING — GDD 自己改得掂（fresh-session Pass 6 action list，CD 已俾具體 fix）
- **IB-1 [audio-director BLK-5-3] 自相矛盾（最高優先）**: 「loot fanfare duck boss_theme = 刻意設計」(Visual/Audio) vs 「LOOT_DROP from BOSS → boss_theme fade to rest_calm」(Rule 6/BLK-8) 衝突。CD 裁決：採「先 BGM transition（LOOT_DROP entry quick-fade boss_theme→rest_calm 0.25s），後 duck（stinger duck rest_calm）」。Visual/Audio「duck boss_theme」段更新為「只適用 BOSS_ENCOUNTER 期間 mid-fight loot drop（boss theme 仍播）」，**唔適用** LOOT_DROP state entry。兩情境分開 spec。
- **IB-2 [godot BLK-P5-2]**: non-looping OGG rotation「gap-free」claim 唔成立（finished 係 deferred signal，~16ms gap）。改 wording 為「near-gap-free ≤1 frame」或改用提前 fade_sec crossfade（AC-29 相應更新）。
- **IB-3 [systems BLK-P5-01]**: `_register_duck(offset: float)` 無正數 guard → caller 傳正數 → duck 反向升 music。Rule 1 test seam + Formula 3 加 `offset ≤ 0` assert + `clamp(offset, MUTE_FLOOR_DB, 0)`，加對應 EC。
- **IB-4 [qa-lead B1]**: PlatformDetect mock seam 缺失 → AC-05/06b/14c/19a/19b/26/31（7 條 Logic BLOCKING）web/desktop 分支 headless phantom-pass。AC-32 擴展加 `var _platform_detect`（untyped）injection seam contract。
- **IB-5 [audio-director BLK-5-1]**: `set_complete` 80-120ms stagger 責任歸屬 → 明確由 #9 WST 做（知道兩 event 同 frame），刪 catalog 備註入面 `create_timer` snippet（唔係 #4 code），改寫為 #9 responsibility。
- **IB-6 [audio-director BLK-5-4]**: `_paused_focus_low` × `_suspended_bgm_state` interaction 加 EC：BOSS_ENCOUNTER 中 SUSPENDED → `_suspended_bgm_state` 記 boss_theme，`_paused_focus_low` 保留原 focus_low 值；兩 field 獨立唔互相覆蓋。
- **IB-7 [qa-lead B2]**: `bgm_changed` emit timing「crossfade 完成」→ headless Tween 唔 advance → AC-07/21 phantom。改「crossfade **開始**時 emit」+ 更新 AC-07 斷言（唔需 Tween advance），或加 mock crossfade-complete test seam。
- **IB-8 [godot BLK-P5-1]**: SUSPENDED 期間 duck Tween 行為未 spec。加 EC：SUSPENDED / `_handle_focus_change(false)` 時 duck Tween **kill** + Music bus dB hard-set 到 base_music_db；resume 由 `_active_ducks` 重算。
- **IB-9 [godot BLK-P5-3]**: `_voice_busy` vs `.playing` rationale 未寫。Rule 1/Detailed Design 加 normative 說明：`_voice_busy` 係 AudioManager 顯式管理嘅邏輯佔用 state，獨立於 engine `.playing`（headless dummy driver 唔 guarantee `.playing`）；永不用 `.playing` 做邏輯判斷，即使 engine reference sample 用 `.playing`。

### External cross-system gates（唔係 #4 internal，要其他 GDD 協調）
- **EG-1**: #9 WST GDD patch — `audio_unlocked` subscribe + mid/high SFX buffer/flush。Owner: game-designer + #9。**同 #10 epic-close gate 重疊。**
- **EG-2**: #20 Gym-Mode HUD GDD authoring — banner soft-gate（#4 contract 已定，#20 GDD 待 author）。
- **EG-3**: #15 LootDrop Pass 3 re-review — confirm boss kill → LOOT_DROP from-state == BOSS_ENCOUNTER（BLK-8 conditional 依賴）。
- **EG-4**: workout_complete × loot fanfare 時序（inline fixable，可併入 Pass 6）。

### Recommendations（非 blocking，建議 Pass 6 順手）
- boss_death SFX（catalog freeze 漏，Pillar 3 最高峰靜音）— 加 high/STEREO；- LOOT→rest_calm 獨立 fade knob `LOOT_BGM_TRANSITION_SEC`；- Formula 2 `is_inf` guard（不只 is_nan）；- `_crossfade_progress` sentinel 用 `< 0` 唔好 `== -1.0`；- p=0.5 mid-crossfade tiebreaker；- `min()` 用 `.values().min()` Array method 表記；- DUCK perceptibility 下限 + `STREAK_CHIME_DUCK_OFFSET_DB > DUCK_OFFSET_DB` invariant；- Q3 Safari auto-resume 降 RESOLVED-provisional。

### Next
Awaiting fresh-session Pass 6 re-review. Action: /clear → revise IB-1..IB-9 inline (CD fixes above) + EG-4 → re-run /design-review. EG-1/2/3 係 external gates，#4 GDD 自身 fix 完 internal 9 項後即可 APPROVE（external gates tracked，唔阻 #4 GDD approval，同 #10/ExerciseClassMapping 先例一致）。Session used heavy context (5 stories + phantom-sweep + push + 6-agent review) — fresh session strongly recommended.

---

## Pass 5 revisions APPLIED — 2026-06-02 (inline, autonomous mode) — awaiting Pass 6 re-review

全部 9 internal BLOCKING + EG-4 已 inline 修正，CD-supplied fixes 落實：

| Item | Fix applied | GDD location |
|------|-------------|--------------|
| **IB-1** 自相矛盾 loot-duck-boss_theme | 拆兩情境：A=LOOT_DROP state entry（先 `LOOT_BGM_TRANSITION_SEC`=0.25s fade boss_theme→rest_calm，後 duck rest_calm）；B=mid-fight loot（仍 BOSS_ENCOUNTER，duck boss_theme，刻意）。判別 = 有冇 GSM transition | Visual/Audio「Loot fanfare × boss_theme 兩情境」+ Rule 6 LOOT_DROP + EC ×2 |
| **IB-2** non-looping OGG「gap-free」 | 改 "near-gap-free（≤1 frame）"，`finished` 係 deferred signal ~16ms gap；真無縫=提前 fade_sec（post-MVP）；AC-29 只驗順序 | Visual/Audio BGM rotation note |
| **IB-3** `_register_duck` 無正數 guard | `assert(offset<=0)` + `clamp(offset, MUTE_FLOOR_DB, 0)` + push_warning；新 AC-09d | Rule 1 test seam + Formula 3 boundary + AC-09d |
| **IB-4** PlatformDetect mock seam 缺失 | `var _platform_detect`（untyped）injection seam；7 條 platform-branch AC 前置；新 AC-32b | AC-32 + 新 AC-32b |
| **IB-5** `set_complete` stagger 責任 | 歸 #9 WST forwarding（佢知同 frame）；刪 #4 catalog 入面 `create_timer` snippet；補 #9 forward contract 條目 | catalog `set_complete` row + Dependencies forward contract |
| **IB-6** `_paused_focus_low`×`_suspended_bgm_state` | 新 EC：BOSS_ENCOUNTER SUSPENDED → `_suspended_bgm_state`=boss_theme，`_paused_focus_low` 保留 focus_low，兩 field 獨立；新 AC-34 | EC + 新 AC-34 |
| **IB-7** `bgm_changed` emit timing | 改「crossfade **開始**時 emit」（headless Tween 唔 advance，emit-at-complete = phantom）；signal comment + AC-07 修正 | Rule 1 signal + AC-07 |
| **IB-8** SUSPENDED duck Tween 未 spec | 新 EC：suspend → kill duck tween + Music bus hard-set base_music_db，`_active_ducks` 唔清；resume 重算；新 AC-33 | EC + 新 AC-33 |
| **IB-9** `_voice_busy` vs `.playing` rationale | normative：`_voice_busy` 邏輯佔用，獨立 engine `.playing`；內部邏輯**永不**讀 `.playing`（即使 ref sample 用），headless-determinism 硬性要求 | Rule 1 test seam block |
| **EG-4** workout_complete × loot fanfare 時序 | 新 EC：兩者皆 SFX bus 唔互 duck，priority 唔互 steal，天然錯開（workout 先、loot 隨 backend latency），極端同 frame=雙 reward（接受） | EC |

順手 recommendation（Pass 5 list）：boss_death catalog row（high/STEREO，Pillar 3 最高峰原本靜音 gap）；Formula 2 `is_inf` guard（不只 is_nan）；`_crossfade_progress` sentinel 改 `< 0`（唔用 `== -1.0` 浮點等號）；新 knob `LOOT_BGM_TRANSITION_SEC`（0.25s）；`.values().min()` notation 已喺 Formula 3 在用。

**未動（deferred / 留 Pass 6 verdict 判）**：其餘 ~8 條 Pass 5 recommendation（DUCK perceptibility invariant、Q3 降 RESOLVED-provisional、p=0.5 tiebreaker 等）非 blocking，留 Pass 6 順手或 verdict note。

**External gates 狀態不變**：EG-1（#9 WST patch）、EG-2（#20 HUD GDD）、EG-3（#15 Pass 3 re-review）仍 tracked external，唔阻 #4 GDD approval（#10 先例）。

### Next
重跑 `/design-review design/gdd/audio-manager.md`（Pass 6 fresh-session 強烈建議）。預期：若無新一輪 churn，internal 全清 → APPROVE-able（external gates 標 tracked）。

---

## Review — 2026-06-02 (Pass 6, lean single-session re-review) — Verdict: NEEDS REVISION → 2 BLOCKING resolved inline → **APPROVED (user-ratified 2026-06-02)**
Scope signal: L（implementation scope；fix 本身 = S 機械改動）
Specialists: lean mode（無 6-specialist spawn — Pass 6 doc 極成熟 + harness spawn-conservatism；main session 自驗 + GSM/dependency ground-truth grep）
Blocking items: 2 internal（both fix-induced 機械錯漏）| Recommended: ~4（deferred）| External gates: 3（tracked，不阻 approval）
Prior verdict resolved: Pass 5（9 internal IB + EG-4）— **全部確認 held，逐項 trace 過，無 regression**

### Summary
架構仍 sound，Pass 1-5 fix 全部守住。逐一 trace IB-1..IB-9 + EG-4 落 GDD 實際位置全部到位（兩情境 loot-duck-boss 分拆、near-gap-free wording、`_register_duck` 正數 guard、PlatformDetect mock seam AC-32b、stagger→#9、`_paused_focus_low`×`_suspended_bgm_state` 獨立 EC、bgm_changed crossfade-start emit、SUSPENDED duck-kill AC-33、`_voice_busy` rationale）。Pass 5「順手」recommendation（boss_death catalog row / Formula 2 `is_inf` / sentinel `<0` / `LOOT_BGM_TRANSITION_SEC` knob）亦全部落實。churn pattern 延續但收斂——今次只剩 2 個機械 fix-induced 矛盾，零設計 re-litigation。

### Blocking items (2) — both resolved inline (autonomous mode)
1. **B1 [cross-system consistency]** Rule 6 line 120 map key `REST_BETWEEN_SETS` **唔係** GSM `GameState` enum 有效值（game-state-machine.md L589 = `REST_PERIOD`，"renamed from EXERCISE_SWITCHING per Decision #3"）→ 該 `→{rest_calm,1.0}` map entry 永不 fire，「我落到 bench 抖氣」rest_calm fantasy beat 靜默死亡 + scenario A loot-peak landing bed 削弱。**Fix**：line 120 key `REST_BETWEEN_SETS`→`REST_PERIOD` + 加 cross-system rationale 註。（rest_calm track 名其餘引用全部正確，無需動。）
2. **B2 [internal consistency / AC testability]** `_suspended_bgm_state`（States table L159 / EC L249,251 / AC-34 L444 — 已升級 `{variant_id, position_sec}` dict）vs `_suspended_bgm_track`（L347 / AC-14 L413 / AC-14b L414 / AC-30 L436）= 同一 member 兩個名，implementer 無法分辨 canonical。更甚：AC-14/14b 仍寫 `_suspended_bgm_track == <track_id>`，但 field 已係 dict → 斷言 type-stale。**Fix**：全部收口 `_suspended_bgm_state`（L347/AC-30）+ AC-14/14b 斷言改 `.variant_id == <variant>`（dict 正確比較）。

### Recommended (deferred — non-blocking)
- R1 `STREAK_CHIME_DUCK_OFFSET_DB > DUCK_OFFSET_DB` invariant 未明文（值正確 −5 > −8，shallower）。
- R2 BGM variant rotation（focus_low_pool 內換 variant）是否 emit `bgm_changed`？spec 沉默（同 track_id pool，估計唔應 emit，但未定義）。
- R3 Q3 Safari auto-resume 降 RESOLVED-provisional（Pass 5 carryover）。
- R4 Q-CLEANUP `_exit_tree()` kill retained Tweens（已 tracked，低優先 impl story 順手）。

### External cross-system gates（tracked，不阻 #4 approval — #10 先例）
- EG-1 #9 WST GDD patch（`audio_unlocked` subscribe + mid/high SFX buffer/flush + set_complete×streak_chime stagger）。**與 #10 epic-close gate 重疊。**
- EG-2 #20 Gym-Mode HUD GDD authoring（banner soft-gate；#4 contract 已定，#20 GDD 待 author，檔案未存在）。
- EG-3 #15 LootDrop Pass 3 re-review（confirm boss kill → LOOT_DROP from_state == BOSS_ENCOUNTER，scenario A conditional 依賴）。

### Completeness: 8/8 sections present（+ States/Interactions/Visual-Audio/UI/Open-Questions 額外）
### Dependency graph
- ✓ game-state-machine.md / persistence-layer.md / gymsys-backend-client.md / particle-system-wrapper.md / screen-effects-system.md / streak-system.md / loot-drop-system.md — 全部存在（all Approved）
- ✗ combat-visual-feedback.md（#25，Not Started forward ref，可接受）
- ✗ gym-mode-hud.md（#20，Not Started forward ref；EG-2 tracked）

### Next
2 internal BLOCKING 已 resolved inline。Internal consistency 清。**User 裁定 2026-06-02：mark Approved（external gates tracked，#10 先例）。** #4 Audio Manager GDD 6 passes 收官。後續：3 external gate（EG-1 #9 WST patch / EG-2 #20 HUD GDD authoring / EG-3 #15 Pass 3 from-state confirm）在各自 GDD 軌道處理，唔阻 #4。下一步可 /create-epics audio-manager 或 /asset-spec system:audio-manager（待 art/audio bible approved）。

---

## EG-1 RESOLVED — 2026-06-03 (Option B, user-ratified)
**Gate**: EG-1 (workout SFX forwarding during LOCKED) — opened, found to be a cross-GDD conflict, resolved by amending #4 (not patching #9).

**Conflict**: #4 audio-manager.md's forward contract assigned "workout SFX forwarding layer" (buffer mid/high SFX until `audio_unlocked` → flush) to **#9 WorkoutStateTracker**. But #9 is a locked **pure data/event layer** (workout-state-tracker.md CD-praised "至今最 architecturally sound"; explicit "audio binding to #9 = architectural smell"; Rule 16 anti-fabrication NEVERs). The CD audio ruling and #9's purity invariant directly contradicted.

**Resolution (Option B, user-chosen)**: keep #9 pure; relocate the SFX forwarding/buffering ownership to the **presentation-layer audio-trigger consumer** that actually calls `play_sfx` (#20 Gym-Mode HUD — EG-2 scope — or a dedicated workout-feedback adapter). That consumer subscribes `#2.set_logged` directly (the #18 PR-Detection precedent) + `AudioManager.audio_unlocked`, buffers mid/high while LOCKED, flushes on unlock, low drops, and owns the `set_complete`×`streak_chime` same-frame 80-120ms stagger. AudioManager stays a stateless gateway; #9 NEVER calls play_sfx.

**Edits**: (1) audio-manager.md Dependencies forward contract re-owned (#9→consumer) + NOT-#9 callout + catalog `set_complete` row stagger-owner updated. (2) workout-state-tracker.md #4 dependency row gets an EG-1-resolution note (#9 not patched, stays pure). 

**Effect on gate list**: **EG-1 is now FOLDED INTO EG-2 (#20 Gym-Mode HUD GDD authoring)** — the audio-trigger consumer contract is a #20 authoring prerequisite. There is no longer a separate "#9 WST patch". #9 needs no change. EG-3 (#15 from-state) unchanged.
