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

var _reglages: Reglages
var _lecteur: AnimationPlayer
var _nom: String = ""
var _duree: float = 1.0

## Position dans le cycle, de 0 a 1.
var _phase: float = 0.0
var _depuis_le_pas: float = 0.0

## Vitesse a laquelle le cycle se fige quand on s'arrete. Une animation coupee
## net laisse le personnage une jambe en l'air.
const REPOS := 6.0


func _init(reglages: Reglages) -> void:
	_reglages = reglages


## Retrouve l'AnimationPlayer sous ce noeud. Renvoie faux s'il n'y en a pas —
## l'appelant retombe alors sur la silhouette procedurale.
func recenser(racine: Node) -> bool:
	_lecteur = racine.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _lecteur == null:
		return false
	for candidat in [CYCLE, COURSE]:
		if _lecteur.has_animation(candidat):
			_nom = candidat
			break
	if _nom == "":
		var toutes := _lecteur.get_animation_list()
		if toutes.is_empty():
			push_warning("demarche : aucune animation dans %s" % racine.name)
			return false
		_nom = toutes[0]
		push_warning("demarche : ni '%s' ni '%s', on prend '%s'"
				% [CYCLE, COURSE, _nom])

	var anim := _lecteur.get_animation(_nom)
	_duree = maxf(0.01, anim.length)
	anim.loop_mode = Animation.LOOP_LINEAR
	# On JOUE puis on met en pause : sans lecture prealable, seek() ne pose
	# rien et le personnage reste en pose de repos, parfaitement immobile
	# pendant qu'il traverse la rue.
	_lecteur.play(_nom)
	_lecteur.pause()
	return true


## A appeler chaque image de physique, avec la vitesse au sol en m/s.
##
## La vitesse peut etre NEGATIVE : le cycle tourne alors a l'envers et le
## personnage marche vraiment a reculons.
func avancer(vitesse_au_sol: float, delta: float) -> void:
	if _lecteur == null:
		return

	if absf(vitesse_au_sol) < 0.15:
		# Retour a la pose de depart, sans a-coup : on ramene la phase vers
		# zero au lieu de couper l'animation.
		_phase = lerpf(_phase, 0.0, clampf(REPOS * delta, 0.0, 1.0))
		_lecteur.seek(_phase * _duree, true)
		_depuis_le_pas = maxf(_depuis_le_pas, _reglages.foulee * 0.35)
		return

	_phase = fposmod(_phase + vitesse_au_sol * delta
			/ maxf(0.05, _reglages.foulee), 1.0)
	_lecteur.seek(_phase * _duree, true)

	# Deux pieds par foulee. On compte la DISTANCE et pas la phase : la phase
	# tourne a l'envers en marche arriere, et detecter un franchissement de
	# seuil dans les deux sens avec le bouclage demande trois cas particuliers.
	var demi := maxf(0.05, _reglages.foulee) * 0.5
	_depuis_le_pas += absf(vitesse_au_sol) * delta
	if _depuis_le_pas >= demi:
		_depuis_le_pas = fmod(_depuis_le_pas, demi)
		pas.emit()


## L'animation en cours, pour les tests. Un personnage immobile ressemble
## exactement a un personnage sans animation.
func animation() -> String:
	return _nom


func phase() -> float:
	return _phase
