# Story 006: Phone-lock / app-switch recovery

> **Epic**: Attention Budget & Interaction Policy
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (~2-3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/attention-budget-policy.md`
**Requirement**: `TR-ab-???`（hard-contract #4 phone-lock recovery）
**ADR Governing Implementation**: ADR-0006 Contract 13（IInputPolicy derivation）+ Contract 4（boot / SUSPENDED lifecycle）
**ADR Decision Summary**: state machine = source of truth；policy 純 read-only derive。SUSPENDED 由 GSM 表達；resume 後 GSM 還原 + WST snapshot reconcile phase。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 無 cache 故無 restore logic — recovery 係 derivation 嘅架構性副產品（Rule 2）。WST reconcile（snapshot）係 #9 責任；#33 只 honor #9 當前 phase。

**Control Manifest Rules (Core layer, v2026-05-29)**:
- Required: pure-pull derivation（無 cached gate → 無 stale lock/open after resume）
- Forbidden: #33 自行判斷 / debounce phase（phase 穩定性 = #9 責任）

---

## Acceptance Criteria

*From GDD `attention-budget-policy.md`, EC-6 / EC-7 / Rule 2:*

- [ ] **AC-11（EC-6 recovery，Integration）**：suspend mid-set（GSM `SUSPENDED`）後 GSM 還原到 **non-floor** `REST_PERIOD` 且 WST reconcile phase == `REST_PERIOD`，query `is_input_permitted()` → `true`（無 stale lock）。若 resume 落 floor state（`COMBAT_ACTIVE`）→ `false`（當前真值，非 stale lock）。
- [ ] **EC-6 path**：phone-lock mid-set → GSM `SUSPENDED` → `false`（Rule 4）；resume → GSM 還原（如 `COMBAT_ACTIVE`）+ WST reconcile → 即時重新 derive，正確（無 stale lock，Rule 2 架構保證）。
- [ ] **EC-7 path**：resume 後 WST reconcile 到 `SET_ACTIVE` → #33 honor → 維持 lock 直到真 `rest_started` / 下個 `set_logged` 更新 #9 phase（#33 唔自行判斷，只 honor #9）。

---

## Implementation Notes

*Derived from GDD EC-6/EC-7 + Rule 2:*

- **本 story 唔加新 production code**（理想情況）—— recovery 已由 Story 002 嘅 pure-pull derivation 架構性保證。本 story = Integration test 證明 suspend→resume 序列下 `is_input_permitted()` 自動正確。
- 若發現需要任何 reset / restore hook = **設計違規信號**（Rule 2 承諾無 stale gate）；應該零 recovery logic。
- Test 模擬：mock GSM state 序列 WORKOUT_ACTIVE/COMBAT_ACTIVE → SUSPENDED →（resume）COMBAT_ACTIVE；mock WST phase reconcile SET_ACTIVE → REST_PERIOD。每步 query 即時 derive。
- EC-7：reconcile 落 SET_ACTIVE → 維持 false（honor #9），唔 race。

---

## Out of Scope

- WST snapshot reconcile 本身（#9 WST own；本 story mock #9 reconcile 結果）。
- #1 SUSPENDED 偵測 / #20 bfcache reconcile —— 各自 system own；本 story 只驗 #33 input-policy 層喺 suspend/resume 下正確。
- browser-level bfcache（headless 物理上無 DOM）—— 若需真 browser，屬 #20 / playtest scope。

---

## QA Test Cases

*GDD-derived。mock GSM/WST 注入 state/phase 序列。*

- **AC-11**: Given 序列 [GSM=COMBAT_ACTIVE/phase=SET_ACTIVE]→[GSM=SUSPENDED]→[GSM=REST_PERIOD/phase=REST_PERIOD]; When 每步 query is_input_permitted; Then `false`(mid-set floor)→`false`(SUSPENDED Rule4)→`true`(resume non-floor，無 stale lock)。
  - Edge: resume 落 floor state（GSM=COMBAT_ACTIVE）→ `false`（當前真值，floor 鎖，**非** stale lock）—— 對照組，證明 floor 同 stale-lock 係兩件事。
- **EC-6 無 stale lock**: Given suspend@SET_ACTIVE→resume@[GSM=REST_PERIOD/phase=REST_PERIOD]; When query; Then `true`（證明 suspend 期間嘅 lock 冇殘留）。
- **EC-7 reconcile SET_ACTIVE**: Given resume 後 WST reconcile phase=SET_ACTIVE（GSM=IDLE）; When query; Then `false`（honor #9，維持 lock）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/attention-budget/test_phone_lock_recovery.gd` — must exist and pass

**Status**: [ ] Not yet created

> ✅ **AC-11 GDD 已校正 2026-06-04**（create-stories 時揾到）：原 example「resume→COMBAT_ACTIVE→true」同 Hybrid floor（COMBAT_ACTIVE→false）矛盾。已改 resume state 為 non-floor `REST_PERIOD`，真正 demonstrate「無 stale lock」；floor resume 作對照組。

---

## Dependencies

- Depends on: Story 002（derivation）DONE
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: AC-11（suspend@floor→SUSPENDED→resume non-floor REST_PERIOD = true 無 stale lock；floor resume 對照 = false）/ EC-6（SET_ACTIVE 鎖 suspend 後完全清）/ EC-7（reconcile→SET_ACTIVE 維持鎖、#9 推進 phase 後即開）/ pure-pull 自動 recovery。
**零 production code**：recovery 係 Story 002 pure-pull derivation 嘅架構性副產品（Rule 2：無 cached gate → 無 stale lock，無需 reset hook）。implementer 確認無 gap、無 Rule 2 違規信號。
**GUT**: 7 tests pass（含 instance-id integrity self-guard 坐實「無 reset」）；final combined 258 scripts / 1685 / 1684 pass / 0 fail / 1 pending。
**Files**: `tests/integration/attention-budget/test_phone_lock_recovery.gd`（new，唯一檔案）。
**Test Evidence**: Integration — `tests/integration/attention-budget/test_phone_lock_recovery.gd`（7/7）。
**Code Review**: Pending（lean — sprint close 前批量）。
