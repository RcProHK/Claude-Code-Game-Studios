# Audio Manager

> **Status**: In Design
> **Author**: Frank + (lean — no specialist agents this pass)
> **Last Updated**: 2026-06-01
> **Implements Pillar**: Indirect Foundation — serves Pillar 3 (Drop Euphoria) + Pillar 1/2 supporting via audio feedback channel
> **System #**: 4 (Foundation / MVP tier)
> **Depends On**: #1 GameStateMachine (music transitions), #3 PersistenceLayer (volume settings), #2 GymSysBackendClient (indirect — workout events drive stingers)
> **Depended On By**: #5 ParticleSystemWrapper (audio co-trigger), #6 ScreenEffects, #8 StreakSystem (counter chime), #15 LootDropSystem (loot fanfare), #25 Combat Visual Feedback, #20 Gym-Mode HUD
> **Governing ADRs**: ADR-0008 Autoload Position Map (Proposed — placement), ADR-0006 Contract 4/6 (boot order + connect_for_initial_state), ADR-0001 (web export budget), ADR-0003 (volume persistence keys)

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
signal bgm_changed(track_id: StringName) # crossfade 完成
```
無 public mutator 掂 AudioServer/AudioStreamPlayer；CI lint `check_audio_callers.gd` ban gateway 外嘅 `AudioServer.` / `new AudioStreamPlayer` / `.bus =` 設定。

**Rule 2 — Bus topology**：`Master → {Music, SFX}` 兩條子 bus。Volume 用 dB。Default：Master 0dB、**Music −6dB（subtle，game-concept locked）**、SFX 0dB。

**Rule 3 — SFX pooling + voice stealing**：固定 pool（`SFX_VOICE_COUNT`，web budget）非位置性 `AudioStreamPlayer`。`play_sfx` 攞 free player，全忙 → steal 最舊。`event_id → AudioStream` 經 data-driven `SfxCatalog.tres`（無 hardcode path，符合 coding-standard）。

**Rule 4 — BGM crossfade single-channel**：兩個 dedicated Music player 做 crossfade。`play_bgm` 由當前 track crossfade 去新 track。同 `track_id` 正播 → no-op（idempotent）。`track_id → stream` 經 `BgmCatalog.tres`。

**Rule 5 — Mobile Safari unlock gate**：unlock 前 AudioContext suspended。`play_bgm` 入 single-slot deferred（latest-wins，跟 streak posture）；`play_sfx` 直接 drop + warn（one-shot 唔值得 defer）。首個 user InputEvent → unlock → resume AudioContext → emit `audio_unlocked` → 起 pending BGM。Desktop/native 無 restriction → boot 即 unlock。

**Rule 6 — GSM state → music transition**：`connect_for_initial_state(_on_gsm_state_changed)`（ADR-0006 C6）。data-driven `state → track` map（e.g. `WORKOUT_ACTIVE→focus_low`、`BOSS_ENCOUNTER→boss_theme`、`LOOT_DROP→`(stinger，唔換 BGM)）。Map 無 entry 嘅 state → 維持當前 BGM。Initial-state sentinel → noop。

**Rule 7 — Ducking**：高優先 SFX（loot fanfare / boss stinger）播放時，Music bus 暫 duck `DUCK_DB`（tween），SFX 完 + release 後還原。令 reward peak 突出（Pillar 3）。

**Rule 8 — Foundation no-throw**：未知 `event_id`/`track_id` → push_warning + no-op + `_unknown_event_count++`，永不 crash（同 #5/#6/#7/#8 一致）。

**Rule 9 — Volume persistence**：`set_bus_volume_db`/`set_bus_muted` 寫 `audio.*` namespace via PersistenceLayer（`audio.master_db` / `audio.music_db` / `audio.sfx_db` / `audio.*_muted`）；boot 時 load。

### States and Transitions

| State | Entry | Behaviour |
|-------|-------|-----------|
| **BOOTING** | autoload `_ready()` | load catalogs + persisted volumes + subscribe GSM；無出聲；`is_audio_unlocked()→false` |
| **LOCKED** | BOOTING 完 + web 且未 gesture | AudioContext suspended；`play_bgm` defer（single-slot latest-wins）；`play_sfx` drop+warn；`set_bus_volume` work（persist） |
| **READY** | first gesture（或 desktop boot 即達） | 正常服務：SFX pool + BGM crossfade + ducking + GSM music transition |
| **SUSPENDED** | GSM → SUSPENDED（覆蓋一切） | pause 全部 audio + 記住當前 BGM track；resume（非-SUSPENDED）→ 還原 BGM。對應 Web visibilitychange / bfcache |

**Arcs**：`BOOTING→LOCKED`（web 未 unlock）/ `BOOTING→READY`（desktop / native 即 unlock）；`LOCKED→READY`（first gesture，emit `audio_unlocked` + 起 pending BGM）；`READY↔SUSPENDED`（GSM）。`SUSPENDED 永遠覆蓋一切`（同 #6/#7/#8 posture）。

### Interactions with Other Systems

1. **#1 GameStateMachine**（upstream）：`connect_for_initial_state(_on_gsm_state_changed)`；state→track map；sentinel noop。**唔**用 plain `.connect`（ADR-0006 C6，CI enforced）。
2. **#3 PersistenceLayer**（up/down）：只讀寫 `audio.*` namespace（volume / mute）；其他 namespace forbidden。
3. **#5 Particle / #6 ScreenEffects / #8 Streak / #15 LootDrop / #25 Combat Visual Feedback**（downstream callers）：call `play_sfx(event_id)` co-trigger；`event_id` 由各自 GDD 約定（滿足 particle-system-wrapper.md「audio direction co-trigger contract」）。
4. **PlatformDetect**（pos 3）：query mobile / web → 決定 unlock 策略（web 要 gesture，desktop/native 即 unlock）。
5. **Forbidden coupling**：gateway 外無人掂 `AudioServer` / `AudioStreamPlayer`（CI `check_audio_callers.gd`）；AudioManager 唔讀 game state（只認 GSM signal + 自己 closed API）；唔訂閱 GSM 以外嘅 gameplay signal。

## Formulas

> *Lean pass — `systems-designer` not consulted (user opted no agent spawns). Review balance before production.*

### Formula 1 — Equal-power BGM crossfade gain

`out_gain(p) = cos(p · π/2)` ， `in_gain(p) = sin(p · π/2)`

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `p` | float | 0–1 | crossfade 進度 = elapsed / fade_sec |
| `out_gain` | float | 1→0 | 舊 track 線性 gain |
| `in_gain` | float | 0→1 | 新 track 線性 gain |

**Output**：`out_gain² + in_gain² = 1`（equal-power，perceived loudness 恆定，中段無音量 dip）。**Example**：p=0.5 → out=in=0.707（−3 dB each），總能量守恆。

### Formula 2 — Volume slider (0–1) → dB

`volume_db(s) = (s ≤ 0) ? MUTE_FLOOR_DB : clamp(linear_to_db(s), MUTE_FLOOR_DB, 0.0)`

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `s` | float | 0–1 | settings slider 值 |
| `MUTE_FLOOR_DB` | float | −80（const） | 靜音地板 |
| `volume_db` | float | −80–0 | 套落 bus 嘅 dB |

**Output**：s=1 → 0 dB，s→0 → −80 dB。**Example**：s=0.5 → `linear_to_db(0.5)` ≈ −6.02 dB（用 Godot 內建 `linear_to_db`，perceptual-ish）。

### Formula 3 — Ducking target + release

duck 期間 Music bus 目標 `= base_music_db + DUCK_OFFSET_DB`；release 用 `RELEASE_SEC` lerp 還原。

| Var | Type | Range | Description |
|-----|------|-------|-------------|
| `base_music_db` | float | −80–0 | Music bus 正常 dB（default −6） |
| `DUCK_OFFSET_DB` | float | −12–0（default −8） | duck 衰減量 |
| `ATTACK_SEC` | float | 0.02–0.2（default 0.05） | duck 落 attack |
| `RELEASE_SEC` | float | 0.1–1.0（default 0.4） | SFX 完後還原時長 |

**Output**：base −6 + duck −8 = duck 期間 −14 dB。**Example**：loot fanfare（~0.8s）→ 0.05s 內 duck 到 −14 dB，fanfare 完後 0.4s lerp 返 −6 dB。

## Edge Cases

- **If `play_sfx(event_id)` 收到未知 event_id**：push_warning + no-op + `_unknown_event_count++`，唔 crash（Foundation no-throw）。
- **If `play_bgm(track_id)` 而 track_id 已經正播**：no-op（唔重啟、唔重新 crossfade）。
- **If `play_bgm` 喺 LOCKED（unlock 前）**：存入 single-slot deferred（latest-wins）；unlock 後先起。多個 pre-unlock call → 只記最後一個。
- **If `play_sfx` 喺 LOCKED**：直接 drop + push_warning（one-shot 唔 defer）。
- **If SFX pool 全忙**：steal 最舊 voice（voice stealing，bounded polyphony）。
- **If 連續 `play_bgm(A)` 再 `play_bgm(B)`（A crossfade 未完）**：cancel in-flight crossfade，由「當前實際 audible 混合態」crossfade 去 B（latest wins，唔 stack）。
- **If GSM → SUSPENDED 喺 crossfade 中途**：kill crossfade tween + pause 全部 + 記住目標 track；resume 時由目標 track 還原（唔會卡喺半 crossfade 態）。
- **If `set_bus_volume_db` 超範圍**：clamp 到 `[MUTE_FLOOR_DB(−80), MAX_DB(0)]`（唔容許 boost 過 0 dB 防 clipping）+ push_warning。
- **If 兩個 ducking SFX 重疊**：用最深 duck（max offset）；維持 active-duck refcount，全部完（count→0）先 release 還原 — 唔會中途彈返。
- **If GSM state 喺 track-map 無 entry**：維持當前 BGM（無變、無 warning）。
- **If catalog resource（`SfxCatalog`/`BgmCatalog`）boot 時缺失**：push_error 一次 + 進入 safe no-op 模式（所有 play 變 no-op），永不 crash。
- **If persisted volume 缺失/corrupt**：fallback 去 defaults（Master 0 / Music −6 / SFX 0）。
- **If tab backgrounded（Web visibilitychange）但 GSM 未發 SUSPENDED**：AudioManager 自己聽 `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_WM_WINDOW_FOCUS_OUT` → pause music；focus 返 → resume（bfcache 安全）。

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

**Indirect**：#2 GymSys workout events 唔直接入 AudioManager，而係經 #8/#15 等中介 trigger SFX。

## Tuning Knobs

| Knob | Default | Safe range | 太高 / 太低 |
|------|---------|-----------|------------|
| `DEFAULT_MASTER_DB` | 0 | −20–0 | 高>0 clip；低 太細聲 |
| `DEFAULT_MUSIC_DB` | −6 | −18 – −3 | 高 搶 set 注意力（違 Pillar 2）；低 聽唔到氛圍 |
| `DEFAULT_SFX_DB` | 0 | −6–0 | 高>0 clip；低 feedback 唔夠 punchy |
| `MUTE_FLOOR_DB` | −80 | −90 – −60 | 太高 slider 最低仲有聲 |
| `MAX_BUS_DB` | 0 | 0–+6 | >0 開放 boost → clipping 風險 |
| `SFX_VOICE_COUNT` | 8 | 4–16 | 高 食 web memory/CPU；低 voice steal 太頻（漏 SFX） |
| `BGM_DEFAULT_FADE_SEC` | 1.0 | 0.3–3.0 | 高 transition 拖沓；低 突兀 |
| `DUCK_OFFSET_DB` | −8 | −12 – −3 | 深 music 幾乎消失；淺 reward peak 唔突出 |
| `DUCK_ATTACK_SEC` | 0.05 | 0.02–0.2 | 高 duck 反應慢蓋唔到 transient |
| `DUCK_RELEASE_SEC` | 0.4 | 0.1–1.0 | 高 music 遲還原；低 pumping artifact |
| `state→track map` | data `.tres` | — | 錯 map → 錯 context music |

**互動**：`DEFAULT_MUSIC_DB` + `DUCK_OFFSET_DB` 疊加決定 duck 期間實際 music level（−6 + −8 = −14）；`MUTE_FLOOR_DB` 同 Formula 2 slider mapping 綁。

## Visual/Audio Requirements

> *Lean pass — `audio-director` not consulted (user opted no agent spawns). Refine sonic palette with audio-director before asset production.*

- **Palette philosophy**：warm、non-fatiguing（gym session 重複聽都唔煩）；SFX punchy + 短；loot fanfare 係唯一「大」moment（Pillar 3 peak）。
- **BGM**：per-state low-intensity loop（idle ambient / workout `focus_low` / `boss_theme` 緊張 / rest calm），seamless loopable，stereo。
- **SFX categories**：UI tap、hit feedback（#25）、streak chime（#8 — low-key 暖 bell）、loot fanfare（#15 — rarity-tiered ascending grandeur）、boss stinger。mono。
- **Format / budget**：web-friendly **OGG Vorbis**；SFX <1s short；BGM streamed loop；總 audio bundle 計入 WASM / 512MB budget；loudness normalized（per `DEFAULT_*_DB`）。

> 📌 **Asset Spec** — art/audio bible approved 後，run `/asset-spec system:audio-manager` 出 per-asset 描述 + 維度 + 生成 prompt。

## UI Requirements

- **Settings screen audio panel**：3 條 slider（Master / Music / SFX）+ 各 mute toggle；slider 0–1 → dB 經 **Formula 2**。
- Gameplay 中**無** audio UI（玩家唔 micro-manage，per Player Fantasy）。

> 📌 **UX Flag — Audio Manager**：Settings audio panel 喺 Pre-Production run `/ux-design` 出 spec；story 引 `design/ux/settings.md` 而非直接引此 GDD。

## Acceptance Criteria

- **AC-01 [Rule 1]** GIVEN codebase，WHEN `check_audio_callers.gd` scan，THEN gateway 外任何 `AudioServer.` / `new AudioStreamPlayer` / `.bus =` → exit 1。
- **AC-02 [Rule 2]** GIVEN boot 完，WHEN 檢查 bus，THEN `Master→{Music,SFX}` 存在，default dB = 0 / −6 / 0。
- **AC-03 [Rule 3]** GIVEN READY + 全 voice busy，WHEN `play_sfx`，THEN 最舊 voice 被 steal，無 error，新 SFX 出聲。
- **AC-04 [Rule 4]** GIVEN track A 正播，WHEN `play_bgm(A)`，THEN no-op（A 唔重啟，playback position 連續）。
- **AC-05 [Rule 5]** GIVEN LOCKED，WHEN `play_bgm(A)` 然後首個 gesture，THEN unlock 時 A 起播 + `audio_unlocked` emit 一次。
- **AC-06 [Rule 5]** GIVEN LOCKED，WHEN `play_sfx`，THEN dropped + push_warning，無 crash。
- **AC-07 [Rule 6]** GIVEN READY，WHEN GSM→BOSS_ENCOUNTER，THEN crossfade 去 boss_theme + `bgm_changed(boss_theme)` emit。
- **AC-08 [Rule 6]** GIVEN boot，WHEN initial-state sentinel 派發，THEN 無 music change（noop）。
- **AC-09 [Rule 7 / Formula 3]** GIVEN BGM −6 dB，WHEN high-priority SFX 播，THEN Music bus duck 到 −14 dB，release 後還原 −6 dB。
- **AC-10 [Rule 8]** GIVEN 未知 event_id，WHEN `play_sfx`，THEN 無 crash + warn + `_unknown_event_count++`。
- **AC-11 [Rule 9]** GIVEN `set_bus_volume_db(MUSIC,−10)`，WHEN reboot，THEN `audio.music_db` load 返 −10。
- **AC-12 [Formula 1]** GIVEN crossfade p=0.5，THEN out_gain ≈ in_gain ≈ 0.707（`out²+in²≈1`）。
- **AC-13 [Formula 2]** GIVEN slider 0.5，THEN `volume_db` ≈ −6.02；slider 0 → −80。
- **AC-14 [State]** GIVEN GSM→SUSPENDED，THEN 全部 audio paused + 當前 BGM track 記住；resume（非-SUSPENDED）→ 還原同一 track。
- **AC-15 [EC duck overlap]** GIVEN 兩個 overlapping duck，WHEN 其中一個完，THEN 仍維持 duck 直至兩個都完（refcount）。
- **AC-16 [EC catalog missing]** GIVEN catalog 缺失，WHEN boot，THEN push_error 一次 + no-op 模式，無 crash。
- **AC-17 [Perf]** GIVEN READY，WHEN 連發 SFX，THEN polyphony ≤ `SFX_VOICE_COUNT`（web memory bounded），無 unbounded player 生成。

> *Lean pass — `qa-lead` not consulted (user opted no agent spawns). Validate testability before story creation.*

## Open Questions

- **Q1**：`SFX_VOICE_COUNT`=8 provisional — 需 web profiling 確認 polyphony vs memory。Owner：performance-analyst（VS-tier）。
- **Q2**：完整 `state→track` map 待所有 GSM state + BGM asset list 落實。Owner：game-designer + audio-director。
- **Q3（HIGH）**：Godot 4.6 Web AudioContext unlock — Godot 係咪 input 自動 resume，定要 `JavaScriptBridge`？（JSBridge 只准喺 `platform_detect.gd`，ADR-0001）需驗證。Owner：godot-specialist。
- **Q4**：ducking「high-priority」由邊啲 event_id 觸發 → `SfxCatalog` 需加 priority field。Owner：sound-designer。
- **Q5（BLOCKING stories）**：ADR-0008 必須 Accept 先 fix AudioManager autoload position。Owner：technical-director。
- **Q6**：loot fanfare rarity 分層（ascending grandeur）需同 #15 LootDrop co-design。Owner：audio-director + economy-designer。
