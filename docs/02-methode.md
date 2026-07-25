# Méthode — coder ce jeu en vibe coding

Comment on fonctionne concrètement quand l'essentiel du code est généré. Ce document est
la partie la plus importante du dépôt : le moteur et la direction artistique sont décidés,
mais c'est la méthode qui déterminera si le projet existe encore dans trois mois.

---

## 0. Le problème central, à comprendre avant tout le reste

Vibe coder une application de gestion, c'est confortable : on décrit une fonctionnalité, elle
sort, un test dit si elle marche. **Vibe coder un jeu ne marche pas pareil, parce que la
question qui compte n'est pas testable.**

« Est-ce que conduire est agréable ? » ne s'écrit pas en assertion. Aucun test ne le dira,
et moi non plus — je n'ai pas de mains sur le clavier ni de sensation. **Vous êtes la suite
de tests du feeling.** Toute la méthode qui suit découle de cette seule contrainte.

Corollaire immédiat : la ressource rare du projet n'est pas ma capacité à écrire du code.
C'est **votre temps de cerveau disponible pour jouer et sentir**. Tout ce qui en consomme
sans produire de sensation est du gaspillage.

---

## 1. Les trois boucles

Il y a trois boucles de travail dans ce projet. Elles n'ont ni la même vitesse, ni le même
propriétaire, et les confondre est la première cause d'enlisement.

| | Boucle de **feeling** | Boucle de **système** | Boucle d'**asset** |
|---|---|---|---|
| Durée | 2 à 10 secondes | 2 à 15 minutes | 1 à 5 minutes |
| Qui | Benjamin, seul | Claude | Claude, sans humain |
| Quoi | Bouger un curseur dans l'éditeur et rejouer | Écrire ou modifier un système | Générer, rendre, regarder, corriger |
| Validation | « ça fait quelque chose » | ça tourne, ça ne casse rien | l'image est correcte |
| Coût | quasi nul | modéré | quasi nul |

**L'objectif de conception de tout le projet : maximiser le temps passé dans la boucle 1.**
C'est la seule des trois où le jeu devient bon. Les deux autres n'existent que pour la servir.

Si vous vous retrouvez à me demander « monte un peu l'accélération », c'est un échec de
méthode : ce réglage aurait dû être un curseur dans l'éditeur. D'où le point suivant.

---

## 2. Le fichier de réglages — la pièce maîtresse du dispositif

**Tous les nombres qui décident du feeling vivent dans une seule ressource Godot**, éditable
avec des curseurs dans l'éditeur, rechargée à chaud, versionnée en texte.

```gdscript
# game/systemes/reglages.gd
# Tous les nombres qui décident du feeling.
# Propriété de Benjamin — jamais modifié automatiquement après création.
class_name Reglages
extends Resource

@export_group("Véhicule")
@export_range(0.0, 60.0)    var acceleration          : float = 18.0
@export_range(0.0, 200.0)   var vitesse_max_kmh       : float = 110.0
@export_range(0.0, 1.0)     var adherence_lente       : float = 0.85
@export_range(0.0, 1.0)     var adherence_rapide      : float = 0.45
@export_range(0.0, 5.0)     var force_frein           : float = 2.2
@export_range(0.0, 2.0)     var inertie_carrosserie   : float = 0.6

@export_group("Caméra")
@export_range(0.0, 1.0)     var lissage_position      : float = 0.12
@export_range(0.0, 1.0)     var lissage_rotation      : float = 0.08
@export_range(40.0, 110.0)  var fov_arret             : float = 70.0
@export_range(40.0, 110.0)  var fov_pleine_vitesse    : float = 88.0
@export_range(0.0, 10.0)    var hauteur               : float = 2.4
@export_range(0.0, 20.0)    var recul                 : float = 6.5

@export_group("Rendu PS2")
@export_range(64, 640)      var largeur_rendu         : int   = 320
@export_range(0.0, 400.0)   var distance_brouillard   : float = 90.0
@export_range(0, 8)         var niveaux_couleur       : int   = 6
@export                     var snapping_actif        : bool  = true
@export_range(0.0, 8.0)     var intensite_snapping    : float = 2.0
```

Pourquoi c'est central : ça **découple l'itération de feeling de la génération de code**.
Benjamin peut passer une heure à régler la conduite sans écrire un seul prompt. Le jeu
progresse pendant que je ne fais rien — c'est exactement l'objectif.

