# La carte

Trois architectures étudiées, une **arrêtée le 28/07/2026**, et une maquette
chiffrée d'Albuquerque pour ce jeu.

> **Décidé.** Architecture **C — quartiers chargés à la volée dans un seul
> repère de coordonnées**. Un quartier en mémoire à la fois, un fondu court aux
> jonctions. C'est ce que le désert fait déjà : la carte généralise un
> mécanisme éprouvé au lieu d'en écrire un nouveau.
>
> **Décidé.** Trame parallèle à la série, avec liberté sur l'histoire
> principale quand ça sert le jeu — voir
> [12-direction-du-jeu.md](12-direction-du-jeu.md).
>
> **Ouvert.** La boucle de jeu. Elle décidera de la densité des commerces et du
> nombre de points de vente, donc une partie du § 3 attend cette réponse.

---

## 1. Ce qu'on a déjà, mesuré

| | |
|---|---|
| Bloc de ville | 40 m de côté, bâti sur 12 m de profondeur, cour au centre |
| Rue | 11 m de chaussée + 2 × 3 m de trottoir = **17 m** |
| Pas de la grille | **57 m** |
| Ville actuelle | 2 × 2 îlots, soit ~115 × 115 m |
| Désert | terrain carré de **460 m**, centré à (900, −900) |
| Liaison | une route et un `Passage` — chargement séparé, avec fondu |

Le générateur accepte déjà `-Blocs N`. Une ville de 16 × 16 îlots sortirait
sans qu'on écrive une ligne : **912 m de côté**. C'est un fait important pour
la suite — la question n'est pas « sait-on faire une grande carte », c'est
« qu'est-ce qu'on met dedans ».

---

## 2. Les trois architectures

### A. Monde ouvert continu

Tout dans une scène, chargé au lancement.

**Pour** : aucune couture, on voit loin, la conduite est reine, et c'est ce que
le code fait déjà. **Contre** : la mémoire et le temps de chargement montent
avec la surface ; au-delà de ~2 km de côté, le brouillard PS2 ne suffit plus à
cacher l'horizon et il faut du LOD.

**Verdict** : parfaitement viable jusqu'à environ **1,5 km de côté**, ce qui est
déjà quatre fois plus grand que ce dont on a besoin pour l'acte I.

### B. Découpage en tuiles chargées à la volée

La carte est découpée en carrés de 300 m, chargés et déchargés selon la
position du joueur.

**Pour** : plus de limite de taille. **Contre** : c'est un système à écrire, à
déboguer et à tester ; il change la façon d'écrire chaque scène ; et il ne sert
à rien tant que la carte tient en mémoire. **Le coût est immédiat, le gain est
hypothétique.**

**Verdict** : pas maintenant. À reconsidérer le jour où l'acte II demandera
vraiment quatre quartiers distincts et peuplés.

### C. Quartiers chargés à la volée — ← **ARRÊTÉ**

Une **ville continue**, plus des **lieux séparés** qu'on rejoint par une route
et un chargement court : le désert, l'entrepôt, le ranch, la casse.

**Pour** :
- c'est exactement ce que le code fait déjà, éprouvé sur le désert ;
- ça correspond à la série : **le trajet vers le désert est un rituel**, et une
  coupure au milieu ne le trahit pas, elle le souligne ;
- chaque zone se conçoit, se teste et se livre séparément — Guillaume peut
  travailler un lieu sans que rien d'autre bouge ;
- une zone vide coûte zéro tant qu'on n'y est pas.

**Contre** : on ne peut pas voir le désert depuis la ville. Sur cette direction
artistique, avec ce brouillard, ce n'était de toute façon pas possible.

**Verdict** : c'est l'architecture du jeu. Elle n'interdit rien : le jour où
l'on voudra fondre deux zones, il suffira de retirer un `Passage`.

**Ce que ça implique concrètement**, et c'est plus petit qu'il n'y paraît. On
n'écrit pas un système de streaming. On garde **un seul repère de coordonnées**
— celui qui place déjà le désert à (900, 0, −900) — et on charge ou décharge
des **sous-arbres** selon la distance au joueur. `desert.gd` cesse d'être un
cas particulier et devient le premier client d'un gestionnaire qui en gère
cinq. Le fondu et le `Passage` existent déjà.

**Le premier chantier est donc une généralisation, pas une construction.**

---

## 3. La carte proposée

Albuquerque **stylisée, pas relevée**. On garde la lecture d'ensemble — la
grille, les montagnes à l'est, le désert à l'ouest, l'autoroute qui coupe — et
on ignore l'échelle réelle. La vraie ville fait 490 km² ; la nôtre en fera
**1,2**, et personne ne le remarquera si les bons repères sont là.

```
                      N
        ┌──────────────────────────────┐
        │  SANDIA  (montagnes, decor)  │
        ├───────┬──────────┬───────────┤
        │       │          │           │
   ouest│ RIO   │  CENTRE  │  HAUTEURS │ est
        │ SUD   │          │           │
        │ (indus│ (commerc │ (pavillon │
        │ trie) │  e, vie) │  s, Walt) │
        ├───────┴────┬─────┴───────────┤
        │  L'AUTOROUTE (I-40 stylisee) │
        ├────────────┴─────────────────┤
        │       ZONE SUD (motels)      │
        └──────────────┬───────────────┘
                       │ route du desert
                       ▼
              ╔════════════════════╗
              ║  LE DESERT (zone)  ║
              ║  camping-car, QG   ║
              ╚════════════════════╝
```

