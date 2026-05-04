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
var _finances_tap_count := 0
var _finances_tap_timer := 0.0
var _cheat_overlay: Control = null

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
		btn.pressed.connect(func(): _on_tab_pressed(idx))
		hbox.add_child(btn)
		_tab_btns.append(btn)

	return bar

func _on_tab_pressed(idx: int) -> void:
	_switch_tab(idx)
	if idx == 2:  # Finances tab
		_finances_tap_timer = 2.0
		_finances_tap_count += 1
		if _finances_tap_count >= 5:
			_finances_tap_count = 0
			_show_cheat_dialog()
	else:
		_finances_tap_count = 0

func _process(delta: float) -> void:
	if _finances_tap_timer > 0.0:
		_finances_tap_timer -= delta
		if _finances_tap_timer <= 0.0:
			_finances_tap_count = 0

func _show_cheat_dialog() -> void:
	if _cheat_overlay:
		return

	_cheat_overlay = Control.new()
	_cheat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cheat_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cheat_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.02, 0.08, 0.88)
	_cheat_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_cheat_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("#0d1525")
	cs.border_color = Color("#5090d8")
	cs.set_border_width_all(1)
	cs.content_margin_left = 14.0; cs.content_margin_right  = 14.0
	cs.content_margin_top  = 12.0; cs.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "ADD CASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#5090d8"))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var input := LineEdit.new()
	input.placeholder_text = "Amount (e.g. 100000)"
	input.add_theme_font_size_override("font_size", 12)
	input.add_theme_color_override("font_color", Color("#c0d0e8"))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("#060b15")
	input_style.border_color = Color("#1a2840")
	input_style.set_border_width_all(1)
	input_style.content_margin_left = 8.0; input_style.content_margin_right  = 8.0
	input_style.content_margin_top  = 6.0; input_style.content_margin_bottom = 6.0
	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_stylebox_override("focus",  input_style)
	vbox.add_child(input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var cancel_btn := _dialog_btn("Cancel", Color("#6a7c94"))
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func():
		_cheat_overlay.queue_free()
		_cheat_overlay = null
	)
	btn_row.add_child(cancel_btn)

	var confirm_btn := _dialog_btn("Add", Color("#38c870"))
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.pressed.connect(func():
		var amount := input.text.to_float()
		if amount > 0.0:
			GameState.cash += amount
			GameState.cash_changed.emit()
		_cheat_overlay.queue_free()
		_cheat_overlay = null
	)
	btn_row.add_child(confirm_btn)

	input.grab_focus()

func _dialog_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   color)
	btn.add_theme_color_override("font_pressed_color", color)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.15)
	s.border_color = color
	s.set_border_width_all(1)
	s.content_margin_left = 8.0; s.content_margin_right  = 8.0
	s.content_margin_top  = 6.0; s.content_margin_bottom = 6.0
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(color.r, color.g, color.b, 0.3)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", s)
	return btn

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
