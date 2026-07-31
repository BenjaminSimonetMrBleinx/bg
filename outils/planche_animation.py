#!/usr/bin/env python3
"""Une planche de contact : plusieurs images d'un cycle, cote a cote.

    blender -b -P outils/planche_animation.py -- \\
        --fichier game/assets/personnages/jesse.glb --clip Repos --images 8

POURQUOI CET OUTIL EXISTE, ET POURQUOI IL ARRIVE SI TARD.

Je ne peux pas VOIR un mouvement. Une image fixe dit si un corps tient debout ;
elle ne dit rien du timing ni du poids, qui sont tout ce qui fait une
animation. C'est la raison de fond pour laquelle j'ai echoue sur les figurants,
et pourquoi j'y suis alle a l'aveugle pendant deux sessions.

La planche de contact est le pendant de `bg.ps1 capture` pour l'animation :
huit poses d'un meme cycle, alignees dans une seule image, se LISENT. On y voit
un pied qui glisse, un bras qui traverse le torse, une pose qui ne bouge pas
entre deux images, un cycle qui ne boucle pas.

C'est aussi ce que fait un animateur avec ses cles : il regarde ses poses
extremes cote a cote avant de s'occuper de l'entre-deux.

LA COMPOSITION SE FAIT DANS BLENDER. On rend chaque image dans un fichier, on
les relit, et on recopie leurs pixels dans une grande image. Ca evite d'ecrire
un decodeur PNG, et ca garde l'outil sans dependance — comme le reste du
projet.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Planche de contact d'un cycle")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--clip", required=True)
    ap.add_argument("--images", type=int, default=8)
    ap.add_argument("--colonnes", type=int, default=4)
    ap.add_argument("--largeur", type=int, default=260)
    ap.add_argument("--hauteur", type=int, default=380)
    ap.add_argument("--cap", type=float, default=28.0,
                    help="angle de vue en degres, 0 = de face")
    ap.add_argument("--sortie", default=".tmp/planche.png")
    return ap.parse_args(argv)


def encadrer(objets: list) -> tuple:
    """La boite de ce qui est REELLEMENT rendu, apres deformation.

    Meme raison qu'ailleurs : la boite d'un maillage decrit la geometrie avant
    l'armature, et les os ne disent rien de l'echelle de l'objet. On mesure
    donc les sommets evalues, et on cadre sur les centiles pour qu'un sommet
    egare ne decentre pas la planche entiere.
    """
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for o in objets:
        if o.type != "MESH":
            continue
        evalue = o.evaluated_get(deps)
        maillage = evalue.to_mesh()
        for v in maillage.vertices:
            points.append(evalue.matrix_world @ v.co)
        evalue.to_mesh_clear()
    if not points:
        return Vector((0, 0, 0)), Vector((1, 1, 2))
    bas, haut = Vector((0, 0, 0)), Vector((0, 0, 0))
    for i in range(3):
        valeurs = sorted(p[i] for p in points)
        bas[i] = valeurs[int(len(valeurs) * 0.02)]
        haut[i] = valeurs[min(len(valeurs) - 1, int(len(valeurs) * 0.98))]
    return bas, haut


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    fichier = racine / a.fichier
    sortie = racine / a.sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)
    travail = sortie.parent / "_planche"
    travail.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(fichier))
    objets = list(bpy.data.objects)
    arm = next((o for o in objets if o.type == "ARMATURE"), None)
    if arm is None:
        raise SystemExit("%s : aucune armature" % fichier.name)

    action = next((x for x in bpy.data.actions
                   if x.name == a.clip or x.name.startswith(a.clip + ".")), None)
    if action is None:
        raise SystemExit("clip absent : %s (presents : %s)"
                         % (a.clip, ", ".join(x.name for x in bpy.data.actions)))
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    debut, fin = int(action.frame_range[0]), int(action.frame_range[1])

    # LE CADRE EST FIXE POUR TOUTE LA PLANCHE, et c'est essentiel : recadrer a
    # chaque image ferait bouger le personnage dans le cadre au lieu de montrer
    # comment il bouge, lui. On cadre donc une fois, sur la premiere image, et
    # on garde.
    bpy.context.scene.frame_set(debut)
    bas, haut = encadrer(objets)
    centre = (bas + haut) * 0.5
    taille = max(haut.x - bas.x, haut.y - bas.y, haut.z - bas.z, 0.5)

    angle = math.radians(a.cap)
    recul = taille * 2.0
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = centre + Vector((math.sin(angle) * recul,
                                    -math.cos(angle) * recul, taille * 0.10))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    for pos, force in (((2.2, -3.0, 2.6), 700.0), ((-2.8, 2.2, 1.8), 300.0)):
        lampe = bpy.data.lights.new("L", type="POINT")
        lampe.energy = force
        obj = bpy.data.objects.new("L", lampe)
        obj.location = centre + Vector(pos)
        bpy.context.collection.objects.link(obj)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = a.largeur
    scene.render.resolution_y = a.hauteur
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Monde")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = \
        (0.20, 0.21, 0.24, 1.0)

    # Les images du cycle, reparties regulierement. On evite la derniere quand
    # elle repete la premiere : un cycle qui boucle les rend identiques, et une
    # colonne pour rien.
    total = max(1, fin - debut)
    numeros = [debut + int(round(k * total / a.images)) for k in range(a.images)]

    fichiers = []
    for k, img in enumerate(numeros):
        scene.frame_set(img)
        chemin = travail / ("i%02d.png" % k)
        scene.render.filepath = str(chemin)
        bpy.ops.render.render(write_still=True)
        fichiers.append(chemin)

    # --- la composition ---------------------------------------------------
    cols = min(a.colonnes, len(fichiers))
    lignes = int(math.ceil(len(fichiers) / cols))
    planche = bpy.data.images.new("planche", width=a.largeur * cols,
                                  height=a.hauteur * lignes)
    px = [0.0] * (planche.size[0] * planche.size[1] * 4)

    for k, chemin in enumerate(fichiers):
        src = bpy.data.images.load(str(chemin))
        spx = list(src.pixels)
        cx = (k % cols) * a.largeur
        # Blender range les lignes du BAS vers le haut : la premiere image doit
        # donc aller sur la ligne du HAUT, soit la derniere en memoire.
        cy = (lignes - 1 - k // cols) * a.hauteur
        for y in range(a.hauteur):
            d = ((cy + y) * planche.size[0] + cx) * 4
            o = (y * a.largeur) * 4
            px[d:d + a.largeur * 4] = spx[o:o + a.largeur * 4]
        bpy.data.images.remove(src)

    planche.pixels = px
    planche.filepath_raw = str(sortie)
    planche.file_format = "PNG"
    planche.save()

    print("")
    print("planche  %s / %s" % (fichier.name, a.clip))
    print("  images   %d sur %d (de %d a %d)" % (len(numeros), total, debut, fin))
    print("  grille   %d x %d" % (cols, lignes))
    print("  -> %s" % sortie)


if __name__ == "__main__":
    main()
