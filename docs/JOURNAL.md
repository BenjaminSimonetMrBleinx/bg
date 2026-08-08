# Journal

**Une entrée par session, avec son début et sa fin.** Chaque entrée dit quatre
choses et pas une de plus : ce qu'on voulait, ce qu'on a livré, ce qu'on a
appris, et où on reprend.

La ligne « surprise » est la plus utile des quatre : c'est celle qu'on relit
dans trois semaines, et c'est elle qui évite de repayer un piège.

Le détail technique vit dans les messages de commit ; ce qu'on peut essayer,
dans `NOTES-DE-VERSION.md` ; ce qui reste à faire, dans les tickets. Ici, on
raconte la session.

---

## Session du 8 août 2026 — le rendu laisse enfin passer le détail

**Début** : sur `v0.50.0`. **Fin** : sur `v0.51.0`, taguée et publiée.

### Ce qui était demandé

Pousser les graphismes — lumières, fluides, détails, textures — avec de vrais
modèles 3D haute définition, en restant dans l'esprit PS2 voire PS3. Et se doter
d'une chaîne de production d'assets par IA, Magnific en tête, pour alimenter tout
ça.

Curseur choisi : **fond PS3, sortie PS2**. On monte la géométrie, les textures et
l'éclairage ; on garde le SubViewport agrandi comme signature.

### Ce qui a été livré

Le socle de rendu, en entier : rendu à **960×720**, post-traitement allumé
(filmique, halo, occlusion de contact), **huit lampadaires sur 526 qui projettent**,
la lune qui porte ses ombres, les phares, le brouillard volumétrique. Plus la
cohérence des textures — l'Aztek passe de 10,1 Mo à 0,59 — et les décors de la
mission 1 qui montent de 32 px à 256, dont quatre textures générées par Magnific.

Trois outils neufs : `magnific.ps1`, `lire_glb.py`, `alleger_textures.py`.

### Les surprises, et elles sont nombreuses

**1. La 3D de Magnific n'est pas dans son API.** Douze chemins sondés, tous en
404, et le `llms.txt` de leur documentation n'en mentionne aucun. Elle n'existe
que dans le MCP — qui refuse la clé d'API : 401 en `x-magnific-api-key`, en
`Bearer` et sans en-tête. Les textures se produisent donc en ligne de commande,
mais les modèles demandent une session OAuth. **La moitié de ce qui était prévu
est bloquée par une porte différente de celle qu'on avait ouverte.**

**2. `generer` a détruit la ville, sans une seule erreur.** 519 m et 526
lampadaires sont devenus 137 m et 32, parce que `bg.ps1` a `-Blocs 2` par défaut
et que la ville du dépôt n'a jamais été générée comme ça. Le seul symptôme est
arrivé après, et de biais : un ancrage introuvable. Sauvé par `git checkout`, et
écrit en **piège 23**. Le vrai nombre de blocs n'est écrit nulle part — c'est ce
qu'il faut retrouver en premier la prochaine fois.

**3. Le jeu mélangeait du 2048 px et du 32 px.** L'Aztek et le chapeau
embarquaient des cartes de 2048 — 27 Mo à eux quatre avec les personnages —
pendant que l'intérieur du QG était texturé en 32. La charte prévenait mot pour
mot ; rien ne l'appliquait, parce que `--texture-max` valait 0 par défaut,
c'est-à-dire « ne touche à rien ». C'est maintenant 256.

**4. Un défaut qui détruit est pire qu'une erreur.** C'est le lien entre les deux
surprises précédentes, et la leçon de la session : `-Blocs 2` et `--texture-max 0`
sont tous les deux des valeurs par défaut qui font silencieusement le contraire
de ce qu'on veut.

**5. `use_nodes` ne servait plus à rien, sauf à casser la chaîne.** Onze
occurrences, un `DeprecationWarning` sur la sortie d'erreur, et `generer` qui
s'arrête. Mesuré : Blender 5.2 crée déjà le `node_tree` et son BSDF. La ligne ne
faisait plus que se plaindre. **Avant de contourner une dépréciation, vérifier si
la ligne fait encore quelque chose.**

**6. Une erreur de shader ne fait pas de bruit.** `INSTANCE_CUSTOM` n'existe que
dans `vertex()` ; le lire dans `fragment()` écrit « Unknown identifier » sur la
sortie d'erreur, et le jeu se charge quand même. Sans `bg.ps1` qui transforme le
moindre stderr en échec, ça passait inaperçu.

**7. Le coût de tout ça est nul.** 0,6 ms par image avant, 0,7 après — pour 3,5
fois plus de pixels, dix sources qui projettent et trois effets d'écran. Le jeu
n'était pas limité par les pixels, il ne l'est toujours pas. **Le budget qu'on
croyait dépenser n'a jamais existé**, et c'est ce qui autorise la suite.

**8. J'ai repayé un piège que je connaissais.** Un `Set-Content` PowerShell sur un
fichier accentué, et les tirets cadratins sont devenus du mojibake. Le piège est
écrit depuis des semaines. La parade : éditer les fichiers avec l'outil d'édition,
jamais avec PowerShell.

---

## Seconde partie — le MCP branché, et quatre instruments qui mentaient

Le MCP Magnific autorisé, la 3D s'est débloquée. Et **chaque objet produit a fait
tomber un bug** — pas dans le modèle, dans la chaîne qui le mesure.

### Ce qui a été livré

Le labo est meublé : **quatre montages de distillation** (ballon, liquide ambré,
pince, statif, condenseur — 3 990 triangles, 48 cm), **un fût et un jerrycan** au
sol, et **du verre** sur les quatorze cylindres du générateur, qui étaient des
blocs blancs opaques.

Coût : **1 660 crédits sur 20 000** pour toute la session — cinq textures, deux
images de référence, deux modèles. Un modèle revient à 655 crédits tout compris.

### Les surprises, et c'est une série

**9. L'échelle était écrasée, pas multipliée.** `obj.scale = (facteur,) * 3`
remplaçait celle que le modèle portait déjà. Invisible depuis toujours — les
modèles livrés à la main arrivent à l'échelle 1 — et fatal au premier modèle
généré, que Tripo livre à 0,4008 : demandé à 0,48 m, il sortait à 1,198.

**10. L'instrument que je venais d'écrire a désigné le mauvais coupable.**
`lire_glb` lisait les min/max des accesseurs sans les transformations de nœuds.
Il annonçait 0,998 m pour un objet de 0,400, et j'ai « corrigé » une chaîne qui
n'avait rien. **Piège 18, avec un instrument de dix minutes d'âge.**

**11. Un modèle bon peut avoir l'air raté.** Le premier montage sortait blanc et
sans détail. J'ai cherché dans le matériau, dans l'émission, dans la texture —
qui contenait bien son ambre. Il était **caché derrière les cylindres du
générateur**, à neuf centimètres près. Déplacé sur la bande avant, il se lit d'un
coup.

**12. `diag` mesurait un endroit différent à chaque appel.** Deux relevés
consécutifs : 0,7 ms et 5,0 ms, 125 et 906 appels de rendu, sans qu'une ligne ait
bougé. `monde.tscn` reprend la sauvegarde, et chaque capture joue puis sauvegarde.
J'en avais conclu qu'un shader coûtait quatre millisecondes — mesuré des deux
côtés, **il ne coûte rien**.

Et la conséquence la plus gênante : **la note de version publiée annonçait un
chiffre faux.** « 0,6 ms avant, 0,7 après » — deux mesures réelles, prises à deux
endroits différents. La conclusion tenait, les chiffres non. Corrigée : au même
point, effets coupés 3,0 ms contre 2,8 pour la 0.51.0 complète.

**13. Le verre transparent ne se génère pas en 3D.** Tripo le rend opaque. Le
ballon ne marche que parce que son liquide lui donne une couleur ; un bécher vide
serait un bloc blanc. C'est au shader de le faire, et pour zéro crédit.

**14. Une image de référence vaut UN objet.** J'en ai mis deux — le fût et le
jerrycan — et Tripo en a fait un bloc unique, impossible à séparer ou répartir.

### Le fil qui relie tout ça

**Quatre défauts sur cinq n'étaient pas dans le jeu, mais dans ce qui le mesure.**
Un outil qui annonce un nombre juste et écrit un fichier faux, un autre qui lit le
bon fichier avec la mauvaise méthode, un troisième qui mesure un endroit au
hasard. Le projet avait déjà écrit la règle — *vérifier l'instrument avant de
corriger ce qu'il dénonce* — et elle a été repayée trois fois dans la même
journée.

Ce qui les a tous attrapés : **relire ce qu'on vient d'écrire**. Le garde-fou de
hauteur dans `integrer`, `verifs/ou_est.gd` qui imprime l'emprise réelle en
coordonnées monde, le point de mesure fixe dans `diag`. Aucun n'existait le matin.

---

## Troisième partie — la minimap, et ce qui manquait n'était pas le dessin

Le ticket **#58** demandait « une minimap et qu'on puisse voir où aller ». Livré
en **0.51.2**, taguée et publiée.

Un disque en bas à droite, le joueur au centre, **les rues tracées par les
lampadaires** — ils les bordent, donc les semer sur le disque dessine le réseau
sans avoir à produire ni resynchroniser une carte. Le plan tourne avec la caméra.
L'objectif est un point jaune qui **se colle au bord en pointe** quand il est hors
de portée : le désert est à neuf cents mètres, trente fois hors du disque, et un
marqueur qui disparaît ne sert qu'à l'endroit où on n'en a plus besoin. Aucun
chiffre nulle part.

### Ce qui a vraiment coûté

**Pas le dessin — la donnée.** Une étape dit ce qui la **valide** : un dialogue,
une zone, un objet ramassé. Aucun de ces évènements ne porte de position, et
`dialogue:mission_jesse_maison` n'a pas à savoir où habite Jesse. Chaque étape a
donc un champ `ou`, **écrit à la main plutôt que déduit** : une table de
correspondance évènement-vers-nœud cachée dans un script serait exactement ce que
`mission1.json` existe pour éviter.

**15. Le symptôme d'une cible fausse est une absence.** Une cible mal nommée ne
casse rien : pas de marqueur — soit exactement ce que fait une étape sans cible.
Deux causes, un seul symptôme, et le symptôme est que rien ne s'affiche. D'où
`test_boussole`, qui vérifie que les quinze étapes visent un nœud existant **et
imprime sa position**. Il a servi tout de suite : `find_child` rend le *premier*
nœud du nom demandé, il y a deux « Sortie » et plusieurs « Porte » dans le jeu, et
l'étape du QG visait une porte du désert à six cents mètres de Tuco.

**16. La sauvegarde du poste est toujours à la dernière étape.** Chaque capture
joue puis sauvegarde : la mission finit inévitablement terminée, donc sans
objectif, donc sans marqueur. Aucune image ne pouvait montrer une mission **en
cours**. `Mission.aller_a()` existe pour ça — la leçon du piège 22 sous une autre
forme : ce qui se mesure et ce qui se joue ont besoin de portes différentes.

**17. Le téléphone se posait pile sur la minimap.** Il s'ouvre tout seul au
changement d'étape et en recouvrait les trois quarts. Elle se cache maintenant
sous tout ce qui passe devant. Vu à la première capture, pas au premier essai en
jeu — et c'est bien pour ça qu'on capture.

### Où on reprend

1. Les tickets **#56** et **#57**, les deux suites qui échouaient déjà avant.
2. Le décor du **QG de Tuco** est le prochain à meubler : lambris texturé, mais un
   seul homme sur trois et un placeholder blanc sur le bureau.
3. Les textures de **ville** peuvent maintenant monter en 256 : le nombre de blocs
   est retrouvé, `generer` n'est plus dangereux.
4. Le **relevé de coût varie de 2,4 à 4,2 ms** d'une exécution à l'autre au même
   point. Le bruit est plus grand que la plupart des effets qu'on mesure : c'est
   la prochaine chose à resserrer si l'on veut trancher un jour sur un
   millième.

### Le bilan

Longue session, deux incidents sérieux — la ville détruite, une affirmation fausse
publiée — tous deux rattrapés. Ce qui a le mieux marché : refuser de conclure sans
une image ou un nombre, et **remesurer quand deux nombres se contredisent** plutôt
que de choisir celui qui arrange. Ce qui a manqué : vérifier ce qu'une commande
allait faire avant de la lancer sur tout le dépôt, et un `Set-Content` PowerShell
sur un fichier accentué alors que le piège est écrit depuis des semaines.

---

## Session du 7 aout 2026, deuxieme partie — la premiere fois qu'on JOUE

**Début** : sur `v0.48.13`. **Fin** : sur `v0.50.0`, trois releases plus loin.

### Ce qui était demandé

Tester la mission 1 manette en main, puis fusionner deux choses qui existaient
séparément : l'appel de Skyler, éprouvé dans une mission de test, et la boucle
des courses, livrée le soir même.

### Ce qui est livré

