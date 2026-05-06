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
var _picker: Control = null
# route_idx -> Label for live in-flight progress
var _progress_labels: Dictionary = {}

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
	if _vbox == null:
		return
	_progress_labels.clear()
	for child in _vbox.get_children():
		_vbox.remove_child(child)
		child.queue_free()
	if _picker:
		_picker.queue_free()
		_picker = null
	_vbox.add_child(_section_header("ROUTES"))
	for i in GameState.routes.size():
		var route: Dictionary = GameState.routes[i]
		if route["locked"]:
			_vbox.add_child(_locked_card(i))
		else:
			_vbox.add_child(_route_card(i))

func _process(_delta: float) -> void:
	for route_idx in _progress_labels:
		var lbl: Label = _progress_labels[route_idx]
		if not is_instance_valid(lbl):
			continue
		var route: Dictionary = GameState.routes[route_idx]
		if route["status"] != "active":
			lbl.visible = false
			continue
		var pct := float(route["flight_progress"]) / float(route["flight_duration_sec"]) * 100.0
		lbl.visible = true
		lbl.text = "In flight  %s  %.0f%%" % [_bar(pct, 10), pct]

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

func _route_card(route_idx: int) -> Control:
	var route: Dictionary = GameState.routes[route_idx]

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

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	card.add_child(cols)

	# ── Left: route identity ──────────────────────────────────────────
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)

	left.add_child(_lbl("%s -> %s" % [route["origin"], route["destination"]], C_TEXT, 13))
	left.add_child(_lbl("%s / %s" % [route["origin_city"], route["destination_city"]], C_DIM, 11))
	left.add_child(_lbl("%d mi  |  %s/seat" % [route["distance_mi"], GameState.format_money(route["ticket_price"])], C_DIM, 11))

	# ── Right: aircraft + status ──────────────────────────────────────
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)

	var assigned: int = int(route["assigned_plane"])

	var ac_row := HBoxContainer.new()
	ac_row.add_theme_constant_override("separation", 6)
	right.add_child(ac_row)

	if assigned == -1:
		var none_lbl := _lbl("No aircraft", C_YELLOW, 11)
		none_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ac_row.add_child(none_lbl)
		var btn := _action_btn("Assign", C_ACCENT)
		btn.pressed.connect(func(): _show_picker(route_idx))
		ac_row.add_child(btn)
	else:
		var plane_status: String = GameState.planes[assigned]["status"]
		var name_color := C_YELLOW if plane_status == "maintenance" else C_GREEN
		var name_lbl := _lbl(GameState.planes[assigned]["name"], name_color, 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ac_row.add_child(name_lbl)
		var btn := _action_btn("Unassign", C_RED)
		btn.pressed.connect(func(): GameState.unassign_route(route_idx))
		ac_row.add_child(btn)

	# Progress / pause status
	var prog_lbl := _lbl("", C_ACCENT, 11)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if route["status"] == "active":
		var pct := float(route["flight_progress"]) / float(route["flight_duration_sec"]) * 100.0
		prog_lbl.text = "In flight  %s  %.0f%%" % [_bar(pct, 10), pct]
		prog_lbl.visible = true
	elif assigned != -1:
		var plane_st: String = GameState.planes[assigned]["status"]
		if plane_st == "maintenance":
			prog_lbl.text = "Paused - under repair"
			prog_lbl.add_theme_color_override("font_color", C_YELLOW)
		elif float(GameState.planes[assigned]["condition"]) <= 0.0:
			prog_lbl.text = "Paused - needs repair"
			prog_lbl.add_theme_color_override("font_color", C_RED)
		prog_lbl.visible = prog_lbl.text != ""
	else:
		prog_lbl.visible = false
	_progress_labels[route_idx] = prog_lbl
	right.add_child(prog_lbl)

	return m

func _locked_card(route_idx: int) -> Control:
	var route: Dictionary = GameState.routes[route_idx]

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   12)
	m.add_theme_constant_override("margin_right",  12)
	m.add_theme_constant_override("margin_top",    2)
	m.add_theme_constant_override("margin_bottom", 2)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#080f1e")
	style.border_color = Color("#12203a")
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

	info.add_child(_lbl("%s -> %s" % [route["origin"], route["destination"]], C_DIM, 13))
	info.add_child(_lbl("%s / %s" % [route["origin_city"], route["destination_city"]], C_DIM, 11))
	info.add_child(_lbl("%d mi  |  %s/seat" % [route["distance_mi"], GameState.format_money(route["ticket_price"])], C_DIM, 11))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right)

	var cost := float(route["unlock_cost"])
	var can_afford := GameState.cash >= cost
	var btn := _action_btn("Unlock\n%s" % GameState.format_money(cost), C_YELLOW if can_afford else C_DIM)
	btn.disabled = not can_afford
	var r_idx := route_idx
	btn.pressed.connect(func(): GameState.unlock_route(r_idx))
	right.add_child(btn)

	return m

