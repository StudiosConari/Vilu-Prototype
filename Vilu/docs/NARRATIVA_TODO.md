# VILU — Puntos de integración de la narrativa (Beat 8)

Los diálogos del prototipo son **PLACEHOLDER**. Reemplazar con los diálogos de
la historia del norte ya escritos. Todos usan el formato de `dialogue_manager`
y se crean en runtime (no hace falta importar `.dialogue`):

```
~ start
Personaje: Línea de diálogo.
Personaje: Otra línea.
=> END
```

## Dónde está cada texto

| Momento | Archivo | Constante |
|---------|---------|-----------|
| Carmen — entrega el arco (Beat 2) | `scenes/actors/CarmenNPC.gd` | `DIALOGUE_INTRO`, `DIALOGUE_AGAIN` |
| Alicanto / Yastay — otorgan dones (Beat 6) | `scenes/actors/AbilityGiver.gd` | banners en `_on_interacted` / `_label` |
| Cierre + gancho narrativo (Beat 8) | `scenes/puzzles/FinalScene.gd` | `CLOSING` |
| Banners de puzzle/arena/cima | respectivos `*.gd` (`_banner(...)`) | strings inline |

## Notas
- Para diálogos largos o ramificados, se puede migrar a archivos `.dialogue`
  reales en `dialogue/` (requiere abrir el editor para importarlos) y
  `preload("res://dialogue/xxx.dialogue")` en vez de `create_resource_from_text`.
- El balloon usado es el GDScript del addon (`example_balloon.tscn`); si se
  quiere un balloon propio, crearlo y cambiar la ruta `BALLOON` en los scripts.
- Avanzar de beat y desbloquear habilidades es lógica (GameManager), separada
  del texto: se puede reescribir todo el diálogo sin tocar la progresión.
