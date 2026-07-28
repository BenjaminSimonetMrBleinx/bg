# La direction du jeu

**Proposition, pas décision.** Ce document dit ce que je ferais de ce jeu et
pourquoi. Chaque section se discute ; les questions ouvertes sont regroupées à
la fin.

État au 28 juillet 2026 : une ville, une conduite, un personnage complet, une
mission jouable de bout en bout, quatre décors. Ce qui manque n'est pas du
contenu — c'est **une raison de jouer une deuxième soirée**.

---

## 1. Ce que ce jeu n'est pas

Il faut le dire avant de proposer, parce que c'est ce qui tranchera la moitié
des arbitrages à venir.

**Ce n'est pas un GTA.** GTA propose un fantasme d'impunité : on est un
inconnu, sans adresse, sans obligations, et le monde encaisse. Breaking Bad
propose exactement l'inverse — **un homme qui a une maison, une femme, un
métier et un cancer**, et dont chaque gain restreint la marge de manœuvre.

Le rapprochement avec Vice City est juste sur un point et un seul : la
structure. Une ville, une progression par missions, des biens qu'on acquiert,
une bande-son et une lumière. Mais les **verbes** ne peuvent pas être les
mêmes. Dans Vice City, progresser veut dire tirer mieux. Ici, progresser doit
vouloir dire **cuisiner mieux, vendre plus loin, et se cacher plus longtemps**.

Le jour où l'on hésitera entre « ajouter une arme » et « ajouter une contrainte
domestique », c'est la contrainte qui gagne. C'est ce qui fera la différence
entre un mod GTA et un jeu Breaking Bad.

---

## 2. Les trois piliers

Tout ce qui suit en découle. Si une idée n'alimente aucun des trois, elle
attend.

### Pilier 1 — L'argent est un compte à rebours, jamais un score

Il n'existe aujourd'hui aucune dépense obligatoire. Tant que c'est le cas,
aucune mécanique ne prendra : gagner de l'argent n'a de saveur que si ne pas en
gagner coûte quelque chose.

**Le puits**, dans l'ordre d'apparition :

| Quand | Ce qui prélève | Effet si on ne paie pas |
|---|---|---|
| Dès le début | La facture médicale, tous les 7 jours, croissante | Une séance de chimiothérapie sautée : la barre de vie plafonne plus bas |
| Acte 1 | La part de Tuco sur chaque vente | Il vient la chercher |
| Acte 2 | Le loyer du labo, le blanchiment à taux fixe | L'argent sale ne peut plus être dépensé |
| Acte 3 | Les silences qui s'achètent | Quelqu'un parle |

Le premier suffit à lancer la machine. **Un entier et un compte à rebours.**

### Pilier 2 — La pureté traverse tout

Une statistique unique, de 0 à 99,1 %. Elle est produite par la cuisine, elle
fixe le prix, elle décide qui accepte de traiter avec vous — **et elle vous
identifie**.

C'est le meilleur mécanisme que la série nous offre, parce qu'il est
*contradictoire par construction* : plus votre produit est pur, plus il
rapporte, et plus il porte votre signature. Le bleu, dans la série, n'est pas
un détail esthétique — c'est une preuve.

> Monter en pureté, c'est gagner en argent et perdre en anonymat. Le joueur
> doit sentir ce choix à chaque cuisine.

### Pilier 3 — Deux vies, et l'une empêche l'autre

Walter a une adresse. C'est notre avantage sur tous les jeux du genre, et il ne
coûte presque rien à exploiter : **il faut rentrer**.

Un rendez-vous manqué, une nuit dehors, une somme inexplicable sur la table de
la cuisine — chacun alimente une **suspicion domestique**, distincte de la
suspicion policière. Skyler n'appelle pas la police : elle pose des questions,
puis elle ferme des portes. Perdre l'accès à sa propre maison est une sanction
plus intéressante que mourir.

---

## 3. La boucle

