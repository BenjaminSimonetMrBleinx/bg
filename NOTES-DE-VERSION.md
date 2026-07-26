# Notes de version

**Ce fichier s'adresse à celui qui va tester**, pas à celui qui a codé.

Une entrée dit deux choses, et rien d'autre :

- **ce qu'on peut essayer** qui n'existait pas avant, et comment y accéder
- **les bugs qui gênaient vraiment** et qui sont réparés

Les ajustements internes, les remaniements, les corrections de tests n'y sont pas.
Le détail technique vit dans les messages de commit et dans [docs/JOURNAL.md](docs/JOURNAL.md).

Le numéro s'affiche en haut à droite de l'écran. `MAJEUR.MINEUR.CORRECTIF` : **MAJEUR**
passera à 1 le jour où le jeu se tient de bout en bout, **MINEUR** à chaque lot livré,
**CORRECTIF** pour ce qui répare sans rien ajouter.

---

## 0.27.0 — La première mission

> **Le jeu a un début, un milieu et une fin.** Quinze étapes, quatre nouveaux
> décors, et de quoi tout rater.
>
> **Sors de chez toi et attends.** Un homme de Salamanca appelle. À partir de
> là, le téléphone est ton carnet de mission : `T`, puis **Mission** — l'objectif
> courant et les deux précédents. À chaque étape franchie il sort tout seul,
> montre la suite, et se range.

**Le déroulé.** Parler à Jesse, prendre la voiture, rejoindre le labo dans le
désert, cuisiner la **botte secrète**, récupérer la marchandise, livrer Tuco,
s'en sortir, rentrer, planquer l'argent.

| Ce qui est nouveau | |
|---|---|
| **L'argent** | En haut à gauche, avec le sac de billets de Guillaume. On démarre avec 100 à 200 $ — tirés au sort — et Tuco en paie **300 000** |
| **La vie** | Une barre, qui n'apparaît qu'au premier coup. Une balle en retire un quart |
| **Le revolver** | Dans la boîte à gants du camping-car. **Clic droit vise, clic gauche tire.** La roue des outils est passée sur `Tab` seul |
| **La mort** | Le temps ralentit, l'image se décolore, et **Walter s'écroule pour de bon** — un vrai ragdoll sur ses vingt-quatre os. Puis on recommence |
| **La cachette** | Une latte du mur, chez Walter. On y règle le montant avec `W`/`S` |

**Quatre décors** construits d'après tes références : l'intérieur du camping-car
— un couloir, la paillasse, la verrerie, les bidons —, la rue du QG avec sa
fresque, et le bureau de Tuco, lambrissé et calfeutré, éclairé par une seule
lampe posée.

**Ce qu'on peut essayer de casser, et qui est prévu :** tirer sur Jesse, sur
Skyler, sur le garde à l'entrée, sur Tuco. Chercher à conduire le camping-car.
Aller chez Tuco sans marchandise. Ressortir de chez soi avec trois cent mille
dollars en poche. Ne rien faire pendant que Tuco s'énerve.

**Ce qui manque, et qui viendra de Guillaume :**

- **le son « this is not meth »** n'était pas dans les livraisons. La scène de
  l'explosion joue un son de synthèse à sa place
- **les coups de feu et l'explosion** sont eux aussi synthétisés — ils tiennent
  la place, ils ne la méritent pas
- **Tuco, le garde et les hommes de main** empruntent les corps des passants, en
  attendant leurs modèles

## 0.26.0 — Sauter, s'accroupir, et emboutir pour de bon

> **À essayer, trois choses.**
>
> - **Espace : il saute.** Environ un mètre de haut. Saute en courant : **il
>   part en avant** et garde son élan jusqu'à l'atterrissage, il ne saute pas
>   sur place.
> - **Ctrl gauche maintenu : il s'accroupit**, et il peut se déplacer comme ça.
>   **Sa capsule de collision descend avec lui** — c'est ce qui compte, sinon
>   s'accroupir ne servirait qu'à aller moins vite.
> - **Rentre dans un mur à plus de 50 mph** : la tôle sonne violent, quoi qu'on
>   ait tapé.

