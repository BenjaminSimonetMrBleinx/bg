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


def carrosserie(base):
    """Tolerie peinte : lignes de caisse discretes et bas de caisse sale."""

    def fn(u: float, v: float):
        n = hache(int(u * 170), int(v * 170))
        ligne = 0.80 if (v % 0.34) < 0.016 else 1.0
        salissure = max(0.0, 1.0 - v * 3.2) * 0.26      # projections de route
        g = (0.93 + n * 0.13) * ligne - salissure
        return (base[0] * g, base[1] * g, base[2] * g)

    return fn


def vitre(u: float, v: float):
    """Vitrage teinte : sombre en bas, le haut attrape le ciel."""
    n = hache(int(u * 90), int(v * 90))
    reflet = 0.30 + v * 0.55
    g = 17 + n * 9
    return (g + reflet * 24, g + reflet * 29, g + reflet * 41)


def pneu(u: float, v: float):
    """Gomme sculptee de rainures. u fait le tour, v traverse la bande."""
    # Assez clair pour se detacher de nuit : une gomme photometriquement juste
    # est un aplat noir des que le soleil se couche.
    n = hache(int(u * 230), int(v * 230))
    rainure = 0.68 if (u % 0.11) < 0.042 else 1.0
    g = (46 + n * 12) * rainure
    return (g, g, g + 3)


def jante(u: float, v: float):
    """Flanc de roue : enjoliveur clair au centre, gomme sombre au bord."""
    dx, dy = u - 0.5, v - 0.5
    d = (dx * dx + dy * dy) ** 0.5
    n = hache(int(u * 150), int(v * 150))
    if d > 0.44:
        return (26 + n * 6, 26 + n * 6, 28 + n * 6)
    g = 122 + n * 24 - d * 110
    return (g, g, g + 5)


def feu(couleur):
    """Optique : verre nervure, plus clair au centre."""

    def fn(u: float, v: float):
        nervure = 0.80 if (u % 0.16) < 0.05 else 1.0
        centre = 1.0 - abs(v - 0.5) * 0.8
        g = nervure * centre
        return (couleur[0] * g, couleur[1] * g, couleur[2] * g)

    return fn


# Un visage PS2 est une texture sur une boite — aucune geometrie ne represente
# un nez ou un oeil a ce budget de triangles. Tout le personnage tient donc
# dans ces quelques traits, et c'est pour ca qu'ils sont parametres : ajouter
# un habitant coute une entree de dictionnaire, pas une fonction de plus.
VISAGES = {
    "walter": {
        "peau": (194, 156, 130), "poil": (58, 49, 45),
        "cheveux": "calvitie", "lunettes": True,
        "moustache": True, "bouc": True,
    },
    "skyler": {
        # Blond CENDRE, pas dore. Une premiere version l'avait a (196,166,102)
        # : a trente pixels de haut, ces cheveux-la se confondaient avec la
        # carnation et son visage ne se lisait plus du tout. A cette
        # resolution, le contraste passe avant la justesse de la teinte.
        "peau": (208, 172, 148), "poil": (146, 112, 68),
        "cheveux": "longs", "lunettes": False,
        "moustache": False, "bouc": False,
    },
    "jesse": {
        "peau": (198, 160, 132), "poil": (46, 40, 38),
        "cheveux": "courts", "lunettes": False,
        "moustache": False, "bouc": False, "barbe_naissante": True,
    },
}


