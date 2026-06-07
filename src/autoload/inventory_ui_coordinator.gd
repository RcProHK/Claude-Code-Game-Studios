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
## claim ② return 嘅 shortfall(verbatim render — #17 invariant 下 N≡1)。
var _make_room_shortfall: int = 0
## ITEM_INSPECT / SALVAGE_CONFIRM 對象(modal 軸對應 transient)。
var _inspect_item_id: StringName = &""
var _salvage_target: StringName = &""
## Inspect 內 lock nudge(Rule 13 (a) — render locus = sheet 內 inline 一行;
## sheet-local lifetime:閂咗即棄,唔跟去 list)。{item_id, confirmed} 或 {}。
var _inspect_nudge: Dictionary = {}

## BULK_CONFIRM receipt itemised list cap(GDD Tuning Knobs — default 8,
## safe range 4-20;cap 咗都「+N more」總數照報 — 誠實度唔縮水)。
const BULK_CONFIRM_RECEIPT_LIST_MAX: int = 8

## BULK_CONFIRM context(row-tap 時點 snapshot — EC-01:modal 唔 live-update,
## preview 係快照,execute 係事實)。
var _bulk_rarity: int = -1
var _bulk_preview: Dictionary = {}
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

## {text, remaining_ms} — 同屏最多 1 條(新取代舊;= #22 pattern)。
var _toast: Dictionary = {}
## injected tz offset seam(F1 date_local;production = device offset;
## tests 注入固定值 — AC-01/14 determinism)。
var _tz_offset_provider: Callable = func() -> int:
	return int(Time.get_time_zone_from_system()["bias"]) * 60

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
			_advance_transients(delta_ms)
			_anim_elapsed_ms += delta_ms
			if _anim_elapsed_ms >= TimingConfig.OPEN_ANIM_MS:
				_state = ScreenState.OPEN
				_anim_elapsed_ms = 0.0
		ScreenState.OPEN:
			_advance_transients(delta_ms)
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
	_inspect_item_id = &""
	_salvage_target = &""
	_inspect_nudge = {}
	_toast = {}
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
## modal ≠ NONE ⇒ tabs 被 scrim 封鎖(States 表;MAKE_ROOM「自行整理」係
## 唯一例外 — 佢本身先 set modal=NONE 再嚟)。
func set_active_section(section: int) -> void:
	if _state != ScreenState.OPEN or _modal != ModalKind.NONE:
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


## ---- mailbox render(story 008;Rule 10 + F1 render guards + EC-08/15) ----

## MAILBOX rows(F2-M 序已喺 view build)+ retention 行 + receipt 裝飾。
## Retention 行:F1 三 guard 喺 formula 層("" = 唔 render);過去日期照
## render 原文案,零 urgency styling(D2/EC-15 — 賬簿唔改寫事實)。
## 「領取」永遠 enabled(rescue window — Rule 12;#17 claim 零 TTL check)。
## #23 唔 render evict 預警(EC-10 — v0.2 Q-IU4 negative fold)。
func get_mailbox_rows() -> Array:
	var tz: int = _tz_offset_provider.call()
	var rows: Array = []
	for view: Dictionary in _mailbox_view:
		var row: Dictionary = view.duplicate()
		var date_text: String = InvUiFormulas.retention_date_text(
			int(view["acquired_at_unix"]), bool(view["receipt"]), tz)
		row["retention_line"] = ("保留至 %s" % date_text) if date_text != "" else ""
		row["receipt_glyph"] = bool(view["receipt"])  # 細印章形(asset spec)
		row["receipt_note"] = "收據件唔會自動分解" if bool(view["receipt"]) else ""  # #17 A3
		row["claim_enabled"] = true  # rescue window(Rule 12 — 唔好「好心」disable)
		rows.append(row)
	return rows


## MAILBOX tab count badge(Rule 10 文法):dim ink 純文字「(N)」;
## 0 件唔 render(""")— 禁色 pill / 紅 / dot / pulse(styling 喺 skin 層)。
func get_mailbox_badge_text() -> String:
	return "(%d)" % _mailbox_view.size() if _mailbox_view.size() > 0 else ""


## Z3 sub-header(filter chips + count + 批量分解)只喺 INVENTORY render
## (UX spec Zones — MAILBOX 冇 filter 冇 bulk 入口)。
func is_sub_header_visible() -> bool:
	return _active_section == SectionKind.INVENTORY


