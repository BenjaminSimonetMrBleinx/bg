#!/usr/bin/env python3
"""Ajoute a un personnage rigge les animations que le modele livre n'a pas.

    blender -b -P outils/animer_perso.py -- --nom walt

Le pack livre porte « Walking » et « Running », et rien d'autre. Il manque donc
les deux animations qu'on voit le PLUS :

    Repos   ce que fait le personnage quand on ne touche a rien. Sans elle, il
            reste fige sur une image de course, jambes ecartees, bras en l'air.
            C'est l'etat dans lequel on le voit le plus longtemps.
    Marche  une marche relachee. Celle du pack est correcte mais raide : le
            buste ne tourne pas, la tete est vissee, et les deux pas sont
            rigoureusement identiques.

Rien n'est invente a partir de rien : les deux clips DERIVENT de la marche
livree. Repos part de sa pose moyenne — la moyenne d'un cycle de marche est un
personnage debout, jambes sous le bassin, bras le long du corps — et Marche est
la marche livree plus une couche de relachement. On garde donc le style de
celui qui a rigge le personnage.

CE QUI EST MESURE, ET PAS SUPPOSE :

    - la FOULEE de chaque clip, c'est-a-dire la distance que le personnage
      parcourrait en un cycle si ses pieds ne patinaient pas. C'est le nombre
      qui accorde l'animation au deplacement, et le lire ici evite de le
      regler a l'oeil dans reglages.tres
    - la position de la main au sommet du geste des lunettes, resolue par
      recherche et verifiee en centimetres. Un bras qui vise la tete et la
      manque de quinze centimetres ne se rattrape pas au montage
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Quaternion, Vector

# La convention du projet, une fois le personnage normalise : il regarde vers
# +Y dans Blender (soit -Z dans Godot), il a le haut vers +Z, et sa gauche est
# donc vers -X.
AVANT = Vector((0.0, 1.0, 0.0))
HAUT = Vector((0.0, 0.0, 1.0))
GAUCHE = Vector((-1.0, 0.0, 0.0))

# Axes de rotation, en repere armature. Le sens suit la regle de la main
# droite : tourner autour de +X d'un angle POSITIF penche vers l'arriere.
TANGAGE = Vector((1.0, 0.0, 0.0))   # hocher, se pencher avant-arriere
ROULIS = Vector((0.0, 1.0, 0.0))    # pencher a gauche-droite
LACET = Vector((0.0, 0.0, 1.0))     # tourner sur soi

IPS = 30


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Fabrique les clips manquants")
    ap.add_argument("--nom", default="walt")
    ap.add_argument("--dossier", default="game/assets/personnages")
    ap.add_argument("--marche", default="Walking",
                    help="le clip de marche livre, source de tout le reste")
    ap.add_argument("--mesurer", action="store_true",
                    help="mesure et affiche, sans rien fabriquer ni ecrire")
    return ap.parse_args(argv)


# --------------------------------------------------------------------------
# Lecture


def armature():
    a = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if a is None:
        raise SystemExit("aucun squelette dans le fichier")
    return a


def poser(arm, action, image: int) -> None:
    """Evalue une action a une image donnee et la pose sur le squelette."""
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(image)


def images_de(action) -> tuple[int, int]:
    d, f = action.frame_range
    return int(round(d)), int(round(f))


def place(arm, os: str) -> Vector:
    """Position monde de la tete d'un os, dans la pose courante."""
    return arm.matrix_world @ arm.pose.bones[os].head