def visage(traits: dict):
    """Fabrique l'atlas de tete d'un personnage.

    Moitie gauche de l'atlas (u < 0.5) : le visage, plaque sur la face avant
    du cube. Moitie droite : crane et nuque.
    """
    base_peau = traits["peau"]
    base_poil = traits["poil"]
    coupe = traits.get("cheveux", "courts")

    def rendu(u: float, v: float):
        n = hache(int(u * 200), int(v * 200))
        peau = (base_peau[0] + n * 14, base_peau[1] + n * 12, base_peau[2] + n * 10)
        poil = (base_poil[0] + n * 13, base_poil[1] + n * 11, base_poil[2] + n * 10)

        # v croit vers le BAS dans un PNG : on le retourne pour raisonner en
        # hauteur de visage, 1 = sommet du crane, 0 = menton. Une premiere
        # version l'oubliait et Walter portait son bouc sur le front.
        fu, fv = (u - 0.5) * 2.0 if u >= 0.5 else u * 2.0, 1.0 - v

        if u >= 0.5:                              # arriere et cotes du crane
            if coupe == "calvitie":
                return peau
            if coupe == "longs":
                return poil if fv > 0.25 else peau
            return poil if fv > 0.70 else peau

        # implantation des cheveux, vue de face
        if coupe == "calvitie":
            if fv <= 0.845 and 0.60 < fv < 0.865 and (fu < 0.13 or fu > 0.87):
                return poil
        elif coupe == "longs":
            # frange haute, et deux masses qui descendent le long du visage
            if fv > 0.815:
                return poil
            if fv > 0.25 and (fu < 0.145 or fu > 0.855):
                return poil
        else:
            if fv > 0.795:
                return poil
            if fv > 0.62 and (fu < 0.12 or fu > 0.88):
                return poil

        # sourcils
        if 0.645 < fv < 0.685 and (0.20 < fu < 0.42 or 0.58 < fu < 0.80):
            return poil

        oeil_g = 0.235 < fu < 0.405
        oeil_d = 0.595 < fu < 0.765

        if traits.get("lunettes"):
            # monture fine, dessinee avant les yeux pour les encadrer
            monture = 0.505 < fv < 0.625
            if monture and (0.220 < fu < 0.420 or 0.580 < fu < 0.780):
                bord_v = fv < 0.525 or fv > 0.605
                bord_u = (0.220 < fu < 0.238 or 0.402 < fu < 0.420
                          or 0.580 < fu < 0.598 or 0.762 < fu < 0.780)
                if bord_v or bord_u:
                    return (66, 62, 58)
            if 0.556 < fv < 0.572 and 0.420 <= fu <= 0.580:
                return (66, 62, 58)               # pont
            if 0.556 < fv < 0.572 and (fu < 0.13 or fu > 0.87):
                return (66, 62, 58)               # branches

        # yeux
        if 0.530 < fv < 0.600 and (oeil_g or oeil_d):
            centre = 0.320 if oeil_g else 0.680
            if abs(fu - centre) < 0.030 and 0.545 < fv < 0.585:
                return (34, 36, 42)               # pupille
            return (222, 220, 214)                # sclere

        # nez : une simple ombre laterale, aucune geometrie a ce budget
        if 0.36 < fv < 0.50 and 0.455 < fu < 0.475:
            return (peau[0] * 0.86, peau[1] * 0.86, peau[2] * 0.86)

        if traits.get("moustache") and 0.300 < fv < 0.355 and 0.345 < fu < 0.655:
            return poil

        # bouc : se resserre vers le menton
        if traits.get("bouc") and fv < 0.300 and 0.325 < fu < 0.675:
            marge = abs(fu - 0.5) / 0.175
            if fv > 0.075 + marge * 0.085:
                return poil

        # barbe de trois jours : on assombrit, on ne remplace pas
        if traits.get("barbe_naissante") and fv < 0.36 and 0.26 < fu < 0.74:
            m = 0.86 + n * 0.06
            return (peau[0] * m, peau[1] * m, peau[2] * m)

        return peau

    return rendu


def carnation(base):
    """Mains, avant-bras : carnation unie et bruitee."""
    def rendu(u: float, v: float):
        n = hache(int(u * 200), int(v * 200))
        return (base[0] + n * 14, base[1] + n * 12, base[2] + n * 10)
    return rendu


def haut(base, capuche: bool = False):
    """Chemise ou sweat. Boutonniere verticale, col plus clair."""
    def rendu(u: float, v: float):
        n = hache(int(u * 180), int(v * 180))
        if v > 0.90:                              # col, ou capuche
            g = 1.32 + n * 0.12 if capuche else 1.16 + n * 0.12
        elif abs(u - 0.5) < 0.022 and not capuche:
            g = 0.78 + n * 0.10                   # boutonniere
        elif capuche and 0.42 < v < 0.50 and abs(u - 0.5) < 0.20:
            g = 0.72 + n * 0.10                   # poche ventrale
        else:
            g = 0.92 + n * 0.16
        return (base[0] * g, base[1] * g, base[2] * g)
    return rendu


