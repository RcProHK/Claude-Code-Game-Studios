# Audio Manager

> **Status**: **Approved 2026-06-02 (Pass 6 lean re-review)** — internal consistency 全清。6 passes 累計：Pass 1-5 fix 全部 trace-confirmed held；Pass 6 只剩 2 個 fix-induced 機械 BLOCKING（B1 Rule 6 map key `REST_BETWEEN_SETS`→`REST_PERIOD` 對齊 GSM `GameState` enum；B2 `_suspended_bgm_track`/`_suspended_bgm_state` 同名收口 + AC-14/14b dict 斷言修正），**兩項已 inline 修正**。無新設計改變、無核心 regression。**3 個 external gate（EG-1 #9 WST patch / EG-2 #20 HUD GDD / EG-3 #15 from-state）tracked，唔阻 approval**（#10/ExerciseClassMapping 先例：external cross-system gate ≠ GDD defect）。User 裁定 mark Approved 2026-06-02。 — PRIOR: **Pass 5 revisions APPLIED (2026-06-02)**: 9 internal BLOCKING (IB-1..IB-9) + EG-4 全部 inline 修正完成（IB-1 兩情境分拆 / IB-2 near-gap-free / IB-3 `_register_duck` 正數 guard / IB-4 `_platform_detect` mock seam / IB-5 stagger→#9 / IB-6 `_paused_focus_low`×`_suspended_bgm_state` 獨立 EC / IB-7 `bgm_changed` emit-at-crossfade-start / IB-8 SUSPENDED duck-kill EC / IB-9 `_voice_busy` vs `.playing` normative）。順手 recommendation：boss_death catalog row、Formula 2 `is_inf` guard、`_crossfade_progress` sentinel `<0`、`LOOT_BGM_TRANSITION_SEC` knob。新增 AC-07 修正 + AC-09d/32b/33/34。EG-1/2/3 tracked external（do not block #4 GDD approval，同 #10 先例一致）。NEXT: 重跑 `/design-review design/gdd/audio-manager.md`（Pass 6）。
> **Author**: Frank + (lean author pass; Pass 1 full 6-specialist adversarial review 2026-06-01 — 6 BLOCKING + 9 RECOMMENDED resolved; Pass 2 fresh-session re-review 2026-06-01 — 8 BLOCKING + 8 RECOMMENDED resolved; Pass 3 fresh-session re-review 2026-06-01 — 10 BLOCKING + 14 RECOMMENDED resolved; Pass 4 fresh-session re-review 2026-06-02 — 8 BLOCKING + 12 RECOMMENDED resolved)
> **Last Updated**: 2026-06-01
> **Implements Pillar**: Indirect Foundation — serves Pillar 3 (Drop Euphoria) + Pillar 1/2 supporting via audio feedback channel
> **System #**: 4 (Foundation / MVP tier)
> **Depends On**: #1 GameStateMachine (music transitions), #3 PersistenceLayer (volume settings), #2 GymSysBackendClient (indirect — workout events drive stingers)
> **Depended On By**: #5 ParticleSystemWrapper (audio co-trigger), #6 ScreenEffects, #8 StreakSystem (counter chime), #15 LootDropSystem (loot fanfare), #25 Combat Visual Feedback, #20 Gym-Mode HUD
> **Governing ADRs**: ADR-0008 Autoload Position Map (**Accepted 2026-06-01** — placement), ADR-0006 Contract 4/6 (boot order + connect_for_initial_state), ADR-0001 (web export budget), ADR-0003 (volume persistence keys)

## Overview

AudioManager 係 Mirror Hero 嘅 Foundation 層 audio gateway singleton autoload — 全 game 所有 SFX 同 BGM 嘅唯一出聲入口。其他系統只能透過 closed API（`play_sfx(event_id)` / `play_bgm(track_id, fade)` / `stop_bgm(fade)` / `set_bus_volume(bus, db)`）觸發音效,**永不**直接 `new AudioStreamPlayer` 或 mutate AudioServer bus（CI enforced,同 #5/#6/#7 single-gateway posture 一致）。佢管理三條 audio bus（Master → Music / SFX 子 bus）,訂閱 #1 GameStateMachine 嘅 state（via `connect_for_initial_state`,ADR-0006 C6）做 music transition（例如 WorkoutActive → BossEncounter 換 boss theme、LootDrop → loot stinger）,並接受 downstream 系統（#5 particle / #6 screen effects / #8 streak / #15 loot）嘅 one-shot SFX co-trigger。音量設定 via #3 PersistenceLayer 持久化（`audio.*` namespace）。關鍵 Web Export constraint：**mobile Safari audio autoplay restriction** — AudioContext 要喺首個 user gesture 之後先 unlock,所以 BGM 唔可以冷啟動自動播,要 gate 喺 unlock 之後。此系統 MVP tier,跨平台單一行為（mobile/desktop 一致）。玩家唔直接操作 AudioManager,但佢 enable 嘅 audio feedback（loot fanfare 嘅 dopamine peak、hit 嘅體感印章、streak 嘅 low-key chime）係 game feel 嘅核心 channel 之一。

## Player Fantasy

**Indirect Foundation Fantasy — 聽得見嘅因果（The Audible Consequence）/ 隱形配樂師**

玩家心入面嘅 felt promise：「**我做緊 leg day 最後一組 squat，耳筒入面 BGM 一直低沉、唔搶戲，我專注數 rep。組數一完，背景啱啱好淡出一粒柔和 chime — streak 由 22 跳 23，唔係 fanfare，係一種沉實嘅確認。跟住我落到 bench 抖氣，個遊戲後台 roll 到一件 epic，耳筒『咚』一聲飽滿嘅 loot fanfare 由 SFX bus 衝出嚟，短暫蓋過 music（ducking），嗰一下 dopamine peak 我唔使睇 screen 都知中咗大獎。我冇 set 過任何音效，我只係知：呢個世界對我每一個真實動作都有聲音回應 — 微弱嘅、剛好嘅、值得嘅。**」

呢個 fantasy 唔由 AudioManager emit 任何敘事 text — 而係由佢嘅 **architectural posture** 強制：

- **Sonic channel separation** — #4 owns 聲音，partition 自 #5（peripheral visual）/ #6（peripheral kinaesthetic）/ #7（spatial framing）。Audio 唔搶 visual attention，亦唔被搶。
- **Subtle-by-default, peak-on-reward** — BGM 永遠 mix 喺低位（唔搶 set 注意力，game-concept locked）；唯一容許爆嘅係 #15 loot fanfare 嘅 dopamine peak（Pillar 3）+ boss theme 嘅 stakes signal。Ducking 令 reward SFX 短暫蓋 music。
- **Silent until gestured** — mobile Safari 唔畀冷啟動出聲；AudioManager 寧願靜，唔會 hack autoplay。第一下 user tap = 世界開聲。
- **Closed gateway，玩家唔使 micro-manage** — 玩家淨係喺 settings 拉 Master / Music / SFX 三條 slider，gameplay 中完全唔使理音效。

呢個 indirect fantasy 同其他 Foundation system 一齊形成統一 **fantasy vocabulary**：#1 owns *temporal continuity* · #5 *peripheral visual signal* · #6 *peripheral kinaesthetic signal* · #7 *spatial framing* · #8 *cross-day accumulation* · **#4（本系統）owns *sonic consequence channel*（聲音回應真實動作）**。

**Pillar links**：Pillar 3（DNF 式爆裝 — primary supporting）loot fanfare 係 audio 唯一容許嘅 peak，amplify #15 ritual moment；Pillar 1/2 supporting — hit SFX 印實真實動作嘅因果，BGM subtle 保 set focus（Pillar 2 frictionless）。

## Detailed Design

### Core Rules

**Rule 1 — Closed API surface (gateway)**
```gdscript
# Public API (read-only callers — 永不直接掂 AudioServer / AudioStreamPlayer)
func play_sfx(event_id: StringName) -> void          # one-shot, pooled, voice-stealing
func play_bgm(track_id: StringName, fade_in_sec: float = 1.0) -> void
func stop_bgm(fade_out_sec: float = 1.0) -> void
func set_bus_volume_db(bus: Bus, db: float) -> void  # Bus { MASTER, MUSIC, SFX }
func get_bus_volume_db(bus: Bus) -> float
func set_bus_muted(bus: Bus, muted: bool) -> void
func is_audio_unlocked() -> bool

signal audio_unlocked()                  # 首次 gesture unlock 後 emit 一次
signal bgm_changed(track_id: StringName) # crossfade **開始**時 emit（IB-7：headless Tween 唔 advance；emit 喺 crossfade complete 會令 AC-07 phantom-pass。emit 點 = `play_bgm` 起 crossfade tween 之後、return 之前）
```
無 public mutator 掂 AudioServer/AudioStreamPlayer；CI lint `check_audio_callers.gd` ban gateway 外嘅 `AudioServer.` / `new AudioStreamPlayer` / `.bus =` 設定。

**Test seam functions（[qa-lead] Pass 4 BLOCKING — pure-function 斷言路徑）**：以下 test-only helpers 供 GUT unit test 使用，**不應被 production code 呼叫**（naming convention 以 `_test_` prefix 標明）：
```gdscript
# Duck refcount pure functions (GUT: call directly instead of mock-emit finished)
func _register_duck(offset: float) -> int          # register active duck; return voice_handle (monotonic int)
                                                    #   IB-3 guard: offset 必須 ≤ 0（duck 衰減量）。入口 assert(offset <= 0.0,
                                                    #   "duck offset must be ≤ 0") + 防呆 stored = clamp(offset, MUTE_FLOOR_DB, 0.0)。
                                                    #   傳正數 → music 反向「升」（破 Pillar 3 + clip 風險），故 clamp 到 0（無效 duck）+ push_warning。
func _release_duck(handle: int) -> void            # idempotent: erase handle from _active_ducks dict; no-op if absent
func _compute_duck_target(ducks_dict: Dictionary) -> float  # pure: dict{handle→offset} → duck target dB; empty → base_music_db

# Pool / crossfade observability (GUT: assert state without touching AudioStreamPlayer internals)
func _test_get_active_voice_count() -> int         # count _voice_busy==true slots (logical occupancy, NOT engine .playing)
func _test_get_active_crossfade_count() -> int     # return _active_crossfade_count member (0 or 1)
```
**`_active_ducks: Dictionary` (handle → offset)** = duck 嘅唯一 source-of-truth（multiset 語意，唔去重）。refcount = `_active_ducks.size()`，唔係獨立 int counter。duck target 唔用全域 `active_offsets`，只用 `_compute_duck_target(_active_ducks)`。
**`_voice_busy: bool`** per-slot = 邏輯佔用狀態（assign 時 set，`finished`/steal release 時 clear）。voice-count ACs 斷言 `_voice_busy`，**唔斷言 `AudioStreamPlayer.playing`**（headless Dummy driver 嘅 `.playing` 行為 post-Godot-4.6-cutoff 未驗，可能 vacuous）。
**`_voice_busy` vs `.playing` — normative rationale（IB-9 [godot-specialist]）**：`_voice_busy` 係 AudioManager **顯式管理**嘅邏輯佔用 state（pool 嘅「忙/閒」由佢定義，唔由 engine 定義）。佢**獨立於** engine `AudioStreamPlayer.playing`：headless Dummy audio driver 唔 guarantee `.playing` 反映真實 playback（可能恆 false / 即時 false），故 `.playing` 喺 headless 不可靠。**AudioManager 內部邏輯（steal 揀 victim、voice-count、pool 佔用判斷）永不讀 `.playing`，一律以 `_voice_busy` 為準**，即使 engine reference sample / 教學示範用 `.playing` 做判斷亦不跟（呢個係 headless-determinism 硬性要求，非風格偏好）。`.playing` 僅可用作 runtime 真機 debug 觀察，永不入邏輯分支。
**`_active_crossfade_count: int`** = crossfade 活躍數（start crossfade ++，kill/complete --）。AC-18 斷言此值 == 1，唔靠 Tween 枚舉 API（Godot 冇 per-node Tween registry）。

**CI lint 實作合約（[godot-specialist] Pass 2 BLOCKING — 修正先前 wording）**：
- **豁免用 full-path array,唔係 filename substring**：`EXEMPT_FILES = ["res://src/autoload/audio_manager.gd"]` + `EXEMPT_FILES.has(file_path)`,**完全跟 `check_camera_callers.gd` / `check_particle_callers.gd` 既有先例**。filename-only matching 會誤殺其他同名 `audio_manager.gd`(先前 wording「by filename」係錯,已修正)。
- **`.bus =` pattern 必須 anchor 到 token**：用 `AudioStreamPlayer[^\n]*\.bus\s*=`(跟 camera lint anchor `Camera2D[^\n]*` 先例),**唔可**裸 ban `.bus\s*=` —— 否則 false-positive 封死 `event_bus =` / `message_bus =` / `signal_bus =` 等無關 identifier。
- `AudioServer\.` / `new AudioStreamPlayer` 裸 ban OK(無 non-gateway file 應掂)。

**`src/autoload/audio_manager.gd` 自我白名單（self-exempt）**：gateway 本體必須用 `player.bus = &"SFX"` 設 pool / BGM player 嘅 bus assignment,CI 只 ban 白名單**外**嘅 caller。

**Rule 2 — Bus topology**：`Master → {Music, SFX}` 兩條子 bus。Volume 用 dB。Default：Master 0dB、**Music −6dB（subtle，game-concept locked）**、SFX 0dB。

**Rule 3 — SFX pooling + priority-aware voice stealing**：固定 pool（`SFX_VOICE_COUNT`，web budget）非位置性 `AudioStreamPlayer`。`play_sfx` 攞 free player，全忙 → steal。`event_id → AudioStream` 經 data-driven `SfxCatalog.tres`（無 hardcode path，符合 coding-standard）。

**Stealing policy（[performance-analyst] + [audio-director] Pass 2 BLOCKING — naive steal-oldest 會殺 P3）**：
- **priority-aware**：揀 victim 時,**high-priority voice 不可俾 lower-priority steal**。steal 順序 = 先揀**最低 priority** 嘅 active voice;同 priority 先 steal **最舊**。
- **Why**：8 條 voice 俾 low `hit_light` 連發塞滿時,naive steal-oldest 會喺 `loot_fanfare_legendary`（high,Pillar 3 唯一 peak）一播即被下一拳 steal → **直接殺 P3**。priority gate 保證 fanfare 唔會俾 combat SFX 搶走。
- **退化情況**：若全 pool 都係 high-priority(罕見),先 steal 最舊 high。

