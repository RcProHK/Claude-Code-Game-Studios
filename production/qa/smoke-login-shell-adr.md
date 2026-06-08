# Smoke Check — Story 002: Login/Shell ADR amendments (G-LS-1 + G-LS-2)

> **Date**: 2026-06-08
> **Story**: `production/epics/login-shell/story-002-adr-amendments.md`
> **Type**: Config/Data — doc/config consistency smoke
> **Verdict**: ✅ PASS

## Scope

Story 002 是 doc-only：兩個 ADR amendment(ADR-0001 layer 拓撲 + ADR-0008 autoload 位置)
+ CLAUDE.md(`@.claude/docs/technical-preferences.md`)architecture log 同步。零 `.gd` code。
project.godot 實際 autoload 登記係 Story 003(scaffold)。

## AC verification

### AC-1 — ADR-0001 amendment(G-LS-1)

| 檢查項 | 期望 | 實測 | Pass |
|--------|------|------|------|
| `LoginShellLayer` topology row | layer=62, PAUSABLE, 加在 InventoryUILayer(61)之上 | adr-0001 L118 ✓ | ✅ |
| Capture enumeration sync | `0/10/50/60/61/62`(canonical 全部一致) | L122 / L140 / L147 / L154 / L160 + #24 amendment L13 ✓ | ✅ |
| `ErrorBannerLayer` topology row | layer=111, ALWAYS, 在 CelebrationVFXLayer(110)同 ModalLayer(120)之間 | adr-0001 L128 ✓ | ✅ |
| `>100 immune / <120 below loot modal` 注記 | 有 | #24 amendment L13 + detailed section L161 ✓ | ✅ |
| Banner 禁第二 BackBufferCopy 注記 | 有(opacity-only,引 #21 blur-CUT 同源) | #24 detailed section「Banner backdrop = opacity-only — a 2nd BackBufferCopy is FORBIDDEN」+ AC-36 cite ✓ | ✅ |
| Two-layer split(EC-E3/AC-54)注記 | 有 | #24 detailed section ✓ | ✅ |
| #24 detailed layer section | 在 #23 section 之後、BackBufferCopy GPU cost note 之前 | adr-0001 L158-164「#### #24 Login Shell layers」✓ | ✅ |

### AC-2 — ADR-0008 amendment(G-LS-2)

| 檢查項 | 期望 | 實測 | Pass |
|--------|------|------|------|
| Header amendment line | #24 G-LS-2,tail append after InventoryUICoordinator,NO #21/#22/#23 constraint | adr-0008 amendment line(#23 之後)✓ | ✅ |
| Reserved insertion rules table row | #24 LoginShellCoordinator row,predecessor set + tail-append slot | adr-0008 table(#23 row 之後)✓ | ✅ |
| Predecessor set 正確 | `{GSM C6, #2, #3, #8, #11, #12, #33, PlatformDetect}` 全部 subscribe/pull consumer | GDD deps table cross-check ✓(#2 auth/claim、#3 get_pending_errors G-LS-8、#8/#11/#12 save-failed banner、#33 EC-13、PlatformDetect announce_aria)| ✅ |
| Explicit NOT-listed clause(防 phantom) | AudioManager(zero-audio Rule 8)/ ScreenEffects / CameraController / AvatarRenderer / InventorySystem | adr-0008 #24 row ✓ | ✅ |
| #28 Telemetry 仍 reserved Last | 是 | row + header line ✓ | ✅ |

### AC-3 — CLAUDE.md(technical-preferences.md)architecture log 同步

| 檢查項 | 期望 | 實測 | Pass |
|--------|------|------|------|
| ADR-0001 log row | 加 #24 G-LS-1 revision(62/111 + enumeration + 禁第二 BBC) | technical-preferences.md L65 ✓ | ✅ |
| ADR-0008 log row | 加 #24 G-LS-2(tail after #23,NO constraint,preds) | technical-preferences.md L72 ✓ | ✅ |

## Pass condition — layer 數值唯一性(grep 62/111 唯一)

ADR-0001 topology block 全部 `CanvasLayer layer=` 賦值,各出現一次:

```
1 layer=0    1 layer=10   1 layer=50   1 layer=60   1 layer=61
1 layer=62   ← LoginShellLayer(#24,唯一)
1 layer=100  1 layer=110
1 layer=111  ← ErrorBannerLayer(#24,唯一)
1 layer=120
```

**零 layer 數值衝突** — 62 / 111 各只被 #24 兩 layer 佔用。Capture enumeration canonical
引用全部 = `0/10/50/60/61/62`(歷史 amendment header line 9/11 保留各自原值 `0/10/50/60`、
`0/10/50/60/61` 作正確歷史記錄,跟 #23 更新 #22 inline「now」line 之先例)。

## Verdict

✅ **PASS** — 兩 ADR amendment + CLAUDE.md log 三者一致,layer 62/111 唯一,
capture enumeration canonical 同步,banner 禁第二 BackBufferCopy + two-layer split + predecessor set
+ explicit NOT-listed(防 phantom)齊備。Story 003 scaffold 嘅 ADR 授權前提滿足。
