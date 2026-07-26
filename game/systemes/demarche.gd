# La marche d'un personnage a SQUELETTE, pilotee par la distance.
#
# Elle remplace silhouette.gd pour qui a un vrai rig. Le principe ne change
# pas, et c'est le seul qui compte : la phase du cycle avance avec la DISTANCE
# PARCOURUE, jamais avec le temps. Les pieds ne patinent donc a aucune vitesse,
# et il n'y a aucun melange d'animations a doser.
#
# La difference avec silhouette.gd est ce qu'on pilote. La, on faisait tourner
# dix segments rigides avec des sinus ecrits a la main ; ici on POSITIONNE une
# animation faite par quelqu'un dont c'est le metier. La seule chose qu'on
# garde, c'est le refus de laisser l'horloge decider.
#
# Concretement : au lieu de jouer l'animation et d'esperer que sa vitesse
# corresponde, on la met en pause et on lui demande l'image qui correspond a la
# distance parcourue.
class_name Demarche
extends RefCounted

## Emis a chaque contact d'un pied avec le sol.
##
## Comme pour silhouette.gd : la demarche ne joue AUCUN son. Elle ne sait pas
## sur quoi elle marche ni de qui elle est la demarche.
signal pas()

## Ce qu'on cherche dans le .glb. Les noms viennent du rig livre ; s'ils
## changent, le personnage reste immobile et le dit.
const CYCLE := "Walking"
const COURSE := "Running"
const IMMOBILE := "Repos"

## Les allures du personnage, et les clips que chacune accepte, DU MEILLEUR AU
## MOINS BON. Le premier present dans le modele gagne.
##
## Cette liste de repli est ce qui permet a un meme code d'animer Walter, qui a
## recu ses clips fabriques, et un figurant qui n'a que ce que son pack
## contenait. Un personnage sans « Repos » retombe sur l'ancien comportement
## sans que rien ne soit a declarer.
const ALLURES := {
	"repos": ["Repos"],
	"marche": ["Marche", "Walking"],
	"trot": ["Trot", "Running"],
	"course": ["Course", "Running"],
	"accroupi": ["Accroupi"],
	"accroupi_marche": ["AccroupiMarche", "Marche", "Walking"],
	"saut": ["Saut"],
}

## Les allures qui avancent AVEC L'HORLOGE et non avec la distance.
##
## Tout le reste du fichier existe pour empecher le temps de piloter la marche.
## Le repos est l'exception, et c'est logique : on respire en secondes, pas en
## metres. Un personnage immobile dont l'animation serait calee sur la distance
## ne respirerait jamais.
## Le saut et l'accroupi immobile s'y ajoutent pour la meme raison : ils ne
## sont pas des cycles de deplacement. Un saut cale sur la distance parcourue
## se figerait au sommet de la parabole, la ou la vitesse horizontale est
## constante mais ou il ne se passe rien.
const AU_TEMPS := ["repos", "accroupi", "saut"]

## LES GESTES : des clips qui ne bouclent pas et qui ont une fin.
##
## Une allure est un etat — on marche tant qu'on avance. Un geste est un
## evenement : il commence, il dure, il se termine tout seul, et pendant ce
## temps il prend la main sur l'allure. Se coiffer en marchant marcherait,
## mais lire un livre en trottinant non, et la difference ne se decrit pas
## avec le vocabulaire des allures.
const GESTES := {
	"coiffer": "Coiffer",
	"lire": "Lire",
}

var _reglages: Reglages
var _lecteur: AnimationPlayer
var _nom: String = ""
var _duree: float = 1.0

## Position dans le cycle, de 0 a 1.
var _phase: float = 0.0
var _depuis_le_pas: float = 0.0
var _disponibles: PackedStringArray = PackedStringArray()

## Clips reclames qui n'existent pas. On ne rale qu'une fois par nom : une
## allure demandee a chaque image noierait la console.
var _manquantes: Dictionary = {}

## Longueur d'une foulee, en metres. Elle CHANGE avec l'allure : on ne fait pas
## les memes enjambees en marchant et en courant, et c'est elle qui accorde la
## vitesse des jambes a celle du deplacement. Une foulee trop courte donne un
## personnage qui pedale, trop longue un personnage qui glisse.
var foulee: float = 1.15

