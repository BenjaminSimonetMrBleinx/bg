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
    ap.add_argument("--depuis", default="",
                    help="copie les clips d'un AUTRE personnage au lieu de les "
                         "fabriquer. Exige le meme squelette")
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


def appliquer(arm, pose: dict, monter: float = 0.0,
              origine: Vector | None = None) -> None:
    """Pose le squelette.

    `monter` est une elevation du bassin, EN METRES, et `origine` la
    translation que le clip source lui donnait deja : un cycle de marche fait
    monter et descendre le bassin, et l'ecraser rend la marche plate.

    DEUX conversions sur `monter`, et oublier l'une ou l'autre ne previent pas :

      - le deplacement d'un os vit dans le repere DE L'OS. Ecrire directement
        dans location.z fait glisser le bassin dans une direction qui depend du
        rig — sur celui-ci, ca ne montait pas du tout.
      - et dans l'UNITE de l'armature, qui n'est pas le metre. Celle-ci est a
        l'echelle 0,011 : demander quarante centimetres en donnait quatre
        dixiemes de millimetre. L'accroupissement descendait de rien, en
        silence, et le solveur cherchait tres serieusement comment plier les
        jambes pour accompagner un bassin qui ne bougeait pas.
    """
    for nom, os in arm.pose.bones.items():
        os.rotation_mode = "QUATERNION"
        os.rotation_quaternion = pose.get(nom, Quaternion()).normalized()
    if "Hips" in arm.pose.bones:
        bassin = arm.pose.bones["Hips"]
        echelle = max(1e-6, arm.matrix_world.to_scale().z)
        repere = bassin.bone.matrix_local.to_3x3().inverted()
        garde = origine if origine is not None else Vector((0.0, 0.0, 0.0))
        bassin.location = garde + repere @ (HAUT * (monter / echelle))
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


def resoudre(arm, depart: dict, leviers: list, cout, departs: list,
             monter: float = 0.0) -> dict:
    """Cherche les angles qui satisfont un objectif, et rend la pose.

    `leviers` est une liste de (os, axe, borne en degres), `cout` une fonction
    a MINIMISER evaluee sur le squelette pose, `departs` une liste de jeux
    d'angles initiaux.

    Descente par coordonnees, a pas decroissant. C'est fruste, et c'est le bon
    outil ici : on cherche quatre a huit angles sur un squelette dont on ne
    connait pas l'orientation des os, et ecrire ces angles a la main donne des
    poses fausses qu'on corrige ensuite pendant une heure.

    PLUSIEURS DEPARTS, parce qu'une descente par coordonnees s'arrete dans le
    premier creux venu et que ce creux depend entierement d'ou elle commence :
    avec un seul depart, la meme fonction trouvait sa cible au millimetre pour
    un point vise et la manquait de quinze centimetres pour un autre, bras
    bloque en butee.
    """
    def construire(valeurs) -> dict:
        pose = {k: v.copy() for k, v in depart.items()}
        for (o, axe, _), deg in zip(leviers, valeurs):
            tourner(arm, pose, o, axe, deg)
        return pose

    def evaluer(valeurs) -> float:
        poser_pose(arm, construire(valeurs), monter)
        # Une pose contorsionnee atteint la cible aussi bien qu'une pose
        # naturelle. On paie donc chaque degre : a resultat egal, le membre qui
        # se tord le moins gagne.
        return cout(valeurs) + 0.00012 * sum(abs(v) for v in valeurs)

    meilleur = None
    for depuis in departs:
        angles = list(depuis)
        courant = evaluer(angles)
        pas = 30.0
        while pas > 0.4:
            bouge = False
            for i, (_, _, borne) in enumerate(leviers):
                for signe in (1.0, -1.0):
                    essai = list(angles)
                    essai[i] += signe * pas
                    if abs(essai[i]) > borne:
                        continue
                    neuf = evaluer(essai)
                    if neuf < courant - 1e-5:
                        courant, angles, bouge = neuf, essai, True
                        break
            if not bouge:
                pas *= 0.5
        if meilleur is None or courant < meilleur[0]:
            meilleur = (courant, angles)
    return construire(meilleur[1])


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