### Les cinq quartiers, et ce que chacun sert

| Quartier | Surface | Rôle de jeu | Ce qu'on y trouve |
|---|---|---|---|
| **Les Hauteurs** | 400 × 400 m | La base, la vie normale | Maison de Walt, école, voisins, calme — et donc **des témoins** |
| **Le Centre** | 500 × 500 m | Le commerce, la densité | Contacts, blanchiment, Los Pollos, circulation, police visible |
| **Rio Sud** | 400 × 300 m | L'industrie, la nuit | Entrepôts, casse, labo fixe de l'acte II, peu de témoins |
| **Zone Sud** | 300 × 400 m | Le bas de l'échelle | Motels, stations-service, dealers de rue, prix bas et risque haut |
| **Sandia** | décor | L'horizon | Montagnes non praticables, à l'est. Elles donnent le nord |

**Total praticable : environ 1 100 × 1 100 m.** Traversée d'un bout à l'autre à
50 km/h : **80 secondes**. C'est la bonne durée pour une livraison : assez
longue pour qu'un détour se décide, assez courte pour qu'on en fasse cinq dans
une soirée.

### Les zones séparées

| Zone | Débloquée | Pourquoi séparée |
|---|---|---|
| **Le désert** ✅ | acte I | Existe déjà. Le camping-car, le QG de Tuco |
| **La casse** | acte I | Petite, dense, verticale — un décor de rendez-vous |
| **L'entrepôt** | acte II | Le laboratoire fixe. Intérieur, très éclairé, l'opposé du reste |
| **Le ranch** | acte III | Loin, isolé, une seule route |

---

## 4. Ce qui rend une carte vivante, dans cet ordre

C'est là que se joue la différence, plus que dans la surface.

1. **Des repères qu'on reconnaît de loin.** Trois ou quatre silhouettes
   suffisent : le panneau de Los Pollos, le château d'eau, l'échangeur, la
   montagne. On se dirige par eux, jamais par une carte.
2. **Des rues qui ne se ressemblent pas.** Le générateur pose déjà des façades
   variées ; il lui manque des **largeurs** différentes. Une avenue à quatre
   voies et une ruelle changent plus la lecture que cinquante textures.
3. **De la vie aux bons endroits.** Pas une foule uniforme : dense au centre,
   rare dans le pavillonnaire, nulle dans l'industriel la nuit. La rareté est
   ce qui rend la densité lisible.
4. **De la verticalité minimale.** Un pont, un échangeur, un parking en étage.
   Trois dénivelés suffisent à casser l'impression de damier.
5. **Des impasses et des cours.** Une grille parfaite se lit comme un tableur.
   Le générateur doit pouvoir supprimer une rue sur huit.

---

## 5. Ce que ça demande comme travail

| Étape | Effort | Ce que ça débloque |
|---|---|---|
| Passer la ville à 8 × 8 îlots | déjà possible | Une vraie surface à parcourir |
| Zones par quartier dans le générateur | 2 soirées | Densité, hauteurs et palette par quartier |
| Largeurs de rue variables | 1 soirée | La carte cesse d'être un damier |
| Trois repères en dur | 2 soirées | On se dirige sans carte |
| Une carte à l'écran | 2 soirées | Les contacts deviennent une interface |
| Dénivelé (un pont) | 3 soirées | Le plus cher, et le plus visible |

**Le meilleur premier pas est le moins cher : passer à 8 × 8 et rouler dedans.**
On saura immédiatement si 450 m de côté suffisent, ou s'il en faut le double —
et cette réponse-là ne se déduit pas, elle se conduit.

---

## 6. La règle de construction

**Un quartier n'est construit que lorsqu'une mission a besoin d'y être.**

On a déjà un désert magnifique où l'on ne fait presque rien. Il ne faut pas en
construire quatre autres. L'ordre qui en découle :

1. **Généraliser le désert** en gestionnaire de quartiers — aucun contenu
   nouveau, la ville et le désert deviennent les quartiers 1 et 2 ;
2. **Les Hauteurs**, parce que la maison de Walt existe déjà et n'a pas de rue ;
3. **Rio Sud**, quand le labo aura besoin d'un entrepôt ;
4. **Le reste**, quand la menace aura un visage.

---

## 7. Questions ouvertes

1. **La taille.** Est-ce qu'on vise 1,1 km de côté, ou est-ce qu'on commence à
   450 m — 8 × 8 îlots — et on agrandit quand la carte est trop petite ?
2. **La fidélité géographique.** Faut-il pouvoir reconnaître Albuquerque sur un
   plan, ou seulement en jouant ? Le premier coûte beaucoup plus cher.
3. **La carte à l'écran.** Plan papier qu'on déplie — cohérent avec 2008 — ou
   GPS ? Le papier est plus juste et plus lent.
4. **Les intérieurs.** Combien de bâtiments doivent s'ouvrir ? Chaque intérieur
   est une scène à construire ; en ouvrir cinq bien vaut mieux qu'en suggérer
   cinquante.
5. **La nuit par quartier.** L'état des vitres est cuit dans les textures. Cinq
   quartiers × deux moments = dix jeux de textures, ou un mécanisme. À poser
   quand le deuxième quartier arrivera, pas avant.
