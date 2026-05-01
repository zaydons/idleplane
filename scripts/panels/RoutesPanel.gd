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
	_progress_labels.clear()
	for child in _vbox.get_children():
		child.queue_free()
	if _picker:
		_picker.queue_free()
		_picker = null
	_vbox.add_child(_section_header("ROUTES"))
	for i in GameState.routes.size():
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
		lbl.text = "In flight  %s  %.0f%%" % [_bar(pct, 12), pct]

# ── Card builder ──────────────────────────────────────────────────────────────

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

func _route_card(route_idx: int) -> Control:
	var route: Dictionary = GameState.routes[route_idx]

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

	vbox.add_child(_lbl("%s  →  %s" % [route["origin"], route["destination"]], C_TEXT, 12))
	vbox.add_child(_lbl("%s → %s" % [route["origin_city"], route["destination_city"]], C_DIM, 10))
	vbox.add_child(_lbl("%d mi  |  Ticket: %s" % [route["distance_mi"], GameState.format_money(route["ticket_price"])], C_DIM, 10))
	vbox.add_child(_sep())

	# Aircraft row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	var assigned: int = route["assigned_plane"]
	var aircraft_lbl := Label.new()
	aircraft_lbl.add_theme_font_size_override("font_size", 10)
	aircraft_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aircraft_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if assigned == -1:
		aircraft_lbl.text = "Aircraft: none"
		aircraft_lbl.add_theme_color_override("font_color", C_YELLOW)
		hbox.add_child(aircraft_lbl)
		var btn := _action_btn("Assign", C_ACCENT)
		btn.pressed.connect(func(): _show_picker(route_idx))
		hbox.add_child(btn)
	else:
		aircraft_lbl.text = "Aircraft: %s" % GameState.planes[assigned]["name"]
		aircraft_lbl.add_theme_color_override("font_color", C_GREEN)
		hbox.add_child(aircraft_lbl)
		var btn := _action_btn("Unassign", C_RED)
		btn.pressed.connect(func(): GameState.unassign_route(route_idx))
		hbox.add_child(btn)

	# Live progress bar (only visible when active)
	var prog_lbl := _lbl("", C_ACCENT, 10)
	prog_lbl.visible = (route["status"] == "active")
	if route["status"] == "active":
		var pct := float(route["flight_progress"]) / float(route["flight_duration_sec"]) * 100.0
		prog_lbl.text = "In flight  %s  %.0f%%" % [_bar(pct, 12), pct]
	_progress_labels[route_idx] = prog_lbl
	vbox.add_child(prog_lbl)

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
	var cs := StyleBoxFlat.new()
	cs.bg_color = C_CARD
	cs.border_color = C_ACCENT
	cs.set_border_width_all(1)
	cs.content_margin_left = 10.0;  cs.content_margin_right  = 10.0
	cs.content_margin_top  = 8.0;   cs.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title := _lbl("SELECT AIRCRAFT", C_ACCENT, 11)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_sep())

	var any := false
	for plane_idx in GameState.planes.size():
		var plane: Dictionary = GameState.planes[plane_idx]
		if plane["status"] == "maintenance" or float(plane["condition"]) <= 0.0:
			continue
		any = true
		var is_elsewhere := int(plane["assigned_route"]) != -1 and int(plane["assigned_route"]) != route_idx
		var btn := Button.new()
		btn.text = plane["name"] + ("  (reassign)" if is_elsewhere else "")
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color",         C_DIM if is_elsewhere else C_TEXT)
		btn.add_theme_color_override("font_hover_color",   C_ACCENT)
		btn.add_theme_color_override("font_pressed_color", C_ACCENT)
		btn.add_theme_stylebox_override("normal",  _ghost_box())
		btn.add_theme_stylebox_override("hover",   _ghost_box(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.15)))
		btn.add_theme_stylebox_override("pressed", _ghost_box(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.15)))
		var p_idx := plane_idx
		btn.pressed.connect(func(): GameState.assign_plane_to_route(p_idx, route_idx))
		vbox.add_child(btn)

	if not any:
		var none_lbl := _lbl("No aircraft available", C_DIM, 10)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(none_lbl)

	vbox.add_child(_sep())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.flat = true
	cancel.add_theme_font_size_override("font_size", 10)
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
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   color)
	btn.add_theme_color_override("font_pressed_color", color)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.15)
	s.border_color = color
	s.set_border_width_all(1)
	s.content_margin_left = 6.0;  s.content_margin_right  = 6.0
	s.content_margin_top  = 2.0;  s.content_margin_bottom = 2.0
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