**Steal × duck refcount 安全（[godot-specialist] Pass 2 BLOCKING — permanent-duck bug）**：被 steal 嘅 voice **唔會** emit `AudioStreamPlayer.finished`（Godot 4.6 `stop()`/replay 唔觸發 `finished`,只有自然播完先 emit）。若該 voice 之前曾 increment duck refcount(high-prio stinger),steal 路徑**必須顯式 call 同一條 release callback 減 refcount**,否則 refcount 永不歸零 → **permanent duck**(BGM 被永久壓住)。實作:duck 註冊以 per-voice handle 追蹤,`finished` **同** steal 兩條路徑都觸發 release。

**Rule 4 — BGM crossfade single-channel**：兩個 dedicated Music player 做 crossfade。`play_bgm` 由當前 track crossfade 去新 track。同 `track_id` 正播 → no-op（idempotent）。`track_id → stream` 經 `BgmCatalog.tres`。

> **Focus_low boss-exit re-entry policy（[game-designer + audio-director] Pass 4 BLOCKING — BLK-7）**：Rule 4 嘅 idempotent no-op 只在「same `track_id` 正播」時觸發。BOSS_ENCOUNTER 期間 boss_theme 替代了 focus_low，所以 WORKOUT_ACTIVE re-entry 時 focus_low **唔係**「正播」→ 觸發 fresh crossfade。若用 fresh start（position 0 + 可能 rotate 到不同 variant），玩家聽到 ambient bed 重新開頭 / 換 variant — 破壞「BGM **一直**低沉」嘅 seamless continuity（Player Fantasy load-bearing promise）。
>
> **正確 re-entry behavior（resume-from-position）**：
> - Boss encounter 期間，focus_low **唔係 stopped，而係 paused**（suspended in background）。AudioManager 維護 `_paused_focus_low: {variant_id: StringName, position_sec: float}` — 每次 focus_low crossfade-out 時記錄。
> - WORKOUT_ACTIVE re-entry：`play_bgm("focus_low_pool")` 檢查 `_paused_focus_low` — 若有記錄，second player preload 同一 variant，seek to `position_sec`，crossfade 進去（seamless resume）；若無記錄（首次進 WORKOUT_ACTIVE），正常 fresh start + rotate。
> - **Fallback**（若 WASM stream seek 實作困難）：continue-same-variant fresh-loop — 鎖住 `_paused_focus_low.variant_id`，從 position 0 crossfade 進去（唔 rotate 到新 variant，避免「換 variant」嘅最刺耳 discontinuity，接受 loop restart）。Implementer 選一，GDD spec preferred path = resume-from-position。

**Retained crossfade Tween（[godot-specialist] Pass 2 BLOCKING — autoload Tween 競寫）**：crossfade 用**單一 retained Tween handle**(存喺 AudioManager 成員)。autoload 嘅 `create_tween()` 唔會隨 scene change 自動 kill,**rapid `play_bgm` 連發會 spawn 多條 Tween 同時寫同一個 `volume_db` → 競態**。故 `play_bgm` 起新 crossfade 前**必須先 `if _crossfade_tween and _crossfade_tween.is_valid(): _crossfade_tween.kill()`**,再 `create_tween()` 由當前 audible gain 起(配合 EC mid-crossfade latest-wins)。同一 retained-handle pattern 套落 ducking Tween(Rule 7c)。

**Rule 5 — Mobile Safari unlock gate（`unlocked` 係正交 flag,非 state）**：

> 🔑 **Architectural change（[game-designer] Pass 2 BLOCKING — LOCKED+SUSPENDED 永久靜音 hole）**：`unlocked` 由**獨立 boolean flag** 表達(`_audio_unlocked: bool`),**唔再係 GSM-orthogonal 嘅獨立 state**。LOCKED「狀態」= `is_web AND NOT _audio_unlocked` 嘅 derived 條件。咁 SUSPENDED 可以同「未 unlock」**正交共存**:玩家 load 入 web(`_audio_unlocked=false`)→ 未 tap 就袋住部機 → GSM SUSPENDED → resume 後 `_audio_unlocked` 仍 `false` → 首 tap 照樣 unlock + 起 pending BGM。**杜絕**「routed to SUSPENDED 後 unlock 路徑被吞 → 永久靜音」。

unlock 前 AudioContext suspended。`play_bgm` 入 single-slot deferred（latest-wins，跟 streak posture）；`play_sfx` 直接 drop + warn（one-shot 唔值得 defer）。首個 user InputEvent → **Godot 4.6 Web Export audio driver 引擎層自動 resume suspended AudioContext**（無需 game code 顯式 `JavaScriptBridge.eval`，故無 ADR-0001 衝突 — 詳見 Q3 resolution；real-Safari 驗證仍 ADVISORY,故保留 `_input()` monitor 做 belt-and-suspenders）→ AudioManager 喺 `_input()` 收到首個 `InputEventScreenTouch`/`InputEventMouseButton` 即呼叫 **`_do_unlock()`**：

> ⚠️ **`_input()` vs #20 banner gate — idempotent `_do_unlock()` 收口（[godot-specialist] Pass 4 BLOCKING）**：`_input()` 喺任何 Control 之前 fire，screen 任何位置嘅 stray tap 都會觸發 unlock，唔必然係 banner button。同時，#20 Gym-Mode HUD 嘅「㩒一下開聲」banner button 嘅 `pressed` signal 亦呼叫同一條 `_do_unlock()`。兩條路徑都 **early-return if `_audio_unlocked` is already true**（idempotent）。唔會 double-fire。**`_input()` = engine-level fallback（確保任何真實 gesture 一定 unlock）；banner `pressed` = canonical UX path（設計意圖上嘅 unlock 觸發點）。** 任一先到達就 unlock，另一條冇副作用。

**`_do_unlock()` 執行步驟**：
1. set `_audio_unlocked = true` + emit `audio_unlocked`;
2. 播 **`audio_unlock_confirm` one-shot**（[game-designer] Pass 2 RECOMMENDED — 首個 real action 唔再無聲後果,將 silence→sound 轉場變成刻意設計嘅 beat,守 Player Fantasy「每個真實動作有聲音回應」）;
3. 起 BGM —— **唔直接補播 deferred track,而係重 query GSM 當前 state**（[game-designer] Pass 2 RECOMMENDED — 防 pre-unlock state churn 令 unlock 起咗一個已結束 encounter 嘅 `boss_theme`;以當前 context 自我修正）。deferred slot 只做 fallback(GSM 無對應 track map entry 時)。

Desktop/native 無 restriction → boot 即 `_audio_unlocked=true`。
> ⚠️ **LOCKED 期間 feedback 取捨（[game-designer] BLOCKING）**：unlock 前 `play_sfx` drop 係刻意（fantasy「silent until gestured」），但會食咗玩家首組 squat 嘅 streak chime / hit SFX。**解決**：unlock 前由 #20 Gym-Mode HUD 顯示 *silent-mode banner*（「㩒一下開聲」prompt 引導首 tap）；玩家唯一 core input（tap 揀下一個動作）天然觸發 unlock，`audio_unlock_confirm` 立即回應,故 LOCKED window 極短。**唔做 stale SFX replay**（補播過時 one-shot 反而 muddy）。Banner UX 屬 #20，此 GDD 只定 contract（見 UI Requirements + AC-06b）。**⚠️ [game-designer] Pass 3 BLOCKING — #20 banner gate contract**：「LOCKED window 極短」假設成立條件係 **#20 banner 係 soft-gate — workout counting start（backend event 推進）必須在 banner tap-dismissed（`audio_unlocked` emitted）之後**。Gym 場景玩家可能「做 squat 唔掂手機」，backend HTTP polling 嘅 `set_complete`/`streak_chime` event 可早過首次 screen tap；若 banner 非 gate，首組 workout SFX 全 drop → 破 Player Fantasy。合約：#20 GDD 必須實現「banner tap → unlock → 之後先算 workout session start 畀 backend event 推進」sequence，並以 `is_audio_unlocked()` 作為 ready signal。

**Rule 6 — GSM state → music transition**：`connect_for_initial_state(_on_gsm_state_changed)`（ADR-0006 C6）。data-driven `state → track` map，每 entry 帶 `{track_id, fade_sec}`（per-state fade override，default `BGM_DEFAULT_FADE_SEC`）。已確認 entries：
- `WORKOUT_ACTIVE→{focus_low_pool, 1.0}`（multi-variant rotation pool，詳見 Visual/Audio Requirements）
- `BOSS_ENCOUNTER→{boss_theme, 0.25}`（**短 fade 強化 stakes signal**）
- `REST_PERIOD→{rest_calm, 1.0}`（**組間休息 calm ambient — [audio-director] Pass 4 RECOMMENDED**：Player Fantasy「我落到 bench 抖氣」moment 需要 calm bed，否則 focus_low 緊張感延續 → loot peak landing bed 唔夠 calm；placeholder entry，track asset 待 audio-director + game-designer 落實）。**⚠️ Pass 6 [cross-system consistency] BLOCKING fix**：state key 必須係 `REST_PERIOD`（GSM `GameState` enum 權威值，game-state-machine.md「renamed from EXERCISE_SWITCHING per Decision #3」）；先前 wording `REST_BETWEEN_SETS` **唔係** GSM 有效 state → map entry 永不 fire，rest_calm beat 靜默死亡。
- `LOOT_DROP→`（stinger only，**但 from-state conditional** — 對應 Visual/Audio「情境 A」）：
  - **從 `BOSS_ENCOUNTER` 進入**（boss 死後 loot drop）：**先 BGM transition 後 duck**（IB-1 CD 裁決）—— (1) 觸發 **boss_theme → rest_calm quick fade-back**（fade_sec = **`LOOT_BGM_TRANSITION_SEC` default 0.25s**，比 1.0s default 快，令 reward 快啲落 calm bed）→ (2) loot fanfare 喺 rest_calm 上播 + duck **rest_calm**（**唔係** duck boss_theme — boss_theme 已 fade 走）。**Pillar 3 直接要求**：loot dopamine peak 需要 calm sonic space，boss_theme 作為底床大幅削弱 reward 嘅 emotional clarity（frequency masking + 持續「危險」信號）。from-state 判斷：AudioManager `_on_gsm_state_changed(from, to, payload)` 中，to == LOOT_DROP && from == BOSS_ENCOUNTER → 觸發 quick fade。**Forward contract：需 #1 GSM `state_changed` payload 包含 from-state，已存在（ADR-0006 signal signature `(from, to, payload)`）✓**；需 #15 LootDrop GDD 確認「boss kill → LOOT_DROP」嘅 GSM transition 確實由 BOSS_ENCOUNTER 進入（co-design marker）。
  - **從非 BOSS_ENCOUNTER 進入**（workout 期間普通 loot drop，底下已係 focus_low）：維持當前 BGM（現有行為）——focus_low 係 calm 嘅，stinger duck 已足夠。
  - **注**：戰鬥中途掉落（仍 BOSS_ENCOUNTER，**無** state transition）= Visual/Audio「情境 B」，fanfare duck boss_theme（刻意設計），由本 Rule 處理唔到（無 transition）→ 純 Rule 7 ducking 行為。

Map 無 entry 嘅 state → 維持當前 BGM。Initial-state sentinel → noop。Q2（完整 state→track map）owner = game-designer + audio-director。

**Rule 7 — Ducking**：高優先 SFX（loot fanfare / boss stinger）播放時，Music bus 暫 duck，duck 完 release 還原，令 reward peak 突出（Pillar 3）。約束：
- **(a) Stinger 一律 SFX bus（[audio-director] BLOCKING）**：所有 stinger（loot / boss）必行 **SFX bus**，ducking 只壓 **Music bus**。**禁止** stinger 行 Music bus（否則 duck 緊自己，殺 Pillar 3 唯一 peak）。CI + AC enforce。
- **(b) Release 由 SFX `finished` **或** steal 觸發（[game-designer] RECOMMENDED + [godot-specialist] Pass 2 BLOCKING）**：duck release **唔用固定時長**,而係該 high-priority SFX 嘅 `AudioStreamPlayer.finished` signal 觸發(rarity-tiered loot fanfare 長度不一,epic 長過 `RELEASE_SEC`,固定 lerp 會喺 fanfare 中途還原 music,muddy 咗 peak)。`RELEASE_SEC` / `SHALLOW_RELEASE_SEC` 只係 release lerp-back 時長。**⚠ steal 安全**:若 ducking voice 被 voice-steal(Rule 3),`finished` **唔會** emit → steal 路徑必須觸發同一 release 減 refcount(否則 permanent duck)。
  - **短 stinger 用 `SHALLOW_RELEASE_SEC`（[audio-director] Pass 2 RECOMMENDED — pumping hazard）**:`mid` priority + 短 high stinger(如 COMMON loot ~0.4s)若用 full `RELEASE_SEC=0.4`,duck 總時長(attack 0.05 + body 0.4 + release 0.4 ≈ 0.85s)**長過 SFX 本身**,60+ COMMON drop/session 造成可聞 pumping。短 stinger 改用 `SHALLOW_RELEASE_SEC`(default 0.15)。
