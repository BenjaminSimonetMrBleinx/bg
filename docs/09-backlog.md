# Ce qui reste à faire

Une ligne par sujet, du plus utile au moins urgent. Ce fichier remplace les listes
éparpillées dans les conversations : quand une idée arrive, elle atterrit ici.

Rien n'est daté. On prend ce qui a le meilleur rapport effet/effort au moment où on a du
temps.

---

## À brancher — du travail déjà livré qui dort

**Les sons de Guillaume ne sont pas tous utilisés.** Trois fichiers sont dans le dépôt et
n'existent pour aucun mécanisme :

| Fichier | Ce qu'il attend |
|---|---|
| `vehicule/roulement_asphalte.wav` | Un roulement continu dont le volume et la hauteur suivent la vitesse. C'est ce qui donne le poids d'une voiture, bien plus que le moteur seul. |
| `vehicule/pneus_crissement.wav` | Le frein à main, et le moment où l'arrière décroche. Il faut lire le `skidinfo` des roues arrière. |
| `vehicule/choc_leger_01.wav` | Une collision. **Rien ne détecte les chocs aujourd'hui** — c'est le seul des trois qui demande un mécanisme neuf. |

**Vérifier l'alignement des voix de la scène de la cuisine.** Les dix répliques ont été
affectées séquentiellement, sans que personne n'ait écouté. Si c'est décalé, redécouper avec
un autre seuil ; les originaux sont archivés dans `assets/voix/originaux/`.

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

`assets/modeles/walt_sculpte.obj`, livré par Benjamin. 1088 faces, converti en
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
