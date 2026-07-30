# BG — Compte rendu de session · Missions & système de ressources

**Date : 31 juillet 2026 · Fait suite à « La direction du jeu » (Le socle, 28 juillet 2026)**

> **Pour Claude Code** : ce document est le compte rendu d'une session de design. Il contient (1) les décisions actées, (2) le système de ressources, (3) la grammaire de mission, (4) les 15 fiches missions histoire des 5 paliers, (5) les missions annexes, (6) les points ouverts. Emplacement suggéré dans le dépôt : le contenu des sections 2 à 6 va dans un nouveau `docs/15-missions.md` ; la section « Système de ressources » peut aussi être intégrée à `docs/12-direction.md` si c'est plus cohérent avec l'existant ; les micro-scènes de la section 6 vont dans `docs/14-boite-a-idees.md`. À toi de juger la meilleure découpe.

---

## 1. Décisions actées pendant la session

1. **Le temps est repoussé.** Toute la question de l'horloge (temps continu, blocs, journées) est mise de côté. Seule décision conservée : temps continu, parfois **forcé au début de certaines missions** (le jeu place Walt à une heure donnée). Aucune mécanique ne doit dépendre du temps pour l'instant.
2. **Trois ressources : argent, réputation, vie perso.** Détail complet en section 2.
3. **Trois missions histoire par palier** : une *ouverture*, une *friction*, une *finale*. La finale est la plus longue/importante et fait basculer vers le palier suivant. Les autres scènes cultes deviennent des **missions annexes**.
4. **Les missions doivent être variées et à étapes multiples.** Certaines mêlent drogue et vie perso ; d'autres, courtes, restent sur une seule catégorie.
5. **Règle « menace » : le joueur ne perd jamais.** Le script peut faire perdre le *personnage* (Walt encaisse, quelqu'un meurt, une situation se dégrade), jamais le *joueur* (pas de game over, pas de ressource retirée arbitrairement, pas de frustration). Le sentiment de piège vient du récit, pas de la difficulté. Le joueur progresse continuellement jusqu'à la fin.
6. **Le jeu doit transpirer.** La première salve de missions manquait de drogue, de tension, de morts, de courses contre la montre. Corrigé : chaque palier contient au moins une séquence à chrono ou à forte tension, en respectant la règle 5 (le stress est réel, la punition est économique ou narrative, jamais un game over).
7. **Chronologie de la série non respectée.** La série est traitée comme un **stock de scènes**, pas comme une frise. Les paliers du socle (désinsectisation au palier 4, labo de Gus au palier 5) inversent l'ordre de la série et on l'assume. Projet de fan, non commercial.
8. **Affichage des points.** À ce stade du développement, les points de vie perso et de réputation sont **affichés ou consultables** à l'écran. C'est une exception assumée à la règle 1 du socle, du même type que l'argent, à documenter ainsi : *« pour l'instant, tout se compte ; à terme, seul l'argent se comptera »*. La règle 1 reste l'objectif final.

---

## 2. Le système de ressources

### Les trois valeurs

| Ressource | Nature | Se gagne | Se perd | Se dépense |
|---|---|---|---|---|
| **Argent** | Monnaie | Ventes, missions, salaire | Achats, traitements | **Oui — la seule** |
| **Réputation** | Score (« Heisenberg ») | Cuisiner soi-même, vendre, tenir tête, le chapeau | Rare (déléguer, reculer) | Non |
| **Vie perso** | Score (« Walter White ») | Présence familiale, honnêteté relative, **traitement du cancer** | Rare (absences graves, mensonges découverts) | Non |

- **Seul l'argent se dépense, et uniquement dans les missions** (matériel, améliorations, traitement, mises de départ).
- **Réputation et vie perso sont des scores** : ils se gagnent et se perdent (rarement) dans les missions et les activités, mais ne se consomment jamais.
- **Le cancer fait partie de la vie perso.** Le soigner rapporte des points de vie perso : l'hôpital est le seul endroit où l'on convertit de l'argent en vie perso. Le traitement doit être la **source de vie perso la plus efficace du jeu** — ainsi, à la rémission, le joueur perd sa meilleure boucle de gain, et le constat du socle (« il n'a plus de raison de continuer, et il continue ») devient une expérience mécanique vécue, pas seulement un moment d'histoire.

### Les portes

Les missions histoire s'ouvrent par **seuils**, jamais par dépense : « réputation ≥ X » débloque sans rien consommer. La ressource-porte varie d'une mission à l'autre pour forcer le joueur à jouer les trois boucles sans le lui dire. Aucun blocage définitif possible : tout progrès est acquis, au pire on farme.

### Les trois formes de choix dans les missions

