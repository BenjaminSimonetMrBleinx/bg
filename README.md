# BG

**Breaking Bad Game** — Benjamin & Guillaume.

Un GTA-like en 3D low-poly PS2 dans l'univers de Breaking Bad. Albuquerque, Nouveau-Mexique.

> **Projet de fan, non commercial.** Voir [DISCLAIMER.md](DISCLAIMER.md).

---

## État du projet

**Le premier jalon est atteint, et dépassé.** Il y a un jeu qui tourne.

> « On conduit une voiture dans quatre blocs d'Albuquerque, de nuit, avec le rendu PS2,
> et on peut descendre du véhicule. »

Ce qui existe aujourd'hui :

| | |
|---|---|
| **Ville** | 2 × 2 îlots générés, routes, trottoirs franchissables, 32 lampadaires, brouillard de nuit |
| **Conduite** | `VehicleBody3D` réglé au curseur, caméra de poursuite, phares, moteur à trois couches sonores |
| **À pied** | Walter jouable et riggé — repos, marche, trot, course, tous calés sur la **distance parcourue** et pas sur l'horloge |
| **Maisons** | Walter et Jesse, extérieur en ville et intérieur séparé, entrée par la porte avec fondu |
| **Habitants** | Skyler et Jesse, qui se tournent vers le joueur et parlent |
| **Dialogue** | Piloté par `game/donnees/dialogues.json`, conversations tournantes |
| **Outils** | Roue à quatre objets — revolver, cristal, livre, porkpie — visibles dans la main |
| **Affichage** | Compteur au volant, nom de l'outil équipé |
| **Tests** | **10 suites automatiques**, `.\bg.ps1 test` |

**La première mission est jouable de bout en bout** — neuf temps, quinze
objectifs, quatre décors. Voir [NOTES-DE-VERSION.md](NOTES-DE-VERSION.md).

Ce qui n'existe pas encore : une deuxième mission, la police, le jour.

**La question ouverte** reste [`docs/00-questions.md`](docs/00-questions.md), blocs A, B, C et
F. Rien de ce qui a été fait n'en dépendait. La suite, si.

## Jouer

```powershell
.\go.ps1
```

Installe ce qui manque, récupère le travail de l'autre, envoie le tien, lance le jeu — en
sautant chaque étape inutile. Ou double-clic sur `JOUER.bat`.

**Tu démarres sur le trottoir devant chez Walter.** Sa porte est éclairée à deux pas, celle
de Jesse vingt mètres plus loin, la voiture est garée le long de la rue.

| Touche | À pied | Au volant |
|---|---|---|
| **W** / haut | Avancer | Accélérer |
| **S** / bas | Reculer | Freiner, puis marche arrière |
| **A** **D** / gauche droite | **Pivoter sur place** | Braquer |
| **Souris** | Regarder autour | Regarder autour |
| **Molette** | Rapprocher ou éloigner la caméra | idem |
| **F** | Fait toujours la chose la plus proche : monter, descendre, entrer, parler, sortir | |
| **Maj** maintenue | Courir. Par défaut Walter trottine ; à l'intérieur il marche | |
| **Espace** | **Sauter** — l'élan est conservé, on ne saute pas sur place | Frein à main |
| **Ctrl gauche** maintenu | **S'accroupir**, et se déplacer accroupi | |
| **H** | — | Klaxon |
| **Tab** maintenu | Roue des outils — viser avec gauche/droite, relâcher pour équiper | |
| **Clic droit** | **Viser**, le revolver en main | |
| **Clic gauche** | **Tirer**, en visant | |
| Échap | Rend le curseur de la souris | |

**À pied, gauche et droite font pivoter, elles ne déplacent pas.** Seuls avant et arrière
déplacent, dans l'axe du personnage. La caméra n'entre pas dans le calcul : où qu'elle
regarde, « avancer » veut toujours dire la même chose.

Les touches sont liées par **position physique**, pas par caractère : elles se lisent `WASD`
en QWERTY et QWERTZ, `ZQSD` en AZERTY, sans rien changer.

Rééquiper l'outil qu'on tient déjà le range — c'est le seul moyen de revenir aux mains vides.

## Documentation