```
        ┌── cuisiner ──► pureté ──► prix ─┐
        │                   │             │
    matériel            signature      argent ──► le puits
        ▲                   │             │
        │                   ▼             ▼
        └── acheter ◄── attention ◄── blanchir
                       (DEA, Skyler)
```

Une soirée type, telle que je la vois :

1. La facture tombe. On sait combien il manque et en combien de jours.
2. On cuisine — trois à quatre minutes, tactile, avec un résultat chiffré.
3. On charge la voiture, on choisit ses contacts sur la carte : **plus loin =
   mieux payé et plus risqué**.
4. On roule. C'est là que le jeu se joue vraiment — c'est notre meilleure
   mécanique existante.
5. On blanchit, on paie, on rentre avant que ça se remarque.
6. Un imprévu par soirée, tiré du contexte : un contrôle, un témoin, un
   concurrent, un appel de Jesse qui a fait une bêtise.

**Le premier jalon tient en une soirée de dev : un contact, une livraison, un
compteur.** On saura tout de suite si le trajet est amusant ou ennuyeux, et
c'est l'information la plus importante du projet.

---

## 4. Les verbes

Ce que le joueur *fait*, par ordre de priorité de développement.

### Cuisiner — le geste central

Pas un puzzle. Une séquence courte et physique : régler une température, verser
au bon moment, surveiller une couleur. Trois à cinq gestes, quatre minutes,
**un score de pureté à la fin**. Elle doit être plaisante à refaire cinquante
fois, donc courte, lisible et sans texte.

Ce qui la fait progresser : le matériel (verrerie, ventilation, source de
précurseur), le lieu (camping-car → labo fixe), et l'aide de Jesse — qui
travaille vite et sale, ou lentement et bien, selon comment on lui parle.

### Conduire — déjà là, et c'est notre force

La conduite existe et elle est réglée. Il ne manque qu'une raison de rouler
longtemps. Les distances deviennent un coût, et le désert devient un choix :
plus loin de tout, donc plus sûr, donc plus cher en temps.

### Vendre — la carte comme interface

Des contacts marqués sur la ville : une demande, un prix, une tolérance au
risque, un quartier. Ils se débloquent, se fâchent, se font arrêter. Le
territoire se lit sur la carte, pas dans un menu.

### Se cacher — la mécanique la plus sous-exploitée du genre

Les témoins (cône de perception, suspicion) sont le meilleur rapport
effort/effet de la liste. Ce qui transforme un trajet en décision, ce n'est pas
la police, c'est **quelqu'un qui vous regarde depuis un balcon**.

Le chapeau entre ici : porté, il améliore les prix et la déférence, et il
accélère la reconnaissance. Un booléen, deux multiplicateurs, et tout le thème
de la série dans un compromis.

### Tirer — le moins possible

Le tir existe et doit rester rare, moche et décisif. Trois balles, pas de
recharge tactique, pas de couverture. Dans la série, une arme sortie signifie
qu'on a déjà perdu le contrôle. Le jeu doit le faire sentir : **tirer en ville
déclenche une enquête qui ne se referme pas.**

---

## 5. L'histoire

Trois options, et je recommande la troisième.

**A. Suivre la série.** Le joueur rejoue ce qu'il connaît. Confortable à
écrire, mais on perd la surprise, et on se met en avant sur le terrain
juridique le plus exposé.

**B. Histoire originale dans l'univers.** Liberté totale, mais on perd la
reconnaissance — or c'est elle qui donne envie de lancer le jeu.

**C. Le squelette de la série, nos propres épisodes.** ← recommandé.

Les **ancres** sont celles que tout le monde reconnaît : le camping-car dans le
désert, Tuco, le porkpie, le blanchiment par un commerce, la roulotte. Entre
elles, **nos missions à nous**, qui n'existent pas dans la série. On garde la
promesse et on garde la surprise.

### Découpage proposé, en trois actes

**Acte I — Le camping-car.** On cuisine mal, on vend peu, on a peur. Tuco est
le seul débouché et il est instable. Se termine quand Tuco devient un problème
plutôt qu'une solution.

