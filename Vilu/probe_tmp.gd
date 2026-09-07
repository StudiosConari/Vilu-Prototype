extends SceneTree
const JUEGO := preload("res://scenes/core/Game.gd")

class Espia extends Node:
	var veces := 0
	func _mandar_el_raton() -> void:
		veces += 1

func _init() -> void:
	var padre := Espia.new()
	var m: Node = JUEGO.MandoDelRaton.new()
	print("clase: ", m.get_class(), " process_mode=", m.process_mode)
	padre.add_child(m)
	root.add_child(padre)
	print("has_method en espia: ", padre.has_method("_mandar_el_raton"))
	print("is_processing: ", m.is_processing())
	await process_frame
	await process_frame
	await process_frame
	print("veces: ", padre.veces, " is_processing: ", m.is_processing())
	quit()
