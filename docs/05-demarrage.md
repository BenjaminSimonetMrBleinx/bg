# Démarrage

Pour Guillaume, ou pour toute machine neuve. Compte vingt minutes, dont
quinze d'attente pendant les téléchargements.

---

## 0. Partir de zéro

### Ouvrir PowerShell

Touche `Windows`, taper `powershell`, `Entrée`. Une fenêtre s'ouvre : c'est
là qu'on colle les commandes. Clic droit colle, `Entrée` exécute.

### Installer Git

C'est la seule chose à installer soi-même — le reste suit tout seul ensuite.
`winget` est livré avec Windows 10 et 11, il n'y a rien à télécharger.

```powershell
winget install --id Git.Git -e
```

**Ferme ensuite la fenêtre PowerShell et rouvre-en une neuve.** Windows ne
voit un outil fraîchement installé qu'à partir d'une nouvelle session — sans
ça, la commande suivante dira que `git` n'existe pas.

### Choisir où poser le projet

```powershell
cd $HOME\Documents
```

Le projet créera un dossier `bg` à cet endroit. N'importe quel autre dossier
convient — **les espaces dans le chemin ne posent aucun problème**, c'est
testé. Évite en revanche OneDrive : la synchronisation permanente entre en
conflit avec git, et ça se diagnostique très mal.

Attention, le Bureau de Windows 11 est souvent redirigé vers OneDrive. Si
ton chemin contient `OneDrive`, choisis autre chose.

### Récupérer le projet

```powershell
git clone https://github.com/BenjaminSimonetMrBleinx/bg.git
cd bg
```

Le dépôt est privé : **une fenêtre de connexion GitHub va s'ouvrir**.
Connecte-toi avec ton compte, autorise, et c'est réglé pour de bon. C'est le
seul moment déroutant de toute l'installation, et il n'arrive qu'une fois.

---

## 1. La seule commande à retenir

```powershell
.\go.ps1
```

Elle fait tout, dans l'ordre, en sautant ce qui n'a rien à faire :

1. **installe ce qui manque** — Git LFS, Blender, Godot, Python
2. **récupère le travail des autres**
3. **envoie le tien**, s'il y en a, après t'avoir montré la liste
4. **lance le jeu**

C'est la seule à connaître. Les autres scripts existent pour les cas
particuliers, mais `go.ps1` couvre le quotidien.

```powershell
.\go.ps1 "sons de portieres"   # avec ta description pour l'envoi
.\go.ps1 -SansJeu              # tout sauf le lancement
```

### Ce qui tourne dessous

Si tu veux une étape isolée :

| | |
|---|---|
| `.\installer.ps1` | installation seule |
| `.\livrer.ps1` | mise à jour et envoi seuls |
| `.\livrer.ps1 -Quoi` | montrer ce qui partirait, sans envoyer |
| `.\bg.ps1 jouer` | lancer le jeu seul |

Le script détecte ce qui manque, l'installe, et laisse tranquille ce qui est
déjà là. Il peut être relancé autant de fois que tu veux. Windows demandera
peut-être une confirmation pendant les installations : réponds oui.

Il s'occupe de :

| | |
|---|---|
| **Git** | récupérer et envoyer le travail |
| **Git LFS** | les images, sons et `.blend` passent par lui |
| **Blender 5.2** | modélisation, et les générateurs du projet tournent dedans |
| **Godot 4.7** | le moteur du jeu |
| **Python 3.12** | génération des textures |

Puis il configure ton identité git, autorise l'exécution des scripts, répare
le téléchargement des fichiers binaires, et vérifie que le projet se lance.

> **Si Git vient d'être installé**, ferme le terminal, rouvre-le, et relance
> `.\installer.ps1`. Windows a besoin d'une nouvelle session pour voir un
> outil fraîchement installé.

### Pour regarder avant de se lancer

```powershell
.\installer.ps1 -Simuler
```

Montre ce qui serait installé, sans rien toucher.

## 2. Le piège qui coûte une soirée

**Git LFS doit être là avant le clone.** Le script le gère si tu as déjà
cloné, mais autant comprendre pourquoi il insiste.

Sans LFS, le dépôt se télécharge en apparence complet — sauf que les fichiers
binaires ne sont pas les vrais. Ouvre `game/assets/textures/route.png` : au
lieu d'une image, tu trouveras trois lignes de texte commençant par
`version https://git-lfs.github.com/spec/v1`. C'est un *pointeur*. Blender et
Godot refuseront de l'ouvrir, et tes envois de fichiers binaires échoueront
avec un message qui ne parle pas de LFS.

Réparation, sans recloner : `git lfs install` puis `git lfs pull`.
C'est exactement ce que fait `installer.ps1`.

## 3. Vérifier

```powershell
.\bg.ps1 outils          # ou en est la chaine d outils
.\bg.ps1 verif           # doit afficher VERIF OK
.\bg.ps1 jouer           # le jeu se lance
```

## 4. Commandes en jeu

| Touche | Action |
|---|---|
| **W A S D** / flèches | Marcher, puis conduire |
| **F** | Monter dans la voiture, en descendre |
| Espace | Frein à main |

Les touches sont liées par **position physique** : elles se lisent `WASD` en
QWERTY et QWERTZ, `ZQSD` en AZERTY, sans rien changer.

## 5. Déposer ton travail — une seule commande

Tu poses tes fichiers dans le bon dossier, puis :

```powershell
.\livrer.ps1
```

C'est tout. Le script fait le reste, dans cet ordre :

1. **Il vérifie ton installation** — Git, Git LFS, ton identité. Si quelque
   chose manque, il te dit exactement quoi taper au lieu d'échouer.
2. **Il récupère le travail des autres** avant d'envoyer le tien, pour éviter
   les conflits.
3. **Il te montre la liste** de ce qui va partir, et te demande confirmation.
4. **Il envoie.**

Tu peux lui donner une description :

```powershell
.\livrer.ps1 "sons moteur et portieres"
```

Sans description, il en écrit une lui-même (« 4 son(s), 2 modèle(s) 3D »).

Et pour regarder sans rien envoyer :

```powershell
.\livrer.ps1 -Quoi
```

### S'il s'arrête

Il ne te laisse jamais dans un état cassé : soit tout est envoyé, soit rien
ne l'est et ton travail reste intact en local. Le message t'indique la
marche à suivre. En cas de doute, **envoie une copie d'écran** — le message
contient tout ce qu'il faut pour comprendre.

### Deux règles à respecter

**Un fichier `.blend` par asset**, jamais un gros fichier de scène partagé.
Un binaire ne se fusionne pas : à deux sur le même fichier, le travail de
l'un serait purement et simplement jeté.

**Aucun média de la série** dans le dépôt — image, son, vidéo, police. Ils
vivent dans `assets-ref/`, que git ignore. Un fichier envoyé une fois reste
dans l'historique même après suppression.

## 6. Où mettre quoi

```
game/assets/sons/   tes WAV, par categorie
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