## ---- claim(story 008/009;Rule 11 — dispatch order BINDING ① ② ③) ----

## Claim 一件 mailbox 件。Return 處理順序(binding — Rule 11):
## ① ok == true → success;② shortfall > 0 → MAKE_ROOM(**呢個 return 冇
## error key — #17 L725,唔行 error path**;not_in_mailbox 有 shortfall:0,
## 所以條件係 >0 唔係 key-presence);③ 其餘 → Rule 14 error path。
## (EC-05 equipped 判定分支 + MAKE_ROOM pending lifecycle/hint — story 009。)
func claim_item(item_id: StringName) -> Dictionary:
	if _state != ScreenState.OPEN:
		return {"ok": false, "error": "screen_not_open"}
	var result: Dictionary = _inventory.claim(item_id)
	# ① success。
	if result.get("ok", false):
		_make_room_pending = &""  # claim 成功清空(States 表)
		_reread_all()
		# EC-05:auto-equip 判定 predicate(claim 觸發 #17 評估 — re-read 後
		# 睇 lifecycle)。零 lock nudge — auto-equip 係 #17 機器,唔係 player
		# 手動選擇(#22 Rule 24 silent-accept 口徑)。
		var claimed = _inventory.get_item(item_id)
		var auto_equipped: bool = claimed != null \
				and claimed.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED
		_show_toast("已領取並裝上" if auto_equipped else "已領取")
		return result
	# ② shortfall(MAKE_ROOM — D4;claim target 入 transient pending)。
	if int(result.get("shortfall", 0)) > 0:
		_make_room_pending = item_id
		_make_room_shortfall = int(result["shortfall"])
		_modal = ModalKind.MAKE_ROOM
		_play_sfx(&"ui_sheet_open")
		return result
	# ③ error path(Rule 14 統一 map;deferred_reentrancy 例外唔 toast,
	# 下 frame 收割 = #22 EC-23 口徑)。
	if String(result.get("error", "")) == "not_in_mailbox":
		_make_room_pending = &""  # not_in_mailbox 清空(States 表)
	_handle_command_error(result)
	return result


## ---- MAKE_ROOM(story 009;Rule 11 D4 — 雙入口 + transient + inline hint) ----

## MAKE_ROOM sheet view(D4 copy;shortfall verbatim — #17 invariant N≡1,
## L725 公式只產 1;中文無複數,copy 零問題)。{} = modal 唔係 MAKE_ROOM。
func get_make_room_view() -> Dictionary:
	if _modal != ModalKind.MAKE_ROOM:
		return {}
	return {
		"title": "倉滿 — 要騰 %d 個位" % _make_room_shortfall,
		"claim_target": _make_room_pending,
	}


## 入口 (a)「批量分解」→ BULK_SELECT(pending 保留 — BULK_CONFIRM
## claim-target warning 喺 story 011 接;兌現 #17 bulk-salvage shortcut 期望)。
## Cue:前 modal 關一響 + 後 modal 開一響(map「兩層連開 = 兩響」口徑)。
func make_room_bulk_entry() -> void:
	if _modal != ModalKind.MAKE_ROOM:
		return
	_modal = ModalKind.BULK_SELECT
	_play_sfx(&"ui_sheet_close")
	_play_sfx(&"ui_sheet_open")


## 入口 (b)「自行整理」→ modal NONE + 切 INVENTORY(= Rule 23 visibility
## re-read)。States 表明文:呢個入口係 tabs-封鎖嘅唯一例外 — 佢本身 set NONE。
func make_room_self_organize() -> void:
	if _modal != ModalKind.MAKE_ROOM:
		return
	_modal = ModalKind.NONE
	_play_sfx(&"ui_sheet_close")
	set_active_section(SectionKind.INVENTORY)


## Dismiss(cancel / scrim / ESC 等效)= 放棄:pending 清空(States 表);
## claim button 唔 disable — 重試 = 再 tap 領取(EC-04)。
func make_room_dismiss() -> void:
	if _modal != ModalKind.MAKE_ROOM:
		return
	_modal = ModalKind.NONE
	_make_room_pending = &""
	_play_sfx(&"ui_sheet_close")


