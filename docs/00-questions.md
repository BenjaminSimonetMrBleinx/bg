# BG — Questions de cadrage

**Répondez directement dans ce fichier**, sous chaque question, en remplaçant les tirets :

- `**B:**` pour Benjamin
- `**G:**` pour Guillaume

Pas besoin d'attendre l'autre pour commiter. Faites un bloc, poussez, passez au suivant.
Une question sans intérêt pour vous : écrivez `passe` et on n'y revient pas.

Les blocs **A** à **C** bloquent le démarrage. Les blocs **D** et **E** peuvent attendre lundi.

---

## A · Guillaume — ce que tu sais faire

Ces réponses ne changent plus le moteur (Godot est tranché), mais elles décident de ce que
tu prends en autonomie et de ce qui est généré automatiquement.

### A1. Blender : quel niveau, honnêtement ?
Modélisation seule, ou aussi UV, texturing, rig, animation ? Et as-tu déjà exporté vers un
moteur, ou seulement fait du rendu ?

- **G:** —

### A2. Un moteur de jeu déjà pratiqué ? Lequel, jusqu'où ?
Même « deux tutos Unity » compte.

- **G:** —

### A3. Quand tu dis « script », tu penses à quoi ?
Python dans Blender, logique de gameplay dans un moteur, ou écriture et scénario ?
Les trois servent, mais ne mènent pas au même rôle.

- **G:** —

### A4. Quel DAW, et quelle ambition sonore ?
Pour le premier jalon, deux sons suffisent : un moteur en boucle et une ambiance nocturne.
Dis si tu veux viser plus loin (musique adaptative, middleware) — ça se planifie, mais après.

- **G:** —

### A5. Combien d'heures par semaine, réellement et durablement ?
Sans optimisme. C'est ce chiffre qui dimensionne le projet, pas l'envie qu'on a aujourd'hui.

- **G:** —

### A6. Ta machine : OS, GPU, RAM ?
Godot et Blender sont légers, mais autant le savoir avant de te faire télécharger 4 Go.

- **G:** —

### A7. Ton compte GitHub ?
Nécessaire pour t'inviter en collaborateur.

- **G:** —

### A8. Tu veux apprendre à scripter dans le moteur, ou rester sur assets et son ?
Les deux réponses sont bonnes et durables. Mais elles ne donnent pas la même organisation
de dépôt ni la même façon de découper le travail.

- **G:** —

### A9. Tu préfères modéliser un véhicule ou un décor en premier ?
La voiture est le plus rentable : c'est ce qu'on regarde pendant 100 % du temps de jeu.

- **G:** —

### A10. Qu'est-ce qui te ferait décrocher de ce projet ?
Question sérieuse. Attendre les autres, faire des tâches ingrates, ne pas voir de résultat,
un rythme trop soutenu ? Autant le savoir maintenant et organiser le projet contre ça.

- **G:** —

---

## B · Benjamin — cadrage de la méthode

### B1. Combien d'heures par semaine, réellement ?

- **B:** —

### B2. Tu codes toi-même, ou tu pilotes et tu relis ?
Ça change tout le rythme de livraison. En mode pilotage, walkthrough court à chaque bloc
livré pour éviter l'effet boîte noire.

- **B:** —

### B3. GDScript ou C# pour les systèmes ?
GDScript itère plus vite et Guillaume peut le lire. C# donne du typage et rejoint ton .NET.
Recommandation : GDScript pour tout le prototype, quitte à basculer les systèmes lourds
plus tard s'il y a une vraie raison.

- **B:** —

### B4. Emplacement local `C:\Users\bsi\source\bg` — validé ?
À côté de `workspace` et `readreceipt`, hors du monorepo professionnel.

- **B:** —

### B5. Le dépôt s'appelle `bg` et le jeu s'appelle « Breaking Bad Game » — validé ?
L'acronyme sert de nom de dépôt pour ne pas se faire indexer sur la marque. Si tu préfères
le slug complet malgré ça, c'est ton appel et c'est noté.