**Règle : dès qu'un nombre influence une sensation, il monte dans ce fichier.** Une constante
de feeling en dur dans le code est un bug de méthode, même si le code fonctionne.

---

## 3. Règles anti-pourrissement

L'échec typique du vibe coding : au bout de trois semaines, 8 000 lignes que personne ne
comprend, où chaque correction en casse deux ailleurs. Les règles ci-dessous existent
uniquement contre ça.

- **Un système = une scène + un script.** Godot y pousse naturellement, on ne lutte pas contre.
- **Aucun fichier au-dessus de 300 lignes.** Au-delà, il se découpe. Pas de discussion.
- **Aucun état global** hors des autoloads déclarés, listés dans `ARCHITECTURE.md`.
- **Chaque script commence par une ligne** disant de quoi il est responsable, et de rien d'autre.
- **`docs/ARCHITECTURE.md` est tenu à jour à chaque système ajouté** : un paragraphe par système,
  ce qu'il possède, ce qu'il lit. C'est la carte, et c'est ce qui vous permet de rentrer dans le
  code trois semaines après sans moi.
- **Code et identifiants en anglais, commentaires et documentation en français.** Convention
  fixée une fois, jamais renégociée : le mélange est ce qui rend un dépôt illisible.

---

## 4. Le protocole de conversation

C'est la section la plus rentable du document. La qualité de ce qui sort dépend directement
de la façon dont c'est demandé, et la différence est spectaculaire.

| Ne fonctionne pas | Fonctionne |
|---|---|
| « Améliore la voiture » | « La voiture patine comme sur de la glace. Je veux qu'elle accroche davantage en dessous de 30 km/h, sans changer le comportement à haute vitesse. » |
| « Fais la ville » | « Génère 4 blocs en damier, immeubles de 2 à 5 étages, trottoirs de 2 m, une seule texture par façade. » |
| « Ça marche pas » | « Au démarrage : erreur ligne 34 de `vehicule.gd`, `null instance`. Voilà la stack. » |
| « Mets du brouillard » | « Le fond est trop net, on voit la limite de la ville. Je veux que ça disparaisse vers 90 m, comme GTA III. » |
| « C'est moche » | *[capture d'écran]* + « les façades sont trop lisses, il manque des variations » |

Quatre principes derrière ces exemples :

1. **Décrire une sensation ou un symptôme, pas une solution.** Vous savez ce que vous ressentez ;
   c'est mon travail de trouver quel nombre le produit. Si vous me donnez déjà la solution, vous
   faites mon travail et je ne peux plus vous contredire quand elle est mauvaise.
2. **Un changement de feeling à la fois.** Deux réglages modifiés ensemble : on ne sait plus
   lequel a produit l'effet. C'est vrai en science comme en game design.
3. **Une capture d'écran vaut mieux qu'un paragraphe** pour tout ce qui est visuel. Je peux
   lire les images — c'est le canal le plus fiable pour un problème d'apparence.
4. **« Explique-moi en cinq lignes ce que tu viens de faire. »** À demander systématiquement sur
   tout système de jeu. Sans cette habitude, le dépôt devient une boîte noire et vous perdez la
   capacité de le reprendre seuls. C'est le prix d'entrée du vibe coding, et il n'est pas
   négociable.

---

## 5. Des verticales, jamais des couches

Ne jamais demander « construis le système de physique du véhicule ». Toujours :

```
la voiture avance                → on y joue → commit
la voiture tourne                → on y joue → commit
la voiture s'arrête              → on y joue → commit
la voiture percute un mur        → on y joue → commit
la caméra suit                   → on y joue → commit
```

Chaque étape se termine par un état **jouable et commité**. Le bénéfice n'est pas la propreté :
c'est que vous sentez le jeu se construire, et que vous détectez au plus tôt qu'une direction
est mauvaise. Une couche complète livrée d'un bloc, c'est trois heures avant de découvrir que
la sensation est ratée.

---

## 6. Le filet de sécurité git

Le vibe coding produit des états cassés en permanence. Ce n'est pas un problème — c'est le mode
de fonctionnement normal. Ce qui rend cette imprudence sans danger, c'est le filet :

- **Commiter chaque état qui tourne**, même moche, même incomplet.
- **Taguer chaque build jouable.** On peut toujours relancer une version qui marchait.
- **`git reset --hard` est un geste ordinaire**, pas un aveu d'échec. C'est même le principal
  avantage de la méthode : on peut tenter n'importe quoi.
