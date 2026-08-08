#!/usr/bin/env python3
"""Deplie un personnage d'un seul bloc et lui peint une texture.

    blender -b -P outils/texturer_modele.py -- --fichier livraisons/modeles/walt_sculpte.obj \\
            --sortie game/assets/personnages/walt_texture.glb --qui walter

Le probleme, et la facon de le contourner
-----------------------------------------
Un modele sculpte arrive sans coordonnees de texture. Blender sait en
fabriquer tout seul (Smart UV Project), mais il place les ilots ou il veut :
savoir ensuite QUEL morceau de l'image correspond a la tete est impossible a
l'oeil, et impossible a deviner par script.

On prend donc le probleme a l'envers. Pour chaque face du maillage on regarde
ou elle se trouve DANS L'ESPACE — a quelle hauteur du corps, de quel cote,
tournee vers l'avant ou non — et on peint sa case UV de la couleur qui
convient. Le dépliage n'a plus besoin d'etre lisible : il sert seulement
d'adresse.

C'est ainsi qu'on obtient une chemise sur le torse et un pantalon sur les
jambes sans que personne n'ait ouvert un logiciel de peinture. Et pour la
tete, on va plus loin : les faces tournees vers l'avant recoivent le VISAGE
deja dessine par gen_textures.py, projete depuis l'avant.

Limite assumee : la decoupe suit des seuils de hauteur, pas l'anatomie. Une
main qui trainerait a hauteur de cuisse sera peinte en pantalon. A 512 pixels
de large, personne ne le verra.
"""

from __future__ import annotations

import argparse
import importlib.util
import math
import sys
from pathlib import Path

import bpy
import bmesh


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Depliage et texture d un modele")
    ap.add_argument("--fichier", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--qui", default="walter",
                    help="personnage de VISAGES / TENUES dans gen_textures.py")
    ap.add_argument("--taille", type=int, default=256)
    ap.add_argument("--hauteur", type=float, default=1.78)
    ap.add_argument("--angle-lisse", dest="angle_lisse", type=float, default=48.0,
                    help="au-dela de cet angle, l arete reste franche")
    return ap.parse_args(argv)


def charger_generateur(racine: Path):
    """Recupere les palettes et l'atlas de visage deja ecrits pour le jeu.

    Les reutiliser plutot que d'en inventer d'autres garantit que le modele
    sculpte et les personnages generes se ressemblent : meme carnation, meme
    chemise, meme visage.
    """
    chemin = racine / "outils" / "gen_textures.py"
    spec = importlib.util.spec_from_file_location("gen_textures", chemin)
    module = importlib.util.module_from_spec(spec)
    sys.argv = ["gen_textures"]
    spec.loader.exec_module(module)
    return module


# --------------------------------------------------------------- rasterisation


