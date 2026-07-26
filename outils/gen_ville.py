#!/usr/bin/env python3
"""Genere un quartier d'Albuquerque en damier et l'exporte en glTF.

    blender -b -P outils/gen_ville.py -- --blocs 2 --seed 505

Albuquerque est le monde ouvert le moins cher qui existe : une grille de rues
droites posee dans un desert plat. Ce script en tire parti — tout est parametre,
rien n'est place a la main, et une graine donnee redonne toujours la meme ville.

Principe d'architecture : le generateur PLACE DES MODULES sur une grille.
D'ou viennent les modules est un parametre. Les boites texturees produites ici
sont des modules par defaut ; les immeubles de Guillaume prendront leur place
sans que ce fichier change.

                COULOIR = 17 m
        |<-------------------->|
        | 3 |       11      | 3 |
        trot    chaussee    trot      <- entre deux ilots
                                      PAS = 40 + 17 = 57 m
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh

# Toutes les distances sont en metres. Blender est en Z-up ; l'exportateur
# glTF convertit vers le Y-up de Godot, on ne compense rien a la main.

# Largeur de la chaussee, en metres.
#
# Elle etait a 8, ce qui parait genereux — jusqu a ce qu on y gare des
# voitures des deux cotes. Mesure : il restait 3,84 m de passage libre pour
# une caisse de 1,86 m, soit moins d un metre de chaque cote. Longer un
# trottoir a cinquante devenait impossible sans accrocher, et la sensation
# etait celle d une ville qui freine sans raison.
#
# Le trottoir n y etait pour rien. La mesure l a montre : le franchir coute un
# kilometre/heure. C est le stationnement qui etranglait la rue.
ROUTE = 11.0
TROTTOIR = 3.0
H_TROTTOIR = 0.18

BLOC = 40.0
BATI = 12.0                # profondeur des immeubles, cour au centre de l'ilot
COULOIR = ROUTE + 2 * TROTTOIR
PAS = BLOC + COULOIR

# La texture de facade contient 2 x 2 travees : un module UV couvre donc
# deux travees de large et deux etages de haut.
MODULE_U = 6.8             # 2 travees de 3,4 m
MODULE_V = 5.8             # 2 etages de 2,9 m
TUILE_ROUTE = 5.0          # la texture de chaussee se repete tous les 5 m
TUILE_SOL = 2.0
TUILE_DESERT = 12.0
Z_ROUTE = 0.01

ESPACEMENT_LAMPES = 20.0
FACADES = ["facade_a", "facade_b", "facade_c", "facade_d"]
HAUTEURS = [4.6, 5.8, 7.1, 8.4, 9.7, 11.2]

# Parcelles laissees vides, ou l'on pose ensuite des batiments faits main.
# Un tuple par cote d'ilot : (ilot_x, ilot_y, cote).
#
# Repere par ilot plutot qu'en metres : la reserve reste au bon endroit si
# la taille des ilots ou le nombre de blocs change.
#
# La facade sud de l'ilot (0, 0) donne sur le carrefour de depart. C'est la
# que vivent Walter et Jesse : a vingt metres du point ou commence la partie.
RESERVES = {(0, 0, "sud")}

# Vers ou regarde un objet pose sur ce cote d'ilot, en radians. La facade sud
# donne sur la rue au sud, donc on lui tourne le dos pour la regarder.
CAPS = {"sud": 0.0, "nord": math.pi, "ouest": math.pi / 2, "est": -math.pi / 2}

# Mobilier urbain. Il n'est PAS cuit dans le maillage de la ville : le
# generateur ne fait qu'ecrire ou le poser, et le jeu instancie. Trois cents
# poubelles fondues dans le .glb pesent trois cents fois le prix d'une seule.
#
# Le tirage est pondere : une rue est faite de poubelles et de bornes, pas
# d'un echantillonnage equitable du catalogue.
MOBILIER = [
    ("poubelle", 34), ("borne", 20), ("banc", 14),
    ("benne", 10), ("cactus", 8),
]

# Ecart moyen entre deux elements le long d'un trottoir, en metres.
ESPACEMENT_DECOR = 9.0

# Un climatiseur sur ce toit-ci ? Sans eux, chaque immeuble est une boite
# parfaite, et ca se voit tout de suite d'en haut comme depuis la rue.
PROBA_CLIM = 0.4

# Voitures a l'arret le long des trottoirs. Purement decoratives — une rue
# vide de vehicules ne se lit pas comme une ville, quelle que soit la
# densite du mobilier.
ESPACEMENT_VOITURES = 13.0

# Quelles voitures sont garees, et en quelle proportion.
#
# Le tirage est pondere parce qu'une rue d'Albuquerque en 2009 n'est pas un
# echantillonnage equitable du catalogue : on y voit surtout des pick-up et de
# grosses berlines. L'Alpine est a 1 sur 100 — c'est une voiture qu'on remarque,
# et on ne remarque que ce qui est rare.
MODELES_GAREES = [
    ("pickup", 34), ("berline", 26), ("break", 22), ("aztek", 17),
    ("alpine", 1),
]
PROBA_PLACE_OCCUPEE = 0.55

# Passants. Chacun arpente un segment de trottoir. Pas de foule : dix
# silhouettes qui bougent en donnent plus qu'une centaine d'immobiles.
PIETONS_PAR_COTE = 1
LONGUEUR_TRAJET = 26.0


# ------------------------------------------------------------------ utilitaires


def arguments() -> argparse.Namespace:
    """Blender avale ses propres arguments : les notres sont apres --."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de ville")
    ap.add_argument("--blocs", type=int, default=2, help="ilots par cote")
    ap.add_argument("--seed", type=int, default=505)
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default="game/assets/ville/ville.glb")
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path) -> bpy.types.Material:
    """Materiau mat, non metallique, texture en couleur de base.

    Aucun reflet speculaire : la PS2 n'en avait pas, et un reflet trahit
    immediatement un rendu moderne.
    """
    if nom in bpy.data.materials:
        return bpy.data.materials[nom]

    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    arbre = mat.node_tree
    bsdf = arbre.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    for champ in ("Specular IOR Level", "Specular"):
        if champ in bsdf.inputs:
            bsdf.inputs[champ].default_value = 0.0

    png = dossier / f"{nom}.png"
    if not png.exists():
        # La palette vit dans .tmp/, hors du projet Godot : elle n est qu une
        # matiere premiere, cuite dans le .glb a l export. Sans elle le modele
        # sortait gris SANS RIEN DIRE, et on cherchait le probleme dans Blender.
        raise SystemExit(
            f"texture absente : {png}\n"
            f"La palette se refabrique : .\\bg.ps1 generer"
        )
    img = bpy.data.images.load(str(png), check_existing=True)
    img.pack()                                  # embarquee dans le .glb
    tex = arbre.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"                # bilineaire : le flou PS2
    tex.extension = "REPEAT"
    tex.location = (-420, 220)
    arbre.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    # Les fenetres allumees, sur le canal d'EMISSION.
    #
    # C'est ce qui permet au jeu de changer d'heure sans refabriquer la ville.
    # La couleur de base porte les vitres de jour, qui renvoient le ciel ; le
    # masque porte celles qui s'allument. Godot n'a plus qu'a monter ou
    # descendre l'energie d'emission, en continu.
    #
    # La force est laissee a 1 a l'export, PAS a 0 : l'exportateur glTF
    # abandonne purement et simplement une texture d'emission dont la force est
    # nulle, et le masque n'arriverait jamais dans le .glb. C'est le jeu qui la
    # ramene a zero de jour, des le chargement.
    vitres = dossier / f"{nom}_vitres.png"
    if vitres.exists() and "Emission Color" in bsdf.inputs:
        img_v = bpy.data.images.load(str(vitres), check_existing=True)
        img_v.pack()
        tex_v = arbre.nodes.new("ShaderNodeTexImage")
        tex_v.image = img_v
        tex_v.interpolation = "Linear"
        tex_v.extension = "REPEAT"
        tex_v.location = (-420, -160)
        arbre.links.new(tex_v.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat


class Maillage:
    """Un objet Blender par materiau, rempli face par face."""

    def __init__(self, nom: str, mat: bpy.types.Material):
        self.mesh = bpy.data.meshes.new(nom)
        self.obj = bpy.data.objects.new(nom, self.mesh)
        bpy.context.collection.objects.link(self.obj)
        self.mesh.materials.append(mat)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def face(self, points, uvs) -> None:
        verts = [self.bm.verts.new(p) for p in points]
        f = self.bm.faces.new(verts)
        for boucle, coord in zip(f.loops, uvs):
            boucle[self.uv].uv = coord

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


def dalle(m: Maillage, x0, y0, x1, y1, z, tuile) -> None:
    """Quadrilatere horizontal, UV libre dans les deux sens."""
    m.face(
        [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)],
        [(x0 / tuile, y0 / tuile), (x1 / tuile, y0 / tuile),
         (x1 / tuile, y1 / tuile), (x0 / tuile, y1 / tuile)],
    )