def distance_au_segment(p: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    l2 = ab.dot(ab)
    t = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, (p - a).dot(ab) / l2))
    return (p - (a + ab * t)).length


def traverse(arm, tronc: tuple, tete: tuple) -> tuple[float, float]:
    """De combien le bras gauche RENTRE dans le buste et dans le crane.

    En metres, et jamais negatif : zero veut dire qu'il passe a cote.

    Cette mesure manquait, et son absence explique le geste. Le solveur ne
    payait que l'arrivee des doigts ; le chemin pour y aller ne lui coutait
    rien. Il trouvait donc la solution la moins chere en degres — l'avant-bras
    a plat en travers de la poitrine, le coude colle au sternum, la main qui
    ressort par la joue. Vue de face, la main arrive aux lunettes ; vue de
    trois quarts, le bras est dans le torse.

    On echantillonne le bras et l'avant-bras, et on garde le pire enfoncement.
    L'avant-bras n'est suivi qu'aux trois quarts : son extremite est CENSEE
    finir contre le visage, et la lui reprocher interdirait le geste.
    """
    tronc_bas, tronc_haut, r_tronc = tronc
    centre_tete, r_tete = tete
    epaule = place(arm, "LeftArm")
    coude = place(arm, "LeftForeArm")
    poignet = place(arm, "LeftHand")
    dans_tronc = 0.0
    dans_tete = 0.0
    for a, b, jusqu in ((epaule, coude, 1.0), (coude, poignet, 0.75)):
        for k in range(1, 9):
            p = a + (b - a) * (jusqu * k / 8.0)
            dans_tronc = max(dans_tronc,
                             r_tronc - distance_au_segment(p, tronc_bas, tronc_haut))
            dans_tete = max(dans_tete, r_tete - (p - centre_tete).length)
    return max(0.0, dans_tronc), max(0.0, dans_tete)


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

    # LE BUSTE ET LE CRANE, en volumes, MESURES sur le rig au repos.
    #
    # Le rayon du buste n'est pas un nombre choisi : c'est la distance de l'axe
    # du tronc a l'articulation de l'epaule, un peu rentree. Sur n'importe quel
    # humanoide, l'epaule est posee sur le bord de la cage thoracique.
    tronc_bas = place(arm, "Hips")
    tronc_haut = bas
    r_tronc = distance_au_segment(place(arm, "LeftArm"), tronc_bas, tronc_haut) * 0.80
    centre_tete = bas + (haut - bas) * 0.5
    r_tete = (haut - bas).length * 0.48
    tronc = (tronc_bas, tronc_haut, r_tronc)
    tete = (centre_tete, r_tete)
    print("  volumes    buste rayon %.1f cm, crane rayon %.1f cm"
          % (r_tronc * 100.0, r_tete * 100.0))

    # QUATRE inconnues, pas neuf : trois pour viser avec le bras, une pour
    # plier le coude. Laisser les neuf libres trouve toujours une solution qui
    # touche la cible, et c'est le probleme — elle passe par un poignet retourne
    # et une epaule a l'envers. Un modele a moins de liberte se trompe moins.
    #
    # Le poignet est desormais borne a 34 degres au lieu de 70 : au-dela on ne
    # remonte plus ses lunettes, on se casse la main.
    axes = [TANGAGE, ROULIS, LACET]
    reglages = [("LeftArm", axes[0], 120.0), ("LeftArm", axes[1], 120.0),
                ("LeftArm", axes[2], 120.0), ("LeftForeArm", plie, 140.0),
                ("LeftShoulder", axes[0], 18.0), ("LeftShoulder", axes[2], 18.0),
                ("LeftHand", axes[0], 34.0), ("LeftHand", axes[1], 34.0),
                ("LeftHand", axes[2], 34.0)]

    # LE COUT. Trois termes, et les deux derniers sont nouveaux :
    #
    #   - ou arrivent les doigts, et ou arrive le poignet ;
    #   - ce que le bras traverse en chemin, paye QUATRE fois le prix d'un
    #     ecart de visee. Un centimetre de bras dans le torse se voit
    #     infiniment plus qu'un centimetre de doigts a cote des montures ;
    #   - le coude qui monte au-dessus de l'epaule. Rien ne l'interdisait, et
    #     c'est le « pli bizarre » : on remonte ses lunettes coude BAS, le
    #     coude en l'air est un salut.
    def ecart_de(_valeurs) -> float:
        dans_tronc, dans_tete = traverse(arm, tronc, tete)
        coude_haut = max(0.0, place(arm, "LeftForeArm").z - place(arm, "LeftArm").z)
        return ((bout(arm, "LeftHand", MAIN) - cible).length
                + 0.7 * (place(arm, "LeftHand") - poignet).length
                + 4.0 * (dans_tronc + dans_tete)
                + 1.5 * coude_haut)

    departs = [[lever, 0.0, 0.0, pli * sens, 0.0, 0.0, 0.0, 0.0, 0.0]
               for pli in (35.0, 75.0, 110.0) for lever in (0.0, -50.0)]
    pose = resoudre(arm, depart, reglages, ecart_de, departs)
    poser_pose(arm, pose)
    ecart = (bout(arm, "LeftHand", MAIN) - cible).length
    dans_tronc, dans_tete = traverse(arm, tronc, tete)
    print("  lunettes   doigts a %.1f cm des montures, poignet a %.1f cm "
          "sous eux" % (ecart * 100.0,
                        (cible.z - place(arm, "LeftHand").z) * 100.0))
    print("  passage    buste %.1f cm, crane %.1f cm, coude %.1f cm sous l epaule"
          % (dans_tronc * 100.0, dans_tete * 100.0,
             (place(arm, "LeftArm").z - place(arm, "LeftForeArm").z) * 100.0))
    if ecart > 0.05:
        print("  ATTENTION  le geste manque la tete de %.1f cm" % (ecart * 100))
    if dans_tronc > 0.02 or dans_tete > 0.02:
        print("  ATTENTION  le bras traverse encore")
    # La tete accompagne un peu : on baisse le menton quand on remonte ses
    # lunettes, on ne reste pas plante droit pendant que la main monte.
    tourner(arm, pose, "Head", TANGAGE, -3.0)
    tourner(arm, pose, "neck", TANGAGE, -2.0)
    return pose


