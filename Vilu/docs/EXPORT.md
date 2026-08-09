# VILU — Export y prueba en máquina limpia (Beat 8)

El proyecto es .NET (Godot 4.7). La ventana y la UI ya dicen **VILU**
(`config/name` y `assembly_name` = "VILU"; TitleScreen y pantalla de FIN dicen
VILU). Falta generar el build — pasos (requieren el editor abierto):

## 1. Instalar export templates (una sola vez)
Actualmente **no están instalados** (`%APPDATA%/Godot/export_templates/` vacío).
- Editor → **Editor** → *Administrar plantillas de exportación* → **Descargar**
  la versión 4.7.1 (o descargar el `.tpz` de godotengine.org e instalarlo).

## 2. .NET: publicar el assembly
Como es un proyecto .NET, antes de exportar hay que construir la solución:
- Al abrir el editor, Godot genera `VILU.csproj`/`VILU.sln`. Compilar
  (**Project → Tools → C#** o build automático). Requiere el SDK de .NET.

## 3. Crear el preset y exportar
- **Proyecto → Exportar…** → *Añadir* → **Windows Desktop**.
- `Export Path`: `build/VILU.exe` (la carpeta `build/` está en `.gitignore`).
- *Exportar proyecto* (release). Deja `Embed PCK` marcado para un solo ejecutable.

Alternativa por CLI (con templates + .NET listos):
```bash
"D:/GameDev/Motores/Godot/Godot.exe" --headless --path "D:/GitHub/Vilu-Prototype/Vilu" --export-release "Windows Desktop" "build/VILU.exe"
```

## 4. Prueba en máquina limpia
- Copiar la carpeta `build/` a una máquina sin Godot ni el proyecto.
- Ejecutar `VILU.exe`. Verificar: la ventana dice **VILU**, el título dice VILU,
  y se puede jugar de punta a punta (TitleScreen → Región 1 → … → FIN).

## Checklist de coherencia (antes de exportar)
- [ ] La ventana/título dicen VILU (no "Emilia"/"EmiliaGame").
- [ ] `gut` en verde (headless): ver README de tests.
- [ ] El loop completo es jugable con teclado.
