#!/usr/bin/env python3
"""Deplie un personnage d'un seul bloc et lui peint une texture.

    blender -b -P outils/texturer_modele.py -- --fichier assets/modeles/walt_sculpte.obj \\
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
    if h > 0.90:
        # L'avant de la tete recoit le visage. En Blender l'avant est -Y.
        return "visage" if normale[1] < -0.35 else "crane"
    if h > 0.855:
        return "peau"                                        # cou
    # Les mains pendent a hauteur de hanche, loin de l'axe.
    if lat > 0.72 and 0.42 < h < 0.60:
        return "peau"
    # Les avant-bras aussi, un peu plus haut.
    if lat > 0.78 and 0.58 < h < 0.72:
        return "peau"
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

    # Reperes de la tete, mesures sur les faces qui la composent — pas sur la
    # boite entiere. Cadrer le visage sur la largeur des EPAULES l'ecraserait
    # au milieu du crane, minuscule et decentre.
    tete_bas = zmin + 0.90 * (zmax - zmin)
    tetes = [v.co.x for v in me.vertices if v.co.z > tete_bas]
    tete_gauche = min(tetes) if tetes else xmin
    tete_droite = max(tetes) if tetes else xmax

    image = Image(a.taille, (int(tenue["haut"][0]), int(tenue["haut"][1]), int(tenue["haut"][2])))
    uv = me.uv_layers.active.data
    compte = {}

    for poly in me.polygons:
        centre = poly.center
        r = region(centre, poly.normal, boite)
        compte[r] = compte.get(r, 0) + 1

        coords = [(uv[i].uv[0], uv[i].uv[1]) for i in poly.loop_indices]
        points = [tuple(me.vertices[i].co) for i in poly.vertices]

        if r == "visage":
            # Le visage est projete DEPUIS L'AVANT : la position 3D du pixel
            # decide de l'endroit ou l'on pioche dans l'atlas de tete. C'est
            # ce qui met les yeux a hauteur des yeux, sans depliage manuel —
            # et par PIXEL, donc le dessin ne suit pas le decoupage.
            def couleur_de(p):
                fx = (p[0] - tete_gauche) / max(1e-6, tete_droite - tete_gauche)
                fz = (p[2] - tete_bas) / max(1e-6, zmax - tete_bas)
                # Moitie gauche de l'atlas = le visage ; v croit vers le bas.
                return visage(0.5 * min(0.999, max(0.0, fx)),
                              1.0 - min(0.999, max(0.0, fz)))
        elif r == "crane":
            def couleur_de(p):
                fz = (p[2] - tete_bas) / max(1e-6, zmax - tete_bas)
                return visage(0.75, 1.0 - min(0.999, max(0.0, fz)))
        elif r == "peau":
            couleur_de = peau
        elif r == "chemise":
            couleur_de = haut
        elif r == "pantalon":
            couleur_de = bas
        else:
            couleur_de = chaussure

        # Le visage et le crane sont peints en 3D, le reste en UV : une
        # texture de tissu n'a aucune raison de suivre la geometrie.
        en_3d = r in ("visage", "crane")
        for k in range(1, len(coords) - 1):
            tri = [coords[0], coords[k], coords[k + 1]]
            pts = [points[0], points[k], points[k + 1]] if en_3d else None
            image.triangle(tri, couleur_de, pts)

    sortie = Path(a.sortie)
    if not sortie.is_absolute():
        sortie = racine / sortie
    sortie.parent.mkdir(parents=True, exist_ok=True)
    png = sortie.with_suffix(".png")
    gen.ecrire_png(png, a.taille, a.taille, image.px)

    mat = bpy.data.materials.new(sortie.stem)
    mat.use_nodes = True
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
