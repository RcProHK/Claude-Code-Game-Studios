## CharacterScreenCoordinator — #22 Character Screen autoload.
## (story 002 scaffold → story 007 lifecycle FSM → story 008 subscriptions)
##
## Driving GDD: design/gdd/character-screen.md (✅ APPROVED 2026-06-07)
## UX spec:     design/ux/character-screen.md (✅ APPROVED)
## Governing ADRs: ADR-0001 (#22 revision — CharacterScreenLayer 60, PAUSABLE,
## inside BackBufferCopy capture 0/10/50/60 so the P-07 preview shake visibly
## moves this screen), ADR-0006 C6 (connect_for_initial_state for #11 + GSM
## only; #26 is plain connect — cfis is NOT exposed by AvatarRenderer, Pass 1
## phantom fix), ADR-0008 (G-CS-8 tail append), ADR-0003 (settings.* +
## charscreen.* keys; close-path critical flush).
##
## Pure overlay review surface (Rule 2): owns ONLY UI state (screen FSM ×
## active_panel × modal × offline banner). Game data is never owned here.
##
## CLOSED invariant (Rule 8): zero active upstream subscriptions while CLOSED.
## Subscribe on open(); disconnect happens AT CLOSED entry — deliberately NOT
## earlier: CLOSING must still hear GSM (upgrade to FORCE_CLOSING / SUSPENDED
## snap — States table rationale; do not "optimise" the disconnect earlier).
##
## Ghost-callv guard (EC-05 / godot R1): GSM's cfis sentinel is a deferred
## next-frame CONNECT_ONE_SHOT lambda holding the callable — disconnect()
## cannot cancel a pending lambda, so the handler can be callv'd AFTER close.
## Every handler therefore no-op guards on screen state, INCLUDING CLOSED.
##
## Timing discipline (GDD AC header, binding): the entire screen runs on ONE
## injected clock. Production _process(delta) feeds advance(delta * 1000.0);
## tests call advance(delta_ms) directly — same code path. No engine Tween /
## SceneTreeTimer for any state-bearing timing.
##
## SFX (CD C1): ui_charscreen_open / ui_charscreen_close fire ONLY on
## player-initiated paths. Force-close + SUSPENDED snap are hard-silent.
extends Node

## ADR-0001 #22 revision pinned layer number.
const CHARACTER_SCREEN_LAYER: int = 60

const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")
const StatTween := preload("res://src/ui/character_screen/stat_tween.gd")
const Formulas := preload("res://src/ui/character_screen/char_screen_formulas.gd")
const StatWatermark := preload("res://src/ui/character_screen/stat_watermark.gd")

## 7 stat rows (#11 StatId values — lowercase StringName,shipped ground truth).
const STAT_IDS: Array[StringName] = [
	&"str", &"dex", &"vit", &"max_hp", &"attack_power", &"move_speed", &"crit_chance",
]
## #11 StatSource ordinals (stat_system.gd enum — EQUIPMENT 先 tween,Rule 10).
const STAT_SOURCE_EQUIPMENT: int = 2

## Screen FSM (GDD States and Transitions — 5 states).
enum ScreenState {
	CLOSED,         ## boot default / close 完成 — zero-subscription invariant
	OPENING,        ## 入場 animation;data 已喺第一 frame sync read 齊 (Rule 7)
	OPEN,           ## 互動中 (orthogonal 軸: active_panel × modal)
	CLOSING,        ## player-initiated 出場 animation;GSM 照聽
	FORCE_CLOSING,  ## GSM 轉入非 permitted state — ≤FORCE_CLOSE_MAX_MS fast path
}

## Tab 軸 (UX spec Z3) — open() 一律 clean-slate reset 到 STATS (Rule 5).
## (名叫 PanelKind 避開 Godot native `Panel` Control class 解析衝突.)
enum PanelKind { STATS, LOADOUT, SETTINGS }

## Modal 軸 (UX spec Z5) — open() reset NONE;force-close 一律 cancel (EC-01).
enum ModalKind { NONE, SALVAGE_CONFIRM, ITEM_INSPECT, SLOT_PICKER }

## ---- UI state (the ONLY state #22 owns) ----
var _state: int = ScreenState.CLOSED
var _active_panel: int = PanelKind.STATS
var _modal: int = ModalKind.NONE
var _offline_banner: bool = false
var _anim_elapsed_ms: float = 0.0

## ---- binding state (story 009;render-model,唔係 game data) ----
## stat_id → StatTween(per-row F1 instance;4-row 並行 = lockstep settle)。
var _tweens: Dictionary = {}
## stat_id → watermark Dictionary({} = persist 不可用,零 render)。
var _watermarks: Dictionary = {}
var _watermark_store = null  # StatWatermark instance(open 時 lazily 建)
## #26 5-getter snapshot(open + avatar_visual_updated 時 refresh — EC-16)。
var _avatar_view: Dictionary = {}
## milestone hint 只喺 open + signal 時 evaluate(EC-16 — 唔追 mid-session flip)。
var _milestone_hint: bool = false
## Rule 11 breathing freeze policy(settings.reduce_camera_motion;AC-53)。
var _reduce_motion: bool = false
## injectable date provider(device local — EC-15;tests 注入固定日期)。
var _date_provider: Callable = func() -> String: return Time.get_date_string_from_system()

