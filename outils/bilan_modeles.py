"""Quels modeles 3D existent, et lesquels le jeu utilise vraiment.

    python outils/bilan_modeles.py

POURQUOI UN SCRIPT ET PAS UNE RECHERCHE. Une recherche interactive se tronque,
et une liste coupee lue comme complete a deja fait ajouter trois personnages
qui existaient (piege 29). Ici on lit TOUS les .glb et TOUS les fichiers qui
peuvent les citer, sans limite d'affichage.

CE QU'ON APPELLE « UTILISE » : le nom du fichier apparait dans une scene, un
script ou un fichier de donnees du jeu. Un modele qu'un GENERATEUR produit mais
que personne ne pose est inutilise — il pese dans le depot et dans les objets
LFS a chaque tag, pour rien.
"""
import io
import os
import re

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(RACINE, "game", "assets")

# Ou l'on cite un modele : les scenes, le code, les donnees, et les generateurs.
A_LIRE = [
    (os.path.join(RACINE, "game", "scenes"), (".tscn",)),
    (os.path.join(RACINE, "game", "systemes"), (".gd",)),
    (os.path.join(RACINE, "game", "verifs"), (".gd",)),
    (os.path.join(RACINE, "game", "rendu"), (".gd", ".tscn")),
    (os.path.join(RACINE, "game", "donnees"), (".json",)),
    # ville_lampes.json porte les 2674 entrees de decor que ville.gd pose a
    # chaque partie. L'oublier faisait passer tout le mobilier urbain pour
    # orphelin — poubelles, bornes, poteaux, arbres.
    (os.path.join(RACINE, "game", "assets", "ville"), (".json",)),
    (os.path.join(RACINE, "outils"), (".py",)),
]


def lire(chemin):
    try:
        with io.open(chemin, encoding="utf-8-sig", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


textes = {}
for dossier, exts in A_LIRE:
    for base, _, fichiers in os.walk(dossier):
        for f in fichiers:
            if f.endswith(exts):
                p = os.path.join(base, f)
                textes[os.path.relpath(p, RACINE)] = lire(p)

modeles = []
for base, _, fichiers in os.walk(ASSETS):
    for f in fichiers:
        if f.endswith(".glb"):
            p = os.path.join(base, f)
            modeles.append({
                "nom": f[:-4],
                "fichier": f,
                "famille": os.path.basename(base),
                "mo": os.path.getsize(p) / 1048576.0,
                "chemin": os.path.relpath(p, RACINE).replace("\\", "/"),
            })

# SIX SYSTEMES CHARGENT PAR NOM CONSTRUIT, et une recherche du nom de fichier
# ne les voit pas :
#
#   foule.gd        "res://assets/personnages/%s.glb"
#   equipement.gd   "res://assets/objets/%s.glb"
#   ville.gd        "res://assets/decor/%s.glb" et vehicules/%s.glb
#   desert.gd       "res://assets/decor/%s.glb"
#   maison.gd       "res://assets/decor/%s.glb"
#   trafic.gd       "res://assets/vehicules/garee_%s.glb"
#
# Le premier jet de ce script declarait donc 51 modeles orphelins, dont les
# oeufs, la botte et tout le mobilier urbain — qui sont poses a chaque partie.
# On cherche aussi le nom NU entre guillemets, tel qu'il apparait dans une
# liste de code ou dans ville_lampes.json.
for m in modeles:
    cites = []
    motifs = [
        re.compile(re.escape(m["fichier"])),
        re.compile(r'"%s"' % re.escape(m["nom"])),
        re.compile(r"'%s'" % re.escape(m["nom"])),
    ]
    # Pour le trafic, le nom pose est « garee_X » mais la table dit « X ».
    if m["nom"].startswith("garee_"):
        court = m["nom"][len("garee_"):]
        motifs.append(re.compile(r'"%s"' % re.escape(court)))
    for nom_fichier, texte in textes.items():
        if any(mo.search(texte) for mo in motifs):
            cites.append(nom_fichier.replace("\\", "/"))
    m["cites"] = cites
    # Un modele cite UNIQUEMENT par le generateur qui le fabrique n'est pas
    # utilise par le jeu : il est produit et jamais pose.
    m["dans_le_jeu"] = any(not c.startswith("outils/") for c in cites)

modeles.sort(key=lambda x: (not x["dans_le_jeu"], x["famille"], -x["mo"]))

utilises = [m for m in modeles if m["dans_le_jeu"]]
orphelins = [m for m in modeles if not m["dans_le_jeu"]]

print("")
print("=== %d modeles, %.1f Mo au total ===" % (
    len(modeles), sum(m["mo"] for m in modeles)))

print("")
print("--- UTILISES PAR LE JEU (%d, %.1f Mo) ---"
      % (len(utilises), sum(m["mo"] for m in utilises)))
famille = None
for m in utilises:
    if m["famille"] != famille:
        famille = m["famille"]
        print("  [%s]" % famille)
    print("    %-30s %6.2f Mo   %d ref" % (m["nom"], m["mo"], len(m["cites"])))

print("")
print("--- JAMAIS POSES DANS LE JEU (%d, %.1f Mo) ---"
      % (len(orphelins), sum(m["mo"] for m in orphelins)))
for m in orphelins:
    ou = "produit par " + ", ".join(
        os.path.basename(c) for c in m["cites"]) if m["cites"] else "cite NULLE PART"
    print("    %-30s %6.2f Mo   %s" % (m["nom"], m["mo"], ou))
