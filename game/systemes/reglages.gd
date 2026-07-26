# Tous les nombres qui decident du feeling du jeu.
#
# Ce fichier appartient a Benjamin. Il se regle dans l'editeur, avec des
# curseurs, projet lance, sans toucher au code et sans redemarrer.
#
# Regle unique et non negociable : des qu'un nombre influence une sensation,
# il monte ici le jour meme. Une constante de feeling en dur dans un systeme
# est un bug de methode, meme si le code fonctionne.
class_name Reglages
extends Resource

# ---------------------------------------------------------------- vehicule
@export_group("Vehicule")

## Poussee du moteur. Monte si la voiture parait molle au demarrage.
@export_range(0.0, 4000.0, 10.0) var acceleration: float = 900.0

## Vitesse maximale en km/h. Purement indicatif : la resistance fait le reste.
@export_range(0.0, 260.0, 1.0) var vitesse_max_kmh: float = 130.0

## Force de freinage. Trop bas, la voiture flotte ; trop haut, elle bloque net.
@export_range(0.0, 200.0, 1.0) var force_frein: float = 45.0

## Angle de braquage maximal, en degres.
@export_range(5.0, 60.0, 0.5) var braquage_max_deg: float = 32.0

## Reduction du braquage a pleine vitesse, en proportion.
## 0 = on braque autant a 130 qu'a l'arret (nerveux, irrealiste).
## 1 = les roues ne tournent plus du tout a pleine vitesse.
@export_range(0.0, 1.0, 0.01) var braquage_reduction_vitesse: float = 0.62

## Vitesse a laquelle les roues rejoignent l'angle demande. Bas = lourd.
@export_range(1.0, 30.0, 0.1) var braquage_reactivite: float = 7.0

## Masse du vehicule en kg. Influence l'inertie et le transfert de charge.
@export_range(400.0, 3000.0, 10.0) var masse: float = 1350.0

## Adherence des roues avant.
##
## ATTENTION A L'UNITE. Ce n'est pas un coefficient entre 0 et 1 : Godot
## attend un facteur de glissement dont la valeur normale est 10,5. En
## dessous de 2, on roule litteralement sur de la glace.
##
## Les valeurs etaient a 0,85 et 0,78 — lues comme un pourcentage d'adherence.
## La voiture chassait de l'arriere en permanence, se rattrapait, rechassait :
## d'ou le dandinement gauche-droite en acceleration. Et les roues patinant au
## lieu d'entrainer, elle perdait aussi de la reprise.
@export_range(0.5, 25.0, 0.1) var adherence_avant: float = 11.0

## Adherence des roues arriere. Legerement sous l'avant : au-dessus, la
## voiture sous-vire betement et ne tourne plus.
@export_range(0.5, 25.0, 0.1) var adherence_arriere: float = 10.0

## Hauteur de caisse au repos. Bas = sportif, haut = monospace mou.
@export_range(0.05, 0.8, 0.01) var suspension_course: float = 0.22

## Raideur des ressorts. Bas = la caisse plonge dans les virages.
##
## Elle decide aussi de la GARDE AU SOL, ce qui n'est pas evident : plus le
## ressort est mou, plus la caisse s'affaisse sur ses roues. A 42 elle ne
## gardait que 24 cm sous le plancher — et 9 degres de roulis en mangent 14.
## Le flanc raclait donc en virage, ce qui freinait net. A 140, la garde
## monte a 35 cm et le probleme disparait a la source.
@export_range(5.0, 500.0, 1.0) var suspension_raideur: float = 140.0

## Amortissement des suspensions.
##
## Il doit suivre la raideur, pas etre choisi seul : un ressort raide mal
## amorti oscille au lieu de se poser. L'ordre de grandeur utile est
## 0,5 x racine(raideur) — soit environ 3,2 pour une raideur de 42. La valeur
## etait a 0,6, cinq fois trop bas, et la caisse rebondissait a chaque
## transfert de charge.
@export_range(0.0, 20.0, 0.05) var suspension_amorti: float = 5.9

