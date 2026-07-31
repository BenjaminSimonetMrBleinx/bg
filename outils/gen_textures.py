#!/usr/bin/env python3
"""Genere les textures 128 px du jeu.

    python outils/gen_textures.py [--sortie .tmp/textures]

Aucune dependance : l'encodeur PNG utilise uniquement la bibliotheque standard.
C'est volontaire — une dependance de moins a installer sur le poste de
Guillaume, et le script tourne aussi bien avec le Python de Blender.

Les fonctions de texture sont le portage de outils/rendu-rue-ps2.js, dont la
palette et le grain ont deja ete valides visuellement. On ne reinvente pas,
on transpose.
"""

from __future__ import annotations

import argparse
import json
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


# Les fonds des panneaux publicitaires. Trois suffisent : au-dela on ne les
# distingue plus, et une ville n'a de toute facon que quelques annonceurs.
AFFICHES = [(196, 62, 48), (44, 88, 148), (214, 172, 52)]


def affiche(base, graine: int):
    """Un panneau publicitaire, vu de la rue.

    AUCUN TEXTE, ET C'EST VOULU. A la resolution du jeu, une accroche ecrite
    serait un pate illisible ; ce qu'on lit d'une affiche a trente metres, ce
    sont des aplats et un bandeau. On peint donc la COMPOSITION d'une affiche
    plutot que son contenu — et ca reste lisible de face comme de biais.
    """
    def fn(u: float, v: float):
        n = hache(int(u * 120) + graine * 7, int(v * 120))
        r, g, b = base
        # Le bandeau du bas, plus clair : c'est la ou vit le numero de
        # telephone sur toutes les affiches du monde.
        if v < 0.22:
            return (232 - n * 14, 228 - n * 14, 220 - n * 12)
        # Un bloc plus sombre a droite, qui tient lieu d'image.
        if u > 0.55 and 0.30 < v < 0.88:
            return (r * 0.62 + n * 12, g * 0.62 + n * 12, b * 0.62 + n * 12)
        return (r + n * 16, g + n * 16, b + n * 16)
    return fn


# ---------------------------------------------------------- banc graphique
#
# Les textures du banc de comparaison. Elles sont en 256 px la ou le jeu est en
# 128 : c'est la moitie de ce qui separe le niveau 1 du niveau 3, l'autre
# moitie etant la geometrie. Voir outils/gen_banc_graphique.py.


def banc_mur(u: float, v: float):
    """Bardage horizontal + crepi, avec salissures.

    CE QUI FAIT LA DIFFERENCE A CETTE RESOLUTION, ce n'est pas le detail fin —
    il disparait au filtrage — ce sont les VARIATIONS LENTES : une lame plus
    sombre par-ci, une trainee sous une fenetre, un bas de mur plus sale. Elles
    survivent au flou et donnent du volume a un aplat.
    """
    lame = int(v * 22) % 2
    n = hache(int(u * 300), int(v * 300))
    grand = hache(int(u * 9), int(v * 9))
    joint = 1.0 if (v * 22) % 1.0 > 0.10 else 0.82
    g = (176 + n * 12 + grand * 20 - lame * 8) * joint
    # Le bas du mur prend la poussiere : dix pour cent de plus bas en bas.
    sale = 1.0 - max(0.0, (0.22 - v)) * 0.55
    return (g * 0.99 * sale, g * 0.90 * sale, g * 0.74 * sale)


def banc_toit(u: float, v: float):
    """Bardeaux d'asphalte, en quinconce."""
    rangee = int(v * 26)
    decal = 0.5 if rangee % 2 else 0.0
    bord = 1.0 if ((v * 26) % 1.0) > 0.14 else 0.72
    fente = 1.0 if (((u * 18) + decal) % 1.0) > 0.06 else 0.78
    n = hache(int(u * 260), int(v * 260))
    g = (86 + n * 22) * bord * fente
    return (g, g * 0.98, g * 0.94)


def banc_carrosserie(base):
    """Tole peinte : degrade vertical, ligne de caisse, grain fin.

    Une carrosserie unie se lit comme du carton. Ce qui la fait ressembler a de
    la peinture, c'est le DEGRADE — plus clair vers le haut, ou le ciel se
    reflete — et une ligne de caisse plus sombre a mi-hauteur.
    """
    r, g, b = base
    def fn(u: float, v: float):
        n = hache(int(u * 340), int(v * 340))
        ciel = 0.82 + v * 0.34
        ligne = 0.88 if 0.46 < v < 0.50 else 1.0
        k = ciel * ligne
        return (r * k + n * 6, g * k + n * 6, b * k + n * 6)
    return fn