## ---- loadout / command view state (stories 014-017;render-model only) ----
## slot(int) → card {item_id, name, rarity, provenance, locked} 或 {}(empty slot)。
var _loadout_view: Dictionary = {}
var _aggregate: Dictionary = {"raw": 0.0, "effective": 0.0}
var _forge_shards: int = 0
## slot → {item_id, remaining_ms, confirmed}(Rule 18 nudge;per-slot 並存,overlay)。
var _nudges: Dictionary = {}
## slot → {text, remaining_ms}(EC-13a backfill ledger note,同 nudge duration)。
var _backfill_notes: Dictionary = {}
## {text, remaining_ms} — 同屏最多 1 條(新取代舊;UX spec 並發表)。
var _toast: Dictionary = {}
## SLOT_PICKER state {slot, item_ids}(F3 sorted)— modal==SLOT_PICKER 時有效。
var _picker: Dictionary = {}
## ITEM_INSPECT / SALVAGE_CONFIRM 對象。
var _inspect_item_id: StringName = &""
var _salvage_target: StringName = &""

## ---- settings panel state (story 018;F2 canonical int pct) ----
var _slider_pct: int = 100           ## P-07 motion(UI source of truth)
var _volume_pct: int = 100           ## Rule 33 MASTER volume
## per-frame coalesce buffers(-1 = 無 pending;advance 每 tick 最多 apply 一次)。
var _pending_motion_pct: int = -1
var _pending_volume_pct: int = -1
var _motion_dragging: bool = false
## key → {value, remaining_ms}(Rule 27 debounce;close path critical flush)。
var _persist_pending: Dictionary = {}
## persist-fail banner(Private Mode — Rule 27;force-close 時 suppress)。
var _persist_fail_banner: bool = false

## ---- DI seams (untyped — GDScript DI seam convention; tests inject mocks) ----
var _gsm = null
var _stat_system = null
var _inventory = null
var _avatar = null
var _persistence = null
var _screen_effects = null
var _camera = null
var _audio = null
var _platform = null
## #23 G-IU-4 glue seam(default = /root/InventoryUICoordinator;唔 subscribe
## 唔讀對方 state — one-shot deferred call only)。
var _inventory_ui = null

## CanvasLayer 60 (ADR-0001 #22 revision) — owned, pre-warmed hidden.
var _layer: CanvasLayer = null


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CharacterScreenLayer"
	_layer.layer = CHARACTER_SCREEN_LAYER
	_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_layer.visible = false
	add_child(_layer)
	_resolve_default_seams()
	# CLOSED at boot: zero subscriptions (Rule 8) + no idle processing.
	set_process(false)


## Injected-clock bridge: production frames and test steppers share advance().
func _process(delta: float) -> void:
	advance(delta * 1000.0)


## Single timing entry point — all six timing knobs advance through here.
func advance(delta_ms: float) -> void:
	match _state:
		ScreenState.OPENING:
			_advance_tweens(delta_ms)
			_advance_transients(delta_ms)
			_advance_settings(delta_ms)
			_anim_elapsed_ms += delta_ms
			if _anim_elapsed_ms >= TimingConfig.OPEN_ANIM_MS:
				_state = ScreenState.OPEN
				_anim_elapsed_ms = 0.0
		ScreenState.OPEN:
			_advance_tweens(delta_ms)
			_advance_transients(delta_ms)
			_advance_settings(delta_ms)
			_advance_aria(delta_ms)
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


## Tick 全部 stat tween;settle-frame coalesce(story 019):同 frame N row
## settle = `ui_equip_settle` 恰好 1 響 + Rule 32d coalesced stat announce
## (只列有變 row,「stat from→to」;retarget merge 共一響容許)。
func _advance_tweens(delta_ms: float) -> int:
	var settled: int = 0
	var announce_parts: Array = []
	for id in _tweens:
		var tween = _tweens[id]
		if tween.advance(delta_ms):
			settled += 1
			var fmt: Callable = Formulas.formatter_for(id)
			if not is_nan(tween.announce_from):
				announce_parts.append("%s %s→%s" % [
					String(id), fmt.call(tween.announce_from), fmt.call(tween.target()),
				])
				tween.announce_from = NAN
	if settled > 0:
		_play_sfx(&"ui_equip_settle")  # settle-frame coalesce — 恰好 1 響(audio R2)
		if not announce_parts.is_empty():
			_announce(",".join(announce_parts))  # Rule 32d
	return settled


## ---- Rule 1 contract surface (shell 接線點;double guard) ----

## Pure check — shell entry-affordance visibility. true ⇔ GSM ∈ {IDLE, DISCONNECTED}.
func can_open() -> bool:
	if _gsm == null:
		return false
	var s: int = _gsm.get_current_state()
	return s == GSMScript.GameState.IDLE or s == GSMScript.GameState.DISCONNECTED


## Opens the screen (player-initiated). Returns true on success.
## Double guard (Rule 1) + clean-slate reset (Rule 5) + subscribe (Rule 8) +
## first-frame sync read hook (Rule 7 — story 009 內容).
func open() -> bool:
	if _state != ScreenState.CLOSED:
		return false  # CLOSING re-tap = ignore;OPEN/OPENING no-op (Rule 5)
	if not can_open():
		return false
	_active_panel = PanelKind.STATS
	_modal = ModalKind.NONE
	_offline_banner = _is_disconnected()
	_anim_elapsed_ms = 0.0
	_state = ScreenState.OPENING
	_layer.visible = true
	set_process(true)
	_sync_read_all()     # Rule 7 — 第一 frame sync read 齊 (story 009 實體)
	_subscribe_all()     # Rule 8 — story 008
	_play_sfx(&"ui_charscreen_open")  # player-initiated only (CD C1)
	return true


## Player-initiated close → CLOSING (出場 animation;GSM 照聽).
func close() -> void:
	if _state != ScreenState.OPEN and _state != ScreenState.OPENING:
		return
	_state = ScreenState.CLOSING
	_anim_elapsed_ms = 0.0
	_play_sfx(&"ui_charscreen_close")  # player-initiated only (CD C1)


