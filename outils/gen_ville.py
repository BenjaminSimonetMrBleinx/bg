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

sys.path.insert(0, str(Path(__file__).resolve().parent))
from formes import embrasure, mur_perce      # noqa: E402

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

# LES TYPES D'ILOT, ET POURQUOI ILS EXISTENT.
#
# Le generateur ne savait construire qu'une chose : quatre rangees d'immeubles
# autour d'une cour. Soixante-quatre fois. Une grille parfaite se lit comme un
# tableur, et surtout aucune mission ne peut donner rendez-vous « au terrain
# vague » s'il n'y en a pas un seul.
#
# Le tirage est PONDERE et il penche lourdement vers le bati : un parc tous les
# deux ilots ne serait plus un parc, ce serait une banlieue. La rarete est ce
# qui rend un lieu reperable — et se reperer sans carte est tout l'enjeu.
#
# Ce que chacun apporte au JEU, pas au decor :
#   parc            le seul endroit traversable a pied et pas en voiture
#   terrain_vague   pas de fenetres, donc pas de temoins
#   parking         de la place, des vehicules, et une sortie de secours
TYPES_ILOT = [
    ("bati", 66),
    ("terrain_vague", 13),
    ("parc", 11),
    ("parking", 10),
]

# LES QUARTIERS, ET POURQUOI ILS SONT ARRIVES AVEC LES PAVILLONS.
#
# Les trois premiers types — parc, terrain vague, parking — se tirent tres bien
# au hasard : un parc entre deux immeubles est un parc, et un parking aussi. Un
# ilot de pavillons coince entre deux tours, non. Il faut qu'il ait des voisins.
#
# La carte se decoupe donc en trois bandes nord-sud, comme le prevoit
# docs/13-carte.md, et chacune tire dans SA table. C'est ce qui fait qu'on sait
# ou l'on est sans qu'aucun panneau ne le dise — et se reperer sans carte est
# tout l'enjeu.
#
#   HAUTEURS   a l'ouest, la ou commence la partie. Walter y habite : des
#              pavillons, des arbres, des temoins a chaque fenetre
#   CENTRE     le commerce et la densite : des immeubles, des parkings, des
#              centres commerciaux de bord de route
#   RIO SUD    l'industrie et la nuit : des terrains vagues, peu de monde,
#              personne pour regarder
QUARTIERS = {
    "hauteurs": [("pavillonnaire", 44), ("bati", 24), ("parc", 18),
                 ("parking", 8), ("terrain_vague", 6)],
    "centre": [("bati", 56), ("parking", 16), ("strip_mall", 14),
               ("parc", 8), ("terrain_vague", 6)],
    "rio_sud": [("bati", 38), ("terrain_vague", 30), ("parking", 16),
                ("strip_mall", 10), ("parc", 6)],
}

# LA FRANGE : la derniere rangee d'ilots, quel que soit son quartier.
#
# Presque pas de bati. C'est ce qui fait qu'on sent la ville se terminer au
# lieu de tomber d'une falaise d'immeubles dans le sable.
FRANGE = [("terrain_vague", 38), ("pavillonnaire", 24), ("parking", 16),
          ("bati", 12), ("strip_mall", 6), ("parc", 4)]

# Largeur d'une place de stationnement et profondeur d'une rangee, en metres.
# La texture de parking porte UNE place : ces deux nombres sont donc aussi la
# taille de sa tuile, et une ligne mal placee se corrige ici.
PLACE_LARGEUR = 2.75
PLACE_PROFONDEUR = 5.0

# Largeur des allees d'un parc. En dessous de deux metres on ne les lit plus
# comme des chemins mais comme des joints entre deux pelouses.
ALLEE = 2.4

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
    ("poubelle", 20), ("poubelle_bleue", 7), ("poubelle_grise", 6),
    ("borne", 15), ("banc", 9),
    ("benne", 4), ("benne_verte", 3), ("benne_bleue", 3),
    ("cactus", 6), ("buisson", 7),
    ("distributeur_journaux", 6), ("cabine_telephone", 3), ("abri_bus", 2),
]

# Ecart moyen entre deux elements le long d'un trottoir, en metres.
ESPACEMENT_DECOR = 9.0

# Un climatiseur sur ce toit-ci ? Sans eux, chaque immeuble est une boite
# parfaite, et ca se voit tout de suite d'en haut comme depuis la rue.
PROBA_CLIM = 0.4

# Voitures a l'arret le long des trottoirs. Purement decoratives — une rue
# vide de vehicules ne se lit pas comme une ville, quelle que soit la
# densite du mobilier.
ESPACEMENT_VOITURES = 15.0

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
# Une place sur trois occupee, pas une sur deux.
#
# A 0,55 avec un espacement de 13 m, les deux cotes de chaque rue etaient
# presque pleins : on ne voyait plus la bordure, on ne pouvait plus se garer, et
# depuis que les voitures a l'arret ont un corps physique (0.36.0) la rue etait
# devenue un couloir. Retour de Benjamin apres essai : « y a trop de voitures
# garees. »
#
# Une rue a moitie vide se lit mieux qu'une rue pleine : les trous laissent voir
# le trottoir, et une file continue de tole ressemble a un mur peint.
PROBA_PLACE_OCCUPEE = 0.32

# Passants. Chacun arpente un segment de trottoir. Pas de foule : dix
# silhouettes qui bougent en donnent plus qu'une centaine d'immobiles.
PIETONS_PAR_COTE = 1
LONGUEUR_TRAJET = 26.0

# LES MODELES DE PASSANTS.
#
# Ce sont les figurants du pack, pas les boites generees. Les boites ont servi
# tant qu'on n'avait rien : elles marchaient — silhouette.gd les anime segment
# par segment — mais elles se lisaient comme des boites.
#
# Les figurants ont un squelette, donc ils passent par demarche.gd comme
# Walter. Leur pack n'avait AUCUNE marche : celle de Walter leur a ete reportee
# par outils/retarget_figurants.py, en passant par l'espace monde.
#
# Le tirage est pondere : une rue ordinaire est faite de gens ordinaires. Un
# medecin en blouse et une policiere sont rares, et c'est ce qui fait qu'on les
# remarque quand ils passent.
# ETAT AU 31/07/2026 : CE SONT ENCORE LES BOITES.
#
# Les figurants du pack sont importes, propres, et le jeu sait les animer
# depuis que pieton.gd choisit entre un squelette et des segments — mais leur
# pack n'a AUCUNE marche, et le report de celle de Walter ne tient pas encore
# debout. Verifie a l'image : le corps se disloque, membres en etoile. Voir
# outils/retarget_figurants.py et le ticket #16.
#
# On garde donc les boites, qui marchent correctement. Un passant en boite qui
# marche vaut mieux qu'un beau modele disloque, et la bascule ne demandera que
# de rouvrir cette liste.
MODELES_PASSANTS = [
    ("passant_a", 34), ("passant_b", 33), ("passant_c", 33),
]


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


