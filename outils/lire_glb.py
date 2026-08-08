#!/usr/bin/env python3
"""Dit ce qu'un .glb CONTIENT vraiment. Sans Blender, sans dependance.

    python outils/lire_glb.py game/assets/vehicules/aztek.glb
    python outils/lire_glb.py game/assets/**/*.glb

C'est la regle la plus chere du projet, appliquee aux modeles : on mesure le
FICHIER PRODUIT, jamais la scene qui l'a produit. Un outil annonce un nombre
juste et ecrit un fichier faux — c'est arrive quatre fois.

Ce module sert deux fois :
  - en ligne de commande, pour auditer ce qui est deja dans le depot ;
  - depuis importer_modele.py, qui l'appelle apres chaque export.

Il n'importe PAS bpy : c'est ce qui permet de le lancer sur une machine nue, et
de l'utiliser dans un test.

UN .glb, C'EST : douze octets d'en-tete, puis des morceaux longueur/type. Le
premier est toujours le JSON ; le second, quand il existe, porte les binaires.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def taille_image(octets: bytes) -> tuple:
    """Cotes d'une image PNG ou JPEG, lus dans ses octets. (0, 0) si inconnu."""
    if octets[:8] == b"\x89PNG\r\n\x1a\n":
        # IHDR est toujours le premier morceau : largeur en 16, hauteur en 20.
        return (int.from_bytes(octets[16:20], "big"),
                int.from_bytes(octets[20:24], "big"))
    if octets[:2] == b"\xff\xd8":
        i = 2
        while i + 9 < len(octets):
            if octets[i] != 0xFF:
                i += 1
                continue
            marqueur = octets[i + 1]
            # SOFn porte les dimensions, sauf C4 (Huffman), C8 et CC.
            if 0xC0 <= marqueur <= 0xCF and marqueur not in (0xC4, 0xC8, 0xCC):
                return (int.from_bytes(octets[i + 7:i + 9], "big"),
                        int.from_bytes(octets[i + 5:i + 7], "big"))
            i += 2 + int.from_bytes(octets[i + 2:i + 4], "big")
    return (0, 0)


# LES COTES SE MESURENT SUR LES SOMMETS TRANSFORMES, PAS SUR LES ACCESSEURS.
#
# Piege paye le 08/08/2026, et il vaut d'etre ecrit parce qu'il a d'abord fait
# accuser le mauvais coupable.
#
# Chaque accesseur de POSITION porte son min et son max. Les lire directement
# parait etre « la mesure du fichier » — et c'est faux : un noeud glTF porte sa
# propre transformation, et un modele genere par Tripo arrive avec une echelle
# de 0,4 sur son noeud racine. Les positions brutes disaient 0,998 m quand
# l'objet en fait 0,400.
#
# Sur cette mesure fausse, j'ai conclu que importer_modele.py ecrivait un
# fichier faux, et j'ai « corrige » une chaine qui marchait. C'est exactement le
# piege 18 : avant de corriger ce qu'un instrument denonce, verifier
# l'instrument.
def _matrice(noeud: dict) -> list:
    """La transformation d'un noeud, en 4x4 ligne par ligne."""
    if "matrix" in noeud:
        m = noeud["matrix"]
        # Le glTF stocke en colonnes ; on transpose pour travailler en lignes.
        return [[m[0], m[4], m[8], m[12]],
                [m[1], m[5], m[9], m[13]],
                [m[2], m[6], m[10], m[14]],
                [m[3], m[7], m[11], m[15]]]
    t = noeud.get("translation", [0.0, 0.0, 0.0])
    r = noeud.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = noeud.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = r
    rot = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [[rot[i][0] * s[0], rot[i][1] * s[1], rot[i][2] * s[2], t[i]]
            for i in range(3)] + [[0.0, 0.0, 0.0, 1.0]]


def _produit(a: list, b: list) -> list:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def _applique(m: list, p: tuple) -> tuple:
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3]
                 for i in range(3))