## Hauteur du centre de gravite, en metres par rapport a l'origine de la
## caisse. NEGATIF = plus bas, donc moins de roulis.
##
## C'est le reglage decisif du roulis, bien plus que la raideur. Par defaut
## Godot le place au centre du volume : la caisse penche alors tellement en
## virage qu'elle finit par toucher le sol de son flanc, ce qui freine
## brutalement et la fait rebondir en sortie. Le descendre sous l'essieu
## supprime la cause au lieu de raidir les ressorts pour la masquer.
@export_range(-1.2, 0.5, 0.05) var centre_gravite: float = -0.45

## Rigidite anti-roulis, en proportion. 0 = les deux roues d'un essieu sont
## independantes et la caisse penche librement ; 1 = elles sont solidaires.
@export_range(0.0, 1.0, 0.05) var anti_roulis: float = 0.55

# ------------------------------------------------------------------ camera
@export_group("Camera")

## Distance de la camera derriere le vehicule.
@export_range(1.0, 20.0, 0.1) var recul: float = 6.5

## Hauteur de la camera au dessus du vehicule.
@export_range(0.5, 10.0, 0.1) var hauteur: float = 2.4

## Lissage de la position. Bas = la camera colle, haut = elle traine.
## C'est le reglage qui change le plus la sensation de vitesse.
@export_range(0.01, 1.0, 0.01) var lissage_position: float = 0.14

## Lissage de la rotation. Independant du precedent, et volontairement.
@export_range(0.01, 1.0, 0.01) var lissage_rotation: float = 0.09

## Champ de vision a l'arret, en degres.
@export_range(40.0, 120.0, 1.0) var fov_arret: float = 70.0

## Champ de vision a pleine vitesse. L'ecart avec fov_arret fait le grisant.
@export_range(40.0, 130.0, 1.0) var fov_pleine_vitesse: float = 88.0

## Hauteur du point vise, au dessus du vehicule.
@export_range(0.0, 5.0, 0.1) var cible_hauteur: float = 1.2

## La camera se rapproche quand un mur la separe du sujet. Sans ca, elle
## passe au travers et on voit l'envers du decor — le defaut le plus visible
## d'une camera de poursuite, et celui qui ne pardonne pas dans un interieur.
@export var camera_collision: bool = true

## Distance conservee devant l'obstacle, en metres. Trop court, le plan de
## coupe de la camera entre quand meme dans le mur.
@export_range(0.05, 1.5, 0.05) var camera_marge: float = 0.32

## Vitesse a laquelle elle revient a son recul normal une fois degagee, en
## metres par seconde. Le rapprochement, lui, est INSTANTANE : traverser un
## mur ne serait-ce qu'une image se voit, alors qu'un retour progressif ne
## se remarque pas.
@export_range(0.5, 40.0, 0.5) var camera_retour: float = 7.0

@export_subgroup("Souris")

## Radians de rotation par pixel de souris. C'est LE reglage a bouger en
## premier si la visee parait molle ou nerveuse.
@export_range(0.0005, 0.02, 0.0005) var souris_sensibilite: float = 0.0032

## Inverse le haut et le bas.
@export var souris_inversee: bool = false

## Angle vertical minimal et maximal, en degres. Negatif = on regarde vers le
## bas. Au-dela de 80 la camera passe au-dessus du sujet et le cadrage part
## en vrille.
@export_range(-80.0, 0.0, 1.0) var tangage_min: float = -22.0
@export_range(0.0, 80.0, 1.0) var tangage_max: float = 62.0

## Temps sans toucher la souris avant que le recentrage automatique reprenne,
## en secondes. Sans ce delai, la camera ramene de force des qu'on lache la
## souris et on ne peut jamais regarder de cote en marchant.
@export_range(0.0, 6.0, 0.1) var souris_repos: float = 1.4

## Vitesse a laquelle la camera du VEHICULE revient dans l'axe apres une
## visee manuelle, en radians par seconde.
@export_range(0.2, 12.0, 0.1) var souris_retour: float = 2.2

## Bornes du recul reglable a la molette, en proportion du recul nominal.
@export_range(0.3, 1.0, 0.05) var zoom_min: float = 0.55
@export_range(1.0, 3.0, 0.05) var zoom_max: float = 1.8
@export_range(0.02, 0.5, 0.01) var zoom_pas: float = 0.12

