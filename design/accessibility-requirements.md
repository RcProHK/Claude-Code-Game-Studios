# Accessibility Requirements

> **Status**: Committed — 2026-05-28
> **Author**: ux-designer
> **Last Updated**: 2026-05-28
> **Applies To**: All screens, HUD, and interactions in Mirror Hero

---

## Committed Accessibility Tier

**Tier: WCAG AA Core + Motion Safety**

Mirror Hero targets a web-deployed gym companion game with 25-40 year old gym users as primary audience. The game runs as a background companion during physical workouts — users have limited attention to spare for the screen. Accessibility requirements reflect this context:

1. **Visual accessibility** — color-independent design (mandated by art bible)
2. **Motion safety** — first-class motion sensitivity controls (mandated by #6 ScreenEffects + #7 Camera GDDs)
3. **Input simplicity** — single-tap primary interaction (Pillar 2 architectural mandate)
4. **Contrast** — readable HUD at a glance from 30-60cm device distance

Full screen reader support is deferred to v0.2+ unless specifically requested. The Godot 4.5+ AccessKit integration is architecturally available but not committed for MVP.

---

## Tier Commitments (binding from MVP)

### 1. Color Independence

Every semantic meaning MUST have at least two non-color signals. Color alone is NEVER the sole identifier.

| Semantic | Color | Shape Backup | Animation Backup | Audio Backup |
|----------|-------|--------------|-----------------|--------------|
| Damage incoming | Danger red `#D94B3E` | Triangle ▲ warning | 8Hz shake | Sharp blip 1.2kHz |
| Heal / Safe | Heal green `#6FB87A` | Cross ✚ icon | Slow pulse 1.5Hz | Soft sine 440Hz |
| Loot — Common | White `#FFFFFF` | 8px orb | Single bounce | "Tink" |
| Loot — Uncommon | Green `#6FB87A` | 12px orb | Trail 0.3s | Tink + harmonic |
| Loot — Rare | Blue `#4D8FD6` | 16px orb + 1 satellite | Trail 0.5s + sparkle | Tink + chime |
| Loot — Epic | Purple `#9B5FCC` | 16px orb + 2 satellite + ring | Trail 0.8s + rotating sparkle | Tink + 3-note |
| Loot — Legendary | Orange `#FF8C42` | 24px orb + pillar + vignette | Trail 1.2s + shake + slowmo | Full fanfare |
| Push / Strike | Strike red `#E85A5A` | Rectangle / straight hitbox | Linear dash | Heavy thud |
| Pull / Control | Control purple `#A66BC9` | Diamond / arc hitbox | Rotating / pull | Whoosh + held tone |
| Leg / Mobility | Mobility blue `#5BA8E8` | Parallelogram / flow | Slide trail | Wind / quick whoosh |

Source: Art Bible Section 4.B — Semantic Color Usage; Section 4.C — Colorblind Safety

**QA Protocol**: Each build must export a desaturated screenshot of combat, loot drop, and boss intro scenes. All gameplay-critical information must be readable in greyscale.

---

### 2. Motion Safety

**Screen Shake Motion Sensitivity Slider**
- Setting name: "畫面震動強度" / "Screen Shake Intensity"
- Range: [0.0, 1.0], default 1.0
- Stored in PersistenceLayer `settings.motion_intensity` namespace
- Applied via `ScreenEffects.set_motion_intensity(scale)` on boot + on change
- Effect at 0.0: shake completely disabled (hit_pause PRESERVED — visual freeze is distinct from vestibular shake)
- Source: GDD #6 ScreenEffects Rule 3, Section B honest endpoint contract

**Camera Motion Reduction Toggle**
- Setting name: "降低畫面動態" / "Reduce Camera Motion"
- Type: boolean toggle, default OFF
- Stored in PersistenceLayer `settings.reduce_camera_motion` namespace
- Applied via `CameraSystem.set_motion_reduction(enabled: bool)` on boot + on change
- Effect when ON: zoom animations disabled, dead-zone = 0% (camera locks to avatar center), boss focal mode retains but zoom-in disabled
- Source: GDD #7 Camera Q-V1 resolution (dead-zone 0% hard-lock eliminates both optical flow and stroboscopic effects per Apple HIG accessibility)
- UI hint: "禁用 zoom 動畫 + camera 鎖定 avatar 中心，保留遊戲性 (Boss / Loot 仍然觸發 ritual 但只用 audio / particle channel)"

**Motion Accessibility Interaction Contract**:
- Motion settings live in `design/ux/character-screen.md` (pending authoring)
- Settings MUST be accessible from main menu — not buried in gameplay
- Settings MUST persist across sessions and browser refreshes
- No motion settings should require navigating into active gameplay to find

---

### 3. Text Contrast

Minimum contrast ratios (WCAG AA):

| Text Type | Foreground | Background | Contrast Ratio | WCAG AA |
|-----------|-----------|------------|----------------|---------|
| HUD number (primary) | `#F5EFE0` warm white | `#1A1D24` ink-bg | ~11:1 | ✅ AAA |
| HUD amber stat | `#F2A93B` amber | `#1A1D24` ink-bg | ~8.5:1 | ✅ AAA |
| Body text | `#F5EFE0` | `#1A1D24` | ~11:1 | ✅ AAA |
| Dim / secondary | `#9A958A` | `#1A1D24` | ~5.2:1 | ✅ AA |
| CJK body text (Zpix 12px) | `#F5EFE0` | `#1A1D24` | ~11:1 | ✅ AA (large text applies at 12px+ bitmap) |

Source: Art Bible Section 4.D UI Palette

---

### 4. Input Simplicity (Pillar 2)

**Core rule**: A player who is mid-set with a barbell on their back MUST be able to perform any required in-game interaction with a single tap or without touching the device.

Binding rules:
- Exercise switch = single tap on exercise name in GymSys app (external to game UI)
- No game mechanic requires holding, multi-touch, swipe, drag, or double-tap during active gameplay
- All gameplay-critical UI elements must have touch targets ≥ 44×44 px (Apple HIG minimum)
- No tap timing requirements — no "tap here within 3 seconds" mechanics
- Source: Game concept Pillar 2 Anti-Pillars + technical-preferences.md Primary Input: "Touch (single-tap)"

---

### 5. HUD Readability at Glance

The HUD is designed for peripheral vision at 30-60cm device distance while mid-exercise:

- All HUD elements use minimum 7px bitmap font (m5x7)
- Exercise progress ring: 16px outer diameter minimum (visible at thumbnail distance)
- Health/exp bars: 6px/3px height respectively (thickness hierarchy = importance hierarchy)
- HUD anchored to screen edges with no center obstructions
- Event Layer (100% saturation) automatically separates from World Layer (70% saturation)
- Source: Art Bible Section 7.B Typography; Section 1.3 Layer Discipline

---

## Deferred Accessibility Features (v0.2+)

The following accessibility features are architecturally available but NOT committed for MVP:

| Feature | Architecture Status | Target Version |
|---------|--------------------|--------------:|
| Screen reader / VoiceOver (Godot 4.5+ AccessKit) | Available in engine, NOT configured | v0.2+ |
| Colorblind mode color swap (Deuteranopia / Protanopia overrides) | Reserved color slots in art bible, NOT implemented | v0.2+ |
| Font size scaling | Bitmap font constraint — requires TTF fallback decision first | v0.2+ |
| Subtitle/closed caption for audio events | No narrative audio in MVP | v1.0+ |
| High contrast mode | Color system designed for contrast, full mode deferred | v0.2+ |

---

## Acceptance Criteria (per screen / feature using these requirements)

Every screen UX spec and implementation story must verify:

- [ ] All interactive elements have ≥ 44×44 px touch target
- [ ] No semantic meaning communicated by color alone (shape + animation backup present)
- [ ] Minimum WCAG AA contrast ratio on all text elements
- [ ] Screen shake responds correctly to `motion_intensity = 0.0` (fully disabled, hit pause preserved)
- [ ] Camera motion reduction toggle functional when enabled
- [ ] QA desaturated screenshot review passes (all gameplay-critical info readable in greyscale)

---

## Open Questions

- **OQ-A1**: Should motion_intensity slider show preset labels ("Gentle" / "Medium" / "Full") or only numeric/percentage? Defer to #22 Character Screen UX spec authoring.
- **OQ-A2**: Should settings be accessible from pause menu in addition to character screen? Determine during pause-menu UX spec.
- **OQ-A3**: Accessibility of loot reveal modal for screen reader users — at MVP, loot is announced visually + audibly. Screen reader narration deferred to v0.2+.