**Le choc violent a deux déclencheurs maintenant**, et le second est nouveau :
au-delà de **50 mph à l'arrivée**, c'est classé violent quelle que soit la
vitesse perdue. Avant, seule la décélération comptait — juste pour un mur, faux
pour tout ce qui cède un peu : on pouvait emboutir à cent kilomètres/heure
quelque chose qui amortit et n'entendre qu'un frottement. Le critère de perte
brutale reste, sinon un mur pris à trente sonnerait léger.

Le seuil se règle : `choc_impact_mph` dans `reglages.tres`.

**Espace saute à pied et reste le frein à main au volant.** Les deux ne se
gênent pas.

Les animations d'accroupissement et de saut sont fabriquées comme les
précédentes, et pour l'accroupissement il a fallu **chercher** les flexions :
descendre le bassin de quarante centimètres sans plier correctement hanches,
genoux et chevilles enterre les pieds. Ils bougent de 2 millimètres.

## 0.25.0 — Walter respire

> **À essayer : lâche les commandes et regarde-le.** Il ne se fige plus sur une
> image de course. Il se tient debout, bras le long du corps, **il respire**, il
> reporte son poids d'un pied sur l'autre — et **toutes les huit secondes il
> remonte ses lunettes**.
>
> **Puis entre dans une maison et marche.** La démarche intérieure était raide ;
> le buste tourne maintenant à l'inverse du bassin, la tête suit avec un temps de
> retard, et les deux pas ne sont plus identiques.

**Pourquoi la marche était robotique, et ce n'était pas l'animation.** La longueur
de foulée était réglée à l'œil : 1,15 m, alors que le clip livré en fait **1,76**.
L'animation était donc jouée 50 % trop vite pour la vitesse réelle — il pédalait.
Les trois foulées sont maintenant **mesurées dans le fichier** au lieu d'être
devinées : `blender -b -P outils/animer_perso.py -- --mesurer` les affiche.

**Les deux animations manquantes sont fabriquées, pas achetées.** Le pack ne
contenait que « Walking » et « Running ». Le repos dérive de la **moyenne du cycle
de marche** — moyenner un cycle symétrique annule le balancement et laisse la
posture de celui qui a riggé le personnage — et la marche relâchée est la marche
livrée plus une couche de mouvement. Rien n'est inventé par-dessus le travail de
Guillaume.

**Toujours en attente côté assets** : une vraie animation de trot. Le trot et la
course partagent encore le clip de course à deux vitesses.

## 0.24.0 — Trois allures

> **À essayer : marche, cours, entre dans une maison.**
>
> - **Par défaut Walter trottine** — c'est le rythme pour traverser un quartier.
> - **Maj + avancer** : il court. Presque deux fois plus vite.
> - **À l'intérieur** : il marche, et Maj n'y change rien. Courir dans un salon de sept
>   mètres n'a pas de sens.

**Une limite à connaître** : le modèle livré porte deux animations, `Walking` et `Running`.
Le trot et la course partagent donc le clip de course, joué à deux vitesses. Ça se tient —
un cycle de course ralenti se lit comme un petit trot — mais **une vraie animation de trot
les séparerait nettement.** C'est la seule chose qui manque côté assets.

**Corrigé au passage, et ça se voit** : la « vitesse de marche » valait 4,2 m/s, soit une
allure de course. C'était la seule vitesse du jeu, donc elle avait été réglée pour traverser
le quartier — **et les passants la partageaient.** Toute la rue trottinait. Elle est
redescendue à 1,65 : les passants marchent enfin.

## 0.23.0 — Le vrai Walter

> **À essayer : marche, cours, regarde-le.** C'est le modèle rigué de Guillaume — un
> squelette de 24 os et sa vraie animation de marche, à la place du pantin de dix segments
> animé par du code. Le chapeau et le revolver s'accrochent à sa main et à sa tête comme
> avant.

