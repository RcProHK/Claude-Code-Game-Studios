# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented -->
4. [Primary mechanic — update when first core system is implemented]

## GymSys Integration (add when ADR-0002 is implemented)

5. GymSys polling connects and receives workout data (5s interval)
6. Workout state updates correctly on set_completed event
7. Loot drop triggers on workout_complete event

## Data Integrity

8. Save game completes without error (once PersistenceLayer is implemented)
9. Load game restores correct state (bfcache resume within 24h window)
10. Private Mode detected and loot disabled gracefully (ADR-0003)

## Performance

11. No visible frame rate drops (60fps target on desktop)
12. Particle count stays ≤200 active (Web Export, GPU particles only)
13. Memory below 512MB ceiling after 5 minutes of play

## Web Export Specific

14. Game loads in browser within 10 seconds (WASM bundle ≤50MB)
15. Touch input works on mobile Safari (single-tap exercise switch)
