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

# LES MODELES.
#
# Une voiture n'est qu'une suite de sections transversales, de l'arriere vers
# l'avant : x, demi-largeur, bas de caisse, haut. Changer de silhouette, c'est
# changer cette table — pas une ligne de code.
#
# Toutes ont NEUF sections, et ce n'est pas une coincidence : c'est ce qui
# permet a un seul constructeur de les traiter toutes, et de designer le
# pare-brise et la lunette par leur indice.
#
# Epoque : la serie se deroule de 2008 a 2010, au Nouveau-Mexique. Le parc
# roulant y est fait de pick-up, de berlines americaines des annees quatre-
# vingt-dix et de gros breaks. C'est ce qu'on croise dans la rue, et c'est ce
# que le generateur produit.
MODELES = {
    "aztek": {
        "quoi": "Le monospace de Walter. Laid, et c'est le sujet.",
        "empattement": 2.75, "voie": 1.64, "rayon_roue": 0.34,
        "ceinture": 1.10, "vitre_toit": (0, 4, 5),
        "couleur": "voiture_aztek",
        "sections": [
            (-2.30, 0.76, 0.46, 1.34),
            (-2.05, 0.90, 0.40, 1.50),
            (-1.55, 0.95, 0.38, 1.60),
            (-0.60, 0.95, 0.37, 1.62),
            ( 0.35, 0.95, 0.37, 1.58),
            ( 0.95, 0.93, 0.38, 1.38),
            ( 1.45, 0.90, 0.40, 1.12),
            ( 2.05, 0.86, 0.44, 1.04),
            ( 2.32, 0.74, 0.52, 0.96),
        ],
    },

    "pickup": {
        "quoi": "Le pick-up. Le vehicule le plus banal du Nouveau-Mexique.",
        "empattement": 3.30, "voie": 1.72, "rayon_roue": 0.38,
        "ceinture": 1.30, "vitre_toit": (5,),
        "couleur": "voiture_pickup",
        "sections": [
            (-2.72, 0.86, 0.54, 1.24),
            (-2.42, 0.96, 0.52, 1.28),
            (-0.92, 0.96, 0.52, 1.30),   # la benne : basse et ouverte
            (-0.78, 0.99, 0.50, 1.94),   # dos de cabine
            (-0.08, 0.99, 0.48, 1.97),
            ( 0.58, 0.97, 0.48, 1.84),   # pare-brise
            ( 1.08, 0.95, 0.50, 1.32),   # capot
            ( 2.24, 0.93, 0.52, 1.24),
            ( 2.58, 0.80, 0.60, 1.16),
        ],
    },

    "berline": {
        "quoi": "La grosse berline americaine des annees quatre-vingt-dix.",
        "empattement": 2.90, "voie": 1.60, "rayon_roue": 0.33,
        "ceinture": 1.00, "vitre_toit": (0, 4, 5),
        "couleur": "voiture_b",
        "sections": [
            (-2.46, 0.72, 0.42, 1.02),
            (-2.16, 0.88, 0.38, 1.16),
            (-1.60, 0.92, 0.36, 1.42),
            (-0.76, 0.92, 0.35, 1.46),
            ( 0.26, 0.92, 0.35, 1.44),
            ( 0.90, 0.90, 0.36, 1.20),
            ( 1.60, 0.88, 0.38, 1.04),
            ( 2.26, 0.84, 0.42, 0.98),
            ( 2.48, 0.70, 0.50, 0.92),
        ],
    },

    "break": {
        "quoi": "Le break familial haut sur pattes, l'autre banalite locale.",
        "empattement": 2.80, "voie": 1.66, "rayon_roue": 0.35,
        "ceinture": 1.16, "vitre_toit": (0, 4, 5),
        "couleur": "voiture_c",
        "sections": [
            (-2.36, 0.80, 0.48, 1.40),
            (-2.10, 0.94, 0.44, 1.72),
            (-1.50, 0.98, 0.42, 1.80),
            (-0.56, 0.98, 0.42, 1.82),
            ( 0.40, 0.98, 0.42, 1.78),
            ( 1.00, 0.96, 0.43, 1.50),
            ( 1.56, 0.92, 0.45, 1.20),
            ( 2.16, 0.88, 0.48, 1.12),
            ( 2.40, 0.74, 0.56, 1.04),
        ],
    },

    # L'ANACHRONISME ASSUME.
    #
    # Alpine n'a rien produit entre 1995 et 2017 : aucune Alpine n'est
    # contemporaine de la serie. Celle-ci est donc une A110 des annees
    # soixante-dix, telle qu'un collectionneur en garderait une — ce qui, a
    # Albuquerque, en fait une voiture qu'on remarque. C'est justement pour ca
    # qu'elle est la : une ville de pick-up a besoin d'une exception.
    #
    # Proportions de l'originale : 3,85 m de long, 1,13 m de haut, tres basse
    # et tres etroite. C'est la silhouette qui la designe, pas le detail.
    "alpine": {
        "quoi": "Une A110 de collection. Anachronique, et voulue comme telle.",
        "empattement": 2.10, "voie": 1.32, "rayon_roue": 0.28,
        "ceinture": 0.72, "vitre_toit": (0, 4, 5),
        "couleur": "voiture_alpine",
        "sections": [
            (-1.92, 0.60, 0.30, 0.84),
            (-1.70, 0.74, 0.26, 0.99),
            (-1.16, 0.78, 0.25, 1.13),   # la bosse du moteur arriere
            (-0.56, 0.78, 0.24, 1.12),
            (-0.10, 0.76, 0.24, 1.10),
            ( 0.46, 0.72, 0.25, 0.92),   # pare-brise tres incline
            ( 1.06, 0.68, 0.27, 0.72),   # capot plongeant
            ( 1.60, 0.62, 0.30, 0.66),
            ( 1.86, 0.50, 0.36, 0.62),
        ],
    },
}

