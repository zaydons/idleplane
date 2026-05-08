extends Control

const C_CARD   := Color("#0d1525")
const C_BORDER := Color("#1a2840")
const C_TEXT   := Color("#c0d0e8")
const C_DIM    := Color("#6a7c94")
const C_ACCENT := Color("#5090d8")
const C_GREEN  := Color("#38c870")
const C_YELLOW := Color("#e8b830")
const C_RED    := Color("#d84838")

var _vbox: VBoxContainer
var _progress_labels: Dictionary = {}  # plane_idx -> en-route Label
var _repair_labels: Dictionary = {}    # plane_idx -> repair progress Label

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
	GameState.flight_completed.connect(_on_flight_completed)
	GameState.repair_completed.connect(_on_repair_completed)
	GameState.used_market_changed.connect(refresh)
	GameState.cash_changed.connect(refresh)
	refresh()

func _on_flight_completed(_route_idx: int) -> void:
	refresh()

func _on_repair_completed(_plane_idx: int) -> void:
	refresh()

func refresh() -> void:
	if _vbox == null:
		return
	_progress_labels.clear()
	_repair_labels.clear()
	for child in _vbox.get_children():
		_vbox.remove_child(child)
		child.queue_free()
	_vbox.add_child(_section_header("FLEET"))
	var total_repair := GameState.total_repair_cost()
	if total_repair > 0.0:
		_vbox.add_child(_repair_all_bar(total_repair))
	for i in GameState.planes.size():
		_vbox.add_child(_plane_card(i))
	_vbox.add_child(_section_header("BUY AIRCRAFT"))
	for i in GameState.PLANE_CATALOG.size():
		_vbox.add_child(_market_card(i))
	_vbox.add_child(_section_header("USED AIRCRAFT"))
	for i in GameState.used_market.size():
		_vbox.add_child(_used_card(i))

func _process(_delta: float) -> void:
	for plane_idx in _progress_labels:
		var lbl: Label = _progress_labels[plane_idx]
		if not is_instance_valid(lbl):
			continue
		var plane: Dictionary = GameState.planes[plane_idx]
		if plane["status"] != "flying":
			lbl.visible = false
			continue
		var route: Dictionary = GameState.routes[int(plane["assigned_route"])]
		var pct := float(route["flight_progress"]) / float(route["flight_duration_sec"]) * 100.0
		lbl.visible = true
		lbl.text = "En route  %s  %.0f%%" % [_bar(pct, 10), pct]

	for plane_idx in _repair_labels:
		var lbl: Label = _repair_labels[plane_idx]
		if not is_instance_valid(lbl):
			continue
		var plane: Dictionary = GameState.planes[plane_idx]
		if plane["status"] != "maintenance":
			lbl.visible = false
			continue
		var total: float = float(plane["repair_total_time"])
		var left: float  = float(plane["repair_time_left"])
		var pct := (1.0 - left / total) * 100.0 if total > 0.0 else 100.0
		lbl.visible = true
		lbl.text = "Repairing  %s  %.0f%%  (%ds left)" % [_bar(pct, 10), pct, int(left)]

# ── Card builder ──────────────────────────────────────────────────────────────

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

