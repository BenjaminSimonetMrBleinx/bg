# Script d'enregistrement des voix

**Genere par `.\bg.ps1 voix -Script`. Ne pas modifier a la main** — il est
reecrit a chaque fois que les dialogues changent.

## Comment enregistrer

1. Enregistre **un fichier par ligne**, dans l'ordre ou dans le desordre.
2. Nomme-le avec son **numero** : `001.wav`, `002.wav`, `017.wav`.
   Le reste du nom est libre : `012_jesse_yo.wav` marche aussi.
3. Depose-les dans **`assets\voix\`** a la racine du depot.
4. Lance `.\livrer.ps1` — ils sont convertis, renommes et ranges tout seuls.

Tu n'as **rien d'autre a faire**. Pas de format impose, pas de dossier a
creer : n'importe quel WAV, MP3 ou OGG convient, il sera converti en 22 kHz
mono, la definition d'une PS2.

Une ligne sans enregistrement garde la voix de synthese. On peut donc en
livrer trois aujourd'hui et le reste plus tard, sans rien casser.

## Les repliques

| N° | Qui | Texte |
|---|---|---|| 001 | **Skyler** | Tu rentres tard. |
| 002 | **Walter** | J'ai fait des heures au lavage. |
| 003 | **Skyler** | Le lavage ferme a six heures, Walt. |
| 004 | **Walter** | ... |
| 005 | **Skyler** | Walter Junior a demande ou tu etais. |
| 006 | **Walter** | Je lui parlerai demain. |
| 007 | **Skyler** | C'est ce que tu as dit hier. |
| 008 | **Skyler** | Il y a du poulet dans le frigo. |
| 009 | **Walter** | Merci. |
| 010 | **Skyler** | Et il faut qu'on parle du toit. |
| 011 | **Jesse** | Yo. T'as pas frappe. |
| 012 | **Walter** | La porte etait ouverte. |
| 013 | **Jesse** | Ouais, ben. C'est chez moi, quand meme. |
| 014 | **Walter** | Il nous faut du materiel. |
| 015 | **Jesse** | Du materiel genre... combien de materiel ? |
| 016 | **Walter** | Assez pour ne pas recommencer. |
| 017 | **Jesse** | Ca sonne cher, ce truc-la. |
| 018 | **Jesse** | T'as vraiment ete mon prof de chimie ? |
| 019 | **Walter** | Deux ans. Tu as eu un D. |
| 020 | **Jesse** | J'etais present, c'est deja pas mal. |