def banc_vitre(u: float, v: float):
    """Vitrage, avec le reflet oblique du ciel.

    IL DOIT ETRE CLAIR, pas teinte. Une vitre sombre sur une carrosserie
    sombre ne se distingue pas : l'habitacle se lit alors comme un bloc plein,
    et la voiture perd sa cabine. Ce qu'on voit d'une vitre en plein jour,
    c'est le CIEL dedans — donc du clair, avec une bande plus vive en biais.
    """
    n = hache(int(u * 200), int(v * 200))
    reflet = 1.0 + max(0.0, 0.55 - abs(u - v)) * 0.75
    g = (128 + n * 12) * reflet
    return (g * 0.88, g * 0.97, g * 1.08)


def banc_jante_rouge(u: float, v: float):
    """La jante a rayons rouge de la Monte Carlo, avec son pneu a flanc blanc.

    C'est le detail le plus voyant des photos : rayons rouges, cercle chrome,
    et un liset blanc sur le flanc du pneu. Ca ne coute rien — la roue est deja
    un disque texture — et c'est ce qu'on reconnait en premier sur la voiture.
    """
    import math as _m
    dx, dy = u - 0.5, v - 0.5
    d = _m.hypot(dx, dy)
    a = _m.atan2(dy, dx)
    n = hache(int(u * 240), int(v * 240))
    if d > 0.47:
        return (26 + n * 8, 26 + n * 8, 28 + n * 8)              # pneu
    if d > 0.40:
        return (214 + n * 12, 210 + n * 12, 202 + n * 12)        # flanc blanc
    if d > 0.35:
        return (176 + n * 14, 178 + n * 14, 182 + n * 14)        # cercle chrome
    if d < 0.11:
        return (172 + n * 12, 174 + n * 12, 178 + n * 12)        # moyeu
    rayon = _m.cos(a * 8.0) > 0.1
    if rayon:
        return (168 + n * 16, 42 + n * 8, 34 + n * 8)            # rayon rouge
    return (120 + n * 12, 26 + n * 6, 22 + n * 6)                # fond sombre


def banc_jante(u: float, v: float):
    """Jante a cinq branches, peinte dans la texture."""
    import math as _m
    dx, dy = u - 0.5, v - 0.5
    d = _m.hypot(dx, dy)
    a = _m.atan2(dy, dx)
    n = hache(int(u * 240), int(v * 240))
    if d > 0.47:
        return (28 + n * 8, 28 + n * 8, 30 + n * 8)          # pneu
    if d < 0.13:
        return (150 + n * 14, 152 + n * 14, 156 + n * 14)    # moyeu
    branche = _m.cos(a * 5.0) > 0.35
    g = (168 if branche else 96) + n * 16
    return (g, g + 2, g + 6)


def montagne(u: float, v: float):
    """La roche des Sandia, vue de tres loin.

    ELLE N'A PAS BESOIN D'ETRE DETAILLEE, ET ELLE NE DOIT PAS L'ETRE. La crete
    est a trois cents metres, donc au bord de la brume : ce qu'on en voit est
    une silhouette delavee. Une texture de rocher fouillee y serait invisible
    et couterait le meme prix.

    Ce qui compte est le DEGRADE vertical — sombre en bas, clair vers les
    cretes. C'est lui qui donne le volume qu'une silhouette plate n'a pas.
    """
    n = hache(int(u * 90), int(v * 90))
    strate = hache(int(v * 14) + 5, 3)
    g = 66 + v * 46 + n * 10 + strate * 12
    # Le violet des montagnes d'Albuquerque au soleil couchant, tire vers le
    # brun le reste du temps. Le bleu reste au-dessus du vert : sans ca, la
    # roche vire au kaki et ressemble a une colline irlandaise.
    return (g * 1.02, g * 0.86, g * 0.88)


def herbe(u: float, v: float):
    """Pelouse de parc. Tuilable.

    VERTE MAIS PAS ANGLAISE. Albuquerque est a deux mille metres dans un
    desert : une pelouse y est arrosee, jaunie par endroits, et jamais du vert
    saturé d'un gazon de banlieue anglaise. Une pelouse trop verte est la
    premiere chose qui sonne faux dans une ville du Nouveau-Mexique.
    """
    n = hache(int(u * 210), int(v * 210))
    touffe = hache(int(u * 26) + 13, int(v * 26) + 5)
    g = 96 + n * 22 + touffe * 26
    return (g * 0.66, g * 0.84, g * 0.40)


