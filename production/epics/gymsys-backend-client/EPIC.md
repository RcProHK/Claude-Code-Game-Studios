# Epic: GymSys Backend Client

> **Layer**: Foundation
> **GDD**: design/gdd/gymsys-backend-client.md
> **Architecture Module**: GymSys BackendClient (autoload pos 3, `src/autoload/gymsys_backend_client.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories gymsys-backend-client`

## Overview

GymSys BackendClient 係 Mirror Hero 嘅 real-world gym data gateway，透過 HTTP polling（5s ±0.5s jitter + differential event cursor）連接 GymSys FastAPI backend（port 9120），提供 workout 事件流比其他系統消費。佢擁有 session lock（POST /session/claim + X-Session-Token）確保同一時間只有一個 game session active，防止跨設備數據衝突。所有 HTTP 請求用 relative URLs（唔係 absolute），由 nginx reverse proxy 透明 route 到 backend，解決 CORS 問題（ADR-0004）。係 Mirror Hero anti-fabrication quintet 嘅第一件套 — 所有 workout data 嘅唯一 canonical source。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002 (Proposed ⚠️) | GymSys Integration Protocol — 5s HTTP polling + differential cursor + session lock + LootDrop endpoints + SSE v0.2 path | HIGH |
| ADR-0004 (Proposed ⚠️) | CORS / Cross-Origin Auth Topology — nginx reverse proxy, same-origin, relative URLs in HTTPRequest | MEDIUM |
| ADR-0006 Contracts 2/4/5/11/15 (Accepted ✅) | transition_id chain + boot order + reconnection + error recovery | MEDIUM |

> ⚠️ ADR-0002 ↔ ADR-0004 mutual Proposed dependency loop (N-003 follow-up) — **全部 stories auto-blocked** 直至兩個 ADRs 同時 ratified (coordinated ratification required)。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gym-001 | HTTP polling 5s ±0.5s jitter (differential event cursor) | ADR-0002 ⚠️ |
| TR-gym-002 | Server-authoritative session lock (POST /session/claim + X-Session-Token) | ADR-0002 ⚠️ |
| TR-gym-003 | CORS same-origin via nginx reverse proxy (relative URLs only) | ADR-0004 ⚠️ |
| TR-gym-004 | SSE v0.2 upgrade path via JavaScriptBridge EventSource | ADR-0002 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 17 TR-gym-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/gymsys-backend-client.md` (31 ACs) are verified
- All Logic and Integration stories have passing test files in `tests/integration/gymsys/`
- HTTP polling loop verified against real GymSys backend (`\\rcprohk\docker\studiosys` or test instance)
- Session lock race condition tested (multi-tab scenario)
- ADR-0002 + ADR-0004 must be Accepted before any stories can move to In Progress

## Next Step

Run `/create-stories gymsys-backend-client` to break this epic into implementable stories.

> **Pre-requisite**: ADR-0002 + ADR-0004 ratification (coordinated — run `/architecture-decision` for both).
