---
name: rarity-hex-adjudication
description: "#21 ruling: rarity hexes canonical = art bible §4.B (#6FB87A/#4D8FD6/#9B5FCC/#FF8C42); #15 GDD Visual Spec Table used Material Design hexes — erratum owed; timing values canonical = system GDD"
metadata:
  type: project
---

2026-06-06 #21 Loot Drop Modal 裁決(AD):

**Canonical split rule:** 色彩語言 = art bible 擁有;timing/tuning 數值 = system GDD 擁有。

1. **Rarity hex canonical = art bible §4.B (L265-268)**: UNCOMMON `#6FB87A` / RARE `#4D8FD6` / EPIC `#9B5FCC` / LEGENDARY `#FF8C42`。P-06 + accessibility-requirements.md + art-style-mockup.html 全部一致。#15 loot-drop-system.md L1031-1034 嘅 `#4CAF50/#2196F3/#9C27B0/#FF9800` 係 Material Design 樣板色 drift → **#15 欠一個 erratum**(doc-only;src/ + assets/ grep 零 code impact)。`#FF8C42` 係刻意揀(protanopia-safe vs damage red `#D94B3E`,§4.C);`#6FB87A` 同 heal green 係 deliberate shared token — Material 色會打破兩者。
2. **Ceremony timing canonical = #15 Visual Spec Table**(hold 0.20/0.35/0.50/0.65/0.80 + per-tier time-stop),P-05 嘅 hold/slowmo 數值係舊版 drift → P-05 應加「timing 見 #15」sync note。

**Why:** 兩份文檔互相引用時兩套數字並存,implementer 會隨機揀一套。
**How to apply:** #21/#22/#23 視覺 spec 一律引 art bible token + #15 timing;見到 Material Design hex 即係 drift 訊號。
