extends "res://addons/gut/test.gd"

## Smoke test de la parte riesgosa del Beat 2: crear el recurso de diálogo en
## runtime (sin import de .dialogue) y que exista el balloon GDScript forzado.

func test_create_resource_from_text() -> void:
	var text := "~ start\nCarmen: Hola.\n=> END\n"
	var res: Resource = DialogueManager.create_resource_from_text(text)
	assert_not_null(res)

func test_gdscript_balloon_exists() -> void:
	assert_true(ResourceLoader.exists("res://addons/dialogue_manager/example_balloon/example_balloon.tscn"))
