#!/usr/bin/env python3
"""Convertit un modele livre (.obj, .fbx, .dae, .stl, .glb) en .glb du projet.

    blender -b -P outils/importer_modele.py -- --fichier "assets/modeles/walt.obj" \\
            --hauteur 1.78 --sortie game/assets/personnages/walt_sculpte.glb

Ce que fait la conversion, et pourquoi chaque etape est necessaire :

  - MISE A L'ECHELLE. Un modele arrive presque toujours a une taille
    arbitraire — celui-ci mesurait 1,0 unite de haut. Dans le jeu, un
    personnage fait 1,78 m et une porte 2,05 : un modele a la mauvaise
    echelle traverse les murs ou disparait sous le trottoir.

  - PIEDS A L'ORIGINE. Nos personnages sont poses par leur point le plus
    bas. Un modele centre sur son milieu s'enfonce de la moitie de sa taille
    dans le sol, et on croit a un probleme de collision.

  - ORIENTATION. L'avant d'un noeud Godot est -Z. Un modele qui regarde
    ailleurs marche en crabe, et le defaut est difficile a diagnostiquer une
    fois qu'il est anime.

Ce que la conversion ne peut PAS faire :

  - inventer des coordonnees de texture. Sans UV, le modele restera d'une
    seule couleur, quoi qu'on lui applique.
  - le decouper en segments animables. C'est un travail a part.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Import d un modele livre")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--hauteur", type=float, default=1.78,
                    help="hauteur voulue en metres, 0 pour ne pas redimensionner")
    ap.add_argument("--lacet", type=float, default=0.0,
                    help="rotation autour de la verticale, en degres")
    ap.add_argument("--couleur", default="",
                    help="texture a appliquer, prise dans game/assets/textures")
    return ap.parse_args(argv)


def charger(chemin: Path) -> None:
    suffixe = chemin.suffix.lower()
    if suffixe == ".obj":
        bpy.ops.wm.obj_import(filepath=str(chemin))
    elif suffixe == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(chemin))
    elif suffixe == ".dae":
        bpy.ops.wm.collada_import(filepath=str(chemin))
    elif suffixe == ".stl":
        bpy.ops.wm.stl_import(filepath=str(chemin))
    elif suffixe in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(chemin))
    else:
        raise SystemExit("format non gere : %s" % suffixe)


def boite(objets) -> tuple:
    """Boite englobante en coordonnees monde."""
    mini = [1e9, 1e9, 1e9]
    maxi = [-1e9, -1e9, -1e9]
    for o in objets:
        for coin in o.bound_box:
            p = o.matrix_world @ bpy.mathutils.Vector(coin) if False else \
                o.matrix_world @ __import__("mathutils").Vector(coin)
            for i in range(3):
                mini[i] = min(mini[i], p[i])
                maxi[i] = max(maxi[i], p[i])
    return mini, maxi


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    fichier = Path(a.fichier)
    if not fichier.is_absolute():
        fichier = racine / fichier
    if not fichier.exists():
        raise SystemExit("introuvable : %s" % fichier)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    charger(fichier)

    maillages = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not maillages:
        raise SystemExit("aucun maillage dans %s" % fichier.name)

    faces = sum(len(o.data.polygons) for o in maillages)
    uv = any(len(o.data.uv_layers) > 0 for o in maillages)

    mini, maxi = boite(maillages)
    taille = [maxi[i] - mini[i] for i in range(3)]
    print("")
    print("modele    %s" % fichier.name)
    print("pieces    %d" % len(maillages))
    print("faces     %d" % faces)
    print("UV        %s" % ("oui" if uv else "NON — il restera d une seule couleur"))
    print("taille    %.3f x %.3f x %.3f (X, Y, Z)" % tuple(taille))

    # Blender est en Z-up : la hauteur est Z. Un modele exporte depuis un
    # logiciel Y-up arrive couche, ce que la taille revele tout de suite.
    couche = taille[1] > taille[2] * 1.4
    if couche:
        print("          l objet est plus long en Y qu en Z : il arrive couche,")
        print("          on le redresse d un quart de tour.")

    for o in maillages:
        o.select_set(True)
    bpy.context.view_layer.objects.active = maillages[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = Path(a.sortie).stem

    if couche:
        obj.rotation_euler[0] = math.pi / 2
        bpy.ops.object.transform_apply(rotation=True)

    if a.lacet:
        obj.rotation_euler[2] = math.radians(a.lacet)
        bpy.ops.object.transform_apply(rotation=True)

    mini, maxi = boite([obj])
    hauteur = maxi[2] - mini[2]
    if a.hauteur > 0 and hauteur > 1e-6:
        facteur = a.hauteur / hauteur
        obj.scale = (facteur,) * 3
        bpy.ops.object.transform_apply(scale=True)
        print("echelle   x%.4f pour atteindre %.2f m" % (facteur, a.hauteur))

    # Pieds a l origine, centre en X et Z : c est la convention de tous nos
    # personnages, et ce qui permet de les poser sans reglage.
    mini, maxi = boite([obj])
    obj.location = (
        -(mini[0] + maxi[0]) / 2.0,
        -(mini[1] + maxi[1]) / 2.0,
        -mini[2],
    )
    bpy.ops.object.transform_apply(location=True)

    if a.couleur:
        png = racine / "game/assets/textures" / f"{a.couleur}.png"
        mat = bpy.data.materials.new(a.couleur)
        mat.use_nodes = True
        principal = mat.node_tree.nodes["Principled BSDF"]
        principal.inputs["Roughness"].default_value = 0.95
        principal.inputs["Metallic"].default_value = 0.0
        if png.exists() and uv:
            img = bpy.data.images.load(str(png), check_existing=True)
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = img
            tex.interpolation = "Linear"
            mat.node_tree.links.new(principal.inputs["Base Color"], tex.outputs["Color"])
        elif png.exists():
            # Sans UV, une texture ne s applique nulle part : on prend sa
            # teinte moyenne plutot que de livrer un modele blanc.
            img = bpy.data.images.load(str(png), check_existing=True)
            px = list(img.pixels)
            n = max(1, len(px) // 4)
            moy = [sum(px[i::4]) / n for i in range(3)]
            principal.inputs["Base Color"].default_value = (*moy, 1.0)
            print("couleur   teinte moyenne de %s.png, faute d UV" % a.couleur)
        obj.data.materials.clear()
        obj.data.materials.append(mat)

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(sortie),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    print("sortie    %s" % sortie)


if __name__ == "__main__":
    main()
