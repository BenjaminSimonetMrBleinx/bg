#!/usr/bin/env python3
"""Genere la zone du desert : le sol, la piste, et le camping-car.

    blender -b -P outils/gen_desert.py

Produit game/assets/desert/desert.glb (le terrain) et camping_car.glb.

Pourquoi une zone et pas une SCENE.

Le desert aurait pu etre une seconde scene Godot, avec tout ce que ca implique
— decharger le monde, recharger l'autre, et surtout reconstruire l'etat :
quelle voiture, quel equipement, quel moment de la journee. C'est le premier
bout d'infrastructure que ce projet n'a pas.

Or le projet a deja resolu ce probleme, autrement : les interieurs de maison
sont poses A SIX CENTS METRES du centre-ville, dans la meme scene. On y va par
un fondu au noir, on en revient pareil, et rien n'a besoin d'etre sauvegarde
puisque rien n'est decharge. Le desert reprend exactement ce dispositif. Il
coute un dixieme, et il economise un mecanisme entier.

La limite est connue et acceptee : tout tient en memoire en meme temps. A deux
zones et deux interieurs c'est gratuit. Le jour ou il y en aura vingt, il
faudra faire le vrai travail — et ce jour-la on saura ce qu'on y met.

Convention : comme partout ailleurs, construit pose au sol, avant vers -Y.
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

# Le desert vit loin de la ville, sur le meme plan. Les interieurs sont deja
# vers (-570, 580) et (-560, 880) ; on prend une autre direction pour qu'aucun
# brouillard ni aucune lumiere ne se melangent.
CENTRE = (900.0, -900.0)

# Le terrain deborde volontiers la portee du brouillard de jour (340 m). Un
# terrain plus petit laissait voir son bord franc a l'horizon, comme une table
# posee dans le vide — et on ne peut pas le masquer par du brouillard puisque
# c'est justement au-dela que commence le rien.
COTE = 460.0             # cote du terrain, en metres

# Ou le jeu pose le camping-car et ou s'ouvre la mission 1 — en ORDONNEE
# seulement. L'abscisse se calcule a partir de la piste, qui serpente : les
# deux etaient ecrits en dur du temps ou elle etait droite, et la premiere
# courbe les a repris tous les deux dessous. Un camping-car gare au milieu de
# la route, et un fosse comble par le nivellement de la piste.
CAMPING_CAR_Y = -96.0
CAMPING_CAR_ECART = 26.0     # a l'ecart de la piste, cote est
FOSSE_Y = -132.0
FOSSE_ECART = 21.0

# Ou l'on arrive en venant de la ville. Sur la piste, forcement : c'est par
# elle qu'on entre. Duplique cote jeu par desert.gd, qui prefere ce fichier.
ARRIVEE_Y = -150.0
TUILE_SABLE = 12.0       # la texture de sable se repete tous les 12 m
PISTE = 6.0              # DEMI-largeur de la piste : elle fait donc 12 m
Z_PISTE = 0.012


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur du desert")
    ap.add_argument("--seed", type=int, default=505)
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default="game/assets/desert")
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    arbre = mat.node_tree
    principal = arbre.nodes["Principled BSDF"]
    principal.inputs["Roughness"].default_value = 0.92
    principal.inputs["Metallic"].default_value = 0.0

    png = dossier / f"{nom}.png"
    if not png.exists():
        raise SystemExit(
            f"texture absente : {png}\n"
            f"La palette se refabrique : .\\bg.ps1 generer"
        )
    img = bpy.data.images.load(str(png), check_existing=True)
    img.alpha_mode = "NONE"
    img.pack()
    tex = arbre.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    arbre.links.new(tex.outputs["Color"], principal.inputs["Base Color"])
    return mat


class Maillage:
    def __init__(self, nom: str, mat):
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

    def boite(self, x0, y0, z0, x1, y1, z1, tuile=1.0) -> None:
        lx, ly, lz = (x1 - x0) / tuile, (y1 - y0) / tuile, (z1 - z0) / tuile
        c = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        for indices, (u, v) in [
            ((0, 3, 2, 1), (lx, ly)), ((4, 5, 6, 7), (lx, ly)),
            ((0, 1, 5, 4), (lx, lz)), ((1, 2, 6, 5), (ly, lz)),
            ((2, 3, 7, 6), (lx, lz)), ((3, 0, 4, 7), (ly, lz)),
        ]:
            self.face([c[i] for i in indices],
                      [(0, 0), (u, 0), (u, v), (0, v)])

    def prisme(self, cx, cy, z0, z1, rb, rh, cotes=8, tuile=1.0) -> None:
        bas, haut = [], []
        for i in range(cotes):
            a = math.tau * i / cotes
            bas.append((cx + math.cos(a) * rb, cy + math.sin(a) * rb, z0))
            haut.append((cx + math.cos(a) * rh, cy + math.sin(a) * rh, z1))
        for i in range(cotes):
            j = (i + 1) % cotes
            self.face([bas[i], bas[j], haut[j], haut[i]],
                      [(0, 0), (tuile, 0), (tuile, tuile), (0, tuile)])
        self.face(haut[::-1], [(0, 0)] * cotes)
        self.face(bas, [(0, 0)] * cotes)

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


# ------------------------------------------------------------------- le terrain


# LE RELIEF DU DESERT, ET POURQUOI IL A CHANGE.
#
# Le terrain etait une grille de vingt par vingt avec des bosses d'un metre.
# C'etait ce qu'il fallait quand le desert n'etait qu'un decor a traverser : on
# arrivait, on regardait le camping-car, on repartait.
#
# Le palier 1 en fait un LIEU. La mission 1 s'ouvre sur le camping-car dans un
# fosse, il faut trois objets a ramasser autour, une piste par laquelle sortir,
# et le joueur doit pouvoir se reperer dans la panique. Un plateau parfaitement
# plat ne permet aucune des quatre : on n'y cache rien, et surtout on n'y sait
# jamais ou l'on est.
#
# D'ou trois formes, et pas une de plus :
#
#   LES MESAS      des plateaux a flancs raides. Ce sont les seuls reperes du
#                  desert : on se dirige par eux, comme on se dirige en ville
#                  par les enseignes
#   L'ARROYO       le lit d'un torrent a sec, qui traverse d'est en ouest. La
#                  piste y plonge, et c'est le seul endroit ou l'on ne voit pas
#                  arriver ce qui vient
#   LE FOSSE       une cuvette contre la piste. C'est la que le camping-car
#                  s'encastre a la mission 1
#
# Les mesas sont a flanc RAIDE et non en pente douce, et c'est une decision de
# jeu : une colline se monte en voiture, un plateau non. Ce qui est derriere
# reste derriere tant qu'on ne l'a pas contourne.

MESAS = [
    # (x, y, rayon, hauteur)
    (-152.0, 118.0, 44.0, 13.5),
    (138.0, -34.0, 33.0, 9.0),
    (-88.0, -178.0, 26.0, 6.5),
]

# L'arroyo : sa position en y, sa demi-largeur, sa profondeur.
ARROYO_Y = 46.0
ARROYO_LARGE = 15.0
ARROYO_FOND = 2.8

# Le fosse de la mission 1 : contre la piste, cote est.
FOSSE_RAYON = 15.0
FOSSE_FOND = 2.3


def piste_x(y: float) -> float:
    """De combien la piste s'ecarte de l'axe, a cette hauteur.

    ELLE SERPENTE, et ce n'est pas cosmetique. Une ligne droite dans une plaine
    donne un couloir : on voit sa fin des le depart, on ne tourne jamais le
    volant, et le desert entier se resume au ruban. Deux courbes tres douces
    suffisent a ce qu'on decouvre la suite en avancant.
    """
    return 26.0 * math.sin(y / 95.0)


def piste_z(y: float) -> float:
    """Le profil vertical de la piste : plate, sauf quand elle passe l'arroyo."""
    return -ARROYO_FOND * 0.82 * math.exp(-((y - ARROYO_Y) / 26.0) ** 2)