## #23 G-IU-4 — LOADOUT panel header「查看全部 →」link handler(MVP glue
## locus,#23 GDD Rules 1-2)。normal close 後**同 gesture** call_deferred
## 開 #23(唔等 CLOSED — CLOSING×OPENING crossfade 接受,layer 61>60 冚住,
## EC-11)。「唔互相依賴」收窄為「唔 subscribe、唔讀對方 state」— one-shot
## deferred call + has_method guard;#24 shell 落地後遷移(Q-IU1)。
## 雙 cue 政策:#22 close 響 + #23 open 響 back-to-back = sequential 切換
## 嘅誠實聲(#23 GDD Rule 1)。GSM race → #23 自己 double guard 拒(EC-11)。
func loadout_view_all_tap() -> void:
	if _state != ScreenState.OPEN or _active_panel != PanelKind.LOADOUT:
		return
	close()
	if _inventory_ui != null and _inventory_ui.has_method("open"):
		_inventory_ui.call_deferred("open")


## ---- GSM lifecycle handler (story 007;plain method — no .bind()) ----
## Active 喺 OPENING/OPEN/CLOSING/FORCE_CLOSING;CLOSED = no-op (ghost callv).
func _on_gsm_state_changed(_from_state, to_state, _payload) -> void:
	if _state == ScreenState.CLOSED:
		return  # ghost sentinel callv after close (EC-05) — hard no-op
	var to: int = int(to_state)
	# SUSPENDED → instant snap CLOSED,無 animation、零 SFX (Rule 3;
	# emit-path contract = G-CS-10;modal 一律 cancel).
	if to == GSMScript.GameState.SUSPENDED:
		_modal = ModalKind.NONE
		_enter_closed()
		return
	var permitted: bool = (
		to == GSMScript.GameState.IDLE or to == GSMScript.GameState.DISCONNECTED
	)
	if permitted:
		# IDLE↔DISCONNECTED 互轉 (Rule 4):唔 close,只 toggle banner;
		# modal 唔受影響 (EC-06)。
		_offline_banner = (to == GSMScript.GameState.DISCONNECTED)
		return
	# ∉ permitted → force-close。Modal 一律 cancel — SALVAGE_CONFIRM 永不被
	# system event confirm (EC-01);pending command input 由 state guard 封
	# (EC-04 ii — command 入口要求 OPEN)。零 SFX (CD C1)。
	_modal = ModalKind.NONE
	if _state == ScreenState.OPENING:
		_enter_closed()  # OPENING abort 直接去 CLOSED,skip OPEN (States table)
		return
	if _state == ScreenState.FORCE_CLOSING:
		return  # 已經喺 fast path
	_state = ScreenState.FORCE_CLOSING  # OPEN / CLOSING upgrade 同款
	_anim_elapsed_ms = 0.0


## ---- subscriptions (story 008;Rule 8) ----

func _subscribe_all() -> void:
	# GSM — connect_for_initial_state ONLY (ADR-0006 C6;deferred next-frame
	# sentinel)。冇 plain-connect fallback — check_attention_subscription lint
	# 禁(2026-06-08 main-RED hotfix:fallback 係 dead code,真 GSM + 全部
	# mock 都實裝 cfis;#22 epic 起 main CI 一直 red 未發現)。
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)
	# #11 — connect_for_initial_state ONLY (sync burst ×7 then connect;5-arg
	# layout)。冇 plain-connect fallback(check_stat_changed_connect lint 禁 —
	# 同 GSM fallback 一齊剷,2026-06-08 main-RED hotfix)。
	if _stat_system != null and _stat_system.has_method("connect_for_initial_state"):
		_stat_system.connect_for_initial_state(_on_stat_changed)
	# #26 — plain connect (cfis 對 #26 係 phantom — Pass 1 fix;initial avatar
	# state 由 Rule 7 sync read cover)。has_signal guard:shipped avatar stub
	# 未有 signal(#26 epic 未實作)— signal 落地後自動接上。
	if _avatar != null and _avatar.has_signal("avatar_visual_updated"):
		_avatar.avatar_visual_updated.connect(_on_avatar_visual_updated)


## Disconnect 喺 CLOSED entry 先做(CLOSING 仍要聽 GSM — rationale 見 header)。
func _disconnect_all() -> void:
	if _gsm != null and _gsm.has_signal("state_changed") \
			and _gsm.state_changed.is_connected(_on_gsm_state_changed):
		_gsm.state_changed.disconnect(_on_gsm_state_changed)
	if _stat_system != null and _stat_system.has_signal("stat_changed") \
			and _stat_system.stat_changed.is_connected(_on_stat_changed):
		_stat_system.stat_changed.disconnect(_on_stat_changed)
	if _avatar != null and _avatar.has_signal("avatar_visual_updated") \
			and _avatar.avatar_visual_updated.is_connected(_on_avatar_visual_updated):
		_avatar.avatar_visual_updated.disconnect(_on_avatar_visual_updated)


## ---- data handlers (story 009 fleshes;guards 屬 007/008) ----

## #11 stat_changed 5-arg layout (stat_id, old, new, source, _meta).
## Plain method — StatSystem cfis unconditionally rejects bound callables.
## Rule 10:EQUIPMENT → tween + arrow;非 EQUIPMENT(reconciliation /
## INITIAL_STATE burst / VOLUME_TICK)→ snap,無 tween 無 arrow —
## mid-tween 收非 EQUIPMENT 一樣 kill+snap+清 arrow(F1 qualifier,sd B-4)。
func _on_stat_changed(stat_id, _old_value, new_value, source, _meta) -> void:
	if _state != ScreenState.OPENING and _state != ScreenState.OPEN:
		return  # EC-05 no-op guard (CLOSING/FORCE_CLOSING/CLOSED ghost)
	var id: StringName = stat_id
	if not _tweens.has(id):
		return
	var tween = _tweens[id]
	if int(source) == STAT_SOURCE_EQUIPMENT:
		tween.retarget(float(new_value))
	else:
		tween.snap(float(new_value))  # 補數唔演成即場升級(Pillar 1)


