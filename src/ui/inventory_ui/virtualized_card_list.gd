## #23 Virtualized card list(story 005;GDD Rule 9 + EC-14;novel — 零先例)。
##
## Generic fixed-row-height virtualized list:ScrollContainer + 固定高 canvas
## spacer + card pool reposition(scroll offset → index 數學)。Instantiated
## card nodes ≤ ceil(viewport_h / ROW_HEIGHT_PX) + 2 × pool_buffer_rows
## (AC-13;ADR-0001 draw-call 紀律 — 120+180 全 instantiate 會爆 budget)。
##
## Generic by design(#24 可 reuse):component 唔識 #17 / view model —
## row content 由 caller 注入(card_factory 造 node;populate_card 填內容,
## 包括 P-06 card 結構 / provenance 單行 ellipsis — caller 責任)。
## INVENTORY / MAILBOX 各自 instance,同一 class(Rule 9)。
##
## Scroll 雙軌(EC-14):
##   - bulk rebuild(內容根本唔同)→ `set_item_count(n, true)` reset 去頂
##   - 單件 mutation(claim / 單件 salvage / equip / lock)→
##     `set_item_count(n, false)` 保留 offset(clamped — 內容 99% 冇變)
##
## Focus-driven virtualization hook(SR/keyboard — UI Req):
## `ensure_index_visible(index)` — 視窗跟 focus 推進;接線喺 story 015。
extends ScrollContainer

## Fixed row height(Rule 9 — retention 行 / receipt note 喺 fixed card 內
## 預留位,唔改 card 高;UX spec fixed-height pin,test 讀同一常數)。
const ROW_HEIGHT_PX: float = 96.0

## Pool buffer knob(GDD Tuning Knobs — default 2,safe range 1-4)。
@export_range(1, 4) var pool_buffer_rows: int = 2

## Caller 注入 seams(component 唔識 #17)。
var _card_factory: Callable = Callable()
var _populate_card: Callable = Callable()  # (card: Control, index: int) -> void

var _item_count: int = 0
var _canvas: Control = null
var _pool: Array[Control] = []


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_canvas = Control.new()
	_canvas.name = "VirtualCanvas"
	add_child(_canvas)
	get_v_scroll_bar().value_changed.connect(_on_scroll_changed)


## 一次性 setup:card_factory() -> Control 造 row node;
## populate_card(card, index) 由 caller 用自己嘅 view model 填內容。
func setup(card_factory: Callable, populate_card: Callable) -> void:
	_card_factory = card_factory
	_populate_card = populate_card


## Rebuild 入口(EC-14 雙軌)。reset_scroll: true = bulk(去頂);
## false = 單件 mutation(保留 offset,clamped)。
func set_item_count(count: int, reset_scroll: bool) -> void:
	_item_count = maxi(count, 0)
	_canvas.custom_minimum_size = Vector2(0.0, _item_count * ROW_HEIGHT_PX)
	if reset_scroll:
		scroll_vertical = 0
	else:
		scroll_vertical = mini(scroll_vertical, _max_scroll())
	refresh_visible()


## Repopulate 視窗內 rows(scroll / rebuild / view-model 變更後 call)。
## 每次全 repopulate 視窗 — populate 係 view-model read,AC-33 2ms budget
## 喺 story 006 驗。
func refresh_visible() -> void:
	if _canvas == null or not _card_factory.is_valid():
		return
	var clamped_scroll: int = mini(scroll_vertical, _max_scroll())
	var first: int = maxi(int(floor(clamped_scroll / ROW_HEIGHT_PX)) - pool_buffer_rows, 0)
	var last: int = mini(first + pool_cap() - 1, _item_count - 1)
	var used: int = 0
	for index in range(first, last + 1):
		var card: Control = _card_at_pool_slot(used)
		card.visible = true
		card.position = Vector2(0.0, index * ROW_HEIGHT_PX)
		card.set_meta(&"row_index", index)
		if _populate_card.is_valid():
			_populate_card.call(card, index)
		used += 1
	for i in range(used, _pool.size()):
		_pool[i].visible = false


## Focus-driven virtualization(UI Req SR policy):scroll 到 index 可見
## (視窗跟 focus 推進,唔淨係跟 scroll position)。Returns 新 scroll。
func ensure_index_visible(index: int) -> int:
	var idx: int = clampi(index, 0, maxi(_item_count - 1, 0))
	var row_top: float = idx * ROW_HEIGHT_PX
	var row_bottom: float = row_top + ROW_HEIGHT_PX
	var view_h: float = size.y
	if row_top < float(scroll_vertical):
		scroll_vertical = int(row_top)
	elif row_bottom > float(scroll_vertical) + view_h:
		scroll_vertical = int(row_bottom - view_h)
	refresh_visible()
	return scroll_vertical


## ---- introspection(tests + AC-13) ----

## Pool 上限公式(AC-13 — test 讀呢個,唔 duplicate 常數)。
func pool_cap() -> int:
	return int(ceil(size.y / ROW_HEIGHT_PX)) + 2 * pool_buffer_rows


## 現時 instantiated card nodes 總數(P-06 card node 計,chrome 唔計)。
func get_card_node_count() -> int:
	return _pool.size()


func get_visible_card_count() -> int:
	var n: int = 0
	for card in _pool:
		if card.visible:
			n += 1
	return n


func get_item_count() -> int:
	return _item_count


## ---- internals ----

func _max_scroll() -> int:
	return maxi(int(_item_count * ROW_HEIGHT_PX - size.y), 0)


func _card_at_pool_slot(slot: int) -> Control:
	while _pool.size() <= slot:
		var card: Control = _card_factory.call()
		card.visible = false
		_canvas.add_child(card)
		_pool.append(card)
	return _pool[slot]


func _on_scroll_changed(_value: float) -> void:
	refresh_visible()