# ------------------------------------------------------------------- rendu
@export_group("Rendu PS2")

## Largeur du rendu interne. La PS2 tournait autour de 512.
## Tout le reste de l'ecran est un agrandissement de cette image.
@export_range(160, 1280, 16) var largeur_rendu: int = 512

## Hauteur du rendu interne.
@export_range(120, 720, 8) var hauteur_rendu: int = 288

## Distance ou le brouillard commence a mordre, en metres.
@export_range(0.0, 200.0, 1.0) var brouillard_debut: float = 7.0

## Distance ou tout a disparu. C'est la limite d'affichage assumee.
@export_range(10.0, 400.0, 1.0) var brouillard_fin: float = 58.0

## Couleur du brouillard. Sert aussi de couleur de fond a l'horizon.
@export var brouillard_couleur: Color = Color(0.141, 0.157, 0.212)

## Couleur du ciel de nuit, au zenith.
@export var ciel_couleur: Color = Color(0.031, 0.039, 0.071)

## Lumiere ambiante. Sans elle, tout ce qui n'est pas sous un lampadaire
## est parfaitement noir.
@export_range(0.0, 1.0, 0.01) var ambiante: float = 0.16

## Filtrage lineaire des textures. Vrai = flou PS2. Faux = texels carres PS1.
@export var filtrage_lineaire: bool = true

# ------------------------------------------------------------------- lampes
@export_group("Lampadaires")

## Intensite de chaque lampadaire. C'est le reglage qui decide si la rue est
## sinistre ou accueillante.
@export_range(0.0, 40.0, 0.5) var lampe_energie: float = 9.0

## Rayon d'action, en metres. Au dela, la lumiere est coupee net.
@export_range(1.0, 80.0, 1.0) var lampe_portee: float = 24.0

## Courbe de decroissance. Bas = la lumiere porte loin et reste plate.
@export_range(0.1, 6.0, 0.1) var lampe_attenuation: float = 1.0

## Couleur des lampadaires. Le sodium orange est le plus caracteristique.
@export var lampe_couleur: Color = Color(1.0, 0.827, 0.596)

## Ombres portees. Coup de fouet visuel, mais couteux quand toutes les rues
## sont eclairees. A tester une fois la ville complete.
@export var lampe_ombres: bool = false

# ------------------------------------------------------------------- phares
@export_group("Phares")

## Les phares resolvent le probleme identifie en V1 : sans eux, le premier
## plan est noir des qu'on s'eloigne d'un lampadaire.
@export var phares_allumes: bool = true

@export_range(0.0, 40.0, 0.5) var phare_energie: float = 8.0

## Portee du faisceau, en metres. Trop court, on roule dans le vide.
@export_range(2.0, 120.0, 1.0) var phare_portee: float = 38.0

## Ouverture du cone, en degres.
@export_range(5.0, 90.0, 1.0) var phare_angle: float = 34.0

@export var phare_couleur: Color = Color(1.0, 0.949, 0.855)

# ------------------------------------------------------------------- audio
@export_group("Audio")

## Volumes en decibels, pas en pourcentage : l'oreille percoit le son de
## facon logarithmique. -6 dB, c'est la moitie de la puissance ressentie ;
## -80 dB, c'est le silence.
@export_range(-40.0, 6.0, 0.5) var volume_maitre: float = 0.0
@export_range(-40.0, 6.0, 0.5) var volume_ambiance: float = -8.0
@export_range(-40.0, 6.0, 0.5) var volume_effets: float = 0.0
@export_range(-40.0, 6.0, 0.5) var volume_musique: float = -6.0
@export_range(-40.0, 6.0, 0.5) var volume_interface: float = -3.0

## Duree du fondu au lancement de l'ambiance, en secondes. Une nappe qui
## demarre a plein volume s'entend comme un declic.
@export_range(0.0, 10.0, 0.1) var ambiance_fondu: float = 2.5

