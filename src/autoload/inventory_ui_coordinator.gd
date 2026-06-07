## InventoryUICoordinator — #23 Inventory UI autoload.
## (story 002 scaffold:FSM fork + CanvasLayer 61 + boot invariant)
##
## Driving GDD: design/gdd/inventory-ui.md (✅ APPROVED 2026-06-07)
## UX spec:     design/ux/inventory-ui.md (✅ APPROVED)
## Governing ADRs: ADR-0001 (#23 revision — InventoryUILayer 61, PAUSABLE,
## inside BackBufferCopy capture 0/10/50/60/61), ADR-0006 C6
## (connect_for_initial_state for GSM only), ADR-0008 (G-IU-2 tail append
## after CharacterScreenCoordinator — NO #22 boot-order constraint).
##
## ============ FSM FORK NOTICE (CD binding — GDD States) ============
## The 5-state screen FSM below is a FORK of
## src/autoload/character_screen_coordinator.gd (#22) — NOT an extraction
## (rule of three: the shared base/component ADR opens at #24 Shell
## authoring). Any change to FSM transition semantics in EITHER file must
## be mirrored in the other (behaviour equivalence is contract-pinned by
## both GDDs' Group B lifecycle ACs, mechanism-agnostic).
## Forked surface: ScreenState enum / advance() / open() / close() /
## _enter_closed() / _on_gsm_state_changed() / cfis subscribe-disconnect
## discipline / ghost-callv guard.
## Divergences (#23-specific — deliberate, NOT drift):
##   - zero persist: no _flush_pending_persist / persistence seam
##     (#23 owns no keys, no namespace — GDD negative AC-37)
##   - zero #11/#26 subscriptions: GSM is the ONLY subscription (Rule 6)
##   - axes: active_section × slot_filter × modal × make_room_pending
##     (vs #22 active_panel × modal)
##   - modal set: 6 kinds incl. BULK_SELECT/BULK_CONFIRM/MAKE_ROOM
##   - no _advance_tweens / _advance_settings (no stat rows, no settings)
##   - layer 61 (vs 60); SFX cues REUSED from #22 family
##     (ui_charscreen_open/close — cue 係質感唔係 screen ID;G-IU-3 errata)
## ====================================================================
##
## Pure overlay (Rule 2 cite #22): owns ONLY UI state (screen FSM ×
## orthogonal axes). Game data is never owned here — all item data flows
## through #17 commands + getters (story 006).
##
## CLOSED invariant (= #22 Rule 8): zero active upstream subscriptions
## while CLOSED. Subscribe on open(); disconnect AT CLOSED entry —
## deliberately NOT earlier: CLOSING must still hear GSM (upgrade to
## FORCE_CLOSING / SUSPENDED snap; do not "optimise" earlier).
##
## Ghost-callv guard (= #22 EC-05): GSM's cfis sentinel is a deferred
## next-frame CONNECT_ONE_SHOT lambda — disconnect() cannot cancel a
## pending lambda, so the handler can be callv'd AFTER close. Every
## handler no-op guards on screen state, INCLUDING CLOSED.
##
## Timing discipline (= #22, binding): ONE injected clock. Production
## _process(delta) feeds advance(delta * 1000.0); tests call
## advance(delta_ms) directly. No engine Tween / SceneTreeTimer for any
## state-bearing timing.
##
## SFX (CD C1 cite #22): open/close cues fire ONLY on player-initiated
## paths. Force-close + SUSPENDED snap are hard-silent.
extends Node

## ADR-0001 #23 revision pinned layer number (> 60 #22 — crossfade z-order).
const INVENTORY_UI_LAYER: int = 61

const GSMScript := preload("res://src/autoload/game_state_machine.gd")
## Timing knobs REUSED from #22 (GDD Tuning Knobs — referenced, 唔搬家唔 rename):
## OPEN_ANIM_MS / CLOSE_ANIM_MS / FORCE_CLOSE_MAX_MS / ERROR_TOAST_DURATION_MS。
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")
## #23 formulas(F1/F2-M/filter predicate/SORT_COMPARATOR identity seam)。
const InvUiFormulas := preload("res://src/ui/inventory_ui/inv_ui_formulas.gd")