1. **Le bon choix** — une option clairement meilleure, qui récompense la lecture de la situation (ex. : voir le morceau d'assiette manquant).
2. **Les bons choix multiples** — plusieurs options valables qui paient dans des monnaies différentes (argent vs vie perso). Le joueur décide implicitement ce qu'il veut gagner ; rien ne l'annonce, il le découvre au gain.
3. **Le choix à perte** — quoi qu'on choisisse, une jauge baisse. **Rare, réservé aux finales.** C'est sa rareté qui le fait marquer.

### Les boucles hors missions (monde ouvert)

| Boucle | Rapporte | Garde-fou anti-farm |
|---|---|---|
| Cuisiner + vendre | Argent + réputation | Les composants coûtent ; les spots de vente s'usent ; incident chimique possible (voir annexe « La fournée qui tourne mal ») |
| Repas, devoirs, sorties avec Junior | Vie perso | Rendement décroissant dans la même journée |
| Hôpital / traitement | Vie perso (le meilleur taux du jeu) | Coûte de l'argent, de plus en plus cher par palier |
| Le lavage auto (avant rachat) | Argent, peu | Volontairement lent : c'est le taux horaire de la vie honnête |
| Petits contrats / livraisons pour Jesse | Argent | Moins rentable que cuisiner soi-même (règle du socle) |
| Blanchiment hebdomadaire (après rachat du lavage, palier 3) | Convertit argent sale → propre | Prend du temps, plafonné par semaine |

### Règle d'équilibrage

Comme rien ne se dépense (hors argent), **éviter l'inflation** : les seuils des portes montent plus vite que les gains faciles. Les gains de réputation d'un palier sont calibrés pour ouvrir le palier suivant *si* on joue les missions du palier ; le farm comble l'écart mais ne permet jamais de sauter un palier.

---

## 3. La grammaire de mission

### Les sept types

| Type | Pression produite |
|---|---|
| **Cuisine** | Temps consommé, couleur qui monte |
| **Vente / livraison** | Déplacement + négociation ; le seul endroit où on choisit son prix |
| **Approvisionnement** | Contrainte matérielle, discrétion, zéro gain |
| **Blanchiment** | Convertit l'argent, toujours ennuyeux, toujours long |
| **Famille** | Ne rapporte rien d'autre que de la vie perso |
| **Médical** | De l'argent contre de la vie perso |
| **Menace** | Les antagonistes en scène. Le joueur gagne, le personnage paie |

Le ratio évolue avec les paliers : acte I dominé par cuisine/vente/appro, acte II par blanchiment/famille, acte III par menace. Les missions de vente disparaissent progressivement — c'est le piège, pas un appauvrissement.

### Le format de fiche

Chaque fiche comporte : **Type** (+ marqueurs ⏱ course contre la montre / ☠ mort au centre) · **Porte** (seuil requis) · **Ce qu'elle installe** (une seule idée) · **Déroulé** (étapes) · **Le choix** (et ce qu'il coûte des deux côtés) · **Paie** (argent / réputation / vie perso par issue) · **Échec** (jamais un game over ; une conséquence, souvent différée) · **Ce qu'on voit** (la traduction visuelle/sonore, jamais un chiffre).

### La philosophie de l'échec

Rater le chrono coûte de l'argent ou de la marchandise. Être détecté déclenche une cinématique de rattrapage (Walt ment, paie, s'enfuit) qui coûte plus cher que la réussite. Certains échecs génèrent une **mission de nettoyage** plus tard — le monde tient les comptes sans les afficher. Les missions histoire sont re-tentables, mais la version ratée laisse une trace dans le monde.

### Le dosage

Sur trois missions histoire par palier : **une tendue, une mixte, une calme**. Les annexes cultes légères (pizza, mouche, minéraux) sont les soupapes entre deux étranglements — comme la série alterne ses épisodes.

---

## 4. Les quinze missions histoire

### PALIER 1 — Camping-car · la rue · brun

*Courbe du palier : la 1 apprend à fuir, la 2 apprend à payer les conséquences, la 3 apprend ce que ce jeu pense de la violence. Les paies suivent la logique du socle : beaucoup de bruit, peu d'argent, et une finale à zéro dollar qui ouvre pourtant tout le palier 2.*

---

#### Mission 1 · DEUX CORPS, UN CAMPING-CAR *(ouverture)* ⏱

**Type** : mixte (menace + production), tendue.
**Porte** : aucune — c'est l'entrée du jeu.

**Ce qu'elle installe** : le jeu commence au pire moment, pas au début. Cuisiner est dangereux, la police existe, et on apprend à conduire en panique avant d'apprendre à cuisiner.

**Déroulé** :
1. *In medias res* — le camping-car dans le fossé, masque à gaz, deux corps inertes à l'arrière, sirènes au loin. Le pantalon s'envole (détail scripté, récupérable plus tard en monde ouvert).
2. Cacher ce qui traîne dehors (sacs, verrerie) — trois objets à ramasser, les sirènes montent en volume et servent de timer sonore.
3. Redémarrer le camping-car (mini-interaction moteur) et sortir de la zone par la piste.
4. Cinématique : les sirènes étaient des pompiers. Fondu — *« trois semaines plus tôt »* — flashback jouable court : la première cuisine avec Jesse, qui sert de tutoriel chimie au calme.

**Le choix** : aucun choix majeur — l'ouverture apprend les commandes. Micro-choix dans le flashback : suivre la méthode de Jesse ou celle de Walt (la méthode Walt donne un cristal moins brun ; personne ne le commente — premier indice de la règle couleur).

