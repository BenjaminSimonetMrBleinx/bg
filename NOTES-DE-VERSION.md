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