def bout(arm, os: str, longueur: float) -> Vector:
    """Un point situe a `longueur` metres du depart de l'os, dans son axe.

    Pour la main, le bout des doigts — et la difference compte : viser le
    POIGNET a bien amene le poignet devant les lunettes, et les doigts vingt
    centimetres au-dessus du crane. Un salut militaire, pas un geste de myope.

    On ne peut pas se servir de `tail` : ce rig annonce des os de deux mille
    unites, et l'extremite tombe a vingt-quatre metres du personnage. Seule la
    DIRECTION de l'os est fiable, verifiee ici — elle tombe au centieme sur la
    direction reelle entre deux articulations. La longueur, on la donne.
    """
    b = arm.pose.bones[os]
    axe = (arm.matrix_world.to_3x3() @ b.y_axis).normalized()
    return (arm.matrix_world @ b.head) + axe * longueur


## Longueur d'une main, du poignet au bout du majeur.
MAIN = 0.095


def foulee_mesuree(arm, action) -> float:
    """Distance parcourue en un cycle, lue sur l'ecartement des pieds.

    Une animation de deplacement est jouee SUR PLACE : rien dans le fichier ne
    dit a quelle vitesse le personnage avance. L'information est pourtant la,
    dans la geometrie — l'ecart maximal entre les deux pieds le long de l'axe
    du regard est la longueur d'un pas, et un cycle en contient deux.

    C'est ce nombre qu'il faut donner au jeu comme longueur de foulee. Le
    regler a l'oeil donne un personnage qui patine ou qui pedale, et on passe
    la soiree a se demander si c'est la vitesse ou l'animation.
    """
    d, f = images_de(action)
    ecart = 0.0
    for i in range(d, f + 1):
        poser(arm, action, i)
        g = place(arm, "LeftToeBase")
        dr = place(arm, "RightToeBase")
        ecart = max(ecart, abs((g - dr).dot(AVANT)))
    return ecart * 2.0


def hauteur_tete(arm) -> float:
    return place(arm, "Head").z


# --------------------------------------------------------------------------
# Ecriture


def courbes(action) -> list:
    """Les courbes d'une action, des deux cotes de Blender 4.4.

    Les actions sont devenues « a couches » : les courbes ne sont plus posees
    sur l'action mais dans un sac, dans une bande, dans une couche. On lit les
    deux formes plutot que d'exiger une version de Blender.
    """
    directes = getattr(action, "fcurves", None)
    if directes is not None:
        return list(directes)
    sortie = []
    for couche in action.layers:
        for bande in couche.strips:
            for sac in getattr(bande, "channelbags", []):
                sortie.extend(sac.fcurves)
    return sortie


def axe_local(arm, os: str, axe: Vector) -> Vector:
    """Un axe du repere armature, exprime dans le repere de repos de l'os.

    Une rotation de pose vit dans le repere PROPRE de l'os, dont l'orientation
    depend du rig. Vouloir « pencher le buste en avant » sans cette conversion
    revient a tourner autour d'un axe tire au sort.
    """
    m = arm.pose.bones[os].bone.matrix_local.to_3x3()
    return (m.inverted() @ axe).normalized()


def tourner(arm, pose: dict, os: str, axe: Vector, degres: float) -> None:
    """Ajoute une rotation, en repere armature, a une pose en construction."""
    if os not in arm.pose.bones:
        return
    q = Quaternion(axe_local(arm, os, axe), math.radians(degres))
    pose[os] = q @ pose.get(os, Quaternion())


def appliquer(arm, pose: dict, monter: float = 0.0) -> None:
    """Pose le squelette. `monter` est une elevation du bassin, EN METRES.

    Le deplacement d'un os vit dans le repere de l'os, pas dans celui du monde.
    Ecrire directement dans location.z fait glisser le bassin dans une
    direction qui depend du rig — mesure faite, sur celui-ci, ca ne montait pas
    du tout.
    """
    for nom, os in arm.pose.bones.items():
        os.rotation_mode = "QUATERNION"
        os.rotation_quaternion = pose.get(nom, Quaternion()).normalized()
    if "Hips" in arm.pose.bones:
        bassin = arm.pose.bones["Hips"]
        repere = bassin.bone.matrix_local.to_3x3().inverted()
        bassin.location = repere @ (HAUT * monter)
    bpy.context.view_layer.update()


