#!/usr/bin/env python3
"""Decoupe le pack de figurants en personnages separes, aux conventions du jeu.

    blender -b -P outils/importer_figurants.py -- \\
        --fichier livraisons/modeles/figurants/people_freePack_webGl_ani.fbx

Produit un .glb par personnage dans game/assets/personnages/, nomme d'apres le
maillage qu'il porte : figurant_casual_male_g, figurant_elder_female_a, etc.

CE QUE LE PACK CONTIENT, MESURE ET PAS SUPPOSE :

    8 armatures    bip, bip001 ... bip007, 36 os chacune, rig Biped
    8 corps        casual/doctor/elder/police/little_boy, 780 a 1000 faces
    7 accessoires  cheveux, lunettes, stethoscope, telephone
    24 actions     toutes de 200 images, et AUCUNE n'est une marche

Le pack n'a pas de marche : son unique clip est une attente debout. C'est
mesure, et c'est ce qui a ouvert le ticket #16.

DEUX PIEGES, ET ILS SE CUMULENT
-------------------------------

1. LES NOMS D'OS NE SONT PAS FIABLES. Les huit armatures sont des copies, et
   Blender resout les collisions de noms en ajoutant un suffixe numerique :
   « bip Spine » et « bip Spine1 » deviennent « bip Spine002 » et
   « bip Spine003 » sur la deuxieme armature. Retirer les chiffres rend les
   deux identiques — on melangerait le bas et le haut du dos.

   On identifie donc chaque os par sa PLACE DANS L'ARBRE, pas par son nom : le
   chemin des indices d'enfants depuis la racine. La premiere armature, seule a
   porter des noms propres, sert de dictionnaire.

2. LES OS NE POINTENT PAS DANS LE SENS DE LEUR MEMBRE. Sur le rig de Walter,
   une cuisse pointe vers le bas (0.09, 0.06, -0.99) et une colonne vers le
   haut (0.00, 0.02, 1.00). Sur un Biped, TOUS les os pointent dans la meme
   direction, ici (0.87, -0.50, 0.00), quel que soit le membre.

   Consequence directe : une rotation LOCALE ne veut pas dire la meme chose sur
   les deux rigs. Recopier telle quelle la marche de Walter — la voie 1 du
   ticket — ne peut pas marcher, et ce n'est pas une incertitude, c'est une
   mesure. Le report passe donc par l'espace MONDE : voir animer_perso.py.

Ce script-ci ne fait donc PAS l'animation. Il livre des personnages propres,
nommes comme le reste du projet, prets a recevoir des clips.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector

# La correspondance Biped -> convention du projet.
#
# A gauche les noms de la PREMIERE armature, la seule dont les noms sont
# propres. A droite ceux du rig de Walter, ceux que animer_perso.py,
# equipement.gd et demarche.gd connaissent.
#
# Les os absents de cette table sont conserves sous leur nom d'origine : les
# doigts et les bouts ("Nub") ne servent a rien ici, mais les supprimer
# casserait le poids des sommets qui s'y accrochent.
CORRESPONDANCE = {
    "bip Pelvis": "Hips",
    "bip Spine": "Spine02",
    "bip Spine1": "Spine01",
    "bip Neck": "neck",
    "bip Head": "Head",
    "bip HeadNub": "head_end",
    "bip L Clavicle": "LeftShoulder",
    "bip L UpperArm": "LeftArm",
    "bip L Forearm": "LeftForeArm",
    "bip L Hand": "LeftHand",
    "bip R Clavicle": "RightShoulder",
    "bip R UpperArm": "RightArm",
    "bip R Forearm": "RightForeArm",
    "bip R Hand": "RightHand",
    "bip L Thigh": "LeftUpLeg",
    "bip L Calf": "LeftLeg",
    "bip L Foot": "LeftFoot",
    "bip L Toe0": "LeftToeBase",
    "bip R Thigh": "RightUpLeg",
    "bip R Calf": "RightLeg",
    "bip R Foot": "RightFoot",
    "bip R Toe0": "RightToeBase",
}

# Il manque « Spine » chez Walter — l'os du haut du dos, parent des clavicules
# et du cou. Le Biped n'en a que deux ; on accroche donc les clavicules et le
# cou directement au haut du dos, ce que la table ci-dessus fait deja en
# donnant Spine01 a « bip Spine1 ». Les scripts qui cherchent « Spine » se
# rabattent sur Spine01, et c'est le meme os a un maillon pres.

## Hauteur cible, en metres. Les figurants ne font pas tous la meme taille dans
## la rue — une rangee de gens identiques se lit comme une rangee de copies —
## mais l'ecart est pose ici, pas herite du pack, dont les modeles arrivent a
## des echelles sans rapport les uns avec les autres.
TAILLES = {
    "little_boy": 1.32,
    "elder_female": 1.62,
    "casual_female": 1.68,
    "police_female": 1.71,
    "casual_male": 1.77,
    "doctor_male": 1.80,
}
TAILLE_PAR_DEFAUT = 1.74


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Decoupe du pack de figurants")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--sortie", default="game/assets/personnages")
    ap.add_argument("--prefixe", default="figurant_")
    ap.add_argument("--inventaire", action="store_true",
                    help="liste ce que le pack contient, sans rien ecrire")
    return ap.parse_args(argv)


def chemin_de(os_) -> tuple:
    """La place d'un os dans l'arbre : les indices d'enfants depuis la racine.

    C'est l'identite fiable. Les noms ne le sont pas — voir l'en-tete.
    """
    trajet = []
    courant = os_
    while courant.parent is not None:
        trajet.append(list(courant.parent.children).index(courant))
        courant = courant.parent
    trajet.reverse()
    return tuple(trajet)


def dictionnaire_des_chemins(reference) -> dict:
    """chemin -> nom du projet, appris sur l'armature aux noms propres."""
    table = {}
    for os_ in reference.data.bones:
        voulu = CORRESPONDANCE.get(os_.name)
        if voulu is not None:
            table[chemin_de(os_)] = voulu
    return table


