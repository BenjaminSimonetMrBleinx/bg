# Disclaimer

Ce projet est une **œuvre de fan, non commerciale et non officielle**, réalisée par deux
personnes pour le plaisir et l'apprentissage.

*Breaking Bad* est une création de Vince Gilligan. La série et l'ensemble des marques,
personnages, musiques et éléments qui s'y rattachent appartiennent à Sony Pictures
Television et AMC Networks. Ce projet n'est ni affilié à, ni approuvé par, ni soutenu par
ces sociétés.

## Ce que ce projet fait

Le projet utilise des éléments visuels et sonores issus de la série, à titre de référence,
de substitut temporaire et — pour certains — dans le jeu lui-même. **Aucun droit n'est
revendiqué sur ces éléments**, qui restent la propriété de leurs ayants droit.

## Engagements

- **Aucune exploitation commerciale, jamais.** Le jeu n'est pas vendu, ne comporte aucune
  publicité, aucun achat intégré et n'appelle à aucun don.
- **Développement privé.** Le dépôt n'est pas public et le jeu n'est pas distribué
  publiquement.
- **Retrait immédiat.** À la première demande d'un ayant droit, le projet et toute copie en
  circulation sont retirés, sans discussion.

## Règles pratiques pour le dépôt

**Aucun média issu de la série n'est versionné dans git** — ni image, ni son, ni vidéo, ni
police, ni logo. Ils vivent dans `assets-ref/`, ignoré par git et synchronisé entre nous par
un autre canal.

Ce n'est pas une précaution juridique de plus, c'est une contrainte technique : un fichier
commité reste dans l'historique git même après suppression. L'enlever réellement exige de
réécrire l'historique, ce qui casse les clones existants. La règle est donc simple —
**ces fichiers n'entrent jamais**, parce que l'opération est irréversible dans les faits.

Les assets créés par Guillaume, eux, sont versionnés normalement via Git LFS.