def cle(arm, action, image: int, avec_bassin: bool = True) -> None:
    # L'action est assignee une fois, AVANT la boucle. La reassigner ici
    # relancait une evaluation qui reposait le squelette a l'image courante :
    # les cles restaient justes, mais tout ce qu'on mesurait apres ne
    # correspondait plus a la pose qu'on venait de construire.
    for nom, os in arm.pose.bones.items():
        os.keyframe_insert("rotation_quaternion", frame=image)
    if avec_bassin and "Hips" in arm.pose.bones:
        arm.pose.bones["Hips"].keyframe_insert("location", frame=image)


def action_neuve(nom: str):
    if nom in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[nom])
    a = bpy.data.actions.new(nom)
    a.use_fake_user = True
    return a


def ranger(arm, action) -> None:
    """Range l'action dans une piste NLA : sans ca elle n'est pas exportee."""
    if arm.animation_data is None:
        arm.animation_data_create()
    piste = arm.animation_data.nla_tracks.new()
    piste.name = action.name
    piste.strips.new(action.name, int(action.frame_range[0]), action)
    piste.mute = True


# --------------------------------------------------------------------------
# La pose de repos


def pose_moyenne(arm, action) -> dict:
    """La moyenne d'un cycle de marche : un personnage debout.

    Ce n'est pas une astuce. La moyenne d'un cycle symetrique annule le
    balancement — les cuisses reviennent sous le bassin, les bras le long du
    corps — et ce qui reste est la posture de celui qui a rigge le personnage,
    et non une pose de repos inventee par-dessus son travail.
    """
    d, f = images_de(action)
    somme: dict = {}
    for i in range(d, f):
        poser(arm, action, i)
        for nom, os in arm.pose.bones.items():
            q = os.rotation_quaternion.copy()
            ref = somme.get(nom)
            if ref is None:
                somme[nom] = [q.w, q.x, q.y, q.z]
                continue
            # Deux quaternions opposes decrivent la meme rotation. Les
            # additionner sans recaler les signes donne la rotation nulle.
            if q.dot(Quaternion(ref).normalized()) < 0.0:
                q = -q
            ref[0] += q.w
            ref[1] += q.x
            ref[2] += q.y
            ref[3] += q.z
    return {n: Quaternion(v).normalized() for n, v in somme.items()}


def bras_le_long_du_corps(arm, pose: dict, quoi: str) -> float:
    """Ecart entre la main et la hanche. Un bras qui pend en fait vingt.

    Un personnage debout se juge d'abord a ses bras, et « bras le long du
    corps » est une distance, pas une impression. On l'imprime pour toutes les
    poses intermediaires : c'est le seul moyen de voir a quelle etape ils se
    sont ecartes.
    """
    poser_pose(arm, pose)
    d = (place(arm, "LeftHand") - place(arm, "LeftUpLeg")).length
    print("  %-11s main gauche a %.0f cm de la hanche" % (quoi, d * 100.0))
    return d


def serrer_le_bras(arm, pose: dict, bras: str, main: str, hanche: str,
                   cible: float) -> None:
    """Rapproche la main du corps jusqu'a la distance demandee.

    On balaie l'angle plutot que de l'ecrire : quel axe ECARTE un bras depend
    de l'orientation que le rig a donnee a l'os, et la reponse n'est pas la
    meme a gauche et a droite. Un balayage de quatre-vingts degres coute une
    seconde et se trompe zero fois.
    """
    meilleur = (0.0, 1e9)
    for dixiemes in range(-400, 401, 20):
        essai = {k: v.copy() for k, v in pose.items()}
        tourner(arm, essai, bras, AVANT, dixiemes / 10.0)
        poser_pose(arm, essai)
        ecart = abs((place(arm, main) - place(arm, hanche)).length - cible)
        if ecart < meilleur[1]:
            meilleur = (dixiemes / 10.0, ecart)
    tourner(arm, pose, bras, AVANT, meilleur[0])


