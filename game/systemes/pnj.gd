# Un personnage non joueur, immobile chez lui.
#
# Il ne marche pas et n'a aucune intelligence : il se tourne vers le joueur
# quand celui-ci approche, et c'est tout. A ce stade du projet, se tourner
# suffit a faire la difference entre un decor et quelqu'un.
class_name Pnj
extends Node3D

## Cle dans donnees/dialogues.json. C'est le seul lien entre ce personnage
## et ce qu'il raconte.
@export var cle: String = ""

@export var geometrie: PackedScene

## L'animation qu'il joue en boucle. Vide = sa pose de repos.
##
## Tuco est ASSIS derriere son bureau : un chef de cartel qui recoit debout au
## milieu de son bureau n'a pas la meme autorite, et la reference le montre
## cale dans son fauteuil de cuir.
@export var pose: String = ""

## Vitesse a laquelle il pivote vers le joueur, en radians par seconde.
@export_range(0.2, 12.0, 0.1) var rotation_vitesse: float = 3.0

## Distance a laquelle il remarque le joueur, en metres.
@export_range(0.5, 12.0, 0.1) var attention: float = 4.5

## Il n'a quelque chose a dire QU'A PARTIR de cette etape de la mission.
## Vide = il parle toujours, ce qui reste le cas de la plupart.
##
## Le meme champ que Point.etape_minimale, et il manquait ici. Un Pnj parlait
## des qu'on etait a portee, quel que soit l'etat du jeu : Jesse reprochait un
## retard devant le camping-car a quelqu'un qui n'avait pas encore commence la
## mission. Ce n'est pas Jesse qui etait mal ecrit — c'est que rien, dans ce
## fichier, ne pouvait le faire taire. Le passage ferme vers le desert cachait
## le trou ; l'ouvrir l'a montre.
@export var etape_minimale: String = ""

var _cible: Node3D
var _cap_repos: float = 0.0


## Tous les PNJ sont dans ce groupe. C'est ainsi que le tir les trouve, sans
## qu'aucun d'eux n'ait a porter de corps de collision : une balle teste la
## distance du rayon a chaque torse, ce qui suffit largement a la resolution
## du jeu et ne demande de toucher a aucune scene existante.
const GROUPE := "cible"

## Hauteur du torse au-dessus des pieds, en metres. C'est LA qu'on vise, pas
## a l'origine du noeud qui est au sol : viser les pieds oblige a tirer par
## terre pour toucher quelqu'un.
const TORSE := 1.15

## Rayon touchable, en metres. Genereux : le jeu se joue a la souris sur une
## image de 512 pixels de large, ou un personnage a vingt metres fait huit
## pixels. Exiger la precision au centimetre ne rendrait pas le tir difficile,
## juste cassé.
const LARGEUR := 0.45

var abattu: bool = false


func _ready() -> void:
	_cap_repos = rotation.y
	_origine = position
	add_to_group(GROUPE)
	if geometrie == null:
		push_error("pnj %s : aucune geometrie" % cle)
		return
	var corps := geometrie.instantiate()
	# LE CORPS EST SUSPENDU A UN PIVOT, ET PAS ACCROCHE DIRECTEMENT.
	#
	# Les modeles rigges livres regardent vers +Z, c'est-a-dire face a la
	# camera. importer_perso.py les retourne bien a l'import, mais leurs
	# animations portent un canal sur le noeud racine qui ECRASE cette rotation
	# des la premiere image jouee — c'est deja documente dans scenes/joueur.tscn,
	# ou Walter est retourne par un noeud parent pour cette raison exacte.
	#
	# Les PNJ n'avaient pas ce noeud. Tous ceux qui portent des animations —
	# Jesse, Tuco — tournaient donc le dos a qui leur parlait, et les
	# compensations posees a la main dans les scenes ne faisaient que deplacer
	# le probleme. On applique ici la meme parade qu'au joueur, une fois pour
	# toutes.
	#
	# LE CRITERE EST LA PRESENCE D'UN LECTEUR D'ANIMATION, pas le nom du
	# fichier : c'est exactement la cause. Un modele sans animation garde la
	# rotation posee a l'import et ne doit surtout pas etre retourne une
	# seconde fois — c'est le cas de Skyler et des passants.
	var pivot := Node3D.new()
	pivot.name = "Corps"
	add_child(pivot)
	pivot.add_child(corps)
	var lecteur := corps.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if lecteur != null:
		pivot.rotation.y = PI
	_respirer(lecteur)


# Un personnage a squelette JOUE SA POSE DE REPOS.
#
# Sans ca il garde le clip que son fichier portait, et les modeles livres
# arrivent en pose en T : Tuco attendait derriere son bureau les bras en
# croix. Le clip de repos leur a ete recopie depuis Walter — meme squelette,
# memes noms d'os — et il suffit de le lancer.
#
# On ne pilote rien d'autre : un PNJ de cette mission ne se deplace pas. Le
# jour ou il le faudra, c'est Demarche qui prendra la suite.
func _respirer(lecteur: AnimationPlayer) -> void:
	if lecteur == null:
		return
	_lecteur = lecteur
	for candidat in [pose, Demarche.IMMOBILE, Demarche.CYCLE]:
		if candidat == "":
			continue
		if lecteur.has_animation(candidat):
			var anim := lecteur.get_animation(candidat)
			anim.loop_mode = Animation.LOOP_LINEAR
			lecteur.play(candidat)
			# Chacun demarre a un endroit different de son cycle : trois
			# hommes de main qui respirent a l'unisson se lisent comme un seul
			# personnage copie trois fois, ce qu'ils sont.
			lecteur.seek(randf() * anim.length, true)
			return


