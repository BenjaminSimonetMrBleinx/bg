#!/usr/bin/env python3
"""Les lieux de la premiere mission : le labo, et le QG de Tuco.

    blender -b -P outils/gen_lieux.py -- --nom tous

Produit trois modeles dans game/assets/lieux/ :

    campingcar_interieur   le couloir du labo, sa paillasse et son atelier
    qg_exterieur           la rue, le batiment a l'abandon, la fresque
    qg_interieur           le bureau de Tuco, calfeutre

CE QUE LES REFERENCES DISENT, ET QU'ON SUIT.

Le camping-car est un COULOIR. Toute la chimie est alignee sur un seul bord,
sous une rangee de fenetres a stores, et l'on circule de l'autre cote. C'est
ce qui le rend jouable : une piece carree encombree se traverse mal, un couloir
se lit d'un coup d'oeil depuis la porte.

Le bureau de Tuco est l'inverse exact : une boite fermee, lambrissee, sans
autre lumiere que les raies d'un store barricade. Le joueur entre au centre,
Tuco est au fond derriere son bureau, les hommes de main sont DERRIERE lui.
On construit donc la piece autour de ces quatre places.

Convention du projet : construit pose au sol, avant vers -Y, et les lieux
vivent loin du centre-ville sur le meme plan — voir gen_desert.py, qui explique
pourquoi il n'y a pas de secondes scenes.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh

TUILE = 2.0


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Les lieux de la mission 1")
    ap.add_argument("--nom", default="tous")
    ap.add_argument("--textures", default=".tmp/textures")
    ap.add_argument("--sortie", default="game/assets/lieux")
    return ap.parse_args(argv)


def matiere(nom: str, dossier: Path):
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    for champ in ("Specular IOR Level", "Metallic", "Sheen Weight"):
        if champ in bsdf.inputs:
            bsdf.inputs[champ].default_value = 0.0
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 0.92
    png = dossier / f"{nom}.png"
    if not png.exists():
        raise SystemExit(
            f"texture absente : {png}\nElle se refabrique : .\\bg.ps1 generer")
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

    def face(self, points, uvs) -> None:
        verts = [self.bm.verts.new(p) for p in points]
        f = self.bm.faces.new(verts)
        for boucle, coord in zip(f.loops, uvs):
            boucle[self.uv].uv = coord

    def mur(self, a, b, z0, z1, tuile=TUILE, retourne=False) -> None:
        (x0, y0), (x1, y1) = a, b
        lg = math.hypot(x1 - x0, y1 - y0)
        nu, nv = lg / tuile, (z1 - z0) / tuile
        pts = [(x0, y0, z0), (x1, y1, z0), (x1, y1, z1), (x0, y0, z1)]
        if retourne:
            pts.reverse()
        self.face(pts, [(0, 0), (nu, 0), (nu, nv), (0, nv)])

    def dalle(self, x0, y0, x1, y1, z, tuile=TUILE, dessous=False) -> None:
        pts = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]
        if dessous:
            pts.reverse()
        self.face(pts, [(x0 / tuile, y0 / tuile), (x1 / tuile, y0 / tuile),
                        (x1 / tuile, y1 / tuile), (x0 / tuile, y1 / tuile)])

    def boite(self, x0, y0, z0, x1, y1, z1, tuile=TUILE) -> None:
        for a, b in [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)),
                     ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]:
            self.mur(a, b, z0, z1, tuile)
        self.dalle(x0, y0, x1, y1, z1, tuile)
        self.dalle(x0, y0, x1, y1, z0, tuile, dessous=True)

    def cylindre(self, cx, cy, z0, z1, rayon, cotes=8, tuile=TUILE) -> None:
        for i in range(cotes):
            a0 = math.tau * i / cotes
            a1 = math.tau * (i + 1) / cotes
            p0 = (cx + math.cos(a0) * rayon, cy + math.sin(a0) * rayon)
            p1 = (cx + math.cos(a1) * rayon, cy + math.sin(a1) * rayon)
            self.mur(p0, p1, z0, z1, tuile)
        haut = [(cx + math.cos(math.tau * i / cotes) * rayon,
                 cy + math.sin(math.tau * i / cotes) * rayon, z1)
                for i in range(cotes)]
        self.face(haut, [(0.5 + 0.5 * math.cos(math.tau * i / cotes),
                          0.5 + 0.5 * math.sin(math.tau * i / cotes))
                         for i in range(cotes)])

    def finir(self) -> int:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        self.bm.normal_update()
        n = len(self.bm.faces)
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        return n


# ------------------------------------------------- l'interieur du camping-car
#
# Dimensions reelles d'un Fleetwood Bounder : 7,2 m de cellule, 2,45 m de large
# a l'interieur, 2,0 m sous plafond. C'est ETROIT — et c'est le sujet : on veut
# que le joueur sente le tube dans lequel ces deux-la travaillent.

# ON A ELARGI, ET C'EST UN CHOIX CONTRE LE REALISME.
#
# Un Bounder fait 2,45 m de large a l'interieur. A cette largeur, la camera de
# poursuite — meme en mode interieur, a 2,10 m de recul — sortait par la paroi
# et l'on voyait le dos du decor : le camping-car paraissait ouvert sur le
# desert, et le joueur ne se reconnaissait plus dans l'image. Le mobilier
# n'avait pour la meme raison aucune collision, sans quoi le couloir restant
# ne se traversait plus.
#
# Un metre de plus regle les deux d'un coup : la camera tient dedans, et il
# reste de quoi marcher meme avec des meubles solides. C'est la meme licence
# que prennent tous les interieurs jouables — une piece de jeu est plus grande
# que la piece qu'elle represente, sinon on s'y cogne.
CC_L = 3.40          # largeur interieure
CC_P = 8.20          # profondeur, cabine comprise
CC_H = 2.30


def campingcar_interieur(mats) -> int:
    total = 0
    hx = CC_L / 2

    coque = Maillage("Coque", mats["camping_car"])
    # Les quatre murs, vus de l'INTERIEUR : on retourne les faces, sinon on
    # regarde le dos des polygones et la piece parait ouverte sur le vide.
    coque.mur((-hx, 0.0), (hx, 0.0), 0.0, CC_H)          # fond
    coque.mur((hx, 0.0), (hx, -CC_P), 0.0, CC_H)         # droite
    coque.mur((-hx, -CC_P), (-hx, 0.0), 0.0, CC_H)       # gauche
    coque.mur((hx, -CC_P), (-hx, -CC_P), 0.0, CC_H)      # avant
    coque.dalle(-hx, -CC_P, hx, 0.0, CC_H, dessous=True)                # toit
    total += coque.finir()

    sol = Maillage("Sol", mats["lino"])
    sol.dalle(-hx, -CC_P, hx, 0.0, 0.01)
    total += sol.finir()

    # LES STORES, sur toute la longueur du bord gauche et deux pans a droite.
    # C'est la seule source de lumiere de la piece et ce qui donne son
    # atmosphere aux images de reference : des raies chaudes en travers.
    st = Maillage("Stores", mats["store"])
    for y0, y1 in ((-6.6, -4.6), (-4.2, -2.4), (-2.0, -0.5)):
        st.mur((-hx + 0.01, y0), (-hx + 0.01, y1), 1.05, 1.72)
    for y0, y1 in ((-6.4, -4.8), (-2.2, -0.7)):
        st.mur((hx - 0.01, y1), (hx - 0.01, y0), 1.05, 1.72)
    total += st.finir()

    # LA PAILLASSE, tout le long du bord gauche. Un seul plan continu : c'est
    # ce qui fait le couloir. On garde 1,35 m de passage, de quoi marcher.
    p = Maillage("Paillasse", mats["paillasse"])
    p.boite(-hx, -6.9, 0.86, -hx + 0.62, -0.6, 0.94)
    for y in (-6.6, -5.2, -3.6, -2.0, -0.9):                 # pieds
        p.boite(-hx + 0.06, y - 0.06, 0.0, -hx + 0.16, y + 0.06, 0.86)
    # Le plan de travail d'en face, plus court : c'est celui de Jesse.
    p.boite(hx - 0.55, -6.8, 0.86, hx, -4.9, 0.94)
    total += p.finir()

    # LA VERRERIE. Des cylindres et des boites, en trois hauteurs : c'est ce
    # qui differencie un labo d'un plan de travail de cuisine. Aucun detail
    # n'est lisible a cette echelle, seule la SILHOUETTE compte — beaucoup de
    # verticales fines et serrees.
    v = Maillage("Verrerie", mats["verre_labo"])
    y = -6.75
    hauteurs = [0.34, 0.22, 0.44, 0.18, 0.30, 0.38, 0.24, 0.42, 0.20, 0.32,
                0.28, 0.46, 0.22, 0.36]
    for k, h in enumerate(hauteurs):
        y = -6.75 + k * 0.44
        if y > -0.8:
            break
        r = 0.05 + 0.03 * ((k * 7) % 3)
        v.cylindre(-hx + 0.22 + 0.10 * ((k * 5) % 3), y, 0.94, 0.94 + h, r, 6)
    # Deux ballons ronds poses a plat, qu'on lit comme des flacons.
    for y in (-5.6, -3.1):
        v.cylindre(-hx + 0.40, y, 0.94, 1.10, 0.13, 8)
    total += v.finir()

    liq = Maillage("Liquides", mats["liquide_ambre"])
    for k in range(6):
        y = -6.5 + k * 1.1
        if y > -0.9:
            break
        liq.cylindre(-hx + 0.26, y, 0.95, 1.06, 0.045, 6)
    total += liq.finir()

    vert = Maillage("LiquidesVerts", mats["liquide_vert"])
    for y in (-6.0, -4.3, -2.6):
        vert.cylindre(-hx + 0.44, y, 0.95, 1.12, 0.05, 6)
    total += vert.finir()

    # LES BIDONS au sol, cote droit : ce sont eux qui remplissent le bas du
    # cadre sur les references, et qui empechent le couloir d'etre un tube vide.
    br = Maillage("BidonsRouges", mats["bidon_rouge"])
    for y in (-6.2, -3.4):
        br.cylindre(hx - 0.34, y, 0.0, 0.86, 0.28, 8)
    total += br.finir()

    bb = Maillage("BidonsBleus", mats["bidon_bleu"])
    for y in (-5.4, -2.6):
        bb.cylindre(hx - 0.34, y, 0.0, 0.72, 0.26, 8)
    total += bb.finir()

    # L'ATELIER : le poste ou l'on cuisine, cote droit, bien identifiable.
    # Il est plus haut et plus massif que le reste — le joueur doit le
    # reconnaitre sans qu'on lui dise ou aller.
    a = Maillage("Atelier", mats["inox"])
    a.boite(hx - 0.62, -4.6, 0.0, hx - 0.04, -3.0, 0.92)
    a.boite(hx - 0.58, -4.4, 0.92, hx - 0.10, -3.2, 1.06)      # cuve
    a.cylindre(hx - 0.34, -4.2, 1.06, 1.62, 0.06, 6)           # colonne
    a.cylindre(hx - 0.34, -3.5, 1.06, 1.44, 0.05, 6)
    total += a.finir()

    # LE POSTE DE CONDUITE.
    #
    # C'etait quatre boites : deux sieges suggeres et un disque pour le volant.
    # De l'interieur, on ne reconnaissait pas l'avant d'un vehicule — juste le
    # bout du couloir. Or c'est la que se trouvent la boite a gants et l'etape
    # ou l'on essaie de prendre le volant : il faut que le joueur SACHE qu'il
    # est arrive dans une cabine.
    #
    # Ce qui fait lire une cabine, dans cet ordre : le pare-brise (une bande
    # claire en travers, tout en haut), la planche de bord (une masse continue
    # sous le pare-brise), puis le volant. Les sieges viennent apres — ils sont
    # deja plus lisibles qu'un tableau de bord absent.
    av = -CC_P                       # le nez du vehicule
    conducteur = -0.72               # a gauche, comme aux Etats-Unis

    c = Maillage("Cabine", mats["cuir_sombre"])
    for sx in (conducteur, -conducteur):
        # L'assise, le dossier incline en deux morceaux, et l'appui-tete.
        c.boite(sx - 0.30, av + 0.30, 0.28, sx + 0.30, av + 0.92, 0.48)
        c.boite(sx - 0.30, av + 0.78, 0.48, sx + 0.30, av + 0.94, 1.02)
        c.boite(sx - 0.20, av + 0.80, 1.02, sx + 0.20, av + 0.94, 1.26)
        # Le pied, pour que le siege ne flotte pas au-dessus du plancher.
        c.boite(sx - 0.14, av + 0.46, 0.0, sx + 0.14, av + 0.74, 0.28)
    total += c.finir()

    # La planche de bord : une masse continue d'un flanc a l'autre, avec une
    # casquette qui avance au-dessus. C'est elle qui separe la cabine du
    # pare-brise, et sans elle les deux se confondent.
    hx_c = CC_L / 2
    tb = Maillage("TableauDeBord", mats["metal_sombre"])
    tb.boite(-hx_c + 0.05, av + 0.02, 0.62, hx_c - 0.05, av + 0.40, 1.06)
    tb.boite(-hx_c + 0.05, av + 0.38, 0.98, hx_c - 0.05, av + 0.56, 1.10)
    # La console centrale et le levier de vitesses.
    tb.boite(-0.18, av + 0.30, 0.0, 0.18, av + 0.80, 0.40)
    tb.cylindre(0.0, av + 0.72, 0.40, 0.78, 0.035, 6)
    total += tb.finir()

    # LE PARE-BRISE, en haut et incline. Une seule face large : c'est la seule
    # chose claire du fond du couloir, donc c'est elle qui dit « l'avant est
    # par la » des la porte.
    pb = Maillage("PareBrise", mats["vitre"])
    pb.face([(-hx_c + 0.06, av + 0.02, 1.10), (hx_c - 0.06, av + 0.02, 1.10),
             (hx_c - 0.06, av + 0.30, 1.92), (-hx_c + 0.06, av + 0.30, 1.92)],
            [(0, 0), (2.4, 0), (2.4, 1.0), (0, 1.0)])
    # Les deux vitres laterales de cabine, en biais vers l'arriere.
    for sx in (-1.0, 1.0):
        pb.mur((sx * (hx_c - 0.03), av + 0.30), (sx * (hx_c - 0.03), av + 1.10),
               1.10, 1.80, retourne=sx < 0)
    total += pb.finir()

    # LE VOLANT, incline sur sa colonne. Une jante en huit segments plutot
    # qu'un disque plein, trois branches, et un moyeu : a cette resolution
    # c'est la silhouette ajouree qui se lit comme un volant, pas le disque.
    vol = Maillage("Volant", mats["metal_sombre"])
    vy, vz, r = av + 0.62, 0.98, 0.20
    cotes = 8
    for i in range(cotes):
        a0 = math.tau * i / cotes
        a1 = math.tau * (i + 1) / cotes
        vol.boite(conducteur + math.cos(a0) * r - 0.025,
                  vy + math.sin(a0) * r * 0.35 - 0.025,
                  vz + math.sin(a0) * r - 0.025,
                  conducteur + math.cos(a1) * r + 0.025,
                  vy + math.sin(a1) * r * 0.35 + 0.025,
                  vz + math.sin(a1) * r + 0.025)
    for a in (math.pi * 0.5, math.pi * 1.17, math.pi * 1.83):
        vol.boite(conducteur + min(0.0, math.cos(a) * r) - 0.02,
                  vy + min(0.0, math.sin(a) * r * 0.35) - 0.02,
                  vz + min(0.0, math.sin(a) * r) - 0.02,
                  conducteur + max(0.0, math.cos(a) * r) + 0.02,
                  vy + max(0.0, math.sin(a) * r * 0.35) + 0.02,
                  vz + max(0.0, math.sin(a) * r) + 0.02)
    vol.boite(conducteur - 0.05, vy - 0.05, vz - 0.05,
              conducteur + 0.05, vy + 0.05, vz + 0.05)
    # La colonne, du moyeu vers la planche de bord.
    vol.boite(conducteur - 0.035, vy + 0.02, 0.70,
              conducteur + 0.035, vy + 0.22, vz)
    total += vol.finir()

    # La boite a gants, ou dort le revolver. Cote passager, encastree dans la
    # planche de bord et bien visible : c'est un point d'interaction.
    bg = Maillage("BoiteGants", mats["bache"])
    bg.boite(-conducteur - 0.32, av + 0.00, 0.66,
             -conducteur + 0.32, av + 0.06, 0.98)
    total += bg.finir()

    return total


# ---------------------------------------------------------- le QG de Tuco
#
# Vu de la rue : un batiment d'angle a deux niveaux, creme, avec une fresque
# sur tout le pignon et des fenetres condamnees. Une seule porte.

QG_L = 15.0
QG_P = 11.0
QG_H = 7.2


def qg_exterieur(mats) -> int:
    total = 0
    hx, hy = QG_L / 2, QG_P / 2

    sol = Maillage("Bitume", mats["asphalte"])
    sol.dalle(-40.0, -40.0, 40.0, 40.0, 0.0, tuile=6.0)
    total += sol.finir()

    murs = Maillage("Murs", mats["crepi"])
    # La facade avant est percee d'une porte : c'est par elle qu'on entre, et
    # une ouverture reelle vaut mieux qu'une porte peinte — on voit le noir de
    # l'interieur depuis la rue, ce qui donne envie d'y aller.
    d0, d1 = -0.75, 0.75
    murs.mur((-hx, -hy), (d0, -hy), 0.0, QG_H)
    murs.mur((d1, -hy), (hx, -hy), 0.0, QG_H)
    murs.mur((d0, -hy), (d1, -hy), 2.35, QG_H)
    murs.mur((hx, -hy), (hx, hy), 0.0, QG_H)
    murs.mur((hx, hy), (-hx, hy), 0.0, QG_H)
    murs.dalle(-hx, -hy, hx, hy, QG_H)
    total += murs.finir()

    # LE PIGNON PEINT. Sur le cote gauche, plein cadre : c'est ce qu'on voit en
    # arrivant, et c'est ce qui identifie l'endroit.
    fresque = Maillage("Fresque", mats["graffiti"])
    fresque.mur((-hx - 0.02, hy), (-hx - 0.02, -hy), 0.0, 5.4, tuile=5.4)
    total += fresque.finir()

    # Les fenetres condamnees de l'etage : des planches en travers.
    b = Maillage("Barricades", mats["planche_barricade"])
    for x in (-4.2, -0.6, 3.0):
        b.mur((x - 0.75, -hy - 0.03), (x + 0.75, -hy - 0.03), 4.3, 5.6)
    total += b.finir()

    # Le rez-de-chaussee vitre, opaque et sale : on ne voit rien a l'interieur.
    vit = Maillage("Vitrine", mats["vitre"])
    for x0, x1 in ((-6.2, -1.4), (1.6, 6.2)):
        vit.mur((x0, -hy - 0.02), (x1, -hy - 0.02), 1.05, 3.0)
    total += vit.finir()

    porte = Maillage("Porte", mats["metal_sombre"])
    porte.mur((d0, -hy - 0.04), (d1, -hy - 0.04), 0.0, 2.35)
    total += porte.finir()

    # Un muret et deux bornes : ils cadrent l'approche et donnent l'echelle.
    m = Maillage("Muret", mats["beton"])
    m.boite(-hx - 6.0, -hy - 7.0, 0.0, -hx - 5.4, hy, 1.1)
    total += m.finir()

    return total


def qg_interieur(mats) -> int:
    """Le bureau. Une boite lambrissee, calfeutree, sans fenetre utilisable.

    Six metres sur huit : assez pour que le joueur puisse se DEPLACER pendant
    la scene finale, comme le demande le scenario, et assez petit pour qu'il
    n'y ait nulle part ou aller.
    """
    total = 0
    L, P, H = 6.4, 8.2, 3.0
    hx, hy = L / 2, P / 2

    murs = Maillage("Lambris", mats["lambris"])
    murs.mur((-hx, hy), (hx, hy), 0.0, H)
    murs.mur((hx, hy), (hx, -hy), 0.0, H)
    murs.mur((hx, -hy), (-hx, -hy), 0.0, H)
    murs.mur((-hx, -hy), (-hx, hy), 0.0, H)
    murs.dalle(-hx, -hy, hx, hy, H, dessous=True)
    total += murs.finir()

    sol = Maillage("Plancher", mats["bureau_bois"])
    sol.dalle(-hx, -hy, hx, hy, 0.01)
    total += sol.finir()

    # LES DEUX SEULES SOURCES DE LUMIERE : deux stores barricades, sur le mur
    # de droite. Toute la piece est lue par ces raies — c'est exactement
    # l'image de reference, et c'est ce qui rend l'endroit etouffant.
    st = Maillage("Stores", mats["store"])
    for y in (-2.0, 1.6):
        st.mur((hx - 0.02, y + 1.0), (hx - 0.02, y - 1.0), 1.3, 2.5)
    total += st.finir()

    b = Maillage("Barricades", mats["planche_barricade"])
    for y in (-2.0, 1.6):
        for z in (1.5, 2.1):
            b.boite(hx - 0.16, y - 1.05, z, hx - 0.06, y + 1.05, z + 0.14)
    total += b.finir()

    # LE BUREAU, au fond. Tuco est derriere ; le joueur entre par devant.
    bu = Maillage("Bureau", mats["bureau_bois"])
    bu.boite(-1.5, hy - 2.4, 0.70, 1.5, hy - 1.2, 0.80)
    bu.boite(-1.45, hy - 2.35, 0.0, -1.15, hy - 1.25, 0.70)
    bu.boite(1.15, hy - 2.35, 0.0, 1.45, hy - 1.25, 0.70)
    total += bu.finir()

    # Le fauteuil de cuir, et deux caisses au fond : le decor tient a trois
    # objets, mais il en faut trois.
    f = Maillage("Fauteuil", mats["cuir_sombre"])
    f.boite(-0.45, hy - 1.05, 0.0, 0.45, hy - 0.35, 0.44)
    f.boite(-0.45, hy - 0.50, 0.44, 0.45, hy - 0.35, 1.24)
    total += f.finir()

    c = Maillage("Caisses", mats["bache"])
    c.boite(-hx + 0.2, -hy + 0.3, 0.0, -hx + 1.1, -hy + 1.2, 0.75)
    c.boite(-hx + 0.2, -hy + 1.3, 0.0, -hx + 0.9, -hy + 2.0, 0.55)
    total += c.finir()

    # Le plateau de verre sur le bureau : c'est la que la botte secrete est
    # posee, et il faut que le joueur voie ou regarder.
    pl = Maillage("Plateau", mats["verre_labo"])
    pl.boite(0.20, hy - 2.10, 0.80, 1.10, hy - 1.45, 0.83)
    total += pl.finir()

    return total


LIEUX = {
    "campingcar_interieur": (campingcar_interieur, [
        "camping_car", "lino", "store", "paillasse", "verre_labo",
        "liquide_ambre", "liquide_vert", "bidon_rouge", "bidon_bleu",
        "inox", "cuir_sombre", "metal_sombre", "bache", "vitre"]),
    "qg_exterieur": (qg_exterieur, [
        "asphalte", "crepi", "graffiti", "planche_barricade", "vitre",
        "metal_sombre", "beton"]),
    "qg_interieur": (qg_interieur, [
        "lambris", "bureau_bois", "store", "planche_barricade",
        "cuir_sombre", "bache", "verre_labo"]),
}


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

    noms = list(LIEUX) if a.nom == "tous" else [a.nom]
    print("")
    for nom in noms:
        if nom not in LIEUX:
            raise SystemExit("lieu inconnu : %s (au choix : %s)"
                             % (nom, ", ".join(LIEUX)))
        batir, besoins = LIEUX[nom]
        bpy.ops.wm.read_factory_settings(use_empty=True)
        mats = {m: matiere(m, textures) for m in besoins}
        faces = batir(mats)
        fichier = sortie / f"{nom}.glb"
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(
            filepath=str(fichier), export_format="GLB", use_selection=True,
            export_apply=True, export_yup=True, export_animations=False,
            export_cameras=False, export_lights=False)
        print("  %-24s %5d faces  -> %s" % (nom, faces, fichier.name))
    print("")
    print("  sortie   %s" % sortie)


if __name__ == "__main__":
    main()
