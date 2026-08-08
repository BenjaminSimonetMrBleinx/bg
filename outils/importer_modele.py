#!/usr/bin/env python3
"""Convertit un modele livre (.obj, .fbx, .dae, .stl, .glb) en .glb du projet.

    blender -b -P outils/importer_modele.py -- --fichier "livraisons/modeles/walt.obj" \\
            --hauteur 1.78 --sortie game/assets/personnages/walt_sculpte.glb

Ce que fait la conversion, et pourquoi chaque etape est necessaire :

  - MISE A L'ECHELLE. Un modele arrive presque toujours a une taille
    arbitraire — celui-ci mesurait 1,0 unite de haut. Dans le jeu, un
    personnage fait 1,78 m et une porte 2,05 : un modele a la mauvaise
    echelle traverse les murs ou disparait sous le trottoir.

  - PIEDS A L'ORIGINE. Nos personnages sont poses par leur point le plus
    bas. Un modele centre sur son milieu s'enfonce de la moitie de sa taille
    dans le sol, et on croit a un probleme de collision.

  - ORIENTATION. L'avant d'un noeud Godot est -Z. Un modele qui regarde
    ailleurs marche en crabe, et le defaut est difficile a diagnostiquer une
    fois qu'il est anime.

Ce que la conversion ne peut PAS faire :

  - inventer des coordonnees de texture. Sans UV, le modele restera d'une
    seule couleur, quoi qu'on lui applique.
  - le decouper en segments animables. C'est un travail a part.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

# lire_glb vit a cote et n'importe pas bpy : c'est lui qui dit ce que le fichier
# CONTIENT, par opposition a ce que la scene annoncait. Blender ne met pas le
# dossier du script dans le chemin d'import, il faut l'y mettre.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import lire_glb  # noqa: E402


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Import d un modele livre")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--hauteur", type=float, default=1.78,
                    help="hauteur voulue en metres, 0 pour ne pas redimensionner")
    ap.add_argument("--lacet", type=float, default=0.0,
                    help="rotation autour de la verticale, en degres")
    ap.add_argument("--couleur", default="",
                    help="texture a appliquer, prise dans .tmp/textures")
    ap.add_argument("--triangles", type=int, default=0,
                    help="decime jusqu a ce nombre de triangles, 0 pour ne pas toucher")
    # LE DEFAUT EST 256, PAS 0 — et c'est un changement d'apres mesure.
    #
    # A 0, l'outil ne touchait a rien, et c'est par la que l'Aztek est entree
    # dans le jeu avec ses trois cartes de 2048 px : 10,1 Mo pour une voiture,
    # dans un monde ou la ville entiere tient en 128 px et ou l'interieur du QG
    # est en 32. La charte prevenait — « un modele livre avec une texture 2048
    # est plus net que tout ce qui l'entoure, et ca se voit plus qu'un modele
    # rate » — mais rien ne l'appliquait.
    #
    # 256 est le palier courant. Un asset heros passe -TextureMax 512, et
    # -TextureMax 0 reste le moyen EXPLICITE de dire « ne touche pas ».
    ap.add_argument("--texture-max", type=int, default=256, dest="texture_max",
                    help="cote maximal des textures en pixels, 0 pour ne pas toucher")
    ap.add_argument("--plat", action="store_true",
                    help="ne garde que la couleur de base : jette la normale, "
                         "le metallique, la rugosite et l emission")
    return ap.parse_args(argv)


def charger(chemin: Path) -> None:
    suffixe = chemin.suffix.lower()
    if suffixe == ".obj":
        bpy.ops.wm.obj_import(filepath=str(chemin))
    elif suffixe == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(chemin))
    elif suffixe == ".dae":
        bpy.ops.wm.collada_import(filepath=str(chemin))
    elif suffixe == ".stl":
        bpy.ops.wm.stl_import(filepath=str(chemin))
    elif suffixe in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(chemin))
    else:
        raise SystemExit("format non gere : %s" % suffixe)


def suffixe_de(chemin: Path) -> str:
    return chemin.suffix.lower()


def boite(objets) -> tuple:
    """Boite englobante en coordonnees monde."""
    mini = [1e9, 1e9, 1e9]
    maxi = [-1e9, -1e9, -1e9]
    for o in objets:
        for coin in o.bound_box:
            p = o.matrix_world @ bpy.mathutils.Vector(coin) if False else \
                o.matrix_world @ __import__("mathutils").Vector(coin)
            for i in range(3):
                mini[i] = min(mini[i], p[i])
                maxi[i] = max(maxi[i], p[i])
    return mini, maxi


def triangles_de(obj) -> int:
    """Le compte en TRIANGLES, pas en faces.

    Un quad est une face et deux triangles. Compter les faces sous-estime un
    modele modelise proprement d un facteur deux, et c est le budget en
    triangles que la charte fixe.
    """
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimer(obj, cible: int) -> None:
    """Ramene le maillage a la cible, et DIT ce qu il a obtenu.

    Le decimateur ne tombe jamais pile sur le nombre demande : il effondre des
    aretes jusqu a approcher le ratio. On imprime donc le resultat reel, parce
    que c est lui qui compte et pas la consigne.
    """
    avant = triangles_de(obj)
    if cible <= 0 or avant <= cible:
        print("triangles %d, sous la cible : rien a decimer" % avant)
        return
    m = obj.modifiers.new("decimation", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = cible / avant
    bpy.ops.object.modifier_apply(modifier=m.name)
    print("decimation %d -> %d triangles (cible %d)"
          % (avant, triangles_de(obj), cible))


def aplatir(mat) -> None:
    """Ne garde que la couleur de base d un materiau.

    Le rendu du jeu est plat : pas de normale, pas de metallique, pas de
    rugosite par texture. Un modele livre en PBR complet arrive avec quatre
    images dont trois ne seront jamais lues â€” elles ne changeraient rien a
    l ecran et pesent l essentiel du fichier.

    On coupe TOUT ce qui entre dans le shader sauf la couleur de base, plutot
    que d enumerer les noms des entrees : ils changent d une version de Blender
    a l autre, et une liste qui vieillit laisse passer ce qu elle ne connait
    pas.
    """
    # ON INTERROGE node_tree, PAS use_nodes.
    #
    # `Material.use_nodes` est deprecie et disparait en Blender 6 : l appeler
    # ecrit un avertissement sur la sortie d ERREUR, ce qui suffit a faire
    # echouer `bg.ps1 integrer` — PowerShell traite la moindre ligne de stderr
    # d un binaire natif comme une erreur. Un outil qui marche mais qu on ne
    # peut plus appeler est un outil casse.
    if mat is None or mat.node_tree is None:
        return
    principal = next((n for n in mat.node_tree.nodes
                      if n.type == "BSDF_PRINCIPLED"), None)
    if principal is None:
        return
    for lien in list(mat.node_tree.links):
        if lien.to_node == principal and lien.to_socket.name != "Base Color":
            mat.node_tree.links.remove(lien)
    principal.inputs["Metallic"].default_value = 0.0
    principal.inputs["Roughness"].default_value = 0.95

    # COUPER UN LIEN NE REMET PAS LA VALEUR PAR DEFAUT — il decouvre celle qui
    # etait dessous, et elle n a jamais servi.
    #
    # L emission du Principled vaut blanc, force 1. Tant qu une texture
    # emissive y est branchee, elle module cette valeur et tout va bien. Le
    # lien coupe, il reste un blanc plein : le materiau EMET, l export ecrit
    # emissiveFactor [1, 1, 1], et le modele apparait entierement blanc dans le
    # jeu — sa couleur de base est bien la, elle est juste noyee. Trois
    # variantes sont sorties comme des blocs de neige avant qu on lise le
    # materiau du fichier produit.
    for nom in ("Emission Strength",):
        if nom in principal.inputs:
            principal.inputs[nom].default_value = 0.0
    for nom in ("Emission Color", "Emission"):
        if nom in principal.inputs:
            try:
                principal.inputs[nom].default_value = (0.0, 0.0, 0.0, 1.0)
            except (TypeError, ValueError):
                pass
    # LES ORPHELINS SE SUPPRIMENT EN CASCADE, et il faut boucler.
    #
    # Une normale passe par un noeud Normal Map avant d atteindre le shader :
    # couper le lien final rend ce noeud orphelin, mais l image reste accrochee
    # A LUI et parait donc encore utilisee. Une seule passe laissait ainsi deux
    # textures dans la scene â€” l export ne les prenait pas, mais le
    # redimensionnement les traitait et la sortie annoncait trois textures pour
    # un fichier qui n en contient qu une.
    encore = True
    while encore:
        encore = False
        for n in list(mat.node_tree.nodes):
            if n.type in ("TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "MAPPING",
                          "TEX_COORD") and not any(s.is_linked for s in n.outputs):
                mat.node_tree.nodes.remove(n)
                encore = True


def reduire_les_textures(mat, maxi: int) -> None:
    """Ramene chaque image a un cote maximal, en puissance de deux."""
    if mat is None or mat.node_tree is None or maxi <= 0:
        return
    for n in mat.node_tree.nodes:
        if n.type != "TEX_IMAGE" or n.image is None:
            continue
        largeur, hauteur = n.image.size
        if max(largeur, hauteur) <= maxi:
            continue
        f = maxi / max(largeur, hauteur)
        n.image.scale(max(1, int(largeur * f)), max(1, int(hauteur * f)))
        print("texture   %s : %dx%d -> %dx%d"
              % (n.image.name, largeur, hauteur, *n.image.size))


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    fichier = Path(a.fichier)
    if not fichier.is_absolute():
        fichier = racine / fichier
    if not fichier.exists():
        raise SystemExit("introuvable : %s" % fichier)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    charger(fichier)

    maillages = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not maillages:
        raise SystemExit("aucun maillage dans %s" % fichier.name)

    faces = sum(len(o.data.polygons) for o in maillages)
    uv = any(len(o.data.uv_layers) > 0 for o in maillages)

    mini, maxi = boite(maillages)
    taille = [maxi[i] - mini[i] for i in range(3)]
    print("")
    print("modele    %s" % fichier.name)
    print("pieces    %d" % len(maillages))
    print("faces     %d" % faces)
    print("UV        %s" % ("oui" if uv else "NON — il restera d une seule couleur"))
    print("taille    %.3f x %.3f x %.3f (X, Y, Z)" % tuple(taille))

    # Blender est en Z-up : la hauteur est Z. Un modele exporte depuis un
    # logiciel Y-up arrive couche, ce que la taille revele tout de suite.
    #
    # MAIS l heuristique « plus long en Y qu en Z » ne vaut que pour les
    # formats qui ne transportent PAS leur axe vertical : .obj et .stl. Le
    # glTF, lui, declare Y-up et l importateur de Blender a deja redresse le
    # modele. Y appliquer la regle couche une voiture — qui est legitimement
    # plus longue que haute — sur le nez. C est ce qui est arrive a l Aztek.
    sans_axe = suffixe_de(fichier) in (".obj", ".stl")
    couche = sans_axe and taille[1] > taille[2] * 1.4
    if couche:
        print("          l objet est plus long en Y qu en Z : il arrive couche,")
        print("          on le redresse d un quart de tour.")

    # ON DETACHE LES PARENTS AVANT DE FUSIONNER, en gardant la matrice monde.
    #
    # Piege paye le 08/08/2026 sur le premier modele genere : annonce a 0,48 m,
    # ecrit a 1,198 m. Exactement le facteur 2,5 de l'echelle du noeud racine
    # que Tripo pose au-dessus du maillage.
    #
    # bpy.ops.object.join() fusionne dans l'objet actif et repart de SA matrice
    # a lui : la transformation du parent est perdue en chemin. La boite mesuree
    # ensuite decrit donc un objet qui n'existe plus, et l'echelle calculee
    # dessus est fausse d'autant — sans que rien ne le signale.
    #
    # matrix_basis = matrix_world fige la transformation complete dans l'objet
    # lui-meme ; parent = None le detache ensuite sans qu'il bouge.
    for o in maillages:
        if o.parent is not None:
            o.matrix_basis = o.matrix_world.copy()
            o.parent = None
    for o in maillages:
        o.select_set(True)
    bpy.context.view_layer.objects.active = maillages[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = Path(a.sortie).stem

    if couche:
        obj.rotation_euler[0] = math.pi / 2
        bpy.ops.object.transform_apply(rotation=True)

    if a.lacet:
        # transform_apply AGIT SUR LA SELECTION, et rien d'autre.
        #
        # L'appel etait la depuis le debut et n'a jamais rien fait : aucun
        # objet n'etait selectionne ni actif a ce moment, l'operateur repartait
        # sans toucher a quoi que ce soit et sans se plaindre. Le lacet demande
        # etait donc silencieusement ignore — la Pontiac est arrivee en travers
        # de la route, et deux tentatives de « la retourner » n'ont rien change
        # puisque ni l'une ni l'autre n'etait appliquee.
        #
        # Mesurable, et desormais mesure : la sortie annonce les cotes finaux
        # dans le repere de GODOT, ou une voiture doit etre longue sur Z.
        obj.data.transform(Matrix.Rotation(math.radians(a.lacet), 4, "Z"))
        obj.data.update()

    mini, maxi = boite([obj])
    hauteur = maxi[2] - mini[2]
    if a.hauteur > 0 and hauteur > 1e-6:
        facteur = a.hauteur / hauteur
        # ON MULTIPLIE L'ECHELLE, ON NE LA REMPLACE PAS.
        #
        # `obj.scale = (facteur,) * 3` ecrasait celle que le modele portait
        # deja. Tant que les modeles arrivaient a l'echelle 1, ca ne se voyait
        # pas — et tous les modeles livres a la main l'etaient.
        #
        # Le premier modele genere ne l'etait pas : Tripo pose une echelle de
        # 0,4008 sur son noeud. La boite mesurait donc 0,400 m, le facteur
        # calcule dessus valait bien 1,2 — et l'ecraser rendait 0,998 x 1,2,
        # soit 1,198 m au lieu de 0,48. Deux fois et demie trop grand, sans un
        # mot, avec une console qui annoncait le bon chiffre.
        #
        # Trouve le 08/08/2026 par le garde-fou qui relit le fichier ecrit. Sans
        # lui, la verrerie entrait dans le camping-car a la taille d'un homme.
        obj.scale = tuple(s * facteur for s in obj.scale)
        bpy.ops.object.transform_apply(scale=True)
        print("echelle   x%.4f pour atteindre %.2f m" % (facteur, a.hauteur))

    # Pieds a l origine, centre en X et Z : c est la convention de tous nos
    # personnages, et ce qui permet de les poser sans reglage.
    mini, maxi = boite([obj])
    obj.location = (
        -(mini[0] + maxi[0]) / 2.0,
        -(mini[1] + maxi[1]) / 2.0,
        -mini[2],
    )
    bpy.ops.object.transform_apply(location=True)

    if a.couleur:
        png = racine / ".tmp/textures" / f"{a.couleur}.png"
        mat = bpy.data.materials.new(a.couleur)
        principal = mat.node_tree.nodes["Principled BSDF"]
        principal.inputs["Roughness"].default_value = 0.95
        principal.inputs["Metallic"].default_value = 0.0
        if png.exists() and uv:
            img = bpy.data.images.load(str(png), check_existing=True)
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = img
            tex.interpolation = "Linear"
            mat.node_tree.links.new(principal.inputs["Base Color"], tex.outputs["Color"])
        elif png.exists():
            # Sans UV, une texture ne s applique nulle part : on prend sa
            # teinte moyenne plutot que de livrer un modele blanc.
            img = bpy.data.images.load(str(png), check_existing=True)
            px = list(img.pixels)
            n = max(1, len(px) // 4)
            moy = [sum(px[i::4]) / n for i in range(3)]
            principal.inputs["Base Color"].default_value = (*moy, 1.0)
            print("couleur   teinte moyenne de %s.png, faute d UV" % a.couleur)
        obj.data.materials.clear()
        obj.data.materials.append(mat)

    # LE DEGRAISSAGE VIENT EN DERNIER, une fois la geometrie posee.
    #
    # Un modele livre arrive au budget de son auteur, pas a celui du jeu. Ce
    # projet vise le rendu PS2 : la charte parle de contraintes esthetiques et
    # non de performance, et un vehicule beaucoup plus fin que les maisons
    # autour de lui se voit davantage qu un modele rate.
    decimer(obj, a.triangles)
    for mat in obj.data.materials:
        if a.plat:
            aplatir(mat)
        reduire_les_textures(mat, a.texture_max)

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(sortie),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    # ON MESURE LE FICHIER ECRIT, pas la scene qui l a produit. C est la regle
    # la plus chere du projet, et elle a ete apprise cinq fois maintenant : un
    # outil annonce un nombre juste et ecrit un fichier faux.
    if not sortie.exists():
        raise SystemExit("rien n a ete ecrit : %s" % sortie)
    print("produit   %.2f Mo" % (sortie.stat().st_size / 1048576.0))
    lire_glb.imprimer(sortie)

    # ET ON REFUSE SI LA HAUTEUR N EST PAS CELLE QU ON A DEMANDEE.
    #
    # C est le garde-fou qui manquait, et il a coute un modele le 08/08/2026 :
    # la verrerie du labo, demandee a 0,48 m, est sortie a 1,198. La scene
    # Blender annoncait pourtant 0,48 — elle mesurait un objet detache de son
    # parent par le join, donc plus petit d un facteur 2,5 que ce qui a ete
    # exporte.
    #
    # Une tolerance de 1 % : le decimateur et l export bougent la derniere
    # decimale, et refuser sur du bruit rendrait l outil inutilisable.
    mesuree = lire_glb.decrire(sortie).get("hauteur")
    if a.hauteur > 0 and mesuree:
        ecart = abs(mesuree - a.hauteur) / a.hauteur
        if ecart > 0.01:
            raise SystemExit(
                "ECHEC : hauteur demandee %.3f m, ECRITE %.3f m (%.0f %% d ecart).\n"
                "        Le fichier est en place mais il est FAUX — ne pas le "
                "garder.\n"
                "        Relancer avec -Hauteur %.3f donnerait la bonne taille, "
                "mais la\n"
                "        vraie question est pourquoi la mesure et l ecriture ne "
                "s accordent pas."
                % (a.hauteur, mesuree, ecart * 100.0,
                   a.hauteur * a.hauteur / mesuree if mesuree > 0 else 0.0))
    print("sortie    %s" % sortie)


if __name__ == "__main__":
    main()