def bas(base):
    """Pantalon, legerement plus sombre en bas de jambe."""
    def rendu(u: float, v: float):
        n = hache(int(u * 170), int(v * 170))
        g = 0.88 + n * 0.16 - max(0.0, 0.25 - v) * 0.5
        return (base[0] * g, base[1] * g, base[2] * g)
    return rendu


# Tenues, dans le meme esprit que les visages.
TENUES = {
    "walter": {"peau": (196, 156, 128), "haut": (92, 108, 88),
               "capuche": False, "bas": (118, 106, 84)},
    "skyler": {"peau": (210, 174, 150), "haut": (128, 156, 186),
               "capuche": False, "bas": (64, 66, 76)},
    "jesse": {"peau": (200, 162, 132), "haut": (132, 54, 48),
              "capuche": True, "bas": (58, 64, 82)},
}


# Conservees sous leur ancien nom : le reste du projet les appelle ainsi.
tete_walter = visage(VISAGES["walter"])
peau = carnation(TENUES["walter"]["peau"])
chemise = haut(TENUES["walter"]["haut"])
pantalon = bas(TENUES["walter"]["bas"])


def chaussure(u: float, v: float):
    """Cuir sombre, semelle plus claire."""
    n = hache(int(u * 180), int(v * 180))
    if v < 0.22:
        g = 78 + n * 14
        return (g, g, g + 3)
    g = 42 + n * 12
    return (g, g * 0.94, g * 0.88)


def crepi(u: float, v: float):
    """Enduit gratte beige, le revetement d'Albuquerque."""
    n = hache(int(u * 210), int(v * 210))
    gros = hache(int(u * 44) + 9, int(v * 44) + 23)
    g = 0.90 + n * 0.16 + gros * 0.06
    return (172 * g, 152 * g, 122 * g)


def bardage(u: float, v: float):
    """Bardage bois horizontal, un peu fatigue. Pour la maison de Jesse."""
    n = hache(int(u * 190), int(v * 190))
    lame = (v % 0.125) / 0.125
    ombre = 0.72 if lame < 0.10 else (1.06 if lame < 0.20 else 1.0)
    g = (0.88 + n * 0.18) * ombre
    return (126 * g, 108 * g, 88 * g)


def toit(u: float, v: float):
    """Gravier de toiture terrasse, ou bardeaux vus de loin."""
    n = hache(int(u * 240), int(v * 240))
    g = 62 + n * 20
    return (g, g * 0.95, g * 0.88)


def porte(u: float, v: float):
    """Porte a panneaux, poignee doree."""
    n = hache(int(u * 150), int(v * 150))
    base = (104, 66, 44)
    if 0.62 < u < 0.72 and 0.44 < v < 0.52:
        return (196, 164, 92)                      # poignee
    cadre = u < 0.10 or u > 0.90 or v < 0.06 or v > 0.94
    panneau = (0.20 < u < 0.80) and (0.14 < v < 0.44 or 0.56 < v < 0.86)
    g = 1.14 if cadre else (0.84 if panneau else 1.0)
    g *= 0.94 + n * 0.12
    return (base[0] * g, base[1] * g, base[2] * g)


def fenetre_maison(u: float, v: float):
    """Fenetre a deux vantaux, eclairee de l'interieur."""
    if u < 0.07 or u > 0.93 or v < 0.07 or v > 0.93:
        return (188, 178, 162)                     # dormant clair
    if 0.47 < u < 0.53:
        return (188, 178, 162)                     # meneau
    n = hache(int(u * 120), int(v * 120))
    chaud = 0.82 + v * 0.35
    return (206 * chaud * (0.92 + n * 0.14),
            170 * chaud * (0.92 + n * 0.14),
            108 * chaud * (0.92 + n * 0.14))


def parquet(u: float, v: float):
    """Lames de bois, decalees d'une rangee a l'autre."""
    rangee = int(v * 6)
    decalage = 0.5 if rangee % 2 else 0.0
    uu = (u * 3 + decalage) % 1.0
    n = hache(int(u * 200) + rangee, int(v * 200))
    joint = 0.68 if uu < 0.03 or (v * 6) % 1.0 < 0.05 else 1.0
    g = (0.90 + n * 0.18) * joint
    return (128 * g, 96 * g, 62 * g)


