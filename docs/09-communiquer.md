# Comment on se parle

**Un seul endroit : les tickets du dépôt.**

👉 **https://github.com/BenjaminSimonetMrBleinx/bg/issues**

Les bugs, les idées, les features à venir, ce qu'il manque, ce qui est prioritaire, et ce
que l'assistant attend de vous. Tout. Il n'y a pas de second endroit, et c'est la seule
règle qui compte : dès qu'une information vit à deux endroits, l'un des deux ment.

---

## Les cinq portes

Le bouton **New issue** propose un formulaire selon ce que tu viens faire. Aucun ne demande
de classer quoi que ce soit — les étiquettes et l'ordre sont posés après coup.

| Tu veux… | Le formulaire | Qui s'en sert |
|---|---|---|
| Signaler que ça ne marche pas | **J'ai trouvé un bug** | Ceux qui testent |
| Proposer quelque chose | **J'ai une idée** | Tout le monde |
| Lancer une mission, un système | **Je propose une feature** | Benjamin |
| Dire qu'un fichier est prêt | **Je livre un fichier** | Guillaume |
| — | ouvert par l'assistant | quand il manque quelque chose |

### Signaler un bug

Trois questions : *qu'est-ce que tu faisais, qu'est-ce qui s'est passé, une capture ?*
Plus la version, affichée **en haut à droite de l'écran** en tout petit.

Avant d'écrire, regarde la liste : si le bug y est déjà, un commentaire « chez moi aussi »
vaut mieux qu'un doublon. Tu recevras un mail quand il sera corrigé.

### Proposer une feature

Le brief de la mission 1 a produit quinze étapes et quatre décors en une soirée. C'est le
format, et le formulaire pose les quatre questions qui comptent :

1. **Ça sert à quoi, pour le joueur ?**
2. **Qu'est-ce qu'on peut faire qu'on ne pouvait pas avant ?**
3. **À quoi on voit que c'est fini ?**
4. **Des références ?**

> **La troisième est celle qui manque le plus souvent.** Le brief de la mission 1 intitulait
> son étape 9 « Cacher la Meth » et son contenu parlait de cacher l'**argent**. Il a fallu
> trancher tout seul. Une ligne — « c'est fini quand on a planqué assez pour ressortir » —
> aurait supprimé le doute.

Ensuite, tout se passe **dans le ticket** : l'assistant répond en commentaire avec le
découpage, ce que ça coûte et ses questions. Quand c'est bâti, il ferme en expliquant ce
qui a été fait, et le brief reste attaché à la feature pour toujours.

### Livrer un fichier

Tu déposes dans `livraisons/` (voir son [LISEZ-MOI](../livraisons/LISEZ-MOI.md)), tu envoies
avec `.\livrer.ps1`, et tu ouvres un ticket **Je livre un fichier** en disant à quel besoin
ça répond. Le ticket se ferme quand c'est intégré — et tu reçois un mail.

---

## Ce que l'assistant attend de vous

Il ouvre des tickets comme tout le monde. Deux étiquettes le disent :

- **`decision`** — il est **bloqué** et attend une réponse humaine. Un arbitrage, un choix
  entre deux approches. Rien n'avance tant que personne n'a répondu.
- **`a-faire`** — il manque un fichier, un son, un modèle. Ça n'empêche pas d'avancer
  ailleurs.

Ces demandes sont reprises **en tête de la feuille de route**, et dans le texte de chaque
version publiée. C'est volontaire : un canal que personne n'a de raison d'ouvrir meurt. En
les mettant là où vous allez déjà — la page où vous récupérez le jeu — elles se lisent sans
effort.

**Règle que l'assistant s'applique :** en fin de session, ce qu'il attend devient un ticket.
Pas un paragraphe de conversation, qui disparaît.

---

## Les priorités

**Une seule étiquette : `maintenant`, plafonnée à cinq tickets.** Plus la feuille de route,
qui donne l'ordre.

Trois niveaux de priorité ne s'entretiennent pas. On l'a vérifié ici : sept tickets sur
vingt et un étaient marqués « priorité haute » deux jours après leur création. Le champ
était mort avant d'avoir servi. Une séquence, elle, s'entretient toute seule — on finit le
premier, le suivant devient le premier.

## La feuille de route

Une **issue épinglée**, en haut de la liste. Ce qui est prévu, dans l'ordre, avec le
pourquoi et une estimation. Elle remplace le fichier de backlog qui vivait ici : un
document qu'il fallait penser à ouvrir.

---

## Ce qui n'est PAS un doublon

Trois documents restent à côté des tickets, parce qu'ils ne s'adressent pas aux mêmes gens :

| | Pour qui | Grain |
|---|---|---|
| [NOTES-DE-VERSION.md](../NOTES-DE-VERSION.md) | **Celui qui teste** | Ce qu'on peut essayer maintenant |
| [docs/JOURNAL.md](JOURNAL.md) | **Celui qui développe** | Ce qu'on a appris, et pourquoi |
| Les messages de commit | **Celui qui relit le code** | Un geste |

Les fusionner produirait un document que personne ne lit.

---

## Ce qui a été supprimé, et pourquoi

`livraisons/TICKETS.csv` et `outils/tickets.ps1` ont existé une journée. L'idée — garder une
copie lisible dans Excel — était bonne, mais elle créait **une seconde interface** alors que
la demande était d'en avoir une seule. Le script n'était appelé par rien : ce qu'aucune
commande n'appelle est mort en six semaines.

`docs/09-backlog.md` disait « quand une idée arrive, elle atterrit ici », en concurrence
directe avec les tickets. Son contenu est monté dans la feuille de route, intact.