def dalle_uv(m: Maillage, x0, y0, x1, y1, z, tu, tv) -> None:
    """Comme dalle(), mais avec une tuile differente dans chaque sens.

    Le parking en a besoin : sa texture porte une place, large de 2,75 m et
    profonde de 5. Avec une tuile carree, les lignes se repeteraient aussi dans
    l'autre sens et on obtiendrait un damier au lieu de rangees.
    """
    m.face(
        [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)],
        [(x0 / tu, y0 / tv), (x1 / tu, y0 / tv),
         (x1 / tu, y1 / tv), (x0 / tu, y1 / tv)],
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


def parapet(m: Maillage, x0: float, y0: float, x1: float, y1: float,
            h: float, haut: float = 0.42, debord: float = 0.10) -> None:
    """L'acrotere qui couronne un toit plat.

    C'EST LA SIGNATURE D'ALBUQUERQUE, et elle coute cinq faces. Sur les
    cinquante-six photos de reference, aucun toit plat ne s'arrete a ras du
    mur : le mur MONTE de trente a soixante centimetres au-dessus du toit et
    le cache. C'est ce qui fait lire « sud-ouest » plutot qu'« immeuble
    quelconque », et c'est ce qui manquait le plus a notre bati.

    Il DEBORDE legerement du mur, ce qui pose une ligne d'ombre juste sous le
    couronnement. Sans ce decrochement, le parapet se confond avec la facade
    et ne se voit plus.
    """
    d = debord
    boite(m, x0 - d, y0 - d, x1 + d, y1 + d, h, h + haut, 3.0, 0.9)


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
            "modele": tirer(rng, MODELES_PASSANTS),
        })
    return trajets


def plan_des_ilots(n: int, graine: int) -> dict:
    """Le type de chaque ilot, decide AVANT tout le reste.

    CHAQUE ILOT A SON PROPRE TIRAGE, DERIVE DE SA POSITION. C'est ce qui rend
    le plan de la ville stable : avec un generateur aleatoire partage, changer
    le nombre de voitures d'un parking decale toute la suite du flux et
    REDISTRIBUE la carte entiere. Constate le 30/07/2026 — une capture cadree
    sur un terrain vague s'est retrouvee nez a nez avec un immeuble, sans que
    rien de ce qui concerne les terrains vagues ait bouge.

    Consequence pratique : les vues de `scenarios.json` gardent leur sujet, et
    une meme graine donne la meme ville d'une version a l'autre.
    """
    plan = {}
    for bx in range(n):
        for by in range(n):
            quartier = quartier_de(bx, n)
            # L'ilot (0, 0) reste bati quoi qu'il arrive : il porte les maisons
            # de Walter et de Jesse, et la partie commence devant.
            if (bx, by) == (0, 0):
                plan[(bx, by)] = ("bati", quartier)
                continue
            table = FRANGE if est_frange(bx, by, n) else QUARTIERS[quartier]
            total = sum(poids for _, poids in table)
            local = random.Random((graine * 7919) ^ (bx * 131 + by * 17))
            seuil = local.uniform(0.0, total)
            choisi = table[0][0]
            for nom, poids in table:
                seuil -= poids
                if seuil <= 0.0:
                    choisi = nom
                    break
            plan[(bx, by)] = (choisi, quartier)
    return plan


def est_frange(bx: int, by: int, n: int) -> bool:
    """Cet ilot est-il sur le bord de la ville ?

    UNE VILLE NE S'ARRETE PAS A UNE RUE. La grille se terminait net : des
    immeubles de quatre etages, puis du sable jusqu'a l'horizon. Aucune ville
    ne fait ca — elle se dilue en terrains vagues, en maisons isolees et en
    parkings avant de rendre les armes.

    Les quatre ilots du coin de depart sont EXCLUS : la partie commence
    devant chez Walter, et clairsemer son quartier ferait commencer le jeu au
    bout du monde. C'est exactement l'erreur des maisons posees dans le desert,
    payee une fois.
    """
    if n < 4:
        return False
    if bx < 2 and by < 2:
        return False
    return bx == 0 or by == 0 or bx == n - 1 or by == n - 1


