# Fabriquer un asset par génération

Établi le 8 août 2026. Ce document décrit la chaîne qui va du besoin au fichier
dans `game/`. Il ne remplace pas [03-conventions-assets.md](03-conventions-assets.md),
qui reste la charte : ce qui suit dit **comment on produit**, la charte dit **ce
qui est acceptable**. Un asset généré passe par les mêmes budgets et les mêmes
pivots que les autres.

---

## Ce que la chaîne remplace, et ce qu'elle ne remplace pas

Deux outils, deux métiers :

| Outil | Ce qu'il produit | Ce qu'il ne produit pas |
|---|---|---|
| **Magnific** (`mcp.magnific.com`) | Images, textures, upscale, modèles 3D en `.glb` avec maps PBR, voix de synthèse | **Ni bruitage, ni musique.** Son seul audio est du texte-vers-parole |
| **ElevenLabs** | Bruitages (0,5 à 30 s), musique, voix | La 3D et les textures |

**Ni l'un ni l'autre ne sait rigger.** Tripo — le moteur 3D derrière Magnific —
possède un auto-rig, mais il n'est pas exposé. Un modèle généré arrive nu : pas
de squelette, pas de poids, pas d'animation. C'est la limite la plus dure de la
chaîne, et elle décide de tout le reste (voir « Les personnages » plus bas).

### Deux portes, et elles n'ouvrent pas sur la même chose

Magnific se pilote de deux façons, et **la différence n'est pas un détail** :

| | Clé d'API (REST) | MCP (`mcp.magnific.com`) |
|---|---|---|
| Authentification | En-tête `x-magnific-api-key` | OAuth, session interactive |
| Images, textures, upscale | **Oui** | Oui |
| **Modèles 3D** | **Non** | **Oui** |
| Utilisable depuis un script | Oui — `outils/magnific.ps1` | Non |

**Constaté le 08/08/2026, douze chemins sondés, tous en 404** : `models3d`,
`image-to-3d`, `text-to-3d`, `tripo-*`, `trellis-2`, `mesh`, `3d-generator`…
L'API REST ne publie que les images, l'upscale et la vidéo. Le `llms.txt` de la
documentation ne mentionne aucun endpoint 3D non plus.

**Conséquence pratique : les textures se produisent en ligne de commande, les
modèles 3D demandent que le MCP soit connecté.** Les deux voies partagent le
même solde de crédits.

Ce que l'API REST donne, mesuré : une image en **2048×2048** en 12 à 30
secondes. Le script la ramène à la taille du jeu et **relit le fichier écrit**
avant de le déclarer bon.

---

## Le manifeste, et pourquoi il existe

Une génération pilotée au fil de la conversation n'est pas reproductible. Trois
mois plus tard, personne ne sait quel prompt a produit quel fichier, ni pourquoi
celui-là a été gardé et les deux autres jetés. C'est le même problème que les
constantes de feeling cachées dans un script : le résultat peut être bon, la
méthode est fausse.

Donc **chaque asset généré est une ligne dans [`outils/assets-ia.json`](../outils/assets-ia.json)**,
et ce fichier est versionné :

```json
{
  "cle": "labo_bechers",
  "type": "3d",
  "moteur": "magnific/tripo-p1",
  "prompt": "chemistry lab beakers and flasks, scratched borosilicate glass...",
  "vues": ["face", "trois-quarts"],
  "faces_max": 3000,
  "texture": "standard",
  "vers": "game/assets/objets/bechers.glb",
  "hauteur": 0.28,
  "creation_id": "",
  "sha256": "",
  "licence": "Magnific — genere, usage libre"
}
```

`creation_id` et `sha256` se remplissent **après** la génération. C'est ce qui
rend la chaîne vérifiable : on retrouve la création dans l'historique Magnific,
et on prouve que le fichier du dépôt est bien celui qui a été téléchargé.

Le manifeste est la source. Les gros fichiers ne le sont pas — ils sont dans
`livraisons/ia/`, qui est **hors de git** (voir `.gitignore`, la raison y est
écrite). Un original perdu se régénère depuis sa ligne. Un manifeste perdu, non.

---

## La boucle, en cinq temps

**1. Lister avant de générer.** On écrit les lignes du manifeste pour le décor
en cours, et on regarde le total. On voit la facture avant de la payer — chaque
génération coûte des crédits, y compris les ratées.

**2. Générer.** `images_generate` pour les textures et les vues de référence,
`3d_generate` pour les modèles.