def renommer(arm, table: dict) -> int:
    """Renomme les os de cette armature d'apres leur place dans l'arbre."""
    # On collecte AVANT de renommer : renommer pendant qu'on parcourt
    # reordonne le tableau des os de Blender, et on saute des entrees.
    a_faire = []
    for os_ in arm.data.bones:
        voulu = table.get(chemin_de(os_))
        if voulu is not None and os_.name != voulu:
            a_faire.append((os_, voulu))
    for os_, voulu in a_faire:
        os_.name = voulu
    return len(a_faire)


def famille(nom: str) -> str:
    """Le nom de fichier tire du nom du maillage, sans les fioritures."""
    propre = re.sub(r"[^a-zA-Z_]", "", nom).strip("_").lower()
    return re.sub(r"_+", "_", propre)


def taille_voulue(nom: str) -> float:
    for cle, valeur in TAILLES.items():
        if nom.startswith(cle):
            return valeur
    return TAILLE_PAR_DEFAUT


def enfants_de(arm) -> list:
    """Les maillages habilles par cette armature.

    On les reconnait a leur MODIFICATEUR, pas a leur parent : un accessoire —
    des lunettes, un stethoscope — est souvent parente a la scene et suit son
    porteur par le seul modificateur d'armature. Se fier au parent en perdait
    la moitie, et le figurant sortait chauve.
    """
    pris = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for m in o.modifiers:
            if m.type == "ARMATURE" and m.object == arm:
                pris.append(o)
                break
    return pris


def corps_de(maillages: list):
    """Le corps parmi les maillages : le plus lourd. Le reste est accessoire."""
    return max(maillages, key=lambda m: len(m.data.polygons))


def isoler(arm, maillages: list) -> None:
    """Ne laisse dans la scene que cette armature et ses maillages."""
    garder = set([arm] + maillages)
    for o in list(bpy.data.objects):
        if o not in garder:
            bpy.data.objects.remove(o, do_unlink=True)