def quartier_de(bx: int, n: int) -> str:
    """Le quartier d'une colonne d'ilots.

    Decoupage en bandes NORD-SUD, et pas en damier : une ville se traverse, et
    ce qui doit changer est ce qu'on voit en roulant tout droit. Un damier de
    quartiers donnerait un changement d'ambiance a chaque carrefour, c'est-a-
    dire aucun.

    Les Hauteurs sont a l'OUEST, la ou commence la partie — Walter part de chez
    lui, dans son quartier.
    """
    if n <= 2:
        return "hauteurs"
    if bx < max(1, n // 3):
        return "hauteurs"
    if bx < max(2, (2 * n) // 3):
        return "centre"
    return "rio_sud"


def parcelle_parc(m: dict, ox: float, oy: float,
                  rng: random.Random) -> list[dict]:
    """Un parc : pelouse, deux allees en croix, des arbres, des bancs.

    LES ALLEES SE CROISENT AU MILIEU, ET C'EST LE POINT. Un parc sans chemin
    est une pelouse : on le contourne. Avec une croix, il devient un RACCOURCI
    entre deux rues — le seul endroit de la ville qu'on traverse a pied et pas
    en voiture, ce qui donne une raison de descendre de voiture.
    """
    dalle(m["herbe"], ox, oy, ox + BLOC, oy + BLOC, 0.03, 4.0)

    milieu_x = ox + BLOC / 2.0
    milieu_y = oy + BLOC / 2.0
    # Les allees montent a 0,05 : au meme niveau que la pelouse, le moteur ne
    # sait pas laquelle afficher et l'image papillonne selon l'angle.
    dalle(m["trottoir"], ox, milieu_y - ALLEE / 2.0,
          ox + BLOC, milieu_y + ALLEE / 2.0, 0.05, TUILE_SOL)
    dalle(m["trottoir"], milieu_x - ALLEE / 2.0, oy,
          milieu_x + ALLEE / 2.0, oy + BLOC, 0.05, TUILE_SOL)

    objets: list[dict] = []
    for _ in range(26):
        x = rng.uniform(ox + 2.0, ox + BLOC - 2.0)
        y = rng.uniform(oy + 2.0, oy + BLOC - 2.0)
        # Rien dans une allee : un arbre plante au milieu du chemin annule
        # l'interet du chemin.
        if abs(x - milieu_x) < ALLEE or abs(y - milieu_y) < ALLEE:
            continue
        objets.append({
            "type": "arbre",
            "pos": [round(x, 2), 0.03, round(-y, 2)],
            "angle": round(rng.uniform(0.0, 6.28), 3),
        })

    # Des tables de pique-nique et des buissons. Un parc qui n'a que des arbres
    # et des bancs se lit comme un decor ; ce qui le rend habite, ce sont les
    # choses qui servent a s'y installer.
    for k in range(3):
        objets.append({
            "type": "table_picnic",
            "pos": [round(ox + BLOC * (0.24 + 0.26 * k), 2), 0.03,
                    round(-(oy + BLOC * (0.72 if k % 2 else 0.24)), 2)],
            "angle": round(rng.uniform(0.0, 6.28), 3),
        })
    # LES ARBRES SE GROUPENT. Semes un par un, ils se repartissent trop
    # regulierement et le parc se lit comme un verger. Sur les photos, ils
    # viennent par deux ou trois, serres, avec du vide entre les groupes.
    for _ in range(5):
        cx = rng.uniform(ox + 6.0, ox + BLOC - 6.0)
        cy = rng.uniform(oy + 6.0, oy + BLOC - 6.0)
        if abs(cx - milieu_x) < ALLEE + 2.0 or abs(cy - milieu_y) < ALLEE + 2.0:
            continue
        for _ in range(rng.randint(2, 3)):
            objets.append({
                "type": rng.choice(["arbre", "arbre", "arbre_haut"]),
                "pos": [round(cx + rng.uniform(-3.2, 3.2), 2), 0.03,
                        round(-(cy + rng.uniform(-3.2, 3.2)), 2)],
                "angle": round(rng.uniform(0.0, 6.28), 3),
            })

    for _ in range(14):
        x = rng.uniform(ox + 2.5, ox + BLOC - 2.5)
        y = rng.uniform(oy + 2.5, oy + BLOC - 2.5)
        if abs(x - milieu_x) < ALLEE or abs(y - milieu_y) < ALLEE:
            continue
        objets.append({
            "type": "buisson",
            "pos": [round(x, 2), 0.03, round(-y, 2)],
            "angle": round(rng.uniform(0.0, 6.28), 3),
        })

    # Les bancs regardent l'allee, poses le long de la branche est-ouest.
    for k in range(4):
        x = ox + BLOC * (0.18 + 0.21 * k)
        cote = 1.0 if k % 2 == 0 else -1.0
        objets.append({
            "type": "banc",
            "pos": [round(x, 2), 0.05,
                    round(-(milieu_y + cote * (ALLEE / 2.0 + 0.7)), 2)],
            "angle": round(0.0 if cote > 0 else math.pi, 3),
        })
    return objets


def parcelle_terrain_vague(m: dict, ox: float, oy: float,
                           rng: random.Random) -> list[dict]:
    """Un terrain vague : de la terre, quelques bennes, rien qui regarde.

    C'est le seul endroit de la ville SANS FENETRE. Le jour ou les temoins
    existeront, ce sera la difference entre faire une chose ici et la faire
    dans une rue pavillonnaire — et c'est pour ca qu'il vaut la peine d'etre
    construit maintenant, avant meme qu'ils existent.
    """
    dalle(m["desert"], ox, oy, ox + BLOC, oy + BLOC, 0.03, TUILE_SOL)

    # LA CLOTURE, ET POURQUOI ELLE N'EST PAS DECORATIVE.
    #
    # Sans elle, la capture montre exactement ce qu'on ne veut pas : une
    # parcelle ou le generateur a oublie de poser des immeubles. C'est le
    # grillage qui dit « ce terrain appartient a quelqu'un, et il est vide » —
    # la difference entre un lieu et un trou.
    #
    # Poteaux et lisses, pas de maille. Un grillage se fait normalement avec
    # une texture decoupee, donc de la transparence, donc un tri par
    # profondeur que ce rendu n'a pas. A vingt metres, deux lisses horizontales
    # donnent la meme lecture.
    poteau = 0.055
    for long_axe, fixe in (("x", oy), ("x", oy + BLOC),
                           ("y", ox), ("y", ox + BLOC)):
        debut = ox if long_axe == "x" else oy
        # Une ouverture par cote : un terrain entierement ceint est un decor
        # qu'on longe, alors qu'on doit pouvoir y entrer.
        trou = debut + BLOC * 0.5
        k = 0.0
        while k < BLOC:
            p = debut + k
            k += 5.0
            if abs(p - trou) < 4.0:
                continue
            if long_axe == "x":
                boite(m["trottoir"], p - poteau, fixe - poteau,
                      p + poteau, fixe + poteau, 0.0, 1.9, 1.0, 1.9)
            else:
                boite(m["trottoir"], fixe - poteau, p - poteau,
                      fixe + poteau, p + poteau, 0.0, 1.9, 1.0, 1.9)
        for hauteur in (0.85, 1.78):
            a, b = debut, debut + BLOC
            if long_axe == "x":
                boite(m["trottoir"], a, fixe - 0.03, trou - 4.0, fixe + 0.03,
                      hauteur, hauteur + 0.06, 2.0, 1.0)
                boite(m["trottoir"], trou + 4.0, fixe - 0.03, b, fixe + 0.03,
                      hauteur, hauteur + 0.06, 2.0, 1.0)
            else:
                boite(m["trottoir"], fixe - 0.03, a, fixe + 0.03, trou - 4.0,
                      hauteur, hauteur + 0.06, 2.0, 1.0)
                boite(m["trottoir"], fixe - 0.03, trou + 4.0, fixe + 0.03, b,
                      hauteur, hauteur + 0.06, 2.0, 1.0)

    objets: list[dict] = []
    for _ in range(11):
        x = rng.uniform(ox + 3.0, ox + BLOC - 3.0)
        y = rng.uniform(oy + 3.0, oy + BLOC - 3.0)
        objets.append({
            "type": tirer(rng, [("benne", 20), ("benne_verte", 12),
                                ("benne_bleue", 10), ("poubelle", 18),
                                ("cactus", 20), ("buisson", 12), ("borne", 8)]),
            "pos": [round(x, 2), 0.03, round(-y, 2)],
            "angle": round(rng.uniform(0.0, 6.28), 3),
        })
    return objets


def parcelle_parking(m: dict, ox: float, oy: float,
                     rng: random.Random) -> list[dict]:
    """Un parking : de l'asphalte marque, et des voitures rangees.

    Les places sont dans la TEXTURE, pas en geometrie — une place peinte
    coute alors zero face, et un parking de cent places coute exactement ce que
    coute un parking vide. Voir parking() dans gen_textures.py.
    """
    dalle_uv(m["parking"], ox, oy, ox + BLOC, oy + BLOC, 0.03,
             PLACE_LARGEUR, PLACE_PROFONDEUR)

    objets: list[dict] = []
    rangees = int(BLOC / PLACE_PROFONDEUR)
    places = int(BLOC / PLACE_LARGEUR)
    for r in range(rangees):
        # Les voitures d'une rangee se garent toutes du meme cote de la ligne,
        # et une rangee sur deux regarde l'autre sens : c'est ce qui fait lire
        # des allees de circulation entre elles.
        cap = math.pi / 2.0 if r % 2 == 0 else -math.pi / 2.0
        y = oy + (r + 0.5) * PLACE_PROFONDEUR
        for p in range(places):
            if rng.random() > 0.34:
                continue
            x = ox + (p + 0.5) * PLACE_LARGEUR
            objets.append({
                "type": "garee_" + tirer(rng, MODELES_GAREES),
                "pos": [round(x, 2), 0.03, round(-y, 2)],
                "angle": round(cap + rng.uniform(-0.04, 0.04), 3),
            })
    return objets


# LES VARIANTES DE PAVILLON.
#
# Douze maisons par ilot, toutes identiques, se lisent comme un copier-coller
# — c'est le meme defaut que les trois cents poubelles. Quatre gabarits
# suffisent a le casser : ils different par ce qui se voit de la rue, la
# SILHOUETTE, pas par des details qu'on ne distinguera jamais a vingt metres.
#
#   toit      croupe (Walter) ou plat a parapet (pueblo)
#   garage    a gauche ou a droite de l'entree
#   avancee   de combien l'aile de garage sort du corps
#   fenetres  une ou deux sur la facade rue
GABARITS = [
    {"toit": "croupe", "garage": "droite", "avancee": 0.70, "fenetres": 2},
    {"toit": "plat", "garage": "gauche", "avancee": 0.45, "fenetres": 2},
    {"toit": "croupe", "garage": "gauche", "avancee": 0.90, "fenetres": 1},
    {"toit": "plat", "garage": "droite", "avancee": 0.30, "fenetres": 1},
]


def maisonnette(m: dict, x0: float, y0: float, largeur: float, profondeur: float,
                cote: str, rng: random.Random) -> None:
    """Un pavillon d'Albuquerque, OUVERTURES CREUSEES.

    Les portes et les fenetres etaient peintes sur une face plate : aucune
    ombre, donc un cube colorie. Elles sont maintenant de vrais trous, avec
    leurs quatre retours — voir outils/formes.py, qui porte le raisonnement.

    Le volume est casse en deux profondeurs : le corps, et l'aile de garage en
    avant. C'est le minimum pour qu'une maison cesse d'etre une boite, et ca
    ne coute que quatre faces de plus.
    """
    g = GABARITS[rng.randrange(len(GABARITS))]
    h = rng.uniform(2.55, 2.80)

    # On travaille dans un repere local ou la facade rue est le segment
    # (0,0)-(largeur,0), puis on transporte. C'est ce qui evite d'ecrire les
    # quatre orientations a la main, et donc d'en rater une.
    if cote == "sud":
        base, ux, uy, nx, ny = (x0, y0), 1.0, 0.0, 0.0, -1.0
        pf = profondeur
    elif cote == "nord":
        base, ux, uy, nx, ny = (x0 + largeur, y0 + profondeur), -1.0, 0.0, 0.0, 1.0
        pf = profondeur
    elif cote == "ouest":
        base, ux, uy, nx, ny = (x0, y0 + profondeur), 0.0, -1.0, -1.0, 0.0
        pf = largeur
    else:
        base, ux, uy, nx, ny = (x0 + profondeur, y0), 0.0, 1.0, 1.0, 0.0
        pf = largeur
    lg = largeur if cote in ("sud", "nord") else profondeur

    def P(t: float, prof: float) -> tuple:
        """Un point : t le long de la facade, prof vers l'interieur."""
        return (base[0] + ux * t - nx * prof, base[1] + uy * t - ny * prof)

    corps = m["crepi"]
    vitre = m["fenetre_maison"]
    porte = m["porte"]

    # L'aile de garage occupe 44 % de la facade, en avant du corps.
    gl = lg * 0.44
    av = g["avancee"]
    gt0 = (lg - gl - 0.2) if g["garage"] == "droite" else 0.2
    gt1 = gt0 + gl

    # --- la facade rue, percee -------------------------------------------
    ouvertures = [(gt0 + 0.35, gt1 - 0.35, 0.0, 2.18)]      # porte de garage
    reste0 = 0.3 if g["garage"] == "droite" else gt1 + 0.3
    reste1 = gt0 - 0.3 if g["garage"] == "droite" else lg - 0.3
    place = max(0.0, reste1 - reste0)
    if place > 2.4:
        ouvertures.append((reste0 + 0.15, reste0 + 1.05, 0.0, 2.05))   # entree
        if g["fenetres"] >= 1 and place > 3.4:
            ouvertures.append((reste0 + 1.45, reste0 + 2.55, 1.02, 2.10))
        if g["fenetres"] >= 2 and place > 4.6:
            ouvertures.append((reste0 + 2.85, reste0 + 3.85, 1.02, 2.10))

    mur_perce(corps, P(0.0, 0.0), P(lg, 0.0), 0.0, h, ouvertures)
    for k, (t0, t1, z0, z1) in enumerate(ouvertures):
        fond = porte if z0 < 0.01 else vitre
        embrasure(corps, fond, P(0.0, 0.0), P(lg, 0.0), t0, t1, z0, z1,
                  0.16 if k == 0 else 0.13, (-nx, -ny))

    # --- les trois autres murs, pleins, plus une fenetre a l'arriere ------
    mur_perce(corps, P(lg, 0.0), P(lg, pf), 0.0, h, [])
    mur_perce(corps, P(lg, pf), P(0.0, pf), 0.0, h, [(pf * 0.35, pf * 0.55, 1.10, 2.05)])
    embrasure(corps, vitre, P(lg, pf), P(0.0, pf), pf * 0.35, pf * 0.55,
              1.10, 2.05, 0.13, (nx, ny))
    mur_perce(corps, P(0.0, pf), P(0.0, 0.0), 0.0, h, [])

    # --- l'aile de garage, EN AVANT du corps ------------------------------
    if av > 0.05:
        for a, b in ((P(gt0, -av), P(gt1, -av)),
                     (P(gt1, -av), P(gt1, 0.0)),
                     (P(gt0, 0.0), P(gt0, -av))):
            mur_perce(corps, a, b, 0.0, h, [])

    # --- le toit ----------------------------------------------------------
    d = 0.34
    c = [P(-d, -d - av), P(lg + d, -d - av), P(lg + d, pf + d), P(-d, pf + d)]
    if g["toit"] == "croupe":
        ht = h + 0.85
        mi = [(c[0][0] + c[2][0]) / 2.0, (c[0][1] + c[2][1]) / 2.0]
        a = (mi[0] + (c[1][0] - c[0][0]) * 0.18, mi[1] + (c[1][1] - c[0][1]) * 0.18, ht)
        b = (mi[0] - (c[1][0] - c[0][0]) * 0.18, mi[1] - (c[1][1] - c[0][1]) * 0.18, ht)
        t = m["toit"]
        t.face([(c[0][0], c[0][1], h), (c[1][0], c[1][1], h), a, b],
               [(0, 0), (3, 0), (2.2, 1.4), (0.8, 1.4)])
        t.face([(c[2][0], c[2][1], h), (c[3][0], c[3][1], h), b, a],
               [(0, 0), (3, 0), (2.2, 1.4), (0.8, 1.4)])
        t.face([(c[1][0], c[1][1], h), (c[2][0], c[2][1], h), a],
               [(0, 0), (2, 0), (1, 1.2)])
        t.face([(c[3][0], c[3][1], h), (c[0][0], c[0][1], h), b],
               [(0, 0), (2, 0), (1, 1.2)])
    else:
        # Toit plat A PARAPET : le mur monte au-dessus et cache le toit. Sur
        # les references, c'est la couverture la plus repandue d'Albuquerque.
        t = m["toit"]
        t.face([(c[0][0], c[0][1], h), (c[1][0], c[1][1], h),
                (c[2][0], c[2][1], h), (c[3][0], c[3][1], h)],
               [(0, 0), (3, 0), (3, 3), (0, 3)])
        for i in range(4):
            j = (i + 1) % 4
            m["crepi"].face(
                [(c[i][0], c[i][1], h), (c[j][0], c[j][1], h),
                 (c[j][0], c[j][1], h + 0.40), (c[i][0], c[i][1], h + 0.40)],
                [(0, 0), (2.4, 0), (2.4, 0.4), (0, 0.4)])

    # --- l'habillage : soubassement et appuis -----------------------------
    hab = m["crepi"]
    for a, b in ((P(0.0, -av if av > 0.05 else 0.0), P(lg, -av if av > 0.05 else 0.0)),):
        hab.face([(a[0], a[1], 0.0), (b[0], b[1], 0.0),
                  (b[0], b[1], 0.26), (a[0], a[1], 0.26)],
                 [(0, 0), (3, 0), (3, 0.3), (0, 0.3)])


def parcelle_pavillonnaire(m: dict, ox: float, oy: float,
                           rng: random.Random) -> list[dict]:
    """Un ilot de pavillons : douze maisons, leurs allees, leurs murets.

    C'EST LE QUARTIER DE WALT, ET DONC CELUI DES TEMOINS. Une rue pavillonnaire
    est l'endroit ou l'on ne peut rien faire discretement : des fenetres
    partout, personne dans la rue, et tout le monde connait la voiture du
    voisin. Le jour ou le soupcon existera, c'est ici qu'il montera le plus vite
    — et c'est pour ca que ce type d'ilot vaut plus qu'un decor.

    LE MURET EN PARPAING est l'element le plus caracteristique du Nouveau-
    Mexique et il ne coute rien : sans lui, la rue est une rue de banlieue
    generique ; avec lui, elle est americaine et sud-ouest.
    """
    # Le sol est du GRAVIER, pas de la pelouse. Une pelouse verte devant chaque
    # maison d'Albuquerque sonne faux : la ville est a deux cents millimetres
    # de pluie par an, et les jardins y sont mineraux.
    dalle(m["desert"], ox, oy, ox + BLOC, oy + BLOC, 0.03, TUILE_SOL)

    largeur, profondeur, recul = 9.0, 7.5, 3.4
    objets: list[dict] = []
    # Les percees du muret, un intervalle par allee et par cote. On les
    # collecte en posant les maisons, et on batit le mur APRES : un muret
    # construit d'abord se ferait traverser par chaque allee.
    percees: dict[str, list[tuple[float, float]]] = {
        "sud": [], "nord": [], "ouest": [], "est": []}
    for cote in ("sud", "nord", "ouest", "est"):
        for k in range(3):
            depart = 2.0 + k * 12.3
            if cote == "sud":
                x0, y0 = ox + depart, oy + recul
            elif cote == "nord":
                x0, y0 = ox + depart, oy + BLOC - recul - profondeur
            elif cote == "ouest":
                x0, y0 = ox + recul, oy + depart
            else:
                x0, y0 = ox + BLOC - recul - profondeur, oy + depart
            lg = largeur if cote in ("sud", "nord") else profondeur
            pf = profondeur if cote in ("sud", "nord") else largeur
            maisonnette(m, x0, y0, lg, pf, cote, rng)

            # L'ALLEE. Elle relie la maison au trottoir, et c'est elle qui
            # designe l'entree : sans allee, douze maisons alignees sur du
            # gravier ne montrent pas ou l'on rentre.
            # L'ALLEE EST LARGE ET BETONNEE, et elle mene AU GARAGE.
            #
            # Elle faisait 2,8 m d'asphalte vers la porte d'entree. Sur les
            # photos, l'allee d'une maison d'Albuquerque est en beton clair,
            # large de six metres, et occupe la moitie du terrain : c'est la
            # surface la plus visible d'un jardin de devant.
            if cote == "sud":
                a = x0 + lg * 0.44
                dalle(m["beton"], a, oy, a + 6.0, y0, 0.04, 3.0)
            elif cote == "nord":
                a = x0 + lg * 0.10
                dalle(m["beton"], a, y0 + pf, a + 6.0, oy + BLOC, 0.04, 3.0)
            elif cote == "ouest":
                a = y0 + pf * 0.44
                dalle(m["beton"], ox, a, x0, a + 6.0, 0.04, 3.0)
            else:
                a = y0 + pf * 0.10
                dalle(m["beton"], x0 + lg, a, ox + BLOC, a + 6.0, 0.04, 3.0)
            percees[cote].append((a - 0.5, a + 6.5))

            # LE XERISCAPE : une rangee d'arbustes plaquee contre la facade,
            # et un arbre pose de biais. Sur les references d'Albuquerque,
            # c'est TOUTE la verdure d'un jardin de devant — le reste est du
            # gravier. Sans eux la maison a l'air inhabitee ; avec eux, elle a
            # l'air entretenue.
            for k in range(3):
                q = 0.18 + k * 0.28
                if cote == "sud":
                    ax, ay = x0 + lg * q, y0 - 0.75
                elif cote == "nord":
                    ax, ay = x0 + lg * q, y0 + pf + 0.75
                elif cote == "ouest":
                    ax, ay = x0 - 0.75, y0 + pf * q
                else:
                    ax, ay = x0 + lg + 0.75, y0 + pf * q
                objets.append({
                    "type": "arbuste",
                    "pos": [round(ax, 2), 0.03, round(-ay, 2)],
                    "angle": round(rng.uniform(0.0, 6.28), 3),
                })
            if rng.random() < 0.55:
                objets.append({
                    "type": rng.choice(["arbre", "arbre_haut"]),
                    "pos": [round(x0 + lg * rng.uniform(0.75, 0.95), 2), 0.03,
                            round(-(y0 - 2.2 if cote == "sud" else y0 + pf + 2.2
                                    if cote == "nord" else y0 + pf * 0.5), 2)],
                    "angle": round(rng.uniform(0.0, 6.28), 3),
                })

            objets.append({
                "type": "boite_lettres",
                "pos": [round(x0 + lg * 0.5, 2), 0.03,
                        round(-(y0 + pf * 0.5), 2)],
                "angle": round(CAPS[cote], 3),
            })

    # LE MURET EN PARPAING, bati en dernier, entre les allees.
    #
    # C'est l'element le plus caracteristique du Nouveau-Mexique et il ne coute
    # presque rien : sans lui, la rue est une banlieue generique ; avec lui,
    # elle est americaine et sud-ouest. Un metre trente, jamais plus : au-dela
    # on ne voit plus les maisons depuis la voiture, et c'est tout ce qu'on
    # vient chercher ici.
    ep, haut = 0.16, 1.32
    for cote, (fixe, sens) in (("sud", (oy, "x")), ("nord", (oy + BLOC, "x")),
                               ("ouest", (ox, "y")), ("est", (ox + BLOC, "y"))):
        debut = ox if sens == "x" else oy
        bornes = sorted(percees[cote])
        curseur = debut
        for a, b in bornes + [(debut + BLOC, debut + BLOC)]:
            if a - curseur > 0.6:
                if sens == "x":
                    boite(m["crepi"], curseur, fixe - ep / 2.0, a,
                          fixe + ep / 2.0, 0.0, haut, 2.4, 1.4)
                else:
                    boite(m["crepi"], fixe - ep / 2.0, curseur,
                          fixe + ep / 2.0, a, 0.0, haut, 2.4, 1.4)
            curseur = max(curseur, b)
    return objets


def parcelle_strip_mall(m: dict, ox: float, oy: float,
                        rng: random.Random) -> list[dict]:
    """Un centre commercial de bord de route : un batiment bas en L, un auvent,
    et un grand parking devant.

    C'EST LE MOTIF D'ALBUQUERQUE. Los Pollos Hermanos en est un, le lavage de
    voitures en est un, et la moitie des commerces de la serie aussi. Un
    batiment bas pose au FOND de la parcelle avec son parking sur la rue :
    l'inverse exact d'un centre-ville, et ce qui fait qu'on lit une ville
    americaine de l'ouest plutot qu'une ville generique.
    """
    profond = 11.0
    dalle_uv(m["parking"], ox, oy, ox + BLOC, oy + BLOC - profond, 0.03,
             PLACE_LARGEUR, PLACE_PROFONDEUR)

    y0 = oy + BLOC - profond
    boite(m["bardage"], ox + 1.0, y0, ox + BLOC - 1.0, oy + BLOC, 0.0, 4.6,
          4.0, 4.6)
    # L'AUVENT. Une bande qui court sur toute la facade, a hauteur d'homme et
    # demi. C'est ce qui distingue un commerce d'un hangar, et c'est aussi ce
    # qui porte l'ombre sur la devanture.
    boite(m["toit"], ox + 0.4, y0 - 2.6, ox + BLOC - 0.4, y0 + 0.2, 3.15, 3.45,
          4.0, 1.0)
    for k in range(5):
        px = ox + 3.0 + k * (BLOC - 6.0) / 4.0
        boite(m["trottoir"], px - 0.09, y0 - 2.5, px + 0.09, y0 - 2.32, 0.0,
              3.15, 1.0, 3.0)
    # Les vitrines : des faces posees devant le bardage, sous l'auvent.
    for k in range(4):
        vx = ox + 3.0 + k * (BLOC - 6.0) / 4.0
        m["fenetre_maison"].face(
            [(vx + 0.6, y0 - 0.01, 0.6), (vx + 7.0, y0 - 0.01, 0.6),
             (vx + 7.0, y0 - 0.01, 2.9), (vx + 0.6, y0 - 0.01, 2.9)][::-1],
            [(0, 0), (2.4, 0), (2.4, 1), (0, 1)])

    # L'ENSEIGNE DE TOIT, plus haute que le batiment lui-meme. C'est elle
    # qu'on lit de loin, pas la boite en brique — Dog House, Octopus Car
    # Wash, Crossroads Motel : sur les trois references, l'enseigne fait la
    # moitie de la hauteur visible.
    ens = "enseigne_%d" % rng.randrange(3)
    ex = ox + BLOC * 0.30
    m[ens].face([(ex, y0 - 0.30, 5.0), (ex + 11.0, y0 - 0.30, 5.0),
                 (ex + 11.0, y0 - 0.30, 8.2), (ex, y0 - 0.30, 8.2)][::-1],
                [(0, 0), (1, 0), (1, 1), (0, 1)])
    m[ens].face([(ex + 11.0, y0 - 0.16, 5.0), (ex, y0 - 0.16, 5.0),
                 (ex, y0 - 0.16, 8.2), (ex + 11.0, y0 - 0.16, 8.2)],
                [(0, 0), (1, 0), (1, 1), (0, 1)])
    for px in (ex + 1.2, ex + 9.0):
        boite(m["trottoir"], px, y0 - 0.30, px + 0.22, y0 + 0.10, 4.4, 5.2,
              1.0, 1.0)

    objets: list[dict] = []
    rangees = int((BLOC - profond) / PLACE_PROFONDEUR)
    places = int(BLOC / PLACE_LARGEUR)
    for r in range(rangees):
        cap = math.pi / 2.0 if r % 2 == 0 else -math.pi / 2.0
        y = oy + (r + 0.5) * PLACE_PROFONDEUR
        for p in range(places):
            if rng.random() > 0.3:
                continue
            objets.append({
                "type": "garee_" + tirer(rng, MODELES_GAREES),
                "pos": [round(ox + (p + 0.5) * PLACE_LARGEUR, 2), 0.03,
                        round(-y, 2)],
                "angle": round(cap + rng.uniform(-0.04, 0.04), 3),
            })
    # L'enseigne, plantee au bord de la rue : c'est ce qu'on voit avant le
    # batiment, et de bien plus loin.
    objets.append({
        "type": "panneau",
        "pos": [round(ox + 4.0, 2), 0.03, round(-(oy + 1.5), 2)],
        "angle": 0.0,
    })
    return objets


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
        # DE COMBIEN ON S'ECARTE DU CARREFOUR AVANT QUE LE TROTTOIR EXISTE.
        #
        # Un carrefour est un carre d'asphalte de ROUTE de cote : le trottoir
        # s'y interrompt, c'est le passage clouté. Un pieton pose a l'ecart
        # perpendiculaire du CENTRE d'un carrefour se retrouve donc sur la
        # chaussee, pas sur un trottoir — mesure du 30/07/2026 : quatorze
        # passants sur seize se tenaient a 0,01 m, la hauteur de la chaussee.
        #
        # Le trottoir commence a la demi-largeur du couloir. C'est aussi ou
        # s'arrete le carre d'asphalte, donc la valeur n'est pas approchee.
        "retrait_carrefour": round(COULOIR / 2.0, 3),
    }


def montagnes(m: Maillage, etendue: float, rng: random.Random) -> None:
    """Les cretes autour de la ville.

    POURQUOI ELLES SONT A TROIS CENTS METRES, ET PAS A DEUX KILOMETRES.
    On voit a 340 m de jour — c'est le reglage de brume, et il fait le look.
    Une montagne posee a sa vraie distance serait donc integralement mangee par
    la brume, c'est-a-dire invisible. Posee au BORD de la brume, elle apparait
    delavee, sans contour net, exactement comme une montagne lointaine. C'est
    une triche, c'est celle des jeux de l'epoque, et elle est indetectable.

    UN RIDEAU, PAS UN VOLUME. Chaque crete est une bande verticale tournee vers
    la ville. Un relief modelise couterait cent fois plus pour une silhouette
    identique a cette distance et dans cette brume. Deux rangs decales donnent
    la seule chose qui manque a un rideau : de la profondeur quand on longe.

    Le cote du desert reste OUVERT. C'est par la qu'on part chez Tuco, et une
    route qui file vers l'horizon vaut mieux que n'importe quel decor.
    """
    # DEUX COTES SEULEMENT, ET C'EST UNE CONTRAINTE, PAS UN GOUT.
    #
    # La zone du desert — le camping-car, le QG de Tuco — est posee dans LE
    # MEME REPERE, a (900, -900), et elle occupe un carre de 460 m. Une crete
    # a l'est tombait donc en plein dedans : deux murs de roche au milieu de la
    # carte du desert, invisibles depuis la ville et infranchissables une fois
    # la-bas.
    #
    # C'est aussi le bon choix de fond : le sud-est est le cote par lequel on
    # QUITTE la ville. Une route qui file vers l'horizon degage vaut mieux que
    # n'importe quel relief, et Albuquerque a ses montagnes d'un seul cote.
    # PLUS PRES ET PLUS HAUTES. Elles etaient a 300 et 420 m, hautes de 26 a
    # 110 m : depuis la ville elles faisaient un lisere. Sur les photos, les
    # Sandia occupent un tiers du ciel et se voient de n'importe quelle rue.
    recul = 230.0
    for rang, (ecart, bas, amplitude) in enumerate(
            ((recul, 52.0, 60.0), (recul + 130.0, 96.0, 110.0))):
        for cote in ("nord", "ouest"):
            segments = 26
            longueur = etendue + 2.0 * ecart
            hauteurs = [bas + rng.uniform(0.0, amplitude)
                        for _ in range(segments + 1)]
            # Les extremites redescendent : une crete qui se termine a pic sur
            # le vide se lit comme un mur, pas comme une montagne.
            hauteurs[0] = bas * 0.35
            hauteurs[-1] = bas * 0.35
            for k in range(segments):
                p0 = -ecart + longueur * k / segments
                p1 = -ecart + longueur * (k + 1) / segments
                h0, h1 = hauteurs[k], hauteurs[k + 1]
                if cote == "nord":
                    # y NEGATIF : la ville occupe y de 0 a etendue, donc le
                    # dehors de ce cote-la est en dessous de zero. Pose a
                    # +ecart, la crete tombait en plein centre-ville — un mur
                    # de roche de soixante metres au milieu des immeubles.
                    a = (p0, -ecart, 0.0)
                    b = (p1, -ecart, 0.0)
                    c = (p1, -ecart, h1)
                    d = (p0, -ecart, h0)
                elif cote == "est":
                    a = (etendue + ecart, p0, 0.0)
                    b = (etendue + ecart, p1, 0.0)
                    c = (etendue + ecart, p1, h1)
                    d = (etendue + ecart, p0, h0)
                else:
                    a = (-ecart, p1, 0.0)
                    b = (-ecart, p0, 0.0)
                    c = (-ecart, p0, h1)
                    d = (-ecart, p1, h0)
                lu = abs(p1 - p0) / 60.0
                m.face([a, b, c, d],
                       [(0, 0), (lu, 0), (lu, h1 / 90.0), (0, h0 / 90.0)])


def poteaux_et_cables(m: dict, n: int) -> list:
    """Les poteaux electriques des rues, et les cables entre eux.

    ILS CADRENT TOUTES LES PHOTOS. Sur les references d'Albuquerque, pas une
    vue de rue sans deux ou trois cables qui traversent le ciel en biais. Ce
    sont les seules lignes OBLIQUES d'un decor fait de verticales et
    d'horizontales, et c'est exactement pour ca qu'on les remarque.

    Les POTEAUX sont instancies — ce sont des objets, comme les poubelles. Les
    CABLES sont cuits dans le maillage de la ville : ils relient deux points
    precis, donc ils ne peuvent pas etre un modele repete.
    """
    objets: list = []
    axe = TROTTOIR + ROUTE / 2.0
    ecart = PAS / 2.0                       # un poteau tous les 28,5 m
    haut = 7.6
    fleche = 0.9

    for i in range(n + 1):
        x = i * PAS + axe + ROUTE / 2.0 + 1.7
        precedent = None
        y = 6.0
        while y < n * PAS + COULOIR:
            objets.append({
                "type": "poteau",
                "pos": [round(x, 2), 0.0, round(-y, 2)],
                "angle": round(math.pi / 2.0, 3),
            })
            if precedent is not None:
                for c in (-0.86, 0.86):     # deux cables, sur la traverse
                    _cable(m["lampes"], x + c, precedent, y, haut, fleche)
            precedent = y
            y += ecart
    return objets


def _cable(m: Maillage, x: float, y0: float, y1: float,
           haut: float, fleche: float) -> None:
    """Un cable qui PEND entre deux poteaux, en trois segments.

    Une droite tendue se lit comme un fil de fer. Une fleche d'un metre
    suffit a en faire un cable — et trois segments suffisent a la fleche, a
    cette distance.
    """
    pas_ = 3
    e = 0.04
    points = []
    for k in range(pas_ + 1):
        t = k / pas_
        # Une parabole vaut la chainette a cette echelle, et coute une ligne.
        z = haut - fleche * 4.0 * t * (1.0 - t)
        points.append((y0 + (y1 - y0) * t, z))
    for (ya, za), (yb, zb) in zip(points, points[1:]):
        m.face([(x - e, ya, za), (x - e, yb, zb), (x + e, yb, zb), (x + e, ya, za)],
               [(0, 0), (1, 0), (1, 0.08), (0, 0.08)])
        m.face([(x, ya, za - e), (x, yb, zb - e), (x, yb, zb + e), (x, ya, za + e)],
               [(0, 0), (1, 0), (1, 0.08), (0, 0.08)])


def routes_sortantes(m: dict, n: int, etendue: float) -> list[dict]:
    """Deux chaussees qui quittent la grille et se perdent dans la brume.

    La ville s'arretait NET : la derniere rue, puis du sable jusqu'a l'horizon.
    Une route qui continue coute trois quadrilateres et dit la seule chose
    qu'on veut dire — qu'il y a un ailleurs. Personne n'ira jamais au bout ;
    elle disparait dans la brume bien avant.
    """
    longueur = 260.0
    axe = TROTTOIR + ROUTE / 2.0
    milieu = (n // 2) * PAS + axe
    objets: list[dict] = []

    # Vers le nord, depuis la rue du milieu.
    chaussee(m["route"], milieu - ROUTE / 2.0, -longueur,
             milieu + ROUTE / 2.0, 0.0, "y")
    # Vers l'est, depuis l'autre rue du milieu.
    chaussee(m["route"], etendue, milieu - ROUTE / 2.0,
             etendue + longueur, milieu + ROUTE / 2.0, "x")

    # Les poteaux electriques le long de la route sortante. C'est la ligne
    # d'horizon la plus caracteristique de l'ouest americain, et c'est aussi ce
    # qui donne l'echelle : sans rien de vertical, une plaine n'a pas de taille.
    # Deux panneaux publicitaires en sortie de ville. C'est ce qu'on voit en
    # dernier en partant et en premier en revenant, et ca porte tres loin :
    # six metres de haut se lisent bien au-dela du mobilier de trottoir.
    for k, (px, pz, angle) in enumerate((
            (milieu - ROUTE / 2.0 - 9.0, 62.0, 0.0),
            (milieu + ROUTE / 2.0 + 9.5, 148.0, math.pi))):
        objets.append({
            "type": "panneau_pub_%d" % (k % 3),
            "pos": [round(px, 2), 0.0, round(pz, 2)],
            "angle": round(angle, 3),
        })
    objets.append({
        "type": "panneau_pub_2",
        "pos": [round(etendue + 96.0, 2), 0.0,
                round(-(milieu - ROUTE / 2.0 - 9.0), 2)],
        "angle": round(-math.pi / 2.0, 3),
    })

    for k in range(8):
        avance = 16.0 + k * 32.0
        objets.append({
            "type": "poteau",
            "pos": [round(milieu + ROUTE / 2.0 + 3.6, 2), 0.0,
                    round(avance, 2)],
            "angle": 0.0,
        })
        objets.append({
            "type": "poteau",
            "pos": [round(etendue + avance, 2), 0.0,
                    round(-(milieu + ROUTE / 2.0 + 3.6), 2)],
            "angle": round(math.pi / 2.0, 3),
        })
    return objets


def cactus_du_desert(etendue: float, rng: random.Random,
                     combien: int = 70) -> list[dict]:
    """Seme des cactus autour de la ville.

    Le desert est un aplat parfaitement plat et parfaitement vide : de nuit
    il ne se distingue pas du neant. Quelques silhouettes suffisent a lui
    rendre une echelle et une profondeur.
    """
    objets: list[dict] = []
    bande = 165.0
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


def construire(n: int, rng: random.Random, mats: dict, graine: int) -> dict:
    noms = ["route", "asphalte", "trottoir", "desert", "lampes",
            "herbe", "parking", "crepi", "toit", "porte", "fenetre_maison",
            "bardage", "montagne", "beton",
            "enseigne_0", "enseigne_1", "enseigne_2"] + FACADES
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
    types: dict[str, int] = {}
    plan = plan_des_ilots(n, graine)

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

            # LE TYPE DE L'ILOT. L'ilot (0, 0) reste bati quoi qu'il arrive :
            # c'est celui qui porte les maisons de Walter et de Jesse, et le
            # point de depart de la partie donne dessus.
            type_ilot, quartier = plan[(bx, by)]
            types[type_ilot] = types.get(type_ilot, 0) + 1

            if type_ilot != "bati":
                # Les rues autour existent toujours : trottoirs, lampadaires,
                # stationnement et passants ne dependent pas de ce qu'il y a
                # derriere. Seul le CONTENU de la parcelle change.
                for cote in ("sud", "nord", "ouest", "est"):
                    decor += voitures_de_cote(ox, oy, cote, rng)
                    pietons += pietons_de_cote(ox, oy, cote, rng)
                    if type_ilot == "terrain_vague":
                        decor += mobilier_de_cote(ox, oy, cote, rng)
                if type_ilot == "parc":
                    decor += parcelle_parc(m, ox, oy, rng)
                elif type_ilot == "terrain_vague":
                    decor += parcelle_terrain_vague(m, ox, oy, rng)
                elif type_ilot == "pavillonnaire":
                    decor += parcelle_pavillonnaire(m, ox, oy, rng)
                elif type_ilot == "strip_mall":
                    decor += parcelle_strip_mall(m, ox, oy, rng)
                else:
                    decor += parcelle_parking(m, ox, oy, rng)
                # Un lieu NOMME par parcelle : c'est ce qui permettra a une
                # mission de dire « rendez-vous au terrain vague » sans que
                # personne recopie des coordonnees.
                lieux.append({
                    "nom": "%s_%d_%d" % (type_ilot, bx, by),
                    "pos": [round(ox + BLOC / 2.0, 3), 0.0,
                            round(-(oy + BLOC / 2.0), 3)],
                    "cap": 0.0,
                    "quartier": quartier,
                })
                nb = max(2, int(BLOC / ESPACEMENT_LAMPES))
                for k in range(nb):
                    f = (k + 0.5) / nb
                    lampes += [
                        (x0 + f * (x1 - x0), y0 + 0.9, 0.0, -1.0),
                        (x0 + f * (x1 - x0), y1 - 0.9, 0.0, 1.0),
                        (x0 + 0.9, y0 + f * (y1 - y0), -1.0, 0.0),
                        (x1 - 0.9, y0 + f * (y1 - y0), 1.0, 0.0),
                    ]
                continue

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
                        parapet(m["beton"], cx0 + pos, cy0,
                                cx0 + pos + large, cy1, h)
                        centre = (cx0 + pos + large / 2, (cy0 + cy1) / 2)
                    else:
                        boite(m[mat], cx0, cy0 + pos, cx1, cy0 + pos + large, 0.0, h)
                        parapet(m["beton"], cx0, cy0 + pos, cx1,
                                cy0 + pos + large, h)
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
    # LE SOL EST ASYMETRIQUE, et pour la meme raison que les cretes.
    #
    # Il doit porter les montagnes — 300 m, second rang a 420 — sinon elles
    # flottent au-dessus du vide. Mais du cote du desert il ne doit PAS
    # atteindre la zone de Tuco, posee a (900, -900) sur 460 m de cote : deux
    # sols superposes a cinq centimetres l'un de l'autre papillonnent des qu'on
    # les regarde de biais.
    #
    # 180 m de ce cote-la laissent 17 m de marge avant le bord de la zone. Ce
    # n'est pas beaucoup, et c'est volontairement calcule plutot que choisi :
    # si la zone du desert bouge, ce nombre est celui qu'il faut revoir.
    # Les deux cretes sont du cote NEGATIF des deux axes (nord = y negatif,
    # ouest = x negatif) : c'est la que le sol doit s'etendre. Du cote positif,
    # ou se trouve la zone du desert, il s'arrete court sur les deux axes.
    large, court = 520.0, 180.0
    dalle(m["desert"], -large, -large, etendue + court, etendue + court,
          -0.05, TUILE_DESERT)
    montagnes(m["montagne"], etendue, rng)
    decor += routes_sortantes(m, n, etendue)

    decor += poteaux_et_cables(m, n)
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
            "faces": faces, "types": types,
            "quartiers": {quartier_de(bx, n): [
                round(COULOIR + bx * PAS - COULOIR / 2.0, 1),
                round(COULOIR + bx * PAS + BLOC + COULOIR / 2.0, 1)]
                for bx in range(n)}}


def main() -> None:
    a = arguments()
    rng = random.Random(a.seed)
    racine = Path.cwd()

    textures = Path(a.textures)
    if not textures.is_absolute():
        textures = racine / textures

    bpy.ops.wm.read_factory_settings(use_empty=True)

    noms = ["route", "asphalte", "trottoir", "desert",
            "herbe", "parking", "crepi", "toit", "porte", "fenetre_maison",
            "bardage", "montagne", "beton",
            "enseigne_0", "enseigne_1", "enseigne_2"] + FACADES
    mats = {nom: materiau(nom, textures) for nom in noms}
    mats["lampes"] = mats["trottoir"]

    info = construire(a.blocs, rng, mats, a.seed)

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
    print(f"ilots      " + ", ".join(f"{n} {t}"
                                     for t, n in sorted(info["types"].items())))
    print(f"graine     {a.seed}")
    print(f"lampes     {len(info['lampes'])}")
    print(f"pietons    {len(info['pietons'])}")
    print(f"decor      {len(info['decor'])} : "
          + ", ".join(f"{n} {t}" for t, n in sorted(types.items())))
    print(f"faces      {info['faces']}")
    print(f"sortie     {sortie}")


if __name__ == "__main__":
    main()