def poser_pose(arm, pose: dict, monter: float = 0.0) -> None:
    appliquer(arm, pose, monter)


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

        appliquer(arm, pose, 0.005 * souffle)
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


def pose_accroupie(arm, debout: dict, descente: float) -> dict:
    """Le bassin descend, ET LES PIEDS RESTENT AU SOL.

    C'est tout le probleme. Baisser le bassin sans rien d'autre enterre les
    pieds de quarante centimetres ; les plier au juge donne un personnage a
    genoux ou en equilibre sur la pointe. On impose donc la descente et on
    CHERCHE les flexions qui laissent les deux pieds exactement ou ils etaient.
    """
    # On DETACHE l'action avant de mesurer : une action encore assignee est
    # reevaluee au prochain rafraichissement et repose le squelette par-dessus
    # ce qu'on vient d'ecrire, ce qui fait mesurer la pose du clip precedent.
    if arm.animation_data is not None:
        arm.animation_data.action = None
    poser_pose(arm, debout)
    ancre = {n: place(arm, n) for n in ("LeftFoot", "RightFoot")}
    vise = place(arm, "Hips").z - descente

    axes = [TANGAGE, ROULIS, LACET]
    leviers = []
    for cote in ("Left", "Right"):
        leviers += [(cote + "UpLeg", axes[0], 120.0),
                    (cote + "UpLeg", axes[1], 35.0),
                    (cote + "Leg", axes[0], 140.0),
                    (cote + "Foot", axes[0], 60.0)]

    def cout(_v) -> float:
        # Le bassin est DEJA descendu — c'est une translation, imposee, pas une
        # inconnue. Plier une cuisse deplace le pied, jamais le bassin : celui-ci
        # est la racine de la hierarchie. Une premiere version demandait au
        # solveur de faire descendre le bassin en pliant les jambes, et il
        # repondait tres correctement en ne pliant rien.
        return sum((place(arm, n) - ancre[n]).length for n in ancre)

    depart = {k: v.copy() for k, v in debout.items()}
    # On penche le buste en avant : un accroupi dos droit est un squat de salle
    # de sport, pas quelqu'un qui se baisse.
    tourner(arm, depart, "Hips", TANGAGE, -14.0)
    tourner(arm, depart, "Spine02", TANGAGE, -10.0)
    tourner(arm, depart, "Spine01", TANGAGE, -6.0)
    tourner(arm, depart, "neck", TANGAGE, 12.0)
    tourner(arm, depart, "Head", TANGAGE, 8.0)

    departs = [[a, 0.0, b, c, a, 0.0, b, c]
               for a, b, c in ((-40.0, 70.0, -25.0), (-70.0, 100.0, -30.0),
                               (40.0, -70.0, 25.0))]
    pose = resoudre(arm, depart, leviers, cout, departs, -descente)
    poser_pose(arm, pose, -descente)
    reste = max((place(arm, n) - ancre[n]).length for n in ancre)
    print("  accroupi   bassin %.2f m -> %.2f m, tete a %.2f m, pieds deplaces "
          "de %.1f cm" % (vise + descente, place(arm, "Hips").z,
                          place(arm, "Head").z, reste * 100.0))
    if reste > 0.06:
        print("  ATTENTION  les pieds glissent de %.1f cm" % (reste * 100.0))
    return pose