def _mesa(x: float, y: float) -> float:
    h = 0.0
    for cx, cy, rayon, haut in MESAS:
        d = math.hypot(x - cx, y - cy)
        if d <= rayon:
            h = max(h, haut)
        elif d < rayon * 1.22:
            # Le talus. Court : c'est ce qui fait la falaise plutot que la
            # colline.
            t = 1.0 - (d - rayon) / (rayon * 0.22)
            h = max(h, haut * t * t)
    return h


def _arroyo(x: float, y: float) -> float:
    # Le lit MEANDRE. Un fosse rectiligne se lit comme une tranchee creusee a
    # la pelleteuse ; l'eau, elle, ne va jamais droit.
    centre = ARROYO_Y + 22.0 * math.sin(x / 78.0)
    d = abs(y - centre)
    if d >= ARROYO_LARGE:
        return 0.0
    return -ARROYO_FOND * math.cos(d / ARROYO_LARGE * math.pi / 2.0) ** 2


def fosse_xy() -> tuple[float, float]:
    """Le fosse, JUSTE A COTE de la piste et jamais dessous.

    C'est la que le camping-car sort de la route a la mission 1 : assez pres
    pour qu'on comprenne d'un regard ce qui s'est passe, assez loin pour que le
    nivellement de la piste ne comble pas la cuvette."""
    return (piste_x(FOSSE_Y) + FOSSE_ECART, FOSSE_Y)


