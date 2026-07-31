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
from mathutils import Matrix, Quaternion, Vector

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


def verifier_le_repos(src, cible, reference: dict) -> float:
    """LE CONTROLE QUI NE DEMANDE PAS D'YEUX.

    Si la formule est juste, transferer la source AU REPOS doit laisser la
    cible EXACTEMENT a son repos : l'ecart au repos vaut l'identite, donc la
    pose visee est le repos de la cible. Tout ecart mesure ici est une erreur
    de formule, et il se voit sur un nombre avant de se voir sur un corps.

    Rend l'ecart maximal en degres.
    """
    src.data.pose_position = "REST"
    bpy.context.view_layer.update()
    pire = 0.0
    for nom in ordonner(cible, [n for n in OS if n in src.data.bones]):
        os_src = src.pose.bones[nom]
        os_cible = cible.pose.bones[nom]
        repos_src = (src.matrix_world @ os_src.bone.matrix_local).to_quaternion()
        pose_src = (src.matrix_world @ os_src.matrix).to_quaternion()
        ecart = pose_src @ repos_src.inverted()
        vise = ecart @ reference[nom]
        pire = max(pire, math.degrees(
                vise.rotation_difference(reference[nom]).angle))
    src.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    return pire


def pose_locale_de_reference(cible, action_pack) -> dict:
    """La rotation LOCALE de chaque os dans la pose debout du pack.

    Elle sert aux os qu'on NE reporte PAS — la colonne intermediaire, les
    doigts, les bouts. On les remettait a leur repos, c'est-a-dire a la pose de
    liaison, c'est-a-dire COUCHEE : la chaine se cassait au milieu du dos et
    tout le haut du corps partait de travers. Vu a l'image, quatre fois.

    Un os non reporte doit rester ou le pack le met. C'est le seul endroit
    sensé : c'est la pose sur laquelle tout le reste est calibre.
    """
    locales = {}
    if action_pack is None:
        return locales
    if cible.animation_data is None:
        cible.animation_data_create()
    cible.animation_data.action = action_pack
    bpy.context.scene.frame_set(int(action_pack.frame_range[0]))
    bpy.context.view_layer.update()
    for os_ in cible.pose.bones:
        locales[os_.name] = (os_.rotation_quaternion.copy(),
                             os_.location.copy(), os_.scale.copy())
    return locales


def pose_de_reference(cible, action_pack) -> dict:
    """L'orientation de chaque os du figurant DANS SA POSE DEBOUT.

    C'EST LA PIECE QUI MANQUAIT, et elle explique tout ce qui a rate cette
    nuit. La pose de LIAISON du pack est couchee — mesure a l'image : 0,21 m de
    haut pour 1,60 m de long, un corps parfaitement propre, allonge sur le dos.
    Le pack s'en accommode parce que ses propres clips le redressent.

    Reporter un mouvement en le rapportant a cette liaison revient donc a faire
    marcher quelqu'un d'allonge. Ce qu'on a vu — un corps disloque, membres en
    etoile — n'etait pas une erreur de formule : c'etait un homme couche qui
    marche, vu de trop pres.

    On prend donc pour reference la premiere image du clip du pack, ou le
    personnage se tient DEBOUT. Walter, lui, a une liaison debout : sa pose de
    repos suffit. Les deux references decrivent la meme chose — quelqu'un qui
    se tient droit — et c'est tout ce que la formule demande.
    """
    reference = {}
    if action_pack is None:
        for os_ in cible.pose.bones:
            reference[os_.name] = (cible.matrix_world
                    @ os_.bone.matrix_local).to_quaternion()
        return reference

    if cible.animation_data is None:
        cible.animation_data_create()
    cible.animation_data.action = action_pack
    bpy.context.scene.frame_set(int(action_pack.frame_range[0]))
    bpy.context.view_layer.update()
    for os_ in cible.pose.bones:
        reference[os_.name] = (cible.matrix_world @ os_.matrix).to_quaternion()
    return reference