def clip_accroupi(arm, debout: dict, duree_s: float = 4.0):
    """Accroupi, immobile. Il respire, mais moins amplement : on se tasse."""
    descente = 0.42
    pose_base = pose_accroupie(arm, debout, descente)
    action = action_neuve("Accroupi")
    arm.animation_data.action = action
    total = int(duree_s * IPS)
    for i in range(total + 1):
        t = i / float(total)
        pose = {k: v.copy() for k, v in pose_base.items()}
        souffle = math.sin(t * math.tau)
        tourner(arm, pose, "Spine01", TANGAGE, 1.0 * souffle)
        tourner(arm, pose, "Head", LACET, 2.0 * math.sin(t * 0.7 * math.tau))
        appliquer(arm, pose, -descente + 0.003 * souffle)
        cle(arm, action, i)
    boucler(action)
    return action


def clip_marche_accroupie(arm, source, debout: dict):
    """Se deplacer accroupi : la marche, jambes pliees et buste baisse.

    On ne refait pas un cycle. On prend celui qui existe et on lui ajoute la
    FLEXION de la pose accroupie, dosee pour rester praticable — un accroupi
    complet ne marche pas, il se traine. La foulee raccourcit d'autant, et
    c'est mesure comme les autres.
    """
    descente = 0.34
    accroupi = pose_accroupie(arm, debout, descente)
    d, f = images_de(source)
    lu = []
    for i in range(d, f + 1):
        poser(arm, source, i)
        lu.append({n: o.rotation_quaternion.copy()
                   for n, o in arm.pose.bones.items()})
        lu[-1]["#loc"] = arm.pose.bones["Hips"].location.copy()

    action = action_neuve("AccroupiMarche")
    arm.animation_data.action = action
    n = len(lu) - 1
    for i, base in enumerate(lu):
        t = i / float(n)
        # 80 % de la flexion accroupie, 20 % du cycle de marche pour les
        # jambes : assez pour que les pieds continuent d'alterner, assez peu
        # pour qu'il reste bas.
        pose = melange({k: v for k, v in base.items() if k != "#loc"},
                       accroupi, 0.55)
        tourner(arm, pose, "Spine02", ROULIS, 2.2 * math.sin(t * math.tau))
        appliquer(arm, pose, -descente * 0.55, base["#loc"])
        cle(arm, action, d + i)
    boucler(action)
    return action


