#!/usr/bin/env python3
"""Met les fichiers audio livres au format que Godot sait lire.

    python outils/normaliser_sons.py            controle seulement
    python outils/normaliser_sons.py --corriger  convertit ce qui doit l etre

Godot n accepte que le WAV en PCM non compresse (ou IEEE float). Or les
stations audio exportent volontiers autre chose sous une extension .wav :
du WAVE_FORMAT_EXTENSIBLE, de l ADPCM, voire un conteneur QuickTime renomme.
Le message d erreur de Godot, lui, ne dit pas quoi faire.

Ce script lit les en-tetes, dit exactement ce qui ne va pas, et convertit
avec ffmpeg si on le lui demande. Sans --corriger il ne touche a rien.
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
from pathlib import Path

FORMATS = {
    1: "PCM",
    3: "IEEE float",
    6: "A-law",
    7: "mu-law",
    17: "IMA ADPCM",
    85: "MP3",
    65534: "WAVE extensible",
}

# Ce que Godot importe sans broncher.
ACCEPTES = {1, 3}


def examiner(chemin: Path) -> dict:
    """Retourne l etat d un fichier audio, sans jamais lever."""
    infos = {"chemin": chemin, "ok": False, "raison": "", "format": ""}
    try:
        octets = chemin.read_bytes()
    except OSError as e:
        infos["raison"] = f"illisible ({e})"
        return infos

    if len(octets) < 44:
        infos["raison"] = "trop petit pour etre un fichier audio"
        return infos

    if octets[:4] == b"OggS":
        infos["ok"] = True
        infos["format"] = "Ogg Vorbis"
        return infos

    if octets[:4] != b"RIFF" or octets[8:12] != b"WAVE":
        entete = octets[4:12].decode("ascii", "replace")
        if b"ftyp" in octets[:16]:
            infos["raison"] = "conteneur QuickTime/MP4 renomme en .wav"
        else:
            infos["raison"] = f"ce n est pas un WAV (en-tete '{entete}')"
        return infos

    code = struct.unpack_from("<H", octets, 20)[0]
    infos["format"] = FORMATS.get(code, f"code {code}")
    if code in ACCEPTES:
        infos["ok"] = True
    else:
        infos["raison"] = f"{infos['format']} : Godot n importe que du PCM"
    return infos


def convertir(chemin: Path, ffmpeg: str) -> bool:
    """Reecrit le fichier en PCM 48 kHz 16 bits, canaux preserves."""
    temporaire = chemin.with_suffix(".converti.wav")
    commande = [
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(chemin),
        "-acodec", "pcm_s16le", "-ar", "48000",
        str(temporaire),
    ]
    resultat = subprocess.run(commande, capture_output=True, text=True)
    if resultat.returncode != 0 or not temporaire.exists():
        print(f"    echec : {resultat.stderr.strip().splitlines()[-1:] or '?'}")
        temporaire.unlink(missing_ok=True)
        return False
    chemin.unlink()
    temporaire.rename(chemin)
    return True


def main() -> None:
    ap = argparse.ArgumentParser(description="Normalisation des sons")
    ap.add_argument("--dossier", default="game/assets/sons")
    ap.add_argument("--corriger", action="store_true",
                    help="convertir les fichiers non conformes")
    args = ap.parse_args()

    racine = Path(args.dossier)
    if not racine.exists():
        print(f"dossier introuvable : {racine}")
        sys.exit(1)

    fichiers = sorted(p for p in racine.rglob("*")
                      if p.suffix.lower() in {".wav", ".ogg", ".mp3"})
    if not fichiers:
        print("aucun fichier audio")
        return

    ffmpeg = shutil.which("ffmpeg")
    a_corriger = []

    print(f"{len(fichiers)} fichier(s) dans {racine}\n")
    for f in fichiers:
        etat = examiner(f)
        relatif = f.relative_to(racine)
        if etat["ok"]:
            print(f"  ok    {relatif}  ({etat['format']})")
        else:
            print(f"  A CORRIGER  {relatif}")
            print(f"              {etat['raison']}")
            a_corriger.append(f)

    if not a_corriger:
        print("\nTout est au format attendu.")
        return

    print(f"\n{len(a_corriger)} fichier(s) a convertir.")
    if not args.corriger:
        print("Relance avec --corriger pour les convertir en PCM 48 kHz 16 bits.")
        sys.exit(1)

    if ffmpeg is None:
        print("\nffmpeg est introuvable. Installe-le :")
        print("  winget install --id Gyan.FFmpeg -e")
        sys.exit(1)

    print("")
    corriges = 0
    for f in a_corriger:
        print(f"  conversion {f.relative_to(racine)}...")
        if convertir(f, ffmpeg):
            corriges += 1
    print(f"\n{corriges}/{len(a_corriger)} converti(s).")
    sys.exit(0 if corriges == len(a_corriger) else 1)


if __name__ == "__main__":
    main()
