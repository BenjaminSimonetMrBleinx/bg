#!/usr/bin/env python3
"""Reporte les clips de Walter sur les figurants du pack. NE MARCHE PAS ENCORE.

ETAT AU 31/07/2026 : le report produit un corps DISLOQUE — membres en etoile,
tronc de travers. Verifie a l'image avec outils/apercu_modele.py, sur plusieurs
images du cycle, avec et sans conservation de l'echelle des os. Le pipeline
tourne de bout en bout et exporte des clips ; ce sont les poses qui sont
fausses.

Ce qui a ete elimine :
  - l'echelle : conserver celle de l'os cible au lieu d'imposer 1 ne change
    rien a l'image produite ;
  - l'ordre des os : ils sont deja traites parents d'abord, et le depsgraph est
    mis a jour apres chaque os.

Ce qui reste a examiner, dans cet ordre :
  1. la transformation de l'objet armature a l'import glTF (conversion Y-up),
     qui n'est peut-etre pas la meme sur les deux fichiers ;
  2. la pose de repos du Biped, qui est peut-etre deja une pose et non un
     T-pose neutre — auquel cas il faut reporter un ECART a la pose de repos,
     et non une orientation absolue ;
  3. la piste 2 du ticket #16 : fabriquer une marche pour ce rig comme on a
     fabrique le repos et l accroupi de Walter, sans rien reporter du tout.

Les passants restent des boites en attendant. Elles marchent, elles.


    blender -b -P outils/retarget_figurants.py -- --nom tous

Le pack de figurants ne contient AUCUNE marche : son unique clip de 200 images
est une attente debout, mesuree par outils/importer_figurants.py. Des passants
qui glissent debout dans la rue sont pires que des boites qui marchent, et
c'est ce qui bloquait le ticket #16.

POURQUOI CE N'EST PAS UNE COPIE DE COURBES
------------------------------------------

La tentation est de recopier les rotations locales de Walter sur les os de
meme nom. Ca ne peut pas marcher, et ce n'est pas une incertitude, c'est une
mesure faite a l'import : sur le rig de Walter une cuisse pointe vers le bas
(0.09, 0.06, -0.99) et une colonne vers le haut ; sur un Biped, TOUS les os
pointent dans la meme direction (0.87, -0.50, 0.00), quel que soit le membre.
Une rotation locale ne veut donc pas dire la meme chose de part et d'autre.

On passe par l'espace MONDE. Pour chaque image et chaque os, on lit
l'orientation ABSOLUE de l'os de Walter et on la pose telle quelle sur l'os du
figurant, en lui laissant sa propre translation — donc ses propres longueurs de
membres. Blender resout la rotation locale correspondante. Le repos de chaque
rig n'a plus aucune importance, et un pack livre avec n'importe quelle
convention passera par le meme chemin.

CE QU'ON NE REPORTE PAS : la position du bassin en X et Z. Elle contient
l'avancee du clip, et le jeu deplace deja le personnage lui-meme — la garder
ferait avancer le passant deux fois, une fois par la physique et une fois par
l'animation. On garde le BALANCEMENT vertical, mis a l'echelle de la taille du
figurant : un enfant d'1,32 m ne rebondit pas de la meme hauteur qu'un homme
d'1,80 m.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

# Les clips a reporter, et rien d'autre. Un figurant n'a pas besoin de savoir
# se coiffer ni de lire un livre : il marche, il court un peu, il attend.
CLIPS = ["Marche", "Repos", "Running"]

# Les os qu'on reporte. Ce sont ceux que importer_figurants.py a renommes a la
# convention de Walter ; tout ce qui n'est pas dans cette liste — les doigts,
# les bouts d'os — garde sa pose de repos.
OS = [
    "Hips", "Spine01", "Spine02", "neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
]

SOURCE = "game/assets/personnages/walt.glb"
DOSSIER = "game/assets/personnages"


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Report des clips sur les figurants")
    ap.add_argument("--nom", default="tous",
                    help="figurant_casual_male_g, ou 'tous'")
    ap.add_argument("--source", default=SOURCE)
    ap.add_argument("--dossier", default=DOSSIER)
    return ap.parse_args(argv)


def vider() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importer(chemin: Path) -> tuple:
    """Importe un .glb et rend (armature, objets importes)."""
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(chemin))
    nouveaux = [o for o in bpy.data.objects if o not in avant]
    arm = next((o for o in nouveaux if o.type == "ARMATURE"), None)
    if arm is None:
        raise SystemExit("%s : aucune armature" % chemin.name)
    return arm, nouveaux


def hauteur(arm) -> float:
    """La taille du personnage, mesuree sur les os et pas sur la boite du
    maillage : une boite englobante decrit la geometrie AVANT deformation par
    l'armature, ce qui a deja fait annoncer 2,70 m pour un modele d'1,75."""
    haut = 0.0
    for os_ in arm.data.bones:
        haut = max(haut, (arm.matrix_world @ os_.head_local).z,
                   (arm.matrix_world @ os_.tail_local).z)
    return haut


def action_de(arm, nom: str):
    for action in bpy.data.actions:
        if action.name == nom or action.name.startswith(nom + "."):
            return action
    return None


def ordonner(arm, noms: list) -> list:
    """Les os, PARENTS D'ABORD.

    L'ordre compte : poser une orientation absolue sur un os deplace tous ses
    enfants. Traiter un avant-bras avant son bras revient a le poser deux fois,
    et la deuxieme fois a partir d'une epaule qui a bouge entre-temps.
    """
    def profondeur(nom: str) -> int:
        os_ = arm.data.bones.get(nom)
        n = 0
        while os_ is not None and os_.parent is not None:
            n += 1
            os_ = os_.parent
        return n
    return sorted([n for n in noms if n in arm.data.bones], key=profondeur)


def reporter(src, cible, nom_clip: str, echelle: float) -> int:
    """Cuit un clip de la source sur la cible. Rend le nombre d'images."""
    action_src = action_de(src, nom_clip)
    if action_src is None:
        return 0

    src.animation_data.action = action_src
    debut, fin = (int(action_src.frame_range[0]), int(action_src.frame_range[1]))

    if cible.animation_data is None:
        cible.animation_data_create()
    ancienne = bpy.data.actions.get(nom_clip + "_cible")
    if ancienne is not None:
        bpy.data.actions.remove(ancienne)
    action = bpy.data.actions.new(nom_clip + "_cible")
    cible.animation_data.action = action

    noms = ordonner(cible, [n for n in OS if n in src.data.bones])
    for os_ in cible.pose.bones:
        os_.rotation_mode = "QUATERNION"

    # Le bassin au repos, pour ne garder du clip que l'ECART vertical.
    repos_bassin = cible.pose.bones["Hips"].bone.head_local.copy() \
        if "Hips" in cible.pose.bones else Vector()
    src_repos = src.pose.bones["Hips"].bone.head_local.copy() \
        if "Hips" in src.pose.bones else Vector()

    for image in range(debut, fin + 1):
        bpy.context.scene.frame_set(image)
        for nom in noms:
            os_src = src.pose.bones[nom]
            os_cible = cible.pose.bones[nom]
            # L'orientation ABSOLUE de l'os source, posee telle quelle.
            monde = (src.matrix_world @ os_src.matrix).to_quaternion()
            actuelle = cible.matrix_world @ os_cible.matrix
            # ON NE REMPLACE QUE LA ROTATION. La premiere version reconstruisait
            # la matrice a partir du seul quaternion : elle imposait donc au
            # passage une echelle de 1 et une translation reprise a la main. Sur
            # un modele dont l'armature n'est pas a l'echelle 1 — c'est le cas
            # de tout ce qui sort d'un import glTF — les membres partaient en
            # etoile. Verifie a l'image, pas deduit.
            position, _rotation, taille_os = actuelle.decompose()
            neuve = Matrix.LocRotScale(position, monde, taille_os)
            os_cible.matrix = cible.matrix_world.inverted() @ neuve
            # Sans cette mise a jour, les enfants gardent la pose de l'image
            # precedente et on cumule un decalage qui grandit le long du membre.
            bpy.context.view_layer.update()

        if "Hips" in cible.pose.bones:
            # Le rebond seulement : X et Z portent l'avancee du clip, et le jeu
            # deplace deja le personnage. Les garder le ferait avancer deux fois.
            monte = (src.pose.bones["Hips"].matrix.translation.z
                     - src_repos.z) * echelle
            os_ = cible.pose.bones["Hips"]
            os_.location = Vector((0.0, 0.0, 0.0))
            os_.location.z = monte
            os_.keyframe_insert("location", frame=image)

        for nom in noms:
            cible.pose.bones[nom].keyframe_insert("rotation_quaternion",
                                                  frame=image)
    return fin - debut + 1


