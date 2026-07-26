#!/usr/bin/env python3
"""Decoupe un enregistrement en plusieurs sons, sur les silences.

    python outils/decouper_son.py game/assets/sons/pas/steps_beton.wav --nom pas_beton

Produit pas_beton_01.wav, pas_beton_02.wav... a cote de l'original, et laisse
l'original en place.

POURQUOI.

Un bruitage court se livre rarement seul. On enregistre une SERIE — six pas
d'affilee, quatre portieres, trois impacts — parce que c'est ce qu'on fait
naturellement devant un micro, et parce qu'une serie sonne juste alors que six
prises separees sonnent comme six prises separees.

Le jeu, lui, a besoin d'un fichier par occurrence : un pas doit jouer UN pas.
Brancher la serie entiere sur le cycle de marche donnerait six pas a chaque
foulee, superposes au suivant.

D'ou ce decoupage. Il sert a tout ce qui arrive en serie, pas seulement aux
pas — et il arrivera encore.

Sans ffmpeg : le module wave de la bibliotheque standard suffit, et une
dependance de moins est une panne de moins chez celui qui recupere le projet.
"""

from __future__ import annotations

import argparse
import array
import wave
from pathlib import Path


def arguments() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("fichier", help="le WAV a decouper")
    ap.add_argument("--nom", default="",
                    help="prefixe des morceaux (defaut : celui du fichier)")
    ap.add_argument("--sortie", default="",
                    help="dossier de sortie (defaut : a cote de l'original)")
    # Le seuil est une FRACTION du pic, pas une valeur absolue : une prise
    # enregistree bas et une prise forte n'ont rien de comparable en absolu,
    # et un seuil fixe marcherait sur l'une et pas sur l'autre.
    ap.add_argument("--seuil", type=float, default=0.06,
                    help="niveau sous lequel c'est du silence, en part du pic")
    ap.add_argument("--silence", type=float, default=0.12,
                    help="duree de silence qui separe deux sons, en secondes")
    ap.add_argument("--minimum", type=float, default=0.08,
                    help="duree minimale d'un morceau, en secondes")
    # Une marge AVANT chaque son : l'attaque d'un pas est ce qui le rend net,
    # et un decoupage au ras du seuil la rogne. On perd alors le claquement et
    # il ne reste que la resonance, qui sonne comme un carton.
    ap.add_argument("--avant", type=float, default=0.02,
                    help="marge conservee avant chaque son, en secondes")
    ap.add_argument("--apres", type=float, default=0.10,
                    help="marge conservee apres, pour la resonance")
    return ap.parse_args()


def lire(chemin: Path):
    with wave.open(str(chemin), "rb") as w:
        if w.getsampwidth() != 2:
            raise SystemExit(
                f"{chemin.name} : {w.getsampwidth() * 8} bits.\n"
                f"Ce decoupage attend du 16 bits. Convertir : "
                f".\\bg.ps1 sons -Corriger")
        return (w.getnchannels(), w.getframerate(),
                array.array("h", w.readframes(w.getnframes())))


def enveloppe(ech: array.array, canaux: int, frames: int) -> list[int]:
    """Le niveau absolu de chaque trame, tous canaux confondus."""
    niveaux = [0] * frames
    for i in range(frames):
        pic = 0
        base = i * canaux
        for c in range(canaux):
            v = ech[base + c]
            if v < 0:
                v = -v
            if v > pic:
                pic = v
        niveaux[i] = pic
    return niveaux


def morceaux(niveaux: list[int], seuil: int, trou: int, mini: int):
    """Les intervalles ou ca sonne, separes par au moins 'trou' trames."""
    zones = []
    debut = -1
    depuis_le_silence = 0
    for i, n in enumerate(niveaux):
        if n > seuil:
            if debut < 0:
                debut = i
            depuis_le_silence = 0
        elif debut >= 0:
            depuis_le_silence += 1
            if depuis_le_silence >= trou:
                fin = i - depuis_le_silence
                if fin - debut >= mini:
                    zones.append((debut, fin))
                debut = -1
    if debut >= 0 and len(niveaux) - debut >= mini:
        zones.append((debut, len(niveaux)))
    return zones


def main() -> None:
    a = arguments()
    source = Path(a.fichier)
    if not source.exists():
        raise SystemExit(f"introuvable : {source}")

    canaux, taux, ech = lire(source)
    frames = len(ech) // canaux
    niveaux = enveloppe(ech, canaux, frames)
    pic = max(niveaux) if niveaux else 0
    if pic == 0:
        raise SystemExit(f"{source.name} : silence complet, rien a decouper.")

    zones = morceaux(niveaux, int(pic * a.seuil),
                     int(a.silence * taux), int(a.minimum * taux))
    if not zones:
        raise SystemExit(
            f"{source.name} : aucun son detache.\n"
            f"Baisser --silence, ou monter --seuil.")

    prefixe = a.nom or source.stem
    dossier = Path(a.sortie) if a.sortie else source.parent
    dossier.mkdir(parents=True, exist_ok=True)

    avant = int(a.avant * taux)
    apres = int(a.apres * taux)
    print(f"{source.name} : {frames / taux:.2f} s, {len(zones)} son(s) detaches")

    for i, (d, f) in enumerate(zones, start=1):
        d = max(0, d - avant)
        f = min(frames, f + apres)
        cible = dossier / f"{prefixe}_{i:02d}.wav"
        with wave.open(str(cible), "wb") as w:
            w.setnchannels(canaux)
            w.setsampwidth(2)
            w.setframerate(taux)
            w.writeframes(ech[d * canaux:f * canaux].tobytes())
        print("  %-28s %5.2f s" % (cible.name, (f - d) / taux))

    print(f"sortie     {dossier}")


if __name__ == "__main__":
    main()