| Document | Contenu |
|---|---|
| [`docs/05-demarrage.md`](docs/05-demarrage.md) | **Machine neuve : commence ici.** |
| [`docs/07-ajouter-du-contenu.md`](docs/07-ajouter-du-contenu.md) | **Écrire des dialogues, créer un personnage — sans coder.** |
| [`docs/06-travailler-a-deux.md`](docs/06-travailler-a-deux.md) | Qui fait quoi, qui tranche quoi, et pourquoi personne n'attend personne |
| [`livraisons/TICKETS.csv`](livraisons/TICKETS.csv) | **Ce qui manque au jeu, et où on en est.** S'ouvre dans Excel. Le canal entre Guillaume et l'intégration |
| [`docs/04-brief-son.md`](docs/04-brief-son.md) | Liste exhaustive des sons — pour Guillaume |
| [`docs/00-questions.md`](docs/00-questions.md) | Les questions de cadrage, **à remplir** |
| [`docs/01-cadrage.md`](docs/01-cadrage.md) | Décisions verrouillées, choix du moteur, répartition |
| [`docs/02-methode.md`](docs/02-methode.md) | Comment on code ce jeu au quotidien |
| [`docs/03-conventions-assets.md`](docs/03-conventions-assets.md) | Formats, budgets de triangles, pivots, nommage |
| [`docs/JOURNAL.md`](docs/JOURNAL.md) | Une entrée par étape : ce qui a marché, ce qui a cassé, pourquoi |

## Commandes

```powershell
.\bg.ps1 jouer       # lance le jeu
.\bg.ps1 editeur     # ouvre l editeur Godot (pour regler reglages.tres)
.\bg.ps1 generer     # regenere TOUT : textures, ville, vehicule, personnages, maisons, objets
.\bg.ps1 test            # les 14 suites
.\bg.ps1 test -Modifies  # seulement celles concernees par ce que tu as change
.\bg.ps1 test -Suite camera   # celles dont le nom contient "camera"
.\bg.ps1 verif       # le projet charge-t-il
.\bg.ps1 capture     # rend une image hors ecran dans .tmp/
.\bg.ps1 exporter    # fabrique build\BG.exe, jouable sans rien installer
.\bg.ps1 sons        # controle le format des fichiers audio (-Corriger pour convertir)
.\bg.ps1 son         # diagnostic complet quand le jeu est muet
.\bg.ps1 nettoyer    # vide .tmp et build
.\bg.ps1 reparer     # detruit le cache d import Godot et le reconstruit
.\bg.ps1 outils      # ou en est la chaine d outils
```

`reparer` est le dernier recours quand un fichier 3D, une image ou un son refuse de se
charger — typiquement un pointeur Git LFS non résolu, importé comme s'il s'agissait du vrai
fichier. Le cache reste alors faussé et le réimport normal n'y change rien.

`generer` accepte `-Blocs 4 -Graine 1234` pour changer la taille et le tirage de la ville,
et `-Moment jour` pour basculer en journée.

**`test -Modifies` est le mode à utiliser avant chaque commit.** Il demande à git ce qui a
bougé et ne rejoue que les suites concernées — chaque suite déclare les fichiers qu'elle
couvre, dans `bg.ps1`. Toucher `scenes/monde.tscn`, `reglages.tres` ou `project.godot`
relance tout : ce sont les trois fichiers que chaque suite charge.

La totale reste à jouer avant de livrer, et après un `generer`.

Pour envoyer son travail :

```powershell
.\livrer.ps1                       # verifie, recupere, montre, envoie
.\livrer.ps1 "sons de portieres"   # avec ta propre description
.\livrer.ps1 -Quoi                 # montre sans rien envoyer
```

## Où se règle quoi

Presque rien n'est écrit en dur. Avant de modifier du code, regarder si la chose vit déjà
dans un fichier de données :

| Fichier | Ce qu'on y règle |
|---|---|
| `game/systemes/reglages.tres` | ~80 curseurs : conduite, caméra, rendu PS2, audio, marche, portes, roue |
| `game/donnees/mission1.json` | **Le déroulé de la première mission** : ses étapes, ses objectifs, ses seuils |
| `game/donnees/dialogues.json` | Tout le texte parlé |
| `game/donnees/outils.json` | Les objets tenus, leur ancrage et leur orientation |
| `outils/animer_perso.py` | Les clips que les modèles livrés n'ont pas : repos, marche relâchée. **Et il MESURE les foulées** — ne pas les régler à l'œil |
| `outils/gen_textures.py` | `VISAGES` et `TENUES` — l'apparence des personnages |
| `outils/gen_maison.py` | `MAISONS` — pièces, meubles, place de l'habitant |
| `outils/gen_ville.py` | `RESERVES` — les parcelles laissées libres pour les bâtiments faits main |

## Regarder le jeu sans y jouer

