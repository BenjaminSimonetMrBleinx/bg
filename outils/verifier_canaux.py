"""Qui parle a travers un appareil, et qui devrait.

    python outils/verifier_canaux.py

DEUX ERREURS SYMETRIQUES, ET AUCUNE NE FAIT DE BRUIT.

  1. Un canal OUBLIE sur un correspondant : la voix sort en direct, le
     personnage a l'air d'etre dans la piece. C'est ce qui se passait pour les
     trois repliques de Tuco a l'interphone, dont le texte francais annoncait
     pourtant « (interphone) ».

  2. Un canal POSE SUR WALTER : sa propre voix passerait par le combine qu'il
     tient. C'est l'erreur inverse, et elle s'entend encore plus mal.

Le script confronte donc deux sources qui ne peuvent pas se tromper ensemble :
le champ 'canal' d'une part, et de l'autre le nom de la fiche plus la mention
« (interphone) » ecrite dans le sous-titre francais.
"""
import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(RACINE, "game", "donnees", "dialogues.json")

# Les fiches ou l'on est au bout d'un fil. Tout ce qui n'est pas Walter y parle
# forcement a travers l'appareil : c'est la scene qui le dit, pas une liste de
# repliques a tenir a jour.
FICHES_TELEPHONE = {
    "telephone_jesse",
    "telephone_skyler",
    "mission_tuco_appel",
    "mission_skyler_oeufs",
}

# Le joueur. Il est dans la piece, sa voix ne traverse jamais rien.
EN_DIRECT = "Walter"

CANAUX = {"telephone", "interphone"}

dialogues = json.load(io.open(DONNEES, encoding="utf-8-sig"))

fautes = []
lignes = []

for cle, fiche in dialogues.items():
    if not isinstance(fiche, dict) or "conversations" not in fiche:
        continue
    for conv in fiche["conversations"]:
        for r in conv:
            if not isinstance(r, dict):
                continue
            qui = r.get("qui", "")
            canal = r.get("canal", "")
            texte = r.get("texte", "")

            if canal and canal not in CANAUX:
                fautes.append("%s / %s : canal inconnu '%s'" % (cle, qui, canal))

            # 1. Walter ne traverse jamais un appareil.
            if canal and qui == EN_DIRECT:
                fautes.append("%s : Walter porte un canal '%s' — il est dans "
                              "la piece" % (cle, canal))

            # 2. Un correspondant dans une fiche telephonique en veut un.
            if cle in FICHES_TELEPHONE and qui != EN_DIRECT and not canal:
                fautes.append("%s / %s : au telephone, sans canal — « %s »"
                              % (cle, qui, texte[:50]))

            # 3. Le sous-titre annonce l'interphone : l'audio doit suivre.
            if "(interphone)" in texte.lower() and canal != "interphone":
                fautes.append("%s / %s : le sous-titre dit (interphone), le "
                              "son non" % (cle, qui))

            if canal:
                lignes.append((cle, qui, canal, texte[:44]))

print("")
print("--- les voix qui traversent un appareil ---")
for cle, qui, canal, texte in lignes:
    print("  %-22s %-8s %-11s %s" % (cle, qui, canal, texte))
print("")
print("  %d replique(s) filtree(s)" % len(lignes))

if fautes:
    print("")
    for f in fautes:
        print("  ECHEC " + f)
    print("")
    print("ECHEC %d incoherence(s)" % len(fautes))
    sys.exit(1)

print("OK  aucun canal oublie, aucun pose sur Walter")
