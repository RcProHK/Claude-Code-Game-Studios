# Tween Spike Findings — #20 Gym-Mode HUD (CD binding ruling, 2026-06-03)

> **Why this spike exists**: R2..R7 連續 7 輪 /design-review 喺 EC-F4 tween handle-map + circuit-breaker 揭新 phantom（paper saturation）。CD 裁定停 paper review，用 headless GUT spike 實測 Godot 4.6 tween runtime behavior，由實測反向 author spec。
>
> **Spike**: `prototypes/tween-spike/test_tween_spike.gd` — 12 tests / 32 asserts / **ALL PASS** (Godot 4.6.3 + GUT 9.6.0, headless).
>
> **Throwaway**: 唔入 src/。reference HudTweenManager inner class = EC-F4 嘅 authoritative spec。

---

## PART A — Raw engine behavior (paper 無法裁決,實測)

| Probe | 結果 | 影響 |
|---|---|---|
| **A1 [B2]** `kill()` 之後 `finished` 會唔會 emit? | **唔會**（kill 後 N 幀 finished count==0） | kill path **必須有獨立 erase code path**,絕不可靠 `_on_tween_finished` callback |
| **A2 [B2 對照]** 自然完成 emit `finished`? | **會,剛好一次** | lifecycle ③（finished→reset `_restart_count`）只行於**自然完成**路徑,kill 路徑唔行 |
| **A3 [B6]** `kill()` 後 `tween.is_valid()`? | **false**（kill 前 true） | `is_valid()` 可做 stale guard 之一,但**唔足夠**區分同一 stat_id 嘅新舊 tween → 仍需 identity (`==`) 比對 |
| **A4 [B6/F8]** `finished`(0 args) + `.bind(stat_id, tween)` callback 收到乜? | 收到 `(stat_id, src_tween)` | bound args 喺尾、signal 0 args 故位置正確。**2-param seam `_on_tween_finished(stat_id, src_tween)` 可行且必須** |

---

## PART B — Reference handle-map impl (邏輯由斷言鎖死)

### 5 條 paper-irreducible BLOCKING 嘅實測裁決

| # | 問題 | 實測裁決 |
|---|---|---|
| **B2** | kill path 需唔需要獨立 erase? | **需要。** `_kill()` 自己做 `_active_tweens.erase()` + `_active_tween_count = maxi(count-1, 0)`,因為 `kill()` 唔 emit finished（A1）。invariant `_active_tween_count == _active_tweens.size()` 喺整個 restart burst 維持（test_B2 verified）。 |
| **B3** | `_restart_count++` ordering? | **`++` 喺 kill-restart branch 最頭,先於 cap-check。** snap 後 `_restart_count[stat_id]` 即時歸 0；snap path 只 `--`（kill）唔 `++`（set_immediate 唔創 tween）→ counter 歸 0 非 stuck。 |
| **B4** | snap 喺第幾個 event?（off-by-one） | **snap 喺第 `MAX_RESTART + 1` 個 event。** create（第 1 個 event）**唔算** kill-restart；之後 5 次 kill-restart（event 2-6）令 `_restart_count` 喺第 6 個 event 達 5 → snap。**AC-EC-F4b 原寫「第 `max_tween_restart_count` 個 event snap」係 off-by-one 錯,須改「第 `max_tween_restart_count + 1` 個」。** |
| **B5** | snap 後 `_on_tween_finished` 對 empty handle? | **no-op（identity guard 提早 return）。** snap 已 erase entry,`_active_tweens.get(stat_id)` 返 null ≠ src_tween → return,counter 不變（無 double-decrement）。 |
| **B6** | F8 single-stat_id seam 夠唔夠做 identity guard? | **唔夠。seam 必須係 2-param `_on_tween_finished(stat_id, src_tween: Tween)`。** stale tween A 嘅 finished 殘響到達時,guard `_active_tweens.get(stat_id) != src_tween` 先擋得住,唔會誤刪新 tween B。single-param 物理上做唔到 identity 比對。 |

---

## 反向 author 入 GDD 嘅 spec changes（R8）

1. **EC-F4 — kill path 獨立 erase（B2）**：明文 `_kill(stat_id)` 自帶 `_active_tweens.erase()` + counter decrement,唔依賴 finished。EC-R2 / EC-F5 kill 路徑同步 erase。

2. **EC-F4 — `_restart_count++` ordering pin（B3）**：「kill-restart branch 第一步 `_restart_count[stat_id] += 1` → 即 compare cap → ≥cap 則 snap+reset → 否則 kill→create」。atomic ordering 寫死。

3. **F8 seam 簽名改 2-param（B6）**：`_on_tween_finished(stat_id: StringName, src_tween: Tween)`,經 `tween.finished.connect(_on_tween_finished.bind(stat_id, t))` wire。callback 入面 identity guard `if _active_tweens.get(stat_id) != src_tween: return`。**取代 R7 F8 嘅 single-`stat_id` mandate。**

4. **AC-EC-F4b off-by-one fix（B4）**：snap 斷言改「注入第 `max_tween_restart_count + 1` 個連續 same-stat_id event 嗰刻 snap」（create 第 1 個唔算 restart）。snap-index 斷言 == `MAX_RESTART + 1`。

5. **AC-EC-F4b empty-handle 斷言（B5）**：明文 `_on_tween_finished` 對 stale/empty handle = no-op（identity guard），counter 不變。

6. **F1 invariant CI assert（B7,非 spike scope 但同批）**：joint assert 須兩條 conjunctive `element_max < threshold_min AND threshold_max < ambient_min`。

7. **invariant 單一真相源（systems-designer ADVISORY）**：考慮 `_active_tween_count` 直接 = `_active_tweens.size()`（derived），消雙真相源；AC-CR-2 加 cross-check assert。

8. **seam mandate 升 AC（ui-programmer R6）**：AC-EC-F4b 明文 mandate `_active_tweens` / `_on_tween_finished(stat_id, src_tween)` / `_get_restart_count_for_test()` 三個 seam,同 AC-CR-2 `_active_tween_count` 同級 BLOCKING implementation requirement。