def pose_relachee(arm, action) -> dict:
    """La pose moyenne, detendue : on ne se tient pas au garde-a-vous."""
    bras_le_long_du_corps(arm, {}, "rig au repos")
    d, f = images_de(action)
    ecarts = []
    for i in range(d, f + 1):
        poser(arm, action, i)
        ecarts.append((place(arm, "LeftHand") - place(arm, "LeftUpLeg")).length)
    print("  %-11s main gauche entre %.0f et %.0f cm de la hanche"
          % ("en marchant", min(ecarts) * 100.0, max(ecarts) * 100.0))
    pose = pose_moyenne(arm, action)
    bras_le_long_du_corps(arm, pose, "moyenne")
    # LES BRAS SE RAPPROCHENT DU CORPS, et c'est la correction qui compte.
    #
    # Le clip livre tient la main a 39 cm de la hanche — mesure ci-dessus — et
    # sa moyenne herite fidelement de cet ecart. En marchant ca ne se remarque
    # pas ; debout, ca donne quelqu'un qui va degainer. On les serre donc
    # jusqu'a une distance de bras qui pend.
    serrer_le_bras(arm, pose, "LeftArm", "LeftHand", "LeftUpLeg", 0.27)
    serrer_le_bras(arm, pose, "RightArm", "RightHand", "RightUpLeg", 0.27)
    # Et les coudes ne sont jamais tendus.
    tourner(arm, pose, "LeftForeArm", GAUCHE, 12.0)
    tourner(arm, pose, "RightForeArm", GAUCHE, 12.0)
    # Les pieds legerement ouverts, et le poids plutot sur une jambe.
    tourner(arm, pose, "LeftUpLeg", HAUT, 4.0)
    tourner(arm, pose, "RightUpLeg", HAUT, -4.0)
    bras_le_long_du_corps(arm, pose, "relachee")
    return pose


def axe_de_flexion(arm, depart: dict, coude: str, main: str,
                   epaule: str) -> tuple[Vector, float]:
    """Sur quel axe, et dans quel sens, ce coude PLIE.

    L'orientation des os appartient a celui qui a fabrique le rig, et rien
    n'oblige « plier le coude » a etre la meme rotation d'un modele a l'autre.
    On la trouve donc au lieu de la supposer : plier, c'est ce qui RAPPROCHE la
    main de l'epaule. On essaie les six possibilites et on garde la bonne.
    """
    poser_pose(arm, depart)
    tendu = (place(arm, main) - place(arm, epaule)).length
    meilleur = (TANGAGE, 1.0, tendu)
    for axe in (TANGAGE, ROULIS, LACET):
        for signe in (1.0, -1.0):
            pose = {k: v.copy() for k, v in depart.items()}
            tourner(arm, pose, coude, axe, 70.0 * signe)
            poser_pose(arm, pose)
            d = (place(arm, main) - place(arm, epaule)).length
            if d < meilleur[2]:
                meilleur = (axe, signe, d)
    axe, signe, replie = meilleur
    print("  coude      bras tendu %.0f cm, plie a 70 deg %.0f cm"
          % (tendu * 100.0, replie * 100.0))
    return axe, signe