def chaussee(m: Maillage, x0, y0, x1, y1, sens: str) -> None:
    """Bande de chaussee. u traverse la largeur (0 a 1, la texture contient
    les rives et la ligne axiale), v suit la longueur."""
    if sens == "x":
        a, b = x0 / TUILE_ROUTE, x1 / TUILE_ROUTE
        uv = [(0, a), (0, b), (1, b), (1, a)]
        pts = [(x0, y0, Z_ROUTE), (x1, y0, Z_ROUTE),
               (x1, y1, Z_ROUTE), (x0, y1, Z_ROUTE)]
    else:
        a, b = y0 / TUILE_ROUTE, y1 / TUILE_ROUTE
        uv = [(0, a), (1, a), (1, b), (0, b)]
        pts = [(x0, y0, Z_ROUTE), (x1, y0, Z_ROUTE),
               (x1, y1, Z_ROUTE), (x0, y1, Z_ROUTE)]
    m.face(pts, uv)


def boite(m: Maillage, x0, y0, x1, y1, z0, z1, mu=MODULE_U, mv=MODULE_V) -> None:
    """Boite sans face inferieure. Les quatre cotes sont mappes par module de
    facade, le dessus recoit une UV neutre."""
    lx, ly, lz = x1 - x0, y1 - y0, z1 - z0
    nz = lz / mv
    for pts, longueur in [
        ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], lx),
        ([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], lx),
        ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], ly),
        ([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], ly),
    ]:
        nu = longueur / mu
        m.face(pts, [(0, 0), (nu, 0), (nu, nz), (0, nz)])
    m.face(
        [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        [(0, 0), (lx / mu, 0), (lx / mu, ly / mu), (0, ly / mu)],
    )


def lampadaire(m: Maillage, x, y, vx, vy) -> None:
    """Poteau, potence, tete. Geometrie minimale : une PS2 n'aurait pas
    depense plus de triangles la-dessus."""
    r = 0.07
    boite(m, x - r, y - r, x + r, y + r, 0.0, 3.4, 1.0, 3.4)
    bx, by = x + vx * 0.6, y + vy * 0.6
    boite(m, min(x, bx) - r, min(y, by) - r, max(x, bx) + r, max(y, by) + r,
          3.28, 3.40, 1.0, 1.0)
    boite(m, bx - 0.30, by - 0.18, bx + 0.30, by + 0.18, 3.06, 3.28, 1.0, 1.0)


# ---------------------------------------------------------------------- ville


def tirer(rng: random.Random, table: list = None) -> str:
    """Un nom tire au sort dans une table ponderee.

    Sert au mobilier comme aux modeles de voitures : les deux ont besoin d'un
    tirage NON equitable. Une rue est faite de poubelles et de bornes, pas d'un
    echantillonnage du catalogue.
    """
    if table is None:
        table = MOBILIER
    total = sum(poids for _, poids in table)
    seuil = rng.uniform(0.0, total)
    for nom, poids in table:
        seuil -= poids
        if seuil <= 0.0:
            return nom
    return table[0][0]


def mobilier_de_cote(ox: float, oy: float, cote: str,
                     rng: random.Random) -> list[dict]:
    """Pose du mobilier le long d'un cote d'ilot, contre les facades.

    Contre les FACADES, pas au bord du trottoir : les lampadaires occupent
    deja la bordure. Les deux rangees ne se croisent donc jamais, et on garde
    le passage libre au milieu — un trottoir infranchissable serait pire que
    vide.
    """
    recul = 0.9                       # distance a la facade
    marge = 3.0                       # on s'ecarte des angles
    objets: list[dict] = []

    # (position fixe, axe qui varie, angle) — l'objet regarde la rue.
    if cote == "ouest":
        fixe, angle, axe = ox - recul, -math.pi / 2, "y"
    elif cote == "est":
        fixe, angle, axe = ox + BLOC + recul, math.pi / 2, "y"
    elif cote == "sud":
        fixe, angle, axe = oy - recul, 0.0, "x"
    else:
        fixe, angle, axe = oy + BLOC + recul, math.pi, "x"

    debut = (oy if axe == "y" else ox) + marge
    fin = debut + BLOC - 2 * marge
    pos = debut + rng.uniform(0.0, ESPACEMENT_DECOR)
    while pos < fin:
        x, y = (fixe, pos) if axe == "y" else (pos, fixe)
        objets.append({
            "type": tirer(rng),
            "pos": [round(x, 3), 0.18, round(-y, 3)],   # sur le trottoir
            "angle": round(angle + rng.uniform(-0.18, 0.18), 3),
        })
        pos += ESPACEMENT_DECOR * rng.uniform(0.65, 1.45)
    return objets


def voitures_de_cote(ox: float, oy: float, cote: str,
                     rng: random.Random) -> list[dict]:
    """Voitures garees le long du trottoir, nez dans le sens de la rue."""
    bord = TROTTOIR + 1.15          # a un metre du trottoir, sur la chaussee
    objets: list[dict] = []

    if cote == "ouest":
        fixe, angle, axe = ox - bord, 0.0, "y"
    elif cote == "est":
        fixe, angle, axe = ox + BLOC + bord, math.pi, "y"
    elif cote == "sud":
        fixe, angle, axe = oy - bord, math.pi / 2, "x"
    else:
        fixe, angle, axe = oy + BLOC + bord, -math.pi / 2, "x"

    debut = (oy if axe == "y" else ox) + 4.0
    pos = debut
    while pos < debut + BLOC - 8.0:
        if rng.random() < PROBA_PLACE_OCCUPEE:
            x, y = (fixe, pos) if axe == "y" else (pos, fixe)
            objets.append({
                "type": "garee_" + tirer(rng, MODELES_GAREES),
                "pos": [round(x, 3), 0.0, round(-y, 3)],
                "angle": round(angle + rng.uniform(-0.03, 0.03), 3),
            })
        pos += ESPACEMENT_VOITURES
    return objets


def pietons_de_cote(ox: float, oy: float, cote: str,
                    rng: random.Random) -> list[dict]:
    """Trajets de passants : un segment de trottoir, parcouru en aller-retour.

    Le trajet est au MILIEU du trottoir, entre les lampadaires cote bordure
    et le mobilier cote facade. Sans cette voie centrale, les passants
    passeraient leur temps a buter dans une poubelle.
    """
    milieu = TROTTOIR / 2.0
    trajets: list[dict] = []

    if cote == "ouest":
        fixe, axe = ox - milieu, "y"
    elif cote == "est":
        fixe, axe = ox + BLOC + milieu, "y"
    elif cote == "sud":
        fixe, axe = oy - milieu, "x"
    else:
        fixe, axe = oy + BLOC + milieu, "x"

    base = (oy if axe == "y" else ox)
    for _ in range(PIETONS_PAR_COTE):
        a = base + rng.uniform(2.0, BLOC - LONGUEUR_TRAJET - 2.0)
        b = a + LONGUEUR_TRAJET * rng.uniform(0.7, 1.0)
        p1 = (fixe, a) if axe == "y" else (a, fixe)
        p2 = (fixe, b) if axe == "y" else (b, fixe)
        trajets.append({
            "depart": [round(p1[0], 2), 0.2, round(-p1[1], 2)],
            "arrivee": [round(p2[0], 2), 0.2, round(-p2[1], 2)],
            "allure": round(rng.uniform(0.55, 0.95), 2),
            "modele": rng.choice(["passant_a", "passant_b", "passant_c"]),
        })
    return trajets


def graphe_des_rues(n: int) -> dict:
    """Le reseau routier : des carrefours, et des troncons entre eux.

    POURQUOI UN GRAPHE, ET PAS DES SEGMENTS.

    Les passants faisaient jusqu'ici un aller-retour sur un bout de trottoir
    fixe, pour toujours. Ca tient trente secondes : au-dela, on voit que le
    meme homme refait les memes vingt-cinq metres, ne tourne jamais un coin et
    n'entre nulle part.

    Et surtout ce n'est pas transposable aux voitures. Une voiture qui fait
    demi-tour au bout d'un troncon et repart en marche arriere est absurde ;
    elle doit tourner aux carrefours. Il faut donc un reseau, pas des segments.

    Le graphe est le meme pour les deux, a une largeur pres : les carrefours
    sont aux memes endroits, seule la voie change. Les pietons prennent le
    milieu du trottoir, les voitures leur file de droite.

    Les indices vont de 0 a n inclus dans les deux directions : (i, j) est le
    carrefour de la i-eme rue nord-sud et de la j-eme rue est-ouest.
    """
    axe = TROTTOIR + ROUTE / 2.0
    noeuds: list[list[float]] = []
    index: dict[tuple[int, int], int] = {}
    for i in range(n + 1):
        for j in range(n + 1):
            index[(i, j)] = len(noeuds)
            noeuds.append([round(i * PAS + axe, 3), 0.0,
                           round(-(j * PAS + axe), 3)])

    aretes: list[list[int]] = []
    for i in range(n + 1):
        for j in range(n + 1):
            if i < n:
                aretes.append([index[(i, j)], index[(i + 1, j)]])
            if j < n:
                aretes.append([index[(i, j)], index[(i, j + 1)]])

    return {
        "noeuds": noeuds,
        "aretes": aretes,
        # De combien un vehicule se decale a DROITE de l'axe du troncon.
        #
        # C'est ce qui donne la circulation a droite sans doubler le graphe :
        # deux voitures en sens inverse sur la meme arete se croisent au lieu
        # de se percuter. Un quart de chaussee, soit le milieu de sa voie.
        "demi_voie": round(ROUTE / 4.0, 3),
        # Le milieu du trottoir, pour les pietons : entre les lampadaires cote
        # bordure et le mobilier cote facade.
        "ecart_trottoir": round(ROUTE / 2.0 + TROTTOIR / 2.0, 3),
    }


def cactus_du_desert(etendue: float, rng: random.Random,
                     combien: int = 70) -> list[dict]:
    """Seme des cactus autour de la ville.

    Le desert est un aplat parfaitement plat et parfaitement vide : de nuit
    il ne se distingue pas du neant. Quelques silhouettes suffisent a lui
    rendre une echelle et une profondeur.
    """
    objets: list[dict] = []
    bande = 75.0
    essais = 0
    while len(objets) < combien and essais < combien * 20:
        essais += 1
        x = rng.uniform(-bande, etendue + bande)
        y = rng.uniform(-bande, etendue + bande)
        # Rien dans la ville ni collé contre : le desert commence apres.
        if -4.0 < x < etendue + 4.0 and -4.0 < y < etendue + 4.0:
            continue
        objets.append({
            "type": "cactus",
            "pos": [round(x, 2), 0.0, round(-y, 2)],
            "angle": round(rng.uniform(0.0, 6.28), 3),
        })
    return objets


def construire(n: int, rng: random.Random, mats: dict) -> dict:
    noms = ["route", "asphalte", "trottoir", "desert", "lampes"] + FACADES
    m = {nom: Maillage(nom, mats[nom]) for nom in noms}

    etendue = n * BLOC + (n + 1) * COULOIR
    lampes: list[tuple[float, float, float, float]] = []
    decor: list[dict] = []
    pietons: list[dict] = []
    # LES ANCRES : les lieux nommes de la ville.
    #
    # Le generateur SAIT ou sont les choses — il les construit. Jusqu'ici il
    # gardait ce savoir pour lui et ne publiait que des listes plates : trente-
    # deux lampadaires, cent soixante-six decors, quinze trajets. Tout ce qui
    # devait etre pose a un endroit precis l'etait a des coordonnees recopiees
    # a la main dans la scene, qui se perimaient au premier changement de
    # gabarit.
    lieux: list[dict] = []

    # --- chaussees et carrefours -------------------------------------------
    # Corridor k : [k*PAS, k*PAS + COULOIR]. Chaussee au centre : +TROTTOIR.
    # Carrefour (i, j) : croisement des chaussees i et j.
    for j in range(n + 1):
        ry0 = j * PAS + TROTTOIR
        ry1 = ry0 + ROUTE
        for i in range(n):                       # segments horizontaux
            sx0 = i * PAS + TROTTOIR + ROUTE
            sx1 = (i + 1) * PAS + TROTTOIR
            chaussee(m["route"], sx0, ry0, sx1, ry1, "x")

    for i in range(n + 1):
        rx0 = i * PAS + TROTTOIR
        rx1 = rx0 + ROUTE
        for j in range(n):                       # segments verticaux
            sy0 = j * PAS + TROTTOIR + ROUTE
            sy1 = (j + 1) * PAS + TROTTOIR
            chaussee(m["route"], rx0, sy0, rx1, sy1, "y")

    for i in range(n + 1):
        for j in range(n + 1):
            dalle(m["asphalte"],
                  i * PAS + TROTTOIR, j * PAS + TROTTOIR,
                  i * PAS + TROTTOIR + ROUTE, j * PAS + TROTTOIR + ROUTE,
                  Z_ROUTE, TUILE_ROUTE)

    # --- ilots ---------------------------------------------------------------
    for bx in range(n):
        for by in range(n):
            ox = COULOIR + bx * PAS
            oy = COULOIR + by * PAS
            x0, y0 = ox - TROTTOIR, oy - TROTTOIR
            x1, y1 = ox + BLOC + TROTTOIR, oy + BLOC + TROTTOIR
            t = TROTTOIR

            # dessus du trottoir : anneau en quatre bandes
            for a, b, c, d in [
                (x0, y0, x1, y0 + t), (x0, y1 - t, x1, y1),
                (x0, y0 + t, x0 + t, y1 - t), (x1 - t, y0 + t, x1, y1 - t),
            ]:
                dalle(m["trottoir"], a, b, c, d, H_TROTTOIR, TUILE_SOL)

            # bordure : quatre faces verticales, pas une ligne peinte
            #
            # On a essaye de les BISEAUTER, en croyant qu une face droite de
            # dix-huit centimetres arretait la voiture. Mesure faite image par
            # image : elle la franchit sans peine, et le biseau ne changeait
            # rien — a 54 km/h le trottoir coute un kilometre/heure. Ce qui
            # bloquait etait le stationnement des deux cotes d une chaussee
            # de huit metres. Voir ROUTE.
            for pts, lg in [
                ([(x0, y0, 0), (x1, y0, 0), (x1, y0, H_TROTTOIR), (x0, y0, H_TROTTOIR)], x1 - x0),
                ([(x1, y1, 0), (x0, y1, 0), (x0, y1, H_TROTTOIR), (x1, y1, H_TROTTOIR)], x1 - x0),
                ([(x1, y0, 0), (x1, y1, 0), (x1, y1, H_TROTTOIR), (x1, y0, H_TROTTOIR)], y1 - y0),
                ([(x0, y1, 0), (x0, y0, 0), (x0, y0, H_TROTTOIR), (x0, y1, H_TROTTOIR)], y1 - y0),
            ]:
                nu, nv = lg / TUILE_SOL, H_TROTTOIR / TUILE_SOL
                m["trottoir"].face(pts, [(0, 0), (nu, 0), (nu, nv), (0, nv)])

            # cour interieure, en terre
            dalle(m["desert"], ox + BATI, oy + BATI,
                  ox + BLOC - BATI, oy + BLOC - BATI, 0.02, TUILE_SOL)

            # immeubles : une rangee par cote de l'ilot
            for cx0, cy0, cx1, cy1, axe, cote in [
                (ox, oy, ox + BLOC, oy + BATI, "x", "sud"),
                (ox, oy + BLOC - BATI, ox + BLOC, oy + BLOC, "x", "nord"),
                (ox, oy + BATI, ox + BATI, oy + BLOC - BATI, "y", "ouest"),
                (ox + BLOC - BATI, oy + BATI, ox + BLOC, oy + BLOC - BATI, "y", "est"),
            ]:
                # Une parcelle reservee reste vide : c'est la qu'on pose les
                # batiments faits main. Sans ca, il n'y a pas un metre carre
                # libre en bordure de rue et les maisons finissent hors de la
                # ville, dans le desert, ou personne ne va jamais.
                if (bx, by, cote) in RESERVES:
                    dalle(m["desert"], cx0, cy0, cx1, cy1, 0.02, TUILE_SOL)
                    # La parcelle reservee devient une ANCRE : un lieu nomme,
                    # dont le jeu lit la position au lieu de la recopier.
                    #
                    # C'est ce qui manquait. Les maisons et le panneau du
                    # desert etaient poses a des coordonnees ecrites a la main
                    # dans la scene ; le jour ou la chaussee est passee de huit
                    # a onze metres, toute la grille a glisse de trois metres et
                    # le panneau s'est retrouve au milieu de la route. Deux fois.
                    # Le BORD : la place de stationnement devant la parcelle,
                    # sur la chaussee. Le centre de la parcelle ne suffit pas —
                    # il tombe derriere les maisons, dans la cour. Tout ce
                    # qu'on veut poser « devant chez Walter » a besoin de ce
                    # point-la, pas de l'autre.
                    if cote == "sud":
                        bord = (ox + BLOC / 2.0, oy - TROTTOIR - 1.15)
                    elif cote == "nord":
                        bord = (ox + BLOC / 2.0, oy + BLOC + TROTTOIR + 1.15)
                    elif cote == "ouest":
                        bord = (ox - TROTTOIR - 1.15, oy + BLOC / 2.0)
                    else:
                        bord = (ox + BLOC + TROTTOIR + 1.15, oy + BLOC / 2.0)
                    lieux.append({
                        "nom": "reserve_%d_%d_%s" % (bx, by, cote),
                        "pos": [round((cx0 + cx1) / 2.0, 3), 0.0,
                                round(-(cy0 + cy1) / 2.0, 3)],
                        "bord": [round(bord[0], 3), 0.0, round(-bord[1], 3)],
                        "cap": round(CAPS[cote], 3),
                        "longueur": round(
                            (cx1 - cx0) if axe == "x" else (cy1 - cy0), 3),
                    })
                    continue

                decor += mobilier_de_cote(ox, oy, cote, rng)
                decor += voitures_de_cote(ox, oy, cote, rng)
                pietons += pietons_de_cote(ox, oy, cote, rng)

                longueur = (cx1 - cx0) if axe == "x" else (cy1 - cy0)
                pos = 0.0
                while longueur - pos > 5.0:
                    large = min(rng.uniform(8.0, 14.0), longueur - pos)
                    if longueur - pos - large < 5.0:
                        large = longueur - pos
                    h = rng.choice(HAUTEURS)
                    mat = rng.choice(FACADES)
                    if axe == "x":
                        boite(m[mat], cx0 + pos, cy0, cx0 + pos + large, cy1, 0.0, h)
                        centre = (cx0 + pos + large / 2, (cy0 + cy1) / 2)
                    else:
                        boite(m[mat], cx0, cy0 + pos, cx1, cy0 + pos + large, 0.0, h)
                        centre = ((cx0 + cx1) / 2, cy0 + pos + large / 2)
                    if rng.random() < PROBA_CLIM:
                        decor.append({"type": "climatiseur",
                                      "pos": [centre[0], h, -centre[1]],
                                      "angle": rng.uniform(0.0, 6.28)})
                    pos += large

            # lampadaires, tournes vers la chaussee
            nb = max(2, int(BLOC / ESPACEMENT_LAMPES))
            for k in range(nb):
                f = (k + 0.5) / nb
                lampes += [
                    (x0 + f * (x1 - x0), y0 + 0.9, 0.0, -1.0),
                    (x0 + f * (x1 - x0), y1 - 0.9, 0.0, 1.0),
                    (x0 + 0.9, y0 + f * (y1 - y0), -1.0, 0.0),
                    (x1 - 0.9, y0 + f * (y1 - y0), 1.0, 0.0),
                ]

    for lx, ly, vx, vy in lampes:
        lampadaire(m["lampes"], lx, ly, vx, vy)

    # --- desert tout autour, pour que la ville ne flotte pas dans le vide ---
    marge = 220.0
    dalle(m["desert"], -marge, -marge, etendue + marge, etendue + marge,
          -0.05, TUILE_DESERT)

    decor += cactus_du_desert(etendue, rng)

    faces = sum(maillage.finir() for maillage in m.values())
    # La SORTIE VERS LE DESERT : au bout de la derniere rue nord-sud, hors de
    # la ville. Calculee, jamais recopiee — c'est le lieu qui s'est retrouve au
    # milieu de la chaussee deux fois de suite.
    axe_rue = TROTTOIR + ROUTE / 2.0            # milieu de la premiere chaussee
    lieux.append({
        "nom": "sortie_desert",
        "pos": [round(axe_rue, 3), 0.0, round(-(etendue - 5.0), 3)],
        "cap": math.pi,                          # on regarde vers le desert
        "bord_droit": round(TROTTOIR + ROUTE + TROTTOIR / 2.0, 3),
    })

    # L'ALPINE. Garee devant les maisons, la ou la partie commence.
    #
    # Elle n'est pas dans le tirage des voitures garees : a une chance sur
    # cent, on peut faire trois villes sans en voir une, et une voiture
    # remarquable qu'on ne remarque jamais ne sert a rien. Elle a donc son
    # lieu, comme les maisons.
    reserve = next((l for l in lieux if l["nom"].startswith("reserve_")), None)
    if reserve is not None:
        bx, _, bz = reserve["bord"]
        lieux.append({
            "nom": "alpine",
            # Garee le long du trottoir devant la parcelle, decalee pour ne pas
            # masquer les portes des deux maisons.
            "pos": [round(bx - 14.0, 3), 0.0, bz],
            "cap": round(math.pi / 2, 3),
        })

    return {"etendue": etendue, "lampes": lampes, "decor": decor,
            "pietons": pietons, "lieux": lieux, "graphe": graphe_des_rues(n),
            "faces": faces}


def main() -> None:
    a = arguments()
    rng = random.Random(a.seed)
    racine = Path.cwd()

    textures = Path(a.textures)
    if not textures.is_absolute():
        textures = racine / textures

    bpy.ops.wm.read_factory_settings(use_empty=True)

    noms = ["route", "asphalte", "trottoir", "desert"] + FACADES
    mats = {nom: materiau(nom, textures) for nom in noms}
    mats["lampes"] = mats["trottoir"]

    info = construire(a.blocs, rng, mats)

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.export_scene.gltf(
        filepath=str(sortie),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )

    # Les lampes sortent en donnees, pas en geometrie eclairante : Godot les
    # instancie lui-meme avec l'intensite et la portee de reglages.tres. Ca
    # laisse l'eclairage nocturne reglable au curseur, ce qu'un glTF fige.
    # Blender est en Z-up, Godot en Y-up : (x, y, z) -> (x, z, -y).
    lampes_json = sortie.with_name(sortie.stem + "_lampes.json")
    lampes_json.write_text(json.dumps({
        "etendue": info["etendue"],
        "lampes": [
            {"pos": [round(x, 3), 3.06, round(-y, 3)],
             "vers": [round(vx, 3), 0.0, round(-vy, 3)]}
            for x, y, vx, vy in info["lampes"]
        ],
        # Meme raison pour le mobilier : instancie au lancement plutot que
        # fondu dans le maillage. Une poubelle est alors un fichier partage
        # par ses trois cents exemplaires, pas trois cents fois ses faces.
        "decor": info["decor"],
        "pietons": info["pietons"],
        # LES ANCRES. Le generateur publie enfin ce qu'il SAIT de la ville :
        # ou sont les parcelles reservees, ou est la sortie vers le desert.
        # Tout ce que le jeu doit poser a un endroit precis se lit ici plutot
        # que d'etre recopie dans la scene, ou ca se perime au premier
        # changement de gabarit.
        "lieux": info["lieux"],
        # LE GRAPHE DES RUES : carrefours et troncons. Les voitures et les
        # passants y circulent au lieu de faire des allers-retours sur un
        # segment fixe. Voir graphe_des_rues().
        "graphe": info["graphe"],
    }, indent=1), encoding="utf-8")

    types = {}
    for d in info["decor"]:
        types[d["type"]] = types.get(d["type"], 0) + 1

    print("")
    print(f"ville      {a.blocs} x {a.blocs} ilots, {info['etendue']:.0f} m de cote")
    print(f"graine     {a.seed}")
    print(f"lampes     {len(info['lampes'])}")
    print(f"pietons    {len(info['pietons'])}")
    print(f"decor      {len(info['decor'])} : "
          + ", ".join(f"{n} {t}" for t, n in sorted(types.items())))
    print(f"faces      {info['faces']}")
    print(f"sortie     {sortie}")


if __name__ == "__main__":
    main()
