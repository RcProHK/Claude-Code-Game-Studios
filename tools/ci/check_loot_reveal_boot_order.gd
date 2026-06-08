## CI lint — #21 LootRevealCoordinator boot-order gate (story 002, AC-79).
##
## Verifies project.godot [autoload] listing order against ADR-0008 G-LM-5:
##   HARD: every member of the predecessor set boots BEFORE LootRevealCoordinator,
##         and LootRevealCoordinator is tail-appended AFTER ZoneSystem.
##   HARD: #28 Telemetry (when it lands) stays after #21 — enforced by the
##         "tail" check failing if any non-whitelisted autoload follows #21.
##
## Exit codes:
##   0 = pass
##   1 = HARD constraint violated
##   2 = internal error (project.godot missing / unreadable / no [autoload])
##
## Governing docs: ADR-0008 (#21 insertion rule 2026-06-07); ADR-0001 #21 revision;
##   design/gdd/loot-drop-modal.md G-LM-5; story-002 AC-79.
extends SceneTree


const PROJECT_FILE: String = "res://project.godot"
const LINT_TAG: String = "check_loot_reveal_boot_order"

const SUBJECT: String = "LootRevealCoordinator"

## ADR-0008 G-LM-5 predecessor set — ALL are HARD (boot-time API/layer providers).
const HARD_PREDECESSORS: Array[String] = [
	"PersistenceLayer",
	"GameStateMachine",
	"PlatformDetect",
	"LootDropSystem",
	"AttentionBudget",
	"ParticleSystemWrapper",
	"CameraController",
	"ScreenEffects",
	"AudioManager",
	"ZoneSystem",
]

## Autoloads allowed to boot AFTER #21 — reserved-Last (#28) plus the
## ADR-0008-sanctioned tail-append amendments that came after G-LM-5:
##   - CharacterScreenCoordinator (#22 G-CS-8, ADR-0008 amendment 2026-06-07)
##   - InventoryUICoordinator (#23 G-IU-2, ADR-0008 amendment 2026-06-07)
##   - LoginShellCoordinator (#24 G-LS-2, ADR-0008 amendment 2026-06-08)
## The #21 invariant this lint protects is "boots after its predecessor set"
## (the #5 LOOT pool reparent handshake) — NOT absolute-tail; ADR-0008 is the
## ground truth for who may follow. Update this list per ADR-0008 amendment
## (feedback_lint_allowlist_adr_sync — keep in sync or main goes RED on the next
## tail-append epic, as happened silently after the #22 merge).
const ALLOWED_SUCCESSORS: Array[String] = [
	"Telemetry",
	"CharacterScreenCoordinator",
	"InventoryUICoordinator",
	"LoginShellCoordinator",
]


func _init() -> void:
	if not FileAccess.file_exists(PROJECT_FILE):
		push_error("[%s] project.godot not found at %s" % [LINT_TAG, PROJECT_FILE])
		quit(2)
		return

	var file := FileAccess.open(PROJECT_FILE, FileAccess.READ)
	if file == null:
		push_error("[%s] project.godot unreadable" % LINT_TAG)
		quit(2)
		return
	var lines: PackedStringArray = file.get_as_text().split("\n")

	var order: Dictionary = _parse_autoload_order(lines)
	if order.is_empty():
		push_error("[%s] no [autoload] section found in project.godot" % LINT_TAG)
		quit(2)
		return

	var errors: Array[String] = []
	var subject_pos: int = order.get(SUBJECT, -1)
	if subject_pos == -1:
		errors.append("%s is not registered in [autoload] — G-LM-5 not executed" % SUBJECT)
	else:
		for name: String in HARD_PREDECESSORS:
			var pos: int = order.get(name, -1)
			if pos == -1:
				errors.append("%s (hard predecessor of %s) is not registered in [autoload]" % [name, SUBJECT])
			elif pos > subject_pos:
				errors.append(
					"%s (pos %d) MUST boot before %s (pos %d) — ADR-0008 G-LM-5" % [
						name, pos, SUBJECT, subject_pos,
					])
		for name: String in order.keys():
			var pos: int = order[name]
			if pos > subject_pos and name not in ALLOWED_SUCCESSORS:
				errors.append(
					"%s (pos %d) boots AFTER %s (pos %d) but is not a reserved-Last autoload — #21 must stay tail (ADR-0008)" % [
						name, pos, SUBJECT, subject_pos,
					])

	if errors.is_empty():
		print("[%s] PASS — %s boot order satisfies ADR-0008 G-LM-5" % [LINT_TAG, SUBJECT])
		quit(0)
	else:
		for e: String in errors:
			push_error("[%s] %s" % [LINT_TAG, e])
		quit(1)


## order[name] = 1-based listing index inside [autoload]. Comments/blank skipped.
func _parse_autoload_order(lines: PackedStringArray) -> Dictionary:
	var order: Dictionary = {}
	var in_section: bool = false
	var idx: int = 0
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line.begins_with("["):
			in_section = line == "[autoload]"
			continue
		if not in_section or line.is_empty() or line.begins_with(";"):
			continue
		var eq: int = line.find("=")
		if eq <= 0:
			continue
		idx += 1
		order[line.substr(0, eq).strip_edges()] = idx
	return order
