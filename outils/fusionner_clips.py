#!/usr/bin/env python3
"""Reunit un modele livre et ses clips livres a part, dans un seul .glb.

    blender -b -P outils/fusionner_clips.py -- \\
        --modele  ".../Character_output.glb" \\
        --clips   ".../Merged_Animations.glb" \\
        --nommer  "019fba09=Saut,019fba21=Coiffer" \\
        --sortie  .tmp/walt_v2.glb

POURQUOI CET OUTIL EXISTE.

Les exportateurs livrent souvent le personnage d'un cote et ses animations de
l'autre — c'est le cas de Meshy, et c'etait deja celui du pack de figurants. Le
jeu, lui, veut un seul fichier : un modele qui porte ses clips.

QUAND LES DEUX PARTAGENT LE MEME SQUELETTE, il n'y a AUCUN report a faire. On
verifie que les os portent les memes noms, et on rattache les actions telles
quelles. C'est la difference entre cette livraison-ci et le pack de figurants,
ou les deux rigs differaient et ou tout le travail etait dans le report.

La verification n'est pas une precaution : rattacher une action a un squelette
qui n'a pas les memes os ne provoque AUCUNE erreur. Les courbes ne trouvent
simplement pas leur cible, le personnage reste au repos, et rien ne le dit.

LES CLIPS ANONYMES se renomment par --nommer. Un exportateur qui livre des
UUID en guise de noms est frequent ; on les identifie en les MESURANT — voir
la note dans le journal — puis on les baptise ici.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Fusionne un modele et ses clips")
    ap.add_argument("--modele", required=True)
    ap.add_argument("--clips", required=True)
    ap.add_argument("--nommer", default="",
                    help="prefixe=NouveauNom, separes par des virgules")
    ap.add_argument("--garder", default="",
                    help="ne garder que ces clips, separes par des virgules")
    ap.add_argument("--sortie", required=True)
    return ap.parse_args(argv)


def os_de(arm) -> set:
    return {b.name for b in arm.data.bones}


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    modele = Path(a.modele)
    clips = Path(a.clips)
    sortie = racine / a.sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # --- le personnage ----------------------------------------------------
    bpy.ops.import_scene.gltf(filepath=str(modele))
    objets_perso = list(bpy.data.objects)
    arm = next((o for o in objets_perso if o.type == "ARMATURE"), None)
    if arm is None:
        raise SystemExit("%s : aucune armature" % modele.name)
    siennes = {x.name for x in bpy.data.actions}

    # --- les clips --------------------------------------------------------
    bpy.ops.import_scene.gltf(filepath=str(clips))
    arm2 = next((o for o in bpy.data.objects
                 if o.type == "ARMATURE" and o is not arm), None)
    if arm2 is None:
        raise SystemExit("%s : aucune armature" % clips.name)

    # LA VERIFICATION QUI EVITE UN PERSONNAGE FIGE SANS MESSAGE.
    a_lui, a_eux = os_de(arm), os_de(arm2)
    communs = a_lui & a_eux
    if len(communs) < len(a_lui) * 0.9:
        raise SystemExit(
            "les deux squelettes ne concordent pas : %d os communs sur %d.\n"
            "Un report est necessaire — voir outils/retarget_figurants.py."
            % (len(communs), len(a_lui)))
    print("")
    print("squelettes   %d os communs sur %d — rattachement direct"
          % (len(communs), len(a_lui)))

    # --- renommer, filtrer ------------------------------------------------
    tables = []
    for paire in filter(None, a.nommer.split(",")):
        prefixe, neuf = paire.split("=")
        tables.append((prefixe.strip(), neuf.strip()))
    for action in bpy.data.actions:
        for prefixe, neuf in tables:
            if action.name.startswith(prefixe):
                print("clip         %-40s -> %s" % (action.name[:40], neuf))
                action.name = neuf
                break

    garder = {x.strip() for x in a.garder.split(",") if x.strip()}
    for action in list(bpy.data.actions):
        if action.name in siennes and garder and action.name not in garder:
            bpy.data.actions.remove(action)
            continue
        if garder and action.name not in garder:
            print("clip         %-40s ecarte" % action.name[:40])
            bpy.data.actions.remove(action)

    # --- ne garder que le personnage --------------------------------------
    for o in list(bpy.data.objects):
        if o not in objets_perso:
            bpy.data.objects.remove(o, do_unlink=True)

    if arm.animation_data is None:
        arm.animation_data_create()
    restantes = list(bpy.data.actions)

    # CHAQUE CLIP DEVIENT UNE PISTE NLA, et ce n'est pas un detail.
    #
    # L'exportateur glTF n'ecrit que les actions qu'il trouve RATTACHEES a
    # quelque chose. Celles qui ne le sont plus — parce qu'on vient de
    # supprimer l'armature qui les portait — sont purgees avant l'export.
    # Symptome mesure : quatre clips annonces, trois dans le fichier, et
    # « Coiffer » disparu sans un mot.
    #
    # Une piste NLA par action les rattache toutes a l'armature qu'on garde.
    # C'est aussi la seule facon documentee d'exporter plusieurs animations
    # pour un meme objet.
    for action in restantes:
        action.use_fake_user = True
        piste = arm.animation_data.nla_tracks.new()
        piste.name = action.name
        piste.strips.new(action.name, int(action.frame_range[0]), action)
    if restantes:
        arm.animation_data.action = None

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(sortie), export_format="GLB", use_selection=True,
        export_animations=True, export_yup=True,
        export_cameras=False, export_lights=False)

    print("clips        %s" % ", ".join(sorted(x.name for x in restantes)))
    print("-> %s" % sortie)


if __name__ == "__main__":
    main()
