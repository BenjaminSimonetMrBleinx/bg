#!/usr/bin/env python3
"""Extrait le profil d'un vehicule depuis une PHOTO, et en deduit ses sections.

    blender -b -P outils/tracer_silhouette.py -- \\
        --image "references/CarJesse2.jpg" --longueur 5.10

POURQUOI CET OUTIL EXISTE.

Jusqu'ici je posais les sections d'une carrosserie a la main : « a 1,80 m du
nez, le toit est a 98 cm ». Ce sont des estimations, corrigees par
allers-retours entre un rendu et mon jugement. Ca converge lentement et ca
plafonne — c'est du modelage a l'aveugle.

La photo, elle, SAIT. Le contour superieur d'une voiture de profil est
exactement la courbe qu'on essaie de reproduire : ligne de capot, montee du
pare-brise, pavillon, chute de lunette, coffre. On la lit, on la met a
l'echelle, et les sections en tombent.

CE QU'ON EXTRAIT, ET CE QU'ON N'EXTRAIT PAS

  Le contour DU DESSUS, oui. C'est lui qui fait la silhouette, et il est
  net : la carrosserie est coloree, le ciel ne l'est pas.

  Le dessous, non. Sous la voiture il y a l'ombre, les roues, le sol : le
  seuil de couleur n'y veut plus rien dire. Le bas de caisse se pose a la
  main, et c'est un seul nombre au lieu de vingt.

  La largeur, non plus — une photo de profil n'en dit rien. Il faudrait une
  vue de dessus. La largeur reste donc parametree.

LA LECTURE DE L'IMAGE PASSE PAR BLENDER, qui sait ouvrir un JPEG. C'est la
seule raison pour laquelle ce script tourne dedans : aucune dependance a
installer sur le poste de Guillaume, comme le reste du projet.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Trace un profil depuis une photo")
    ap.add_argument("--image", required=True)
    ap.add_argument("--longueur", type=float, default=5.10,
                    help="longueur reelle du vehicule, en metres")
    ap.add_argument("--hauteur", type=float, default=0.0,
                    help="hauteur reelle au toit ; 0 = deduire de la longueur")
    ap.add_argument("--sections", type=int, default=24)
    ap.add_argument("--redresser", default="",
                    help="parts capot,habitacle,coffre — ex. 40,32,28")
    ap.add_argument("--sortie", default=".tmp/profil.json")
    # Le masque de couleur. Par defaut : ce qui tire franchement vers le rouge.
    ap.add_argument("--teinte", default="rouge",
                    choices=["rouge", "bleu", "clair"])
    ap.add_argument("--seuil", type=float, default=1.35,
                    help="combien de fois le canal dominant doit depasser les autres")
    return ap.parse_args(argv)


def charger(chemin: Path) -> tuple:
    """Rend (largeur, hauteur, pixels) — pixels en RGBA, lignes du BAS vers
    le haut, comme Blender les stocke."""
    img = bpy.data.images.load(str(chemin))
    l, h = img.size
    px = list(img.pixels)          # copie : l'acces direct est tres lent
    return l, h, px


def masque(l: int, h: int, px: list, teinte: str, seuil: float) -> list:
    """Vrai la ou le pixel appartient a la carrosserie.

    On travaille sur les RAPPORTS entre canaux, jamais sur la luminosite : une
    photo a des ombres, et un rouge a l'ombre reste un rouge. Un seuil sur la
    luminosite, lui, decoupe la voiture en deux au milieu du flanc.
    """
    dedans = [False] * (l * h)
    for y in range(h):
        for x in range(l):
            i = (y * l + x) * 4
            r, v, b = px[i], px[i + 1], px[i + 2]
            if teinte == "rouge":
                ok = r > 0.16 and r > v * seuil and r > b * seuil
            elif teinte == "bleu":
                ok = b > 0.16 and b > r * seuil and b > v * seuil
            else:
                ok = r > 0.55 and v > 0.55 and b > 0.55
            dedans[y * l + x] = ok
    return dedans


def plus_grande_tache(l: int, h: int, dedans: list) -> list:
    """Ne garde que la plus grosse region connexe.

    UNE PHOTO CONTIENT D'AUTRES OBJETS DE LA MEME COULEUR : sur la reference,
    trois carcasses rouges de casse au second plan. Sans ce tri, le contour
    saute de la voiture a une epave et la silhouette devient un accident de
    montagne. On garde la tache la plus grande, qui est le sujet.
    """
    vu = [False] * (l * h)
    meilleure: list = []
    for depart in range(l * h):
        if not dedans[depart] or vu[depart]:
            continue
        pile = [depart]
        vu[depart] = True
        tache = []
        while pile:
            p = pile.pop()
            tache.append(p)
            px_, py_ = p % l, p // l
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = px_ + dx, py_ + dy
                if 0 <= nx < l and 0 <= ny < h:
                    q = ny * l + nx
                    if dedans[q] and not vu[q]:
                        vu[q] = True
                        pile.append(q)
        if len(tache) > len(meilleure):
            meilleure = tache
    garde = [False] * (l * h)
    for p in meilleure:
        garde[p] = True
    return garde


def contour_haut(l: int, h: int, dedans: list) -> dict:
    """Pour chaque colonne, le pixel le plus HAUT de la carrosserie."""
    haut = {}
    for x in range(l):
        for y in range(h - 1, -1, -1):
            if dedans[y * l + x]:
                haut[x] = y
                break
    return haut


def lisser(valeurs: list, passes: int = 3) -> list:
    """Moyenne glissante. Une photo a du bruit, un reflet, une antenne : sans
    lissage, la silhouette herisse."""
    v = list(valeurs)
    for _ in range(passes):
        v = [v[0]] + [(v[i - 1] + 2 * v[i] + v[i + 1]) / 4.0
                      for i in range(1, len(v) - 1)] + [v[-1]]
    return v


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    chemin = Path(a.image)
    if not chemin.is_absolute():
        chemin = racine / chemin
    if not chemin.exists():
        raise SystemExit("introuvable : %s" % chemin)

    l, h, px = charger(chemin)
    dedans = masque(l, h, px, a.teinte, a.seuil)
    combien = sum(1 for d in dedans if d)
    if combien < 200:
        raise SystemExit("le masque ne retient que %d pixels : mauvaise teinte "
                         "ou mauvais seuil" % combien)
    dedans = plus_grande_tache(l, h, dedans)

    haut = contour_haut(l, h, dedans)
    if not haut:
        raise SystemExit("aucun contour")
    x0, x1 = min(haut), max(haut)
    largeur_px = x1 - x0
    bas_px = min(haut.values())

    # DEUX ECHELLES, UNE PAR AXE, ET C'EST LA CORRECTION QUI COMPTE.
    #
    # Une photo de trois quarts RACCOURCIT la longueur : les 5,10 m du
    # vehicule tiennent sur moins de pixels qu'une vraie vue de profil. Une
    # echelle unique deduite de la longueur gonfle donc toutes les hauteurs —
    # premiere mesure sur la reference : un toit annonce a 1,59 m pour une
    # voiture qui en fait 1,37.
    #
    # On connait les deux dimensions reelles, alors on normalise les deux
    # axes separement. Ce n'est pas une correction de perspective en bonne et
    # due forme — il faudrait les points de fuite — mais ca redresse
    # l'essentiel, qui est le RAPPORT entre la longueur et la hauteur.
    colonnes = [haut.get(x, bas_px) for x in range(x0, x1 + 1)]
    colonnes = lisser(colonnes, 4)

    # Les extremites sont peu fiables : ombre, pare-chocs coupe, reflet. On
    # ecarte ce qui est sous le cinquieme de la hauteur, et on recadre dessus.
    plafond = max(colonnes) - bas_px
    utiles = [i for i, c in enumerate(colonnes) if (c - bas_px) > plafond * 0.20]
    if len(utiles) > 10:
        colonnes = colonnes[utiles[0]:utiles[-1] + 1]

    metre_par_px_x = a.longueur / max(1, len(colonnes) - 1)
    haut_px = max(colonnes) - bas_px
    metre_par_px_z = ((a.hauteur / haut_px) if (a.hauteur > 0 and haut_px > 0)
                      else metre_par_px_x)

    # REDRESSER LA REPARTITION DES LONGUEURS.
    #
    # Une photo de trois quarts ne fausse pas seulement l'echelle globale :
    # elle ecrase la partie LOINTAINE et etire la proche. Sur la reference,
    # le tracé brut donne un capot de 1,1 m et un habitacle de 2,4 m, alors
    # que la Monte Carlo a exactement l'inverse.
    #
    # La photo reste la source de ce qu'elle sait vraiment : la FORME des
    # transitions et le RAPPORT des hauteurs. Les longueurs, elles, viennent
    # des proportions connues du modele. On repere donc les trois plateaux —
    # capot bas, pavillon haut, coffre — et on les redistribue.
    if a.redresser:
        parts = [float(x) for x in a.redresser.split(",")]
        total = sum(parts)
        parts = [x / total for x in parts]
        bas_ref = min(colonnes)
        plafond2 = max(colonnes)
        mi = bas_ref + (plafond2 - bas_ref) * 0.55
        hauts = [i for i, c in enumerate(colonnes) if c > mi]
        if len(hauts) > 4:
            d_hab, f_hab = hauts[0], hauts[-1]
            morceaux = [colonnes[:d_hab], colonnes[d_hab:f_hab + 1],
                        colonnes[f_hab + 1:]]
            neuf = []
            for morceau, part in zip(morceaux, parts):
                combien = max(2, int(round(part * len(colonnes))))
                if not morceau:
                    continue
                for k in range(combien):
                    t = k / (combien - 1.0)
                    neuf.append(morceau[int(t * (len(morceau) - 1))])
            colonnes = lisser(neuf, 2)
            print("  redresse      capot %.0f%%, habitacle %.0f%%, coffre %.0f%%"
                  % (parts[0] * 100, parts[1] * 100, parts[2] * 100))

    sections = []
    for k in range(a.sections):
        t = k / (a.sections - 1.0)
        xi = int(t * (len(colonnes) - 1))
        y = (t - 0.5) * a.longueur                      # -L/2 a +L/2
        z = (colonnes[xi] - bas_px) * metre_par_px_z
        sections.append([round(y, 3), round(z, 3)])

    fiche = racine / a.sortie
    fiche.parent.mkdir(parents=True, exist_ok=True)
    fiche.write_text(json.dumps({
        "image": chemin.name,
        "longueur": a.longueur,
        "hauteur_lue": round(max(z for _, z in sections), 3),
        "sections": sections,
    }, indent=1), encoding="utf-8")

    print("")
    print("profil   %s" % chemin.name)
    print("  masque        %d pixels retenus" % combien)
    print("  etendue       %d px de long, %.4f m/px en long, %.4f en haut"
          % (largeur_px, metre_par_px_x, metre_par_px_z))
    print("  hauteur lue   %.2f m pour %.2f m de long"
          % (max(z for _, z in sections), a.longueur))
    print("")
    for y, z in sections:
        barre = "#" * max(1, int(z * 26))
        print("   y %+6.2f   z %5.2f  %s" % (y, z, barre))
    print("")
    print("  -> %s" % fiche)


if __name__ == "__main__":
    main()
