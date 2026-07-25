#!/usr/bin/env python3
"""Decoupe un personnage d'un seul bloc en segments animables.

    blender -b -P outils/segmenter_modele.py -- \\
        --fichier game/assets/personnages/walt_texture.glb \\
        --sortie game/assets/personnages/walt_anime.glb

Pourquoi ce decoupage
---------------------
L'animation du projet ne fait pas de deformation de peau : elle fait TOURNER
des segments rigides nommes, exactement comme les jeux PS1 et PS2. Un modele
sculpte d'une seule piece ne peut donc pas marcher — il glisserait, raide.

Le script attribue chaque face a un segment d'apres sa position dans le
corps, puis reconstruit la hierarchie que silhouette.gd attend :

    Racine
      Bassin
        Torse
          Tete
          BrasG / BrasD
            AvantBrasG / AvantBrasD
              MainG / MainD
        CuisseG / CuisseD
          TibiaG / TibiaD
            PiedG / PiedD

Le point delicat n'est pas la decoupe : c'est le PIVOT. L'origine de chaque
segment doit tomber sur son articulation, sinon la cuisse tourne autour du
genou et la jambe part en helice. On mesure donc chaque articulation sur la
geometrie reelle, au lieu de la supposer.

Ce que le decoupage ne fera jamais bien : les articulations sont franches.
A l'epaule et a la hanche, la matiere se separe visiblement quand l'angle est
grand. C'etait le cas sur PS1, ca l'est ici, et c'est le prix a payer pour
qu'un modele sculpte entre dans une animation ecrite pour des boites.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import bmesh


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Decoupage en segments animables")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--sortie", required=True)
    # Proportions du corps, en fraction de la hauteur totale. Ce sont celles
    # de gen_personnage.py, pour que les deux personnages bougent pareil.
    ap.add_argument("--epaule", type=float, default=0.809)
    ap.add_argument("--coude", type=float, default=0.640)
    ap.add_argument("--poignet", type=float, default=0.494)
    ap.add_argument("--cou", type=float, default=0.854)
    ap.add_argument("--hanche", type=float, default=0.539)
    ap.add_argument("--genou", type=float, default=0.281)
    ap.add_argument("--cheville", type=float, default=0.075)
    # Au-dela de cette fraction de la demi-largeur, on est dans un bras.
    ap.add_argument("--bras", type=float, default=0.55)
    return ap.parse_args(argv)


def charger(chemin: Path) -> None:
    s = chemin.suffix.lower()
    if s in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(chemin))
    elif s == ".obj":
        bpy.ops.wm.obj_import(filepath=str(chemin))
    elif s == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(chemin))
    else:
        raise SystemExit("format non gere : %s" % s)


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    fichier = Path(a.fichier)
    if not fichier.is_absolute():
        fichier = racine / fichier

    bpy.ops.wm.read_factory_settings(use_empty=True)
    charger(fichier)

    maillages = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not maillages:
        raise SystemExit("aucun maillage")
    for o in maillages:
        o.select_set(True)
    bpy.context.view_layer.objects.active = maillages[0]
    if len(maillages) > 1:
        bpy.ops.object.join()
    source = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    me = source.data
    materiaux = list(me.materials)
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    xmin, xmax = min(xs), max(xs)
    zmin, zmax = min(zs), max(zs)
    hauteur = zmax - zmin
    milieu = (xmin + xmax) / 2.0
    demi = max(1e-6, (xmax - xmin) / 2.0)

    def z(fraction: float) -> float:
        return zmin + fraction * hauteur

    def segment_de(centre) -> str:
        h = (centre[2] - zmin) / max(1e-6, hauteur)
        lat = (centre[0] - milieu) / demi
        cote = "D" if lat > 0 else "G"

        if h >= a.cou:
            return "Tete"
        # Tout ce qui est loin de l'axe appartient au bras, quelle que soit
        # la hauteur — sauf tout en bas, ou ce sont les pieds.
        #
        # Une premiere version exigeait aussi h > poignet - 0.06. La main
        # deborde de cette bande : sa partie basse tombait donc dans la
        # CUISSE et partait avec elle a chaque foulee. En jeu, des eclats de
        # peau flottaient autour des hanches, et rien ne le signalait.
        if abs(lat) > a.bras and h > 0.32:
            if h >= a.coude:
                return "Bras" + cote
            if h >= a.poignet:
                return "AvantBras" + cote
            return "Main" + cote
        if h >= a.hanche + 0.045:
            return "Torse"
        if h >= a.hanche - 0.045:
            return "Bassin"
        if h >= a.genou:
            return "Cuisse" + cote
        if h >= a.cheville:
            return "Tibia" + cote
        return "Pied" + cote

    # --- repartition des faces -------------------------------------------
    groupes: dict[str, list[int]] = {}
    for poly in me.polygons:
        groupes.setdefault(segment_de(poly.center), []).append(poly.index)

    # Articulation de chaque segment, mesuree sur la geometrie.
    #
    # En hauteur, c'est la proportion connue. En largeur, c'est le milieu du
    # segment lui-meme : supposer un ecart d'epaule fixe deplacerait le pivot
    # hors du bras sur un modele plus large ou plus etroit que le notre.
    def articulation(nom: str, indices: list[int]) -> tuple:
        sx = []
        for i in indices:
            for vi in me.polygons[i].vertices:
                sx.append(me.vertices[vi].co.x)
        mx = sum(sx) / len(sx) if sx else milieu

        if nom == "Tete":
            return (milieu, 0.0, z(a.cou))
        if nom.startswith("Bras"):
            return (mx, 0.0, z(a.epaule))
        if nom.startswith("AvantBras"):
            return (mx, 0.0, z(a.coude))
        if nom.startswith("Main"):
            return (mx, 0.0, z(a.poignet))
        if nom == "Torse":
            return (milieu, 0.0, z(a.hanche))
        if nom == "Bassin":
            return (milieu, 0.0, z(a.hanche))
        if nom.startswith("Cuisse"):
            return (mx, 0.0, z(a.hanche))
        if nom.startswith("Tibia"):
            return (mx, 0.0, z(a.genou))
        return (mx, 0.0, z(a.cheville))

    pivots = {nom: articulation(nom, idx) for nom, idx in groupes.items()}

    # --- un objet par segment --------------------------------------------
    objets: dict[str, bpy.types.Object] = {}
    for nom, indices in groupes.items():
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        garder = set(indices)
        bmesh.ops.delete(
            bm,
            geom=[f for f in bm.faces if f.index not in garder],
            context="FACES",
        )
        # Les sommets sont exprimes PAR RAPPORT AU PIVOT : c'est ce qui fait
        # que la rotation du noeud tourne autour de l'articulation.
        p = pivots[nom]
        for v in bm.verts:
            v.co.x -= p[0]
            v.co.y -= p[1]
            v.co.z -= p[2]

        maillage = bpy.data.meshes.new(nom)
        bm.to_mesh(maillage)
        bm.free()
        for m in materiaux:
            maillage.materials.append(m)

        obj = bpy.data.objects.new(nom, maillage)
        bpy.context.collection.objects.link(obj)
        objets[nom] = obj

    # --- la hierarchie ----------------------------------------------------
    racine_obj = bpy.data.objects.new("Racine", None)
    bpy.context.collection.objects.link(racine_obj)
    racine_obj.location = (0.0, 0.0, 0.0)

    liens = [
        ("Bassin", None), ("Torse", "Bassin"), ("Tete", "Torse"),
        ("BrasG", "Torse"), ("AvantBrasG", "BrasG"), ("MainG", "AvantBrasG"),
        ("BrasD", "Torse"), ("AvantBrasD", "BrasD"), ("MainD", "AvantBrasD"),
        ("CuisseG", "Bassin"), ("TibiaG", "CuisseG"), ("PiedG", "TibiaG"),
        ("CuisseD", "Bassin"), ("TibiaD", "CuisseD"), ("PiedD", "TibiaD"),
    ]
    manquants = []
    for nom, parent in liens:
        obj = objets.get(nom)
        if obj is None:
            manquants.append(nom)
            continue
        p = pivots[nom]
        if parent is None or parent not in pivots:
            obj.parent = racine_obj
            obj.location = p
        else:
            pp = pivots[parent]
            obj.parent = objets[parent]
            # Position RELATIVE au pivot du parent : sans ca, chaque segment
            # se retrouve decale de la position absolue de son parent, et le
            # personnage explose en morceaux disperses.
            obj.location = (p[0] - pp[0], p[1] - pp[1], p[2] - pp[2])

    print("")
    print("segments (faces) :")
    for nom, _ in liens:
        print("   %-12s %4d" % (nom, len(groupes.get(nom, []))))
    if manquants:
        print("   ABSENTS : %s" % ", ".join(manquants))
        print("   L animation les ignorera — le personnage bougera sans eux.")

    bpy.data.objects.remove(source, do_unlink=True)

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
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
