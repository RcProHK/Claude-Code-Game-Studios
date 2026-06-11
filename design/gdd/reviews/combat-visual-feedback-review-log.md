# Combat Visual Feedback (#25) — Design Review Log

## Review — 2026-06-11 — Verdict: NEEDS REVISION → revise-now → **APPROVED**(同 session)
Scope signal: **L**(5 formula、6+ dependency、需 ADR-0001 amendment[2 層]、Presentation autoload + UI)
Specialists: **degraded-inline**(game-designer / systems-designer / qa-lead / godot-specialist / performance-analyst / ux-designer domains — Task subagent spawn 受 1M-context credit 限制 fail，改 single-session adversarial + grep-verify against shipped src/，跟本 project #18/#19/#21–#24/#26-Pass6/#29 degraded-inline 先例)
Blocking items: 1 | Recommended: 9 | Nice-to-have: 7
Prior verdict resolved: First review

### grep-verified 上游 contract（全 EXACT，除 #26）
| Claim | Shipped src | 結果 |
|---|---|---|
| #6 dispatch `HIT_HEAVY → shake(0.4,0.12) pause=0`（命脈缺口） | screen_effects.gd:203 | ✓ EXACT |
| #6 `PARRY pause:0.06` / `DEATH shake(0.3) pause:0` / `HIT_LIGHT:{}` | :204-209 | ✓ |
| #6 `hit_pause()` clamp≤`MAX_PAUSE_SEC=0.12` + max-remaining merge | :308-320,:55 | ✓ |
| #5 `play(preset_id, position, multiplier=1.0) -> ParticleHandle` | particle_system_wrapper.gd:419 | ✓ EXACT |
| #5 9 closed PresetId 無 HIT_CRITICAL / `MAX_ACTIVE_PARTICLES=200` / `EVICTION_MIN_LIFE_MS=150` | :30,139,147 | ✓ |
| #13 `DamageTier{NEGLIGIBLE,LIGHT,MEDIUM,HEAVY,CRITICAL}` + `HitOutcome{NORMAL_HIT,CRITICAL_HIT,KILLED,OVERKILL}` + `T_CRITICAL=0.40` | combat_resolver.gd:44-59,87 | ✓ |
| #13 crit-override「every crit reads ≥ HEAVY」（令 is_crit→tier≥HEAVY） | :363 | ✓ supporting R-12 |
| #14 hit_resolved payload（target_id/outcome/damage_tier/damage_dealt/damage_raw/is_crit/transition_id，**無 position**） | combat_resolver.gd:164-172 | ✓ EXACT |
| #4 `play_sfx(event_id: StringName)` | audio_manager.gd:235 | ✓ |
| enemy-director L592 列 #25 downstream / #6 L9「Depended On By」#25 / #13 L889/L1170 damage number 歸 #25 | GDD docs | ✓ |
| **#26 anchor / position / facing API** | avatar_renderer.gd（只 get_visual_state/get_class_posture/get_evolution_tier/get_animation_state/get_evolution_snapshot） | 🔴 **唔存在**（render-only ADR-0010）→ R-2 |

### Required Before Implementation（BLOCKING）— RESOLVED
- **B-1** [engine/architecture] Damage-number pool host-node topology 自相矛盾（autoload-owned + world-space + 跟 world shake + 坐 layer 10-50 + 唔開新 CanvasLayer），無法 implement；Q-CV2 ADR amendment 只 cover overlay 105，漏 number host。**Fix**：pin #25-owned `CombatNumberLayer`（follow_viewport_enabled，shake-uniform 範圍內）+ 折入 Q-CV2 兩層 ADR scope。

### Recommended Revisions — 全 RESOLVED
- **R-1** [game/systems] 招牌 Player-Fantasy「一刀 CRITICAL 劈死」喺 KILLED（非 OVERKILL）時 R-3/F4 route 去無 pause/flash → 不可達。**Fix**：R-9 climax-kill carve-out（KILLED+CRITICAL→flash+80ms）+ F4 + AC-30。
- **R-2** [systems/engine] #26 anchor API grep 證實唔存在 → F5/R-17/Dependencies 將 phantom API 寫成 primary。**Fix**：camera-relative fixed focal point = MVP primary；#26 anchor 降 v0.2；dep 剔走 #26；Q-CV4 RESOLVED。
- **R-3** [game] HEAVY/CRITICAL shake 相同（0.4）+ pause 只差 15ms（<peripheral JND）→ 真 tier marker 得 flash，而 flash ratification-gated；未 ratify HEAVY/CRITICAL peripheral 不可辨。**Fix**：EC-20 degrade-mode `CRITICAL_DEGRADE_PAUSE_SEC=0.100`（pause 單獨拉開 ≥35ms）。
- **R-4** [systems] F3 `_last_particle_ms` dict 隨死敵無限增長（30-60 分鐘 workout leak）。**Fix**：enemy_killed evict target_id（R-14 + F3 註 + AC-31）。
- **R-5** [QA] test seam 缺 injectable monotonic clock → AC-13/14 time-dependent flaky。**Fix**：DI seam 加 FakeClock `_now_ms()`。
- **R-6** [QA] AC-07 兩個合法 outcome 非 deterministic。**Fix**：拆 AC-07a（ratified flash）/ AC-07b（degrade）on config flag。
- **R-7** [QA] AC-24（ADR-gated）+ AC-28（mobile Safari P95）唔可 CI auto-pass。**Fix**：明標 `pending()` skip-with-reason，防假綠；AC-28 拆 CI-testable 三項 vs hardware-gated P95。
- **R-8** [engine] #25 確定 autoload 但無 ADR-0008 boot position。**Fix**：governing ADR 寫 tail-append after {#14,#6,#5,#1}。
- **R-9** [QA] coverage gap（EC-12/15/19 + F3 eviction 無 AC）。**Fix**：補 AC-31..34。

### Nice-to-Have（部分 applied）
- N-1 ✅ F1 ease_out ratio clamp[0,1]（applied）。N-2 ✅ F3 int-clean sentinel（applied）。N-5 ✅ WCAG 2.3.1 文件化（applied）。N-7 ✅ §Interactions #20 citation 修正（combat-resolver 已歸 #25 @ L889/L1170，非 L1167/#20）。
- N-3（AC-26/27 falsifiable proxy）/ N-4（_process has-active-work early-out）/ N-6（flash 未必需 shader）— carry epic-time（ADVISORY，唔 block）。

### Senior Verdict（degraded-inline synthesis）
架構 sound、上游 contract 全 grep-verify EXACT（除 #26 anchor 證偽）、completeness 8/8、CD-GDD-ALIGN 已 APPROVE。問題三類：(a) 一個真‧unimplementable 矛盾（number-pool host B-1）；(b) 兩個 Player-Fantasy 兌現 gap（critical-kill spectacle R-1；HEAVY/CRITICAL peripheral 分離靠 gated flash R-3）；(c) 一串 spec-accuracy / testability 修正（#26 phantom dep、dict leak、clock injection、gated-AC honesty）。全部 fixable，無 architectural rewrite。同 session revise-now 全收，0 phantom。**APPROVED**。

### Lesson
- **Rep Map「project-API facts」要 grep shipped src 驗，唔信 GDD anticipatory ref**：#26 anchor 係 GDD 設計時自報嘅「新 dep」，但 grep avatar_renderer.gd 證實 render-only 零 position API → phantom dep。同 [[feedback_citation_grep_verify]] 家族；reviewer grep 推翻 author 嘅 dependency 假設。
- **autoload-owned + world-render 矛盾**：autoload Node2D 預設坐 root，唔自動入 gameplay world layer / 唔食 world-shake uniform；任何「autoload 擁有 world-space shaken node」spec 要明寫 host topology（follow-viewport layer / reparent）。
- **outcome-first gate 會吞 tier spectacle**：R-3 outcome gate 令 critical-tier kill 行 KILLED 分支 → 失 flash/pause；招牌 fantasy moment 要 carve-out 回 tier-aware。
