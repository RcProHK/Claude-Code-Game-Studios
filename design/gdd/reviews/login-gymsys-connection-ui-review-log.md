# Review Log — Login / GymSys Connection UI(Shell) #24

## Review — 2026-06-08 — Verdict: NEEDS REVISION → REVISED(同 session inline)
Scope signal: M(GDD 自稱 S;boot-race pull-check + cancellation pin + 2 條新 additive API + debounce 刪除 cascade 推到 M)
Specialists: game-designer / systems-designer / qa-lead / ux-designer / ui-programmer / godot-specialist(6 adversarial)+ creative-director(synthesis)
Mode: fresh independent `/design-review`(full mode;authoring session 之後嘅獨立 re-review — independence 紀律)
Blocking items: 6 | Recommended: ~14 | Freeze: 否(首輪 fresh review,結構生還,blocker 全 grep-verified real gap)

### 6 BLOCKING(全部同 session inline 收 — user full-autonomous 指示)
1. **auth_required boot-race(致命,godot B1 + CD 加碼)** — #2 AC-08(gymsys-backend-client.md L596)contract `_ready()` 同步 emit auth_required;#24 tail autoload 必 miss → 首次開機黑屏。修:G-LS-4(c) `is_auth_required()` pull-check(Rule 2 / EC-E5 / AC-53)+ **8-signal boot-window sweep 表**(systemic blind spot 收口:「為 category 第一 instance 工程化 pattern 但冇 sweep 成個 category」)。
2. **error_severity_map silent dead-end(game+systems+qa 三命中)** — 無 default-deny fallback,#3 加第 13 code → lookup miss → silent drop = 證偽 Pillar 1。修:Rule 5 source-first dispatch + UNMAPPED row + EC-B9 + AC-52。
3. **Honest Door vs directional debounce 自相矛盾 + cross-GDD 衝突(多命中)** — held-ENABLED window tap → EC-E4 reject = Test 4 禁止;且 #22 EC-30(L350)DISCONNECTED 全功能本地 view → grey 全功能 surface = 細講大話。修:**整套刪 debounce / Formula 1 / EC-C1 / ENTRY_DISABLE_DEBOUNCE_SEC / invariant 1 / AC-13-15**,入口 enabled/hidden 二態。
4. **AC phantom-pass 群(qa+ui+godot cluster)** — AC-26 tautological / AC-21 只測合法 knob / AC-35 grep 誤殺 cross-fade + 漏 .tscn / AC-06/07/08/22 倚賴未釘 G-LS-3 卻 BLOCKING。修:AC-26 真斷言 / AC-21 _validate_knobs 兩路 / AC-35 拆 35a+35b / claim AC relabel GATED G-LS-3。
5. **BannerStack sort non-deterministic(systems+ui+godot 三命中)** — sort_custom 非 stable + StringName pointer-sort → EC-B2/AC-29 deterministic 不可達。修:total-order comparator (severity, arrival_sequence) + StringName 轉 String + AC-29b。
6. **claim_session cancel await-hang(godot B2 + qa B3)** — #2 cancel 唔保證 request_completed fire → await 永不 resolve → submit 掛死。修:G-LS-3 cancellation 語意 pin(resolve cancelled result 或 race timer)。

### RECOMMENDED(一併 inline 收)
WIPE copy lead-with-impact(cry-wolf 修正)/ ONGOING acknowledge-to-minimize / region GDD-level arbitration(Rule 7 — 唔純 punt ux-design)/ a11y announce_aria routing(canvas DOM 不透明,非 AccessKit)+ SR re-announce 防護 / cross-knob invariant 2 cartesian fix(DRAIN range 收窄 ≤3.0)/ iOS 16px canvas no-op caveat + dual-focus(G-LS-6 擴)/ F1 m:ss format / credential residue(AC-50)/ clock seam(AC-51)/ banner two-layer 獨立性(AC-54)/ 多條 EC 補 AC / orphan placeholder 刪。

### 結果形態(REVISED)
15 Rules / 5-state shell FSM / **2 active formula**(rate-limit + banner-expire,F1 debounce 已刪)/ **26 ECs**(7H/11M/8L)/ **56 active ACs**(39B / 10 GATED / 6A / 1E;AC-13/14/15 移除留 placeholder)/ **G-LS-1..9**(G-LS-3 加 cancellation;G-LS-4 加 (c) is_auth_required)/ 8-signal boot-window sweep 表 / 7 上游 Q 閉環。

### 系統性發現(CD)
finding #1(unmapped)+ #5(boot-race)+ #12(#8/#11/#12 boot sweep)= 同一元缺陷「為 category 第一 instance 工程化對嘅 defensive pattern,但冇 sweep 成個 category」。Revision 交 8-signal sweep 表收口。

Prior verdict resolved: 是(authoring-session CD-GDD-ALIGN CONCERNS 已 REVISED;本輪係 fresh independent re-review,獨立紀律)
NEXT: fresh session re-review(independence — revision author 唔自 re-verify)→ APPROVED 後 /ux-design(Z5/Z6 region 已 GDD-arbitrate,ux 釘 pixel)→ /create-epics