def poser_au_sol_et_a_l_echelle(arm, maillages: list, hauteur: float) -> tuple:
    """Met le personnage a la bonne taille, pieds a zero, face a -Z.

    Les memes trois garanties que importer_perso.py, et pour les memes
    raisons : un modele a la mauvaise echelle traverse les murs, un modele
    centre sur son milieu s'enfonce dans le sol, et un modele tourne marche a
    reculons.

    LA MESURE SE FAIT SUR LES OS, PAS SUR LA BOITE ENGLOBANTE. Une boite
    englobante decrit la geometrie AVANT deformation par l'armature : sur ce
    pack elle annonce jusqu'a 6,7 m pour des maillages a plat, ce qui n'a aucun
    rapport avec la taille du personnage debout.
    """
    hauts = [(arm.matrix_world @ b.head_local).z for b in arm.data.bones]
    hauts += [(arm.matrix_world @ b.tail_local).z for b in arm.data.bones]
    brut = max(hauts) - min(hauts)
    # Le sommet du crane n'est pas le sommet du dernier os : il reste un peu
    # de matiere au-dessus. Le meme facteur que importer_perso.py, mesure sur
    # Walter, et il vaut pour tout humanoide.
    brut = brut / 0.93
    if brut <= 1e-6:
        raise SystemExit("armature sans hauteur mesurable")

    facteur = hauteur / brut

    # ON NE TOUCHE QU'A L'ARMATURE.
    #
    # Premiere version : on mettait a l'echelle l'armature ET ses maillages.
    # Un maillage peaufine est deja pilote par l'armature — son modificateur
    # applique la transformation de celle-ci a chaque sommet — donc le facteur
    # se retrouvait applique deux fois, et le figurant sortait gros comme un
    # immeuble. Il couvrait le QG de Tuco sur la capture, ce qui est la seule
    # facon dont on s'en est apercu.
    #
    # Les maillages sont donc PARENTES a l'armature, en conservant leur
    # transformation, et c'est elle seule qu'on redimensionne : ils suivent
    # une fois, et une seule.
    for m in maillages:
        if m.parent is not arm:
            local = m.matrix_world.copy()
            m.parent = arm
            m.matrix_parent_inverse = arm.matrix_world.inverted()
            m.matrix_world = local

    arm.scale = arm.scale * facteur
    arm.location = arm.location * facteur
    bpy.context.view_layer.update()

    bas = min((arm.matrix_world @ b.head_local).z for b in arm.data.bones)
    bas = min(bas, min((arm.matrix_world @ b.tail_local).z
                       for b in arm.data.bones))
    arm.location.z -= bas
    bpy.context.view_layer.update()
    return brut, facteur


def sens_du_regard(arm) -> float:
    """Vers ou regarde le personnage, en radians autour de la verticale.

    On le DEDUIT du bassin plutot que de le supposer : l'axe qui pointe vers
    l'avant depend du rig, et un personnage retourne a tort marche a reculons
    sans que rien ne le signale.

    Sur un Biped, le regard suit la normale du bassin dans le plan horizontal.
    """
    bassin = arm.data.bones.get("Hips")
    if bassin is None:
        return 0.0
    avant = (arm.matrix_world.to_3x3() @ bassin.matrix_local.to_3x3()
             @ Vector((0.0, 0.0, 1.0)))
    avant.z = 0.0
    if avant.length < 1e-6:
        return 0.0
    return math.atan2(avant.x, avant.y)