- **(c) 單一 retained Tween（非 `_process`）+ idle gate（[godot-specialist] + [performance-analyst] Pass 2 BLOCKING — 合流）**：refcount overlap 用**單一 retained `tween_method` Tween**(handle 存成員,跟 Rule 4 pattern) lerp-toward-target dB,**唔用 `_process()` per-frame lerp**(frame-rate-dependent settle time + idle 浪費)亦**唔用多條疊加 Tween**(競態)。
  - **frame-rate independence（⚠️ [godot-specialist] Pass 3 BLOCKING — `bind()` 修正）**：bus-level duck 必須用 **lambda closure**：`tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(music_idx, db), from_db, to_db, sec)`。**禁止** `AudioServer.set_bus_volume_db.bind(music_idx)` — Godot 4.x `bind()` APPENDS args，展開成 `set_bus_volume_db(dB_float, music_idx)`（bus_idx 收到 dB，volume 收到 index）→ ducking 靜默失效，GUT spy 可能 phantom-pass（見 memory 教訓）。
  - **idle gate**:無 active duck(refcount==0 且已到 base)時,**kill tween + 唔再 spawn**,杜絕 idle(90%+ session)每 frame 狂 call `AudioServer.set_bus_volume_db`。若 refcount 喺 lerp 途中升返（新 stinger），kill 舊 duck tween + respawn 由當前 bus dB 起（latest-wins，同 Rule 4 crossfade pattern）。
  - **de-escalation = recompute-on-release（[systems-designer] Pass 2/3/4 收斂修正）**：duck 狀態用 **`_active_ducks: Dictionary[voice_handle → offset_float]`** 追蹤（multiset 語意，**唔係** deduplicated Set — 兩件 high stinger 同 −8dB 須各佔一個 handle entry，去重會令第一件 release 就清空 dict → duck 提早還原，殺 Pillar 3 peak）。操作順序（**必須嚴格依序**，唔可調換）：
    1. **先** `_active_ducks.erase(finishing_handle)`（移除完成嘅 voice）
    2. **再** `new_target = _compute_duck_target(_active_ducks)`（空 dict → `base_music_db`；非空 → `max(base + min(values()), MUTE_FLOOR_DB)`）
    3. **最後** kill 舊 duck tween + respawn 由當前 bus dB lerp toward new_target
    
    若操作順序錯（先 recompute 後 erase），finishing voice 嘅 offset 仍在 dict → target 計算包含了已完成嘅 offset → music 唔 step（AC-15 fail）。
    
    **`_release_duck(handle)` 天然 idempotent**（`Dictionary.erase(absent_key)` 係 no-op）→ steal path + `finished` path 都呼叫 `_release_duck(handle)`，雙重 call 安全，無 under-duck 風險。refcount = `_active_ducks.size()`（唔係獨立 counter，size 自動正確）。
    
    例：loot(handle_L, −8) + streak(handle_S, −5) 兩個 active → `min(−8,−5)=−8` → target `max(−6+(−8),−80)=−14dB`；loot 完（erase handle_L → dict 剩 {handle_S:−5}）→ 重算 `min(−5)=−5` → target **`max(−6+(−5),−80)=−11dB`**（分級 step 由 −14 回 −11）；streak 完（erase handle_S → dict 空）→ `_compute_duck_target({}) = base_music_db = −6dB`（全還原）。

**Rule 8 — Foundation no-throw**：未知 `event_id`/`track_id` → push_warning + no-op + `_unknown_event_count++`，永不 crash（同 #5/#6/#7/#8 一致）。

**Rule 9 — Volume persistence**：`set_bus_volume_db`/`set_bus_muted` 寫 `audio.*` namespace via PersistenceLayer（`audio.master_db` / `audio.music_db` / `audio.sfx_db` / `audio.*_muted`）；boot 時 load。

### States and Transitions

> 📌 **Two orthogonal axes（[game-designer] Pass 2 BLOCKING fix）**：audio lifecycle = **(1) GSM service state**(BOOTING / READY / SUSPENDED) × **(2) `_audio_unlocked` flag**(false=LOCKED-equivalent / true)。LOCKED **唔係** GSM axis 上嘅獨立 state,而係 `is_web AND NOT _audio_unlocked` 嘅 derived gate。兩軸正交 → SUSPENDED 可同「未 unlock」共存,resume 後 unlock 路徑唔被吞。

| State / Gate | Entry | Behaviour |
|-------|-------|-----------|
| **BOOTING** | autoload `_ready()` | load catalogs + persisted volumes + subscribe GSM；無出聲；`is_audio_unlocked()→false` |
| **LOCKED**（derived gate：web 且 `_audio_unlocked==false`） | BOOTING 完 + web 且未 gesture | AudioContext suspended；`play_bgm` defer（single-slot latest-wins）；`play_sfx` drop+warn（**#20 HUD 顯示 silent-mode banner 引導首 tap**）；`set_bus_volume` work（persist）；引擎喺首 InputEvent 自動 resume context。**可同 SUSPENDED 共存**(見下) |
| **READY** | first gesture set `_audio_unlocked=true`（或 desktop boot 即達） | 正常服務：SFX pool + BGM crossfade + ducking + GSM music transition |
| **SUSPENDED** | GSM → SUSPENDED、OS `NOTIFICATION_APPLICATION_PAUSED`、或 `NOTIFICATION_WM_WINDOW_FOCUS_OUT`（任一 source — **三源 multi-source 去重**） | pause 全部 audio + 記住當前 BGM state。**`_suspend_sources` bitmask**（bit 0 = GSM，bit 1 = OS `NOTIFICATION_APPLICATION_PAUSED`，**bit 2 = `NOTIFICATION_WM_WINDOW_FOCUS_OUT`**）：任一 source set → 若 bitmask 0→non-zero 先 pause + 記 BGM state（first-entry latch）；任一 source clear → 若 bitmask 降到 0 先 resume + 還原 BGM（last-exit）。**`_handle_focus_change(paused: bool)` 走同一 bitmask**（set/clear bit 2）。**`_suspended_bgm_state: {variant_id: StringName, position_sec: float}`**（唔係單純 track_id — BLK-1/BLK-7 升級：須記 variant + position 先可 resume-from-position + non-looping stream 安全 seek）。resume → 還原 BGM 到原 variant + position。**`_audio_unlocked` flag 不受 SUSPENDED 影響** |

**Arcs**：`BOOTING→(LOCKED gate)`（web 未 unlock）/ `BOOTING→READY`（desktop / native 即 unlock）；`(LOCKED gate)→READY`（first gesture set flag，emit `audio_unlocked` + `audio_unlock_confirm` + 起 GSM-current BGM）；`READY↔SUSPENDED`（任一 bitmask source）。
**LOCKED × SUSPENDED 共存（[game-designer] Pass 2 BLOCKING — 最常見 mobile 入場 hole）**：web load 後未 tap 就 background → bitmask source（GSM / focus_out / OS pause）任一 fire，同時 `_audio_unlocked==false`。SUSPENDED 覆蓋 service（pause），但 **`_audio_unlocked` flag 保持 false**；resume 後仍處 LOCKED gate，deferred slot 保留，首 gesture 照樣 unlock + 起 GSM-current track。**杜絕永久靜音**。`SUSPENDED 永遠覆蓋 service axis`（同 #6/#7/#8 posture），但**唔覆蓋 unlock flag axis**。

### Interactions with Other Systems

1. **#1 GameStateMachine**（upstream）：`connect_for_initial_state(_on_gsm_state_changed)`；state→track map；sentinel noop。**唔**用 plain `.connect`（ADR-0006 C6，CI enforced）。
2. **#3 PersistenceLayer**（up/down）：只讀寫 `audio.*` namespace（volume / mute）；其他 namespace forbidden。
3. **#5 Particle / #6 ScreenEffects / #8 Streak / #15 LootDrop / #25 Combat Visual Feedback**（downstream callers）：call `play_sfx(event_id)` co-trigger；`event_id` 由各自 GDD 約定（滿足 particle-system-wrapper.md「audio direction co-trigger contract」）。
4. **PlatformDetect**（pos 3）：query mobile / web → 決定 unlock 策略（web 要 gesture，desktop/native 即 unlock）。
5. **Forbidden coupling**：gateway 外無人掂 `AudioServer` / `AudioStreamPlayer`（CI `check_audio_callers.gd`）；AudioManager 唔讀 game state（只認 GSM signal + 自己 closed API）；唔訂閱 GSM 以外嘅 gameplay signal。

## Formulas

> *Reviewed by `systems-designer` (design-review 2026-06-01) — boundary hardening applied below. Engine `tween_method` note per `godot-specialist`.*

> 📌 **Tween API note（[godot-specialist] Pass 3 BLOCKING 修正）**：
> - **bus-level ducking**（AudioServer 無 property setter）：用 **lambda closure**：`tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db), from_db, to_db, sec)`。**禁止** `.bind(bus_idx)` — Godot `bind()` append args，參數反轉（見 Rule 7c）。
> - **player-level BGM crossfade（Formula 1 equal-power）**：用 `tween_method` 喺 normalized `p`（0→1）空間，callback 內計算：`player_out.volume_db = linear_to_db(cos(p * PI/2))`；`player_in.volume_db = linear_to_db(sin(p * PI/2))`。**禁止** `tween_property(player, "volume_db", from_db, to_db, sec)` — 呢個係 linear dB ramp，中點 ≈ −40dB（幅度 ~0.01），違反 Formula 1 equal-power（中點應 −3dB 無 dip）。
> - mid-crossfade **source-of-truth + writer contract（[godot-specialist] Pass 4 BLOCKING）**：維護 `_crossfade_progress: float` 成員；**tween_method callback 必須每 step 同時 update**：`player_out.volume_db = linear_to_db(cos(p * PI/2)); player_in.volume_db = linear_to_db(sin(p * PI/2)); _crossfade_progress = p`（三件事原子 inline）。**終點處理（endpoint sentinel）**：crossfade `finished` callback 顯式 hard-set 終態：`player_out.stop()`（唔靠 `cos(π/2) ≈ 6.12e-17 → −324dB` 殘值）+ `player_in.volume_db = base_music_db` + `_crossfade_progress = -1.0`（sentinel：負值表示「目前無 crossfade in-flight」）。kill+respawn 路徑讀 `_crossfade_progress`：**若 `< 0.0`**（sentinel 判斷用 `< 0`，**唔用 `== -1.0`** 浮點等號比較，Pass 5 recommendation）→ 從 full-gain 起（單一 active player）；若 ∈ (0,1) → 從 `cos(_crossfade_progress·π/2)` / `sin(_crossfade_progress·π/2)` 起（partial mix）。**kill 後唔係**直接讀 `player.volume_db`（dB 空間反算 p 有精度損失）。**2-player mid-crossfade interrupt rule**：若 A→B crossfade 中途 `play_bgm(C)` 到達，AudioManager 只有 2 個 BGM player，無法同時保留 A+B+C 三條。處理：kill 嗰刻 drop 較小 gain（`sin(_crossfade_progress·π/2)` in-player）立即 stop，保留較大 gain（out-player 或 in-player 視 progress）做唯一 out-source，由此 out-source → C 起新 crossfade。

### Formula 1 — Equal-power BGM crossfade gain

`p_clamped = clamp(p, 0.0, 1.0)` ， `out_gain(p) = cos(p_clamped · π/2)` ， `in_gain(p) = sin(p_clamped · π/2)`

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `p` | float | 0–1 | crossfade 進度 = elapsed / fade_sec |
| `out_gain` | float | 1→0 | 舊 track 線性 gain |
| `in_gain` | float | 0→1 | 新 track 線性 gain |

**Output**：`out_gain² + in_gain² = 1`（equal-power，perceived loudness 恆定，中段無音量 dip）。**Example**：p=0.5 → out=in=0.707（−3 dB each），總能量守恆。

**Boundary protection（[systems-designer] BLOCKING）**：`fade_sec ≤ 0` → **instant-swap**（直接套 p=1，舊 track 即停、新 track 即 full gain），**唔做** `elapsed / 0` 除零（NaN gain → 靜音 / click）。`p` 入公式前 `clamp(p, 0, 1)` 防 caller `elapsed > fade_sec` 令 cos 翻負。

**Endpoint hard-set（[systems-designer] Pass 4 RECOMMENDED — implementer trap 防護）**：`cos(π/2)` 浮點殘值 ≈ `6.12e-17`，`linear_to_db(6.12e-17) ≈ −324dB`（唔係 0dB），若 tween 靠 trig 自然逼近終點，`player_out.volume_db` 設成 −324dB 而非 stop。雖然 −324dB 實際係靜音唔 click，但喺某些 AudioServer 內部可能產生 float edge case。**修正**：crossfade tween 嘅 `finished` callback **顯式 hard-set 終態**：`player_out.stop()` + `player_in.volume_db = base_music_db` + `_crossfade_progress = -1.0`（sentinel）。唔依賴 trig 殘值。

### Formula 2 — Volume slider (0–1) → dB

`s_safe = (is_nan(s) or is_inf(s)) ? 0.0 : clamp(s, 0.0, 1.0)`
`volume_db(s) = (s_safe ≤ 0) ? MUTE_FLOOR_DB : clamp(linear_to_db(maxf(s_safe, 0.0001)), MUTE_FLOOR_DB, MAX_BUS_DB)`

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `s` | float | 0–1 | settings slider 值 |
| `MUTE_FLOOR_DB` | float | −80（const） | 靜音地板 |
| `MAX_BUS_DB` | float | 0（const，single source-of-truth） | 上限（防 clipping，預設禁 boost） |
| `volume_db` | float | −80–0 | 套落 bus 嘅 dB |

**Output**：s=1 → 0 dB，s→0 → −80 dB。**Example**：s=0.5 → `linear_to_db(0.5)` ≈ −6.02 dB（用 Godot 內建 `linear_to_db`，perceptual-ish）。

**Boundary protection（[systems-designer] + [godot-specialist] RECOMMENDED）**：(a) `is_nan(s)` **同 `is_inf(s)`** guard 入口（NaN/±inf 皆會穿透 `clamp` → bus 設 NaN/inf dB；Pass 5 recommendation：`is_inf` 唔好漏，corrupt persisted value 可能係 inf）；(b) `maxf(s_safe, 0.0001)` 防 `linear_to_db(0) = −inf` 污染插值（−inf 餵 tween 會爆）；(c) upper-clamp 引用常數 `MAX_BUS_DB`（**唔 hardcode 0.0**）。

> ⚠️ **`MAX_BUS_DB=+6` boost 唔可達(透過此 formula)（[systems-designer] Pass 2 RECOMMENDED — dead range 修正）**：`linear_to_db(s)` 喺 `s≤1` 永遠 `≤0dB`,而 slider `s` 已 clamp 到 `[0,1]` → 即使 `MAX_BUS_DB` 改 +6,**此 formula 最大輸出仍 0dB**(upper-clamp 變 dead range)。要真正開 boost,需**獨立 gain mapping**(slider 重映射到 `>1` linear,或 `set_bus_volume_db` 直接收 boost dB)。**現行 MVP default `MAX_BUS_DB=0`(禁 boost)係正確且安全**;Tuning Knobs 表嘅「+6 開 boost」係 *future capability flag*,需配 separate mapping,非單改常數即生效。

### Formula 3 — Ducking target + release

duck 期間 Music bus 目標（使用 `_active_ducks: Dictionary[voice_handle → offset_float]`，multiset 語意）：
- **空 dict（無 active duck）**：`duck_target = base_music_db`（guard：`_active_ducks.is_empty()` → 直接還原 base，**唔呼叫 `min([])`** — GDScript `min([])` 回 null → runtime error；[systems-designer] Pass 4 BLOCKING）
- **單 duck**：`duck_target = max(base_music_db + DUCK_OFFSET_DB, MUTE_FLOOR_DB)`
- **多 duck 疊加（de-escalation）**：`duck_target = max(base_music_db + min(_active_ducks.values()), MUTE_FLOOR_DB)`（`min(values())` 因為 offset 係負數，最深 = 絕對值最大 = **min，唔係 max**；**values() 係 multiset，唔去重** — 兩件 −8dB stinger 保持兩個 entry，各自 erase by handle）