| Version | Quoi |
|---|---|
| **0.48.14** | La cachette se voit et se trouve ; le klaxon s'entend |
| **0.49.0** | **#53** — Skyler appelle pendant qu'on roule vers le désert. `F` décroche, `T` raccroche, laisser sonner coûte cinq points. Arriver avec les courses coûte une réputation, et Jesse comme Tuco le remarquent |
| — | **#47** — la sauvegarde ne gardait que l'argent et l'heure. Trois liens manquaient dans la scène |
| **0.50.0** | **#20** — le puits économique : cuisiner, livrer, être payé, recommencer. Le prix suit la pureté |

Les formulaires de tickets ont aussi été remis d'aplomb, et tous les liens du
dépôt corrigés — ils pointaient encore vers le dépôt **pro** d'avant le
transfert, y compris le corps de chaque release publiée.

### Les surprises

**Trois parcours de test sur trois, sans un défaut.** Tout ce qui avait été livré
à l'aveugle dans la journée s'est révélé juste manette en main. C'est la première
fois de ce projet.

**Le seul blocage n'était pas une régression : la cachette n'avait jamais été
trouvable.** Aucune planche à l'écran, posée au milieu du vide, dans un salon de
quatorze mètres sur dix — alors que le tuto annonce « une latte du mur n'est pas
comme les autres ». Troisième fois cette semaine que la même leçon se paie :
**une adresse exacte que rien ne signale n'est pas une adresse.**

**La sauvegarde ne gardait que la moitié depuis quinze versions.** L'argent et
l'heure revenaient ; ni l'inventaire, ni la position, ni l'avancement. Ce qui a
masqué le trou pendant si longtemps : **la moitié qui marchait était la moitié
qu'on regarde** en relançant.

**Le klaxon ne s'entendait pas, et ce n'était pas le code.** Le fichier est
enregistré six fois plus bas que les autres. Mesuré, pas deviné — et quatorze
sons sur soixante-quatre sont dans le même cas.

**Un faux diagnostic, et il était de moi.** Un bug « on ne peut pas courir »
ouvert sur une liste d'actions que ma propre commande avait tronquée. On court
très bien. **Une absence ne prouve rien tant que la recherche n'est pas
complète** — c'est passé dans `CLAUDE.md`.

### Où on reprend

**#55** : reprendre une partie ne dit pas où l'on arrive — revers de la
sauvegarde réparée. À vérifier en premier : reprend-on **dans** sa voiture ou à
côté ?

**La passe d'organisation, demandée et pas faite.** Le classement était prêt
— trois « maintenant », cinq « ensuite », le reste en feuille de route — et mis
de côté pour traiter des tickets plutôt que les archiver. Restent à écrire : la
feuille de route, la méthode et la fiche de test.

**Les sept chantiers de code restants n'attendent aucun code**, mais des choix :
les précurseurs, où vivent Junior et Hank, ce que voient les témoins, les quatre
missions du palier 2. Les trancher seul, c'est livrer un jeu que Benjamin
découvrirait.

**Et les nombres de ressenti n'ont jamais été joués** : vingt secondes avant
l'appel, cinq points pour le retard, trois cents dollars la livraison.

---

## Session du 7 aout 2026, premiere partie — un remede qui dormait a cote du malade

**Début** : 07/08, sur `v0.48.10`. **Fin** : sur `v0.48.13`, trois releases
publiées après deux jours de silence.

### Ce qui était demandé

Reprendre par #48, comme le journal de la veille le disait : la mission de Tuco
est cassée depuis l'ouverture du désert. Puis, une fois #48 clos, finir #51 — le
camping-car de Guillaume, jamais intégré.

### Ce qui est livré

**0.48.11**, en deux lots, et un ticket ouvert exprès pour ne pas mélanger les
deux :

| Lot | Quoi |
|---|---|
| **#48** | `Pnj` a un garde-fou de mission. Jesse se tait tant que rien ne l'a amené au camping-car |
| **#50** | Jesse, la porte et la sortie du désert s'ancrent sur les lieux publiés au lieu de les recopier. Trois distances mesurées par le test |
| — | Les situations de capture du camping-car se posent **autour** du véhicule (`autour` dans `scenarios.json`) |
| — | **Release `v0.48.11` publiée**. La dernière datait du 5 août en 0.40.0 : Guillaume téléchargeait un jeu sans les trois compteurs, sans écran-titre et sans sauvegarde |
| **#51** | **0.48.12** — le camping-car de Guillaume entre dans le jeu, dégraissé à 8 000 triangles ; `integrer` sait désormais dégraisser ; le générateur ne fabrique plus de camping-car |
| **#49** | **0.48.13** — l'épicerie vend (4 $, un son, une boîte d'œufs) et la cuisine compte : les points de famille ne tombent qu'en posant la boîte sur le plan de travail, et Skyler répond dans les deux cas |

Côté tickets : **#48, #49, #50 et #51 fermés**, **#52 ouvert** pour Guillaume
(la tôle du camping-car ondule à la source).

### Les surprises

**Un ticket peut décrire cinq pannes et n'en contenir qu'une.** #48 en listait
cinq. Un seul symptôme venait de l'ouverture du désert ; trois avaient une cause
commune vieille de huit jours, et le cinquième n'était pas une panne mais un
travail jamais fait. **Vingt minutes de diagnostic ont évité de refermer le
désert pour rien.**

**Le code annonçait sa propre panne, en majuscules.** Deux fichiers écrivaient
noir sur blanc que ces coordonnées ne devaient jamais être recopiées, et ce qui
arriverait si on le faisait. C'est arrivé : Jesse est resté vingt-neuf mètres
derrière le camping-car, au milieu de la piste. Deuxième session d'affilée où un
commentaire prédit une panne et se lit comme une décoration.

**Le remède dormait à côté du malade.** `ancrage.gd` faisait déjà exactement ce
qui manquait, pour la ville, et son en-tête racontait la même histoire payée
deux fois. Le désert avait la maladie et pas le remède, à un champ près.

**Trois vérifications regardaient à côté, et elles étaient au vert.** Un test qui
se téléportait sur la sortie avant de vérifier qu'on peut sortir. Une capture qui
photographiait du sable à vingt-neuf mètres de son sujet. Et la même, recalée,
posée à la verticale exacte — une image sans haut ni bas. Troisième soirée
d'affilée qu'un instrument de ce projet se révèle aveugle.

**Le camping-car de Guillaume n'avait jamais été dans le jeu.** Il dormait dans
`livraisons/` depuis des semaines pendant que deux commentaires du code
affirmaient le contraire. **Un commentaire qui décrit un asset se périme sans
bruit** : personne ne le relit pour vérifier qu'il est encore vrai.

**Guillaume attendait un exe qui n'existait pas.** Onze versions bumpées sans
jamais être taguées : il téléchargeait un jeu sans écran-titre ni sauvegarde,
pendant que trois de ses tickets 🔥 attendaient qu'il voie ce qui existait déjà.

**Le budget d'un asset se mesure, il ne se décide pas.** 17 828 triangles livrés
pour un budget de 2 000, et aucune bonne réponse sur le papier. Cinq niveaux
posés côte à côte sur le banc graphique — un outil qui existait et n'avait jamais
servi à ça — ont tranché en une image : sous 4 000 la carrosserie se froisse, et
**à partir de 8 000 la silhouette cesse de bouger**. Huit fois le poids pour rien
au-delà. Aucun des trois faits n'était devinable.

**Une image et un test se sont contredits, et les deux avaient raison.** La
capture montrait Walter dehors ; le test le disait dans la tôle. La physique
l'avait éjecté avant la prise de vue — **l'image montrait où il finit, pas où on
l'avait mis.** Quand les deux se contredisent, ils ne répondent pas à la même
question, et il faut trouver laquelle avant de corriger.

### Où on reprend

**Une manette, d'abord.** Rien de ce qui a été livré n'a été joué : la mission de
bout en bout, le trajet épicerie → maison, le refus quand on n'a pas les quatre
dollars. Les tests couvrent la mécanique, jamais le plaisir qu'il y a — ou pas —
à faire ce détour.

**À surveiller :** la chaîne d'intégration ne dégraisse que si on le lui demande,
et le prochain modèle livré passera au budget de son auteur si personne n'y
pense. Les deux réactions de Skyler n'ont pas de voix — la maison est le seul
endroit du jeu où l'on parle sans entendre personne. Et `bg.ps1 generer` est
inutilisable sur cette machine faute de Python : le contournement est connu, pas
câblé.

---

## Session du 6 au 7 aout 2026 — les trois compteurs, et cinq instruments qui mentaient

**Début** : 06/08, sur `v0.43.0`. **Fin** : sur `v0.48.10`, onze versions plus tard.

### Ce qui était demandé

Reprendre les tickets un par un, comme la veille. En cours de route, la session
a changé de nature deux fois : d'abord des outils, puis une décision de
direction qui renverse la règle numéro un du projet.

### Ce qui est livré

| Version | Quoi |
|---|---|
| **0.44.0** | L'écran-titre passe par le rendu du jeu — il était plus net que sa propre première image |
| **0.45.0** | Un menu d'**outils de test** dans la pause : onze gestes qui évitent une relance |
| **0.46.0** | Aller à un lieu nommé (45 destinations), traverser les murs et voler |
| **0.47.0** | Relevé de performance en direct, densités foule/trafic, collisions et repères visibles |
| **0.48.0** | La **pureté** : cinq paliers, une couleur dans la main, aucun chiffre |
| **0.48.1** | Les **points de famille**, affichés en permanence |
| **0.48.2** | La **réputation de rue** — les trois compteurs sont à l'écran |
| **0.48.3** | Une épicerie, première façon de faire remonter la famille |
| **0.48.4** | « Un simple service » : la mission de test des appels |
| **0.48.5 → .10** | Cinq corrections successives sur cette mission, chacune revelant un vrai défaut du jeu |

Côté tickets : **#33 fermé** (fausse alerte), **#46 créé et fermé** (les outils),
**#30 fermé** (les trois ressources), **#21, #22 et #28 supprimés**, **#47, #48
et #49 ouverts**. Et deux tickets sortis de 🔥 parce qu'ils attendaient autre
chose qu'eux-mêmes.

### Les surprises

**Un instrument peut mentir avec l'aplomb d'un chiffre.** Le relevé de coût
annonçait un effondrement du jeu : pire cas tombé à 7 images/seconde, 16,5 ms de
scripts par image. Le jeu tournait en réalité avec **vingt-six fois la marge
nécessaire**, zéro image ratée sur quinze mille. Trois compteurs mal lus, aucun
bug : le compteur d'images du moteur ne se rafraîchit qu'une fois par seconde,
`TIME_PROCESS` est un **maximum de la seconde écoulée** et pas un temps de
scripts, et une seconde de chauffe laissait la compilation des shaders dans la
mesure. C'est le piège 18, et il donne son revers à la règle d'or du projet :
*une image ou un nombre, jamais une conviction* — **mais un nombre n'est une
preuve que si on a lu le code qui le produit.**

**Cinq tickets décrivaient un travail déjà fait.** L'Aztek amélioré était
intégré depuis le 5 août. Les voix de la mission 1 existent (113 fichiers de
synthèse). Les sons de pas des piétons aussi (17 fichiers) — ce qui manque,
c'est que `pieton.gd` ne les joue jamais. Un ticket ouvert n'est pas un travail
à faire ; c'est parfois un travail déjà fait que personne n'a coché, et on l'a
repayé cinq fois en une soirée.

**Deux vérifications avaient cessé de vérifier.** Depuis que l'écran-titre est
devenu la scène d'entrée en 0.43, `verif` validait `monde.tscn` en dur — la
vraie porte du jeu n'était contrôlée par personne — et `capture` photographiait
le menu au lieu de sa situation, en écrivant un PNG parfaitement valide. Rien ne
le signalait. **Une vérification qui ne suit pas un réglage rassure à côté.**

**La règle numéro un a été renversée, et c'est écrit.** Le projet disait
qu'aucun chiffre ne se montre au joueur. Les trois ressources — argent, famille,
réputation — s'affichent désormais en permanence, parce que ce sont des comptes
à rebours qu'on surveille en conduisant. `docs/12-direction.md` et `CLAUDE.md`
portent l'exception, sa raison et sa borne : la pureté reste une couleur dans la
main. Une règle qu'on change sans l'écrire devient une règle qu'on enfreint sans
le savoir.

**Le premier appel pris au volant a révélé un trou de quatre ans.** Le
contrôleur fait capter la touche d'interaction par une conversation en cours
dans trois états — à pied, dans une maison, au téléphone — et **pas au volant**.
Personne ne l'avait vu parce qu'aucun dialogue ne se déclenchait en conduisant.
Le premier est resté bloqué sur sa première réplique, pendant que le même `F`
essayait de faire descendre Walter de sa voiture.

**Cinq allers-retours sur la même mission, et pas un pour rien.** Chaque essai a
sorti un défaut du jeu et pas de la mission : l'appel comptait depuis le début
de la mission au lieu de la conduite ; `F` éjectait de la voiture ; aucun
dialogue ne pouvait avancer au volant ; `Audio.bruit()` ne rend pas de poignée,
donc **un son ne peut pas être coupé** — le téléphone continuait de sonner après
qu'on avait décroché ; et une parcelle du générateur n'est pas une adresse — sans
enseigne, l'épicerie était introuvable. **Jouer trouve ce que tester ne trouve
pas.**

