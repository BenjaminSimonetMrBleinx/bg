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
    ap.add_argument("--repos", action="store_true",
                    help="force le squelette a sa pose de repos")
    ap.add_argument("--cap", type=float, default=35.0,
                    help="angle de vue en degres, 0 = de face")
    return ap.parse_args(argv)


def encadrer(objets: list, arm) -> tuple:
    """La boite qui contient le personnage, en coordonnees du monde.

    ON MESURE SUR LES OS, PAS SUR LA BOITE DU MAILLAGE. C'est la regle la plus
    chere du projet et elle vient de mordre une fois de plus : la boite
    englobante d'un maillage decrit la geometrie AVANT deformation par
    l'armature. Sur un personnage anime elle est enorme et decentree, donc la
    camera cadrait un sujet minuscule dans un coin — et j'ai conclu deux fois
    « le corps est disloque » en regardant vingt pixels mal places.

    Sans armature, on retombe sur la boite du maillage : c'est le bon defaut
    pour une poubelle.
    """
    bas = Vector((1e9, 1e9, 1e9))
    haut = Vector((-1e9, -1e9, -1e9))
    points = []
    # ON MESURE LA GEOMETRIE REELLEMENT RENDUE, sommet par sommet, apres
    # evaluation du depsgraph — donc apres deformation par l'armature ET apres
    # l'echelle de l'objet.
    #
    # Les deux mesures plus simples mentent, et elles m'ont menti toutes les
    # deux la meme nuit :
    #   - la boite du maillage decrit la geometrie AVANT deformation ;
    #   - les os disent 1,64 m pendant que le maillage rendu en fait dix fois
    #     plus, parce que l'echelle vit sur l'objet et pas sur l'armature.
    # J'ai conclu deux fois « le corps est disloque » en regardant en fait un
    # bras cadre de trop pres.
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objets:
        if o.type != "MESH":
            continue
        evalue = o.evaluated_get(deps)
        maillage = evalue.to_mesh()
        for v in maillage.vertices:
            points.append(evalue.matrix_world @ v.co)
        evalue.to_mesh_clear()
    # ON CADRE SUR LES PERCENTILES, PAS SUR LES EXTREMES.
    #
    # Quelques sommets egares — un bout d'os, une pointe de vetement mal
    # ponderee — suffisent a gonfler la boite et, surtout, a en DECALER le
    # centre. La camera cadrait alors du vide, le personnage se retrouvait
    # minuscule dans un coin, et j'ai lu ca comme un corps disloque. Deux fois.
    #
    # Le cinquieme et le quatre-vingt-quinzieme centile decrivent ce qu'on
    # voit ; le reste est du bruit qu'on laisse deborder du cadre.
    if not points:
        return bas, haut
    for i in range(3):
        valeurs = sorted(p[i] for p in points)
        n = len(valeurs)
        bas[i] = valeurs[int(n * 0.05)]
        haut[i] = valeurs[min(n - 1, int(n * 0.95))]
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
    if arm is not None and a.repos:
        # Le repos est la SEULE pose qu'aucune animation ne peut abimer. Si le
        # corps est deja casse la, ce n'est pas l'animation qu'il faut chercher
        # mais la liaison entre le maillage et le squelette.
        arm.data.pose_position = "REST"
        bpy.context.view_layer.update()
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

    bas, haut = encadrer(objets, arm)
    centre = (bas + haut) * 0.5
    # On recule d'apres la PLUS GRANDE dimension, pas la hauteur : un
    # personnage couche a une hauteur ridicule, et la camera lui rentrait
    # dedans. Le chiffre imprime ci-dessous dit d'ailleurs tout de suite si le
    # corps est debout ou par terre — c'est la mesure qu'il fallait avant de
    # commenter une image.
    etendues = Vector((haut.x - bas.x, haut.y - bas.y, haut.z - bas.z))
    taille = max(etendues.x, etendues.y, etendues.z, 0.5)
    print("apercu   encombrement  %.2f x %.2f x %.2f m  (hauteur %.2f)"
          % (etendues.x, etendues.y, etendues.z, etendues.z))

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
