---
name: pr-detection-qa-review
description: "#18 PR Detection GDD QA review — Pass 2 (2026-06-06) verdict TARGETED REVISION: F1-F7 全 FIXED, 25 PASS/4 WEAK/1 FAIL (AC-30 buffer orphan BLOCKING); 0 phantom; spot-check list for Pass 3 / epic"
metadata:
  type: project
---

#18 pr-detection.md QA review 歷史(qa-lead)。

**Pass 1(2026-06-06)**: MAJOR — 3 FAIL/14 WEAK,7 BLOCKING(F1 L101 矛盾 / F2 D2×D5 race / F3 seam list / F4 AC-20 / F5 AC-22 / F6 WEIGHT_SANITY_MAX orphan / F7 EC-6/EC-11 無 AC)+ 10 coverage gaps。詳見 review log `design/gdd/reviews/pr-detection-review-log.md`(cluster 16 = qa items)。

**Pass 2(2026-06-06,fresh verification)**: **TARGETED REVISION(1 BLOCKING)**
- F1–F7 全部 FIXED ✓;10 coverage gaps 全部落地 ✓(AC-24/25/26/27 + AC-01 pr.detected + AC-18 aggregation + AC-19 no-re-emit + AC-16 race + AC-30 GSM 靜默)。
- Citation grep-verify **0 phantom**:ability_system.gd:895 簽名 exact ✓ / #11 L338-340 golden 0.500 ✓ / persistence_layer.gd:291-294 ✓ / WST L863 ✓ / #2 L479 ✓ / #15 L293 ✓ / #12 L223+L498 ✓ / ADR-0011 §D-1/2/3/4 齊 ✓。一個 line drift:zone-system 引 L22 實際 L39(substance 成立,cosmetic)。
- Golden 全 recompute ✓(δ≈0.4999 / ramp max 70.0 / e1rm(100,15)=140 / 86.4×5=100.8 / 75×2=80.0, m₂=0.054945 / AC-31 bound 0.2513≤0.2633≤0.2857)。
- AC verdict:**25 PASS / 4 WEAK(AC-01, AC-18, AC-23, AC-26)/ 1 FAIL(AC-30)**;AC-29 唔存在(numbering gap — 實得 30 條,唔係 31)。
- **N-1 BLOCKING(唯一)— AC-30 buffer-flush orphan**:AC assert「buffer 一格,resume 時 flush」但 Rule 6.7 只 spec belt-and-braces assert;Rule 10 L95「無 SUSPENDED queue 需求」+ States L108「stateless」直接矛盾。上游 #12 EC-16(ability-system.md L498)「wait…後先 emit」語意支持 buffer,且 G-PR-5 令 Path B skip PR_BREAKTHROUGH → drop signal = unlock evaluation 永久漏 — 所以 AC 行為係**啱**,缺嘅係 rule backing。Fix = Rule 6.7 加 one-slot pending-emit buffer spec + 收窄 L95/L108 措辭。單點 edit。
- WEAK 3 項 RECOMMENDED:75.83 vs 75.8333 違自己 ±0.001 epsilon(AC-01 baseline assert / AC-18 e1rm_kg — pin 75.833)/ AC-23 缺超 sanity vector(§D-2.2 上限 700,加 800.0)/ AC-26「+telemetry」無對應 event(13-event list 冇 persist-fail — 加 `pr.persist_failed`)。

**Why:** AC-30 係 Logic AC = BLOCKING evidence gate — AC mandate 無 rule backing 嘅行為會令 implementer 分歧([[binding-gate-satisfiability]] 同源原則:gate 必須 spec-consistent 先可執行)。
**How to apply:** Pass 3 / epic /qa-plan spot-check:(1) Rule 6.7 有冇 buffer 字眼 + L95/L108 措辭收窄咗未;(2) AC-01/18 golden 改 75.833 未;(3) AC-23 第 5 vector;(4) telemetry list 14 events;(5) AC-29 gap 喺 epic story mapping 唔好假設存在。同 [[equipment-inventory-qa-review]] 同款 follow-up pattern。