## Vrai tant que l'allure en cours tourne a l'horloge.
var _au_temps: bool = false

## Le geste en cours, son temps restant, et l'allure a laquelle revenir.
var _geste: String = ""
var _reste: float = 0.0
var _apres: String = ""

## Vitesse a laquelle le cycle se fige quand on s'arrete, POUR UN PERSONNAGE
## SANS CLIP DE REPOS. Une animation coupee net laisse le personnage une jambe
## en l'air ; celui-ci revient a l'image zero de son cycle de marche.
const RETOUR := 6.0


func _init(reglages: Reglages) -> void:
	_reglages = reglages
	foulee = reglages.foulee


## Retrouve l'AnimationPlayer sous ce noeud. Renvoie faux s'il n'y en a pas —
## l'appelant retombe alors sur la silhouette procedurale.
func recenser(racine: Node) -> bool:
	_lecteur = racine.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _lecteur == null:
		return false
	_disponibles = _lecteur.get_animation_list()
	if _disponibles.is_empty():
		push_warning("demarche : aucune animation dans %s" % racine.name)
		return false

	# On demarre au REPOS quand le modele en a un. C'est l'etat dans lequel on
	# voit le personnage en premier, et le plus longtemps : le laisser
	# apparaitre fige sur une image de course, jambes ecartees, est ce qu'on
	# remarque avant tout le reste.
	for candidat in [IMMOBILE, CYCLE, COURSE]:
		if _disponibles.has(candidat):
			_nom = candidat
			break
	if _nom == "":
		_nom = _disponibles[0]
		push_warning("demarche : ni '%s' ni '%s' ni '%s', on prend '%s'"
				% [IMMOBILE, CYCLE, COURSE, _nom])

	var anim := _lecteur.get_animation(_nom)
	_duree = maxf(0.01, anim.length)
	anim.loop_mode = Animation.LOOP_LINEAR
	_au_temps = (_nom == IMMOBILE)
	# On JOUE puis on met en pause : sans lecture prealable, seek() ne pose
	# rien et le personnage reste en pose de repos, parfaitement immobile
	# pendant qu'il traverse la rue.
	_lecteur.play(_nom)
	if not _au_temps:
		_lecteur.pause()
	return true


## Ce modele sait-il tenir cette allure ? Lu par les tests, et par les
## personnages qui doivent s'adapter a ce que leur pack contenait.
func connait(nom: String) -> bool:
	for candidat in ALLURES.get(nom, []):
		if _disponibles.has(candidat):
			return true
	return false


## Change d'allure. Renvoie faux si le clip demande n'existe pas — le
## personnage garde alors le sien, ce qui vaut mieux qu'un arret net.
##
## Changer de clip REMET LA PHASE A SA PLACE et pas a zero : passer du trot a
## la course au milieu d'une foulee ne doit pas replanter le pied.
func allure(nom: String) -> bool:
	# Un geste en cours garde la main. On retient quand meme l'allure demandee :
	# a la fin du geste, on doit reprendre celle du moment, pas celle d'il y a
	# cinq secondes.
	if _geste != "":
		_apres = nom
		return true

	var clip := ""
	for candidat in ALLURES.get(nom, []):
		if _disponibles.has(candidat):
			clip = candidat
			break
	if clip == "":
		if not _manquantes.has(nom):
			_manquantes[nom] = true
			push_warning("demarche : aucun clip pour l'allure '%s' parmi %s. "
					% [nom, ALLURES.get(nom, [])]
					+ "Disponibles : %s" % ", ".join(_disponibles))
		return false
	if clip == _nom:
		return true

	_nom = clip
	var anim := _lecteur.get_animation(_nom)
	_duree = maxf(0.01, anim.length)
	anim.loop_mode = Animation.LOOP_LINEAR
	_au_temps = AU_TEMPS.has(nom)
	if _au_temps:
		# Le seul endroit ou le moteur joue l'animation lui-meme, et le seul ou
		# l'on demande un fondu : arriver au repos depuis une foulee doit
		# glisser, pas claquer. Le fondu ne peut se derouler que sur une
		# animation qui TOURNE — c'est pour ca qu'on ne met pas en pause ici, et
		# qu'on ne demande aucun fondu dans l'autre sens.
		_lecteur.play(_nom, 0.25)
	else:
		_lecteur.play(_nom)
		_lecteur.seek(_phase * _duree, true)
		_lecteur.pause()
	return true