## Distance de reference des bruitages POSITIONNES — portes, portieres, pas.
## Bien plus courte que celle du moteur : une porte qui claque ne doit pas
## s'entendre a l'autre bout de la rue, alors qu'une voiture, si.
@export_range(1.0, 30.0, 0.5) var son_portee: float = 5.0
@export_range(5.0, 100.0, 1.0) var son_distance_max: float = 34.0

## Duree d'affichage d'un bandeau d'information en haut de l'ecran, en
## secondes. Un message qui reste colle est un message qu'on ne lit plus.
@export_range(0.5, 10.0, 0.1) var bandeau_duree: float = 3.0

@export_subgroup("Telephone")

## Temps de sortie et de rangement du combine, en secondes. Un telephone qui
## apparait d'un coup n'a pas de poids ; au-dela d'une demi-seconde on attend.
@export_range(0.05, 1.5, 0.05) var telephone_ouverture: float = 0.35

## Duree de la sonnerie avant que le correspondant decroche. C'est du temps
## mort assume : sans lui, appeler quelqu'un et lui parler sont le meme geste.
@export_range(0.0, 8.0, 0.1) var telephone_sonnerie: float = 2.2

## Taille du combine a l'ecran, en pixels du rendu interne (512 x 384).
@export_range(30.0, 140.0, 1.0) var telephone_largeur: float = 66.0
@export_range(50.0, 240.0, 1.0) var telephone_hauteur: float = 118.0

@export_subgroup("Pas")

## Longueur d'une foulee sonore, en fraction du cycle. Le pied se pose deux
## fois par cycle : ce reglage decale le declic pour le faire coincider avec
## le contact, qui n'arrive pas exactement au passage par zero.
@export_range(0.0, 1.0, 0.01) var pas_decalage: float = 0.18

## Variation de hauteur d'un pas a l'autre. Sans elle, quatre variantes
## sonnent quand meme comme une boucle.
@export_range(0.0, 0.5, 0.01) var pas_variation: float = 0.12

@export_subgroup("Roulement")

## Volume du roulement des pneus a pleine vitesse, en decibels.
@export_range(-40.0, 6.0, 0.5) var roulement_volume: float = -9.0

## Vitesse (km/h) a laquelle le roulement atteint son plein volume.
@export_range(5.0, 120.0, 1.0) var roulement_plein: float = 55.0

## Etirement de la hauteur du roulement avec la vitesse.
@export_range(0.0, 1.5, 0.05) var roulement_hauteur: float = 0.45

## En dessous de cette adherence (0 = roue qui patine totalement, 1 = accroche
## parfaite), les pneus crissent.
@export_range(0.0, 1.0, 0.01) var crissement_seuil: float = 0.55

## Temps minimum entre deux crissements, en secondes. Sans lui, une longue
## glissade en declenche un par image.
@export_range(0.1, 5.0, 0.1) var crissement_repos: float = 0.9

@export_subgroup("Moteur")

## Volume des boucles moteur. C'est le son le plus present du jeu : trop
## fort il fatigue en deux minutes, trop bas la conduite parait morte.
@export_range(-40.0, 6.0, 0.5) var moteur_volume: float = -4.0

## Distance de reference pour l'attenuation, en metres. Plus c'est grand,
## plus la voiture s'entend de loin.
@export_range(2.0, 60.0, 1.0) var moteur_portee: float = 14.0

## Vitesse a laquelle le regime sonore suit la vitesse reelle. Sans ce
## lissage, le moindre a-coup de la physique s'entend comme un hoquet.
@export_range(0.5, 20.0, 0.1) var moteur_reactivite: float = 4.0

## Variation de hauteur appliquee A L'INTERIEUR de chaque couche. Affine la
## progression entre deux boucles ; au-dela de 0,3 l'echantillon s'entend.
@export_range(0.0, 0.6, 0.01) var moteur_variation_hauteur: float = 0.18

# ------------------------------------------------------------------ joueur
@export_group("Joueur a pied")

## Vitesse de marche en m/s.
@export_range(0.5, 12.0, 0.1) var marche_vitesse: float = 4.2

## Acceleration au sol. Haut = demarrage sec.
@export_range(1.0, 60.0, 0.5) var marche_acceleration: float = 22.0

