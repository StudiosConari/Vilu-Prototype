extends CanvasLayer

# Menu de pausa (Esc): Reanudar / Opciones (volumen) / Menu principal.
# Funciona con el arbol en pausa (process_mode = ALWAYS).

var _root: Control
var _options: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	visible = false


func _unhandled_input(e: InputEvent) -> void:
	var toggle := false
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		toggle = true
	elif e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		toggle = true
	if toggle:
		if _options.visible:
			_options.visible = false
		else:
			_toggle()


func _toggle() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	visible = p
	if not p:
		_options.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	cc.add_child(vb)
	vb.add_child(_lbl("PAUSA", 58))
	vb.add_child(_btn("Reanudar", func(): _toggle()))
	vb.add_child(_btn("Opciones", func(): _options.visible = true))
	vb.add_child(_btn("Menu principal", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")))
	_build_options()


func _build_options() -> void:
	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	_root.add_child(_options)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	_options.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	cc.add_child(vb)
	vb.add_child(_lbl("OPCIONES", 44))
	vb.add_child(_slider("Musica", Save.music_vol, Save.set_music_vol, false))
	vb.add_child(_slider("Efectos", Save.sfx_vol, Save.set_sfx_vol, true))
	vb.add_child(_btn("Volver", func(): _options.visible = false))


func _lbl(txt: String, fsize: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(420, 58)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	return b


func _slider(row_name: String, value: float, cb: Callable, preview: bool) -> Control:
	var row := VBoxContainer.new()
	var l := Label.new()
	l.text = row_name
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(420, 32)
	s.value_changed.connect(func(v):
		cb.call(v)
		if preview:
			Sfx.play("hit", -4.0))
	row.add_child(s)
	return row
