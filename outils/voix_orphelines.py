"""Les fichiers de voix que plus aucune replique ne reclame.

    python outils/voix_orphelines.py            # liste, ne touche a rien
    python outils/voix_orphelines.py --purger   # supprime, .import compris

POURQUOI CE SCRIPT EXISTE. Le nom d'un fichier de voix est l'empreinte de ce
qui est DIT. Le jour ou le jeu est passe en VO anglaise, les 93 empreintes
francaises sont devenues introuvables d'un coup : les fichiers sont restes la,
plus personne ne les demande, et rien ne le signale. Ils pesent, ils partent
dans le depot, et ils font croire qu'un personnage est double alors que ce
qu'on entend vient d'ailleurs.

CE QU'IL NE FAUT SURTOUT PAS SUPPRIMER : les vraies prises. La confession de
Walter et la dispute avec Skyler ont ete ENREGISTREES, pas synthetisees, et
elles ne se regenerent pas. Elles sont protegees ici parce que leurs repliques
n'ont pas de champ 'vo' : leur 'texte' est deja l'anglais, donc l'empreinte n'a
pas bouge et le script les compte comme reclamees. Le garde-fou n'est pas une
liste a maintenir, c'est une consequence.
"""
import hashlib
import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(RACINE, "game", "donnees", "dialogues.json")
VOIX = os.path.join(RACINE, "game", "assets", "voix")


def simplifier(nom):
    """Doit produire exactement le meme nom que Dialogue._simplifier()."""
    return "".join(c for c in nom.lower() if c.isalnum() and c.isascii())


def empreinte(texte):
    return hashlib.md5(texte.encode("utf-8")).hexdigest()[:10]


def prononce(replique):
    """Doit produire exactement la meme chaine que Dialogue._prononce().

    Si les deux divergent, ce script prend pour orphelins des fichiers que le
    jeu reclame, et les supprime. C'est la fonction la plus dangereuse d'ici.
    """
    vo = replique.get("vo") or ""
    if not vo:
        return replique.get("texte", "")
    jeu = replique.get("jeu") or ""
    if not jeu:
        return vo
    return "[%s] %s" % (jeu, vo)


dialogues = json.load(io.open(DONNEES, encoding="utf-8-sig"))

reclames = set()
for cle, fiche in dialogues.items():
    if not isinstance(fiche, dict) or "conversations" not in fiche:
        continue
    for conv in fiche["conversations"]:
        for r in conv:
            if not isinstance(r, dict):
                continue
            dit = prononce(r)
            if not dit:
                continue
            reclames.add("%s_%s.wav" % (simplifier(r.get("qui", "")),
                                        empreinte(dit)))

orphelins = []
poids = 0
for nom in sorted(os.listdir(VOIX)):
    if not nom.endswith(".wav"):
        continue
    if nom in reclames:
        continue
    chemin = os.path.join(VOIX, nom)
    taille = os.path.getsize(chemin)
    orphelins.append((nom, taille))
    poids += taille

for nom, taille in orphelins:
    print("  %-28s %8.1f Ko" % (nom, taille / 1024.0))

print("")
print("%d reclame(s), %d orphelin(s), %.1f Mo"
      % (len(reclames), len(orphelins), poids / 1048576.0))

if "--purger" not in sys.argv:
    print("Rien supprime. Relancer avec --purger pour le faire.")
    sys.exit(0)

for nom, _ in orphelins:
    os.remove(os.path.join(VOIX, nom))
    imp = os.path.join(VOIX, nom + ".import")
    if os.path.exists(imp):
        os.remove(imp)
print("%d fichier(s) supprime(s), .import compris." % len(orphelins))
