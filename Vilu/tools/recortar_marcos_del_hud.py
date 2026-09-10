"""Corta las piezas del HUD desde los PNG del usuario (todos 5760x3240, capas
sobre el mismo lienzo) y deja en textures/ui/hud:

- panel_<quien>.png : el panel de la derecha SIN las barras pintadas (quedan
  el marco, el nombre, los iconos y los rótulos); las barras se dibujan en
  el juego.
- barra_vida.png / barra_energia.png / barra_carga.png : las barras pintadas,
  recortadas, para usarlas como textura de progreso (se cortan del panel de
  Benjamín; son iguales en el de Emilia).
- retrato_<quien>.png, amurrad*.png, alterno_<quien>.png : los círculos.

También imprime las fracciones (respecto del panel) donde van las barras.
"""
from PIL import Image
import numpy as np, os

SRC = r"C:\Users\kdelr\Pictures\ui marco emilia"
OUT = "textures/ui/hud"
os.makedirs(OUT, exist_ok=True)
K = 0.25
PANEL = (2438, 448, 5106, 1706)
RETRATO = (775, 121, 2743, 2142)
ALTERNO = (960, 140, 2680, 1860)
# Cajas de las barras pintadas, en coordenadas del recorte PANEL (2668x1258),
# medidas sobre la cuadrícula: un poco holgadas para llevarse el borde dorado.
# Los rótulos pintados («Vida», «Energía», «Carga») también se borran: el juego
# los escribe en el idioma que toque. Quedan el marco, el nombre y los iconos.
ROTULOS = {
    "vida": (500, 405, 930, 550),
    "energia": (440, 655, 945, 835),
    "carga": (490, 925, 945, 1115),
}
BARRAS = {
    "vida": (960, 420, 2075, 545),
    "energia": (960, 660, 2075, 785),
    "carga": (950, 890, 2090, 1090),
}


def cargar(n):
    return Image.open(os.path.join(SRC, n)).convert("RGBA")


def reducir(im):
    return im.resize((round(im.width * K), round(im.height * K)), Image.LANCZOS)


def borrar(panel, caja):
    """Rellena `caja` con el fondo del panel interpolando, fila a fila, el
    color que hay justo fuera de la caja por la izquierda y por la derecha."""
    a = np.array(panel).astype(np.float32)
    x0, y0, x1, y1 = caja
    for y in range(y0, y1):
        izq = a[y, x0 - 6:x0 - 1].mean(axis=0)
        der = a[y, x1 + 1:x1 + 6].mean(axis=0)
        t = np.linspace(0.0, 1.0, x1 - x0)[:, None]
        a[y, x0:x1] = izq * (1 - t) + der * t
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


benja = cargar("benjamin maco drch.png").crop(PANEL)
emilia = cargar("emilia MARCO PANEL DRCH.png").crop(PANEL)
W, H = benja.size
for nombre, caja in BARRAS.items():
    x0, y0, x1, y1 = caja
    barra = benja.crop(caja)
    # Fuera de la barra pintada el recorte lleva fondo del panel: se hace
    # transparente lo que no sea barra (todo lo que es azul marino apagado).
    a = np.array(barra).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    fondo = (b < 90) & (r < 60) & (g < 70)
    a[:, :, 3][fondo] = 0
    barra = Image.fromarray(a.astype(np.uint8))
    reducir(barra).save(os.path.join(OUT, "barra_%s.png" % nombre))
    print(nombre, "frac", tuple(round(v, 4) for v in (x0 / W, y0 / H, x1 / W, y1 / H)))
    benja = borrar(benja, caja)
    emilia = borrar(emilia, caja)
for nombre, caja in ROTULOS.items():
    x0, y0, x1, y1 = caja
    print("rotulo", nombre, "frac", tuple(round(v, 4) for v in (x0 / W, y0 / H, x1 / W, y1 / H)))
    benja = borrar(benja, caja)
    emilia = borrar(emilia, caja)
reducir(benja).save(os.path.join(OUT, "panel_benjamin.png"))
reducir(emilia).save(os.path.join(OUT, "panel_emilia.png"))
print("panel", reducir(benja).size, "prop", round(H / W, 4))

for archivo, caja, salida in [
    ("benjamin marco chiquito.png", RETRATO, "retrato_benjamin.png"),
    ("emilia MARCO CHIQUTO.png", RETRATO, "retrato_emilia.png"),
    ("benja amurrado.png", RETRATO, "amurrado_benjamin.png"),
    ("emilia amurrada.png", RETRATO, "amurrada_emilia.png"),
    ("benjamin marco alterno.png", ALTERNO, "alterno_benjamin.png"),
    ("emilia MARCO ALTERNTIVO.png", ALTERNO, "alterno_emilia.png"),
]:
    im = reducir(cargar(archivo).crop(caja))
    im.save(os.path.join(OUT, salida))
    print(salida, im.size)


# --- Amurrados con la corona alternativa ------------------------------------
# El marco alterno tiene que verse también en el compañero plantado con [T].
# La artista no dibujó esa combinación: se arma aquí metiendo la cara amurrada
# (recortada al hueco de la corona) sobre un disco azul marino, y la corona
# encima. `ui marco *.png` son las coronas solas; los huecos se midieron con un
# relleno desde el centro.
from PIL import ImageDraw

NAVY = (19, 32, 64, 255)
CENTRO_CLASICO = (1831, 1017)          # centro del círculo clásico (con la cara)
CORONAS = {
    "emilia": ("ui marco emilia.png", "emilia amurrada.png", (1097, 330, 2551, 1733), "amurrada_alterna_emilia.png"),
    "benjamin": ("ui marco bj.png", "benja amurrado.png", (1089, 273, 2567, 1702), "amurrado_alterno_benjamin.png"),
}
for quien, (corona, cara, hueco, salida) in CORONAS.items():
    x0, y0, x1, y1 = hueco
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    lienzo = Image.new("RGBA", (5760, 3240), (0, 0, 0, 0))
    ImageDraw.Draw(lienzo).ellipse((x0 - 20, y0 - 20, x1 + 20, y1 + 20), fill=NAVY)
    mascara = Image.new("L", (5760, 3240), 0)
    ImageDraw.Draw(mascara).ellipse((x0 + 4, y0 + 4, x1 - 4, y1 - 4), fill=255)
    rostro = cargar(cara)
    # La cara está centrada en el círculo clásico; se corre al centro del hueco.
    desplazada = Image.new("RGBA", rostro.size, (0, 0, 0, 0))
    desplazada.paste(rostro, (cx - CENTRO_CLASICO[0], cy - CENTRO_CLASICO[1]))
    lienzo.paste(desplazada, (0, 0), mascara)
    lienzo.alpha_composite(cargar(corona))
    im = reducir(lienzo.crop(ALTERNO))
    im.save(os.path.join(OUT, salida))
    print(salida, im.size)
