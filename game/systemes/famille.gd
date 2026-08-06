# Les points de famille.
#
# UN SEUL COMPTEUR, PAS UN PAR PERSONNE. Skyler, Junior et Hank ne tiennent pas
# trois comptes separes : ce qu'on suit, c'est la place qu'on laisse a sa vie
# d'avant. S'occuper d'eux fait monter, penser aux courses fait monter,
# s'occuper de son cancer fait monter. Les negliger fait descendre tout seul.
#
# IL EST AFFICHE, ET C'EST UN CHOIX ASSUME. La direction du projet dit
# habituellement qu'aucun chiffre ne se montre au joueur — voir
# docs/12-direction.md, ou la regle porte desormais son exception. Celui-ci se
# voit en permanence : c'est un compte a rebours qu'on doit pouvoir surveiller
# en conduisant, pas une note qu'on decouvre a la fin.
class_name Famille
extends Node

signal change(points: int)

## Le groupe par lequel le HUD nous trouve, comme pour la bourse et l'audio :
## aucun NodePath a cabler, celui qui veut le compteur le demande.
const GROUPE := "famille"


static func courante(depuis: Node) -> Famille:
	if depuis == null or not depuis.is_inside_tree():
		return null
	return depuis.get_tree().get_first_node_in_group(GROUPE) as Famille

## Les bornes. Zero n'est pas la mort de la relation, c'est le fond : on peut
## toujours remonter, et c'est ce qui rend la negligence rattrapable au prix
## d'un detour.
const MINIMUM := 0
const MAXIMUM := 100
const DEPART := 60

## Ce que chaque attention rapporte. Ce sont des nombres de RESSENTI, et ils
## finiront dans reglages.tres le jour ou on les reglera manette en main. En
## attendant ils vivent ici, groupes, plutot que disperses dans le code.
const GAINS := {
	"presence": 6,     # etre la, parler, ecouter
	"courses": 10,     # y penser sans qu'on le demande
	"soin": 12,        # ses rendez-vous, son traitement
}

## Ce qu'on perd par heure de jeu, sans rien faire. La relation ne tient pas
## toute seule : c'est tout le sujet.
@export_range(0.0, 5.0, 0.1) var perte_par_heure: float = 1.2

## Au-dela de cet ecart d'horloge en une seule image, ce n'est pas du temps
## vecu : c'est quelqu'un qui a POSE l'heure. Une demi-heure est trente fois ce
## que la vitesse la plus rapide du jeu produit en une image, donc le seuil ne
## peut pas se declencher par accident.
const SAUT_MAXIMUM := 0.5

var _points: float = float(DEPART)
var _heure_avant: float = -1.0


func _ready() -> void:
	add_to_group(GROUPE)
	_heure_avant = Reglages.heure
	change.emit(points())
	# DIFFERE : les points d'interaction se construisent avec la scene, et
	# certains vivent dans la mission, instanciee apres nous.
	call_deferred("_brancher_les_points")


# TOUT POINT D'INTERACTION DONT L'EVENEMENT EST UNE ATTENTION NOUS ALIMENTE.
#
# On ne cable pas l'epicerie a la main : le jour ou l'on pose un second magasin,
# ou un rendez-vous medical, ou un fauteuil dans le salon, il suffit d'ecrire
# `evenement = "courses"` dans la scene. Aucun code a ajouter — c'est la
# difference entre une mecanique et une liste d'endroits.
func _brancher_les_points() -> void:
	for n in get_tree().get_nodes_in_group(Point.GROUPE):
		var p := n as Point
		if p == null or not GAINS.has(p.evenement):
			continue
		if not p.utilise.is_connected(_sur_point):
			p.utilise.connect(_sur_point)


func _sur_point(p: Point) -> void:
	merci(p.evenement)


func _process(_delta: float) -> void:
	# ON SUIT L'HORLOGE DU JEU, PAS LE TEMPS REEL. Une pause, un menu ouvert ou
	# un ecran de dialogue ne doivent rien couter : ce qui erode le lien, c'est
	# le temps qu'on passe AILLEURS dans la fiction.
	if _heure_avant < 0.0:
		_heure_avant = Reglages.heure
		return
	var ecoule := Reglages.heure - _heure_avant
	# Minuit repasse a zero : sans ce garde, la traversee de minuit rendrait
	# vingt-trois heures d'un coup.
	if ecoule < 0.0:
		ecoule += 24.0
	if ecoule <= 0.0:
		return
	_heure_avant = Reglages.heure

	# POSER L'HEURE N'EST PAS AVOIR VECU LES HEURES.
	#
	# Une mission, un scenario de capture ou les outils de test appellent
	# Temps.regler() : l'horloge saute de huit heures a dix-sept, et sans ce
	# garde la famille encaissait onze points en une image. Vu a la premiere
	# capture — le compteur affichait 36 apres deux secondes de jeu.
	#
	# On ne peut pas distinguer les deux depuis ici, mais on peut mesurer ce
	# qu'une image PEUT produire : au plus rapide, le temps avance de quelques
	# centiemes d'heure par image. Au-dela du seuil, c'est un reglage, et on se
	# contente de se resynchroniser.
	if ecoule > SAUT_MAXIMUM:
		return
	_poser(_points - perte_par_heure * ecoule)


## Le compteur, arrondi. C'est ce que le HUD affiche.
func points() -> int:
	return roundi(_points)


## Une attention portee. Le nom vient de GAINS ; un nom inconnu ne fait rien
## plutot que d'inventer une valeur.
func merci(quoi: String) -> int:
	var gain := int(GAINS.get(quoi, 0))
	if gain == 0:
		push_warning("famille : '%s' n'est pas une attention connue" % quoi)
		return 0
	ajouter(gain)
	return gain


func ajouter(n: int) -> void:
	_poser(_points + float(n))


## Pose le compteur directement. Sert a la reprise d'une partie et aux outils
## de test.
func poser(n: int) -> void:
	_poser(float(n))


func _poser(v: float) -> void:
	var avant := points()
	_points = clampf(v, float(MINIMUM), float(MAXIMUM))
	if points() != avant:
		change.emit(points())
