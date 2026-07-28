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
| **Outils** | Roue à cinq objets — revolver, cristal, botte secrète, livre, porkpie. Le chapeau se **porte**, le livre se **lit** |
| **Affichage** | Portrait, vie et argent en un bloc, compteur au volant, téléphone avec jauge de mission |
| **Tests** | **27 suites automatiques**, `.\bg.ps1 test -Suite <nom>` |
| **Contrôle visuel** | **32 scénarios de capture**, `.\bg.ps1 capture -Scenario <nom>` |

**La première mission est jouable de bout en bout** — neuf temps, quinze
objectifs, quatre décors. Voir [NOTES-DE-VERSION.md](NOTES-DE-VERSION.md).

Ce qui n'existe pas encore : une deuxième mission, la police, l'économie.

**La question ouverte** reste [`docs/00-questions.md`](docs/00-questions.md), blocs A, B, C et
F. Rien de ce qui a été fait n'en dépendait. La suite, si.

## Jouer — sans rien installer

**[→ Télécharger la dernière version](https://github.com/BenjaminSimonetMrBleinx/bg/releases/latest)**

Un `.zip`, un `.exe` dedans, double-clic. Pas de Godot, pas de Blender, pas de
Python, pas de compte, rien à cloner. C'est ce qu'il faut à quelqu'un qui veut
juste essayer le jeu.

Windows affichera un avertissement « éditeur inconnu » : l'exécutable n'est pas
signé, et le faire signer coûte plus cher que le jeu ne vaut. **Informations
complémentaires → Exécuter quand même.**

## Jouer depuis les sources

Pour ceux qui développent ou qui livrent des assets.

```powershell
.\go.ps1
```

Installe ce qui manque, récupère le travail de l'autre, envoie le tien, lance le jeu — en
sautant chaque étape inutile. Ou double-clic sur `JOUER.bat`.

**C'est ce chemin qui demande la chaîne d'outils complète** — Git, Git LFS, Godot, Blender,
Python, ffmpeg. `installer.ps1` s'en occupe, mais ça reste un téléchargement de plusieurs
gigaoctets. Personne ne devrait passer par là pour jouer vingt minutes.

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

## Un bug, une idée, une envie

**Tout se passe au même endroit : [les tickets](https://github.com/BenjaminSimonetMrBleinx/bg/issues).**

Le bouton **New issue** propose un formulaire selon ce que tu viens faire — signaler un bug,
proposer une idée, lancer une feature, dire qu'un fichier est prêt. Aucun ne demande de
classer quoi que ce soit.

La **[feuille de route](https://github.com/BenjaminSimonetMrBleinx/bg/issues/22)** est
épinglée en haut de la liste : ce qui est prévu, dans l'ordre, et ce que l'assistant attend
de vous pour avancer.

Le mode d'emploi complet : [`docs/09-communiquer.md`](docs/09-communiquer.md).

## Documentation

| Document | Contenu |
|---|---|
| [`docs/12-direction.md`](docs/12-direction.md) | **Où va ce jeu.** Piliers, boucle, verbes, histoire, missions — et les questions ouvertes |
| [`docs/13-carte.md`](docs/13-carte.md) | **La carte.** Trois architectures, une maquette chiffrée d'Albuquerque |
| [`CLAUDE.md`](CLAUDE.md) | **Comment on travaille.** Ce qui n'est pas négociable, ce qu'il faut refuser, le rituel de fin de session |
| [`docs/11-pieges.md`](docs/11-pieges.md) | **Ce que le projet a appris en se trompant.** Seize pièges qui ne préviennent pas |
| [`docs/05-demarrage.md`](docs/05-demarrage.md) | **Machine neuve : commence ici.** |
| [`docs/07-ajouter-du-contenu.md`](docs/07-ajouter-du-contenu.md) | **Écrire des dialogues, créer un personnage — sans coder.** |
| [`docs/06-travailler-a-deux.md`](docs/06-travailler-a-deux.md) | Qui fait quoi, qui tranche quoi, et pourquoi personne n'attend personne |
| [`docs/09-communiquer.md`](docs/09-communiquer.md) | **Comment on se parle.** Bugs, idées, features, priorités — tout passe par les tickets |
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
.\bg.ps1 test -Suite camera   # LA suite nommee. C est le mode a utiliser
.\bg.ps1 test            # les 27 suites — reserve aux grosses releases
.\bg.ps1 verif       # le projet charge-t-il
.\bg.ps1 capture     # rend une image hors ecran dans .tmp/
.\bg.ps1 integrer    # met un modele livre aux normes et le pose dans game\assets
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

**Tester coûte du temps qu'on ne passe pas à livrer.** Le jeu est petit ; la suite nommée
suffit pendant l'itération, et `couvre` dans `bg.ps1` dit laquelle couvre quel fichier.

`test -Modifies` demande à git ce qui a bougé — mais **il n'est pas ciblé sur ce projet** :
toucher `monde.tscn`, `controleur.gd`, `reglages.tres` ou `project.godot` relance les 27
suites, et c'est presque toujours le cas. La totale est réservée aux grosses releases et à
l'après-`generer`.

`integrer` est le **seul** chemin par lequel un modèle livré entre dans le jeu : il le met
à l'échelle, le pose au sol, l'oriente, puis **relit le fichier écrit** pour vérifier que
tout a survécu à l'export. Voir [`CLAUDE.md`](CLAUDE.md) et
[`docs/11-pieges.md`](docs/11-pieges.md).

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