完整 formula：`_compute_duck_target(ducks_dict: Dictionary) -> float = ducks_dict.is_empty() ? base_music_db : max(base_music_db + min(ducks_dict.values()), MUTE_FLOOR_DB)`

Attack 用 `ATTACK_SEC` lerp 落，release（high-priority SFX `finished` 或 steal 後，經 `_release_duck(handle)` 觸發）用 `RELEASE_SEC` / `SHALLOW_RELEASE_SEC` lerp 還原。

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `base_music_db` | float | −80–0 | Music bus 正常 dB（default −6）。**邊界**：`base_music_db == MUTE_FLOOR_DB(−80)` 時 duck_target == base → duck 自然失效（已靜音無得再壓），intended 非 bug |
| `_active_ducks` | Dictionary[int→float] | handle→offset | per-voice-handle dict（multiset 語意）；`min(values())` = 最深 offset；**空 dict → guard 返 base**（唔呼叫 `min([])`） |
| `DUCK_OFFSET_DB` | float | −12–0（default −8） | high-priority duck 衰減量 |
| `STREAK_CHIME_DUCK_OFFSET_DB` | float | −6 – −3（default −5） | mid-priority（streak_chime）淺 duck offset |
| `ATTACK_SEC` | float | 0.02–0.2（default 0.05） | duck 落 attack（setter clamp 下限 0.02，防 0s instant-jump） |
| `RELEASE_SEC` | float | 0.1–1.0（default 0.4） | 長 SFX `finished` 後嘅 lerp-back 時長 |
| `SHALLOW_RELEASE_SEC` | float | 0.05–0.3（default 0.15） | 短 stinger（mid priority / COMMON loot ~0.4s）嘅 lerp-back 時長 |

**Output**：base −6 + duck −8 = duck 期間 −14 dB。**Example**：loot fanfare → attack 0.05s 內 duck 到 −14 dB，**fanfare `finished` signal 觸發後**（非固定時長）0.4s lerp 返 −6 dB。

**Boundary protection**：`duck_target` 用 `max(..., MUTE_FLOOR_DB)` 防穿地板（base −80 + offset −12 = −92 dB < −80；duck target 係內部 computed 繞過 `set_bus_volume_db` 入口 clamp）。`ATTACK_SEC` / `RELEASE_SEC` setter clamp 落各自 safe range 下限。**`_release_duck(handle)` idempotent**：`Dictionary.erase(absent_key)` 係 no-op，steal + `finished` 雙路徑安全。
**`_register_duck(offset)` 正數 guard（IB-3 [systems-designer] BLOCKING）**：duck offset 語意係**衰減量**，必須 `≤ 0`。若 caller 誤傳正數（如 `+8`），`base + (+8)` 會令 Music bus 反向**升** 8dB（破壞 Pillar 3 reward peak 對比 + 可能 clip）。`_register_duck` 入口 `assert(offset <= 0.0)`（debug build 即捕捉 caller bug）+ production 防呆 `stored_offset = clamp(offset, MUTE_FLOOR_DB, 0.0)`（正數 clamp 到 0 = 無效 duck，唔升 music）+ push_warning 一次。`_compute_duck_target` 只見 clamped 值，故公式輸出永不超過 `base_music_db`。對應 **AC-09d**。

## Edge Cases

- **If `play_sfx(event_id)` 收到未知 event_id**：push_warning + no-op + `_unknown_event_count++`，唔 crash（Foundation no-throw）。
- **If `play_bgm(track_id)` 而 track_id 已經正播**：no-op（唔重啟、唔重新 crossfade）。
- **If `play_bgm` 喺 LOCKED（unlock 前）**：存入 single-slot deferred（latest-wins）；unlock 後先起。多個 pre-unlock call → 只記最後一個。
- **If `play_sfx` 喺 LOCKED**：直接 drop + push_warning（one-shot 唔 defer）。**注**：刻意丟棄（fantasy「silent until gestured」），但 LOCKED window 須極短 + #20 banner 引導首 tap，避免食咗玩家首組嘅 hit/streak feedback（design-review [game-designer] BLOCKING）。**唔做** stale SFX replay。
- **If SFX pool 全忙**：**priority-aware** steal — 先揀最低 priority 嘅 active voice,同 priority 揀最舊(Rule 3)。**high-priority(loot fanfare / boss stinger)唔可俾 lower steal**(保 Pillar 3 peak)。被 steal 嘅 voice 若曾 increment duck refcount → steal 路徑顯式減 refcount(防 permanent duck)。
- **If 連續 `play_bgm(A)` 再 `play_bgm(B)`（A crossfade 未完）**：先 `kill()` retained crossfade Tween(防 autoload Tween 競寫),再由「當前實際 audible 混合態」crossfade 去 B（latest wins，唔 stack，只一條 active Tween）。
- **If GSM → SUSPENDED 喺 crossfade 中途**：kill crossfade tween + pause 全部 + 記住目標 variant + position（`_suspended_bgm_state`）；resume 時由目標 variant + position 還原（唔會卡喺半 crossfade 態）。
- **If SUSPENDED / `_handle_focus_change(false)` 喺 duck 進行中（IB-8 [godot-specialist BLK-P5-1]）**：suspend 嗰刻 **kill duck Tween**（同 crossfade tween 一齊 kill）+ Music bus dB **hard-set 到 `base_music_db`**（唔留喺半 duck 態 −14dB，否則 resume 時 bus 卡喺壓低值而 `_active_ducks` 可能已被處理）。⚠️ **`_active_ducks` dict 本身唔清**（仍記住 suspend 前 active 嘅 voice handles）。resume 時：若 `_active_ducks` 非空（suspend 期間 voice 理論上仍「邏輯 active」），由 `_compute_duck_target(_active_ducks)` **重算** target + 重新 spawn duck tween lerp 落去；若 suspend 期間該 voice 嘅 `finished`/steal 已 release（dict 空）→ resume 後 `_compute_duck_target({}) == base_music_db`，bus 已喺 base，無 op。對應 **AC-33**。
- **If BOSS_ENCOUNTER 期間 SUSPENDED（`_paused_focus_low` × `_suspended_bgm_state` 獨立性 — IB-6 [audio-director BLK-5-4]）**：BOSS_ENCOUNTER 時 boss_theme 正播、focus_low 已 paused（`_paused_focus_low = {variant_id, position_sec}` 記住）。此刻若 SUSPENDED → `_suspended_bgm_state` 記低**當前正播嘅 boss_theme**（variant + position）；`_paused_focus_low` **保留原值唔變**（仍記 focus_low 嘅 variant + position）。**兩個 field 各記各，唔互相覆蓋**：`_suspended_bgm_state` = suspend 嗰刻 audible track（boss_theme）；`_paused_focus_low` = boss-exit re-entry 用嘅 focus_low resume point。resume → 還原 boss_theme（`_suspended_bgm_state`）；之後若 boss 死轉 WORKOUT_ACTIVE → 用 `_paused_focus_low` resume-from-position（Rule 4 boss-exit policy）。對應 **AC-34**。
- **If `workout_complete` 同 `loot_fanfare_*` 時序重疊（EG-4 — workout 完同時 roll 到 loot）**：兩者皆 high priority + STEREO（fanfare）/ mono（workout_complete）。`workout_complete` 定位「莊重 resolved」，`loot_fanfare` 定位「dopamine peak」——情緒維度不同（見 catalog rationale），**唔互相 steal**（priority-aware steal 同 priority 揀最舊；但兩者通常唔同 frame，且 8 voice pool 容得落）。Duck：兩者各 `_register_duck`（multiset，唔去重）→ `min(values())` 取最深 → Music 壓到最深嗰個（通常 loot −8 深過 workout_complete 若亦 −8 則相同）。時序裁決：**workout_complete 先響（workout 結束係 trigger），loot fanfare 隨後（backend roll loot 有 latency）**——天然錯開，無需強制 stagger。若極端同 frame，兩 STEREO/mono high SFX 疊加 = 雙 reward 體驗（接受，唔係 bug，同情境 B「興奮疊加」一致）。**唔 duck 對方**（兩者皆 SFX bus，duck 只壓 Music bus，Rule 7a）。Craft：sound-designer 確保兩者 frequency 唔完全 mask（Q8）。
- **If BOSS_ENCOUNTER → WORKOUT_ACTIVE re-entry（focus_low boss-exit）**：focus_low 唔係「正播」（已 crossfade-out 去 boss_theme），Rule 4 idempotent 唔 trigger。AudioManager 檢查 `_paused_focus_low` — 若有記錄：seek same variant to position_sec + crossfade 進去（resume-from-position，seamless continuity，守「BGM 一直低沉」promise）；若無（首次 WORKOUT_ACTIVE）：fresh start + rotate。[game-designer + audio-director] BLK-7。
- **If GSM → LOOT_DROP from BOSS_ENCOUNTER（情境 A，先 fade 後 duck — IB-1）**：`_on_gsm_state_changed(from=BOSS_ENCOUNTER, to=LOOT_DROP)` → **先** boss_theme → rest_calm quick fade-back（**`LOOT_BGM_TRANSITION_SEC` = 0.25s**，非 1.0s default）→ **後** 播 stinger + duck **rest_calm**（boss_theme 已 fade 走，唔 duck boss_theme）。確保 loot fanfare 喺 calm bed 上，唔係緊張 boss bed。[audio-director + game-designer] BLK-8 + IB-1 CD 裁決。
- **If loot drop 喺 BOSS_ENCOUNTER 期間但無 state transition（情境 B，mid-fight loot）**：GSM 仍喺 BOSS_ENCOUNTER（boss 未死），boss_theme 仍播 → loot fanfare duck **boss_theme**（純 Rule 7 ducking，無 BGM transition）。呢個係**刻意設計**（Pillar 3 > boss tension，loot peak 永遠贏）。同情境 A 由「有冇 GSM transition」區分。[IB-1]
- **If `set_bus_volume_db` 超範圍**：clamp 到 `[MUTE_FLOOR_DB(−80), MAX_DB(0)]`（唔容許 boost 過 0 dB 防 clipping）+ push_warning。
- **If 兩個 ducking SFX 重疊（de-escalation = recompute-on-release）**：`_active_ducks = {handle_L:−8, handle_S:−5}`（multiset，**唔去重** — 兩件同 −8dB stinger 各佔一個 handle entry）→ `min(values())=−8` → target `max(−6+(−8),−80)=−14dB`；loot 先完（erase handle_L，strict order: erase → recompute → lerp；dict 剩 {handle_S:−5}）→ 重算 `min(−5)=−5` → target `max(−6+(−5),−80)=**−11dB**`（music 分級 **step** 由 −14 回 −11）；streak 亦完（erase handle_S，dict 空）→ `_compute_duck_target({}) = base_music_db = −6dB`（全還原）。**`_active_ducks.size()==0` = refcount 0，先 release 還原 base**。
- **If GSM state 喺 track-map 無 entry**：維持當前 BGM（無變、無 warning）。
- **If catalog resource（`SfxCatalog`/`BgmCatalog`）boot 時缺失**：push_error 一次 + 進入 safe no-op 模式（所有 play 變 no-op），永不 crash。
- **If persisted volume 缺失/corrupt**：fallback 去 defaults（Master 0 / Music −6 / SFX 0）。
- **If tab backgrounded（Web `NOTIFICATION_WM_WINDOW_FOCUS_OUT`）但 GSM 未發 SUSPENDED**：`_handle_focus_change(false)` **set `_suspend_sources` bit 2**（走同一 bitmask，防同時 GSM SUSPEND 嘅 double-pause）→ bitmask 0→non-zero 觸發 pause + 記 track；focus 返 `_handle_focus_change(true)` clear bit 2 → 若 bitmask 降 0 resume。**AC-24a** 測 pure function `_handle_focus_change`；**AC-24b** ADVISORY 測 OS notification wiring。
- **If web load 後未 tap 就 background（LOCKED × SUSPENDED 共存，[game-designer] Pass 2 BLOCKING）**：`_audio_unlocked==false` 同時 GSM/notification SUSPENDED。SUSPENDED pause service,但 **`_audio_unlocked` flag 保持 false**;resume 後仍 LOCKED gate,deferred BGM slot 保留。首 gesture → unlock + `audio_unlock_confirm` + 起 GSM-current BGM。**唔會永久靜音**(正交雙軸保證 unlock 路徑唔被 SUSPENDED 吞)。
- **If pre-unlock 期間 GSM state 快速 churn（如 WORKOUT→短暫 BOSS→WORKOUT）**：unlock 時**唔補播 deferred track,而重 query GSM 當前 state** 起對應 BGM(防起咗已結束 encounter 嘅 boss_theme)。deferred slot 只做 GSM 無 map entry 時 fallback。

## Dependencies

**Upstream（此系統依賴）**
- **#1 GameStateMachine** — *soft*：經 `connect_for_initial_state` 訂閱 state 做 music transition。缺失 → 無 auto music transition，但 `play_bgm` 直接 call 仍 work（degrades gracefully）。Interface：`state_changed(from, to, payload)`。
- **#3 PersistenceLayer** — *soft*：`audio.*` namespace 持久化 volume/mute。缺失 → 用 defaults。Interface：`read/write(audio.*)`。
- **PlatformDetect（pos 3）** — *soft*：query mobile/web 決定 unlock 策略。缺失 → 安全假設「需要 gesture unlock」。
- **`SfxCatalog.tres` / `BgmCatalog.tres`（data）** — *hard*：`event_id`/`track_id` → AudioStream 對照。缺失 → safe no-op 模式（EC）。

**Downstream（依賴此系統 — 呢啲 GDD 應反向列「depends on #4」）**
- **#5 Particle / #6 ScreenEffects / #8 Streak / #15 LootDrop / #25 Combat Visual Feedback** — call `play_sfx(event_id)` co-trigger。
- **#20 Gym-Mode HUD / Settings screen** — host volume slider UI（call `set_bus_volume_db` / `get_bus_volume_db`）。
- **#29 Mirror Moment** — 可能 trigger ceremony BGM/stinger。

