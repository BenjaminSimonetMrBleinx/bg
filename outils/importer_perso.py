#!/usr/bin/env python3
"""Met un personnage RIGGE livre a la main aux conventions du projet.

    blender -b -P outils/importer_perso.py -- --fichier "livraisons/modeles/walt_anim.glb" \\
            --nom walt --hauteur 1.78

Un modele livre arrive rarement pret : il est a l'echelle de son logiciel
d'origine, oriente selon une autre convention, pose au-dessus ou au-dessous du
sol, et traine des objets de travail. Ce script normalise, et il DIT ce qu'il a
corrige — sans quoi on decouvre le probleme en jeu, sous la forme d'un
personnage qui glisse ou qui marche a reculons.

CE QU'IL GARANTIT, ET QUI EST TOUT CE QUI COMPTE :

    - hauteur exacte, en metres
    - pieds a z = 0, donc pose sur le sol et pas enterre
    - FACE VERS -Z DANS GODOT, c'est-a-dire de dos quand la camera est
      derriere. C'est la convention de tout le projet, et s'en ecarter donne un
      personnage qui recule quand on avance
    - squelette et animations conserves

Il ne touche NI au maillage NI aux textures : ce n'est pas son travail, et un
script qui retouche un modele livre est un script qui defait le travail de
quelqu'un a chaque reimport.
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
    ap = argparse.ArgumentParser(description="Import d'un personnage rigge")
    ap.add_argument("--fichier", required=True, help="le .glb ou .fbx livre")
    ap.add_argument("--nom", required=True, help="nom du fichier de sortie")
    ap.add_argument("--hauteur", type=float, default=1.78,
                    help="hauteur cible en metres")
    ap.add_argument("--sortie", default="game/assets/personnages")
    # Un modele peut arriver dans n'importe quel sens. On mesure celui qu'il a,
    # mais on laisse la main : la mesure se trompe sur un personnage
    # symetrique, et il vaut mieux pouvoir corriger que discuter.
    ap.add_argument("--sens", default="auto",
                    choices=["auto", "tel-quel", "tourner"],
                    help="auto deduit du squelette ; les deux autres decident")
    ap.add_argument("--garder", default="",
                    help="ne conserve que les maillages dont le nom commence "
                         "par ceci (les autres sont des objets de travail)")
    return ap.parse_args(argv)


def importer(chemin: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if chemin.suffix.lower() == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(chemin))
    else:
        bpy.ops.import_scene.gltf(filepath=str(chemin))


def maillages() -> list:
    return [o for o in bpy.data.objects if o.type == "MESH"]


def boite(objets: list):
    """Boite englobante, en coordonnees monde."""
    xs, ys, zs = [], [], []
    for o in objets:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


def sens_du_regard(arm) -> str:
    """Vers ou regarde le personnage, en lisant son squelette.

    On compare la position du pied GAUCHE : un humain debout, vu de dessus, a
    son cote gauche a quatre-vingt-dix degres de son regard. Avec Z vers le
    haut, si le pied gauche est en X positif, le personnage regarde vers -Y.

    C'est la mesure la moins fragile disponible : elle ne depend ni du nom du
    modele, ni de la pose, ni de l'orientation du fichier d'origine — seulement
    d'une convention de nommage d'os que tous les rigs humanoides respectent.
    """
    for gauche, droite in (("LeftFoot", "RightFoot"),
                           ("LeftUpLeg", "RightUpLeg"),
                           ("mixamorig:LeftFoot", "mixamorig:RightFoot")):
        g = arm.data.bones.get(gauche)
        d = arm.data.bones.get(droite)
        if g is None or d is None:
            continue
        pg = arm.matrix_world @ g.head_local
        pd = arm.matrix_world @ d.head_local
        return "-Y" if pg.x > pd.x else "+Y"
    return "?"


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    source = Path(a.fichier)
    if not source.is_absolute():
        source = racine / source
    if not source.exists():
        raise SystemExit("introuvable : %s" % source)

    importer(source)

    # Les objets de travail — une sphere de reference, un plan de sol — sont
    # exportes avec le personnage et arrivent tels quels dans le jeu. On les
    # ecarte plutot que de demander a quelqu'un de nettoyer son fichier.
    if a.garder:
        for o in list(maillages()):
            if not o.name.startswith(a.garder):
                print("  ecarte  %s (%d faces)" % (o.name, len(o.data.polygons)))
                bpy.data.objects.remove(o, do_unlink=True)

    corps = maillages()
    if not corps:
        raise SystemExit("aucun maillage dans %s" % source.name)
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if arm is None:
        raise SystemExit(
            "%s n'a pas de squelette.\n"
            "Ce script est pour les personnages RIGGES. Pour un maillage d'un "
            "bloc, voir outils/importer_modele.py." % source.name)

    x0, x1, y0, y1, z0, z1 = boite(corps)
    hauteur = z1 - z0
    if hauteur < 0.01:
        raise SystemExit("hauteur mesuree nulle : le modele est-il plat ?")
    facteur = a.hauteur / hauteur

    regard = sens_du_regard(arm)
    # La convention du projet : l'avant est -Z dans Godot, ce qui est +Y dans
    # Blender une fois l'exportateur passe. Un personnage qui regarde -Y arrive
    # donc face camera, et marche a reculons.
    demi_tour = (a.sens == "tourner") or (a.sens == "auto" and regard == "-Y")

    # Tout se joue sur la racine — l'armature — et pas sur le maillage : c'est
    # elle qui porte le personnage, et lui appliquer la transformation emmene
    # les animations avec.
    arm.scale = arm.scale * facteur
    if demi_tour:
        arm.rotation_euler.z += math.pi
    bpy.context.view_layer.update()

    # Les pieds a zero, APRES mise a l'echelle : un decalage mesure avant ne
    # vaut plus rien une fois le modele redimensionne.
    _, _, _, _, nz0, nz1 = boite(corps)
    arm.location.z -= nz0
    bpy.context.view_layer.update()

    _, _, _, _, fz0, fz1 = boite(corps)
    faces = sum(len(o.data.polygons) for o in corps)

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.mkdir(parents=True, exist_ok=True)
    fichier = sortie / ("%s.glb" % a.nom)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(fichier),
        export_format="GLB",
        use_selection=True,
        export_apply=False,          # PAS d'application : ca detruirait le rig
        export_yup=True,
        export_animations=True,
        export_cameras=False,
        export_lights=False,
    )

    print("")
    print("%-14s %s" % ("source", source.name))
    print("%-14s %.3f m -> %.3f m  (x %.4f)" % ("hauteur", hauteur, fz1 - fz0, facteur))
    print("%-14s %.4f m" % ("pieds a z", fz0))
    print("%-14s %s%s" % ("regard mesure", regard,
                          "  -> demi-tour applique" if demi_tour else ""))
    print("%-14s %d os" % ("squelette", len(arm.data.bones)))
    print("%-14s %s" % ("animations", [x.name for x in bpy.data.actions]))
    print("%-14s %d faces" % ("maillage", faces))
    print("%-14s %s" % ("sortie", fichier))


if __name__ == "__main__":
    main()
