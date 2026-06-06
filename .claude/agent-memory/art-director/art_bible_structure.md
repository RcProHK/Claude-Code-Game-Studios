---
name: art-bible-structure
description: Mirror Hero art-bible location + the principles/tokens AD must enforce when speccing visuals
metadata:
  type: reference
---

Art bible: `C:\Users\frank\Desktop\Claude-Code-Game-Studios\design\art\art-bible.md` (Complete 2026-05-28, Direction A "Maple Pixel + Particle Storm", AD-ART-BIBLE CONCERNS-accepted).

**One-Line Rule (§1.1):** 「乾淨剪影 + 骯髒粒子」— silhouette carries identity, particle carries event, saturation carries priority.

**3 supporting principles (§1.2):** P1 Silhouette First; P2 Particle Budget Rule (baseline 1N / loot 3N, particle = state明度尺); P3 Layer Discipline (World −30% sat / Character mid / Event 100% sat HDR amber+white).

**Color tokens (§4):** `event_amber #F2A93B` (HUD主色, S76% V95%, 永遠100%不受mood override), `event_white #FFFFFF` (loot burst/critical/P5 reveal only). UI ink: `ui_ink_bg #1A1D24`, text `ui_text_primary #F5EFE0` (warm white — pure white reserved for loot). amber/white **Event Layer only** — NPC黃衫=誤讀interactable.

**Mood override (§4.E):** MoodController.gd autoload tweens per-layer saturation by game state. DISCONNECTED/SUSPENDED/LOOT defer是#20自己嘅dim狀態 (not in §4.E table).

**UI direction (§7):** Frameless HUD, no box/border; 1px hard shadow `#1A1D24` @40% (not gaussian); HUD 100% flat 2D, depth靠layer contrast. Typography (§7.B): m5x7/m6x11 pixel font, Zpix 12px中文; HUD number 7px monospace + 1px shadow amber. Icon (§7.C): solid silhouette + 1px ink outline, squint-test @8×8, active state amber ≤3px. Animation (§7.D): "Snap + Settle" personality (NO bounce — 太可愛); number ticker = step function (跳唔滑); HUD appear ease-out cubic 120ms.

**Budget (§8):** Web Export, ≤200 draw call (HUD reserved ≤15 elements of 150 sprite cap), 512MB, Compatibility renderer. Mobile 0.5×: cut particle count, NOT sprite resolution. GPUParticles2D only via particle_system_wrapper.gd (ADR-0001); CPUParticles2D HARD-banned. Particle .tres naming `vfx_<event>_<variant>.tres`, amount總和≤200 desktop/≤100 mobile.

**Reference (§9):** one element per reference — HUD layout=Hyper Light Drifter (frameless, <15% edge), hit feel=Dead Cells (freeze 4-6f + white flash), particle=Noita.
