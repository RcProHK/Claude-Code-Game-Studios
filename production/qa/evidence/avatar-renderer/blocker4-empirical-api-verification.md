# #26 Avatar Renderer — Blocker 4 Empirical API Verification (Evidence)

> **Date**: 2026-06-10
> **Context**: v2-rewrite Blocker 4 of 4 — "Godot 4.6 empirical API verification" flagged
> by Pass 3 + Pass 4 fresh-session adversarial review as **mandatory empirical** (LLM knowledge
> cutoff May 2025 < Godot 4.6 Jan 2026; godot-gdscript-specialist flagged 3 calls as likely hallucination).
> **Engine**: Godot 4.6.3-stable (steam) — `godot.windows.opt.tools.64.exe`, run headless locally.
> **Reproduce**: `"$GODOT" --headless --script production/qa/evidence/avatar-renderer/blocker4_api_probe.gd`

## Questions & Verdicts

### Q1 — `AnimatedSprite2D.stop()` "pauses-in-place"? (CR-8 / F-8 snapshot chain)

**VERDICT: CR-8 CLAIM IS A HALLUCINATION — CONFIRMED.**

| Call | Empirical result (4.6.3) |
|------|--------------------------|
| `set_frame_and_progress(3, 0.5)` | `frame == 3`, `frame_progress == 0.5` |
| `stop()` | `frame == 0`, `is_playing() == false` → **RESETS to frame 0** |
| `pause()` | `frame == 3`, `is_playing() == false` → **PAUSES in place** |

- `AnimatedSprite2D.pause()` **exists** as a method in 4.6.3 (`ClassDB.class_has_method == true`).
- The GDD Pass-2 F-8 fix (`stop()` to freeze a frame for snapshot) is **fundamentally wrong** — `stop()` resets to frame 0, destroying the frame the snapshot wants to capture.
- The Pass-4 review's proposed correction "`pause = true` property" is also imprecise: it is a **method `pause()`**, not a settable property.
- **v2-rewrite binding**: snapshot / freeze must use `pause()` (method). The F-1/F-8 snapshot chain is rebuilt on `pause()`.

### Q2 — `set_frame_and_progress()` signature (F-8 frame_progress field)

**VERDICT: EXISTS — signature confirmed.**

```
set_frame_and_progress(frame: int, progress: float)
```
(`ClassDB.class_get_method_list` introspection.) `set_frame` / `get_frame` / `is_playing` all present too.

### Q3 — texture-memory monitor enum on Compatibility renderer (INV-6)

**VERDICT: correct enum exists; original `Performance.MEMORY_STATIC` was wrong.**

Two valid paths confirmed present in 4.6.3:

| API | Constant | Value |
|-----|----------|-------|
| `Performance.get_monitor(...)` | `Performance.RENDER_TEXTURE_MEM_USED` | 15 |
| `RenderingServer.get_rendering_info(...)` | `RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED` | 3 |

- The GDD's `Performance.MEMORY_STATIC` (=4) measures **total static memory**, not texture VRAM — Pass-3/4 flag correct. INV-6 must use `RENDER_TEXTURE_MEM_USED`.
- **Caveat (carries to Q-OQ11, VS-tier)**: these constants exist and return values on the **Vulkan desktop** backend (this probe). Whether the **Compatibility (GLES3 / WebGL2)** web backend reports a meaningful non-zero texture-memory figure remains a **web-runtime empirical item** — gated VS-tier per existing ADR pattern (cannot be settled by a headless desktop probe). Q-OQ11 (WebGL VRAM monitor reliability) stays open as a VS-tier gate, but the **enum name is verified** so the code can be written correctly now.

## Net effect on #26 v2 rewrite

Blocker 4 **RESOLVED**. The three API facts are now ground-truth instead of LLM-guessed:
`pause()` freezes (not `stop()`) · `set_frame_and_progress(int, float)` confirmed · texture VRAM = `RENDER_TEXTURE_MEM_USED` (with web-runtime caveat → Q-OQ11 VS-tier).
