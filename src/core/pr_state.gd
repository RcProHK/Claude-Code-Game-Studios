## PrState — #18 `pr.state` single-key persistence envelope (Story 003).
##
## Driving GDD: design/gdd/pr-detection.md Rule 8 (single key — #3 IPersistence
## has NO key enumeration; whole-cache flush makes per-key splitting free of
## benefit) + D8 (pending inner schema) + ADR-0006 C3 / ADR-0009.
##
## Schema:
##   baselines:  { exercise_id: String → best_e1rm: float }   (trusted ratchet)
##   pending:    { exercise_id: String → { e1rm_raw, weight, reps, opened_seq } } (D8)
##   candidates: { exercise_id: String → candidate_e1rm: float } (Formula 4 window)
##   workout_seq:       int   (#2 workout_started counter — D8 discard deadline)
##   lifetime_count:    int   (Rule 9 milestone axis)
##   lifetime_pr_score: float (Σ magnitude — #19 v0.2 PR_SCORE data surface)
##
## JSON round-trip notes: ints arrive back as float (JSON has one number type) —
## from_dict() re-coerces; dictionaries are rebuilt with String keys + coerced
## values so a fresh-loaded envelope is type-identical to a live one.
class_name PrState extends SerializableResource


var baselines: Dictionary = {}
var pending: Dictionary = {}
var candidates: Dictionary = {}
var workout_seq: int = 0
var lifetime_count: int = 0
var lifetime_pr_score: float = 0.0


func to_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"baselines": baselines.duplicate(),
		"pending": pending.duplicate(true),
		"candidates": candidates.duplicate(),
		"workout_seq": workout_seq,
		"lifetime_count": lifetime_count,
		"lifetime_pr_score": lifetime_pr_score,
	}


## Defensive reconstruction (missing keys → defaults; JSON float→int re-coerce).
## Returns a fresh PrState — corrupt/partial input degrades to empty fields
## (INV-PR-1 makes an empty baseline map safe: establishment-only, never fake PRs).
static func from_dict(data: Dictionary) -> PrState:
	var s := PrState.new()
	var raw_baselines: Variant = data.get("baselines", {})
	if raw_baselines is Dictionary:
		for k: Variant in raw_baselines:
			var v: Variant = raw_baselines[k]
			if (v is float or v is int) and str(k) != "":
				s.baselines[str(k)] = float(v)
	var raw_pending: Variant = data.get("pending", {})
	if raw_pending is Dictionary:
		for k: Variant in raw_pending:
			var entry: Variant = raw_pending[k]
			if entry is Dictionary:
				s.pending[str(k)] = {
					"e1rm_raw": float(entry.get("e1rm_raw", 0.0)),
					"weight": float(entry.get("weight", 0.0)),
					"reps": int(entry.get("reps", 0)),
					"opened_seq": int(entry.get("opened_seq", 0)),
				}
	var raw_candidates: Variant = data.get("candidates", {})
	if raw_candidates is Dictionary:
		for k: Variant in raw_candidates:
			var v: Variant = raw_candidates[k]
			if v is float or v is int:
				s.candidates[str(k)] = float(v)
	s.workout_seq = int(data.get("workout_seq", 0))
	s.lifetime_count = int(data.get("lifetime_count", 0))
	s.lifetime_pr_score = float(data.get("lifetime_pr_score", 0.0))
	return s
