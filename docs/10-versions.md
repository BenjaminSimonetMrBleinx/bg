# Les versions

Le numéro affiché en haut à droite de l'écran, et ce qu'il contient.

`MAJEUR.MINEUR.CORRECTIF`. **MAJEUR** passera à 1 le jour où le jeu se tient de bout en
bout — on n'y est pas. **MINEUR** à chaque lot livré. **CORRECTIF** pour ce qui répare sans
rien ajouter.

Le numéro vit dans `game/project.godot`, et nulle part ailleurs. `livrer.ps1` réclame de le
bouger dès que le jeu a changé.

---

## 0.10.0

**La nouvelle prise du dialogue de la cuisine.** Les dix répliques de la scène avec Skyler
jouaient encore l'ancien enregistrement.

**`-Grouper`.** Le découpage par silences rend toujours plus de segments que de répliques —
un comédien respire, et le monologue final s'est trouvé coupé en six. Le regroupement se
déclare maintenant à l'assignation au lieu de se recoller à la main dans un éditeur audio.

**Réparé** : `bg.ps1` partait fonctionnel et arrivait cassé, faute de marque d'octets ;
28 sons étaient revenus en double à la racine, dans leur version d'avant conversion ;
l'archive des prises écrasait la précédente au lieu de la conserver.

## 0.9.0

**Les sons de Guillaume, branchés.** Vingt-quatre sur vingt-huit : la roue, les objets
équipés, les portes, les portières, le klaxon, les pas, le roulement et le crissement des
pneus. Tout passe par `game/donnees/sons.json` — changer un son est une ligne de données.

**Le rangement du dépôt.** Une règle : `game/` ne contient que ce que le jeu charge. Le
dossier de dépôt devient `livraisons/`, les tests Godot deviennent `game/verifs/`.

**La version, affichée.**

**Trouvé au passage** : aucune boucle ne bouclait, depuis le début. Godot lit « détecter
depuis le WAV » par défaut et nos fichiers n'ont pas de marqueur — les trois couches moteur
repartaient de zéro à chaque fin.

## Avant

Le premier jalon, sans numéro de version : la ville, la conduite, marcher, les maisons et
leurs habitants, les dialogues doublés, la roue des outils, la visée à la souris, les
passants, le modèle sculpté de Walter. Le détail est dans [JOURNAL.md](JOURNAL.md).
