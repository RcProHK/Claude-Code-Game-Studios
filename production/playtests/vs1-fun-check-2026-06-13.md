# Playtest — VS-1 Fun Check (Milestone 1, desk pass)

> **Date**: 2026-06-13
> **Build**: `prototypes/vertical-slice/PlayableSlice.tscn` (F5) — placeholder art/audio, mock workout
> **Tester**: frank
> **Goal**: answer the 2 core-hypothesis questions BEFORE investing in real art / GymSys backend.
> **Status**: ✅ PLAYED 2026-06-13 — verdict **PROCEED** (desk pass).
>
> **Verdict (frank, 2026-06-13)**: 「全部都OK」 — loop reads, combat + loot moment land, pacing fine.
> Core hypothesis holds at the desk-pass level → PROCEED to real production. (Full Pillar-2
> "doesn't distract mid-workout" test still pending — needs GymSys backend + a real mid-set run.)

---

## 點玩(~15 分鐘)
1. F5 跑個 scene,睇個 loop 行 **3–5 次**(佢自動循環)。
2. 試吓**唔好盯住佢**,做緊嘢時偶爾瞄一眼(模擬 mid-set glance),睇下你 catch 唔 catch 到發生咩事。
3. 答下面 2 條問題 + 填觀察。誠實,唔好客氣。

---

## Q1 — Watchability(可讀性)
**瞄一眼(~1 秒)睇唔睇得明啱啱發生咗咩事?**(class / 打緊怪 / 爆咗咩裝)

- [ ] YES — 一眼清楚
- [ ] 半半 — 要諗一陣
- [ ] NO — 睇唔切 / 太亂

觀察:
```
（你寫）
```

## Q2 — Return value(回頭價值)
**爆裝嗰下,你會唔會想為咗再爆而做多一日 workout?**

- [ ] YES — 有期待感
- [ ] 半半 — OK 但唔強
- [ ] NO — 冇感覺 / 悶

觀察:
```
（你寫）
```

## 其他感覺(pacing / 節奏 / 聲 / 任何嘢)
```
（你寫）
```

---

## 裁決(填完上面再揀)
- [ ] **PROCEED** — core idea 抵做 → 落實真 art(entity-inventory T1 STRIKE 起)+ 接 GymSys backend(等真 workout 驅動)+ 接已寫好嘅 #21 真 loot modal
- [ ] **TUNE** — 大致得,但要調某啲嘢(列出)→ 調完再 test
- [ ] **PIVOT** — core loop 假設唔成立 → 改 loop 本身,唔好喺上面加嘢(game-concept.md L342 failure path)

決定 + 理由:
```
（你寫）
```

---

## ⚠️ 呢個只係「枱面」pass
真正嘅 Pillar 2 測試(「遊戲會唔會干擾我健身」)要**喺手機/第二屏擺喺身邊、做緊真 set 時**測 —— 嗰個要先接 GymSys backend（用真 workout data 而唔係 mock）。枱面 pass 先過,再排真 mid-workout test。