def _etendue(g: dict) -> tuple:
    """Boite englobante du modele entier, transformations comprises."""
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    identite = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]

    def descendre(indice: int, parent: list) -> None:
        noeud = g["nodes"][indice]
        monde = _produit(parent, _matrice(noeud))
        if "mesh" in noeud:
            for prim in g["meshes"][noeud["mesh"]].get("primitives", []):
                pos = prim.get("attributes", {}).get("POSITION")
                if pos is None:
                    continue
                acc = g["accessors"][pos]
                if "min" not in acc or "max" not in acc:
                    continue
                # LES HUIT COINS, pas seulement min et max : une rotation fait
                # tourner la boite, et deux coins ne suffisent plus a la decrire.
                for cx in (acc["min"][0], acc["max"][0]):
                    for cy in (acc["min"][1], acc["max"][1]):
                        for cz in (acc["min"][2], acc["max"][2]):
                            p = _applique(monde, (cx, cy, cz))
                            for k in range(3):
                                lo[k] = min(lo[k], p[k])
                                hi[k] = max(hi[k], p[k])
        for enfant in noeud.get("children", []):
            descendre(enfant, monde)

    scenes = g.get("scenes", [])
    racines = scenes[g.get("scene", 0)].get("nodes", []) if scenes else \
        range(len(g.get("nodes", [])))
    for r in racines:
        descendre(r, identite)
    return lo, hi


def _morceaux(brut: bytes) -> dict:
    trouve = {}
    i = 12
    while i + 8 <= len(brut):
        longueur = int.from_bytes(brut[i:i + 4], "little")
        trouve[brut[i + 4:i + 8]] = (i + 8, longueur)
        i += 8 + longueur + (-longueur % 4)
    return trouve