## A appeler chaque image de physique, avec la vitesse au sol en m/s.
##
## La vitesse peut etre NEGATIVE : le cycle tourne alors a l'envers et le
## personnage marche vraiment a reculons.
func avancer(vitesse_au_sol: float, delta: float) -> void:
	if _lecteur == null:
		return

	if _geste != "":
		# Le moteur joue le geste tout seul, a l'horloge. On ne fait que compter.
		_reste -= delta
		if _reste <= 0.0:
			_terminer_le_geste()
		return

	if _au_temps:
		# Le moteur joue tout seul. On garde la phase a jour pour que reprendre
		# la marche ne reparte pas d'une image arbitraire, et on n'emet aucun
		# pas : personne ne fait de bruit de semelle en respirant.
		_phase = fposmod(_lecteur.current_animation_position / _duree, 1.0)
		return

	if absf(vitesse_au_sol) < 0.15:
		# Personnage sans clip de repos : retour a la pose de depart, sans
		# a-coup. On ramene la phase vers zero au lieu de couper l'animation.
		_phase = lerpf(_phase, 0.0, clampf(RETOUR * delta, 0.0, 1.0))
		_lecteur.seek(_phase * _duree, true)
		_depuis_le_pas = maxf(_depuis_le_pas, foulee * 0.35)
		return

	_phase = fposmod(_phase + vitesse_au_sol * delta
			/ maxf(0.05, foulee), 1.0)
	_lecteur.seek(_phase * _duree, true)

	# Deux pieds par foulee. On compte la DISTANCE et pas la phase : la phase
	# tourne a l'envers en marche arriere, et detecter un franchissement de
	# seuil dans les deux sens avec le bouclage demande trois cas particuliers.
	var demi := maxf(0.05, foulee) * 0.5
	_depuis_le_pas += absf(vitesse_au_sol) * delta
	if _depuis_le_pas >= demi:
		_depuis_le_pas = fmod(_depuis_le_pas, demi)
		pas.emit()


## Lance un geste. Renvoie sa DUREE en secondes, ou zero si le modele ne le
## connait pas — l'appelant sait alors qu'il ne s'est rien passe, au lieu de
## bloquer le joueur pendant une animation qui ne joue pas.
func geste(nom: String) -> float:
	if _lecteur == null:
		return 0.0
	var clip := str(GESTES.get(nom, ""))
	if clip == "" or not _disponibles.has(clip):
		if not _manquantes.has(nom):
			_manquantes[nom] = true
			push_warning("demarche : pas de clip '%s' pour le geste '%s'"
					% [clip, nom])
		return 0.0
	if _geste == nom:
		return _reste

	# _apres se remplit tout seul : le joueur appelle allure() a chaque image et
	# celle-ci se contente de la retenir tant qu'un geste tourne. On repart donc
	# de l'allure du moment ou le geste finit, pas de celle d'avant.
	_apres = ""
	_geste = nom
	_nom = clip
	var anim := _lecteur.get_animation(clip)
	anim.loop_mode = Animation.LOOP_NONE
	_duree = maxf(0.01, anim.length)
	_reste = _duree
	_au_temps = true
	# Un fondu court : un geste qui claque depuis la marche se lit comme un
	# changement de personnage.
	_lecteur.play(clip, 0.15)
	return _duree


## Le geste en cours, ou "" — lu par le controleur pour savoir s'il doit encore
## bloquer le joueur, et par les tests.
func geste_en_cours() -> String:
	return _geste


## Interrompt le geste. C'est ce qui rend la lecture annulable : on bouge, on
## arrete de lire.
func annuler_le_geste() -> void:
	if _geste != "":
		_terminer_le_geste()


func _terminer_le_geste() -> void:
	_geste = ""
	_reste = 0.0
	# On force la reprise en effacant le clip courant : allure() court-circuite
	# quand le clip demande est deja en place, et il l'est justement encore.
	var reprendre := _apres if _apres != "" else "repos"
	_nom = ""
	allure(reprendre)


## L'animation en cours, pour les tests. Un personnage immobile ressemble
## exactement a un personnage sans animation.
func animation() -> String:
	return _nom


func phase() -> float:
	return _phase
