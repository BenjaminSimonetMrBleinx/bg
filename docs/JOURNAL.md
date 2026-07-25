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