- **B:** —

### B6. Tu veux des agents spécialisés travaillant en parallèle ?
Concrètement : un agent shader, un agent générateur de ville, un agent véhicule, chacun dans
une copie isolée du dépôt. Plus rapide, mais plus difficile à suivre en direct.

- **B:** —

---

## C · À trancher ensemble — le périmètre du premier jalon

**Objectif proposé, en une phrase :**

> « On conduit une voiture dans quatre blocs d'Albuquerque, de nuit, avec le rendu PS2,
> et on peut descendre du véhicule. »

Pas de missions, pas de quêtes, pas d'IA, pas de trafic, pas de police, pas de cuisine, pas de
personnage animé. Ces éléments **sont** le jeu — ils ne sont pas le premier jalon. Celui-ci sert
à répondre à une seule question : est-ce que rouler là-dedans procure déjà quelque chose ?

### C1. Cette phrase-cible est-elle la bonne ?
Si vous la changez, changez-la maintenant — pas au milieu du sprint.

- **B:** —
- **G:** —

### C2. Personnage jouable, ou capsule sans bras ni jambes ?
Un personnage animé = modélisation + rig + walk cycle + blend tree. Facilement six heures.
Recommandation : la capsule. On teste la sensation de sortir du véhicule sans payer l'animation.

- **B:** —
- **G:** —

### C3. Un seul véhicule — lequel ?
L'Aztek de Walt est la plus iconique et la plus simple : un monospace, c'est une boîte.
Le camping-car est plus emblématique mais bien plus gros, et pénible à faire tenir dans des rues.

- **B:** —
- **G:** —

### C4. Nuit confirmée ?
C'est la plus grosse économie de production disponible. Le jour exige des façades détaillées,
des ombres crédibles, un ciel. La nuit exige des lampadaires.

- **B:** —
- **G:** —

### C5. Du son dès le premier jalon, ou silence assumé ?
Un moteur en boucle plus un vent de désert changent radicalement la perception, pour environ
deux heures de travail. Ça vaut probablement le coût.

- **B:** —
- **G:** —

### C6. Qu'est-ce qui fait qu'on considère le jalon réussi ?
À définir **avant**, sinon on négocie le verdict avec soi-même à la fin.
Proposition : vous y jouez vingt minutes chacun sans vous forcer.

- **B:** —
- **G:** —

---

## D · Direction du jeu — ne bloque rien, mais ne doit pas se perdre

### D1. On joue Walter White, ou un personnage original dans son monde ?
Plus lourd qu'il n'y paraît. Jouer Walt impose la chronologie de la série et son arc.
Un personnage original libère le level design et les quêtes annexes — et réduit nettement
l'exposition juridique.

- **B:** —
- **G:** —

### D2. La chronologie suit la série, ou s'en détache ?
Suivre les saisons donne une structure de missions gratuite. S'en détacher évite la comparaison
permanente avec une série que tout le monde connaît par cœur.

- **B:** —
- **G:** —

### D3. Que fait-on de l'argent ?
Dans GTA, l'argent est décoratif. Ici il pourrait être le cœur : blanchir, planquer, dépenser
trop et attirer l'attention. C'est peut-être là qu'est la mécanique signature du jeu.

- **B:** —
- **G:** —

### D4. Niveau de recherche à la GTA, ou jauge de soupçon ?
Breaking Bad n'est pas une course-poursuite, c'est une lente montée de pression. Une jauge qui
grimpe sur des semaines serait plus fidèle — et plus originale — qu'un gyrophare.

- **B:** —
- **G:** —

### D5. Que se passe-t-il quand on échoue ?
Mort, arrestation, retour au dernier point ? Ou des conséquences persistantes, sans game over ?

- **B:** —
- **G:** —

### D6. Combien de missions principales visez-vous ?
Pas pour s'engager : pour calibrer. Cinq missions bien faites valent mieux que trente esquissées,
et ce nombre détermine la taille de ville à construire.

