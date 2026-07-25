# Ajouter du contenu sans écrire de code

Trois choses se règlent en éditant un fichier de données : **ce que les gens disent**,
**à quoi ils ressemblent**, et **qui habite où**. Aucune ne demande d'ouvrir Godot.

Après toute modification décrite ici :

```
.\bg.ps1 generer     # régénère textures, personnages, maisons, ville
.\bg.ps1 test        # vérifie que rien n'est cassé
.\bg.ps1 jouer
```

`generer` est sans risque : les générateurs écrivent toujours le même résultat pour les
mêmes entrées. On peut le relancer autant qu'on veut.

> **Note — passer par `generer`, jamais par Blender directement.**
> Godot garde une copie importée de chaque fichier 3D. Régénérer un `.glb` à la main sans
> lui dire de le relire laisse le jeu servir l'ancienne version : on corrige, on relance,
> rien ne change, et on cherche l'erreur ailleurs. Ça nous est arrivé deux fois en un
> week-end. `.\bg.ps1 generer` fait le réimport à la fin, c'est tout l'intérêt.

> **Note — `generer` couvre tout.**
> Textures, ville, véhicule, personnages **et** maisons. Une version antérieure oubliait
> les deux derniers : on pouvait modifier un visage ou déplacer un habitant sans qu'aucun
> changement n'apparaisse. Si un doute revient un jour, la liste est en tête de la commande
> dans `bg.ps1`.

---

## 1. Changer ou ajouter des répliques

Un seul fichier : **`game/donnees/dialogues.json`**. Rien à régénérer, le jeu le relit
à chaque lancement.

```json
"jesse": {
  "nom": "Jesse",
  "conversations": [
    [
      { "qui": "Jesse",  "texte": "Yo. T'as pas frappé." },
      { "qui": "Walter", "texte": "La porte était ouverte." }
    ],
    [
      { "qui": "Walter", "texte": "Il nous faut du matériel." }
    ]
  ]
}
```

- **`conversations`** est une liste de conversations. Le jeu joue la première au premier
  contact, la deuxième au suivant, et ainsi de suite avant de recommencer. En ajouter une
  suffit à faire respirer le personnage.
- **`qui`** est affiché tel quel au-dessus de la réplique. Ce n'est pas une clé, on peut y
  mettre n'importe quoi.
- **Garder les répliques courtes.** L'écran fait 512 pixels de large et le cadre en affiche
  trois lignes. Au-delà, le texte est coupé.

> **Note — une virgule en trop rend *tout le monde* muet.**
> Et sans qu'aucune erreur n'apparaisse ailleurs : la maison s'ouvre, le personnage est là,
> il n'a simplement rien à dire. Deux façons de le voir tout de suite — `.\bg.ps1 test`, et
> la ligne `DIALOGUE : N personnage(s) chargés` écrite au démarrage du jeu. Si N ne
> correspond pas au nombre de personnages du fichier, il est cassé.

> **Note — les accents et apostrophes passent sans problème.**
> Le fichier est en UTF-8, écrire « t'as pas frappé » est correct. En revanche une
> apostrophe ne doit jamais fermer une chaîne : c'est `"texte": "t'as"`, avec des
> guillemets doubles autour. JSON n'accepte pas les guillemets simples.

---

## 2. Créer un nouveau personnage

Trois entrées de dictionnaire, dans deux fichiers. Aucune fonction à écrire.

### a. Son visage — `outils/gen_textures.py`, dictionnaire `VISAGES`

```python
"hank": {
    "peau": (196, 158, 132),      # carnation de base
    "poil": (74, 58, 46),         # cheveux, sourcils, barbe
    "cheveux": "courts",          # "courts" | "calvitie" | "longs"
    "lunettes": False,
    "moustache": True,
    "bouc": False,
    "barbe_naissante": False,     # facultatif : assombrit la mâchoire
},
```

Un visage PS2 est une texture peinte sur une boîte : aucune géométrie ne représente un nez
ou un œil à ce budget de triangles. Tout le personnage tient donc dans ces quelques traits.

> **Note — le contraste entre `poil` et `peau` doit être franc.**
> Une tête fait vingt à trente pixels de haut à l'écran. Skyler avait des cheveux blond
> doré sur une peau claire : son visage ne se lisait plus du tout, on ne voyait qu'un bloc
> uni. Passé en blond cendré, elle est redevenue lisible. À cette résolution, le réalisme
> de la teinte perd contre la lisibilité, systématiquement — et ça vaudra pour tous les
> personnages à venir.

### b. Sa tenue — même fichier, dictionnaire `TENUES`

```python
"hank": {
    "peau": (198, 160, 134),      # mains et avant-bras
    "haut": (108, 96, 84),        # chemise ou sweat
    "capuche": False,             # True : poche ventrale au lieu d'une boutonnière
    "bas": (58, 62, 74),          # pantalon
},
```

Les deux dictionnaires doivent avoir **la même clé**.

### c. Sa taille — `outils/gen_personnage.py`, dictionnaire `PERSONNAGES`

```python
"hank": {"taille": 1.03},         # multiplicateur ; Walter fait 1,78 m
```

C'est tout. `.\bg.ps1 generer` produit `game/assets/personnages/hank.glb`.

**Le maillage est le même pour tout le monde** — seules les textures changent. C'est
volontaire : l'animation procédurale écrite pour Walter marche telle quelle sur n'importe
quel personnage, sans qu'on ait à retoucher quoi que ce soit.

---

## 3. Installer quelqu'un dans une maison

Là, il faut ouvrir Godot une fois — c'est la seule étape qui le demande.

