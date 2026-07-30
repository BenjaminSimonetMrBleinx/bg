#!/usr/bin/env python3
"""Genere le mobilier urbain et le decor des jardins.

    blender -b -P outils/gen_decor.py -- --nom tous

Produit un .glb par element dans game/assets/decor/. Ces objets ne sont PAS
dans le .glb de la ville : ils sont instancies au lancement d'apres un fichier
de placement, comme les lampadaires. Une ville de trois cents poubelles cuites
dans le maillage pese trois cents fois le prix d'une seule.

Convention : chaque objet est construit POSE AU SOL, centre sur l'origine,
oriente sa face avant vers -Y dans Blender (donc vers +Z une fois dans Godot).
Le placement n'a alors qu'a fournir une position et un angle.

Budget : quelques dizaines de faces chacun. Ce sont des silhouettes vues de
loin dans le brouillard, jamais des maillages de heros.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de decor")
    ap.add_argument("--nom", default="tous")
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default="game/assets/decor")
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    arbre = mat.node_tree
    principal = arbre.nodes["Principled BSDF"]
    principal.inputs["Roughness"].default_value = 0.88
    principal.inputs["Metallic"].default_value = 0.0

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
    img.alpha_mode = "NONE"
    tex = arbre.nodes.new("ShaderNodeTexImage")
    tex.image = img
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

    def prisme(self, cx, cy, z0, z1, rayon_bas, rayon_haut, cotes=8,
               tuile=1.0) -> None:
        """Volume a base reguliere. Huit cotes suffisent a lire un cylindre a
        cette distance, et coutent trois fois moins qu'un cercle lisse."""
        bas, haut = [], []
        for k in range(cotes):
            a = 2.0 * math.pi * k / cotes
            bas.append((cx + math.cos(a) * rayon_bas, cy + math.sin(a) * rayon_bas, z0))
            haut.append((cx + math.cos(a) * rayon_haut, cy + math.sin(a) * rayon_haut, z1))
        for k in range(cotes):
            j = (k + 1) % cotes
            u0, u1 = k / cotes * tuile, (k + 1) / cotes * tuile
            self.face([bas[k], bas[j], haut[j], haut[k]],
                      [(u0, 0), (u1, 0), (u1, (z1 - z0) / tuile), (u0, (z1 - z0) / tuile)])
        self.face(haut, [(0.5 + 0.5 * math.cos(2 * math.pi * k / cotes),
                          0.5 + 0.5 * math.sin(2 * math.pi * k / cotes))
                         for k in range(cotes)])

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


# ------------------------------------------------------------------ les objets


def poubelle(mats) -> int:
    m = Maillage("Poubelle", mats["plastique"])
    m.prisme(0, 0, 0.0, 0.86, 0.28, 0.31, 8, 0.9)
    total = m.finir()
    c = Maillage("Couvercle", mats["metal_sombre"])
    c.prisme(0, 0, 0.86, 0.93, 0.33, 0.30, 8, 0.9)
    return total + c.finir()


def benne(mats) -> int:
    """Benne a ordures. Le couvercle incline est ce qui la distingue d'une
    caisse : sans lui, c'est un cube."""
    m = Maillage("Benne", mats["rouille"])
    m.boite(-0.95, -0.62, 0.10, 0.95, 0.62, 1.05, 1.2)
    total = m.finir()
    c = Maillage("Couvercle", mats["metal_sombre"])
    c.face([(-0.98, -0.66, 1.05), (0.98, -0.66, 1.05),
            (0.98, 0.66, 1.22), (-0.98, 0.66, 1.22)],
           [(0, 0), (1.6, 0), (1.6, 1.1), (0, 1.1)])
    total += c.finir()
    p = Maillage("Pieds", mats["metal_sombre"])
    for sx in (-0.78, 0.78):
        for sy in (-0.48, 0.48):
            p.boite(sx - 0.06, sy - 0.06, 0.0, sx + 0.06, sy + 0.06, 0.12)
    return total + p.finir()


def boite_lettres(mats) -> int:
    """Boite aux lettres sur pied, modele americain : un tube couche sur un
    poteau. Petit, mais c'est ce qui fait lire une maison comme habitee."""
    p = Maillage("Poteau", mats["bois_banc"])
    p.boite(-0.05, -0.05, 0.0, 0.05, 0.05, 1.02)
    total = p.finir()
    b = Maillage("Boite", mats["metal"])
    b.boite(-0.14, -0.24, 1.02, 0.14, 0.24, 1.30, 0.5)
    return total + b.finir()