func _repair_all_bar(total_cost: float) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   12)
	m.add_theme_constant_override("margin_right",  12)
	m.add_theme_constant_override("margin_top",    0)
	m.add_theme_constant_override("margin_bottom", 2)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	m.add_child(hbox)

	var lbl := _lbl("Repair all:  %s" % GameState.format_money(total_cost), C_YELLOW, 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var can_afford := GameState.cash >= total_cost
	var btn := _action_btn("Repair All", C_GREEN if can_afford else C_DIM)
	btn.disabled = not can_afford
	btn.pressed.connect(func(): GameState.repair_all_planes())
	hbox.add_child(btn)

	return m

func _plane_card(plane_idx: int) -> Control:
	var plane: Dictionary = GameState.planes[plane_idx]

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

	# Two-column layout: left = identity, right = status/condition/repair
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	card.add_child(cols)

	# ── Left column ──────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)

	var status: String = plane["status"]
	var route_suffix := ""
	if status == "flying":
		var r: Dictionary = GameState.routes[int(plane["assigned_route"])]
		route_suffix = "  (%s -> %s)" % [r["origin"], r["destination"]]

	left.add_child(_lbl(plane["name"], C_TEXT, 12))
	left.add_child(_lbl("Seats: %d  |  %s%s" % [plane["seats"], status.capitalize(), route_suffix], _status_color(status), 11))
	left.add_child(_lbl("Total flights: %d" % int(plane["total_flights"]), C_DIM, 11))

	# ── Right column ─────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)

	# Live flight progress — shown only when flying, updated in _process
	var prog_lbl := _lbl("", C_ACCENT, 11)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_lbl.visible = (status == "flying")
	if status == "flying":
		var route: Dictionary = GameState.routes[int(plane["assigned_route"])]
		var pct := float(route["flight_progress"]) / float(route["flight_duration_sec"]) * 100.0
		prog_lbl.text = "En route  %s  %.0f%%" % [_bar(pct, 10), pct]
	_progress_labels[plane_idx] = prog_lbl
	right.add_child(prog_lbl)

	# Condition bar
	var cond: float = float(plane["condition"])
	var bar_color := C_GREEN if cond >= 80.0 else (C_YELLOW if cond >= 50.0 else C_RED)
	var cond_lbl := _lbl("Condition  %s  %.0f%%" % [_bar(cond, 10), cond], bar_color, 11)
	cond_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cond_lbl)

	var cost := GameState.repair_cost_for_plane(plane)

	if status == "maintenance":
		# Live repair countdown — updated in _process
		var rep_lbl := _lbl("", C_YELLOW, 11)
		rep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_repair_labels[plane_idx] = rep_lbl
		right.add_child(rep_lbl)
	elif cond < 100.0:
		# Repair button
		var suffix := "  (pauses)" if status == "flying" else ""
		var cost_lbl := _lbl("%s%s" % [GameState.format_money(cost), suffix], C_YELLOW, 11)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(cost_lbl)

		var can_afford := GameState.cash >= cost
		var btn := _action_btn("Repair", C_GREEN if can_afford else C_DIM)
		btn.disabled = not can_afford
		var p_idx: int = plane_idx
		btn.pressed.connect(func(): GameState.repair_plane(p_idx))
		right.add_child(btn)

	# Sell button — available when grounded or in maintenance (not mid-flight)
	if status != "flying":
		var sell_price := GameState.sell_price_for_plane(plane)
		var sell_btn := _action_btn("Sell  %s" % GameState.format_money(sell_price), C_DIM)
		sell_btn.add_theme_font_size_override("font_size", 10)
		var p_idx: int = plane_idx
		sell_btn.pressed.connect(func(): GameState.sell_plane(p_idx))
		right.add_child(sell_btn)

	return m

func _market_card(catalog_idx: int) -> Control:
	var entry: Dictionary = GameState.PLANE_CATALOG[catalog_idx]

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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)

	# Info column
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	info.add_child(_lbl(entry["name"], C_TEXT, 12))
	info.add_child(_lbl("%d seats  |  Wear: %.1f%%/flight" % [entry["seats"], entry["wear_per_flight"]], C_DIM, 11))
	info.add_child(_lbl(entry["description"], C_DIM, 11))

	# Price + buy button column
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right)

	right.add_child(_lbl(GameState.format_money(entry["price"]), C_YELLOW, 11))

	var can_afford := GameState.cash >= float(entry["price"])
	var btn := _action_btn("Buy", C_GREEN if can_afford else C_DIM)
	btn.disabled = not can_afford
	var idx := catalog_idx
	btn.pressed.connect(func(): GameState.buy_plane(idx))
	right.add_child(btn)

	return m

func _used_card(market_idx: int) -> Control:
	var listing: Dictionary = GameState.used_market[market_idx]

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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	info.add_child(_lbl(listing["name"], C_TEXT, 12))
	info.add_child(_lbl("%d seats  |  Wear: %.1f%%/flight" % [listing["seats"], listing["wear_per_flight"]], C_DIM, 11))
	var cond: float = float(listing["condition"])
	var bar_color := C_GREEN if cond >= 80.0 else (C_YELLOW if cond >= 50.0 else C_RED)
	info.add_child(_lbl("Condition  %s  %.0f%%" % [_bar(cond, 10), cond], bar_color, 11))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right)

	right.add_child(_lbl(GameState.format_money(listing["price"]), C_YELLOW, 11))

	var can_afford := GameState.cash >= float(listing["price"])
	var btn := _action_btn("Buy", C_GREEN if can_afford else C_DIM)
	btn.disabled = not can_afford
	var idx := market_idx
	btn.pressed.connect(func(): GameState.buy_used_plane(idx))
	right.add_child(btn)

	return m

# ── Helpers ───────────────────────────────────────────────────────────────────

func _action_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   color)
	btn.add_theme_color_override("font_pressed_color", color)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.15)
	s.border_color = color
	s.set_border_width_all(1)
	s.content_margin_left = 12.0;  s.content_margin_right  = 12.0
	s.content_margin_top  = 6.0;  s.content_margin_bottom = 6.0
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(color.r, color.g, color.b, 0.3)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", s)
	return btn

func _status_color(status: String) -> Color:
	match status:
		"flying":      return C_ACCENT
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
	var s := "["
	for i in width:
		s += "=" if i < n else "-"
	return s + "]"