1. Ouvrir `game/scenes/monde.tscn`
2. Sélectionner la maison sous `Rendu → Scene3D → Maisons`
3. Dans l'inspecteur :
   - **Habitant Geometrie** → glisser le `.glb` du personnage
   - **Habitant Cle** → la clé utilisée dans `dialogues.json`

Le personnage se pose tout seul sur le repère `Habitant` de la pièce, face à la porte, et
se tourne vers le joueur quand celui-ci approche.

> **Note — une clé mal orthographiée donne un personnage muet, pas une erreur.**
> Il apparaît, il se tourne vers vous, et l'invite « Parler à » ne mène à rien.
> `.\bg.ps1 test` vérifie exactement ce point, parce que ça ne se voit pas autrement qu'en
> allant lui parler.

---

## 4. Déplacer un habitant ou meubler une pièce

Dans `outils/gen_maison.py`, dictionnaire `MAISONS` :

```python
"jesse": {
    "piece": (7.2, 6.6, 2.8),          # largeur, profondeur, hauteur
    "meubles": [
        # x, y, largeur, profondeur, hauteur, texture
        (-2.0, 1.6, 2.6, 1.0, 0.72, "pantalon"),
    ],
    "habitant": (0.0, 1.5),            # où il se tient
},
```

Le repère est centré sur la pièce.

> **Note — le générateur refuse d'exporter une pièce mal fichue.**
> Si l'habitant se retrouve dans un meuble ou dans un mur, `generer` s'arrête et dit lequel.
> Ce n'est pas de la prudence gratuite : Jesse était planté au milieu de son plan de
> travail, coupé à la taille, et rien ne le signalait — il fallait aller le voir.

---

## Ce qui demande vraiment du code

Pour mémoire, la frontière :

| Ça se fait en données | Ça demande d'écrire du code |
|---|---|
| Répliques, conversations | Un choix dans un dialogue |
| Apparence d'un personnage | Un nouveau type de vêtement |
| Qui habite où | Une nouvelle pièce dans une maison |
| Meubles, position d'un habitant | Un PNJ qui se déplace |
| Tous les réglages de `reglages.tres` | Une nouvelle mécanique |

Quand une envie tombe dans la colonne de droite, la dire — c'est souvent moins de travail
qu'il n'y paraît, et c'est le bon moment pour décider si ça vaut le coup.

---

## 5. Livrer un modèle 3D fait à la main

Pose le fichier dans **`assets/modeles/`** — `.obj`, `.fbx`, `.dae`, `.stl` ou `.glb`, peu
importe. Puis :

```powershell
blender -b -P outils/importer_modele.py -- --fichier assets/modeles/ton_fichier.obj `
        --sortie game/assets/personnages/ton_nom.glb --hauteur 1.78
```

La conversion met à l'échelle, pose les pieds à l'origine et oriente vers l'avant du jeu.
Elle affiche aussi ce qu'elle a trouvé : nombre de faces, présence d'UV, dimensions.

> **Note — sans coordonnées de texture, le modèle reste d'une seule couleur.**
> Aucun script n'invente un dépliage. Un personnage livré sans UV n'aura ni visage ni
> vêtements : il sera propre, gris, et muet visuellement. C'est le premier point à vérifier
> dans la sortie de l'outil.

> **Note — un maillage d'un seul bloc ne peut pas marcher.**
> L'animation fait tourner des segments nommés : `Bassin`, `Torse`, `CuisseG`, `CuisseD`,
> `TibiaG`, `TibiaD`, `BrasG`, `BrasD`, `AvantBrasG`, `AvantBrasD`. Un modèle qui les porte
> entre dans l'animation existante sans une ligne de code. Un modèle d'un bloc ne peut servir
> que de statue — ce qui est parfois exactement ce qu'on veut.

### Rendre un modèle sculpté animable

Deux passes, dans cet ordre — le découpage conserve les UV et le matériau, donc on texture
d'abord :

```powershell
# 1. Déplier et peindre
blender -b -P outils/texturer_modele.py -- --fichier assets/modeles/ton_fichier.obj `
        --sortie game/assets/personnages/ton_nom_texture.glb --qui walter --taille 512

# 2. Découper en segments animables
blender -b -P outils/segmenter_modele.py -- `
        --fichier game/assets/personnages/ton_nom_texture.glb `
        --sortie game/assets/personnages/ton_nom_anime.glb
```

Le résultat entre dans l'animation existante **sans une ligne de code** : `silhouette.gd`
retrouve ses segments par leur nom.

> **Note — le dépliage automatique place les îlots n'importe où.**
> On ne peut donc pas peindre « le visage sur la tête » en regardant l'image. L'outil prend
> le problème à l'envers : il classe chaque face par sa **position dans le corps** — hauteur,
> distance à l'axe, orientation — et peint sa case UV en conséquence. Le dépliage ne sert que
> d'adresse.

> **Note — le pivot compte plus que la découpe.**
> L'origine de chaque segment doit tomber sur son articulation. Sinon la cuisse tourne autour
> du genou et la jambe part en hélice. Les articulations sont mesurées sur la géométrie
> réelle, pas supposées : un modèle plus large ou plus étroit que le nôtre reste correct.

> **Note — les articulations sont franches, et ça se voit.**
> À l'épaule et à la hanche, la matière se sépare quand l'angle est grand. C'était le cas sur
> PS1, ça l'est ici. C'est le prix pour qu'un modèle sculpté entre dans une animation écrite
> pour des boîtes — et à distance de jeu, personne ne le remarque.

Les seuils de découpe (`--epaule`, `--hanche`, `--bras`…) sont réglables : un modèle aux
proportions inhabituelles se rattrape sans toucher au script.