def banc(mats) -> int:
    a = Maillage("Assise", mats["bois_banc"])
    for k in range(3):
        y = -0.20 + k * 0.19
        a.boite(-0.85, y - 0.07, 0.42, 0.85, y + 0.07, 0.48, 0.6)
    for k in range(3):                                    # dossier
        z = 0.62 + k * 0.15
        a.boite(-0.85, 0.20, z, 0.85, 0.27, z + 0.10, 0.6)
    total = a.finir()
    p = Maillage("Pietement", mats["metal_sombre"])
    for sx in (-0.70, 0.70):
        p.boite(sx - 0.05, -0.28, 0.0, sx + 0.05, 0.30, 0.42)
        p.boite(sx - 0.04, 0.22, 0.48, sx + 0.04, 0.30, 0.90)
    return total + p.finir()


def panneau(mats) -> int:
    p = Maillage("Mat", mats["metal_sombre"])
    p.prisme(0, 0, 0.0, 2.25, 0.045, 0.045, 6, 1.0)
    total = p.finir()
    s = Maillage("Plaque", mats["panneau_stop"])
    for sens in (-1.0, 1.0):
        s.face([(-0.33, sens * 0.03, 1.72), (0.33, sens * 0.03, 1.72),
                (0.33, sens * 0.03, 2.38), (-0.33, sens * 0.03, 2.38)][::int(sens)],
               [(0, 0), (1, 0), (1, 1), (0, 1)])
    return total + s.finir()


def panneau_direction(texture: str):
    """Fabrique un panneau de direction portant CETTE texture.

    Le meme modele sert pour toutes les destinations — DESERT, ALBUQUERQUE,
    QG TUCO — parce qu'il n'y a rien qui les distingue sinon la plaque. Le
    texte, lui, est cuit dans la texture par gen_textures.panneau_ecrit.
    """
    def batir(mats) -> int:
        return _panneau_direction(mats, texture)
    return batir


def _panneau_direction(mats, texture: str) -> int:
    """Le panneau de direction au bord de la ville.

    Plus haut et plus large que le stop : c'est une destination, on doit la
    lire en roulant. Deux mats plutot qu'un, comme les vrais panneaux de cette
    taille — un seul pied sous une plaque d'un metre soixante se lit comme une
    pancarte plantee a la va-vite."""
    p = Maillage("Mat", mats["metal_sombre"])
    for sx in (-0.62, 0.62):
        p.prisme(sx, 0, 0.0, 2.55, 0.05, 0.05, 6, 1.0)
    total = p.finir()

    s = Maillage("Plaque", mats[texture])
    # La face arriere n'est PAS la face avant retournee.
    #
    # Le panneau stop s'en accommodait — un aplat rouge barre de blanc est
    # symetrique. Celui-ci porte du texte : inverser l'ordre des sommets sans
    # inverser celui des UV ecrivait TRESED de l'autre cote. On decrit donc les
    # deux faces separement, chacune avec ses coordonnees.
    y = 0.035
    s.face([(-0.86, -y, 1.90), (0.86, -y, 1.90),
            (0.86, -y, 2.62), (-0.86, -y, 2.62)],
           [(0, 0), (1, 0), (1, 1), (0, 1)])
    s.face([(0.86, y, 1.90), (-0.86, y, 1.90),
            (-0.86, y, 2.62), (0.86, y, 2.62)],
           [(0, 0), (1, 0), (1, 1), (0, 1)])
    return total + s.finir()


def fleche_sol(mats) -> int:
    """La fleche peinte sur la chaussee, pointant vers -Y.

    Un simple quadrilatere pose a deux centimetres du sol. Pas zero : deux
    surfaces exactement coplanaires se disputent le tampon de profondeur et la
    fleche clignote quand la camera bouge."""
    m = Maillage("Fleche", mats["fleche_orange"])
    z = 0.02
    # La pointe est en HAUT de la texture, donc du cote v = 1. On la place
    # explicitement vers -Y de Blender, qui devient -Z dans Godot : la fleche
    # pointe alors dans le sens ou regarde un objet non tourne, comme tout le
    # reste du projet. Sans ce reperage ecrit, l'orientation se decide par
    # essais successifs et se reperd au premier remaniement.
    m.face([(-1.6, 2.4, z), (1.6, 2.4, z), (1.6, -2.4, z), (-1.6, -2.4, z)],
           [(0, 1), (1, 1), (1, 0), (0, 0)])
    return m.finir()


def borne(mats) -> int:
    """Bouche d'incendie. Deux volumes et deux bras : lisible a vingt metres,
    ce qui est tout ce qu'on lui demande."""
    m = Maillage("Borne", mats["rouge_borne"])
    m.prisme(0, 0, 0.0, 0.14, 0.20, 0.18, 8, 0.5)
    m.prisme(0, 0, 0.14, 0.62, 0.15, 0.13, 8, 0.5)
    m.prisme(0, 0, 0.62, 0.74, 0.17, 0.09, 8, 0.5)
    for sx in (-1.0, 1.0):
        m.boite(sx * 0.13, -0.06, 0.34, sx * 0.22, 0.06, 0.46)
    return m.finir()


