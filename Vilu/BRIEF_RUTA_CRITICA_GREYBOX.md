# VILU — Brief de ruta crítica para Claude Code (greybox-first, sin arte)

**Objetivo:** dejar el MVP jugable de punta a punta (los 8 beats) usando **placeholders y primitivas de Godot**, de modo que el arte final de Ari se pueda **swapear más tarde sin tocar código ni romper escenas**. El código NUNCA espera al arte.

**Contexto del proyecto (estado real hoy):**
- Godot **4.7** .NET (Forward+). `config/name="EmiliaGame"`, `assembly_name="EmiliaGame"` → hay que rebrandear a **VILU**.
- Escena principal actual: `res://scenes/TitleScreen.tscn`.
- Scripts existentes en `scenes/`: `Player`, `Enemy`, `Guanaco`, `Arrow`, `Projectile`, `LavaPatch`, `VineField`, `Pickup`, `DamageNumber`, `PauseMenu`, `Save` (autoload), `Sfx` (autoload), `Main`, `TitleScreen`.
- Escenas de enemigos ya existen: `scenes/enemies/EnemyNormal.tscn`, `EnemyFast.tscn`, `EnemyBig.tscn`, `EnemyRanged.tscn`, `BossGuardian.tscn`.
- Addons activos: **beehave** (árboles de comportamiento IA), **dialogue_manager** (diálogos), **gut** (tests), **godot_mcp** (Godot MCP Pro).
- Modelos disponibles en `models/`: rigs "benja_*", animaciones Mixamo "mix_*", `guanaco.fbx`, `wings.fbx`. Los protagonistas **se quedan en su rig actual (no re-riggear)**.

---

## 0. Principios de trabajo (no negociables)

1. **Greybox primero.** Todo asset visual ausente se representa con una primitiva (`BoxMesh`, `CapsuleMesh`, `CylinderMesh`, `SphereMesh`) o un `CSGBox3D`, con un color plano por categoría. La jugabilidad debe existir y ser testeable aunque todo se vea gris.
2. **Contrato de nombres = cuello de botella #1.** Antes de crear cualquier escena de personaje/criatura/prop, se fija la convención de nombres, escala, pivote y orientación (ver §2). El arte entra reemplazando el nodo visual, no la escena entera.
3. **Placeholder = escena, no nodo suelto.** Cada actor es su propia escena (`.tscn`) con una estructura fija. El "arte" es un único nodo hijo (`Visual`) que se reemplaza después.
4. **Lo más riesgoso, primero y en paralelo.** El **ascenso cooperativo del Ojos del Salado** se prototipa en Semana 1 con plan B lineal por turnos.
5. **Sin pulido visual.** Nada de iluminación bonita, materiales, post-proceso ni cámara cinematográfica hasta que el loop completo sea jugable.
6. **Cada beat cierra con criterio "jugable"** (ver §5, Definition of Done por beat).

---

## 1. Fase 0 — Higiene y rebrand (bloquea todo lo demás, hacer primero)

Orden exacto para Claude Code:

1. **Rebrand a VILU** en `project.godot`:
   - `config/name="VILU"` y `[dotnet] project/assembly_name="VILU"` (ojo: cambiar assembly renombra la DLL; verificar que el proyecto siga compilando en .NET y ajustar referencias si algo apunta a `EmiliaGame`).
   - Buscar en todo el repo strings "Emilia"/"EmiliaGame" visibles al jugador (títulos, UI, ventana) y reemplazar por VILU. Dejar registro de lo cambiado.
