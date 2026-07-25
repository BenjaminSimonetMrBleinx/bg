# Démarrage

Pour Guillaume, ou pour toute machine neuve. Dix minutes.

---

## 1. Installer les outils

| Outil | Pourquoi | Lien |
|---|---|---|
| **Git LFS** | **Indispensable.** Sans lui, rien ne marche — voir plus bas | [git-lfs.com](https://git-lfs.com/) |
| **Blender 5.2** | Modélisation, et les générateurs du projet tournent dedans | [blender.org](https://www.blender.org/download/) |
| **Godot 4.7** | Le moteur. 120 Mo, aucun compte à créer | [godotengine.org](https://godotengine.org/download) |
| Python 3.12 | Génération des textures | [python.org](https://www.python.org/downloads/) |

## 2. Git LFS d'abord, le clone ensuite

**L'ordre compte.** Cloner avant d'avoir installé LFS donne un dépôt en
apparence complet mais inutilisable.

```powershell
git lfs version          # doit repondre quelque chose
git lfs install          # une seule fois par machine
git clone https://github.com/BenjaminSimonetMrBleinx/bg.git
cd bg
```

### Si tu as déjà cloné sans LFS

C'est le piège classique, et il ne ressemble pas à une erreur :

- **tes pushs de fichiers binaires échouent**, avec un message peu parlant ;
- **tes images sont fausses.** Ouvre `game/assets/textures/route.png` : au lieu
  d'une image, tu trouveras trois lignes de texte commençant par
  `version https://git-lfs.github.com/spec/v1`. C'est un *pointeur*, pas le
  fichier. Blender et Godot refuseront de l'ouvrir.

Réparation, sans recloner :

```powershell
git lfs install
git lfs pull
```

## 3. Vérifier que tout est là

```powershell
.\bg.ps1 outils          # doit trouver Godot, Blender et Python
.\bg.ps1 verif           # doit afficher VERIF OK
.\bg.ps1 jouer           # le jeu se lance
```

Si `bg.ps1` refuse de s'exécuter, PowerShell bloque les scripts non signés :

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 4. Commandes en jeu

| Touche | Action |
|---|---|
| **W A S D** / flèches | Marcher, puis conduire |
| **F** | Monter dans la voiture, en descendre |
| Espace | Frein à main |

Les touches sont liées par **position physique** : elles se lisent `WASD` en
QWERTY et QWERTZ, `ZQSD` en AZERTY, sans rien changer.

## 5. Déposer ton travail

```powershell
git pull                                  # toujours avant de commencer
# ... tu travailles ...
git add assets/sons/vehicule/moteur_ralenti.wav
git commit -m "Son moteur au ralenti"
git push
```

**Un fichier `.blend` par asset**, jamais un gros fichier de scène partagé :
un binaire ne se fusionne pas, et à deux sur le même fichier l'un des deux
travaux serait purement et simplement jeté.

## 6. Où mettre quoi

```
assets/sons/        tes WAV, par categorie
assets/personnages/ tes .blend de personnages
assets/vehicules/   tes .blend de vehicules
assets/ville/       tes .blend de decor
assets-ref/         medias de la serie — IGNORE PAR GIT, n y compte pas
```

Ce que Godot consomme vit dans `game/assets/` et **est généré** par les
scripts. Ne le modifie pas à la main : ça sera écrasé au prochain
`.\bg.ps1 generer`.

## 7. À lire ensuite

| | |
|---|---|
| [`04-brief-son.md`](04-brief-son.md) | **Tes ~55 sons**, avec formats et priorités. Commence par la section « si tu n'as que deux heures » |
| [`03-conventions-assets.md`](03-conventions-assets.md) | Budgets de triangles, textures, pivots, échelle |
| [`00-questions.md`](00-questions.md) | Le bloc A t'est destiné, réponds dedans directement |
| [`01-cadrage.md`](01-cadrage.md) | Pourquoi Godot, pourquoi le PS2, où on va |

## En cas de blocage

Note **le message d'erreur exact** — sans lui, on devine. Neuf fois sur dix,
c'est Git LFS.
