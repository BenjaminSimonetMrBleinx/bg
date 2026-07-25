# Conventions d'assets

Fiche de référence pour Guillaume. Elle répond aussi à la question F8 : plutôt qu'une
spec par asset, une contrainte technique unique, et tu t'organises librement dedans.

---

## Audio

### Quel format, et pourquoi

Godot accepte WAV, Ogg Vorbis et MP3. Il n'y a pas de « meilleur format » dans l'absolu —
le bon choix dépend de la durée et du nombre de sons joués en même temps.

| Usage | Format | Compression à l'import |
|---|---|---|
| **Bruitages courts** — moteur, portes, pas, arme, impacts | **WAV** | **QOA** (défaut Godot) |
| **Musique et ambiances longues** — radio, vent, nappe | **Ogg Vorbis** | — |
| MP3 | **jamais** | — |

**Pourquoi WAV pour les bruitages.** Le décodage est quasi gratuit : Godot encaisse des
centaines de voix simultanées sans broncher. Le seul défaut est la taille disque, et la
compression QOA la réduit nettement pour une perte de qualité bien moins audible que
l'IMA-ADPCM, à un coût CPU qui reste très inférieur au MP3. Dans un jeu de conduite où le
moteur, les pneus, la ville et les pas tournent en permanence, c'est le bon compromis.

**Pourquoi Ogg pour la musique.** Le meilleur rapport taille/qualité disponible. Il coûte
plus de CPU à décoder, mais sur une ou deux pistes simultanées c'est sans importance.

**Pourquoi jamais de MP3.** À qualité égale il est nettement plus gros qu'un Ogg, donc il
perd sur le seul terrain où il pourrait gagner. Et son encodage ajoute du silence en tête
et en queue de fichier, ce qui rend une boucle sans couture peu fiable — rédhibitoire pour
un son de moteur.

### Trois règles qui coûtent cher si on les découvre tard

1. **Tout son positionné en 3D doit être MONO.** Moteur, portes, pas, PNJ : un fichier
   stéréo sur un `AudioStreamPlayer3D` ne se spatialise pas correctement. Seules la musique
   et les nappes d'ambiance non positionnées sont en stéréo.
2. **Les masters arrivent toujours en WAV 48 kHz 16 bits non compressé.** Godot compresse à
   l'import ; on garde la source intacte dans le dépôt. Ne jamais livrer un MP3 comme
   master : on ne peut pas remonter la pente.
3. **Le son du moteur boucle sans couture.** C'est de loin le son le plus entendu du jeu :
   quelques millisecondes de blanc à chaque boucle deviennent insupportables au bout de
   deux minutes. WAV, points de boucle posés à l'échantillon près.

### Taille

Les WAV passent par Git LFS, déjà configuré. Pour situer : une boucle moteur de 3 s en
48 kHz / 16 bits / mono pèse environ 280 Ko. Il n'y a pas de sujet.

---

## 3D

### Budgets de triangles — références PS2 réelles

| Élément | Triangles |
|---|---|
| Personnage jouable | 500 – 1 500 |
| Personnage secondaire | 300 – 800 |
| Véhicule | 800 – 2 000 |
| Immeuble | 50 – 300 |
| Accessoire, mobilier | 20 – 200 |

Ce ne sont pas des plafonds de performance — une machine moderne encaisserait cent fois
plus. Ce sont des **contraintes esthétiques** : au-delà, ça ne ressemble plus à un jeu PS2.

### Textures

- **128 × 128** par défaut, **256 × 256** pour un asset héros qu'on regarde de près,
  **64 × 64** pour les petits accessoires.
- Toujours en puissance de deux.
- Le filtrage bilinéaire est actif : la texture sera **floue à l'écran**, c'est voulu. Ne
  pas compenser en montant la résolution, ça casserait le rendu.
- Une seule texture par objet quand c'est possible — un atlas plutôt que six matériaux.

### Tessellation : pas de contrainte, contrairement à ce qui était écrit ici

Correction d'une affirmation initialement fausse.

Un grand quadrilatère éclairé **par sommet** ne reçoit la lumière qu'à ses quatre coins,
donc apparaît noir. C'est ce qu'on a observé en montant le rendu, et on en avait conclu
qu'il fallait tesseller toutes les grandes surfaces.

**Sauf que le projet utilise l'ombrage par pixel.** À 512 × 384 la différence avec le
par-sommet est invisible, et le par-pixel est plus prévisible — c'est donc lui qu'on garde.
Avec lui, un sol de quatre sommets s'éclaire correctement. La vraie cause du sol noir était
ailleurs : **aucun lampadaire ne couvrait le premier plan.**

Il n'y a donc **aucune obligation de tesseller**. Modélise au plus simple. Un découpage
grossier reste utile sur les très grandes surfaces pour d'autres raisons — culling, futur
passage en éclairage par sommet — mais ce n'est pas un prérequis d'éclairage.

**Ce qu'il faut retenir à la place :** une zone sans source lumineuse est noire, point.
L'éclairage se pense en couverture, pas en géométrie.

### Échelle, orientation, pivots

- **1 unité = 1 mètre.** Blender est déjà en mètres ; appliquer l'échelle avant export
  (`Ctrl+A` → Scale), sinon Godot hérite d'un facteur parasite.
- **Export en glTF (`.glb`).** L'exportateur gère la conversion Z-up de Blender vers le
  Y-up de Godot ; ne rien compenser à la main.
- **Pivots** : à la base et au centre pour un personnage ou un immeuble, au centre de
  l'essieu pour une roue, au centre de gravité pour une caisse de véhicule. Un pivot mal
  placé fait tourner une roue de travers et ça se voit immédiatement.
- **Faces** : normales vers l'extérieur, pas de faces internes inutiles.

### Nommage et emplacement

```
livraisons/     ce qu on DEPOSE, pas ce que le jeu lit
  sons/         WAV mono pour le 3D, stereo pour la musique
  voix/         prises de dialogue, avant decoupage
  modeles/      .obj, .fbx, .blend livres a la main
  LICENCES.md   origine et licence de tout asset externe
```

Un fichier posé dans `livraisons/sons/` ou `livraisons/voix/` est **rangé tout seul** dans
`game/assets/` au prochain `.\go.ps1`. Personne n'a à retenir où Godot les lit.

Côté jeu, les sons sont classés par mécanisme, pas par auteur :

```
game/assets/sons/
  vehicule/     moteur, portieres, klaxon, chocs, pneus
  pas/          selon la surface
  maison/       portes et ambiances interieures
  interface/    roue des outils, objets equipes
  telephone/    sonnerie
  ambiance/     nappes exterieures
```

Fichiers en minuscules avec des underscores : `imm_commercial_a.blend`,
`walter_tete.png`, `moteur_boucle.wav`. **Un fichier `.blend` par asset** — jamais un gros
fichier de scène partagé, qui garantirait un conflit dès qu'on travaille en même temps.

---

## Ce qui n'entre jamais dans le dépôt

Les médias issus de la série — image, son, vidéo, police, logo — vivent dans
`assets-ref/`, ignoré par git. Voir [DISCLAIMER.md](../DISCLAIMER.md). La raison est autant
technique que juridique : un binaire commité reste dans l'historique même après suppression.
