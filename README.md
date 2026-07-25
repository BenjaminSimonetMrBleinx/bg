# BG

**Breaking Bad Game** — Benjamin & Guillaume.

Un GTA-like en 3D low-poly PS2 dans l'univers de Breaking Bad. Albuquerque, Nouveau-Mexique.

> **Projet de fan, non commercial.** Voir [DISCLAIMER.md](DISCLAIMER.md).

---

## État du projet

Phase de cadrage. Rien n'est encore développé — et c'est volontaire : on répond d'abord
aux questions, on fige la direction, on code ensuite.

**→ [`docs/00-questions.md`](docs/00-questions.md) — à remplir par Benjamin et Guillaume.**

| Document | Contenu |
|---|---|
| [`docs/05-demarrage.md`](docs/05-demarrage.md) | **Machine neuve : commence ici.** Git LFS avant le clone |
| [`docs/00-questions.md`](docs/00-questions.md) | Les questions de cadrage, à remplir |
| [`docs/01-cadrage.md`](docs/01-cadrage.md) | Décisions verrouillées, choix du moteur, répartition du travail |
| [`docs/02-methode.md`](docs/02-methode.md) | Comment on code ce jeu au quotidien |
| [`docs/03-conventions-assets.md`](docs/03-conventions-assets.md) | Formats, budgets de triangles, pivots, nommage |
| [`docs/04-brief-son.md`](docs/04-brief-son.md) | **Liste exhaustive des sons du prototype** — pour Guillaume |
| [`docs/JOURNAL.md`](docs/JOURNAL.md) | Une entrée par session, les constats |

## Décidé

| | |
|---|---|
| Genre | Monde ouvert type GTA — missions principales + quêtes annexes |
| Direction artistique | 3D low-poly PS2 : filtrage bilinéaire, perspective corrigée, textures 128 px, éclairage par sommet, brouillard, rendu ~512×448 |
| Moteur | Godot 4.7 — choix définitif, pas un choix de prototype |
| Modélisation | Blender 5.2 |
| Plateforme | Windows, puis Linux |
| Diffusion | Dépôt privé, non commercial, jamais vendu |

## Premier jalon

> « On conduit une voiture dans quatre blocs d'Albuquerque, de nuit, avec le rendu PS2,
> et on peut descendre du véhicule. »

Pas de missions, pas d'IA, pas de trafic, pas de personnage animé. Le jalon sert à répondre
à une seule question : est-ce que rouler là-dedans procure déjà quelque chose ?

## Mise en route

```powershell
git clone https://github.com/BenjaminSimonetMrBleinx/bg.git
cd bg
.\installer.ps1        # installe et configure tout, relancable sans risque
```

`installer.ps1` détecte ce qui manque, l'installe via winget, configure Git
LFS et ton identité, répare le téléchargement des binaires et vérifie que le
projet se lance. Détails dans [docs/05-demarrage.md](docs/05-demarrage.md).

Outils : [Godot 4.7](https://godotengine.org/download) · [Blender 5.2](https://www.blender.org/download/) · [Python 3.12](https://www.python.org/downloads/) · [Git LFS](https://git-lfs.com/)

Pas besoin de retenir les chemins, tout passe par le lanceur :

```powershell
.\bg.ps1 outils     # ou en est la chaine d outils
.\bg.ps1 jouer      # lance le jeu
.\bg.ps1 editeur    # ouvre l editeur Godot (pour regler reglages.tres)
.\bg.ps1 generer    # regenere textures, ville et vehicule
.\bg.ps1 capture    # rend une image hors ecran dans .tmp/
.\bg.ps1 verif      # verifie que le projet charge
```

`generer` accepte `-Blocs 4 -Graine 1234` pour changer la taille et le tirage de la ville.

Pour envoyer son travail sur GitHub, une seule commande, qui vérifie tout et
explique quoi faire en cas de souci :

```powershell
.\livrer.ps1                       # verifie, recupere, montre, envoie
.\livrer.ps1 "sons de portieres"   # avec ta propre description
.\livrer.ps1 -Quoi                 # montre sans rien envoyer
```

## Commandes en jeu

| Touche | Action |
|---|---|
| **W A S D** / flèches | Conduire |
| Espace | Frein à main |
| F | Interagir |

Les touches sont liées par **position physique**, pas par caractère. Les mêmes
touches fonctionnent donc quelle que soit la disposition du clavier : elles se
lisent `WASD` en QWERTY et QWERTZ, `ZQSD` en AZERTY, sans rien changer au code.

## Structure

```
docs/        cadrage, questions, décisions
assets/      sources Blender et textures (LFS)
game/        projet Godot
outils/      scripts de génération procédurale
```
