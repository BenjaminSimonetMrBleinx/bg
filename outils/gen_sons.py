#!/usr/bin/env python3
"""Fabrique les sons que personne n'a encore enregistres.

    python outils/gen_sons.py

CE SONT DES BOUCHONS, et ils le disent. La mission a besoin de coups de feu,
d'une rafale et d'une explosion ; aucun des trois n'est dans les livraisons, et
attendre aurait laisse la moitie de la scene finale muette — c'est-a-dire
impossible a juger. Ceux-ci tiennent la place et se remplacent en deposant un
fichier du meme nom.

La synthese est celle qu'on utilisait avant les banques d'echantillons, et elle
marche encore : du bruit blanc, une enveloppe qui s'effondre, un filtre passe-bas
qui se ferme. Un coup de feu est un claquement large qui meurt en un dixieme de
seconde ; une explosion est le meme evenement, en plus grave et dix fois plus
long.

Pur stdlib : `wave` et `random` suffisent, comme decouper_son.py.
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path

TAUX = 44100


def ecrire(chemin: Path, echantillons: list[float]) -> None:
    chemin.parent.mkdir(parents=True, exist_ok=True)
    # Normalisation a -3 dB. Un son de synthese qui sature s'entend tout de
    # suite, et il sature d'autant plus facilement qu'on empile des couches.
    crete = max(0.0001, max(abs(v) for v in echantillons))
    gain = 0.707 / crete
    with wave.open(str(chemin), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAUX)
        f.writeframes(b"".join(
            struct.pack("<h", max(-32767, min(32767, int(v * gain * 32767))))
            for v in echantillons))
    print("  %-22s %5.2f s" % (chemin.name, len(echantillons) / TAUX))


def bruit(duree: float, graine: int) -> list[float]:
    r = random.Random(graine)
    return [r.uniform(-1.0, 1.0) for _ in range(int(duree * TAUX))]


def passe_bas(source: list[float], depart: float, arrivee: float) -> list[float]:
    """Filtre a un pole dont la coupure se DEPLACE pendant le son.

    C'est ce detail qui fait la difference entre un claquement et un « pshhh » :
    l'aigu d'une detonation part en quelques millisecondes, le grave reste. Un
    filtre a coupure fixe donne un souffle de machine a laver.
    """
    sortie = []
    etat = 0.0
    n = len(source)
    for i, v in enumerate(source):
        t = i / max(1, n - 1)
        coupure = depart * math.pow(arrivee / depart, t)
        k = 1.0 - math.exp(-2.0 * math.pi * coupure / TAUX)
        etat += k * (v - etat)
        sortie.append(etat)
    return sortie


def enveloppe(source: list[float], attaque: float, chute: float,
              courbe: float = 2.5) -> list[float]:
    n = len(source)
    na = max(1, int(attaque * TAUX))
    sortie = []
    for i, v in enumerate(source):
        if i < na:
            a = i / na
        else:
            t = (i - na) / max(1, n - na)
            a = math.pow(max(0.0, 1.0 - t), courbe)
        sortie.append(v * a)
    return sortie


def melanger(*couches: list[float]) -> list[float]:
    n = max(len(c) for c in couches)
    sortie = [0.0] * n
    for c in couches:
        for i, v in enumerate(c):
            sortie[i] += v
    return sortie


def ton(frequence: float, duree: float, amplitude: float = 1.0) -> list[float]:
    """Une sinusoide. Tout ce qui TINTE part de la, la ou tout ce qui claque
    part du bruit blanc."""
    n = int(duree * TAUX)
    return [amplitude * math.sin(2.0 * math.pi * frequence * i / TAUX)
            for i in range(n)]


def silence(duree: float) -> list[float]:
    return [0.0] * int(duree * TAUX)


def apres(retard: float, source: list[float]) -> list[float]:
    """Decale un son dans le temps. Une caisse enregistreuse n'est pas un
    accord : c'est un declic PUIS une cloche, et l'ecart entre les deux est ce
    qui fait qu'on reconnait le geste."""
    return silence(retard) + source


def caisse(graine: int) -> list[float]:
    """La caisse enregistreuse de l'epicerie.

    Un declic de touche, puis le tiroir : deux notes de cloche a la quinte,
    qui decroissent ensemble. C'est le son qu'on entend quand on PAIE — le
    projet en avait deja un pour quand on encaisse (`gain_argent`), et les
    reutiliser l'un pour l'autre aurait rendu le signal ambigu : on ne saurait
    plus, a l'oreille, si l'argent est entre ou sorti.

    Bouchon de synthese, comme tout ce fichier. Il se remplace en deposant un
    fichier du meme nom.
    """
    declic = enveloppe(passe_bas(bruit(0.045, graine), 6000.0, 1400.0),
                       0.0006, 0.045, 3.0)
    cloche_a = enveloppe(ton(1318.5, 0.55, 0.42), 0.003, 0.55, 2.2)
    cloche_b = enveloppe(ton(1975.5, 0.50, 0.26), 0.003, 0.50, 2.4)
    return melanger(declic,
                    apres(0.055, cloche_a),
                    apres(0.062, cloche_b))