def reporter(src, cible, nom_clip: str, echelle: float,
             reference: dict, locales: dict) -> int:
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
    # ON REPART D'UNE POSE NEUVE.
    #
    # Notre clip ne pilote QUE des rotations. Tout ce qu'on ne pilote pas garde
    # la derniere valeur evaluee — et on vient justement d'evaluer le clip du
    # pack pour en tirer la pose de reference. S'il anime l'echelle des os, on
    # herite de la sienne, et les membres s'etirent en pointes sans qu'aucune
    # rotation soit en cause. Vu a l'image.
    for os_ in cible.pose.bones:
        os_.rotation_mode = "QUATERNION"
        if os_.name in locales:
            rot, pos, ech = locales[os_.name]
            os_.rotation_quaternion = rot.copy()
            os_.location = pos.copy()
            os_.scale = ech.copy()
        else:
            os_.location = Vector()
            os_.rotation_quaternion = Quaternion()
            os_.scale = Vector((1.0, 1.0, 1.0))
    bpy.context.view_layer.update()

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
            # L'ECART AU REPOS, PAS L'ORIENTATION.
            #
            # C'est ici qu'etait la faute. On posait sur le figurant
            # l'orientation ABSOLUE de l'os de Walter — ce qui ne vaut que si
            # les deux squelettes ont le meme repos. Ils ne l'ont pas, et
            # c'etait deja mesure a l'import : chez Walter une cuisse pointe
            # vers le bas, chez un Biped TOUS les os pointent dans la meme
            # direction. Chaque os se faisait donc tordre de l'ecart entre son
            # repos et celui de Walter, d'ou les membres en etoile.
            #
            # Ce qu'on transfere est ce que Walter FAIT : la rotation qui mene
            # de son repos a sa pose. Appliquee au repos du figurant, elle ne
            # suppose plus rien sur l'orientation des os.
            repos_src = (src.matrix_world @ os_src.bone.matrix_local).to_quaternion()
            pose_src = (src.matrix_world @ os_src.matrix).to_quaternion()
            ecart = pose_src @ repos_src.inverted()
            monde = ecart @ reference[nom]

            # ON N'ECRIT QUE LA ROTATION. JAMAIS LA POSITION.
            #
            # La version precedente posait la matrice complete de l'os, en
            # reprenant sa translation courante. C'est ce qui ETIRAIT les
            # membres : une translation ecrite sur un os le decolle de son
            # parent, et le maillage suit — une cuisse de deux metres, vue a
            # l'image.
            #
            # On resout donc la rotation LOCALE qui, composee avec le parent
            # deja pose et avec le repos de l'os, donne l'orientation voulue :
            #
            #     parent_monde x repos_local x locale = monde
            #
            # Les os gardent alors exactement les longueurs de leur squelette,
            # quoi qu'on leur demande.
            if os_cible.parent is not None:
                parent_monde = (cible.matrix_world
                        @ os_cible.parent.matrix).to_quaternion()
                repos_local = (os_cible.parent.bone.matrix_local.inverted()
                        @ os_cible.bone.matrix_local).to_quaternion()
            else:
                parent_monde = cible.matrix_world.to_quaternion()
                repos_local = os_cible.bone.matrix_local.to_quaternion()
            os_cible.rotation_quaternion =                     (parent_monde @ repos_local).inverted() @ monde
            os_cible.location = Vector()
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

        for os_ in cible.pose.bones:
            os_.keyframe_insert("rotation_quaternion", frame=image)
            os_.keyframe_insert("scale", frame=image)
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

        # Le clip du pack, garde a l'import : c'est lui qui porte la pose
        # debout. On le retient AVANT de creer les notres, sinon on ne sait
        # plus lequel est lequel.
        action_pack = None
        if cible.animation_data is not None:
            action_pack = cible.animation_data.action
        if action_pack is None:
            action_pack = next((x for x in bpy.data.actions
                                if not x.name.endswith("_cible")
                                and x.name not in CLIPS), None)
        locales = pose_locale_de_reference(cible, action_pack)
        reference = pose_de_reference(cible, action_pack)

        ecart_repos = verifier_le_repos(src, cible, reference)
        if ecart_repos > 0.5:
            raise SystemExit(
                "%s : la formule de report est fausse. Au repos, la cible "
                "devrait rester a son repos ; elle s'en ecarte de %.1f degres. "
                "Rien n'est exporte : mieux vaut pas de clip qu'un corps disloque."
                % (chemin.name, ecart_repos))

        faits = []
        for clip in CLIPS:
            images = reporter(src, cible, clip, echelle, reference, locales)
            if images:
                faits.append("%s (%d images)" % (clip, images))

        # LA SOURCE S'EN VA AVANT L'EXPORT — SES OBJETS ET SES ACTIONS.
        #
        # Retirer les objets ne suffisait pas, et c'est ce qui a fait perdre la
        # nuit : Blender exporte TOUTES les actions du fichier, pas seulement
        # celles qui sont assignees. Le .glb du figurant contenait donc les
        # neuf clips de Walter — Accroupi, Assis, Marche, Saut... — en plus des
        # notres. Tout ce qui demandait « Marche » recevait les rotations
        # LOCALES BRUTES de Walter posees sur un Biped, c'est-a-dire le corps
        # disloque qu'on a regarde cinq fois en croyant juger un report.
        #
        # Le clip du pack part avec : le notre porte le meme nom et doit gagner.
        for o in list(bpy.data.objects):
            if o not in objets:
                bpy.data.objects.remove(o, do_unlink=True)
        nos_clips = {c + "_cible" for c in CLIPS}
        for act in list(bpy.data.actions):
            if act.name not in nos_clips:
                bpy.data.actions.remove(act)
        # Puis on leur rend leur vrai nom : c'est celui que demarche.gd cherche.
        for act in list(bpy.data.actions):
            act.name = act.name.removesuffix("_cible")
        if cible.animation_data is not None:
            cible.animation_data.action = bpy.data.actions.get("Repos")

        exporter(objets, chemin)
        print("figurant %-28s %.2f m  <-  %s"
              % (chemin.stem, h_cible, ", ".join(faits) if faits else "RIEN"))


if __name__ == "__main__":
    main()
