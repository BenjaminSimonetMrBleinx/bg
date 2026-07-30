---
name: nouvelle-mission
description: Créer une nouvelle mission de BG — pose toutes les questions nécessaires, puis écrit game/donnees/missionN.json et la liste de ce qui reste à fabriquer. À utiliser dès qu'on dit « nouvelle mission », « ajouter une mission », « mission 2 », ou qu'on décrit un déroulé de mission à implémenter.
---

# Nouvelle mission

Une mission de BG est **une liste d'étapes dans un fichier JSON**. `mission.gd`
ne connaît ni Jesse, ni le désert, ni la botte secrète : il avance dans la
liste, et c'est tout. Écrire une mission, c'est donc surtout **répondre à des
questions** — le code ne s'ouvre que pour ce qui manque vraiment.

Ce skill existe parce que la moitié de ces questions ne se posent pas
naturellement, et qu'une seule oubliée coûte une session : une étape validée
par un événement que personne n'émet ne bloque pas au chargement, elle bloque
le joueur au milieu de la mission.

## 1. Poser le formulaire

**Poser les questions par blocs, pas toutes d'un coup**, et donner une valeur
par défaut chaque fois que c'est possible. Un bloc dont toutes les réponses
sont évidentes se résume en une phrase (« je prends X, Y, Z — dis-moi si ça ne
va pas ») au lieu de se demander.

### Bloc A — ce qu'elle est

1. **Numéro et titre.** Le titre s'affiche dans le téléphone. Court.
2. **Ce qu'elle installe.** Une phrase. Les premières missions ont le droit
   d'être explicites et enseignent **un** principe chacune — voir le tableau
   des premières missions dans `docs/12-direction.md`. Si la réponse est « rien
   de nouveau », c'est peut-être une mission de trop.
3. **Où elle commence** : dans un intérieur, dans la rue, au volant ?
4. **À quelle heure.** `depart.heure` (0 à 24) impose l'heure au lancement ;
   sans la clé, le monde reste à l'heure où il a été chargé. L'horloge avance
   toute seule ensuite — une heure de jeu par minute réelle — donc une mission
   longue change de moment, et c'est voulu.
5. **Argent et objets de départ** (`argent_min`, `argent_max`, `objets`).

### Bloc B — le déroulé

Pour **chaque étape**, dans l'ordre :

- `cle` : identifiant interne, cité par les points d'interaction ;
- `objectif` : ce que lit le joueur dans son téléphone. **Deux lignes
  maximum** — c'est un écran de 1999 ;
- `valide_par` : **l'événement, un seul**, qui fait passer à la suivante ;
- `tuto` : bandeau facultatif à l'arrivée sur l'étape.

**Les événements qui existent aujourd'hui** — vérifier dans
`game/systemes/` avant d'en promettre un autre, et sinon dire ce qu'il faudra
écrire pour l'émettre :

| Événement | Émis quand |
|---|---|
| `dialogue:<cle>` | une conversation s'achève |
| `volant` | on monte dans un véhicule |
| `zone:<nom>` | on arrive dans une zone (voir le champ `zone` d'un `Passage`) |
| `objet:<cle>` | on ramasse quelque chose |
| `action:<cle>` | on utilise un point d'interaction |
| `argent_cache` | on a planqué assez d'argent |

La dernière étape n'a pas de `valide_par` : elle ne se termine jamais seule.

### Bloc C — ce que ça coûte

**La question la plus importante, et celle qu'on oublie.** Règle 2 de la
direction : un choix sans coût n'est pas un choix. Demander :

- qu'est-ce que le joueur **perd** en la faisant — du temps, de l'argent, une
  relation, de la discrétion ?
- qu'est-ce qui se passe s'il **traîne** ?
- y a-t-il plusieurs méthodes (parler, payer, intimider, contourner), et
  qu'est-ce que chacune coûte ?

Si les trois réponses sont « rien », le dire : la mission est une course de
relais, pas une mission.

### Bloc D — ce qu'il faut fabriquer

Faire la liste **avant** d'écrire quoi que ce soit, en distinguant ce qui
existe de ce qui n'existe pas :

- **Dialogues** : chaque `dialogue:<cle>` a besoin d'une entrée dans
  `game/donnees/dialogues.json`, et les voix se génèrent ensuite
  (`.\bg.ps1 voix`).
- **Lieux** : un décor nouveau est soit généré (`outils/gen_lieux.py`), soit
  livré par Guillaume. Les intérieurs et les lieux de mission se posent **loin
  du centre-ville dans le même repère** — voir l'en-tête de
  `game/scenes/mission1.tscn` pour les coordonnées déjà prises.
- **Zones** : un `Passage` avec son champ `zone` renseigné, et son
  `etape_minimale` s'il ne doit pas s'ouvrir tout de suite.
- **Points d'interaction** : un `point.gd` par `action:<cle>`.
- **Personnages** : modèle, textures, et l'entrée de `voix.json`.

### Bloc E — comment on la regarde

1. **Quelle capture la montre ?** Si on ne sait pas dire quelle image montrerait
   la mission, elle n'est pas prête à être codée. Ajouter la situation dans
   `game/donnees/scenarios.json`.
2. **Quel test la garde ?** `game/verifs/test_mission.gd` parcourt le déroulé
   sans y jouer : il vérifie que chaque étape est atteignable et qu'aucune
   n'attend un événement que personne n'émet. L'étendre plutôt qu'en écrire un
   deuxième.

## 2. Écrire

1. `game/donnees/missionN.json`, sur le modèle de `mission1.json` — y compris
   le bloc `_lisez_moi` : ces fichiers se relisent à six mois.
2. Brancher la mission : le champ `fichier` du nœud `Mission`.
3. Ce qui manque encore, en clair, avec ce que ça coûte. Ne rien inventer pour
   combler : une étape validée par un événement inexistant est un blocage
   silencieux, exactement le genre de panne que ce projet paie deux fois.

## 3. Finir

- Lancer **la suite concernée seulement** : `.\bg.ps1 test -Suite mission`.
- Prendre la capture prévue au bloc E et **la regarder**.
- Bump et note dans `NOTES-DE-VERSION.md` : ce qu'on peut essayer, et comment
  y accéder.