## Screen FSM (GDD States — = #22 五態全套;fork notice above).
enum ScreenState {
	CLOSED,         ## boot default / close 完成 — zero-subscription invariant
	OPENING,        ## 入場 animation;data 第一 frame sync read 齊 (story 006)
	OPEN,           ## 互動中 (orthogonal 軸 active)
	CLOSING,        ## player-initiated 出場 animation;GSM 照聽
	FORCE_CLOSING,  ## GSM 轉入非 permitted state — ≤FORCE_CLOSE_MAX_MS fast path
}

## Section 軸 (GDD States 表) — open() clean-slate reset 到 INVENTORY (Rule 3)。
enum SectionKind { INVENTORY, MAILBOX }

## Filter 軸 (Rule 8) — view predicate only;open reset ALL。
enum SlotFilter { ALL, WEAPON, ARMOR, ACCESSORY, COSMETIC }

## Modal 軸 (GDD States 表) — 單值軸(唔係 stack);force-close 一律 cancel。
## Per-modal dismiss return-target 表(SALVAGE_CONFIRM→ITEM_INSPECT 逐層退 etc.)
## 隨 flow stories(007-015)落地。
enum ModalKind { NONE, ITEM_INSPECT, SALVAGE_CONFIRM, BULK_SELECT, BULK_CONFIRM, MAKE_ROOM }

## SlotFilter chip → formula filter 值(Rule 8;ALL → FILTER_ALL sentinel,
## 其餘 1:1 EquipSlot ordinal — mapping 收喺 coordinator,formula 層零 coupling)。
const CHIP_TO_SLOT: Dictionary = {
	SlotFilter.ALL: InvUiFormulas.FILTER_ALL,
	SlotFilter.WEAPON: EquipmentEnums.EquipSlot.WEAPON,
	SlotFilter.ARMOR: EquipmentEnums.EquipSlot.ARMOR,
	SlotFilter.ACCESSORY: EquipmentEnums.EquipSlot.ACCESSORY,
	SlotFilter.COSMETIC: EquipmentEnums.EquipSlot.COSMETIC,
}

## ---- UI state (the ONLY state #23 owns — 四 orthogonal 軸 + FSM) ----
var _state: int = ScreenState.CLOSED
var _active_section: int = SectionKind.INVENTORY
var _slot_filter: int = SlotFilter.ALL
var _modal: int = ModalKind.NONE
## MAKE_ROOM claim-target transient (Rule 11;零 persist — open reset / close /
## force-close / claim 成功 / not_in_mailbox / MAKE_ROOM dismiss 一律清空)。
var _make_room_pending: StringName = &""
var _offline_banner: bool = false
var _anim_elapsed_ms: float = 0.0

## ---- view model state (story 006;render-model snapshot,唔係 game data) ----
## Rule 5:read 後即 build snapshot view models — render 層零 live
## EquipmentItem reference(#22 _loadout_view 先例)。
var _inventory_view: Array = []   # F3 序(SORT_COMPARATOR — IN_INVENTORY+EQUIPPED)
var _mailbox_view: Array = []     # F2-M 序(acquired asc)
var _inventory_count: int = 0     # get_inventory_count(#17 L1125 口徑)
var _forge_shards: int = 0
var _equipped_ids: Dictionary = {}  # item_id → true(loadout set — 現役 badge O(1))

## ---- DI seams (untyped — GDScript DI seam convention; tests inject mocks) ----
## #23 只掂 4 個 upstream(ADR-0008 predecessor set)— 冇 #11/#26/#3/#6/#7 seams。
var _gsm = null
var _inventory = null
var _audio = null
var _platform = null

## CanvasLayer 61 (ADR-0001 #23 revision) — owned, pre-warmed hidden.
var _layer: CanvasLayer = null


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "InventoryUILayer"
	_layer.layer = INVENTORY_UI_LAYER
	_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_layer.visible = false
	add_child(_layer)
	_resolve_default_seams()
	# CLOSED at boot: zero subscriptions (Rule 6) + no idle processing.
	set_process(false)


## Injected-clock bridge: production frames and test steppers share advance().
func _process(delta: float) -> void:
	advance(delta * 1000.0)


