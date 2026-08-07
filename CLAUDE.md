# Comment on travaille sur BG

**Ce fichier se lit au début de chaque session et se met à jour à la fin.**
C'est le seul document que je charge automatiquement : tout ce qui doit
survivre d'une session à l'autre vit ici, ou dans un fichier que celui-ci
désigne.

Il ne remplace pas les docs — il dit ce qu'aucune doc ne dit : ce qui a déjà
raté, ce qui guide un arbitrage, et ce que je dois refuser.

---

## Le projet en trois lignes

Un GTA-like low-poly **PS2** dans l'univers de Breaking Bad, à Albuquerque.
Godot 4.7, GDScript. Benjamin code avec moi ; **Guillaume** livre le son et la
3D et n'est pas développeur. Projet de fan, non commercial — voir
[DISCLAIMER.md](DISCLAIMER.md).

**Ce qui décide, quand deux options se valent :** est-ce que ça donne envie de
rouler dedans ? Le ton de la série avant la fidélité au décor, le décor avant
la technique, et une chose qui tourne avant trois qui attendent.

---

## La direction, en cinq règles

Le détail vit dans [docs/12-direction.md](docs/12-direction.md), qui est le
socle. Ces cinq-là décident de tout et se relisent avant de concevoir quoi que
ce soit :

1. **Aucun chiffre n'est montré au joueur — sauf les trois ressources.**
   **L'argent, la famille et la réputation** s'affichent en permanence, décision
   du 06/08/2026 : ce sont des comptes à rebours qu'on surveille en conduisant.
   Tout le reste se perçoit — la couleur du produit, le ton d'une réplique, la
   lumière d'une pièce. Un chiffre transforme un choix en optimisation, et
   l'exception ne s'étend à rien d'autre.
2. **Un choix sans coût n'est pas un choix.** Si une option est meilleure sur
   tous les plans, il n'y a rien à décider.
3. **L'argent est un compte à rebours, pas un score.** Il doit être prélevé.
4. **Monter retire des options.** Chaque palier donne de l'argent et enlève de
   la liberté.
5. **Le ton ne bouge pas.** Lent, sale, provincial.

**L'ordre de travail** — et il vaut aussi pour moi : *théorie → cœur → boîte à
idées → réglage*. La [boîte à idées](docs/14-boite-a-idees.md) existe pour
qu'on puisse souffler sans bricoler au hasard : on y pioche quand on en a marre
du cœur, et une idée piochée doit tenir en une soirée ou deux.

---

## Ce qui n'est pas négociable

**On mesure le fichier PRODUIT, jamais la scène qui l'a produit.** C'est la
règle la plus chère du projet : elle a été apprise quatre fois, toujours de la
même façon — un outil annonce un nombre juste et écrit un fichier faux. Voir
[docs/11-pieges.md](docs/11-pieges.md), qui existe pour ça.

**Une image ou un nombre, jamais une conviction.** Un rendu se juge sur
`.\bg.ps1 capture -Scenario <nom>`. Une géométrie se juge sur des centimètres
imprimés. J'ai conclu trois fois de suite « la voiture est dans le bon sens »
sur une image ambiguë ; elle était à l'envers.

**Et son revers : un nombre n'est une preuve que si j'ai lu le code qui le
produit.** Un relevé de performance a annoncé un effondrement du jeu ; il
mesurait sa propre synchro verticale. Avant de corriger ce qu'un instrument
dénonce, vérifier l'instrument — voir le piège 18.

**Une vérification qui se place elle-même au bon endroit valide toujours.** Un
test téléportait la voiture sur la sortie du désert avant de vérifier qu'on peut
repartir ; la sortie était introuvable depuis une semaine, et il était au vert.
Devant un test qui passe, demander **quel geste du joueur il reproduit** — s'il
commence par placer quelque chose à la main, il ne vérifie pas qu'on peut y
arriver, et c'est presque toujours la question. Piège 19.

**Tout nombre de ressenti vit dans `reglages.tres`.** Une constante de feeling
cachée dans un script est un bug de méthode, même si le résultat est bon.

**Aucune mention de l'assistant** dans les commits, le code, la documentation
ou les tickets.

**Guillaume ne bumpe pas et n'écrit pas les notes de version.** À chaque bump,
une entrée dans `NOTES-DE-VERSION.md` écrite pour celui qui teste : ce qu'on
peut essayer, et les bugs qui gênaient vraiment.

**`livraisons/` se range dès qu'on y touche.** Et `assets-ref/` n'entre jamais
dans git.

**Le français, sans accents dans le code** — commentaires compris. Les accents
sont réservés aux fichiers `.md` et aux textes affichés à l'écran.

---

## Recevoir un asset livré

Ils arrivent à des échelles, des orientations et des résolutions sans rapport
les uns avec les autres. **C'est normal et ça ne se corrige pas à la main** :
un modèle importé sans passer par la chaîne est une incohérence qui se
découvrira trois sessions plus tard, à l'écran.

```powershell
.\bg.ps1 integrer -Fichier livraisons/modeles/x.glb -Vers game/assets/... -Hauteur 1.78
```

