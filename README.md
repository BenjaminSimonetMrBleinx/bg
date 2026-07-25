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
| [`docs/00-questions.md`](docs/00-questions.md) | Les questions de cadrage, à remplir |
| [`docs/01-cadrage.md`](docs/01-cadrage.md) | Décisions verrouillées, choix du moteur, répartition du travail |
| [`docs/02-methode.md`](docs/02-methode.md) | Comment on code ce jeu au quotidien |

## Décidé

| | |
|---|---|
| Genre | Monde ouvert type GTA — missions principales + quêtes annexes |
| Direction artistique | 3D low-poly PS2 : vertex snapping, textures 64 px, brouillard, 320×240 upscalé |
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

```bash
git clone https://github.com/BenjaminSimonetMrBleinx/bg.git
cd bg
git lfs install
```

Outils : [Godot 4.7](https://godotengine.org/download) · [Blender 5.2](https://www.blender.org/download/) · [Git LFS](https://git-lfs.com/)

## Structure

```
docs/        cadrage, questions, décisions
assets/      sources Blender et textures (LFS)
game/        projet Godot
outils/      scripts de génération procédurale
```