## Single timing entry point — all state-bearing timing advances through here.
## (#22 fork minus _advance_tweens/_advance_settings;transient timers —
## toast / inline hint — 隨 flow stories 接入呢度。)
func advance(delta_ms: float) -> void:
	match _state:
		ScreenState.OPENING:
			_anim_elapsed_ms += delta_ms
			if _anim_elapsed_ms >= TimingConfig.OPEN_ANIM_MS:
				_state = ScreenState.OPEN
				_anim_elapsed_ms = 0.0
		ScreenState.OPEN:
			pass  # transient timers (stories 007+) tick here
		ScreenState.CLOSING:
			_anim_elapsed_ms += delta_ms
			if _anim_elapsed_ms >= TimingConfig.CLOSE_ANIM_MS:
				_enter_closed()
		ScreenState.FORCE_CLOSING:
			_anim_elapsed_ms += delta_ms
			if _anim_elapsed_ms >= TimingConfig.FORCE_CLOSE_MAX_MS:
				_enter_closed()
		_:
			pass


## ---- Rule 1 contract surface (shell / #22-link 接線點;double guard) ----

## Pure check — entry-affordance visibility. true ⇔ GSM ∈ {IDLE, DISCONNECTED}.
## 明文拒用 #33 is_input_permitted()(Rule 1 — 同款語意分離 cite #22)。
func can_open() -> bool:
	if _gsm == null:
		return false
	var s: int = _gsm.get_current_state()
	return s == GSMScript.GameState.IDLE or s == GSMScript.GameState.DISCONNECTED


## Opens the screen (player-initiated;#22 link path 經 call_deferred 都行呢度)。
## Double guard (Rule 1) + clean-slate reset (Rule 3 — 四軸 + pending 全 reset)
## + subscribe (Rule 6)。Rule 5 first-frame sync reads 隨 story 006 接入。
## 唔 re-check #22 state — 各自 double guard 夾埋 safe (EC-11)。
func open() -> bool:
	if _state != ScreenState.CLOSED:
		return false  # CLOSING re-tap = ignore;OPEN/OPENING no-op (= #22 Rule 5)
	if not can_open():
		return false
	_active_section = SectionKind.INVENTORY
	_slot_filter = SlotFilter.ALL
	_modal = ModalKind.NONE
	_make_room_pending = &""
	_offline_banner = _is_disconnected()
	_anim_elapsed_ms = 0.0
	_state = ScreenState.OPENING
	_layer.visible = true
	set_process(true)
	_sync_read_all()  # Rule 5 — 第一 frame 五 read 齊,冇 loading state
	_subscribe_all()  # Rule 6 — GSM only
	_play_sfx(&"ui_charscreen_open")  # reuse #22 cue family (GDD #4 row;CD C1)
	return true


## Player-initiated close → CLOSING (出場 animation;GSM 照聽).
func close() -> void:
	if _state != ScreenState.OPEN and _state != ScreenState.OPENING:
		return
	_state = ScreenState.CLOSING
	_anim_elapsed_ms = 0.0
	_play_sfx(&"ui_charscreen_close")  # player-initiated only (CD C1)


## ---- GSM lifecycle handler (= #22 fork;plain method — no .bind()) ----
## Active 喺 OPENING/OPEN/CLOSING/FORCE_CLOSING;CLOSED = no-op (ghost callv)。
func _on_gsm_state_changed(_from_state, to_state, _payload) -> void:
	if _state == ScreenState.CLOSED:
		return  # ghost sentinel callv after close (= #22 EC-05) — hard no-op
	var to: int = int(to_state)
	# SUSPENDED → instant snap CLOSED,無 animation、零 SFX (Rule 3;
	# modal 一律 cancel + pending 清空)。
	if to == GSMScript.GameState.SUSPENDED:
		_modal = ModalKind.NONE
		_enter_closed()
		return
	var permitted: bool = (
		to == GSMScript.GameState.IDLE or to == GSMScript.GameState.DISCONNECTED
	)
	if permitted:
		# IDLE↔DISCONNECTED 互轉 (Rule 3):唔 close,只 toggle banner;
		# modal 唔受影響。
		_offline_banner = (to == GSMScript.GameState.DISCONNECTED)
		return
	# ∉ permitted(含 LOOT_DROP — GDD mood note force-close path)→ force-close。
	# Destructive modal (SALVAGE_CONFIRM/BULK_CONFIRM) + MAKE_ROOM 一律 cancel,
	# 永不被 system event confirm (Rule 3 = #22 EC-01)。零 SFX (CD C1)。
	_modal = ModalKind.NONE
	if _state == ScreenState.OPENING:
		_enter_closed()  # OPENING abort 直接去 CLOSED,skip OPEN (= #22 States)
		return
	if _state == ScreenState.FORCE_CLOSING:
		return  # 已經喺 fast path
	_state = ScreenState.FORCE_CLOSING  # OPEN / CLOSING upgrade 同款
	_anim_elapsed_ms = 0.0


