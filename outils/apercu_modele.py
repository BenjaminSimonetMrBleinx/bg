#!/usr/bin/env python3
"""Rend une image d'un modele, a une image d'animation donnee.

    blender -b -P outils/apercu_modele.py -- \\
        --fichier game/assets/personnages/figurant_casual_male_g.glb \\
        --clip Marche --image 5

POURQUOI CET OUTIL EXISTE. Juger un personnage dans le jeu suppose de le
trouver : les passants sont recycles autour du joueur, ils marchent, et trois
captures d'affilee peuvent n'en montrer aucun. Pour repondre a « est-ce que ce
corps tient debout », il faut le regarder SEUL, dans une pose CHOISIE.

C'est le pendant de bg.ps1 capture, du cote des modeles : la meme idee — une
image plutot qu'une conviction — appliquee a un fichier au lieu d'une scene.
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
    ap = argparse.ArgumentParser(description="Apercu d'un modele")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--clip", default="")
    ap.add_argument("--image", type=int, default=1)
    ap.add_argument("--sortie", default=".tmp/apercu.png")
    ap.add_argument("--cap", type=float, default=35.0,
                    help="angle de vue en degres, 0 = de face")
    return ap.parse_args(argv)


def encadrer(objets: list) -> tuple:
    """La boite qui contient tout, en coordonnees du monde."""
    bas = Vector((1e9, 1e9, 1e9))
    haut = Vector((-1e9, -1e9, -1e9))
    for o in objets:
        if o.type != "MESH":
            continue
        for coin in o.bound_box:
            p = o.matrix_world @ Vector(coin)
            for i in range(3):
                bas[i] = min(bas[i], p[i])
                haut[i] = max(haut[i], p[i])
    return bas, haut


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    fichier = racine / a.fichier
    sortie = racine / a.sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(fichier))
    objets = list(bpy.data.objects)

    arm = next((o for o in objets if o.type == "ARMATURE"), None)
    if arm is not None and a.clip:
        action = next((x for x in bpy.data.actions
                       if x.name == a.clip or x.name.startswith(a.clip + ".")),
                      None)
        if action is None:
            print("clip absent : %s  (presents : %s)"
                  % (a.clip, ", ".join(x.name for x in bpy.data.actions)))
        else:
            if arm.animation_data is None:
                arm.animation_data_create()
            arm.animation_data.action = action
            bpy.context.scene.frame_set(a.image)

    bas, haut = encadrer(objets)
    centre = (bas + haut) * 0.5
    taille = max(haut.z - bas.z, 0.5)

    # La camera recule d'assez pour tout prendre, quel que soit le modele : on
    # ne veut pas avoir a la regler a la main pour chaque personnage.
    angle = math.radians(a.cap)
    recul = taille * 2.1
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = centre + Vector((math.sin(angle) * recul,
                                    -math.cos(angle) * recul, taille * 0.18))
    direction = centre - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    # Deux lumieres : une de face pour lire les volumes, une de dos pour
    # detacher la silhouette du fond. Sans la seconde, un bras colle au torse
    # ne se distingue pas d'un bras absent.
    for pos, force in (((2.5, -3.0, 3.0), 900.0), ((-3.0, 2.5, 2.0), 400.0)):
        lampe = bpy.data.lights.new("L", type="POINT")
        lampe.energy = force
        obj = bpy.data.objects.new("L", lampe)
        obj.location = centre + Vector(pos)
        bpy.context.collection.objects.link(obj)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 640
    scene.render.filepath = str(sortie)
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Monde")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = \
        (0.16, 0.18, 0.22, 1.0)
    bpy.ops.render.render(write_still=True)
    print("apercu   %-42s %s image %d  -> %s"
          % (fichier.name, a.clip or "(repos)", a.image, sortie))


if __name__ == "__main__":
    main()
