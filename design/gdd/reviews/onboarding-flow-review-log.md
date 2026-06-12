# Onboarding Flow (#27) — Design Review Log

## Review — 2026-06-11 — Verdict: APPROVED (NEEDS REVISION → revise-now → APPROVED, 同 session)
Scope signal: M (11 systems touched 但全 observe-only;3 trivial UI-timing formula;2 additive+precedented ADR amendment;1 CI lint)
Specialists: degraded-inline (specialist spawn credit-limited → single-session adversarial + grep-verify against shipped src/GDDs;跟 #18/#19/#21–#26/#29/#25 先例)
Blocking items: 2 | Recommended: 2 | Nice: 2

### Grep-verified 上游 contract（全 EXACT — 11 項）
- #9 `workout_started_forwarded()` / `dominant_class_changed(new_class:int)` / `workout_completed_forwarded(completed_at:int, transition_id:String)` — workout_state_tracker.gd:65/104/69 ✅
- #21 `modal_dismissed(drop_id:String, terminal:bool)` — loot_reveal_coordinator.gd:27 ✅
- #10 `get_class_for_exercise(exercise_id:StringName) -> int` — exercise_class_mapping.gd:119 ✅
- #24「#27 owns flow;#24 owns surface;first-run tutorial 唔入 #24」— login-gymsys-connection-ui.md L11/L117/L249 ✅ bidirectional
- #15 `POST /api/game/loot/claim-daily` + ≥COMMON floor + server-authority(client 唔 trigger)— loot-drop-system.md L178/96/148 ✅
- ADR-0006 C6 `connect_for_initial_state` — game_state_machine.gd:271 ✅
- ADR-0001 layers #21 loot=110 / #24 banner=111 / #25 overlay=105 / modal=120 — adr-0001 L131-140 ✅
- AbilityClass `{STRIKE,CONTROL,MOBILITY,UNKNOWN}=0,1,2,3` — ability_system.gd:49 ✅
- **#9 `dominant_class_changed` 可 carry UNKNOWN** — workout_state_tracker.gd:102/200/259 ✅ → EC-11/AC-20 defensive 係真實必要,grep-CONFIRMED

### Blocking items（revise-now 全收）
- **B-1 — `SET_ACTIVE` cross-enum 型別錯誤**：GDD 全程當 `SET_ACTIVE` 係 GSM `GameState`(Formula 1 / Rule 4 / EC-04 / AC-10 等 6 處),但 grep 證實 GSM enum 冇 `SET_ACTIVE`(game_state_machine.gd:80-90),`SET_ACTIVE` 係 `WorkoutPhase`(#9 WST,ordinal 2)。`WORKOUT_CRITICAL = {SET_ACTIVE, REST_PERIOD, LOOT_DROP}` 撈亂兩 enum → 單一 `gsm_state ∉ WORKOUT_CRITICAL` gate 寫唔成。**Fix（Option A）**：`SET_ACTIVE → WORKOUT_ACTIVE`,WORKOUT_CRITICAL 變純 #1 GSM `GameState` set(單 enum membership、零新 subscription、更保守 deferral);#9 `WorkoutPhase.SET_ACTIVE` finer 精度 deferred 去 epic-time(若要可 subscribe #9 `phase_changed`)。
- **B-2 — `tail after #29 MirrorMomentCoordinator` stale citation**：G-OB-1(Rule 1 + AC-23)pin「tail after #29」,但 project.godot L162 `CombatVisualFeedback`(#25,64ebbb5 後加)先係 current tail。照字面插喺 #29 後 shift #25 = [[feedback_lint_allowlist_adr_sync]] position-drift class。**Fix**：改 robust 表述「tail-append after current tail(now #25)= after every prior autoload,terminal」。

### Recommended（revise-now 全收）
- **R-1 — CF-1 citation precision**：L52「錨 CF-1...registry:`DEFAULT_BASE_STAT=10 ≥ TIER_1=10`」。數值 grep-verified TRUE(ability-system.md L444 CF-1「Default Baseline Auto-Unlock」),但真源係 **#12 ability-system.md** 唔係「entities.yaml registry」(該檔無此值),constant 真名 `TIER_1_THRESHOLD` 唔係 `TIER_1`。改 cite #12 L444/L637 + 真名 + 明寫「onboarding 唔計呢個值,純引用作 teaching 背景」。
- **R-2 — OnboardingOverlayLayer desaturation 張力**：Visual 講 coach-mark「唔受 world desaturation」(暗示 >100 immune),但 coach-mark 喺所有 world-desaturating state(LOOT_DROP)一律 defer → 永不同 world desaturation 同框 → immunity moot → 可安全住 captured band(<100)。澄清 G-OB-3,避免 epic-time 誤逼入擠迫嘅 (100,110) immune band。

### Nice-to-Have
- N-1：Step 2 preview「試演」scripted wave 第一印象說服力(Q-OB-1 已 defer 內容到 epic;watermark + real-takeover 已護 Pillar 1)。
- N-2：#9 interaction row「WorkoutPhase 經 GSM/phase 作 gating」措辭含糊 → B-1 修時一併澄清 gating 軸 = GSM state。

### Senior Verdict（creative-director — degraded-inline synthesis）
設計非常紮實:thin observe-only orchestrator + 零 gameplay math 誠實申報 + Pillar 1/2 兩命脈用 architectural restraint 強制 + Step 4 fire 喺 ceremony dismiss 之後唔疊 sacred surface。11 個上游 contract grep-verify **全 EXACT**,證明 author consumer-forward claim 可信。兩個 BLOCKING 係 citation/enum 精度錯,非設計缺陷,修法 surgical 全 grep-grounded。**APPROVED**（revise-now 後 0 new phantom,exit bar 全綠）。

Prior verdict resolved: First review