def resoudre_les_lunettes(arm, depart: dict) -> dict:
    """Trouve la pose du bras gauche qui amene la main aux lunettes.

    Poser des angles a la main sur un rig qu'on n'a pas fabrique ne marche pas :
    l'orientation des os est propre au rig, et une valeur qui semble juste
    envoie le poignet dans l'epaule. On cherche donc les angles, et on VERIFIE
    en centimetres ou la main a atterri.

    Descente par coordonnees : six angles, un a la fois, pas de plus en plus
    fin. C'est lent a lire et court a ecrire, et le probleme est trop petit
    pour meriter mieux.

    La main GAUCHE, parce que la droite tient le revolver et le porkpie —
    remonter ses lunettes avec un calibre est une autre scene.
    """
    poser_pose(arm, depart)
    # OU SONT LES LUNETTES. On ne le demande pas au nom des os : « headfront »
    # laissait croire au visage et designait le sommet du crane, ce qui donnait
    # un personnage qui se gratte la tete. On mesure la tete et on se place aux
    # deux tiers de sa hauteur, un peu en avant — c'est la ou sont les yeux sur
    # n'importe quel humain.
    bas = place(arm, "Head")
    haut = place(arm, "head_end")
    cible = bas + (haut - bas) * 0.46 + AVANT * 0.085 + GAUCHE * 0.025
    # Le poignet, lui, doit rester BAS : c'est ce qui fait la difference entre
    # remonter ses lunettes et faire un signe. On demande donc deux choses a la
    # fois — les doigts au montures, le poignet une main plus bas.
    poignet = cible - HAUT * 0.115 + AVANT * 0.02
    print("  tete       de %.2f m a %.2f m, lunettes visees a %.2f m"
          % (bas.z, haut.z, cible.z))
    plie, sens = axe_de_flexion(arm, depart, "LeftForeArm", "LeftHand",
                                "LeftArm")

    # QUATRE inconnues, pas neuf : trois pour viser avec le bras, une pour
    # plier le coude. Laisser les neuf libres trouve toujours une solution qui
    # touche la cible, et c'est le probleme — elle passe par un poignet retourne
    # et une epaule a l'envers. Un modele a moins de liberte se trompe moins.
    axes = [TANGAGE, ROULIS, LACET]
    reglages = [("LeftArm", axes[0], 120.0), ("LeftArm", axes[1], 120.0),
                ("LeftArm", axes[2], 120.0), ("LeftForeArm", plie, 140.0),
                ("LeftShoulder", axes[0], 18.0), ("LeftShoulder", axes[2], 18.0),
                ("LeftHand", axes[0], 70.0), ("LeftHand", axes[1], 70.0),
                ("LeftHand", axes[2], 70.0)]

    def construire(valeurs) -> dict:
        pose = {k: v.copy() for k, v in depart.items()}
        for (o, axe, _), deg in zip(reglages, valeurs):
            tourner(arm, pose, o, axe, deg)
        return pose

    def evaluer(valeurs) -> float:
        poser_pose(arm, construire(valeurs))
        ecart = ((bout(arm, "LeftHand", MAIN) - cible).length
                 + 0.7 * (place(arm, "LeftHand") - poignet).length)
        # Une pose contorsionnee atteint la cible aussi bien qu'une pose
        # naturelle. On paie donc chaque degre : a distance egale, le bras qui
        # se tord le moins gagne.
        return ecart + 0.00012 * sum(abs(v) for v in valeurs)

    def descendre(depuis: list) -> tuple[float, list]:
        angles = list(depuis)
        cout = evaluer(angles)
        pas = 30.0
        while pas > 0.4:
            bouge = False
            for i, (_, _, borne) in enumerate(reglages):
                for signe in (1.0, -1.0):
                    essai = list(angles)
                    essai[i] += signe * pas
                    if abs(essai[i]) > borne:
                        continue
                    neuf = evaluer(essai)
                    if neuf < cout - 1e-5:
                        cout, angles, bouge = neuf, essai, True
                        break
            if not bouge:
                pas *= 0.5
        return cout, angles

    # PLUSIEURS DEPARTS. Une descente par coordonnees s'arrete dans le premier
    # creux venu, et ce creux depend entierement d'ou elle commence : avec un
    # seul depart, la meme fonction trouvait la cible au millimetre pour un
    # point vise et la manquait de quinze centimetres pour un autre, bras
    # bloque en butee. Six essais coutent quelques secondes.
    meilleur = None
    for pli in (35.0, 75.0, 110.0):
        for lever in (0.0, -50.0):
            depart_i = [lever, 0.0, 0.0, pli * sens, 0.0, 0.0, 0.0, 0.0, 0.0]
            resultat = descendre(depart_i)
            if meilleur is None or resultat[0] < meilleur[0]:
                meilleur = resultat
    angles = meilleur[1]

    pose = construire(angles)
    poser_pose(arm, pose)
    ecart = (bout(arm, "LeftHand", MAIN) - cible).length
    print("  lunettes   doigts a %.1f cm des montures, poignet a %.1f cm "
          "sous eux" % (ecart * 100.0,
                        (cible.z - place(arm, "LeftHand").z) * 100.0))
    if ecart > 0.05:
        print("  ATTENTION  le geste manque la tete de %.1f cm" % (ecart * 100))
    # La tete accompagne un peu : on baisse le menton quand on remonte ses
    # lunettes, on ne reste pas plante droit pendant que la main monte.
    tourner(arm, pose, "Head", TANGAGE, -3.0)
    tourner(arm, pose, "neck", TANGAGE, -2.0)
    return pose


