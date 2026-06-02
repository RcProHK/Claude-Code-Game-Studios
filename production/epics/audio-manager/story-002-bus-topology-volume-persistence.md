# Story 002: Bus topology + volume persistence + Formula 2

> **Epic**: Audio Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-002`, `TR-audio-009`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: ADR-0003 (Save State Strategy) — `audio.*` namespace persistence
**ADR Decision Summary**: backend-primary + IndexedDB(`user://`) secondary；volume/mute 寫 `audio.*` namespace；boot load；corrupt → fallback/clamp。localStorage FORBIDDEN。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `linear_to_db` / `db_to_linear` 係 Godot 內建；`AudioServer.set_bus_volume_db(bus_idx, db)`（gateway 內合法）。Private Mode / Safari ITP 影響 persist（ADR-0003 detect-and-gate）。

**Control Manifest Rules (Foundation)**:
- Required: volume 寫只經 PersistenceLayer `audio.*` namespace；其他 namespace forbidden
- Forbidden: `window.localStorage`（use `user://` / PersistenceLayer）；boost > 0dB（防 clipping）
- Guardrail: 無 time-dependent assertion（determinism）

---

## Acceptance Criteria

- [ ] **AC-02** GIVEN boot 完，THEN `Master→{Music,SFX}` 存在，default dB = 0 / −6 / 0
- [ ] **AC-11** GIVEN `set_bus_volume_db(MUSIC,−10)`，WHEN reboot，THEN `audio.music_db` load 返 −10
- [ ] **AC-13** GIVEN slider 0.5，THEN `volume_db` ≈ −6.02；slider 0 → −80
- [ ] **AC-20** WHEN boot：(a) key 缺失 → default(−6) 無 warn；(b) NaN/非數值 → default + warn；(c) out-of-range → clamp `[MUTE_FLOOR_DB, MAX_BUS_DB]` + warn
- [ ] **AC-22** GIVEN slider `s = NaN`，THEN `volume_db` 回 `MUTE_FLOOR_DB`，無 NaN dB 套落 bus
- [ ] **AC-23** GIVEN `set_bus_volume_db(MUSIC, +12)`，THEN clamp 到 `MAX_BUS_DB(0)` + warn
- [ ] **AC-28** GIVEN `set_bus_muted(MUSIC,true)` + `set_bus_volume_db(MUSIC,−10)`，WHEN reboot，THEN `audio.music_muted` true 且 `audio.music_db` −10（獨立持久化，互不覆蓋）

---

## Implementation Notes

*Derived from ADR-0003 + GDD Formula 2 + Rule 2/9:*

- **Formula 2**：`s_safe = (is_nan(s) or is_inf(s)) ? 0.0 : clamp(s,0,1)`；`volume_db = (s_safe ≤ 0) ? MUTE_FLOOR_DB : clamp(linear_to_db(maxf(s_safe, 0.0001)), MUTE_FLOOR_DB, MAX_BUS_DB)`。`is_inf` guard **唔好漏**（corrupt persisted value 可能係 inf）。`maxf(s,0.0001)` 防 `linear_to_db(0)=−inf` 污染插值。upper-clamp 引用常數 `MAX_BUS_DB`（**唔 hardcode 0.0**）。
- **`MAX_BUS_DB=+6` boost 透過此 formula 唔可達**（`linear_to_db(s≤1) ≤ 0`）；MVP 鎖 `MAX_BUS_DB=0` 禁 boost（正確且安全）。真 boost 需 separate gain mapping（future）。
- namespace keys：`audio.master_db` / `audio.music_db` / `audio.sfx_db` / `audio.master_muted` / `audio.music_muted` / `audio.sfx_muted`。

---

## Out of Scope

- Story 001: gateway API signature + seam（前置）
- Story 004: ducking 改 Music bus dB（呢度只設 base volume）
- Private Mode degraded-mode banner（屬 #3 PersistenceLayer / ADR-0003）

---

## QA Test Cases

- **AC-02**: bus topology + defaults — Given boot 完 / When 讀 AudioServer bus layout（gateway accessor）/ Then Master/Music/SFX 三 bus 存在，dB == 0/−6/0。Edge: Music ≠ 0（subtle default 鎖死）。
- **AC-13/AC-22**: Formula 2 pure — Given slider s / When `_slider_to_db(s)` / Then s=0.5→≈−6.02、s=0→−80、s=NaN→−80、s=+inf→−80。Edge: s=0.0001 唔回 −inf。
- **AC-20**: corrupt persist 三 case — Given mock persistence 回 (a)缺 key (b)NaN (c)+40 / When boot load / Then (a)−6 無 warn (b)−6+warn (c)clamp 0+warn。各一斷言，皆無 crash。
- **AC-23**: set boost clamp — Given `set_bus_volume_db(MUSIC,+12)` / When apply / Then bus dB==0 + warn once。
- **AC-11/AC-28**: round-trip persist — Given set music −10 + mute true / When reboot（mock reload）/ Then music_db==−10 且 music_muted==true（兩 key 獨立）。Edge: unmute 後還原 −10 唔變 default。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/test_bus_volume_persistence.gd` — must exist and pass（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 001 (gateway scaffold + seams)
- Unlocks: 004 (duck recompute reads `base_music_db`)
