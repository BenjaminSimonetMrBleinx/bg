# Brief son — premier prototype

Pour Guillaume. Liste exhaustive de ce dont le jeu a besoin, avec le format
attendu et l'intention derrière chaque son.

Le périmètre couvert : quelques blocs de ville, Walter jouable, conduite,
deux maisons avec intérieurs, PNJ avec dialogue, roue des outils.

---

## Le format, en une ligne

**Bruitages en WAV 48 kHz / 16 bits / mono. Musique et ambiances non
positionnées en WAV stéréo (converties en Ogg à l'import).**

| | Format livré | Pourquoi |
|---|---|---|
| Bruitages courts | **WAV 48 kHz 16 bits mono** | Décodage quasi gratuit, des centaines de voix simultanées |
| Ambiances longues, musique | **WAV 48 kHz 16 bits stéréo** | Converties en Ogg côté moteur |
| MP3 | **jamais** | Plus gros qu'un Ogg à qualité égale, et son padding casse les boucles |

### Trois règles qui coûtent cher si on les découvre tard

**1. Tout son positionné dans l'espace doit être MONO.** Moteur, portes, pas,
lampadaires, PNJ. Un fichier stéréo posé sur un `AudioStreamPlayer3D` ne se
spatialise pas — le moteur ne sait pas d'où il vient. Seules la musique et les
nappes d'ambiance globales sont en stéréo.

**2. Livre sec.** Pas de réverbération, pas de filtre de distance, pas de
compression d'ambiance. Godot applique la spatialisation, l'atténuation et la
réverbération lui-même ; un traitement déjà cuit dans le fichier se cumule au
sien et sonne faux dès qu'on bouge.

**3. Les boucles bouclent à l'échantillon près.** Un son marqué « boucle »
ci-dessous doit pouvoir tourner dix minutes sans qu'on entende le raccord.
C'est particulièrement vrai du moteur : c'est de loin le son le plus entendu du
jeu, et quelques millisecondes de blanc deviennent insupportables en deux
minutes.

---

## Si tu n'as que deux heures

Ces sept-là transforment le prototype à eux seuls. Le reste peut attendre.

1. `moteur_ralenti.wav` + `moteur_charge.wav` — sans eux, conduire est muet
2. `amb_rue_nuit.wav` — change la perception du jeu plus que n'importe quoi
3. `pas_asphalte_01` à `04` — quatre variantes suffisent
4. `portiere_ouverture.wav` + `portiere_fermeture.wav`
5. `lampadaire_bourdon.wav` — spatialisé, ridiculement rentable
6. `roue_tick.wav` + `roue_selection.wav`
7. `dialogue_lettre_01` à `03` — le bip de défilement du texte

---

## A · Véhicule

C'est 80 % du temps de jeu. Si un seul poste doit être bon, c'est celui-là.

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `moteur_demarrage.wav` | 1,5–2,5 s | mono | — | **P1** | Le démarreur qui peine une demi-seconde, puis ça prend |
| `moteur_ralenti.wav` | 3–4 s | mono | **oui** | **P1** | V6 fatigué, tourne un peu irrégulier |
| `moteur_charge.wav` | 3–4 s | mono | **oui** | **P1** | Même moteur en montée de régime, plus rauque |
| `moteur_haut.wav` | 3–4 s | mono | **oui** | P2 | Troisième couche, haut régime — pour un mélange plus fin |
| `moteur_arret.wav` | 1–2 s | mono | — | P2 | La coupure et le petit soubresaut |
| `roulement_asphalte.wav` | 3–4 s | mono | **oui** | P2 | Bruit de roulement, mélangé selon la vitesse |
| `pneus_crissement.wav` | 1–2 s | mono | — | P2 | Freinage appuyé ou virage serré |
| `choc_leger_01..03.wav` | 0,4–0,8 s | mono | — | P2 | Trois variantes : frotter un trottoir, toucher un mur |
| `choc_fort_01..02.wav` | 0,8–1,5 s | mono | — | P3 | Tôle qui encaisse vraiment |
| `portiere_ouverture.wav` | 0,6–1 s | mono | — | **P1** | Grincement, vieille voiture |
| `portiere_fermeture.wav` | 0,5–0,8 s | mono | — | **P1** | Claquement mat, pas une portière de berline allemande |
| `klaxon.wav` | 0,8 s | mono | — | P3 | Deux tons, fatigué |

**Sur le moteur, un point technique qui change tout.** Un seul fichier joué en
variant la hauteur sonne artificiel dès qu'on accélère. La méthode classique,
celle des jeux de conduite, consiste à superposer **deux ou trois boucles
enregistrées à des régimes différents** et à les fondre l'une dans l'autre
selon le régime. C'est pour ça qu'il y a `ralenti`, `charge` et `haut` dans la
liste. Deux suffisent pour le prototype ; trois font une vraie différence.

Enregistre-les **au même niveau et avec le même timbre de base**, sinon le
fondu s'entend.

---

## B · Personnage à pied

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `pas_asphalte_01..06.wav` | 0,25–0,4 s | mono | — | **P1** | Chaussée. Six variantes, sinon l'oreille repère la répétition |
| `pas_beton_01..06.wav` | 0,25–0,4 s | mono | — | P2 | Trottoir, plus sec et plus clair |
| `pas_interieur_01..04.wav` | 0,25–0,4 s | mono | — | P2 | Parquet ou moquette, feutré |
| `entrer_vehicule.wav` | 0,8 s | mono | — | P2 | Froissement, siège qui s'affaisse |
| `sortir_vehicule.wav` | 0,8 s | mono | — | P2 | L'inverse, plus bref |

Quatre variantes est le minimum vital, six est confortable. En dessous, on
entend la boucle au bout de dix secondes de marche.

---

## C · Maisons et intérieurs

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `porte_maison_ouverture.wav` | 1–1,5 s | mono | — | **P1** | Poignée, gonds, battant |
| `porte_maison_fermeture.wav` | 0,8 s | mono | — | **P1** | Claquement plus loquet |
| `amb_interieur_walter.wav` | 30–60 s | stéréo | **oui** | P2 | Réfrigérateur lointain, horloge, calme pesant. Une maison trop bien rangée |
| `amb_interieur_jesse.wav` | 30–60 s | stéréo | **oui** | P2 | Basse sourde d'une pièce voisine, ventilateur, désordre |
| `transition_interieur.wav` | 0,4 s | mono | — | P3 | Bref souffle au passage de la porte, masque le changement d'ambiance |

Les deux ambiances intérieures **caractérisent les personnages avant même
qu'ils parlent.** C'est le poste où ton apport sera le plus visible.

---

## D · Ambiances extérieures

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `amb_rue_nuit.wav` | 60 s | stéréo | **oui** | **P1** | Grillons, vent léger, un chien au loin, une circulation très lointaine. Rien de saillant |
| `amb_desert_vent.wav` | 60 s | stéréo | **oui** | P3 | Pour les abords de la ville, plus nu |
| `lampadaire_bourdon.wav` | 4–6 s | **mono** | **oui** | P2 | Bourdonnement de ballast. Placé sur chaque lampadaire, il fait exister la rue |

Le bourdonnement de lampadaire est **le meilleur rapport effort/résultat de
toute la liste.** Quelques secondes de son, posées sur trente-deux lampadaires
déjà positionnés, et la rue cesse d'être un décor.

---

## E · Roue des outils

Arme, sachet de meth, livre, chapeau.

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `roue_ouverture.wav` | 0,3 s | mono | — | **P1** | Le temps ralentit, quelque chose s'ouvre |
| `roue_tick.wav` | 0,05–0,1 s | mono | — | **P1** | Un cran entre deux segments. Très court, très sec |
| `roue_selection.wav` | 0,2 s | mono | — | **P1** | Validation, un peu plus grave que le tick |
| `roue_fermeture.wav` | 0,25 s | mono | — | P2 | Retour au jeu |
| `equiper_arme.wav` | 0,5 s | mono | — | P2 | Métal, culasse |
| `equiper_chapeau.wav` | 0,4 s | mono | — | P2 | Feutre, tissu. Le geste Heisenberg |
| `equiper_livre.wav` | 0,5 s | mono | — | P3 | Pages, couverture souple |
| `equiper_meth.wav` | 0,6 s | mono | — | P3 | Plastique froissé |

Le `roue_tick` est joué **très souvent**. S'il est une seule fois trop long ou
trop présent, il devient insupportable. Vise court et discret.

---

## F · Dialogue

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `dialogue_ouverture.wav` | 0,2 s | mono | — | **P1** | La boîte apparaît |
| `dialogue_lettre_01..03.wav` | 0,03–0,06 s | mono | — | **P1** | Bip de défilement, un par caractère. Trois variantes pour éviter la mitraillette |
| `dialogue_choix.wav` | 0,15 s | mono | — | P2 | Déplacement entre les réponses |
| `dialogue_valide.wav` | 0,2 s | mono | — | P2 | Réponse choisie |
| `dialogue_fermeture.wav` | 0,2 s | mono | — | P2 | La boîte disparaît |

Si tu veux pousser plus tard : **une variante de bip par personnage** (plus
grave pour Walter, plus haute pour Jesse) donne une identité vocale sans une
seule ligne enregistrée. C'est peu coûteux et très efficace.

---

## G · Musique

| Fichier | Durée | Canal | Boucle | Prio | Intention |
|---|---|---|---|---|---|
| `mus_rue_nuit.wav` | 90–150 s | stéréo | **oui** | P2 | Nappe lente, tendue, peu d'événements. Elle doit supporter d'être entendue longtemps |

**Composition originale obligatoire.** Rien de la série ne doit se retrouver
dans un fichier musical du dépôt — c'est le seul poste où l'exception au
disclaimer ne s'applique pas, parce que les catalogues musicaux sont détectés
automatiquement.

---

## Nommage, dépôt, livraison

```
assets/sons/
  vehicule/     moteur_*, portiere_*, pneus_*, choc_*, klaxon
  personnage/   pas_*, entrer_vehicule, sortir_vehicule
  maison/       porte_maison_*, amb_interieur_*, transition_*
  ambiance/     amb_rue_nuit, amb_desert_vent, lampadaire_bourdon
  interface/    roue_*, dialogue_*, equiper_*
  musique/      mus_*
```

- Minuscules, underscores, **pas d'accents ni d'espaces** dans les noms de fichiers.
- Variantes numérotées sur deux chiffres : `pas_asphalte_01.wav`.
- Les WAV passent par **Git LFS**, déjà configuré : tu commites normalement.
- Garde tes sessions de DAW **hors du dépôt** — seuls les rendus WAV y entrent.

Pour situer le poids : une boucle moteur de 3 s en 48 kHz / 16 bits / mono pèse
environ **280 Ko**. La liste complète tient largement sous 100 Mo. Il n'y a pas
de sujet.

---

## Récapitulatif

| Priorité | Nombre de fichiers | Signification |
|---|---|---|
| **P1** | ~20 | Le prototype est muet sans eux |
| P2 | ~25 | Fort impact, à faire dès que P1 est bouclé |
| P3 | ~10 | Confort, peut attendre la suite |

Environ **55 fichiers** en comptant les variantes. Les vingt P1 suffisent à ce
que le prototype sonne comme un jeu.
