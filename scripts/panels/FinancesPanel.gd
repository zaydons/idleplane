extends Control

const C_CARD   := Color("#0d1525")
const C_BORDER := Color("#1a2840")
const C_TEXT   := Color("#c0d0e8")
const C_DIM    := Color("#6a7c94")
const C_ACCENT := Color("#5090d8")
const C_GOLD   := Color("#e8b830")
const C_GREEN  := Color("#38c870")
const C_RED    := Color("#d84838")

var _vbox:     VBoxContainer
var _cash_lbl: Label

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_vbox)

	GameState.cash_changed.connect(_on_cash_changed)
	GameState.assignment_changed.connect(refresh)
	GameState.flight_completed.connect(_on_flight_completed)
	refresh()

func _on_cash_changed() -> void:
	if _cash_lbl and is_instance_valid(_cash_lbl):
		_cash_lbl.text = GameState.format_money(GameState.cash)

func _on_flight_completed(_route_idx: int) -> void:
	refresh()

func refresh() -> void:
	if _vbox == null:
		return
	_cash_lbl = null
	for child in _vbox.get_children():
		_vbox.remove_child(child)
		child.queue_free()

	_vbox.add_child(_section_header("OVERVIEW"))
	_vbox.add_child(_overview_card())

	var active_routes := _get_active_routes()
	if active_routes.size() > 0:
		_vbox.add_child(_section_header("INCOME STREAMS"))
		for entry in active_routes:
			_vbox.add_child(_route_income_card(entry))

	if GameState.flight_log.size() > 0:
		_vbox.add_child(_section_header("RECENT FLIGHTS"))
		_vbox.add_child(_log_card())

# ── Cards ─────────────────────────────────────────────────────────────────────

func _overview_card() -> Control:
	var card := _make_card()
	var vbox: VBoxContainer = card.get_child(0).get_child(0)

	var cash_row := _row("Cash on hand", GameState.format_money(GameState.cash), C_GOLD)
	_cash_lbl = cash_row.get_child(1) as Label
	vbox.add_child(cash_row)

	vbox.add_child(_sep())

	var net := GameState.total_earned - GameState.total_spent
	vbox.add_child(_row("Total earned", GameState.format_money(GameState.total_earned), C_GREEN))
	vbox.add_child(_row("Total spent",  GameState.format_money(GameState.total_spent),  C_RED))
	vbox.add_child(_sep())
	var net_color := C_GREEN if net >= 0.0 else C_RED
	vbox.add_child(_row("Net profit", GameState.format_money(net), net_color))

	return card

func _route_income_card(entry: Dictionary) -> Control:
	var card := _make_card()
	var vbox: VBoxContainer = card.get_child(0).get_child(0)

	var route: Dictionary  = entry["route"]
	var plane: Dictionary  = entry["plane"]
	var rev_per_flight := float(route["ticket_price"]) * float(plane["seats"]) * float(route["occupancy_rate"])
	var dur_min        := float(route["flight_duration_sec"]) / 60.0
	var rev_per_min    := rev_per_flight / dur_min

	vbox.add_child(_row(
		"%s -> %s" % [route["origin"], route["destination"]],
		"%s / flight" % GameState.format_money(rev_per_flight),
		C_TEXT
	))
	vbox.add_child(_row(
		"%s  |  %.1f min/flight" % [plane["name"], dur_min],
		"%s / min" % GameState.format_money(rev_per_min),
		C_GREEN
	))

	return card

func _log_card() -> Control:
	var card := _make_card()
	var vbox: VBoxContainer = card.get_child(0).get_child(0)

	for i in GameState.flight_log.size():
		var entry: Dictionary = GameState.flight_log[i]
		vbox.add_child(_row(entry["route"], "+%s" % GameState.format_money(entry["amount"]), C_GREEN))
		if i < GameState.flight_log.size() - 1:
			vbox.add_child(_thin_sep())

	return card

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_active_routes() -> Array:
	var result := []
	for route in GameState.routes:
		if route["status"] != "active":
			continue
		var plane_idx: int = int(route["assigned_plane"])
		if plane_idx < 0 or plane_idx >= GameState.planes.size():
			continue
		result.append({"route": route, "plane": GameState.planes[plane_idx]})
	return result

func _make_card() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   12)
	m.add_theme_constant_override("margin_right",  12)
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

	return m

func _section_header(title: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   12)
	m.add_theme_constant_override("margin_top",    6)
	m.add_theme_constant_override("margin_bottom", 2)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", C_ACCENT)
	l.add_theme_font_size_override("font_size", 13)
	m.add_child(l)
	return m

func _row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", C_DIM)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", value_color)
	val.add_theme_font_size_override("font_size", 11)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val)
	return hbox

func _sep() -> Control:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_BORDER
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _thin_sep() -> Control:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.4)
	sep.add_theme_stylebox_override("separator", s)
	return sep