Il fait 1,78 m, ses pieds touchent le sol, et **il regarde dans le bon sens** — il arrivait
face caméra, donc marchait à reculons.

La cadence du pas reste calée sur la **distance parcourue**, pas sur l'horloge : c'est ce
qui empêche les pieds de patiner, à n'importe quelle vitesse. On ne joue pas l'animation,
on lui demande l'image qui correspond aux mètres franchis.

Les passants gardent l'ancien corps pour l'instant — leurs modèles rigués arrivent.

## 0.22.0 — La ville bouge

> **À essayer : reste sur un trottoir et regarde la rue.** Il y a maintenant des voitures
> qui **roulent** — dix, chacune sur sa file de droite, qui tournent aux carrefours et
> s'arrêtent derrière ce qui les bloque. Mets-toi devant l'une d'elles, elle te pousse.
>
> **Et suis un passant.** Avant, il refaisait les mêmes vingt-cinq mètres à l'infini. Il
> tourne maintenant aux coins de rue et ne repasse plus au même endroit.

Le générateur publie un **graphe** de la ville — carrefours et tronçons — et tout le monde
y circule : les voitures sur la chaussée, les piétons au milieu du trottoir. Une ville
regénérée avec une autre graine fait circuler ses voitures toute seule.

Rien de tout ça n'est simulé en physique : les voitures suivent une ligne et s'arrêtent si
quelque chose la barre. C'est volontaire — une circulation avec changement de voie est
l'endroit précis où les projets à deux s'enlisent.

## 0.21.0 — Cinq voitures, et une Alpine

> **À essayer : regarde les voitures garées.** Il y en avait un seul modèle décliné en trois
> couleurs ; il y en a maintenant **cinq silhouettes** — pick-up, berline, break, Aztek, et
> une Alpine A110 bleue garée devant chez Walter.
>
> Le parc est pondéré comme une rue d'Albuquerque en 2009 : surtout des pick-up.

**L'Alpine est un anachronisme assumé.** Alpine n'a rien produit entre 1995 et 2017, donc
aucune n'est contemporaine de la série. Celle-ci est une A110 des années soixante-dix,
telle qu'un collectionneur en garderait une — et c'est la seule teinte saturée de tout le
parc. Dans une rue de beiges et de gris, elle se voit à cent mètres. C'est le but.

**Les lieux nommés.** Le panneau DESERT s'était retrouvé au milieu de la chaussée **deux
fois**, à chaque fois qu'une rue changeait de largeur. Le générateur publie maintenant des
lieux nommés — la parcelle des maisons, la sortie vers le désert, la place de l'Alpine — et
la scène les lit au lieu de recopier des coordonnées. Un lieu nommé se recalcule ; une
coordonnée écrite à la main se périme.

## 0.20.0 — Les rues sont enfin praticables

> **À essayer : roule vite en frôlant le trottoir.** Avant, la voiture perdait **62 % de sa
> vitesse** en une seconde et demie. Maintenant elle en garde 82 %.

**Ce n'était pas le trottoir.** Mesuré image par image : franchir une bordure de dix-huit
centimètres à 54 km/h coûte **un** kilomètre/heure.

C'était le **stationnement**. Deux rangées de voitures garées sur une chaussée de huit
mètres laissaient 3,84 m de passage pour une caisse de 1,86 m — moins d'un mètre de chaque
côté. On accrochait une aile à la moindre dérive.

La chaussée passe de 8 à 11 mètres. Les rues sont un peu plus larges, la ville un peu plus
grande, et on peut doubler une voiture garée sans la toucher.

## 0.19.0 — La roue des outils s'entend

> **À essayer : ouvre la roue (`Tab` maintenu) et écoute.** Trois couches se superposent
> maintenant — le déclic de l'ouverture, le monde qui ralentit, et une tenue qui dure aussi
> longtemps que la roue reste ouverte. Elle s'arrête en fondu quand tu relâches.
>
> **Dis si ça porte le geste ou si ça l'alourdit.** C'est exactement la question, et elle
> ne se tranche qu'à l'oreille.