def saguaro(mats) -> int:
    """Le cactus d'Albuquerque. Un tronc et deux bras coudes suffisent : c'est
    une silhouette, et elle est immediatement reconnaissable."""
    m = Maillage("Cactus", mats["cactus"])
    m.prisme(0, 0, 0.0, 2.60, 0.20, 0.16, 8, 1.4)
    # bras : montant lateral puis coude vertical
    m.prisme(-0.38, 0, 0.95, 1.15, 0.11, 0.10, 6, 1.0)
    m.boite(-0.44, -0.10, 0.95, 0.0, 0.10, 1.11)
    m.prisme(0.42, 0, 1.35, 1.95, 0.10, 0.09, 6, 1.0)
    m.boite(0.0, -0.09, 1.35, 0.48, 0.09, 1.50)
    return m.finir()


def arbre(mats) -> int:
    """Un arbre de parc. Tronc et deux etages de feuillage.

    PAS DE PLANS CROISES, PAS D'ALPHA. La facon habituelle de faire un arbre a
    ce budget est deux quadrilateres croises portant une texture de feuillage
    decoupee — mais la decoupe demande de la transparence, et la transparence
    demande un tri par profondeur que le rendu du projet n'a pas. Deux prismes
    superposes coutent le meme prix, ne trient rien, et donnent une silhouette
    qui tient de dos comme de face.

    Trente-six faces. C'est le double d'un cactus, pour un objet qui sera pose
    par dizaines dans un parc : c'est le budget qu'on peut mettre.
    """
    m = Maillage("Tronc", mats["bois_banc"])
    m.prisme(0, 0, 0.0, 2.05, 0.16, 0.13, 6, 1.2)
    total = m.finir()
    f = Maillage("Feuillage", mats["herbe"])
    # Deux etages plutot qu'un : une seule masse fait un champignon, et la
    # cassure entre les deux est ce qui se lit comme des branches a vingt
    # metres.
    f.prisme(0, 0, 1.70, 3.15, 1.35, 1.05, 8, 2.4)
    f.prisme(0, 0, 3.05, 4.10, 0.95, 0.20, 8, 2.4)
    return total + f.finir()


def climatiseur(mats) -> int:
    """Bloc de climatisation. Sur un toit-terrasse plat, c'est la seule chose
    qui empeche la maison de ressembler a une boite."""
    m = Maillage("Climatiseur", mats["metal"])
    m.boite(-0.42, -0.42, 0.0, 0.42, 0.42, 0.62, 0.7)
    total = m.finir()
    g = Maillage("Grille", mats["metal_sombre"])
    for k in range(4):
        z = 0.14 + k * 0.11
        g.boite(-0.44, -0.44, z, 0.44, -0.42, z + 0.06)
    return total + g.finir()


OBJETS = {
    "poubelle": (poubelle, ["plastique", "metal_sombre"]),
    "benne": (benne, ["rouille", "metal_sombre"]),
    "boite_lettres": (boite_lettres, ["bois_banc", "metal"]),
    "banc": (banc, ["bois_banc", "metal_sombre"]),
    "panneau": (panneau, ["metal_sombre", "panneau_stop"]),
    "borne": (borne, ["rouge_borne"]),
    "cactus": (saguaro, ["cactus"]),
    "arbre": (arbre, ["bois_banc", "herbe"]),
    "climatiseur": (climatiseur, ["metal", "metal_sombre"]),
    "panneau_desert": (panneau_direction("panneau_desert"),
                       ["metal_sombre", "panneau_desert"]),
    "panneau_albuquerque": (panneau_direction("panneau_albuquerque"),
                            ["metal_sombre", "panneau_albuquerque"]),
    "panneau_tuco": (panneau_direction("panneau_tuco"),
                     ["metal_sombre", "panneau_tuco"]),
    "fleche_sol": (fleche_sol, ["fleche_orange"]),
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
    total = 0
    for nom in noms:
        if nom not in OBJETS:
            raise SystemExit("decor inconnu : %s" % nom)
        batir, besoins = OBJETS[nom]

        bpy.ops.wm.read_factory_settings(use_empty=True)
        mats = {m: materiau(m, textures) for m in besoins}
        faces = batir(mats)
        total += faces

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
        print("decor %-14s %3d faces  -> %s" % (nom, faces, fichier.name))

    print("total %d faces" % total)
    print("sortie     %s" % sortie)


if __name__ == "__main__":
    main()