## #26 plain-connect handler — refresh 5-getter view(idempotent,EC-02);
## milestone hint 喺呢度(同 open)先 evaluate(EC-16)。
## Significant change(posture swap / tier transition)→ coalesced ARIA
## (Rule 12;EC-29:window 內多次 → 最後一條為準,唔 queue)。
func _on_avatar_visual_updated(_visual_state) -> void:
	if _state != ScreenState.OPENING and _state != ScreenState.OPEN:
		return  # EC-05 no-op guard
	var prev_posture = _avatar_view.get("class_posture", null)
	var prev_tier = _avatar_view.get("evolution_tier", null)
	_refresh_avatar_view()
	var posture = _avatar_view.get("class_posture", &"")
	var tier = _avatar_view.get("evolution_tier", 0)
	if prev_posture != null and (posture != prev_posture or tier != prev_tier):
		_announce_coalesced("Avatar 變為 %s T%d" % [String(posture), int(tier)])


## Rule 7 — open 第一 frame synchronous read 齊:7 stats(tween reset +
## watermark ensure)+ avatar 5 getters + reduce-motion 現值。冇 loading state。
## (Loadout / aggregate / shards reads — story 014 接入呢度。)
func _sync_read_all() -> void:
	# settings 現值(Rule 28 — consumer 冇 getter,讀 #3;AC-53 嘅 persisted 翼)
	if _persistence != null and _persistence.has_method("read"):
		var rm = _persistence.read("settings.reduce_camera_motion")
		_reduce_motion = bool(rm) if rm != null else false
		# P-07 現值:F2 quantize 顯示(EC-25:0.999 →「100%」;**唔即時 rewrite**
		# — write 只喺 user settle,避 open-time write storm 撞 ADR-0003 syncfs)
		var mi = _persistence.read("settings.motion_intensity")
		_slider_pct = Formulas.quantize(mi if mi != null else 1.0)["pct"]
	# MASTER volume 現值(Rule 33 — #4 配對 getter;persistence #4 own)
	if _audio != null and _audio.has_method("get_bus_volume_linear"):
		_volume_pct = Formulas.quantize(_audio.get_bus_volume_linear(0))["pct"]  # Bus.MASTER=0
	# watermark store(#3 seam;persist-fail → ensure 回 {})
	_watermark_store = StatWatermark.new(_persistence)
	var date_str: String = _date_provider.call()
	# 7 stat rows:reset tween + watermark write-once
	if _stat_system != null and _stat_system.has_method("get_stat"):
		for id in STAT_IDS:
			var v: float = float(_stat_system.get_stat(id))
			if not _tweens.has(id):
				_tweens[id] = StatTween.new(Formulas.formatter_for(id))
			_tweens[id].reset(v)
			_watermarks[id] = _watermark_store.ensure(id, v, date_str)
	_reread_loadout()  # AC-20:loadout + aggregate + shards 同 frame 讀齊
	_refresh_avatar_view()


func _refresh_avatar_view() -> void:
	if _avatar == null:
		return
	var view: Dictionary = {}
	if _avatar.has_method("get_visual_state"):
		view["visual_state"] = _avatar.get_visual_state()
	if _avatar.has_method("get_class_posture"):
		view["class_posture"] = _avatar.get_class_posture()
	if _avatar.has_method("get_evolution_tier"):
		view["evolution_tier"] = _avatar.get_evolution_tier()
	if _avatar.has_method("get_animation_state"):
		view["animation_state"] = _avatar.get_animation_state()
	if _avatar.has_method("is_ready_for_milestone_check"):
		_milestone_hint = bool(_avatar.is_ready_for_milestone_check())
	_avatar_view = view


## ---- internals ----

func _enter_closed() -> void:
	# Rule 27/EC-27:任何 close path 離開前 flush pending settings write
	# (critical flush;screen 閂緊 → persist-fail banner suppress)。
	_flush_pending_persist(true)
	_state = ScreenState.CLOSED
	_anim_elapsed_ms = 0.0
	_layer.visible = false
	set_process(false)
	# Transients 全 drop(EC-04 i:pending toast drop;modal targets 清 —
	# force-close-interrupted modal 永不還魂,Rule 5 clean-slate 嘅另一半)。
	_toast = {}
	_nudges = {}
	_backfill_notes = {}
	_picker = {}
	_inspect_item_id = &""
	_salvage_target = &""
	_disconnect_all()  # CLOSED invariant (Rule 8) — AC-15


func _play_sfx(event_id: StringName) -> void:
	if _audio != null and _audio.has_method("play_sfx"):
		_audio.play_sfx(event_id)


## ---- tab 軸 (Rule 23 visibility re-read;story 009) ----

## Tab 切換 — 切到邊個 panel 就 re-read 對應 data source(切返 = re-read)。
## STATS 切返:snap 到當前 true 值 + kill 舊 tween(EC-11/AC-24 — resume 一條
## 基於舊 read 嘅 tween 可能 tween 向 stale target)。
func set_active_panel(panel: int) -> void:
	if _state != ScreenState.OPEN:
		return
	_active_panel = panel
	match panel:
		PanelKind.STATS:
			if _stat_system != null and _stat_system.has_method("get_stat"):
				for id in STAT_IDS:
					if _tweens.has(id):
						_tweens[id].snap(float(_stat_system.get_stat(id)))
		PanelKind.LOADOUT:
			_reread_loadout()  # story 014 實體
		PanelKind.SETTINGS:
			pass  # story 018:settings 現值 re-read


