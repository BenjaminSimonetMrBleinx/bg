#!/usr/bin/env python3
"""Genere les textures 128 px du jeu.

    python outils/gen_textures.py [--sortie assets/textures]

Aucune dependance : l'encodeur PNG utilise uniquement la bibliotheque standard.
C'est volontaire — une dependance de moins a installer sur le poste de
Guillaume, et le script tourne aussi bien avec le Python de Blender.

Les fonctions de texture sont le portage de outils/rendu-rue-ps2.js, dont la
palette et le grain ont deja ete valides visuellement. On ne reinvente pas,
on transpose.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

# --------------------------------------------------------------- encodeur PNG


def ecrire_png(chemin: Path, largeur: int, hauteur: int, pixels: bytearray) -> None:
    """pixels : RGB, 3 octets par pixel, ligne par ligne."""
    brut = bytearray()
    for y in range(hauteur):
        brut.append(0)  # filtre "none"
        debut = y * largeur * 3
        brut += pixels[debut:debut + largeur * 3]

    def bloc(typ: bytes, data: bytes) -> bytes:
        c = typ + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    ihdr = struct.pack(">IIBBBBB", largeur, hauteur, 8, 2, 0, 0, 0)
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + bloc(b"IHDR", ihdr)
        + bloc(b"IDAT", zlib.compress(bytes(brut), 9))
        + bloc(b"IEND", b"")
    )


# ------------------------------------------------------------------- utilitaires


def hache(a: int, b: int) -> float:
    """Bruit deterministe dans [0, 1). Meme fonction que le rastériseur JS."""
    h = ((a * 73856093) ^ (b * 19349663)) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) & 0xFFFFFFFF
    return (h % 1024) / 1024.0


def borne(v: float) -> int:
    return 0 if v < 0 else 255 if v > 255 else int(v)


def rendre(largeur: int, hauteur: int, fn) -> bytearray:
    """fn(u, v) -> (r, g, b), u et v dans [0, 1)."""
    px = bytearray(largeur * hauteur * 3)
    for y in range(hauteur):
        v = (y + 0.5) / hauteur
        for x in range(largeur):
            u = (x + 0.5) / largeur
            r, g, b = fn(u, v)
            i = (y * largeur + x) * 3
            px[i] = borne(r)
            px[i + 1] = borne(g)
            px[i + 2] = borne(b)
    return px


# --------------------------------------------------------------------- textures


def route(u: float, v: float):
    """Section complete de chaussee : u traverse les 8 m de large,
    v se repete dans le sens de la longueur.

    Les bandes et la ligne axiale sont dans la texture, pas en geometrie —
    c'est la methode PS2, et ca evite des dizaines de quads inutiles.
    """
    n = hache(int(u * 260), int(v * 260))
    tache = hache(int(u * 34) + 31, int(v * 34) + 17)

    # bandes de rive
    if u < 0.030 or u > 0.970:
        g = 108 + n * 18
        return (g, g, g - 4)

    # ligne axiale discontinue : deux tirets par tuile
    if 0.484 < u < 0.516:
        phase = (v * 2.0) % 1.0
        if phase < 0.55:
            w = hache(int(u * 300), int(v * 300))
            return (170 + w * 26, 156 + w * 24, 100 + w * 18)

    g = 41 + n * 13 - tache * 9
    return (g, g + 1, g + 6)


def asphalte(u: float, v: float):
    """Asphalte nu, sans marquage : carrefours et parkings. Tuilable."""
    n = hache(int(u * 260), int(v * 260))
    tache = hache(int(u * 34) + 31, int(v * 34) + 17)
    g = 41 + n * 13 - tache * 9
    return (g, g + 1, g + 6)


def desert(u: float, v: float):
    """Terre sableuse du Nouveau-Mexique, pour tout ce qui entoure la ville."""
    n = hache(int(u * 200), int(v * 200))
    gros = hache(int(u * 23) + 7, int(v * 23) + 41)
    r = 58 + n * 16 + gros * 14
    return (r, r * 0.86, r * 0.68)


def trottoir(u: float, v: float):
    """Dalles jointoyees, tuilable dans les deux sens."""
    n = hache(int(u * 190), int(v * 190))
    joint = 0.70 if (u % 0.5) < 0.030 or (v % 0.5) < 0.030 else 1.0
    g = (66 + n * 12) * joint
    return (g, g, g + 7)


def facade(base, graine: int):
    """Une tuile = **2 x 2 travees** de fenetre, aux etats differents.

    Une seule travee par tuile donnerait un immeuble dont toutes les vitres
    sont dans le meme etat — mort, et la repetition saute aux yeux. Deux par
    deux suffit a melanger allume et eteint sur une meme facade, et c'est
    exactement ce que faisaient les jeux PS2.

    base   : couleur du crepi
    graine : decale le tirage d'un immeuble a l'autre
    """

    def fn(u: float, v: float):
        cu, cv = int(u * 2), int(v * 2)          # quelle travee
        bu, bv = (u * 2) % 1.0, (v * 2) % 1.0    # position dans la travee
        n = hache(int(u * 300) + graine, int(v * 300))

        # bandeau d'etage en pied de travee
        if bv < 0.10:
            g = 0.56 + n * 0.16
            return (base[0] * g, base[1] * g, base[2] * g)

        if 0.18 < bu < 0.82 and 0.24 < bv < 0.84:
            # encadrement clair
            if bu < 0.235 or bu > 0.765 or bv < 0.295 or bv > 0.795:
                return (base[0] * 1.26, base[1] * 1.24, base[2] * 1.20)
            # vitrage : allume chaud, allume vert, ou eteint
            k = hache(cu * 17 + graine * 5, cv * 23 + graine * 3)
            j = 0.88 + hache(int(u * 220), int(v * 220)) * 0.24
            if k > 0.86:
                return (94 * j, 200 * j, 126 * j)
            if k > 0.46:
                return (210 * j, 158 * j, 80 * j)
            return (24 * j, 27 * j, 37 * j)

        g = 0.86 + n * 0.26
        return (base[0] * g, base[1] * g, base[2] * g)

    return fn


def mur(base):
    """Pignon aveugle : crepi seul, pour les cotes et l'arriere des immeubles."""

    def fn(u: float, v: float):
        n = hache(int(u * 150), int(v * 150))
        salissure = max(0.0, 1.0 - v * 2.6) * 0.16  # trainee sombre en pied
        g = 0.84 + n * 0.26 - salissure
        return (base[0] * g, base[1] * g, base[2] * g)

    return fn


