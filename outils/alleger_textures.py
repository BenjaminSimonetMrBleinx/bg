#!/usr/bin/env python3
"""Reduit les textures d'un .glb DEJA INTEGRE, sans toucher a sa geometrie.

    blender -b -P outils/alleger_textures.py -- \\
            --fichier game/assets/vehicules/aztek.glb --texture-max 512

POURQUOI CET OUTIL EXISTE PLUTOT QU'UN RE-INTEGRER.

L'Aztek est entree dans le jeu avec trois cartes de 2048 px — 10,1 Mo — parce
que --texture-max valait 0 par defaut. Il fallait la ramener au palier du jeu.

La reponse evidente etait de relancer `bg.ps1 integrer` depuis la livraison. Elle
est mauvaise : les valeurs de --hauteur et surtout de --lacet qui ont donne le
resultat actuel ne sont ecrites nulle part, et le lacet de cette voiture a deja
coute deux tentatives ratees (piege 2). Reintegrer, c'est rejouer une commande
qu'on ne connait pas et esperer.

Ici on ne touche NI aux sommets, NI aux transformations, NI a l'orientation :
seulement aux images. Et on verifie que la boite englobante n'a pas bouge — si
elle bouge, l'export a fait quelque chose qu'on ne lui demandait pas, et on
refuse d'ecrire.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import bpy


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Allege les textures d un .glb")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--texture-max", type=int, default=256, dest="texture_max")
    return ap.parse_args(argv)


def boite_de(objets) -> tuple:
    import mathutils
    mini = [1e9, 1e9, 1e9]
    maxi = [-1e9, -1e9, -1e9]
    for o in objets:
        for coin in o.bound_box:
            p = o.matrix_world @ mathutils.Vector(coin)
            for i in range(3):
                mini[i] = min(mini[i], p[i])
                maxi[i] = max(maxi[i], p[i])
    return tuple(maxi[i] - mini[i] for i in range(3))


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    cible = Path(a.fichier)
    if not cible.is_absolute():
        cible = racine / cible
    if not cible.exists():
        raise SystemExit("introuvable : %s" % cible)

    poids_avant = cible.stat().st_size / 1048576.0

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(cible))

    maillages = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not maillages:
        raise SystemExit("aucun maillage dans %s" % cible.name)
    avant = boite_de(maillages)

    touchees = 0
    for img in bpy.data.images:
        if img.size[0] <= 0:
            continue
        l, h = img.size
        if max(l, h) <= a.texture_max:
            continue
        f = a.texture_max / max(l, h)
        img.scale(max(1, int(l * f)), max(1, int(h * f)))
        print("texture   %s : %dx%d -> %dx%d" % (img.name, l, h, *img.size))
        touchees += 1

    if touchees == 0:
        print("rien a faire : tout est deja sous %d px" % a.texture_max)
        return

    # UNE SAUVEGARDE AVANT D'ECRIRE. Le fichier d'origine est dans Git LFS, donc
    # recuperable — mais pas si on decouvre le probleme trois commits plus tard.
    secours = cible.with_suffix(".glb.avant-allegement")
    shutil.copy(cible, secours)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(cible),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )

    # ON RELIT CE QU'ON VIENT D'ECRIRE, et on refuse si la geometrie a bouge.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(cible))
    relus = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    apres = boite_de(relus)

    ecart = max(abs(apres[i] - avant[i]) for i in range(3))
    print("boite     avant %.3f x %.3f x %.3f" % avant)
    print("          apres %.3f x %.3f x %.3f" % apres)
    if ecart > 0.01:
        shutil.copy(secours, cible)
        raise SystemExit(
            "ECHEC : la geometrie a bouge de %.3f m, fichier restaure" % ecart)

    poids = cible.stat().st_size / 1048576.0
    print("poids     %.2f Mo -> %.2f Mo (%d texture(s) reduites)"
          % (poids_avant, poids, touchees))
    print("secours   %s" % secours.name)


if __name__ == "__main__":
    main()
