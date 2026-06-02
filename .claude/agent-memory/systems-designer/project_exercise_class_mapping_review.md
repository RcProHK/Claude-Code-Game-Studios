---
name: exercise-class-mapping-review
description: Adversarial review findings for #10 Exercise→Class Mapping GDD — 4 BLOCKING formula/data-model defects found 2026-06-02
metadata:
  type: project
---

Adversarial review of #10 Exercise→Class Mapping GDD (`design/gdd/exercise-class-mapping.md`) on 2026-06-02 found 4 BLOCKING defects — NOT ready for story creation.

**Why:** Lean-authored GDD (no systems-designer/qa-lead consulted — user opted no agent spawns, see GDD line 150). Defects:
- B1: Formula 1 step 2 `pattern_map[movement_pattern(exercise_id)]` is dead code for the main id-lookup API (unregistered id has no entry to read `.movement_pattern` from). Must split into resolve_by_id + resolve_by_pattern.
- B2: `pattern_map` var table lists `CORE/CARDIO/FLEX/COMPOUND→authored` — type-incoherent ("authored" not an AbilityClass) + contradicts Rule 4. pattern_map should hold ONLY {PUSH→STRIKE, PULL→CONTROL, LEGS→MOBILITY}.
- B3: `MovementPattern` enum used but NEVER defined (not in ADR-0007, not in any repo file except the GDD). GDD's 7-member plural `LEGS` set conflicts with REGISTERED `class_id enum {PUSH, PULL, LEG}` at `entities.yaml:376` (singular LEG, 3 members). Cross-system entity divergence — needs reconciliation or registry update.
- B4: registry `ability_class` null/unset semantics undefined → Godot enum default ordinal 0 = STRIKE → silent fabrication, violates ADR-0007 line 93 "zero-default reliance FORBIDDEN". Worse than a fallthrough bug.

**How to apply:** When #10 stories are authored or the GDD is revised, these 4 must be closed first. The `MovementPattern` vs `{PUSH,PULL,LEG}` (entities.yaml:376) conflict is the load-bearing cross-system fact — do not let #10 introduce a divergent enum without a registry update. ADR-0007 defines AbilityClass only, NOT MovementPattern. Related: [[exercise-class-mapping-gdd]] (the authoring memory in main session store).