def parking(u: float, v: float):
    """Asphalte marque d'une ligne de stationnement.

    La ligne est DANS la texture, pas en geometrie. Un parking de quarante
    places demanderait quarante quadrilateres peints ; ici la texture se repete
    une fois par place et le sol reste une seule face. C'est ce que faisaient
    les jeux de l'epoque, et c'est aussi ce qui rend le nombre de places
    gratuit.

    La ligne s'arrete avant le bord en v : une place de parking est ouverte du
    cote ou l'on entre.
    """
    n = hache(int(u * 260), int(v * 260))
    g = 41 + n * 13
    if u < 0.055 and v < 0.84:
        # Peinture usee : elle laisse passer l'asphalte par endroits, sinon la
        # ligne est un trait parfait qu'aucun parking n'a jamais eu.
        usure = hache(int(u * 90) + 3, int(v * 90) + 61)
        c = 132 + n * 26 - usure * 34
        return (c, c, c * 0.95)
    return (g, g + 1, g + 6)


def trottoir(u: float, v: float):
    """Dalles jointoyees, tuilable dans les deux sens."""
    n = hache(int(u * 190), int(v * 190))
    joint = 0.70 if (u % 0.5) < 0.030 or (v % 0.5) < 0.030 else 1.0
    g = (66 + n * 12) * joint
    return (g, g, g + 7)


def facade_vitres(base, graine: int):
    """Le masque d'EMISSION d'une facade : ce qui s'allume la nuit.

    C'EST LA PIECE QUI DEBLOQUE LE JOUR/NUIT.

    Jusqu'ici l'etat des fenetres etait peint dans la couleur meme de la
    facade : une texture de jour, une texture de nuit, choisies a la
    GENERATION. Le jeu ne pouvait donc pas changer d'heure — il aurait fallu
    refabriquer la ville, et le moment etait cuit dans le .glb.

    Ici, la facade n'a plus qu'une seule couleur — celle du jour, ou les vitres
    renvoient le ciel — et les fenetres allumees vivent dans un canal separe.
    Godot n'a plus qu'a monter l'emission de zero a un pour passer du jour a la
    nuit, en continu, sur les memes assets. L'aube et le crepuscule deviennent
    gratuits.

    Le tirage 'k' est IDENTIQUE a celui de facade() : c'est ce qui garantit que
    la fenetre qui s'allume est bien une fenetre, et pas un morceau de mur.
    """

    def fn(u: float, v: float):
        cu, cv = int(u * 2), int(v * 2)
        bu, bv = (u * 2) % 1.0, (v * 2) % 1.0

        noir = (0, 0, 0)
        if bv < 0.10:
            return noir
        if not (0.18 < bu < 0.82 and 0.24 < bv < 0.84):
            return noir
        # L'encadrement ne s'allume pas : seule la vitre.
        if bu < 0.235 or bu > 0.765 or bv < 0.295 or bv > 0.795:
            return noir

        k = hache(cu * 17 + graine * 5, cv * 23 + graine * 3)
        j = 0.88 + hache(int(u * 220), int(v * 220)) * 0.24
        if k > 0.86:
            return (94 * j, 200 * j, 126 * j)      # un neon vert
        if k > 0.46:
            return (210 * j, 158 * j, 80 * j)      # une lampe chaude
        return noir                                 # personne, ou tout le monde dort

    return fn