2. **Aparcar el "modo arena muerto"**: identificar escenas/scripts del prototipo viejo que no forman parte de los 8 beats y moverlos a `scenes/_deprecated/` (no borrar), para que no estorben ni compilen a la ruta crítica.
3. **Backbone de escenas del MVP** (ver §3): crear la estructura de carpetas y las escenas vacías/greybox que sostienen el viaje.
4. **Sanidad de build**: confirmar que el proyecto abre sin errores en Godot 4.7 .NET, que los 4 plugins cargan, y que `TitleScreen` → nueva escena de juego arranca.
5. **Git**: confirmar repo limpio, hacer commit de la fase 0 con mensaje claro (`chore: rebrand EmiliaGame→VILU + higiene de proyecto`). A partir de aquí, **un commit por beat**.

> Nota entorno: el MCP de Godot solo funciona desde Claude Code (lee `.mcp.json`) con Godot abierto y el plugin `godot_mcp` activo. `CLAUDE_CODE_GIT_BASH_PATH` = `D:\GameDev\Github\Git\bin\bash.exe`.

---

## 2. Contrato de nombres e imports (definir ANTES de crear actores)

Esto es lo que permite que Ari swapee arte sin romper nada. Claude Code debe dejarlo escrito en `docs/ART_SWAP_CONTRACT.md` y respetarlo en cada escena.

**Estructura fija de toda escena de actor** (personaje, enemigo, criatura, NPC):

```
Actor (CharacterBody3D)          # lógica, script, colisión, nombre estable
├── Collision (CollisionShape3D) # capsula/caja de gameplay — NO depende del arte
├── Visual (Node3D)              # <-- ÚNICO punto de swap de arte
│   └── Placeholder (MeshInstance3D)   # primitiva gris; Ari reemplaza este subárbol
├── AnimationPlayer              # nombres de animación estándar (ver abajo)
└── (marcadores) Muzzle/Hand/Head (Marker3D)  # puntos de anclaje estables
```

**Reglas del contrato:**
- **Escala y orientación:** 1 unidad = 1 metro. Personajes miran a **−Z**. Pivote en los pies (origen a ras de suelo).
- **El swap toca solo `Visual/`.** El código referencia `Collision`, `AnimationPlayer` y los `Marker3D`, nunca la malla del arte.
- **Nombres de animación estándar** que el código invoca (aunque el placeholder no anime): `idle`, `walk`, `run`, `attack`, `hit`, `death`, `draw`, `shoot`. Cuando llegue el rig real, se mapean a estos nombres o a un `AnimationTree` con los mismos estados.
- **Rutas de recurso estables** para materiales/placeholder: `res://art_placeholders/` (ver §4). El arte final entra en `models/` y se conecta en `Visual/`, sin cambiar la ruta de la escena.
- **IDs de contenido estables:** cada enemigo/criatura/NPC/región tiene un nombre canónico (ej. `minero_corrupto`, `cazador`, `yastay`, `alicanto`, `guardian_isluga`, `guardian_ojos`, `carmen`) usado en nombres de escena, diálogos y spawns.

Claude Code debe entregar esta tabla acordada con Coen antes de modelar nada.

---

## 3. Arquitectura y backbone de escenas

Carpetas objetivo:

```
scenes/
  core/        GameManager, TravelManager, escena raíz de juego
  regions/     Region1_Tarapaca.tscn, Region2_Volcan.tscn (greybox)
  actors/      Player, NPCs, criaturas (escenas con contrato §2)
  enemies/     (ya existe) reusar EnemyNormal/Fast/Big/Ranged/BossGuardian
  puzzles/     Isluga.tscn, AscensoOjos.tscn
  ui/          HUD, PauseMenu, DialogueBalloon
dialogue/      *.dialogue (dialogue_manager)
art_placeholders/  materiales y mallas grises reutilizables
```

**Sistemas núcleo a construir con placeholders:**

