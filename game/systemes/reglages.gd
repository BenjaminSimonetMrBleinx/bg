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

## Adherence laterale des roues avant.
@export_range(0.0, 2.0, 0.01) var adherence_avant: float = 0.85

## Adherence laterale des roues arriere. En dessous de l'avant, ca part en glisse.
@export_range(0.0, 2.0, 0.01) var adherence_arriere: float = 0.78

## Hauteur de caisse au repos. Bas = sportif, haut = monospace mou.
@export_range(0.05, 0.8, 0.01) var suspension_course: float = 0.22

## Raideur des ressorts. Bas = la caisse plonge dans les virages.
@export_range(5.0, 200.0, 1.0) var suspension_raideur: float = 42.0

## Amortissement. Trop bas, la voiture rebondit sans fin.
@export_range(0.0, 5.0, 0.05) var suspension_amorti: float = 0.6

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

@export_subgroup("Camera a pied")

## Recul de la camera quand on marche. Plus court qu'en voiture.
@export_range(1.0, 12.0, 0.1) var pieton_recul: float = 3.6

@export_range(0.5, 6.0, 0.1) var pieton_hauteur: float = 1.9

@export_range(0.01, 1.0, 0.01) var pieton_lissage: float = 0.22

## Vitesse a laquelle la camera se replace derriere le personnage, en
## radians par seconde. Elle ne le fait que lorsqu'il s'ELOIGNE d'elle :
## sinon la camera suivrait le personnage qui suit la camera, et reculer
## ferait tourner en rond sans jamais se stabiliser.
@export_range(0.1, 8.0, 0.1) var pieton_recentrage: float = 1.6

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