def pose_assise(arm, debout: dict, hauteur: float = 0.46) -> dict:
    """Assis sur un siege : cuisses a l'horizontale, tibias verticaux.

    Ce n'est PAS un accroupi plus bas. Un accroupi garde les pieds sous le
    bassin et le buste en avant ; assis, les pieds sont DEVANT, le buste est
    droit et le poids repose sur le siege. Les deux poses ont l'air proches
    sur le papier et n'ont aucune articulation en commun.

    On impose donc les cuisses et le bassin, et on CHERCHE les genoux et les
    chevilles qui reposent les pieds a plat au sol, devant.
    """
    if arm.animation_data is not None:
        arm.animation_data.action = None
    poser_pose(arm, debout)
    depart_hanche = place(arm, "Hips").z
    descente = depart_hanche - hauteur

    pose = {k: v.copy() for k, v in debout.items()}
    # Les cuisses partent a l'horizontale. C'est la seule chose qu'on ecrit :
    # tout le reste en decoule et se resout.
    for cote in ("Left", "Right"):
        tourner(arm, pose, cote + "UpLeg", TANGAGE, -82.0)
        tourner(arm, pose, cote + "Leg", TANGAGE, 78.0)
    # Le buste droit, legerement en arriere : on est cale dans un fauteuil.
    tourner(arm, pose, "Hips", TANGAGE, 6.0)
    tourner(arm, pose, "Spine01", TANGAGE, 3.0)
    # Les avant-bras remontent sur les accoudoirs.
    tourner(arm, pose, "LeftForeArm", GAUCHE, 62.0)
    tourner(arm, pose, "RightForeArm", GAUCHE, 62.0)
    # ET LES BRAS SE REFERMENT SUR LE CORPS.
    #
    # Ils etaient ecartes de huit degres, ecrits a la main. Huit degres sur un
    # rig ne valent pas huit degres sur un autre — l'axe qui ECARTE un bras
    # depend de l'orientation que le rig a donnee a l'os — et chez Tuco ca
    # donnait un homme assis les bras en croix, ce qui lit comme une pose en T
    # ratee plutot que comme un chef de cartel dans son fauteuil.
    #
    # On BALAIE l'angle jusqu'a une distance main-hanche mesuree, exactement
    # comme pour la pose debout. Un peu plus large que debout : assis, les
    # coudes reposent sur les accoudoirs, ils ne pendent pas le long du corps.
    serrer_le_bras(arm, pose, "LeftArm", "LeftHand", "LeftUpLeg", 0.30)
    serrer_le_bras(arm, pose, "RightArm", "RightHand", "RightUpLeg", 0.30)

    poser_pose(arm, pose, -descente)
    # Les pieds doivent finir AU SOL et devant. On les vise la ou ils sont
    # tombes, ramenes a z = 0 : c'est la seule contrainte qui compte, un
    # personnage assis dont les pieds pendent dans le vide se voit tout de
    # suite.
    ancre = {}
    for n in ("LeftFoot", "RightFoot"):
        p = place(arm, n)
        p.z = hauteur * 0.09
        ancre[n] = p

    axes = [TANGAGE, ROULIS, LACET]
    leviers = []
    for cote in ("Left", "Right"):
        leviers += [(cote + "Leg", axes[0], 60.0),
                    (cote + "Foot", axes[0], 55.0),
                    (cote + "UpLeg", axes[0], 30.0)]

    def cout(_v) -> float:
        return sum((place(arm, n) - ancre[n]).length for n in ancre)

    departs = [[a, b, 0.0, a, b, 0.0]
               for a, b in ((0.0, 0.0), (20.0, -15.0), (-20.0, 15.0))]
    pose = resoudre(arm, pose, leviers, cout, departs, -descente)
    poser_pose(arm, pose, -descente)
    reste = max((place(arm, n) - ancre[n]).length for n in ancre)
    print("  assis      bassin %.2f m -> %.2f m, tete a %.2f m, pieds a %.2f m "
          "(ecart %.1f cm)"
          % (depart_hanche, place(arm, "Hips").z, place(arm, "Head").z,
             place(arm, "LeftFoot").z, reste * 100.0))
    pose["#descente"] = descente
    return pose


