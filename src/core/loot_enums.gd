## LootEnums — canonical enum declarations for #15 Loot Drop System
##
## Driving GDD: design/gdd/loot-drop-system.md (APPROVED 2026-05-28, Pass 2 Revised)
## Driving Story: production/epics/loot-drop-system/story-002-data-resources-enums.md
## Governing ADRs:
##   * ADR-0007 (Accepted 2026-05-29) Class & Domain Enum Convention — Family A / Family B rules
##   * ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula — RarityTier ordinals consumed by Formula
##   * ADR-0009 (Accepted 2026-05-29) Signal Payload Schema — enum string-name serialization
##
## WHY a dedicated enum holder (vs inline in loot_drop_system.gd):
## loot_drop_system.gd is the autoload (Story 009, currently a stub). LootDrop
## (loot_drop.gd) + every formula story (003-008) import these enums BEFORE the
## autoload exists. Declaring them in src/core/ keeps them dependency-neutral and
## importable by both the pure data records and the eventual autoload.
##
## ── ADR-0007 ENUM FAMILY CONVENTION (locked) ─────────────────────────────────
## Family A (Outcome / State): ordinal 0 = the conservative / safe / uninitialised
##   value. An unset @export field defaults to 0 and that MUST be a legitimate safe
##   state (e.g. RarityTier.COMMON is the Pillar 3 floor — see ADR-0005).
## Family B (Classification): declaration order is load-bearing; zero-default
##   reliance is FORBIDDEN. A producer must EXPLICITLY initialise the field; it must
##   never rely on the int-default fabricating a real classification.
##
## ── CRITICAL: ClassTag ≠ AbilityClass (ADR-0007 F-7 clarification) ────────────
## ClassTag (declared here) is a LOOT-ITEM outcome tag — the weight-distribution
## RESULT of Formula E2 (which class an item is affined to). Its sentinel is
## NEUTRAL ("any class can use" — a real, usable item outcome).
## AbilityClass (declared in src/autoload/ability_system.gd) is a PLAYER-CLASS
## identity enum. Its sentinel is UNKNOWN ("no dominant class determinable" —
## anti-fabrication, Pillar 1).
## They coincidentally share STRIKE/CONTROL/MOBILITY members but are DISTINCT
## types with DIFFERENT sentinels and DIFFERENT semantics. They must NEVER be
## cast, compared, or assigned cross-enum. This file declaring ClassTag is NOT a
## redeclaration of AbilityClass.
class_name LootEnums


## Loot rarity tier — ADR-0007 Family A (Outcome). Ordinal 0 = COMMON is the
## Pillar 3 floor (ADR-0005: final_tier = max(raw_tier, COMMON)) — a default /
## uninitialised tier safely means "the most common drop", never a no-drop or a
## high-value fabrication. Ordinals are LOAD-BEARING: ADR-0005 tier_thresholds /
## tier_values map raw scores to these exact ordinals (0..4 ascending value).
enum RarityTier {
	COMMON,     # 0 — safe floor (Pillar 3)
	UNCOMMON,   # 1
	RARE,       # 2
	EPIC,       # 3
	LEGENDARY,  # 4
}


## Source of the loot-granting event — ADR-0007 Family A. Ordinal 0 = WORKOUT_DAILY
## is the most common, lowest-stakes trigger (the daily-token path), a safe default
## meaning "ordinary daily drop" rather than a boss reward.
enum SourceEventKind {
	WORKOUT_DAILY,  # 0 — daily token trigger (Rule 11)
	MINI_BOSS,      # 1 — mini-boss kill ceremony
	FINAL_BOSS,     # 2 — final-boss kill (reserved emit pool, Rule 9)
}


## Ceremony routing decision — ADR-0007 Family A. Ordinal 0 = FULL_CEREMONY is the
## default "celebrate it" path; degraded routes (micro-ack / non-ceremony) are
## explicit downgrades the cap/attention logic selects.
enum CeremonyDecision {
	FULL_CEREMONY,        # 0 — full reveal animation
	MICRO_ACK,            # 1 — micro acknowledgement (cap-pressure degrade)
	NON_CEREMONY_ROUTE,   # 2 — silent grant to inventory (cap hit)
}