def camping_car_xy() -> tuple[float, float]:
    return (piste_x(CAMPING_CAR_Y) + CAMPING_CAR_ECART, CAMPING_CAR_Y)


def _fosse(x: float, y: float) -> float:
    fx, fy = fosse_xy()
    d = math.hypot(x - fx, y - fy)
    if d >= FOSSE_RAYON:
        return 0.0
    return -FOSSE_FOND * math.cos(d / FOSSE_RAYON * math.pi / 2.0) ** 2


def hauteur_du_sol(x: float, y: float, rng_bruit) -> float:
    """L'altitude du terrain en ce point. C'est LA fonction de reference : le
    placement des cactus et des lieux la relit, plutot que de supposer zero."""
    demi = COTE / 2.0
    # Bord du terrain rigoureusement plat : une bosse a la limite du maillage
    # ferait apparaitre le vide en dessous.
    if abs(x) > demi - 0.5 or abs(y) > demi - 0.5:
        return 0.0

    h = _mesa(x, y) + _arroyo(x, y) + _fosse(x, y)
    # Les dunes : du bruit doux par-dessus, jamais sur les plateaux.
    h += rng_bruit(x, y) * 1.3

    # LA PISTE IMPOSE SON PROFIL. On mélange vers elle a l'approche plutot que
    # de la poser sur le terrain : une bande d'asphalte qui suit des bosses
    # d'un metre fait sauter la voiture, et une bande plate posee sur un
    # terrain bossu laisse voir le vide en dessous.
    d = abs(x - piste_x(y))
    emprise = PISTE + 9.0
    if d < emprise:
        t = 1.0 if d < PISTE + 1.0 else 1.0 - (d - PISTE - 1.0) / (emprise - PISTE - 1.0)
        h = h * (1.0 - t) + piste_z(y) * t
    return h


def bruit_de_dunes(graine: int):
    """Un bruit lisse et REPETABLE, tire une fois et interpole.

    Il est fabrique a part parce que DEUX choses doivent lire le meme sol : le
    terrain qui le sculpte, et les cactus qui se posent dessus. Un cactus qui
    relirait un autre bruit flotterait ou s'enterrerait, et ca ne se verrait
    que sur une capture rapprochee.
    """
    rng = random.Random(graine)
    cote_bruit = 26
    bruit = [[rng.uniform(-1.0, 1.0) for _ in range(cote_bruit + 1)]
             for _ in range(cote_bruit + 1)]

    def dunes(x: float, y: float) -> float:
        u = (x + COTE / 2.0) / COTE * cote_bruit
        v = (y + COTE / 2.0) / COTE * cote_bruit
        i, j = int(u), int(v)
        i = max(0, min(cote_bruit - 1, i))
        j = max(0, min(cote_bruit - 1, j))
        fu, fv = u - i, v - j
        a = bruit[i][j] * (1 - fu) + bruit[i + 1][j] * fu
        b = bruit[i][j + 1] * (1 - fu) + bruit[i + 1][j + 1] * fu
        return a * (1 - fv) + b * fv

    return dunes