## ---- subscriptions (Rule 6 — GSM only;#11/#26 明文唔訂) ----

func _subscribe_all() -> void:
	# GSM — connect_for_initial_state (ADR-0006 C6;deferred next-frame sentinel).
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)
	elif _gsm != null and _gsm.has_signal("state_changed"):
		_gsm.state_changed.connect(_on_gsm_state_changed)


## Disconnect 喺 CLOSED entry 先做(CLOSING 仍要聽 GSM — rationale 見 header)。
func _disconnect_all() -> void:
	if _gsm != null and _gsm.has_signal("state_changed") \
			and _gsm.state_changed.is_connected(_on_gsm_state_changed):
		_gsm.state_changed.disconnect(_on_gsm_state_changed)


## ---- internals ----

func _enter_closed() -> void:
	# #23 零 persist — 冇 flush(#22 divergence;negative AC-37)。
	_state = ScreenState.CLOSED
	_anim_elapsed_ms = 0.0
	_layer.visible = false
	set_process(false)
	# Transients 全 drop(Rule 3 clean-slate 另一半;make_room_pending 清空 —
	# States 表「close / force-close 一律清空」)。
	_modal = ModalKind.NONE
	_make_room_pending = &""
	_disconnect_all()  # CLOSED invariant (Rule 6)


func _play_sfx(event_id: StringName) -> void:
	if _audio != null and _audio.has_method("play_sfx"):
		_audio.play_sfx(event_id)


## ---- view models(story 006;Rules 5/6/7/8 + EC-09) ----

## Rule 5 — open 第一 frame synchronous 五 read 齊:all-inventory(含
## EQUIPPED — G-IU-1 口徑)+ mailbox + count + shards + loadout(badge set
## only — G-CS-1)。Read 後即 build snapshot view models。
func _sync_read_all() -> void:
	_reread_all()


## Rule 6 — re-read 範圍統一 = Rule 5 全套(五 read 全重讀 + view model
## rebuild;唔做 targeted re-read — AC-33 2ms budget 驗可行性)。
## Command-then-re-read + section visibility re-read 全部行呢度。
func _reread_all() -> void:
	if _inventory == null:
		return
	# loadout 先讀(badge set — view build 要用)。
	_equipped_ids = {}
	if _inventory.has_method("get_loadout"):
		for equipped_id in _inventory.get_loadout().values():
			if equipped_id != &"":
				_equipped_ids[equipped_id] = true
	# INVENTORY enumeration(IN_INVENTORY + EQUIPPED)→ snapshot views → F3 序。
	_inventory_view = []
	if _inventory.has_method("get_all_inventory_items"):
		for item_id in _inventory.get_all_inventory_items():
			var view: Dictionary = _build_item_view(item_id)
			if not view.is_empty():
				_inventory_view.append(view)
		_inventory_view.sort_custom(InvUiFormulas.SORT_COMPARATOR)  # = #22 F3 同一 code
	# MAILBOX enumeration → F2-M 序(acquired asc — FIFO expiry)。
	_mailbox_view = []
	if _inventory.has_method("get_mailbox_items"):
		for item_id in _inventory.get_mailbox_items():
			var view: Dictionary = _build_item_view(item_id)
			if not view.is_empty():
				_mailbox_view.append(view)
		_mailbox_view.sort_custom(InvUiFormulas.mailbox_before)
	# counters。
	if _inventory.has_method("get_inventory_count"):
		_inventory_count = _inventory.get_inventory_count()
	if _inventory.has_method("get_forge_shards"):
		_forge_shards = _inventory.get_forge_shards()


