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

# Ou le jeu pose le camping-car, en coordonnees du TERRAIN (Blender : x, y).
# Duplique de systemes/desert.gd, qui l'instancie — le generateur ne peut pas
# lire un script Godot. Les deux doivent bouger ensemble ; s'ils divergent, un
# cactus repousse dans le vehicule.
CAMPING_CAR = (-23.0, -96.0)
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


def terrain(mats, graine: int) -> int:
    """Le sol, la piste, et un relief tres bas.

    Le sol n'est pas un seul quadrilatere : une grille de vingt par vingt, dont
    les sommets montent un peu. C'est presque gratuit — quatre cents faces — et
    ca suffit a enlever l'impression de patinoire qu'un plan parfait donne
    toujours, meme texture."""
    rng = random.Random(graine)
    m = Maillage("Sol", mats["desert"])

    n = 20
    pas = COTE / n
    demi = COTE / 2.0

    def hauteur(i: int, j: int) -> float:
        # Bord du terrain rigoureusement plat : une bosse a la limite du
        # maillage ferait apparaitre le vide en dessous.
        if i in (0, n) or j in (0, n):
            return 0.0
        x = -demi + i * pas
        y = -demi + j * pas
        # La piste reste plate, sinon la voiture saute sur une route.
        if abs(x) < PISTE:
            return 0.0
        loin = min(abs(x) - PISTE, 40.0) / 40.0
        return (rng.random() - 0.35) * 1.1 * loin

    grille = [[hauteur(i, j) for j in range(n + 1)] for i in range(n + 1)]
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
    # espace qui n'en a aucune.
    p = Maillage("Piste", mats["asphalte"])
    p.face([(-PISTE, -demi, Z_PISTE), (PISTE, -demi, Z_PISTE),
            (PISTE, demi, Z_PISTE), (-PISTE, demi, Z_PISTE)],
           [(0, 0), (PISTE * 2 / 5.0, 0),
            (PISTE * 2 / 5.0, COTE / 5.0), (0, COTE / 5.0)])
    total += p.finir()
    return total


def cactus(mats, graine: int) -> int:
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
        if abs(x) < PISTE + 3.5:
            continue
        # Ni sur le camping-car. Le generateur du terrain ne sait pas qu'un
        # objet sera pose ici — c'est le jeu qui l'instancie — donc la reserve
        # est declaree en dur. Un saguaro traversait la cellule de part en
        # part, et ca ne se voyait que sur une capture rapprochee.
        if (x - CAMPING_CAR[0]) ** 2 + (y - CAMPING_CAR[1]) ** 2 < 8.0 ** 2:
            continue
        h = rng.uniform(2.2, 4.4)
        m.prisme(x, y, 0.0, h, 0.26, 0.20, 6, 1.0)
        # Un bras sur deux, coude vers le haut : c'est la silhouette qui fait
        # le saguaro, pas le nombre de bras.
        if rng.random() < 0.55:
            s = 1.0 if rng.random() < 0.5 else -1.0
            m.boite(x + s * 0.2, y - 0.12, h * 0.52,
                    x + s * 0.78, y + 0.12, h * 0.52 + 0.24)
            m.prisme(x + s * 0.66, y, h * 0.52, h * 0.86, 0.17, 0.14, 6, 1.0)
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

    for nom, besoins, batir in [
        ("desert", ["desert", "asphalte", "cactus"],
         lambda mats: terrain(mats, a.seed) + cactus(mats, a.seed)),
        ("camping_car", ["camping_car", "vitre", "pneu"], camping_car),
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

    print("centre du desert : (%.0f, %.0f)" % CENTRE)
    print("sortie     %s" % sortie)


if __name__ == "__main__":
    main()