def clip_assis(arm, debout: dict, duree_s: float = 5.0):
    """Assis, et vivant. Il respire, et il bouge la tete de temps en temps."""
    base = pose_assise(arm, debout)
    descente = base.pop("#descente")
    action = action_neuve("Assis")
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    total = int(duree_s * IPS)
    for i in range(total + 1):
        t = i / float(total)
        pose = {k: v.copy() for k, v in base.items()}
        souffle = math.sin(t * duree_s / 4.0 * math.tau)
        tourner(arm, pose, "Spine01", TANGAGE, 1.1 * souffle)
        tourner(arm, pose, "Head", LACET, 3.2 * math.sin(t * 0.8 * math.tau))
        tourner(arm, pose, "Head", TANGAGE, 1.4 * math.cos(t * 1.3 * math.tau))
        appliquer(arm, pose, -descente + 0.004 * souffle)
        cle(arm, action, i)
    boucler(action)
    return action


def clip_saut(arm, debout: dict, duree_s: float = 0.8):
    """En l'air. Jambes repliees a la montee, tendues a la retombee.

    Le clip tourne a l'horloge et se rejoue a chaque saut. Il est plus long que
    la plupart des sauts : on n'en voit alors que le debut, ce qui est
    exactement ce qu'on veut — l'impulsion.
    """
    action = action_neuve("Saut")
    arm.animation_data.action = action
    total = int(duree_s * IPS)
    for i in range(total + 1):
        t = i / float(total)
        pose = {k: v.copy() for k, v in debout.items()}
        # Les genoux montent puis redescendent ; les bras partent en arriere a
        # l'impulsion et reviennent devant.
        repli = math.sin(min(1.0, t * 1.4) * math.pi)
        tourner(arm, pose, "LeftUpLeg", TANGAGE, -52.0 * repli)
        tourner(arm, pose, "RightUpLeg", TANGAGE, -34.0 * repli)
        tourner(arm, pose, "LeftLeg", TANGAGE, 62.0 * repli)
        tourner(arm, pose, "RightLeg", TANGAGE, 38.0 * repli)
        tourner(arm, pose, "LeftArm", TANGAGE, 40.0 * repli)
        tourner(arm, pose, "RightArm", TANGAGE, 26.0 * repli)
        tourner(arm, pose, "Spine01", TANGAGE, -8.0 * repli)
        appliquer(arm, pose)
        cle(arm, action, i)
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

        appliquer(arm, pose, 0.0, base["#loc"])
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