## Inline hint strip(P-14 文法;L0 static — 唔 slide 唔 pulse)。
## 騰夠位(count < cap)+ pending 件仍 IN_MAILBOX 先 render;件已消失
## (被 bulk 食咗 — QA note)→ 清 pending,silent。{} = 唔 render。
func get_make_room_hint() -> Dictionary:
	if _make_room_pending == &"" or _modal != ModalKind.NONE:
		return {}
	if _inventory_count >= InvUiFormulas.InventoryScript.MAX_INVENTORY:
		return {}
	var item = _inventory.get_item(_make_room_pending) if _inventory != null else null
	if item == null or item.lifecycle_state != EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		_make_room_pending = &""  # implementer note:件唔再喺 mailbox → 清,silent
		return {}
	return {
		"text": "已騰出空位 — 領取「%s」" % String(_make_room_pending),
		"item_id": _make_room_pending,
	}


## Hint one-tap claim(P-14 action)。
func hint_claim_tap() -> Dictionary:
	if _make_room_pending == &"":
		return {"ok": false, "error": "no_pending"}
	return claim_item(_make_room_pending)


## Hint dismiss X = 放棄(pending 清空;claim 可重試)。
func hint_dismiss() -> void:
	_make_room_pending = &""


## ---- ITEM_INSPECT + 單件 commands(story 010 mailbox 面;013 收 inventory/equipped 全套) ----

## Command 入口 guard(= #22 — 只喺 OPEN 接受;EC-04 ii)。
func _command_allowed() -> bool:
	return _state == ScreenState.OPEN


## List row 主體 tap → ITEM_INSPECT(Rule 13/22 entry map)。
func open_inspect(item_id: StringName) -> void:
	if not _command_allowed() or _modal != ModalKind.NONE:
		return
	_inspect_item_id = item_id
	_modal = ModalKind.ITEM_INSPECT
	_play_sfx(&"ui_sheet_open")


## Inspect view(Rule 13 — affordance set 按 lifecycle 分;Rule 12 mailbox 面)。
## provenance 全文(list row 先 ellipsis);stat_modifiers 原始數據 — 禁 predicted final。
func get_inspect_view() -> Dictionary:
	if _inspect_item_id == &"" or _inventory == null:
		return {}
	var item = _inventory.get_item(_inspect_item_id)
	if item == null:
		return {}
	var in_mailbox: bool = \
			item.lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX
	var is_equipped: bool = \
			item.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED
	var locked: bool = bool(item.is_locked)
	return {
		"item_id": _inspect_item_id,
		"name": String(_inspect_item_id),
		"rarity": int(item.rarity),
		"provenance": String(item.provenance_text),
		"locked": locked,
		"receipt": bool(item.has_receipt()),
		"stat_modifiers": item.stat_modifiers.duplicate(),  # 原始數據(= #22 Rule 22)
		# Rule 13 affordance set 按 lifecycle 分:
		# (a) IN_INVENTORY —「裝備」;(b) EQUIPPED —「裝備」唔 render
		#(self-equip 無意義 — 唔係靠 error 擋),「現役」標記 +「卸下」;
		# (c) IN_MAILBOX — disabled +「先領取」hint(Rule 12)。
		"equip_visible": not is_equipped,
		"equip_enabled": not in_mailbox and not is_equipped,
		"equip_hint": "先領取先用得" if in_mailbox else "",
		"equipped_badge": is_equipped,
		"unequip_visible": is_equipped,
		"salvage_enabled": (not in_mailbox) and not locked,
		"salvage_hint": "先領取先分解得" if in_mailbox else ("上鎖中 — 解鎖先可以分解" if locked else ""),
		# D1:lock toggle enabled(set_lock 冇 lifecycle check — 有效)+ honest copy
		#(lock 擋 bulk 唔擋 sweep — 文案照直講;pinned,唔好「改善」成全保護)。
		"lock_enabled": true,
		"lock_copy": "鎖定 — 批量分解唔會掂佢;保留期照計" if in_mailbox else "",
	}


