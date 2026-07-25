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

                COULOIR = 14 m
        |<-------------------->|
        | 3 |      8      | 3  |
        trot   chaussee   trot        <- entre deux ilots
                                      PAS = 40 + 14 = 54 m
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import bpy
import bmesh

# Toutes les distances sont en metres. Blender est en Z-up ; l'exportateur
# glTF convertit vers le Y-up de Godot, on ne compense rien a la main.
ROUTE = 8.0
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


# ------------------------------------------------------------------ utilitaires


def arguments() -> argparse.Namespace:
    """Blender avale ses propres arguments : les notres sont apres --."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de ville")
    ap.add_argument("--blocs", type=int, default=2, help="ilots par cote")
    ap.add_argument("--seed", type=int, default=505)
    ap.add_argument("--textures", default="game/assets/textures")
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
    if png.exists():
        img = bpy.data.images.load(str(png), check_existing=True)
        img.pack()                                  # embarquee dans le .glb
        tex = arbre.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Linear"                # bilineaire : le flou PS2
        tex.extension = "REPEAT"
        tex.location = (-420, 220)
        arbre.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        print(f"  ! texture absente : {png}")
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


def construire(n: int, rng: random.Random, mats: dict) -> dict:
    noms = ["route", "asphalte", "trottoir", "desert", "lampes"] + FACADES
    m = {nom: Maillage(nom, mats[nom]) for nom in noms}

    etendue = n * BLOC + (n + 1) * COULOIR
    lampes: list[tuple[float, float, float, float]] = []

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
                    continue

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
                    else:
                        boite(m[mat], cx0, cy0 + pos, cx1, cy0 + pos + large, 0.0, h)
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

    faces = sum(maillage.finir() for maillage in m.values())
    return {"etendue": etendue, "lampes": lampes, "faces": faces}


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
    }, indent=1), encoding="utf-8")

    print("")
    print(f"ville      {a.blocs} x {a.blocs} ilots, {info['etendue']:.0f} m de cote")
    print(f"graine     {a.seed}")
    print(f"lampes     {len(info['lampes'])}")
    print(f"faces      {info['faces']}")
    print(f"sortie     {sortie}")


if __name__ == "__main__":
    main()