def poser_pose(arm, pose: dict) -> None:
    for nom, os in arm.pose.bones.items():
        os.rotation_mode = "QUATERNION"
        os.rotation_quaternion = pose.get(nom, Quaternion()).normalized()
    bpy.context.view_layer.update()


def melange(a: dict, b: dict, t: float) -> dict:
    """Interpolation entre deux poses, os par os."""
    sortie = {}
    for nom in set(a) | set(b):
        qa = a.get(nom, Quaternion())
        qb = b.get(nom, Quaternion())
        sortie[nom] = qa.slerp(qb, t)
    return sortie


def adoucir(t: float) -> float:
    """Entree et sortie douces. Un geste a vitesse constante est un robot."""
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def clip_repos(arm, source, duree_s: float = 8.0):
    """Debout, vivant, et une fois par cycle il remonte ses lunettes.

    Trois choses se superposent, et aucune n'a la meme periode : la
    respiration, un tres lent report du poids, et le geste. Des mouvements qui
    partagent une periode se resynchronisent a chaque tour et le personnage
    redevient une machine — c'est exactement ce qu'on cherche a eviter.
    """
    repos = pose_relachee(arm, source)
    lunettes = resoudre_les_lunettes(arm, repos)

    action = action_neuve("Repos")
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action

    total = int(duree_s * IPS)
    # Le geste : depart, sommet, tenue, retour. Il tombe au deux tiers du
    # cycle, la ou l'oeil ne l'attend plus.
    g0, g1, g2, g3 = 0.62, 0.70, 0.735, 0.83

    # On mesure le DEPLACEMENT du buste entre le creux et le sommet du
    # souffle, pas sa hauteur : ouvrir la cage thoracique pousse la poitrine en
    # avant bien plus qu'elle ne la leve. Une premiere version ne regardait que
    # l'altitude de la tete et annoncait fierement zero millimetre.
    inspire = None
    expire = None
    for i in range(total + 1):
        t = i / float(total)
        pose = {k: v.copy() for k, v in repos.items()}

        # Respiration : quinze par minute, soit un cycle de quatre secondes.
        # Le buste s'ouvre a l'inspiration, le bassin monte d'un demi
        # centimetre. C'est peu, et c'est tout ce qu'il faut pour qu'un
        # personnage arrete d'avoir l'air en pause.
        souffle = math.sin(t * duree_s / 4.0 * math.tau)
        tourner(arm, pose, "Spine01", TANGAGE, 1.4 * souffle)
        tourner(arm, pose, "Spine", TANGAGE, 0.8 * souffle)
        tourner(arm, pose, "neck", TANGAGE, -0.6 * souffle)
        # Les epaules montent avec la cage thoracique. C'est ce qui rend une
        # respiration LISIBLE a la resolution du jeu : le buste bouge de
        # quelques millimetres, les mains de trois fois plus.
        tourner(arm, pose, "LeftArm", AVANT, 1.2 * souffle)
        tourner(arm, pose, "RightArm", AVANT, -1.2 * souffle)

        # Report du poids, sur toute la duree du clip : personne ne tient
        # huit secondes parfaitement d'aplomb.
        bascule = math.sin(t * math.tau)
        tourner(arm, pose, "Hips", ROULIS, 1.6 * bascule)
        tourner(arm, pose, "Spine02", ROULIS, -1.0 * bascule)

        # La tete, sur une periode qui ne tombe juste avec aucune des deux.
        regard = math.sin(t * duree_s / 5.3 * math.tau)
        tourner(arm, pose, "Head", LACET, 2.6 * regard)
        tourner(arm, pose, "Head", TANGAGE, 0.8 * math.cos(t * duree_s / 3.7 * math.tau))

        if g0 <= t <= g3:
            if t < g1:
                poids = adoucir((t - g0) / (g1 - g0))
            elif t < g2:
                poids = 1.0
            else:
                poids = 1.0 - adoucir((t - g2) / (g3 - g2))
            pose = melange(pose, lunettes, poids)

        appliquer(arm, pose, 0.009 * souffle)
        cycle = t * duree_s / 4.0
        if abs(cycle - 0.25) < 0.01:
            inspire = (place(arm, "Spine"), place(arm, "Head"))
        if abs(cycle - 0.75) < 0.01:
            expire = (place(arm, "Spine"), place(arm, "Head"))
        cle(arm, action, i)

    if inspire is not None and expire is not None:
        print("  respiration  le buste bouge de %.1f mm, la tete de %.1f mm"
              % ((inspire[0] - expire[0]).length * 1000.0,
                 (inspire[1] - expire[1]).length * 1000.0))
    boucler(action)
    return action