La commande mesure, met à l'échelle, pose au sol, oriente, **relit le fichier
écrit**, et refuse d'écrire si le résultat ne correspond pas à la demande.

La charte graphique — budgets de triangles, tailles de texture, pivots — est
dans [docs/03-conventions-assets.md](docs/03-conventions-assets.md). Les deux
règles qu'on oublie : **128 px de texture par défaut** et **une seule texture
par objet**. Un modèle livré avec une texture 2048 est plus net que tout ce qui
l'entoure, et ça se voit plus qu'un modèle raté.

**Un modèle livré ne doit jamais figurer dans la table d'un générateur.** Le
Jesse de Guillaume a été écrasé par un `generer` lancé pour une autre raison.
Vérifier `gen_personnage.py`, `gen_objets.py`, `gen_lieux.py` avant d'intégrer.

---

## Tester

`.\bg.ps1 test -Suite <nom>` — la suite nommée, et rien d'autre. Le jeu est
petit, il n'y a pas grand-chose à casser, et le temps passé à tester n'est pas
du temps passé à livrer.

- **`-Modifies` n'est pas ciblé sur ce projet.** Dès qu'un fichier partagé
  bouge — c'est-à-dire presque toujours — il relance les 27 suites.
- **La suite complète est réservée aux grosses releases.** Pas à chaque bump.
- Si je ne sais pas quelle suite couvre un changement, je lis `couvre` dans
  `bg.ps1`.

---

## Ce que je dois refuser

**Ne pas toujours aller dans leur sens.** Une idée qui coûte trois sessions
pour un gain qu'on ne verra pas à l'écran doit être discutée avant d'être
faite, pas après. Ce qui mérite une objection :

- une fonctionnalité qui n'a pas d'image — si je ne sais pas quelle capture la
  montrerait, elle n'est probablement pas prête à être codée ;
- du code custom là où une donnée suffirait ;
- un ajout qui contredit le ton de la série — le jeu est lent, sale et
  provincial, pas nerveux et clinquant ;
- une demande formulée comme une solution alors que le problème n'est pas
  posé. Demander « lequel des deux problèmes tu veux régler » coûte une phrase.

**Et livrer quand même** si la réponse est « fais-le ». L'objection tient en
deux phrases, pas en trois paragraphes, et elle ne se répète pas.

**Ne pas créer de dépendance.** Quand j'écris du code non trivial, un
walkthrough court : ce que ça fait, où c'est, pourquoi comme ça.

---

## Le rituel de fin de session

1. `livraisons/` rangé, `.tmp/` vidé de ce qui n'est pas régénérable.
2. Un bump si quelque chose de jouable a changé, avec sa note de version — **et
   son tag poussé**. Onze versions ont été bumpées sans jamais être taguées :
   Guillaume a téléchargé pendant deux jours un jeu sans écran-titre ni
   sauvegarde, et trois de ses tickets 🔥 attendaient qu'il voie ce qui existait
   déjà. Un bump sans tag ne livre rien, et ça ne se voit pas du côté qui bumpe.
3. **Une entrée dans [docs/JOURNAL.md](docs/JOURNAL.md)** : début, fin, ce
   qu'on voulait, ce qu'on a livré, les surprises, et où on reprend. Les
   surprises sont le cœur — c'est ce qu'on relit dans trois semaines.
4. **Relire ce fichier et [docs/11-pieges.md](docs/11-pieges.md)** : est-ce
   qu'un piège nouveau est apparu ? une règle s'est-elle révélée fausse ?
5. Le bilan : effort, apprentissages, ressenti.

## Les tickets

Trois familles d'étiquettes : **ce que c'est** (🔨 chantier, ✅ à faire,
🐛 bug, 💡 idée), **qui doit agir** (🤖 Claude, 🎨 Guillaume, 🎮 Benjamin), et
**quand** (🔥 maintenant, 🧊 plus tard).

Chaque ticket **commence par une ligne qui dit à qui il appartient**. Personne
ne doit avoir à lire un ticket en entier pour savoir s'il l'attend. Les titres
portent leurs accents ; la règle « pas d'accents » ne vaut que pour le code.

**Le titre suit une forme, et une seule** — décidé le 07/08/2026, après une
passe où vingt-deux titres sur vingt-quatre ont été refaits :

> `Domaine — ce qui existera quand ce sera fini`

Les domaines : **Économie, Ville, Intérieurs, Monde, Son, Personnages, Missions,
Famille, Réglage**. Le titre dit le **résultat**, jamais la raison — celle-ci
est dans le corps, c'est sa place. Ni question, ni jugement, ni formule : un
titre n'a pas à être joli, il a à être trouvable dans une liste de trente.

**Sauf pour un bug, qui dit le SYMPTÔME** : quand on cherche un bug, on cherche
ce qu'on a vu, pas ce qu'on obtiendra en le réparant.

Ce que la forme libre coûtait : des titres qui posaient une question déjà
tranchée depuis dix jours, d'autres qui argumentaient contre leur propre version
précédente, et aucun moyen de grouper la liste à l'œil.

Un piège qui n'est pas écrit sera repayé au prix fort. Les quatre plus chers de
ce projet ont tous été payés deux fois.
