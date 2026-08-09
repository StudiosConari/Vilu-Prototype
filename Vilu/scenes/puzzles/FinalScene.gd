extends Node3D

## Beat 8 — Cierre. Al entrar, reproduce el diálogo de cierre con el gancho
## narrativo y luego muestra la pantalla de FIN (volver al título).
##
## IMPORTANTE: el texto de abajo es PLACEHOLDER. Reemplazar con los diálogos de
## la historia del norte ya escritos (ver docs/NARRATIVA_TODO.md).

const BALLOON := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"
const CLOSING := "~ start
Narrador: Has alcanzado la cima. El viento del norte lo sabe.
Narrador: (PLACEHOLDER — reemplazar con los diálogos de la historia del norte.)
Narrador: Pero algo más te espera... aquí va el GANCHO FINAL de VILU.
=> END
"

var _shown := false


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_closing_ended)
	# Pequeña espera para que el jugador aterrice, luego arranca el cierre.
	get_tree().create_timer(0.6).timeout.connect(_start_closing)


func _start_closing() -> void:
	var res: Resource = DialogueManager.create_resource_from_text(CLOSING)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


func _on_closing_ended(_res: Resource) -> void:
	if _shown:
		return
	_shown = true
	_show_end_panel()


func _show_end_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.10, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 22)
	layer.add_child(vb)

	vb.add_child(_label("VILU", 96, Color(1.0, 0.85, 0.4)))
	vb.add_child(_label("FIN del prototipo", 34, Color(0.9, 0.9, 0.95)))
	vb.add_child(_label("El norte guarda algo más…", 24, Color(0.7, 0.85, 0.95)))

	var btn := Button.new()
	btn.text = "Volver al título"
	btn.custom_minimum_size = Vector2(320, 64)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn"))
	vb.add_child(btn)


func _label(txt: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l
