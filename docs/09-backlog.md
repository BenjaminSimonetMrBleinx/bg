# Ce qui reste à faire

Une ligne par sujet, du plus utile au moins urgent. Ce fichier remplace les listes
éparpillées dans les conversations : quand une idée arrive, elle atterrit ici.

Rien n'est daté. On prend ce qui a le meilleur rapport effet/effort au moment où on a du
temps.

---

## À brancher — du travail déjà livré qui dort

Les 28 sons de Guillaume sont branchés, sauf quatre lots. Tout passe par
`game/donnees/sons.json` : ajouter ou changer un son est une ligne de données, pas de code.

**Ce qui reste :**

| Fichiers | Ce qui manque |
|---|---|
| `vehicule/choc_leger_01..04`, `choc_fort_01..04` | **Rien ne détecte les collisions.** C'est le seul lot qui demande un mécanisme neuf. La force du choc devrait choisir entre léger et fort. |
| `interface/menu_item_hold`, `stp_time` | Une nappe qui démarre et s'arrête avec la roue, pas un bruitage ponctuel. À faire quand on saura si ça alourdit le geste ou si ça le porte. |
| `telephone/phone_ring` | Attend la fonctionnalité téléphone, plus bas. |

**Et deux dettes ouvertes par ce branchement :**

- **Les passants sont muets.** `silhouette.gd` émet le signal `pas` pour tout le monde,
  mais seul le joueur l'écoute. Quinze passants sonores d'un coup risquaient une grêle de
  bruits sans qu'on sache d'où elle vient — à reprendre avec une portée courte.
- **Une seule surface de pas.** Extérieur ou intérieur, rien de plus. Le brief prévoyait
  asphalte, béton et parquet distincts.

**Vérifier l'alignement des voix de la scène de la cuisine.** Les dix répliques ont été
affectées séquentiellement, sans que personne n'ait écouté. Si c'est décalé, redécouper avec
un autre seuil ; les originaux sont archivés dans `livraisons/voix/originaux/`.

---

## Demandé, à concevoir puis faire

**Le téléphone.** Une touche ouvre un SGH-127 dessiné par-dessus le jeu, comme la roue.
Menu `Appeler` → `Jesse` ou `Skyler` → « Bonjour. » / « Bonjour. » → ça raccroche. Les
répliques vivent dans `dialogues.json`, aucune voix pour l'instant. Aucun système neuf : c'est
le dialogue existant, déclenché autrement.

**Le désert.** Un panneau « DESERT » au bord de la ville, une flèche orange peinte au sol
devant. En voiture, la franchir téléporte vers une seconde carte avec le camping-car. À pied,
un bandeau : « Vous devez être en voiture pour vous rendre ici ».

> **Le vrai morceau, c'est le changement de scène.** Il n'existe aujourd'hui qu'une seule
> scène, `monde.tscn`, avec tout dedans. Deux cartes demandent un mécanisme qui conserve le
> véhicule, l'équipement et le moment de la journée. C'est le premier bout d'infrastructure du
> projet qui ne soit pas du décor : à faire proprement une fois.

---

## Le modèle sculpté de Walt

`livraisons/modeles/walt_sculpte.obj`, livré par Benjamin. 1088 faces, converti en
`game/assets/personnages/walt_sculpte.glb`. Il se lit immédiatement comme Walter White, ce
que notre personnage généré ne fait pas.

Deux obstacles, et ils décident de l'usage :

- **Aucune coordonnée de texture.** Il ne peut porter aucune image — ni visage, ni chemise. Il
  restera d'une seule couleur tant que quelqu'un ne le déplie pas dans Blender.
- **Une seule pièce.** L'animation du projet fait tourner des segments nommés (`Bassin`,
  `Torse`, `CuisseG`…). Un maillage d'un bloc ne peut pas marcher : il glisserait, raide.

Trois façons d'en tirer quelque chose, par coût croissant :

1. **Un PNJ immobile.** Utilisable tout de suite, sans rien toucher. Quelqu'un d'assis, un
   type au coin de la rue.
2. **Le découper aux mêmes noms de segments**, par plans horizontaux dans Blender. Il entre
   alors dans l'animation existante sans une ligne de code. Découpe grossière aux
   articulations, mais c'est exactement ce que faisait la PS2.
3. **Le déplier et le texturer.** Le plus beau résultat, et le plus de travail — c'est du
   métier de Guillaume, pas du script.

---

## Dettes connues

- **L'ambiance sonore est une nappe de jour** (`amb_rue_jour`) et le jeu peut être de nuit.
  Il faudrait une nappe par moment, comme pour les textures.
- **Les intérieurs sont posés à des coordonnées écrites à la main** dans la scène, au lieu
  d'être placés par un système. Ça tiendra tant qu'il y a deux maisons.
- **Aucun son de pas.** Le brief en prévoit, ils ne sont pas enregistrés.
- **Les objets de la roue ne s'utilisent pas.** Ils s'équipent et se voient, rien de plus.
  Décidé : on ne fait pas l'arme pour l'instant.

---

## Le Walt sculpté : ce qui marche et ce qui reste moche

Audit fait en captures, huit vues, après passage en personnage jouable.

**Ce qui est bon** : la silhouette, la démarche, les vêtements, le chapeau qui se pose sur la
tête, le revolver dans la main. À distance de jeu — la tête fait **douze pixels** — il se lit
parfaitement.

**Un vrai bug trouvé et corrigé** : la partie basse des mains tombait dans la **cuisse** et
partait avec elle à chaque foulée. Des éclats de peau flottaient autour des hanches. La cause
était un seuil qui n'attribuait au segment « main » qu'une bande étroite autour du poignet.

**Ce qui reste moche, et pourquoi :**

- **Les mains restent éclatées.** Le maillage source est un bloc unique sans séparation entre
  la main et la hanche. Une coupe par plans horizontaux ne peut pas trouver un poignet : elle
  coupe où on lui dit, pas où est l'articulation.
- **Le visage est rugueux de près.** La tête fait environ 130 faces. Une texture projetée
  casse sur chaque facette, et aucun réglage n'y changera rien — c'est une limite de la
  géométrie, pas du script.

**Ce qui le règlerait vraiment.** Que Guillaume ouvre le `.blend` et **sépare le maillage en
parties nommées** (`Bassin`, `Torse`, `CuisseG`…) avec les origines sur les articulations.
C'est une demi-heure pour quelqu'un qui a le fichier ouvert, contre des heures de réglage à
l'aveugle de mon côté. `segmenter_modele.py` devient alors inutile : le modèle entre
directement dans l'animation.

Même chose pour le visage : un dépliage à la main de la seule tête, et une texture peinte
dessus, valent tous les réglages automatiques du monde.

**En attendant, deux choix défendables :** le garder tel quel — les défauts sont invisibles à
distance de jeu — ou revenir au personnage généré, qui est laid mais cohérent avec la ville et
les passants.
