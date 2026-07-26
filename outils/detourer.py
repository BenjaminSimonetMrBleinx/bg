#!/usr/bin/env python3
"""Retire le fond uni d'une image livree, et la reduit a la taille du jeu.

    python outils/detourer.py --source livraisons/Money.png \\
            --sortie game/assets/images/argent.png --hauteur 20

Une image destinee au HUD arrive presque toujours sur fond blanc opaque. Collee
telle quelle, elle donne un rectangle blanc a l'ecran, ce qui se voit plus que
l'objet dessine.

CE N'EST PAS UN SIMPLE « BLANC = TRANSPARENT ». Un remplacement couleur par
couleur troue aussi les blancs INTERIEURS — un reflet, un liseré — et laisse
une frange claire sur chaque bord oblique. On part donc des BORDS et on ne
mange que ce qui leur est connexe : ce qui est enferme dans le dessin reste,
quelle que soit sa couleur.

PUR STDLIB, comme gen_textures.py. Le projet n'installe rien sur la machine de
personne : une dependance de plus, c'est une machine de plus ou la chaine ne
tourne pas, et on ne le decouvre que le jour ou l'autre essaie.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from collections import deque
from pathlib import Path


# --------------------------------------------------------------------- PNG


def lire_png(chemin: Path) -> tuple[int, int, bytearray]:
    """Renvoie (largeur, hauteur, pixels RGBA). Gere RGB et RGBA, 8 bits."""
    brut = chemin.read_bytes()
    if brut[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("%s n'est pas un PNG" % chemin.name)

    largeur = hauteur = 0
    canaux = 3
    donnees = b""
    palette = b""
    i = 8
    while i < len(brut):
        taille = struct.unpack_from(">I", brut, i)[0]
        typ = brut[i + 4:i + 8]
        corps = brut[i + 8:i + 8 + taille]
        if typ == b"IHDR":
            largeur, hauteur, profondeur, couleur = struct.unpack_from(
                ">IIBB", corps, 0)
            if profondeur != 8:
                raise SystemExit("%s : %d bits par canal, seul 8 est gere"
                                 % (chemin.name, profondeur))
            canaux = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(couleur, 0)
            if canaux == 0:
                raise SystemExit("%s : type de couleur %d inconnu"
                                 % (chemin.name, couleur))
            indexee = couleur == 3
        elif typ == b"PLTE":
            palette = corps
        elif typ == b"IDAT":
            donnees += corps
        elif typ == b"IEND":
            break
        i += 12 + taille

    flux = zlib.decompress(donnees)
    par_ligne = largeur * canaux
    sortie = bytearray()
    precedente = bytearray(par_ligne)
    p = 0
    for _ in range(hauteur):
        filtre = flux[p]
        ligne = bytearray(flux[p + 1:p + 1 + par_ligne])
        p += 1 + par_ligne
        # Le defiltrage PNG. Chaque ligne est encodee par rapport a sa voisine
        # de gauche et a celle du dessus ; sauter cette etape donne une image
        # qui « bave » vers la droite, ce qui ressemble a une image corrompue.
        for x in range(par_ligne):
            a = ligne[x - canaux] if x >= canaux else 0
            b = precedente[x]
            c = precedente[x - canaux] if x >= canaux else 0
            if filtre == 1:
                ligne[x] = (ligne[x] + a) & 0xFF
            elif filtre == 2:
                ligne[x] = (ligne[x] + b) & 0xFF
            elif filtre == 3:
                ligne[x] = (ligne[x] + (a + b) // 2) & 0xFF
            elif filtre == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                ligne[x] = (ligne[x] + pred) & 0xFF
        precedente = ligne
        sortie += ligne

    # Tout est ramene en RGBA : la suite du script n'a alors qu'un seul cas.
    rgba = bytearray(largeur * hauteur * 4)
    for k in range(largeur * hauteur):
        src = sortie[k * canaux:(k + 1) * canaux]
        if canaux == 4:
            rgba[k * 4:k * 4 + 4] = src
        elif canaux == 3:
            rgba[k * 4:k * 4 + 3] = src
            rgba[k * 4 + 3] = 255
        elif canaux == 2:
            rgba[k * 4:k * 4 + 3] = bytes([src[0]] * 3)
            rgba[k * 4 + 3] = src[1]
        elif indexee and palette:
            d = src[0] * 3
            rgba[k * 4:k * 4 + 3] = palette[d:d + 3]
            rgba[k * 4 + 3] = 255
        else:
            rgba[k * 4:k * 4 + 3] = bytes([src[0]] * 3)
            rgba[k * 4 + 3] = 255
    return largeur, hauteur, rgba


def ecrire_png(chemin: Path, largeur: int, hauteur: int,
               pixels: bytearray) -> None:
    """pixels : RGBA, 4 octets par pixel."""
    brut = bytearray()
    for y in range(hauteur):
        brut.append(0)
        debut = y * largeur * 4
        brut += pixels[debut:debut + largeur * 4]

    def bloc(typ: bytes, data: bytes) -> bytes:
        c = typ + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I",
                                                              zlib.crc32(c))

    ihdr = struct.pack(">IIBBBBB", largeur, hauteur, 8, 6, 0, 0, 0)
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + bloc(b"IHDR", ihdr)
        + bloc(b"IDAT", zlib.compress(bytes(brut), 9))
        + bloc(b"IEND", b"")
    )


# ---------------------------------------------------------------- traitement


def detourer(largeur: int, hauteur: int, px: bytearray,
             tolerance: int) -> int:
    coins = [(0, 0), (largeur - 1, 0), (0, hauteur - 1),
             (largeur - 1, hauteur - 1)]
    couleurs = [tuple(px[(y * largeur + x) * 4:(y * largeur + x) * 4 + 3])
                for x, y in coins]
    # La couleur du fond est celle des coins, a la majorite. La LIRE plutot que
    # de supposer du blanc : un pack livre sur fond gris ou damier existe, et
    # supposer rend l'image intacte sans rien dire.
    fond = max(set(couleurs), key=couleurs.count)

    def pareil(x: int, y: int) -> bool:
        d = (y * largeur + x) * 4
        return all(abs(px[d + k] - fond[k]) <= tolerance for k in range(3))

    vus = bytearray(largeur * hauteur)
    file = deque()

    def semer(x: int, y: int) -> None:
        if not vus[y * largeur + x] and pareil(x, y):
            vus[y * largeur + x] = 1
            file.append((x, y))

    for x in range(largeur):
        semer(x, 0)
        semer(x, hauteur - 1)
    for y in range(hauteur):
        semer(0, y)
        semer(largeur - 1, y)

    efface = 0
    while file:
        x, y = file.popleft()
        px[(y * largeur + x) * 4 + 3] = 0
        efface += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < largeur and 0 <= ny < hauteur:
                semer(nx, ny)

    print("  fond      rgb%s, %d pixels effaces sur %d (%.0f %%)"
          % (fond, efface, largeur * hauteur,
             100.0 * efface / (largeur * hauteur)))
    return efface


def recadrer(largeur: int, hauteur: int,
             px: bytearray) -> tuple[int, int, bytearray]:
    """Rogne le vide autour. Une icone perdue au milieu d'une grande image
    reserverait sur le HUD une place trois fois trop grande."""
    x0, y0, x1, y1 = largeur, hauteur, -1, -1
    for y in range(hauteur):
        for x in range(largeur):
            if px[(y * largeur + x) * 4 + 3] > 8:
                x0, y0 = min(x0, x), min(y0, y)
                x1, y1 = max(x1, x), max(y1, y)
    if x1 < 0:
        return largeur, hauteur, px
    nl, nh = x1 - x0 + 1, y1 - y0 + 1
    sortie = bytearray(nl * nh * 4)
    for y in range(nh):
        s = ((y + y0) * largeur + x0) * 4
        sortie[y * nl * 4:(y + 1) * nl * 4] = px[s:s + nl * 4]
    print("  recadre   %d x %d" % (nl, nh))
    return nl, nh, sortie


def reduire(largeur: int, hauteur: int, px: bytearray,
            cible: int) -> tuple[int, int, bytearray]:
    """Reduction par MOYENNE de la zone source, pas par echantillonnage.

    Prendre un pixel sur n sur un dessin trait donne une icone trouee : les
    contours noirs, larges d'un pixel, tombent entre deux echantillons et
    disparaissent par endroits. La moyenne les garde, en plus pale.

    La transparence est prise en compte dans la moyenne, sinon le fond efface
    — qui garde sa couleur d'origine sous un alpha nul — revient teinter les
    bords.
    """
    nh = cible
    nl = max(1, round(largeur * cible / hauteur))
    sortie = bytearray(nl * nh * 4)
    for y in range(nh):
        for x in range(nl):
            x0, x1 = x * largeur // nl, max(x * largeur // nl + 1,
                                            (x + 1) * largeur // nl)
            y0, y1 = y * hauteur // nh, max(y * hauteur // nh + 1,
                                            (y + 1) * hauteur // nh)
            somme = [0.0, 0.0, 0.0]
            alpha = 0.0
            poids = 0.0
            for sy in range(y0, y1):
                for sx in range(x0, x1):
                    d = (sy * largeur + sx) * 4
                    a = px[d + 3] / 255.0
                    for k in range(3):
                        somme[k] += px[d + k] * a
                    alpha += a
                    poids += 1.0
            d = (y * nl + x) * 4
            if alpha > 0.0:
                for k in range(3):
                    sortie[d + k] = min(255, round(somme[k] / alpha))
            sortie[d + 3] = min(255, round(255.0 * alpha / max(1.0, poids)))
    print("  reduit    %d x %d" % (nl, nh))
    return nl, nh, sortie


def main() -> None:
    ap = argparse.ArgumentParser(description="Detoure une image livree")
    ap.add_argument("--source", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--hauteur", type=int, default=0,
                    help="hauteur finale en pixels ; 0 garde la taille")
    ap.add_argument("--tolerance", type=int, default=26)
    a = ap.parse_args()

    source = Path(a.source)
    if not source.exists():
        raise SystemExit("introuvable : %s" % source)
    print("")
    print("  source    %s" % source.name)
    largeur, hauteur, px = lire_png(source)
    print("  taille    %d x %d" % (largeur, hauteur))

    detourer(largeur, hauteur, px, a.tolerance)
    largeur, hauteur, px = recadrer(largeur, hauteur, px)
    if a.hauteur > 0 and a.hauteur < hauteur:
        largeur, hauteur, px = reduire(largeur, hauteur, px, a.hauteur)

    ecrire_png(Path(a.sortie), largeur, hauteur, px)
    print("  sortie    %s" % a.sortie)


if __name__ == "__main__":
    main()