# ── Picker overlay ────────────────────────────────────────────────────────────

func _show_picker(route_idx: int) -> void:
	if _picker:
		_picker.queue_free()

	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.02, 0.08, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and _picker:
			_picker.queue_free()
			_picker = null
	)
	_picker.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_picker.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.bg_color = C_CARD
	cs.border_color = C_ACCENT
	cs.set_border_width_all(1)
	cs.content_margin_left = 10.0;  cs.content_margin_right  = 10.0
	cs.content_margin_top  = 8.0;   cs.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	card.add_child(outer_vbox)

	var title := _lbl("SELECT AIRCRAFT", C_ACCENT, 11)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)
	outer_vbox.add_child(_sep())

	# Scrollable plane list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Build two sorted lists: available first, then reassignable
	var available := []
	var reassignable := []
	for plane_idx in GameState.planes.size():
		var plane: Dictionary = GameState.planes[plane_idx]
		if plane["status"] == "maintenance" or float(plane["condition"]) <= 0.0:
			continue
		var assigned_route: int = int(plane["assigned_route"])
		if assigned_route != -1 and assigned_route != route_idx:
			reassignable.append(plane_idx)
		else:
			available.append(plane_idx)

	var any := available.size() > 0 or reassignable.size() > 0

	for plane_idx in available:
		var plane: Dictionary = GameState.planes[plane_idx]
		var btn := Button.new()
		btn.text = plane["name"]
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color",         C_TEXT)
		btn.add_theme_color_override("font_hover_color",   C_ACCENT)
		btn.add_theme_color_override("font_pressed_color", C_ACCENT)
		btn.add_theme_stylebox_override("normal",  _ghost_box())
		btn.add_theme_stylebox_override("hover",   _ghost_box(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.15)))
		btn.add_theme_stylebox_override("pressed", _ghost_box(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.15)))
		var p_idx: int = plane_idx
		btn.pressed.connect(func(): GameState.assign_plane_to_route(p_idx, route_idx))
		vbox.add_child(btn)

	if available.size() > 0 and reassignable.size() > 0:
		vbox.add_child(_thin_sep())

	for plane_idx in reassignable:
		var plane: Dictionary = GameState.planes[plane_idx]
		var r: Dictionary = GameState.routes[int(plane["assigned_route"])]
		var btn := Button.new()
		btn.text = "%s  %s->%s" % [plane["name"], r["origin"], r["destination"]]
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color",         C_DIM)
		btn.add_theme_color_override("font_hover_color",   C_ACCENT)
		btn.add_theme_color_override("font_pressed_color", C_ACCENT)
		btn.add_theme_stylebox_override("normal",  _ghost_box())
		btn.add_theme_stylebox_override("hover",   _ghost_box(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.15)))
		btn.add_theme_stylebox_override("pressed", _ghost_box(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.15)))
		var p_idx: int = plane_idx
		btn.pressed.connect(func(): GameState.assign_plane_to_route(p_idx, route_idx))
		vbox.add_child(btn)

	# Cap the scroll area height so it doesn't overflow the screen
	var row_h := 36
	var max_visible := 5
	scroll.custom_minimum_size = Vector2(0, mini(GameState.planes.size(), max_visible) * row_h)

	if not any:
		var none_lbl := _lbl("No aircraft available", C_DIM, 12)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(none_lbl)

	vbox.add_child(_sep())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.flat = true
	cancel.add_theme_font_size_override("font_size", 13)
	cancel.add_theme_color_override("font_color",       C_DIM)
	cancel.add_theme_color_override("font_hover_color", C_TEXT)
	cancel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel.add_theme_stylebox_override("normal",  _ghost_box())
	cancel.add_theme_stylebox_override("hover",   _ghost_box())
	cancel.add_theme_stylebox_override("pressed", _ghost_box())
	cancel.pressed.connect(func():
		if _picker:
			_picker.queue_free()
		_picker = null
	)
	vbox.add_child(cancel)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _action_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 13)
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

func _ghost_box(bg := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = 4.0;  s.content_margin_right  = 4.0
	s.content_margin_top  = 3.0;  s.content_margin_bottom = 3.0
	return s

func _thin_sep() -> Control:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.4)
	sep.add_theme_stylebox_override("separator", s)
	return sep

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