def clip_marche(arm, source):
    """La marche livree, relachee.

    La marche du pack est juste mais raide, et la raideur a trois causes qu'on
    peut nommer : le buste ne contre pas le bassin, la tete est vissee sur les
    epaules, et les deux pas sont rigoureusement identiques. On corrige les
    trois par-dessus, sans toucher aux jambes — c'est le travail de Guillaume
    et il est bon.
    """
    d, f = images_de(source)
    lu = []
    for i in range(d, f + 1):
        poser(arm, source, i)
        lu.append({n: o.rotation_quaternion.copy()
                   for n, o in arm.pose.bones.items()})
        lu[-1]["#loc"] = arm.pose.bones["Hips"].location.copy()

    action = action_neuve("Marche")
    arm.animation_data.action = action

    n = len(lu) - 1
    for i, base in enumerate(lu):
        t = i / float(n)
        pose = {k: v.copy() for k, v in base.items() if k != "#loc"}

        # Le buste tourne a l'INVERSE du bassin. C'est ce qui manque le plus :
        # sans cette opposition, le haut du corps est une caisse posee sur des
        # jambes qui bougent.
        contre = math.sin(t * math.tau)
        tourner(arm, pose, "Spine01", LACET, 4.2 * contre)
        tourner(arm, pose, "Spine", LACET, 2.4 * contre)
        # La tete garde son cap pendant que les epaules tournent dessous, avec
        # un retard : elle suit, elle ne pilote pas.
        retard = math.sin((t - 0.12) * math.tau)
        tourner(arm, pose, "neck", LACET, -2.8 * retard)
        tourner(arm, pose, "Head", LACET, -1.6 * retard)
        tourner(arm, pose, "Head", TANGAGE, 1.2 * math.sin(t * 2.0 * math.tau))

        # Une dissymetrie franche entre les deux pas. Un cycle contient les
        # deux, donc la boucle tient quand meme — et c'est le detail qui fait
        # qu'on ne voit plus la repetition.
        cote = math.sin(t * math.tau + math.pi * 0.25)
        tourner(arm, pose, "Spine02", ROULIS, 1.8 * cote)
        tourner(arm, pose, "LeftShoulder", TANGAGE, 1.5 * max(0.0, cote))

        appliquer(arm, pose, base["#loc"])
        cle(arm, action, d + i)

    boucler(action)
    return action