## Distance maximale pour entrer dans un vehicule.
@export_range(0.5, 8.0, 0.1) var portee_interaction: float = 3.2

## Hauteur des yeux a pied.
@export_range(0.5, 2.5, 0.05) var oeil_hauteur: float = 1.65

## Hauteur maximale d'obstacle franchie sans sauter, en metres. Les trottoirs
## font 18 cm : sans ce franchissement, on reste bloque contre eux, ce qui est
## intenable dans une ville. Trop haut, on escalade les voitures.
@export_range(0.0, 0.8, 0.01) var hauteur_marche: float = 0.34

## Vitesse de rotation du personnage vers sa direction de marche, en tours
## par seconde. Bas = il pivote lourdement, haut = il se retourne net.
@export_range(0.2, 12.0, 0.1) var marche_rotation: float = 5.0

## Vitesse de pivot sur place, en degres par seconde. Gauche et droite ne
## deplacent pas : elles tournent. Trop bas, on passe son temps a viser une
## porte ; trop haut, on ne peut plus s'arreter dans une direction.
@export_range(30.0, 400.0, 5.0) var pivot_vitesse: float = 165.0

## Vitesse de marche arriere, en proportion de la vitesse avant. On recule
## toujours plus lentement qu'on avance.
@export_range(0.1, 1.0, 0.05) var marche_arriere: float = 0.55

@export_subgroup("Camera a pied")

## Recul de la camera quand on marche. Plus court qu'en voiture.
@export_range(1.0, 12.0, 0.1) var pieton_recul: float = 3.6

@export_range(0.5, 6.0, 0.1) var pieton_hauteur: float = 1.9

@export_range(0.01, 1.0, 0.01) var pieton_lissage: float = 0.22

## Vitesse a laquelle la camera se replace derriere le personnage, en
## radians par seconde.
##
## Elle doit rester AU-DESSUS de pivot_vitesse, sinon elle prend un retard
## qui s'accumule tant qu'on tourne : a 1,6 rad/s contre un pivot a 165 deg/s
## (2,9 rad/s), le personnage avait fait un demi-tour de plus qu'elle au bout
## d'une seconde et demie. Ici 4,0 rad/s, soit 229 deg/s : le retard se
## stabilise a quelques degres au lieu de croitre.
@export_range(0.1, 12.0, 0.1) var pieton_recentrage: float = 4.0

@export_subgroup("Marche procedurale")

## Longueur d'une foulee, en metres. C'est elle qui cale la cadence sur la
## vitesse reelle : la phase avance avec la DISTANCE parcourue, pas avec le
## temps, donc les pieds ne patinent jamais.
@export_range(0.3, 2.5, 0.05) var foulee: float = 1.15

## Amplitude du balancement des cuisses, en degres.
@export_range(0.0, 80.0, 1.0) var amplitude_jambe: float = 34.0

## Flexion maximale du genou, en degres. Le genou ne plie que vers l'arriere.
@export_range(0.0, 110.0, 1.0) var amplitude_genou: float = 46.0

## Balancement des bras, en degres. Oppose aux jambes.
@export_range(0.0, 70.0, 1.0) var amplitude_bras: float = 26.0

## Flexion du coude, en degres.
@export_range(0.0, 90.0, 1.0) var amplitude_coude: float = 22.0

## Oscillation verticale du bassin a chaque pas, en metres.
@export_range(0.0, 0.20, 0.005) var rebond: float = 0.045

## Roulis du torse a chaque foulee, en degres. Discret, mais c'est lui qui
## enleve l'impression de pantin.
@export_range(0.0, 20.0, 0.5) var roulis_torse: float = 4.0


@export_group("Maisons")

## Distance a laquelle la porte propose d'entrer, en metres. Plus genereuse
## que pour le vehicule : on vise une porte de face, on ne tourne pas autour.
@export_range(0.5, 8.0, 0.1) var portee_porte: float = 3.0

## Duree d'une moitie de fondu au noir, en secondes. Le passage complet en
## dure donc le double. C'est le seul masque dont on dispose : la teleportation
## vers l'interieur est instantanee, et sans ce noir on la verrait.
@export_range(0.05, 1.5, 0.05) var fondu_porte: float = 0.35

