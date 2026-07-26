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
    ap.add_argument("--mains", type=float, default=1.0,
                    help="retrecit les mains vers le poignet. 1 = telles que "
                         "livrees, 0.8 = un cinquieme plus petites")
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
    """Boite englobante du maillage TEL QU'IL EST DEFORME par le squelette.

    On evalue le depsgraph au lieu de lire bound_box. La difference n'est pas
    un detail : bound_box decrit la geometrie AVANT modificateurs, donc avant
    que l'armature ne la deforme. Sur un personnage dont le fichier livre pose
    deja le squelette, les deux n'ont plus rien a voir — mesure faite, un
    modele de 1,75 m s'annoncait a 2,70 puis ressortait a 3,10 apres une mise a
    l'echelle censee le ramener a 1,75.

    C'est le genre d'erreur qui ne se voit pas dans Blender et saute aux yeux
    en jeu, sous la forme d'un personnage deux fois trop grand.
    """
    dg = bpy.context.evaluated_depsgraph_get()
    xs, ys, zs = [], [], []
    for o in objets:
        evalue = o.evaluated_get(dg)
        maille = evalue.to_mesh()
        for v in maille.vertices:
            p = o.matrix_world @ v.co
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
        evalue.to_mesh_clear()
    if not xs:
        raise SystemExit("aucun sommet : le maillage est-il vide ?")
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


def taille_au_squelette(arm) -> float:
    """Hauteur du personnage, lue sur ses OS et pas sur son maillage.

    C'est la mesure qui marche. Celle du maillage passe par le depsgraph et
    depend de la facon dont le fichier livre attache sa peau a son squelette :
    deux modeles rigges le meme jour, meme exportateur, s'annoncaient a 2,70 m
    et refusaient de converger vers 1,75 quoi qu'on multiplie.

    Les os, eux, sont dans un repere qu'on maitrise — c'est deja par eux que
    animer_perso.py mesure les foulees et la hauteur des yeux. Du sol au sommet
    du crane : le plus bas des deux pieds, le haut de la tete.
    """
    m = arm.matrix_world
    hauts = [os for os in ("head_end", "HeadTop_End", "Head") if os in arm.pose.bones]
    if not hauts or "LeftFoot" not in arm.pose.bones:
        return 0.0
    sommet = (m @ arm.pose.bones[hauts[0]].head).z
    pieds = min((m @ arm.pose.bones[p].head).z
                for p in ("LeftFoot", "RightFoot") if p in arm.pose.bones)
    # L'os de la tete s'arrete au crane, pas aux cheveux, et le pied a la
    # cheville. On ajoute ce qui manque en dessous et au-dessus, en proportion :
    # une cheville est a 4 % de la taille, le sommet du crane 3 % au-dessus de
    # l'os de tete le plus haut.
    brut = sommet - pieds
    return brut / 0.93 if brut > 0.0 else 0.0


def sol_au_squelette(arm) -> float:
    """Altitude de la cheville la plus basse, en monde."""
    m = arm.matrix_world
    return min((m @ arm.pose.bones[p].head).z
               for p in ("LeftFoot", "RightFoot") if p in arm.pose.bones)


def reduire_les_mains(arm, facteur: float) -> float:
    """Retrecit les mains vers le poignet, en suivant le poids des sommets.

    LES MAINS LIVREES SONT TROP GRANDES. C'est le genre de defaut qu'on ne voit
    pas sur un modele isole et qui saute aux yeux des qu'un personnage tient
    quelque chose : le revolver disparait dedans.

    On ne peut pas simplement mettre l'os a l'echelle — un os d'armature met a
    l'echelle tout ce qui en depend, poignet compris, et le bras se retrecit
    avec. On deplace donc les SOMMETS, chacun vers le poignet, et l'amplitude
    du deplacement suit son POIDS sur l'os de la main : un sommet du bout des
    doigts, pese a un, se rapproche pleinement ; un sommet de l'avant-bras,
    pese a zero, ne bouge pas du tout. La transition se fait donc toute seule,
    exactement la ou le rig l'a placee.

    Renvoie de combien la main a retreci, en centimetres, pour qu'on puisse le
    lire au lieu de le supposer.
    """
    if abs(facteur - 1.0) < 1e-4:
        return 0.0
    bouge_max = 0.0
    for nom in ("LeftHand", "RightHand"):
        os_ = arm.data.bones.get(nom)
        if os_ is None:
            print("  %-14s os '%s' absent, mains inchangees" % ("mains", nom))
            continue
        poignet = arm.matrix_world @ os_.head_local
        for m in maillages():
            groupe = m.vertex_groups.get(nom)
            if groupe is None:
                continue
            vers_local = m.matrix_world.inverted()
            for v in m.data.vertices:
                poids = 0.0
                for g in v.groups:
                    if g.group == groupe.index:
                        poids = g.weight
                        break
                if poids <= 0.0:
                    continue
                monde = m.matrix_world @ v.co
                cible = poignet + (monde - poignet) * facteur
                final = monde.lerp(cible, poids)
                bouge_max = max(bouge_max, (final - monde).length)
                v.co = vers_local @ final
    return bouge_max * 100.0


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
    if demi_tour:
        arm.rotation_euler.z += math.pi
    bpy.context.view_layer.update()

    # ON MESURE, ON CORRIGE, ON REMESURE — jusqu'a tomber juste.
    #
    # Multiplier l'echelle par le rapport voulu SEMBLE suffire, et ca ne suffit
    # pas toujours : selon la facon dont le fichier livre attache son maillage a
    # son squelette, l'echelle de l'armature se propage une fois, deux fois, ou
    # pas du tout. Deux modeles livres le meme jour, meme rig, meme exportateur,
    # sortaient a 3,10 m pour 1,75 demandes — et rien dans Blender ne le disait.
    #
    # Trois tours suffisent quel que soit le mecanisme, parce qu'on ne raisonne
    # plus sur la cause : on regarde le resultat.
    for _ in range(8):
        actuelle = taille_au_squelette(arm)
        if actuelle < 1e-6 or abs(actuelle - a.hauteur) < 0.002:
            break
        arm.scale = arm.scale * (a.hauteur / actuelle)
        bpy.context.view_layer.update()

    # Les pieds a zero, APRES mise a l'echelle : un decalage mesure avant ne
    # vaut plus rien une fois le modele redimensionne.
    #
    # Par les OS, comme la taille, et pour la meme raison. Le pied de l'os
    # s'arrete a la cheville : on descend de ce qui reste dessous, quatre
    # pour cent de la taille.
    arm.location.z -= sol_au_squelette(arm) - a.hauteur * 0.04
    bpy.context.view_layer.update()

    # APRES la mise a l'echelle et le calage au sol : le retrecissement se
    # mesure en centimetres du monde, et il n'a de sens qu'une fois le
    # personnage a sa taille reelle.
    mains = reduire_les_mains(arm, a.mains)

    fz0 = sol_au_squelette(arm) - a.hauteur * 0.04
    fz1 = fz0 + taille_au_squelette(arm)
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
    if mains > 0.0:
        print("%-14s x%.2f, le bout des doigts recule de %.1f cm"
              % ("mains", a.mains, mains))
    print("%-14s %s" % ("sortie", fichier))


if __name__ == "__main__":
    main()