def _copier_les_clips(arm, source: Path, fichier: Path) -> None:
    """Donne a ce personnage les animations d'un autre.

    Ca ne marche que parce que les squelettes sont IDENTIQUES — memes os,
    memes noms. Les courbes d'animation ne designent pas des os par un
    identifiant mais par un chemin, `pose.bones["Hips"].rotation_quaternion` :
    a noms egaux, elles s'appliquent telles quelles.

    C'est le cas de Jesse et Tuco, rigges sur le meme squelette que Walter. Ils
    arrivent avec un unique clip qui est une pose en T, ce qui donne des
    personnages bras ecartes plantes derriere leur bureau. Leur recopier le
    repos de Walter coute une commande ; leur fabriquer le leur reviendrait a
    refaire le meme travail sur les memes os.
    """
    if not source.exists():
        raise SystemExit("source introuvable : %s" % source)

    # ON PURGE D'ABORD LES CLIPS DEJA COPIES.
    #
    # Blender ne remplace pas une action homonyme, il la renomme : un second
    # transfert produit « Repos.001 » et le jeu, qui cherche « Repos », ne
    # trouve plus rien. Le personnage redevient une pose en T sans qu'aucune
    # erreur ne le dise.
    #
    # On garde le clip d'origine du fichier — c'est le seul que le modele
    # possede en propre.
    purges = [a for a in bpy.data.actions
              if "baselayer" not in a.name and "clip0" not in a.name]
    for a in purges:
        bpy.data.actions.remove(a)
    if purges:
        print("  %-12s %d clip(s) precedents remplaces"
              % ("purge", len(purges)))

    avant = {x.name for x in bpy.data.actions}
    bpy.ops.import_scene.gltf(filepath=str(source))
    neuves = [x for x in bpy.data.actions if x.name not in avant]
    if not neuves:
        raise SystemExit("%s n'apporte aucune animation" % source.name)

    # L'armature importee a servi de vehicule aux actions ; on la jette, les
    # actions restent. Sans ca on exporte deux personnages superposes.
    # L'ECHELLE DES TRANSLATIONS, et c'est le piege du transfert.
    #
    # Une rotation se recopie telle quelle d'un squelette a l'autre : elle
    # n'a pas d'unite. Une TRANSLATION en a une — celle de l'armature — et les
    # deux modeles n'ont pas ete mis a la meme echelle en arrivant. Le bassin
    # que le clip « Assis » fait descendre de cinquante-neuf centimetres chez
    # Walter descendait d'un centimetre chez Tuco, qui restait donc debout au
    # milieu de son bureau EN JOUANT L'ANIMATION ASSISE. Rien ne le signalait :
    # le clip existait, il tournait, il ne faisait simplement presque rien.
    source_arm = next((o for o in bpy.data.objects
                       if o.type == "ARMATURE" and o != arm), None)
    facteur = 1.0
    if source_arm is not None:
        e_source = source_arm.matrix_world.to_scale().z
        e_cible = arm.matrix_world.to_scale().z
        if e_cible > 1e-9:
            facteur = e_source / e_cible

    intrus = [o for o in bpy.data.objects
              if o != arm and (o.type == "ARMATURE"
                               or (o.parent is not None and o.parent != arm))]
    for o in intrus:
        bpy.data.objects.remove(o, do_unlink=True)

    if abs(facteur - 1.0) > 1e-6:
        touchees = 0
        for act in neuves:
            for c in courbes(act):
                if not c.data_path.endswith(".location"):
                    continue
                for k in c.keyframe_points:
                    k.co.y *= facteur
                    k.handle_left.y *= facteur
                    k.handle_right.y *= facteur
                touchees += 1
        print("  %-12s x %.4f sur %d courbe(s) de position"
              % ("echelle", facteur, touchees))

    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = None
    gardees = []
    for act in neuves:
        # On ne reprend PAS le clip d'origine du fichier source s'il n'est
        # qu'une pose : ce qui nous interesse, ce sont les clips fabriques.
        if "baselayer" in act.name or "clip0" in act.name:
            continue
        act.use_fake_user = True
        ranger(arm, act)
        gardees.append(act.name)

    print("")
    print("  %-12s %s" % ("copies de", source.name))
    print("  %-12s %s" % ("clips", ", ".join(gardees)))

    # ON N'EXPORTE PAS ICI. Les clips transferes servent de MATIERE : la
    # fabrication normale reprend juste apres et refait Repos, Assis, Accroupi
    # et les autres SUR CE RIG-CI.
    #
    # C'est indispensable. Une rotation se recopie d'un squelette a l'autre sans
    # rien perdre ; une TRANSLATION est exprimee dans le repere de l'os, propre
    # a chaque rig. Mesure faite : le bassin que « Assis » fait descendre de
    # cinquante-neuf centimetres chez Walter REMONTAIT de trente-six chez Tuco,
    # qui restait donc plante debout en jouant l'animation assise. Aucune
    # erreur, aucun avertissement : le clip existait et tournait.
    #
    # Seuls Walking et Running survivent au transfert — ce sont les seuls dont
    # on a besoin, et la fabrication recalcule tout le reste dans le bon repere.


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

    if a.depuis:
        _copier_les_clips(arm, racine / a.depuis, fichier)

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

    debout = pose_relachee(arm, source)
    nouvelles = (clip_repos(arm, source), clip_marche(arm, source),
                 clip_accroupi(arm, debout),
                 clip_marche_accroupie(arm, source, debout),
                 clip_saut(arm, debout), clip_assis(arm, debout))
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
        marque = ""
        if nouvelle.name in ("Marche", "AccroupiMarche"):
            marque = ", foulee %.2f m" % foulee_mesuree(arm, nouvelle)
        print("  %-14s %3d images, %.1f s, la tete parcourt %.0f mm%s"
              % (nouvelle.name, f - d, (f - d) / float(IPS),
                 (maxi - mini).length * 1000.0, marque))
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
    for nom in ("Repos", "Marche", "Accroupi", "AccroupiMarche", "Saut", "Assis"):
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
