# Gate Check: Pre-Production → Production

**Date**: 2026-06-12
**Checked by**: `/gate-check` skill (review mode: **full** — 四 director panel 全跑)
**Verdict**: **CONCERNS** — eligible to advance,但帶 4 組明文 condition(全部 = Production Sprint 1 內容)

---

## 背景:呢個 gate 嘅特殊形狀

呢個 project 嘅 Pre-Production→Production 缺口**唔係 scope/code,而係 validation + tracking infrastructure**。Code 反而**超前**:

- 114 個 `.gd`、28 autoload(`src/autoload/`,對齊 ADR-0008)
- 440 個 test file;full-project combined gate(`-gdir=tests/unit,tests/integration`)= **2861 tests / 0 fail / 3 honest pending**
- 30 個 epic(`production/epics/`)全部 IMPLEMENTED + committed(`da478b8`)+ GitHub CI tests.yml GREEN
- 33 系統 GDD、12 ADR(全 Accepted variants)、art-bible 9 sections、10 UX spec(全 ux-review APPROVED)

但 `production/stage.txt` 仍標 **Pre-Production**,而項目自定嘅 Pre-Prod go/no-go(vertical slice + human playtest,見 `game-concept.md` L333/L342/L343)**從未 trigger 過**。

---

## Required Artifacts

| Artifact | 狀態 |
|----------|------|
| All MVP-tier GDDs complete | ✅ 33 GDD |
| Master architecture doc (`docs/architecture/architecture.md`) | ⚠️ 存在但 **STALE**(v1.1 / 2026-05-28 / 標「12 GDD」「ADR-0001..0008」vs 實際 33 GDD / 12 ADR) |
| 3+ Foundation-layer ADRs | ✅ 12 ADR |
| All Foundation/Core ADRs status = Accepted | ✅ |
| Control manifest (`docs/architecture/control-manifest.md`) | ⚠️ 存在但 STALE(同上 drift) |
| Epics defined (foundation + core) | ✅ 30 epic |
| Art bible complete (9 sections) + AD-ART-BIBLE sign-off | ✅ 9 sections;sign-off = "CONCERNS Accepted 2026-05-28"(6 concern 全 resolved inline) |
| UX specs for key screens + ux-review APPROVED | ✅ 10 spec(gym overlay 無傳統 main-menu/pause;login-ui = entry,gym-mode-hud = core HUD) |
| **Vertical slice build + REPORT.md** | ❌ 缺席(prototypes/ 只有 tween-spike + visual-mockup,都唔係 VS)→ CONCERNS |
| **Vertical slice playtested (1+ session)** | ❌ 缺席 → CONCERNS |
| **First sprint plan (`production/sprints/`)** | ❌ dir 不存在(工作用 epic/story 追蹤)→ CONCERNS |
| Entity inventory (`design/assets/entity-inventory.md`) | ❌ 缺席(`entities.yaml` 容器空,`entities: []`)→ CONCERNS |

## Quality Checks

- ❌ **Core loop fun NOT validated by human** — 只有 automated functional test green;`game-concept.md` L305 core hypothesis 兩半(mid-set glance watchable / 爆裝值得返嚟)從未人類驗證
- ❌ No human playtest(`production/playtests/` dir 不存在)
- ✅ All MVP GDDs pass design-review;all UX passed ux-review
- ✅ Foundation/Core ADR coverage complete;boot-order 對齊 ADR-0008
- ⚠️ Performance budgets documented(ADR-0001)但 **VS-tier hardware profiling 從未做**(iOS Safari WebGL2 / CPU budget 數值未驗)
- ⚠️ GymSys backend transport(ADR-0002/0004)從未接真 backend(`gym_sys_backend_client.gd` 無真 endpoint;無 nginx config / docker-compose)

---

## Director Panel Assessment (review mode: full)

