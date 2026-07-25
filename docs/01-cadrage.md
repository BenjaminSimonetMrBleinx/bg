# Cadrage

État au 25 juillet 2026. Ce document est révisé à chaque décision prise.

---

## 1. Ce qui est verrouillé

| Sujet | Décision |
|---|---|
| Genre | Monde ouvert type GTA — missions principales + quêtes annexes |
| Direction artistique | 3D low-poly PS2 : vertex snapping, affine texture mapping, textures 64 px, brouillard épais, rendu 320×240 upscalé |
| Univers | Breaking Bad, Albuquerque, Nouveau-Mexique |
| Moteur | **Godot 4.7** — choix définitif |
| Modélisation | Blender 5.2, pipeline procédural en Python |
| Juridique | Fan game non commercial, aucun asset officiel |
| Dépôt | Public, dédié, séparé du monorepo professionnel |
| Rôles | Benjamin : stack, systèmes, intégration · Guillaume : son, 3D, script |

## 2. Le premier jalon

> « On conduit une voiture dans quatre blocs d'Albuquerque, de nuit, avec le rendu PS2,
> et on peut descendre du véhicule. »

Hors périmètre, explicitement : missions, quêtes annexes, IA, trafic, police, cuisine,
personnage animé, camping-car, intérieurs. Ces éléments **sont** le jeu — ils ne sont pas
le premier jalon.

**La nuit n'est pas un choix esthétique gratuit.** C'est le plus gros levier de production
disponible : elle divise par trois le nombre de détails à modéliser, rend le brouillard
crédible au lieu de suspect, transforme des façades plates en silhouettes, et laisse
quelques lampadaires porter toute l'ambiance.

## 3. Pourquoi Godot, et pourquoi définitivement

Sur le monde ouvert seul, Unity gardait de vrais avantages : streaming mature, physique de
véhicule documentée, Asset Store fourni. Ils comptent au mois six ; ils ne comptent pas au
premier jalon, et trois faits les annulent.

| | Godot 4.7 | Unity 6 |
|---|---|---|
| Temps avant le premier pixel | 120 Mo, aucun compte, ouvre en 5 s | ~15 Go, compte, licence, import lent |
| Scènes générables par script | Oui — `.tscn` et `.tres` sont du texte | Non en pratique — YAML à références GUID |
| Look PS2 disponible | Packs de shaders matures | À assembler en Shader Graph |
| Merge git à deux | Scènes en texte, mergeables comme du code | YAML + `.meta`, conflits réguliers |
| Pipeline Blender | `.blend` natif, réimport auto | FBX/glTF, export manuel |

**« On prototype en Godot puis on bascule sur Unity » est un piège.** Une migration de
moteur est une réécriture : les assets passent, le code, les scènes, les shaders et tout le
réglage de physique ne passent pas.

Référence utile : *Road to Vostok*, survival open-world développé en solo, a fait exactement
ce trajet **dans l'autre sens** — Unity → Godot fin 2023, **615 heures rien que pour le
portage**. En 2026 sa version Godot dépasse l'originale : cartes plus grandes, végétation
plus dense, meilleur éclairage. Early Access Steam en avril 2026.

Le seul argument sérieux restant pour Unity serait le portage console — Godot n'a pas
d'export first-party PS5/Xbox. Mais un fan game Breaking Bad non commercial ne sortira
jamais sur une boutique console. L'argument s'annule pour ce projet.

**Le vrai plafond du projet n'est pas le moteur : c'est la capacité de deux personnes à
produire du contenu.** C'est là que meurent les mondes ouverts.

## 4. La contrainte d'échelle

GTA III : environ 23 personnes, deux ans, à temps plein. Ici : deux personnes, le soir.
Il y a un facteur d'environ 50 à absorber quelque part, volontairement, plutôt qu'à
découvrir au troisième mois.

Ce qui rend l'affaire jouable, c'est justement l'esthétique choisie. GTA III, Vice City et
San Andreas *sont* des mondes ouverts PS2 : ils tiennent grâce à des bâtiments modulaires
répétés, un terrain plat, et un brouillard qui mange la distance d'affichage pour masquer
l'absence de LOD. Ce ne sont pas des concessions esthétiques, ce sont des économies de
production déguisées en style.

Et Albuquerque est le monde ouvert le moins cher qui existe : une ville en damier posée
dans un désert vide. Rues droites, blocs répétables, et plus rien à modéliser dès qu'on
sort de la ville.

**Stratégie : le monde ouvert est l'architecture dès le jour 1, pas le contenu.** On
construit le chargement par zones, le système de missions, la conduite, la montée de
pression — conçus pour grandir. Le terrain de jeu, lui, commence à quatre blocs.

## 5. Répartition du travail

| Domaine | Claude | Benjamin | Guillaume |
|---|---|---|---|
| Ville procédurale — blocs, routes, immeubles | Produit | Relit | — |
| Textures 64 px | Produit | — | Retouche |
| Shader PS2 | Produit | Relit | Valide le look |
| Contrôleur de véhicule, physique | Produit | Règle le feeling | — |
| Caméra, HUD, scènes `.tscn` | Produit | Relit | — |
| Dépôt, CI, build, documentation | Produit | Authentifie GitHub | — |
| Véhicule héros — l'Aztek | Ébauche | — | **Produit** |
| Personnages, rig, animations | Non | — | **Produit** |
| Son, musique, ambiances | Non | — | **Produit** |
| Direction artistique — l'arbitrage | Propose | Arbitre | **Décide** |
| Architecture, choix techniques | Propose | **Décide** | — |
| Playtest — « est-ce que c'est fun ? » | Non | **Décide** | **Décide** |

Logique du découpage : la masse technique et répétitive — celle qui se génère, se vérifie
et se corrige en boucle — est automatisée. Guillaume prend ce qui demande un œil et une
oreille, c'est-à-dire l'âme du jeu. Benjamin arbitre et intègre. Personne ne fait la queue
derrière quelqu'un d'autre : c'est la seule contrainte réelle d'un projet à deux.

### Pipeline procédural

```bash
blender --background --python outils/gen_ville.py -- --blocs 4 --seed 505
   # génère géométrie, UV, matériaux · exporte assets/ville/ville.glb

blender --background --python outils/rendu_check.py -- --cam survol
   # sort .tmp/check.png en 640×360, relu et corrigé en boucle

godot --headless --path game --script outils/verif_scene.gd
   # vérifie que la scène charge et qu'aucun script ne casse
```

Ce qui **ne peut pas** être automatisé, et relève entièrement de Guillaume : tout le son,
les personnages, le rig et l'animation, les assets « héros » qu'on regarde de près, et le
jugement de goût.

## 6. Outillage — état du poste de Benjamin

| Outil | État |
|---|---|
| Godot 4.7.1 | Installé (portable, sans alias PATH) |
| Blender 5.2 | Installé |
| Python 3.12 | Installé |
| Git LFS 3.7.1 | Installé |
| GitHub CLI 2.96 | Installé, **authentification à faire** (`gh auth login`) |
| Identité git | À configurer |

## 7. Ce qui reste ouvert

Tout est dans [`00-questions.md`](00-questions.md). Les blocs A, B et C bloquent le
démarrage ; D et E peuvent attendre.
