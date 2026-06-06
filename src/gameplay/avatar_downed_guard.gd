## AvatarDownedGuard — invincible-avatar enforcement during a boss fight (Story 013)
##
## Driving GDD:
##   * design/gdd/boss-system.md — EC-25 (AvatarDowned) + Rule 16 NEVER #13 (no game-over)
##     + AC-45 + DOWNED_INVULN_SEC / AVATAR_RECOVER_HP_FRACTION knobs
##
## Driving Story: production/epics/boss-system/story-013-avatar-downed-recover.md
## Implementing TR: (EC-25 / AC-45 — Formula 2 live-HP consequence; no dedicated TR)
##
## ADR: N/A — a Pillar-2 frictionless behaviour enforcer (consumes Formula 2 damage
## via #13). References ADR-0001 (no new budget).
##
## Mirror Hero is a gym companion auto-battler: there is NO game-over / permadeath /
## retry (Pillar 2 absolute). The avatar is the「打唔死嘅見證者」— when boss damage
## drives its HP to 0 it enters a brief `downed` state then AUTO-RECOVERS to a low
## fraction of max HP, with a short grace/invulnerability window that suppresses
## further damage so a degenerate low-HP avatar can't infinite-flicker (Pass 11
## live-HP consequence). This class OWNS that rule. It deliberately exposes NO
## game-over / death / retry API (AC-45 a) — there is nothing here to「lose」.
##
## DI: `_now_provider` (injectable clock for the grace window). The boss attack
## damage (Formula 2 output, applied by #13) is fed via `apply_boss_damage`.
class_name AvatarDownedGuard extends RefCounted

## Emitted when the avatar is downed (consumer forwards `boss.avatar_downed`
## telemetry to #28). Intrinsic payload only (ADR-0009).
signal avatar_downed

## Fraction of avatar max_hp restored after a downed auto-recover (clamped >= 1).
const AVATAR_RECOVER_HP_FRACTION: float = 0.25

## Post-recover grace / invulnerability window (seconds) — boss damage does NOT
## apply during it (kills the degenerate-player_max_hp instant re-down flicker).
const DOWNED_INVULN_SEC: float = 0.6

var avatar_max_hp: int = 100
var avatar_current_hp: int = 100
var downed_count: int = 0  # how many times downed this fight (telemetry / test)

var _grace_until_sec: float = -1.0  # unix time until which damage is suppressed
var _now_provider: Callable = Callable(Time, "get_unix_time_from_system")


func _init(max_hp: int = 100) -> void:
	avatar_max_hp = maxi(1, max_hp)
	avatar_current_hp = avatar_max_hp


## Apply boss attack damage (Formula 2 output). During the post-recover grace
## window the hit is suppressed (AC-45 f). On reaching 0 the avatar is downed
## then auto-recovers — it NEVER stays dead, NEVER triggers a game-over.
func apply_boss_damage(amount: int) -> void:
	var now: float = float(_now_provider.call())
	if now < _grace_until_sec:
		return  # grace window — damage suppressed (anti re-down flicker)
	avatar_current_hp = maxi(0, avatar_current_hp - maxi(0, amount))
	if avatar_current_hp == 0:
		_enter_downed_and_recover(now)


## True while the post-recover invulnerability window is active.
func is_in_grace_window() -> bool:
	return float(_now_provider.call()) < _grace_until_sec


func _enter_downed_and_recover(now: float) -> void:
	downed_count += 1
	# AC-45 (b) — auto-recover to a low HP fraction (>= 1). NO game-over node/signal
	# is created here (AC-45 a) — this class has no such API.
	avatar_current_hp = maxi(1, roundi(AVATAR_RECOVER_HP_FRACTION * float(avatar_max_hp)))
	# AC-45 (f) — open the grace window.
	_grace_until_sec = now + DOWNED_INVULN_SEC
	# AC-45 (e) — signal the down (consumer forwards boss.avatar_downed telemetry).
	avatar_downed.emit()
