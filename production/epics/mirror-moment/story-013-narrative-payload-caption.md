# Story 013: Narrative payload CR-M10 + G-MM-5 #9 caption enrich

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M10 / EC-MM-19 / Q-OQ-CAPTION-N / Q-OQ-PR-CONTEXT
**Requirement**: AC-21 / AC-22(GDD 直接 trace)+ G-MM-5 cross-system gate(#9 caption wire)
**ADR Governing Implementation**: N/A — null-safe read(no architectural pattern);secondary ADR-0009(payload read)
**ADR Decision Summary**: N/A;Soft dep null-safe read（#9/#17/#18 缺則 degrade）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #9 WST workout surface(週數 + 訓練次數);#17 `SourceReceipt.signature_text`(registry);#18 PR context(via #17 receipt)。全部 Soft + null-safe。`snapshot.source_metrics` 只有 `{stat_total, ability_count, max_class_depth, achieved_at_unix}`(**無** weekly count / 無 week N)。

**Control Manifest Rules (Polish layer)**:
- Required: narrative 行 Soft + null-safe;#29 只 read 已存在 receipt（唔自己揾 loot/判 PR）
- Forbidden: #29 自己揾 loot / 判 PR;缺 dep crash
- Guardrail: 缺 #9/#17/#18 → caption 退化純 tier/class,慶典照常

---

## Acceptance Criteria

- [ ] **AC-21**(CR-M10 / EC-MM-19): 本週無 LEGENDARY drop(`SourceReceipt` null)且無 PR → narrative 行**唔出**,慶典只用 #26 snapshot 照常呈現(null-safe,無 crash)
- [ ] **AC-22**(CR-M10,ADVISORY): 本週有 LEGENDARY drop 帶 `signature_text="鍛造自 180kg × 5"` → present EVOLUTION → caption 多一行顯示該 signature_text
- [ ] **G-MM-5**(Q-OQ-CAPTION-N): caption 週數 N + 訓練次數 M(「第 N 週 · 練咗 M 次」)source = **#9 WST** surface(snapshot.source_metrics 砌唔到 N/M);wire #9,缺 #9 → caption 退化純 tier/class(「進化到 T{n}」/「本週回顧」,null-safe)
- [ ] CR-M10:(a) #17 `SourceReceipt.signature_text` → 「本週簽名戰利品」一行;(b) #18 PR context(via #17 receipt,Q-OQ-PR-CONTEXT)→ 「本週 PR」一行;兩者 Soft + null-safe
- [ ] #29 **唔**自己揾 loot / 判 PR — 只 read 已存在 receipt payload

---

## Implementation Notes

*Derived from CR-M10 + Q-OQ-CAPTION-N(#9 wire):*

- **G-MM-5**:week N + workout count M wire #9 WST surface(consumer-forward;mock-scoped 先行,真接線隨 #9 surface)。缺 #9 → caption 退化純 tier/class(AC-06 null-safe base form)。
- #17 `SourceReceipt.signature_text`(#17 Rule 10「供 #29 ceremony narrative」已 wired path)+ #18 PR(via #17 receipt,Q-OQ-PR-CONTEXT default #17 path)。
- 全部 Soft + null-safe:缺任何一個 → 對應 narrative 行唔出,慶典核心(#26 snapshot)照常(EC-MM-19)。
- marquee caption(「第 6 週 · 練咗 18 次」)係 **enriched form**;base form 無 N/M。

---

## Out of Scope

- Story 007:reveal 構圖(本 story 係 caption narrative 行)
- #9/#17/#18 真接線(consumer-forward — mock-scoped 先行)

---

## QA Test Cases

- **AC-21**: null-safe narrative
  - Given: SourceReceipt null + 無 PR + #9 缺
  - When: present
  - Then: narrative 行唔出,caption 退化純 tier/class;無 crash
  - Edge cases: #9/#17/#18 任一缺 → degrade gracefully
- **AC-22**(advisory): signature enrich
  - Given: LEGENDARY drop signature_text
  - When: present EVOLUTION
  - Then: caption 多一行 signature_text
- **G-MM-5**: #9 caption
  - Given: #9 surface 有 week N + count M
  - When: present
  - Then: 「第 N 週 · 練咗 M 次」;缺 #9 → 退化

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/narrative_caption_test.gd` — mock #9/#17/#18 seam;null-safe degrade case(各 dep 缺）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007(reveal caption base)/ Story 010(caption render)
- Unlocks: None(#9/#17/#18 真接線 follow-up)