## Equip dispatch(Rule 13 (a) — slot = item.slot_affinity;mailbox 件 UI
## disabled,stale tap 漏網由 #17 guard 兜底 L658-659)。
## (Success 嘅 lock nudge + announce — story 013。)
func equip_item(item_id: StringName, slot_override: int = -1) -> Dictionary:
	if not _command_allowed():
		return {"ok": false, "error": "screen_not_open"}
	var item = _inventory.get_item(item_id)
	var slot: int = slot_override if slot_override >= 0 \
			else (int(item.slot_affinity) if item != null else 0)
	var was_locked: bool = item != null and bool(item.is_locked)
	var result: Dictionary = _inventory.equip(item_id, slot)
	if result.get("ok", false):
		_reread_all()
		_show_toast("已裝備 %s" % String(item_id))
		# Rule 13 (a):manual equip 成功 → lock nudge inline 喺 inspect sheet
		# 內(unconditional,已 lock 除外 — #22 Rule 18 同款;sheet 閂咗即棄)。
		if _modal == ModalKind.ITEM_INSPECT and not was_locked:
			_inspect_nudge = {"item_id": item_id, "confirmed": false}
	else:
		_handle_command_error(result)
	return result


## EQUIPPED 件「卸下」(Rule 13 (b))。Silent SFX(cue map — toast/badge 承擔
## 視覺,ARIA announce 承擔 SR);unequip 永不爆 cap(#17 L1125 口徑)。
func unequip_slot(slot: int) -> Dictionary:
	if not _command_allowed():
		return {"ok": false, "error": "screen_not_open"}
	var result: Dictionary = _inventory.unequip(slot)
	if result.get("ok", false):
		_reread_all()
		_announce("已卸下")  # UI Req command-result announce set
	else:
		_handle_command_error(result)
	return result


## Nudge 內 [鎖定] one-tap(Rule 13 (a))— lock + nudge 變「已鎖定」確認態。
func nudge_lock_tap() -> void:
	if _inspect_nudge.is_empty():
		return
	var result: Dictionary = toggle_lock(_inspect_nudge["item_id"], true)
	if result.get("ok", false):
		_inspect_nudge["confirmed"] = true


func get_inspect_nudge() -> Dictionary:
	return _inspect_nudge


## Salvage 入口(兩步 friction 第一步 = #22 Rule 19)。
## Rule 12 零-dispatch invariant:IN_MAILBOX / locked → 唔開 modal,
## confirm path 都到唔到 — #23 對 IN_MAILBOX 件零 salvage() dispatch(binding)。
func request_salvage(item_id: StringName) -> void:
	if not _command_allowed():
		return
	var item = _inventory.get_item(item_id)
	if item == null or bool(item.is_locked):
		return  # locked 入口 disabled — double guard
	if item.lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		return  # Rule 12 binding invariant — disabled 入口係唯一防線(#17 冇 guard)
	_salvage_target = item_id
	_modal = ModalKind.SALVAGE_CONFIRM
	_play_sfx(&"ui_sheet_open")


## Confirm(兩步第二步)。Defence-in-depth:dispatch 前 re-check IN_MAILBOX
## (stale race — confirm 開緊期間件被退回 mailbox 嘅理論窗;invariant 最強讀法)。
## (SALVAGE_CONFIRM view + 兩層一齊閂 + backfill — story 013。)
func confirm_salvage() -> Dictionary:
	if not _command_allowed() or _modal != ModalKind.SALVAGE_CONFIRM:
		return {"ok": false, "error": "no_confirm_context"}
	var target: StringName = _salvage_target
	var item = _inventory.get_item(target)
	if item != null and item.lifecycle_state == EquipmentEnums.ItemLifecycle.IN_MAILBOX:
		_modal = ModalKind.NONE
		_salvage_target = &""
		return {"ok": false, "error": "in_mailbox_zero_dispatch"}  # Rule 12 invariant
	var result: Dictionary = _inventory.salvage(target)
	# Rule 13 (c):confirm 成功 → SALVAGE_CONFIRM + ITEM_INSPECT 一齊閂 → 返
	# list(件已毀,inspect 對住唔存在嘅嘢係 limbo)。
	_modal = ModalKind.NONE
	_salvage_target = &""
	_inspect_item_id = &""
	_inspect_nudge = {}
	if result.get("ok", false):
		_reread_all()
		_play_sfx(&"ui_salvage_execute")
		_show_toast("已分解 %s — +%d 碎片" % [String(target), int(result.get("shards", 0))])
	else:
		_handle_command_error(result)
	return result