## Loadout / aggregate / shards re-read(Rule 13/23;每次 mutation 後同 frame call)。
func _reread_loadout() -> void:
	if _inventory == null:
		return
	if _inventory.has_method("get_loadout"):
		var lo: Dictionary = _inventory.get_loadout()
		_loadout_view.clear()
		for slot in lo:
			var iid: StringName = lo[slot]
			if iid == &"" or not _inventory.has_method("get_item"):
				_loadout_view[slot] = {}
				continue
			var item = _inventory.get_item(iid)
			if item == null:
				_loadout_view[slot] = {}
				continue
			_loadout_view[slot] = {
				"item_id": iid,
				"name": String(iid),  # display 名隨 asset/UI build;ledger 用 id 誠實
				"rarity": int(item.rarity),
				"provenance": String(item.provenance_text),
				"locked": bool(item.is_locked),
			}
	if _inventory.has_method("get_aggregate_raw_and_effective"):
		_aggregate = _inventory.get_aggregate_raw_and_effective()
	if _inventory.has_method("get_forge_shards"):
		_forge_shards = _inventory.get_forge_shards()


## ---- #17 command surface (story 015;Rule 14/15 + EC-04/17/23) ----

## Command 入口 guard:只喺 OPEN 接受(EC-04 ii — FORCE_CLOSING/CLOSING input ignore)。
func _command_allowed() -> bool:
	return _state == ScreenState.OPEN


## Picker row tap / 程式 equip(Rule 14:synchronous return → 同 frame re-read)。
func equip_item(item_id: StringName, slot: int) -> Dictionary:
	if not _command_allowed():
		return {"ok": false, "error": "screen_not_open"}
	var result: Dictionary = _inventory.equip(item_id, slot)
	if result.get("ok", false):
		_reread_loadout()
		_maybe_nudge(slot, item_id)  # Rule 18 unconditional(未 lock 先彈)
		_announce(_command_announce_text("equip", item_id))
	else:
		_handle_command_error(result)
	return result


func unequip_slot(slot: int) -> Dictionary:
	if not _command_allowed():
		return {"ok": false, "error": "screen_not_open"}
	var result: Dictionary = _inventory.unequip(slot)
	if result.get("ok", false):
		_reread_loadout()
	else:
		_handle_command_error(result)
	return result


## Lock toggle(card 第三 zone / nudge [鎖定] inline)。
func toggle_lock(item_id: StringName, locked: bool) -> Dictionary:
	if not _command_allowed():
		return {"ok": false, "error": "screen_not_open"}
	var result: Dictionary = _inventory.set_lock(item_id, locked)
	if result.get("ok", false):
		_reread_loadout()
		_play_sfx(&"ui_lock_on" if locked else &"ui_lock_off")
	else:
		_handle_command_error(result)
	return result


## Nudge 內 [鎖定] one-tap(Rule 18a)— lock + nudge 變「已鎖定」確認態。
func nudge_lock_tap(slot: int) -> void:
	if not _nudges.has(slot):
		return
	var nudge: Dictionary = _nudges[slot]
	var result: Dictionary = toggle_lock(nudge["item_id"], true)
	if result.get("ok", false):
		nudge["confirmed"] = true
		nudge["remaining_ms"] = TimingConfig.LOCK_NUDGE_DURATION_MS  # 確認態重新計時


## ---- modal flows (story 016;Rule 19/20/22 + EC-07/18) ----

## Entry map(Rule 22):occupied card 主體 tap → ITEM_INSPECT。
func open_inspect(item_id: StringName) -> void:
	if not _command_allowed():
		return
	_inspect_item_id = item_id
	_modal = ModalKind.ITEM_INSPECT
	_play_sfx(&"ui_sheet_open")


## Inspect view data(provenance 全文 + LEGENDARY signature + salvage 入口狀態)。
func get_inspect_view() -> Dictionary:
	if _inspect_item_id == &"" or _inventory == null:
		return {}
	var item = _inventory.get_item(_inspect_item_id)
	if item == null:
		return {}
	var sig: String = ""
	if item.source_receipt != null and "signature_text" in item.source_receipt:
		sig = String(item.source_receipt.signature_text)
	return {
		"item_id": _inspect_item_id,
		"name": String(_inspect_item_id),
		"rarity": int(item.rarity),
		"provenance": String(item.provenance_text),
		"signature_text": sig,
		"locked": bool(item.is_locked),
		"salvage_enabled": not bool(item.is_locked),  # Rule 20 — locked 灰掉
		"stat_modifiers": item.stat_modifiers.duplicate(),  # 原始數據;禁 predicted final
	}


## Salvage 入口(inspect 內;Rule 19 兩步 friction 第一步)。Locked → 唔開 modal。
func request_salvage(item_id: StringName) -> void:
	if not _command_allowed():
		return
	var item = _inventory.get_item(item_id)
	if item == null or bool(item.is_locked):
		return  # locked 入口 disabled(EC-22)— UI 唔應該叫到嚟,double guard
	_salvage_target = item_id
	_modal = ModalKind.SALVAGE_CONFIRM
	_play_sfx(&"ui_sheet_open")


## SALVAGE_CONFIRM modal view(yield preview + warning + signature)。
func get_salvage_confirm_view() -> Dictionary:
	if _salvage_target == &"" or _inventory == null:
		return {}
	var item = _inventory.get_item(_salvage_target)
	if item == null:
		return {}
	var equipped: bool = item.lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED
	var sig: String = ""
	if item.source_receipt != null and "signature_text" in item.source_receipt:
		sig = String(item.source_receipt.signature_text)
	var view: Dictionary = {
		"item_id": _salvage_target,
		"yield": _inventory.salvage_yield(item.rarity) if _inventory.has_method("salvage_yield") else 0,
		"provenance": String(item.provenance_text),
		"rarity": int(item.rarity),
		"signature_text": sig,
	}
	if equipped:
		view["warning"] = "現役裝備 — 會自動卸下(如有後備會自動補上)"
	return view


