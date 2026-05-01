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
	refresh()

func _on_flight_completed(_route_idx: int) -> void:
	refresh()

func _on_repair_completed(_plane_idx: int) -> void:
	refresh()

func refresh() -> void:
	_progress_labels.clear()
	_repair_labels.clear()
	for child in _vbox.get_children():
		child.queue_free()
	_vbox.add_child(_section_header("FLEET"))
	for i in GameState.planes.size():
		_vbox.add_child(_plane_card(i))

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
		lbl.text = "En route  %s  %.0f%%" % [_bar(pct, 12), pct]

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
	m.add_theme_constant_override("margin_left",   8)
	m.add_theme_constant_override("margin_top",    6)
	m.add_theme_constant_override("margin_bottom", 2)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", C_ACCENT)
	l.add_theme_font_size_override("font_size", 12)
	m.add_child(l)
	return m

func _plane_card(plane_idx: int) -> Control:
	var plane: Dictionary = GameState.planes[plane_idx]

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

	var status: String = plane["status"]
	var route_suffix := ""
	if status == "flying":
		var r: Dictionary = GameState.routes[int(plane["assigned_route"])]
		route_suffix = "  (%s → %s)" % [r["origin"], r["destination"]]
	vbox.add_child(_lbl("Seats: %d  |  %s%s" % [plane["seats"], status.capitalize(), route_suffix], _status_color(status), 10))

	vbox.add_child(_sep())

	# Live flight progress — shown only when flying, updated in _process
	var prog_lbl := _lbl("", C_ACCENT, 10)
	prog_lbl.visible = (status == "flying")
	if status == "flying":
		var route: Dictionary = GameState.routes[int(plane["assigned_route"])]
		var pct := float(route["flight_progress"]) / float(route["flight_duration_sec"]) * 100.0
		prog_lbl.text = "En route  %s  %.0f%%" % [_bar(pct, 12), pct]
	_progress_labels[plane_idx] = prog_lbl
	vbox.add_child(prog_lbl)

	# Condition bar
	var cond: float = float(plane["condition"])
	var bar_color := C_GREEN if cond >= 80.0 else (C_YELLOW if cond >= 50.0 else C_RED)
	vbox.add_child(_lbl("Condition  %s  %.0f%%" % [_bar(cond), cond], bar_color, 10))

	var damage := 100.0 - cond
	var cost   := damage * float(plane["repair_cost_per_pct"])

	if status == "maintenance":
		# Live repair countdown — updated in _process
		var rep_lbl := _lbl("", C_YELLOW, 10)
		_repair_labels[plane_idx] = rep_lbl
		vbox.add_child(rep_lbl)
	elif cond >= 100.0:
		vbox.add_child(_lbl("No repairs needed", C_DIM, 10))
	else:
		# Repair button row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		vbox.add_child(hbox)

		var cost_lbl := _lbl("Repair to 100%%:  %s" % GameState.format_money(cost), C_YELLOW, 10)
		cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(cost_lbl)

		var can_afford := GameState.cash >= cost
		var btn := _action_btn("Repair", C_GREEN if can_afford else C_DIM)
		btn.disabled = not can_afford
		var p_idx := plane_idx
		btn.pressed.connect(func(): GameState.repair_plane(p_idx))
		hbox.add_child(btn)

	return m

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
	var s := ""
	for i in width:
		s += "█" if i < n else "░"
	return s