# Le modele en cours de construction. Pose par main() : les constructeurs
# lisent ces valeurs plutot que de recevoir dix parametres.
SECTIONS = MODELES["aztek"]["sections"]
CEINTURE = MODELES["aztek"]["ceinture"]
VITRE_TOIT = MODELES["aztek"]["vitre_toit"]


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de vehicule")
    ap.add_argument("--modele", default="aztek",
                    help="silhouette : " + ", ".join(MODELES) + ", ou tous")
    ap.add_argument("--couleur", default="",
                    help="remplace la couleur par defaut du modele")
    # Une voiture GAREE n'a pas besoin de roues pilotees : on fond tout dans un
    # seul maillage. Cent voitures a l'arret, c'est cent instances d'un fichier
    # au lieu de cinq cents.
    ap.add_argument("--garee", action="store_true",
                    help="produit un seul .glb roues comprises, pour le decor")
    ap.add_argument("--textures", default=".tmp/textures")
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
    if not png.exists():
        # La palette vit dans .tmp/, hors du projet Godot : elle n est qu une
        # matiere premiere, cuite dans le .glb a l export. Sans elle le modele
        # sortait gris SANS RIEN DIRE, et on cherchait le probleme dans Blender.
        raise SystemExit(
            f"texture absente : {png}\n"
            f"La palette se refabrique : .\\bg.ps1 generer"
        )
    img = bpy.data.images.load(str(png), check_existing=True)
    img.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
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
        vitre_toit = i in VITRE_TOIT
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


def batir(nom: str, couleur: str, garee: bool, textures: Path, sortie: Path) -> str:
    """Construit un modele et l'exporte. Renvoie une ligne de compte rendu."""
    global SECTIONS, CEINTURE, VITRE_TOIT, EMPATTEMENT, VOIE, RAYON_ROUE

    fiche = MODELES[nom]
    SECTIONS = fiche["sections"]
    CEINTURE = fiche["ceinture"]
    VITRE_TOIT = fiche["vitre_toit"]
    EMPATTEMENT = fiche["empattement"]
    VOIE = fiche["voie"]
    RAYON_ROUE = fiche["rayon_roue"]
    teinte = couleur or fiche["couleur"]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {n: materiau(n, textures) for n in
            [teinte, "vitre", "feu_avant", "feu_arriere", "pneu", "jante"]}

    caisse = construire_caisse([mats[teinte], mats["vitre"],
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

    if garee:
        # Les quatre roues sont POSEES et fondues dans la caisse. Une voiture
        # a l'arret n'a pas de roues a piloter, et un seul objet coute un seul
        # appel de rendu au lieu de cinq.
        demi_e = EMPATTEMENT / 2.0
        demi_v = VOIE / 2.0
        exemplaires = []
        for dz in (-demi_e, demi_e):
            for dx in (-demi_v, demi_v):
                copie = roue.obj.copy()
                copie.data = roue.obj.data.copy()
                # Apres rotation, la caisse regarde -Z : l'empattement est sur
                # Z et la voie sur X.
                # Blender est en Z-UP : la hauteur est z, pas y. Une premiere
                # version posait les roues a (x, rayon, z) et les faisait
                # flotter au niveau des vitres, couchees sur le flanc.
                #
                # La caisse ayant subi une rotation de 90 degres autour de Z,
                # sa longueur est desormais sur Y et sa largeur sur X.
                copie.location = (dx, dz, RAYON_ROUE)
                bpy.context.collection.objects.link(copie)
                exemplaires.append(copie)
        bpy.data.objects.remove(roue.obj, do_unlink=True)

        for o in bpy.data.objects:
            o.select_set(o in exemplaires or o is caisse.obj)
        bpy.context.view_layer.objects.active = caisse.obj
        bpy.ops.object.join()

        fichier = sortie / f"garee_{nom}.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(fichier), export_format="GLB", use_selection=True,
            export_apply=True, export_yup=True,
            export_cameras=False, export_lights=False)
        return "garee_%-9s %4d faces   %s" % (nom, f_caisse + f_roue * 4, teinte)

    for obj, base in ((caisse.obj, "caisse"), (roue.obj, "roue")):
        for o in bpy.data.objects:
            o.select_set(o is obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(
            filepath=str(sortie / f"{base}.glb"),
            export_format="GLB", use_selection=True, export_apply=True,
            export_yup=True, export_cameras=False, export_lights=False)
    return ("caisse %-11s %4d faces   %s   empattement %.2f m"
            % (nom, f_caisse, teinte, EMPATTEMENT))


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

    noms = list(MODELES) if a.modele == "tous" else [a.modele]
    for nom in noms:
        if nom not in MODELES:
            raise SystemExit("modele inconnu : %s. Connus : %s"
                             % (nom, ", ".join(MODELES)))

    for nom in noms:
        print(batir(nom, a.couleur, a.garee, textures, sortie))
    print(f"sortie     {sortie}")


if __name__ == "__main__":
    main()