def exporter(objets: list, chemin: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objets[0]
    bpy.ops.export_scene.gltf(
        filepath=str(chemin),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    dossier = racine / a.dossier
    source = racine / a.source

    cibles = sorted(dossier.glob("figurant_*.glb")) if a.nom == "tous" \
        else [dossier / ("%s.glb" % a.nom)]
    if not cibles:
        raise SystemExit("aucun figurant dans %s" % dossier)

    for chemin in cibles:
        vider()
        src, _ = importer(source)
        cible, objets = importer(chemin)

        h_src, h_cible = hauteur(src), hauteur(cible)
        echelle = (h_cible / h_src) if h_src > 0.01 else 1.0

        faits = []
        for clip in CLIPS:
            images = reporter(src, cible, clip, echelle)
            if images:
                faits.append("%s (%d images)" % (clip, images))

        # La source s'en va avant l'export : sans ca on exporterait Walter et le
        # figurant dans le meme fichier, et le jeu instancierait les deux.
        for o in list(bpy.data.objects):
            if o not in objets:
                bpy.data.objects.remove(o, do_unlink=True)

        exporter(objets, chemin)
        print("figurant %-28s %.2f m  <-  %s"
              % (chemin.stem, h_cible, ", ".join(faits) if faits else "RIEN"))


if __name__ == "__main__":
    main()
