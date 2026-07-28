#!/usr/bin/env python3
"""Remet un .glb rigge a la bonne taille, en agissant sur les DONNEES.

    blender -b -P outils/mettre_a_l_echelle.py -- --fichier x.glb --hauteur 1.68

Pourquoi un outil separe, et pourquoi il agit sur les donnees.

Un personnage peut etre a la bonne taille dans Blender et sortir a cent fois
sa taille dans le .glb : il suffit que l'echelle vive sur l'OBJET armature. Le
fichier de travail est alors juste, la console annonce le bon nombre, et la
sortie est fausse. On l'a cru trois fois sur le pack de figurants, exportes a
cent soixante-dix metres pendant que l'outil annoncait 1,68 m.

La parade est la meme que pour le lacet de l'Aztek : ne rien confier a une
transformation d'objet, et ecrire directement dans la geometrie. Une armature
dont les os mesurent 1,60 unite mesure 1,60 m partout, quel que soit ce que
l'exportateur decide de transporter.

ON MESURE SUR LES OS, jamais sur la boite englobante d'un maillage : celle-ci
decrit la geometrie AVANT deformation par l'armature, et annonce n'importe quoi
sur un personnage livre a plat.

Et on RELIT le fichier ecrit, parce que c'est la seule mesure qui compte.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Matrix


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Remise a l echelle d un rig")
    ap.add_argument("--fichier", required=True,
                    help="un .glb, ou un dossier de .glb")
    ap.add_argument("--hauteur", type=float, default=1.72,
                    help="hauteur voulue en metres, sommet du crane compris")
    return ap.parse_args(argv)


def armature():
    """Le squelette, ou None.

    None est un cas NORMAL et pas une erreur : cet outil est enchaine derriere
    l import pour tout modele, et la plupart n'ont pas de squelette. Une voiture
    ou un chapeau sont deja a la bonne taille en sortie d import — c'est le
    detour par l'objet armature qui pose probleme, et il n'existe pas ici.
    """
    return next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)


def hauteur_des_os(arm) -> float:
    """La hauteur du squelette, en unites de la scene.

    Le sommet du crane n'est pas le sommet du dernier os : il reste un peu de
    matiere au-dessus. Le facteur 0,93 est celui de importer_perso.py, mesure
    sur Walter, et il vaut pour tout humanoide.
    """
    zs = [(arm.matrix_world @ b.head_local).z for b in arm.data.bones]
    zs += [(arm.matrix_world @ b.tail_local).z for b in arm.data.bones]
    return (max(zs) - min(zs)) / 0.93


def traiter(chemin: Path, voulue: float) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(chemin))
    arm = armature()
    if arm is None:
        print("  %-34s pas de squelette, rien a corriger" % chemin.name)
        return
    avant = hauteur_des_os(arm)
    if avant <= 1e-6:
        raise SystemExit("%s : squelette sans hauteur mesurable" % chemin.name)

    facteur = voulue / avant

    # DANS LES DONNEES, et EXPRIME DANS LE REPERE DU MONDE.
    #
    # arm.scale ne survit pas a l'export ; arm.data.transform, si. Mais ecrire
    # simplement Scale(f) dans les donnees ne suffit pas : une donnee vit dans
    # le repere de son objet, et cet objet porte deja une transformation. Sur
    # ce pack, les maillages portent une echelle de cent — mettre leurs donnees
    # au centieme les laissait exactement de la meme taille. Mesure : os a
    # 1,60 m, maillage a 93 m, c'est-a-dire un squelette d'homme dans un corps
    # d'immeuble.
    #
    # On conjugue donc par la transformation de l'objet : M⁻¹ · S · M. Ce qui
    # est alors mis a l'echelle, c'est la geometrie TELLE QU'ON LA VOIT, quelle
    # que soit la transformation que l'objet transporte.
    echelle = Matrix.Scale(facteur, 4)
    for o in list(bpy.data.objects):
        if o.type not in ("MESH", "ARMATURE"):
            continue
        m = o.matrix_world
        o.data.transform(m.inverted() @ echelle @ m)
        if o.type == "MESH":
            o.data.update()
    bpy.context.view_layer.update()

    # LES ANIMATIONS AUSSI. Une rotation ne change pas d'echelle, mais une
    # TRANSLATION d'os est exprimee en unites d'armature : sans ce passage, le
    # bassin d'un cycle de marche se deplacerait cent fois trop, et le
    # personnage traverserait la rue a chaque foulee.
    courbes = 0
    for action in bpy.data.actions:
        for fc in _courbes(action):
            if not fc.data_path.endswith(".location"):
                continue
            for cle in fc.keyframe_points:
                cle.co.y *= facteur
                cle.handle_left.y *= facteur
                cle.handle_right.y *= facteur
            courbes += 1

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(chemin), export_format="GLB",
                              use_selection=True, export_yup=True,
                              export_cameras=False, export_lights=False)

    # ON RELIT LE FICHIER ECRIT. C'est tout l'objet de cet outil : croire la
    # scene est precisement l'erreur qu'on repare.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(chemin))
    apres = hauteur_des_os(armature())
    marque = "" if abs(apres - voulue) < 0.05 else "   <-- ECHEC"
    print("  %-34s %8.2f m  ->  %.2f m  (x%.4f, %d courbe(s))%s"
          % (chemin.name, avant, apres, facteur, courbes, marque))


def _courbes(action) -> list:
    """Les courbes d'une action, des deux cotes de Blender 4.4."""
    directes = getattr(action, "fcurves", None)
    if directes is not None:
        return list(directes)
    sortie = []
    for couche in action.layers:
        for bande in couche.strips:
            for sac in getattr(bande, "channelbags", []):
                sortie.extend(sac.fcurves)
    return sortie


def main() -> None:
    a = arguments()
    cible = Path(a.fichier)
    if not cible.is_absolute():
        cible = Path.cwd() / cible
    fichiers = sorted(cible.glob("*.glb")) if cible.is_dir() else [cible]
    if not fichiers:
        raise SystemExit("aucun .glb dans %s" % cible)
    print("")
    print("  hauteur voulue %.2f m" % a.hauteur)
    for f in fichiers:
        traiter(f, a.hauteur)


if __name__ == "__main__":
    main()