## Recul de la camera a l'interieur. Les pieces font sept metres de large :
## le recul de rue collerait la camera dans le mur d'en face.
@export_range(0.6, 6.0, 0.1) var interieur_recul: float = 2.1

@export_range(0.3, 4.0, 0.1) var interieur_hauteur: float = 1.5

## Distance a laquelle un habitant accepte de parler, en metres. Plus courte
## que la porte : sinon, entrer dans une piece ou quelqu'un se tient pres de
## l'entree proposerait les deux choses a la fois.
@export_range(0.5, 6.0, 0.1) var portee_dialogue: float = 2.2


@export_group("Roue des outils")

## Rayon du cercle de parts, en pixels de l'ecran interne (512 x 384).
@export_range(30.0, 160.0, 1.0) var roue_rayon: float = 92.0

## Duree d'ouverture, en secondes. Court : c'est un geste, pas un menu.
@export_range(0.02, 0.6, 0.01) var roue_ouverture: float = 0.12

## Ralenti pendant que la roue est ouverte. 1 = pas de ralenti, 0 = arret
## complet. Les jeux de l'epoque ralentissaient sans figer, ce qui garde le
## monde vivant derriere sans mettre le joueur en danger.
@export_range(0.05, 1.0, 0.05) var roue_ralenti: float = 0.25


@export_group("Temps")

## Combien d'heures de jeu passent par seconde reelle. A zero, l'heure est
## figee — c'est le reglage par defaut, parce qu'un cycle qui tourne pendant
## qu'on regle un autre curseur rend tout reglage impossible a juger.
##
## 0.05 fait une journee complete en huit minutes, ce qui est le rythme d'un
## GTA de l'epoque.
@export_range(0.0, 1.0, 0.005) var temps_vitesse: float = 0.0

@export_group("Jour")

## Les couleurs du plein jour. Elles ne remplacent plus celles de nuit : le
## jeu MELANGE les deux selon l'heure, et l'aube comme le crepuscule sont des
## positions intermediaires. Voir Reglages.nuit_part().

@export var jour_ciel: Color = Color(0.404, 0.573, 0.788)

## Brume de chaleur, pas brouillard. Elle blanchit le lointain au lieu de
## l'assombrir — c'est ce qui donne l'echelle du desert a midi.
@export var jour_brouillard: Color = Color(0.741, 0.769, 0.784)

@export_range(0.0, 3.0, 0.01) var jour_ambiante: float = 0.62

## Le soleil. Haut et dur : Albuquerque est a deux mille metres, la lumiere
## y est franche et les ombres nettes.
@export_range(0.0, 8.0, 0.05) var soleil_energie: float = 1.35
@export var soleil_couleur: Color = Color(1.0, 0.973, 0.925)

## Hauteur du soleil au-dessus de l'horizon, en degres. Bas = fin de journee,
## ombres longues. Haut = midi, ombres courtes.
@export_range(5.0, 89.0, 1.0) var soleil_hauteur: float = 58.0

## Orientation du soleil, en degres.
@export_range(-180.0, 180.0, 1.0) var soleil_azimut: float = 35.0

@export var soleil_ombres: bool = true

## De jour, on voit beaucoup plus loin. Garder les distances de nuit
## donnerait une purée blanche à trente metres.
@export_range(10.0, 400.0, 5.0) var jour_brouillard_debut: float = 90.0
@export_range(20.0, 900.0, 5.0) var jour_brouillard_fin: float = 340.0

## Combien la brume mange le ciel. A 1, elle le recouvre entierement et on
## obtient un aplat gris pale au lieu du bleu d'Albuquerque. C'est bon de
## nuit, ou le ciel EST le brouillard ; de jour il faut le laisser respirer.
@export_range(0.0, 1.0, 0.05) var jour_brume_ciel: float = 0.25


@export_group("Affichage")

## Duree d'affichage du nom d'un outil qu'on vient d'equiper, en secondes.
## L'objet se voit dans la main : le nom n'a d'interet qu'a cet instant.
@export_range(0.3, 6.0, 0.1) var hud_annonce: float = 1.6