## Loot-item class affinity tag — ADR-0007 Family B (Classification).
##
## This is the RESULT of Formula E2 (class_affinity_resolution): which player
## class an item is biased toward. NEUTRAL = "any class can use this item" and is
## a REAL, usable outcome (CONSUMABLE / COSMETIC items always resolve to NEUTRAL;
## class items may also roll NEUTRAL via W_NEUTRAL weight). NEUTRAL is the Family B
## sentinel placed LAST.
##
## DISTINCT from AbilityClass (see file header). NEUTRAL here is NOT the
## anti-fabrication player-class sentinel (that is AbilityClass.UNKNOWN). Producers
## MUST set this explicitly (Family B forbids zero-default reliance) — but note
## that for ClassTag, ordinal 0 (STRIKE) is a real class, so an unset field would
## fabricate STRIKE: the producer (Formula E2) always assigns an explicit value.
enum ClassTag {
	STRIKE,    # 0 — push / STR affinity (a REAL class, not a safe default)
	CONTROL,   # 1 — pull / DEX affinity
	MOBILITY,  # 2 — leg / VIT affinity
	NEUTRAL,   # 3 — any class can use (sentinel LAST; a real usable outcome)
}


## Item category — ADR-0007 Family B (Classification). Declaration order is the
## canonical item-type space consumed by Formula item_type_weighted_selection.
## Ordinal 0 (WEAPON) is a real type; producers assign explicitly (Family B).
enum ItemType {
	WEAPON,      # 0
	ARMOR,       # 1
	ACCESSORY,   # 2
	CONSUMABLE,  # 3 — Formula E2 forces ClassTag.NEUTRAL for this type
	COSMETIC,    # 4 — Formula E2 forces ClassTag.NEUTRAL for this type
}


## Pending-loot expiry state — ADR-0007 Family A. Ordinal 0 = FRESH is the safe
## default: an uninitialised pending drop is treated as still-valid (never
## prematurely discarded). SOFT/HARD expiry are explicit aged states (Formula 3 TTL).
enum ExpiryState {
	FRESH,         # 0 — within TTL, safe default
	SOFT_EXPIRED,  # 1 — past soft TTL (degrade ceremony)
	HARD_EXPIRED,  # 2 — past hard cap (Rule 5 force-commit on next boot)
}


## Resume action after a bfcache restore / boot with pending loot — ADR-0007
## Family A. Ordinal 0 = CONTINUE_ANIMATION is the safe "pick up where we left off"
## default; the other actions are explicit deferrals chosen by reconcile logic.
enum ResumeAction {
	CONTINUE_ANIMATION,   # 0 — resume the in-flight reveal
	DEFER_TO_NEXT_BOOT,   # 1 — stash, replay later
	NO_ACTION,            # 2 — nothing pending
}


## Catch-up presentation mode for multiple pending drops — ADR-0007 Family A.
## Ordinal 0 = SEQUENTIAL_REVEAL is the default low-volume path; the summary
## banner is the explicit high-volume degrade.
enum CatchUpMode {
	SEQUENTIAL_REVEAL,          # 0 — reveal each drop in turn (few pending)
	SUMMARY_BANNER_THEN_BURST,  # 1 — banner + batched burst (many pending)
}


## Inventory overflow routing — ADR-0007 Family A. Ordinal 0 = DIRECT_INVENTORY is
## the normal path; mailbox overflow is the explicit full-inventory fallback.
enum OverflowMode {
	DIRECT_INVENTORY,   # 0 — slot available, grant directly
	MAILBOX_OVERFLOW,   # 1 — inventory full, route to mailbox
}


## Reveal FSM state for a single LootDrop — ADR-0007 Family A. Ordinal 0 =
## PRE_REVEAL is the safe default (a drop not yet shown; bfcache resume defers
## it to the next user gesture rather than forcing an animation mid-session).
## Used by Formula 4 `bfcache_resume_action()` (Story 005) to determine
## whether a suspended reveal should continue or defer on app foreground.
enum DropRevealState {
	PRE_REVEAL = 0,              # 0 — queued, not yet shown (safe default)
	MID_REVEAL = 1,              # 1 — reveal animation in progress
	POST_REVEAL_PRE_HANDOFF = 2, # 2 — animation complete, awaiting #17 handoff
}
