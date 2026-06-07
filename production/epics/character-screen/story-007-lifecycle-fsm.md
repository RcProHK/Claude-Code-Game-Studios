# Story 007: Lifecycle FSM + force-close + suspend snap + G-CS-10 contract pin

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L(可一 session,FSM 集中)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 1-6 + States and Transitions 表(CLOSING row GSM 照聽 + rationale)+ EC-01..07 + G-CS-10
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0006(primary — C6 / ghost callv / call_deferred)+ ADR-0001
**ADR Decision Summary**: GSM emit-before-release ⇒ handler 內觸發 GSM 行為必須 `call_deferred`;cfis sentinel 係 deferred-next-frame callv,disconnect 取消唔到 pending lambda。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(web SUSPENDED 行為依賴 G-CS-10 contract)
**Engine Notes**: GSM SUSPENDED wiring 未 shipped(story 017 deferred)— **G-CS-10 contract pin 喺本 story 交付**:doc(GSM contract 段落 / story 017 spec 注記)+ mock-level test;真機 validation EXTERNAL

**Control Manifest Rules (Presentation)**: 零 Camera2D 操作;PAUSABLE process mode(story 002)

---

## Acceptance Criteria(GDD AC-10..17;AC-12 GATED)

- [ ] **AC-10**:IDLE/DISCONNECTED open 成功 + clean-slate reset(STATS/NONE)+ 零 GSM mutation/pause;全部 ∉ permitted states 拒絕(double guard,唔 hardcode 數)
- [ ] **AC-11**:SALVAGE_CONFIRM open + GSM→WORKOUT_ACTIVE → modal cancel(永不 confirm)+ advance(FORCE_CLOSE_MAX_MS) 內 CLOSED + pending command 唔 fire + **零 play_sfx**
- [ ] **AC-12** *(G-CS-10 GATED — mock GSM emit)*:SUSPENDED → instant snap;resume 唔 auto-reopen
- [ ] **AC-13**:IDLE↔DISCONNECTED → 唔 close,banner toggle;modal 唔受影響
- [ ] **AC-14**:DISCONNECTED→WORKOUT_ACTIVE 直跳 → force-close 照行
- [ ] **AC-15**:3 close path × 3 upstream = 9 個 `is_connected==false` assertions
- [ ] **AC-16**:CLOSING re-tap open → ignore
- [ ] **AC-17**:CLOSING/FORCE_CLOSING/**CLOSED** signal/ghost sentinel → handler no-op
- [ ] G-CS-10 deliverable:GSM SUSPENDED emit-path contract 文檔 pin(hide-time synchronous,唔經 `_process` queue)+ AC-12 GATED 標記持續

## Implementation Notes

- FSM:CLOSED/OPENING/OPEN/CLOSING/FORCE_CLOSING;orthogonal 軸 `active_panel` × `modal` + `offline_banner` flag
- CLOSING 期間 GSM 照聽(upgrade FORCE_CLOSING / SUSPENDED snap)— **disconnect 留到 CLOSED 嘅 rationale 喺 States 表,唔好「優化」走**
- EC-04 三 ordering 屬 story 015(commands);本 story 行 FSM 側
- 全部 timing 行 injected clock(AC-11 = advance(150) assert,唔係 wall clock)

## Out of Scope

- Story 008:subscription 建立細節(cfis vs plain);Story 015:EC-04 command orderings;Story 016:modal 內容

## QA Test Cases

GDD AC-10..17 GWT 直接 embed;frame-stepping `await process_frame`(禁 wait_frames);ghost callv case:open→同 frame close→下 frame sentinel 照 callv → no-op assert

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_lifecycle.gd`;combined CI gate
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002
- Unlocks: Story 008 / 009