def garder_son_clip(arm, nom_arm: str) -> str:
    """Ne laisse que l'animation de CE personnage, et l'appelle « Repos ».

    Chaque figurant sortait avec les HUIT clips du pack — un par armature du
    fichier d'origine. Sept d'entre eux pilotent des os qui n'existent pas ici :
    ils ne font rien, ils ne provoquent aucune erreur, et ils quadruplent le
    poids du fichier. Le jeu, lui, cherche « Repos » et ne trouvait rien, donc
    le figurant restait fige sur sa premiere image.

    Le pack n'a AUCUNE marche — mesure, voir l'en-tete. Le seul clip disponible
    est une attente debout : c'est donc un repos, et on le nomme comme tel.
    """
    sien = None
    for action in list(bpy.data.actions):
        if action.name.split("|")[0] == nom_arm:
            sien = action
        else:
            bpy.data.actions.remove(action)
    if sien is None:
        return ""
    sien.name = "Repos"
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = sien
    return sien.name


def exporter(chemin: Path) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(chemin), export_format="GLB", use_selection=True,
        export_apply=False, export_yup=True, export_animations=True,
        export_cameras=False, export_lights=False,
        export_skins=True)


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    source = Path(a.fichier)
    if not source.is_absolute():
        source = racine / source
    if not source.exists():
        raise SystemExit("introuvable : %s" % source)
    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.mkdir(parents=True, exist_ok=True)

    # Le fichier est recharge POUR CHAQUE personnage : isoler detruit les
    # autres, et il n'y a pas de retour en arriere propre en Blender headless.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source))
    armatures = sorted((o for o in bpy.data.objects if o.type == "ARMATURE"),
                       key=lambda o: o.name)
    if not armatures:
        raise SystemExit("aucune armature dans %s" % source.name)
    table = dictionnaire_des_chemins(armatures[0])
    print("")
    print("  dictionnaire  %d os reconnus sur %s"
          % (len(table), armatures[0].name))

    plan = []
    for arm in armatures:
        maillages = enfants_de(arm)
        if not maillages:
            print("  %-12s aucun maillage, ignore" % arm.name)
            continue
        nom = famille(corps_de(maillages).name)
        plan.append((arm.name, nom, [m.name for m in maillages]))
        print("  %-12s %-22s %d maillage(s)" % (arm.name, nom, len(maillages)))

    if a.inventaire:
        print("")
        print("  inventaire seul, rien n'a ete ecrit")
        return

    print("")
    for nom_arm, nom, noms_maillages in plan:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(source))
        arm = bpy.data.objects[nom_arm]
        maillages = [bpy.data.objects[n] for n in noms_maillages]

        manques = renommer(arm, table)
        isoler(arm, maillages)

        voulue = taille_voulue(nom)
        brut, facteur = poser_au_sol_et_a_l_echelle(arm, maillages, voulue)

        # Face a -Z, comme tout le projet. On tourne l'armature ET ses
        # maillages du meme angle, autour de l'origine.
        # La aussi, l'armature seule : les maillages lui sont parentes.
        angle = -sens_du_regard(arm)
        if abs(angle) > 1e-4:
            arm.rotation_euler.z += angle
        bpy.context.view_layer.update()

        clip = garder_son_clip(arm, nom_arm)

        fichier = sortie / ("%s%s.glb" % (a.prefixe, nom))
        exporter(fichier)
        print("  %-24s %d os renommes, %.2f m (x%.3f), clip %s  -> %s"
              % (nom, manques, voulue, facteur,
                 clip if clip else "AUCUN", fichier.name))

    print("")
    print("  sortie   %s" % sortie)
    print("  ATTENTION : ces personnages n'ont PAS de marche. Le pack n'en")
    print("  contient aucune, et les rotations de Walter ne se recopient pas")
    print("  sur un Biped — voir l'en-tete de ce fichier.")
    print("  Ils sont donc poses DEBOUT dans la rue, pas mis a marcher : un")
    print("  personnage qui glisse en jouant une attente est pire que le")
    print("  passant procedural qu'il remplacerait.")
    print("")
    print("  A FAIRE ENSUITE, apres l'export :")
    print("    blender -b -P outils/mettre_a_l_echelle.py -- --fichier %s"
          % sortie)
    print("  L'echelle posee ici vit sur les OBJETS et ne survit pas au .glb.")


if __name__ == "__main__":
    main()
