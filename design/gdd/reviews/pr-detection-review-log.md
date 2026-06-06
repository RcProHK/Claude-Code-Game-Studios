# PR Detection & Avatar Progression (#18) — Review Log

## Review — 2026-06-06 — Pass 3 — Verdict: ✅ APPROVED
Scope signal: L
Specialists: creative-director(grep spot-check,照 #17 Pass 3 先例)
Blocking items: 0 | Recommended: 0(2 trivial errata 已 same-session 收:seam ⑤「ring」字眼 + buffer keep-latest 注)
Summary: Pass 2 嘅 6 targeted BLOCKING 逐項 grep 確認 FIXED(NEW-1 buffer 三處一致 + load-bearing 注 / NEW-2 ADR §D-2.3 D8 ratchet 語意 / NEW-3 WEIGHT_SANITY_MIN 下界 + 公式上界 + AC-23 六 vectors / NEW-5 D8 pipeline + commit-time magnitude 重計 + AC-29 數驗過 / G-PR-3 chain 同 project.godot:42-45 一字不差 / AC-01..31 零 gap)。8 項 RECOMMENDED 抽驗全中(to_dict 先例 citation 字字準確 / workout_seq / telemetry 16 events / G-PR-5 test 反轉 grep 實證 / G-PR-6 lint 未 shipped / Formula 4 max() / zone L14-L39-L43-L64 / G-PR-4 pin)。Cross-GDD citation 終驗 0 phantom、0 方向讀反;Position A–F 零漂移;數值 spot-check 全部驗算正確。三 pass 收斂軌跡:16 clusters → 6 targeted → 0。**Epic creation UNBLOCKED → /create-epics pr-detection。**
Epic 方向提示(CD):story 1 綑綁三件 wiring(CI whitelist + G-PR-3 ADR-0008 amendment + G-PR-6 namespace);G-PR-5 四件套獨立 story(skip source==0 / test_unlock_path_b_multi_tier.gd:98-99 反轉 / is_boot_completed() getter / L890 comment);AC-22 標 BLOCKED-ON G-PR-2;G-PR-1 = GymSys backend 外部 story(offline grace 唔 block epic)。
Prior verdict resolved: Yes(Pass 2 6 BLOCKING 全 FIXED)

## Review — 2026-06-06 — Pass 2 — Verdict: TARGETED REVISION(fresh 3-verifier)
Scope signal: L
Specialists: systems-designer + qa-lead + godot-specialist(fresh context,verify Pass 1 fixes + 捕 revision 自引)
Blocking items: 6 | Recommended: ~10 | 結果: Pass 1 全 16 clusters 確認 FIXED;citation 0 phantom(project 首次 fix pass 全 clean — 唔觸發 freeze)
Summary: 6 targeted BLOCKING — NEW-1 AC-30/Rule 6.7/Rule 10 三向矛盾(+short-circuit path 令 gate load-bearing);NEW-2 ADR §D-2.3 server ratchet 缺 D8 corroboration 語意(typo 經 server 軸重現壓制);NEW-3 §D-2.2 下界 >0 留 near-zero hole(÷0 sibling);NEW-5 D8 pipeline 未 pin + stale-magnitude commit 破 INV-PR-2 upper bound(worked example 實證)→ commit-time 重計;G-PR-3 chain `WST ≺ AbilitySystem` 同 project.godot + ADR-0008 相反(Pass 1 review log 自己寫錯指示,revision 忠實執行 — Pass 1 漏 grep);AC-29 numbering gap。RECOMMENDED:to_dict boundary / workout_seq / telemetry String+append-log / G-PR-5 test 反轉 scope / G-PR-6 lint 未 shipped / Formula 4 candidate 棄用 lose 真突破 / INV-PR-2 lower bound qualify / 75.833 precision / AC-23 第五 vector / pr.persist_failed / GSM 無 READY enum 注。三 verifier 一致:Pass 3 = quick verifier-grep 級,唔使 full re-review。
Prior verdict resolved: Yes(Pass 1 16 BLOCKING 全 FIXED + exit bar 0-phantom 達成)

## Review — 2026-06-06 — Pass 1 — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-specialist + creative-director (senior synthesis)
Blocking items: 16 clusters | Recommended: ~10 | Nice-to-have: ~8
Prior verdict resolved: First review (degraded-inline authored 2026-06-06; 本次係 GDD 自標嘅 mandatory fresh-session /design-review)

### Summary
骨架配得上 Pillar 1 心臟系統(D5 monotonic idempotency 優雅、D1-D6 紀律高、topology 無人質疑、全部 fix 係 spec-level),但:(1) **cold-start warmup-ramp 假 PR cascade** — Formula 4 只擋第一 set,新 exercise ascending ramp = default path 連串假 PR(三 specialist 獨立發現,EC-10 自相矛盾);(2) **G-PR-1 server baseline contract 四面全空**(formula parity / value validation [server 回 0 → ÷0 → clamp 2.0 = 保證假 max PR] / ratchet 語意 [microloading 永久壓制] / sync timing);(3) **需要 ADR-0011** — game-concept Q3 L298 要求「server-side 判定 + ADR」,Q-N3 client-derivation 論證 on-merits 收貨但必須以 ADR 正式 supersede + #11 EC-36 / #12 FR-2 guarantee mapping。

### CD Design Position 裁決(binding,revision 按此落實)
- **A. Max single dead-zone**:維持單一 e1RM 尺(economy 方)。Mitigation:`one_rm_kg`→`e1rm_kg` 改名 + `pr.weight_novelty_no_pr` telemetry + 新 EC 標明 intended + Future Extensions dual-track(trigger:novelty 率 ≥5% set 數)。
- **B. REP_CAP**:skip → **clamp**(`effective_reps = min(reps, 12)`)— true lower bound,anti-fabrication-safe;rep-only 增長 cap 後零 PR。
- **C. PR 頻率 cliff**:接受 cliff(lifetime ratchet = stats 唯一通道;rolling-window stats 不可行 — #11 churn)。加「Progression cadence ownership」段 + Q-PR-1 擴 scope(真 GymSys 數據回放 by training age)+ #15「hardcore 7 PR/週」erratum risk note + veteran baseline import reveal(presentation)+ windowed 慶祝 = Future Extension。
- **D. Typo 防線**:升格 BLOCKING。soft-confirm:`SUSPECT_PR_MAGNITUDE`(0.30 [0.15,0.5])→ PENDING_CONFIRMATION(delta/signal/count 全 hold)→ 後續 set corroborate 先 commit。WEIGHT_SANITY_MAX 接線 Rule 2。
- **E. Baseline Forged moment**:升格 BLOCKING(同 cold-start fix 綑綁)— player-visible glance event + ≥1 binding experience AC。
- **F. Celebration 倒掛**:mid-set 層級係 Pillar 2 正確結果(唔調 sting)。BLOCKING 部分 = summary schema 加 raw weight/reps;RECOMMENDED = consumer-forward contract(end-of-workout PR recap ≥ loot tier)route #20/#29。

### BLOCKING(16 clusters,來源標註)
1. Cold-start warmup-ramp cascade [game-designer+systems+economy] → baseline window = 首 workout,INV-PR-1「No trusted baseline, no PR」
2. G-PR-1 四 sub-spec 全空 [systems B-2/3/4] → 落 ADR-0011
3. D2×D5 server-LOWER double-count race [qa F2] → session-confirmed floor + EC + AC
4. Typo soft-confirm [game #8, CD 升格] (Position D)
5. IPersistence 冇 enumeration — `pr.best.*` unimplementable [godot #1 + systems B-6] → 單一 `pr.baselines` key
6. #12 double-path:stat_changed 搶先 STAT_THRESHOLD unlock [godot #2] → 新 gate G-PR-5(#12 additive:`_on_stat_changed` skip source==PR_BREAKTHROUGH)
7. BASELINE_SYNCING farmable window [systems B-5] → fail-closed 入 INV-PR-1
8. Summary clear 訂錯 signal(#9 係 `workout_completed_forwarded`)+ use-after-clear race [game #4 + godot #5] → clear 改 next `workout_started`
9. Summary schema 餵唔起 receipt「180kg×5」 [game #3 + systems R-11] → 加 raw weight/reps/exercise_id + `e1rm_kg` rename
10. L101 reps=1 矛盾 [全員] → 刪,AC-11 wins
11. WEIGHT_SANITY_MAX orphan knob [三人] → Rule 2 接線 + AC(+考慮 WEIGHT_SANITY_MIN 擋 tiny-baseline)
12. L47 phantom「#11 clamp 最後防線」 [systems B-8] — #11 EC-36 L553 原文相反 → 改寫 + ADR-0011 guarantee mapping
13. #12 EC-16 義務(wait boot_completed + GSM Ready 先 emit)零着墨 [systems B-7]
14. G-PR-2 #9 接線方向未 spec + G-PR-3 chain 唔完整 [game #14 + godot #3] → pin `WST ≺ AbilitySystem ≺ PrDetection`
15. `src/feature/` phantom path + vacuous lint [godot #4] → `src/autoload/pr_detection.gd` + epic story 修 lint(whitelist 2/4 stale + regex 被 DI 繞過 — escalate lead-programmer)
16. qa-lead:AC-07 rewrite(soft-confirm 吸收)/ AC-20 validation-function form / AC-22 標 GATED(G-PR-2)+ split;seam list 對齊 #17 8-seam(加 telemetry spy / #2 async mock / #9 / #12 spy / GSM,刪 TimeProvider);coverage gaps(EC-6 / EC-11 / boot ordering / boundary ==0.01 / milestone no-re-emit / pr.detected / aggregation vector)

### RECOMMENDED
- `pr.*` namespace #3 註冊 gate(VALID_NAMESPACES + registry + CI lint)[godot #7] — sync flags 漏咗 #3
- Telemetry 機制 pin internal ring pattern(#15/#17 先例)[godot #8]
- D5 crash-window(6.3↔6.4)caveat + deliberate-decision 記錄 [systems R-9]
- δ==0(stat cap)short-circuit:skip 6.3,直行 6.4-6.6 [systems R-12]
- Float boundary epsilon(`>= MIN_PR_MAGNITUDE − 1e-9`)+ exact-boundary AC [systems R-10]
- Milestone 三處 stale「MVP 無 consumer」→ cite #19(zone-system L22/L43/L64 已接線)+ bidirectional 表 [economy #5];milestone thresholds 標 PROVISIONAL;**CD directive route 去 #19 review:MVP zone unlock 用 streak/workout-count kind,PR_MILESTONE 留 v0.2**(+建議 milestone 軸改 Σmagnitude — #19 design space)
- MAX_PR_FACTOR cite 撤回(上游 #15 內部三矛盾:EC-42 count-clamp 10 / knob 1.25 / Q-OQ4 ratio[0.5,2.0])→ 防線 rest 於 INV-PR-2 log-additivity(named invariant + property AC)+ erratum flag 畀 #15 owner [economy #3/#4]
- G-PR-1 揀「polling state response 加 field」option(catch-up race 結構性消除)[godot #6];INITIALISING sync-`_ready` 慣例寫明
- AC-22「UTC 日界」改「per #9 daily 語意」 [systems N-14];String vs StringName 注明跟 #2(String)[godot #11];PR 雙 write collapse(baselines flush=false → lifetime_count flush=true)[godot #10]
- Retro-logging / late-set edge case(workout_completed 後 PR 唔入 summary,telemetry only)[game #18 + systems R-11]
- 補 expected PR frequency 表(provisional,Q-PR-1 實證化)[economy #7]

### Specialist Disagreements(CD 已裁,見 Position 裁決)
A(game vs economy:dual-track vs 單一尺 → 單一尺)· B(clamp vs skip → clamp)· F(mid-set 層級 → 維持,修 end-of-workout)· B-8 措辭(「防線唔存在」→「incidental fail-soft 誤寫成 designed defense」)

### Exit Bar(re-review 通過條件)
1. 全部 BLOCKING 落 GDD;2. **ADR-0011 authored**(Q3 supersession + G-PR-1 四 sub-spec + guarantee mapping + caller path);3. **0 new phantom** — 全部 cross-GDD citation enumerate + 逐條 grep-verify 附上游 line quote(無 sampling);4. 新 ACs:warmup-ramp golden / server 0-負數 reject / double-count race / soft-confirm 三路徑 / boundary 0.01 / ≥1 experience AC(Baseline Forged);5. Position A-F 照裁決落實。
Validation criteria:Q-PR-1 真數據回放 — 首 workout 零 PR;novice 每週 2-6 PR;`pr.weight_novelty_no_pr` <5% set 數;零 magnitude>0.3 無 corroboration commit。

### 正面確認(revision 唔好掟走)
D5 monotonic idempotency / log-additivity(升格 INV-PR-2)/ D1-D6 block / ADR-0010 邊界紀律 / AC-12=0.500 golden 同 #11 grep 一致 / citation 整體 clean(僅 1 phantom B-8 + 1 ambiguous MAX_PR_FACTOR — 遠低 freeze 門檻)
