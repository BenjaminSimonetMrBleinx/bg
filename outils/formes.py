#!/usr/bin/env python3
"""Les formes qui donnent de la PROFONDEUR a un batiment.

Partage par gen_ville.py et gen_banc_graphique.py :

    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from formes import mur_perce, embrasure

CE QUI FAIT « MINECRAFT », ET CE QUI LE DEFAIT.

Retour de Benjamin, 31/07/2026 : « tes modeles sont tres cubiques, ca fait
presque Minecraft. » C'etait exact, et la cause n'etait pas le nombre de faces
— c'est que TOUT ETAIT DANS LE MEME PLAN. Une porte et des fenetres peintes
sur une face plate ne portent aucune ombre : il ne reste qu'un cube colorie.

La maison qui a leve l'objection fait 169 faces, soit MOINS que celle qu'elle
remplace. Le realisme n'est pas venu des polygones, il est venu de la
profondeur. D'ou ce module, et l'ordre de ce qui rapporte :

  1. CREUSER LES OUVERTURES. Une fenetre en retrait de douze centimetres
     fabrique quatre bandes d'ombre qui suivent le soleil. C'est le poste le
     plus rentable de tout le projet graphique.
  2. CASSER LE VOLUME. Un corps principal, une aile en avant, une entree en
     retrait. Trois profondeurs suffisent a supprimer la silhouette de cube.
  3. HABILLER LES ARETES. Soubassement, linteau, appui de fenetre, planche de
     rive : chacun est une arete de plus qui accroche la lumiere la ou il n'y
     avait qu'un aplat.

Les fonctions prennent n'importe quel objet ayant une methode `face(points,
uvs)` : les deux generateurs ont leur propre classe Maillage, et elles se
ressemblent assez pour que ces formes marchent avec l'une comme avec l'autre.
"""

from __future__ import annotations

import math


def mur_perce(m, p0, p1, z0: float, z1: float, ouvertures, tuile: float = 2.6):
    """Un mur plein, avec de VRAIS trous.

    p0 et p1 sont les deux extremites du mur au sol, en (x, y). Chaque
    ouverture est (debut, fin) le long du mur et (bas, haut) en hauteur.

    On decoupe le mur sur la grille formee par les bords des ouvertures et on
    saute les cellules qui tombent dedans. C'est la methode la plus simple qui
    donne un trou VRAI plutot qu'un rectangle peint, et elle ne suppose rien du
    nombre d'ouvertures ni de leur alignement.
    """
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    longueur = math.hypot(dx, dy)
    if longueur < 1e-6:
        return
    ux, uy = dx / longueur, dy / longueur

    def point(t, z):
        return (p0[0] + ux * t, p0[1] + uy * t, z)

    coupes_t = sorted({0.0, longueur} | {o[0] for o in ouvertures}
                      | {o[1] for o in ouvertures})
    coupes_z = sorted({z0, z1} | {o[2] for o in ouvertures}
                      | {o[3] for o in ouvertures})
    for i in range(len(coupes_t) - 1):
        for j in range(len(coupes_z) - 1):
            ta, tb = coupes_t[i], coupes_t[i + 1]
            za, zb = coupes_z[j], coupes_z[j + 1]
            if tb - ta < 1e-4 or zb - za < 1e-4:
                continue
            if any(o[0] - 1e-4 <= ta and tb <= o[1] + 1e-4
                   and o[2] - 1e-4 <= za and zb <= o[3] + 1e-4
                   for o in ouvertures):
                continue
            m.face([point(ta, za), point(tb, za), point(tb, zb), point(ta, zb)],
                   [(ta / tuile, za / tuile), (tb / tuile, za / tuile),
                    (tb / tuile, zb / tuile), (ta / tuile, zb / tuile)])


def embrasure(m, fond, p0, p1, t0: float, t1: float, z0: float, z1: float,
              profondeur: float, normale) -> None:
    """Les quatre retours d'une ouverture creusee, plus son fond.

    C'EST CE QUI FABRIQUE L'OMBRE. Sans ces quatre bandes, une fenetre est un
    trou noir dans un mur plat ; avec elles, elle a une epaisseur, un rebord
    qui prend le soleil et un cote qui reste dans l'ombre. Le meme mur passe de
    « cube colorie » a « facade ».

    `fond` recoit la vitre ou le panneau de porte, `normale` pointe vers
    l'exterieur du mur.
    """
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    longueur = math.hypot(dx, dy)
    if longueur < 1e-6:
        return
    ux, uy = dx / longueur, dy / longueur
    nx, ny = normale

    def pt(t, z, prof):
        return (p0[0] + ux * t + nx * prof, p0[1] + uy * t + ny * prof, z)

    d = -profondeur
    m.face([pt(t0, z0, 0), pt(t0, z0, d), pt(t0, z1, d), pt(t0, z1, 0)],
           [(0, 0), (0.4, 0), (0.4, 1), (0, 1)])
    m.face([pt(t1, z0, d), pt(t1, z0, 0), pt(t1, z1, 0), pt(t1, z1, d)],
           [(0, 0), (0.4, 0), (0.4, 1), (0, 1)])
    m.face([pt(t0, z1, 0), pt(t0, z1, d), pt(t1, z1, d), pt(t1, z1, 0)],
           [(0, 0), (0.4, 0), (0.4, 1), (0, 1)])
    m.face([pt(t0, z0, d), pt(t0, z0, 0), pt(t1, z0, 0), pt(t1, z0, d)],
           [(0, 0), (0.4, 0), (0.4, 1), (0, 1)])
    fond.face([pt(t0, z0, d), pt(t1, z0, d), pt(t1, z1, d), pt(t0, z1, d)],
              [(0, 0), (1, 0), (1, 1), (0, 1)])