def decrire(chemin: Path) -> dict:
    """Ce que le fichier contient : triangles, materiaux, images, alertes."""
    brut = chemin.read_bytes()
    if brut[:4] != b"glTF":
        return {"erreur": "ce n'est pas un .glb"}

    morceaux = _morceaux(brut)
    if b"JSON" not in morceaux:
        return {"erreur": "aucun morceau JSON"}
    debut, longueur = morceaux[b"JSON"]
    g = json.loads(brut[debut:debut + longueur])
    bin_debut = morceaux.get(b"BIN\x00", (0, 0))[0]

    vues = g.get("bufferViews", [])
    images = g.get("images", [])
    textures = g.get("textures", [])

    # Les triangles, comptes sur les accesseurs d'indices. Mode 4 = TRIANGLES,
    # et c'est le defaut du glTF quand le champ est absent.
    tris = 0
    for maillage in g.get("meshes", []):
        for prim in maillage.get("primitives", []):
            if prim.get("mode", 4) != 4:
                continue
            if "indices" in prim:
                tris += g["accessors"][prim["indices"]].get("count", 0) // 3
            elif prim.get("attributes", {}).get("POSITION") is not None:
                tris += g["accessors"][
                    prim["attributes"]["POSITION"]].get("count", 0) // 3

    def carte(indice) -> str:
        if indice is None:
            return "ABSENT"
        source = textures[indice].get("source")
        if source is None:
            return "sans image"
        img = images[source]
        if "bufferView" not in img:
            return img.get("uri", "externe")
        vue = vues[img["bufferView"]]
        depart = bin_debut + vue.get("byteOffset", 0)
        octets = brut[depart:depart + min(vue.get("byteLength", 0), 4096)]
        l, h = taille_image(octets)
        ko = vue.get("byteLength", 0) / 1024.0
        return "%dx%d %.0f Ko" % (l, h, ko) if l else "%.0f Ko" % ko

    materiaux = []
    alertes = []
    plus_grande = 0
    for n, mat in enumerate(g.get("materials", [])):
        pbr = mat.get("pbrMetallicRoughness", {})
        base = (pbr.get("baseColorTexture") or {}).get("index")
        mr = (pbr.get("metallicRoughnessTexture") or {}).get("index")
        normale = (mat.get("normalTexture") or {}).get("index")
        emis = (mat.get("emissiveTexture") or {}).get("index")
        occ = (mat.get("occlusionTexture") or {}).get("index")
        materiaux.append({
            "couleur": carte(base), "normale": carte(normale),
            "metal_rugosite": carte(mr), "emission": carte(emis),
            "occlusion": carte(occ),
        })
        # LE PIEGE 20 : une emission blanche SANS texture noie la couleur de
        # base, et le modele sort entierement blanc. Trois camping-cars sont
        # deja partis comme des blocs de neige avant qu'on lise le materiau.
        facteur = mat.get("emissiveFactor")
        if facteur and max(facteur) > 0.0 and emis is None:
            alertes.append("materiau %d : emissiveFactor %s sans texture, il EMET"
                           % (n, facteur))

    for img in images:
        if "bufferView" not in img:
            continue
        vue = vues[img["bufferView"]]
        depart = bin_debut + vue.get("byteOffset", 0)
        l, _ = taille_image(brut[depart:depart + min(vue.get("byteLength", 0), 4096)])
        plus_grande = max(plus_grande, l)

    lo, hi = _etendue(g)
    cotes = tuple(hi[k] - lo[k] for k in range(3)) if lo[0] < 1e8 else (0.0, 0.0, 0.0)

    # UN MODELE RIGGE NE SE MESURE PAS COMME CA, et il faut le DIRE plutot que
    # de rendre un nombre qui a l'air d'en etre un.
    #
    # Les sommets d'un maillage peau sont en pose de reference, et c'est
    # l'armature qui les place. Walt, qui fait 1,78 m dans le jeu, se mesure
    # ainsi a 0,018 : les noeuds d'os portent l'echelle, le maillage non. Le
    # journal le dit deja pour Blender — « la boite englobante decrit la
    # geometrie AVANT deformation par l'armature » — et c'est vrai du glTF pour
    # la meme raison.
    rigge = bool(g.get("skins"))
    if rigge:
        alertes.append(
            "modele RIGGE : les cotes ci-dessus ne veulent rien dire, la taille"
            " vient de l'armature. Mesurer sur les os.")

    return {
        "triangles": tris,
        "materiaux": materiaux,
        "images": len(images),
        "poids_images_mo": sum(vues[i["bufferView"]].get("byteLength", 0)
                               for i in images if "bufferView" in i) / 1048576.0,
        "plus_grande_texture": plus_grande,
        "cotes": cotes,
        # hauteur reste None sur un modele rigge : mieux vaut rien qu'un nombre
        # faux, parce qu'un appelant qui compare a une cible y croirait.
        "hauteur": None if rigge else cotes[1],
        "rigge": rigge,
        "sous_le_sol": lo[1] if lo[0] < 1e8 else 0.0,
        "alertes": alertes,
    }


def imprimer(chemin: Path) -> None:
    d = decrire(chemin)
    if "erreur" in d:
        print("%-46s %s" % (chemin.name, d["erreur"]))
        return
    poids = chemin.stat().st_size / 1048576.0
    print("%-46s %7.2f Mo  %6d tris  %d img  max %d px"
          % (chemin.name, poids, d["triangles"], d["images"],
             d["plus_grande_texture"]))
    print("    cotes  X %.3f  Y %.3f (hauteur)  Z %.3f   pied a %.3f"
          % (d["cotes"][0], d["cotes"][1], d["cotes"][2], d["sous_le_sol"]))
    for n, m in enumerate(d["materiaux"]):
        print("    mat %d  couleur %-16s normale %-16s metal/rug %s"
              % (n, m["couleur"], m["normale"], m["metal_rugosite"]))
    for a in d["alertes"]:
        print("    ATTENTION %s" % a)


def main() -> None:
    cibles = [Path(a) for a in sys.argv[1:]]
    if not cibles:
        raise SystemExit("usage : lire_glb.py <fichier.glb> [...]")
    for c in cibles:
        if c.exists():
            imprimer(c)
        else:
            print("%-46s introuvable" % c.name)


if __name__ == "__main__":
    main()