- **Une branche par expérimentation risquée.** Si ça ne donne rien, on supprime la branche et
  il ne s'est rien passé.

Sans ce filet, la peur de casser fait ralentir — et un vibe coding prudent perd tout son intérêt.

---

## 7. Ce que Claude n'a pas le droit de faire

Des limites explicites, parce qu'un assistant serviable dépasse volontiers le périmètre demandé.

- **Ne pas toucher `reglages.tres`** après sa création. Il appartient à Benjamin.
- **Ne pas toucher `livraisons/`.** Ce sont les fichiers de Guillaume.
- **Ne pas inventer une décision de design.** Si une question de game design se pose en cours de
  route, elle remonte — elle ne se tranche pas silencieusement dans du code.
- **Ne pas refactorer sans demande.** Un refactor non sollicité casse la carte mentale que vous
  aviez du code, et c'est votre compréhension qui est la ressource fragile ici.
- **Ne pas ajouter de fonctionnalité non demandée**, même évidente, même utile.

---

## 8. Les agents parallèles — quand, et surtout quand pas

**Règle simple : on parallélise ce qui produit des fichiers, on sérialise ce qui produit du
comportement.**

| Parallélisable | À garder en série |
|---|---|
| Génération de la ville | Contrôleur de véhicule |
| Génération de textures | Caméra |
| Props urbains | Passage véhicule ↔ à pied |
| Shader PS2 | Tout ce qui touche à la scène principale |
| Documentation | Tout ce qui touche au feeling |

Les systèmes de gameplay se marchent dessus : ils touchent les mêmes scènes et le même état.
Trois agents en parallèle sur la conduite produisent trois conflits, pas trois fois plus de
travail. Les générateurs d'assets, eux, sont indépendants par nature — chacun écrit ses propres
fichiers et ne lit rien de partagé.

---

## 9. Structure d'une session

**Au début, une phrase :** « à la fin de cette session, qu'est-ce qui doit être différent quand
on joue ? » Une seule. Si on n'arrive pas à l'écrire, la session n'est pas prête à démarrer.

**Pendant :** des verticales, un commit par verticale qui tourne.

**À la fin :** un build qui se lance, et une entrée dans le journal.

---

## 10. Le journal

`docs/JOURNAL.md`, une entrée par session, quatre lignes maximum :

```markdown
## 2026-08-01 — la voiture roule

Voulu    : conduire dans un bloc, caméra qui suit.
Obtenu   : ça roule, la caméra est trop molle en virage.
Surprise : le brouillard change tout — sans lui la ville a l'air fausse.
Prochain : régler la caméra avant d'ajouter quoi que ce soit.
```

Ça prend deux minutes et ça vaut trois choses : ça empêche de refaire les mêmes erreurs, ça rend
la progression visible quand on a l'impression de stagner, et ça permet de reprendre le projet
après trois semaines d'interruption sans tout relire.

---

## 11. Les pièges spécifiques à ce projet

- **Construire la ville avant que conduire soit agréable.** Le piège numéro un du monde ouvert :
  on se retrouve avec une grande ville dans laquelle se déplacer est pénible. La conduite se
  valide sur *un* bloc.
- **Ajouter du contenu avant que le noyau soit bon.** Une deuxième mission ne rendra jamais la
  première amusante.
- **Accepter du code qu'on ne comprend pas.** Ça passe pendant deux semaines, puis plus jamais.
- **Refactorer pour la beauté.** Le code d'un prototype a le droit d'être laid. Il n'a pas le
  droit d'être illisible — ce n'est pas la même chose.
- **Me laisser décider du design.** Je proposerai toujours quelque chose de raisonnable et
  générique. Le jeu, c'est ce que vous mettez de non générique dedans.
- **Confondre « ça tourne » et « c'est bien ».** Je peux garantir le premier. Jamais le second.

---

## 12. La métrique unique

Une seule chose à surveiller :

> **Combien de minutes se sont écoulées entre l'idée et le moment où on l'a sentie dans le jeu ?**

En dessous de dix minutes, la méthode fonctionne et le projet avancera. Au-dessus, ce n'est pas
le jeu qu'il faut corriger — c'est la boucle. Réglages exposés, temps de génération, temps de
lancement, taille des verticales : c'est là qu'il faut aller chercher.
