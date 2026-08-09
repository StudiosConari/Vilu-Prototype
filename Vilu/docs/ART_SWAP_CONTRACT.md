# VILU — Contrato de nombres e imports (Art Swap Contract)

> **Estado:** PROPUESTA para acuerdo con Coen/Ari. Una vez aprobado, la
> estructura `Actor / Visual / …` **no se cambia** (rompería los swaps de arte).
> Fijado en Fase 0. Todo actor nuevo debe respetarlo.

Este contrato es el que permite que **Ari reemplace el arte sin tocar código ni
romper escenas**. El código nunca espera al arte: todo se prototipa en greybox.

---

## 1. Estructura fija de toda escena de actor

Personaje jugable, enemigo, criatura, NPC y jefe usan **la misma estructura**.
Plantilla canónica: [`scenes/actors/_TEMPLATE_Actor.tscn`](../scenes/actors/_TEMPLATE_Actor.tscn)
(duplícala para crear cada actor nuevo).

```
Actor (CharacterBody3D)           # lógica, script, nombre estable
├── Collision (CollisionShape3D)  # cápsula/caja de gameplay — NO depende del arte
├── Visual (Node3D)               # <-- ÚNICO punto de swap de arte
│   └── Placeholder (MeshInstance3D)   # primitiva gris; Ari reemplaza este subárbol
├── AnimationPlayer               # nombres de animación estándar (§4)
├── Muzzle (Marker3D)             # boca de disparo / origen de proyectil (-Z)
├── Hand  (Marker3D)              # ancla de objeto en mano (arco, arma)
└── Head  (Marker3D)              # ancla de cabeza (UI, efectos)
```

## 2. Reglas del contrato (no negociables una vez fijado)

1. **Escala y orientación:** 1 unidad = **1 metro**. Los personajes miran a
   **−Z**. **Pivote en los pies**: el origen del `Actor` queda a ras de suelo
   (la cápsula se centra en `y = altura/2`).
2. **El swap toca SOLO `Visual/`.** El arte final reemplaza el subárbol
   `Visual/Placeholder`. El código referencia `Collision`, `AnimationPlayer` y
   los `Marker3D` — **nunca** la malla del arte.
3. **Nombres de nodo estables:** `Actor`, `Collision`, `Visual`,
   `AnimationPlayer`, `Muzzle`, `Hand`, `Head`. No renombrar.
4. **El arte final entra en `models/`** y se conecta dentro de `Visual/`, **sin
   cambiar la ruta de la escena** del actor.
5. **No re-riggear a los protagonistas** — se quedan en su rig actual
   (`models/benja_*`, animaciones `mix_*`).

## 3. Nombres de animación estándar

El código invoca estos nombres aunque el placeholder no anime. Cuando llegue el
rig real, se mapean a estos nombres (o a un `AnimationTree` con los mismos
estados):

| Estado   | Cuándo |
|----------|--------|
| `idle`   | Quieto |
| `walk`   | Caminando |
| `run`    | Corriendo (Shift) |
| `attack` | Golpe melee / combo |
| `hit`    | Recibe daño |
| `death`  | Muere |
| `draw`   | Tensar arco (arquero) |
| `shoot`  | Soltar flecha (arquero) |

**Feedback sin rig:** mientras no haya animación, usar `Tween` de escala/posición
(ej. squash al atacar) o cambio de color al recibir daño. Los **nombres de estado
siguen siendo los de arriba**.

## 4. Recetas de placeholder (materiales en `art_placeholders/`)

Un material de color plano por categoría → lectura instantánea de qué es cada
cosa. Archivos `.tres` ya creados:

| Categoría | Primitiva | Color | Material |
|-----------|-----------|-------|----------|
| Jugador / protagonistas | Capsule | Azul | `mat_player.tres` |
| NPC (Carmen, aliados) | Capsule | Verde | `mat_npc.tres` |
| Enemigo cuerpo a cuerpo (minero) | Capsule | Rojo | `mat_enemy_melee.tres` |
| Enemigo a distancia / cazador | Capsule | Naranja | `mat_enemy_ranged.tres` |
| Criatura (Yastay, Alicanto) | Box + alas | Morado | `mat_creature.tres` |
| Jefe / Guardián | Capsule grande | Magenta | `mat_boss.tres` |
| Prop interactuable / palanca | Box | Amarillo | `mat_prop.tres` |
| Zona de puzzle / trigger | CSGBox3D translúcido | Cian | `mat_trigger.tres` |
| Coleccionable / pickup | Sphere | Dorado | `mat_pickup.tres` |
| Terreno región | CSGBox3D / plano | Gris | `mat_terrain.tres` |

## 5. IDs de contenido canónicos

Nombre estable usado en **nombres de escena, diálogos y spawns**. No cambiar.

| ID canónico | Qué es | Beat |
|-------------|--------|------|
| `carmen` | NPC — La Tirana; entrega el arco | 2 |
| `minero_corrupto` | Enemigo melee (reusa `EnemyNormal`/`EnemyBig`) | 3 |
| `cazador` | Enemigo a distancia (reusa `EnemyRanged`/`EnemyFast`) | 6 |
| `guardian_isluga` | Gate/jefe de la prueba de Isluga (reusa `BossGuardian`) | 4 |
| `guardian_ojos` | Gate del ascenso del Ojos del Salado | 5 |
| `yastay` | Criatura — otorga habilidad guanaco (`has_guanaco`) | 6 |
| `alicanto` | Criatura — otorga habilidad alas (`has_wings`) | 6 |

Regiones: `Region1_Tarapaca`, `Region2_Volcan` (registradas en `TravelManager`).

## 6. Habilidades = estados, no arte

`has_bow`, `has_wings`, `has_guanaco` son **banderas en `GameManager`**
(persistidas por `Save`). Las habilidades se implementan como **cambios de estado
del jugador** (velocidad, salto, gravedad, cruzar huecos), **no** como arte:

- **Alas (planeo):** el guanaco/alas pueden ser cajas ancladas al `Visual/` del
  jugador; el efecto es menor gravedad al mantener salto.
- **Guanaco (montura):** caja anclada + más velocidad/salto.

## 7. Layout de carpetas

```
scenes/
  core/        GameManager, TravelManager, Game.tscn (raíz jugable)
  regions/     Region1_Tarapaca.tscn, Region2_Volcan.tscn (greybox)
  actors/      _TEMPLATE_Actor.tscn + Player, NPCs, criaturas
  enemies/     (existente) EnemyNormal/Fast/Big/Ranged/BossGuardian
  puzzles/     Isluga.tscn, AscensoOjos.tscn
  ui/          HUD, PauseMenu, DialogueBalloon
  _deprecated/ prototipo arena viejo (Main.*) — NO borrar, no compilar a la ruta crítica
dialogue/          *.dialogue (dialogue_manager)
art_placeholders/  materiales grises reutilizables
docs/              este contrato
```