## Confirm(兩步 friction 第二步;EC-18 stale item / EC-13 backfill 兩 outcome)。
func confirm_salvage() -> Dictionary:
	if not _command_allowed() or _modal != ModalKind.SALVAGE_CONFIRM:
		return {"ok": false, "error": "no_confirm_context"}
	var target: StringName = _salvage_target
	var loadout_before: Dictionary = {}
	for slot in _loadout_view:
		loadout_before[slot] = _loadout_view[slot].get("item_id", &"")
	var result: Dictionary = _inventory.salvage(target)
	_modal = ModalKind.NONE
	_salvage_target = &""
	if result.get("ok", false):
		_reread_loadout()  # shards snap + slot 變化(#17 sync batch — L258)
		_detect_backfill(loadout_before, target)
		_play_sfx(&"ui_salvage_execute")
		_announce("已分解 %s — +%d 碎片" % [String(target), int(result.get("shards", 0))])
	elif String(result.get("error", "")) == "not_found":
		# EC-18:confirm 時 item 已死 → modal 已閂 + toast + 全 panel re-read;
		# #22 零 shards 計算(credit 係消滅嗰下 #17 已做)。
		_reread_loadout()
		_show_toast("件物品已唔存在")
	else:
		_handle_command_error(result)
	return result


## EC-13 outcome (a):salvage 後 slot 由舊 item 變咗另一件(backfill)→ ledger note。
func _detect_backfill(loadout_before: Dictionary, salvaged: StringName) -> void:
	for slot in _loadout_view:
		var before: StringName = loadout_before.get(slot, &"")
		var after: StringName = _loadout_view[slot].get("item_id", &"")
		if before == salvaged and after != &"" and after != before:
			_backfill_notes[slot] = {
				"text": "自動補上 %s" % String(after),
				"remaining_ms": TimingConfig.LOCK_NUDGE_DURATION_MS,
			}


## Modal dismiss(ESC 第一下 / scrim tap / cancel button — 一律 = cancel,EC-07)。
func cancel_modal() -> void:
	if _modal == ModalKind.NONE:
		return
	_modal = ModalKind.NONE
	_salvage_target = &""
	_inspect_item_id = &""
	_picker = {}
	_play_sfx(&"ui_sheet_close")


## ESC routing(EC-07):modal 先,screen 後。Returns true 如果今下已被 modal 食咗。
func handle_escape() -> bool:
	if _modal != ModalKind.NONE:
		cancel_modal()
		return true
	close()
	return false


## ---- picker (story 017;Rule 17 + EC-19/20) ----

## Picker 入口:empty slot tap / occupied「更換」button(Rule 22 entry map)。
## 0 件照開(EC-20 — empty sheet 教玩家 inventory 狀態)。
func open_picker(slot: int) -> void:
	if not _command_allowed():
		return
	_picker = {"slot": slot, "item_ids": _build_picker_list(slot)}
	_modal = ModalKind.SLOT_PICKER
	_play_sfx(&"ui_sheet_open")


func _build_picker_list(slot: int) -> Array:
	if _inventory == null or not _inventory.has_method("get_items_for_slot"):
		return []
	var ids: Array = Array(_inventory.get_items_for_slot(slot))
	var items: Array = []
	for iid in ids:
		var item = _inventory.get_item(iid)
		if item != null:
			items.append(item)
	items.sort_custom(Formulas.picker_before)  # F3:rarity desc → 新先 → id asc
	return items.map(func(i) -> StringName: return i.item_id)


## Picker row tap = equip(Rule 17)。Stale → toast + 原地 rebuild(EC-19,唔 close)。
func picker_tap(item_id: StringName) -> Dictionary:
	if _modal != ModalKind.SLOT_PICKER:
		return {"ok": false, "error": "no_picker"}
	var slot: int = _picker.get("slot", 0)
	var result: Dictionary = equip_item(item_id, slot)
	if result.get("ok", false):
		_modal = ModalKind.NONE
		_picker = {}
	elif String(result.get("error", "")) == "not_found":
		_picker["item_ids"] = _build_picker_list(slot)  # 原地 rebuild
	return result


func get_picker_view() -> Dictionary:
	return _picker


## ---- command error handling (Rule 15 + EC-23) ----

func _handle_command_error(result: Dictionary) -> void:
	var err: String = String(result.get("error", ""))
	if err == "deferred_reentrancy":
		# EC-23:#17 下一 frame 自動 replay — 唔 toast,下 frame re-read 收割。
		call_deferred("_reread_loadout")
		return
	_reread_loadout()
	_show_toast(_error_toast_text(err))
	_announce(_error_toast_text(err))


func _error_toast_text(err: String) -> String:
	match err:
		"not_found": return "件物品已唔存在"
		"slot_type_mismatch": return "件裝備唔啱呢個位"
		"in_mailbox_claim_first": return "先去信箱領取"
		"slot_empty": return "呢個位係空嘅"
		"locked": return "上鎖中 — 解鎖先可以操作"
		_: return "操作失敗(%s)" % err


func _show_toast(text: String) -> void:
	_toast = {"text": text, "remaining_ms": TimingConfig.ERROR_TOAST_DURATION_MS}


## Rule 18 unconditional nudge(equip 成功 + 未 lock)。Overlay,per-slot 並存。
func _maybe_nudge(slot: int, item_id: StringName) -> void:
	var item = _inventory.get_item(item_id) if _inventory != null else null
	if item == null or bool(item.is_locked):
		return  # 已 lock → 無 nudge
	_nudges[slot] = {
		"item_id": item_id,
		"remaining_ms": TimingConfig.LOCK_NUDGE_DURATION_MS,
		"confirmed": false,
	}


