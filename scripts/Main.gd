extends Control

const PANEL_PATHS := [
	"res://scripts/panels/FleetPanel.gd",
	"res://scripts/panels/RoutesPanel.gd",
	"res://scripts/panels/FinancesPanel.gd",
]
const TAB_NAMES := ["Fleet", "Routes", "Finances"]

const C_BG      := Color("#080d1a")
const C_BAR     := Color("#060b15")
const C_BORDER  := Color("#1a2840")
const C_TAB_ON  := Color("#183060")
const C_TAB_OFF := Color("#0a1428")
const C_TEXT    := Color("#c0d0e8")
const C_DIM     := Color("#6a7c94")
const C_ACCENT  := Color("#5090d8")
const C_GOLD    := Color("#e8b830")

var _panels := []
var _tab_btns := []
var _cash_lbl: Label
var _speed_btn: Button

func _ready() -> void:
	_build()
	_switch_tab(0)
	GameState.cash_changed.connect(_refresh_cash)

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	vbox.add_child(_make_top_bar())

	var content := _make_content()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	vbox.add_child(_make_tab_bar())

func _make_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 32)
	bar.add_theme_stylebox_override("panel", _flat(C_BAR, C_BORDER, 0, 0, 1, 0))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	bar.add_child(hbox)

	_spacer(hbox, 8)

	var name_lbl := _lbl(GameState.airline_name, C_ACCENT, 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_lbl)

	_cash_lbl = _lbl("", C_GOLD, 11)
	_cash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_cash_lbl)

	_spacer(hbox, 6)

	_speed_btn = Button.new()
	_speed_btn.text = "1×"
	_speed_btn.flat = true
	_speed_btn.add_theme_font_size_override("font_size", 12)
	_speed_btn.add_theme_color_override("font_color", C_DIM)
	_speed_btn.add_theme_color_override("font_hover_color", C_TEXT)
	_speed_btn.add_theme_color_override("font_pressed_color", C_TEXT)
	var sp_s := StyleBoxFlat.new()
	sp_s.bg_color = Color(0, 0, 0, 0)
	sp_s.content_margin_left = 4.0; sp_s.content_margin_right  = 4.0
	sp_s.content_margin_top  = 0.0; sp_s.content_margin_bottom = 0.0
	_speed_btn.add_theme_stylebox_override("normal",  sp_s)
	_speed_btn.add_theme_stylebox_override("hover",   sp_s)
	_speed_btn.add_theme_stylebox_override("pressed", sp_s)
	_speed_btn.pressed.connect(_on_speed_pressed)
	hbox.add_child(_speed_btn)

	_spacer(hbox, 8)
	_refresh_cash()
	return bar

func _on_speed_pressed() -> void:
	GameState.cycle_speed()
	var spd := int(GameState.time_scale)
	_speed_btn.text = "%d×" % spd
	var color := C_ACCENT if spd > 1 else C_DIM
	_speed_btn.add_theme_color_override("font_color", color)

func _make_content() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.clip_contents = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	c.add_child(bg)

	for path in PANEL_PATHS:
		var panel := Control.new()
		panel.set_script(load(path))
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		c.add_child(panel)
		_panels.append(panel)

	return c

func _make_tab_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.add_theme_stylebox_override("panel", _flat(C_BAR, C_BORDER, 1, 0, 0, 0))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	bar.add_child(hbox)

	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 12)
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))
		hbox.add_child(btn)
		_tab_btns.append(btn)

	return bar

func _switch_tab(idx: int) -> void:
	for i in _panels.size():
		_panels[i].visible = (i == idx)
	for i in _tab_btns.size():
		var btn: Button = _tab_btns[i]
		var on := (i == idx)
		var s := _flat(
			C_TAB_ON  if on else C_TAB_OFF,
			C_ACCENT  if on else C_BORDER,
			2, 0, 0, 0
		)
		var color := C_ACCENT if on else C_DIM
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_color_override("font_color",         color)
		btn.add_theme_color_override("font_hover_color",   color)
		btn.add_theme_color_override("font_pressed_color", color)

func _refresh_cash() -> void:
	if _cash_lbl:
		_cash_lbl.text = GameState.format_money(GameState.cash)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _flat(bg: Color, border: Color, top: int, right: int, bottom: int, left: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_top    = top
	s.border_width_right  = right
	s.border_width_bottom = bottom
	s.border_width_left   = left
	return s

func _lbl(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

func _spacer(parent: Control, px: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 0)
	parent.add_child(c)