```powershell
.\bg.ps1 capture -Scenario tous       # la planche complète, dans .tmp\captures\
.\bg.ps1 capture -Scenario desert     # une seule vue
```

Un **scénario** est une situation de jeu déclarée dans
[game/donnees/scenarios.json](game/donnees/scenarios.json) : une liste d'étapes datées en
images — placer quelqu'un, presser une touche, appeler une méthode, poser la caméra — puis
une capture. Ajouter une vue coûte six lignes de données.

**Pourquoi ça existe.** Le seul moyen de savoir si quelque chose est juste, ici, est de le
regarder. La flèche du désert pointait vers la ville, le cap d'arrivée était à 180°, un
cactus poussait à travers le camping-car : aucun des trois n'a été trouvé par un test, et
tous les trois ont sauté aux yeux sur une image.

Produire cette image demandait d'écrire un script jetable à chaque fois — instancier le
monde, téléporter, presser, attendre, enregistrer — puis de le supprimer. Quatre fois dans
la même journée, dont trois quasi identiques. Le quatrième n'a pas été écrit, et c'est
celui qui aurait montré le panneau à l'envers.

La planche **reste** : on la rejoue après un remaniement et on compare.

## Quoi de neuf

[NOTES-DE-VERSION.md](NOTES-DE-VERSION.md) — **à lire avant de tester**. Une entrée par
version, et deux choses seulement : ce qu'on peut essayer qui n'existait pas, et les bugs
qui gênaient vraiment. Pas de détail technique, il vit dans les commits.

## La version

Elle est affichée **en permanence en haut à droite de l'écran**, en tout petit :
`v0.9.0 · 8931b13`.

C'est la seule chose visible en continu, et ça vaut l'exception : quand quelqu'un envoie
une capture en disant que ça ne marche pas, la première question est toujours « tu es sur
quelle version ». Elle est maintenant sur l'image.

| | |
|---|---|
| **Le numéro** | `MAJEUR.MINEUR.CORRECTIF`. Vit dans `game/project.godot`, **et nulle part ailleurs** — c'est déjà le champ que Godot utilise pour l'export. En tenir un second garantirait qu'ils divergent. |
| **Le commit** | Écrit par `bg.ps1` avant chaque lancement. Un `+` à la fin veut dire qu'il y a du travail non commité : ce qui tourne ne correspond alors à aucun commit. |
| `.\bg.ps1 outils` | Affiche les deux. |

**Quand bumper.** `MAJEUR` passera à 1 le jour où le jeu se tient de bout en bout — on n'y
est pas. `MINEUR` à chaque lot de fonctionnalités. `CORRECTIF` pour ce qui répare sans rien
ajouter.

## Structure

Une règle, et elle décide de tout : **`game/` ne contient que ce que le jeu charge.**
Le reste est de la matière première ou de l'outillage.

```
game/          le projet Godot
  assets/      modèles, sons, voix — ce qui part dans l'exécutable
  donnees/     dialogues et outils, en JSON
  systemes/    le code du jeu
  scenes/      les scènes
  rendu/       le shader PS2
  verifs/      les suites de tests, jouées par .\bg.ps1 test
outils/        les générateurs Python et Blender qui fabriquent les assets
livraisons/    ce que Guillaume dépose, et les sources pas encore intégrées
docs/          cadrage, méthode, journal, backlog
.tmp/          tout ce qui se refabrique — jamais dans git
build/         l'exécutable — jamais dans git
```

Deux pièges que ces noms évitent, et qui coûtaient une hésitation à chaque fois :

- `assets/` existait **deux fois**, à la racine et dans `game/`, avec deux rôles opposés.
  Celui de la racine s'appelle maintenant `livraisons/` : on y **dépose**, on n'y lit pas.
- `outils/` aussi, à la racine et dans `game/`. Celui de Godot s'appelle `verifs/`, ce
  qu'il a toujours été.

## Mise en route sur une machine neuve

Git est la seule chose à poser soi-même — `winget` est livré avec Windows.
**Rouvrir PowerShell entre les deux** : Windows ne voit un outil fraîchement installé qu'à
partir d'une nouvelle session.

```powershell
winget install --id Git.Git -e
# fermer PowerShell, en rouvrir un
cd $HOME\Documents
git clone https://github.com/BenjaminSimonetMrBleinx/bg.git
cd bg
.\go.ps1
```

Outils : [Godot 4.7](https://godotengine.org/download) · [Blender 5.2](https://www.blender.org/download/) · [Python 3.12](https://www.python.org/downloads/) · [Git LFS](https://git-lfs.com/)