**Bidirectional flag**：上述 consumer GDD 嘅 Dependencies section 應列「depends on #4 AudioManager (SFX co-trigger)」。particle-system-wrapper.md 已有「audio direction co-trigger contract」⇒ 一致。

**⚠️ Forward contract — workout SFX forwarding during LOCKED（[game-designer] Pass 4 BLOCKING — BLK-B1; ownership RESOLVED 2026-06-03 via EG-1 — Option B）**：AudioManager 喺 LOCKED 期間 drop `play_sfx`（Rule 5，intentional）。但 #2 GymSys HTTP polling（5s interval，ADR-0002）可在 first screen tap 之前推送 `set_logged`/`streak_updated` event，觸發 `set_complete`/`streak_chime` SFX request。第一組 set 嘅 SFX 靜音 → 破壞「每個真實動作都有聲音回應」（Player Fantasy core promise + Pillar 1）。

**解決方案（[creative-director] 裁決 + EG-1 ownership 修正 2026-06-03）**：由**真正 call `play_sfx` 嘅 presentation-layer audio-trigger consumer** 持 high/mid priority workout SFX（`set_complete`、`streak_chime`、`workout_complete`）直到收到 AudioManager `audio_unlocked` signal，再 forward 呼叫 `play_sfx`。AudioManager 自身保持 stateless gateway（唔做 time-windowed defer-replay，保持 Rule 5 架構），enforcement 落喺 SFX-emitting consumer 端。

> ⚠️ **NOT #9 WorkoutStateTracker（EG-1 conflict 裁決）**：#9 係 locked **pure data/event layer**（workout-state-tracker.md CD-praised「至今最 architecturally sound」；GDD 明文「任何 visual/audio 直接綁定 #9 = architectural smell」）。#9 **永不** call `play_sfx`、永不 subscribe `audio_unlocked`、永不 buffer SFX。佢只 forward workout events（`workout_completed_forwarded` / `workout_summary_available`），而 per-set 事件由 consumer **直接訂 `#2.set_logged`**（先例：#18 PR Detection 直接訂 #2，唔經 #9 — workout-state-tracker.md line 493）。先前「#9 forwarding layer」嘅 wording 同 #9 purity invariant 衝突，已撤回；ownership 搬去 presentation-layer consumer。

**Contract（presentation-layer audio-trigger consumer 必須實現 — assign 去 #20 Gym-Mode HUD GDD，與 EG-2 收口；或 dedicated workout-feedback adapter）**：
- Subscribe `AudioManager.audio_unlocked`（或 poll `is_audio_unlocked()` on each SFX trigger point）+ subscribe `#2.set_logged` / #9 forwarded workout events 做 SFX trigger source
- LOCKED 期間 hold pending mid/high SFX call（queue 或 defer）；`audio_unlocked` emit → flush pending calls
- `low` priority SFX 仍 drop（唔 buffer，唔影響 P1/P2）；只 buffer `mid/high`（`workout_complete` high / `streak_chime` mid / `set_complete` 視最終 priority）
- **`set_complete` × `streak_chime` 同-frame stagger（IB-5）**：由呢個 consumer adapter 負責（佢係兩個 SFX 嘅 funnel，知道 same-frame timing）— 若同 frame fire 兩者，自行 delay 其中一個 `play_sfx` call 80-120ms（AudioManager 唔做 delay，stateless gateway）。
- **此 contract = #20 Gym-Mode HUD GDD authoring prerequisite（EG-2 範圍；或 dedicated adapter）。#9 WST 無需 patch（保持 pure data layer）。**

**Indirect**：#2 GymSys workout events 唔直接入 AudioManager，而係經 presentation-layer audio-trigger consumer（+ #8/#15 等）中介 trigger SFX。

## Tuning Knobs

| Knob | Default | Safe range | 太高 / 太低 |
|------|---------|-----------|------------|
| `DEFAULT_MASTER_DB` | 0 | −20–0 | 高>0 clip；低 太細聲 |
| `DEFAULT_MUSIC_DB` | −6 | −18 – −3 | 高 搶 set 注意力（違 Pillar 2）；低 聽唔到氛圍 |
| `DEFAULT_SFX_DB` | 0 | −6–0 | 高>0 clip；低 feedback 唔夠 punchy |
| `MUTE_FLOOR_DB` | −80 | −90 – −60 | 太高 slider 最低仲有聲 |
| `MAX_BUS_DB` | 0 | 0（MVP 鎖）| Formula 2 upper-clamp single source。**+6 boost 需 separate gain mapping 先生效(此 formula 唔可達,見 Formula 2 註)**,MVP 鎖 0 禁 boost |
| `SFX_VOICE_COUNT` | 8 | 4–16 | 高 食 mixing CPU(memory 由 stream count 定,非 voice);低 voice steal 太頻（漏 SFX）。mobile 早期 profiling 可暫降 6（Q1） |
| `BGM_DEFAULT_FADE_SEC` | 1.0 | 0.3–3.0 | 高 transition 拖沓；低 突兀 |
| `DUCK_OFFSET_DB` | −8 | −12 – −3 | 深 music 幾乎消失；淺 reward peak 唔突出 |
| `DUCK_ATTACK_SEC` | 0.05 | 0.02–0.2 | 高 duck 反應慢蓋唔到 transient |
| `DUCK_RELEASE_SEC` | 0.4 | 0.1–1.0 | high/長 stinger 嘅 release lerp;高 music 遲還原;低 pumping |
| `SHALLOW_RELEASE_SEC` | 0.15 | 0.05–0.3 | **短 stinger(COMMON loot ~0.4s / mid)嘅 release**,防 duck 長過 SFX 本身 pumping([audio-director] Pass 2) |
| `BGM_MIN_LOOP_SEC` | 90 | 60–180 | 低 短 loop 重複疲勞（30-90min session）；高 asset 大 + bundle 風險。**Boot push_warning if track < min（非硬 reject，Foundation no-throw）+ CI build-time fail**（[game-designer] Pass 4 RECOMMENDED — boot warning 唔夠力：runtime warning 玩家唔睇，artist 忘記就 ship 30s loop × 180 次 fatigue；升 CI build-time lint 掃 BgmCatalog 所有 track loop_sec，任一 < min → CI fail，同 bundle-size CI gate 同一 enforcement posture，AC-27 對應） |
| `FOCUS_LOW_VARIANT_COUNT` | 3 | 1–4 | 低 rotation 單調(2 條 90min 聽 30× 仍疲勞);高 食 bundle（每 variant ~1.5-2.5MB,=4 撞 `MAX_BGM_BUNDLE_MB`） |
| `STREAK_CHIME_DUCK_OFFSET_DB` | −5 | −6 – −3 | 淺 duck 令 streak chime 聽到唔被 BGM 淹(default −3 係 JND 太淺,gym 噪音下聽唔到,Pass 2 深化 −5;比 loot −8 淺) |
| `BOSS_THEME_FADE_SEC` | 0.25 | 0.1–0.5 | per-state override；高 stakes signal 唔夠緊迫 |
| `LOOT_BGM_TRANSITION_SEC` | 0.25 | 0.1–0.5 | **IB-1**：LOOT_DROP from BOSS 嘅 boss_theme→rest_calm quick fade-back（情境 A）。獨立於 `BGM_DEFAULT_FADE_SEC`（1.0s 太慢，reward peak 等太耐先落 calm bed）；高 boss_theme 殘留太耐削弱 loot emotional clarity；低 過急轉 calm 顯突兀 |
| `MAX_BGM_BUNDLE_MB` | 10 | 6–16 | audio BGM bundle 軟上限（WASM 50MB 把關） |
| `state→track map` | data `.tres` | — | 錯 map → 錯 context music |

**互動**：`DEFAULT_MUSIC_DB` + `DUCK_OFFSET_DB` 疊加決定 duck 期間實際 music level（−6 + −8 = −14，且 `max(..., MUTE_FLOOR_DB)` 防穿地板）；`MUTE_FLOOR_DB` + `MAX_BUS_DB` 同 Formula 2 slider mapping 綁；`streak_chime` 用 `STREAK_CHIME_DUCK_OFFSET_DB`（淺 duck −5）而非 full `DUCK_OFFSET_DB`。
**Cross-knob 互鎖（[performance-analyst] Pass 2）**：`FOCUS_LOW_VARIANT_COUNT × BGM_MIN_LOOP_SEC`(每 variant size ∝ loop 長度) 同 `MAX_BGM_BUNDLE_MB` 三者互鎖 —— `VARIANT=4 × 90s @128kbps ≈ 撞 10MB soft cap`。改高任一個前要核 bundle budget,並靠 CI bundle-size gate(非人手) enforce。短 stinger(COMMON/mid)用 `SHALLOW_RELEASE_SEC` 而非 `DUCK_RELEASE_SEC`,防 duck 長過 SFX pumping。

## Visual/Audio Requirements

> *Reviewed by `audio-director` (design-review 2026-06-01) — SFX catalog freeze + BGM variation strategy added below.*

- **Palette philosophy**：warm、non-fatiguing（gym session 重複聽都唔煩）；SFX punchy + 短；loot fanfare 係唯一「大」moment（Pillar 3 peak）。

**BGM channel policy（[performance-analyst] Pass 4 RECOMMENDED — normative，令 bundle CI gate 可校準）**：BGM tracks = **STEREO**（ambient loop 嘅空間感 + seamless loop 需要 stereo width；亦係 cross-knob 互鎖估算 `~1.44MB/track·min@128kbps` 已假設嘅格式）。Bundle 估算：`FOCUS_LOW_VARIANT_COUNT(3) + boss_theme + rest_calm + 其他 state ≈ 5-8 tracks × 90s × 1.44MB/min ≈ 6-12MB`；CI gate 基準 = STEREO。SFX channel policy 見下 catalog 表。

**Loot fanfare × boss_theme — 兩個分開情境（IB-1 [audio-director BLK-5-3] 自相矛盾收口，CD 裁決）**：

⚠️ 先前 wording「loot fanfare duck boss_theme = 刻意設計」同 Rule 6「LOOT_DROP from BOSS → boss_theme fade to rest_calm」直接衝突（一個話壓住 boss_theme 仲播、一個話 fade 走 boss_theme）。CD 裁決 = **先 BGM transition，後 duck**，兩情境**唔同 trigger，分開 spec**：

- **情境 A — LOOT_DROP *state entry*（boss 死後正式進入 loot drop state）**：由 GSM `BOSS_ENCOUNTER → LOOT_DROP` transition 觸發（Rule 6）。執行順序 = **(1) 先** boss_theme → rest_calm quick-fade（`LOOT_BGM_TRANSITION_SEC` default 0.25s）→ **(2) 後** loot fanfare 喺已轉成 rest_calm 嘅 calm bed 上播 + duck **rest_calm**（唔再係 boss_theme）。Pillar 3 reward peak 落喺 calm space，emotional clarity 最高。**boss_theme 喺 fanfare 響起前已經 fade 走，唔存在「duck boss_theme」**。
- **情境 B — mid-fight loot drop（仍處 BOSS_ENCOUNTER state，boss 未死，boss_theme 仍播）**：戰鬥中途掉落（GSM 停喺 BOSS_ENCOUNTER，**無** state transition），loot fanfare（SFX bus）duck **boss_theme**（Music bus，Rule 7）。呢個情境先係**刻意設計**：Pillar 3 > boss tension continuity，loot peak 永遠贏；兩個 high-energy signal 疊加玩家感知做「興奮疊加」而非「衝突」。**明文 acknowledge，唔係 bug**。

**判別準則**：有 `BOSS_ENCOUNTER → LOOT_DROP` GSM transition = 情境 A（先 fade 後 duck rest_calm）；無 state transition（仍 BOSS_ENCOUNTER）= 情境 B（duck boss_theme）。兩者由 `_on_gsm_state_changed` 嘅 from/to 判斷區分（見 Rule 6 + EC）。

**BGM variation 策略（[audio-director] + [game-designer] BLOCKING — 30-90 分鐘抗疲勞）**：
- per-state low-intensity loop（idle ambient / workout `focus_low` / `boss_theme` 緊張 / `rest_calm` 組間休息），STEREO，seamlessly loopable。
- **每條 BGM loop 最短 `BGM_MIN_LOOP_SEC`（default 90s）** — 防短 loop 30+ 次重複疲勞。
- **`focus_low` 用 multi-variant rotation pool（MVP）**：**default `FOCUS_LOW_VARIANT_COUNT=3`**（90min=60 loops，3 variants → 每條聽 ~20×），同 key / tempo melodic 變化。`BgmCatalog` 以 variant array 表達。

> ⚠️ **BGM loop rotation 機制（[godot-specialist+audio-director] Pass 4 BLOCKING — 修正）**：`AudioStreamOggVorbis.loop=true` 永遠**唔** emit `finished`（Godot 4.6 confirmed）。「每 loop 結束 rotate」需要 loop-boundary signal hook，looped OGG 冇呢個 hook。**正確實現**：
> - BGM variant 以 **non-looping OGG**（`loop=false`）authoring + import
> - `AudioStreamPlayer.finished` signal（自然播完後 fire）→ AudioManager rotate 到下一個 variant（non-immediate-repeat）+ 用**第二個 BGM player**（已有，crossfade 架構）做 equal-power crossfade
> - ⚠️ **「gap-free」claim 收口（IB-2 [godot-specialist BLK-P5-2]）**：`finished` 係 Godot **deferred** signal（idle frame 先派發），純靠 `finished` 觸發 rotate 必然有 **~1 frame（~16ms @60fps）gap**，唔係真 gap-free。正確 wording = **「near-gap-free（≤1 frame）」**。若要真正無縫 loop boundary，須**提前** `fade_sec`（如 variant 結束前 `BGM_DEFAULT_FADE_SEC` 預先 schedule crossfade 起 second player），唔等 `finished`。MVP 接受 near-gap-free（≤1 frame，gym BGM ambient bed 聽唔出）；真無縫 = post-MVP 升級（須 stream length 預知 + 提前排程）。AC-29 只驗 rotation **順序**（non-immediate-repeat），唔斷言 zero-gap（headless 無法量 frame-level gap）。
> - 呢個重用現有 `_crossfade_tween` 架構：把「loop-boundary crossfade」同「state-transition crossfade」統一為同一機制
> - non-looping OGG authoring 要求：loop 點要 seamless（頭尾對齊），audio-director 負責 authoring spec
> - `_suspended_bgm_state`（**canonical member 名，Pass 6 統一** — 先前 AC-14/14b/30 誤寫 `_suspended_bgm_track`，已收口為單一名）從「track_id: StringName」升級為 **`{variant_id: StringName, position_sec: float}`**，SUSPENDED/resume 恢復到正確 variant + 播放位置（BLK-7 resume-from-position 亦依賴此）

