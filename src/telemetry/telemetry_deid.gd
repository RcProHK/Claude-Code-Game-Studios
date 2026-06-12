class_name TelemetryDeId extends RefCounted
## Telemetry (#28) — de-identification primitives (Rule 4 / privacy binding).
##
## Telemetry NEVER records raw bodyweight, absolute weight, or absolute 1RM. Body data
## is already normalized at the SOURCE (#9 WST / GymSys) before it is emitted; these
## helpers are the client-side normalization a handler applies when translating a signal
## into a de-identified payload — they only ever accept already-normalized inputs and
## clamp / shape them into the recorded form. The no-PII denylist is statically enforced
## by G-TEL-3 (Story 014, `tools/ci/check_telemetry_no_pii.gd`).
##
## Governing: design/gdd/telemetry.md Rule 4.

## PR magnitude relative to the player's OWN baseline, clamped to [0, 2.0] (Rule 4).
## 1.0 = at baseline; 2.0 = a doubled lift (capped). The raw kg / absolute 1RM is never
## passed through — only this normalized, self-relative ratio. Non-finite → MIN (defensive).
const PR_MAGNITUDE_MIN: float = 0.0
const PR_MAGNITUDE_MAX: float = 2.0


static func pr_magnitude(raw_ratio: float) -> float:
	if not is_finite(raw_ratio):
		return PR_MAGNITUDE_MIN
	return clampf(raw_ratio, PR_MAGNITUDE_MIN, PR_MAGNITUDE_MAX)


## Volume is recorded as a completed-exercise COUNT, never kg lifted (Rule 4).
## Negative counts are nonsensical → floored to 0.
static func volume_exercise_count(completed_exercises: int) -> int:
	return maxi(0, completed_exercises)