## Le centre de la cible, en coordonnees du monde.
func point_vise() -> Vector3:
	return global_position + Vector3.UP * TORSE


## Il prend une balle. On ne gere aucun point de vie : dans cette mission, tirer
## sur quelqu'un declenche une scene, ce n'est jamais un echange de coups.
func abattre() -> void:
	if abattu:
		return
	abattu = true
	set_process(false)


## A-t-il quelque chose a dire maintenant ?
##
## Meme role que Point.offert, moins la distance : c'est le controleur qui
## mesure, parce que la portee de dialogue est un reglage commun et pas une
## propriete de ce personnage.
##
## Sans mission en cours, un personnage garde-fou se tait. C'est le meme choix
## que Point : mieux vaut un decor muet qu'un decor qui raconte une histoire
## qui n'a pas commence.
func offert(mission: Mission) -> bool:
	if abattu or cle == "":
		return false
	if etape_minimale == "":
		return true
	if mission == null:
		return false
	return mission.a_l_etape(etape_minimale) or mission.passee(etape_minimale)


## Le joueur a surveiller. Passe par la maison, qui sait qui joue.
func observer(n: Node3D) -> void:
	_cible = n
	set_process(n != null)


## Va se poster la, puis reste. Le garde s'en sert pour venir fouiller Walter
## au moment ou Tuco l'ordonne, et repartir ensuite.
##
## Un deplacement en ligne droite, sans evitement : la piece fait six metres
## sur huit et le trajet est ecrit dans la scene. Un chemin calcule couterait
## une infrastructure entiere pour trois metres de parquet.
func aller_vers(ou: Vector3) -> void:
	_but = ou
	_marche = true
	set_process(true)
	_jouer(CLIP_MARCHE)


## Il est arrive quelque part ? Le scenario attend la fin d'un deplacement pour
## enchainer — Jesse franchit sa porte une fois qu'il l'a atteinte, pas avant.
func arrive() -> bool:
	return not _marche


## Les noms possibles du clip de marche, dans l'ordre de preference. Meme table
## d'esprit que Demarche.ALLURES : les modeles livres n'ont pas tous les memes
## noms de clips, et un nom absent doit degrader au lieu de casser.
const CLIP_MARCHE := ["Marche", "Walking"]

var _lecteur: AnimationPlayer


# Joue le premier clip disponible de la liste. Rien si aucun n'existe : un
# personnage qui glisse est laid, un personnage qui plante est pire.
func _jouer(candidats: Array) -> void:
	if _lecteur == null:
		return
	for nom in candidats:
		if _lecteur.has_animation(str(nom)):
			var anim := _lecteur.get_animation(str(nom))
			anim.loop_mode = Animation.LOOP_LINEAR
			_lecteur.play(str(nom))
			return


## Combien de metres par seconde quand il se deplace. Un pas decide, pas une
## course : il vient chercher quelque chose sur quelqu'un, il ne fuit pas.
const ALLURE := 1.9

var _but: Vector3 = Vector3.ZERO
var _marche: bool = false

## Sa place, retenue au chargement. Un personnage qu'on deplace doit pouvoir
## revenir : sinon recommencer la partie laisse le garde plante au milieu du
## bureau, la ou la scene precedente l'avait envoye.
var _origine: Vector3 = Vector3.ZERO


## Il retourne a sa place.
func rentrer() -> void:
	if get_parent() is Node3D:
		aller_vers((get_parent() as Node3D).to_global(_origine))
	else:
		aller_vers(_origine)


## Il y est remis d'un coup, sans marcher. Pour recommencer une partie : voir
## quelqu'un traverser la piece au lancement n'a aucun sens.
func replacer() -> void:
	_marche = false
	position = _origine
	rotation.y = _cap_repos


func _process(delta: float) -> void:
	if _marche:
		_avancer(delta)
		return
	if _cible == null:
		return
	var vers := _cible.global_position - global_position
	vers.y = 0.0
	# Au-dela de sa portee d'attention il revient a sa pose de repos, sinon un
	# PNJ passe sa vie a fixer un mur dans la direction ou le joueur est sorti.
	var voulu := _cap_repos
	if vers.length() < attention and vers.length() > 0.05:
		voulu = atan2(-vers.x, -vers.z)      # l'avant d'un noeud Godot est -Z
	rotation.y = rotate_toward(rotation.y, voulu, rotation_vitesse * delta)


# Un pas vers le but, et on regarde ou l'on va. Arrive, il reprend sa vie
# normale — c'est-a-dire qu'il se remet a suivre le joueur du regard.
func _avancer(delta: float) -> void:
	var vers := _but - global_position
	vers.y = 0.0
	if vers.length() <= 0.15:
		_marche = false
		_cap_repos = rotation.y
		# Il reprend sa respiration la ou il s'est arrete.
		_jouer([pose, Demarche.IMMOBILE, Demarche.CYCLE])
		return
	var pas := minf(ALLURE * delta, vers.length())
	global_position += vers.normalized() * pas
	rotation.y = rotate_toward(rotation.y, atan2(-vers.x, -vers.z),
			rotation_vitesse * delta)