# La palette vient du rasteriseur de reference, deja calibree.
FACADES = {
    "facade_a": (96, 80, 68),
    "facade_b": (72, 76, 92),
    "facade_c": (106, 86, 70),
    "facade_d": (64, 70, 84),
}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sortie", default="game/assets/textures")
    ap.add_argument("--taille", type=int, default=128)
    args = ap.parse_args()

    dossier = Path(args.sortie)
    t = args.taille
    faits = []

    ecrire_png(dossier / "route.png", t, t, rendre(t, t, route))
    faits.append("route.png")

    ecrire_png(dossier / "asphalte.png", t, t, rendre(t, t, asphalte))
    faits.append("asphalte.png")

    ecrire_png(dossier / "desert.png", t, t, rendre(t, t, desert))
    faits.append("desert.png")

    ecrire_png(dossier / "trottoir.png", t // 2, t // 2,
               rendre(t // 2, t // 2, trottoir))
    faits.append("trottoir.png")

    for i, (nom, couleur) in enumerate(FACADES.items()):
        ecrire_png(dossier / f"{nom}.png", t, t, rendre(t, t, facade(couleur, i * 13)))
        ecrire_png(dossier / f"{nom}_mur.png", t, t, rendre(t, t, mur(couleur)))
        faits.append(f"{nom}.png + _mur")

    print(f"{len(faits)} textures ecrites dans {dossier}/")
    for f in faits:
        print(f"  {f}")


if __name__ == "__main__":
    main()