## ARIA announce seam(Rule 32 — story 019 spy 對象;quiet ledger 聲線)。
func _announce(text: String) -> void:
	if _platform != null and _platform.has_method("announce_aria"):
		_platform.announce_aria(text)


## Coalesced ARIA channel(EC-28/29 — avatar 變化 + settings 值):window 內
## 多次 → 最後一條為準,window 完先讀一句(ARIA_COALESCE_WINDOW_MS)。
var _aria_pending: Dictionary = {}


func _announce_coalesced(text: String) -> void:
	_aria_pending = {"text": text, "remaining_ms": TimingConfig.ARIA_COALESCE_WINDOW_MS}


func _advance_aria(delta_ms: float) -> void:
	if _aria_pending.is_empty():
		return
	_aria_pending["remaining_ms"] -= delta_ms
	if _aria_pending["remaining_ms"] <= 0.0:
		_announce(_aria_pending["text"])
		_aria_pending = {}


func _command_announce_text(kind: String, item_id: StringName) -> String:
	match kind:
		"equip": return "已裝備 %s" % String(item_id)
		_: return String(item_id)


## ---- settings panel (story 018;Rules 25-30/33 + EC-24..28) ----

## P-07 slider drag tick(apply-on-change;per-frame coalesce — locus #22-side)。
func slider_drag(v_raw: Variant) -> void:
	if _state != ScreenState.OPEN:
		return
	_motion_dragging = true
	_pending_motion_pct = Formulas.quantize(v_raw)["pct"]


## P-07 slider release(settle):final apply + preview(uniform path,0% 照發
## — #6 short-circuit 負責零 motion;**preview 路徑零 play_sfx**)+ persist debounce。
func slider_release() -> void:
	if _state != ScreenState.OPEN:
		return
	_motion_dragging = false
	if _pending_motion_pct >= 0:
		_apply_motion_pct(_pending_motion_pct)
		_pending_motion_pct = -1
	if _screen_effects != null and _screen_effects.has_method("preview_hit_heavy"):
		_screen_effects.preview_hit_heavy()
	_arm_persist("settings.motion_intensity", float(_slider_pct) / 100.0)
	_announce_coalesced("%d%%" % _slider_pct)


## P-07 keyboard ±10pct(EC-28 clamp 唔 wrap;即時 settle 語意)。
func slider_keyboard_step(direction: int) -> void:
	if _state != ScreenState.OPEN:
		return
	var new_pct: int = Formulas.keyboard_step(_slider_pct, direction)
	if new_pct == _slider_pct:
		_announce_coalesced("%d%%" % _slider_pct)  # clamp no-op 照 announce 一次(coalesce 喺 ARIA 層)
		return
	_apply_motion_pct(new_pct)
	_arm_persist("settings.motion_intensity", float(_slider_pct) / 100.0)
	_announce_coalesced("%d%%" % _slider_pct)


func _apply_motion_pct(pct: int) -> void:
	_slider_pct = pct
	if _screen_effects != null and _screen_effects.has_method("set_motion_intensity"):
		_screen_effects.set_motion_intensity(float(pct) / 100.0)


## P-08 toggle flip — 一掣兩 consumer(#7 camera + Rule 11 avatar freeze)+ persist。
func toggle_reduce_motion(enabled: bool) -> void:
	if _state != ScreenState.OPEN:
		return
	set_reduce_motion(enabled)  # avatar freeze 同 frame 生效(AC-53)
	if _camera != null and _camera.has_method("set_motion_reduction"):
		_camera.set_motion_reduction(enabled)
	_arm_persist("settings.reduce_camera_motion", enabled)
	_play_sfx(&"ui_toggle_flip")


## MASTER volume slider(Rule 33 — G-CS-11 linear setter;零 SFX 零 #22 persist)。
func volume_drag(v_raw: Variant) -> void:
	if _state != ScreenState.OPEN:
		return
	_pending_volume_pct = Formulas.quantize(v_raw)["pct"]


func volume_release() -> void:
	if _state != ScreenState.OPEN:
		return
	if _pending_volume_pct >= 0:
		_apply_volume_pct(_pending_volume_pct)
		_pending_volume_pct = -1
	_announce_coalesced("%d%%" % _volume_pct)


func _apply_volume_pct(pct: int) -> void:
	_volume_pct = pct
	if _audio != null and _audio.has_method("set_bus_volume_linear"):
		_audio.set_bus_volume_linear(0, float(pct) / 100.0)  # Bus.MASTER=0;persistence #4 own


## Rule 27 debounce arm(settle 先觸發;drag 每 tick 寫 = syncfs 災難)。
func _arm_persist(key: String, value: Variant) -> void:
	_persist_pending[key] = {
		"value": value,
		"remaining_ms": TimingConfig.SETTINGS_PERSIST_DEBOUNCE_MS,
	}


## 任何 close path 離開前 flush(Rule 27 + EC-27 critical flush)。
## Mid-drag force-close:當 force-close = settle — 以當前 applied/pending 值寫。
func _flush_pending_persist(suppress_banner: bool) -> void:
	if _motion_dragging and _pending_motion_pct >= 0:
		_apply_motion_pct(_pending_motion_pct)  # 當 settle
		_persist_pending["settings.motion_intensity"] = {
			"value": float(_slider_pct) / 100.0, "remaining_ms": 0.0,
		}
		_pending_motion_pct = -1
		_motion_dragging = false
	for key in _persist_pending.keys():
		_do_persist_write(key, _persist_pending[key]["value"], true, suppress_banner)
	_persist_pending = {}