**Acte II — Le laboratoire.** Volume, qualité, blanchiment. Le jeu s'ouvre :
plusieurs quartiers, plusieurs contacts, une comptabilité. La DEA apparaît, non
comme un ennemi qui tire, mais comme **une pression sur les délais**.

**Acte III — Heisenberg.** Le joueur est devenu la menace. Les mécaniques
s'inversent : ce qu'on protégeait devient ce qu'on sacrifie. Fin ouverte, ou
plusieurs fins selon ce qu'il reste de la maison.

### Missions principales de l'acte I

La mission 1 existe déjà et sert de patron : neuf temps, quinze objectifs,
quatre décors.

| # | Titre | Ce qu'elle apprend au joueur |
|---|---|---|
| 1 | *Un client impatient* ✅ | La boucle complète en une fois |
| 2 | *Le fournisseur* | Acheter du matériel — l'argent sert à quelque chose |
| 3 | *Une odeur de chien* | Un voisin remarque le camping-car : déplacer le labo |
| 4 | *La leçon* | Cuisiner soi-même, avec un score. Introduit la pureté |
| 5 | *Le concurrent* | Un dealer vend sur votre zone. Choix : négocier, écraser, ignorer |
| 6 | *Rendez-vous à quinze heures* | Une obligation domestique pendant une livraison |
| 7 | *La part du lion* | Tuco augmente sa part. Le puits se creuse |
| 8 | *Le chapeau* | Première apparition d'Heisenberg. Débloque le porkpie |

### Activités secondaires

Elles doivent toutes nourrir un pilier, sinon ce sont des mini-jeux.

- **Les courses de nuit** dans le désert — la conduite pure, pour l'argent et
  pour le plaisir de conduire.
- **Le lavage** : un commerce à faire tourner, avec un plafond de blanchiment
  qui augmente si on s'en occupe.
- **La chasse au précurseur** : repérer, voler, ou acheter cher.
- **Les photos** de lieux de la série — la collecte qui fait visiter la carte,
  et la seule qui n'a pas besoin d'être justifiée par l'économie.
- **Le ménage** : faire disparaître ce qui traîne avant une visite. Court,
  tendu, sans combat.

---

## 6. Ce que je ferais dans l'ordre

1. **Une livraison, un contact, un compteur.** Une soirée. C'est le test.
2. **Le puits** — la facture. Une demi-soirée.
3. **La cuisine avec un score.** Deux à trois soirées.
4. **Les témoins.** Deux soirées, le meilleur rapport effort/effet.
5. **La carte des contacts.** Deux soirées.
6. **Le chapeau porté qui change les prix.** Une demi-soirée.

Six items, et le jeu est tendu. Le reste — police, réputation, acte II — vient
après et sera plus facile à concevoir une fois qu'on aura joué ces six-là.

---

## 7. Questions ouvertes

Elles changent le travail, pas le goût. Je ne les tranche pas seul.

1. **L'histoire : option C ?** Le squelette de la série avec nos propres
   épisodes, ou vraiment rejouer la série ?
2. **La mort.** Que se passe-t-il quand Walter meurt ? Retour au dernier
   réveil, avec l'argent perdu ? Ou pas de mort du tout, seulement des
   arrestations et des dettes ?
3. **Le temps.** Est-ce que les jours passent tout seuls, ou seulement quand on
   dort ? Le premier crée de la pression, le second respecte le joueur.
4. **Jesse.** Compagnon présent en permanence, ou personnage qu'on appelle ?
   Le second coûte dix fois moins cher et perd la moitié du sel.
5. **La violence.** Jusqu'où va-t-on ? La série n'est pas pudique, mais un jeu
   où l'on tire librement en ville n'est plus une adaptation.
6. **La musique.** Originale, libre de droits, ou pas de musique du tout hors
   autoradio ? Ça engage Guillaume sur plusieurs mois.
