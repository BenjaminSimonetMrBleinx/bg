#!/usr/bin/env python3
"""Le banc de comparaison graphique : trois maisons et trois voitures.

    blender -b -P outils/gen_banc_graphique.py

Produit six modeles et un fichier de placement. Le jeu les pose cote a cote
dans le desert, ou l'on peut tourner autour et decider.

POURQUOI UN BANC PLUTOT QU'UNE REFONTE.

« Plus beau » ne se discute pas dans le vide : il se regarde. Trois niveaux
poses cote a cote repondent en une image a des questions qui prendraient une
soiree de discussion — est-ce que ca vaut le coup, ou est-ce qu'on ne voit pas
la difference en roulant ?

CE QUI SEPARE LES TROIS NIVEAUX, dans l'ordre de ce que l'oeil remarque :

  1. LA SILHOUETTE. C'est le poste le plus rentable. Un toit qui deborde, un
     auvent, une cheminee, un pare-chocs qui sort : ce sont des formes qu'on
     lit de loin, avant toute texture. Une boite reste une boite quelle que
     soit son image.
  2. LE GALBE. Une voiture faite de boites est reconnaissable comme telle a
     cinquante metres. Les niveaux 2 et 3 la construisent par SECTIONS
     TRANSVERSALES reliees entre elles — capot qui plonge, pavillon qui
     retrecit — pour un cout en faces a peine superieur.
  3. LA TEXTURE. 256 px au lieu de 128, et surtout des variations LENTES —
     un degrade, une trainee de salissure, une ligne de caisse — parce que le
     detail fin disparait au filtrage et a la resolution du jeu.
  4. LA MATIERE. Vitrage, tole, pneu, jante : des materiaux distincts au lieu
     d'un seul. C'est ce qui empeche une voiture d'avoir l'air moulee d'un
     bloc.

Le budget PS2 reste la mesure : le niveau 3 vise ce qu'une PS2 affichait pour
un vehicule de heros, pas ce qu'une carte moderne encaisse.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh

SORTIE = "game/assets/decor"


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Banc de comparaison graphique")
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default=SORTIE)
    return ap.parse_args(argv)


def materiau(nom: str, dossier: Path):
    if nom in bpy.data.materials:
        return bpy.data.materials[nom]
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
    png = dossier / f"{nom}.png"
    if not png.exists():
        raise SystemExit("texture absente : %s" % png)
    img = bpy.data.images.load(str(png), check_existing=True)
    img.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


class Maillage:
    def __init__(self, nom: str, mat):
        self.mesh = bpy.data.meshes.new(nom)
        self.obj = bpy.data.objects.new(nom, self.mesh)
        bpy.context.collection.objects.link(self.obj)
        self.mesh.materials.append(mat)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def face(self, points, uvs=None) -> None:
        verts = [self.bm.verts.new(p) for p in points]
        f = self.bm.faces.new(verts)
        if uvs is None:
            uvs = [(0, 0), (1, 0), (1, 1), (0, 1)][:len(points)]
        for boucle, coord in zip(f.loops, uvs):
            boucle[self.uv].uv = coord

    def boite(self, x0, y0, z0, x1, y1, z1, tuile=1.0) -> None:
        lx, ly, lz = (x1 - x0) / tuile, (y1 - y0) / tuile, (z1 - z0) / tuile
        c = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        for idx, (u, v) in [
            ((0, 3, 2, 1), (lx, ly)), ((4, 5, 6, 7), (lx, ly)),
            ((0, 1, 5, 4), (lx, lz)), ((1, 2, 6, 5), (ly, lz)),
            ((2, 3, 7, 6), (lx, lz)), ((3, 0, 4, 7), (ly, lz)),
        ]:
            self.face([c[i] for i in idx], [(0, 0), (u, 0), (u, v), (0, v)])

    def prisme(self, cx, cy, z0, z1, rb, rh, cotes=8, tuile=1.0) -> None:
        bas, haut = [], []
        for k in range(cotes):
            a = math.tau * k / cotes
            bas.append((cx + math.cos(a) * rb, cy + math.sin(a) * rb, z0))
            haut.append((cx + math.cos(a) * rh, cy + math.sin(a) * rh, z1))
        for k in range(cotes):
            j = (k + 1) % cotes
            u0, u1 = k / cotes * tuile, (k + 1) / cotes * tuile
            self.face([bas[k], bas[j], haut[j], haut[k]],
                      [(u0, 0), (u1, 0), (u1, tuile), (u0, tuile)])
        self.face(haut, [(0.5 + 0.5 * math.cos(math.tau * k / cotes),
                          0.5 + 0.5 * math.sin(math.tau * k / cotes))
                         for k in range(cotes)])
        self.face(bas[::-1], [(0.5, 0.5)] * cotes)

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


# ------------------------------------------------------------------ maisons


def maison_1(mats) -> int:
    """Niveau 1 : ce que la ville pose aujourd'hui.

    Un corps, un toit plat qui deborde, et une porte et des fenetres POSEES
    devant le mur — pas creusees. Quatorze faces.
    """
    m = Maillage("Corps", mats["crepi"])
    m.boite(-4.5, -3.5, 0.0, 4.5, 3.5, 3.0, 3.2)
    total = m.finir()
    t = Maillage("Toit", mats["toit"])
    t.boite(-4.8, -3.8, 3.0, 4.8, 3.8, 3.22, 3.0)
    total += t.finir()
    p = Maillage("Porte", mats["porte"])
    p.face([(-0.5, -3.51, 0.0), (0.5, -3.51, 0.0),
            (0.5, -3.51, 2.05), (-0.5, -3.51, 2.05)][::-1])
    total += p.finir()
    f = Maillage("Fenetres", mats["fenetre_maison"])
    for x in (-2.6, 2.6):
        f.face([(x - 0.7, -3.51, 1.05), (x + 0.7, -3.51, 1.05),
                (x + 0.7, -3.51, 2.15), (x - 0.7, -3.51, 2.15)][::-1])
    return total + f.finir()


def _pignon(m, x, y0, y1, z_mur, z_faite, sens) -> None:
    """Le triangle sous un toit a deux pentes."""
    m.face([(x, y0, z_mur), (x, y1, z_mur), (x, (y0 + y1) / 2.0, z_faite)]
           [::sens], [(0, 0), (1, 0), (0.5, 1)])


def maison_2(mats) -> int:
    """Niveau 2 : la silhouette.

    Toit a deux pentes, auvent d'entree sur deux poteaux, cheminee,
    encadrements de fenetres en relief, marche de seuil. Rien de fin : que des
    formes qu'on lit a trente metres, et c'est exactement le but.
    """
    m = Maillage("Corps", mats["banc_mur"])
    m.boite(-4.5, -3.5, 0.0, 4.5, 3.5, 2.9, 2.2)
    _pignon(m, -4.5, -3.5, 3.5, 2.9, 4.1, 1)
    _pignon(m, 4.5, -3.5, 3.5, 2.9, 4.1, -1)
    total = m.finir()

    t = Maillage("Toit", mats["banc_toit"])
    for cote in (-1, 1):
        t.face([(-4.8, cote * 3.8, 2.78), (4.8, cote * 3.8, 2.78),
                (4.8, 0.0, 4.15), (-4.8, 0.0, 4.15)][::cote],
               [(0, 0), (4.6, 0), (4.6, 2.0), (0, 2.0)])
    total += t.finir()

    a = Maillage("Auvent", mats["banc_toit"])
    a.boite(-1.9, -5.2, 2.35, 1.9, -3.4, 2.5, 2.0)
    total += a.finir()
    po = Maillage("Poteaux", mats["banc_mur"])
    for x in (-1.7, 1.55):
        po.boite(x, -5.05, 0.0, x + 0.15, -4.9, 2.35, 1.0)
    po.boite(-2.1, -5.4, 0.0, 2.1, -3.5, 0.14, 1.6)      # perron
    total += po.finir()

    c = Maillage("Cheminee", mats["banc_mur"])
    c.boite(2.2, 0.6, 3.2, 2.9, 1.3, 4.9, 1.0)
    total += c.finir()

    e = Maillage("Encadrements", mats["banc_mur"])
    for x in (-2.6, 2.6):
        for dx, dy in ((-0.85, 0.0), (0.75, 0.0)):
            e.boite(x + dx, -3.62, 0.95, x + dx + 0.10, -3.5, 2.28, 1.0)
        e.boite(x - 0.85, -3.62, 2.18, x + 0.85, -3.5, 2.28, 1.0)
        e.boite(x - 0.85, -3.62, 0.95, x + 0.85, -3.5, 1.05, 1.0)
    total += e.finir()

    p = Maillage("Porte", mats["porte"])
    p.boite(-0.55, -3.58, 0.0, 0.55, -3.5, 2.1, 1.0)
    total += p.finir()
    f = Maillage("Fenetres", mats["banc_vitre"])
    for x in (-2.6, 2.6):
        f.face([(x - 0.78, -3.55, 1.05), (x + 0.78, -3.55, 1.05),
                (x + 0.78, -3.55, 2.18), (x - 0.78, -3.55, 2.18)][::-1])
    return total + f.finir()


def maison_3(mats) -> int:
    """Niveau 3 : le detail qui se voit de pres.

    Tout le niveau 2, plus ce qu'on remarque en passant devant : volets,
    appuis, gouttiere, climatiseur, antenne, et un bardage qui casse la facade
    en deux au lieu d'un aplat de quatre metres.
    """
    total = maison_2(mats)

    v = Maillage("Volets", mats["porte"])
    for x in (-2.6, 2.6):
        for dx in (-1.35, 0.85):
            v.boite(x + dx, -3.68, 1.0, x + dx + 0.48, -3.6, 2.24, 0.8)
    total += v.finir()

    g = Maillage("Gouttiere", mats["metal_sombre"])
    for cote in (-1, 1):
        g.boite(-4.85, cote * 3.9 - 0.09, 2.62, 4.85, cote * 3.9 + 0.09,
                2.80, 2.0)
    g.boite(4.5, -3.99, 0.0, 4.68, -3.81, 2.7, 1.0)      # descente
    total += g.finir()

    b = Maillage("Bandeau", mats["banc_mur"])
    b.boite(-4.62, -3.62, 1.02, 4.62, 3.62, 1.20, 2.0)   # ceinture de facade
    b.boite(-4.62, -3.62, 0.0, 4.62, 3.62, 0.34, 2.0)    # soubassement
    total += b.finir()

    ap = Maillage("Appuis", mats["banc_mur"])
    for x in (-2.6, 2.6):
        ap.boite(x - 0.95, -3.74, 0.86, x + 0.95, -3.5, 0.98, 1.0)
    total += ap.finir()

    cl = Maillage("Climatiseur", mats["metal"])
    cl.boite(-3.6, 2.6, 0.0, -2.9, 3.3, 0.72, 0.8)
    total += cl.finir()

    an = Maillage("Antenne", mats["metal_sombre"])
    an.boite(-1.2, 0.9, 4.1, -1.12, 0.98, 5.6, 1.0)
    for k in range(3):
        z = 4.9 + k * 0.28
        an.boite(-1.7, 0.93, z, -0.62, 0.95, z + 0.05, 1.0)
    return total + an.finir()


# ----------------------------------------------------------------- voitures


def coque(m, sections, tuile=1.0) -> None:
    """Une carrosserie faite de SECTIONS TRANSVERSALES reliees.

    Chaque section est (y, demi_largeur, z_bas, z_haut). On relie les sections
    deux a deux : flancs, pavillon, plancher. C'est ce qui donne un capot qui
    plonge et un pavillon qui retrecit — donc une voiture — la ou des boites
    empilees donnent une caisse a savon.
    """
    for a, b in zip(sections, sections[1:]):
        ya, la, za0, za1 = a
        yb, lb, zb0, zb1 = b
        for cote in (-1, 1):
            m.face([(cote * la, ya, za0), (cote * lb, yb, zb0),
                    (cote * lb, yb, zb1), (cote * la, ya, za1)][::cote],
                   [(0, 0), (tuile, 0), (tuile, tuile), (0, tuile)])
        m.face([(-la, ya, za1), (la, ya, za1), (lb, yb, zb1), (-lb, yb, zb1)],
               [(0, 0), (tuile, 0), (tuile, tuile), (0, tuile)])
        m.face([(-lb, yb, zb0), (lb, yb, zb0), (la, ya, za0), (-la, ya, za0)],
               [(0, 0), (tuile, 0), (tuile, tuile), (0, tuile)])
    for bout, sens in ((sections[0], 1), (sections[-1], -1)):
        y, l, z0, z1 = bout
        m.face([(-l, y, z0), (l, y, z0), (l, y, z1), (-l, y, z1)][::sens])


def voiture_1(mats) -> int:
    """Niveau 1 : la voiture d'aujourd'hui. Deux boites et quatre roues."""
    m = Maillage("Caisse", mats["banc_tole_bleue"])
    m.boite(-0.93, -2.30, 0.42, 0.93, 2.05, 1.02, 2.0)
    m.boite(-0.82, -0.85, 1.02, 0.82, 0.95, 1.48, 2.0)
    total = m.finir()
    r = Maillage("Roues", mats["pneu"])
    for sx in (-0.86, 0.86):
        for sy in (-1.45, 1.30):
            r.boite(sx - 0.10, sy - 0.33, 0.02, sx + 0.10, sy + 0.33, 0.68)
    return total + r.finir()


def _roue(pneus, jantes, x, y, rayon, largeur, cotes) -> None:
    """Une roue : bande de roulement NOIRE, flancs a la jante.

    LES DEUX MATIERES SONT SEPAREES, et c'est ce qui manquait. La bande de
    roulement portait la texture de jante : le pneu ressortait gris clair vu de
    trois quarts. Une roue dont le caoutchouc ne se lit pas comme du caoutchouc
    casse toute la voiture — c'est la piece qu'on regarde en premier.
    """
    for signe in (-1, 1):
        pts = []
        for k in range(cotes):
            a = math.tau * k / cotes
            pts.append((x + signe * largeur / 2.0,
                        y + math.cos(a) * rayon, rayon + math.sin(a) * rayon))
        jantes.face(pts[::signe],
                    [(0.5 + 0.5 * math.cos(math.tau * k / cotes),
                      0.5 + 0.5 * math.sin(math.tau * k / cotes))
                     for k in range(cotes)])
    for k in range(cotes):
        j = (k + 1) % cotes
        a1, a2 = math.tau * k / cotes, math.tau * j / cotes
        p = []
        for a in (a1, a2):
            p.append((x - largeur / 2.0, y + math.cos(a) * rayon,
                      rayon + math.sin(a) * rayon))
        for a in (a2, a1):
            p.append((x + largeur / 2.0, y + math.cos(a) * rayon,
                      rayon + math.sin(a) * rayon))
        pneus.face(p, [(0, 0), (1, 0), (1, 0.3), (0, 0.3)])


def _passage_de_roue(m, x, y, rayon, profondeur) -> None:
    """L'arche sombre au-dessus d'une roue.

    Une roue qui sort d'un flanc PLAT se lit comme une roue collee dessus.
    Quelques faces sombres en arche, en retrait, donnent le creux : c'est le
    detail qui separe une voiture d'un jouet, pour six faces.
    """
    for k in range(6):
        a1 = math.pi * (0.06 + 0.88 * k / 6.0)
        a2 = math.pi * (0.06 + 0.88 * (k + 1) / 6.0)
        p = []
        for a in (a1, a2):
            p.append((x, y + math.cos(a) * rayon * 1.20,
                      rayon + math.sin(a) * rayon * 1.20))
        for a in (a2, a1):
            p.append((x - profondeur, y + math.cos(a) * rayon * 1.20,
                      rayon + math.sin(a) * rayon * 1.20))
        m.face(p, [(0, 0), (1, 0), (1, 0.4), (0, 0.4)])


# LES PROPORTIONS COMPTENT PLUS QUE LE NOMBRE DE FACES.
#
# La premiere version avait une caisse basse et un pavillon long : ca donnait
# un savon, et deux cent dix-huit faces n'y changeaient rien. Ceinture de
# caisse a 1,05 m, pavillon a 1,52 m et COURT, porte-a-faux avant reduit :
# c'est la silhouette d'une berline americaine des annees 2000.
#
# (y, demi_largeur, z_bas, z_haut)
SECTIONS_2 = [
    (-2.30, 0.66, 0.40, 0.92),
    (-1.86, 0.88, 0.28, 1.00),
    (-1.05, 0.94, 0.24, 1.08),
    (-0.62, 0.92, 0.24, 1.50),
    (0.62, 0.92, 0.24, 1.52),
    (1.15, 0.94, 0.26, 1.18),
    (1.90, 0.86, 0.34, 1.02),
    (2.16, 0.68, 0.42, 0.94),
]

SECTIONS_3 = [
    (-2.34, 0.60, 0.40, 0.86),
    (-2.10, 0.80, 0.32, 0.94),
    (-1.74, 0.90, 0.26, 0.99),
    (-1.20, 0.95, 0.24, 1.06),
    (-0.78, 0.95, 0.24, 1.16),
    (-0.52, 0.93, 0.24, 1.50),
    (0.34, 0.93, 0.24, 1.54),
    (0.78, 0.93, 0.24, 1.44),
    (1.22, 0.95, 0.26, 1.20),
    (1.80, 0.90, 0.32, 1.06),
    (2.14, 0.70, 0.42, 0.96),
]

# Les essieux, et la demi-voie. Les roues rentrent SOUS la caisse : 0,78 pour
# une demi-largeur de 0,95, donc le flanc du pneu reste en retrait de la tole.
# Elles debordaient, ce qui donnait quatre disques colles sur les cotes.
ESSIEUX = (-1.42, 1.30)
DEMI_VOIE = 0.78

# LA MONTE CARLO. Cinq metres dix, un capot de deux metres, un pavillon de
# quatre-vingt-quinze centimetres pose aux deux tiers arriere. Ce sont ces
# rapports qui font la voiture ; on peut lui retirer la moitie de ses faces,
# elle restera reconnaissable, et lui en ajouter le double sur de mauvaises
# proportions n'y changera rien.
SECTIONS_MONTE_CARLO = [
    (-2.62, 0.80, 0.52, 0.94),
    (-2.40, 0.90, 0.38, 0.97),
    (-1.90, 0.92, 0.34, 0.98),
    (-1.00, 0.92, 0.33, 0.99),
    (-0.58, 0.92, 0.33, 1.01),
    (-0.14, 0.90, 0.33, 1.40),
    (0.98, 0.89, 0.33, 1.41),
    (1.34, 0.90, 0.33, 1.14),
    (1.76, 0.92, 0.35, 1.04),
    (2.14, 0.90, 0.42, 1.00),
    (2.30, 0.82, 0.50, 0.96),
]
ESSIEUX_MC = (-1.55, 1.42)
DEMI_VOIE_MC = 0.76


def voiture_2(mats) -> int:
    """Niveau 2 : le galbe, et de vraies roues."""
    m = Maillage("Caisse", mats["banc_tole_bleue"])
    coque(m, SECTIONS_2, tuile=1.3)
    total = m.finir()

    v = Maillage("Vitrage", mats["banc_vitre"])
    for cote in (-1, 1):
        v.face([(cote * 0.94, -0.58, 1.10), (cote * 0.94, 0.58, 1.10),
                (cote * 0.94, 0.58, 1.46), (cote * 0.94, -0.58, 1.46)][::cote])
    v.face([(-0.90, -1.02, 1.06), (0.90, -1.02, 1.06),
            (0.88, -0.60, 1.50), (-0.88, -0.60, 1.50)][::-1])
    v.face([(-0.88, 0.64, 1.52), (0.88, 0.64, 1.52),
            (0.92, 1.12, 1.18), (-0.92, 1.12, 1.18)][::-1])
    total += v.finir()

    d = Maillage("Sombre", mats["metal_sombre"])
    # Le pare-chocs epouse la caisse au lieu de la deborder : un bloc plus
    # large que la voiture se lit comme une piece rapportee.
    d.boite(-0.74, -2.36, 0.40, 0.74, -2.30, 0.60, 1.0)
    d.boite(-0.74, 2.12, 0.44, 0.74, 2.18, 0.64, 1.0)
    for sx in (-0.99, 0.87):
        d.boite(sx, -0.66, 1.12, sx + 0.12, -0.46, 1.26, 0.6)
    for sx in (-1, 1):
        for sy in ESSIEUX:
            _passage_de_roue(d, sx * 0.945, sy, 0.34, sx * 0.16)
    total += d.finir()

    f = Maillage("Feux", mats["feu_avant"])
    for sx in (-0.58, 0.32):
        f.boite(sx, -2.34, 0.66, sx + 0.26, -2.28, 0.82, 0.5)
    total += f.finir()
    fa = Maillage("FeuxArriere", mats["feu_arriere"])
    for sx in (-0.60, 0.34):
        fa.boite(sx, 2.12, 0.72, sx + 0.26, 2.18, 0.92, 0.5)
    total += fa.finir()

    pneus = Maillage("Pneus", mats["pneu"])
    jantes = Maillage("Jantes", mats["banc_jante"])
    for sx in (-DEMI_VOIE, DEMI_VOIE):
        for sy in ESSIEUX:
            _roue(pneus, jantes, sx, sy, 0.34, 0.20, 10)
    return total + pneus.finir() + jantes.finir()


def voiture_3(mats) -> int:
    """Niveau 3 : la Monte Carlo de Jesse, d'apres les references.

    CE N'EST PLUS UNE BERLINE GENERIQUE. Benjamin a fourni trois photos de la
    voiture de Jesse — une Chevrolet Monte Carlo du milieu des annees 80 — et
    ce qui la rend reconnaissable tient a cinq proportions, pas au nombre de
    faces :

      LE CAPOT est enorme et PLAT. Deux metres de long, quasi horizontal. Sur
      une berline moderne il plonge et fait la moitie ; ici il fait la moitie
      de la voiture a lui seul, et c'est la premiere chose qu'on lit.

      LE PAVILLON est COURT et RECULE. Un coupe deux portes : l'habitacle
      commence apres le milieu de la voiture. Un pavillon centre donne
      immediatement une berline familiale.

      LA LUNETTE ARRIERE EST PRESQUE VERTICALE — toit dit « formel » — avec un
      montant arriere tres large. C'est la signature de la voiture, celle qu'on
      reconnait de trois quarts arriere.

      LA FACE AVANT EST VERTICALE, pas fuyante : une calandre rectangulaire a
      lamelles, quatre phares rectangulaires encastres, et un pare-chocs
      chrome horizontal qui prend toute la largeur.

      LA BANDE CREME DE BAS DE CAISSE. Deux tons, rouge et creme, separes par
      un jonc. Elle allonge la voiture et c'est ce qui accroche l'oeil sur les
      photos.
    """
    m = Maillage("Caisse", mats["banc_tole_rouge"])
    coque(m, SECTIONS_MONTE_CARLO, tuile=1.1)
    total = m.finir()

    # La bande creme, posee sur le flanc plutot que peinte dans la texture :
    # elle doit suivre exactement la silhouette, et une texture de carrosserie
    # est etiree differemment sur chaque section.
    b = Maillage("BandeBasse", mats["banc_tole_creme"])
    for cote in (-1, 1):
        for a1, a2 in zip(SECTIONS_MONTE_CARLO, SECTIONS_MONTE_CARLO[1:]):
            y0, l0, z0, _ = a1
            y1, l1, z1, _ = a2
            if y0 < -2.30 or y1 > 2.10:
                continue
            b.face([(cote * (l0 + 0.005), y0, z0 + 0.02),
                    (cote * (l1 + 0.005), y1, z1 + 0.02),
                    (cote * (l1 + 0.005), y1, z1 + 0.16),
                    (cote * (l0 + 0.005), y0, z0 + 0.16)][::cote],
                   [(0, 0), (1, 0), (1, 0.3), (0, 0.3)])
    total += b.finir()

    v = Maillage("Vitrage", mats["banc_vitre"])
    # DEUX portes, donc UNE vitre laterale par cote, et un montant arriere
    # large : le vitrage s'arrete a 0,55 alors que le pavillon va jusqu'a 0,95.
    for cote in (-1, 1):
        v.face([(cote * 0.908, -0.04, 1.03), (cote * 0.908, 0.90, 1.03),
                (cote * 0.900, 0.90, 1.34), (cote * 0.900, -0.04, 1.37)][::cote])
    v.face([(-0.88, -0.60, 1.00), (0.88, -0.60, 1.00),
            (0.86, -0.13, 1.37), (-0.86, -0.13, 1.37)])           # pare-brise
    v.face([(-0.86, 1.00, 1.37), (0.86, 1.00, 1.37),
            (0.88, 1.32, 1.13), (-0.88, 1.32, 1.13)])             # lunette
    total += v.finir()

    # LES MONTANTS. Une vitre sans encadrement ne se lit pas : c'est le
    # contraste avec le noir qui la designe comme un trou, et un trou est ce
    # qui distingue une cabine d'un bloc de tole.
    mo = Maillage("Montants", mats["metal_sombre"])
    for cote in (-1, 1):
        mo.boite(cote * 0.885, -0.14, 0.99, cote * 0.915, -0.02, 1.41, 0.6)
        mo.boite(cote * 0.885, 0.88, 0.99, cote * 0.915, 1.02, 1.41, 0.6)
        mo.boite(cote * 0.885, -0.08, 1.35, cote * 0.915, 0.94, 1.42, 0.6)
    total += mo.finir()

    # Le chrome : pare-chocs pleine largeur, jonc de caisse, entourages.
    c = Maillage("Chrome", mats["metal"])
    c.boite(-0.93, -2.76, 0.52, 0.93, -2.62, 0.74, 1.0)
    c.boite(-0.93, 2.24, 0.56, 0.93, 2.38, 0.78, 1.0)
    for cote in (-1, 1):                                          # jonc
        c.boite(cote * 0.925, -2.30, 0.50, cote * 0.940, 2.10, 0.54, 2.0)
    total += c.finir()

    d = Maillage("Sombre", mats["metal_sombre"])
    d.boite(-0.68, -2.70, 0.70, 0.68, -2.64, 0.92, 0.8)           # calandre
    for sx in (-0.96, 0.90):                                       # retroviseurs
        d.boite(sx, -0.30, 1.00, sx + 0.12, -0.10, 1.14, 0.6)
    for sx in (-0.955, 0.925):                                     # poignees
        d.boite(sx, 0.10, 0.96, sx + 0.04, 0.32, 1.02, 0.4)
    d.boite(0.32, 2.26, 0.30, 0.50, 2.42, 0.42, 0.5)              # echappement
    for sx in (-1, 1):
        for sy in ESSIEUX_MC:
            _passage_de_roue(d, sx * 0.935, sy, 0.37, sx * 0.16)
    total += d.finir()

    f = Maillage("Feux", mats["feu_avant"])
    for sx in (-0.84, 0.20):                    # deux blocs de phares doubles
        f.boite(sx, -2.71, 0.72, sx + 0.64, -2.66, 0.90, 0.6)
    total += f.finir()
    fa = Maillage("FeuxArriere", mats["feu_arriere"])
    for sx in (-0.86, 0.14):                                       # bandeaux larges
        fa.boite(sx, 2.22, 0.76, sx + 0.72, 2.28, 0.96, 0.5)
    total += fa.finir()

    pneus = Maillage("Pneus", mats["pneu"])
    jantes = Maillage("Jantes", mats["banc_jante_rouge"])
    for sx in (-DEMI_VOIE_MC, DEMI_VOIE_MC):
        for sy in ESSIEUX_MC:
            _roue(pneus, jantes, sx, sy, 0.37, 0.22, 12)
    return total + pneus.finir() + jantes.finir()


# --------------------------------------------------------------------- sortie


MODELES = [
    ("banc_maison_1", maison_1, ["crepi", "toit", "porte", "fenetre_maison"]),
    ("banc_maison_2", maison_2, ["banc_mur", "banc_toit", "banc_vitre",
                                 "porte", "metal_sombre", "metal"]),
    ("banc_maison_3", maison_3, ["banc_mur", "banc_toit", "banc_vitre",
                                 "porte", "metal_sombre", "metal"]),
    ("banc_voiture_1", voiture_1, ["banc_tole_bleue", "pneu"]),
    ("banc_voiture_2", voiture_2, ["banc_tole_bleue", "banc_vitre",
                                   "banc_jante", "pneu", "metal_sombre",
                                   "feu_avant", "feu_arriere"]),
    ("banc_voiture_3", voiture_3, ["banc_tole_rouge", "banc_tole_creme",
                                   "banc_vitre", "banc_jante_rouge", "pneu",
                                   "metal", "metal_sombre",
                                   "feu_avant", "feu_arriere"]),
]

# Ou le banc se pose dans le desert, en coordonnees de la ZONE (le jeu ajoute
# le centre). Les trois niveaux alignes, la voiture devant sa maison : on se
# place a vingt metres et on les a tous les trois dans le meme cadre.
ECART = 17.0
PLACEMENT = {"origine": [-92.0, 0.0, -18.0], "ecart": ECART}


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    textures = Path(a.textures)
    if not textures.is_absolute():
        textures = racine / textures
    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.mkdir(parents=True, exist_ok=True)

    print("")
    for nom, batir, besoins in MODELES:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        mats = {m: materiau(m, textures) for m in besoins}
        faces = batir(mats)
        fichier = sortie / f"{nom}.glb"
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=str(fichier), export_format="GLB",
                                  use_selection=True, export_apply=True,
                                  export_yup=True, export_cameras=False,
                                  export_lights=False)
        print("banc %-18s %4d faces  -> %s" % (nom, faces, fichier.name))

    fiche = sortie / "banc_graphique.json"
    objets = []
    for k in range(3):
        x = PLACEMENT["origine"][0] + k * ECART
        objets.append({"type": "banc_maison_%d" % (k + 1),
                       "pos": [x, 0.0, PLACEMENT["origine"][2]], "angle": 0.0})
        objets.append({"type": "banc_voiture_%d" % (k + 1),
                       "pos": [x + 1.0, 0.0, PLACEMENT["origine"][2] + 9.5],
                       "angle": round(math.pi / 2.0, 3)})
    fiche.write_text(json.dumps({"decor": objets}, indent=1), encoding="utf-8")
    print("placement  %s" % fiche.name)


if __name__ == "__main__":
    main()