## Snapshot view model — 欄位即場 copy(get_item 回 live ref;render 層
## 零 live EquipmentItem reference — AC-10)。{} = item 已消失(skip)。
func _build_item_view(item_id: StringName) -> Dictionary:
	var item = _inventory.get_item(item_id)
	if item == null:
		return {}
	return {
		"item_id": item_id,
		"name": String(item_id),  # ledger 用 id 誠實(#22 先例;display 名隨 asset build)
		"rarity": int(item.rarity),
		"provenance": String(item.provenance_text),  # 單行 ellipsis 係 render 層責任
		"slot_affinity": int(item.slot_affinity),
		"locked": bool(item.is_locked),
		"receipt": bool(item.has_receipt()),
		"acquired_at_unix": int(item.acquired_at_unix),
		"equipped": _equipped_ids.has(item_id),  # 現役 badge(Rule 8 — EQUIPPED 照列)
	}


## Section 切換(Rule 6/23 — visibility re-read:切到 / 切返都 re-read 全套)。
func set_active_section(section: int) -> void:
	if _state != ScreenState.OPEN:
		return
	_active_section = section
	_reread_all()


## Filter 切換(Rule 8)— view predicate only:零 re-read、view model array
## object identity 不變(AC-12);切 chip = 即時 re-filter(本地)。
func set_slot_filter(filter: int) -> void:
	if _state != ScreenState.OPEN:
		return
	_slot_filter = filter


## ---- browse view getters(render 層 + tests) ----

## 全 INVENTORY view(F3 序;filter 唔影響呢個 object — AC-12 identity)。
func get_inventory_view() -> Array:
	return _inventory_view


## Filter 後 view(Rule 8 predicate;每 call 新 array — 唔 mutate 主 view)。
func get_filtered_inventory_view() -> Array:
	var slot: int = CHIP_TO_SLOT.get(_slot_filter, InvUiFormulas.FILTER_ALL)
	if slot == InvUiFormulas.FILTER_ALL:
		return _inventory_view
	var out: Array = []
	for view: Dictionary in _inventory_view:
		if InvUiFormulas.matches_filter(int(view["slot_affinity"]), slot):
			out.append(view)
	return out


func get_mailbox_view() -> Array:
	return _mailbox_view


## 「[count]/120」readout(Rule 5 — verbatim;禁 progress bar 禁變色;
## cap referenced #17 MAX_INVENTORY,唔 hardcode)。
func get_count_readout() -> String:
	return "%d/%d" % [_inventory_count, InvUiFormulas.InventoryScript.MAX_INVENTORY]


## Shards 顯示 — G-IU-5 thousands-separator formatter 喺 story 017 落地;
## TODO(story 017): 換 shared formatter(AC-21 golden 嗰陣跑)。
func get_forge_shards_display() -> String:
	return str(_forge_shards)


## EC-09 empty copy 分流("" = 非 empty,唔 render empty state)。
func get_inventory_empty_copy() -> String:
	if get_filtered_inventory_view().is_empty():
		if _slot_filter == SlotFilter.ALL and _inventory_view.is_empty():
			# first-run(ALL + 0 件)— ledger 聲線,講事實順手教 loot 來源。
			return "收據庫仲未有收藏 — 完成 workout 之後,loot 會喺度等你"
		return "呢類暫時冇收藏"  # filter 收窄到 0 件 — 唔 auto-reset filter
	return ""


func _is_disconnected() -> bool:
	if _gsm == null:
		return false
	return _gsm.get_current_state() == GSMScript.GameState.DISCONNECTED


func _resolve_default_seams() -> void:
	_gsm = get_node_or_null("/root/GameStateMachine")
	_inventory = get_node_or_null("/root/InventorySystem")
	_audio = get_node_or_null("/root/AudioManager")
	_platform = get_node_or_null("/root/PlatformDetect")


## ---- introspection helpers (tests + shell) ----

func get_screen_state() -> int:
	return _state


func get_active_section() -> int:
	return _active_section


func get_slot_filter() -> int:
	return _slot_filter


func get_modal() -> int:
	return _modal


func get_make_room_pending() -> StringName:
	return _make_room_pending


func is_offline_banner_visible() -> bool:
	return _offline_banner
