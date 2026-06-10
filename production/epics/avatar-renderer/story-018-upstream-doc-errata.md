# Story 018: G-AR-4 upstream doc errata (R-3) + G-AR-5 asset scope note

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data (doc)
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` Status header (R-3 deferred) / Q-OQ-ASSET / F. Asset Spec Flag
**Requirement**: G-AR-4 + G-AR-5 cross-system gates(doc errata + asset scope)
**ADR Governing Implementation**: N/A — doc errata + scope note(no architectural pattern)
**ADR Decision Summary**: N/A。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 純 doc edit;asset scope gate 交 art-director + producer。

**Control Manifest Rules (Presentation layer)**:
- Required: cross-file doc errata grep-verify(改一處 grep 晒下游 mention — feedback_orphan_cleanup)
- Forbidden: net-regression(改一處冇 grep 下游)
- Guardrail: errata = framing-only,唔改行為

---

## Acceptance Criteria

- [ ] **G-AR-4**(R-3):#11 GDD L261 + #12 GDD L227 downstream-framing errata — 描述 #26 嘅措辭 stale(render-only ADR-0010 前嘅舊框架)→ 更新對齊 v2.1 render-only scope;grep 晒兩 file 所有 #26 mention 確認一致
- [ ] **G-AR-5 asset scope note**:Q-OQ-ASSET 決定記錄(36 sheet + 12 hero still solo-dev throughput)— default option (a) ≥1.5 sheet/week ships as-spec;art-director + producer 確認;`/asset-spec system:avatar-renderer` 觸發點記錄(BLOCKING AC 唔等 final art,ADVISORY playtest AC-31/32/33 等)
- [ ] systems-index / 相關 doc #26 row 對齊 render-only scope(無殘留 ceremony-ownership 舊措辭)

---

## Implementation Notes

*Derived from R-3 deferred + Q-OQ-ASSET:*

- **G-AR-4**:grep `#26`/`avatar` mention in `design/gdd/stat-system.md`(L261)+ `design/gdd/ability-system.md`(L227);更新 downstream-framing(render-only,唔再講 ceremony ownership);**grep-verify cross-file**(feedback_citation_grep_verify — 改一處要 grep 晒)。
- **G-AR-5**:記錄 Q-OQ-ASSET 決定(default (a) ship as-spec;option (b) 18 sheet + 4-week cadence / (c) 12 sheet drop-P4 = fallback);art-director + producer sign-off;`/asset-spec` 觸發 = post-epic 或並行 art pipeline。**唔 block code stories**(EMERGENCY + placeholder SpriteFrames 跑 30 BLOCKING AC)。
- 順手 grep 確認 systems-index #26 row 無殘留 pre-ADR-0010 ceremony-ownership 措辭。

---

## Out of Scope

- 實際 sprite 生產(`/asset-spec` — separate art pipeline)
- 行為改動(errata = framing-only)

---

## QA Test Cases

- **G-AR-4**: doc errata cross-file
  - Given: #11 L261 / #12 L227 #26-framing
  - When: grep 晒兩 file #26 mention
  - Then: 全部對齊 render-only;零殘留 ceremony-ownership 舊框架
  - Edge cases: 改一處 grep 下游(net-regression 防)
- **G-AR-5**: asset scope recorded
  - Given: Q-OQ-ASSET
  - When: art-director + producer review
  - Then: default option 記錄;`/asset-spec` 觸發點記低

---

## Test Evidence

**Story Type**: Config/Data (doc)
**Required evidence**: doc diff(#11/#12 GDD errata)+ Q-OQ-ASSET 決定記錄(`production/qa/smoke-*.md` 或 epic note);grep-verify cross-file 一致
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None(doc-only,可並行)
- Unlocks: `/asset-spec`(G-AR-5 sign-off 後)
