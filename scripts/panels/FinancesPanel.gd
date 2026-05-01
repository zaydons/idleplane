extends Control

const C_CARD   := Color("#0d1525")
const C_BORDER := Color("#1a2840")
const C_DIM    := Color("#485870")
const C_ACCENT := Color("#5090d8")
const C_GOLD   := Color("#e8b830")
const C_GREEN  := Color("#38c870")
const C_RED    := Color("#d84838")

var _vbox: VBoxContainer
var _cash_val: Label

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_vbox)

	GameState.cash_changed.connect(_update_cash)
	GameState.assignment_changed.connect(refresh)
	refresh()

func refresh() -> void:
	_cash_val = null
	for child in _vbox.get_children():
		child.queue_free()
	_vbox.add_child(_section_header("FINANCES"))
	_vbox.add_child(_summary_card())

func _update_cash() -> void:
	if _cash_val and is_instance_valid(_cash_val):
		_cash_val.text = GameState.format_money(GameState.cash)

func _section_header(title: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   8)
	m.add_theme_constant_override("margin_top",    6)
	m.add_theme_constant_override("margin_bottom", 2)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", C_ACCENT)
	l.add_theme_font_size_override("font_size", 12)
	m.add_child(l)
	return m

func _summary_card() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   8)
	m.add_theme_constant_override("margin_right",  8)
	m.add_theme_constant_override("margin_top",    2)
	m.add_theme_constant_override("margin_bottom", 2)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_CARD
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)
	m.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Cash — store label ref for live updates
	var cash_row := _row("Cash on hand", GameState.format_money(GameState.cash), C_GOLD)
	_cash_val = cash_row.get_child(1) as Label
	vbox.add_child(cash_row)

	vbox.add_child(_sep())

	var rev := _revenue_per_flight()
	var rev_str := GameState.format_money(rev) + " / flight" if rev > 0.0 else "$0 / flight"
	vbox.add_child(_row("Revenue",  rev_str,       C_GREEN))
	vbox.add_child(_row("Expenses", "$0 / flight", C_RED))

	vbox.add_child(_sep())

	var net_str := GameState.format_money(rev) + " / flight" if rev > 0.0 else "$0 / flight"
	vbox.add_child(_row("Net", net_str, C_GREEN if rev > 0.0 else C_DIM))

	return m

func _revenue_per_flight() -> float:
	var total := 0.0
	for route in GameState.routes:
		if route["status"] != "active":
			continue
		var plane_idx: int = route["assigned_plane"]
		if plane_idx == -1:
			continue
		var plane: Dictionary = GameState.planes[plane_idx]
		total += float(route["ticket_price"]) * float(plane["seats"]) * float(route["occupancy_rate"])
	return total

func _row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", C_DIM)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", value_color)
	val.add_theme_font_size_override("font_size", 10)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val)

	return hbox

func _sep() -> Control:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_BORDER
	sep.add_theme_stylebox_override("separator", s)
	return sep
