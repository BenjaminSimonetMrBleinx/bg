# Dépôt de sources

**C'est ici qu'on pose ce qui n'est pas encore intégré au jeu.** Fichiers de travail,
sources Blender, sons bruts, planches de référence maison.

```
livraisons/
  sons/         WAV ou OGG deposes ici : livrer.ps1 les range tout seul
  blend/        fichiers .blend sources
```

## Les sons se rangent tout seuls

Pose tes fichiers dans `livraisons/sons/`, en respectant les sous-dossiers du
[brief son](../docs/04-brief-son.md) — `vehicule/`, `ambiance/`, `pas/`, etc. Au prochain
`.\livrer.ps1` ou `.\go.ps1`, ils sont déplacés vers `game/assets/sons/`, là où Godot les
lit, et le format est vérifié au passage.

Tu n'as donc **pas** à savoir où le jeu les range. Pose et livre.

## Ce qui ne va PAS ici

**Les médias issus de la série.** Ils vont dans `assets-ref/`, qui n'entre jamais dans git.
Voir [DISCLAIMER.md](../DISCLAIMER.md).

**Ce qui est généré par script.** Textures, ville, véhicule, personnages, maisons, objets :
tout ça sort de `outils/` et se refabrique avec `.\bg.ps1 generer`. Ne jamais poser à la
main un fichier qu'un générateur écrase à la commande suivante.

## Pourquoi ce fichier existe

Git ne suit pas les dossiers vides. Sans lui, `livraisons/` disparaîtrait du prochain clone, et
le rangement automatique des sons n'aurait plus d'endroit où chercher.
