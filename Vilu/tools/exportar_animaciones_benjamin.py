# -*- coding: utf-8 -*-
"""Arma benjamin_animaciones.glb a partir de los .fbx de la carpeta de Benjamín.

Uso (desde cualquier sitio):
  "D:/GameDev/Modelado/Blender/blender.exe" --background --python tools/exportar_animaciones_benjamin.py -- \
      "D:/GameDev/Assets/Benjamin/Animaciones Benjamin" "D:/GitHub/Vilu-Prototype/Vilu/models/personaje/benjamin_animaciones.glb"

Qué hace: importa cada .fbx de la tabla CLIPS, se queda con su acción, la
renombra al nombre que el juego llama por código (AnimadorPersonaje.gd) y las
apila todas en un solo esqueleto llamado «Armature». Después exporta SOLO ese
esqueleto con sus acciones a un .glb sin malla, que es lo que
`_injertar_animaciones_aparte` se lleva al modelo al montar.

Para meter una animación nueva: se agrega el .fbx a la carpeta, una línea a
CLIPS con el nombre que va a usar el código, y se vuelve a correr esto.
"""
import sys
import os
import bpy

# archivo -> nombre del clip en el juego
CLIPS = {
    "Reposo.fbx": "reposo",
    "Rodar.fbx": "rodar",
    "Mantener caminando hacia adelante.fbx": "mantener_adelante",
    "Mantener caminando hacia atras.fbx": "mantener_atras",
    "Mantener caminando hacia derecha.fbx": "mantener_derecha",
    "Mantener caminando hacia izquierda.fbx": "mantener_izquierda",
}


def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importar(ruta):
    antes = set(bpy.data.objects)
    # Los huesos «hoja» (HeadTop_End, los *4 de los dedos, *Toe_End) SE
    # CONSERVAN: el modelo de Benjamín los trae, y el animador mira las puntas
    # de los dedos para saber si la mano está abierta. Sin ellos el rig sale
    # con 52 huesos en vez de 65 y las pistas no calzan con el esqueleto.
    bpy.ops.import_scene.fbx(filepath=ruta, ignore_leaf_bones=False,
                             automatic_bone_orientation=False)
    nuevos = [o for o in bpy.data.objects if o not in antes]
    arm = next((o for o in nuevos if o.type == 'ARMATURE'), None)
    if arm is None:
        raise RuntimeError("sin esqueleto en " + ruta)
    act = arm.animation_data.action if arm.animation_data else None
    if act is None:
        raise RuntimeError("sin acción en " + ruta)
    return arm, act, nuevos


def apilar(arm, act):
    """Deja la acción como pista del NLA del esqueleto principal."""
    if arm.animation_data is None:
        arm.animation_data_create()
    ad = arm.animation_data
    track = ad.nla_tracks.new()
    track.name = act.name
    strip = track.strips.new(act.name, int(act.frame_range[0]), act)
    # Blender 4.4+: las acciones tienen «slots»; sin asignarlo la pista no
    # sabe a qué objeto va y el exportador la salta.
    try:
        if hasattr(strip, "action_slot") and len(act.slots) > 0:
            strip.action_slot = act.slots[0]
    except Exception as e:  # noqa
        print("slot:", e)
    strip.mute = False


def main(carpeta, salida):
    limpiar()
    principal = None
    for archivo, nombre in CLIPS.items():
        ruta = os.path.join(carpeta, archivo)
        if not os.path.exists(ruta):
            raise RuntimeError("falta " + ruta)
        arm, act, nuevos = importar(ruta)
        act.name = nombre
        act.use_fake_user = True
        if principal is None:
            principal = arm
            principal.name = "Armature"
            principal.data.name = "Armature"
            # La acción activa también va al NLA, y se quita del activo para
            # que no salga dos veces.
            principal.animation_data.action = None
        else:
            for o in nuevos:
                bpy.data.objects.remove(o, do_unlink=True)
        apilar(principal, act)
        print("clip", nombre, "frames", act.frame_range[:])

    # Sin mallas: sólo el esqueleto y sus acciones.
    for o in list(bpy.data.objects):
        if o is not principal:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    principal.select_set(True)
    bpy.context.view_layer.objects.active = principal

    bpy.ops.export_scene.gltf(
        filepath=salida,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_nla_strips=True,
        export_force_sampling=True,
        export_optimize_animation_size=False,
        export_skins=True,
        export_apply=False,
        export_yup=True,
    )
    print("exportado", salida, os.path.getsize(salida), "bytes")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) < 2:
        raise SystemExit("uso: blender --background --python este.py -- <carpeta fbx> <salida.glb>")
    main(args[0], args[1])
