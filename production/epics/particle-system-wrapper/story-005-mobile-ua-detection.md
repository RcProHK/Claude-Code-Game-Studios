# Story 005: Mobile UA Detection (Boot-Cached, Conservative Default)

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)；ADR-0001 FORBIDDEN pattern：raw `JavaScriptBridge.eval()` outside `src/autoload/platform_detect.gd`
**ADR Decision Summary**: Mobile detection 經 PlatformDetect autoload boot-cache（一次 JSBridge call），wrapper 唔每 frame call。Unknown/null UA → conservative default = MOBILE（FR-3 安全方向：寧可降 particle budget）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `JavaScriptBridge.eval` 喺 `--headless` 返 null（無 web platform）；`OS.has_feature("web")==false` 喺 CI。所以 UA-string 分類邏輯**必須**抽 pure static func 或經 injectable UA provider seam，先可 headless 驗證。raw `JavaScriptBridge.eval()` 只可喺 `platform_detect.gd`（CI: `check_platform_detect_callers.gd`）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: UA 經 PlatformDetect boot-cache；分類邏輯抽 pure func / injectable seam
- Forbidden: raw `JavaScriptBridge.eval()` outside `platform_detect.gd`；per-frame UA 讀取
- Guardrail: `_is_mobile` boot 後 immutable

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-11** — UA classification + conservative default + boot-cache immutability：iPhone UA → mobile；null/非-String/throw → mobile（FR-3 conservative）；boot 後 provider swap 唔改 `_is_mobile`（provider 只讀一次，後續 play 唔重讀）；debug override（`set_mobile_override`）只喺 `OS.is_debug_build()` 有效。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- **強烈建議** 抽 pure static func `classify_ua(ua: Variant, max_touch: int) -> bool` — 令成個 UA table headless deterministic。
- UA table（全 → MOBILE 除註明）：`iphone/ipod/ipad`→mobile；`macintosh` + `maxTouchPoints>1`（iPad-as-Mac）→mobile；`macintosh` + `maxTouchPoints==0`→desktop；`android`+`mobile`→mobile；`android` 無 `mobile`（tablet）→mobile（conservative fallthrough）；`windows nt`/`linux x86_64`→desktop；空/unknown→mobile（FR-3）。
- `OS.has_feature("web")==false`（native/CI）→ Rule 10 喺 bridge 之前 return desktop(false)；但注入 provider 可繞過呢個 short-circuit 去測 UA table。
- `_is_mobile` boot-cache，`_ua_provider` 只 call 一次（assert invocation count == 1 across many play）。
- 注意：FR-3 100% iOS Safari accuracy（TR-particle-021）係 perf/hardware claim，喺 Story 009 (BLOCKED)；呢個 story 只測分類邏輯正確性 + conservative default。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: mobile_mult(0.5) 喺 Formula 1 應用（呢個 story 只決定 `_is_mobile` boolean）
- Story 009: FR-3 真實 iOS Safari device UA accuracy（hardware-gated）

---

## QA Test Cases

- **AC-11**: UA classification + conservative default + boot-cache immutability
  - Given: injectable `_ua_provider` seam（JSBridge headless 不可用）
  - When: provider 返 `"...iPhone..."` → `_detect_mobile()==true`
  - And When: provider 返 null / 非-String(int) / throw → `true`（FR-3 conservative）
  - And: boot 後 provider swap 成 desktop UA，再 play → `_is_mobile` 保持 boot-cached；`_ua_provider` invocation count == 1 across many play
  - Edge cases（全 assert true=MOBILE 除註明）: iphone/ipod/ipad→mobile；macintosh+touch>1→mobile；macintosh+touch0→desktop；android+mobile→mobile；android tablet→mobile；windows/linux→desktop；空/unknown→mobile；`OS.has_feature("web")==false`→desktop(Rule 10，注入 provider 繞過唔污染 UA-string test)；debug override 只 debug build 有效

> **Critical headless caveat**: `JavaScriptBridge.eval` 喺 headless 返 null。UA-string 分支邏輯**唔可以**經真 `_detect_mobile()` 喺 CI 跑除非 UA source injectable。Mandatory：抽 `classify_ua()` static func 或注入 UA provider seam。強烈建議 pure static func。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/particle/test_mobile_ua_detection.gd` — must exist and pass（AC-11）

**Status**: [x] Created; GUT 10/10 PASS（particle dir 44/44）+ combined 1138/1139（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 001（wrapper shell）
- Unlocks: Story 003（Formula 1 mobile_mult 用 `_is_mobile`）— 003 已先做，`_is_mobile` default false 由本 story wire

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 1/1（AC-11 classify_ua table + conservative default FR-3 + boot-cache immutability + debug-only override）
**Implementation**: `particle_system_wrapper.gd`：
- **Static pure `classify_ua(ua, max_touch)`**（qa-lead 建議）— UA table（iphone/ipod/ipad→mobile；macintosh+touch>1→mobile；android/mobile→mobile；其餘 valid string→desktop；null/non-string→mobile FR-3）。零 JSBridge，headless deterministic。
- `_detect_mobile()` — override → `_ua_provider`（injectable seam）→ classify_ua。ADR-0001 禁 wrapper 直接 call JavaScriptBridge.eval（只 platform_detect.gd 可），UA 經 provider（production wired to PlatformDetect）。
- `_mobile_override` + `set_mobile_override()`（`OS.is_debug_build()` gated，production no-op）。
- `_ready()` cache `_is_mobile = _detect_mobile()` 一次（Rule 10 immutable mid-session）。
**Key discoveries（spec flag for designer）**:
1. **GDD Rule 10 code-vs-table/FR-3 矛盾**：authoritative code block 最後 `return false` → unrecognized **valid** string（包括空字串「""」）classify 做 **DESKTOP**；但 Rule 10 table + FR-3 intent 講「fallthrough → MOBILE conservative」。實作跟 locked code（null/non-String → MOBILE；unknown valid string → DESKTOP），test 明確驗證。**建議 designer 釐清**：truly-unknown UA 應否 conservative-mobile（若係，code 應改 known-desktop-patterns→false、else→true）。記低待澄清。
2. `JavaScriptBridge.eval` headless 返 null + ADR-0001 forbidden → 必須 injectable provider seam + pure static classify_ua（已做）。
**Deviations**: production `_ua_provider` → PlatformDetect 嘅 wiring 留 Story 007 boot sequence（PlatformDetect 已 pos 3 boot 先於 wrapper pos 12）。本 story default（無 provider + native/CI）= DESKTOP。
**Test Evidence**: `tests/unit/particle/test_mobile_ua_detection.gd`（10 test functions）
**Code Review**: Pending（lean mode — 後續 batch review）
