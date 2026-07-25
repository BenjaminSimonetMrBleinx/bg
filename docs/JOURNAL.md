# Journal

Une entrée par session. Quatre lignes suffisent. La ligne « surprise » est la plus
utile des quatre : c'est celle qu'on relit dans trois semaines.

---

## 2026-07-25 — V0 et V1 : le projet tourne et je peux le regarder

**Voulu** : un squelette Godot qui charge, le rendu PS2 en place, et surtout savoir si
Claude peut produire une image de Godot tout seul.

**Obtenu** : les deux. `godot --path game --script res://outils/capture.gd` rend une image
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