> **non-immediate-repeat 算法**：每次 rotation 從 variant pool 中排除剛播完嘅 variant，再 random/sequential pick；確保冇相鄰兩次播同一條（AC-29 驗）。

⚠ 注意 `FOCUS_LOW_VARIANT_COUNT × BGM_MIN_LOOP_SEC` 同 `MAX_BGM_BUNDLE_MB` cross-knob 互鎖（見 Tuning Knobs 互動）。stem-based intensity ramp（隨 session 進度疊加 layer）標為 **post-MVP** 升級（Q-A1）。

**SFX catalog freeze（[audio-director] BLOCKING — Foundation 收貨前必須 freeze 完整 `event_id` 清單，否則 `SfxCatalog.tres` schema + voice pool 估算失準）**。下表為 freeze v0（每 entry 帶 `priority` field 供 ducking 判斷 [Q4 resolved] + `channels` field [mono/stereo]）：

> 🔊 **Channel policy（[audio-director] Pass 2 BLOCKING — mono 殺 P3 fanfare）**：combat / UI SFX = **mono**(慳 memory,空間感唔重要);但 **`loot_fanfare_*` + `boss_stinger` + `boss_phase` = STEREO**(mono collapse 咗 reverb tail + spatial width,令 Pillar 3 唯一 dopamine peak 變細、體感唔「大」)。`audio_unlock_confirm` = mono。

| event_id | 來源系統 | priority（duck?） | channels | 備註 |
|----------|---------|------------------|----------|------|
| `ui_tap` | #20 HUD / #33 | low | mono | next-exercise tap |
| `ui_back` / `ui_error` | #20 / #21 / #22 | low | mono | menu nav / 無效操作(#22 G-CS-9 reuse 2026-06-07)|
| `audio_unlock_confirm` | #4 self | **mid** | mono | **首 gesture unlock 確認 chime**（首個 real action 唔無聲後果）。**升 mid**：unlock 嗰刻同首個 BGM + 首個 workout SFX 可能撞；low priority 會即刻俾 pool 嘅其他 SFX steal → 「開聲」嗰一下反而無聲，諷刺地破壞 Rule 5 §81 design intent。mid 確保 chime 唔俾 combat SFX steal。[audio-director] Pass 4 |
| `hit_light` / `hit_heavy` | #13/#14/#25 | low | mono | combat hit feedback（體感印章） |
| `enemy_death` | #14 | low | mono | enemy 死 |
| `ability_cast_{strike,control,mobility}` | #12 | low | mono | ability 釋放,**3 sub-id freeze**(Pillar 4 audio identity,[audio-director] Pass 2) |
| `damage_taken` | #13/#25 | low | mono | avatar 受擊 |
| `set_complete` | #2 set_logged event（trigger）→ presentation consumer（play_sfx） | low | mono | 一組完。**Stagger 責任歸 presentation-layer audio-trigger consumer（IB-5 + EG-1 ownership 修正 2026-06-03 — 唔係 #4 code，亦唔係 #9 WST）**：若 `set_complete` 同 `streak_chime` 同 frame fire，需錯開 80-120ms 避免 transient 重疊 / SFX bus clip + 語意 muddy（「組完確認」同「streak +1」混為一聲）。**呢個 stagger 由 audio-trigger consumer adapter 負責**——佢係兩個 SFX 嘅 funnel，知道 same-frame timing。AudioManager 係 stateless gateway，`play_sfx` 收到就即播，**唔做** time-windowed delay（違反 gateway 無狀態原則 + Rule 5）。⚠️ **NOT #9 WST**（#9 pure data layer，唔 call play_sfx — EG-1 Option B）：consumer 直接訂 `#2.set_logged` 做 trigger。Contract：consumer 喺兩 event 同 frame 時，自行 delay 其中一個 `play_sfx` call 80-120ms（見 Dependencies forward contract）。Craft 細節（音色、長度）留 Q8 / `/asset-spec`。[audio-director + game-designer] Pass 4/5 + EG-1 |
| `workout_complete` | #9 WST | **high (duck)** | mono | 整個 workout 完，ritual moment。**Mono rationale（明確）**：`workout_complete` 定位係「莊重確認（dignified resolved）」而非「爆炸性 dopamine spike」，同 `loot_fanfare_*` 嘅 excitement 係不同情緒維度，而非同一 intensity 軸上嘅「大 vs 小」。Pillar 3 明文「loot fanfare = 唯一許可嘅 peak」，`workout_complete` 刻意唔搶呢個 crown — 改以 warm + long tail mono 傳遞莊嚴感（non-STEREO）。若 sound-designer 認為 STEREO 更符合 fantasy，需升級呢個 rationale 先可改。[audio-director + game-designer] Pass 4 |
| `streak_chime` | #8 | **mid (淺 duck)** | mono | low-key 暖 bell（淺 duck `STREAK_CHIME_DUCK_OFFSET_DB` default 深化 −5,確保 gym 噪音下聽到,[game-designer] Pass 2） |
| `loot_fanfare_{common,uncommon,rare,epic,legendary}` | #15 | **high (duck)** | **STEREO** | rarity-tiered ascending grandeur（見下）;短 tier 用 `SHALLOW_RELEASE_SEC` |
| `boss_stinger` | #16 | **high (duck)** | **STEREO** | boss 出場 stakes signal |
| `boss_phase` | #16 | **high (duck)** | **STEREO** | boss 階段轉換 |
| `boss_death` | #16 | **high (duck)** | **STEREO** | **boss 死亡 — Pillar 3 最高峰**（Pass 5 catalog gap：原本漏咗呢個 event → boss 死嗰一刻靜音，緊接 loot drop 前最大 stakes payoff 無聲）。STEREO + 大 reverb tail，緊接情境 A 嘅 boss_theme→rest_calm fade（boss_death stinger 蓋過 transition）。craft 待 Q8 |

> 清單為 v0 freeze；新增 event 須同 consumer GDD co-design 並更新此表 + `SfxCatalog.tres`。**確認 consumer GDD 反向列「depends on #4」**。

**Loot fanfare rarity 分層（[audio-director] RECOMMENDED — Q6，同 #15 + economy-designer co-design）**：5 tier 沿 ADR-0005 rarity 軸 ascending grandeur，差異維度建議 = **layer count + 樂器豐富度 + 長度 + reverb tail**（COMMON：單 layer 短 chime ~0.4s 無 tail；LEGENDARY：full-stack 長 fanfare ~1.5s + 長 reverb tail）。實際 tier mapping 待 #15 co-design 落實。

**Boss theme transition（[audio-director] RECOMMENDED）**：BOSS_ENCOUNTER 用短 fade（`0.25s`，per Rule 6 per-state override）強化 stakes signal，避免 1.0s default fade 太柔。

- **Format / budget（[performance-analyst] + [godot-specialist]）**：web-friendly **OGG Vorbis**；**SFX = `AudioStreamWAV` in-memory（短 <1s，全載入；fanfare/boss stinger STEREO,其餘 mono）；BGM = `AudioStreamOggVorbis` streamed loop（compressed streaming，唔好 decode 落 PCM 爆 budget）**；crossfade 期間 2× BGM decode CPU peak（mobile VS-tier 量,最易喺 WASM/Safari glitch — 列 VS-tier perf profiling 點，最差情況 ~0.2-0.6ms；fallback = instant-swap if profiling shows overrun）；**SFX in-memory 估 ~2.25MB**（[performance-analyst] Pass 4 更新：5 STEREO loot fanfare ~1.25MB + boss_stinger/phase STEREO ~0.5MB + ~10 mono combat/UI WAVs ~0.5MB；舊估 1.5-1.8MB 係 STEREO 加入前；遠低於 512MB ceiling）；**BGM bundle 估 ~6-12MB**（STEREO，3 focus_low variants + boss_theme + rest_calm ×90s ≈ 5-8 tracks ×1.44MB）；total audio bundle 8-14MB，計入 WASM 50MB 上限現實可行；loudness normalized（per `DEFAULT_*_DB`）。
- **Bundle CI gate（[performance-analyst] Pass 2 RECOMMENDED — soft limit 冇 enforce = 冇 limit）**：`MAX_BGM_BUNDLE_MB` 唔可淨靠人手。`FOCUS_LOW_VARIANT_COUNT=4 × 90s @128kbps ≈ 7 tracks × 1.44MB ≈ 10.1MB > 10MB soft cap`。需 **CI bundle-size gate**(build 時量 BGM 總 size vs `MAX_BGM_BUNDLE_MB`,超 → warn/fail),並喺 Tuning Knobs 互動段標 cross-knob 互鎖。SFX memory 估 ~1.5-1.8MB(30-40 stream,含 fanfare 5 tier + ability 3 sub-id),遠低於 512MB ceiling。

> 📌 **Asset Spec** — art/audio bible approved 後，run `/asset-spec system:audio-manager` 出 per-asset 描述 + 維度 + 生成 prompt。

## UI Requirements

- **Settings screen audio panel**：3 條 slider（Master / Music / SFX）+ 各 mute toggle；slider 0–1 → dB 經 **Formula 2**。
- **Silent-mode banner（LOCKED → unlock prompt，[game-designer] BLOCKING contract）**：web + 未 gesture 期間，#20 Gym-Mode HUD 顯示「㩒一下開聲」banner，玩家首 tap（core input）天然觸發 unlock 後 banner 消失。此 GDD 只定 contract（`is_audio_unlocked()` + `audio_unlocked` signal 供 HUD 訂閱），banner 視覺 / 文案屬 #20。
- Gameplay 中**無** audio UI（玩家唔 micro-manage，per Player Fantasy）。

> 📌 **UX Flag — Audio Manager**：Settings audio panel 喺 Pre-Production run `/ux-design` 出 spec；story 引 `design/ux/settings.md` 而非直接引此 GDD。

## Acceptance Criteria

