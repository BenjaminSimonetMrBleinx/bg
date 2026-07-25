# Travailler à deux

Comment Benjamin et Guillaume avancent en parallèle sans se marcher dessus.

---

## Le fait technique qui dicte tout le reste

**Un fichier binaire ne se fusionne pas.** Un `.wav`, un `.blend`, un `.glb`,
un `.png` — git ne sait pas mélanger deux versions. Quand deux personnes
modifient le même, ce n'est pas un conflit à résoudre ligne par ligne : c'est
un des deux travaux qu'il faut **jeter**.

Tout ce qui suit découle de là. Ce ne sont pas des préférences
d'organisation, c'est la seule façon de ne pas perdre de travail.

---

## Trois voies qui ne se croisent jamais

| | Territoire | Tranche |
|---|---|---|
| **Guillaume** | `game/assets/sons/` pour l'audio, `assets/` pour les `.blend` sources | le **son** et le **look** |
| **Benjamin** | `game/systemes/reglages.tres`, le périmètre, les priorités | l'**architecture** et ce qu'on fait |
| **Claude** | `game/`, `outils/`, `docs/` | rien. Il propose, vous décidez |

Personne n'écrit dans la voie d'un autre sans le dire. `livrer.ps1` prévient
d'ailleurs quand des fichiers sortent de la voie attendue.

**Les fichiers générés** (`game/assets/`, les `.glb`, les textures produites
par les scripts) appartiennent aux générateurs, pas aux personnes. On ne les
modifie jamais à la main : ils seraient écrasés à la prochaine génération.

---

## Personne n'attend personne

C'est le point le plus important, et son absence est ce qui tue les projets
à deux.

Guillaume livre un son quand il veut ; il est câblé quand quelqu'un passe.
Une voiture provisoire est générée pour que la conduite avance ; Guillaume la
remplace trois jours plus tard sans que le code bouge. **Aucune tâche n'en
bloque une autre.**

Le générateur de ville est construit exactement pour ça : il **place des
modules sur une grille**, et l'origine des modules est un paramètre. Les
boîtes texturées d'aujourd'hui et les immeubles de Guillaume de la semaine
prochaine passent par le même chemin — `outils/gen_ville.py` ne change pas.

**Corollaire pratique :** si tu attends quelque chose de l'autre pour avancer,
c'est le signe qu'il faut un provisoire. Un placeholder laid qui débloque vaut
mieux qu'une belle chose qui arrive dans trois jours.

---

## Ce qui n'est pas parallélisable

**Juger.** Est-ce que conduire est agréable. Est-ce que la rue a la bonne
gueule. Est-ce que le son du moteur tient dix minutes sans agacer.

Ça demande d'être devant l'écran, manette ou clavier en main, idéalement à
deux. C'est le seul moment où vous devez être ensemble — et c'est aussi le
seul moment qui décide de la qualité du jeu. Le reste n'est que de la
production.

Prévoyez-le explicitement : une session de jeu commune vaut plus que deux
heures de travail parallèle.

---

## Le rythme

**Au début d'une session, chacun de son côté :**

```powershell
.\go.ps1
```

Récupère le travail de l'autre, envoie le sien s'il en a, lance le jeu.
C'est le seul point de synchronisation nécessaire.

**Pendant :** on travaille dans sa voie, sans se consulter.

**À la fin :** `.\go.ps1` à nouveau, et une ligne dans le journal.

---

## Où passent les échanges

| Quoi | Où | Pourquoi |
|---|---|---|
| Décisions ouvertes | [`00-questions.md`](00-questions.md) | Elles y restent. Une conversation se perd. |
| Ce qui s'est passé, ce qu'on a appris | [`JOURNAL.md`](JOURNAL.md) | Quatre lignes par session suffisent |
| Specs d'assets | [`03-conventions-assets.md`](03-conventions-assets.md) | Une seule source, pas un message |
| Sons à produire | [`04-brief-son.md`](04-brief-son.md) | Avec priorités et intentions |

La règle : **si une information doit survivre à la conversation, elle va dans
le dépôt.** Sinon elle sera redemandée dans trois semaines.

---

## Quand ça coince

**Conflit git.** Il ne peut arriver que si vous avez touché le même fichier.
`livrer.ps1` s'arrête proprement, n'envoie rien, et le travail reste intact
en local. Copie d'écran, et ça se démêle en deux minutes.

**Désaccord.** Celui dont c'est le territoire tranche. Guillaume sur le son
et le look, Benjamin sur l'architecture et le périmètre. Sur ce qui n'est
clairement ni l'un ni l'autre, c'est le périmètre qui prime : est-ce que ça
sert le prochain jalon ?

**Quelqu'un décroche.** Ça arrive, et ce n'est pas grave si le projet est
construit pour. Il l'est : rien ne bloque, les provisoires tiennent, et le
générateur produit un jeu complet sans aucun asset livré. Dites-le simplement
plutôt que de laisser deviner.

---

## Une règle absolue

**Aucun média de la série n'entre dans le dépôt.** Image, son, vidéo, police,
logo. Ils vivent dans `assets-ref/`, que git ignore. Un fichier envoyé une
fois reste dans l'historique même après suppression, et l'en sortir casse la
copie de l'autre.

C'est la seule chose qui ne se rattrape pas.