- **B:** —
- **G:** —

### D7. Le jeu sort un jour, ou reste entre vous ?
Une sortie sur itch.io change les priorités : build reproductible, sauvegarde solide, menu,
options, manette. À décider tôt, pas au moment de publier.

- **B:** —
- **G:** —

---

## E · Workflow Git — comment on travaille à deux sans se marcher dessus

C'est le bloc le plus ennuyeux et le plus rentable. Un projet 3D à deux meurt de conflits de
fichiers binaires bien avant de mourir d'un problème de game design.

### E1. Branches : tout le monde sur `main`, ou une branche par personne avec PR ?
À deux, `main` direct est plus fluide tant que vous ne touchez pas aux mêmes fichiers — ce qui
est le cas ici, vos domaines sont disjoints. La PR devient utile quand vous voulez vous relire.

- **B:** —
- **G:** —

### E2. `main` est-elle protégée ?
Protection = personne ne pousse en force, pas de suppression accidentelle. Coût : quelques
frictions. Recommandation : protéger contre le force-push uniquement, sans exiger de PR.

- **B:** —
- **G:** —

### E3. Guillaume : ligne de commande, ou GitHub Desktop ?
Aucune importance sur le fond. Mais autant préparer le bon outil et la bonne fiche mémo avant,
plutôt que de dépanner en plein sprint.

- **G:** —

### E4. Les fichiers `.blend` sources : dans le dépôt via LFS, ou hors dépôt ?
**Dans le dépôt (LFS)** : tout est versionné au même endroit, on peut revenir en arrière sur un
modèle. Coût : quota LFS GitHub de 1 Go gratuit, vite atteint si on itère beaucoup.
**Hors dépôt** (Drive, Dropbox) avec seulement les `.glb` exportés dans git : dépôt léger,
mais l'historique des sources est perdu et la synchro devient manuelle.
Recommandation : LFS dans le dépôt, en surveillant le quota.

- **B:** —
- **G:** —

### E5. Un `.blend` par asset, ou un gros fichier de scène ?
**Critique.** Un seul gros `.blend` partagé = conflit garanti dès que vous travaillez en même
temps, et un binaire ne se merge pas : il faut choisir une version et jeter l'autre.
Recommandation ferme : un fichier par asset, nommé clairement.

- **B:** —
- **G:** —

### E6. Rythme de commit ?
À chaque asset fini, ou en fin de session ? Les petits commits fréquents rendent les retours
en arrière indolores. Les gros commits de fin de session sont plus confortables sur le moment
et douloureux ensuite.

- **B:** —
- **G:** —

### E7. On suit les tâches dans les Issues GitHub, ou ailleurs ?
Les Issues sont dans le dépôt, gratuites, liables aux commits. Un simple fichier `TODO.md`
marche aussi et évite de changer d'outil. Ce qui compte, c'est qu'il n'y ait qu'un seul endroit.

- **B:** —
- **G:** —

### E8. On tague les builds jouables ?
Un tag `v0.1-premier-roulage` avec l'exécutable attaché : vous pouvez toujours relancer une
version qui marchait, et voir la progression. Coût : quasi nul, c'est automatisable.

- **B:** —
- **G:** —

### E9. Claude pousse directement sur `main`, ou passe par des PR que vous relisez ?
**Direct** : beaucoup plus rapide, mais du code arrive sans que vous l'ayez vu.
**Par PR** : vous gardez la main et la compréhension, au prix d'une étape de relecture.
Vu ta note sur l'effet boîte noire, la PR est probablement le bon réflexe sur tout ce qui est
système de jeu — et le direct convient pour les assets générés et les corrections mécaniques.

- **B:** —

### E10. Qu'est-ce qui n'entre jamais dans le dépôt ?
Proposition : les exports de build, les caches Godot (`.godot/`), les fichiers temporaires
Blender, et tout fichier issu de la série (image, son, vidéo) — ce dernier point est autant
juridique que technique.

- **B:** —
- **G:** —