func _do_persist_write(key: String, value: Variant, critical_flush: bool, suppress_banner: bool) -> void:
	if _persistence == null or not _persistence.has_method("write"):
		return
	var ok: bool = _persistence.write(key, value, critical_flush)
	if not ok and not suppress_banner:
		_persist_fail_banner = true  # 「設定今次有效,未能儲存」(session-only 生效)


func _advance_persist_debounce(delta_ms: float) -> void:
	for key in _persist_pending.keys():
		_persist_pending[key]["remaining_ms"] -= delta_ms
		if _persist_pending[key]["remaining_ms"] <= 0.0:
			_do_persist_write(key, _persist_pending[key]["value"], false, false)
			_persist_pending.erase(key)


## Per-frame coalesced consumer apply(AC-35:同 frame N tick ⇒ ≤1 call)。
func _advance_settings(delta_ms: float) -> void:
	if _pending_motion_pct >= 0:
		_apply_motion_pct(_pending_motion_pct)
		_pending_motion_pct = -1
	if _pending_volume_pct >= 0:
		_apply_volume_pct(_pending_volume_pct)
		_pending_volume_pct = -1
	_advance_persist_debounce(delta_ms)


## ---- settings view getters ----

func get_motion_slider() -> Dictionary:
	return {"pct": _slider_pct, "label": "%d%%" % _slider_pct}


func get_volume_slider() -> Dictionary:
	return {"pct": _volume_pct, "label": "%d%%" % _volume_pct}


func is_persist_fail_banner_visible() -> bool:
	return _persist_fail_banner


## ---- transient timers (nudge / toast / backfill notes — injected clock) ----

func _advance_transients(delta_ms: float) -> void:
	for slot in _nudges.keys():
		_nudges[slot]["remaining_ms"] -= delta_ms
		if _nudges[slot]["remaining_ms"] <= 0.0:
			_nudges.erase(slot)
	for slot in _backfill_notes.keys():
		_backfill_notes[slot]["remaining_ms"] -= delta_ms
		if _backfill_notes[slot]["remaining_ms"] <= 0.0:
			_backfill_notes.erase(slot)
	if not _toast.is_empty():
		_toast["remaining_ms"] -= delta_ms
		if _toast["remaining_ms"] <= 0.0:
			_toast = {}


## ---- loadout view getters ----

func get_loadout_view() -> Dictionary:
	return _loadout_view


func get_aggregate_badge() -> Dictionary:
	var raw: float = float(_aggregate.get("raw", 0.0))
	var eff: float = float(_aggregate.get("effective", 0.0))
	return {
		"visible": Formulas.badge_visible(raw, eff),
		"text": Formulas.badge_text(raw, eff) if Formulas.badge_visible(raw, eff) else "+%d" % roundi(eff),
	}


func get_forge_shards_display() -> String:
	return InventorySystem.format_shards(_forge_shards)  # G-IU-5 shared contract(D6 — 千位逗號 lossless;禁 K/M)


func get_nudge(slot: int) -> Dictionary:
	return _nudges.get(slot, {})


func get_backfill_note(slot: int) -> Dictionary:
	return _backfill_notes.get(slot, {})


func get_toast() -> Dictionary:
	return _toast


## ---- Rule 11 breathing freeze policy (AC-53;settings story 018 flip 入口) ----

## P-08 toggle 一掣兩 consumer:#7 camera setter(story 013/018)+ 呢度。
## 同 frame 生效 — avatar panel 同 SETTINGS tab 同屏可見。
func set_reduce_motion(enabled: bool) -> void:
	_reduce_motion = enabled


func is_avatar_breathing_frozen() -> bool:
	return _reduce_motion


## ---- binding view getters (render 層 + tests) ----

func get_stat_display(stat_id: StringName) -> String:
	if not _tweens.has(stat_id):
		return ""
	return _tweens[stat_id].display()


func get_stat_arrow(stat_id: StringName) -> int:
	if not _tweens.has(stat_id):
		return 0
	return _tweens[stat_id].arrow()


## watermark dim 行(""= suppress — formatter epsilon / persist-fail)。
func get_watermark_line(stat_id: StringName) -> String:
	var wm: Dictionary = _watermarks.get(stat_id, {})
	if not _tweens.has(stat_id):
		return ""
	var current: float = _tweens[stat_id].current_raw()
	var fmt: Callable = Formulas.formatter_for(stat_id)
	if not StatWatermark.should_render(wm, current, fmt):
		return ""
	return StatWatermark.render_text(wm, fmt)


func get_avatar_view() -> Dictionary:
	return _avatar_view


func has_milestone_hint() -> bool:
	return _milestone_hint


## ---- introspection helpers (tests + shell) ----

func get_screen_state() -> int:
	return _state


func get_active_panel() -> int:
	return _active_panel


func get_modal() -> int:
	return _modal


func is_offline_banner_visible() -> bool:
	return _offline_banner


func _is_disconnected() -> bool:
	if _gsm == null:
		return false
	return _gsm.get_current_state() == GSMScript.GameState.DISCONNECTED


func _resolve_default_seams() -> void:
	_gsm = get_node_or_null("/root/GameStateMachine")
	_stat_system = get_node_or_null("/root/StatSystem")
	_inventory = get_node_or_null("/root/InventorySystem")
	_avatar = get_node_or_null("/root/AvatarRenderer")
	_persistence = get_node_or_null("/root/PersistenceLayer")
	_screen_effects = get_node_or_null("/root/ScreenEffects")
	_camera = get_node_or_null("/root/CameraController")
	_audio = get_node_or_null("/root/AudioManager")
	_platform = get_node_or_null("/root/PlatformDetect")
	_inventory_ui = get_node_or_null("/root/InventoryUICoordinator")  # G-IU-4 glue