**Paie** : argent ~0 · réputation +faible (la rue apprend qu'un nouveau produit circule) · vie perso 0.

**Échec** : si les sirènes arrivent avant la sortie de zone, cinématique de rattrapage — Walt planque tout dans le fossé et joue le randonneur en détresse. On repart, mais la verrerie est perdue : la première cuisine en monde ouvert coûtera son remplacement. Pas de game over, une facture.

**Ce qu'on voit** : le cristal brun-terne dans le sac. La chemise verte trempée. Le pantalon qui reste au sol quand la caméra s'éloigne.

---

#### Mission 2 · LA BAIGNOIRE *(friction)* ☠

**Type** : mixte (production + famille), tendue puis noire-comique.
**Porte** : réputation ≥ seuil bas — la première fournée doit avoir été vendue, ce qui force un passage par le monde ouvert entre les missions 1 et 2.

**Ce qu'elle installe** : les conséquences ne s'évaporent pas, il faut les dissoudre. La chimie punit ceux qui ne l'écoutent pas. Premier vrai choix payant du jeu.

**Déroulé** :
1. Le corps d'Emilio est toujours dans le camping-car, garé chez Jesse. Ça ne peut plus attendre.
2. Approvisionnement : acheter l'acide fluorhydrique. Deux magasins possibles — le proche où le vendeur pose des questions, ou le lointain qui rallonge la mission mais où on reste anonyme.
3. Le choix central, en dialogue avec Jesse : **le bac en polyéthylène** que Walt exige (à charger, porter — long et pénible) **ou la baignoire** de l'étage (immédiat, facile).
4. Bac : séquence de manutention laborieuse, volontairement ingrate, la dissolution se passe bien. — Baignoire : tout est simple… puis le plafond cède en cinématique, et il faut nettoyer *ce qui tombe* — séquence longue, viscérale, avec un timer social : Skyler a appelé, elle passe « puisque Walt est chez Jesse ».
5. Fin commune : la maison de Jesse redevient présentable, ou à peu près.

**Le choix** : la forme 1 à l'état pur. Le bac est objectivement meilleur mais coûte de l'effort immédiat ; la baignoire est tentante et coûte le double ensuite. Le joueur a le droit de se tromper, et l'effondrement est assez spectaculaire pour être sa propre récompense — beaucoup choisiront la baignoire *exprès* en seconde partie.

**Paie** : argent −(coût de l'acide) · réputation +faible · vie perso : + si le nettoyage est fini avant l'arrivée de Skyler, − si elle voit quoi que ce soit d'anormal. Première fois que la jauge vie perso peut descendre, et la mission le fait comprendre sans texte.

**Échec** : pas d'état d'échec dur — la baignoire *est* l'échec, intégré au script. Si Skyler arrive trop tôt : cinématique de mensonge maladroit, vie perso −, et **le mensonge choisi est enregistré** (il resservira contre Walt au palier 3).

**Ce qu'on voit** : le trou dans le plafond, jamais réparé de tout le jeu — chaque visite chez Jesse le montre. La règle 1 en décor.

---

#### Mission 3 · LE MORCEAU D'ASSIETTE *(FINALE du palier)* ☠

**Type** : dialogue + menace, lente puis brutale.
**Porte** : réputation ≥ seuil **ET** vie perso ≥ seuil bas. Double porte voulue : pour affronter ça, il faut que Walt ait encore quelque chose à protéger — sinon la scène ne veut rien dire.

**Ce qu'elle installe** : tuer, dans ce jeu, est long, laid et ne rapporte rien directement. La mission qui donne son genre au jeu entier, et qui ferme le palier : après elle, plus de retour à la vie d'avant.

**Déroulé** :
1. Krazy-8 au sous-sol, attaché au poteau par l'antivol de vélo. Mission **fragmentée** : on y revient entre deux activités du monde ouvert, en plusieurs visites scriptées.
2. Chaque visite : choisir le sandwich, couper les croûtes ou non, parler. Le dialogue creuse — sa famille, le magasin de meubles, le berceau que son père a peut-être vendu aux White. Chaque visite le rend plus humain, et c'est le but.
3. Entre deux visites, en haut : Walt tergiverse, la liste « le tuer / le libérer » écrite puis déchirée (cinématique courte).
4. Visite finale : Walt descend avec la clé, décidé à le libérer. En ramassant les débris de l'assiette cassée plus tôt, **séquence d'observation libre** : le joueur manipule les morceaux et doit remarquer qu'il en manque un, taillé en pointe.
5. S'il le remarque : Walt remonte, s'effondre, redescend. La strangulation en QTE **prolongé et pénible** — trop long, inconfortable, jusqu'au « I'm sorry ». — S'il ne le remarque pas : il ouvre l'antivol, Krazy-8 frappe avec le tesson, lutte scriptée, même issue. Walt s'en sort — le joueur ne perd jamais — mais blessé, et sans avoir *choisi* : il a réagi.

**Le choix** : le vrai choix n'est pas tuer ou pas (le script l'impose), c'est **voir ou pas**. Remarquer le tesson transforme un accident en décision, et c'est toute la différence du personnage. Récompense de lecture pure (forme 1).

**Paie** : **argent 0** — volontairement, la seule finale du jeu qui ne rapporte rien. Réputation +forte (Krazy-8 disparu, la rue tire ses conclusions seule). Vie perso − dans les deux cas, −− si Walt est blessé (Skyler voit les marques, le mensonge coûte plus cher).

**Échec** : aucun état d'échec possible. Les deux branches avancent. La punition de l'inattention est narrative et physique, jamais mécanique.

**Ce qu'on voit** : l'assiette recollée sur le plan de travail de Jesse, avec son trou. L'antivol jeté, retrouvable dans la benne. Et au tableau des scores, ce zéro dollar — le seul du jeu.

---

### PALIER 2 — Camping-car amélioré · dealers · ambré

*Courbe du palier : la 4 fait naître Heisenberg, la 5 montre le prix du monde où l'argent est bon, la 6 le referme dans le sang. Le paiement de la finale dépasse une année de traitement — c'est ici que le prétexte médical est dépassé, et personne ne le commente (socle).*

---

#### Mission 4 · LE MERCURE FULMINANT *(ouverture)* ⏱

**Type** : mixte (vente + menace), tendue.
**Porte** : réputation ≥ seuil (l'écho de la disparition de Krazy-8).

**Ce qu'elle installe** : Heisenberg — le nom, le chapeau, et la négociation où l'on ne contrôle pas tout.

**Déroulé** :
1. Cinématique : Jesse est rentré tabassé de chez Tuco, le produit confisqué, rien payé.
2. Cuisine spéciale : préparer « le cristal » — une fournée qui coûte des composants et **ne se vend pas**. Le joueur ne comprend pas encore pourquoi, et le jeu ne dit rien.
3. Préparation : le chapeau, en cinématique muette devant le miroir. Trajet vers le QG.
4. Le bureau de Tuco : dialogue tendu, la négociation (50 000 $ pour le produit volé + le tabassage de Jesse, ou moins si le joueur plie). Puis **le lancer** — une seule entrée, une fenêtre courte, la vitre soufflée.
5. Sortie avec l'argent, et le sac de cristaux vendus dans la foulée.

**Le choix** : dans le dialogue — exiger le prix fort (réputation ++, tension maximale) ou sécuriser un prix moindre (argent quand même, réputation +). Micro-arbitrage d'aplomb, pas de mauvaise réponse.

**Paie** : argent ++ · réputation ++ (première fois qu'un PNJ prononce « Heisenberg ») · vie perso 0.

**Échec** : lancer raté (fenêtre manquée) → Tuco rit, prend le produit, paie la moitié. Pas de mort, pas de game over — une humiliation et un manque à gagner. Re-tentable, mais la version ratée reste dans le monde (les hommes de Tuco s'en souviennent en dialogue).

**Ce qu'on voit** : la vitre soufflée du bureau, jamais remplacée. Le chapeau, désormais dans l'inventaire — l'arbitrage Heisenberg (mieux payé / plus vite reconnu) est actif pour tout le reste du jeu.

---

#### Mission 5 · NO-DOZE *(friction)* ☠

**Type** : menace pure, courte, calme puis glaçante.
**Porte** : aucune (suit la mission 4).

**Ce qu'elle installe** : le monde où l'argent est bon. Le joueur gagne tout ; le personnage comprend où il a mis les pieds.

**Déroulé** :
1. Livraison régulière au point de rendez-vous de Tuco. Tout se passe bien : le produit est bon, le paiement est complet, l'ambiance est presque détendue.
2. Un des hommes de Tuco, No-Doze, dit un mot de trop. Tuco le tue à mains nues, devant Walt et Jesse, **pour rien**. Le joueur tient le sac d'argent pendant toute la scène — aucune commande disponible.
3. Tuco fait comme si de rien : « Vendredi prochain, même heure. » Fin de mission.
4. L'écran de gains s'affiche **normalement**, comme après n'importe quelle livraison. C'est le contraste qui glace.

**Le choix** : un seul, optionnel, pendant la scène — se taire (rien) ou dire un mot (réputation +, mais la scène se prolonge et devient plus dure à regarder). Aucune option n'arrête quoi que ce soit.

**Paie** : argent + · réputation + · vie perso 0.

**Échec** : aucun état d'échec.

**Ce qu'on voit** : Jesse qui vomit près de la voiture au retour. L'écran de score, impeccable, par-dessus.

---

#### Mission 6 · LA CABANE DE TUCO *(FINALE du palier)* ⏱☠

**Type** : menace + survie, très tendue — la plus grosse mission de l'acte I.
**Porte** : réputation ≥ seuil.

**Ce qu'elle installe** : on ne choisit pas toujours ses clients. Ferme le palier : Tuco mort, le circuit des dealers s'effondre, il faut un réseau structuré (palier 3).

**Déroulé** :
1. Cinématique : Tuco, devenu paranoïaque, enlève Walt et Jesse. La cabane dans le désert, Tio Salamanca dans son fauteuil, la sonnette.
2. **La ricine en douce** : mini-jeu de discrétion — préparer et glisser la poudre dans l'assiette pendant que Tuco fait les cent pas et que Tio observe. Fenêtres d'action courtes, patterns lisibles.
3. **Le repas** : la tentative échoue — Tio sonne, Tuco jette l'assiette. La cloche entre dans le jeu ici, et elle reviendra (finale du jeu).
4. **La bagarre et la fuite** : lutte scriptée, puis fuite à pied dans les rochers. Derrière, sans qu'on la voie, la fusillade Hank/Tuco — le joueur l'*entend* en courant.
5. Retour en ville en cinématique : la disparition de deux jours, la maison silencieuse.

**Le choix** : pendant la fuite — **retourner chercher le sac d'argent du deal** (chrono serré, tension maximale) ou **fuir directement** (l'argent est perdu). Deux issues valables : l'une paie en argent, l'autre en sécurité de jeu (fuite plus simple). Forme 2.

**Paie** : argent + ou 0 selon le choix · réputation ++ (la rue apprend que Heisenberg a survécu à Tuco) · **vie perso −−** (deux jours de disparition, Skyler). Choix à perte assumé — c'est une finale, la forme 3 y est autorisée.

**Échec** : détection pendant la préparation de la ricine → Tuco se méfie, la tentative saute, la fuite est plus longue et plus dure — mais même issue. Pas de game over.

**Ce qu'on voit** : la cloche de Tio, cadrée une seconde de trop. Le fauteuil vide de Tuco à son QG, visitable ensuite en monde ouvert.

---

### PALIER 3 — Atelier · revendeurs · clair

*Courbe du palier : la 7 fait de l'argent un problème, la 8 montre que la violence de Walt frappe les siens, la 9 referme le piège — et pour la première fois, le joueur le voit se refermer au lieu de le subir. C'est le palier de l'acte II : blanchiment et famille dominent.*

---

#### Mission 7 · SAVEWALTERWHITE.COM *(ouverture)*

**Type** : mixte (famille + blanchiment), calme.
**Porte** : vie perso ≥ seuil — il faut que Junior parle encore à son père pour que la mission existe.
**Prérequis narratif** : l'annexe « Saul dans le désert » doit avoir été jouée (elle recrute Saul).

**Ce qu'elle installe** : l'argent existe et ne peut pas être dépensé — le vrai problème de l'acte II. Un seul objet contient les deux vies de Walt.

**Déroulé** :
1. **La soirée avec Junior** : monter le site ensemble. Mini-interactions sincères (choisir la photo, le texte, le bouton de don). Mission famille sans ironie — le jeu la joue premier degré.
2. **Chez Saul** : il explique le tour. Dialogue.
3. **Le réglage du flux** : mini-jeu simple — doser les « dons » quotidiens injectés depuis l'argent sale pour que la courbe reste crédible.
4. **Le soir, à la maison** : regarder les dons arriver sur l'écran du PC familial, Junior fier, Skyler émue. Le joueur sait d'où vient chaque dollar.

**Le choix** : le dosage. Flux gros = argent blanchi vite, mais **une trace est enregistrée** (elle ressortira à l'acte III). Flux lent = propre, mais long. Implicite, jamais commenté.

**Paie** : argent (blanchi) + · vie perso + · réputation 0.

**Échec** : aucun échec dur. Le sur-dosage n'échoue pas la mission — il inscrit une trace pour plus tard.

**Ce qu'on voit** : le compteur de dons sur l'écran familial. Le pire de la mission, c'est que c'est un beau moment.

---

#### Mission 8 · UNE MINUTE *(friction)* ⏱☠

**Type** : menace, très tendue — on joue Hank, seule fois du jeu.
**Porte** : réputation ≥ seuil — et c'est méchant à dessein : c'est la montée de Heisenberg qui a mis les Cousins en route. La porte *est* la cause.

**Ce qu'elle installe** : la violence que Walt génère frappe les siens. Le joueur triomphe, le personnage paie — la règle « menace » à la lettre.

**Déroulé** :
1. Cinématique : l'appel anonyme. « Deux hommes viennent vous tuer. Vous avez une minute. »
2. **60 secondes affichées à l'écran** — la seule fois du jeu où un chrono est littéralement le titre. Hank désarmé dans sa voiture, le parking, les Cousins dans les rétros.
3. Gameplay : gérer le regard, la marche arrière, le moment de l'impact contre le premier Cousin, ramper, la balle creuse qui tombe au sol, la saisir, le tir final.
4. Cinématique : l'hôpital. Toute la famille dans la salle d'attente — Walt compris.

**Le choix** : aucun choix moral. Exécution pure. C'est reposant à dessein après la 7, et c'est la mission la plus « jeu d'action » du titre.

**Paie** : argent 0 · réputation 0 · **vie perso +** — le drame resserre la famille autour de l'hôpital. C'est pervers, et très fidèle à la série.

**Échec** : Hank ne peut pas mourir. Si le joueur est trop lent, la cinématique rattrape (la balle creuse tombe plus tôt, le script compense). La mission est inéchouable, le stress est réel quand même.

**Ce qu'on voit** : Hank en fauteuil roulant ensuite, dans le monde ouvert. Les minéraux qui s'accumulent sur son lit, visite après visite.

---

#### Mission 9 · LE RACHAT DU LAVAGE *(FINALE du palier)*

**Type** : dialogue + économie, calme — la seule finale sans une goutte de sang.
**Porte** : **argent ≥ gros seuil** — la seule finale à porte d'argent du jeu, et la plus grosse dépense du jeu à ce stade.

**Ce qu'elle installe** : le blanchiment sérieux, et le piège *choisi* : c'est le premier palier où le joueur voit la porte se fermer et la ferme lui-même.

**Déroulé** :
1. **L'évaluation, avec Skyler** : dialogue — première vraie coopération du couple depuis le début du jeu.
2. **Faire baisser le prix** : le coup de l'inspecteur environnemental — mini-enquête pour relever les non-conformités du lavage et faire chuter Bogdan.
3. **La négociation finale** : Bogdan, les sourcils, l'humiliation rendue.
4. **La signature, et le premier dollar** : Bogdan exige de laisser son cadre « premier dollar gagné ». Walt le décroche après son départ et achète un soda avec. Cinématique, sans un mot.

**Le choix** : payer plein prix (rapide, propre) ou monter le coup de l'inspecteur (moins cher, mais **une trace de plus** et du temps). Deux monnaies, forme 2.

**Paie** : argent −−− · vie perso + (Skyler complice : paradoxalement, la relation se stabilise — elle préfère savoir) · réputation 0.

**Échec** : aucun.

**Ce qu'on voit** : l'enseigne qui change. Et une nouvelle boucle de monde ouvert : **le blanchiment hebdomadaire** — convertir l'argent sale en argent propre, plafonné, un peu ennuyeux, exactement comme le socle l'exige.

---

### PALIER 4 — Maison désinsectisée · distributeurs · translucide

*Courbe du palier : la 10 installe la commande et le délai, la 11 fait vivre la règle centrale (cuisiner soi-même > déléguer) sans un mot d'explication, la 12 est le sommet du jeu — et son épilogue retire à Walt sa dernière justification. Fin de l'acte II.*

---

#### Mission 10 · LA TENTE *(ouverture)* ⏱

**Type** : production + logistique, tendue.
**Porte** : réputation ≥ seuil — les distributeurs ne parlent qu'à une marque établie.

**Ce qu'elle installe** : la production sur commande. Le délai remplace le danger.

**Déroulé** :
1. Briefing : une maison sous tente de désinsectisation, **trois jours** avant le retour des occupants. Objectif de volume.
2. Monter le labo mobile (séquence d'installation, checklist diégétique).
3. La cuisine longue — avec objectif de volume et incident chimique possible (même mécanique que le monde ouvert).
4. **Le coup de fil** : le bureau de désinsectisation prévient — la famille rentre plus tôt. Replanifier en direct.
5. Démontage : ne rien laisser. Séquence inverse de l'installation, sous pression.

**Le choix** : bâcler le démontage pour tenir le nouveau délai (**risque de trace**) ou livrer en retard (pénalité d'argent, réputation −). Forme 2, tendue.

**Paie** : argent ++ · réputation +.

**Échec** : trace laissée → une **mission de nettoyage** est générée plus tard dans le palier. Si le joueur n'a rien laissé, elle n'existe pas — et c'est bien.

**Ce qu'on voit** : la famille qui rentre, l'enfant qui court dans le salon impeccable. Il ne trouve rien. Ou presque — un plan d'une seconde sur un détail, jamais commenté.

---

#### Mission 11 · DÉLÉGUER *(friction)*

**Type** : production + famille, calme — la respiration du palier.
**Porte** : aucune.

**Ce qu'elle installe** : la règle centrale du socle — cuisiner soi-même rapporte plus, en argent et en réputation — vécue au lieu d'expliquée.

**Déroulé** :
1. Un employé (profil Todd) propose de prendre une cuisine. Walt accepte.
2. **La journée libre, en famille** : scriptée et généreuse — l'anniversaire de Junior, la voiture offerte. La plus grosse paie de vie perso du jeu, d'un coup.
3. **La livraison** : le client ouvre la caisse. Le cristal est **ambré**, pas translucide. Il paie moins. Sans un mot. Le jeu n'explique rien.
4. Fin de mission ouverte : aucun objectif affiché ensuite. Le joueur décide seul, en monde ouvert, de reprendre la main ou de continuer à déléguer.

**Le choix** : il est *après* la mission, et il est permanent : déléguer (argent moindre, vie perso disponible) ou reprendre (l'inverse). Le jeu ne tranche jamais.

**Paie** : vie perso ++ · argent + (visiblement moindre qu'une cuisine à soi) · **réputation −faible** — l'une des rares pertes de réputation du jeu : la marque baisse. Assumé, car rare.

**Échec** : aucun.

**Ce qu'on voit** : deux cristaux côte à côte sur la table de l'atelier — celui de Walt, celui de l'employé. Cinq textures suffisent à raconter toute la montée (socle) ; ici, deux suffisent à poser tout le dilemme.

---

#### Mission 12 · LE TRAIN *(FINALE du palier — fin de l'acte II)* ⏱☠

**Type** : braquage, très tendue — le sommet mécanique du jeu.
**Porte** : réputation ≥ seuil haut. Le matériel (cuves, pompes, camion) s'achète **dans** la mission.

**Ce qu'elle installe** : le sommet de la maîtrise — et le prix payé par quelqu'un d'autre.

**Déroulé** :
1. **Le repérage** : mission de surveillance au pont — noter le point mort de la couverture radio, chronométrer l'arrêt.
2. **Le calcul** : dialogue technique où le joueur choisit les volumes — combien de méthylamine pomper, combien d'eau substituer pour que le poids colle. Vraie petite arithmétique, à l'ancienne.
3. **Le jour J** : le camion « en panne » sur la voie. **Double chrono** : la jauge de volume pompé d'un côté, la patience du conducteur retenue par le complice de l'autre — deux jauges qui ne se parlent pas, le joueur arbitre en continu. Puis le bon samaritain qui s'arrête pour pousser le camion : le temps se compresse d'un coup.
4. **L'extraction** : sous le wagon, au redémarrage du train.
5. **Cinématique** : le désert, le silence, le triomphe — et le garçon à moto. Le coup de feu est hors champ. L'écran de gains s'affiche **sur le plan du vélo**.

**Le choix** : pendant le double chrono — pomper plus (argent, réputation) ou partir tôt (sécurité). Continu, pas binaire.

**Paie** : **argent +++ (la plus grosse paie du jeu)** · réputation ++ · vie perso 0.

**Échec** : chrono raté → le conducteur redémarre tôt, une partie du volume seulement est sauvée — et la cinématique change : pas de témoin, pas de garçon. **Réussir totalement coûte le plus cher moralement.** À écrire noir sur blanc dans le doc : c'est voulu, c'est le jeu.

**Ce qu'on voit** : la tarentule dans le bocal, posée sur le tableau de bord au retour.

**Épilogue scripté du palier — LA RÉMISSION** : consultation à l'hôpital, bonne nouvelle, la facture disparaît — et avec elle la meilleure boucle de vie perso du jeu. Puis **le jeu ne donne aucun objectif**. La journée continue, le monde est ouvert, et le joueur décide seul d'aller cuisiner — et il ira. C'est la plus longue plage de silence du jeu. Le lendemain matin, le téléphone sonne : c'est Gus. → Palier 5.

---

### PALIER 5 — Labo de Gus · un acheteur · bleue

*Courbe du palier : la 13 installe l'impuissance, la 14 fait payer le prix le plus lourd du jeu, la 15 referme tout — la cloche du palier 2, les traces accumulées depuis le palier 1, et les jauges elles-mêmes. Le choix a changé de nature : on ne décide plus quoi vendre ni à qui, on décide qui protéger, quoi cacher, à qui mentir.*

---

#### Mission 13 · LE CUTTER *(ouverture)* ☠

**Type** : menace, mise en scène pure.
**Porte** : aucune — l'appel de Gus *est* la porte.

**Ce qu'elle installe** : le monde de Gus — précision, silence, salaire, impuissance. Le troisième trou du socle (« le dernier acte enlève tout et n'ajoute rien ») se comble ici : ce que l'acte III retire en liberté commerciale, il le rend en menace.

**Déroulé** :
1. **La descente au superlab** : émerveillement, tutoriel du nouvel outil de cuisine — le meilleur équipement du jeu, la couleur bleue à portée de main.
2. Quelques jours de routine en séquence compressée : cuisiner, être payé. Le salaire tombe **tout seul**, régulièrement — nouvelle boucle, la plus confortable du jeu, et la plus inquiétante.
3. **La journée où ça bascule** : le joueur exécute des tâches de nettoyage simples — paillasses, sols, verrerie — pendant que Victor cuisine *la formule de Walt* de l'autre côté du labo.
4. Gus entre. Se change en silence. Le cutter. **Dans le dos du joueur**, en reflets dans l'inox des cuves. Aucune commande disponible, et le nettoyage continue jusqu'au bout.

**Le choix** : aucun. La seule mission du jeu sans le moindre choix, et c'est le propos. À ne faire qu'une fois — jamais deux missions sur ce registre.

**Paie** : argent ++ (le salaire de Gus, énorme et régulier) · réputation 0 · vie perso 0. **Au labo, la jauge de réputation s'affiche grisée** : elle ne sert plus à rien ici, et l'interface le dit sans un mot.

**Échec** : aucun.

**Ce qu'on voit** : le seau, la serpillière, le reflet. La chemise de Gus, pliée au millimètre sur la chaise.

---

#### Mission 14 · LE TÉLÉPHONE *(friction)* ☠

**Type** : menace, deux personnages jouables.
**Porte** : aucune — scriptée dans l'arc du palier.

**Ce qu'elle installe** : la décision la plus lourde du jeu, prise en une phrase, exécutée par quelqu'un d'autre.

**Déroulé** :
1. La nuit où tout bascule : Walt retenu au labo par Victor, le canon de la situation bien compris. **Un seul appel possible.**
2. **L'appel** : le joueur choisit la phrase — comment le dire à Jesse, avec quels mots. C'est le seul gameplay de Walt dans la mission.
3. **Bascule sur Jesse** : le trajet en voiture, la pluie, la porte de Gale. Le QTE unique — un seul bouton, une seule fois. L'écran coupe au son.
4. Retour au labo en cinématique : Victor reçoit l'appel, la situation se fige. Fin.

**Le choix** : la formulation de l'appel. Elle ne change pas l'issue — Gale meurt — mais elle change **l'état de Jesse** pour la suite : associé tenu ou associé brisé. Conformément au socle, Jesse n'est pas une jauge : sa fiabilité est un état du monde, lisible dans son comportement, sa maison, sa musique.

**Paie** : **rien. Argent 0, réputation 0, vie perso 0.** Deuxième mission à zéro du jeu — la première était le premier meurtre (mission 3), celle-ci est le dernier ordre. Les deux zéros encadrent le jeu, et le tableau des scores raconte ça tout seul.

**Échec** : aucun.

**Ce qu'on voit** : l'appartement de Gale, visitable plus tard en monde ouvert — le carnet, la cafetière artisanale, la cassette de karaoké.

---

#### Mission 15 · LA CLOCHE *(FINALE DU JEU)* ⏱☠

**Type** : tout — la plus longue mission du jeu.
**Porte** : réputation ≥ maximum **ET** vie perso ≥ seuil. La double porte finale est un choix de design : il faut qu'il reste à Walt quelque chose à protéger pour que la fin morde. Si le joueur a négligé la vie perso, le jeu le renvoie d'abord vers sa famille — et c'est déjà la fin qui commence.

**Ce qu'elle installe** : la fermeture de toutes les boucles — mécaniques et narratives.

**Déroulé** :
1. **Le vide sanitaire** : l'argent qui manque, Skyler qui avoue, et le rire sous le plancher. Séquence scriptée, la plus basse du jeu — le joueur est allongé dans la poussière avec Walt.
2. **Convaincre Hector** : la mécanique de la cloche du palier 2 revient, inversée — cette fois c'est Walt qui pose les **questions fermées**, et Hector qui répond d'un coup de sonnette. Le joueur doit reformuler ses phrases en questions à oui/non : le verbe de dialogue installé à la cabane de Tuco, rejoué trois paliers plus tard.
3. **Le fauteuil** : mini-jeu d'artisanat — écho direct de la batterie du camping-car. Les mains de Walt, le mécanisme, la sonnette.
4. **La fausse piste** : Hector à la DEA, face à Hank — cinématique où **toutes les traces accumulées depuis le palier 1 ressortent** : le mensonge de la baignoire, le flux de dons trop gros, le démontage bâclé de la tente. Chaque trace enregistrée pendant la partie donne une réplique à Hank. Un joueur propre entend une scène courte ; un joueur négligent entend son propre dossier.
5. **L'attente** : la voiture, garée loin. Le parking. Le silence.
6. **La dernière entrée du jeu** : un seul appui. La cloche. **Contre-champ** : on ne voit pas l'explosion — on voit Walt qui l'entend.

**Le choix** : il n'y en a plus, et c'est le point d'arrivée de tout le système : au palier 1 on choisissait tout, au palier 5 on ne choisit plus que d'appuyer. L'épilogue, lui, varie selon la **vie perso finale** : haute — quelqu'un décroche le téléphone ; basse — personne. Deux fins d'épilogue, même mission.

**Paie** : **l'écran de fin n'affiche aucun score.** Pendant l'acte final, les jauges disparaissent de l'interface une à une — la réputation d'abord (grisée depuis le labo), l'argent ensuite (le vide sanitaire l'a vidé de sens), la vie perso en dernier. Le jeu finit sans chiffres : la règle 1 du socle, accomplie à la toute fin, comme une destination et pas comme une contrainte. *(Proposition forte — à valider en équipe.)*

**Échec** : aucun.

**Ce qu'on voit** : le générique sur le parking vide. Et si le joueur a ramassé le pantalon au palier 1, il est plié sur la banquette arrière.

---

## 5. Les missions annexes par palier

### Palier 1
- **LA FOURNÉE QUI TOURNE MAL** ⏱ *(monde ouvert, répétable)* — chaque cuisine libre a une faible chance d'incident : emballement, jauge de température, quelques secondes pour couper et ventiler. Réussi : fournée sauvée. Raté : composants perdus, rien de plus. C'est le garde-fou qui empêche le farm d'être mécanique.
- **LA BMW DE KEN** *(très courte)* — la station-service, la raclette, le terminal, le feu. Aucune porte, aucune paie. Elle existe pour montrer que Walt change avant que le jeu le dise. Débloquée après la mission 2.
- **LES ROUES DU CHEF** *(courte, répétable)* — le lavage, Bogdan, l'élève qui photographie. Revenu honnête volontairement lent et mal payé : le taux horaire de la vie d'avant, à sentir dans les mains. Petit +vie perso la première fois (une paie propre ramenée à la maison), plus rien ensuite.
- **LE PANTALON** *(easter egg)* — récupérable dans le désert à l'endroit exact de la mission 1. Ne sert à rien. Trophée chez Walt si ramassé — et un plan au générique de fin.

### Palier 2
- **LA BATTERIE** *(longue, une seule catégorie)* — camping-car en panne au fond du désert. Pièces de monnaie, éponges, fil de cuivre, plaquettes de frein : un vrai puzzle d'artisanat, la seule mission qui récompense la chimie du joueur et pas celle de Walt. Dernier moment où Walt et Jesse s'entendent vraiment — à placer avant que ça se gâte. « Yeah, Mr. White ! Yeah, science ! »
- **LA TORTUE** *(courte, menace)* — l'avertissement du cartel dans le désert. On trouve, on comprend, on repart. Zéro combat, zéro perte : mise en scène pure d'un antagoniste qu'on ne rencontrera pas avant deux paliers.
- **LE BROYEUR** *(courte)* — le camping-car à la casse, en silence. La seule fois où Jesse pleure devant le joueur. À placer en transition vers le palier 3.

### Palier 3
- **SAUL DANS LE DÉSERT** *(moyenne, comique)* — cagoules, pelle, trou : enlever l'avocat pour le convaincre de travailler pour soi. Sans mort. **Prérequis narratif de la mission 7** (elle recrute Saul).
- **LA PIZZA SUR LE TOIT** *(mini-jeu)* — porte fermée, la pizza dans les mains, physique correcte, visée libre. Elle reste sur le toit jusqu'à la fin du jeu, visible depuis la rue, et personne ne l'enlève jamais.
- **LES COUSINS CHEZ WALT** ⏱ *(moyenne, infiltration inversée)* — les jumeaux assis sur le lit, la hache. Walt rentre, sent que quelque chose cloche (porte, silence, chaussures), et doit **ressortir** de sa propre maison sans rien déclencher. Le coup de fil de Gus qui les rappelle sert de résolution.
- **JANE** ☠ *(scène scriptée, automatique entre les missions 8 et 9)* — Walt entre chez Jesse, la voit s'étouffer, et le jeu donne une seule commande : intervenir. Le joueur appuie. **Walt ne bouge pas.** La seule fois du jeu où l'input est refusé — et ça doit rester la seule. Zéro gameplay, impact maximal. *(Ton à valider en équipe : c'est la scène la plus dure de la série.)*
- **LA MOUCHE** *(courte, absurde, optionnelle)* — une pièce, un insecte, le temps qu'il faudra. La moitié des joueurs la citeront.

### Palier 4
- **LES AIMANTS** *(moyenne, mixte)* — acheter le camion, empiler les aimants, se garer contre le bon mur, monter l'intensité. On ne voit jamais l'intérieur de la salle des scellés : on devine que ça marche parce qu'un cadre tombe du mur. Puis le camion se retourne. « Yeah bitch ! Magnets ! »
- **HUELL** *(très courte)* — le garde-meuble, la palette de billets. Le jeu demande explicitement au joueur de compter ; le compteur refuse d'afficher un nombre. La règle 1 jouée comme une blague — et la scène où « combien c'est assez » devient la vraie question.
- **DECLAN — DIS MON NOM** ☠ *(courte, dialogue)* — négociation dans le désert, aucune arme sortie : le chapeau suffit à conclure — le paiement de la mécanique installée au palier 2. Puis la suite : le joueur ne tire pas, mais choisit **la phrase qui condamne Mike ou celle qui le laisse partir**. Les deux options paient — l'une en réputation, l'autre en vie perso — et le jeu ne dit pas laquelle est la bonne, parce qu'il n'y en a pas.
- **LYDIA** *(courte)* — le café, le Stevia, la table du fond, toujours dos à Walt. Petite, étrange, et elle installe la toute dernière image du jeu si on veut s'en servir un jour.
- **LA QUENELLE DE RICINE** ⏱ *(moyenne, infiltration domestique)* — préparer, dissimuler dans le bon objet, placer chez la bonne personne sans être vu, avec des allées et venues scriptées dans la maison. La série adore ces séquences d'objets déplacés en douce (la cigarette, le Stevia, le pot de Lily of the Valley) : c'est un genre de niveau à part entière.
- **MISSION DE NETTOYAGE** *(conditionnelle)* — n'existe que si le joueur a laissé une trace à la mission 10. Retourner effacer ce qui a été bâclé, sous pression. Si le joueur a été propre, il ne saura jamais qu'elle existait.

### Palier 5
- **L'AZTEK** *(moyenne)* — mission de conduite dont l'objectif est de **se crasher de façon convaincante** au carrefour pour empêcher Hank d'arriver à la blanchisserie. Le joueur doit rater exprès, et le jeu ne le félicite pas.
- **CELUI QUI FRAPPE À LA PORTE** *(courte, famille)* — la cuisine, la nuit, Skyler. Une scène de dialogue où toutes les options sont mauvaises et où la meilleure est celle qui fait le plus peur.
- **L'APPEL QU'ON NE PEUT PAS PRENDRE** *(courte)* — une production en cours au labo, le téléphone qui vibre, le nom de la famille à l'écran, et aucune commande pour décrocher. Trois minutes. Le palier 1 avait « les œufs » en trois réponses possibles ; le palier 5 a le même appel, en zéro.

---

## 6. Boîte à idées — micro-scènes et clins d'œil (→ `docs/14-boite-a-idees.md`)

Le bacon en chiffres sur l'assiette d'anniversaire · Hank et ses minéraux (« c'est des *minéraux*, Marie ») · la Schraderbräu à goûter poliment · Badger qui raconte son scénario de Star Trek pendant un trajet · Skinny Pete au piano, très bien · le distributeur d'essuie-mains de l'hôpital · le violet de Marie et ses petits vols · l'ours en peluche rose dans une piscine, jamais expliqué · Los Pollos Hermanos comme vrai restaurant où l'on peut manger · la cassette de karaoké de Gale à trouver dans son appartement (lié à la mission 14) · le chapeau acheté en magasin, en cinématique, sans un mot · la tarentule dans le bocal (liée à la mission 12).

---

## 7. Points ouverts

1. **Le temps** — volontairement repoussé (décision de session). Aucune fiche ne doit en dépendre. À rouvrir plus tard.
2. **Les valeurs chiffrées** — toutes les paies (+, ++, +++) et tous les seuils de porte sont des **ordres de grandeur**, à régler en phase 4 du socle (« le réglage, une fois qu'on y aura vraiment joué »).
3. **La scène de Jane** — principe validé côté design (input refusé, unique), **ton à valider en équipe** avant écriture.
4. **La disparition des jauges à la fin** (mission 15) — proposition forte, à valider : l'interface qui s'efface pour accomplir la règle 1.
5. **La chronologie assumée** — l'ordre série n'est pas respecté (désinsectisation avant Gus, train avant le labo). Assumé comme « stock de scènes ». Si quelqu'un y tient, le seul point de friction réel est la place du Train ; tout le reste est déplaçable.
6. **L'affichage des points** — exception temporaire à la règle 1, à documenter dans `docs/12-direction.md` : *« pour l'instant, tout se compte ; à terme, seul l'argent se comptera »*.
7. **Jesse** — conformément au socle, pas une jauge : sa fiabilité est un état du monde (maison, musique, ponctualité), modifiée par les missions 6, 14 et l'annexe Jane.

---

## 8. Prochaines étapes

1. Trancher les points ouverts 3 et 4 en équipe.
2. Prototyper le palier 1 complet (3 missions histoire + « La fournée qui tourne mal ») — c'est la tranche verticale naturelle : elle contient la fuite, la dissolution, le meurtre, le monde ouvert, les trois ressources et la première trace enregistrée.
3. Définir le **système de traces** techniquement (les mensonges/négligences enregistrés aux missions 2, 7, 9, 10 et rejoués à la mission 15) — c'est la seule mécanique transverse nouvelle de ce document.
4. Poser les seuils de porte provisoires du palier 1 pour tester la boucle farm → porte → mission.

---

*Projet de fan, non commercial.*