- **AC-01 [Rule 1]** GIVEN codebase，WHEN `check_audio_callers.gd` scan，THEN gateway 外任何 `AudioServer.` / `new AudioStreamPlayer` / `.bus =` → exit 1。
- **AC-02 [Rule 2]** GIVEN boot 完，WHEN 檢查 bus，THEN `Master→{Music,SFX}` 存在，default dB = 0 / −6 / 0。
- **AC-03 [Rule 3 / priority-aware steal]** GIVEN READY + pool 全忙（各 voice `_voice_busy==true`，`assigned_sequence` 順序 s0<s1<…<s7，全 low priority），WHEN `play_sfx(new_low)`，THEN `assigned_sequence` 最低（最舊）嘅 slot 被重新指派（`slot.stream == new_stream`）+ 其餘 7 個 `stream` 不變 + `_test_get_active_voice_count() == SFX_VOICE_COUNT`（無 unbounded 生成）。**[qa-lead] Pass 4 BLOCKING 修正**：voice-count 斷言用 `_voice_busy` 邏輯佔用（`_test_get_active_voice_count()` 數 `_voice_busy==true` slots），**唔斷言 `player.playing`**（headless Dummy driver `.playing` 行為 post-Godot-4.6-cutoff 未驗；若 `.playing` headless == false，AC vacuously fails or needs frame advance → time-dependent，違反 determinism）。斷言 `slot.stream` 係 pure data property，headless 可靠。Test seam：`assigned_sequence: int` per slot readable + `_test_get_active_voice_count()`。
- **AC-03b [Rule 3 / priority gate]** GIVEN pool 全忙且全部 low priority + 其中一個正播 high `loot_fanfare_*`，WHEN `play_sfx(new_low)`，THEN 被 steal 嘅係某 low voice(`stolen.priority==low`)，**high fanfare voice 不受影響仍 playing**(保 Pillar 3)。
- **AC-04 [Rule 4]** GIVEN track A 正播，WHEN `play_bgm(A)`，THEN no-op（A 唔重啟，playback position 連續）。
- **AC-05 [Rule 5]** GIVEN **web** + LOCKED，WHEN `play_bgm(A)` 然後首個 gesture，THEN unlock 時 A 起播 + `audio_unlocked` emit 一次。
- **AC-06 [Rule 5]** GIVEN LOCKED，WHEN `play_sfx`，THEN dropped + push_warning，無 crash。
- **AC-06b [Rule 5 / UI contract]** GIVEN web + LOCKED，WHEN `is_audio_unlocked()` query，THEN 回 `false`；WHEN 首 InputEvent，THEN `audio_unlocked` emit 一次後 `is_audio_unlocked()` 回 `true`（#20 banner 訂閱此 signal 收起 prompt）。
- **AC-07 [Rule 6 / IB-7 emit timing]** GIVEN READY，WHEN GSM→BOSS_ENCOUNTER，THEN 起 crossfade 去 boss_theme + `bgm_changed(boss_theme)` emit **一次**。**[IB-7] emit 喺 crossfade 起 tween 之後即 emit（唔等 crossfade 完成）** — headless Dummy driver Tween 唔自然 advance，若 emit 綁喺 crossfade-complete callback，GUT 收唔到 signal → AC phantom-pass。斷言：`watch_signals(audio_manager)` 後 emit `state_changed(_, BOSS_ENCOUNTER, _)` → `assert_signal_emitted_with_parameters(audio_manager, "bgm_changed", [&"boss_theme"])`，**唔需 advance Tween / wait fade_sec**。
- **AC-08 [Rule 6]** GIVEN boot，WHEN initial-state sentinel 派發，THEN 無 music change（noop）。
- **AC-09 [Rule 7 / Formula 3]** GIVEN `base_music_db` set，WHEN high-priority SFX 播（call `_register_duck(DUCK_OFFSET_DB)→handle`），THEN `_compute_duck_target(_active_ducks)` == `max(base_music_db + DUCK_OFFSET_DB, MUTE_FLOOR_DB)`（default −6 + −8 = **−14 dB**，斷言用常數表達非 hardcode 值）。**[qa-lead] Pass 4 BLOCKING 修正 — pure function 驗法**：直接呼叫 `_register_duck(DUCK_OFFSET_DB)→handle` → assert `_compute_duck_target(_active_ducks) == −14dB` → call `_release_duck(handle)` → assert `_compute_duck_target({}) == base_music_db`。**唔需要 mock-emit AudioStreamPlayer `finished` signal**（closed gateway 無入口取得 pool instance；`_register_duck`/`_release_duck` 係 pure seam）。**禁止** wall-clock wait RELEASE_SEC — 違反「no time-dependent assertions」coding standard。
- **AC-09b [Rule 7a / bus 隔離]** GIVEN 任一 stinger(`loot_fanfare_*`/`boss_*`) player，THEN `player.bus == &"SFX"`(readable property 斷言)；且**除咗 2 個 BGM crossfade player 外,無任何 AudioStreamPlayer 嘅 bus == Music**(duck 只壓 Music bus,防自我抵消)。
- **AC-09c [Rule 3/7 / steal-duck 安全]** GIVEN `_register_duck(DUCK_OFFSET_DB)→handle`（模擬 high stinger 正 duck），WHEN 顯式呼叫 `_release_duck(handle)`（模擬 steal 路徑 explicit release，**唔靠 `finished` signal**）THEN `_active_ducks.has(handle) == false`（handle 已 erase）+ `_compute_duck_target({}) == base_music_db`（refcount→0，永不 permanent duck）。**[qa-lead] Pass 4 — pure function seam：steal path 呼叫 `_release_duck(handle)` 同 `finished` path 完全相同，冇獨立 code branch 需要 mock-emit。**
- **AC-09d [Rule 1 / Formula 3 / IB-3 正數 guard — Logic BLOCKING]** GIVEN AudioManager READY，WHEN `_register_duck(+8.0)`（誤傳正 offset，模擬 caller bug），THEN stored offset clamp 到 `0.0`（`clamp(+8, MUTE_FLOOR_DB, 0.0)`）+ push_warning 一次 + `_compute_duck_target(_active_ducks) <= base_music_db`（**music 永不被「升」**）。子斷言：`_register_duck(0.0)` → target == base_music_db（無效 duck，無害）。**[systems-designer] IB-3：debug build 另有 `assert(offset <= 0.0)` 即時捕捉，但 release build 靠 clamp 防呆（assert 喺 release 被 strip）。**
- **AC-10 [Rule 8]** GIVEN 未知 event_id，WHEN `play_sfx`，THEN 無 crash + warn + `_unknown_event_count++`。
- **AC-11 [Rule 9]** GIVEN `set_bus_volume_db(MUSIC,−10)`，WHEN reboot，THEN `audio.music_db` load 返 −10。
- **AC-12 [Formula 1]** GIVEN crossfade p=0.5，THEN `abs(out_gain − 0.707) < 0.001` 且 `abs(in_gain − 0.707) < 0.001` 且 `abs(out_gain² + in_gain² − 1.0) < 0.001`(equal-power,明確 epsilon)。
- **AC-13 [Formula 2]** GIVEN slider 0.5，THEN `volume_db` ≈ −6.02；slider 0 → −80。
- **AC-14 [State]** GIVEN **READY（`_audio_unlocked==true`）** + GSM→SUSPENDED，THEN 全部 audio paused 且 `_suspended_bgm_state.variant_id == <當前 track 的 variant_id>`（**Pass 6 修正**：`_suspended_bgm_state` 係 `{variant_id, position_sec}` dict，斷言用 `.variant_id`，**唔可**直接 `== <track_id>` — type mismatch）；resume（GSM 轉非-SUSPENDED，bitmask 降 0）→ active BGM player.stream == 該 track（同一 track 還原）。**見 AC-14c** 覆蓋 LOCKED(`_audio_unlocked==false`) 期間嘅 suspend/resume 行為。
- **AC-14b [State / EC SUSPENDED mid-crossfade]** GIVEN A→B crossfade 中途 GSM→SUSPENDED，THEN crossfade Tween `is_valid()==false`(killed) + pause all + `_suspended_bgm_state.variant_id == B`(目標 variant)；resume → active player.stream == B(唔卡半 crossfade 態)。
- **AC-14c [LOCKED × SUSPENDED 共存]** GIVEN web + `_audio_unlocked==false` + `play_bgm(A)` deferred，WHEN GSM→SUSPENDED→resume(仍未 gesture)，THEN `_audio_unlocked` 仍 false + deferred slot 仍 == A；WHEN 首 gesture，THEN unlock 起 GSM-current track + `audio_unlocked` emit 一次(無永久靜音)。
- **AC-15 [EC duck overlap / de-escalation recompute — pure function]** GIVEN `_register_duck(DUCK_OFFSET_DB)→handle_L`（loot, −8）+ `_register_duck(STREAK_CHIME_DUCK_OFFSET_DB)→handle_S`（streak, −5），THEN `_compute_duck_target(_active_ducks)` == `max(base+min(−8,−5), MUTE_FLOOR_DB)` == `max(base+(−8), MUTE_FLOOR_DB)` = −14dB（multiset 兩個 entry，唔去重）；WHEN `_release_duck(handle_L)`（erase handle_L，strict order: erase→recompute），THEN `_compute_duck_target(_active_ducks)` == `max(base+STREAK_CHIME_DUCK_OFFSET_DB, MUTE_FLOOR_DB)` = **−11dB**（分級 step，唔係一次回 base）；WHEN `_release_duck(handle_S)`（dict 空），THEN `_compute_duck_target({})` == `base_music_db`（全還原）。**pure function 斷言：無需 wall-clock，無需 AudioStreamPlayer instance。[qa-lead] Pass 4。**
- **AC-16 [EC catalog missing]** GIVEN catalog 缺失，WHEN boot，THEN push_error 一次 + no-op 模式，無 crash。
- **AC-17 [Rule 3 / Voice Cap — Logic]** GIVEN READY，WHEN 連發 SFX（> SFX_VOICE_COUNT 次），THEN `_test_get_active_voice_count()` == `SFX_VOICE_COUNT`（voice cap 係 memory-safety invariant）+ 無 unbounded slot 生成。**[qa-lead] Pass 4 修正**：斷言 `_test_get_active_voice_count()`（`_voice_busy==true` slots），**唔斷言 `AudioStreamPlayer.playing`**（headless Dummy driver 行為未驗；`.playing` 可能 headless == false → AC vacuously passes 0==0，而非 8==8，phantom-pass）。Pool 嘅「忙」由 `_voice_busy` logical state 定義，唔係 engine audio driver state。
- **AC-18 [EC mid-crossfade latest-wins / state-machine 斷言]** GIVEN A→B crossfade in-flight（`_crossfade_progress ∈ (0,1)`），WHEN `play_bgm(C)`，THEN 舊 crossfade Tween `is_valid()==false`(killed) + **`_test_get_active_crossfade_count() == 1`**（唔 stack；Godot 無 per-node Tween registry，無法直接數 Tween 實例，改用 `_active_crossfade_count` member proxy）+ 新 crossfade 起點 gain 由 `_crossfade_progress` 讀取（`cos(_crossfade_progress·π/2)` / `sin(_crossfade_progress·π/2)`，**唔係**直接讀 `player.volume_db`——dB 空間反算 p 有精度損失）。**[qa-lead] Pass 4 BLOCKING 修正**：「Tween 數 == 1」改用 `_active_crossfade_count` member 斷言（start ++，kill/complete --），確保可 headless verify。
- **AC-19a [EC multi pre-unlock / GSM-priority — [qa-lead] Pass 3 BLOCKING — disjunction 修正]** GIVEN `_audio_unlocked==false` 連 `play_bgm(A)`/`(B)`/`(C)` + mock GSM current state 有 track-map entry（如 `WORKOUT_ACTIVE→focus_low`），WHEN unlock，THEN BGM 起播 track == **GSM-mapped track（`focus_low`）**（唔係 deferred C）+ `bgm_changed` emit ≤1 次 + payload == `focus_low`（非 C）。驗 Pass 2「防 stale boss_theme churn」fix。
- **AC-19b [EC multi pre-unlock / deferred-fallback]** GIVEN `_audio_unlocked==false` 連 `play_bgm(A)`/`(B)`/`(C)` + mock GSM current state **無** track-map entry，WHEN unlock，THEN deferred slot 值 == C + BGM 起播 == C + `bgm_changed` emit ≤1 次（fallback path）。**子例**：`play_bgm(A)`/`(A)` 重複 → slot 維持 A，unlock 後起一次(冪等，不 double-fire)。
- **AC-20 [EC persisted volume corrupt — 三 case]** WHEN boot：(a) `audio.music_db` **key 缺失** → fallback default(−6),無 warn(正常首啟);(b) 值 **NaN/非數值** → fallback default + push_warning;(c) 值 **out-of-range**(如 +40 / −500) → **clamp 到 `[MUTE_FLOOR_DB, MAX_BUS_DB]`**(非 fallback default) + push_warning。三 case 行為唔同,各一斷言,皆無 crash。
- **AC-21 [Formula 1 boundary]** GIVEN `play_bgm(track, 0.0)`（fade_sec=0），THEN instant-swap（舊即停 / 新即 full gain），無 NaN / click。
- **AC-22 [Formula 2 boundary]** GIVEN slider `s = NaN`，THEN `volume_db` 回 `MUTE_FLOOR_DB`，無 NaN dB 套落 bus。
- **AC-23 [EC clamp]** GIVEN `set_bus_volume_db(MUSIC, +12)`，THEN clamp 到 `MAX_BUS_DB(0)` + push_warning（禁 boost）。
- **AC-24a [EC tab-backgrounded — Logic 純函數]** GIVEN READY，WHEN `_handle_focus_change(false)` 直接 call，THEN music paused;`_handle_focus_change(true)` → resume(可 headless GUT 斷言,抽純函數脫離 OS notification)。
- **AC-24b [EC tab-backgrounded — wiring]**(ADVISORY / documented playtest) GIVEN 真機，WHEN `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 派發，THEN 該 notification 正確 wire 去 `_handle_focus_change(false)`(headless 唔發 OS notification,故 wiring 留 playtest 驗證)。
- **AC-25 [Rule 7 / priority dispatch]** GIVEN priority∈{low, mid, high} 各一 SFX 播，THEN duck target 分別 == `base`(low,不 duck) / `max(base+STREAK_CHIME_DUCK_OFFSET_DB, MUTE_FLOOR_DB)`(mid −11) / `max(base+DUCK_OFFSET_DB, MUTE_FLOOR_DB)`(high −14)。(未測核心 dispatch formula,[qa-lead] Pass 2)
- **AC-26 [Rule 5 / unlock confirm]** GIVEN web + `_audio_unlocked==false`，WHEN 首 InputEvent unlock，THEN `audio_unlock_confirm` one-shot 播一次 + `audio_unlocked` emit 一次(首個 real action 有聲音回應)。
- **AC-27 [Tuning / BGM_MIN_LOOP_SEC boot warning]** GIVEN BGM track loop length < `BGM_MIN_LOOP_SEC`，WHEN boot / load BgmCatalog，THEN `push_warning` 一次（帶 track_id + actual_loop_sec）+ track 仍可正常播（非 reject，非 push_error，唔 crash）。**[qa-lead] Pass 3 — no-throw 家族，Logic BLOCKING**（防 author 漏標 loop length 但 game 靜默接受短 loop 造成疲勞）。

- **AC-28 [Rule 9 / Mute persistence — Integration]** GIVEN `set_bus_muted(MUSIC, true)` + `set_bus_volume_db(MUSIC, −10)`，WHEN reboot，THEN `audio.music_muted` loaded true **且** `audio.music_db` loaded −10（mute 同 volume 獨立持久化，unmute 後還原原 dB，唔互相覆蓋）。[qa-lead] Pass 4 RECOMMENDED。

- **AC-29 [Visual/Audio / BGM rotation non-immediate-repeat — Logic]** GIVEN `focus_low_pool` variant count == `FOCUS_LOW_VARIANT_COUNT`（N=3），WHEN state 進入 WORKOUT_ACTIVE 並連續 rotate（trigger on-state-entry 或 loop-end）N×3 次（=9 次 rotation），THEN 冇任何兩個 **相鄰** rotation 播同一條 variant（non-immediate-repeat 約束）。驗法：rotation 演算法用「排除 current 嘅 seeded pick」，GUT 可 deterministic 斷言順序。[qa-lead] Pass 4 RECOMMENDED。

- **AC-30 [State / `_suspend_sources` multi-source dedup — Logic]** GIVEN READY，WHEN GSM→SUSPENDED（bit 0 set，bitmask 0→1）THEN pause once + 記 track（副作用各一次）；WHEN `_handle_focus_change(false)`（bit 2 set，bitmask 1→5）THEN **唔再** pause（first-entry latch 已過）；WHEN GSM clears（bitmask 5→4）THEN **唔** resume（仍有 source）；WHEN `_handle_focus_change(true)`（bit 2 clear，bitmask 4→0）THEN resume once。斷言：pause callback 觸發剛好一次 + resume callback 觸發剛好一次（用 spy count 或 `_suspended_bgm_state` set 次數）。**[godot-specialist + qa-lead] Pass 4 BLOCKING — 新增 AC**。

- **AC-31 [Rule 5 / desktop no-unlock-confirm — Logic]** GIVEN **desktop**（`_audio_unlocked==true` at boot，non-web）+ READY，WHEN 任何 InputEvent 到達，THEN `audio_unlock_confirm` **唔播**（playcall == 0）+ `audio_unlocked` signal **唔 emit**（已 unlocked，唔 re-fire）。斷言 PlatformDetect 分支正確，desktop 唔觸發 web-only unlock flow。[qa-lead] Pass 4 RECOMMENDED。

- **AC-32 [Integration / mock injection seams — Integration contract]** GSM **同** PlatformDetect reference 皆必須經 **untyped injection seam**（`var _gsm` / `var _platform_detect`，非 typed `var _gsm: GameStateMachine` / `var _platform_detect: PlatformDetect`）接受 mock double，符合 ADR-0006 C4 + GDScript DI seam rule（typed Node 喺 compile-time member check 失敗）。Integration ACs（AC-07/14/14b/14c/19a/19b）嘅 test setup：注入 mock `_gsm` double → emit `state_changed` signal → assert AudioManager response。[qa-lead] Pass 4 RECOMMENDED。
- **AC-32b [Integration / PlatformDetect mock seam — IB-4 [qa-lead B1] BLOCKING]** PlatformDetect reference 經 **`var _platform_detect`（untyped）injection seam**。**呢個係 AC-05/06b/14c/19a/19b/26/31 共 7 條 Logic BLOCKING AC 嘅前置**：headless 無真 PlatformDetect autoload，若無 inject seam，web/desktop 分支（`is_web()` / unlock 策略）headless 會走 default 分支 → **phantom-pass**（測 web LOCKED 行為實際走 desktop 即-unlock，AC vacuously passes）。Contract：test setup 注入 mock `_platform_detect` double（stub `is_web()→true/false`），AudioManager 所有平台分支判斷一律經 `_platform_detect`（**唔直接 call** PlatformDetect singleton / `OS.has_feature("web")`）。GIVEN inject `_platform_detect.is_web()==true` → AC-05/06b unlock-gate 行為可 headless verify；inject `==false` → AC-31 desktop no-confirm 可 verify。

- **AC-33 [EC / SUSPENDED duck-kill — IB-8 [godot-specialist BLK-P5-1] Logic BLOCKING]** GIVEN READY + `_register_duck(DUCK_OFFSET_DB)→handle`（duck active，Music bus 邏輯目標 −14dB），WHEN `_handle_focus_change(false)`（或 GSM→SUSPENDED），THEN duck Tween killed（`_duck_tween.is_valid()==false`）+ Music bus dB **hard-set == `base_music_db`**（唔卡半 duck 態）+ `_active_ducks` dict **保留 handle**（唔清）。WHEN resume（`_handle_focus_change(true)`，`_active_ducks` 仍含 handle），THEN 重 spawn duck tween，target == `_compute_duck_target(_active_ducks)` == −14dB（重算還原 duck）。子斷言：若 resume 前 `_release_duck(handle)`（dict 空），resume 後 target == base_music_db（無 re-duck）。pure-function + readable bus dB 斷言，無需 wall-clock。
- **AC-34 [State / `_paused_focus_low` × `_suspended_bgm_state` 獨立性 — IB-6 [audio-director BLK-5-4] Logic BLOCKING]** GIVEN BOSS_ENCOUNTER（boss_theme 正播 + `_paused_focus_low == {variant_id: "focus_low_v1", position_sec: 12.3}` 已記），WHEN GSM→SUSPENDED，THEN `_suspended_bgm_state.variant_id == "boss_theme"`（記當前 audible track）**且** `_paused_focus_low` **不變**（仍 == `{focus_low_v1, 12.3}`，唔被 boss_theme 覆蓋）。WHEN resume，THEN 還原 boss_theme（`_suspended_bgm_state`）；子斷言：之後 mock GSM→WORKOUT_ACTIVE → 用 `_paused_focus_low` resume-from-position（active player.stream == focus_low_v1）。**兩 field 各記各，互不覆蓋。**

> *Reviewed by `qa-lead` (design-review 2026-06-01 Pass 1/2/3, 2026-06-02 Pass 4/5). Pass 4 修正：AC-03 改 `_voice_busy` logical occupancy（唔依賴 `.playing`）；AC-09/09c/15 改 pure-function `_register_duck/_release_duck/_compute_duck_target` 驗法（唔需 mock-emit AudioStreamPlayer）；AC-14 加 GIVEN READY 前置；AC-17 改 `_test_get_active_voice_count()`（logical occupancy）；AC-18 改 `_test_get_active_crossfade_count()` proxy；新增 AC-28（mute persistence）、AC-29（rotation non-repeat）、AC-30（bitmask multi-source，BLOCKING）、AC-31（desktop no-confirm negative）、AC-32（mock-GSM injection seam）。**Pass 6 (IB fixes) 新增/修正：AC-07（IB-7 emit-at-crossfade-start，唔等 Tween advance）；AC-09d（IB-3 正數 guard，BLOCKING）；AC-32b（IB-4 PlatformDetect mock seam，BLOCKING — 7 條 platform-branch AC 前置）；AC-33（IB-8 SUSPENDED duck-kill，BLOCKING）；AC-34（IB-6 `_paused_focus_low`×`_suspended_bgm_state` 獨立性，BLOCKING）。** Story-type: AC-01 = CI lint；**AC-03/03b/04/05/08/09/09c/09d/10/12/13/14c/15/16/17/18/19a/19b/20/21/22/23/24a/25/26/27/28/29/30/31/33/34 = Logic**（GUT unit, `tests/unit/audio/`, BLOCKING）；AC-06b/07/09b/11/14/14b/32b = Integration；AC-24b/32 = ADVISORY/contract（OS notification wiring + seam doc 不可 headless 或純文檔）；AC-02 = smoke/perf。*

## Open Questions

- **Q1**：`SFX_VOICE_COUNT`=8 provisional — 需 web profiling 確認 **polyphony mixing CPU**（memory 由 stream count 決定，非 voice count；voice count 主要食 mixing CPU；per-voice WASM mixing cost 估 tens μs，8 voices 理論上 well within 2ms；但建議 profiling 同時量 **worst-case boss transition frame**（dual OGG decode + combat SFX peak 疊加），fallback = 即降 6，單一 knob 改動零架構影響）。Owner：performance-analyst（VS-tier early）。
- **Q7（Pass 2 ADVISORY）**：Godot 4.6 Web Export AudioContext 自動 resume 仍需 **真機 Safari 驗證**(LLM cutoff May 2025 < Godot 4.6 Jan 2026,[godot-specialist] 無法 verify);`_input()` unlock monitor 保留做 belt-and-suspenders。Owner：godot-specialist（真機驗證）。
- **Q8（Pass 2 ADVISORY）**：`audio_unlock_confirm` + streak_chime「sober 暖 bell 唔 fanfare」+ 5-tier loot fanfare 嘅 asset craft constraint → `/asset-spec` 落實。Owner：audio-director + sound-designer。
- **Q9（Pass 2）**：streak_chime −5dB duck 深度需 **noisy-environment(gym) playtest** 驗證 perceptibility(−3 太淺已調 −5,但實際 masking 由 gym ambient 主導)。Owner：game-designer + audio-director(playtest)。
- **Q2**：完整 `state→track` map 待所有 GSM state 落實（BGM asset list 已 freeze 4 state）。Owner：game-designer + audio-director。
- **Q3（RESOLVED 2026-06-01 [godot-specialist]）**：Godot 4.6 Web Export audio driver **引擎層喺首個 user input event 自動 resume suspended AudioContext**，AudioManager 無需 / 不應 call `JavaScriptBridge` → **ADR-0001 衝突消解**。Rule 5 已更新。仍建議真機 Safari 驗證（post-cutoff 區域）— 降為 VS-tier ADVISORY。
- **Q4（RESOLVED 2026-06-01）**：ducking priority 已加 `priority` field 入 SfxCatalog freeze 表（low/mid/high）。Owner：sound-designer 確認最終值。
- **Q5（RESOLVED 2026-06-01）**：ADR-0008 已 **Accepted**（autoload position map），AudioManager 插入位已定，stories 不再 blocked。
- **Q6**：loot fanfare rarity 分層（ascending grandeur）需同 #15 LootDrop co-design — design intent 已落（layer/樂器/長度/reverb tail 維度），實際 tier mapping 待 co-design。Owner：audio-director + economy-designer。
- **Q-A1（post-MVP）**：`focus_low` stem-based intensity ramp（隨 session 進度疊加 layer）— MVP 用 multi-variant rotation，stem 升級 deferred。Owner：audio-director。
- **Q-PENDING-BLK8-CO ✅ RESOLVED 2026-06-03 (EG-3 confirmed)**：LOOT_DROP from BOSS_ENCOUNTER → conditional boss_theme→rest_calm fade-back（Rule 6 情境A）**已確認正確**。證據：(1) **GSM GDD line 213**（BossEncounter state transitions）明定 `Boss defeated → LootDrop (BossOutcome.DEFEATED)` + `workout_completed → LootDrop (INTERRUPTED_WITH_CREDIT)` → **final boss kill 入 LOOT_DROP 嘅 from_state == BOSS_ENCOUNTER**。(2) **#15 LootDrop GDD line 71** = 純 data/event layer（收 boss_killed/enemy_killed/workout_completed → generate loot + emit ceremony signal），**唔 own GSM state transition** → 無 contradict from-state。(3) Nuance：mini-boss 喺 COMBAT_ACTIVE（非 BOSS_ENCOUNTER；GSM line 213「Boss 戰 promote 自 CombatActive」= final boss）+ deferred-reveal loot 從 safe state 入 → 兩者 from ≠ BOSS_ENCOUNTER 且 boss_theme 已停，audio 正確唔 fire 情境A。**唯一 boss_theme 響緊 + 入 LOOT_DROP 嘅 path = final boss via BOSS_ENCOUNTER，啱啱好 == 情境A 判別。** EG-3 CLOSED — 無需改 audio 或 #15 GDD。
- **Q-PENDING-B1-CO（Pass 4 resolved — needs #9 patch）**：Forward contract 已落入 Dependencies section。**#9 WST GDD（已 Approved）需 patch** 加 `audio_unlocked` subscribe + mid/high SFX buffer/flush 邏輯。Owner：game-designer + #9 WST GDD。此 patch 係 #9 revision，唔係 /design-system 新 GDD。
- **Q-CLEANUP（Pass 4 RECOMMENDED）**：`_exit_tree()` / `NOTIFICATION_PREDELETE` 中 kill retained Tweens（`_duck_tween.kill()`, `_crossfade_tween.kill()`）防 shutdown dangling Tween callback。低優先，可 implementation story 順手做。

---

## Errata + G-LM-8 Cue Freeze 表(2026-06-07 — #21 stories 023 執行)

### Errata ×2

1. **Catalog source 列**:`loot_fanfare_*` 觸發 caller = **#21 LootRevealCoordinator @ S0 frame**(EG-1 precedent — data layer 唔 call play_sfx;#15 唔係 caller)。
2. **AudioManager process-mode**:`PROCESS_MODE_ALWAYS`(code-set 喺 `_ready`)— `ceremony_freeze`(#6 G-LM-3)用 `get_tree().paused`,PAUSABLE audio 會令 fanfare 喺 dopamine peak 停 0.4s;SFX pool players 係 children 自動繼承。CI lint:`tools/ci/check_autoload_process_modes.gd`(audio_manager / loot_reveal_coordinator / screen_effects 三檔 marker)。

### G-LM-8 Cue Freeze 表(BINDING co-design 記錄;`SfxCatalog.tres` 由 /asset-spec 產 — streamless catalog 會反轉 safe no-op mode,唔 ship 半生 tres)

| event_id | Priority | Channels | Duck | Note |
|---|---|---|---|---|
| `loot_fanfare_common` | LOW | mono | per-tier ceremony duck 照 #4 flat −8dB 機制 | tier sting 家族(#15 §D 音色) |
| `loot_fanfare_uncommon` | LOW | mono | 同上 | |
| `loot_fanfare_rare` | MID | mono | 同上 | |
| `loot_fanfare_epic` | MID | stereo | 同上 | |
| `loot_fanfare_legendary` | HIGH | stereo | 同上;0.1s pre-roll 對齊 pre-shake | ~1.6s orchestral |
| `sfx_loot_shutter_dismiss` | **MID / mono / NO-DUCK** | mono | 無 | S4 快門 — 儀式錨點唔俾 combat-class 食(`audio_unlock_confirm` 升 mid 同構);單一共用唔分 tier |
| `sfx_loot_contactsheet_enter` | LOW | mono | 無 | exposure sweep whoosh ≤0.6s |
| `loot_stream_aggregate` | LOW | mono | **單一 duck handle −4dB sustained**(catch-up 全程;exit release) | ≤stream 長度 riser/coin-shower;**禁 per-beat fanfare**(D4) |
| `loot_toast_tick` | LOW | mono | 無 | ≤0.15s;toast 一律 tick — fanfare 家族 modal 獨家(#15 L204 erratum);`FLUSH_DELAY` 下限 0.15s 避開 set_complete/streak_chime stagger |
| `sfx_loot_stash_put` | — | — | — | **default SILENT**(stash 語境 = 玩家已唔望 mon;acknowledgment 由 flush toast 承擔) |
| Grid hero-cell sting | 條件化 | — | — | 只喺 hero 件未經 full ceremony 先播(2 秒內同 peak 播兩次 = devaluation) |

**Voice pool 重估(catch-up 包絡)**:stream 全程單一 aggregated cue(1 voice + 1 duck handle)+ per-ceremony fanfare(≤1 並發,EC-M9 gap 隔開)+ shutter(no-duck)— 8-voice pool 充裕;機關槍 per-beat 方案已禁(D4),洪水 steal 場景消滅。
**Lint scope 裁決(原 OQ-4)**:cue id 註冊 lint 隨 `/asset-spec` 產 tres 時一齊開(catalog 未 ship 前 lint 無對象)。

### #22 Character Screen cue 註冊(G-CS-9,2026-06-07 — G-LM-8 先例;co-design ✅;audio-director sign-off 記錄於 #22 story 012)

> 全部 **low / mono / no-duck**(#22 §Audio direction:「紙、木、石墨 + 細金屬 accent 限 lock 語意」;零 chime 零 fanfare — Pillar 3 reserved;AC-03b 永不 steal loot fanfare voice)。`SfxCatalog.tres` entries 隨 `/asset-spec system:character-screen` 產 tres 時落(Q-CS7;Lint scope 裁決同上)。

| event_id | 來源系統 | priority(duck?)| channels | 備註 |
|----------|---------|------------------|----------|------|
| `ui_charscreen_open` / `ui_charscreen_close` | #22 | low | mono | 低沉軟 thock + 紙(close = 短 reverse);**只 player-initiated** — force-close / SUSPENDED snap 零 SFX(#22 CD C1)|
| `ui_equip_settle` | #22 | low | mono | stat tween settle 一刻「刻一下」;**dedupe locus = #22-side settle-frame coalesce**(每 command 最多 1 響,4-row 並行都係 1 — #4 stateless gateway 唔做 time-window)|
| `ui_lock_on` / `ui_lock_off` | #22 | low | mono | 細金屬 click,on 略重 |
| `ui_salvage_execute` | #22 | low | mono | 短 grind / 紙撕 — 唔係爆炸 |
| `ui_sheet_open` / `ui_sheet_close` | #22 | low | mono | picker / modal 軟 slide(共用)|
| `ui_toggle_flip` | #22 | low | mono | P-08 toggle 細 click |

**Naming 慣例裁決(#22 G-CS-9 順手,audio N5)**:UI cue canonical prefix = bare `ui_*`(`ui_tap`/`ui_back` 同源);#21 嘅 `sfx_loot_*` prefix 係 outlier(已 ship,唔改 — 記錄在案,新 cue 一律跟 `ui_*`/domain 名)。
**Voice pool 重估(#22 包絡)**:#22 只喺 IDLE/DISCONNECTED 開(combat/workout SFX 唔並發),同時最多 ~2-3 UI cue — 8-voice pool 零 contention。
