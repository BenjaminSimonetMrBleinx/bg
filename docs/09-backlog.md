# Ce qui reste à faire

Une ligne par sujet, du plus utile au moins urgent. Ce fichier remplace les listes
éparpillées dans les conversations : quand une idée arrive, elle atterrit ici.

Rien n'est daté. On prend ce qui a le meilleur rapport effet/effort au moment où on a du
temps.

---

# La direction

> **Il ne manque pas du contenu, il manque un puits.**
>
> Il y a une ville, des déplacements et des objets, mais **rien qui coûte quelque chose au
> joueur**. Tant qu'aucune dépense n'est obligatoire et récurrente, aucune mécanique ne
> prendra, parce que rien ne rend l'argent désirable.

Ce diagnostic vient d'une consultation extérieure (conversation parallèle, 26 juillet 2026).
Il est retenu. Il change l'ordre du reste de ce fichier : le téléphone et le désert sont des
morceaux d'ambiance, pas des raisons de jouer.

**L'ordre proposé, du plus structurant au plus dépendant :**

```
livraison minimale  →  le puits  →  les témoins  →  la pureté  →  la réputation  →  la police
```

Chaque étape rend la précédente plus intéressante. Le jeu devient tendu bien avant la fin de
la liste.

---

## 1. La boucle de distribution — 8 à 10 soirées

Le générateur marque N bâtiments comme **contacts**. Chaque contact est une ligne de
données : position, demande, prix de base, tolérance au risque, quartier. On récupère de la
marchandise chez soi, on conduit, on livre, on encaisse.

L'argent est **sale** : il ne s'utilise pas directement. Une seconde adresse le blanchit à
un taux fixe, avec un délai. Les améliorations exigent de l'argent propre.

**Le puits** : une facture médicale qui tombe tous les X jours et qui augmente. Un entier et
un compte à rebours. C'est la seule chose qui manque aujourd'hui pour avoir une raison de
sortir.

**Ce que ça réutilise, sans rien modéliser de neuf** : la conduite devient le gameplay, les
distances de la ville deviennent un coût, les maisons deviennent base et planque, les PNJ
deviennent des interlocuteurs.

> **Premier jalon, deux soirées : un contact, une livraison, un compteur.** On saura tout de
> suite si le trajet est amusant ou ennuyeux — et c'est l'information la plus importante du
> projet. Tout le reste en dépend.

**Note technique** : `gen_ville.py` écrit déjà `ville_lampes.json`, relu par `ville.gd`.
Les contacts passent exactement par là. Rien à inventer.

## 2. Les témoins — 4 à 5 soirées

Le meilleur rapport effort/effet de la liste.

Les quinze passants existent et marchent. Leur donner un **cône de perception** — produit
scalaire sur le vecteur regard, plus un raycast. Toute action compromettante vue fait monter
un **compteur de soupçon par quartier**, qui décroît avec le temps.

**Le soupçon n'a pas besoin de police pour être intéressant**, et c'est pour ça qu'il vient
avant : au-dessus d'un seuil, les contacts du quartier refusent, les prix baissent, les
passants changent de trottoir. On obtient la sensation centrale de la série — **être vu**,
pas la fusillade — sans écrire une ligne de scénario.

La police, plus tard, se branchera dessus sans rien réécrire : une patrouille apparaît quand
le soupçon dépasse un seuil.

## 3. La pureté, statistique unique — 6 à 8 soirées

La cuisine se ramène à trois ou quatre curseurs abstraits et une formule qui sort un
pourcentage. Zéro chimie, zéro contenu écrit.

L'intérêt n'est pas le minijeu, il est qu'**un seul nombre irrigue tout le reste** : il fixe
le prix chez chaque contact selon sa tolérance, il fait monter la demande de quartier en
quartier, et il fait monter le soupçon, parce qu'un produit reconnaissable se remonte.

C'est la boucle de rétroaction de la série, obtenue en système plutôt qu'en scènes : plus le
produit est bon, plus il rapporte, plus il vous désigne.

La moitié du travail est la propagation dans l'économie, pas la cuisine.

## 4. Les quatre objets de la roue — quatre verbes, zéro combat

Ils s'équipent et se voient, rien de plus. Ce qui vaut le coup, sans partir sur du combat :

| Objet | Verbe | Coût |
|---|---|---|
| **Revolver** | Menacer, pas tirer. Dégainé près d'un contact, il force une issue favorable et fait bondir le soupçon. Ni mort ni dégâts : le PNJ obtempère ou fuit. | Réutilise « le PNJ se tourne vers le joueur » |
| **Cristal** | Le jeton de cargaison et le verbe d'échange. Devant un contact il ouvre la transaction ; dans la rue il multiplie le soupçon. | Faible |
| **Livre** | Le journal de bord, diégétique : contacts, prix connus, carte de chaleur des quartiers. | Nul côté 3D, tout en interface |
| **Chapeau** | Le plus rentable des quatre. Un booléen, deux multiplicateurs : porté, il améliore les prix et la déférence, et il accélère la reconnaissance par les témoins. **Tout le thème de la série tient dans ce compromis.** | Une demi-soirée |

---

# Ce qui va nous coincer

Signalé de l'extérieur, confronté au code d'ici. Trois points sur cinq sont déjà partiellement
couverts — les deux autres ne le sont pas du tout.

**Le jour/nuit est cuit dans les textures. Confirmé, et c'est le plus sérieux.**
L'état des vitres est peint dans les textures de façade, `bg.ps1 generer -Moment` choisit, et
`donnees/monde.json` transporte le choix jusqu'au ciel et aux lampadaires. La moitié des
systèmes ci-dessus veut du temps qui passe — livraisons nocturnes, horaires de contacts,
patrouilles. **À trancher avant d'en dépendre**, pas après.