## SALVAGE_CONFIRM view(P-15 兩步文法 = #22 Rule 19/22:yield + provenance
## + LEGENDARY signature + equipped warning)。
func get_salvage_confirm_view() -> Dictionary:
	if _modal != ModalKind.SALVAGE_CONFIRM or _salvage_target == &"":
		return {}
	var item = _inventory.get_item(_salvage_target)
	if item == null:
		return {}
	var sig: String = ""
	if item.source_receipt != null and "signature_text" in item.source_receipt:
		sig = String(item.source_receipt.signature_text)
	var view: Dictionary = {
		"item_id": _salvage_target,
		"yield": InvUiFormulas.InventoryScript.salvage_yield(int(item.rarity)),
		"provenance": String(item.provenance_text),
		"rarity": int(item.rarity),
		"signature_text": sig,
		"default_focus": "cancel",
	}
	if item.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED:
		view["warning"] = "現役裝備 — 會自動卸下(如有後備會自動補上)"
	return view


## Lock toggle(D1 — mailbox 件都 enabled;card 第三 zone / inspect 內)。
func toggle_lock(item_id: StringName, locked: bool) -> Dictionary:
	if not _command_allowed():
		return {"ok": false, "error": "screen_not_open"}
	var result: Dictionary = _inventory.set_lock(item_id, locked)
	if result.get("ok", false):
		_reread_all()
		_play_sfx(&"ui_lock_on" if locked else &"ui_lock_off")
	else:
		_handle_command_error(result)
	return result


## Command error handling(= #22 Rule 15 pattern;full error map — story 014)。
func _handle_command_error(result: Dictionary) -> void:
	var err: String = String(result.get("error", ""))
	if err == "deferred_reentrancy":
		call_deferred("_reread_all")  # 唔 toast,下 frame 收割(= #22 EC-23)
		return
	_reread_all()
	_show_toast(_error_toast_text(err))


## Error toast 文案(Rule 14 — 6 codes + deferred_reentrancy 例外;
## #22 map fork 後**必須加 not_in_mailbox entry** — 唔加 = raw code leak)。
func _error_toast_text(err: String) -> String:
	match err:
		"not_found": return "件物品已唔存在"
		"in_mailbox_claim_first": return "先去信箱領取"
		"slot_type_mismatch": return "件裝備唔啱呢個位"
		"slot_empty": return "呢個位係空嘅"
		"locked": return "上鎖中 — 解鎖先可以操作"
		"not_in_mailbox": return "件物品已唔喺信箱(可能已自動分解)"
		_: return "操作失敗(%s)" % err


## ---- bulk sheets(story 011;Rules 15/16 + EC-02/03 + D5) ----

## INVENTORY header「批量分解」入口 → BULK_SELECT(MAKE_ROOM 入口 (a) 同款落腳)。
func open_bulk_select() -> void:
	if not _command_allowed() or _modal != ModalKind.NONE:
		return
	_modal = ModalKind.BULK_SELECT
	_play_sfx(&"ui_sheet_open")


## BULK_SELECT 5 rarity rows — sheet 每次 enter 重行全 5 row preview
## (Rule 15 pin:preview 係 free synchronous read,冇理由用舊快照)。
func get_bulk_select_rows() -> Array:
	var rows: Array = []
	for rarity in 5:
		var preview: Dictionary = _inventory.bulk_salvage_preview(rarity)
		rows.append({
			"rarity": rarity,
			"count": int(preview["count"]),
			"yield": int(preview["yield"]),
			"receipt_count": int(preview["receipt_count"]),
			"grayed": int(preview["count"]) == 0,  # 灰掉唔 disable tap(EC-02)
		})
	return rows