def coup_de_feu(graine: int) -> list[float]:
    """Un .38 : claquement sec, une pointe de corps, et une queue de piece."""
    claque = enveloppe(passe_bas(bruit(0.09, graine), 9000.0, 900.0),
                       0.0004, 0.09, 3.2)
    corps = enveloppe(passe_bas(bruit(0.16, graine + 1), 1400.0, 180.0),
                      0.001, 0.16, 2.0)
    queue = enveloppe(passe_bas(bruit(0.42, graine + 2), 700.0, 220.0),
                      0.02, 0.42, 1.4)
    return melanger(claque, [v * 0.55 for v in corps], [v * 0.16 for v in queue])


def rafale(graine: int, coups: int = 10) -> list[float]:
    """La fusillade de l'etape 7 : ca tire de partout, on ne voit personne.

    Les coups ne sont PAS reguliers. Un intervalle constant donne une machine ;
    ce qu'on veut est plusieurs armes qui partent en meme temps sans se
    concerter.
    """
    r = random.Random(graine)
    total = [0.0] * int(2.6 * TAUX)
    for k in range(coups):
        depart = int((0.05 + r.uniform(0.0, 2.0)) * TAUX)
        un = coup_de_feu(graine + k * 7)
        volume = r.uniform(0.45, 1.0)
        for i, v in enumerate(un):
            if depart + i < len(total):
                total[depart + i] += v * volume
    return total


def explosion(graine: int) -> list[float]:
    """Le fulminate sur le sol : une claque, un souffle, et ca resonne."""
    claque = enveloppe(passe_bas(bruit(0.22, graine), 6000.0, 300.0),
                       0.0008, 0.22, 2.6)
    souffle = enveloppe(passe_bas(bruit(1.6, graine + 1), 900.0, 90.0),
                        0.01, 1.6, 1.5)
    # Une composante grave tenue : c'est elle qui fait sentir le volume d'air
    # deplace plutot qu'un simple bruit.
    grave = []
    n = int(1.2 * TAUX)
    for i in range(n):
        t = i / TAUX
        f = 62.0 * math.exp(-1.1 * t)
        grave.append(math.sin(2.0 * math.pi * f * t)
                     * math.pow(max(0.0, 1.0 - i / n), 2.0))
    return melanger(claque, [v * 0.85 for v in souffle],
                    [v * 0.5 for v in grave])


def main() -> None:
    ap = argparse.ArgumentParser(description="Sons de synthese provisoires")
    ap.add_argument("--sortie", default="game/assets/sons/mission")
    # UN NOM, ET PAS TOUTE LA BANQUE À CHAQUE FOIS.
    #
    # Ce script reecrivait ses cinq fichiers a chaque appel. Ajouter un son en
    # ecrasait donc quatre autres — et le jour ou l'un d'eux aura ete remplace
    # par un vrai enregistrement, on le perdra sans que rien ne le signale.
    # C'est le piege 11, et il a deja coute deux modeles livres.
    ap.add_argument("--nom", default="tous",
                    help="un son, ou 'tous'. Voir les cles ci-dessous.")
    a = ap.parse_args()
    dossier = Path(a.sortie)

    recettes = {
        "coups_de_feu": lambda: [
            (dossier / ("coup_de_feu_0%d.wav" % (i + 1)), coup_de_feu(1000 + i))
            for i in range(3)],
        "fusillade": lambda: [(dossier / "fusillade.wav", rafale(4242))],
        "explosion": lambda: [(dossier / "explosion.wav", explosion(777))],
        "caisse": lambda: [(dossier / "caisse.wav", caisse(31))],
    }
    if a.nom != "tous" and a.nom not in recettes:
        raise SystemExit("son inconnu : %s. Connus : %s, tous"
                         % (a.nom, ", ".join(sorted(recettes))))

    print("")
    print("  Sons de SYNTHESE, en attendant les vrais.")
    print("")
    for nom, recette in recettes.items():
        if a.nom not in ("tous", nom):
            continue
        for chemin, echantillons in recette():
            ecrire(chemin, echantillons)
    print("")


if __name__ == "__main__":
    main()
