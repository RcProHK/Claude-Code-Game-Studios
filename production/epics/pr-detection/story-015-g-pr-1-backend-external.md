# Story 015: G-PR-1 — GymSys backend baseline API(EXTERNAL)

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: **Blocked — EXTERNAL**(GymSys backend repo;user 自有 backend)
> **Layer**: Feature(external dependency)
> **Type**: Integration
> **Estimate**: M(backend 側)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(G-PR-1 gate row)
**ADR**: **ADR-0011 §D-2**(binding contract — 四 sub-spec)
**Engine**: N/A(Python / GymSys FastAPI 側)| **Risk**: LOW(contract 已 spec)

## Acceptance Criteria(= ADR-0011 §D-2 contract)

- [ ] **D-2.1 Formula parity**:server e1RM = 同款 Epley(divisor 30.0 float + `min(reps,12)` clamp + 無 reps=1 特判)
- [ ] **D-2.2**:回傳值 well-formed(client 端 validation 已喺 008 — server 側都應 sane)
- [ ] **D-2.3 Ratchet 語意**:confirmed-PR ratchet 鏡像(**唔係 raw max over all sets**)+ **D8 corroboration 語意**(suspect 跳升要 corroborating set 先入 ratchet — sequential scan + pending slot,同 client 同 algorithm)
- [ ] **D-2.4 Sync timing**:baseline ride 喺 polling state response field(唔開獨立 endpoint)
- [ ] Parity spot-check:抽 N 個真實 exercise,server 回值 == client 重計值

## Implementation Notes

- GymSys repo @ `C:\Users\frank\Desktop\GYM`(FastAPI port 9120)。#2 client 都係 stub — 本 story 同 #2 live-transport stories 同一個 external wave。
- **唔 block epic close**:INV-PR-1 fail-closed 令 client 冇 server baseline 都安全(establishment-only;新用戶語意一致)。

## Test Evidence

**Required**:GymSys 側 pytest + parity spot-check 記錄(`production/qa/evidence/g-pr-1-parity.md`)。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: GymSys backend access(EXTERNAL)+ #2 polling 實裝
- Unlocks: AC-14/15/16/23 嘅 live-backend 驗證(mock 版已喺 008)
