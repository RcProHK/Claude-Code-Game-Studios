# Story 011: Flush model async batch POST

> **Epic**: Telemetry / Analytics(#28)
> **Status**: **Complete** — ADR-0012 transport 落地(injectable `_flush_transport` seam,真 HTTPRequest = VS-tier production default)。
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12(ADR-0012 unblock)

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 6(flush model async batch)+ Formula 5(backoff)+ EC-01/EC-12。AC-09/20。
**ADR Governing Implementation**: **ADR-0012 Telemetry Data Pipeline & Privacy(Accepted-contract 2026-06-12)**(primary)+ ADR-0004(same-origin)+ ADR-0002(session_token + HTTPRequest-per-channel idiom)
**ADR Decision Summary**: ✅ **RESOLVED** — `POST /api/game/telemetry`(X-Session-Token header)batch envelope;**dedicated 第 5 HTTPRequest channel**(隔離於 #2 4-channel MAX_INFLIGHT pool — Q-T3);成功 `200` ACK 後先清 buffer;backend `UNIQUE(session_id, client_event_id)` dedup(Q-T6);`401` → **keep buffer,NO force-boot**(pure-observer Rule 1,對比 #2 401→force-boot)。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `HTTPRequest` POST 去 same-origin `/api/game/telemetry`(ADR-0004 relative URL);**telemetry 自己一條 orphan HTTPRequest**(ADR-0002 idiom:`CONNECT_ONE_SHOT` + `call_deferred("queue_free")`,handler path **無 `await`**),**唔入** #2 的 4-channel pool(ADR-0012 §Transport / registry `telemetry_dedicated_http_channel`)。

**Control Manifest Rules (Polish layer)**:
- Required: same-origin relative URL(ADR-0004);at-least-once + backend 去重
- Forbidden: 第三方 SaaS endpoint;flush 阻 gameplay frame
- Guardrail: flush 失敗永不影響 gameplay(留 buffer + backoff)

---

## Acceptance Criteria

*ADR-0012 Accepted (contract) → finalized:*

- [x] **Rule 6 flush triggers**:(a) `flush_batch_size`(`_record` 後檢查 buffer.size);(b) `flush_interval_seconds` `_flush_timer`;(c) `workout_completed_forwarded`(`_request_flush`);(d) page-hide(Story 012 `_on_visibility_changed`)
- [x] batch serialize `_serialize_batch` → envelope `{session_id, client_batch_id, schema_envelope_version, events[]}` → `POST /api/game/telemetry`(relative,`X-Session-Token` header);`200` ACK → `_buffer.remove_by_event_ids(_in_flight_ids)` remove-on-ACK
- [x] **dedicated channel**:`_default_dispatch` orphan `HTTPRequest`(CONNECT_ONE_SHOT + call_deferred queue_free,無 await);`_flush_now` single in-flight(FLUSHING gate);**唔入** #2 pool
- [x] **401 handling**:`_on_flush_response` 401 → 留 buffer、ACTIVE、`_flush_failure_count` 不增,**無 force-boot**(test `test_401_keeps_buffer_no_force_boot`)
- [x] **pre-session buffering**:`_session_token==""` → `_flush_now` 即 return false,events 留 buffer(test `test_pre_session_no_token_keeps_buffered`)
- [x] **AC-09**:200 清 batch;429/5xx/dispatch-fail 留 buffer + Formula 5 backoff
- [x] **Formula 5 backoff**:`TelemetryFormulas.flush_backoff_delay(n, base, cap)` pure + `_register_flush_failure`;429 先 honour `Retry-After`(test `test_429_honours_retry_after`)
- [x] **EC-12**:`remove_by_event_ids` 搵唔到 no-op(test `test_ec12_late_ack_for_evicted_batch_is_noop`)
- [x] **AC-20**:`test_offline_resilience`(backend 全 down → buffer 保 + CRITICAL 保 + backoff 增 + 重連 200 自動恢復)

---

## Implementation Notes

*ADR-0012 §Endpoint / §Transport / §Auth / §Backend Schema:*

- flush 係獨立 async path(非 handler 內;Rule 2)。FLUSHING state(Story 002 FSM)。
- **transport = dedicated 第 5 orphan `HTTPRequest`**(telemetry autoload own;ADR-0002 `http_request_per_channel` idiom:`request_completed` `CONNECT_ONE_SHOT` + `call_deferred("queue_free")`;**handler path 無 `await`**)。**隔離於** #2 GymSysBackendClient 的 4-channel `MAX_INFLIGHT_REQUESTS=4` pool(registry `telemetry_dedicated_http_channel`)—— 防止 telemetry batch 餓死 `loot_commit`。
- **endpoint** = `POST /api/game/telemetry`(relative URL per ADR-0004 `absolute_game_api_urls` forbidden;`X-Session-Token` header per ADR-0002 `gymsys_session_api`,token 由 #2 session claim 提供 — telemetry 只 read,唔 own)。
- **envelope** = `{session_id, client_batch_id, schema_envelope_version=1, events:[<Rule 3 per-event envelope>]}`;成功 `200 {accepted, duplicates}` 後先 remove-on-ACK。
- **401 ≠ force-boot**:telemetry 係 pure observer,401 只 drop 當次 attempt + 留 buffer(ADR-0012 §Auth)。**呢個係同 #2 transport 契約最關鍵嘅 divergence**,務必 test(對比 #2 的 `session_invalidated`→force-boot)。
- backend dedup `UNIQUE(session_id, client_event_id)` 保證重 flush(EC-12)安全。
- Story 012 page-hide beacon 復用本 story 嘅 serialize(token-in-body 變體)。

---

## Out of Scope

- Story 012:page-hide beacon flush(緊急 fire-and-forget,另一路徑)
- Story 002:FLUSHING FSM state(此處接真 flush)

---

## QA Test Cases

*待 ADR-0012 finalize endpoint schema 後 qa-lead 補全。先記 GDD-level:*

- **AC-1 (flush lifecycle, AC-09)**:
  - Given: buffer N events + mock backend
  - When: flush POST 成功 ACK
  - Then: 該批由 buffer 移除;失敗 → 留 buffer + backoff;gameplay 不受影響
  - Edge cases: EC-12 ACK 遲到 + 已 evict → by-id 移除 no-op
- **AC-2 (offline resilience, AC-20)**:
  - Given: backend 全程 down
  - When: 跑完整 session
  - Then: gameplay 零影響;CRITICAL 全保;重連後 flush 恢復

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_flush_lifecycle.gd` + `test_offline_resilience.gd`
**Status**: [x] `test_flush_lifecycle.gd`(9 tests:remove-on-ACK / single-in-flight / 401-keeps-buffer-no-force-boot / 5xx+dispatch-fail backoff / 429 Retry-After / EC-12 by-id no-op / pre-session / opt-out)+ `test_offline_resilience.gd`(1 test AC-20 MockClock backoff growth + reconnect)。全 15 pass。transport empirical = VS-tier-gated(ADR-0012 §Verification)

---

## Dependencies

- Depends on: ✅ **ADR-0012 Accepted (contract)**(G-TEL-5 滿足)+ Story 004(buffer)/ 009 / 010
- Unlocks: Story 012(beacon 復用 flush serialize)
