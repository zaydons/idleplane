extends Control

const C_CARD   := Color("#0d1525")
const C_BORDER := Color("#1a2840")
const C_TEXT   := Color("#c0d0e8")
const C_DIM    := Color("#485870")
const C_ACCENT := Color("#5090d8")
const C_GREEN  := Color("#38c870")
const C_YELLOW := Color("#e8b830")
const C_RED    := Color("#d84838")

var _vbox: VBoxContainer

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_vbox)

	GameState.assignment_changed.connect(refresh)
	refresh()

func refresh() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_vbox.add_child(_section_header("FLEET"))
	for plane in GameState.planes:
		_vbox.add_child(_plane_card(plane))

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

func _plane_card(plane: Dictionary) -> Control:
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
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	vbox.add_child(_lbl(plane["name"], C_TEXT, 11))

	# Status row — show assigned route when applicable
	var status: String = plane["status"]
	var route_suffix := ""
	if status == "assigned":
		var r: Dictionary = GameState.routes[plane["assigned_route"] as int]
		route_suffix = "  (%s → %s)" % [r["origin"], r["destination"]]
	var status_color := _status_color(status)
	vbox.add_child(_lbl("Seats: %d  |  Status: %s%s" % [plane["seats"], status.capitalize(), route_suffix], status_color, 10))

	vbox.add_child(_sep())

	var cond: float = plane["condition"]
	var bar_color := C_GREEN if cond >= 80.0 else (C_YELLOW if cond >= 50.0 else C_RED)
	vbox.add_child(_lbl("Condition  %s  %.0f%%" % [_bar(cond), cond], bar_color, 10))

	var cost := (100.0 - cond) * float(plane["repair_cost_per_pct"])
	if cond >= 100.0:
		vbox.add_child(_lbl("No repairs needed", C_DIM, 10))
	else:
		vbox.add_child(_lbl("Repair to 100%%:  %s" % GameState.format_money(cost), C_YELLOW, 10))

	return m

func _status_color(status: String) -> Color:
	match status:
		"assigned":    return C_ACCENT
		"flying":      return C_GREEN
		"maintenance": return C_YELLOW
	return C_DIM  # grounded

func _sep() -> Control:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_BORDER
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _lbl(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

func _bar(pct: float, width: int = 14) -> String:
	var n := int(round(pct / 100.0 * width))
	var s := ""
	for i in width:
		s += "█" if i < n else "░"
	return s