# ------------------------------------------------------------ jour ou nuit

const MONDE := "res://donnees/monde.json"

## L'heure du monde, de 0 a 24. C'est desormais LA source du jour et de la
## nuit, et tout le reste en decoule.
##
## Elle est statique parce que la question « fait-il jour » est posee par cinq
## systemes qui n'ont aucune raison de se connaitre. Un booleen recopie dans
## chacun finirait par en contredire un autre — un ciel de midi sur des
## fenetres allumees, sans savoir lequel a tort.
static var heure: float = -1.0

## Combien de temps met l'aube, en heures. En dessous d'une demi-heure la
## bascule se voit comme un interrupteur ; au-dela de deux, on ne sait plus
## quelle heure il est.
const TRANSITION := 1.2

## Le jour dure de la fin de l'aube au debut du crepuscule.
const AUBE := 6.5
const CREPUSCULE := 19.5


## Lit l'heure de depart dans donnees/monde.json, une seule fois.
##
## Le fichier ne porte plus qu'une intention — "jour" ou "nuit" — parce que
## c'est ce que la ligne de commande sait dire. Elle devient une heure ronde,
## et le jeu prend le relais a partir de la.
static func _heure_initiale() -> float:
	var moment := "nuit"
	if FileAccess.file_exists(MONDE):
		var lu: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(MONDE))
		if typeof(lu) == TYPE_DICTIONARY:
			var d := lu as Dictionary
			# Une heure explicite l'emporte : c'est ce qui permettra un jour de
			# reprendre une partie a l'heure ou on l'a quittee.
			if d.has("heure"):
				return clampf(float(d["heure"]), 0.0, 24.0)
			moment = str(d.get("moment", "nuit"))
		else:
			push_error("reglages : %s illisible, on reste de nuit" % MONDE)
	return 13.0 if moment == "jour" else 22.0


## Quelle part de nuit : 0 en plein jour, 1 en pleine nuit, et tout entre les
## deux a l'aube et au crepuscule.
##
## C'est la seule fonction que les autres systemes devraient consulter. Le
## booleen est_jour() reste pour ce qui ne peut pas nuancer — allumer ou non
## les phares — mais il en derive, il ne le contredit jamais.
static func nuit_part() -> float:
	if heure < 0.0:
		heure = _heure_initiale()
	if heure >= AUBE + TRANSITION and heure <= CREPUSCULE:
		return 0.0
	if heure <= AUBE or heure >= CREPUSCULE + TRANSITION:
		return 1.0
	if heure < AUBE + TRANSITION:
		return 1.0 - (heure - AUBE) / TRANSITION          # l'aube
	return (heure - CREPUSCULE) / TRANSITION              # le crepuscule


## Fait-il jour ? Derive de l'heure, jamais pose a part.
static func est_jour() -> bool:
	return nuit_part() < 0.5


# Les accesseurs melangent les deux jeux de valeurs au lieu d'en choisir un.
#
# C'est tout ce qu'il a fallu changer pour rendre le cycle continu : la
# structure separait deja proprement « les couleurs de jour » et « celles de
# nuit », et il ne manquait qu'un curseur entre les deux.
func _melange(de_nuit: Color, de_jour: Color) -> Color:
	return de_jour.lerp(de_nuit, nuit_part())


func ciel() -> Color:
	return _melange(ciel_couleur, jour_ciel)


func brume() -> Color:
	return _melange(brouillard_couleur, jour_brouillard)


func lumiere_ambiante() -> float:
	return lerpf(jour_ambiante, ambiante, nuit_part())


func brume_debut() -> float:
	return lerpf(jour_brouillard_debut, brouillard_debut, nuit_part())


func brume_fin() -> float:
	return lerpf(jour_brouillard_fin, brouillard_fin, nuit_part())


## Combien le brouillard mange le ciel. De nuit il le recouvre entierement —
## le ciel EST le brouillard ; de jour il faut le laisser respirer, sinon on
## obtient un aplat gris pale au lieu du bleu d'Albuquerque.
func brume_ciel() -> float:
	return lerpf(jour_brume_ciel, 1.0, nuit_part())
