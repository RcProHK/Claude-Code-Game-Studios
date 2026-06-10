# UX Spec: Mirror Moment Ceremony (#29)

> **Status**: In Design
> **Author**: user + ux-designer (full-autonomous, 2026-06-10)
> **Last Updated**: 2026-06-10
> **Journey Phase(s)**: Week-End Retention Loop — "the pause where you recognise yourself"
> **Template**: UX Spec
> **Coupled pair**: consumes the Hero-Pose Shared-Asset Contract from `design/ux/avatar-renderer.md` (#26). #29 owns COMPOSITION; #26 owns the asset (ADR-0010).
> **GDD**: `design/gdd/mirror-moment.md` (APPROVED 2026-06-10) — UI Requirements §, CR-M7/M8/M9/M12, AC-13/16/18.

---

## Purpose & Player Need

Once a week, when the player opens Mirror Hero **outside a workout**, the game pauses to show them what their real training did to their avatar — a **before→after reveal they can screenshot and share**. The need is emotional, not functional: a designed pause that says *"come look — you really changed this week."* Without it, the avatar silhouette quietly swaps and nobody stops to witness it — and that witnessing is the single-player retention heart (game-concept: "每週 visible 進化嘅 anticipation"). The screenshot is worth sharing **precisely because it can't be faked** — the character changed because the player went to the gym (Pillar 1).

> "The player arrives at this moment wanting to **see — and prove — that the week counted.**"

---

## Player Context on Arrival

| Attribute | Value |
|---|---|
| **When** | Week-end (or first non-workout open after a cadence window opens), GSM == `IDLE` |
| **Just before** | Finished a set / opened the app in the locker room; NOT mid-workout (Pillar 2 — #26 CR-15 defers the trigger, #29 CR-M3 gates the presentation) |
| **Emotional state** | Calm, reflective, **pride-seeking** (Achiever transformation pride) |
| **Voluntary?** | **Passive-trigger, active-share** — the system decides *when* it fires (player can't summon it); the player actively screenshots / shares / dismisses |
| **Frequency** | At most **once per 7-day cadence window** (CR-M9 once-per-window; never nags) |

The ceremony **must not feel like an interruption to dismiss** — it must feel like a reward to linger on. Dismiss is zero-friction (Pillar 2), but the default invites a screenshot.

---

## Navigation Position

The ceremony is a **modal overlay on top of the IDLE game**, not a navigated screen:

`[in-game IDLE] → (system auto-detect: cadence window open ∧ has_change ∧ safe context) → Mirror Moment overlay`

- **Not reachable from any menu** — there is no "replay ceremony" entry (MVP non-goal). It is purely system-triggered.
- The game underneath is **not paused** — GSM stays `IDLE`; the ceremony is a CanvasLayer overlay, not a game state (#29 owns no GSM transition). Dismiss returns the player to the same IDLE they were in.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| In-game IDLE | `ceremony_arm_check` true (Formula 1) **and** GSM stable `IDLE` ≥ `CEREMONY_PRESENT_DELAY_FRAMES` (6, anti-flicker EC-MM-14) **and** CR-M3 gate (∉ workout/combat/loot/suspended; #33 `is_input_permitted()` if present) | fresh `get_evolution_snapshot()` taken at present-time (CR-M6) |
| Boot flush | persisted `pending_evolution_ceremony` + first safe context after boot (CR-M11) | latch rebuilt from `mirror_moment.*` |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Back to IDLE | tap **✕** / tap **backdrop** / `CEREMONY_AUTO_DISMISS_SECONDS` (default 0 = manual) | sets window markers + clears latch (CR-M9); **screenshot-taken or not is irrelevant to the marker** (no re-nag) |
| Back to IDLE (shared) | screenshot confirmed | emits `mirror.shared` + `last_shared_unix`; same window-done marker |
| Hold (no exit) | GSM `SUSPENDED` mid-ceremony | overlay pauses (CR-M12); resume ≤30s continues, >30s collapses overlay but keeps window marker (no resume-spam) |

> **One-way note**: once dismissed, the player **cannot return to this window's ceremony** (MVP non-goal — no replay). The evolution itself persists in the avatar; only the *ceremony* is one-shot.

---

## Layout Specification

### Information Hierarchy

In the ceremony, the player's eye must land in this order:

1. **The avatar hero pose** (current, full-saturation, centred) — *the subject; "this is me."*
2. **The before→after delta** (EVOLUTION only): 30%-opacity prior-tier ghost beside/behind the current pose — *"you came from here."*
3. **The tier badge** ("T2", amber-gold high-sat) — *the headline achievement.*
4. **The caption** ("第 6 週 · STRIKE · 進化到 T2" — enriched form needs #9, null-safe to "進化到 T2") — *the words to read/share.*
5. **The screenshot affordance** ("截圖分享" CTA) — *the call to action.*
6. **Narrative line(s)** (optional, smaller: #17 signature loot / #18 PR) — *flavour, smallest.*
7. **Dismiss ✕** (low-emphasis) — *present but quiet.*

> **Layer-discipline binding (B-1 resolved)**: the world behind is desaturated/dimmed (opacity-only backdrop, **NO 2nd BackBufferCopy** — #24 AC-36 budget); the share-card content is full-saturation so the eye lands on the avatar + badge first.

### Layout Zones

ADR-0001 modal topology (aligned with #21 Loot Drop Modal's established >100 modal stack):

| Zone | CanvasLayer | Content |
|---|---|---|
| **Backdrop** | (below 110) opacity-only dim over the IDLE world | tap = dismiss; world already desaturated |
| **Celebration + Composite** | **CelebrationVFXLayer 110** | avatar hero-pose composite + prior-tier ghost (EVOLUTION) + celebration particle burst (**LOOT preset only**, B-1 — only LOOT presets reach this layer via #5 `_celebration_layer` residence) |
| **Share-card chrome + controls** | **ModalLayer 120** | tier badge + caption + narrative + "截圖分享" CTA + ✕ dismiss |

The **share-card region** is a bounded Control (`SHARE_CARD_ASPECT`, MVP = `"viewport"`) — **this is exactly what the player screenshots**, so its edges must be clean (surrounding chrome is hidden the instant a screenshot is invoked, CR-M7).

### Component Inventory

| Component | Type | Interactive? | Pattern | Notes |
|---|---|---|---|---|
| Backdrop | dim overlay | Yes (tap = dismiss) | Modal-Dismiss-Backdrop (existing-likely) | opacity-only, no BackBufferCopy |
| Share-card region | bounded Control | No (display) | **Share-Card (NEW — flag for library)** | the screenshot target |
| Avatar hero-pose composite | image (from #26 `hero_pose_frame`) | No | Hero-Pose (from #26 spec) | full saturation, centred |
| Prior-tier ghost | image @ 30% opacity | No | — | EVOLUTION only; absent for REFLECTION / first-ever (Formula 3 `show_ghost`) |
| Celebration burst | #5 particles (LOOT preset) | No | — | EVOLUTION only; **none** for REFLECTION |
| Tier badge | label/icon | No | Badge (existing-likely) | amber-gold high-sat |
| Caption + narrative | text | No | — | enriched via #9/#17/#18 (null-safe) |
| **"截圖分享" CTA** | button | **Yes** | **Screenshot-Share Affordance (NEW — flag for library)** | amber-gold; the MVP deliverable |
| **✕ dismiss** | button | **Yes** | Modal-Close (existing-likely) | top-right, low-emphasis |

Two **new patterns** to flag for `design/ux/interaction-patterns.md`: **Share-Card** (bounded screenshot-target region with chrome-hide on capture) and **Screenshot-Share Affordance** (native-screenshot prompt flow). See Cross-Reference Check.

### ASCII Wireframe

```
EVOLUTION (大慶典)                         REFLECTION (輕慶典)
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│  ░░ dimmed / desaturated world ░░│ ✕     │  ░░ dimmed / desaturated world ░░│ ✕
│  ┌───────────── share-card ────┐ │       │  ┌───────────── share-card ────┐ │
│  │     ·:✦·  burst (LOOT/110)  │ │       │  │      (no burst, 輕)         │ │
│  │   ╲▓█▓╱        ▓██▓         │ │       │  │            ▓██▓             │ │
│  │  ghost(30%)   HERO POSE     │ │       │  │          HERO POSE          │ │
│  │   (T-1)        (current)    │ │       │  │     (micro-shader on)       │ │
│  │            ┌────┐            │ │       │  │                             │ │
│  │            │ T2 │ badge      │ │       │  │   第 6 週 · 本週回顧        │ │
│  │   第 6 週 · STRIKE · 進化到 T2│ │       │  │   (你練咗 N 次 — #9 opt)    │ │
│  │   本週簽名:鍛造自 180kg×5    │ │       │  └─────────────────────────────┘ │
│  └─────────────────────────────┘ │       │       [   截圖分享 📸   ]        │
│       [   截圖分享 📸   ]        │       │                                 │
└─────────────────────────────────┘       └─────────────────────────────────┘
  ModalLayer 120 = badge/caption/CTA/✕       (same structure, no ghost, no burst)
  CelebrationVFXLayer 110 = pose+ghost+burst
```

---

## States & Variants

| State / Variant | Trigger | What changes |
|---|---|---|
| **EVOLUTION** | `pending_evolution_ceremony` (Formula 2) | before→after ghost (if `show_ghost`) + tier badge + celebration burst + screenshot CTA |
| **REFLECTION** | `week_had_change` only, no tier-up | single hero pose + "本週回顧" caption + screenshot CTA; **no ghost, no burst** |
| **NONE (no render)** | no change this week | **ceremony does not appear** (CR-M15 honest skip; `mirror.no_change_skip`) — there is no empty-state screen, the overlay simply never opens |
| **First-ever tier-up** | `prior_sprite == ""` (EC-MM-7) | single frame + "首次進化" caption, no ghost |
| **Screenshot-armed** | tapped "截圖分享" | non-card chrome hidden + native-screenshot hint shown |
| **Post-screenshot** | 3s / second tap | chrome restored + "影咗喇 ✓ / 跳過" choice |
| **Paused** | GSM `SUSPENDED` mid-ceremony | particles frozen, share-card frozen, window marker NOT set (CR-M12) |
| **Snapshot-invalid** | hero-pose asset fails (EC-MM-8) | collapse ceremony + `mirror.snapshot_invalid` CRITICAL; mark window presented (no retry loop) |

> **No "loading state"** — `get_evolution_snapshot()` is a synchronous read at present-time; if it returns null (EC-MM-11) the ceremony stays ARMED and retries next tick (no spinner shown to the player).

---

## Interaction Map

> Input methods (from `technical-preferences.md`): **Touch (primary, single-tap)** + Keyboard/Mouse; Gamepad **None**. All ceremony interactions are **one-tap, no hover-only, no drag**.

| Player Action | Input | Immediate Feedback | Outcome |
|---|---|---|---|
| Tap **"截圖分享"** | tap / click / Enter | button depress; non-card chrome fades out; hint "用裝置截圖功能影低呢個畫面 📸" appears | emit `mirror.share_prompted`; share-card pushed to cleanest state (CR-M7) |
| Tap again / 3s elapse (after share-prompt) | tap / click | chrome fades back in; "影咗喇 ✓ / 跳過" two-choice appears | — |
| Confirm "影咗喇 ✓" | tap | brief confirm flash | emit `mirror.shared` + `last_shared_unix`; dismiss → IDLE |
| Choose "跳過" | tap | — | emit `mirror.share_skipped`; dismiss → IDLE |
| Tap **✕** | tap / click / Esc | button highlight | set window markers + clear latch (CR-M9); dismiss → IDLE |
| Tap **backdrop** | tap / click | — | same as ✕ (CR-M9 dismiss) |
| (none) auto-dismiss | `CEREMONY_AUTO_DISMISS_SECONDS` timer (default 0 = off) | — | dismiss → IDLE if enabled |

> **In-app capture-to-PNG is NOT in MVP** (Q-OQ-CAPTURE locked native-only) — web export `get_viewport().get_texture()` → file-save is cross-browser-unreliable. MVP trusts the OS screenshot. "儲存圖片" one-tap is v0.2.

---

## Events Fired

| Player Action | Event | Payload |
|---|---|---|
| Ceremony presented | `mirror.ceremony_presented` | `{content: EVOLUTION/REFLECTION, tier, transition_id}` |
| Tap "截圖分享" | `mirror.share_prompted` | `{tier, content}` |
| Confirm shared | `mirror.shared` (**FT-2**) | `{tier, unix}` — drives the ≥30% weekly self-initiated share falsifiable test |
| Skip share | `mirror.share_skipped` | `{tier}` |
| No-change week | `mirror.no_change_skip` | `{}` (CR-M15) |
| Snapshot invalid | `mirror.snapshot_invalid` | CRITICAL (EC-MM-8) |

> **Persistent-state writes flagged for architecture**: dismiss writes `mirror_moment.*` (window markers, latch clear, `ceremony_count`, `last_shared_unix`) via PersistenceLayer (ADR-0003). **Zero `avatar.*` write** (CI-MM-4 — #29 owns no tier state). All events go to #28 Telemetry (Soft, emit-only).

---

## Transitions & Animations

| Transition | Behaviour | Constraint |
|---|---|---|
| Ceremony enter | backdrop fades to dim (opacity-only) + share-card scales/fades in; EVOLUTION fires one celebration burst as the pose settles | **NO 2nd BackBufferCopy** (#24 AC-36); burst on CelebrationVFXLayer 110 (LOOT preset, B-1) |
| Screenshot-arm | non-card chrome fades out ~150ms → hint in | clean screenshot target (CR-M7) |
| Ceremony exit | share-card fades/scales out + backdrop clears | zero-friction (Pillar 2) |
| REFLECTION | **no burst**; micro-evolution shader already on the avatar (#26 CR-5b — #29 doesn't re-draw) | 輕慶典 — quiet |
| Suspend → resume | ≤30s continue; >30s / negative collapse overlay (keep window marker) | CR-M12, bfcache 30s parity |
| **Reduced-motion** | `motion_intensity` slider (#6) = 0 → **static share-card, no particle animation, no scale-in** | celebration carried by static badge + caption, not motion — information never motion-dependent |

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| `AvatarEvolutionSnapshot` (tier, posture, sprite paths, hero_pose_frame, prior_tier, prior path, source_metrics) | **#26** (HARD) | Read | fresh at present-time (CR-M6); **#29 never derives tier** |
| `avatar_evolution_milestone` / `avatar_micro_evolution` signals | #26 (HARD) | Read (subscribe) | latch trigger (CR-M4 / CR-M2b) |
| GSM state + `state_changed` | #1 (HARD) | Read | safe-context gate (CR-M3) + suspend |
| `mirror_moment.*` latch + window markers + counters | #3 (HARD) | **Read/Write** | CR-M13; **only namespace #29 writes** |
| celebration burst | #5 (HARD) | call `play()` | LOOT preset → CelebrationVFXLayer 110 (B-1) |
| week N / workout count M (caption enrich) | **#9** (SOFT) | Read | null-safe → caption degrades to tier/class (R-1, Q-OQ-CAPTION-N) |
| `SourceReceipt.signature_text` (signature loot line) | #17 (SOFT) | Read | null-safe (CR-M10a) |
| PR breakthrough context | #18 (SOFT) | Read | null-safe (CR-M10b) |
| `is_input_permitted()` extra gate | #33 (SOFT) | Read | null-safe → GSM gate only |

All 4 HARD deps are shipped → #29 can build with no upstream block; all SOFT deps degrade gracefully (caption/gate thinner, core unchanged).

---

## Accessibility

Committed against `design/accessibility-requirements.md` + aligned with #24 / #19 a11y patterns:

- **Screen reader**: on present, `platform_detect.announce_aria("Mirror Moment：第 N 週進化到 T{tier}", polite)` (#24 Story 019 additive 2-arg announce + polite region, back-compat). "截圖分享" CTA and ✕ have ARIA labels.
- **Reduced motion**: respects `motion_intensity` (#6 owns) — celebration burst density down/off; at 0 → static share-card, no particle animation. **Ceremony content (avatar + caption + badge) is unaffected** — information is never carried by motion.
- **Colour independence**: tier badge pairs colour with the **text label** ("T2"), never colour alone; the avatar class is silhouette-mass (inherited from #26).
- **Touch targets**: "截圖分享" + ✕ ≥ **44 × 44 px** (web mobile/tablet, touch primary).
- **One-tap**: dismiss / screenshot / skip are all single tap — no hover-only, no drag, no chord.
- **No forced timing**: default `CEREMONY_AUTO_DISMISS_SECONDS = 0` (manual dismiss) so a player using assistive tech is never rushed off the ceremony.

---

## Localization Considerations

| Element | Longest-text risk | Mitigation |
|---|---|---|
| Caption ("第 N 週 · STRIKE · 進化到 T{tier}") | **HIGH** — class names + "進化到" + tier; 40% EN→DE/FR expansion could wrap | caption region must allow 2-line wrap inside the share-card; never truncate the tier |
| "截圖分享" CTA | MEDIUM — must stay on one line | button auto-sizes; reserve width for ~60% expansion |
| Narrative line (signature loot / PR) | MEDIUM | smaller font, single line, ellipsis-on-overflow (flavour, non-critical) |
| "影咗喇 ✓ / 跳過" | LOW | short tokens |
| Numbers (week N, count M, kg in signature) | — | locale number formatting (delegated to #9/#17 source) |

Flag for localization engineer: the **caption is layout-critical inside the screenshot** — it must remain legible and unclipped across locales because the player shares it.

---

## Acceptance Criteria

- [ ] **Opens only in safe context** — ceremony presents only when GSM == `IDLE` (stable ≥ 6 frames) and cadence window open and has_change; never during workout/combat/loot/suspended (AC-03 / FT-M3).
- [ ] **Screenshot flow** — tapping "截圖分享" hides non-card chrome, shows the native-screenshot hint, and emits `mirror.share_prompted`; confirming emits `mirror.shared` (AC-13).
- [ ] **EVOLUTION vs REFLECTION** — EVOLUTION shows ghost (when `show_ghost`) + tier badge + celebration burst; REFLECTION shows a single hero pose + recap caption + **no burst** (AC-05/06/14).
- [ ] **Dismiss is zero-friction and non-nagging** — ✕, backdrop tap, or auto-dismiss all return to IDLE; the same window never re-presents, **whether or not a screenshot was taken** (AC-16, CR-M9).
- [ ] **Celebration burst lands above the backdrop** — the EVOLUTION burst is visible over the dimmed modal backdrop (uses a LOOT preset → CelebrationVFXLayer 110), not hidden behind it (B-1).
- [ ] **Accessibility** — ceremony announces via `announce_aria(..., polite)`; "截圖分享" + ✕ are ≥ 44×44 px with ARIA labels; reduced-motion yields a static share-card with no information loss.
- [ ] **Suspend safety** — `SUSPENDED` mid-ceremony freezes the overlay; resume ≤30s continues, >30s collapses but keeps the window marker (no resume-spam) (AC-18, CR-M12).
- [ ] **Caption null-safety** — with #9/#17/#18 absent, the caption renders as tier/class only with no crash and no blank fields (AC-21, R-1).

---

## Open Questions

| ID | Question | Owner | Resolution |
|----|----------|-------|------------|
| **Q-UX-PRESET** | EVOLUTION burst preset — **must be a LOOT preset** to reach CelebrationVFXLayer 110 (B-1 HARD). Confirm reuse of an existing loot-celebration preset (vs a new #5 preset needing a LARGE-tier + celebration-residence amendment). | art-director + #5 owner | pre-`/create-stories` (= GDD Q-OQ-PRESET); default reuse |
| **Q-UX-CELEB-LAYER** | Confirm CelebrationVFXLayer 110 is **persistent shared infra** registered at #5/#21 boot (so an IDLE ceremony — when #21's loot modal is NOT active — still has the layer to render onto). | #5 / #21 owner | epic wiring (B-1 dependency note) |
| **Q-UX-CAPTION-N** | Week N + workout count M source = #9 WST surface (snapshot.source_metrics lacks them). Wire #9, else caption degrades to tier/class. | epic wiring | epic time (= GDD Q-OQ-CAPTION-N) |
| **Q-UX-SHARECARD-ASPECT** | MVP `SHARE_CARD_ASPECT = "viewport"` (full-screen clean screenshot); 9:16 layered portrait → v0.2. Confirm viewport for MVP. | ux-designer | this spec — **locked viewport for MVP** |
| **Q-UX-NEWPATTERNS** | "Share-Card" + "Screenshot-Share Affordance" are new patterns — add to `interaction-patterns.md`? | ux-designer | post-spec (flagged in Cross-Reference Check) |
| **Player-journey gap** | No `design/player-journey.md` — week-end context inferred from game-concept Retention Hooks. | — | post-spec |

> **Cross-link**: consumes the **Hero-Pose Shared-Asset Contract** in `design/ux/avatar-renderer.md` (#26). #29 composes; #26 supplies the frame. Keep hero-pose requirements in sync.

---

## Cross-Reference Check

> **GDD requirement coverage**: all UI Requirements from `mirror-moment.md` §UI (ceremony overlay topology, screenshot prompt flow, share-card, interaction states, accessibility, non-goals) are covered. ✅
> **New patterns to add to library**: **Share-Card** (bounded screenshot-target with chrome-hide on capture) + **Screenshot-Share Affordance** (native-screenshot prompt flow). Flagged — add to `design/ux/interaction-patterns.md` at `/ux-review` or epic time.
> **Navigation consistency**: overlay-only, no navigation edges to other specs except the #26 hero-pose seam. ✅
> **Accessibility gaps**: tier not formally pinned project-wide (Q-UX-A11Y in #26 spec); ceremony meets touch/ARIA/reduced-motion/one-tap baseline. ✅
> **Missing empty states**: NONE-week = no overlay (honest skip), not an empty screen — intentional, not a gap. ✅