def mur_interieur(u: float, v: float):
    """Peinture mate, plinthe sombre en pied de mur."""
    n = hache(int(u * 170), int(v * 170))
    if v < 0.055:
        g = 0.60 + n * 0.10
        return (188 * g, 180 * g, 168 * g)
    g = 0.94 + n * 0.10
    return (196 * g, 188 * g, 174 * g)


def carrelage(u: float, v: float):
    """Sol de cuisine, damier discret."""
    cx, cy = int(u * 8), int(v * 8)
    n = hache(int(u * 160), int(v * 160))
    clair = (cx + cy) % 2 == 0
    joint = ((u * 8) % 1.0 < 0.06) or ((v * 8) % 1.0 < 0.06)
    g = (0.95 + n * 0.10) * (0.78 if joint else 1.0)
    base = 178 if clair else 140
    return (base * g, base * g * 0.99, base * g * 0.94)


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

# Le beige-or est la couleur de l'Aztek de Walt. Les autres serviront au
# trafic quand il existera.
CARROSSERIES = {
    "voiture_aztek": (154, 138, 108),
    "voiture_b": (78, 84, 96),
    "voiture_c": (112, 62, 52),
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

    # --- vehicules ---
    for nom, couleur in CARROSSERIES.items():
        ecrire_png(dossier / f"{nom}.png", t, t, rendre(t, t, carrosserie(couleur)))
        faits.append(f"{nom}.png")

    ecrire_png(dossier / "vitre.png", t // 2, t // 2, rendre(t // 2, t // 2, vitre))
    ecrire_png(dossier / "pneu.png", t // 2, t // 2, rendre(t // 2, t // 2, pneu))
    ecrire_png(dossier / "jante.png", t // 2, t // 2, rendre(t // 2, t // 2, jante))
    ecrire_png(dossier / "feu_avant.png", t // 4, t // 4,
               rendre(t // 4, t // 4, feu((252, 240, 208))))
    ecrire_png(dossier / "feu_arriere.png", t // 4, t // 4,
               rendre(t // 4, t // 4, feu((196, 42, 34))))
    faits += ["vitre.png", "pneu.png", "jante.png", "feu_avant.png", "feu_arriere.png"]

    # --- personnages ---
    # Un jeu de quatre textures par personnage, sous un suffixe commun : le
    # generateur de maillage n'a alors qu'un nom a connaitre.
    for qui, traits in VISAGES.items():
        tenue = TENUES[qui]
        ecrire_png(dossier / f"tete_{qui}.png", t, t, rendre(t, t, visage(traits)))
        ecrire_png(dossier / f"peau_{qui}.png", t // 2, t // 2,
                   rendre(t // 2, t // 2, carnation(tenue["peau"])))
        ecrire_png(dossier / f"haut_{qui}.png", t, t,
                   rendre(t, t, haut(tenue["haut"], tenue["capuche"])))
        ecrire_png(dossier / f"bas_{qui}.png", t, t, rendre(t, t, bas(tenue["bas"])))
        faits.append(f"tete/peau/haut/bas_{qui}.png")

    # Anciens noms, encore references par les .glb deja exportes.
    ecrire_png(dossier / "peau.png", t // 2, t // 2, rendre(t // 2, t // 2, peau))
    ecrire_png(dossier / "chemise.png", t, t, rendre(t, t, chemise))
    ecrire_png(dossier / "pantalon.png", t, t, rendre(t, t, pantalon))
    ecrire_png(dossier / "chaussure.png", t // 2, t // 2,
               rendre(t // 2, t // 2, chaussure))
    faits += ["peau.png", "chemise.png", "pantalon.png", "chaussure.png"]

    # --- maisons ---
    for nom, fn in [("crepi", crepi), ("bardage", bardage), ("toit", toit),
                    ("porte", porte), ("fenetre_maison", fenetre_maison),
                    ("parquet", parquet), ("mur_interieur", mur_interieur),
                    ("carrelage", carrelage)]:
        ecrire_png(dossier / f"{nom}.png", t, t, rendre(t, t, fn))
        faits.append(f"{nom}.png")

    print(f"{len(faits)} textures ecrites dans {dossier}/")
    for f in faits:
        print(f"  {f}")


if __name__ == "__main__":
    main()