- **`TravelManager` (viaje entre 2 volcanes):** máquina de estados simple que carga `Region1` → transición → `Region2`, preservando estado del jugador (habilidades desbloqueadas, progreso de beat) vía el autoload `Save`. La "transición de viaje" puede ser un fundido a negro + pantalla de texto; sin cinemática.
- **`GameManager` (autoload o nodo raíz):** lleva el índice de beat actual (0–7), banderas de habilidades (`has_bow`, `has_wings`, `has_guanaco`), y expone señales para avanzar de beat. Persistir con `Save`.
- **HUD mínimo:** vida, indicador de habilidad activa, prompt de interacción. Cajas y `Label`, sin arte.

---

## 4. Cómo representar cada asset ausente (recetas de placeholder)

Crear en `art_placeholders/` un set de materiales de color plano y reutilizarlos por categoría (lectura instantánea de qué es cada cosa):

| Categoría | Primitiva | Color placeholder |
|---|---|---|
| Jugador / protagonistas | Capsule | Azul |
| NPC (Carmen, aliados) | Capsule | Verde |
| Enemigo cuerpo a cuerpo (minero) | Capsule | Rojo |
| Enemigo a distancia / cazador | Capsule | Naranja |
| Criatura (Yastay, Alicanto) | Box alargada + alas caja | Morado |
| Jefe / Guardián | Capsule grande | Magenta |
| Prop interactuable / palanca | Box | Amarillo |
| Zona de puzzle / trigger | Área con `CSGBox3D` translúcido | Cian |
| Coleccionable / pickup | Sphere | Dorado |
| Terreno región | `CSGBox3D` / plano + `GridMap` opcional | Gris |

- **Animación:** si el placeholder necesita "feedback", usar tween de escala/posición (ej. squash al atacar) o cambio de color al recibir daño, en vez de animación de rig. Los nombres de estado siguen el contrato §2.
- **Enemigos:** reutilizar directamente `scenes/enemies/*.tscn` existentes, re-skinneando solo el color/rol; no crear enemigos nuevos si uno existente sirve para minero/cazador.
- **`Guanaco.gd`, `wings.fbx`:** las habilidades (montar guanaco, planear con alas) se implementan como **cambios de estado del jugador** (velocidad, salto, gravedad, capacidad de cruzar huecos), no como arte. El guanaco/alas pueden ser cajas ancladas al `Visual` del jugador.

---

## 5. Los 8 beats — greybox en orden de ruta crítica

Para cada beat: **construir la mecánica, no el arte.** Definition of Done = "un tester puede completar el beat con teclado y llegar al siguiente".

**Beat 1 — Apertura explorable (Tarapacá / Región 1).**
- Región 1 en greybox (suelo `CSGBox3D`, límites, un par de props amarillos).
- Player camina/corre/salta. Cámara funcional (seguimiento simple).
- DoD: recorrer la zona y llegar al NPC Carmen.

**Beat 2 — La Tirana entrega arco + combos (Carmen).**
- NPC `carmen` con `dialogue_manager`: diálogo que **desbloquea `has_bow`** (bandera en GameManager).
- Sistema de arco: apuntar, `draw`→`shoot`, instanciar `Arrow`/`Projectile` existentes. Combos de melee básicos (cadena de 2–3 golpes con ventana de input).
- DoD: tras hablar con Carmen, el jugador dispara flechas y encadena combos.

**Beat 3 — Mineros corruptos (arena de combate).**
- Arena greybox. Spawnear `EnemyNormal`/`EnemyBig` como `minero_corrupto` (color rojo). IA con beehave: perseguir + atacar.
- Usar `DamageNumber` y `Sfx` existentes para feedback.
- DoD: el jugador derrota la oleada y se abre la salida.

**Beat 4 — Prueba de Isluga (puzzle: combo exacto + flecha sincronizada).**
- `puzzles/Isluga.tscn`: mecanismo que exige una **secuencia exacta** (input de combo) y una **flecha sincronizada** a un objetivo temporizado. Palancas/targets como cajas amarillas.
- Guardián de Isluga como gate (BossGuardian reusado si aplica).
- DoD: resolver la secuencia abre el paso al viaje de volcán.

