# Vilu — Setup del MCP de Godot y addons

Guía de arranque para el proyecto tras formatear el PC. Sigue los pasos en orden.
Entorno detectado: **Godot 4.5 (Forward+)**, ejecutable en `D:\GameDev\Motores\Godot\Godot.exe`, proyecto en `D:\GitHub\Vilu-Prototype\Vilu`.

## 1. Prerequisitos a instalar (PC recién formateado)

- **Node.js 24 LTS o superior** — necesario para el servidor MCP. Descárgalo de https://nodejs.org (instalador Windows x64). Verifica en una terminal nueva: `node --version` (debe decir v24 o mayor).
- **Godot 4.5** — ya lo tienes en `D:\GameDev\Motores\Godot\Godot.exe`. No hace falta añadirlo al PATH: el `.mcp.json` ya apunta a esa ruta con `GODOT_PATH`.
- **Git** (opcional, para el repo) — https://git-scm.com.

## 2. Instalar los addons

Los addons vienen en `Vilu-addons.zip`. Extráelo en la **raíz del proyecto** (`D:\GitHub\Vilu-Prototype\Vilu`), de modo que quede la carpeta `addons\` junto a `project.godot`:

```
Vilu\
  addons\
    beehave\
    dialogue_manager\
    gut\
    phantom_camera\
  project.godot
  .mcp.json
```

Ya dejé `project.godot` con los cuatro plugins **habilitados** y el autoload de Dialogue Manager configurado, así que al abrir el proyecto en Godot deberían aparecer activos en `Project > Project Settings > Plugins`. La primera vez Godot reimportará los assets de los addons (es normal que tarde unos segundos).

> Si algún plugin muestra un error al abrir (por ser Godot 4.5 muy nuevo), desactívalo y actívalo de nuevo en `Project Settings > Plugins`, o actualízalo desde la Godot Asset Store.

## 3. Activar el MCP (better-godot-mcp)

**Coloca el `.mcp.json` manualmente** en la raíz del proyecto (por seguridad, la app no permite que Claude escriba archivos `.mcp.json` de forma remota). Descárgalo del chat, o crea `D:\GitHub\Vilu-Prototype\Vilu\.mcp.json` con este contenido exacto:

```json
{
  "mcpServers": {
    "better-godot-mcp": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@n24q02m/better-godot-mcp@latest"],
      "env": {
        "GODOT_PROJECT_PATH": "D:\\GitHub\\Vilu-Prototype\\Vilu",
        "GODOT_PATH": "D:\\GameDev\\Motores\\Godot\\Godot.exe"
      }
    }
  }
}
```

Este servidor **better-godot-mcp** aporta 17 herramientas para crear/editar escenas, nodos, scripts, shaders, física, animación y UI escribiendo archivos directamente. Ya trae puestas las rutas `GODOT_PROJECT_PATH` y `GODOT_PATH`, no necesitas cambiarlas.

Luego:

1. Cierra y vuelve a abrir la app de Claude / la tarea de Cowork sobre esta carpeta.
2. Al detectar el `.mcp.json`, la app pedirá aprobar el servidor MCP del proyecto: acéptalo.
3. La primera vez, `npx` descargará el paquete `@n24q02m/better-godot-mcp` automáticamente (requiere Node 24+ y conexión a internet).

## 4. Addons instalados y para qué sirven

| Addon | Versión | Uso en Vilu |
|-------|---------|-------------|
| **Phantom Camera** | 0.11.0.3 | Sistema de cámara 2D/3D estilo Cinemachine: seguimiento del Player, transiciones suaves, encuadres por zona. Ideal para el juego de acción. |
| **Beehave** | 2.9.2 | Árboles de comportamiento (Behavior Trees) para la IA de enemigos (`Enemy.gd`, `Guanaco.gd`): patrullar, perseguir, atacar, huir, de forma modular y depurable. |
| **GUT** | 9.6.1 | Framework de tests unitarios para GDScript. Permite verificar la lógica (daño, guardado, pickups) de forma automática. |
| **Dialogue Manager** | 3.10.1 | Sistema de diálogos no lineal con su propio lenguaje de guion; autoload `DialogueManager` ya configurado. Para NPCs, tutorial e historia. |

Notas:
- La física 3D usa **Jolt**, que en Godot 4.5 ya viene integrado en el motor — no hace falta addon aparte.
- Beehave trae su propio panel de depuración de árboles; GUT añade un panel inferior "GUT" para correr tests.

## 5. Verificación rápida

1. `node --version` → v24+.
2. Abre el proyecto en Godot: `Project Settings > Plugins` muestra los 4 plugins **Enabled**, sin errores en la consola de salida.
3. En la app de Claude, el servidor `better-godot-mcp` aparece conectado y sus herramientas responden (p. ej. listar escenas del proyecto).

Cuando esté todo, puedes borrar `Vilu-addons.zip` del proyecto.