## Rarity row tap — **tap 時再 re-preview 一次**,用 tap-time 數開 CONFIRM
## (Rule 15);仍 0 → inline note(EC-02/03 分流),唔開 modal;
## reverse drift(re-preview > 0)→ 照開 CONFIRM。
## Return:{opened: bool, note: String}。
func bulk_row_tap(rarity: int) -> Dictionary:
	if not _command_allowed() or _modal != ModalKind.BULK_SELECT:
		return {"opened": false, "note": ""}
	var preview: Dictionary = _inventory.bulk_salvage_preview(rarity)
	if int(preview["count"]) == 0:
		# EC-03:owned > 0 但全 locked → locked variant(N = view-model 點算);
		# owned == 0 → EC-02 copy。
		var locked_n: int = _count_locked_in_range(rarity)
		var note: String = "0 件可分解(%d 件已鎖)" % locked_n if locked_n > 0 \
				else "呢個 tier 冇可分解嘅件"
		return {"opened": false, "note": note}
	_bulk_rarity = rarity
	_bulk_preview = preview  # row-tap 快照(EC-01 — modal 唔 live-update)
	_modal = ModalKind.BULK_CONFIRM
	_play_sfx(&"ui_sheet_open")
	return {"opened": true, "note": ""}


## View-model 對該 rarity 嘅 locked count(EC-03 — bulk range = mailbox +
## inventory + equipped;view 層點算,唔係 selection predicate duplicate)。
func _count_locked_in_range(rarity: int) -> int:
	var n: int = 0
	for view: Dictionary in _inventory_view:
		if int(view["rarity"]) == rarity and bool(view["locked"]):
			n += 1
	for view: Dictionary in _mailbox_view:
		if int(view["rarity"]) == rarity and bool(view["locked"]):
			n += 1
	return n


## BULK_CONFIRM view(D5 三層誠實度 + 三段結構 pin — Rule 16)。
## 數字 = row-tap 快照(_bulk_preview);execute 用 #17 當下真值(story 012)。
func get_bulk_confirm_view() -> Dictionary:
	if _modal != ModalKind.BULK_CONFIRM:
		return {}
	var receipt_ids: Array = _bulk_preview.get("receipt_ids", [])
	var receipt_total: int = int(_bulk_preview.get("receipt_count", 0))
	# ① receipt 件逐件列(同毀滅名單同源 — G-IU-1;cap + 「+N more」總數照報)。
	var receipt_lines: Array = []
	for i in mini(receipt_ids.size(), BULK_CONFIRM_RECEIPT_LIST_MAX):
		var item = _inventory.get_item(receipt_ids[i])
		if item != null:
			receipt_lines.append({
				"item_id": receipt_ids[i],
				"name": String(receipt_ids[i]),
				"provenance": String(item.provenance_text),
			})
	var overflow: int = receipt_ids.size() - BULK_CONFIRM_RECEIPT_LIST_MAX
	# ② conditional count breakdown(view-model 點算;有先 render,零中招唔出)。
	var parts: Array = []
	var m_count: int = _count_in_range_unlocked(_mailbox_view, _bulk_rarity)
	var k_count: int = _count_equipped_unlocked(_bulk_rarity)
	if m_count > 0:
		parts.append("信箱 %d 件" % m_count)
	if k_count > 0:
		parts.append("現役 %d 件" % k_count)
	# ③ MAKE_ROOM context warning(claim-target destruction trap 封口)。
	var pending_warning: String = ""
	if _make_room_pending != &"":
		var pending = _inventory.get_item(_make_room_pending)
		if pending != null and int(pending.rarity) == _bulk_rarity \
				and not bool(pending.is_locked):
			pending_warning = "⚠ 包括你想領取嗰件「%s」" % String(_make_room_pending)
	return {
		# fixed header(決策資訊 above-the-fold)。
		"header": {
			"count": int(_bulk_preview.get("count", 0)),
			"yield": int(_bulk_preview.get("yield", 0)),
			"receipt_total_line": "內含 %d 件收據件" % receipt_total if receipt_total > 0 else "",
		},
		# scrollable 中段(三層)。
		"pending_warning": pending_warning,  # ③ 第一行
		"receipt_lines": receipt_lines,      # ①
		"receipt_overflow": "+%d more" % overflow if overflow > 0 else "",
		"receipt_warning": "呢 %d 件帶收據,分解後簽名永久消失" % receipt_total \
				if receipt_total > 0 else "",
		"breakdown_line": "內含" + "、".join(parts) if not parts.is_empty() else "",  # ②
		# fixed footer(cancel + confirm 永遠 on-screen;ENTER 只喺 confirm
		# 獲 focus 先觸發 — UX spec)。
		"default_focus": "cancel",
	}


