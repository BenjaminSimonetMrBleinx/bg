#!/usr/bin/env python3
"""Genere un personnage low-poly segmente.

    blender -b -P outils/gen_personnage.py -- --nom walter

Produit game/assets/personnages/<nom>.glb : une hierarchie de segments
rigides, SANS squelette ni animation.

Pourquoi pas de squelette. Les membres rigides articules sont le look PS1/PS2,
pas un pis-aller — les personnages de l'epoque etaient souvent segmentes.
Surtout, animer en GDScript plutot qu'en clips cuits donne trois choses :
la cadence de marche se cale d'elle-meme sur la vitesse reelle sans melange
d'animations, tout devient reglable au curseur, et Guillaume peut remplacer
les maillages sans toucher a l'animation.

La hierarchie exportee, avec le pivot de chaque segment a son articulation :

    Racine (aux pieds)
      Bassin
        Torse
          Tete
          BrasG / BrasD
            AvantBrasG / AvantBrasD
              MainG / MainD
        CuisseG / CuisseD
          TibiaG / TibiaD
            PiedG / PiedD
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import bmesh

# Proportions, en metres. Walter fait 1,78 m.
HAUTEUR = 1.78
Y_TETE = 1.52          # base du cou
Y_EPAULE = 1.44
Y_COUDE = 1.14
Y_POIGNET = 0.88
Y_HANCHE = 0.96
Y_GENOU = 0.50
Y_CHEVILLE = 0.10

LARGEUR_TORSE = 0.40
PROFONDEUR_TORSE = 0.23
ECART_EPAULE = 0.21
ECART_HANCHE = 0.11

# Un personnage, c'est une taille et un jeu de textures. Le maillage, lui, ne
# change pas : c'est ce qui permet a joueur.gd d'animer n'importe lequel
# d'entre eux sans savoir de qui il s'agit.
# UN PERSONNAGE LIVRE NE FIGURE PLUS ICI.
#
# « jesse » y etait encore alors que Guillaume avait livre son modele. Un
# `.\bg.ps1 generer` — lance pour une tout autre raison, repasser le monde en
# journee — a donc silencieusement remplace un modele de 6,6 Mo par le corps
# generique de 68 Ko. Rien ne l'a signale : le fichier de sortie porte le meme
# nom, le jeu charge, et le personnage est simplement redevenu laid.
#
# La regle : des qu'un modele est livre et integre, on retire son nom de cette
# table. Le corps generique reste pour ceux que personne n'a encore sculptes.
#
# Deja livres, donc absents d'ici : walt, jesse, tuco.
PERSONNAGES = {
    "walter": {"taille": 1.00},
    "skyler": {"taille": 0.97},
    # Les passants varient de taille : une rue ou tout le monde mesure
    # pareil se lit comme une rangee de copies, meme avec des visages
    # differents.
    "passant_a": {"taille": 1.04},
    "passant_b": {"taille": 0.93},
    "passant_c": {"taille": 0.99},
}


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Generateur de personnage")
    ap.add_argument("--nom", default="walter")
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default="game/assets/personnages")
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


def segment(nom: str, mat, taille, decalage, parent=None, position=(0, 0, 0),
            visage: bool = False):
    """Boite dont l'origine est a l'articulation.

    taille    : (largeur X, profondeur Y, longueur Z)
    decalage  : position du CENTRE de la boite par rapport a l'origine.
                Pour un membre qui pend, c'est (0, 0, -longueur/2).
    position  : position de l'articulation dans le repere du parent.
    visage    : mappe la face avant sur la moitie gauche de l'atlas de tete,
                et les cinq autres sur la moitie droite.
    """
    mesh = bpy.data.meshes.new(nom)
    obj = bpy.data.objects.new(nom, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)

    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    sx, sy, sz = (t / 2.0 for t in taille)
    cx, cy, cz = decalage
    x0, x1 = cx - sx, cx + sx
    y0, y1 = cy - sy, cy + sy
    z0, z1 = cz - sz, cz + sz

    # (points, largeur, hauteur, est_la_face_avant)
    #
    # L'avant du personnage est +Y dans Blender. Attention au sens de la
    # conversion glTF : (x, y, z) part sur (x, z, -y), donc Blender +Y donne
    # bien Godot -Z. Une premiere version visait -Y et Walter avait son
    # visage derriere la tete, pieds tournes vers l'arriere.
    faces = [
        ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], taille[0], taille[2], False),
        ([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], taille[0], taille[2], True),
        ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], taille[1], taille[2], False),
        ([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], taille[1], taille[2], False),
        ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], taille[0], taille[1], False),
        ([(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)], taille[0], taille[1], False),
    ]
    for pts, _lu, _lv, avant in faces:
        verts = [bm.verts.new(p) for p in pts]
        f = bm.faces.new(verts)
        if visage:
            u0, u1 = (0.0, 0.5) if avant else (0.5, 1.0)
        else:
            u0, u1 = 0.0, 1.0
        for boucle, coord in zip(f.loops, [(u0, 0), (u1, 0), (u1, 1), (u0, 1)]):
            boucle[uv].uv = coord

    bm.normal_update()
    bm.to_mesh(mesh)
    faces_n = len(bm.faces)
    bm.free()

    obj.location = position
    if parent is not None:
        obj.parent = parent
    return obj, faces_n


def construire(mats: dict) -> tuple:
    total = 0

    racine = bpy.data.objects.new("Racine", None)     # repere au sol
    bpy.context.collection.objects.link(racine)

    bassin, n = segment("Bassin", mats["pantalon"],
                        (0.34, 0.21, 0.16), (0, 0, 0.02),
                        racine, (0, 0, Y_HANCHE))
    total += n

    torse, n = segment("Torse", mats["chemise"],
                       (LARGEUR_TORSE, PROFONDEUR_TORSE, Y_TETE - Y_HANCHE),
                       (0, 0, (Y_TETE - Y_HANCHE) / 2),
                       bassin, (0, 0, 0.06))
    total += n

    _, n = segment("Tete", mats["tete"],
                   (0.20, 0.21, 0.24), (0, 0, 0.13),
                   torse, (0, 0, Y_TETE - Y_HANCHE - 0.06), visage=True)
    total += n

    for cote, signe in (("G", -1), ("D", 1)):
        bras, n = segment(f"Bras{cote}", mats["chemise"],
                          (0.11, 0.12, Y_EPAULE - Y_COUDE),
                          (0, 0, -(Y_EPAULE - Y_COUDE) / 2),
                          torse, (signe * ECART_EPAULE, 0,
                                  Y_EPAULE - Y_HANCHE - 0.06))
        total += n
        avant, n = segment(f"AvantBras{cote}", mats["peau"],
                           (0.095, 0.10, Y_COUDE - Y_POIGNET),
                           (0, 0, -(Y_COUDE - Y_POIGNET) / 2),
                           bras, (0, 0, -(Y_EPAULE - Y_COUDE)))
        total += n
        _, n = segment(f"Main{cote}", mats["peau"],
                       (0.085, 0.055, 0.11), (0, 0, -0.055),
                       avant, (0, 0, -(Y_COUDE - Y_POIGNET)))
        total += n

        cuisse, n = segment(f"Cuisse{cote}", mats["pantalon"],
                            (0.145, 0.15, Y_HANCHE - Y_GENOU),
                            (0, 0, -(Y_HANCHE - Y_GENOU) / 2),
                            bassin, (signe * ECART_HANCHE, 0, -0.04))
        total += n
        tibia, n = segment(f"Tibia{cote}", mats["pantalon"],
                           (0.125, 0.13, Y_GENOU - Y_CHEVILLE),
                           (0, 0, -(Y_GENOU - Y_CHEVILLE) / 2),
                           cuisse, (0, 0, -(Y_HANCHE - Y_GENOU)))
        total += n
        # Le pied deborde vers l'avant, soit +Y dans Blender.
        _, n = segment(f"Pied{cote}", mats["chaussure"],
                       (0.115, 0.27, 0.10), (0, 0.06, -0.05),
                       tibia, (0, 0, -(Y_GENOU - Y_CHEVILLE)))
        total += n

    return racine, total


def main() -> None:
    a = arguments()
    racine_disque = Path.cwd()
    textures = Path(a.textures)
    if not textures.is_absolute():
        textures = racine_disque / textures
    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine_disque / sortie
    sortie.mkdir(parents=True, exist_ok=True)

    qui = list(PERSONNAGES) if a.nom == "tous" else [a.nom]
    for nom in qui:
        if nom not in PERSONNAGES:
            raise SystemExit("personnage inconnu : %s" % nom)
        spec = PERSONNAGES[nom]

        bpy.ops.wm.read_factory_settings(use_empty=True)

        # Les cles sont generiques, les fichiers sont propres au personnage :
        # construire() n'a donc pas a savoir de qui il fabrique le corps.
        mats = {
            "tete": materiau(f"tete_{nom}", textures),
            "peau": materiau(f"peau_{nom}", textures),
            "chemise": materiau(f"haut_{nom}", textures),
            "pantalon": materiau(f"bas_{nom}", textures),
            "chaussure": materiau("chaussure", textures),
        }

        racine, faces = construire(mats)
        racine.scale = (spec["taille"],) * 3

        # Le personnage regarde vers +Y dans Blender, que l'exportateur envoie
        # sur -Z : la convention Godot, et celle du reste du projet.
        fichier = sortie / f"{nom}.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(fichier),
            export_format="GLB",
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
        )
        print("personnage %-8s %3d faces  %.2f m  -> %s"
              % (nom, faces, HAUTEUR * spec["taille"], fichier.name))


if __name__ == "__main__":
    main()