def facade(base, graine: int, jour: bool = False):
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
            k = hache(cu * 17 + graine * 5, cv * 23 + graine * 3)
            j = 0.88 + hache(int(u * 220), int(v * 220)) * 0.24
            if jour:
                # De jour, aucune fenetre n'est "allumee" : elles renvoient le
                # ciel. Les etats sont donc des inclinaisons de reflet, pas des
                # lampes — sinon on obtient des carres jaunes qui brillent en
                # plein soleil, ce qui trahit tout de suite la texture de nuit.
                if k > 0.86:
                    return (126 * j, 152 * j, 176 * j)
                if k > 0.46:
                    return (98 * j, 126 * j, 154 * j)
                return (72 * j, 92 * j, 116 * j)
            # De nuit : allume chaud, allume vert, ou eteint.
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
    # Passants anonymes. Trois suffisent : dans une rue, on ne compare pas
    # les visages, on remarque seulement s'ils sont tous identiques.
    "passant_a": {
        "peau": (176, 134, 104), "poil": (34, 28, 26),
        "cheveux": "courts", "lunettes": False,
        "moustache": False, "bouc": False,
    },
    "passant_b": {
        "peau": (222, 186, 158), "poil": (128, 92, 56),
        "cheveux": "longs", "lunettes": True,
        "moustache": False, "bouc": False,
    },
    "passant_c": {
        "peau": (142, 104, 78), "poil": (26, 22, 22),
        "cheveux": "calvitie", "lunettes": False,
        "moustache": True, "bouc": False,
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
    "passant_a": {"peau": (178, 136, 106), "haut": (74, 84, 104),
                  "capuche": False, "bas": (48, 50, 56)},
    "passant_b": {"peau": (224, 188, 160), "haut": (168, 148, 112),
                  "capuche": False, "bas": (86, 78, 70)},
    "passant_c": {"peau": (144, 106, 80), "haut": (108, 122, 96),
                  "capuche": True, "bas": (62, 68, 78)},
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


def uni(base, grain: float = 0.10, veine: bool = False):
    """Matiere unie et bruitee, pour les objets tenus en main.

    Ils font quelques centimetres a l'ecran : une texture detaillee y serait
    invisible, et seule la teinte compte. Le grain evite l'aplat plastique.
    """
    def rendu(u: float, v: float):
        n = hache(int(u * 190), int(v * 190))
        g = 1.0 + (n - 0.5) * 2.0 * grain
        if veine:                                  # tranche de pages, planches
            g *= 0.90 + 0.10 * ((int(v * 26) % 2))
        return (base[0] * g, base[1] * g, base[2] * g)
    return rendu


def planches(base, largeur: float = 0.14, joint: float = 0.30):
    """Lambris vertical : des lattes, et un joint sombre entre elles.

    C'est la matiere du bureau de Tuco — un lambris de bois sombre du sol au
    plafond — et c'est aussi celle des murs interieurs de la maison de Walter,
    ou l'on doit reperer LA latte qui n'est pas comme les autres. La regularite
    est donc le sujet : sans elle, rien ne depasse.
    """
    def rendu(u: float, v: float):
        n = hache(int(u * 230), int(v * 90))
        # Chaque latte a sa teinte propre, tiree de son numero : du bois debite
        # dans le meme arbre n'est jamais deux fois du meme ton.
        latte = int(u / largeur)
        teinte = 0.86 + 0.28 * hache(latte * 37, 11)
        g = teinte * (0.94 + n * 0.12)
        bord = (u / largeur) % 1.0
        if bord < joint * 0.12 or bord > 1.0 - joint * 0.12:
            g *= 1.0 - joint
        # Le fil du bois, horizontal et serre.
        g *= 0.97 + 0.03 * ((int(v * 120) % 3) == 0)
        return (base[0] * g, base[1] * g, base[2] * g)
    return rendu


def paillasse(u: float, v: float):
    """Le plan de travail du labo : contreplaque brut, tache par endroits.

    Les taches comptent plus que le bois. Un etabli propre dit « meuble de
    cuisine » ; ce sont les cernes et les brulures qui disent qu'on y travaille
    des produits.
    """
    n = hache(int(u * 200), int(v * 200))
    base = (152, 122, 84)
    g = 0.90 + n * 0.20
    g *= 0.96 + 0.04 * ((int(v * 44) % 4) == 0)
    # Cernes sombres, poses sur une grille lache pour ne pas se repeter a l'oeil
    t = hache(int(u * 9), int(v * 7))
    if t > 0.86:
        g *= 0.62 + 0.2 * n
    return (base[0] * g, base[1] * g, base[2] * g)


def graffiti(u: float, v: float):
    """Le mur peint du QG, vu de la rue.

    Aucune lettre : a la distance ou on le voit, une fresque de rue est une
    suite de TACHES vives cernees de noir. On empile donc des bandes de
    couleurs saturees et on les cerne, ce qui donne la meme lecture qu'un
    tag reel sans avoir a en dessiner un.
    """
    n = hache(int(u * 170), int(v * 170))
    # Le bas du mur est du beton nu : les fresques ne descendent pas au sol.
    if v > 0.86:
        g = 0.88 + n * 0.18
        return (146 * g, 142 * g, 134 * g)
    palette = [(196, 58, 48), (58, 92, 168), (214, 176, 56),
               (74, 148, 84), (156, 78, 156), (222, 226, 232)]
    # Des formes larges et obliques, comme les lettres bombees d'un tag.
    forme = int((u * 5.0 + v * 1.7 + 0.8 * hache(int(u * 6), int(v * 4))) % 6)
    base = palette[forme]
    g = 0.86 + n * 0.26
    # Le cerne noir entre deux formes.
    bord = (u * 5.0 + v * 1.7) % 1.0
    if bord < 0.10:
        g *= 0.22
    return (base[0] * g, base[1] * g, base[2] * g)


def store(u: float, v: float):
    """Un store venitien ferme : des lames, et la lumiere qui passe entre.

    C'est l'element central des deux interieurs de reference — le camping-car
    et le bureau de Tuco sont tous les deux eclaires par des raies horizontales.
    """
    n = hache(int(u * 120), int(v * 260))
    lame = (v * 34.0) % 1.0
    if lame > 0.78:
        # L'interstice : chaud et lumineux, c'est le soleil du dehors.
        g = 0.95 + n * 0.10
        return (236 * g, 206 * g, 150 * g)
    g = 0.70 + 0.30 * lame + n * 0.10
    return (128 * g, 118 * g, 104 * g)


def panneau_stop(u: float, v: float):
    """Panneau rouge barre de blanc. On ne lit jamais le mot a cette taille :
    ce qui identifie un stop, c'est le rouge et la barre claire."""
    n = hache(int(u * 150), int(v * 150))
    if 0.42 < v < 0.58 and 0.18 < u < 0.82:
        g = 232 + n * 16
        return (g, g, g * 0.98)
    base = (162, 34, 30)
    g = 0.92 + n * 0.14
    return (base[0] * g, base[1] * g, base[2] * g)


def panneau_ecrit(texte: str):
    """Fabrique un panneau routier vert portant CE texte.

    Les lettres sont dessinees a la main sur une grille 5x7 : a 128 pixels de
    large pour une poignee de caracteres, aucune police ne survivrait, et on ne
    peut pas non plus se contenter d'une barre claire comme pour le stop — la
    destination est justement l'information.

    LE TEXTE EST UN PARAMETRE, et il ne l'etait pas. Le panneau ne savait ecrire
    que DESERT : celui du retour vers la ville annoncait donc « DESERT » alors
    qu'il pointe vers Albuquerque, et il n'y avait aucun moyen d'en poser un
    pour le QG de Tuco. Une lettre en plus est une entree dans ALPHABET.
    """
    lettres = list(texte.upper())
    n_lettres = max(1, len(lettres))
    # Les lettres retrecissent quand il y en a beaucoup, mais pas en dessous
    # d'une hauteur lisible : au-dela d'une douzaine, mieux vaut deux lignes,
    # et on n'en est pas la.
    hauteur = min(0.28, 1.8 / n_lettres)

    def dessin(u: float, v: float):
        n = hache(int(u * 150), int(v * 150))
        fond = (28, 74, 52)
        g = 0.93 + n * 0.12

        # Le bord clair, qui donne au panneau sa lecture de panneau.
        if u < 0.045 or u > 0.955 or v < 0.07 or v > 0.93:
            return (214 * g, 222 * g, 214 * g)

        v0 = 0.5 - hauteur / 2.0
        if v0 < v < v0 + hauteur:
            col = (u - 0.09) / 0.82 * float(n_lettres)
            i = int(col)
            if 0 <= i < n_lettres:
                cx = (col - i - 0.08) / 0.84     # 0..1 dans la lettre
                cy = (v - v0) / hauteur          # 0..1, haut vers bas
                if 0.0 <= cx <= 1.0 and _lettre(lettres[i], cx, cy):
                    return (226 * g, 232 * g, 226 * g)

        return (fond[0] * g, fond[1] * g, fond[2] * g)

    return dessin


def portrait_hud(u: float, v: float):
    """Le portrait de Walter pour le HUD, en 32 pixels de cote.

    Trente-deux pixels, c'est la taille d'une vignette de jeu PS2, et c'est
    aussi trop peu pour un visage : on ne dessine donc pas un visage, on
    dessine ce qui le rend RECONNAISSABLE en trois traits. Chez Walter c'est le
    crane degarni, les lunettes et le bouc — dans cet ordre d'importance.

    Fond transparent impossible ici : le format de sortie du projet est un PNG
    opaque. On pose donc un fond sombre, qui fait cadre.
    """
    fond = (18, 20, 26)
    peau = (206, 168, 138)
    poil = (58, 52, 48)

    # Le cadre.
    if u < 0.06 or u > 0.94 or v < 0.06 or v > 0.94:
        return (92, 88, 80)

    # La tete : une ellipse un peu haute, posee bas dans le cadre.
    dx = (u - 0.5) / 0.34
    dy = (v - 0.56) / 0.40
    if dx * dx + dy * dy > 1.0:
        return fond

    # La couronne de cheveux : sur les cotes, jamais sur le dessus.
    if v < 0.34 and abs(u - 0.5) > 0.17:
        return poil
    # Le bouc, autour de la bouche.
    if v > 0.72 and abs(u - 0.5) < 0.17:
        return poil
    # Les lunettes : deux verres et le pont.
    if 0.44 < v < 0.56:
        if 0.20 < abs(u - 0.5) < 0.30:
            return (36, 38, 44)
        if abs(u - 0.5) < 0.06:
            return (36, 38, 44)
    if 0.46 < v < 0.54 and 0.09 < abs(u - 0.5) < 0.20:
        return (24, 26, 30)

    return peau


panneau_desert = panneau_ecrit("DESERT")
panneau_albuquerque = panneau_ecrit("ALBUQUERQUE")
panneau_tuco = panneau_ecrit("QG TUCO")

# Chaque lettre : sept lignes de cinq caracteres. Le point est vide, le diese
# est allume. Une grille 5x7 est le plus petit format ou l'alphabet latin reste
# lisible, et c'est celui des afficheurs de l'epoque.
ALPHABET = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "G": [".####", "#....", "#....", "#..##", "#...#", "#...#", ".####"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "N": ["#...#", "##..#", "##..#", "#.#.#", "#..##", "#..##", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#..#.", "#...#", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


def _lettre(c: str, x: float, y: float) -> bool:
    grille = ALPHABET.get(c)
    if grille is None:
        return False
    ligne = int(y * 7.0)
    colonne = int(x * 5.0)
    if not (0 <= ligne < 7 and 0 <= colonne < 5):
        return False
    return grille[ligne][colonne] == "#"


def fleche_orange(u: float, v: float):
    """Fleche peinte sur la chaussee, pointant vers le haut de la texture.

    Peinte, pas posee : elle porte le grain de l'asphalte au travers, sinon
    elle flotte au-dessus de la route comme un autocollant."""
    n = hache(int(u * 190), int(v * 190))
    sol = asphalte(u, v)

    # La hampe, puis la pointe. v croit vers le bas : la pointe est en v petit.
    dans = False
    if v > 0.42:
        dans = 0.38 < u < 0.62
    else:
        demi = v / 0.42 * 0.46 + 0.04      # s'elargit en descendant
        dans = abs(u - 0.5) < demi

    if not dans:
        return sol

    # L'usure : la peinture s'ecaille et laisse voir le bitume dessous.
    if n > 0.86:
        return sol
    g = 0.88 + n * 0.20
    return (226 * g, 128 * g, 34 * g)


def cactus(u: float, v: float):
    """Saguaro : vert sourd, cotes verticales marquees, epines claires."""
    n = hache(int(u * 200), int(v * 200))
    cote = abs(((u * 6.0) % 1.0) - 0.5) * 2.0        # 0 au creux, 1 sur l'arete
    base = (62, 92, 58)
    g = (0.80 + cote * 0.34) * (0.94 + n * 0.12)
    if n > 0.93 and cote > 0.7:
        return (198, 196, 168)                        # epine
    return (base[0] * g, base[1] * g, base[2] * g)


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


def fenetre_maison_fn(jour: bool = False):
    """Fenetre a deux vantaux. Eclairee de l'interieur la nuit, renvoyant le
    ciel le jour."""

    def fn(u: float, v: float):
        if u < 0.07 or u > 0.93 or v < 0.07 or v > 0.93:
            return (188, 178, 162)                 # dormant clair
        if 0.47 < u < 0.53:
            return (188, 178, 162)                 # meneau
        n = hache(int(u * 120), int(v * 120))
        if jour:
            # Un reflet de ciel qui s'assombrit vers le bas de la vitre.
            ciel = 1.10 - v * 0.38
            return (118 * ciel * (0.94 + n * 0.12),
                    146 * ciel * (0.94 + n * 0.12),
                    172 * ciel * (0.94 + n * 0.12))
        chaud = 0.82 + v * 0.35
        return (206 * chaud * (0.92 + n * 0.14),
                170 * chaud * (0.92 + n * 0.14),
                108 * chaud * (0.92 + n * 0.14))

    return fn


fenetre_maison = fenetre_maison_fn(False)


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
    "voiture_aztek": (154, 138, 108),      # le beige-sable de l'Aztek
    "voiture_b": (78, 84, 96),             # gris bleute, berline
    "voiture_c": (112, 62, 52),            # rouge brique fatigue, break
    "voiture_pickup": (58, 72, 62),        # vert sombre, pick-up
    # Le bleu Alpine. C'est la couleur qui identifie la voiture bien avant sa
    # forme, et la seule teinte saturee de tout le parc — dans une rue de
    # beiges et de gris, elle se voit a cent metres. C'est le but.
    "voiture_alpine": (28, 62, 138),
}


def camping_car(u: float, v: float):
    """La cellule du camping-car : blanc creme sale, avec la bande brune des
    campings-cars des annees quatre-vingt.

    Le sale n'est pas un detail : un blanc propre en plein desert ne se lit pas
    comme un vehicule qui a roule, et c'est tout ce qu'on demande a celui-la."""
    n = hache(int(u * 170), int(v * 170))
    trainee = hache(int(u * 30), int(v * 6) + 41)

    # Deux bandes horizontales, dans le tiers bas de la cellule.
    if 0.56 < v < 0.63:
        g = 0.90 + n * 0.16
        return (128 * g, 88 * g, 54 * g)
    if 0.66 < v < 0.70:
        g = 0.90 + n * 0.16
        return (154 * g, 116 * g, 72 * g)

    # La crasse monte du bas de caisse, pas du haut.
    bas = max(0.0, (v - 0.72)) / 0.28
    g = (0.92 + n * 0.14) * (1.0 - bas * 0.22 * (0.5 + trainee))
    return (216 * g, 210 * g, 194 * g)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sortie", default=".tmp/textures")
    ap.add_argument("--taille", type=int, default=128)
    ap.add_argument("--moment", default="nuit", choices=["jour", "nuit"],
                    help="l'etat des vitres est cuit dans la texture")
    ap.add_argument("--donnees", default="game/donnees/monde.json")
    args = ap.parse_args()

    dossier = Path(args.sortie)
    t = args.taille
    jour = args.moment == "jour"
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

    ecrire_png(dossier / "herbe.png", t, t, rendre(t, t, herbe))
    faits.append("herbe.png")

    ecrire_png(dossier / "montagne.png", t, t, rendre(t, t, montagne))
    faits.append("montagne.png")

    # --- le banc graphique : 256 px, deux fois le jeu ---
    d = t * 2
    for nom, fn in [("banc_mur", banc_mur), ("banc_toit", banc_toit),
                    ("banc_vitre", banc_vitre), ("banc_jante", banc_jante),
                    ("banc_jante_rouge", banc_jante_rouge)]:
        ecrire_png(dossier / f"{nom}.png", d, d, rendre(d, d, fn))
        faits.append(f"{nom}.png")
    for nom, base in [("banc_tole_bleue", (54, 78, 128)),
                      ("banc_tole_rouge", (146, 52, 44)),
                      ("banc_tole_creme", (196, 186, 156))]:
        ecrire_png(dossier / f"{nom}.png", d, d,
                   rendre(d, d, banc_carrosserie(base)))
        faits.append(f"{nom}.png")

    for k, base in enumerate(AFFICHES):
        ecrire_png(dossier / f"affiche_{k}.png", t, t, rendre(t, t, affiche(base, k)))
        faits.append(f"affiche_{k}.png")

    ecrire_png(dossier / "parking.png", t, t, rendre(t, t, parking))
    faits.append("parking.png")

    for i, (nom, couleur) in enumerate(FACADES.items()):
        # La couleur de base est TOUJOURS celle du jour, quel que soit --moment.
        # Les fenetres allumees ne sont plus peintes dedans : elles vivent dans
        # le masque d'emission ci-dessous, que le jeu monte et descend a l'heure
        # qu'il veut. Voir facade_vitres().
        ecrire_png(dossier / f"{nom}.png", t, t,
                   rendre(t, t, facade(couleur, i * 13, True)))
        ecrire_png(dossier / f"{nom}_vitres.png", t, t,
                   rendre(t, t, facade_vitres(couleur, i * 13)))
        ecrire_png(dossier / f"{nom}_mur.png", t, t, rendre(t, t, mur(couleur)))
        faits.append(f"{nom}.png + _vitres + _mur")

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

    # --- objets tenus en main ---
    for nom, base, grain, veine in [
        ("metal", (118, 120, 126), 0.09, False),
        ("metal_sombre", (58, 58, 62), 0.09, False),
        ("cristal", (150, 196, 214), 0.14, False),
        ("cristal_clair", (196, 232, 244), 0.16, False),
        # La « botte secrete » : un cristal BLANC, la ou la meth de Walter tire
        # sur le bleu. Il faut qu'on les distingue d'un coup d'oeil dans la
        # roue — c'est tout l'enjeu de la scene chez Tuco.
        ("cristal_blanc", (232, 231, 226), 0.12, False),
        ("cristal_blanc_vif", (250, 250, 248), 0.10, False),
        ("couverture", (96, 62, 46), 0.10, False),
        ("pages", (226, 218, 196), 0.06, True),
        ("feutre", (48, 46, 48), 0.08, False),
        ("feutre_sombre", (30, 28, 30), 0.08, False),
        # --- la mission : le labo, et le QG de Tuco ---
        ("verre_labo", (206, 224, 226), 0.07, False),
        ("liquide_ambre", (196, 138, 44), 0.09, False),
        ("liquide_vert", (96, 168, 92), 0.09, False),
        ("bidon_rouge", (150, 44, 38), 0.11, False),
        ("bidon_bleu", (54, 78, 128), 0.11, False),
        ("inox", (170, 174, 178), 0.08, False),
        ("lino", (118, 104, 88), 0.13, True),
        ("bache", (86, 84, 78), 0.12, False),
        ("cuir_sombre", (58, 40, 32), 0.10, False),
        ("bureau_bois", (78, 48, 30), 0.10, True),
        ("mur_qg", (62, 56, 50), 0.12, False),
        ("planche_barricade", (92, 74, 54), 0.12, True),
    ]:
        ecrire_png(dossier / f"{nom}.png", t // 4, t // 4,
                   rendre(t // 4, t // 4, uni(base, grain, veine)))
        faits.append(f"{nom}.png")

    # --- mobilier urbain ---
    for nom, base, grain, veine in [
        ("plastique", (46, 62, 50), 0.10, False),
        ("rouille", (122, 80, 54), 0.16, False),
        ("bois_banc", (112, 76, 46), 0.12, True),
        ("rouge_borne", (156, 44, 36), 0.10, False),
        ("beton", (128, 124, 116), 0.09, False),
        # LES VARIANTES DE COULEUR. Le meme objet, repeint.
        #
        # Trois cents poubelles rigoureusement identiques se lisent comme un
        # copier-coller, et c'est ce qu'on voit en premier dans une rue
        # generee. Une teinte differente coute une texture de 32 pixels et
        # casse la repetition mieux que n'importe quel objet supplementaire.
        ("plastique_bleu", (44, 58, 92), 0.10, False),
        ("plastique_gris", (78, 80, 80), 0.10, False),
        ("rouille_verte", (58, 84, 56), 0.14, False),
        ("rouille_bleue", (48, 66, 96), 0.14, False),
        ("toile_abri", (62, 70, 78), 0.10, False),
        ("verre_cabine", (128, 158, 164), 0.06, False),
        ("journal_boite", (156, 60, 44), 0.10, False),
    ]:
        ecrire_png(dossier / f"{nom}.png", t // 4, t // 4,
                   rendre(t // 4, t // 4, uni(base, grain, veine)))
        faits.append(f"{nom}.png")

    for nom, fn in [("panneau_stop", panneau_stop), ("cactus", cactus),
                    ("paillasse", paillasse), ("store", store),
                    ("lambris", planches((84, 52, 34))),
                    ("latte_mur", planches((156, 146, 130), 0.11, 0.34))]:
        ecrire_png(dossier / f"{nom}.png", t // 2, t // 2,
                   rendre(t // 2, t // 2, fn))
        faits.append(f"{nom}.png")

    # La fresque du QG reste en pleine resolution : c'est un mur entier vu de
    # face depuis la rue, et c'est la premiere chose qu'on voit en arrivant.
    ecrire_png(dossier / "graffiti.png", t, t, rendre(t, t, graffiti))
    faits.append("graffiti.png")

    # Le panneau de direction et la fleche au sol restent en pleine resolution :
    # le premier porte du texte, la seconde une diagonale. Les deux se lisent
    # tres mal a 64 pixels, alors qu'un panneau stop n'est qu'un aplat rouge.
    # Le portrait du HUD : 32 pixels, sa taille d'affichage. L'agrandir puis le
    # reduire a l'ecran ne ferait que le rendre flou.
    ecrire_png(dossier / "visage.png", 32, 32, rendre(32, 32, portrait_hud))
    faits.append("visage.png")

    for nom, fn in [("panneau_desert", panneau_desert),
                    ("panneau_albuquerque", panneau_albuquerque),
                    ("panneau_tuco", panneau_tuco),
                    ("fleche_orange", fleche_orange),
                    ("camping_car", camping_car)]:
        ecrire_png(dossier / f"{nom}.png", t, t, rendre(t, t, fn))
        faits.append(f"{nom}.png")

    # --- maisons ---
    for nom, fn in [("crepi", crepi), ("bardage", bardage), ("toit", toit),
                    ("porte", porte),
                    ("fenetre_maison", fenetre_maison_fn(jour)),
                    ("parquet", parquet), ("mur_interieur", mur_interieur),
                    ("carrelage", carrelage)]:
        ecrire_png(dossier / f"{nom}.png", t, t, rendre(t, t, fn))
        faits.append(f"{nom}.png")

    # Le moment de la journee est ecrit ICI, une seule fois, par celui qui
    # cuit les vitres. Le jeu le relit au lancement pour choisir son ciel, son
    # soleil et l'allumage des lampadaires.
    #
    # Une source unique, parce que le contraire ne pardonne pas : un reglage
    # de nuit cote jeu avec des textures de jour donne une ville noire aux
    # fenetres bleues, et personne ne sait lequel des deux a tort.
    donnees = Path(args.donnees)
    if not donnees.is_absolute():
        donnees = Path.cwd() / donnees
    donnees.parent.mkdir(parents=True, exist_ok=True)
    donnees.write_text(json.dumps({
        "_lisez_moi": [
            "Ecrit par outils/gen_textures.py. Ne pas modifier a la main :",
            "l'etat des vitres est cuit dans les textures, et changer ce",
            "fichier seul donnerait un ciel de jour sur des fenetres de nuit.",
            "Pour changer : .\\bg.ps1 generer -Moment jour",
        ],
        "moment": args.moment,
    }, indent=1, ensure_ascii=False), encoding="utf-8")

    print(f"{len(faits)} textures ecrites dans {dossier}/  (moment : {args.moment})")
    for f in faits:
        print(f"  {f}")


if __name__ == "__main__":
    main()
