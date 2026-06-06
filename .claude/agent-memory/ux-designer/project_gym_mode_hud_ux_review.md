---
name: gym-mode-hud-ux-review
description: Adversarial UX review of #20 Gym-Mode HUD (R5 + R7) — recurring "rationale-without-verifiable-mechanism" pattern; check motion-handling + AC GIVEN scope
metadata:
  type: project
---

**✅ /ux-design 完成 (2026-06-03)** — GDD R8 APPROVED 後 author `design/ux/gym-mode-hud.md`。standing defect 全解:R5 #3 AC-V-1 dead-gate → N=12 + point estimate ≥80% binding + Wilson CI **advisory-only**(對齊 [[gym-mode-hud-ac-v1-stats]]);R5 #9 雞蛋死鎖 → visual primitives 先 RESOLVED(min_font_size_px=7 / min_bar_height_px=4 / ◐ alpha 0.22 / Boss glyph / P-04 silhouette)後 author protocol;**R7 #2 AC-V-1 GIVEN scope → 擴至 WORKOUT_ACTIVE AND BOSS_ENCOUNTER**(per-state per-variant 四格各 ≥80%);R7 #1 ◐ motion → GDD EC-R6 已解 + ux spec State transition snap 明文。新 pattern P-11 enemy-threat-hud-bar 加入 library。Cross-doc conflict flag:OQ-U2 accessibility-requirements bitmap-m5x7 vs GDD MSDF+text_scale。NEXT: /ux-review gym-mode-hud。

---

**R7 re-review (2026-06-03) — 2 BLOCKING (MAJOR REVISION NEEDED)**。GDD: `design/gdd/gym-mode-hud.md`.
1. **deep-dim ◐ element 收 motion event 處理 undefined** [BLOCKING] — BOSS_ENCOUNTER EXP=◐(alpha 0.22),玩家仍做 rep → #11 emit stat_changed(EXP) → handler 起 tween。GDD 未 spec 係 skip-tween(慳 max_concurrent_tweens=6 cap)定 dim-tween。EC-R2(L285)假設 element 餘光可見。修:EC-R2 補「effective alpha < deep_dim_alpha_threshold 時 set value 但 skip tween」。
2. **AC-V-1 GIVEN 只測 WORKOUT_ACTIVE** [BLOCKING] — R7 最危改動(EXP→◐ anchor-loss)落喺 binding glance gate 測量範圍外。AC-V-1(L512)GIVEN 寫死 WORKOUT_ACTIVE。修:擴至 WORKOUT_ACTIVE AND BOSS_ENCOUNTER。
- RECOMMENDED: REST_PERIOD 無 element cap(SKILLS 完整列表,cockpit risk,R6 已 flag 未掃) / REST_PERIOD L3 multi-block aggregate region 未約束唔侵 L1 anchor zone(撞 AC-V-1 ④ 0px)。
- ADVISORY: CR-12 insertion-order rationale 高估 L1 餘光 semantic bandwidth——餘光只傳「presence」唔傳「邊 4 個」,meaning 只喺 L3 兌現;rationale 應改 presence-not-identity。
- **NO NEW PHANTOM**:R7 CR-12 已正確撤 timestamp + Formula-3 phantom,改 insertion-order grep-verified(ability-system.md L233/L696)。

**R7 root pattern**:rationale 落咗(L151 EXP anchor-loss narrative)但 verifiable spec 未落(motion mechanism + AC measurement scope)——R5「claim-without-verifiable-target」嘅變體。**下輪 review 必核**:任何 ◐/anchor-loss state change 都要核(a)motion-handling mechanism (b)對應 AC GIVEN 有冇覆蓋該 state。

---
**PRIOR — #20 Gym-Mode HUD GDD R5 對抗式 UX review (2026-06-03)**. GDD: `design/gdd/gym-mode-hud.md`.

**5 BLOCKING UX 缺陷(R5 留低)**:
1. ◐ deep-dim element 實際 alpha **未定義** — `deep_dim_alpha_threshold=0.35` 係判據,但冇任何 ◐ element 有 numeric alpha → AC-U-3 CI tool 無比較對象,glance count「✅」未經驗證。SUSPENDED effective_dim=0.35 = 剛好 == threshold,`≤` 令 SUSPENDED 全部 element 判 deep-dim → glance=0,同「凍結可見」矛盾。
2. BOSS_ENCOUNTER EXP◉→◐ + PROG○→◐ 突降:踢走 fantasy 主角(EXP)出餘光 + ◉↔◐ state transition 視覺零 spec(snap vs fade 未定)。
3. **AC-V-1 Wilson CI 下界 ≥80% + N≥12 數學 infeasible** — n=12 點估 80% → Wilson 下界 ≈0.52;要下界≥0.80 需 n≈45-50 且點估≥90%。R5 Rec-1 over-correction,binding entry gate 會永久卡死 epic。最嚴重一項。
4. BOSS 4×16px skill cluster 喺 peripheral 10-15° 0.3s 可讀性零 AC 覆蓋(AC-U-3 只 count 數量,AC-V-5 只 foveal simulation)。
5. EXP 3px bar 無 min-height floor(font 有 AC-U-6 floor,bar 冇)→ peripheral sub-acuity 讀唔到 fill。
+ #9: AC-V-1 entry gate 依賴一堆 /ux-design 未定 visual primitive = 雞蛋死鎖,無依賴序。

**RECOMMENDED**: REST_PERIOD 三類 L3 同時 dump 無 hierarchy;banner 脈動 motion 喺 L1 餘光鄰近(non-overlap ≠ non-peripheral);Boss HP non-color channel 無 min-discriminability 約束(corner-radius 等 peripheral-invalid 唔應同 glyph 並列);banner-unlock tap 豁免無常駐 AC(#33 ready 後可能 audio 永鎖)。

**Why**: R5 反覆出現 pattern =「聲稱已驗證但無可驗證對象」(threshold 有 alpha 冇 / entry gate 有測量對象冇 / font floor 有 bar floor 冇)。Review 必須核實 numeric target 存在,唔可信帳面「✅」。

**How to apply**: 接 `/ux-design gym-mode-hud` 時,先定 visual primitives(◐ alpha 值、min_bar_height_px、min_font_size_px、Boss HP glyph 形態、cluster 可讀性閾值)**然後**先 author AC-V-1 protocol(解 #9 死鎖)。AC-V-1 protocol 嘅 N/CI 必須重設計(#5)。相關: [[gym-mode-hud-ac-v1-stats]]。