**Tous les sons livrés par Guillaume sont désormais branchés.** Il n'en reste aucun de côté.

## 0.18.0 — Le son marchait à moitié

> **À essayer : rentre dans un mur en voiture.** Ça fait du bruit, et la tôle ne sonne pas
> pareil selon la violence. Marche aussi : frotter un trottoir, taper une benne.
>
> **Et écoute tes pas.** Quinze variantes dehors, elles ne se répètent plus.

**Le bug important.** Le véhicule, le joueur, la roue des outils et le téléphone ne
trouvaient pas le système audio et **restaient muets pour toute la partie**. Les portes et
les portières sonnaient quand même, ce qui rendait la panne difficile à voir : le son
marchait *un peu*.

Concrètement, tout ceci était silencieux et ne l'est plus : les pas, les crans de la roue,
les objets qu'on équipe, la sonnerie du téléphone, le klaxon, et les chocs.

**Ce qui reste muet, et c'est voulu** : deux sons d'interface qui demandent un mécanisme
différent (une nappe qui dure tant que la roue est ouverte).

## 0.17.0 — Les chocs

> **À essayer : tape quelque chose en voiture.** Un frottement et un impact violent ne
> jouent pas le même son.

## 0.16.0 — Le jour et la nuit

> **À essayer :** ouvre `game/systemes/reglages.tres` dans Godot et mets **`temps_vitesse`
> à `0.05`**. Une journée complète passe en huit minutes : le soleil se lève, tourne,
> rougit et se couche ; les lampadaires s'allument au crépuscule ; les fenêtres des
> immeubles s'allument une à une.

Avant, le moment était figé à la génération et changer d'heure demandait de refabriquer
toute la ville.

Par défaut le temps est **arrêté** — un cycle qui tourne pendant qu'on règle autre chose
rend tout réglage impossible à juger.

## 0.15.0 — Le désert, réparé

> **À essayer :** la flèche orange au bout de la route ouest. En voiture, elle emmène au
> désert ; à pied, un bandeau explique pourquoi ça ne marche pas.

**Bugs corrigés** : la flèche pointait vers la ville, le panneau était planté sur la
chaussée, DESERT s'écrivait à l'envers vu de dos, on pouvait repartir à pied, et surtout
**revenir en ville renvoyait aussitôt au désert**, en boucle.

## 0.14.0 — Voir le jeu sans y jouer

> **Pour Benjamin :** `.\bg.ps1 capture -Scenario tous` rend une douzaine de vues du jeu
> dans `.tmp\captures\`. Utile pour vérifier ce qui a changé sans lancer une partie.

## 0.13.0 — Le désert

> **À essayer :** rouler jusqu'au bout de la route ouest et franchir la flèche. Le
> camping-car est là-bas.
>
> **Et le téléphone** : touche `T`, `Appeler`, choisis Jesse ou Skyler. Walter porte le
> combiné à l'oreille.

## 0.11.0 — Le téléphone

> **À essayer :** `T` ouvre le SGH-127. Aucune voix pour l'instant, c'est normal.

## 0.10.0 — La scène de la cuisine, nouvelle prise

> **À essayer :** entre chez Skyler et parle-lui. Les dix répliques ont été réenregistrées.

## 0.9.0 — Les sons de Guillaume, branchés

> **À essayer :** la roue des outils (`Tab`), les portes des maisons, monter et descendre
> de voiture, le klaxon (`H`). Tout ça fait du bruit maintenant.

**Bug corrigé** : aucune boucle sonore ne bouclait — les trois couches du moteur repartaient
de zéro toutes les cinq secondes.

## Avant

Le premier jalon, sans numéro : la ville, la conduite, marcher, les maisons et leurs
habitants, les dialogues doublés, la roue des outils, la visée à la souris, les passants,
le modèle sculpté de Walter. Le détail est dans [docs/JOURNAL.md](docs/JOURNAL.md).