| Director | Verdict | 核心 finding |
|----------|---------|-------------|
| **Creative Director** (CD-PHASE-GATE) | **CONCERNS** | Pillar fidelity 全 PASS（5 pillar + anti-pillar 架構級鎖死）；但 core fantasy hypothesis 從未人類驗證 = 成個 game 嘅賭注未開。推薦 focused VS playtest 先驗兩半 hypothesis。 |
| **Technical Director** (TD-PHASE-GATE) | **CONCERNS** | 架構 sound、ADR/boot/CI 齊。3 concern:(A) VS-tier 真環境 spike 一個未做（GymSys/CORS/iOS）；(B) architecture.md / traceability / control-manifest 三份 **STALE**；(C) 未驗假設要立 risk register。推薦 Sprint 1 = VS-tier spike sprint。 |
| **Producer** (PR-PHASE-GATE) | **CONCERNS** | Code throughput 超 entry bar，scope 對 solo dev REALISTIC。但 production tracking infra 缺：`sprints/` `milestones/` `risk-register/` `playtests/` 四 dir 從未建立；14 個 external gate 無集中 burndown view。Conditions C1（external-gate burndown）/ C2（首個 milestone）/ C3（Sprint 1 deliverable = VS 真跑 + Web Export smoke）。 |
| **Art Director** (AD-PHASE-GATE) | **CONCERNS** | Visual identity production-ready 且質素極高（art-bible 9 section + mockup CONFIRMED）。3 個 sprite 開工前必 close 嘅 tooling gap:C-AD-1 entity-inventory.md（`entities.yaml` entity list 空）、C-AD-2 `tools/ci/asset_validator.gd` 缺席、C-AD-3 `assets/.godot_import_presets/pixel_art.tres` 缺席。 |

**Escalation**:四 director 全 CONCERNS,無 NOT READY → overall 最低 CONCERNS,但全部係「READY-with-conditions」,無 blocker 阻止推進。

---

## Chain-of-Verification

5 challenge 問過,2 個 [TOOL ACTION]:
- [TOOL ACTION] 確認 `architecture.md` v1.1 / 「12 GDD」「ADR-0001..0008」= STALE（實際 33 GDD / 12 ADR）→ 證實 TD CONCERN-B
- [TOOL ACTION] 確認 `production/playtests/` + `production/sprints/` dir 不存在 → 證實缺席
- 「skipped vertical slice 應否升 FAIL?」→ skill 明文 skipped slice = CONCERNS（非 FAIL）；四 director 一致 CONCERNS → 不升
- 「有冇將 FAIL 軟化成 CONCERN?」→ 無;fun-validation 缺席係真 risk 但可解於 Sprint 1
- **Verdict 維持 CONCERNS — unchanged**

---

## Verdict: CONCERNS (advisory — user 決定是否推進)

Code artifact 大幅超越 Production-entry bar,四 director 一致「可推進但帶 condition」。缺嘅嘢**全部係 Production Sprint 1 應交付嘅內容**,唔係入 gate 前嘅前置 blocker。

### 收斂建議:Production Sprint 1 = 「Validation & Infrastructure Catch-Up」

唔砌新 code（internal code 已 essentially done）。Sprint 1 agenda 收斂四 director 建議:

1. **VS 真跑 + 第一次真 Web Export smoke**（CD-1 / TD-A / PR R1+R2+C3）— mock GymSys data 餵入,end-to-end workout→loot→avatar→mirror moment 跑一次,寫 VS report
2. **第一次 human fun-check playtest**（CD Option A）— 驗 core hypothesis 兩半,寫 `production/playtests/`
3. **Refresh stale 架構 doc**（TD-B）— fresh `/architecture-review` regenerate + bump `architecture.md` v2.0 + systems-index header
4. **建 external-gate burndown + risk register + 首個 milestone**（PR C1+C2 / TD-C）— 集中追 ~14 external gate（GymSys deploy / hardware profiling / art sign-off / ADR ratification）
5. **Asset pipeline sprint-0**（AD C-AD-1/2/3）— entity-inventory + asset_validator.gd + pixel_art.tres preset

> ⚠️ **關鍵 reframe**:Sprint 1 大部分 deliverable（human playtest、真瀏覽器測試、GymSys backend deploy、hardware profiling、真 sprite 製作）**需要 user 親手做或外部資源**,唔係 autonomous code task。呢度係「完成遊戲」由 autonomous implementation 過渡到 human-in-the-loop validation + external execution 嘅自然 boundary。

### 引用 file

- `design/gdd/game-concept.md`（pillars / core hypothesis L305 / VS go-no-go governance L333+342+343）
- `docs/architecture/architecture.md`（STALE v1.1）、`requirements-traceability.md`、`control-manifest.md`
- `src/autoload/gym_sys_backend_client.gd`（transport 未接真 backend）
- `design/registry/entities.yaml`（L63 `entities: []`）、`design/art/art-bible.md`（§8.C/§8.D）
- 缺席:`prototypes/[vertical-slice]/REPORT.md`、`production/{sprints,milestones,risk-register,playtests}/`、`design/assets/entity-inventory.md`、`tools/ci/asset_validator.gd`、`assets/.godot_import_presets/pixel_art.tres`
