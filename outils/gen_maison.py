#!/usr/bin/env python3
"""Genere les maisons de Walter et Jesse, exterieur et interieur.

    blender -b -P outils/gen_maison.py -- --nom walter

Produit deux fichiers par maison :
    game/assets/maisons/<nom>_ext.glb    la facade, posee dans la ville
    game/assets/maisons/<nom>_int.glb    l'interieur, pose a l'ecart du monde

Les interieurs sont SEPARES, pas continus. Ce n'est pas une facilite : la
camera se tient a 3,6 m derriere le personnage et traverserait les murs en
permanence dans une piece. GTA III et Vice City posaient leurs interieurs
dans une zone reculee de la carte pour exactement cette raison, et le
fondu au passage de la porte fait partie du souvenir qu'on en a.

Chaque interieur exporte deux reperes nommes :
    Sortie   ou l'on repose le joueur quand il ressort
    Habitant ou se tient le personnage non joueur
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import bmesh

TUILE = 2.4              # metres couverts par une tuile de texture murale
H_PORTE = 2.05
L_PORTE = 0.95

# Chaque interieur est place tres loin de la ville, sur sa propre parcelle.
ECART_INTERIEURS = 400.0


MAISONS = {
    "walter": {
        # 308 Negra Arroyo Lane : plain-pied en enduit, toit-terrasse.
        "mur": "crepi",
        "largeur": 12.0, "profondeur": 9.0, "hauteur": 3.1,
        "toit": "terrasse",
        "fenetres": [(-3.6, 1.6), (3.2, 1.6), (4.8, 1.6)],
        "sol": "carrelage",
        "piece": (10.4, 7.4, 2.7),
        "meubles": [
            # (x, y, largeur, profondeur, hauteur, texture)
            (-3.2, 1.8, 2.6, 1.0, 0.78, "parquet"),      # plan de travail
            (2.2, -1.4, 2.2, 1.1, 0.42, "parquet"),      # table basse
            (3.6, 1.9, 2.4, 0.9, 0.85, "chemise"),       # canape
            (-4.2, -2.2, 0.7, 0.7, 1.10, "pantalon"),    # colonne, appoint
        ],
        "habitant": (1.0, 1.4),
    },
    "jesse": {
        # Bardage bois, deux niveaux, nettement moins bien tenu.
        "mur": "bardage",
        "largeur": 8.6, "profondeur": 8.0, "hauteur": 5.8,
        "toit": "pente",
        "fenetres": [(-2.6, 1.5), (2.4, 1.5), (-2.6, 4.2), (2.4, 4.2)],
        "sol": "parquet",
        "piece": (7.2, 6.6, 2.8),
        "meubles": [
            (-2.0, 1.6, 2.6, 1.0, 0.72, "pantalon"),
            (1.8, -1.2, 1.9, 1.9, 0.40, "chaussure"),
            (2.4, 1.8, 1.2, 0.9, 1.30, "bardage"),
            (-2.4, -2.0, 1.0, 0.6, 0.95, "chemise"),
        ],
        "habitant": (0.0, 1.5),
    },
}


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de maisons")
    ap.add_argument("--nom", default="toutes", choices=["walter", "jesse", "toutes"])
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default="game/assets/maisons")
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path) -> bpy.types.Material:
    if nom in bpy.data.materials:
        return bpy.data.materials[nom]
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
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
    img.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
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

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


def quad_vertical(m: Maillage, a, b, z0, z1, tuile=TUILE, retourne=False) -> None:
    """Pan de mur entre deux points du plan, de z0 a z1."""
    (x0, y0), (x1, y1) = a, b
    lg = ((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5
    nu, nv = lg / tuile, (z1 - z0) / tuile
    pts = [(x0, y0, z0), (x1, y1, z0), (x1, y1, z1), (x0, y0, z1)]
    if retourne:
        pts.reverse()
    m.face(pts, [(0, 0), (nu, 0), (nu, nv), (0, nv)])


def dalle(m: Maillage, x0, y0, x1, y1, z, tuile=TUILE, dessous=False) -> None:
    pts = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]
    if dessous:
        pts.reverse()
    m.face(pts, [(x0 / tuile, y0 / tuile), (x1 / tuile, y0 / tuile),
                 (x1 / tuile, y1 / tuile), (x0 / tuile, y1 / tuile)])


def boite(m: Maillage, x0, y0, x1, y1, z0, z1, tuile=TUILE) -> None:
    for a, b in [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)),
                 ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]:
        quad_vertical(m, a, b, z0, z1, tuile)
    dalle(m, x0, y0, x1, y1, z1, tuile)


# ------------------------------------------------------------------ exterieur


def construire_exterieur(spec: dict, mats: dict) -> int:
    """Facade avec ouverture de porte reelle : c'est par la qu'on entrera."""
    L, P, H = spec["largeur"], spec["profondeur"], spec["hauteur"]
    hx, hy = L / 2, P / 2
    total = 0

    murs = Maillage("Murs", mats[spec["mur"]])
    # La facade avant (y = -hy) est decoupee autour de la porte, centree en x.
    d0, d1 = -L_PORTE / 2, L_PORTE / 2
    quad_vertical(murs, (-hx, -hy), (d0, -hy), 0, H)
    quad_vertical(murs, (d1, -hy), (hx, -hy), 0, H)
    quad_vertical(murs, (d0, -hy), (d1, -hy), H_PORTE, H)
    # Les trois autres cotes, pleins.
    quad_vertical(murs, (hx, -hy), (hx, hy), 0, H)
    quad_vertical(murs, (hx, hy), (-hx, hy), 0, H)
    quad_vertical(murs, (-hx, hy), (-hx, -hy), 0, H)
    # Tableau de la porte, pour ne pas voir l'epaisseur nulle du mur.
    quad_vertical(murs, (d0, -hy), (d0, -hy + 0.25), 0, H_PORTE)
    quad_vertical(murs, (d1, -hy + 0.25), (d1, -hy), 0, H_PORTE)
    total += murs.finir()

    couverture = Maillage("Toit", mats["toit"])
    if spec["toit"] == "terrasse":
        boite(couverture, -hx - 0.25, -hy - 0.25, hx + 0.25, hy + 0.25, H, H + 0.35)
    else:
        faite = H + 1.7
        for cote in (-1, 1):
            couverture.face(
                [(-hx - 0.2, cote * (hy + 0.2), H),
                 (hx + 0.2, cote * (hy + 0.2), H),
                 (hx + 0.2, 0, faite), (-hx - 0.2, 0, faite)][::cote],
                [(0, 0), (L / TUILE, 0), (L / TUILE, P / TUILE), (0, P / TUILE)])
        for x in (-hx - 0.2, hx + 0.2):
            couverture.face(
                [(x, -hy - 0.2, H), (x, hy + 0.2, H), (x, 0, faite)],
                [(0, 0), (P / TUILE, 0), (P / (2 * TUILE), 1.7 / TUILE)])
    total += couverture.finir()

    # Vitrages et porte, poses juste devant la facade.
    vitres = Maillage("Fenetres", mats["fenetre_maison"])
    for fx, fz in spec["fenetres"]:
        vitres.face(
            [(fx - 0.62, -hy - 0.03, fz - 0.55), (fx + 0.62, -hy - 0.03, fz - 0.55),
             (fx + 0.62, -hy - 0.03, fz + 0.55), (fx - 0.62, -hy - 0.03, fz + 0.55)],
            [(0, 0), (1, 0), (1, 1), (0, 1)])
    total += vitres.finir()

    battant = Maillage("Battant", mats["porte"])
    battant.face(
        [(d0, -hy + 0.24, 0), (d1, -hy + 0.24, 0),
         (d1, -hy + 0.24, H_PORTE), (d0, -hy + 0.24, H_PORTE)],
        [(0, 0), (1, 0), (1, 1), (0, 1)])
    total += battant.finir()

    # Repere du seuil, juste devant la porte. Exporte plutot que recalcule
    # cote Godot : la geometrie change, le repere suit tout seul.
    #
    # Il s'appelait "Porte", et il n'arrivait jamais dans le .glb : le battant
    # porte le materiau "porte", et l'exportateur glTF fusionne les noms qui
    # se ressemblent trop a ce point. On se retrouvait avec un maillage nomme
    # "Porte" a l'origine de la maison, que le code cote Godot prenait pour le
    # seuil — l'entree se serait faite au milieu du salon. Nom distinct.
    seuil = bpy.data.objects.new("Seuil", None)
    seuil.empty_display_type = "PLAIN_AXES"
    seuil.location = (0.0, -hy - 1.1, 0.0)
    bpy.context.collection.objects.link(seuil)

    return total


# ------------------------------------------------------------------ interieur


def verifier(nom: str, spec: dict) -> None:
    """Refuse une piece ou l'habitant se tient dans un meuble.

    Ca s'est produit : Jesse etait plante au milieu de son plan de travail,
    coupe a la taille. Rien ne plantait, rien ne s'affichait en rouge — il
    fallait aller le voir. Un habitant est un point, un meuble est une boite,
    la verification tient en six lignes, autant la faire ici une fois pour
    toutes plutot que de la redecouvrir en jouant.
    """
    hx, hy = spec["piece"][0] / 2, spec["piece"][1] / 2
    px, py = spec["habitant"]
    marge = 0.45                              # demi-largeur d'un personnage

    if abs(px) > hx - marge or abs(py) > hy - marge:
        raise SystemExit(f"{nom} : l'habitant {spec['habitant']} est dans un mur")

    for mx, my, ml, mp, _mh, _tex in spec["meubles"]:
        if (abs(px - mx) < ml / 2 + marge) and (abs(py - my) < mp / 2 + marge):
            raise SystemExit(
                f"{nom} : l'habitant {spec['habitant']} est dans le meuble "
                f"pose en ({mx}, {my}). Le deplacer dans MAISONS.")


def construire_interieur(spec: dict, mats: dict) -> int:
    """Piece fermee, murs tournes vers l'INTERIEUR.

    Une boite ordinaire a ses normales vers l'exterieur : vue de dedans, elle
    disparait. Chaque pan est donc retourne.
    """
    L, P, H = spec["piece"]
    hx, hy = L / 2, P / 2
    total = 0

    sol = Maillage("Sol", mats[spec["sol"]])
    dalle(sol, -hx, -hy, hx, hy, 0.0, 1.6)
    total += sol.finir()

    murs = Maillage("MursInterieurs", mats["mur_interieur"])
    for a, b in [((-hx, -hy), (hx, -hy)), ((hx, -hy), (hx, hy)),
                 ((hx, hy), (-hx, hy)), ((-hx, hy), (-hx, -hy))]:
        quad_vertical(murs, a, b, 0, H, TUILE, retourne=True)
    dalle(murs, -hx, -hy, hx, hy, H, 2.4, dessous=True)
    total += murs.finir()

    meubles = {}
    for mx, my, ml, mp, mh, tex in spec["meubles"]:
        if tex not in meubles:
            meubles[tex] = Maillage(f"Meuble_{tex}", mats[tex])
        boite(meubles[tex], mx - ml / 2, my - mp / 2, mx + ml / 2, my + mp / 2,
              0.0, mh, 1.2)
    for m in meubles.values():
        total += m.finir()

    # Reperes : Blender +Y donne Godot -Z, les scripts s'y retrouvent seuls.
    for nom, (px, py) in [("Sortie", (0.0, -hy + 1.2)),
                          ("Habitant", spec["habitant"])]:
        repere = bpy.data.objects.new(nom, None)
        repere.empty_display_type = "PLAIN_AXES"
        repere.location = (px, py, 0.0)
        bpy.context.collection.objects.link(repere)

    return total


def exporter(chemin: Path) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(chemin),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )


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

    noms = list(MAISONS) if a.nom == "toutes" else [a.nom]
    besoins = ["crepi", "bardage", "toit", "porte", "fenetre_maison",
               "parquet", "mur_interieur", "carrelage", "chemise",
               "pantalon", "chaussure"]

    for nom in noms:
        spec = MAISONS[nom]
        verifier(nom, spec)
        for suffixe, batir in (("ext", construire_exterieur),
                               ("int", construire_interieur)):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            mats = {m: materiau(m, textures) for m in besoins}
            faces = batir(spec, mats)
            fichier = sortie / f"{nom}_{suffixe}.glb"
            exporter(fichier)
            print(f"maison {nom:8s} {suffixe}  {faces:4d} faces  -> {fichier.name}")

    print(f"\nsortie     {sortie}")


if __name__ == "__main__":
    main()