**L'animation par code casse à la première action contextuelle.**
Ça tient pour la marche. Ouvrir un coffre, tendre un sac, dégainer : chaque geste serait codé
à la main, et ça devient ingérable vers le dixième. La sortie existe déjà à moitié —
`silhouette.gd` a `_tourner(nom, angle)` et une liste de segments nommés. **Le généraliser en
poses déclarées en données**, avec interpolation, est un petit travail *maintenant* et un
gros dans six mois.

**Les ancres mémorisables.** Un GTA repose sur des lieux qu'on reconnaît ; une ville
uniformément générée n'en produit aucun. Le mécanisme est déjà là — `RESERVES` dans
`gen_ville.py` laisse des parcelles libres, et c'est comme ça que les deux maisons sont
posées. Il reste à en faire un vrai système de lieux nommés et fixes, avant que la liste ne
s'allonge.

**Les dialogues qui tournent vont sonner creux.** La sortie est le **dialogue à trous** : des
fragments avec des emplacements remplis par l'état de la simulation — pureté du moment,
quartier chaud, dette en cours. Une petite grammaire produit des centaines de répliques
pertinentes et donne l'illusion que les PNJ savent ce qu'on fait.

**Le trafic, si on y va : sur graphe, jamais en physique.** Le graphe des routes existe
puisqu'on les génère. Des agents qui le suivent, avec un arrêt basique sur obstacle. La
simulation physique avec changement de voie est l'endroit précis où les projets à deux
meurent.

**Non technique** : projet de fan non commercial, le garder ainsi et continuer d'éviter tout
asset, logo ou audio issu de la série. C'est ce qui déclenche les retraits, bien plus que le
concept. Voir [DISCLAIMER.md](../DISCLAIMER.md) — la règle `assets-ref/` existe déjà pour ça.

---

# Demandé, à faire — mais après la direction ci-dessus

**Le téléphone.** Une touche ouvre un SGH-127 dessiné par-dessus le jeu, comme la roue.
Menu `Appeler` → `Jesse` ou `Skyler` → « Bonjour. » / « Bonjour. » → ça raccroche. Aucun
système neuf : c'est le dialogue existant, déclenché autrement. `telephone/phone_ring.wav`
attend depuis la livraison de Guillaume.

**Le désert.** Un panneau « DESERT » au bord de la ville, une flèche orange peinte au sol
devant. En voiture, la franchir téléporte vers une seconde carte avec le camping-car. À pied,
un bandeau : « Vous devez être en voiture pour vous rendre ici ».

> **Le vrai morceau, c'est le changement de scène.** Il n'existe qu'une seule scène,
> `monde.tscn`, avec tout dedans. Deux cartes demandent un mécanisme qui conserve le
> véhicule, l'équipement et le moment de la journée. C'est le premier bout d'infrastructure
> du projet qui ne soit pas du décor : à faire proprement une fois.

---

# Petites choses

## Sons livrés qui dorment encore

Vingt-quatre des vingt-huit sons de Guillaume sont branchés, tous par
`game/donnees/sons.json`. Restent :

| Fichiers | Ce qui manque |
|---|---|
| `vehicule/choc_leger_01..04`, `choc_fort_01..04` | **Rien ne détecte les collisions.** Le seul lot qui demande un mécanisme neuf. La force du choc choisirait entre léger et fort. |
| `interface/menu_item_hold`, `stop_time` | Une nappe qui démarre et s'arrête avec la roue, pas un bruitage. À faire quand on saura si ça alourdit le geste ou si ça le porte. |
| `telephone/phone_ring` | Attend le téléphone. |

## Dettes connues

- **Les passants sont muets.** `silhouette.gd` émet le signal `pas` pour tout le monde, mais
  seul le joueur l'écoute. Quinze passants sonores d'un coup risquaient une grêle de bruits
  sans qu'on sache d'où elle vient — à reprendre avec une portée courte.
- **Une seule surface de pas** : dehors ou dedans. Le brief prévoyait asphalte, béton et
  parquet distincts.
- **L'ambiance extérieure est une nappe de jour** et le jeu peut être de nuit. Il faudrait
  une nappe par moment, comme pour les textures.
- **Les intérieurs sont posés à des coordonnées écrites à la main** dans la scène. Ça tiendra
  tant qu'il y a deux maisons.
- **La carte de couverture des tests tire trop large** : bouger le numéro de version touche
  `project.godot`, qui est dans la liste des fichiers partagés, donc les 19 suites repartent.
  À affiner — ne déclencher la totale que si `[input]` ou `[rendering]` bouge.

## Le Walt sculpté, laissé en l'état

Décidé : on le garde tel quel. À distance de jeu — la tête fait douze pixels — il se lit
parfaitement. Deux défauts restent, et aucun ne se corrige par script :

- **Les mains sont éclatées.** Le maillage source est un bloc unique sans séparation entre la
  main et la hanche.
- **Le visage est rugueux de près.** La tête fait environ 130 faces ; une texture projetée
  casse sur chaque facette. C'est une limite de la géométrie.

**Ce qui le réglerait vraiment** : que Guillaume ouvre le `.blend` et sépare le maillage en
parties nommées (`Bassin`, `Torse`, `CuisseG`…) avec les origines sur les articulations. Une
demi-heure pour quelqu'un qui a le fichier ouvert, contre des heures de réglage à l'aveugle
autrement. `segmenter_modele.py` devient alors inutile.