func _count_in_range_unlocked(views: Array, rarity: int) -> int:
	var n: int = 0
	for view: Dictionary in views:
		if int(view["rarity"]) == rarity and not bool(view["locked"]):
			n += 1
	return n


func _count_equipped_unlocked(rarity: int) -> int:
	var n: int = 0
	for view: Dictionary in _inventory_view:
		if int(view["rarity"]) == rarity and bool(view["equipped"]) \
				and not bool(view["locked"]):
			n += 1
	return n


## Confirm → execute(story 012;Rule 16/17 + EC-01/12)。
## Toast 報 **execute return**(#17 當下真值 — 唔報 row-tap preview 數;
## 兩者可以唔同,EC-01 處理唔係 bug);`ui_salvage_execute` 恰好一響
## (transaction stamp,count-invariant — 唔 per 件);`modal := NONE`
## (連環 bulk 由玩家重開,sheet re-enter 自然攞新 preview)。
func confirm_bulk_salvage() -> Dictionary:
	if not _command_allowed() or _modal != ModalKind.BULK_CONFIRM:
		return {"ok": false, "error": "no_confirm_context"}
	var result: Dictionary = _inventory.bulk_salvage(_bulk_rarity)
	_bulk_rarity = -1
	_bulk_preview = {}
	if _state != ScreenState.OPEN:
		# EC-12 executed 邊(AC-36):dispatch 期間 force-close 落地 — #17
		# single transaction 已成立;presentation 全 skip(零 toast 零 SFX
		# 零 re-read — modal/transients 已由 _enter_closed/_on_gsm 清),
		# 下次 open 收割(open 嘅 sync read 自然 render 新 state)。
		return result
	_modal = ModalKind.NONE
	if result.get("ok", false):
		_reread_all()  # bulk rebuild — list 層 scroll reset 頂(EC-14;005 API)
		_play_sfx(&"ui_salvage_execute")
		# TODO(story 017 G-IU-5):shards 數字換 thousands-separator shared formatter。
		_show_toast("已分解 %d 件 — +%d 碎片" % [
			int(result.get("count", 0)), int(result.get("shards", 0)),
		])
	else:
		_handle_command_error(result)
	return result


## ---- modal dismiss routing(story 011;States return-target 表 + EC-07) ----

## Per-modal dismiss(cancel button / scrim tap / ESC 三者等效 — 一律呢度)。
func cancel_modal() -> void:
	match _modal:
		ModalKind.NONE:
			return
		ModalKind.SALVAGE_CONFIRM:
			_modal = ModalKind.ITEM_INSPECT  # 逐層退(States 表)
			_salvage_target = &""
		ModalKind.BULK_CONFIRM:
			_modal = ModalKind.BULK_SELECT  # 逐層退;re-enter 重行 preview(Rule 15)
			_bulk_rarity = -1
			_bulk_preview = {}
		ModalKind.MAKE_ROOM:
			make_room_dismiss()  # NONE + pending 清空(= 放棄)
			return  # cue 喺 make_room_dismiss 內
		_:
			# ITEM_INSPECT / BULK_SELECT → NONE。
			_modal = ModalKind.NONE
			_inspect_item_id = &""
			_inspect_nudge = {}  # sheet 閂咗 nudge 即棄(Rule 13 (a))
	_play_sfx(&"ui_sheet_close")


## ESC routing(EC-07 大原則 = #22:modal 先,screen 後)。
## Returns true 如果今下已被 modal 食咗。
func handle_escape() -> bool:
	if _modal != ModalKind.NONE:
		cancel_modal()
		return true
	close()
	return false


## ---- toast(= #22 transient pattern;injected clock) ----

func _show_toast(text: String) -> void:
	_toast = {"text": text, "remaining_ms": TimingConfig.ERROR_TOAST_DURATION_MS}
	_announce(text)  # toast = ARIA live region(Rule 14)


func get_toast() -> Dictionary:
	return _toast


func _advance_transients(delta_ms: float) -> void:
	if not _toast.is_empty():
		_toast["remaining_ms"] -= delta_ms
		if _toast["remaining_ms"] <= 0.0:
			_toast = {}


## ARIA announce seam(UI Req;story 015 spy 對象)。
func _announce(text: String) -> void:
	if _platform != null and _platform.has_method("announce_aria"):
		_platform.announce_aria(text)


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