> **Une référence de style par décor, pas par objet.** `custom_references_create`
> (Soul) fabrique un style réutilisable. Sans lui, dix objets d'une même pièce
> sortent de dix univers différents et le décor ne tient pas ensemble — c'est le
> défaut le plus visible d'un lot généré, et le plus coûteux à rattraper.

**3. Télécharger dans `livraisons/ia/<decor>/`.** Jamais directement dans
`game/`. `livraisons/` est le sas, il l'a toujours été.

**4. Intégrer par `bg.ps1 integrer`.** La commande mesure, met à l'échelle, pose
au sol, oriente, **relit le fichier écrit** et refuse d'écrire si le résultat ne
correspond pas. Aucun modèle n'entre à la main — un import manuel est une
incohérence qui se découvre trois sessions plus tard, à l'écran.

**5. Prouver à l'image.** `.\bg.ps1 capture -Scenario <nom>`, comparé au même
scénario d'avant. Une image, jamais une conviction.

---

## Quel moteur pour quoi

| Besoin | Moteur | Pourquoi |
|---|---|---|
| Asset héros vu de près | **Tripo v3.1**, texture `detailed` | Le meilleur détail, jusqu'à 4 vues d'entrée |
| Décor, mobilier, objets tenus, figurants | **Tripo P1**, texture `standard` | Topologie propre et légère, faite pour le temps réel |
| Objet simple depuis une seule image | **Trellis 2** | Mono-vue, rapide |
| Textures, panneaux, affiches | `images_generate` puis `images_upscale` | C'est du plan, le budget de faces ne s'applique pas |

**Le budget de triangles se demande, il ne se corrige pas.** `3d_generate` prend
un `face limit` : on demande directement le bon nombre au lieu de décimer après
coup. Une décimation détruit les arêtes dures et arrondit les silhouettes —
exactement ce qu'on cherche à garder.

Ordres de grandeur en crédits : Tripo P1 ≈ 775, Tripo v3.1 de 580 à 1 160,
Trellis 2 de 610 à 850, une image de 50 à 400. **Compter une tentative et demie
par asset** : on ne réussit pas un modèle du premier coup.

---

## Les personnages : ce que la chaîne ne peut pas faire

`walt.glb`, `jesse.glb` et `tuco.glb` portent un squelette. Tout ce qui a été
construit dessus — la marche paramétrique, les poses de `poses.json`, la
respiration, le geste des lunettes, les ancrages d'objets en unités d'os — vit
sur ce rig et sur aucun autre.

**Un modèle généré n'a pas de rig. Ces trois-là ne se remplacent donc pas.**

Ce qu'on peut leur donner sans toucher au squelette : une **texture plus fine**
sur le maillage existant. L'image se génère, on substitue le matériau, le rig ne
bouge pas et les animations non plus.

Les personnages **sans** squelette — les hommes de Tuco, le garde, les passants,
`walter.glb` — se régénèrent en entier sans risque.

Et `outils/importer_perso.py` reste le seul chemin d'un modèle riggé. Il ne
touche volontairement ni au maillage ni aux textures : **on ne le modifie pas**.

---

## Les trois règles qui évitent des dégâts déjà payés

**Un asset généré ne doit jamais figurer dans la table d'un générateur.** Le
Jesse livré a déjà été écrasé par un `generer` lancé pour une autre raison
(piège 11). Avant chaque intégration, vérifier `gen_personnage.py`,
`gen_objets.py`, `gen_lieux.py` et `gen_decor.py`.

**La licence se note à la ligne.** Même discipline que pour les assets tiers.

**Les maps PBR ne se coupent plus par défaut.** `integrer` sans `-Plat` conserve
normale et rugosité, et c'est ce qu'on veut d'un modèle généré — c'est même la
moitié de ce qui le rend meilleur que du procédural. `-Plat` reste disponible
pour un asset qui doit se fondre dans le décor généré.

---

## Ce qui reste à Guillaume

Le tableau de répartition de [01-cadrage.md](01-cadrage.md) a été écrit quand la
seule façon d'obtenir un modèle était que quelqu'un le modélise. Ce n'est plus
vrai, et le tableau a été mis à jour.

Ce qui ne change pas : **le jugement de goût**. Un décor généré est cohérent,
rapide et sans âme tant que personne n'a dit lequel des trois essais est le bon.
C'est le travail qui reste, et c'est celui qui décide de ce à quoi le jeu
ressemble.
