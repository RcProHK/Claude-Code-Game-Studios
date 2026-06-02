# Story 005: BGM equal-power crossfade (Formula 1 + retained Tween)

> **Epic**: Audio Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-004`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps) — crossfade 2× OGG decode CPU peak
**ADR Decision Summary**: crossfade 期間 2× BGM decode CPU peak（mobile VS-tier 最易 WASM/Safari glitch）；列 VS-tier profiling 點，最差 ~0.2-0.6ms；fallback = instant-swap if overrun。

**Engine**: Godot 4.6 | **Risk**: MEDIUM (VS-tier decode profiling — Q1)
**Engine Notes**: 兩個 dedicated Music player。crossfade 用 `tween_method` 喺 normalized `p`（0→1）空間，callback 內計 `linear_to_db(cos/sin)`。**禁止** `tween_property(player,"volume_db",...)` — 係 linear dB ramp，中點 ≈−40dB 違反 equal-power。autoload `create_tween()` 唔自動 kill → retained handle kill-before-respawn。

**Control Manifest Rules (Foundation)**:
- Required: 單一 retained `_crossfade_tween`，kill-before新-crossfade；`_crossfade_progress` source-of-truth（sentinel `<0`）
- Forbidden: `tween_property(volume_db)` linear ramp（違 equal-power）；`==-1.0` 浮點等號比較（用 `<0`）
- Guardrail: BGM = `AudioStreamOggVorbis` streamed（唔 decode 落 PCM 爆 budget）

---

## Acceptance Criteria

- [ ] **AC-04** GIVEN track A 正播，WHEN `play_bgm(A)`，THEN no-op（A 唔重啟，position 連續）
- [ ] **AC-12** GIVEN crossfade p=0.5，THEN `abs(out_gain−0.707)<0.001` 且 `abs(in_gain−0.707)<0.001` 且 `abs(out²+in²−1.0)<0.001`（equal-power）
- [ ] **AC-18** GIVEN A→B crossfade in-flight（`_crossfade_progress∈(0,1)`），WHEN `play_bgm(C)`，THEN 舊 Tween `is_valid()==false` + `_test_get_active_crossfade_count()==1`（唔 stack）+ 新起點 gain 由 `_crossfade_progress` 讀（`cos/sin(p·π/2)`，唔讀 `player.volume_db`）
- [ ] **AC-21** GIVEN `play_bgm(track, 0.0)`（fade_sec=0），THEN instant-swap（舊即停 / 新即 full gain），無 NaN / click

---

## Implementation Notes

*Derived from ADR-0001 + GDD Formula 1 + Rule 4:*

- **Formula 1**：`p_clamped=clamp(p,0,1)`；`out_gain=cos(p·π/2)`、`in_gain=sin(p·π/2)`；`out²+in²=1`（中點 −3dB each，無 dip）。
- **tween_method callback 每 step 原子 inline**：`player_out.volume_db=linear_to_db(cos(p·π/2)); player_in.volume_db=linear_to_db(sin(p·π/2)); _crossfade_progress=p`。
- **endpoint hard-set**（`finished` callback）：`player_out.stop()` + `player_in.volume_db=base_music_db` + `_crossfade_progress=-1.0`（sentinel）。唔靠 `cos(π/2)≈6.12e-17→−324dB` 殘值。
- **kill+respawn 讀 `_crossfade_progress`**：若 `< 0.0`（sentinel，**唔用 `==-1.0`**）→ 從 full-gain 起（單一 player）；若 ∈(0,1) → 從 `cos/sin(_crossfade_progress·π/2)` 起。
- **2-player mid-crossfade interrupt**：只 2 個 BGM player，A→B 中 `play_bgm(C)` → kill 嗰刻 drop 較細 gain player 立即 stop，保留較大 gain 做唯一 out-source → C。
- **fade_sec≤0 → instant-swap**（直接 p=1），**唔做** `elapsed/0` 除零。

---

## Out of Scope

- Story 006: GSM state→track map 觸發 crossfade（呢度只實作 `play_bgm` crossfade primitive）+ `bgm_changed` emit timing
- Story 008: SUSPENDED mid-crossfade kill + resume（AC-14b）
- Story 009: variant rotation 重用呢個 crossfade

---

## QA Test Cases

- **AC-04**: idempotent no-op — Given A 正播 / When `play_bgm(A)` / Then 無新 crossfade（`_test_get_active_crossfade_count()` 唔升），無 `bgm_changed` emit。
- **AC-12**: equal-power gain pure — Given p=0.5 / When 計 out/in_gain / Then 各 0.707，out²+in²==1（epsilon 0.001）。Edge: p=0→out=1,in=0；p=1→out=0,in=1；p>1 clamp。
- **AC-18**: latest-wins kill-respawn — Given A→B `_crossfade_progress=0.4` / When `play_bgm(C)` / Then 舊 tween invalid + crossfade_count==1 + 新起點讀 `cos(0.4·π/2)`（唔讀 player.volume_db）。
- **AC-21**: fade=0 instant-swap — Given `play_bgm(B,0.0)` / Then 舊 stop、新 full gain，無 NaN（無除零）。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/test_bgm_crossfade_formula1.gd` — must exist and pass（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 001 (crossfade seam `_crossfade_progress` / `_active_crossfade_count`)
- Unlocks: 006 (GSM transition triggers crossfade), 008 (suspend mid-crossfade), 009 (rotation reuses crossfade)
