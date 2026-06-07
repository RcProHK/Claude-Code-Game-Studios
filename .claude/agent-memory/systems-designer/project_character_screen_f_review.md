---
name: character-screen-22-formulas-review
description: "#22 Character Screen Formulas adversarial review Pass 1 (2026-06-07): 4 BLOCKING (F1 缺 u-clamp 過衝 / F2 缺 NaN-type guard / EC-10 settle 值未 pin / F1 retarget 缺 source qualifier) — 全部 one-line pin 級;NEEDS REVISION"
metadata:
  type: project
---

#22 character-screen.md §Formulas review 軌跡(systems-designer adversarial pass,2026-06-07)。

**Why:** Pass 2 verify 時只需 spot-check 4 個 one-line fix,唔使 full re-pass — formulas 結構全 sound,0 phantom citation(同 [[loot-modal-21-review]] 對比:呢份乾淨得多)。

**How to apply:** Pass 2 對:① F1 L183 有冇加 `u := clampf(t/STAT_TWEEN_MS, 0, 1)`(否證 vector:t=500ms@300 → ease=1.296 → 84+6×1.296=91.78「92」>target 90;test seam advance(1000) → 顯示「166」)② F2 L204 前有冇 ingestion type/finite guard fallback 1.0(NaN 過 clampf IEEE 比較全 false → roundi(NaN) UB/WASM trap;#6 L390 reject-retain vs #22 divergence)③ EC-10「settle 該值」有冇 pin = `v_target`(真值;同 arrow-operand pin 同類)④ F1 retarget 規則有冇加「只適用 EQUIPMENT source;非 EQUIPMENT mid-tween → kill+snap+清 arrow」(可達:EC-30 DISCONNECTED equip tween 中 reconnect reconciliation)。

**Verified ✓(唔使重查)**:F1 example 84+6×0.875=89.25→「89」啱;F2 1% grid bijectivity 證明成立(101 distinct doubles,round-trip 誤差 ~1e-14 ≪ 0.5);F3 strict total order 證明成立(item_id unique;#17 Formula 6 construction = ASCII-only,CJK 唔會出現);F3 divergence note 對 code L786-796 準確(#17 asc / #22 desc intentional);F4 raw≥0 結構保證有 code 證據(inventory_system.gd L1059-1061 negative-delta hydration clamp);get_aggregate_raw_and_effective L895-901 只回 attack_power — GDD badge ATK-only 一致;salvage_yield L911 static 一致;set_motion_intensity L394 clamp + L390 non-finite reject 一致;Tuning Knobs 同 formula 全一致;natural-completion 唔會 stuck(guard 只喺 signal arrival evaluate)。

RECOMMENDED:.5 boundary golden vector 只准 binary-exact 值(90.5 OK / 0.075 → ×100=7.4999… 會「7」唔係「8」)。NICE:max_hp knob headroom 5 位數 column 預留;F3 acquired_at_unix「>0」claim 軟化;EC-25 transient divergence vs L219「設計上消滅」措辭收窄。
