#!/usr/bin/env python3
"""Genere les objets que Walter peut tenir.

    blender -b -P outils/gen_objets.py -- --nom tous

Produit un .glb par objet dans game/assets/objets/. Ce sont des accessoires,
pas des maillages de heros : quelques dizaines de faces chacun, tenus a bout
de bras et vus a 512 pixels de large. Ce qui compte est la silhouette — a
cette taille, on reconnait une forme, jamais un detail.

Chaque objet est modelise dans le repere de la MAIN, pas dans le sien : la
poignee de l'arme est a l'origine, le bord du chapeau aussi. C'est ce qui
permet de les accrocher sans reglage au cas par cas.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import bmesh


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur d objets tenus")
    ap.add_argument("--nom", default="tous")
    ap.add_argument("--textures", default="game/assets/textures")
    ap.add_argument("--sortie", default="game/assets/objets")
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    arbre = mat.node_tree
    principal = arbre.nodes["Principled BSDF"]
    principal.inputs["Roughness"].default_value = 0.85
    principal.inputs["Metallic"].default_value = 0.0

    png = dossier / f"{nom}.png"
    if png.exists():
        img = bpy.data.images.load(str(png), check_existing=True)
        img.alpha_mode = "NONE"
        tex = arbre.nodes.new("ShaderNodeTexImage")
        tex.image = img
        # Filtrage lineaire : c'est le rendu PS2, pas les texels carres PS1.
        tex.interpolation = "Linear"
        arbre.links.new(principal.inputs["Base Color"], tex.outputs["Color"])
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
        """Pave droit, six faces, UV mis a l'echelle de chaque face."""
        lx, ly, lz = (x1 - x0) / tuile, (y1 - y0) / tuile, (z1 - z0) / tuile
        c = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        for indices, (u, v) in [
            ((0, 3, 2, 1), (lx, ly)),          # dessous
            ((4, 5, 6, 7), (lx, ly)),          # dessus
            ((0, 1, 5, 4), (lx, lz)),
            ((1, 2, 6, 5), (ly, lz)),
            ((2, 3, 7, 6), (lx, lz)),
            ((3, 0, 4, 7), (ly, lz)),
        ]:
            self.face([c[i] for i in indices],
                      [(0, 0), (u, 0), (u, v), (0, v)])

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


# --------------------------------------------------------------- les objets
#
# Convention : l'objet est construit debout, Z vers le haut, et son point de
# prise est a l'origine. L'orientation finale dans la main est reglee dans
# game/donnees/outils.json — donc modifiable sans regenerer quoi que ce soit.


def arme(mats) -> int:
    """Un revolver court. Deux volumes suffisent a le rendre reconnaissable :
    une crosse inclinee et un canon horizontal."""
    total = 0
    m = Maillage("Arme", mats["metal"])
    m.boite(-0.018, -0.030, -0.105, 0.018, 0.028, 0.010)   # crosse
    m.boite(-0.016, 0.020, 0.012, 0.016, 0.170, 0.048)     # canon
    m.boite(-0.020, -0.005, 0.006, 0.020, 0.045, 0.052)    # barillet
    total += m.finir()

    d = Maillage("Detente", mats["metal_sombre"])
    d.boite(-0.006, 0.004, -0.030, 0.006, 0.030, 0.006)    # pontet
    total += d.finir()
    return total


def meth(mats) -> int:
    """Un sachet de cristaux bleus. Une poche plate, et quelques eclats qui
    depassent : c'est ce qui la distingue d'un simple rectangle."""
    total = 0
    m = Maillage("Sachet", mats["cristal"])
    m.boite(-0.055, -0.018, 0.0, 0.055, 0.018, 0.130)
    total += m.finir()

    e = Maillage("Cristaux", mats["cristal_clair"])
    for x, z, t in [(-0.028, 0.045, 0.020), (0.010, 0.075, 0.026),
                    (0.034, 0.038, 0.017), (-0.006, 0.104, 0.014)]:
        e.boite(x - t / 2, -0.021, z - t / 2, x + t / 2, 0.021, z + t / 2)
    total += e.finir()
    return total


def livre(mats) -> int:
    """« Feuilles d'herbe ». Une couverture et une tranche claire, ce qui
    suffit a lire un livre a cette distance."""
    total = 0
    c = Maillage("Couverture", mats["couverture"])
    c.boite(-0.075, -0.012, 0.0, 0.075, 0.012, 0.210)
    total += c.finir()

    p = Maillage("Pages", mats["pages"])
    p.boite(-0.070, -0.009, 0.006, 0.072, 0.009, 0.204)
    total += p.finir()
    return total


def chapeau(mats) -> int:
    """Le porkpie. Deux volumes : un bord large et plat, une calotte basse.
    C'est la silhouette la plus reconnaissable de la serie, et elle tient
    en douze faces."""
    total = 0
    m = Maillage("Chapeau", mats["feutre"])
    m.boite(-0.145, -0.155, 0.0, 0.145, 0.155, 0.016)      # bord
    m.boite(-0.105, -0.112, 0.014, 0.105, 0.112, 0.088)    # calotte
    total += m.finir()

    r = Maillage("Ruban", mats["feutre_sombre"])
    r.boite(-0.108, -0.115, 0.016, 0.108, 0.115, 0.034)
    total += r.finir()
    return total


OBJETS = {
    "arme": (arme, ["metal", "metal_sombre"]),
    "meth": (meth, ["cristal", "cristal_clair"]),
    "livre": (livre, ["couverture", "pages"]),
    "chapeau": (chapeau, ["feutre", "feutre_sombre"]),
}


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

    noms = list(OBJETS) if a.nom == "tous" else [a.nom]
    for nom in noms:
        if nom not in OBJETS:
            raise SystemExit("objet inconnu : %s" % nom)
        batir, besoins = OBJETS[nom]

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
        print("objet %-9s %3d faces  -> %s" % (nom, faces, fichier.name))

    print("sortie     %s" % sortie)


if __name__ == "__main__":
    main()