**Un garde-fou retiré en le citant.** Le passage vers le désert était fermé tant
que la mission 1 n'y envoyait pas, et son commentaire disait mot pour mot ce qui
arriverait sans lui : *« on pouvait filer au camping-car dès la première minute,
y trouver un Jesse qui reproche un retard à une mission pas encore commencée »*.
Il a été retiré à la demande, en recopiant cette phrase, sans en tirer la
conséquence. Elle est arrivée dans la minute. **Un commentaire qui prédit une
panne mérite d'être lu comme un avertissement, pas comme une décoration.**

**Deux fausses manœuvres, dites plutôt que tues.** Un `git stash pop` non abouti
a laissé une heure de travail dans le stash le temps d'un tour — récupérée
intégralement. Et un commentaire de ticket posté sous le **compte pro** sur un
dépôt perso public : supprimé, reposté du bon côté, et le remote est passé sur
l'alias SSH perso pour que ça ne se reproduise pas.

**Un board se lit, ou ne se lit pas.** En fin de session, passe complète sur les
vingt-sept tickets : trois fermés (l'Aztek était livré depuis deux jours, la
sauvegarde et la finition étaient finies pour ce qu'elles pouvaient être), et
**vingt-deux titres refaits**. Ils mélangeaient quatre formes — un nom, une
question, une phrase, une opinion — et se lisaient bien une fois, jamais deux.
La forme est désormais fixée dans `CLAUDE.md`. Ce que la passe a montré, et
qu'aucun ticket ne disait : **neuf tickets sur vingt-quatre attendent Guillaume,
trois attendent une décision de Benjamin.** La moitié du board n'attend pas du
code, et les deux chantiers qui débloqueraient le plus — #36 et #43 — n'ont
jamais été ouverts.

### Où on reprend

**#48 d'abord** : la mission de Tuco est cassée depuis l'ouverture du désert.
Jesse parle hors contexte, il est mal placé, on n'entre plus dans le camping-car,
le modèle affiché n'est peut-être pas le bon, et la sortie du désert pose
problème. La correction n'est pas de refermer la porte — c'est de donner à `Pnj`
le garde-fou de mission que `Point` a déjà, et de faire taire Jesse tant que rien
ne l'a amené là. Les quatre autres symptômes sont peut-être antérieurs : à
vérifier avant de conclure.

**Puis #49** : l'épicerie est encore un bouton qu'on peut marteler. Elle doit
devenir une vraie course — quatre dollars, une boîte d'œufs dans l'inventaire,
les points donnés **en rentrant**, et Skyler qui réagit selon qu'on a pensé à
elle ou non.

**En attente ailleurs** : #47 (l'objet tenu ne revient plus après une reprise —
régression pré-existante, la moitié du critère de fin de #32), un système de
**dialogue à choix** qui n'existe pas et que réclament #31, #35 et #29, et dix
tickets jamais passés en revue (#34 à #45). Guillaume : les rigs de passants, les
voix, le formulaire de mission.

---

## Session du 6 aout 2026 — sauvegarder, reprendre, et un ecran-titre

**Début** : 06/08, sur `v0.40.0`, dépôt propre et outillage enfin en place.
**Fin** : sur `v0.43.0`, trois versions livrées et un verbe d'outil de plus.

### Ce qui était demandé

Reprendre le traitement des tickets, cette fois du vrai code de jeu — et le
faire un par un, chaque ticket validé avant d'être démarré.

### Ce qui est livré

| Version | Quoi |
|---|---|
| **0.41.0** | On peut **sauvegarder et reprendre** (#32 lot 1) : heure, argent, inventaire, position, mission. On sauve en quittant et à la fin d'une mission ; au lancement, une partie existante reprend seule |
| — | Le jeu s'ouvre sur le **second écran** (`bg.ps1 jouer`), pour ne pas recouvrir l'éditeur |
| **0.42.0** | **Mourir recharge le dernier point** (#32 lot 2) au lieu de repartir de zéro ; l'argent gagné depuis est perdu |
| **0.43.0** | Un **écran-titre** (#40 lot 1) : Nouvelle partie / Reprendre / Quitter, avec confirmation avant d'écraser |
| — | Un verbe **`bg.ps1 diag`** pour relever le coût de la ville (#33) |

### Les surprises

**Le pre-flight a évité deux fausses routes.** Avant de coder chaque ticket, on
a cadré — et deux se sont révélés déjà faits : **#18** (Tuco est assis depuis un
moment, vérifié à la capture) et **#33** (la règle « plafonner et recycler » est
déjà appliquée, l'outil de diag existe déjà). Un ticket ouvert n'est pas un
travail à faire ; parfois c'est un travail déjà fait que personne n'a coché.

**Recharger une partie n'est pas refaire les gestes.** Le premier test de
sauvegarde a échoué sur une seule chose : le chapeau ne revenait pas sur la
tête. `_demander_le_port` pose le port après un **délai** — c'est une animation,
juste pour le geste joué. À la restauration on écrit l'état directement : on
retrouve le chapeau dessus, on ne le remet pas cran par cran.

**Le relevé frais a fait exactement son travail.** `bg.ps1 diag` sur la 0.43 a
sorti un chiffre qui prévient : **7 images/seconde au pire, 8 images ratées sur
180, 16,5 ms de scripts par image — et zéro passant.** La moyenne (58) allait
bien ; c'est le pire cas qui s'est effondré depuis le décor d'Albuquerque. C'est
tout l'intérêt d'un instrument : il dit ce que la moyenne cache.

**Un type non inférable plante tout, en silence jusqu'à ce qu'on regarde.**
`var etiquette := ... if ... else liste[i]` — `liste[i]` est un Variant, donc le
type ne s'infère pas, et GDScript refuse de compiler le fichier ET tous ceux qui
en dépendent. Le lanceur ne montrait qu'une bannière ; il a fallu lancer le
script en direct pour lire l'erreur. Type explicite, et c'est réglé.

### Où on reprend

**L'à-coup perf est le premier fil à tirer** : 7 im/s au pire, 16,5 ms de
scripts par image avec 0 passant — documenté sur #33, à profiler (décor
d'Albuquerque ? rafraîchissement jour/nuit ?). À part ça : les lots suivants de
#40 (écran de chargement, cartons de chapitre, générique, bilan d'acte) et de
#32 (dormir pour sauver ; pureté/famille/réputation quand elles existeront).
Décisions toujours en attente de Benjamin : **#30** (comment on gagne la
réputation) et **#38** (musique). Guillaume : rig des passants (#16), voix (#5),
formulaire de mission (#37). Et un fil ancien : les suites `tenue de route` et
`sons` échouent sur ce poste **même sur le code propre** — pré-existant, à
creuser.

---

## Session du 5 au 6 aout 2026 — le depot demenage, l'outillage arrive, et le suivi se remet d'aplomb

**Début** : 05/08 au soir, sur `v0.40.0`. **Fin** : 06/08 au petit matin, même
version — c'est une session d'infrastructure, d'outillage et de tickets, pas de
game code. Rien de jouable n'a changé, donc pas de bump.

### Ce qui était demandé

Reprendre le projet côté perso, donner aux gens un lien propre pour télécharger
l'exe, puis remettre les tickets d'aplomb — et en traiter.

### Ce qui est livré

| | |
|---|---|
| **Le dépôt** | Transféré sur le compte perso `benjibleinx-perso/bg`, public. L'ancienne URL redirige, les liens existants tiennent |
| **La release** | `v0.40.0` publiée — les versions 0.37→0.40 étaient codées mais jamais sorties. Le lien de download est enfin celui du code actuel |
| **Les docs** | Journal rattrapé jusqu'à 0.40, doublon 0.37.0 des notes retiré, cadrage corrigé (dépôt public assumé) |
| **Les tickets** | #23/#24/#25 soldés (déjà faits à 0.28→0.40), #44 et #45 pour les vrais résidus, quatre décisions consignées, et un grooming complet : trois familles d'étiquettes, un seul *qui* par ticket, et un label **🤖 Claude** pour ce sur quoi j'avance seul |
| **L'outillage** | Godot 4.7.1 et Blender 5.2.0 installés sur cette machine, chaîne vérifiée |
| **#18** | Tuco assis : vérifié à l'image, il l'était déjà. Fermé |
| **#19** | `project.godot` ne relance plus les 27 suites quand seule sa carte d'entrées change — 9 au lieu de 27. Plus un `-Lister` pour voir la sélection sans jouer |

### Les surprises

**Le dépôt vivait sur le compte GitHub pro.** Un projet perso hébergé du mauvais
côté de la séparation. Le transfert l'a remis où il faut, et comme il préserve
tout — historique, issues, releases, LFS — et redirige l'ancienne URL, personne
ne casse un lien au passage.

**Les retours de test étaient faits, mais jamais fermés.** #23, #24, #25
listaient soixante points ; la quasi-totalité avait été livrée entre la 0.28 et
la 0.40, sans que le ticket bouge. *Un ticket ouvert n'est pas un travail à
faire — c'est parfois un travail déjà fait que personne n'a coché.* On les a
soldés en croisant chaque point avec sa version.

**Cette machine n'avait pas le toolchain.** Godot et Blender nulle part : c'est
la machine miroir, celle qui sert au git et à l'admin. Tout ce qu'on a fait ce
soir avant l'install ne demandait pas le jeu — et c'est justement pour coder
ET vérifier qu'on l'a posé ici.

**#18 était périmé.** Tuco est assis depuis un moment : le clip `Assis` est
fabriqué par le solveur, présent dans `tuco.glb`, branché. La règle d'or a
tranché — capture `qg_bureau`, il est bien calé dans son fauteuil — là où une
conviction aurait laissé le ticket ouvert ou l'aurait fermé à tort.

**Le correctif de #19 a failli être défait par sa propre mesure.** On compare
`project.godot` à HEAD, section `[input]` retirée, pour savoir si seule la carte
d'entrées a bougé. Sauf que `Get-Content -Raw` lit le fichier en CP-1252 et
`git show` sort de l'UTF-8 : les tirets cadratins des commentaires, *hors*
`[input]`, cassaient l'égalité à tous les coups, et `project.godot` aurait
continué de relancer les 27 suites en silence. C'est le piège UTF-8 de
PowerShell 5.1, encore lui. Trouvé parce qu'on a mesuré « identiques ? » au lieu
de le croire.

**`tir.gd` n'était couvert par aucune suite.** Trouvé en vérifiant #19 : modifier
le système de visée et de tir ne déclenchait aucun test. Rattaché à la suite
`mission`, qui charge et câble le signal du tir. Le comportement du tir
lui-même — viser, toucher, la riposte — n'a toujours pas de test qui tire
vraiment : c'est un cran au-dessus, noté.

### Où on reprend

Deux décisions attendent, et elles débloquent le socle : **#30** — comment on
gagne la réputation (Benjamin + Guillaume) — et **#38** — la musique (Benjamin).
Guillaume a trois choses en 🔥 : le rig des passants (#16), les voix (#5), le
formulaire de mission (#37). Côté code autonome, le prochain chantier propre et
sans dépendance est **#32** (sauvegarder et reprendre) ; le puits économique
(#20) reprendra une fois #30 tranchée. La page Issues, elle, dit maintenant d'un
coup d'œil quoi, pour qui, et quand.

---

## Session du 31 juillet au 2 aout 2026 — de 0.36.0 a 0.40.0

**Début** : 31/07, dans la foulée de la release `v0.36.0`. **Fin** : 02/08 sur
`v0.40.0`. Trois soirées, cinq versions — entrée écrite après coup, à partir des
commits, pour que le journal rejoigne le code.

### Ce qui était demandé

Rapprocher la ville de ses vraies références d'Albuquerque ; casser le damier
trop régulier ; donner une voiture héros à Jesse ; intégrer le nouveau Walter
livré par Benjamin ; et donner à l'interface l'identité de la série. Plusieurs de
ces demandes sont arrivées en cours de route, formulées devant l'écran — « tes
modèles sont très cubiques », « c'est encore trop carré », « pour les voitures,
218 ça va pas, c'est moche ».

### Ce qui est livré

| Version | Quoi |
|---|---|
| **0.37.0** | Albuquerque d'après 56 photos : palette sans gris froid, ouvertures **creusées** dans le bâti, quatre gabarits de pavillon, parapets, maisons de plain-pied à garage, végétation xeriscape, câbles qui traversent les rues, banquette de gravier et caniveau |
| **0.38.0** | La trame n'est plus au cordeau (îlots de 30 à 64 m, carrefours non équidistants, super-îlots), les immeubles ne sont plus des boîtes (devanture, auvent, décrochement, fouillis de toit), et Jesse s'affaisse au lieu d'attendre au garde-à-vous |
| **0.39.0** | Le Walter v2 de Benjamin et ses quatre animations livrées — marcher, courir, sauter, remettre ses lunettes |
| **0.40.0** | L'interface prend l'esthétique de la série : portrait en case de tableau périodique, barre de vie segmentée, cadran de vitesse, rappel de l'objet tenu, trois couleurs |

Hors versions : un **banc de comparaison graphique** dans le désert (trois
niveaux de détail côte à côte), la **Monte Carlo de Jesse** modelée d'après
photo, un outil qui **trace la silhouette d'un véhicule depuis une image**, et
l'analyse complète des références rangée dans `docs/16-albuquerque.md`.

### Les surprises

**Deux instruments faux, l'un derrière l'autre — et cinq conclusions tirées de
leurs images.** Le report de la démarche sur les figurants sortait un corps
disloqué, et j'ai cherché le défaut dans l'animation pendant une soirée. Il était
ailleurs, deux fois : l'aperçu de modèle cadrait sur la boîte englobante du
maillage — la géométrie *avant* déformation par le squelette — donc montrait un
sujet minuscule et décentré ; et l'export du report **embarquait les neuf actions
de Walter**, que Blender écrit toutes qu'elles soient assignées ou non. On
jugeait un report en regardant les rotations brutes de Walter posées sur un autre
rig. Une fois les deux instruments réparés — l'aperçu mesure maintenant la
géométrie réellement rendue et **imprime l'encombrement**, ce qui dit sans image
si un corps est debout — la mesure a désigné le vrai coupable : la pose de
liaison du figurant est **couchée**, 0,21 m de haut pour 1,60 de long. Le défaut
est à l'import, pas dans l'animation. *Aucun report ne réussit sur un modèle dont
la liaison est cassée.*

**« Casser PAS » : essayé, mesuré, annulé le jour même.** Rendre les îlots
irréguliers a sorti une ville juste — mais le jeu n'a pas suivi. Mesure sur
vingt-six passants : quinze sur le trottoir, **six sur la chaussée, trois dans le
désert**. Deux hypothèses éliminées avant de trouver la cause, structurelle et
côté jeu : `foule.gd` publie un seul écart de trottoir pour toute la ville, et
`pieton.gd` borne la ville par une seule étendue carrée — deux raccourcis qui
mentent dès que les rues changent de largeur. Le remède touche `pieton.gd` et
`foule.gd` avec leurs tests : pas un travail de fin de session. On a gardé les
**super-îlots**, qui cassent déjà le damier sans rien demander au jeu — 80 % de
l'effet pour 10 % du risque. Le raisonnement est dans `docs/16-albuquerque.md`,
pour que le prochain parte de la mesure.

**Le « Minecraft » n'était pas le nombre de faces.** « Tes modèles sont très
cubiques » — et la cause n'était pas la géométrie mais que *tout était dans le
même plan* : une porte peinte sur une face plate ne porte aucune ombre. Les
ouvertures sont devenues de vrais trous avec leurs quatre retours, et **la maison
qui a levé l'objection fait moins de faces que celle qu'elle remplace**. Le
réalisme est venu de la profondeur, pas des polygones. La Monte Carlo l'a redit
dans l'autre sens : ses sections étaient des rectangles, donc quatre arêtes vives
couraient sur toute la caisse — et aucune quantité de polygones ne rattrape une
arête. Il a fallu des sections *galbées*, un congé au rayon variable, pour que la
carrosserie cesse d'être une savonnette.

**Identifier un clip livré en le mesurant.** Deux des quatre animations de Walter
v2 arrivaient sans nom, avec des UUID : le bassin qui monte de 116 mm est le
saut, une main à 193 mm de la tête sans que le bassin bouge est les lunettes.
Vérifié ensuite sur planche de contact. Au passage, un piège d'export :
l'exportateur glTF n'écrit que les actions **rattachées** à quelque chose, et un
clip s'était volatilisé sans un mot — une piste NLA par action les retient
toutes. Et une règle posée pour de bon : **un clip livré prime sur un clip
fabriqué**, et une régénération ne peut plus l'écraser en silence — c'est
exactement ce qui était arrivé au Jesse de Guillaume.

**Enfin pouvoir juger une animation.** Une image fixe dit si un corps tient
debout, jamais s'il bouge bien — c'était la raison de fond de mes échecs en
animation, contournée deux sessions durant au lieu d'être réglée.
`outils/planche_animation.py` rend huit poses d'un même cycle côte à côte, comme
les poses extrêmes d'un animateur. Il a tranché en une seconde sur le repos de
Jesse : huit images identiques d'un homme au garde-à-vous.

**Un avertissement qu'on apprend à ignorer.** « Aucune voix pour ? » s'affichait
à chaque lancement — l'appelant inconnu du téléphone, muet depuis toujours,
quatre répliques sans son. Trouvé en lisant le journal de la session de test.
*C'est la troisième fois que le projet paie cette règle :* un avertissement qu'on
ignore est un avertissement qu'on n'ira pas lire le jour où il compte.

### Où on reprend

**Les passants sont à zéro depuis la 0.38.0**, désactivés le temps de casser la
trame — c'est le premier chantier de reprise : publier l'écart de trottoir par
tronçon et remplacer le bornage carré par un test contre la géométrie réelle
(`pieton.gd`, `foule.gd`), tout est écrit dans `docs/16-albuquerque.md`. Ensuite :
mettre Skyler, Jesse et les figurants au niveau du nouveau Walter ; brancher le
traceur de silhouette sur le générateur de véhicules (les accessoires ne suivent
pas encore les repères du profil) ; et, quand Benjamin le décidera, le palier 1
(#43) et le puits économique (#20).

---

## Session du 31 juillet 2026, nuit — de 0.35.0 a 0.36.0

**Début** : 31/07 vers 1 h, sur `v0.35.0`, juste après la publication de la
release. **Fin** : au petit matin, sur `v0.36.0`.

**Séance en autonomie complète**, sans personne pour juger à l'écran. C'est le
premier point à noter, parce qu'il change ce qu'on peut livrer : tout ce qui se
mesure a avancé, tout ce qui se juge à l'œil a été vérifié en capture, et une
chose a été **annulée faute de tenir cet examen**.

### Ce qui était demandé

Reprendre le désert ; mettre les vrais figurants avec la démarche de Walter ;
enrichir la ville en objets et en couleurs ; réparer deux défauts de jeu (les
voitures garées traversables, et le joueur baladé par ce qu'il percute) ; passer
sur les tickets ; publier.

### Ce qui est livré

| | |
|---|---|
| **Les voitures garées** | Elles n'avaient aucune collision : `SOLIDES_PREFIXES` était déclaré dans `ville.gd` et lu nulle part. Elles sont maintenant des corps rigides **gelés** — gratuits tant qu'ils dorment, poussables quand on les percute |
| **Le choc** | Ce qu'on percute cède : une voiture qui roule s'arrête et laisse passer, une voiture garée se fait pousser et se repose de travers |
| **Six objets neufs** | Cabine téléphonique, distributeur de journaux, abri de bus, table de pique-nique, buisson, panneaux publicitaires |
| **Des variantes** | Poubelles et bennes repeintes : une texture de 32 pixels casse la répétition mieux qu'un objet de plus |
| **Le désert** | Quatre-vingt-dix blocs de grès au pied des mesas, et son **ambiance sonore**, livrée le 27 et jamais branchée |
| **La foule** | Vingt-six passants au lieu de seize, plus près, et devant soi |

### Les surprises

**La foule était invisible, et personne ne s'en était aperçu.** Seize passants
répartis dans un anneau de quatre-vingt-quinze mètres : trois captures de rue
d'affilée n'en montraient aucun. Deux causes, toutes deux trouvées en
instrumentant plutôt qu'en réfléchissant — on comparait la distance aux
**carrefours**, distants de 57 m, donc une rue passant à dix mètres devant soi
n'était pas candidate ; et on peuplait aussi bien le dos du joueur que son champ
de vision.

**Le report de la démarche sur les figurants ne marche pas, et je l'ai cru
pendant une heure.** Le pipeline tourne de bout en bout, les clips s'exportent,
le jeu les joue — et le corps est disloqué. Je l'ai annoncé comme fonctionnel
avant de l'avoir regardé. C'est exactement la faute que le dépôt documente
depuis le premier jour : *une image ou un nombre, jamais une conviction.* Les
passants sont donc restés des boîtes, et `outils/apercu_modele.py` existe
maintenant pour rendre un modèle seul dans une pose choisie — l'outil qui
manquait pour que cette vérification coûte trente secondes.

**Deux suites de conduite sont tombées pour une raison étrangère à la
conduite.** Le circuit de tenue de route passait à soixante mètres de la ville,
et la bande de cactus est passée de 75 à 165 m dans la même nuit : la voiture a
tapé un saguaro et le test a annoncé « 0 km/h ». Le circuit de bordure, lui,
longe un trottoir — c'est-à-dire là où se garent les voitures, qui venaient de
recevoir un corps physique. **Un test isolé de son décor ne l'est jamais
vraiment.**

**Une ambiance livrée peut dormir quatre jours** faute d'un endroit où la
déclarer. Les intérieurs sont câblés un par un dans la scène ; une zone n'avait
aucun endroit équivalent. La convention — un fichier nommé d'après la zone —
remplace le câblage, et la prochaine carte n'aura rien à déclarer.

### Où on reprend

Le palier 1 (#43) est la tranche verticale suivante, et le désert a désormais
son relief, ses lieux nommés et son ambiance pour l'accueillir. Trois décisions
attendent Benjamin : les figurants (#16), la musique (#38), et l'équilibrage
(#41) le jour venu.

---

## Session du 30 au 31 juillet 2026 — de 0.30.0 à 0.35.0

**Début** : 30/07 en fin de journée, sur `v0.30.0`, dépôt propre.
**Fin** : 31/07 au petit matin, sur `v0.35.0`, sept commits, rien de poussé.

### Ce qu'on voulait

Reprendre le projet après trois jours d'arrêt, et avancer sur la carte — « je
veux avancer sur la carte, c'est le plan pour ce soir ».

### Ce qu'on a livré

| Version | Quoi |
|---|---|
| **0.31.0** | Le temps passe (une heure de jeu par minute), une mission peut imposer son heure, la ville passe de 131 à 473 m |
| **0.32.0** | Trois types d'îlot : parc, terrain vague, parking |
| **0.33.0** | Trois quartiers en bandes, le pavillonnaire et le strip mall |
| **0.34.0** | Un horizon (les Sandia), une frange clairsemée en bordure, deux routes qui quittent la ville |
| **0.35.0** | Le désert prend du relief : mesas, arroyo, fossé de la mission 1 |

Hors jeu : les quinze missions et les trois ressources rangées en documents
(`docs/15-missions.md`), le formulaire d'écriture de mission, une feuille de
route complète sur GitHub, et les tickets repris de fond en comble —
étiquettes, titres, et une première ligne qui dit à qui chaque ticket appartient.

### Les surprises, et ce qu'elles ont coûté

**La ville de 473 m tournait à 6 images/seconde, et la géométrie n'y était pour
rien.** Ni les 1 682 décors, ni les 512 lampadaires, ni les douze mille faces :
en retirant les seuls passants on remontait à 55. Le générateur en écrivait un
par côté d'îlot — 255 au lieu de 15. **La règle qui en sort : ce qui est écrit
par îlot ET vivant à chaque image finira par tuer le jeu.** La foule a
maintenant un effectif fixe, comme le trafic.

**Trois défauts sont tombés en branchant la foule sur le graphe des rues**, et
le premier dormait depuis six versions : `pieton.gd` calculait l'arrivée depuis
la direction inverse du tronçon, donc les passants traversaient la chaussée en
diagonale. Personne ne l'avait vu parce que `foule.gd` construisait le graphe
**sans jamais poser personne dessus**. Le code mort ne se teste pas.

**Le tirage des types d'îlot partageait son flux aléatoire avec le reste du
générateur.** Changer la densité d'un parking redistribuait la carte entière :
une capture cadrée sur un terrain vague s'est retrouvée nez à nez avec un
immeuble. Chaque îlot tire maintenant depuis sa propre position.

**Un mur de roche en plein centre-ville**, puis deux autres au milieu de la
carte du désert : les crêtes ont été posées du mauvais côté d'un axe, puis du
bon côté mais dans la zone d'une autre carte. Les deux se voyaient sur la
première image et sur aucun test.

**J'ai documenté un muret en parpaing que je n'avais pas écrit.** Trouvé en
regardant la capture. La règle du projet — on mesure le fichier produit, jamais
l'intention — vaut aussi pour les commentaires.

**Une piste qui serpente reprend tout ce qui était posé en supposant une piste
droite.** Le camping-car s'est retrouvé garé sur la chaussée, et le fossé
comblé par le nivellement de la route. Les deux se calculent maintenant à
partir d'elle, et le générateur publie ses lieux au lieu que le jeu en garde
des copies.

### Ce qu'on a mesuré, et qui servira

| | 8×8 (473 m) | 16×16 (929 m) |
|---|---|---|
| Images/seconde, de jour | 55 | 57 |
| Images/seconde, de nuit | — | 55 |
| Mémoire | 117 Mo | 258 Mo |
| Nœuds | 11 900 | 27 600 |

Quatre fois la surface ne coûte rien. Ce qui coûte, c'est ce qui bouge. Et
quinze fois la ville actuelle tout chargé en même temps ne tiendra pas — d'où
le gestionnaire de zones, à écrire quand la troisième zone arrivera.

### Où on reprend

Le désert est en pause à mi-chemin : il a son relief et ses lieux, il lui
manque de quoi jouer la mission 1. Ensuite, au choix : finir le désert, ou
attaquer le puits économique (#20), qui est ce qui répondra vraiment au « ça
fait un peu vide ».

---

## 2026-07-25 — V0 et V1 : le projet tourne et je peux le regarder

**Voulu** : un squelette Godot qui charge, le rendu PS2 en place, et surtout savoir si
Claude peut produire une image de Godot tout seul.

**Obtenu** : les deux. `godot --path game --script res://verifs/capture.gd` rend une image
512×288 via Vulkan et l'enregistre. La boucle « génère, rends, regarde, corrige » est donc
fermée côté Godot aussi, pas seulement côté Blender.

**Surprises** — quatre, toutes utiles pour la suite :

1. **Fausse piste, corrigée le jour même.** J'ai d'abord conclu que l'éclairage par sommet
   imposait de tesseller toutes les grandes surfaces — un sol de 4 sommets n'étant éclairé
   qu'à ses 4 coins. C'était vrai en par-sommet, mais **on a gardé le par-pixel**, et là un
   sol de 4 sommets s'éclaire très bien. La vraie cause du sol noir était le point 4.
   Leçon de méthode : j'ai tiré une règle générale d'une observation faite dans une
   configuration qu'on allait justement abandonner. Les docs ont été corrigées.
2. **Par sommet et par pixel donnent le même rendu à 512×384.** L'écart est invisible à
   cette résolution. On garde le par-pixel : plus prévisible, et le look PS2 vient du
   filtrage, de la basse résolution et du brouillard, pas du mode d'ombrage.
3. **L'ambiante doit être nettement au-dessus de la couleur du brouillard**, sinon tout ce
   qui n'est pas sous un lampadaire est un aplat parfaitement noir. Montée de 0,16 à 0,50.
4. **Le premier plan a besoin de sa propre source.** Le noir de l'avant-plan n'était pas un
   bug d'éclairage mais de composition : le lampadaire le plus proche était à 16 m. Dans le
   jeu réel, ce sont les phares du véhicule qui régleront ça — à ne pas oublier en V3.

**Aussi** : passage en **4/3** (rendu interne 512 × 384, fenêtre 1024 × 768, ratio verrouillé
donc bandes noires sur écran large). Et convention audio arrêtée : WAV+QOA pour les
bruitages, Ogg pour la musique, jamais de MP3, tout son 3D en mono.

**Prochain** : V2, textures 128 px et générateur de ville.

---

## 2026-07-25 (suite) — V2 et V3 : la ville existe, la voiture roule

**Voulu** : une ville générée qu'on puisse parcourir, et un véhicule conduisible.

**Obtenu** : les deux. Chaîne complète Python → Blender → glTF → Godot, sans intervention
humaine. Ville de 2 × 2 îlots, 122 m de côté, 743 faces. Voiture de 54 faces, roue de 30.

**Surprises** :

1. **Une seule travée par texture de façade était une erreur.** Toutes les fenêtres d'un
   immeuble se retrouvaient dans le même état — bâtiment entièrement éteint, mort. Passé à
   2 × 2 travées : le mélange allumé/éteint apparaît, et la répétition se voit moins. C'est
   ce que faisaient les jeux PS2, pour cette raison exacte.
2. **32 lampadaires à énergie 9 saturent tout.** Le premier rendu était un aplat orange.
   Descendu à 2,6 avec 17 m de portée. Leçon : l'éclairage se règle après avoir posé
   *toutes* les sources, jamais sur une seule.
3. **La caméra de capture était écrasée par la caméra de poursuite**, qui réécrit sa
   position à chaque image de physique. L'outil crée maintenant sa propre caméra et la rend
   active — robuste quel que soit le script en place.
4. **Le toit de la voiture était en verre.** Mon test « est-ce la cabine ? » couvrait tout
   le pavillon. Seules les faces réellement inclinées — pare-brise et hayon — sont vitrées.
5. **Une gomme de pneu photométriquement juste est invisible de nuit.** Éclaircie
   arbitrairement de 27 à 46. Le réalisme perd contre la lisibilité, systématiquement.

**Ce que je ne peux pas juger** : si conduire est agréable. Les 150 images de physique
tournent sans erreur, la voiture tient la route, mais le ressenti se teste au clavier.
C'est le seul point où Benjamin est indispensable.

**Deux bugs remontés par Benjamin au premier essai au clavier**, et ils valident la
méthode : je ne pouvais pas les trouver seul.

6. **Le `VehicleBody3D` de Godot pousse vers +Z, pas vers -Z.** Exception à la convention
   du moteur, où tout le reste — caméras, `look_at` — regarde vers -Z. J'ai tranché en
   mesurant plutôt qu'en relisant la documentation : `outils/test_sens.gd` applique une
   poussée et projette le déplacement sur le nez. Verdict sans appel, 9,81 m à l'envers.
   Corrigé par une constante `SENS_POUSSEE`, pas en retournant la scène — mélanger deux
   conventions dans un même projet coûte plus cher qu'un signe documenté.
7. **La marche arrière tremblait parce que je comparais une vitesse NON signée.** Reculer
   fait monter cette vitesse, elle repasse le seuil, le code croit qu'on avance et freine,
   la vitesse retombe, il repart en arrière. Plusieurs fois par seconde. Corrigé en
   projetant la vélocité sur l'axe du nez : le signe distingue enfin « je freine » de
   « je recule ».

Le test de sens est resté dans le dépôt comme non-régression, accessible par
`.\bg.ps1 test`. C'est typiquement le piège qui revient à la première refonte.

**Prochain** : V4, Walter jouable à pied.

---

## V6 — Les maisons de Walter et Jesse

Deux maisons posées sur la rue du haut de la grille, avec un intérieur dans lequel on entre
par la porte. Extérieur et intérieur ne se touchent jamais : l'intérieur est déporté six
cents mètres à l'écart du monde, et le passage est masqué par un fondu au noir. C'est ce que
faisaient GTA III et Vice City, et pour une raison très concrète — la caméra se tient à 3,6 m
derrière le personnage et traverserait les murs en permanence dans une pièce de sept mètres.

**Le repère du seuil n'arrivait pas dans le `.glb`.** Il s'appelait `Porte`, le battant de
la porte porte le matériau `porte`, et l'exportateur glTF de Blender a fusionné les deux :
le fichier exporté contenait un *maillage* nommé `Porte`, à l'origine de la maison, et plus
aucun repère. Côté Godot, `find_child("Porte")` trouvait ce maillage et le prenait pour le
seuil — donc entrer se serait déclenché depuis le milieu du salon, et ressortir aurait déposé
Walter à l'intérieur du mur. Rien n'aurait planté. Renommé en `Seuil`, et `maison.gd` gueule
maintenant si le repère manque, parce que c'est une panne parfaitement silencieuse.

Trouvé en comparant les objets présents en scène côté Blender avec la liste des nœuds du
`.glb` exporté. Le raisonnement seul ne donnait rien : les deux intérieurs exportaient leurs
repères sans problème, seul l'extérieur perdait le sien.

**Le cache d'import de Godot a ensuite fait croire que le correctif ne marchait pas.** Le
`.glb` régénéré sur le disque, mais `.godot/imported` tenait encore l'ancien. Un
`--headless --import` avant de tester, sinon on corrige à l'aveugle.

**La caméra devait sauter, pas suivre.** Elle rattrape sa position en lissage : sur six cents
mètres, elle aurait mis plusieurs secondes à traverser, et on aurait vu défiler le vide.
`recaler()` la repose d'un coup pendant le noir.

**Les façades étaient des silhouettes noires.** Les maisons sont hors de la grille, donc hors
de portée des lampadaires, qui ne sont générés qu'autour des îlots. Une lumière de porche
au-dessus de chaque porte règle la lisibilité et désigne l'endroit où aller — et c'est ce
qu'a n'importe quelle maison de banlieue, donc ça ne coûte rien.

`outils/test_maison.gd` entre et ressort en mesurant les positions, parce que c'est une
téléportation masquée par un écran noir : quand elle se trompe, elle ne plante pas, elle
dépose le joueur dans un mur et personne ne voit rien. Huit suites maintenant.

**Prochain** : V7, les personnages dans les maisons et le dialogue.

---

## V7 — Les habitants et le dialogue

Skyler chez Walter, Jesse chez lui. On leur parle avec la même touche que le reste, et le
texte ne vit nulle part dans le code : il est dans `game/donnees/dialogues.json`, que
Guillaume peut réécrire sans ouvrir Godot. Reparler à quelqu'un donne la conversation
suivante, puis ça recommence — trois par personnage pour l'instant. C'est peu, mais des PNJ
qui radotent est ce qui fait le plus vite sentir qu'un monde est vide.

**Les personnages sortent du même générateur.** Un visage PS2 est une texture sur une boîte —
aucune géométrie ne représente un nez à ce budget de triangles. Tout le personnage tient donc
dans une poignée de traits, et ces traits sont maintenant des paramètres : calvitie, lunettes,
bouc, couleur de peau, couleur de cheveux. Ajouter un habitant coûte une entrée de
dictionnaire dans `gen_textures.py`, pas une fonction de plus. Le maillage, lui, ne change
jamais — ce qui veut dire que l'animation procédurale écrite pour Walter marchera telle
quelle sur n'importe lequel d'entre eux.

**Jesse se tenait à l'intérieur de son plan de travail**, coupé à la taille. Rien ne plantait,
rien ne s'affichait en rouge — il fallait aller le voir. Un habitant est un point, un meuble
est une boîte : la vérification tient en six lignes, elle est maintenant faite à la
génération et refuse d'exporter une pièce mal fichue.

**Les cheveux de Skyler étaient blond doré et son visage ne se lisait plus.** À trente pixels
de haut, cette teinte se confond avec la carnation : on ne voyait qu'un bloc uni. Passé en
blond cendré. À cette résolution le contraste passe avant la justesse de la teinte, et c'est
une règle qui vaudra pour tous les personnages à venir.

**Le personnage se fige sans qu'on suspende sa physique.** Un simple `set_process(false)`
pendant le dialogue l'aurait arrêté net, une jambe en l'air. Un drapeau `bloque` coupe les
commandes, il finit son pas et repose ses pieds normalement.

Un piège de méthode, aussi : ma première lecture des captures concluait « Skyler est de dos ».
Elle était simplement quatre mètres plus loin que Jesse dans le cadre, donc sa tête faisait
vingt pixels. J'ai vérifié de quel côté le générateur pose le visage — en interrogeant les UV
du maillage, pas en relisant le code — avant de toucher à quoi que ce soit. Bien m'en a pris :
l'orientation était juste, le problème était le contraste.

Neuf suites.

**Prochain** : V8, la roue des outils.

---

## V8 — La roue des outils

Revolver, cristal, « Feuilles d'herbe » et le porkpie. On maintient **Tab** (ou le clic
droit), on choisit avec gauche/droite, on relâche pour équiper. Rechoisir ce qu'on tient
déjà le range — sinon il n'y a aucun moyen de revenir aux mains vides une fois qu'on a pris
quelque chose.

**La roue est dessinée, pas assemblée en nœuds.** Le nombre de parts vient de
`donnees/outils.json` : ajouter une entrée ajoute une part, sans toucher à quoi que ce soit.
Une roue faite de nœuds posés à la main devrait être refaite à chaque objet ajouté.

**On valide au relâchement, pas à l'appui.** C'est ce qui fait de la roue un geste continu
plutôt qu'un menu où l'on entre et d'où l'on sort. Et le temps ralentit sans se figer —
`Engine.time_scale` à 0,25 — ce que faisaient les jeux de l'époque : le monde reste vivant
derrière, mais on n'est pas en danger pendant qu'on choisit.

Les objets sont accrochés **une fois pour toutes** au démarrage puis simplement masqués. Les
instancier au changement provoquerait un temps de chargement au moment précis où l'on tourne
la roue, c'est-à-dire au pire moment.

**Les quatre orientations étaient fausses au premier essai** — revolver pointant le sol,
livre à plat comme un plateau. Les objets sont modélisés avec l'axe long vers le haut et le
point de prise à l'origine : après conversion glTF, la rotation nulle donne déjà une prise
correcte. Mes valeurs « corrigeaient » un problème qui n'existait pas. Tout est dans le
fichier de données, donc corrigé sans rien régénérer.

**Un piège de capture, à retenir.** Mon premier gros plan sur la main a photographié
**Skyler**. `find_child("MainD")` depuis la racine descend en profondeur, et les maisons
viennent avant le joueur dans l'arbre — tous les personnages ont les mêmes noms de segments.
Chercher depuis le joueur, jamais depuis la racine.

**Et un piège Godot qui a failli passer.** La première version du test annonçait « le
revolver apparaît » pour les quatre outils, y compris les mains vides : `visible` est
**local** en Godot, un maillage garde `visible = true` sous un parent masqué. C'est
`is_visible_in_tree()` qu'il faut. Un test qui valide toujours est pire que pas de test.

Dix suites.

**Prochain** : V9, HUD, export Windows, et le week-end est bouclé.

---

## V9 — HUD, export Windows, et le jalon est atteint

Un compteur de vitesse en bas à droite, et le nom de l'outil annoncé une seconde et demie
quand on l'équipe. **Rien d'autre.** La règle que je me suis donnée : n'afficher que ce qui
change. Un compteur immobile pendant qu'on marche est du bruit, pas de l'information — donc
il n'apparaît qu'au volant, et le nom de l'outil s'efface puisque l'objet se voit dans la
main.

Le HUD vit **dans** le SubViewport, donc rendu à 512 × 384 comme le reste. Un texte net
superposé à une image basse résolution trahirait immédiatement un jeu moderne : les HUD PS2
partageaient le même tampon que la 3D, et c'est ce qui leur donne ce grain. Chaque chiffre
est cerné de noir, sinon il passe devant un phare et devient illisible une seconde sur trois.

La vitesse est **lissée**. La valeur brute d'un `VehicleBody3D` oscille d'un ou deux km/h à
chaque image ; affichée telle quelle, le compteur papillonne.

**Le HUD interroge le contrôleur au lieu de deviner.** Il aurait été plus court de lire
l'état directement, mais deux sources de vérité finissent toujours par diverger — et celle
qui compte est celle qui décide.

### L'exécutable

`.\bg.ps1 exporter` produit `build\BG.exe`, 113 Mo, qui se lance seul. Les modèles d'export
sont un téléchargement à part de 1,2 Go, absent de l'installation de Godot : sans eux
l'export échoue avec un message qui ne dit pas quoi faire. La commande les installe elle-même
la première fois.

`export_presets.cfg` est **volontairement suivi par git**, contrairement à l'habitude. Godot
l'exclut par défaut parce qu'il peut contenir des mots de passe de signature ; le nôtre ne
contient que des réglages de build, et le partager évite que chacun refasse la configuration
à la main et produise un exécutable différent.

### Le jalon

> « On conduit une voiture dans quatre blocs d'Albuquerque, de nuit, avec le rendu PS2, et
> on peut descendre du véhicule. »

Atteint, et dépassé : les deux maisons, leurs habitants, les conversations et la roue des
outils n'en faisaient pas partie. Dix suites de tests, chacune écrite après un vrai bug.

Ce qui a le plus servi, sur trois jours : **la boucle de capture hors écran**. Pouvoir rendre
une image et la regarder sans déranger personne a trouvé le seuil perdu à l'export glTF,
Jesse planté dans son plan de travail, le visage illisible de Skyler, les quatre orientations
d'objets fausses. Aucune de ces choses ne provoquait d'erreur. Toutes se voyaient.

Ce qui a le plus coûté : **les pannes silencieuses**. Le SubViewport sans écouteur audio, le
repère glTF fusionné avec un matériau, le cache d'import qui sert l'ancienne version, un test
qui validait toujours. Aucune ne plantait. C'est pour ça qu'il y a dix suites plutôt que zéro.

**Reste à décider ensemble** : les blocs A, B, C et F de `00-questions.md`, toujours sans
réponse. Rien de ce qui a été fait n'en dépendait — mais la suite, si.

---

## Correctif — récupérer du travail ne rechargeait pas les nouveaux assets

Trouvé en répondant à la question « comment Guillaume récupère la dernière version ». La
réponse était `.\go.ps1`, et elle était **fausse**.

Godot garde une copie convertie de chaque fichier 3D, image et son dans `.godot\`, qui n'est
pas suivi par git — et ne peut pas l'être, c'est un cache machine. Un fichier qui arrive par
`git pull` sans cette copie **ne se charge pas du tout** :

```
ERROR: Cannot open file 'res://.godot/imported/arme.glb-....scn'
```

`bg.ps1` n'importait qu'au tout premier lancement, quand `.godot\` était absent. Guillaume,
qui l'avait déjà, aurait pullé les maisons, les habitants et les objets — et lancé un jeu où
rien de tout ça n'existe. Le jeu démarre quand même, ce qui est le pire cas : pas de plantage,
juste un monde amputé.

Même piège pour les scripts : les noms déclarés par `class_name` vivent dans un cache du même
dossier. Sans lui, `Pnj`, `Dialogue` ou `Roue` sont introuvables à l'exécution.

Vérifié plutôt que supposé : j'ai mis de côté l'entrée de cache de `arme.glb` et relancé la
suite. Quatre erreurs de chargement, trois tests au rouge. C'est exactement ce qu'il aurait vu.

Corrigé en datant le dernier import et en le refaisant dès que quoi que ce soit a bougé sous
`game\`. Coût mesuré : **10 s la première fois, 1,3 s quand rien n'a changé.** Ça ne se
remarque pas, et ça supprime une classe entière de « chez moi ça marche ».

C'est la troisième fois que ce cache nous coûte du temps — les maisons, puis les personnages,
puis ça. Il est maintenant traité une fois pour toutes, dans la seule commande que tout le
monde utilise.

---

## Correctif — les maisons étaient injouables, et c'est un défaut de conception

Benjamin ne les trouvait pas. Elles étaient au nord, dans le désert au-delà de la dernière
rue, à cent mètres du point de départ. La raison était mécanique : le générateur bâtit les
quatre côtés de chaque îlot, il ne restait **pas un mètre carré libre en bordure de rue**.
Le désert était le seul emplacement possible.

En jeu, ça donnait deux maisons au bout du monde, dans le noir, sans rien pour indiquer d'y
aller. On fait naturellement demi-tour avant de les atteindre. Une explication n'y aurait
rien changé.

**Le générateur accepte maintenant des parcelles réservées.** Un `RESERVES` repéré par îlot
et par côté — pas en mètres, pour que ça survive à un changement de taille d'îlot. Le côté
réservé reçoit un sol en terre au lieu d'immeubles. Walter et Jesse occupent la façade sud
de l'îlot (0, 0), qui donne sur le carrefour de départ.

**Et le point de départ est passé devant chez Walter**, sur le trottoir, porte éclairée à
deux pas. C'est aussi ce qui a du sens narrativement : Walter part de chez lui.

### Deux choses trouvées en déplaçant, qu'aucune n'aurait été trouvée autrement

**La voiture partait vers le bord de la carte.** Garée le long d'une rue horizontale, elle
demandait un quart de tour — et le quart de tour que j'avais écrit l'orientait vers -X, à dix
mètres du vide. Mesuré par `test_sens.gd`, qui applique une poussée et projette le
déplacement, plutôt que déduit du contenu de la matrice.

**Le test de franchissement de bordure s'est mis à échouer sans que le franchissement ait
changé.** Il place la caméra par son cap pour que « avancer » pointe vers le trottoir — mais
la caméra rejoint sa position **en lissage**, et la direction de marche est calculée à partir
de son orientation réelle, pas du cap voulu. Tant qu'elle était en route, le personnage
marchait ailleurs. Le test tenait uniquement parce que le point de départ était à dix mètres
de là ; en l'éloignant, il s'est cassé.

C'est le genre de test qui passe pour de mauvaises raisons, et on ne l'apprend qu'en changeant
autre chose. Il force maintenant la caméra à se placer d'un coup.

Dix suites, toujours.

---

## V10 — Habiller les rues et les jardins

Huit accessoires générés — poubelle, benne, boîte aux lettres, banc, panneau, bouche
d'incendie, saguaro, climatiseur — pour **234 faces au total**. Ce sont des silhouettes vues
de loin dans le brouillard, jamais des maillages de héros : huit côtés suffisent à lire un
cylindre, et coûtent trois fois moins qu'un cercle lisse.

**Rien de tout ça n'est cuit dans le maillage de la ville.** Le générateur écrit seulement
où poser, dans le même JSON que les lampadaires ; le jeu instancie au lancement. Trois cents
poubelles fondues dans le `.glb` pèsent trois cents fois le prix d'une seule. Et chaque type
n'est chargé **qu'une fois** : cent exemplaires d'une `PackedScene` partagent son maillage et
sa texture, là où un `ResourceLoader.load` par exemplaire les rechargerait à chaque appel.

139 éléments posés, 6 modèles.

**Le mobilier va contre les façades, pas au bord du trottoir**, parce que les lampadaires
occupent déjà la bordure. Les deux rangées ne se croisent jamais et le passage reste libre au
milieu — un trottoir infranchissable serait pire que vide.

**Presque rien n'a de collision.** Une poubelle qui arrête une voiture est plus pénible
qu'une poubelle qu'on traverse. Seuls la benne, le banc, le cactus et le panneau sont
solides : ceux-là, on ne pardonne pas de passer au travers.

Les jardins sont meublés **à partir du seuil**, pas de coordonnées écrites en dur : la maison
peut grandir ou déménager, la boîte aux lettres suit. Volontairement peu de choses, et toutes
en retrait de l'allée — ce qui encombre le chemin de la porte se paie à chaque fois qu'on
rentre chez soi.

Et soixante-douze saguaros semés autour de la ville. Le désert est un aplat parfaitement plat
et parfaitement vide : de nuit, il ne se distinguait pas du néant. Quelques silhouettes
suffisent à lui rendre une échelle.

### Ce que le test a trouvé

`test_decor.gd` vérifie qu'aucun élément ne traîne au milieu d'un carrefour — une poubelle
sur la chaussée ne provoque aucune erreur, elle attend juste qu'on lui rentre dedans à
quarante — et que rien ne coince le point de départ.

Il a surtout trouvé autre chose : **133 des 139 nœuds s'appelaient `@Node3D@35`.** Godot
refuse deux frères homonymes et renomme le second. Sur cent trente éléments, l'arbre devenait
illisible et le recensement par type ne voulait plus rien dire. Rien ne cassait — c'est
précisément le genre de chose qu'on ne voit que si on la mesure. Ils sont nommés maintenant,
et le test échoue si un seul redevient anonyme.

Onze suites.

---

## V11 — La roue ne répondait pas, et le jeu passe en journée

### Le bug de la roue

Benjamin : « j'arrive pas à changer d'objet sélectionné ». Diagnostic en une phrase :
**la roue lisait les touches par événement, et toute l'interface vit dans le `SubViewport`
de rendu.** Godot ne propage pas les événements d'entrée dans un `SubViewport` qui n'est pas
sous un `SubViewportContainer` : le `_unhandled_input` y était silencieusement mort.

Rien ne le signalait. La roue s'ouvrait, s'animait, ralentissait le temps, se fermait — et la
sélection ne bougeait jamais. Le reste du jeu scrute déjà les touches (`Input.is_action_...`),
ce qui explique que l'ouverture et la fermeture, elles, marchaient.

Passée en scrutation, comme la convention du projet le voulait depuis le début.

**Le test a d'abord échoué pour une mauvaise raison**, ce qui vaut d'être noté :
`is_action_just_pressed` reste vrai **jusqu'à la fin de la trame** où la touche a été
enfoncée, même après relâchement. Deux appuis dans la même trame comptent tous les deux pour
le premier. Le test concluait que « gauche » ne marchait pas alors que le fautif était le
test. Il s'étale maintenant sur plusieurs trames.

### La journée

Le moment de la journée n'est **pas** un curseur, et c'est le point de conception :
**l'état des vitres est cuit dans les textures de façade**. Un booléen côté jeu pourrait
contredire les textures, et on obtiendrait un ciel de midi sur des fenêtres allumées sans
savoir lequel des deux a tort.

Le générateur de textures écrit donc le moment dans `game/donnees/monde.json` en même temps
qu'il cuit les vitres. Cinq systèmes le relisent : le rendu pour son ciel et son soleil, la
ville pour ses lampadaires, la maison pour son porche, le véhicule pour ses phares.
**Une seule source, écrite par celui qui décide.**

`.\bg.ps1 generer -Moment jour`

Ce qui change de jour, au-delà des couleurs :

- **Un soleil.** De nuit il n'y a aucune source directionnelle, tout vient des lampadaires.
  Sans soleil, la ville de jour est un aplat ambiant sans une seule ombre, et tout paraît plat.
- **Aucun lampadaire créé** — pas éteint, pas créé. Une source coûte même quand son énergie
  est nulle, sur PS2 comme aujourd'hui.
- **Les vitres renvoient le ciel** au lieu d'être allumées. Sinon on obtient des carrés jaunes
  qui brillent en plein soleil, ce qui trahit immédiatement une scène de nuit éclaircie.
- **La brume blanchit le lointain au lieu de l'assombrir**, et on voit à 340 m au lieu de 58.
- **La brume ne mange plus le ciel.** `fog_sky_affect` à 1 convient à la nuit, où le ciel
  *est* le brouillard. De jour, ça donnait un aplat gris pâle au lieu du bleu d'Albuquerque.
  Descendu à 0,25.

`test_jour.gd` vérifie que la bascule est appliquée partout : une bascule à moitié faite ne
plante pas, elle donne une ville de nuit avec un soleil.

Douze suites.

---

## V12 — La caméra, et la vie dans les rues

### La caméra ne traverse plus les murs

Un rayon du sujet vers la caméra, et un rapprochement si quelque chose bloque. Deux
décisions comptent :

**Le clamp est appliqué APRÈS le lissage**, sur la position finale, pas sur la position
visée. Lisser vers une cible déjà corrigée laisserait la caméra traverser le mur pendant
qu'elle rattrape — c'est-à-dire exactement au moment où ça se voit.

**Se rapprocher est instantané, s'éloigner est progressif.** Traverser un mur ne serait-ce
qu'une image se remarque ; un retour progressif au recul nominal, non.

**Mon premier test passait sans rien prouver.** Il collait le joueur au mur et mesurait —
sauf que dans cette configuration la caméra reste dehors toute seule. Il fallait construire
le cas exprès : joueur devant la façade, **cap tourné vers la maison**, pour que la position
idéale tombe à l'intérieur du bâtiment. Contre-épreuve faite en désactivant la parade :
*« recul 4,07 m, obstacle OUI — la caméra est dans le bâtiment »*. Avec la parade, elle est
ramenée à 2,22 m.

Un test qui ne peut pas échouer ne vaut rien. Le vérifier coûte deux minutes.

### La vie

**La marche procédurale a quitté `joueur.gd`** pour `silhouette.gd`. Elle n'avait rien à y
faire de particulier : le maillage est le même pour tout le monde, seules les textures
changent. Un passant mérite exactement la démarche de Walter, et la dupliquer aurait garanti
qu'elles divergent au premier réglage.

**Vingt-et-une voitures garées** le long des trottoirs. Ce sont des `StaticBody3D`, pas des
`VehicleBody3D` endormis : une rue de véhicules physiques coûterait une simulation complète
par voiture, et la moindre d'entre elles se mettrait à glisser.

**Quinze passants**, qui font l'aller-retour sur un segment de trottoir. Aucune recherche de
chemin, aucune décision. C'est volontaire : une foule crédible ne demande pas d'intelligence,
elle demande du **mouvement** et de la **variété**. Trois apparences, trois tailles, des
allures tirées entre 0,55 et 0,95, et des pauses désynchronisées aux extrémités — sinon toute
la rue fait demi-tour en même temps.

Leur voie passe **au milieu du trottoir**, entre les lampadaires côté bordure et le mobilier
côté façade. Sans cette voie centrale, ils passeraient leur temps à buter dans une poubelle.

Ils sont sur la couche de collision du joueur, pas celle du décor : un passant qui croise la
ligne de vue collerait sinon la caméra à la nuque.

`test_foule.gd` mesure un **déplacement réel** entre deux instants. Un passant coincé contre
une poubelle a l'air parfaitement normal sur une capture — debout, bien placé, bien texturé.
Il ne bouge simplement jamais.

Quatorze suites.

---

## V13 — Aller sur le côté, et des tests ciblés

### Le vrai défaut de la caméra à pied

Benjamin : « la caméra est chelou quand je vais à gauche ou à droite, pour faire ce que je
veux je dois faire avancer ».

C'était une dette que j'avais contractée sciemment sans en mesurer le coût. Le personnage
relisait l'orientation de la caméra **à chaque image** pour savoir où est « la gauche ». Si
la caméra tournait pour le suivre, sa direction tournait avec elle, et il marchait en cercle
— le bug des tout premiers jours. Ma parade d'alors : empêcher la caméra de se recentrer
ailleurs que sur une marche avant franche. Le cercle disparaissait ; la caméra restait plantée
dès qu'on allait sur le côté.

**La bonne solution est de figer le repère au moment de l'appui**, et de le garder tant que la
touche est tenue. « À gauche » veut dire à gauche de ce qu'on voyait *quand on a appuyé*. La
direction ne dépend plus d'une caméra mobile, la boucle n'existe plus, et la caméra peut faire
son travail dans les quatre directions.

Mesure après : **6,3 m parcourus en ligne droite, 0° de dérive, caméra à 0° de l'axe** — dans
les quatre directions. Le test vérifie maintenant aussi le CADRAGE, pas seulement l'absence de
rotation : c'est précisément ce que l'ancienne version ne regardait pas.

**Le correctif a immédiatement cassé le test de bordure**, et pour une bonne raison : le
repère est figé à la *première* image d'appui. Si la caméra n'a pas encore pris sa place, on
fige une orientation périmée — et pour toute la durée de l'appui, puisqu'on ne la relit plus.
Le personnage partait à angle droit. Ajout d'un garde : tant que la caméra n'est pas posée, on
ne fige rien.

### Des tests ciblés

Demande de Benjamin, et elle est juste : rejouer quatorze suites pour un changement de trois
lignes coûte deux minutes à chaque commit.

Chaque suite déclare désormais **les fichiers qu'elle couvre**, et deux modes s'ajoutent :

- `.\bg.ps1 test -Modifies` demande à git ce qui a bougé et ne rejoue que le concerné.
- `.\bg.ps1 test -Suite camera` filtre par nom.

Essai réel : modifier `camera_poursuite.gd` et `dialogues.json` sélectionne **4 suites sur
14** — la boucle caméra, les murs, le dialogue, et le franchissement de bordure, qui dépend
de la caméra sans que ce soit évident.

Deux garde-fous, parce qu'une suite oubliée coûte plus cher qu'une suite jouée pour rien :
les motifs de couverture sont **volontairement larges**, et toucher `monde.tscn`,
`reglages.tres` ou `project.godot` relance **tout** — ce sont les trois fichiers que chaque
suite charge.

---

## V14 — La visée à la souris

La caméra était entièrement automatique. Sur PC, un GTA-like se regarde à la souris.

Souris capturée au lancement, **Échap** rend le curseur, un clic le reprend — sans issue,
une souris capturée est un piège. Molette pour le recul.

**À pied**, la souris pose le cap et le recentrage automatique **se suspend** pendant un
délai réglable. Sans ce délai, la caméra ramènerait de force dès qu'on lâche la souris, et
regarder de côté en marchant serait impossible — ce qui est tout l'intérêt.

**Au volant**, elle ne remplace pas le cap : la caméra de conduite est solidaire de la
caisse, c'est ce qui fait qu'elle accompagne les virages. La visée s'ajoute par-dessus et se
résorbe d'elle-même. Le comportement testé de la conduite est intact.

**Le tangage fait pivoter la caméra autour du sujet** — elle monte et se rapproche en même
temps. Se contenter de lever la hauteur donnerait une caméra qui plane sans jamais regarder
d'en haut.

### Le piège, évité cette fois

La souris est lue par le **contrôleur**, pas par la caméra. La caméra vit dans le
`SubViewport` de rendu, où Godot ne propage aucune entrée : un `_input` y serait
silencieusement mort. C'est exactement ce qui avait rendu la roue des outils inutilisable
pendant deux jours.

Le test envoie donc un **vrai événement** dans la boucle d'entrée du moteur, plutôt que
d'appeler la méthode de la caméra. C'est la seule façon de vérifier que la chaîne complète
tient.

**Et il s'est trompé de la même façon que le test de la roue**, ce qui commence à faire une
famille : `Input.parse_input_event` met l'événement dans la file du moteur, il n'est
distribué qu'à la trame suivante. Ma première version envoyait quarante mouvements puis
lisait l'angle dans la même trame, et annonçait une butée à 26° — c'était simplement la
valeur d'avant, aucun des quarante n'ayant encore été traité. Chaque étape envoie
maintenant, la suivante mesure.

**À retenir pour tout test d'entrée : envoyer et mesurer ne peuvent pas être dans la même
trame.**

Quinze suites. Sept jouées pour ce commit.

---

## V15 — Les voix

Chaque réplique de `dialogues.json` a maintenant un fichier audio, et le dialogue le joue en
affichant la ligne. Vingt répliques, mesurées à −6,1 dB sur le bus Interface — le test
vérifie le **volume réellement sorti**, pas la présence du fichier.

**La synthèse est celle de Windows.** Hors ligne, rien à installer, aucune clé, aucun compte.
Ce n'est pas un pis-aller : une voix synthétique de 2005 dans un jeu à l'esthétique PS2 est
cohérente, là où une voix parfaitement naturelle jurerait avec des personnages de quatre-vingt
dix faces. Tout est sorti en **22 kHz mono**, ce que sortait une PS2 — et ça masque au passage
une partie des artefacts.

Une seule voix française est installée par défaut sur Windows, et elle est féminine. Les
personnages se distinguent donc par **transposition** : `donnees/voix.json` donne à chacun sa
hauteur, son débit et son filtrage. En dessous de 0,6 la voix devient caverneuse plutôt que
masculine — les formants descendent avec la hauteur.

**Le nom du fichier est déduit du texte**, par empreinte MD5. Conséquence utile : réécrire une
réplique change son empreinte, donc son fichier. Impossible d'entendre l'ancienne version sur
le nouveau texte, ce qu'un index numéroté aurait permis sans rien signaler.

Le générateur est en PowerShell et le lecteur en GDScript : **ils ne se rejoignent que sur un
nom de fichier**. S'ils calculaient l'empreinte différemment, le dialogue s'afficherait
normalement, personne ne parlerait, et rien ne serait signalé. Le test calcule le nom avec la
fonction *du jeu*, pas avec la sienne — sinon il validerait sa propre convention.

### Le circuit pour enregistrer de vraies voix

Personne ne doit calculer une empreinte à la main. `.\bg.ps1 voix -Script` écrit
`docs/08-script-voix.md` : la liste **numérotée** des répliques, comme un vrai script
d'enregistrement.

On enregistre `001.wav`, `002.wav`, on dépose dans `livraisons/voix/`, et `.\livrer.ps1` convertit,
renomme et range. Le numéro est la première suite de chiffres du nom : `012_jesse_yo.wav`
marche aussi bien que `12.wav`. Un fichier sans numéro est laissé en place avec un
avertissement, jamais deviné.

Une ligne sans enregistrement garde la voix de synthèse. On peut donc en livrer trois
aujourd'hui et le reste plus tard.

### Ce que je n'ai pas fait

Reproduire la voix de Bryan Cranston. Fabriquer de nouvelles phrases dans la voix d'une
personne réelle, c'est produire des propos qu'elle n'a jamais tenus — autre chose que reprendre
des extraits existants. Le circuit ci-dessus accepte n'importe quel enregistrement, y compris
de vraies répliques découpées de la série : ça ne met aucun mot dans la bouche de personne.

Seize suites.

**Correctif immediat, trouve en verifiant l'ordre des etapes** : l'integration **supprimait**
la prise d'origine apres conversion. Ce qui part dans le jeu est ecrase, compresse et ramene a
22 kHz — c'est une impasse, on ne remonte pas de la. Quelqu'un qui depose sa seule copie
l'aurait perdue et aurait du refaire la prise. Les originaux sont maintenant archives dans
`livraisons/voix/originaux/`, suivis par LFS, et le scan les exclut pour ne pas les reintegrer en
boucle a chaque livraison.

---

## V16 — La première vraie voix, et le découpage

Guillaume a livré un fichier de **58 secondes** nommé `1.wav`. L'intégration l'a donc affecté
entièrement à la réplique 001 : en jeu, Skyler disait « Tu rentres tard » et on entendait une
minute de monologue.

Ce n'était pas une erreur de sa part. **On n'arrête pas le micro entre chaque phrase** — une
longue prise est le cas normal. C'est le circuit qui manquait une étape.

### Le découpage

`.\bg.ps1 voix -Decouper <fichier>` cherche les silences et extrait les segments parlés.
Le seuil se règle : `-Pause 0.6` donnait 13 segments, `-Pause 0.3` en donnait 20, `-Pause 0.9`
en donne **9** — exactement les neuf phrases de la confession du pilote.

Rien n'est affecté automatiquement par défaut. Le nombre de segments ne correspond presque
jamais au nombre de lignes : on se reprend, on tousse, on enchaîne deux phrases. Deviner
produirait un doublage où chacun dit le texte du précédent, sans que personne ne voie d'où ça
vient. `-Assigner -Depuis 11` existe pour le cas où l'on a **vérifié** que la prise suit le
script — ici, un monologue lu d'une traite, donc l'ordre était garanti.

### Reconnaître ce qu'il y a dans un fichier

Je ne peux pas écouter. Mais Windows a un moteur de reconnaissance français hors ligne, et je
connais les phrases attendues : les donner comme **grammaire fermée** transforme la
transcription libre en un choix parmi vingt, ce qui est bien plus facile.

Repère mesuré : une phrase de synthèse propre atteint **93 %**. Les segments de Guillaume
plafonnaient à **30 %**, avec la même phrase reconnue trois fois — verdict sans appel, ce
n'était pas le script. Benjamin a confirmé : c'était la confession, en anglais.

Le moteur est resté dans l'outil sous `-Reconnaitre`. Il ne dira pas ce qui est dit hors du
script, mais il répond à une question qui compte : *cette prise correspond-elle à la réplique
qu'on croit ?*

### Deux pièges bouchés au passage

**`-Refaire` aurait écrasé les vraies prises par de la synthèse.** Une soirée
d'enregistrement perdue, et le seul avertissement aurait été le silence de celui qui les
avait faites. Un registre `enregistrees.json` liste les répliques doublées pour de vrai.

**Ce registre est tenu par l'intégration, pas déduit du nom des archives.** Première version :
je lisais le numéro dans le nom du fichier archivé. Sauf qu'une prise unique couvre ici les
répliques 11 à 19, et son nom ne peut en porter qu'un — la 001, précisément celle qu'elle ne
contenait pas.

**État** : neuf répliques en vraie voix, dix en synthèse, dans la même conversation. Le
mélange fonctionne, c'est ce qui permet d'avancer par morceaux.

### Le virage : la caisse raclait vraiment

*« Quand je tourne j'ai l'impression qu'elle touche le sol sur le côté et ça la ralentit. »*
Impression exacte, et mesurée : **garde au sol de −0,008 m** en courbe. Le bas de caisse
passait sous le sol.

Trois causes empilées, trouvées une par une :

**Les corrections précédentes n'étaient pas actives.** `reglages.tres` écrase les valeurs par
défaut du script — l'adhérence y était toujours à 0,85. J'avais corrigé le script en croyant
avoir corrigé le jeu. C'est le fichier de Benjamin, mais des unités fausses ne sont pas un
goût : corrigé là où ça compte.

**La raideur décide de la garde au sol**, ce qui n'est pas évident : plus le ressort est mou,
plus la caisse s'affaisse sur ses roues. À 42 elle ne gardait que 24 cm sous le plancher — et
12° de gîte en mangent 20.

**La boîte de collision descendait jusqu'aux roues.** Ce sont les roues qui portent la
voiture ; la caisse n'a aucune raison d'aller si bas. Son bas est remonté de 0,39 à 0,55.

Résultat : **0,140 m de garde en virage**, contre-roulis de 1,2°, et elle garde sa vitesse.

**Une barre anti-roulis écrite puis mesurée inutile.** Elle réduisait le contre-roulis de
moitié à 1,0 — gardée — mais au-delà elle coûtait dix km/h sans rien gagner sur la gîte. Le
roulis ne venait pas des ressorts mais de la suspension arrivée en butée : aucun couple ne
peut corriger ça.

**Et une leçon de mesure.** Mon premier indicateur d'oscillation annonçait 8 degrés *par
image* — un non-sens physique. Il comparait deux images consécutives mais ne mettait à jour sa
référence qu'après la quarantième, si bien que le premier écart valait quarante images de
mouvement. Le test mesure maintenant la **garde au sol**, pas l'angle : une caisse peut
pencher de quinze degrés sans rien racler si elle est haute, et frotter à huit si elle est
basse. L'angle seul ne dit rien.

Dix-huit suites.

---

## V18 — « I am the one who knocks »

Guillaume a livré la scène de la cuisine, **une piste par comédien** : `dialogue1_Skyler.mp3`
et `dialogue1_Walt.mp3`, plus le texte. Cinq répliques chacun, qui alternent.

C'est la façon normale de doubler un dialogue — chacun lit sa piste de son côté — et le
circuit ne savait pas la traiter. Il sait maintenant : `-Assigner -Depuis 1 -Pas 2` pour le
premier, `-Depuis 2 -Pas 2` pour le second.

**Les seuils de découpage ne sont pas au hasard.** 0,55 s pour Skyler, 1,4 s pour Walt — ce
sont les seuls qui donnent exactement cinq segments par piste. Trouvés en balayant, pas en
devinant : à 0,6 s Skyler tombe à quatre, à 0,45 s elle monte à dix.

Les deux MP3 n'ont pas de numéro en tête de nom, donc l'intégration les a **laissés
tranquilles** au lieu de les affecter en bloc à la réplique 001 — c'est exactement le
garde-fou écrit après la confession de Walter, et il a servi dès la livraison suivante.

Le cadre de dialogue est passé de 90 à 174 pixels : la tirade finale fait 562 caractères.

**Ce que je ne peux pas vérifier** : que chaque segment tombe sur la bonne réplique. Les
durées ne collent pas parfaitement aux longueurs de texte, et je ne peux pas écouter. Un
seul passage en jeu tranche — et si c'est décalé, il suffit de redécouper avec un autre
seuil, les originaux sont archivés.

---

## V19 — Le Walt sculpté devient le personnage jouable

Benjamin a livré `test Walt.obj` : 1088 faces, une seule pièce, **aucune coordonnée de
texture, aucun matériau**. Il se lisait immédiatement comme Walter White, ce que notre
bonhomme en boîtes ne fait pas — mais il ne pouvait ni porter d'image ni marcher.

Trois outils l'ont fait entrer dans le jeu, et ils marchent sur n'importe quel modèle livré.

### Déplier — en prenant le problème à l'envers

Blender sait fabriquer des UV tout seul, mais il place les îlots où il veut : savoir ensuite
*quel morceau de l'image est la tête* est impossible à deviner. Peindre « le visage sur la
tête » semblait donc hors de portée d'un script.

**On classe donc chaque face par sa position dans le corps** — hauteur, distance à l'axe,
orientation — et on peint sa case UV en conséquence. Le dépliage ne sert plus que d'adresse ;
sa lisibilité n'a aucune importance.

Le visage est projeté depuis l'avant, en piochant dans l'atlas que `gen_textures.py` dessine
déjà : le modèle sculpté et les personnages générés partagent la même palette, les mêmes
lunettes, le même bouc.

**Correction en cours de route** : je peignais chaque triangle d'une couleur unique prise en
son centre. Un œil couvrait une facette entière ou disparaissait entre deux. En interpolant la
position 3D **par pixel**, le dessin traverse la géométrie sans s'occuper de son découpage.

### Découper — le pivot compte plus que la coupe

Quinze segments, la hiérarchie exacte qu'attend `silhouette.gd`. Le point délicat n'était pas
la découpe : c'est que **l'origine de chaque segment doit tomber sur son articulation**, sinon
la cuisse tourne autour du genou et la jambe part en hélice.

Les articulations sont **mesurées sur la géométrie réelle**, pas supposées : un modèle plus
large ou plus étroit que le nôtre reste correct.

Résultat : il marche avec le même code, sans une ligne de différence. Le chapeau se pose sur
sa tête, le revolver dans sa main — les points d'ancrage de la roue fonctionnent tels quels.

### Ce que ça coûte, et ce qui reste

- **1088 faces contre 90.** Douze fois plus. Ça reste dans le budget PS2, mais Skyler, Jesse
  et les passants sont toujours en boîtes à côté de lui.
- **Les articulations sont franches.** À l'épaule et à la hanche, la matière se sépare quand
  l'angle est grand. C'était le cas sur PS1 ; à distance de jeu, ça ne se remarque pas.
- **Le découpage est asymétrique** — 105 faces à une main contre 53 à l'autre. Des seuils
  rectilignes sur une pose qui ne l'est pas. Réglable par paramètre, invisible au rendu.

**Un trou dans la carte de couverture des tests, trouvé au passage** : modifier
`scenes/joueur.tscn` ne déclenchait aucune suite. Changer le maillage du personnage — donc
ses segments, ses ancrages, sa taille — ne testait rien. Cinq suites le couvrent maintenant.

Dix-huit suites.

---

## V20 — Ranger, brancher les sons, et deux pannes qui ne se voyaient pas d'ici

**Voulu** : remettre Walter dans la scène, ranger un dépôt devenu confus, brancher les
vingt-huit sons livrés par Guillaume.

**Obtenu** : les trois, plus un numéro de version affiché en jeu, plus la nouvelle prise du
dialogue de la cuisine. Dix-huit commits, `v0.10.0`.

**Surprises** — cinq, et quatre concernent la même chose : *ce qui marche ici ne marche pas
forcément là-bas.*

1. **Walter n'était pas cassé, il ne se chargeait plus.** Godot extrait par défaut les
   images d'un `.glb` dans un PNG posé à côté, et le `.import` se met à en dépendre. Un
   commit précédent avait supprimé ce PNG en croyant nettoyer un doublon : le maillage ne
   se charge plus, la scène se charge quand même, le jeu se lance sans un mot.
   En creusant, mieux : les `.glb` **portent déjà leurs textures**, cuites par les
   générateurs. Les 88 PNG posés à côté ne servaient à rien — retirés, le rendu à froid est
   pixel pour pixel le même. L'extraction est coupée par défaut de projet.

2. **Aucune boucle ne bouclait, depuis le début.** Godot lit « détecter depuis le WAV » et
   nos fichiers n'ont pas de marqueur de boucle : les trois couches moteur repartaient de
   zéro à chaque fin. Personne ne l'avait vu parce que **le test moteur ne durait pas plus
   longtemps que le fichier**. La nouvelle suite dure plus que le plus court des flux, ce
   qui est la seule façon de distinguer « il joue » de « il boucle ».

3. **`bg.ps1` partait fonctionnel et arrivait cassé.** PowerShell 7 lit un `.ps1` en UTF-8
   quoi qu'il arrive ; PowerShell 5.1 — celui de Windows, celui que lance `JOUER.bat` — le
   lit en CP-1252 sans marque d'octets. Un tiret cadratin y devient trois caractères dont un
   guillemet, qui ferme la chaîne et casse tout le fichier à partir de là. L'erreur pointait
   une ligne jamais touchée. Le lanceur est repassé en ASCII, et `livrer.ps1` refuse
   désormais d'envoyer un script qui ne s'exécuterait pas chez l'autre.

4. **Un `git add -A` en plein rebase a ressuscité 28 sons**, dans leur version d'avant
   conversion en PCM — exactement celles que Godot refuse. Le jeu marchait parfaitement
   pendant ce temps, ce qui est tout le problème. Une vérification refuse maintenant qu'un
   fichier traîne à la racine de `sons/`.

5. **J'avais conclu que la nouvelle prise du dialogue était un montage des anciennes**, sur
   la seule foi des durées. Benjamin a entendu que c'était faux. Leçon : une corrélation
   circonstancielle ne vaut pas une écoute. La mesure qui a *ensuite* prouvé l'alignement
   était d'une autre nature — deux cadences de parole distinctes et chacune constante, 13 à
   16 caractères/seconde pour Skyler, 7 à 10 pour Walter. Un décalage d'une réplique aurait
   mélangé les deux.

**Ce qu'on emporte** : le dépôt a une règle unique — `game/` ne contient que ce que le jeu
charge. Le son passe par une banque en données. Et trois garde-fous existent parce que les
trois pannes correspondantes étaient invisibles depuis la machine qui les créait.
---

## 26 juillet 2026 — Walter respire, saute, s'accroupit, et fait sa première livraison

Quatre versions dans la journée : **0.25.0** à **0.27.1**. Le jeu est passé d'un bac à sable
à quelque chose qui a un début et une fin.

**Ce qui a été construit** : les animations que les modèles livrés n'avaient pas (repos avec
respiration et geste des lunettes, marche relâchée, accroupi, saut), le saut et
l'accroupissement, le choc violent au-delà de 50 mph, et **la première mission** — quinze
étapes, quatre décors, argent, barre de vie, tir, ragdoll, écran de fin.

### Ce que la journée a appris, et qui vaut au-delà d'elle

**Une mesure fausse ne prévient jamais.** Trois fois dans la journée, un nombre calculé
proprement décrivait autre chose que ce qu'on croyait :

- la foulée était réglée **à l'œil** à 1,15 m quand le clip en fait 1,76 — l'animation
  tournait 50 % trop vite, et c'est *ça* qui rendait la marche « robotique ». Elle se lit
  maintenant dans le fichier
- `get_bone_global_pose()` rend des unités de squelette, pas des mètres : la respiration
  s'annonçait à **672 mm** pour 16 mm réels. Seule l'invraisemblance du chiffre l'a trahie
- la boîte englobante d'un maillage décrit la géométrie **avant** déformation par
  l'armature. Deux modèles de 1,75 m s'annonçaient à 2,70 puis ressortaient à 3,10 après
  une mise à l'échelle censée les ramener à 1,75

Le remède est le même à chaque fois : **mesurer sur les os**, dans un repère qu'on maîtrise.

**Exister et se jouer sont deux choses.** Le geste des lunettes était dans le fichier,
mesuré à sept centimètres du visage, et invisible en jeu. Entre la pose construite et
l'animation vue, il y a une insertion de clés, un mélange et une interpolation — chacun peut
avaler le geste. On relit donc systématiquement ce qu'on vient d'écrire.

**Une régression peut être muette sur sa cause.** Les corps du ragdoll, créés au chargement
et laissés en collision, poussaient le joueur à travers le sol du salon jusqu'à −75 m.
Quatre suites sont devenues rouges d'un coup et **aucune ne parlait de ragdoll**.

**Un solveur vaut mieux qu'un angle écrit à la main.** L'orientation des os appartient au rig
et ne se devine pas. On cherche donc : l'axe de flexion du coude parmi les six possibles, les
angles qui amènent les doigts aux lunettes, les flexions qui gardent les pieds au sol pendant
que le bassin descend de quarante centimètres. Avec plusieurs points de départ — une descente
par coordonnées s'arrête dans le premier creux venu.

**Le repère de Blender n'est pas celui de Godot**, et l'export `+Y up` envoie la profondeur
`-Y` sur `+Z`. Tout le contenu du camping-car s'est retrouvé derrière sa paroi arrière : la
pièce paraissait vide depuis l'intérieur.

### Le suivi

Le ticketing est passé sur **GitHub Issues** — formulaires à champs obligatoires, étiquettes,
appli mobile. `livraisons/TICKETS.csv` reste, mais **régénéré** par `outils/tickets.ps1` :
une seule source, pas de divergence possible.

`livraisons/` est rangé par type. Deux pièges y décidaient du rangement : `sons/` est un sas
que `livrer.ps1` vide vers le jeu à chaque envoi, et `voix/originaux/` est le seul dossier
que l'intégration ignore.
