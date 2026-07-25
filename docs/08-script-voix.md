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
| 011 | **Walter** | My name is Walter Hartwell White. |
| 012 | **Walter** | I live at 308 Negra Arroyo Lane, Albuquerque, New Mexico, 87104. |
| 013 | **Walter** | To all law enforcement entities, this is not an admission of guilt. |
| 014 | **Walter** | I am speaking to my family now. |
| 015 | **Walter** | Skyler, you are the love of my life. I hope you know that. |
| 016 | **Walter** | Walter Junior, you're my big man. |
| 017 | **Walter** | There are going to be some things. |
| 018 | **Walter** | Things that you'll come to learn about me in the next few days. I just want you to know that no matter how it may look, I only had you in my heart. |
| 019 | **Walter** | Good-bye. |