**Beat 5 — Ascenso del Ojos del Salado (puzzle cooperativo — EL MÁS RIESGOSO, prototipar en Semana 1 en paralelo).**
- `puzzles/AscensoOjos.tscn`: mecánica cooperativa (dos personajes / dos acciones coordinadas para escalar).
- **Plan B obligatorio:** versión **lineal por turnos** si la coordinación en tiempo real no cuaja bajo plazo. Implementar el plan B primero como red de seguridad.
- DoD: se puede completar el ascenso de principio a fin (aunque sea con el plan B).

**Beat 6 — Viaje de volcán → Región 2 + Alicanto/Yastay + cazadores.**
- `TravelManager` transiciona a Región 2 (greybox: desierto/oasis/cumbre como cajas de distinta altura).
- Habilidades: **alas (`has_wings`, planeo)** y **guanaco (`has_guanaco`, montura)** desbloqueadas por criaturas `alicanto`/`yastay`.
- Escaramuza de cazadores (EnemyRanged/Fast recoloreados).
- DoD: cruzar a Región 2, obtener alas+guanaco, superar a los cazadores usando esas habilidades.

**Beat 7 — Ascenso cooperativo / progresión de cumbre.**
- Encadenar habilidades (alas + guanaco + arco) en un tramo de plataformeo/puzzle de cumbre. Reusar mecánicas de los beats 4/5.
- DoD: llegar a la cima.

**Beat 8 — Cierre con el gancho + integración.**
- Integrar diálogos de historia del norte (ya escritos) en las pantallas del slice vía `dialogue_manager`.
- Pantalla/diálogo de cierre con el hook narrativo.
- Primer arte + audio que llegue se **swapea** en `Visual/` y buses de `Sfx`.
- **Export + prueba en máquina limpia.**
- DoD: build exportado, jugable de punta a punta, la ventana y los textos dicen **VILU**.

---

## 6. Orden de ataque recomendado para Claude Code

1. **Fase 0** (higiene + rebrand + backbone + git).
2. **Contrato de nombres §2** escrito y acordado (`docs/ART_SWAP_CONTRACT.md`).
3. **Núcleo jugable:** Player (mover/saltar/cámara) + GameManager + un HUD mínimo.
4. **Sistemas de habilidad:** arco/combos → alas → guanaco (como estados, §4).
5. **Combate:** cablear enemigos existentes con beehave (beats 3 y 6).
6. **Puzzles:** Isluga (beat 4) y **Ascenso Ojos con plan B primero** (beat 5, en paralelo desde el inicio).
7. **Viaje + Región 2** (TravelManager, beat 6).
8. **Diálogos + cierre** (beats 2, 8) y costura narrativa.
9. **Swap de arte/audio a medida que llega** + **export + prueba limpia**.

Regla de corte (del plan): si a mitad de Semana 3 el MVP no está sólido, **congelar expansión y pulir MVP**. Un MVP pulido puntúa más que un ideal a medias.

---

## 7. Testing y verificación (usar el addon gut)

- Escribir tests gut para la lógica que no depende de arte: máquina de estados de `TravelManager`, banderas de `GameManager`/`Save`, desbloqueo de habilidades, resolución de secuencia de Isluga, condición de victoria del ascenso.
- Correr gut en modo headless en CI local antes de cada commit de beat.
- **Doble check de coherencia antes de cualquier export:** que el build diga **VILU** (no "Emilia") en ventana, título y UI; que no queden referencias a `EmiliaGame` visibles.

---

## 8. Qué NO hacer

- No re-riggear a los protagonistas (se quedan en su rig actual).
- No esperar arte para avanzar un beat.
- No pulir iluminación/materiales/cámara antes de tener el loop completo.
- No borrar el modo arena viejo (aparcarlo en `_deprecated/`).
- No cambiar la estructura `Actor/Visual/…` del contrato una vez fijada (rompe los swaps de Ari).
```
