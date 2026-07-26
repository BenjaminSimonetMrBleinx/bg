# Livraisons

**C'est ici que Guillaume dépose, et ici qu'on se parle.**

Rien de ce dossier n'est lu par le jeu. C'est un sas : ce qui est intégré part
dans `game/`, transformé par les outils, et la source reste ici.

## Le fichier qui compte : `TICKETS.csv`

**Double-clique dessus** — il s'ouvre dans Excel. Une ligne = une chose qui
manque au jeu.

| Colonne | |
|---|---|
| **Ce qu'on attend** | Le détail. Combien de fichiers, quelle durée, quel usage |
| **Où le poser** | Le dossier exact. Pose le fichier là, sans te demander où le jeu le range |
| **Statut** | `A faire` → `Livre - a integrer` → `Integre`. **C'est la colonne que tu changes** |
| **Note de Guillaume** | Ta colonne. Une question, un doute, « pas possible », « fait autrement » |

**Le cycle :**

1. `.\go.ps1` — tu récupères la dernière version, tickets compris
2. Tu déposes tes fichiers dans le dossier indiqué
3. Tu passes le statut à `Livre - a integrer`, et tu écris ta note s'il y a lieu
4. `.\livrer.ps1 "mes sons de flingue"` — ça part
5. Je relis le fichier au début de chaque session, j'intègre, et je passe les
   lignes à `Integre`

**Enregistre en CSV**, pas en `.xlsx`. Excel proposera de changer de format à
chaque sauvegarde : réponds **garder ce format**. Le CSV se relit ligne par
ligne dans git, donc on voit exactement qui a changé quoi ; un `.xlsx` est un
bloc binaire qu'on ne peut ni comparer ni fusionner à deux.

Tu peux **ajouter des lignes**. Prends le numéro suivant, et remplis au moins
**Titre**, **Ce qu'on attend** et **Priorité** — c'est de là que je pars.

## Où se pose quoi

```
livraisons/
  TICKETS.csv       ce qui manque, et ou on en est
  briefs/           les deroules de mission, les cadrages ecrits
  references/       les images de reference : decors, ambiances, lumiere
  modeles/          .glb, .obj, .fbx — personnages, vehicules, decors
    figurants/      le pack de figurants, tel que livre
  images/           textures et icones destinees a l'ecran
  sons/             LE SAS AUTOMATIQUE — voir plus bas
  voix/             les repliques enregistrees, rangees par le script
  integre/          ce qui est deja dans le jeu, garde comme source
```

## Les sons se rangent tout seuls

Pose tes fichiers dans `livraisons/sons/`, en respectant les sous-dossiers du
[brief son](../docs/04-brief-son.md) — `vehicule/`, `ambiance/`, `pas/`. Au
prochain `.\livrer.ps1` ou `.\go.ps1`, ils partent vers `game/assets/sons/`, là
où Godot les lit, et le format est vérifié au passage.

Tu n'as donc **pas** à savoir où le jeu les range. Pose et livre.

**Le dossier se vide tout seul, et c'est normal.** Ce n'est pas une perte : les
enregistrements bruts restent dans `voix/originaux/` pour les voix, et
`integre/` garde les autres sources.

## Ce qui ne va PAS ici

**Les médias issus de la série.** Ils vont dans `assets-ref/`, qui n'entre
jamais dans git. Voir [DISCLAIMER.md](../DISCLAIMER.md).

**Ce qui est généré par script.** Textures, ville, véhicules, maisons, objets,
décors de mission : tout ça sort de `outils/` et se refabrique avec
`.\bg.ps1 generer`. Ne jamais poser à la main un fichier qu'un générateur
écrase à la commande suivante.
