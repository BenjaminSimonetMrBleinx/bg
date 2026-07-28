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

> **TRANCHÉ le 28 juillet 2026 : trame parallèle à la série, avec liberté sur
> l'histoire principale quand ça sert le jeu.** C'est l'option **C** ci-dessous.
>
> Les personnages, les lieux et le ton sont ceux de la série ; les événements
> sont les nôtres. On croise Tuco, Gus, Mike **au moment où le jeu en a
> besoin**, pas à l'épisode où la série les place — et on peut inventer un
> client, un labo, une nuit entière, tant que la série aurait pu la contenir.
>
> **Ce que ça nous évite :** être comparés défavorablement à une scène que tout
> le monde connaît par cœur, et être enfermés dans un ordre d'événements qui
> n'a pas été écrit pour un jeu.
>
> **Ce que ça n'autorise pas :** contredire ce qui définit un personnage. Gus ne
> s'emporte pas, Mike ne bavarde pas, Walt ne s'excuse pas longtemps. Et le ton
> ne bouge pas — **lent, sale et provincial**. Une explosion reste un
> événement, pas une ponctuation.

Trois options, et c'est la troisième qui est retenue.

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

### Le choix, sans bifurcation

**Léger mais réel, et sans impact sur le cœur de l'histoire** — c'est la
contrainte posée le 28 juillet 2026, et elle est la bonne. Le sentiment de
choix ne demande pas de bifurcation : il demande que **le joueur ait eu quelque
chose à décider, et qu'il le retrouve plus tard**.

Deux pièges valent d'être écrits, parce qu'ils annulent tout le reste :

- **Jamais de jauge de moralité visible.** Dès qu'elle s'affiche, le joueur
  optimise la jauge au lieu de choisir. On obtient l'inverse exact de ce qu'on
  cherchait.
- **Un choix sans coût n'est pas un choix.** Si une option est meilleure sur
  tous les plans, il n'y a rien à décider. Chaque paire doit échanger quelque
  chose contre autre chose.

Quatre leviers, du moins cher au plus cher :

**1. Choisir la MÉTHODE, jamais le résultat.** La mission se termine
identiquement ; le chemin varie. Parler, payer, intimider, contourner. Chacun
règle la même dette dans une monnaie différente — du temps, de l'argent, de la
suspicion, une relation. C'est le levier le plus rentable : une mission, trois
approches, zéro embranchement à écrire.

**2. Un registre du monde, pas un arbre.** Les décisions n'écrivent pas
l'histoire, elles écrivent l'**état du monde** dans lequel elle se déroule. Le
dealer qu'on a épargné réapparaît comme contact ; celui qu'on a écrasé laisse
un coin de rue vide et une rumeur. Aucun de ces états ne change une réplique de
Tuco — tous changent la ville qu'on traverse pour aller le voir.

**3. Un curseur Heisenberg.** Les réponses de dialogue ne changent pas l'issue,
elles s'accumulent. Ce curseur ne débloque rien : il décide **comment on vous
parle**. Le même événement, joué froidement ou platement, ne se raconte pas
pareil. C'est exactement le sujet de la série, et ça coûte un flottant.

**4. Le bilan de fin d'acte.** Le jeu ne demande jamais « es-tu sûr ». Mais à
la fin de chaque acte, il **récapitule ce qu'on a choisi** : qui on a épargné,
combien on a menti, ce qu'on a laissé filer. Rien n'est jugé. C'est le seul
moment où le joueur voit l'homme qu'il est devenu — et c'est là que le
sentiment de choix se paie, d'un coup, sans avoir rien coûté à écrire.

**Les vrais embranchements vivent dans le secondaire**, où ils ne menacent
rien. Une quête annexe peut se terminer de trois façons ; l'acte II commencera
pareil.

### La méthamphétamine progresse — et le jeu avec elle

Idée retenue le 28 juillet 2026, et c'est la colonne vertébrale de la
progression.

Au début, on cuisine mal, avec de mauvais précurseurs, et on vend à de mauvais
clients. Tout s'améliore ensemble : la matière première, la pureté, les
acheteurs.

| Palier | Où | Précurseur | Pureté | Qui achète | Ce qui change vraiment |
|---|---|---|---|---|---|
| **0** | camping-car | pseudoéphédrine de pharmacie | 60–70 % | consommateurs, dealers de rue | On est payé partiellement, en retard, ou volé. Beaucoup de clients, tous instables |
| **1** | camping-car équipé | pseudo en volume, courses obligées | 75–85 % | dealers structurés, un revendeur par quartier | Moins de clients, plus fiables. La logistique devient le sujet |
| **2** | labo fixe | méthylamine détournée | 92–96 % | distributeurs | Le volume explose. Le blanchiment devient obligatoire |
| **3** | labo industriel | méthylamine en fût | 99,1 %, **bleue** | **un seul acheteur** | Plus rien à négocier. On dépend entièrement de lui |

**Ce que ce tableau doit faire sentir, et c'est le point important :** monter en
palier n'est pas seulement « gagner plus ». À chaque palier, **le jeu retire des
options en même temps qu'il ajoute de l'argent**. On commence avec vingt
clients minables et une liberté totale ; on finit avec un client unique et
aucune. C'est le piège qui se referme, et c'est exactement la série.

**Le risque à surveiller :** que la première heure paraisse une corvée qu'on
subit en attendant mieux. La parade est de ne pas faire du palier 0 une version
*dégradée* du jeu, mais une version *plus sale* — chaotique, imprévisible, avec
des clients qui posent problème. Ce n'est pas moins intéressant, c'est
autrement tendu. Le palier 3, lui, est propre, riche, et étouffant.

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

### Tranché le 28 juillet 2026

- **L'histoire** : trame parallèle, avec liberté sur l'histoire principale
  quand ça sert le jeu. Le sentiment de choix passe par la méthode, le registre
  du monde, le curseur Heisenberg et le bilan de fin d'acte.
- **L'architecture du monde** : quartiers chargés à la volée dans un seul
  repère de coordonnées. Voir [13-carte.md](13-carte.md).
- **La progression** : la pureté est la colonne vertébrale, et chaque palier
  retire des options en même temps qu'il ajoute de l'argent.

### Au backlog, volontairement

- **La boucle de jeu** — produire/livrer/réinvestir, mission après mission, ou
  territoire. La pureté et le système de choix se construisent sans cette
  réponse, et elle sera plus facile à trancher une fois qu'on aura joué « une
  livraison, un contact, un compteur ».

### Encore ouvertes

1. **La mort.** Que se passe-t-il quand Walter meurt ? Retour au dernier
   réveil, avec l'argent perdu ? Ou pas de mort du tout, seulement des
   arrestations et des dettes ?
2. **Le temps.** Est-ce que les jours passent tout seuls, ou seulement quand on
   dort ? Le premier crée de la pression, le second respecte le joueur.
3. **Jesse.** Compagnon présent en permanence, ou personnage qu'on appelle ?
   Le second coûte dix fois moins cher et perd la moitié du sel.
4. **La violence.** Jusqu'où va-t-on ? La série n'est pas pudique, mais un jeu
   où l'on tire librement en ville n'est plus une adaptation.
5. **La musique.** Originale, libre de droits, ou pas de musique du tout hors
   autoradio ? Ça engage Guillaume sur plusieurs mois.
