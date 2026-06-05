## BossFormulas — stateless pure boss-fight math (GP-F9)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Formulas section (Formula 1-4) + GP-F9 contract
##
## Governing ADR:
##   * ADR-0001 (Web Export Budget Caps) — HP/scaling envelope
##
## Driving Story: production/epics/boss-system/story-003-formula1-hp-scaling.md
## Implementing TR: TR-boss-007 (boss_max_hp_scaling, clamped)
##
## STATELESS PURE-FUNCTION CLASS (mirrors #13 CombatResolver architecture):
## every public method is a `static func` taking explicit inputs and returning a
## value — NO instance state, NO signals, NO autoload access, NO `_emit_telemetry`.
## This purity is what makes AC-41(e) statically verifiable: a pure helper CANNOT
## reach `BossSystem._emit_telemetry`, so first-session-bootstrap telemetry must be
## emitted by the `BossSystem.spawn_boss` CALLER (Story 007), not here. The CI lint
## `check_boss_formulas_purity.gd` (Story 015 / followup-08) enforces 0 occurrences
## of `_emit_telemetry` / `BossSystem` in this file.
##
## SIGNATURE NOTE (deviation from the GDD's `compute_max_hp(template, snapshot)`):
## the shipped `CombatResolver.StatSnapshot` (combat_resolver.gd:142) carries ONLY
## `attack_power` + `crit_chance` — it has NO `workout_duration_sec` (and no
## `max_hp` for Formula 2). The GDD signature is therefore not implementable as
## written. These pure formulas take EXPLICIT SCALARS instead — the cleaner, more
## testable form that matches GP-F9's own「static func taking explicit inputs」rule.
## The caller (BossSystem / BossInstance, Story 002/007) sources `base_hp` from the
## BossTemplate, `attack_power` from the passed snapshot, and `workout_duration_sec`
## from the #9 WorkoutSummaryRO. (GDD signature reconciliation tracked as a #16
## doc-sync followup — non-blocking; shipped-code is authoritative.)
class_name BossFormulas extends RefCounted


# --- Formula 1 tuning knobs (boss-system.md Tuning Knobs; data-driven .tres is a
#     post-MVP refinement — these MVP defaults mirror the GDD knob table) ---

## Target hits to kill the final boss (Formula 1). Range [9, 15] — lower bound 9
## range-enforces INV-9b against the first-session window (Pass 9 B3).
const TARGET_KILL_HITS_FINAL: int = 9

## Global HP scaling sensitivity to player ATTACK_POWER.
const HP_SCALE_FACTOR: float = 1.0

## Anti-trivialize floor. Upper bound narrowed 200->80 (Pass 10 B4) to range-
## enforce INV-9c; default 50.
const MIN_BOSS_HP: int = 50

## Anti-impossible ceiling.
const MAX_BOSS_HP: int = 10000

## First-session bootstrap (player_attack_power == 0) minimum effective_atk.
const BOOTSTRAP_ATTACK_POWER: float = 10.0

## First-session ramp target ATTACK_POWER after the duration ramp completes.
## ⚠️ INERT at default knobs — the first-session cap (180) < base_hp (200) always
## binds, so this shapes the pre-cap effective_atk only (Followup #26).
const FIRST_SESSION_BASELINE_ATK: float = 28.0

## First-session duration ramp denominator (seconds). ⚠️ INERT (see above).
const FIRST_SESSION_DURATION_TARGET_SEC: float = 600.0

## First-session player's expected per-hit damage (#13-co-calibrated). Caps the
## bootstrap HP so the first fight isn't tankier than mid-game.
const FIRST_SESSION_EXPECTED_HIT_DAMAGE: int = 20

## Max hits to clear the first-session boss. INV-9b: <= TARGET_KILL_HITS_FINAL.
const FIRST_SESSION_KILL_HITS_MAX: int = 9


## Effective ATTACK_POWER used by Formula 1.
##
## Normal path: returns the player's real ATTACK_POWER unchanged.
##
## First-session bootstrap (player_attack_power == 0 — true first session OR a
## degenerate boot before #11 has real lift data): a duration-based ramp gives an
## engaging (not trivial) fight even before real stats exist —
## `max(BOOTSTRAP_ATTACK_POWER, duration_factor * FIRST_SESSION_BASELINE_ATK)`
## where `duration_factor = clamp(workout_duration_sec / target, 0, 1)`.
##
## Exposed as its own static func so AC-41 (a)-(d) can test the ramp intermediate
## directly — the final `compute_max_hp` masks it under the first-session cap.
static func compute_effective_atk(player_attack_power: float, workout_duration_sec: float) -> float:
	if player_attack_power != 0.0:
		return player_attack_power
	var duration_factor: float = clampf(workout_duration_sec / FIRST_SESSION_DURATION_TARGET_SEC, 0.0, 1.0)
	return maxf(BOOTSTRAP_ATTACK_POWER, duration_factor * FIRST_SESSION_BASELINE_ATK)


## Formula 1 — boss_max_hp_scaling.
##
## `raw = base_hp + effective_atk * TARGET_KILL_HITS_FINAL * HP_SCALE_FACTOR`,
## clamped to [MIN_BOSS_HP, MAX_BOSS_HP]. On the first-session bootstrap branch
## (player_attack_power == 0) a floor-safe cap keeps the first fight from being
## tankier than mid-game: `max(min(hp, EXPECTED_HIT_DAMAGE * KILL_HITS_MAX), MIN_BOSS_HP)`.
##
## @param base_hp                Per-boss baseline (BossTemplate.base_hp, [50,500]).
## @param player_attack_power    Frozen snapshot ATTACK_POWER (0 -> bootstrap).
## @param workout_duration_sec   #9 WorkoutSummaryRO duration (bootstrap ramp only).
## @return                       boss_max_hp in [MIN_BOSS_HP, MAX_BOSS_HP].
static func compute_max_hp(base_hp: int, player_attack_power: float, workout_duration_sec: float) -> int:
	var effective_atk: float = compute_effective_atk(player_attack_power, workout_duration_sec)
	var raw: float = float(base_hp) + effective_atk * float(TARGET_KILL_HITS_FINAL) * HP_SCALE_FACTOR
	var boss_max_hp: int = int(clampf(raw, float(MIN_BOSS_HP), float(MAX_BOSS_HP)))
	if player_attack_power == 0.0:
		# Bootstrap branch only — floor-safe first-session cap (Pass 7 fix 10).
		var cap: int = FIRST_SESSION_EXPECTED_HIT_DAMAGE * FIRST_SESSION_KILL_HITS_MAX
		boss_max_hp = maxi(mini(boss_max_hp, cap), MIN_BOSS_HP)
	return boss_max_hp
