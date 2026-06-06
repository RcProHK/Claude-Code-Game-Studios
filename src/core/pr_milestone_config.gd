## PrMilestoneConfig — #18 milestone thresholds (Story 010, data-driven).
## PROVISIONAL [10, 25, 50, 100] — zero gameplay validation yet; #19 v0.2 must
## not consume before the Q-PR-1 calibration (GDD Rule 9 / P2 ruling).
## MVP consumer: telemetry only.
class_name PrMilestoneConfig extends Resource


## Strictly ascending positive ints (EC-12 — validate_milestone_config gates boot).
@export var thresholds: Array[int] = [10, 25, 50, 100]
