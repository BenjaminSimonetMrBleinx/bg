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

**Le piège :** une virgule en trop et *tout le monde* devient muet, sans qu'aucune erreur
n'apparaisse ailleurs — la maison s'ouvre, le personnage est là, il n'a simplement rien à
dire. `.\bg.ps1 test` le détecte, et le jeu écrit `DIALOGUE : N personnage(s) chargés` au
démarrage. Si N est faux, le fichier est cassé.

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

**Règle apprise à la dure :** le contraste entre `poil` et `peau` doit être franc. À trente
pixels de haut, un blond doré sur une peau claire donne un bloc uni sans visage. Le
réalisme de la teinte perd contre la lisibilité, systématiquement.

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

**Si la clé ne correspond à rien dans `dialogues.json`**, le personnage apparaît mais reste
muet. `.\bg.ps1 test` vérifie exactement ce point, parce que c'est une panne qui ne se voit
pas autrement qu'en allant lui parler.

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

Le repère est centré sur la pièce. **Le générateur refuse d'exporter si l'habitant se
retrouve dans un meuble ou dans un mur** — ça s'est produit, Jesse était planté au milieu
de son plan de travail, coupé à la taille, et rien ne le signalait.

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