def boucler(action) -> None:
    if hasattr(action, "use_cyclic"):
        action.use_cyclic = True
    for courbe in courbes(action):
        for k in courbe.keyframe_points:
            k.interpolation = "BEZIER"
            k.handle_left_type = "AUTO_CLAMPED"
            k.handle_right_type = "AUTO_CLAMPED"


# --------------------------------------------------------------------------


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    fichier = racine / a.dossier / ("%s.glb" % a.nom)
    if not fichier.exists():
        raise SystemExit("introuvable : %s" % fichier)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(fichier))
    bpy.context.scene.render.fps = IPS
    arm = armature()

    livrees = [x.name for x in bpy.data.actions]
    print("")
    print("%-12s %s" % ("fichier", fichier.name))
    print("%-12s %d os" % ("squelette", len(arm.data.bones)))
    print("%-12s %s" % ("livrees", livrees))
    print("")

    source = bpy.data.actions.get(a.marche)
    if source is None:
        raise SystemExit("pas de clip '%s' dans %s" % (a.marche, fichier.name))

    print("  foulees mesurees, en metres par cycle")
    for nom in livrees:
        act = bpy.data.actions[nom]
        d, f = images_de(act)
        print("    %-10s %.2f m  (%.2f s)"
              % (nom, foulee_mesuree(arm, act), (f - d) / float(IPS)))
    print("")

    if a.mesurer:
        return

    nouvelles = (clip_repos(arm, source), clip_marche(arm, source))
    print("")
    # On RELIT ce qu'on vient d'ecrire. Construire une pose et l'inserer en cle
    # sont deux operations distinctes, et rien ne garantit que la seconde ait
    # enregistre la premiere : la seule preuve est de rejouer le clip.
    for nouvelle in nouvelles:
        d, f = images_de(nouvelle)
        mini = Vector((1e9, 1e9, 1e9))
        maxi = Vector((-1e9, -1e9, -1e9))
        for i in range(d, f + 1):
            poser(arm, nouvelle, i)
            p = place(arm, "Head")
            mini = Vector((min(mini[k], p[k]) for k in range(3)))
            maxi = Vector((max(maxi[k], p[k]) for k in range(3)))
        print("  %-10s %3d images, %.1f s, la tete parcourt %.0f mm"
              % (nouvelle.name, f - d, (f - d) / float(IPS),
                 (maxi - mini).length * 1000.0))
        if nouvelle.name != "Repos":
            continue
        # Le geste, RELU DANS LE CLIP. La pose resolue etait juste et
        # l'animation ne la montrait pas : entre les deux il y a une insertion
        # de cles, un melange et une interpolation, et chacun des trois peut
        # avaler le geste.
        haut = 0.0
        quand = 0
        for i in range(d, f + 1):
            poser(arm, nouvelle, i)
            z = bout(arm, "LeftHand", MAIN).z
            if z > haut:
                haut, quand = z, i
        poser(arm, nouvelle, quand)
        print("             geste au sommet a l'image %d (%.2f s) : doigts a "
              "%.2f m, %.0f cm devant le visage"
              % (quand, quand / float(IPS), haut,
                 (bout(arm, "LeftHand", MAIN) - place(arm, "Head")).dot(AVANT)
                 * 100.0))

    # Les actions creees ici ne sont attachees a rien : sans piste NLA, elles
    # ne sortent pas du fichier et on cherche pourquoi le jeu ne les voit pas.
    arm.animation_data.action = None
    for nom in ("Repos", "Marche"):
        ranger(arm, bpy.data.actions[nom])

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(fichier),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_animations=True,
        export_cameras=False,
        export_lights=False,
    )
    print("")
    print("%-12s %s" % ("sortie", fichier))


if __name__ == "__main__":
    main()