class Image:
    """Image RVB en memoire, remplie triangle par triangle."""

    def __init__(self, taille: int, fond):
        self.n = taille
        self.px = bytearray(taille * taille * 3)
        for i in range(taille * taille):
            self.px[i * 3 + 0] = fond[0]
            self.px[i * 3 + 1] = fond[1]
            self.px[i * 3 + 2] = fond[2]

    def poser(self, x: int, y: int, c) -> None:
        if 0 <= x < self.n and 0 <= y < self.n:
            i = (y * self.n + x) * 3
            self.px[i] = max(0, min(255, int(c[0])))
            self.px[i + 1] = max(0, min(255, int(c[1])))
            self.px[i + 2] = max(0, min(255, int(c[2])))

    def triangle(self, uvs, couleur_de, points=None) -> None:
        """Remplit un triangle UV.

        couleur_de(u, v) donne la couleur, ou couleur_de(p) si `points` est
        fourni — p etant alors la position 3D interpolee du pixel.

        Cette interpolation change tout pour le visage. Peindre chaque
        triangle d'une seule couleur prise en son centre donnait une figure
        en taches : un oeil couvrait une facette entiere, ou disparaissait
        entre deux. En interpolant, le dessin traverse la geometrie sans
        s'occuper de son decoupage.

        On DEBORDE d'un pixel tout autour. Sans cette marge, le filtrage
        bilineaire va chercher la couleur du fond juste au bord de chaque
        ilot, et le modele se retrouve souligne de lignes claires a chaque
        couture — le defaut le plus visible d'une texture generee.
        """
        xs = [u[0] * (self.n - 1) for u in uvs]
        ys = [(1.0 - u[1]) * (self.n - 1) for u in uvs]
        x0 = max(0, int(min(xs)) - 2)
        x1 = min(self.n - 1, int(max(xs)) + 2)
        y0 = max(0, int(min(ys)) - 2)
        y1 = min(self.n - 1, int(max(ys)) + 2)

        ax, ay = xs[0], ys[0]
        bx, by = xs[1], ys[1]
        cx, cy = xs[2], ys[2]
        aire = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(aire) < 1e-9:
            return

        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                w0 = ((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / aire
                w1 = ((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / aire
                w2 = 1.0 - w0 - w1
                # -0.06 au lieu de 0 : c'est la marge de debordement.
                if w0 < -0.06 or w1 < -0.06 or w2 < -0.06:
                    continue
                if points is None:
                    u = x / (self.n - 1)
                    v = 1.0 - y / (self.n - 1)
                    self.poser(x, y, couleur_de(u, v))
                else:
                    p = (
                        points[0][0] * w0 + points[1][0] * w1 + points[2][0] * w2,
                        points[0][1] * w0 + points[1][1] * w1 + points[2][1] * w2,
                        points[0][2] * w0 + points[1][2] * w1 + points[2][2] * w2,
                    )
                    self.poser(x, y, couleur_de(p))


# ----------------------------------------------------------------- le corps


COU = 0.855          # fraction de la hauteur ou commence la tete


def visage_sculpte(traits):
    """Peint un visage DIRECTEMENT sur une tete, en coordonnees de tete.

    On n'utilise pas l'atlas de gen_textures.py, et c'est le coeur du sujet.
    Cet atlas est dessine pour un CUBE : le carre avant represente tout le
    visage, le bouc y occupe le bas 30 %. Plaque sur un crane reel, ce bas
    30 % ne couvre pas le menton — il couvre la machoire ET la bouche, d'ou
    une tache noire au milieu de la figure.

    Ici les reperes sont ceux d'une tete vue de face, du cou (fz = 0) au
    sommet du crane (fz = 1), et fx s'ecarte de l'axe (0 au nez, 1 a
    l'oreille) :

        menton    0,15      nez       0,45
        bouche    0,30      yeux      0,56
        sourcils  0,64      naissance des cheveux  0,76

    Chaque trait est donc pose ou il est sur un visage, pas ou il tombait
    sur une boite.
    """
    base_peau = traits["peau"]
    base_poil = traits["poil"]
    lunettes = traits.get("lunettes", False)
    bouc = traits.get("bouc", False)
    moustache = traits.get("moustache", False)
    coupe = traits.get("cheveux", "courts")

    def rendu(fx, fz, bruit):
        peau = (base_peau[0] + bruit * 12, base_peau[1] + bruit * 10,
                base_peau[2] + bruit * 9)
        poil = (base_poil[0] + bruit * 10, base_poil[1] + bruit * 9,
                base_poil[2] + bruit * 8)
        a = abs(fx)

        # Cheveux : couronne sur les cotes et l'arriere, sommet degage.
        if coupe == "calvitie":
            if 0.50 < fz < 0.86 and a > 0.62:
                return poil
        elif coupe == "longs":
            if fz > 0.72 or (fz > 0.30 and a > 0.66):
                return poil
        else:
            if fz > 0.74 or (fz > 0.52 and a > 0.70):
                return poil

        # Le bouc suit la machoire : large au menton, il se resserre en
        # montant vers les levres. Une zone rectangulaire donnait un carre
        # noir plaque au milieu de la figure.
        if bouc and 0.135 < fz < 0.295:
            largeur = 0.30 - (fz - 0.135) * 0.80
            if a < largeur:
                return poil
        if moustache and 0.27 <= fz < 0.335 and 0.02 < a < 0.165:
            return poil

        # Sourcils, un peu au-dessus des yeux.
        if 0.625 < fz < 0.675 and 0.11 < a < 0.38:
            return poil

        # Yeux : blanc, avec la pupille au centre.
        if 0.515 < fz < 0.585 and 0.11 < a < 0.35:
            if abs(a - 0.23) < 0.055 and 0.53 < fz < 0.572:
                return (34, 36, 42)
            return (222, 220, 214)

        if lunettes:
            # Monture : le contour du verre, pas le verre lui-meme.
            dans = 0.495 < fz < 0.605 and 0.09 < a < 0.375
            if dans:
                bord = fz < 0.515 or fz > 0.585 or a < 0.105 or a > 0.355
                if bord:
                    return (58, 54, 50)
            # Pont entre les deux verres, et branches vers les oreilles.
            if 0.545 < fz < 0.567 and a <= 0.09:
                return (58, 54, 50)
            if 0.545 < fz < 0.567 and a > 0.375:
                return (58, 54, 50)

        # Ombre du nez : une simple bande verticale decalee, aucun relief.
        if 0.33 < fz < 0.50 and 0.015 < fx < 0.055:
            return (peau[0] * 0.87, peau[1] * 0.87, peau[2] * 0.87)

        # Creux des joues, pour que la figure ne soit pas un aplat.
        if 0.22 < fz < 0.44 and 0.40 < a < 0.62:
            return (peau[0] * 0.94, peau[1] * 0.94, peau[2] * 0.94)

        return peau

    return rendu


def region(centre, normale, boite) -> str:
    """A quelle partie du corps appartient cette face ?

    Tout est en proportion de la boite englobante, jamais en metres : le
    meme classement marche pour un modele de n'importe quelle taille.
    """
    (xmin, xmax), (ymin, ymax), (zmin, zmax) = boite
    h = (centre[2] - zmin) / max(1e-6, zmax - zmin)          # 0 pieds, 1 tete
    demi = max(1e-6, (xmax - xmin) / 2.0)
    lat = abs(centre[0] - (xmin + xmax) / 2.0) / demi        # 0 axe, 1 bord

    if h < 0.055:
        return "chaussure"
    if h > COU:
        # L'avant de la tete recoit le visage. En Blender l'avant est -Y.
        #
        # Le seuil est LARGE : a -0,35 le visage s'arretait net sur une arete
        # verticale, et de trois quarts on voyait une joue nue a cote d'un
        # oeil. En prenant tout ce qui n'est pas franchement de dos, le
        # dessin fait le tour et la couture disparait.
        return "visage" if normale[1] < -0.25 else "crane"
    if h > COU - 0.02:
        return "peau"                                        # cou
    # Bras et mains : tout ce qui est loin de l'axe, du haut du bras jusqu'en
    # bas. Le classement doit suivre EXACTEMENT celui de segmenter_modele.py,
    # sinon un morceau de main est peint en pantalon puis anime comme une
    # main — et personne ne comprend d'ou vient la tache.
    if lat > 0.55 and h > 0.32:
        return "chemise" if h >= 0.640 else "peau"
    if h > 0.50:
        return "chemise"
    return "pantalon"


def main() -> None:
    a = arguments()
    racine = Path.cwd()
    gen = charger_generateur(racine)

    traits = gen.VISAGES.get(a.qui, gen.VISAGES["walter"])
    tenue = gen.TENUES.get(a.qui, gen.TENUES["walter"])
    visage = gen.visage(traits)
    face = visage_sculpte(traits)
    peau = gen.carnation(tenue["peau"])
    haut = gen.haut(tenue["haut"], tenue["capuche"])
    bas = gen.bas(tenue["bas"])
    chaussure = gen.chaussure

    fichier = Path(a.fichier)
    if not fichier.is_absolute():
        fichier = racine / fichier

    bpy.ops.wm.read_factory_settings(use_empty=True)
    suffixe = fichier.suffix.lower()
    if suffixe == ".obj":
        bpy.ops.wm.obj_import(filepath=str(fichier))
    elif suffixe in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(fichier))
    elif suffixe == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(fichier))
    else:
        raise SystemExit("format non gere : %s" % suffixe)

    maillages = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not maillages:
        raise SystemExit("aucun maillage")
    for o in maillages:
        o.select_set(True)
    bpy.context.view_layer.objects.active = maillages[0]
    if len(maillages) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active

    # Mise a l'echelle et pieds a l'origine, comme importer_modele.py.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = obj.data
    zs = [v.co.z for v in me.vertices]
    hauteur = max(zs) - min(zs)
    if a.hauteur > 0 and hauteur > 1e-6:
        f = a.hauteur / hauteur
        obj.scale = (f,) * 3
        bpy.ops.object.transform_apply(scale=True)
    me = obj.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    obj.location = (-(min(xs) + max(xs)) / 2.0, -(min(ys) + max(ys)) / 2.0, -min(zs))
    bpy.ops.object.transform_apply(location=True)

    # Depliage automatique. Sa lisibilite n'a aucune importance : il ne sert
    # que d'adresse pour poser la couleur.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    me = obj.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    boite = ((min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs)))
    (xmin, xmax), _, (zmin, zmax) = boite

    # --- la tete recoit son propre depliage, plein cadre -------------------
    #
    # C'est LE correctif du visage, et il n'a rien a voir avec le dessin des
    # traits.
    #
    # Le depliage automatique decoupe la tete en dizaines d'ilots minuscules :
    # sur une image partagee avec tout le corps, chaque triangle du visage
    # tombe a trois ou quatre pixels. Le debordement d'un pixel — indispensable
    # ailleurs pour eviter les coutures claires — fait alors baver chaque ilot
    # sur ses voisins, et la figure se couvre de taches sales.
    #
    # On remplace donc les UV de la tete par une projection frontale unique :
    # l'avant du crane occupe un quart entier de l'image, l'arriere un autre.
    # Le visage passe de quelques dizaines de pixels a plus de deux cents de
    # cote, et il n'y a plus aucune couture a l'interieur.
    uv_layer = me.uv_layers.active.data
    tete_z0 = zmin + COU * (zmax - zmin)
    tetes_co = [v.co for v in me.vertices if v.co.z > tete_z0]
    if tetes_co:
        tx0 = min(p.x for p in tetes_co)
        tx1 = max(p.x for p in tetes_co)
        for poly in me.polygons:
            if poly.center[2] <= tete_z0:
                # Le corps est comprime dans la moitie basse de l'image.
                for i in poly.loop_indices:
                    uv_layer[i].uv[1] = uv_layer[i].uv[1] * 0.48
                continue
            devant = poly.normal[1] < -0.25
            u0 = 0.02 if devant else 0.52
            for i in poly.loop_indices:
                p = me.vertices[me.loops[i].vertex_index].co
                fx = (p.x - tx0) / max(1e-6, tx1 - tx0)
                fz = (p.z - tete_z0) / max(1e-6, zmax - tete_z0)
                if not devant:
                    fx = 1.0 - fx          # l'arriere est vu en miroir
                uv_layer[i].uv[0] = u0 + 0.46 * min(1.0, max(0.0, fx))
                uv_layer[i].uv[1] = 0.51 + 0.47 * min(1.0, max(0.0, fz))

    # Reperes de la tete, mesures sur la TETE ENTIERE, depuis le cou.
    #
    # Une premiere version les mesurait au-dessus de 90 % de la hauteur —
    # c'est-a-dire sur le sommet du crane, sa partie la plus etroite. Le
    # visage se retrouvait comprime au milieu du front, et le bouc, dessine
    # dans le bas de l'atlas, bavait sur la bouche.
    tete_bas = zmin + COU * (zmax - zmin)
    tetes = [v.co for v in me.vertices if v.co.z > tete_bas]
    tete_gauche = min(p.x for p in tetes) if tetes else xmin
    tete_droite = max(p.x for p in tetes) if tetes else xmax
    tete_cx = (tete_gauche + tete_droite) / 2.0
    demi_tete = max(1e-6, (tete_droite - tete_gauche) / 2.0)

    # Centre du corps, pour l'enroulement du tissu.
    cx = (xmin + xmax) / 2.0
    ys = [v.co.y for v in me.vertices]
    cy = (min(ys) + max(ys)) / 2.0

    image = Image(a.taille, (int(tenue["haut"][0]), int(tenue["haut"][1]), int(tenue["haut"][2])))
    uv = me.uv_layers.active.data
    compte = {}

    for poly in me.polygons:
        centre = poly.center
        r = region(centre, poly.normal, boite)
        compte[r] = compte.get(r, 0) + 1

        coords = [(uv[i].uv[0], uv[i].uv[1]) for i in poly.loop_indices]
        points = [tuple(me.vertices[i].co) for i in poly.vertices]

        # TOUT est peint depuis la position 3D, jamais depuis les UV.
        #
        # Peindre le tissu d'apres ses coordonnees UV donnait un resultat
        # mouchete : le depliage automatique decoupe le vetement en dizaines
        # d'ilots sans rapport entre eux, et le motif — col, boutonniere —
        # se retrouvait disperse au hasard. En enroulant la texture autour du
        # corps, la boutonniere descend le long du buste et le col fait le
        # tour du cou, comme un vetement.
        if r in ("visage", "crane"):
            # UNE SEULE fonction pour toute la tete, avant comme arriere.
            #
            # Les traits sont poses par leurs propres coordonnees et ne
            # sortent jamais de la zone du visage ; l'arriere recoit donc
            # naturellement de la peau et des cheveux, sans qu'on ait a le
            # traiter a part. Deux fonctions distinctes creaient une couture
            # verticale visible sur la tempe.
            devant = r == "visage"
            def couleur_de(p, _devant=devant):
                # Centre sur l AXE DU CORPS, pas sur la boite de la tete : le
                # nez et les oreilles la faussent, et le bouc se retrouvait
                # decale d un cote de la machoire.
                fx = (p[0] - cx) / max(1e-6, demi_tete)
                fz = (p[2] - tete_bas) / max(1e-6, zmax - tete_bas)
                fz = min(1.0, max(0.0, fz))
                n = (((int(abs(p[0]) * 8111) ^ int(abs(p[2]) * 9377)) % 100)
                     / 100.0 - 0.5)
                if not _devant:
                    # De dos, on ecarte volontairement fx hors de la zone des
                    # traits : pas d'oeil derriere la tete.
                    fx = 1.4 if fx >= 0 else -1.4
                return face(fx, fz, n)
        elif r == "peau":
            def couleur_de(p):
                return peau(p[0] * 3.1 % 1.0, p[2] * 3.1 % 1.0)
        elif r in ("chemise", "pantalon", "chaussure"):
            fn = haut if r == "chemise" else (bas if r == "pantalon" else chaussure)
            hauteur_tissu = 0.62 if r == "chemise" else 0.9
            def couleur_de(p, _fn=fn, _h=hauteur_tissu):
                # u fait le tour du corps, v monte : la texture s'enroule.
                angle = math.atan2(p[1] - cy, p[0] - cx)
                u = (angle / (2.0 * math.pi)) + 0.5
                v = ((p[2] - zmin) / max(1e-6, zmax - zmin)) / _h
                return _fn(u % 1.0, v % 1.0)
        else:
            couleur_de = chaussure

        for k in range(1, len(coords) - 1):
            image.triangle([coords[0], coords[k], coords[k + 1]],
                           couleur_de,
                           [points[0], points[k], points[k + 1]])

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)
    png = sortie.with_suffix(".png")
    gen.ecrire_png(png, a.taille, a.taille, image.px)

    mat = bpy.data.materials.new(sortie.stem)
    principal = mat.node_tree.nodes["Principled BSDF"]
    principal.inputs["Roughness"].default_value = 0.95
    principal.inputs["Metallic"].default_value = 0.0
    img = bpy.data.images.load(str(png), check_existing=True)
    img.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    mat.node_tree.links.new(principal.inputs["Base Color"], tex.outputs["Color"])
    me.materials.clear()
    me.materials.append(mat)

    # OMBRAGE LISSE, et c'est probablement le reglage le plus rentable de tout
    # ce script.
    #
    # En ombrage plat, chaque facette capte la lumiere separement : un crane
    # de cent trente triangles ressemble a un cristal taille, et aucune
    # texture n'y change quoi que ce soit. En lissant sous un angle donne, les
    # normales se moyennent d'une face a l'autre et la tete redevient ronde —
    # tandis que les aretes franches, comme le col ou le bord d'une semelle,
    # restent nettes parce qu'elles depassent l'angle.
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(a.angle_lisse))
    except Exception:
        # Selon la version de Blender, le lissage par angle est un operateur
        # ou un modificateur. On ne se laisse pas arreter par la difference.
        pass

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

    print("")
    print("faces peintes par region :")
    for r in sorted(compte):
        print("   %-10s %4d" % (r, compte[r]))
    print("texture   %s (%d px)" % (png.name, a.taille))
    print("sortie    %s" % sortie)


if __name__ == "__main__":
    main()