def terrain(mats, dunes) -> tuple[int, dict]:
    """Le sol, la piste, le relief — et les lieux qu'ils definissent."""
    m = Maillage("Sol", mats["desert"])
    # Cent mailles de cote : 4,6 m par cellule. A vingt, une mesa n'avait que
    # deux cellules de flanc et ressemblait a une pyramide.
    n = 100
    pas = COTE / n
    demi = COTE / 2.0

    grille = [[hauteur_du_sol(-demi + i * pas, -demi + j * pas, dunes)
               for j in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for j in range(n):
            x0, y0 = -demi + i * pas, -demi + j * pas
            x1, y1 = x0 + pas, y0 + pas
            m.face([(x0, y0, grille[i][j]), (x1, y0, grille[i + 1][j]),
                    (x1, y1, grille[i + 1][j + 1]), (x0, y1, grille[i][j + 1])],
                   [(x0 / TUILE_SABLE, y0 / TUILE_SABLE),
                    (x1 / TUILE_SABLE, y0 / TUILE_SABLE),
                    (x1 / TUILE_SABLE, y1 / TUILE_SABLE),
                    (x0 / TUILE_SABLE, y1 / TUILE_SABLE)])
    total = m.finir()

    # La piste : une bande d'asphalte fatigue qui traverse du nord au sud.
    # C'est par la qu'on arrive, et c'est ce qui donne une direction a un
    # espace qui n'en a aucune. Elle suit maintenant sa propre courbe et son
    # propre profil — voir piste_x() et piste_z().
    p = Maillage("Piste", mats["asphalte"])
    segments = 92
    for k in range(segments):
        ya = -demi + COTE * k / segments
        yb = -demi + COTE * (k + 1) / segments
        xa, xb = piste_x(ya), piste_x(yb)
        za, zb = piste_z(ya) + Z_PISTE, piste_z(yb) + Z_PISTE
        va, vb = (ya + demi) / 5.0, (yb + demi) / 5.0
        p.face([(xa - PISTE, ya, za), (xa + PISTE, ya, za),
                (xb + PISTE, yb, zb), (xb - PISTE, yb, zb)],
               [(0, va), (PISTE * 2 / 5.0, va),
                (PISTE * 2 / 5.0, vb), (0, vb)])
    total += p.finir()

    # LES LIEUX. Le generateur SAIT ou sont les choses — il les creuse. Il les
    # publie donc, au lieu que desert.gd en garde des copies : le fichier le
    # disait lui-meme en tete de CAMPING_CAR, « les deux doivent bouger
    # ensemble ; s'ils divergent, un cactus repousse dans le vehicule ».
    # Publies en coordonnees GODOT, pas Blender : (x, y, z) blender devient
    # (x, z, -y). C'est le jeu qui les lit, il n'a pas a faire la conversion —
    # et une conversion faite a deux endroits finit toujours par diverger.
    def godot(lx: float, ly: float, lz: float | None = None) -> list:
        z = hauteur_du_sol(lx, ly, dunes) if lz is None else lz
        return [round(lx, 2), round(z, 2), round(-ly, 2)]

    lieux = {
        "camping_car": godot(*camping_car_xy()),
        "fosse": godot(*fosse_xy()),
        "arroyo_piste": godot(piste_x(ARROYO_Y), ARROYO_Y, piste_z(ARROYO_Y)),
        # Legerement au-dessus du sol : on y depose un vehicule, et le poser
        # pile sur la surface le fait naitre en intersection avec elle.
        "arrivee": godot(piste_x(ARRIVEE_Y), ARRIVEE_Y,
                         piste_z(ARRIVEE_Y) + 0.4),
    }
    for k, (cx, cy, rayon, haut) in enumerate(MESAS):
        lieux["mesa_%d" % (k + 1)] = godot(cx, cy, haut)
    return total, lieux


def rochers(graine: int, dunes) -> list:
    """Ou poser les blocs de gres. Des DONNEES, pas de la geometrie.

    Les cactus, eux, sont cuits dans le terrain — ils y etaient avant qu'on ait
    un fichier de placement pour le desert. Les rochers arrivent apres et
    passent par desert_lieux.json, comme le mobilier de la ville : un rocher
    instancie cent fois partage son maillage, un rocher cuit cent fois pese
    cent fois.

    Ils se serrent au PIED DES MESAS. C'est la que l'eboulis se depose dans la
    vraie vie, et surtout c'est ce qui adoucit le raccord entre un flanc raide
    et un sol plat — sans eux, la mesa a l'air posee sur le desert.
    """
    rng = random.Random(graine + 311)
    poses = []
    for _ in range(1400):
        if len(poses) >= 90:
            break
        # Deux tiers au pied d'une mesa, un tiers disperses : le desert nu a
        # besoin de quelques reperes intermediaires, pas seulement de tas.
        if rng.random() < 0.66:
            cx, cy, rayon, _h = MESAS[rng.randrange(len(MESAS))]
            angle = rng.uniform(0.0, math.tau)
            d = rayon * rng.uniform(1.18, 1.75)
            x, y = cx + math.cos(angle) * d, cy + math.sin(angle) * d
        else:
            x = rng.uniform(-COTE / 2 + 14, COTE / 2 - 14)
            y = rng.uniform(-COTE / 2 + 14, COTE / 2 - 14)
        if abs(x) > COTE / 2 - 10 or abs(y) > COTE / 2 - 10:
            continue
        # Jamais sur la piste — on roule dessus — ni sur le camping-car.
        if abs(x - piste_x(y)) < PISTE + 5.0:
            continue
        cx2, cy2 = camping_car_xy()
        if (x - cx2) ** 2 + (y - cy2) ** 2 < 12.0 ** 2:
            continue
        z = hauteur_du_sol(x, y, dunes)
        poses.append({
            "type": "rocher",
            # Enfonce de quinze centimetres : un bloc pose pile sur la surface
            # laisse voir un lisere de sol sous lui des qu'on le regarde de
            # biais, et il a l'air de flotter.
            "pos": [round(x, 2), round(z - 0.15, 2), round(-y, 2)],
            "angle": round(rng.uniform(0.0, 6.28), 3),
            "echelle": round(rng.uniform(0.55, 2.10), 2),
        })
    return poses


def cactus(mats, graine: int, dunes) -> int:
    """Des saguaros semes autour de la piste.

    Cuits dans le terrain plutot qu'instancies comme le mobilier urbain : ils
    ne bougent jamais, il y en a une trentaine, et le desert n'a pas de fichier
    de placement a lui. Trente objets cuits coutent moins qu'un systeme."""
    rng = random.Random(graine + 77)
    m = Maillage("Cactus", mats["cactus"])
    poses = 0
    for _ in range(400):
        x = rng.uniform(-COTE / 2 + 12, COTE / 2 - 12)
        y = rng.uniform(-COTE / 2 + 12, COTE / 2 - 12)
        # Jamais sur la piste, ni assez pres pour qu'on les percute en roulant.
        if abs(x - piste_x(y)) < PISTE + 3.5:
            continue
        # Ni sur le camping-car. Le generateur du terrain ne sait pas qu'un
        # objet sera pose ici — c'est le jeu qui l'instancie — donc la reserve
        # est declaree en dur. Un saguaro traversait la cellule de part en
        # part, et ca ne se voyait que sur une capture rapprochee.
        cx, cy = camping_car_xy()
        if (x - cx) ** 2 + (y - cy) ** 2 < 9.0 ** 2:
            continue
        # Ni au fond de l'arroyo : c'est un lit de torrent, ce qui y pousse est
        # emporte a la premiere pluie. Le vide y sert le lieu — c'est le seul
        # endroit degage du desert.
        z = hauteur_du_sol(x, y, dunes)
        if z < -0.9:
            continue
        h = rng.uniform(2.2, 4.4)
        m.prisme(x, y, z, z + h, 0.26, 0.20, 6, 1.0)
        # Un bras sur deux, coude vers le haut : c'est la silhouette qui fait
        # le saguaro, pas le nombre de bras.
        if rng.random() < 0.55:
            s = 1.0 if rng.random() < 0.5 else -1.0
            m.boite(x + s * 0.2, y - 0.12, z + h * 0.52,
                    x + s * 0.78, y + 0.12, z + h * 0.52 + 0.24)
            m.prisme(x + s * 0.66, y, z + h * 0.52, z + h * 0.86,
                     0.17, 0.14, 6, 1.0)
        poses += 1
        if poses >= 70:
            break
    return m.finir()


# -------------------------------------------------------------- le camping-car


def camping_car(mats) -> int:
    """Le camping-car. Decor, pas vehicule : on ne le conduit pas.

    Une boite haute sur un chassis, la cabine plus basse et en avant, la bande
    laterale et la porte. C'est une silhouette : a la distance ou on le voit,
    ce qui le designe est sa proportion, pas ses details."""
    total = 0

    caisse = Maillage("Caisse", mats["camping_car"])
    # La cellule : 7,2 m de long, 2,5 de large, du plancher au toit.
    caisse.boite(-1.25, -3.6, 0.95, 1.25, 2.4, 3.05, 2.0)
    # La cabine, plus basse et avancee.
    caisse.boite(-1.15, 2.4, 0.95, 1.15, 4.05, 2.35, 2.0)
    total += caisse.finir()

    vitres = Maillage("Vitres", mats["vitre"])
    # Pare-brise incline, et deux fenetres de cellule.
    vitres.face([(-1.12, 4.06, 1.55), (1.12, 4.06, 1.55),
                 (1.12, 3.55, 2.34), (-1.12, 3.55, 2.34)],
                [(0, 0), (1, 0), (1, 1), (0, 1)])
    for sx in (-1.0, 1.0):
        for y0, y1 in ((-3.0, -1.4), (0.2, 1.8)):
            vitres.face([(sx * 1.26, y0, 1.95), (sx * 1.26, y1, 1.95),
                         (sx * 1.26, y1, 2.62), (sx * 1.26, y0, 2.62)][::int(sx)],
                        [(0, 0), (1, 0), (1, 1), (0, 1)])
    total += vitres.finir()

    # Les roues sont des disques VERTICAUX, alors que prisme() empile toujours
    # sur Z. On les pose donc a la main plutot que d'ajouter un axe a une
    # methode qui sert partout ailleurs.
    p = Maillage("Pneus", mats["pneu"])
    rayon = 0.52
    for sx in (-1.3, 1.3):
        for y in (3.1, -1.5, -2.7):
            for i in range(8):
                a0 = math.tau * i / 8
                a1 = math.tau * (i + 1) / 8
                bande = [
                    (sx, y + math.cos(a0) * rayon, rayon + math.sin(a0) * rayon),
                    (sx, y + math.cos(a1) * rayon, rayon + math.sin(a1) * rayon),
                    (sx * 0.86, y + math.cos(a1) * rayon, rayon + math.sin(a1) * rayon),
                    (sx * 0.86, y + math.cos(a0) * rayon, rayon + math.sin(a0) * rayon),
                ]
                p.face(bande if sx > 0 else bande[::-1],
                       [(0, 0), (1, 0), (1, 1), (0, 1)])
    total += p.finir()
    return total


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    textures = Path(a.textures)
    if not textures.is_absolute():
        textures = racine / textures
    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.mkdir(parents=True, exist_ok=True)

    lieux: dict = {}
    dunes = bruit_de_dunes(a.seed)

    def batir_desert(mats):
        nonlocal lieux
        faces, lieux = terrain(mats, dunes)
        return faces + cactus(mats, a.seed, dunes)

    # LE CAMPING-CAR N EST PLUS FABRIQUE ICI, et c est deliberé.
    #
    # Il est desormais le modele livre par Guillaume, integre le 07/08/2026 par
    # `bg.ps1 integrer` vers ce meme chemin. Le laisser dans cette table
    # signifiait qu un `generer` lance pour une tout autre raison — un cactus,
    # une dune, la couleur de l asphalte — ecrasait sa livraison sans rien
    # dire. C est le piege 11, et il a deja coute le Jesse de Guillaume.
    #
    # Le generateur garde ce qu il est seul a savoir : OU se trouve le
    # camping-car. camping_car_xy() suit la piste qui serpente, et la position
    # continue d etre publiee dans desert_lieux.json. Le terrain au
    # generateur, les objets a Guillaume.
    #
    # La fonction camping_car() est conservee juste en dessous : elle sait
    # rebatir une caisse de secours si la livraison venait a manquer, et ses
    # cotes documentent l encombrement attendu.
    for nom, besoins, batir in [
        ("desert", ["desert", "asphalte", "cactus"], batir_desert),
    ]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        mats = {m: materiau(m, textures) for m in besoins}
        faces = batir(mats)
        fichier = sortie / f"{nom}.glb"
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(
            filepath=str(fichier),
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
        )
        print("desert %-14s %4d faces  -> %s" % (nom, faces, fichier.name))

    # LES LIEUX, en donnees. desert.gd les relit au lieu d'en garder des
    # copies : l'en-tete de CAMPING_CAR prevenait deja que les deux devaient
    # bouger ensemble, et qu'un cactus repousserait dans le vehicule sinon.
    fiche = sortie / "desert_lieux.json"
    fiche.write_text(json.dumps({"cote": COTE, "lieux": lieux,
                                 "decor": rochers(a.seed, dunes)}, indent=1),
                     encoding="utf-8")
    for nom, pos in sorted(lieux.items()):
        print("  lieu %-14s %s" % (nom, pos))
    print("lieux      %s" % fiche.name)
    print("centre du desert : (%.0f, %.0f)" % CENTRE)
    print("sortie     %s" % sortie)


if __name__ == "__main__":
    main()
