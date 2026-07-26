# La latte descellee, et ce qu'on glisse derriere.
#
# Un ecran a un seul reglage : combien on planque. Haut et bas font varier la
# somme, F valide, Echap referme.
#
# LE PAS N'EST PAS CONSTANT. Choisir 290 000 dollars par tranches de mille
# demanderait deux cent quatre-vingt-dix appuis ; par tranches de cent mille,
# on ne peut pas garder les neuf mille qu'on a le droit de sortir. Le pas suit
# donc l'ordre de grandeur de la somme affichee, comme le ferait une molette
# bien reglee : gros quand on est loin, fin quand on approche.
class_name Cachette
extends Control

signal range(somme: int)

@export var reglages: Reglages

var _ouverte: bool = false
var _choix: int = 0
var _disponible: int = 0
var _reste_maximum: int = 10000
var _cache_total: int = 0
var _audio: Audio


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio


func ouverte() -> bool:
	return _ouverte


func total_cache() -> int:
	return _cache_total


func ouvrir(disponible: int, reste_maximum: int) -> void:
	if _ouverte:
		return
	_ouverte = true
	_disponible = maxi(0, disponible)
	_reste_maximum = maxi(0, reste_maximum)
	# On propose d'emblee le montant JUSTE : tout sauf ce qu'on a le droit de
	# garder. C'est ce que le joueur veut neuf fois sur dix, et il lui reste a
	# appuyer une fois. Proposer zero l'obligerait a monter depuis rien.
	_choix = maxi(0, _disponible - _reste_maximum)
	visible = true
	if _son() != null:
		_son().bruit("roue_ouvre")


func fermer() -> void:
	if not _ouverte:
		return
	_ouverte = false
	visible = false
	if _son() != null:
		_son().bruit("roue_ferme")


## Le pas de reglage, choisi sur l'ordre de grandeur du montant courant.
func _pas() -> int:
	if _disponible >= 100000:
		return 10000 if _choix >= 20000 else 1000
	if _disponible >= 10000:
		return 1000
	return 100


func _process(_delta: float) -> void:
	if not _ouverte:
		return
	var bouge := 0
	if Input.is_action_just_pressed("gaz"):
		bouge = 1
	elif Input.is_action_just_pressed("frein"):
		bouge = -1
	if bouge != 0:
		var avant := _choix
		_choix = clampi(_choix + bouge * _pas(), 0, _disponible)
		if _choix != avant and _son() != null:
			_son().bruit("roue_cran")

	if Input.is_action_just_pressed("interagir"):
		_valider()
	# ON PEUT REPARTIR SANS RIEN CACHER.
	#
	# La seule sortie etait de valider, donc de deposer. Un joueur qui ouvre la
	# latte pour voir ce que c'est se retrouvait oblige de s'en servir, et
	# l'ecran ressemblait a un piege plutot qu'a un choix. Deux touches ferment :
	# celle qui annule partout ailleurs, et celle du telephone, qui est la
	# touche de « je range ce que j'ai en main ».
	elif Input.is_action_just_pressed("ui_cancel") \
			or Input.is_action_just_pressed("telephone"):
		fermer()
	queue_redraw()


func _valider() -> void:
	var somme := _choix
	fermer()
	if somme > 0:
		_cache_total += somme
		range.emit(somme)


func _draw() -> void:
	if not _ouverte:
		return
	var police := get_theme_default_font()
	if police == null:
		return

	var l := 240.0
	var h := 92.0
	var coin := Vector2((size.x - l) / 2.0, size.y * 0.55 - h / 2.0)
	draw_rect(Rect2(coin, Vector2(l, h)), Color(0.06, 0.06, 0.07, 0.92))
	draw_rect(Rect2(coin, Vector2(l, h)), Color(0.36, 0.33, 0.26, 0.9), false, 1.0)

	_ecrire(police, "Cacher derriere la latte",
			coin + Vector2(l / 2.0, 18.0), 12, Color(0.80, 0.78, 0.72))
	_ecrire(police, Bourse.ecrire(_choix), coin + Vector2(l / 2.0, 48.0), 24,
			Color(0.60, 0.82, 0.44))

	var restant := _disponible - _choix
	var bon := restant <= _reste_maximum
	_ecrire(police, "Il vous restera %s" % Bourse.ecrire(restant),
			coin + Vector2(l / 2.0, 66.0), 10,
			Color(0.60, 0.82, 0.44) if bon else Color(0.85, 0.45, 0.35))
	_ecrire(police, "W / S   regler     F   valider     Echap   fermer",
			coin + Vector2(l / 2.0, 84.0), 9, Color(0.62, 0.60, 0.56))


func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color) -> void:
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille).x
	var p := ou - Vector2(largeur / 2.0, 0.0)
	var ombre := Color(0.0, 0.0, 0.0, couleur.a)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		police.draw_string(get_canvas_item(), p + d, texte,
				HORIZONTAL_ALIGNMENT_LEFT, -1, taille, ombre)
	police.draw_string(get_canvas_item(), p, texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
