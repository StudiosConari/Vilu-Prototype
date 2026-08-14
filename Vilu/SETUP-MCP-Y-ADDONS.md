# Vilu — Setup del MCP de Godot y addons

Estado verificado el **9 de agosto de 2026** directamente en el PC.

Entorno real detectado:

| Elemento | Valor |
|---|---|
| Godot | **4.7.1.stable.official** en `D:\GameDev\Motores\Godot\Godot.exe` |
| Proyecto | `D:\GitHub\Vilu-Prototype\Vilu` |
| Node.js | **v24.19.0** |
| npm / npx | **11.17.0** |
| Servidor MCP | `@n24q02m/better-godot-mcp` **v1.21.0** (instalado global) |

## 1. Estado actual

Todo lo que depende de esta máquina está **listo**:

- Node 24 instalado y funcionando.
- `Godot.exe` existe en la ruta que declara el `.mcp.json`.
- El paquete `@n24q02m/better-godot-mcp` está instalado globalmente, así que `npx` arranca al instante (sin descarga en frío).
- `better-godot-mcp doctor` da **todo OK**: detecta el binario de Godot, la versión 4.7.1 y el proyecto.

Lo único que falta es del lado de la **app de Claude**: debe cargar el `.mcp.json` del proyecto. Eso ocurre al reiniciar la app y aprobar el servidor MCP cuando lo pida.

## 2. El `.mcp.json` (correcto, no tocar)

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

Por seguridad la app no permite que Claude escriba archivos `.mcp.json` de forma remota; este ya está colocado manualmente y es correcto.

## 3. Cómo activarlo

1. Cierra y vuelve a abrir la app de Claude sobre esta carpeta.
2. Acepta el aviso de aprobación del servidor MCP del proyecto.
3. Comprueba que responde pidiendo, por ejemplo, la lista de escenas del proyecto.

## 4. Aviso importante: el addon `godot_mcp` está DESACTIVADO

En el proyecto había instalado el addon **"Godot MCP Pro" v1.16.0**. Es un producto **distinto** de `better-godot-mcp`:

- Godot MCP Pro es un addon que abre un **WebSocket hacia los puertos 6505–6514** esperando su propio servidor Node.
- Ese servidor **no está instalado ni existe en npm** (`godot-mcp-pro` da 404). El ZIP descargado en `Descargas\godot-mcp-pro-4d5f491c...` está **vacío** (0 archivos), solo trae la carpeta.
- Resultado medido con `netstat`: Godot lanzaba 10 conexiones en estado `SYN_SENT` a los puertos 6505–6514 sin nadie escuchando, reintentando en bucle indefinidamente.

Por eso lo he desactivado en `project.godot`:

- Quitado `res://addons/godot_mcp/plugin.cfg` de `[editor_plugins] enabled`.
- Quitados los 3 autoloads `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`.

Los archivos del addon siguen en `addons/godot_mcp/`, así que **es reversible**: si algún día consigues el servidor de Godot MCP Pro, basta con volver a activar el plugin en `Project > Project Settings > Plugins` y restaurar los tres autoloads.

`better-godot-mcp` **no necesita ningún addon**: escribe los archivos `.tscn` / `.gd` directamente e invoca el binario de Godot. Sus 17 herramientas funcionan con el editor abierto o cerrado.

## 5. Addons activos

| Addon | Uso en Vilu |
|-------|-------------|
| **Beehave** | Árboles de comportamiento para la IA de enemigos (`Enemy.gd`, `Guanaco.gd`): patrullar, perseguir, atacar, huir. Trae panel de depuración propio. |
| **GUT** | Tests unitarios de GDScript (daño, guardado, pickups). Añade un panel inferior "GUT". |
| **Dialogue Manager** | Diálogos no lineales con lenguaje de guion propio; autoload `DialogueManager` configurado. Para NPCs, tutorial e historia. |
| ~~Godot MCP Pro~~ | Desactivado — ver sección 4. |

Notas:

- La física 3D usa **Jolt**, integrado en el motor desde Godot 4.4. No hace falta addon.
- **Phantom Camera no está instalado** en el proyecto pese a lo que decía la versión anterior de este documento. Si lo quieres, instálalo desde la Godot Asset Store.

## 6. Verificación rápida

1. `node --version` → v24.19.0 ✔
2. `npx -y @n24q02m/better-godot-mcp@latest doctor` → tres líneas `[ok]` ✔
3. Abre el proyecto en Godot: `Project Settings > Plugins` debe mostrar **3** plugins activos (beehave, dialogue_manager, gut) y ningún error de MCP en la consola de salida.
4. En la app de Claude, el servidor `better-godot-mcp` aparece conectado.

## 7. Alternativas si quieres herramientas dentro del editor

`better-godot-mcp` trabaja sobre archivos, no dentro del editor en vivo. Si te interesa control del editor en tiempo real, hay opciones open source en npm:

- `@npgamedev/godot-mcp-server` (+ plugin `godot-mcp-toolkit`) — escenas, nodos, scripts, ClassDB, playtests.
- `@godot-mcp/protocol` — servidor + addon, con soporte declarado para Godot 4.7.
- `@coding-solo/godot-mcp` — más básico: lanzar editor, correr proyecto, capturar debug.
