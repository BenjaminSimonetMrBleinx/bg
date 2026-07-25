#!/usr/bin/env python3
"""Genere le vehicule joueur — un monospace low-poly facon Aztek.

    blender -b -P outils/gen_voiture.py -- --couleur voiture_aztek

Produit deux fichiers separes :
    game/assets/vehicules/caisse.glb   origine au sol, au centre du vehicule
    game/assets/vehicules/roue.glb     origine au centre de la roue

Cette separation n'est pas cosmetique : le VehicleBody3D de Godot attend une
caisse dont l'origine est au centre de gravite, et des roues pilotees par des
noeuds VehicleWheel3D. Un pivot mal place fait tourner une roue de travers, et
ca se voit immediatement.

La caisse est construite par sections transversales successives, reliees deux
a deux. C'est la methode la plus economique pour obtenir une silhouette de
voiture credible en une centaine de triangles — exactement le budget PS2.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh

# Cotes en metres. X = longueur (avant vers +X), Y = largeur, Z = hauteur.
EMPATTEMENT = 2.75
VOIE = 1.64
RAYON_ROUE = 0.34
LARGEUR_ROUE = 0.24
COTES_ROUE = 10                 # 10 cotes : rond de loin, facette de pres

CEINTURE = 1.10                 # ligne de separation tolerie / vitrage

# Sections de la caisse, de l'arriere vers l'avant.
#   x     demi-largeur  bas    haut
SECTIONS = [
    (-2.30, 0.76, 0.46, 1.34),
    (-2.05, 0.90, 0.40, 1.50),
    (-1.55, 0.95, 0.38, 1.60),
    (-0.60, 0.95, 0.37, 1.62),
    ( 0.35, 0.95, 0.37, 1.58),
    ( 0.95, 0.93, 0.38, 1.38),
    ( 1.45, 0.90, 0.40, 1.12),
    ( 2.05, 0.86, 0.44, 1.04),
    ( 2.32, 0.74, 0.52, 0.96),
]


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de vehicule")
    ap.add_argument("--couleur", default="voiture_aztek")
    ap.add_argument("--textures", default="game/assets/textures")
    ap.add_argument("--sortie", default="game/assets/vehicules")
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path) -> bpy.types.Material:
    if nom in bpy.data.materials:
        return bpy.data.materials[nom]
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    for champ in ("Specular IOR Level", "Specular"):
        if champ in bsdf.inputs:
            bsdf.inputs[champ].default_value = 0.0
    png = dossier / f"{nom}.png"
    if png.exists():
        img = bpy.data.images.load(str(png), check_existing=True)
        img.pack()
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Linear"
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        print(f"  ! texture absente : {png}")
    return mat


class Maillage:
    def __init__(self, nom: str, mats: list):
        self.mesh = bpy.data.meshes.new(nom)
        self.obj = bpy.data.objects.new(nom, self.mesh)
        bpy.context.collection.objects.link(self.obj)
        for m in mats:
            self.mesh.materials.append(m)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def face(self, points, uvs, slot=0) -> None:
        verts = [self.bm.verts.new(p) for p in points]
        f = self.bm.faces.new(verts)
        f.material_index = slot
        for boucle, coord in zip(f.loops, uvs):
            boucle[self.uv].uv = coord

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


# --------------------------------------------------------------------- caisse


def construire_caisse(mats_noms: list) -> Maillage:
    """Deux bandeaux par section : tolerie sous la ceinture, vitrage au-dessus.

    Les emplacements de materiau sont : 0 carrosserie, 1 vitrage,
    2 feu avant, 3 feu arriere.
    """
    m = Maillage("caisse", mats_noms)
    n = len(SECTIONS)

    def bornes(s):
        x, hw, bas, haut = s
        ceinture = min(max(CEINTURE, bas + 0.05), haut - 0.05)
        return x, hw, bas, ceinture, haut

    # --- flancs, toit et soubassement ---
    for i in range(n - 1):
        x0, w0, b0, c0, h0 = bornes(SECTIONS[i])
        x1, w1, b1, c1, h1 = bornes(SECTIONS[i + 1])
        u0, u1 = i / (n - 1), (i + 1) / (n - 1)

        for cote in (1, -1):                       # droite puis gauche
            # tolerie
            pts = [(x0, cote * w0, b0), (x1, cote * w1, b1),
                   (x1, cote * w1, c1), (x0, cote * w0, c0)]
            if cote < 0:
                pts.reverse()
            m.face(pts, [(u0, 0.0), (u1, 0.0), (u1, 0.62), (u0, 0.62)], 0)
            # vitrage
            pts = [(x0, cote * w0, c0), (x1, cote * w1, c1),
                   (x1, cote * w1, h1), (x0, cote * w0, h0)]
            if cote < 0:
                pts.reverse()
            m.face(pts, [(u0, 0.0), (u1, 0.0), (u1, 1.0), (u0, 1.0)], 1)

        # Seules les faces superieures reellement inclinees sont vitrees :
        # pare-brise (i = 4 et 5) et hayon arriere (i = 0). Le toit plat entre
        # les deux est de la tolerie — une premiere version vitrait tout et la
        # voiture ressemblait a une serre.
        vitre_toit = i in (0, 4, 5)
        m.face([(x0, -w0, h0), (x1, -w1, h1), (x1, w1, h1), (x0, w0, h0)],
               [(u0, 0), (u1, 0), (u1, 1), (u0, 1)], 1 if vitre_toit else 0)
        # soubassement
        m.face([(x0, w0, b0), (x1, w1, b1), (x1, -w1, b1), (x0, -w0, b0)],
               [(u0, 0), (u1, 0), (u1, 1), (u0, 1)], 0)

    # --- fermeture avant et arriere ---
    for s, sens in ((SECTIONS[0], -1), (SECTIONS[-1], 1)):
        x, w, b, c, h = bornes(s)
        pts = [(x, -w, b), (x, w, b), (x, w, h), (x, -w, h)]
        if sens < 0:
            pts.reverse()
        m.face(pts, [(0, 0), (1, 0), (1, 1), (0, 1)], 0)

    # --- optiques : de simples quads plaques sur le nez et la poupe ---
    xa = SECTIONS[-1][0] + 0.005
    xr = SECTIONS[0][0] - 0.005
    for cote in (1, -1):
        m.face([(xa, cote * 0.30, 0.72), (xa, cote * 0.66, 0.72),
                (xa, cote * 0.66, 0.92), (xa, cote * 0.30, 0.92)][::cote],
               [(0, 0), (1, 0), (1, 1), (0, 1)], 2)
        m.face([(xr, cote * 0.28, 0.80), (xr, cote * 0.68, 0.80),
                (xr, cote * 0.68, 1.02), (xr, cote * 0.28, 1.02)][::-cote],
               [(0, 0), (1, 0), (1, 1), (0, 1)], 3)

    return m


# ----------------------------------------------------------------------- roue


def construire_roue(mats_noms: list) -> Maillage:
    """Cylindre a 10 cotes, axe sur Y, origine au centre. Emplacements :
    0 gomme, 1 flanc."""
    m = Maillage("roue", mats_noms)
    r, w = RAYON_ROUE, LARGEUR_ROUE / 2.0
    pas = 2.0 * math.pi / COTES_ROUE

    for i in range(COTES_ROUE):
        a0, a1 = i * pas, (i + 1) * pas
        x0, z0 = math.cos(a0) * r, math.sin(a0) * r
        x1, z1 = math.cos(a1) * r, math.sin(a1) * r
        u0, u1 = i / COTES_ROUE, (i + 1) / COTES_ROUE

        # bande de roulement
        m.face([(x0, -w, z0), (x1, -w, z1), (x1, w, z1), (x0, w, z0)],
               [(u0, 0), (u1, 0), (u1, 1), (u0, 1)], 0)

        # flancs : UV en disque pour que l'enjoliveur tombe au centre
        c0 = (0.5 + math.cos(a0) * 0.5, 0.5 + math.sin(a0) * 0.5)
        c1 = (0.5 + math.cos(a1) * 0.5, 0.5 + math.sin(a1) * 0.5)
        m.face([(0, w, 0), (x0, w, z0), (x1, w, z1)],
               [(0.5, 0.5), c0, c1], 1)
        m.face([(0, -w, 0), (x1, -w, z1), (x0, -w, z0)],
               [(0.5, 0.5), c1, c0], 1)

    return m


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

    bpy.ops.wm.read_factory_settings(use_empty=True)

    mats = {n: materiau(n, textures) for n in
            [a.couleur, "vitre", "feu_avant", "feu_arriere", "pneu", "jante"]}

    caisse = construire_caisse([mats[a.couleur], mats["vitre"],
                                mats["feu_avant"], mats["feu_arriere"]])
    f_caisse = caisse.finir()
    roue = construire_roue([mats["pneu"], mats["jante"]])
    f_roue = roue.finir()

    # Orientation. La caisse est construite avec l'avant vers +X, mais le
    # VehicleBody3D de Godot attend l'avant vers -Z. Une rotation de 90 deg
    # autour de Z avant export ramene +X sur +Y, et l'exportateur glTF envoie
    # +Y sur -Z. La roue suit : son axe passe de Y a X, ce qui est l'axe
    # gauche-droite attendu. On applique la rotation plutot que de tordre la
    # construction, qui reste ainsi lisible.
    for obj in (caisse.obj, roue.obj):
        obj.rotation_euler = (0.0, 0.0, math.radians(90.0))

    # Un objet par fichier : Godot recoit une scene propre pour chacun.
    for obj, nom in ((caisse.obj, "caisse"), (roue.obj, "roue")):
        for o in bpy.data.objects:
            o.select_set(o is obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(
            filepath=str(sortie / f"{nom}.glb"),
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
        )

    print("")
    print(f"caisse     {f_caisse} faces   couleur {a.couleur}")
    print(f"roue       {f_roue} faces   rayon {RAYON_ROUE} m")
    print(f"empattement {EMPATTEMENT} m, voie {VOIE} m")
    print(f"sortie     {sortie}")


if __name__ == "__main__":
    main()
